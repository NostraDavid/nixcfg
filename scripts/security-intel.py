"""Compare an existing CycloneDX inventory with EUVD and the NixOS tracker."""

import argparse
import hashlib
import json
import math
import os
import re
import subprocess
import sys
import tempfile
import time
import urllib.error
import urllib.parse
import urllib.request
from pathlib import Path

TRACKER = "https://tracker.security.nixos.org/api/v1/suggestions"
EUVD = "https://euvdservices.enisa.europa.eu/api/search"
CVE = re.compile(r"CVE-\d{4}-\d{4,}")


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(
        self,
        _request: urllib.request.Request,
        _response: object,
        _code: int,
        _message: str,
        _headers: object,
        _url: str,
    ) -> None:
        return None


def write_json(path: Path, value: object) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with tempfile.NamedTemporaryFile(mode="w", dir=path.parent, delete=False) as stream:
        temporary = Path(stream.name)
        try:
            json.dump(value, stream, indent=2, ensure_ascii=False, allow_nan=False)
            stream.write("\n")
            stream.close()
            temporary.replace(path)
        finally:
            temporary.unlink(missing_ok=True)


class Client:
    def __init__(self, cache: Path, refresh: bool = False) -> None:
        self.cache = cache
        self.refresh = refresh
        self.requests: list[dict] = []
        cache.mkdir(parents=True, exist_ok=True, mode=0o700)

    def get(self, url: str) -> object:
        parsed = urllib.parse.urlsplit(url)
        if parsed.scheme != "https" or parsed.netloc not in {
            "tracker.security.nixos.org",
            "euvdservices.enisa.europa.eu",
        }:
            raise ValueError("Unexpected advisory API URL")
        path = self.cache / (hashlib.sha256(url.encode()).hexdigest() + ".json")
        now = time.time()
        cached = None
        if path.exists() and not self.refresh:
            try:
                candidate = json.loads(path.read_text())
                if (
                    isinstance(candidate, dict)
                    and candidate.get("url") == url
                    and isinstance(candidate.get("fetched_at"), (int, float))
                    and 0 <= now - candidate["fetched_at"] < 86400
                    and "data" in candidate
                ):
                    cached = candidate
            except (ValueError, OSError):
                pass  # A corrupt cache is replaced only after a successful request.
        if cached is None:
            request = urllib.request.Request(  # noqa: S310 - fixed HTTPS origins checked above.
                url,
                headers={
                    "Accept": "application/json",
                    "User-Agent": "nixcfg-security-check/1",
                },
            )
            opener = urllib.request.build_opener(NoRedirect())
            with opener.open(request, timeout=20) as response:
                redirected = urllib.parse.urlsplit(response.geturl())
                if redirected.scheme != "https" or redirected.netloc != parsed.netloc:
                    raise ValueError("Advisory API redirected to another origin")
                content = response.read(8 * 1024 * 1024 + 1)
            if len(content) > 8 * 1024 * 1024:
                raise ValueError("Advisory API response exceeds 8 MiB")
            cached = {"url": url, "fetched_at": now, "data": json.loads(content)}
            write_json(path, cached)
            from_cache = False
        else:
            from_cache = True
        self.requests.append(
            {"url": url, "fetched_at": cached["fetched_at"], "cached": from_cache}
        )
        return cached["data"]


def inventory(document: object) -> list[dict]:  # noqa: C901 - external nested document validation.
    if not isinstance(document, dict) or document.get("bomFormat") != "CycloneDX":
        raise ValueError("Expected a CycloneDX SBOM")
    items = document.get("components", [])
    metadata = document.get("metadata", {})
    if not isinstance(items, list) or not isinstance(metadata, dict):
        raise TypeError("Invalid CycloneDX components or metadata")
    if "component" in metadata:
        items = [metadata["component"], *items]
    components = {}
    pending = list(items)
    while pending:
        item = pending.pop()
        if (
            not isinstance(item, dict)
            or not isinstance(item.get("name"), str)
            or not item["name"]
        ):
            raise ValueError("SBOM component is missing its name")
        if item.get("version") is not None and not isinstance(item["version"], str):
            raise TypeError(f"Invalid SBOM component version: {item['name']}")
        children = item.get("components", [])
        if not isinstance(children, list):
            raise TypeError("Invalid nested SBOM components")
        pending.extend(children)
        reference = item.get(
            "bom-ref",
            item.get("purl", f"{item['name']}@{item.get('version') or 'unknown'}"),
        )
        if not isinstance(reference, str) or not reference:
            raise ValueError("Invalid SBOM component reference")
        component = {
            key: item[key]
            for key in ("name", "version", "purl", "properties")
            if key in item
        }
        component["reference"] = reference
        component["version"] = item.get("version") or None
        if reference in components and components[reference] != component:
            raise ValueError(f"Conflicting SBOM component: {reference}")
        components[reference] = component
    if not components:
        raise ValueError("SBOM contains no versioned components")
    return list(components.values())


def page(data: object, field: str, total_field: str) -> tuple[list, int]:
    if not isinstance(data, dict) or not isinstance(data.get(field), list):
        raise TypeError(f"Invalid API page: missing {field}")
    total = data.get(total_field)
    if type(total) is not int or total < 0:
        raise TypeError("Invalid API result count")
    if not all(isinstance(item, dict) for item in data[field]):
        raise ValueError("Invalid API result entry")
    return data[field], total


def tracker(client: Client, name: str) -> list[dict]:  # noqa: C901 - validate each pagination boundary.
    query = urllib.parse.urlencode(
        [("package", name), ("status", "accepted"), ("status", "published")]
    )
    url = TRACKER + "?" + query
    seen = set()
    results = []
    received = 0
    while url:
        if url in seen or len(seen) >= 1000:
            raise ValueError("Tracker pagination repeats or exceeds 1000 pages")
        seen.add(url)
        data = client.get(url)
        items, total = page(data, "results", "count")
        received += len(items)
        for item in items:
            if not isinstance(item.get("packages"), dict) or not CVE.fullmatch(
                str(item.get("cve_id", ""))
            ):
                raise ValueError("Invalid tracker CVE or package bindings")
            if item.get("status") not in {
                "accepted",
                "published",
                "pending",
                "rejected",
            }:
                raise ValueError("Unknown tracker review status")
            if name in item["packages"] and item["status"] in {"accepted", "published"}:
                results.append(
                    {
                        "ids": [item["cve_id"]],
                        "source": "nixos-tracker",
                        "url": f"https://tracker.security.nixos.org/suggestions/by-cve/{item['cve_id']}",
                        "title": item.get("title"),
                        "review_status": item["status"],
                        "package_context": item["packages"][name],
                        "affected_products": item.get("affected_products", []),
                    }
                )
        next_page = data.get("next")
        if next_page is not None:
            if not isinstance(next_page, str) or not items:
                raise ValueError("Invalid tracker next page")
            next_page = urllib.parse.urljoin(url, next_page)
            parsed = urllib.parse.urlsplit(next_page)
            parameters = urllib.parse.parse_qs(parsed.query)
            if (
                parsed.scheme != "https"
                or parsed.netloc != urllib.parse.urlsplit(TRACKER).netloc
                or parsed.path != urllib.parse.urlsplit(TRACKER).path
                or parameters.get("package") != [name]
            ):
                raise ValueError("Tracker next page changed origin or package")
        elif received != total:
            raise ValueError("Tracker returned an incomplete result set")
        url = next_page
    return results


def euvd_items(client: Client, name: str, exploited: bool = False) -> list[dict]:
    results = []
    seen = set()
    for number in range(1000):
        query = {"product": name, "page": number, "size": 100}
        if exploited:
            query["exploited"] = "true"
        data = client.get(EUVD + "?" + urllib.parse.urlencode(query))
        items, total = page(data, "items", "total")
        for item in items:
            identifier = item.get("id")
            if not isinstance(identifier, str) or not re.fullmatch(
                r"EUVD-\d{4}-\d+", identifier
            ):
                raise ValueError("Invalid EUVD identifier")
            if identifier in seen:
                raise ValueError("EUVD pagination repeated an entry")
            seen.add(identifier)
            products = item.get("enisaIdProduct")
            if not isinstance(products, list) or not all(
                isinstance(row, dict)
                and isinstance(row.get("product"), dict)
                and isinstance(row["product"].get("name"), str)
                for row in products
            ):
                raise ValueError("Invalid EUVD product bindings")
            if any(
                row["product"]["name"].casefold() == name.casefold() for row in products
            ):
                results.append(item)
        if len(seen) == total:
            return results
        if not items or len(seen) > total:
            raise ValueError("EUVD returned an incomplete result set")
    raise ValueError("EUVD pagination exceeds 1000 pages")


def euvd(client: Client, name: str) -> list[dict]:
    items = euvd_items(client, name)
    results = []
    for item in items:
        aliases = item.get("aliases", "")
        if not isinstance(aliases, str):
            raise TypeError("Invalid EUVD aliases")
        for key in ("baseScore", "epss"):
            value = item.get(key)
            if value is not None and (
                type(value) not in {float, int}
                or not math.isfinite(value)
                or not 0 <= value <= (10 if key == "baseScore" else 100)
            ):
                raise ValueError(f"Invalid EUVD {key}")
        results.append(
            {
                "ids": sorted(set(CVE.findall(aliases))) or [item["id"]],
                "aliases": aliases.split(),
                "source": "euvd",
                "id": item["id"],
                "url": "https://euvd.enisa.europa.eu/vulnerability/" + item["id"],
                "description": item.get("description"),
                "references": item.get("references"),
                "cvss": item.get("baseScore"),
                "epss_raw": item.get("epss"),
                "exploited": None,
                "affected_products": item["enisaIdProduct"],
            }
        )
    return results


def assess(components: list[dict], client: Client) -> dict:  # noqa: C901 - retain independent source failures and partial results.
    advisories = {}
    errors = []
    queries = []
    unavailable = set()
    names = sorted({component["name"] for component in components})
    for index, name in enumerate(names, 1):
        if index == 1 or index % 25 == 0:
            print(
                f"Checking package {index}/{len(names)}: {name}",
                file=sys.stderr,
                flush=True,
            )
        references = [
            component["reference"]
            for component in components
            if component["name"] == name
        ]
        for source, fetch in [("nixos-tracker", tracker), ("euvd", euvd)]:
            if source in unavailable:
                queries.append(
                    {"source": source, "package": name, "status": "unavailable"}
                )
                continue
            try:
                records = fetch(client, name)
            except (TypeError, ValueError, OSError) as error:
                if isinstance(error, (urllib.error.URLError, TimeoutError)):
                    unavailable.add(source)
                errors.append({"source": source, "package": name, "error": str(error)})
                queries.append({"source": source, "package": name, "status": "error"})
                continue
            queries.append(
                {
                    "source": source,
                    "package": name,
                    "status": "candidates" if records else "unknown",
                    "count": len(records),
                }
            )
            if source == "euvd" and records:
                try:
                    exploited = {
                        item["id"] for item in euvd_items(client, name, exploited=True)
                    }
                    for record in records:
                        record["exploited"] = record["id"] in exploited
                except (TypeError, ValueError, OSError) as error:
                    errors.append(
                        {
                            "source": source,
                            "package": name,
                            "phase": "exploitation",
                            "error": str(error),
                        }
                    )
            for record in records:
                for identifier in record["ids"]:
                    advisory = advisories.setdefault(
                        identifier,
                        {
                            "id": identifier,
                            "assessment": "needs_review",
                            "components": [],
                            "sources": [],
                        },
                    )
                    advisory["components"] = sorted(
                        set(advisory["components"]) | set(references)
                    )
                    advisory["sources"].append(record)
    ordered = sorted(
        advisories.values(),
        key=lambda item: (
            not any(source.get("exploited") is True for source in item["sources"]),
            item["id"],
        ),
    )
    return {
        "schema_version": 1,
        "status": "incomplete" if errors else "complete",
        "advisory_only": True,
        "created_at": time.time(),
        "coverage": "Package-name candidates, not proof of affected versions or local backport applicability. Tracker: accepted/published bindings. EUVD: exact product names. Empty results do not establish safety; embedded dependencies can be absent from the SBOM.",
        "components": components,
        "advisories": ordered,
        "errors": errors,
        "queries": queries,
        "requests": client.requests,
    }


def main() -> int:  # noqa: C901,PLR0912,PLR0915 - CLI input/output and partial-failure reporting.
    parser = argparse.ArgumentParser(description=__doc__)
    inputs = parser.add_mutually_exclusive_group()
    inputs.add_argument(
        "--sbom", type=Path, help="Existing CycloneDX JSON; never build its target"
    )
    inputs.add_argument(
        "--target",
        type=Path,
        default=Path("/run/current-system"),
        help="Existing store output; defaults to the running NixOS generation",
    )
    parser.add_argument(
        "--package",
        action="append",
        default=[],
        help="Check only this exact SBOM component name; repeatable",
    )
    parser.add_argument(
        "--vex",
        type=Path,
        help="Retain OpenVEX as context, without suppressing findings",
    )
    parser.add_argument(
        "--output",
        type=Path,
        help="JSON output; default: a fresh reports/security-intel/run.* directory",
    )
    parser.add_argument(
        "--refresh", action="store_true", help="Bypass the 24-hour local response cache"
    )
    args = parser.parse_args()
    if args.output and any(
        args.output.resolve() == path.resolve()
        for path in (args.sbom, args.vex)
        if path
    ):
        parser.error("Output must not overwrite the SBOM or VEX input")
    if (
        args.output
        and args.sbom is None
        and args.output.name in {"sbom.cdx.json", "sbom.csv", "sbom.spdx.json"}
    ):
        parser.error("Output name conflicts with a generated SBOM artifact")
    if args.output:
        output = args.output
        output.parent.mkdir(parents=True, exist_ok=True)
    else:
        parent = Path("reports/security-intel")
        parent.mkdir(parents=True, exist_ok=True)
        output = Path(tempfile.mkdtemp(prefix="run.", dir=parent)) / "intelligence.json"
    try:
        sbom = args.sbom
        target = None
        if sbom is None:
            target = args.target.resolve(strict=True)
            if target.parent != Path("/nix/store") or target.suffix == ".drv":
                raise ValueError(
                    "--target must resolve to an existing Nix store output, not a flake or derivation"
                )
            sbom = output.parent / "sbom.cdx.json"
            subprocess.run(  # noqa: S603 - target is a realized store output.
                [  # noqa: S607 - repository-provided scanner on PATH.
                    "sbomnix",
                    str(target),
                    "--exclude-meta",
                    "--exclude-cpe-matching",
                    "--cdx",
                    str(sbom),
                    "--csv",
                    str(output.parent / "sbom.csv"),
                    "--spdx",
                    str(output.parent / "sbom.spdx.json"),
                ],
                check=True,
            )
        sbom_data = sbom.read_bytes()
        components = inventory(json.loads(sbom_data))
        if args.package:
            names = {item["name"] for item in components}
            if set(args.package) - names:
                raise ValueError("Requested package is absent from the SBOM")
            components = [item for item in components if item["name"] in args.package]
        context = None
        vex_data = None
        if args.vex:
            vex_data = args.vex.read_bytes()
            context = json.loads(vex_data)
            if (
                not isinstance(context, dict)
                or context.get("@context") != "https://openvex.dev/ns/v0.2.0"
                or not isinstance(context.get("statements"), list)
            ):
                raise ValueError("Invalid OpenVEX context")
        cache = (
            Path(os.environ.get("XDG_CACHE_HOME", str(Path.home() / ".cache")))
            / "nixcfg-security-intel"
        )
        result = assess(components, Client(cache, args.refresh))
        result["inventory"] = {
            "sbom": str(sbom.resolve()),
            "sha256": hashlib.sha256(sbom_data).hexdigest(),
            "target": str(target) if target else None,
        }
        if context is not None:
            result["vex_context"] = {
                "applied": False,
                "sha256": hashlib.sha256(vex_data).hexdigest(),
                "document": context,
            }
    except (TypeError, ValueError, OSError, subprocess.CalledProcessError) as error:
        result = {
            "schema_version": 1,
            "status": "incomplete",
            "advisory_only": True,
            "advisories": [],
            "errors": [{"error": str(error)}],
        }
    write_json(output, result)
    print(f"Security intelligence: {output}")
    print(
        f"{result['status']}: {len(result['advisories'])} advisory candidates; {len(result['errors'])} errors"
    )
    for advisory in result["advisories"][:20]:
        priority = (
            "known exploited; "
            if any(source.get("exploited") is True for source in advisory["sources"])
            else ""
        )
        print(f"  {advisory['id']}: {priority}needs review")
    return 2 if result["status"] == "incomplete" else 0


if __name__ == "__main__":
    sys.exit(main())

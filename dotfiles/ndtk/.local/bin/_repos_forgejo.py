#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "structlog==26.1.0",
# ]
# ///

from __future__ import annotations

import concurrent.futures
import json
import os
import shutil
import sys
from pathlib import Path
from urllib.request import Request, urlopen

sys.path.insert(0, str(Path.home() / ".local" / "bin"))
import _repos_github as repos

API = "https://forgejo.powerlan.empire/api/v1/user/repos"


def repository_urls(token: str) -> list[str]:
    urls = []
    page = 1
    while True:
        request = Request(  # noqa: S310 - fixed HTTPS endpoint
            f"{API}?limit=50&page={page}",
            headers={"Authorization": f"token {token}", "Accept": "application/json"},
        )
        with urlopen(request, timeout=30) as response:  # noqa: S310 - fixed HTTPS endpoint
            records = json.load(response)
        if not isinstance(records, list):
            raise TypeError("Forgejo returned an invalid repository list")
        for record in records:
            url = record["ssh_url"]
            name = repos.repo_path_part(url)
            if (
                repos.url_host(url) != "forgejo.powerlan.empire"
                or len(name.split("/")) != 2
                or any(part in {"", ".", ".."} for part in name.split("/"))
            ):
                raise ValueError("Forgejo returned an invalid repository URL")
            urls.append(url)
        if len(records) < 50:
            return sorted(set(urls), key=str.casefold)
        page += 1


def run_tests(verbose: bool) -> int:
    import io  # noqa: PLC0415 - used only by test
    import unittest  # noqa: PLC0415 - used only by test
    from unittest import mock  # noqa: PLC0415 - used only by test

    class Tests(unittest.TestCase):
        def test_pagination(self) -> None:
            record = {
                "ssh_url": "ssh://forgejo@forgejo.powerlan.empire:2222/owner/repo.git"
            }
            pages = [io.BytesIO(json.dumps([record] * 50).encode()), io.BytesIO(b"[]")]
            with mock.patch(f"{__name__}.urlopen", side_effect=pages) as request:
                self.assertEqual(repository_urls("test"), [record["ssh_url"]])
                self.assertEqual(request.call_count, 2)

    result = unittest.TextTestRunner(verbosity=2 if verbose else 1).run(
        unittest.defaultTestLoader.loadTestsFromTestCase(Tests)
    )
    return 0 if result.wasSuccessful() else 1


def main() -> int:
    args = repos.parse_args(provider="forgejo")
    if args.command == "test":
        return run_tests(args.verbose)
    if args.command == "check":
        errors = []
        if not shutil.which("git"):
            errors.append("missing executable: git")
        if not os.environ.get("FORGEJO_TOKEN"):
            errors.append("missing environment variable: FORGEJO_TOKEN")
        print(
            "\n".join(errors) if errors else "OK",
            file=sys.stderr if errors else sys.stdout,
        )
        return int(bool(errors))
    token = os.environ.get("FORGEJO_TOKEN")
    if not token:
        print("missing environment variable: FORGEJO_TOKEN", file=sys.stderr)
        return 1
    repos.configure_logging()
    try:
        urls = repository_urls(token)
        target = args.target_dir.expanduser()
        if not args.dry_run:
            target.mkdir(parents=True, exist_ok=True)
        with concurrent.futures.ThreadPoolExecutor(
            max_workers=repos.detect_jobs(args.jobs)
        ) as executor:
            results = list(
                executor.map(
                    lambda url: repos.clone_or_update_repo(
                        url,
                        target,
                        None if args.all_branches else repos.parse_csv(args.branches),
                        repos.parse_csv(args.tags),
                        args.all_tags,
                        args.worktrees,
                        args.prune_worktrees,
                        args.fetch_timeout,
                        args.dry_run,
                    ),
                    urls,
                )
            )
        return int(any(not result[1] for result in results))
    except Exception as exc:  # noqa: BLE001 - report worker and API failures
        print(f"Forgejo sync failed: {exc}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())

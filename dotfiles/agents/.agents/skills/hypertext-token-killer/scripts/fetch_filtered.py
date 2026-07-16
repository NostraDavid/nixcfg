#!/usr/bin/env -S uv run --script
# /// script
# requires-python = ">=3.14"
# dependencies = [
#     "beautifulsoup4==4.15.0",
#     "click==8.4.2",
#     "niquests==3.20.1",
#     "pytest==9.1.1",
#     "pytest-cov==7.1.0",
#     "structlog==26.1.0",
# ]
# ///

"""Fetch web documentation and emit only compact, semantic HTML."""

import contextlib
import ipaddress
import io
import os
import socket
import subprocess as sp
import sys
import tempfile
from dataclasses import dataclass
from enum import StrEnum
from pathlib import Path
from urllib.parse import SplitResult, urljoin, urlsplit, urlunsplit

import click
import niquests as http
import pytest
import structlog as sl
import structlog.stdlib as log
from bs4 import BeautifulSoup, Comment, NavigableString, Tag
from click.testing import CliRunner

logger = log.get_logger(__name__)


class FilterError(Exception):
    """Report an expected fetch, filtering, or output failure."""


class Profile(StrEnum):
    """Control the trade-off between fidelity and token reduction."""

    CONSERVATIVE = "conservative"
    BALANCED = "balanced"
    COMPACT = "compact"


@dataclass(frozen=True)
class FilterOptions:
    strip_attributes: bool
    preserve_links: bool
    preserve_image_alt: bool
    preserve_tables: bool
    remove_boilerplate: bool
    collapse_whitespace: bool
    unwrap_containers: bool


@dataclass(frozen=True)
class FilterResult:
    html: str
    input_characters: int
    input_elements: int
    output_elements: int

    @property
    def elements_removed(self) -> int:
        return max(0, self.input_elements - self.output_elements)

    @property
    def character_reduction(self) -> float:
        if self.input_characters == 0:
            return 0.0
        removed = max(0, self.input_characters - len(self.html))
        return removed / self.input_characters * 100


@dataclass(frozen=True)
class DownloadedDocument:
    html: str
    final_url: str
    raw_bytes: int


PROFILES = {
    Profile.CONSERVATIVE: FilterOptions(
        strip_attributes=False,
        preserve_links=True,
        preserve_image_alt=True,
        preserve_tables=True,
        remove_boilerplate=False,
        collapse_whitespace=False,
        unwrap_containers=False,
    ),
    Profile.BALANCED: FilterOptions(
        strip_attributes=True,
        preserve_links=True,
        preserve_image_alt=True,
        preserve_tables=True,
        remove_boilerplate=True,
        collapse_whitespace=True,
        unwrap_containers=True,
    ),
    Profile.COMPACT: FilterOptions(
        strip_attributes=True,
        preserve_links=False,
        preserve_image_alt=False,
        preserve_tables=False,
        remove_boilerplate=True,
        collapse_whitespace=True,
        unwrap_containers=True,
    ),
}

ALWAYS_REMOVE = {
    "audio",
    "base",
    "canvas",
    "embed",
    "head",
    "iframe",
    "link",
    "meta",
    "noscript",
    "object",
    "picture",
    "script",
    "style",
    "svg",
    "template",
    "video",
}
BOILERPLATE_TAGS = {"aside", "dialog", "footer", "form", "nav"}
BOILERPLATE_ROLES = {"banner", "complementary", "contentinfo", "navigation"}
FORM_CONTROLS = {"button", "input", "option", "select", "textarea"}
TABLE_TAGS = {
    "caption",
    "col",
    "colgroup",
    "table",
    "tbody",
    "td",
    "tfoot",
    "th",
    "thead",
    "tr",
}
EMPTY_OK = {"br", "hr"}
UNSAFE_ATTRIBUTES = {"class", "id", "integrity", "nonce", "srcdoc", "style"}
REDIRECT_STATUSES = {301, 302, 303, 307, 308}
HTML_MEDIA_TYPES = {"application/xhtml+xml", "text/html"}


def configure_logging() -> None:
    """Send human-readable structured logs to stderr."""
    sl.configure(
        processors=[
            sl.processors.TimeStamper(fmt="iso", utc=True),
            sl.processors.add_log_level,
            sl.dev.ConsoleRenderer(colors=sys.stderr.isatty()),
        ],
        wrapper_class=sl.make_filtering_bound_logger("debug"),
        logger_factory=sl.PrintLoggerFactory(file=sys.stderr),
        cache_logger_on_first_use=False,
    )


def parse_source_url(url: str) -> SplitResult:
    """Validate URL syntax before any network operation."""
    parsed = urlsplit(url.strip())
    if parsed.scheme not in {"http", "https"}:
        raise FilterError("URL scheme must be http or https")
    if parsed.username is not None or parsed.password is not None:
        raise FilterError("URL credentials are not allowed")
    if parsed.hostname is None:
        raise FilterError("URL must include a hostname")
    return parsed


def ensure_allowed_addresses(
    hostname: str,
    addresses: tuple[str, ...],
    *,
    allow_private: bool,
) -> None:
    """Reject targets that resolve outside the public Internet by default."""
    if not addresses:
        raise FilterError(f"hostname did not resolve: {hostname}")
    if allow_private:
        return
    blocked = [
        address for address in addresses if not ipaddress.ip_address(address).is_global
    ]
    if blocked:
        raise FilterError(
            f"hostname resolves to a non-public address: {hostname}; "
            "use --allow-private only for an intended private documentation host"
        )


def validate_network_target(url: str, *, allow_private: bool) -> SplitResult:
    """Resolve and validate every initial or redirected network target."""
    parsed = parse_source_url(url)
    hostname = parsed.hostname
    if hostname is None:
        raise FilterError("URL must include a hostname")
    port = parsed.port or (443 if parsed.scheme == "https" else 80)
    try:
        records = socket.getaddrinfo(
            hostname,
            port,
            type=socket.SOCK_STREAM,
        )
    except socket.gaierror as error:
        raise FilterError(f"hostname lookup failed: {hostname}") from error
    addresses = tuple(
        sorted(
            {
                address
                for record in records
                if isinstance((address := record[4][0]), str)
            }
        )
    )
    ensure_allowed_addresses(
        hostname,
        addresses,
        allow_private=allow_private,
    )
    return parsed


def display_url(url: str) -> str:
    """Remove query and fragment data from diagnostics."""
    parsed = parse_source_url(url)
    return urlunsplit((parsed.scheme, parsed.netloc, parsed.path, "", ""))


def read_limited_body(response: http.Response, max_bytes: int) -> bytes:
    """Read a streamed response without crossing the configured byte bound."""
    content_length = response.headers.get("content-length")
    if content_length is not None:
        try:
            declared_size = int(content_length)
        except ValueError as error:
            raise FilterError("server returned an invalid Content-Length") from error
        if declared_size > max_bytes:
            raise FilterError(f"document exceeds --max-bytes ({max_bytes})")

    chunks: list[bytes] = []
    received = 0
    for chunk in response.iter_content(chunk_size=65_536):
        if not chunk:
            continue
        received += len(chunk)
        if received > max_bytes:
            raise FilterError(f"document exceeds --max-bytes ({max_bytes})")
        chunks.append(chunk)
    return b"".join(chunks)


def decode_body(body: bytes, encoding: str | None) -> str:
    """Decode server bytes deterministically with a safe fallback."""
    selected_encoding = encoding or "utf-8"
    try:
        return body.decode(selected_encoding, errors="replace")
    except LookupError:
        return body.decode("utf-8", errors="replace")


def download_document(
    url: str,
    *,
    max_bytes: int,
    timeout_seconds: float,
    max_redirects: int,
    allow_private: bool,
    trust_environment: bool,
) -> DownloadedDocument:
    """Fetch HTML while validating each redirect before following it."""
    current_url = url
    with http.Session() as session:
        session.trust_env = trust_environment
        for redirect_count in range(max_redirects + 1):
            validate_network_target(current_url, allow_private=allow_private)
            try:
                response = session.get(
                    current_url,
                    allow_redirects=False,
                    headers={
                        "Accept": "text/html,application/xhtml+xml;q=0.9",
                        "User-Agent": "HyperText-Token-Killer/1.0",
                    },
                    stream=True,
                    timeout=(timeout_seconds, timeout_seconds),
                )
            except http.exceptions.RequestException as error:
                raise FilterError(
                    f"request failed for {display_url(current_url)} "
                    f"({type(error).__name__})"
                ) from error

            with response:
                status_code = response.status_code
                if status_code is None:
                    raise FilterError("server returned no HTTP status")
                if status_code in REDIRECT_STATUSES:
                    location = response.headers.get("location")
                    if location is None:
                        raise FilterError("redirect response omitted Location")
                    if redirect_count == max_redirects:
                        raise FilterError(f"redirect limit exceeded ({max_redirects})")
                    current_url = urljoin(current_url, location)
                    continue
                if status_code >= 400:
                    raise FilterError(f"HTTP {status_code} from documentation host")

                media_type = response.headers.get("content-type", "").split(";", 1)[0]
                media_type = media_type.strip().lower()
                if media_type and media_type not in HTML_MEDIA_TYPES:
                    raise FilterError(f"expected HTML but received {media_type}")
                body = read_limited_body(response, max_bytes)
                return DownloadedDocument(
                    html=decode_body(body, response.encoding),
                    final_url=current_url,
                    raw_bytes=len(body),
                )

    raise FilterError("redirect processing ended unexpectedly")


def select_content(soup: BeautifulSoup) -> Tag | BeautifulSoup:
    """Prefer the page's explicit documentation content boundary."""
    main = soup.find("main")
    if isinstance(main, Tag):
        return main
    articles = list(soup.find_all("article"))
    substantial = [tag for tag in articles if len(tag.get_text(" ", strip=True)) >= 200]
    if substantial:
        return max(substantial, key=lambda tag: len(tag.get_text(" ", strip=True)))
    if soup.body is not None:
        return soup.body
    return soup


def attribute_text(tag: Tag, name: str) -> str | None:
    """Read only scalar HTML attributes."""
    value = tag.get(name)
    return value if isinstance(value, str) else None


def safe_link(value: str, base_url: str) -> str | None:
    """Resolve useful link targets while rejecting active URL schemes."""
    trimmed = value.strip()
    if not trimmed:
        return ""
    if trimmed.startswith("#") or trimmed.lower().startswith(("mailto:", "tel:")):
        return trimmed
    resolved = urlsplit(urljoin(base_url, trimmed))
    if resolved.scheme not in {"http", "https"}:
        return None
    if resolved.username is not None or resolved.password is not None:
        return None
    return resolved.geturl()


def remove_unwanted_content(root: BeautifulSoup, options: FilterOptions) -> None:
    """Remove non-content elements before any serialization reaches stdout."""
    for tag in list(root.find_all(ALWAYS_REMOVE)):
        if not tag.decomposed:
            tag.decompose()
    for tag in list(root.find_all(True)):
        if tag.decomposed:
            continue
        if tag.has_attr("hidden") or attribute_text(tag, "aria-hidden") == "true":
            tag.decompose()

    if options.remove_boilerplate:
        for tag in list(root.find_all(BOILERPLATE_TAGS)):
            if not tag.decomposed:
                tag.decompose()
        for tag in list(root.find_all(True)):
            if not tag.decomposed and attribute_text(tag, "role") in BOILERPLATE_ROLES:
                tag.decompose()
    else:
        for tag in list(root.find_all(FORM_CONTROLS)):
            if not tag.decomposed:
                tag.decompose()

    for comment in list(root.find_all(string=lambda value: isinstance(value, Comment))):
        comment.extract()


def transform_images(root: BeautifulSoup, preserve_alt: bool) -> None:
    for image in list(root.find_all("img")):
        alt = attribute_text(image, "alt") or ""
        alt = " ".join(alt.split())
        if preserve_alt and alt:
            image.replace_with(NavigableString(f"[Image: {alt}]"))
        else:
            image.decompose()


def clean_attributes(tag: Tag, options: FilterOptions, base_url: str) -> None:
    """Keep only attributes with semantic value and safe link targets."""
    original = dict(tag.attrs)
    tag.attrs = {}
    for name, value in original.items():
        lowered = name.lower()
        if lowered.startswith("on") or lowered in UNSAFE_ATTRIBUTES:
            continue
        scalar = value if isinstance(value, str) else None
        if tag.name == "a" and lowered == "href" and options.preserve_links:
            if scalar is not None:
                href = safe_link(scalar, base_url)
                if href is not None:
                    tag["href"] = href
            continue
        is_table_structure = (
            options.preserve_tables
            and tag.name in {"td", "th"}
            and lowered in {"colspan", "rowspan"}
        )
        is_list_structure = (tag.name == "ol" and lowered == "start") or (
            tag.name == "li" and lowered == "value"
        )
        is_code_language = tag.name == "code" and lowered == "data-language"
        is_time_value = tag.name == "time" and lowered == "datetime"
        if scalar is not None and (
            not options.strip_attributes
            or is_table_structure
            or is_list_structure
            or is_code_language
            or is_time_value
        ):
            tag[lowered] = scalar


def collapse_text_whitespace(root: BeautifulSoup) -> None:
    """Collapse prose whitespace without changing preformatted or code content."""
    for node in list(root.find_all(string=True)):
        if isinstance(node, Comment):
            continue
        if node.find_parent(["code", "pre"]):
            continue
        raw = str(node)
        collapsed = " ".join(raw.split())
        if collapsed and raw[:1].isspace():
            collapsed = f" {collapsed}"
        if collapsed and raw[-1:].isspace():
            collapsed = f"{collapsed} "
        node.replace_with(NavigableString(collapsed))

    for tag in [root, *root.find_all(True)]:
        if tag.name in {"code", "pre"}:
            continue
        if tag.contents and isinstance(tag.contents[0], NavigableString):
            tag.contents[0].replace_with(NavigableString(str(tag.contents[0]).lstrip()))
        if tag.contents and isinstance(tag.contents[-1], NavigableString):
            tag.contents[-1].replace_with(
                NavigableString(str(tag.contents[-1]).rstrip())
            )


def remove_empty_elements(root: BeautifulSoup) -> None:
    """Remove empty leaves until the tree reaches a stable state."""
    changed = True
    while changed:
        changed = False
        for tag in reversed(list(root.find_all(True))):
            if tag.name in EMPTY_OK:
                continue
            if not tag.get_text(strip=True) and not tag.find(True):
                tag.decompose()
                changed = True


def filter_html(html: str, base_url: str, profile: Profile) -> FilterResult:
    """Produce compact semantic HTML from an untrusted source document."""
    options = PROFILES[profile]
    soup = BeautifulSoup(html, "html.parser")
    input_elements = len(soup.find_all(True))
    source = select_content(soup)
    root = BeautifulSoup(source.decode_contents(), "html.parser")

    remove_unwanted_content(root, options)
    transform_images(root, options.preserve_image_alt)
    if not options.preserve_links:
        for tag in list(root.find_all("a")):
            tag.unwrap()
    if not options.preserve_tables:
        for tag in reversed(list(root.find_all(TABLE_TAGS))):
            tag.unwrap()
    if options.unwrap_containers:
        for tag in list(root.find_all(["div", "span"])):
            tag.unwrap()

    for tag in list(root.find_all(True)):
        clean_attributes(tag, options, base_url)
    if options.collapse_whitespace:
        collapse_text_whitespace(root)
    remove_empty_elements(root)
    root.smooth()
    output = root.decode_contents(formatter="minimal").strip()
    return FilterResult(
        html=output,
        input_characters=len(html),
        input_elements=input_elements,
        output_elements=len(root.find_all(True)),
    )


def write_output(path: Path, content: str, *, force: bool) -> None:
    """Atomically write filtered content without clobbering by default."""
    if not path.parent.is_dir():
        raise FilterError(f"output directory does not exist: {path.parent}")
    if path.exists() and not force:
        raise FilterError(f"output already exists: {path}; use --force to replace it")
    previous_mode = path.stat().st_mode if path.exists() else None
    descriptor, temporary_name = tempfile.mkstemp(
        dir=path.parent,
        prefix=f".{path.name}.",
        text=True,
    )
    temporary = Path(temporary_name)
    try:
        with os.fdopen(descriptor, "w", encoding="utf-8") as output:
            output.write(content)
            output.write("\n")
        if previous_mode is not None:
            temporary.chmod(previous_mode)
        temporary.replace(path)
    except OSError as error:
        temporary.unlink(missing_ok=True)
        raise FilterError(f"could not write output: {path}") from error


@click.group()
def cli() -> None:
    """Fetch web documentation without exposing raw HTML to the caller."""
    configure_logging()


@cli.command(name="fetch")
@click.argument("url")
@click.option(
    "--profile",
    type=click.Choice([profile.value for profile in Profile]),
    default=Profile.BALANCED.value,
    show_default=True,
    help="Filtering profile.",
)
@click.option(
    "--output",
    type=click.Path(path_type=Path, dir_okay=False),
    help="Atomically store filtered HTML instead of printing it.",
)
@click.option("--force", is_flag=True, help="Replace an existing output file.")
@click.option(
    "--max-bytes",
    type=click.IntRange(min=1),
    default=4_000_000,
    show_default=True,
    help="Maximum downloaded response bytes.",
)
@click.option(
    "--max-output-chars",
    type=click.IntRange(min=1),
    default=200_000,
    show_default=True,
    help="Fail when filtered HTML remains larger than this bound.",
)
@click.option(
    "--timeout",
    "timeout_seconds",
    type=click.FloatRange(min=0.1),
    default=15.0,
    show_default=True,
    help="Connect and read timeout in seconds.",
)
@click.option(
    "--max-redirects",
    type=click.IntRange(min=0, max=20),
    default=5,
    show_default=True,
    help="Maximum validated redirects.",
)
@click.option(
    "--allow-private",
    is_flag=True,
    help="Allow an intended localhost or private-network documentation host.",
)
@click.option(
    "--trust-environment",
    is_flag=True,
    help="Honor ambient proxy and .netrc configuration.",
)
def fetch_command(
    url: str,
    profile: str,
    output: Path | None,
    force: bool,
    max_bytes: int,
    max_output_chars: int,
    timeout_seconds: float,
    max_redirects: int,
    allow_private: bool,
    trust_environment: bool,
) -> None:
    """Fetch URL and emit or store filtered semantic HTML."""
    try:
        document = download_document(
            url,
            max_bytes=max_bytes,
            timeout_seconds=timeout_seconds,
            max_redirects=max_redirects,
            allow_private=allow_private,
            trust_environment=trust_environment,
        )
        result = filter_html(document.html, document.final_url, Profile(profile))
        if not result.html:
            raise FilterError(
                "filter removed all content; retry with --profile conservative"
            )
        if len(result.html) > max_output_chars:
            raise FilterError(
                f"filtered output exceeds --max-output-chars ({max_output_chars}); "
                "retry with --profile compact or a higher explicit bound"
            )
        if output is None:
            click.echo(result.html)
        else:
            write_output(output, result.html, force=force)
            click.echo(output)
    except FilterError as error:
        raise click.ClickException(str(error)) from error

    logger.info(
        "document_filtered",
        source=display_url(document.final_url),
        raw_bytes=document.raw_bytes,
        input_characters=result.input_characters,
        output_characters=len(result.html),
        reduction=f"{result.character_reduction:.1f}%",
        elements_removed=result.elements_removed,
        profile=profile,
        stored=output is not None,
    )


def compact_pytest_output(output: str) -> str:
    """Remove pytest-cov banners while preserving its useful report."""
    lines = []
    for line in output.splitlines():
        is_section_banner = (
            line.startswith("=") and line.endswith("=") and " tests coverage " in line
        )
        is_platform_banner = (
            line.startswith("_")
            and line.endswith("_")
            and " coverage: platform " in line
        )
        if not is_section_banner and not is_platform_banner:
            lines.append(line)
    return "\n".join(lines).strip() + "\n"


@click.command(name="unit-test")
def _embedded_unit_test_command() -> None:
    """Run embedded tests and report line and branch coverage."""
    with tempfile.TemporaryDirectory(prefix="python-cli-coverage-") as directory:
        coverage_config = Path(directory) / ".coveragerc"
        coverage_config.write_text(
            os.linesep.join(
                (
                    "[run]",
                    "patch = subprocess",
                    "include =",
                    f"    {Path(__file__).resolve().as_posix()}",
                    "",
                )
            ),
            encoding="utf-8",
        )
        previous_coverage_file = os.environ.get("COVERAGE_FILE")
        os.environ["COVERAGE_FILE"] = str(Path(directory) / ".coverage")
        pytest_output = io.StringIO()
        try:
            with contextlib.redirect_stdout(pytest_output):
                result = pytest.main(
                    [
                        "--cov",
                        "--cov-branch",
                        "--cov-config",
                        str(coverage_config),
                        "--cov-report=term-missing",
                        "-p",
                        "no:cacheprovider",
                        __file__,
                        "-q",
                    ]
                )
        finally:
            if previous_coverage_file is None:
                os.environ.pop("COVERAGE_FILE", None)
            else:
                os.environ["COVERAGE_FILE"] = previous_coverage_file
    click.echo(compact_pytest_output(pytest_output.getvalue()), nl=False)
    raise SystemExit(result)


cli.add_command(_embedded_unit_test_command)


SAMPLE_HTML = """<!doctype html>
<html>
  <head><title>Noise</title><style>.x { color: red }</style></head>
  <body>
    <main class="docs" onclick="track()">
      <nav>Documentation menu</nav>
      <article>
        <h1 id="intro">  Token   efficient docs </h1>
        <!-- editorial note -->
        <p>Read <strong>only useful</strong> content.</p>
        <p><a href="/guide?q=1">Guide</a></p>
        <p><a href="javascript:alert(1)">Unsafe</a></p>
        <img src="hero.png" alt=" A useful diagram ">
        <table class="layout"><tr><th colspan="2">Name</th></tr><tr><td>A</td><td>B</td></tr></table>
        <pre><code>if value &lt; limit:\n    keep(value)</code></pre>
        <script>ignore()</script>
      </article>
      <footer>Legal links</footer>
    </main>
  </body>
</html>"""


def test_balanced_filter_keeps_semantics_and_removes_noise() -> None:
    result = filter_html(
        SAMPLE_HTML, "https://docs.example.test/start", Profile.BALANCED
    )

    assert "Token efficient docs" in result.html
    assert "Documentation menu" not in result.html
    assert "Legal links" not in result.html
    assert "ignore()" not in result.html
    assert "editorial note" not in result.html
    assert 'href="https://docs.example.test/guide?q=1"' in result.html
    assert "javascript:" not in result.html
    assert "[Image: A useful diagram]" in result.html
    assert '<th colspan="2">' in result.html
    assert 'class="' not in result.html
    assert "if value &lt; limit:\n    keep(value)" in result.html
    assert result.elements_removed > 0
    assert result.character_reduction > 0


def test_nested_hidden_content_does_not_revisit_decomposed_nodes() -> None:
    html = (
        "<main><section hidden><div><p>secret</p></div></section><p>public</p></main>"
    )

    result = filter_html(html, "https://docs.example.test/", Profile.BALANCED)

    assert "secret" not in result.html
    assert result.html == "<p>public</p>"


def test_balanced_filter_unwraps_presentation_containers() -> None:
    result = filter_html(
        "<main><div><span>content</span></div></main>",
        "https://docs.example.test/",
        Profile.BALANCED,
    )

    assert result.html == "content"


def test_compact_filter_unwraps_links_and_tables_and_removes_images() -> None:
    result = filter_html(SAMPLE_HTML, "https://docs.example.test/", Profile.COMPACT)

    assert "Guide" in result.html
    assert "Name" in result.html
    assert "A useful diagram" not in result.html
    assert BeautifulSoup(result.html, "html.parser").find("a") is None
    assert "<table" not in result.html


def test_conservative_filter_preserves_boilerplate() -> None:
    result = filter_html(
        SAMPLE_HTML,
        "https://docs.example.test/",
        Profile.CONSERVATIVE,
    )

    assert "Documentation menu" in result.html
    assert "Legal links" in result.html
    assert "Token   efficient docs" in result.html


def test_parse_source_url_rejects_unsafe_forms() -> None:
    with pytest.raises(FilterError, match="scheme"):
        parse_source_url("file:///etc/passwd")
    with pytest.raises(FilterError, match="credentials"):
        parse_source_url("https://user:secret@example.test/docs")
    with pytest.raises(FilterError, match="hostname"):
        parse_source_url("https:///docs")


def test_non_public_addresses_require_explicit_opt_in() -> None:
    with pytest.raises(FilterError, match="non-public"):
        ensure_allowed_addresses("localhost", ("127.0.0.1",), allow_private=False)

    ensure_allowed_addresses("localhost", ("127.0.0.1",), allow_private=True)


def test_safe_link_rejects_active_or_credentialed_targets() -> None:
    assert safe_link("javascript:alert(1)", "https://example.test") is None
    assert safe_link("https://user:secret@example.test", "https://example.test") is None
    assert safe_link("../guide", "https://example.test/docs/start") == (
        "https://example.test/guide"
    )


def test_write_output_requires_force_and_preserves_content(tmp_path: Path) -> None:
    output = tmp_path / "docs.html"
    write_output(output, "<p>first</p>", force=False)
    assert output.read_text(encoding="utf-8") == "<p>first</p>\n"

    with pytest.raises(FilterError, match="already exists"):
        write_output(output, "<p>second</p>", force=False)

    write_output(output, "<p>second</p>", force=True)
    assert output.read_text(encoding="utf-8") == "<p>second</p>\n"


def fake_download_document(
    url: str,
    *,
    max_bytes: int,
    timeout_seconds: float,
    max_redirects: int,
    allow_private: bool,
    trust_environment: bool,
) -> DownloadedDocument:
    del max_bytes, timeout_seconds, max_redirects, allow_private, trust_environment
    return DownloadedDocument(SAMPLE_HTML, url, len(SAMPLE_HTML.encode()))


def test_cli_help_shows_unit_test_command() -> None:
    result = CliRunner().invoke(cli, ["--help"])

    assert result.exit_code == 0
    assert "fetch" in result.stdout
    assert "unit-test" in result.stdout


def test_fetch_command_separates_filtered_output_and_logs(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        sys.modules[__name__],
        "download_document",
        fake_download_document,
    )
    result = CliRunner().invoke(
        cli,
        ["fetch", "https://docs.example.test/start"],
    )

    assert result.exit_code == 0
    assert "Token efficient docs" in result.stdout
    assert "ignore()" not in result.stdout
    assert "document_filtered" in result.stderr


def test_fetch_command_rejects_output_over_bound(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        sys.modules[__name__],
        "download_document",
        fake_download_document,
    )
    result = CliRunner().invoke(
        cli,
        [
            "fetch",
            "https://docs.example.test/start",
            "--max-output-chars",
            "10",
        ],
    )

    assert result.exit_code == 1
    assert result.stdout == ""
    assert "exceeds --max-output-chars" in result.stderr


def test_real_entrypoint_rejects_non_http_url_without_output() -> None:
    result = sp.run(
        [sys.executable, __file__, "fetch", "file:///etc/passwd"],
        check=False,
        capture_output=True,
        text=True,
        timeout=10,
    )

    assert result.returncode == 1
    assert result.stdout == ""
    assert "URL scheme must be http or https" in result.stderr


def make_http_response(
    status_code: int | None,
    *,
    body: bytes = b"",
    headers: dict[str, str] | None = None,
    encoding: str | None = "utf-8",
) -> http.Response:
    """Build a real Niquests response around controlled in-memory content."""
    response = http.Response()
    response.status_code = status_code
    response.headers.update(headers or {})
    response.encoding = encoding
    response._content = body
    response._content_consumed = True
    return response


class StubSession:
    """Provide a deterministic Niquests session at the owned HTTP boundary."""

    def __init__(
        self,
        responses: list[http.Response | http.exceptions.RequestException],
    ) -> None:
        self.responses = responses
        self.requested_urls: list[str] = []
        self.trust_env = False

    def __enter__(self) -> "StubSession":
        return self

    def __exit__(
        self,
        exception_type: type[BaseException] | None,
        exception: BaseException | None,
        traceback: object | None,
    ) -> None:
        del exception_type, exception, traceback

    def get(
        self,
        url: str,
        *,
        allow_redirects: bool,
        headers: dict[str, str],
        stream: bool,
        timeout: tuple[float, float],
    ) -> http.Response:
        del allow_redirects, headers, stream, timeout
        self.requested_urls.append(url)
        response = self.responses.pop(0)
        if isinstance(response, http.exceptions.RequestException):
            raise response
        return response


def install_stub_session(
    monkeypatch: pytest.MonkeyPatch,
    responses: list[http.Response | http.exceptions.RequestException],
) -> StubSession:
    session = StubSession(responses)
    monkeypatch.setattr(http, "Session", lambda: session)
    monkeypatch.setattr(
        sys.modules[__name__],
        "validate_network_target",
        lambda url, *, allow_private: parse_source_url(url),
    )
    return session


def test_filter_result_handles_empty_and_expanding_content() -> None:
    empty = FilterResult("", 0, 0, 0)
    expanded = FilterResult("longer", 2, 1, 3)

    assert empty.character_reduction == 0.0
    assert expanded.character_reduction == 0.0
    assert expanded.elements_removed == 0


def test_allowed_addresses_cover_empty_public_and_private_sets() -> None:
    with pytest.raises(FilterError, match="did not resolve"):
        ensure_allowed_addresses("empty.example", (), allow_private=False)

    ensure_allowed_addresses(
        "public.example",
        ("93.184.216.34", "2606:2800:220:1:248:1893:25c8:1946"),
        allow_private=False,
    )


@pytest.mark.parametrize(
    ("url", "expected_port"),
    [
        ("https://docs.example/path", 443),
        ("http://docs.example:8080/path", 8080),
    ],
)
def test_validate_network_target_resolves_and_filters_addresses(
    monkeypatch: pytest.MonkeyPatch,
    url: str,
    expected_port: int,
) -> None:
    calls: list[tuple[str, int]] = []

    def fake_getaddrinfo(
        hostname: str,
        port: int,
        *,
        type: socket.SocketKind,
    ) -> list[tuple[int, int, int, str, tuple[str | int, int]]]:
        assert type == socket.SOCK_STREAM
        calls.append((hostname, port))
        return [
            (socket.AF_INET, socket.SOCK_STREAM, 6, "", ("93.184.216.34", port)),
            (socket.AF_INET, socket.SOCK_STREAM, 6, "", (123, port)),
        ]

    monkeypatch.setattr(socket, "getaddrinfo", fake_getaddrinfo)

    parsed = validate_network_target(url, allow_private=False)

    assert parsed.hostname == "docs.example"
    assert calls == [("docs.example", expected_port)]


def test_validate_network_target_translates_dns_failure(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    def failing_getaddrinfo(
        hostname: str,
        port: int,
        *,
        type: socket.SocketKind,
    ) -> list[tuple[int, int, int, str, tuple[str, int]]]:
        del hostname, port, type
        raise socket.gaierror("not found")

    monkeypatch.setattr(socket, "getaddrinfo", failing_getaddrinfo)

    with pytest.raises(FilterError, match="hostname lookup failed"):
        validate_network_target("https://missing.example/docs", allow_private=False)


def test_validate_network_target_defends_against_missing_hostname_after_parse(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        sys.modules[__name__],
        "parse_source_url",
        lambda url: SplitResult("https", "", url, "", ""),
    )

    with pytest.raises(FilterError, match="include a hostname"):
        validate_network_target("/docs", allow_private=False)


def test_display_url_removes_query_and_fragment() -> None:
    assert display_url("https://docs.example/path?token=secret#part") == (
        "https://docs.example/path"
    )


def test_read_limited_body_accepts_bounded_chunks_and_skips_empty_chunk(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    response = make_http_response(200, headers={"content-length": "2"})
    monkeypatch.setattr(
        response,
        "iter_content",
        lambda chunk_size: iter((b"a", b"", b"b")),
    )

    assert read_limited_body(response, 2) == b"ab"


@pytest.mark.parametrize(
    ("headers", "body", "message"),
    [
        ({"content-length": "invalid"}, b"", "invalid Content-Length"),
        ({"content-length": "3"}, b"abc", "exceeds --max-bytes"),
        ({}, b"abc", "exceeds --max-bytes"),
    ],
)
def test_read_limited_body_rejects_invalid_or_oversized_responses(
    headers: dict[str, str],
    body: bytes,
    message: str,
) -> None:
    response = make_http_response(200, body=body, headers=headers)

    with pytest.raises(FilterError, match=message):
        read_limited_body(response, 2)


def test_decode_body_uses_declared_default_and_fallback_encodings() -> None:
    assert decode_body("café".encode("latin-1"), "latin-1") == "café"
    assert decode_body(b"plain", None) == "plain"
    assert decode_body(b"plain", "not-an-encoding") == "plain"


def test_download_document_follows_validated_redirect_and_returns_html(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    session = install_stub_session(
        monkeypatch,
        [
            make_http_response(302, headers={"location": "/guide"}),
            make_http_response(
                200,
                body=b"<main>guide</main>",
                headers={"content-type": "text/html; charset=utf-8"},
            ),
        ],
    )

    document = download_document(
        "https://docs.example/start",
        max_bytes=1_000,
        timeout_seconds=1.5,
        max_redirects=2,
        allow_private=False,
        trust_environment=True,
    )

    assert document == DownloadedDocument(
        "<main>guide</main>",
        "https://docs.example/guide",
        18,
    )
    assert session.requested_urls == [
        "https://docs.example/start",
        "https://docs.example/guide",
    ]
    assert session.trust_env is True


@pytest.mark.parametrize(
    ("response", "max_redirects", "message"),
    [
        (make_http_response(None), 1, "no HTTP status"),
        (make_http_response(302), 1, "omitted Location"),
        (
            make_http_response(302, headers={"location": "/again"}),
            0,
            "redirect limit exceeded",
        ),
        (make_http_response(404), 1, "HTTP 404"),
        (
            make_http_response(200, headers={"content-type": "application/json"}),
            1,
            "expected HTML",
        ),
    ],
)
def test_download_document_rejects_invalid_http_responses(
    monkeypatch: pytest.MonkeyPatch,
    response: http.Response,
    max_redirects: int,
    message: str,
) -> None:
    install_stub_session(monkeypatch, [response])

    with pytest.raises(FilterError, match=message):
        download_document(
            "https://docs.example/start",
            max_bytes=100,
            timeout_seconds=1.0,
            max_redirects=max_redirects,
            allow_private=False,
            trust_environment=False,
        )


def test_download_document_redacts_request_failures(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    install_stub_session(
        monkeypatch,
        [http.exceptions.ConnectionError("https://docs.example/?token=secret")],
    )

    with pytest.raises(FilterError) as captured:
        download_document(
            "https://docs.example/start?token=secret",
            max_bytes=100,
            timeout_seconds=1.0,
            max_redirects=1,
            allow_private=False,
            trust_environment=False,
        )

    assert "ConnectionError" in str(captured.value)
    assert "secret" not in str(captured.value)


def test_download_document_accepts_missing_content_type(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    install_stub_session(monkeypatch, [make_http_response(200, body=b"<p>ok</p>")])

    document = download_document(
        "https://docs.example/start",
        max_bytes=100,
        timeout_seconds=1.0,
        max_redirects=1,
        allow_private=False,
        trust_environment=False,
    )

    assert document.html == "<p>ok</p>"


def test_download_document_rejects_negative_redirect_bound(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    install_stub_session(monkeypatch, [])

    with pytest.raises(FilterError, match="ended unexpectedly"):
        download_document(
            "https://docs.example/start",
            max_bytes=100,
            timeout_seconds=1.0,
            max_redirects=-1,
            allow_private=False,
            trust_environment=False,
        )


def test_select_content_prefers_largest_substantial_article_then_body() -> None:
    article_soup = BeautifulSoup(
        f'<article id="short">{"a" * 200}</article>'
        f'<article id="long">{"b" * 250}</article>',
        "html.parser",
    )
    body_soup = BeautifulSoup("<html><body><p>body</p></body></html>", "html.parser")
    fragment_soup = BeautifulSoup("<p>fragment</p>", "html.parser")

    assert attribute_text(select_content(article_soup), "id") == "long"
    assert select_content(body_soup) is body_soup.body
    assert select_content(fragment_soup) is fragment_soup


def test_attribute_text_and_safe_link_cover_non_scalar_and_local_targets() -> None:
    soup = BeautifulSoup('<p class="one two">text</p>', "html.parser")
    paragraph = soup.find("p")
    assert isinstance(paragraph, Tag)

    assert attribute_text(paragraph, "class") is None
    assert safe_link("", "https://docs.example/") == ""
    assert safe_link("#part", "https://docs.example/") == "#part"
    assert safe_link("mailto:docs@example.test", "https://docs.example/") == (
        "mailto:docs@example.test"
    )


def test_remove_unwanted_content_handles_nested_dead_nodes_and_roles() -> None:
    root = BeautifulSoup(
        """
        <object><script>nested script</script></object>
        <nav><form>nested boilerplate</form></nav>
        <section role="navigation"><div role="navigation">nested role</div></section>
        <section aria-hidden="true"><p>hidden</p></section>
        <p>kept</p>
        """,
        "html.parser",
    )

    remove_unwanted_content(root, PROFILES[Profile.BALANCED])

    assert root.get_text(" ", strip=True) == "kept"


def test_conservative_removal_keeps_nav_but_removes_controls_and_comments() -> None:
    root = BeautifulSoup(
        "<nav>kept</nav><select><option>removed</option></select><!--comment-->",
        "html.parser",
    )

    remove_unwanted_content(root, PROFILES[Profile.CONSERVATIVE])

    assert root.get_text(" ", strip=True) == "kept"
    assert "comment" not in str(root)


def test_filter_preserves_supported_structural_attributes() -> None:
    html = """
    <main><article data-extra="kept only conservatively">
      <ol start="3"><li value="4">item</li></ol>
      <code data-language="python">pass</code>
      <time datetime="2026-07-17">today</time>
      <table><tr><td rowspan="2">cell</td></tr></table>
      <a>no href</a>
    </article></main>
    """

    balanced = filter_html(html, "https://docs.example/", Profile.BALANCED)
    conservative = filter_html(html, "https://docs.example/", Profile.CONSERVATIVE)

    assert 'start="3"' in balanced.html
    assert 'value="4"' in balanced.html
    assert 'data-language="python"' in balanced.html
    assert 'datetime="2026-07-17"' in balanced.html
    assert 'rowspan="2"' in balanced.html
    assert "data-extra" not in balanced.html
    assert 'data-extra="kept only conservatively"' in conservative.html


def test_clean_attributes_rejects_non_scalar_href() -> None:
    soup = BeautifulSoup("<a>link</a>", "html.parser")
    anchor = soup.find("a")
    assert isinstance(anchor, Tag)
    anchor.attrs["href"] = anchor.get_attribute_list("href")

    clean_attributes(anchor, PROFILES[Profile.BALANCED], "https://docs.example/")

    assert not anchor.has_attr("href")


def test_collapse_whitespace_skips_comments_and_preserves_preformatted_text() -> None:
    root = BeautifulSoup(
        "<!--comment--><p> alpha <strong> beta </strong> gamma </p>"
        "<pre> x  y </pre><hr>",
        "html.parser",
    )

    collapse_text_whitespace(root)

    assert "comment" in str(root)
    assert "<p>alpha <strong>beta</strong> gamma</p>" in str(root)
    assert "<pre> x  y </pre>" in str(root)


def test_remove_empty_elements_reaches_fixed_point_and_keeps_void_elements() -> None:
    root = BeautifulSoup(
        "<section><div><span></span></div></section><br><hr><p>kept</p>",
        "html.parser",
    )

    remove_empty_elements(root)

    assert root.decode_contents() == "<br/><hr/><p>kept</p>"


def test_write_output_rejects_missing_directory(tmp_path: Path) -> None:
    with pytest.raises(FilterError, match="directory does not exist"):
        write_output(tmp_path / "missing" / "docs.html", "content", force=False)


def test_write_output_cleans_temporary_file_after_replace_failure(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    output = tmp_path / "docs.html"

    def failing_replace(source: Path, target: Path) -> Path:
        del source, target
        raise OSError("disk failure")

    monkeypatch.setattr(Path, "replace", failing_replace)

    with pytest.raises(FilterError, match="could not write"):
        write_output(output, "content", force=False)

    assert list(tmp_path.iterdir()) == []


def fake_empty_download_document(
    url: str,
    *,
    max_bytes: int,
    timeout_seconds: float,
    max_redirects: int,
    allow_private: bool,
    trust_environment: bool,
) -> DownloadedDocument:
    del max_bytes, timeout_seconds, max_redirects, allow_private, trust_environment
    return DownloadedDocument("<script>removed</script>", url, 24)


def test_fetch_command_rejects_fully_filtered_page(
    monkeypatch: pytest.MonkeyPatch,
) -> None:
    monkeypatch.setattr(
        sys.modules[__name__],
        "download_document",
        fake_empty_download_document,
    )

    result = CliRunner().invoke(cli, ["fetch", "https://docs.example/start"])

    assert result.exit_code == 1
    assert "filter removed all content" in result.stderr


def test_fetch_command_stores_filtered_output(
    monkeypatch: pytest.MonkeyPatch,
    tmp_path: Path,
) -> None:
    monkeypatch.setattr(
        sys.modules[__name__],
        "download_document",
        fake_download_document,
    )
    output = tmp_path / "filtered.html"

    result = CliRunner().invoke(
        cli,
        [
            "fetch",
            "https://docs.example/start",
            "--output",
            str(output),
        ],
    )

    assert result.exit_code == 0
    assert result.stdout == f"{output}\n"
    assert "Token efficient docs" in output.read_text(encoding="utf-8")
    assert "stored=True" in result.stderr


@pytest.mark.parametrize("previous_coverage_file", [None, "/tmp/existing-coverage"])
def test_unit_test_command_compacts_output_and_restores_environment(
    monkeypatch: pytest.MonkeyPatch,
    previous_coverage_file: str | None,
) -> None:
    if previous_coverage_file is None:
        monkeypatch.delenv("COVERAGE_FILE", raising=False)
    else:
        monkeypatch.setenv("COVERAGE_FILE", previous_coverage_file)

    def fake_pytest_main(arguments: list[str]) -> int:
        assert "--cov-branch" in arguments
        print("==== tests coverage ====")
        print("____ coverage: platform test ____")
        print("kept summary")
        return 0

    monkeypatch.setattr(pytest, "main", fake_pytest_main)

    result = CliRunner().invoke(cli, ["unit-test"])

    assert result.exit_code == 0
    assert result.stdout == "kept summary\n"
    if previous_coverage_file is None:
        assert "COVERAGE_FILE" not in os.environ
    else:
        assert os.environ["COVERAGE_FILE"] == previous_coverage_file


if __name__ == "__main__":
    cli()

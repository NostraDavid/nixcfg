# Python skill scripts parity audit

Baseline: Git commit `4c7c1ea281425656bcfce20288f7cc2711ad647f`  
Additional upstream baseline: `mattpocock/skills` commit
`9603c1cc8118d08bc1b3bf34cf714f62178dea3b`

Scope: all Python files under `dotfiles/agents/.agents/skills`  
Method: isolated black-box differential tests, normalized document comparison,
and injected network/subprocess adapters.

## Result

No unintended functional regressions were found in the tested contracts. The
rewrites preserve the old scripts' intended capabilities while deliberately
changing their CLI shape, safety controls, logging, and execution model.

| Script                                                             | Compared contract                                                                     | Result                                             |
| ------------------------------------------------------------------ | ------------------------------------------------------------------------------------- | -------------------------------------------------- |
| `acquire-codebase-knowledge/scripts/scan.py`                       | Fifteen report sections and their complete contents on a representative project       | Exact match                                        |
| `draw-io-diagram-generator/scripts/add-shape.py`                   | Inserted cell attributes, style, parent, and geometry                                 | Match after generated ID normalization             |
| `draw-io-diagram-generator/scripts/validate-drawio.py`             | Valid and invalid XML decisions                                                       | Exact match                                        |
| `diagnosing-bugs/scripts/hitl_loop.py`                             | Ordered HITL steps/captures and `KEY=VALUE` result output                             | Match, with validated TOML replacing source edits  |
| `excalidraw-diagram-generator/scripts/add-arrow.py`                | Arrow and label payload                                                               | Match after generated identity normalization       |
| `excalidraw-diagram-generator/scripts/add-icon-to-diagram.py`      | Transformed icon, label, bindings, and preserved diagram metadata                     | Match after generated identity normalization       |
| `excalidraw-diagram-generator/scripts/split-excalidraw-library.py` | Icon filenames, decoded JSON, sorting, and reference rows                             | Semantic match                                     |
| `imagegen/scripts/image_gen.py`                                    | Generate/edit dry-run API payloads and input validation                               | Exact semantic match                               |
| `imagegen/scripts/remove_chroma_key.py`                            | Hard-key and soft-matte/despill RGBA pixels                                           | Exact match                                        |
| `plugin-creator/scripts/create_basic_plugin.py`                    | Complete optional tree, manifest, companion files, and marketplace entry              | Exact semantic match                               |
| `plugin-creator/scripts/read_marketplace_name.py`                  | Name output and malformed-object failure                                              | Exact match                                        |
| `plugin-creator/scripts/update_plugin_cachebuster.py`              | Version rewrite and preservation of unrelated manifest data                           | Exact semantic match                               |
| `plugin-creator/scripts/validate_plugin.py`                        | Generated valid plugin and unknown-field rejection                                    | Exact decision match                               |
| `skill-creator/scripts/generate_openai_yaml.py`                    | Parsed YAML data                                                                      | Semantic match                                     |
| `skill-creator/scripts/init_skill.py`                              | Normalized name, resource tree, skill metadata, and UI metadata                       | Match, except documented example change            |
| `skill-creator/scripts/quick_validate.py`                          | Representative valid and invalid skill decisions                                      | Exact match                                        |
| `skill-installer/scripts/github_utils.py`                          | GitHub contents URL and response-body contract                                        | Match, with documented HTTP hardening              |
| `skill-installer/scripts/install-skill-from-github.py`             | URL parsing, source resolution, relative-path validation, and ZIP traversal rejection | Match or stricter                                  |
| `skill-installer/scripts/list-skills.py`                           | API directory filtering, sorting, installed annotations, text, and JSON rendering     | Exact semantic match                               |
| `python-script-builder/scripts/scaffold.py`                        | Generated source and executable mode                                                  | Exact match                                        |
| `python-script-builder/scripts/validate_script.py`                 | Acceptance of a valid generated script                                                | Match, with intentional executable-bit requirement |

## Intentional differences

- Every standalone CLI now uses a Click group and explicit task subcommand.
- The `diagnosing-bugs` HITL helper now reads a validated TOML plan instead of
  requiring an agent to copy and edit a Bash template; `--dry-run` previews the
  complete interaction without prompting.
- Mutating commands add confirmation, `--yes`, dry-run behavior where useful,
  and atomic or rollback-safe writes.
- Operational diagnostics moved to structured stderr logging; normal results
  remain on stdout.
- Every Python file is directly executable through its uv shebang.
- `generate_openai_yaml.py` emits equivalent YAML without unnecessary scalar
  quotes.
- `split-excalidraw-library.py` uses a different Markdown table-separator style;
  filenames and data rows are unchanged.
- `init_skill.py --examples --resources scripts,...` now creates
  `scripts/README.md` instead of a nonfunctional `scripts/example.py`
  placeholder.
- `github_utils.py` uses Niquests with a timeout and a Bearer authorization
  scheme instead of `urllib`; GitHub accepts both token representations.
- The installer additionally rejects backslash traversal, empty/dot path
  segments, missing HTTP response metadata, and ZIP symbolic links.
- The validator now rejects non-executable scripts and invokes quality checks
  through the script shebang instead of wrapping them in `uv run`.

## Boundaries

- No paid OpenAI Image API request was made. Equivalence was verified through
  generated request payloads, validation behavior, and local image processing.
- No live GitHub repository was downloaded or installed. Network responses,
  archive contents, Git commands, and destination trees were controlled or
  mocked; the existing inline tests cover download fallback and rollback paths.
- Random element IDs, UUIDs, timestamps, formatting-only YAML quotes, and
  Markdown separator syntax were normalized before comparison.

## Permanent regression coverage

The rewritten scripts already contain inline tests for their functional cores,
CLI boundaries, error translation, dry-run behavior, atomic writes, rollback,
and output separation. This audit additionally freezes:

- the legacy fifteen-section scan-report contract; and
- the legacy Image API edit dry-run payload contract.

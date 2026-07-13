# Personal AI governance baseline

| Field | Value |
| --- | --- |
| Owner | David |
| Scope | Purely personal, non-professional AI use |
| Status | Voluntary preventive baseline; not a compliance claim |
| Last reviewed | 2026-07-13 |
| Review due | `on-change` |

## Scope assessment

Article 2(10) of the EU AI Act excludes deployer obligations for a natural
person using AI in a purely personal, non-professional activity. This assessment
therefore assumes no professional work, customer work, revenue-generating use,
operation on behalf of another person, or provision of an AI system under the
owner's name.

The current intended uses are coding assistance, research, documentation, and
personal system administration. No high-risk use, public-facing AI service, or
provider role is intended. A scope change invalidates this assessment and
requires review before relying on it.

AI literacy obligations have applied to professional providers and deployers
since 2 February 2025. Article 50 transparency obligations apply from 2 August
2026. The personal publication policy in this repository is voluntary and
deliberately broader than Article 50.

## AI system inventory

`Unknown` means that the provider, model, or destination is selected at runtime
and cannot be established from the tracked configuration. It is not an
assumption that processing is local.

| System | Status and purpose | Provider/model | Data flow | Role and intended risk |
| --- | --- | --- | --- | --- |
| Codex and Codex Desktop | Installed and configured coding agents | OpenAI; `gpt-5.6-sol` | Prompts, code, and tool results to an external service | Personal user; no intended high-risk use |
| Claude | Global client configuration present; coding and general assistance | Anthropic; model unknown | Potential external processing; runtime details unknown | Personal user; no intended high-risk use |
| GitHub Copilot CLI | Installed coding agent | GitHub; model unknown | Prompts, code, and tool results to an external service | Personal user; no intended high-risk use |
| Pi | Enabled coding agent | TensorX; `deepseek/deepseek-v4-flash` | Prompts, code, and tool results to an external endpoint | Personal user; no intended high-risk use |
| Gemini CLI | Installed general and coding agent using personal OAuth | Google; model unknown | Prompts, code, and tool results to an external service | Personal user; no intended high-risk use |
| OpenCode | Installed provider-agnostic coding agent | Provider and model unknown | Local or external destination selected at runtime | Personal user; no intended high-risk use |
| Hermes Agent and Desktop | Installed provider-agnostic autonomous agent and desktop client | Provider and model unknown | Local tools; inference destination selected at runtime | Personal user; no intended high-risk use |
| CodeAlmanac | Installed AI-maintained local codebase wiki | Claude Agent SDK; model unknown | Local repository data may be sent to the configured inference service | Personal user; no intended high-risk use |
| Semble | Installed semantic code-search support | Local Model2Vec embeddings | Repository content is embedded and searched locally after model retrieval | Supporting component; no consequential decisions |
| Stable Diffusion CPP | Installed local image-generation runtime | Local runtime; model unknown | Prompts and generated images remain local unless separately published | Personal user; no intended high-risk use; publication labels apply |

Skillkit, Context7, RTK, and Snip support agent workflows but are not recorded
as independent inference systems in this inventory. Reclassify them if their
behaviour changes materially.

## Controls

| Risk | Preventive control | Evidence |
| --- | --- | --- |
| Potential prohibited or high-risk use | Name the possible category, explain the trigger, and require explicit confirmation before the risky part | Shared `eu-ai-act.md` rule and client mappings |
| Consequential or external action | Human review before publication, third-party contact, irreversible action, or a decision affecting another person | Shared rule and normal approval flow |
| Sensitive or non-public input | Warn before cloud transfer; prefer redaction, pseudonymisation, synthetic data, or local processing; require confirmation if transfer remains necessary | Shared rule; no prompt logging |
| Public AI-generated prose or media | Use a prominent `AI-generated`/`AI-gegenereerd` or `AI-assisted`/`AI-ondersteund` label and preserve provenance marks | Shared rule and publication review |
| Software-development artefacts | Source code, commits, pull requests, and releases are excluded from the voluntary publication label | Explicit rule exception |
| Governance drift | Review on tool, model, provider, destination, purpose, role, or relevant legal change | Inventory and append-only review log |

The controls do not authorise conduct prohibited by other law or platform
policy. No prompts, secrets, personal data, or per-use activity logs are kept as
compliance evidence.

## Review triggers

Review this document and the shared rule when:

- an AI tool, model, provider, data destination, or material configuration is
  added, removed, or changed;
- use becomes professional, customer-facing, revenue-generating, or is carried
  out on behalf of another person;
- an AI system is offered under the owner's name or is considered for a
  prohibited or high-risk area;
- final Article 50 guidelines are published; or
- the Digital Omnibus on AI or another relevant legal instrument enters into
  force.

## Review log

Append new entries; do not rewrite previous assessments.

| Date | Trigger | Outcome |
| --- | --- | --- |
| 2026-07-13 | Initial preventive implementation before 2 August 2026 | Personal-use exclusion recorded; inventory and controls established. The final transparency code and its adequacy assessment are included. Final Article 50 guidelines and a final Digital Omnibus amending regulation were not found and remain review triggers. |

## Official sources

- [Regulation (EU) 2024/1689](https://eur-lex.europa.eu/eli/reg/2024/1689/oj)
- [Article 2: scope and personal-use exclusion](https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-2)
- [AI literacy questions and answers](https://digital-strategy.ec.europa.eu/en/faqs/ai-literacy-questions-answers)
- [Article 50: transparency obligations](https://ai-act-service-desk.ec.europa.eu/en/ai-act/article-50)
- [Final Code of Practice on Transparency of AI-Generated Content](https://digital-strategy.ec.europa.eu/en/policies/code-practice-ai-generated-content)
- [Commission opinion on the code's adequacy](https://digital-strategy.ec.europa.eu/en/library/commission-opinion-assessment-code-practice-transparency-ai-generated-content)
- [Draft Article 50 guidelines](https://digital-strategy.ec.europa.eu/en/library/draft-guidelines-implementation-transparency-obligations-certain-ai-systems-under-article-50-ai-act)
- [Digital Omnibus on AI proposal](https://eur-lex.europa.eu/legal-content/EN/TXT/?uri=CELEX:52025PC0836)

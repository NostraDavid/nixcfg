---
name: create-pull-request
description: "Prepare pull requests using the target repository's applicable template. Exclude PR reviews and general PR questions."
---

# Pull requests

When the user asks to prepare, open, or create a PR:

1. Search the repository, including hidden directories, for filenames containing
   `PULL_REQUEST_TEMPLATE`, case-insensitively. Check locations such as
   `.azuredevops/`, `.github/`, `docs/`, and the repository root.
2. If a template applies, use its full contents as the PR `Description`. Keep
   its headings, order, and checklist items. Fill sections with facts from the
   changes, repository context, and verification results. Leave checkboxes
   unchecked unless the change or verification proves them complete.
3. If multiple templates apply, choose the one for the target PR platform. Ask
   the user only when the target or choice remains unclear.
4. If no template exists, continue the existing PR workflow using repository
   conventions and the user's instructions.

Follow the repository's and PR platform's existing workflow for the remaining
PR details.

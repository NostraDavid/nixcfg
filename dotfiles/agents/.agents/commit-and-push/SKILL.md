---
name: push
description: "Use when the user asks for a Git push, including 'push', 'commit en push', or 'commit and push'. Commit scoped changes if needed, update or open the PR and fix CI until the pushed revision passes."
---

# Commit en push

Use this workflow for a request to publish Git commits. A question about pushing,
a request for commit messages, or a commit-only request stays local. Honor explicit
limits such as “alleen pushen, geen PR”.

## Publish the branch

1. Inspect the branch, upstream, outgoing commits, index and working tree. Identify
   the intended changes, push remote, review host and target branch from the
   request and repository. An existing PR may target a release branch. Use the
   configured Git push destinations and the canonical review host unless the
   user specifies another. Clarify only if the intended target is ambiguous.
2. If you are on the PR target branch, create a topic branch **before pushing**
   so the target can receive the PR. Preserve existing commits and local edits.
   For an explicit direct push to the target, respect that destination and
   monitor the push build. If the remote already contains all the work, look for
   its existing PR or build.
3. Commit only outstanding changes that belong to the request. Inspect the staged
   diff, follow the repository's commit and hook rules, and preserve unrelated
   staged and unstaged work. Push existing commits as they are when they already
   contain the requested changes. Check the full outgoing range before a normal,
   fast-forward push. Resolve any conflict with the user's scope before publishing.
   Verify the remote source branch points to the intended SHA at each destination.

## Keep one PR current

Use the review host's authenticated CLI or API. Find an open PR by base repository
and branch, source repository (including fork owner) and branch. Update that PR,
or create one when the branch has a diff and none is open. After an uncertain
create result, look it up again before retrying.

Use the `create-pull-request` skill for the repository's PR template. Describe
the whole PR diff against its actual base, why it matters and what was tested.
Read the current description before editing. Preserve reviewer notes, issue
links and checklists while updating the affected sections. Use a structured body
or a body file. Refresh the description after each repair push and when the final
verification changes the result.

## Follow CI through completion

- Discover the builds and checks expected for this PR or direct push. Track the
  pushed SHA, including a provider's test merge commit when it corresponds to
  that head. Allow for check registration and queued jobs. Poll or watch the
  runs and give progress updates during long builds.
- On failure, read the failing job's log, diagnose the cause and run the relevant
  test locally when possible. Commit an in-scope repair to the same branch,
  push it, refresh the PR and follow the new revision. Retry a transient
  infrastructure failure when the evidence supports a rerun. If the same failure
  recurs, investigate it before another push or retry. Preserve the tests,
  branch protections and CI requirements.
- Finish when the expected applicable checks pass for the latest published
  revision. Verify the remote head again. An empty check list, a cancelled job
  or a successful older run cannot establish that result. If no CI is configured,
  report the local checks and the absence of a remote build. If access, a required
  approval or a failure outside the task prevents progress, report the blocker,
  the run link when available and the action needed to continue.

Report the final SHA, push destinations, PR URL and build result with its link.
Merging the PR requires a separate request.

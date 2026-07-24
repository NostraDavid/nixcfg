# Batch Instructions

In Code Mode, within each bounded stage, run independent tool calls available
through `functions.exec` concurrently in a single `functions.exec` call. Use
`await Promise.allSettled([...])` when partial results are useful, and inspect
every result. Use `await Promise.all([...])` when the aggregate should fail if
any call fails; note that already-started calls are not cancelled.

Keep dependencies, waits and resumes, approvals, conflicting or interdependent
mutations, and adaptive investigations—where each result may change the next
step—sequential. Limit concurrency for resource-intensive calls. Do not split
otherwise batchable inspections across outer tool calls.

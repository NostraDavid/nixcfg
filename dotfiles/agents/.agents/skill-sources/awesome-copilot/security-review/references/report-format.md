# Security review report

Lead with actionable findings. Do not begin with a generic summary table when no finding exists.

For each finding:

1. **Severity — concise title**
2. **Location:** file and line/symbol/configuration.
3. **Violated invariant:** the security property that should hold.
4. **Preconditions and path:** attacker access, controlled source/state, transformations, missing/insufficient guard, and security-relevant operation.
5. **Impact and scope:** concrete capability and affected assets/tenants/users.
6. **Evidence:** code/config facts and safe reproduction when performed.
7. **Minimal remediation direction:** preserve compatibility; do not silently patch during review.
8. **Verification:** negative/positive tests and operational checks.
9. **Confidence and uncertainty:** high/medium/low with what would change the conclusion.

After findings, state reviewed scope, techniques/tools and their results, assumptions, excluded/generated/vendor paths, and residual blind spots. If no validated findings remain, say so without claiming the system is secure.

---
name: c7
description: Retrieve library documentation with Context7 when implementing or checking an external library API, configuration option, or version-specific behavior.
---

# Context7

Find the library ID for the task, then query its documentation:

```bash
ctx7 library "$POTENTIAL_LIB_NAME" "$TASK_OR_QUESTION"
ctx7 docs "$CONTEXT7_LIBRARY_ID" "$TASK_OR_QUESTION"
```

For example:

```bash
ctx7 library "sqlalchemy" "SQLAlchemy 2.0 async session"
ctx7 docs "/sqlalchemy/sqlalchemy" "async session transaction handling"
```

Use `ctx7 library "$POTENTIAL_LIB_NAME"` without a task for a general lookup.
Add `--json` to either command when parsing its output.

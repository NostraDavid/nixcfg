# Context7

Use Context7 to retrieve up-to-date library documentation.

```bash
# Find the specific Context7 library ID.
ctx7 library "$POTENTIAL_LIB_NAME"

# Find the library ID, ranked for a specific task or question.
ctx7 library "$POTENTIAL_LIB_NAME" "$TASK_OR_QUESTION"

# Query documentation for a concept, task, or API.
ctx7 docs "$CONTEXT7_LIBRARY_ID" "$TASK_OR_QUESTION"
```

Examples:

```bash
ctx7 library "sqlalchemy" "SQLAlchemy 2.0 async session"
ctx7 docs "/sqlalchemy/sqlalchemy" "async session transaction handling"

ctx7 library "polars" "lazy group by aggregation"
ctx7 docs "/pola-rs/polars" "lazy group by aggregation"

# Use --json when the output needs to be parsed by tooling:
ctx7 library "sqlalchemy" "async session" --json
ctx7 docs "/sqlalchemy/sqlalchemy" "async session" --json
```

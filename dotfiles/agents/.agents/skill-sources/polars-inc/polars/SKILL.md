---
name: polars
description: Write, debug, review, optimize, or migrate Python Polars code and analyze tabular data with Polars DataFrames, LazyFrames, expressions, and query plans. Use when the user explicitly names Polars, supplies Polars code, or asks for Python tabular work where Polars fits the repository and constraints. Do not replace a requested pandas, DuckDB, Spark, or other implementation unless migration is requested. Not for Polars Cloud, On-Prem, distributed, or GPU workloads.
---

# Polars

Build correct, idiomatic Polars pipelines, then optimize only where the workload
and measurements justify it.

## Workflow

1. Inspect the repository, installed Polars version, input format, and existing
   conventions. Preserve the user's chosen library and observable output
   contract.
2. For unfamiliar inputs, inspect the schema without reading the full dataset:
   use `collect_schema()` on a LazyFrame and a bounded `head().collect()` when
   values or data quality matter. Never guess names or dtypes.
3. Make the analytical contract explicit: grain, filters, time boundaries, null
   handling, denominators, grouping keys, and expected ordering.
4. Choose execution style deliberately:
   - Prefer lazy scans for file-backed, multi-step, or potentially large work.
   - Eager DataFrames are reasonable for exploration, small intermediate
     results, or APIs that require materialization.
5. Compose native expressions. Put semantically safe filters near the source,
   batch independent expressions in one context, and use sequential
   `with_columns()` calls when a derived column depends on another new column.
6. Before expensive execution, validate the final lazy schema and inspect
   `explain()` when plan shape matters. Materialize once per required output;
   use `collect_all` for independent outputs sharing inputs and sinks or
   streaming when memory pressure requires them.
7. Verify the result: shape, schema, nulls, uniqueness, join cardinality,
   ordering, and representative totals or denominators. Run relevant tests.
8. Report the result, important assumptions, the query or code, and the checks
   performed.

## Core rules

- Prefer Polars expressions over Python row UDFs. Use `map_elements`,
  `map_batches`, or `map_groups` only as a documented last resort when no native
  expression implements the required behavior.
- Do not move a filter across a join, window expression, aggregation, or
  derived-column boundary unless semantics remain unchanged. Let the optimizer
  perform safe predicate and projection pushdown.
- Expressions in one context run independently and cannot refer to aliases
  created by siblings in that same context. Split dependent derivations into
  sequential contexts.
- Polars is typed. Inspect schemas and cast explicitly; if using `strict=False`,
  count and explain values converted to null.
- Ordering is not implicit. Sort explicitly when output order, top-k tie
  handling, `first`/`last`, or reproducibility matters.
- Check join-key uniqueness and expected row counts before and after joins.
  Choose `nulls_equal=True` only when null keys are intended to match.
- Do not claim a performance improvement without comparing equivalent outputs
  and measuring the relevant workload.
- Do not install Polars, `polars-mcp`, or other dependencies without
  authorization. Use the project's existing runner and dependency management.

## Minimal patterns

```python
lf = pl.scan_csv("sales.csv", try_parse_dates=True)
schema = lf.collect_schema()
sample = lf.head(10).collect()

result = (
    lf.filter(pl.col("date") >= start)
    .group_by("region")
    .agg(pl.col("revenue").sum().alias("revenue"))
    .sort(["revenue", "region"], descending=[True, False])
    .collect()
)
```

For an in-memory frame, begin with `df.lazy()` when whole-plan optimization is
useful, or keep it eager when the task is genuinely small and exploratory.

## API verification

Confirm unfamiliar APIs against the installed version:

1. Use an already configured `polars-mcp` integration if available.
2. Inspect the project environment, for example with its existing Python runner.
3. Consult the live Polars documentation at <https://docs.pola.rs/>.

Do not assume pandas method names or remembered signatures transfer to Polars.

## Reference routing

Read only the references needed for the task:

- Natural-language analysis and reusable query shapes:
  `references/insight-recipes.md`
- pandas-to-Polars migration and compatibility traps:
  `references/pandas-to-polars.md`
- Context behavior, windows, joins, and dependent expressions:
  `references/contexts.md`
- Expression namespaces, casting, selectors, and null handling:
  `references/expressions.md`
- Scans, plans, streaming, multiple outputs, and sinks: `references/lazy-api.md`

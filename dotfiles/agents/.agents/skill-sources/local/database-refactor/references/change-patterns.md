# Evolutionary database change patterns

## Contents

- Rename or move
- Split or merge
- Type and constraint changes
- Index changes
- Backfills
- Contract and recovery

## Rename or move

Introduce the target object first. Keep the old contract available through compatible application logic, a view, a trigger, or another engine-appropriate synchronization mechanism. Choose the mechanism from write ownership, transactionality, load, and failure behavior; triggers are not a universal default. Backfill, compare both representations, move consumers, then remove compatibility code.

## Split or merge

Create the target tables and integrity rules before moving data. Define authoritative write ownership during the transition. Backfill stable keys first, reconcile counts and domain invariants, then move reads. For merges, define collision and null semantics before copying data.

## Type and constraint changes

Determine whether the engine rewrites the table or takes a strong lock. Find invalid existing rows before adding or validating a constraint. When direct conversion is unsafe, add a new column, dual-write or derive it, backfill, validate equivalence, switch reads, and later remove the old column.

## Index changes

Start with the workload and execution plans. Estimate build time, temporary disk, write amplification, replication effects, and lock behavior. Use the engine's online or concurrent facility only after checking its transaction restrictions and failure cleanup. Verify that the new index is valid and used before removing an old one.

## Backfills

- Select rows by a stable, resumable key.
- Use bounded batches and short transactions.
- Record progress without making one process instance the sole source of truth.
- Throttle against database load and replication lag.
- Make repeated execution converge on the same result.
- Validate row counts plus semantic invariants, not counts alone.

## Contract and recovery

Prove that old code, jobs, dashboards, and integrations have stopped using deprecated schema. Take required backups or recovery checkpoints before irreversible steps. Prefer a tested forward fix after the contract phase; a syntactic down migration cannot recreate discarded information.

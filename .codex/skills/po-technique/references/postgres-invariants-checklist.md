# PostgreSQL Invariants Checklist

Use this checklist whenever a request touches schema, lifecycle, booking conflicts, or integrity rules.

## Truth source
- Start from `db/structure.sql`.
- Use `db/schema.rb` only as a secondary summary.

## Checkpoints
- Does the change affect check constraints?
- Does the change affect exclusion constraints?
- Does the change affect triggers?
- Does the change affect uniqueness rules?
- Does the change affect lifecycle-dependent validations?
- Does the change affect pending or confirmed booking overlap rules?
- Does the change require migration tests?
- Does the change require updated model tests and service tests?

## Block if unclear
- target state machine is unclear
- data migration impact is unclear
- rollback or compatibility strategy is unclear for a critical invariant

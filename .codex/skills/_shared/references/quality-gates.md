# Quality Gates

## Purpose
This reference defines the repository quality gates that downstream role skills must respect.

## Primary local commands
- `bin/setup --skip-server`
- `bin/dev`
- `bin/check`
- `bin/ci`

## Meaning of each command
- `bin/setup --skip-server`
  - validates Ruby, Bundler, and PostgreSQL preconditions
  - installs dependencies if needed
  - prepares the database
- `bin/check`
  - runs the Rails test suite
- `bin/ci`
  - runs the aggregated CI-aligned checks

## CI-aligned checks
- gem vulnerability audit
- importmap vulnerability audit
- Brakeman
- RuboCop
- Rails tests

## Quality implications for skills
- Product and PO skills must specify how success will be validated.
- Technical skills must define required tests and checks before handoff.
- Dev skills must not call work done if the expected proof is missing.
- Review skills must verify that claimed completion matches the relevant checks.

## Escalation rule
If a change affects:
- DB constraints
- booking lifecycle
- public booking flow
- CI configuration

then the artifact must explicitly name:
- impacted checks
- expected tests
- residual risks

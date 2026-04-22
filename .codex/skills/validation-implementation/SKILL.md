- Output:
  - Scope
  - Findings
  - Missing proof
  - Verdict

- Compare requested change vs implementation.

- Validate:
  - requested behavior implemented
  - no requested behavior missing
  - no unrelated behavior changed
  - no out-of-scope file modified
  - no wider refactor
  - no new abstraction without need

- Check whether the change added or modified:
  - route
  - DB column / migration
  - controller action
  - service
  - helper
  - partial
  - CSS class
  - public API
  - state flow

- Reject if any changed without explicit reason.

- Follow:
  - `.codex/skills/_shared/references/rails-conventions.md`
  - `.codex/skills/_shared/references/html-conventions.md`

- Require proof when relevant:
  - updated test
  - failing test now passing
  - command output
  - migration impact explained
  - before/after behavior

- Reject if:
  - required test missing
  - risky change without proof
  - implementation harder to read or maintain
  - feature spread across more files without need
  - implementation differs from request
  - out-of-scope change not justified

- Out-of-scope accepted only with:
  - reason
  - impact
  - risk

- Verdict:
  - OK
  - OK under conditions
  - Rejected
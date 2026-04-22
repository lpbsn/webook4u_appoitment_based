# implementation-dev

- Output:
  - Scope
  - Confirmed
  - Unknown
  - Questions

- Ask max 3 short questions only if they change the implementation.

- Implement only the requested scope.

- Prefer the smallest correct diff.

- Follow:
  - `.codex/skills/_shared/references/rails-conventions.md`

- Reuse existing:
  - service
  - helper
  - partial
  - CSS class
  - test file
  - naming

- Prefer:
  - local changes
  - low coupling
  - explicit naming
  - short focused methods
  - one responsibility per file/class/method
  - reuse over duplication
  - extending existing structure over creating a new one

- Reject:
  - broad refactor
  - new architecture
  - new pattern if one already exists
  - new abstraction for one use case
  - new CSS class if an existing one fits
  - business logic in controller or ERB
  - duplicated logic
  - feature spread across more files without need

- Out-of-scope only if all are true:
  - directly related
  - improves quality or reduces a real risk
  - local and low impact
  - no wider refactor

- For accepted out-of-scope, output:
  - Reason
  - Impact
  - Risk

- Add only tests directly required by the change.

- Output:
  - Scope
  - Questions
  - Minimal plan
  - Changes
  - Tests
  - Rejected or justified out-of-scope
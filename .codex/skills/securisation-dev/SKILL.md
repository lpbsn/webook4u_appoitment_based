- Output:
  - Scope
  - Risks
  - Unknown
  - Verdict

- Check only the changed code.

- For controllers:
  - missing authorization
  - unsafe params permitting
  - state change on GET
  - missing server-side validation
  - redirect from user input

- For views/helpers:
  - unsafe `html_safe`
  - unsafe `raw`
  - unescaped user content
  - token or secret exposure

- For models/services:
  - forged params changing protected state
  - bypass of existing state flow
  - missing slot / booking protection
  - race condition
  - double booking path
  - hidden side effects

- For tokens / public access:
  - predictable token
  - token reuse
  - missing expiration
  - access without ownership check

- Require when relevant:
  - `bin/brakeman`
  - `bin/bundler-audit`
  - targeted tests

- Classify:
  - Critical
  - High
  - Medium
  - Low
  - Unknown

- Reject if:
  - any Critical issue
  - Critical point still Unknown
  - required fix missing

- Output:
  - Risks by severity
  - Required fixes
  - Missing checks
  - Recommended commands
  - Verdict:
    - OK
    - OK under conditions
    - Rejected
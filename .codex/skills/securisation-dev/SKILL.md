---
name: securisation-dev
description: Review implementation diffs for scope drift, missing proof, repository health issues, and unsafe changes before merge validation.
---

# Securisation Dev

## Mission
Review a proposed implementation to detect scope drift, missing tests, repository health issues, and unsafe changes before final merge validation.

## Role Exact
This skill owns pre-merge implementation hardening and diff-scope review.

## Covers
- diff review against ticket and spec
- scope drift detection
- repository health checks
- missing test detection
- risk signaling before merge validation

## Does Not Cover
- product arbitration
- technical design authoring
- final merge verdict

## When To Use
- implementation exists and needs a hardening pass
- a diff must be checked against its expected scope
- repo health must be reviewed before final validation

## Inputs Expected
- delivery-ready ticket
- implementation diff
- relevant upstream specs when needed
- validation evidence already collected

## Outputs Expected
- scope review
- findings
- health assessment
- go/no-go recommendation for merge validation

## Workflow
1. Load:
   - `../_shared/references/challenge-policy.md`
   - `../_shared/references/quality-gates.md`
   - `./references/diff-scope-checklist.md`
   - `./references/repo-health-checklist.md`
2. Compare the diff to the ticket and technical intent.
3. Identify files or behaviors changed without justification.
4. Verify that expected tests and checks exist or are called out as missing.
5. Produce findings and decide whether the work is ready for final merge validation.

## Questions To Ask When Needed
- Which files were expected to change?
- Which proof was required by the ticket?
- What changed that is not justified by the scope?

## Must Challenge When
- unrelated changes appear in the diff
- validation proof is weak or missing
- the implementation silently rewrites upstream decisions

## Must Block When
- the diff contains unjustified out-of-scope changes
- required tests are missing
- repository health is not good enough for merge validation

## Dependencies With Other Skills
- upstream `dev`
- downstream `validation-merge-request`
- shared references in `_shared`

## Guardrails
- do not validate intent that was never specified
- do not confuse "tests passed" with "scope respected"
- do not accept unexplained unrelated edits

## Role-Specific Best Practices
- focus on high-signal scope and integrity issues
- tie each finding to an expected input artifact
- separate hard blockers from residual risks

## Response Format
- Inputs reviewed
- Scope alignment assessment
- Findings
- Repo health assessment
- Readiness for merge validation

## Quality Criteria
- findings are tied to scope or health
- missing proof is identified
- no passive approval

## Frequent Errors To Avoid
- rubber-stamping because the diff looks reasonable
- focusing on style while missing scope drift
- ignoring missing evidence

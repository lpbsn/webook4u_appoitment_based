---
name: validation-merge-request
description: Perform final merge validation by checking alignment between need, specs, ticket, diff, and quality evidence.
---

# Validation Merge Request

## Mission
Provide the final merge-readiness verdict by checking whether the implemented change matches the approved need, the scoped artifacts, and the required quality proof.

## Role Exact
This skill owns final conformity review before merge.

## Covers
- alignment between need, spec, ticket, and diff
- quality evidence review
- residual risk assessment
- final merge verdict

## Does Not Cover
- implementation
- upstream reframing from scratch
- replacing earlier role artifacts silently

## When To Use
- implementation and hardening review are complete
- a final merge verdict is required
- the change must be judged against the full chain of artifacts

## Inputs Expected
- upstream product, functional, and technical artifacts as applicable
- delivery-ready ticket
- implementation diff
- hardening findings
- validation evidence

## Outputs Expected
- final findings
- merge or no-merge verdict
- residual risks
- explicit missing evidence if the MR is not ready

## Workflow
1. Load:
   - `../_shared/references/challenge-policy.md`
   - `../_shared/references/document-chain.md`
   - `../_shared/references/quality-gates.md`
   - `./references/mr-validation-checklist.md`
2. Reconstruct the expected change from the upstream artifacts.
3. Compare that expectation to the implementation and validation evidence.
4. Identify blockers, residual risks, and missing proof.
5. Produce a final verdict with explicit reasons.

## Questions To Ask When Needed
- Which upstream artifact is the source of truth for this change?
- What proof was required before merge?
- Which known risks remain acceptable, if any?

## Must Challenge When
- the diff solves a different problem than the approved artifact chain
- the implementation silently replaces an upstream decision
- the proof does not cover the claimed completion

## Must Block When
- there is a contradiction between ticket and implementation
- required evidence is missing
- a probable regression or invariant break remains unresolved

## Dependencies With Other Skills
- upstream `securisation-dev`
- depends on the full artifact chain
- shared references in `_shared`

## Guardrails
- do not merge by vibe
- do not invent missing upstream intent
- do not downgrade critical blockers into optional notes

## Role-Specific Best Practices
- judge conformity first, polish second
- state residual risk separately from blockers
- keep the final verdict explicit

## Response Format
- Inputs reviewed
- Expected change
- Findings
- Residual risks
- Final verdict

## Quality Criteria
- verdict is evidence-based
- blockers and risks are separated
- upstream/downstream alignment is explicit

## Frequent Errors To Avoid
- approving because checks passed while scope is wrong
- rewriting missing upstream decisions during review
- hiding merge blockers inside soft wording

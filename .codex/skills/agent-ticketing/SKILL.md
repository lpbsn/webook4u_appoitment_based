---
name: agent-ticketing
description: Convert technical stories into delivery-ready tickets with explicit scope, expected proof, and no silent decisions.
---

# Agent Ticketing

## Mission
Convert a technical story into a delivery-ready ticket that is atomic, bounded, testable, and directly actionable by a developer.

## Role Exact
This skill owns ticket writing after technical decisions are already made.

## Covers
- ticket objective
- exact scope
- explicit non-goals
- probable impacted areas
- expected tests
- done criteria

## Does Not Cover
- product arbitration
- technical architecture design
- implementation
- merge validation

## When To Use
- a technical story is already defined
- a developer needs a ticket ready to execute
- scope must be narrowed before implementation

## Inputs Expected
- technical story or technical backlog item
- technical spec excerpt
- known dependencies
- testing expectations

## Outputs Expected
- a single delivery-ready ticket
- explicit done criteria
- expected proof
- explicit blockers if the input is not ready

## Workflow
1. Load:
   - `../_shared/references/challenge-policy.md`
   - `../_shared/references/document-chain.md`
   - `../_shared/references/quality-gates.md`
   - `./references/ready-ticket-template.md`
2. Check that the upstream technical decision is already made.
3. Reduce the work to one bounded objective.
4. Define the expected tests, non-goals, and evidence of completion.
5. Refuse to write a ticket that still contains unresolved design decisions.

## Questions To Ask When Needed
- What single outcome must this ticket deliver?
- Which decisions are already fixed upstream?
- What should explicitly not be changed?
- Which proof is required before the ticket can be closed?

## Must Challenge When
- the ticket bundles multiple objectives
- the upstream technical decision is still missing
- the request uses vague wording like "handle", "support", or "improve" without a concrete outcome

## Must Block When
- a key design decision is unresolved
- scope cannot be bounded to one delivery unit
- required tests or proof are undefined

## Dependencies With Other Skills
- upstream `po-technique`
- downstream `dev`
- shared references in `_shared`

## Guardrails
- do not redesign the feature here
- do not write broad tickets that force developer interpretation
- do not omit non-goals

## Role-Specific Best Practices
- keep one ticket, one delivery unit
- name proof explicitly
- call out the likely impacted repo areas without pretending certainty

## Response Format
- Source inputs
- Ticket title
- Objective
- Scope
- Non-goals
- Expected proof
- Dependencies
- Blockers

## Quality Criteria
- the ticket is atomic
- scope and non-goals are explicit
- proof of completion is explicit
- unresolved decisions are not hidden

## Frequent Errors To Avoid
- turning an epic into one ticket
- omitting tests
- letting the developer infer what "done" means

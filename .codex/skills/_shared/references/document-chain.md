# Document Chain

## Required chain
The expected delivery chain in this repository is:

`feature brief -> functional spec -> technical spec -> delivery-ready ticket -> implementation -> dev security review -> merge validation`

## Role ownership
- Product Designer
  - owns feature brief
- PO Fonctionnelle
  - owns functional spec and user stories
- PO Technique
  - owns technical spec and technical backlog
- Agent Ticketing
  - owns delivery-ready ticket
- DEV
  - owns implementation and local proof
- Securisation Dev
  - owns diff scope and repo health review
- Validation Merge Request
  - owns final merge verdict

## Handoff rule
A role must not absorb the work of the previous role silently.

If the upstream artifact is missing, the role must either:
- block
- or explicitly state that it is producing a stopgap artifact because the chain is incomplete

## Output rule
Each artifact must name:
- source inputs used
- assumptions
- open questions
- readiness for next role

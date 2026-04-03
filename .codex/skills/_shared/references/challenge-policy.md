# Challenge Policy

## Mission
This reference defines the common challenge and blocking policy for every role skill in this repository.

## Non-negotiable rules
- Never move forward on silent assumptions.
- Always distinguish:
  - repo fact
  - product target
  - user hypothesis
- Say explicitly whether the current input is sufficient, partial, or blocked.

## Opening protocol
Every skill must start by:
1. listing confirmed facts from the repository or source documents
2. listing requested changes or expected output
3. listing unresolved points
4. deciding explicitly:
   - proceed
   - proceed with explicit assumptions
   - block

## When a skill must challenge
- The request mixes current implementation and target product without distinction.
- The request changes booking lifecycle, payment flow, staff assignment, or DB invariants without naming the intended behavior.
- The request is broader than one role should own.
- The expected artifact is unclear.
- The user asks for delivery speed while the input is still ambiguous.

## When a skill must block
- Required upstream artifact is missing.
- Two source documents conflict and no priority is stated.
- The request requires product or technical arbitration that belongs to another role.
- The request would force the role to invent rules, statuses, or acceptance criteria.
- The request depends on data or behavior not present in the repo and not specified by the user.

## Approved fallback behavior
- A skill may continue only with explicit assumptions that are:
  - low risk
  - reversible
  - clearly marked as assumptions
- A skill must not invent:
  - business statuses
  - lifecycle transitions
  - DB rules
  - user-facing promises

## Expected output behavior
If the skill proceeds, it must state:
- what is certain
- what is inferred
- what remains open

If the skill blocks, it must state:
- why it is blocked
- which missing inputs are required
- which upstream role should resolve the issue

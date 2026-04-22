## Services
- Reuse existing service first.
- New service only if:
  - reused logic
  - current object too large
  - clearly separate responsibility
- Reject:
  - one-method wrappers
  - near-duplicates
  - extraction only for "cleanliness"

## Controllers
- Only:
  - params
  - authorization
  - service call
  - response
- No business logic.

## Views
- Keep ERB local and readable.
- No business logic in ERB.
- Helpers only for repeated presentation logic.
- Partial only if:
  - repeated markup
  - readability issue
  - independent evolution
  - reused UI element
- Reject:
  - micro-partials
  - deep partial nesting
  - partial chains less readable than inline ERB
- Inline ERB for short, local, single-use markup.

## Models
- Persistence + domain rules only.
- Reuse existing enums/state flows before new flags or columns.
- Extract logic only when readability or maintenance degrades.

## Methods
- One responsibility.
- Short, explicit, low side effects.
- Early return over nested conditionals.

## Structure
- Extend existing file/object before creating a new one.
- Keep changes local and low coupling.
- New behavior should touch as few files as possible.
- Reject:
  - new abstraction for one use case
  - new pattern if one already exists
  - feature spread across many files without need

## Naming
- Match nearby naming.
- Explicit > generic:
  - `Bookings::Confirm`
  - not `BookingManager`
- One concept per class.
- Avoid vague suffixes:
  - manager
  - handler
  - processor
  unless already established.
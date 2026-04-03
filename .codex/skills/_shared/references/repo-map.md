# Repo Map

## Repository profile
- Framework: Ruby on Rails
- Runtime focus: local solo development first
- Domain: appointment-based booking engine
- Main product document: `docs/EDB-Webook4U-Appointment-Based-V1.md`

## Sources to consult first
1. `README.md`
2. `docs/EDB-Webook4U-Appointment-Based-V1.md`
3. `config/routes.rb`
4. `app/services/bookings/`
5. `app/models/booking.rb`
6. `db/structure.sql`
7. `test/`
8. `.github/workflows/ci.yml`
9. `config/ci.rb`

## Key product flow
- public booking page by slug
- enseigne selection
- service selection
- date selection
- visible slot computation
- pending booking creation
- booking confirmation
- success page

## Key code areas
- Public flow: `app/controllers/public_clients_controller.rb`
- Booking flow: `app/controllers/bookings_controller.rb`
- Booking services: `app/services/bookings/`
- Booking model and lifecycle: `app/models/booking.rb`
- Staff assignment cursor: `app/models/service_assignment_cursor.rb`
- DB truth source: `db/structure.sql`

## Main repository constraints
- `db/structure.sql` is the authoritative DB source for serious analysis.
- `db/schema.rb` is secondary and may omit advanced PostgreSQL behavior.
- The repository uses PostgreSQL constraints and triggers as active business guardrails.
- CI includes security, style, and test steps.

## Existing validation layers
- local setup: `bin/setup --skip-server`
- local tests: `bin/check`
- aggregated checks: `bin/ci`
- CI workflow: `.github/workflows/ci.yml`

## Current documentation state
- Present:
  - `README.md`
  - `docs/EDB-Webook4U-Appointment-Based-V1.md`
- Missing as repo artifacts:
  - structured functional specs
  - structured technical specs
  - backlog artifacts
  - delivery-ready tickets
  - ADRs

## Main high-risk topics
- booking lifecycle semantics
- visible availability vs final staff assignment
- pending expiration and confirmation race conditions
- PostgreSQL invariants
- target product vs current implementation gaps

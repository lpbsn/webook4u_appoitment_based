# Current vs Target Gap

## Purpose
This reference tracks the main gaps between the repository as implemented and the target V1 described in the EDB.

## Gap table

| Area | Current repository state | Target in EDB | Risk |
| --- | --- | --- | --- |
| Payment | Stripe fields exist on `Booking`, but payment flow is not implemented as a delivered runtime workflow | Stripe-enabled per-client payment should gate confirmation when enabled | Product and technical documents must not pretend payment is already delivered |
| Booking auth | `BookingsController` uses `before_action :authenticate_user!` | Public final-user booking flow is described as a hosted public flow | Specs and tickets must state whether auth stays, changes, or is transitional |
| Booking statuses | Repo actively uses `pending`, `confirmed`, `failed` | EDB describes behavior covering `available`, `pending_payment`, `confirmed`, `failed`, `expired` | Do not invent implementation states without explicit technical decision |
| DB truth source | `db/structure.sql` carries advanced PostgreSQL truth | Same repository should rely on real DB invariants | Any technical spec ignoring `db/structure.sql` is incomplete |
| Documentation chain | No functional spec, technical spec, or ticketing structure exists yet | EDB should feed downstream delivery artifacts | Skills must create missing artifacts instead of assuming they already exist |
| Round robin | Implemented through staff rotation cursor and revalidation flow | Round robin must remain simple and must not reduce visible availability | Any change here needs product + technical validation |

## Mandatory handling rule
Every role must classify statements as one of:
- current repo fact
- target product statement
- assumption still requiring validation

## Decision rule
If a request crosses one of the gap areas above without explicitly resolving the gap, the skill must challenge it and may block.

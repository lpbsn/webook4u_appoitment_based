# Booking Invariant Registry

## Objectif

Centraliser les invariants critiques et leur mecanisme d'application pour reduire la derive entre DB, modele, services et tests.

## Legende

- **Layer owner**: couche qui force l'invariant.
- **Proof**: tests ou artefacts de verification existants.

## Invariants

### INV-01 - Booking cross-table consistency

- Rule: `bookings.client_id` doit rester coherent avec `enseigne.client_id`; `booking.enseigne_id` doit matcher `service.enseigne_id` et `staff.enseigne_id`.
- Layer owner: PostgreSQL trigger function + model validations.
- Implementation:
  - `db/structure.sql` (`enforce_bookings_client_consistency`, trigger `bookings_client_consistency_trigger`)
  - `app/models/booking.rb` (`enseigne_belongs_to_client`, `service_belongs_to_enseigne`, `staff_belongs_to_enseigne`)
- Proof:
  - `test/models/bookings_cross_table_trigger_infrastructure_test.rb`
  - `test/models/booking_test.rb`

### INV-02 - Confirmed booking overlap forbidden per staff

- Rule: deux bookings `confirmed` ne doivent pas overlap sur le meme `staff`.
- Layer owner: PostgreSQL exclusion constraint (+ service revalidation pre-DB).
- Implementation:
  - `db/structure.sql` constraint `bookings_confirmed_no_overlapping_intervals_per_staff`
  - `app/services/bookings/confirm_staff_revalidation.rb`
- Proof:
  - `test/models/bookings_cross_table_trigger_infrastructure_test.rb`
  - `test/services/bookings/booking_duplicates_flow_test.rb`

### INV-03 - Pending token globally unique across bookings and expired links

- Rule: `pending_access_token` est unique globalement entre `bookings` et `expired_booking_links`.
- Layer owner: PostgreSQL triggers + model validations.
- Implementation:
  - `db/structure.sql` function `enforce_global_pending_access_token_uniqueness`
  - `app/models/booking.rb`
  - `app/models/expired_booking_link.rb`
- Proof:
  - `test/models/booking_test.rb`
  - `test/services/bookings/public_pending_token_resolver_test.rb`

### INV-04 - Lifecycle field requirements by status

- Rule:
  - `pending` requiert `booking_expires_at` + `pending_access_token`
  - `confirmed` requiert customer data + `confirmation_token` + `staff_id`
- Layer owner: DB checks + model validations.
- Implementation:
  - `db/structure.sql` check constraints `bookings_*_requires_*`
  - `app/models/booking.rb`
- Proof:
  - `test/models/booking_test.rb`

### INV-05 - Round-robin cursor update policy

- Rule:
  - read cursor in pending creation for `automatic`
  - update cursor uniquement sur booking `confirmed` en mode `automatic`
- Layer owner: service layer.
- Implementation:
  - `app/services/bookings/create_pending.rb`
  - `app/services/bookings/confirm.rb`
  - `app/models/service_assignment_cursor.rb`
- Proof:
  - `test/services/bookings/create_pending_test.rb`
  - `test/services/bookings/confirm_test.rb`
  - `test/models/service_assignment_cursor_test.rb`

### INV-06 - Pending expiration semantics

- Rule: un pending expire n'est plus confirmable ni bloquant.
- Layer owner: domain rules + service checks.
- Implementation:
  - `app/services/booking_rules.rb`
  - `app/services/bookings/transition_to_confirmed.rb`
  - `app/models/booking.rb` (`active_pending` scope)
- Proof:
  - `test/services/bookings/transition_to_confirmed_test.rb`
  - `test/models/booking_test.rb`

### INV-07 - Booking slot input boundaries

- Rule: date/time de reservation limitees (non passe, horizon max futur).
- Layer owner: service input boundary.
- Implementation:
  - `app/services/bookings/input.rb`
- Proof:
  - `test/services/bookings/input_test.rb`
  - `test/controllers/bookings_controller_test.rb`

### INV-08 - `failed` status reserved for payment failures

- Rule: le runtime non-paiement ne doit jamais transitionner un booking vers `failed`.
- Layer owner: service orchestration + lifecycle contract.
- Implementation:
  - `docs/booking_lifecycle_contract.md`
  - `app/services/bookings/confirm.rb`
  - `app/services/bookings/create_pending.rb`
  - `app/services/bookings/errors.rb` (codes transitoires hors statut persiste)
- Proof:
  - `test/services/bookings/confirm_test.rb`
  - `test/models/booking_test.rb`

## Review cadence

- Mettre a jour ce registre a chaque changement:
  - de statut booking
  - de contrainte DB booking
  - de logique de confirmation/create-pending
  - de politique round-robin

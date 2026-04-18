# Booking Proof Gates

## Objectif

Associer chaque zone de risque critique a des preuves techniques obligatoires, avec seuil de sortie explicite avant merge.

## Global gates (toute story booking sensible)

1. `bin/check` passe au vert.
2. `bin/ci` passe au vert.
3. Les tests impactes par la story sont executes explicitement.
4. Le risque residuel est documente dans la story/PR.

## Risk Area -> Required Proof

### RISK-AUTH-DRIFT - Auth behavior drift (pending token flow)

- Required tests:
  - `test/integration/booking_authentication_flow_test.rb`
  - `test/integration/role_namespaces_access_test.rb`
- Required checks:
  - `bin/check`
  - `bin/ci`
- Exit criteria:
  - acces pending/confirm anonyme par token confirme
  - aucun acces non autorise inter-namespace role

### RISK-LIFECYCLE-DRIFT - Lifecycle semantics drift

- Required tests:
  - `test/services/bookings/transition_to_confirmed_test.rb`
  - `test/models/booking_test.rb`
  - tests de non-transition vers `failed` (a ajouter si manquants)
- Required checks:
  - `bin/check`
  - `bin/ci`
- Exit criteria:
  - seules transitions contractuelles observees
  - `failed` inatteignable hors paiement

### RISK-AVAILABILITY-DIVERGENCE - Visible slots vs transactional revalidation

- Required tests:
  - `test/services/bookings/available_slots_test.rb`
  - `test/services/bookings/create_pending_staff_revalidation_test.rb`
  - `test/services/bookings/confirm_staff_revalidation_test.rb`
  - `test/integration/booking_flow_test.rb`
- Required checks:
  - `bin/check`
- Exit criteria:
  - scenario contractuel "visible then bookable unless race" couvert
  - codes d'erreur metier alignes avec comportement attendu

### RISK-CONCURRENCY - Locking/concurrency fragility

- Required tests:
  - `test/services/bookings/booking_duplicates_flow_test.rb`
  - `test/services/bookings/slot_lock_test.rb`
  - `test/services/bookings/confirm_test.rb`
- Required checks:
  - `bin/check`
  - `bin/ci`
- Exit criteria:
  - pas de double confirmation overlap pour un meme staff
  - comportement de lock ordering conserve

### RISK-CONTROLLER-HOTSPOT - Admin onboarding controller complexity

- Required tests:
  - `test/integration/admin_client_users_management_test.rb`
- Required checks:
  - `bin/check`
- Exit criteria:
  - regression fonctionnelle absente sur wizard admin
  - responsabilites controller reduites et explicites

### RISK-PAYMENT-LEAKAGE - Payment assumptions leaking into non-payment runtime

- Required tests:
  - `test/services/bookings/confirm_test.rb`
  - `test/models/booking_test.rb`
- Required checks:
  - `bin/check`
  - `bin/ci`
- Exit criteria:
  - aucune dependance paiement pour confirmer en mode runtime actuel
  - statut `failed` non exploite hors flux paiement

## Backlog Theme -> Proof Plan

### Theme 1 - Lifecycle Contract Hardening

- proof:
  - docs contract updated
  - lifecycle tests pass
  - non-transition-to-failed assertions pass

### Theme 2 - Auth & Public Flow Decision Closure

- proof:
  - auth flow integration tests pass
  - docs and ADRs aligned

### Theme 3 - Availability/Revalidation Convergence

- proof:
  - contract tests across slot visibility and booking revalidation pass
  - no mismatch in user-facing errors for covered cases

### Theme 4 - Controller Decomposition & Form Objects

- proof:
  - integration onboarding tests pass
  - no behavior delta in wizard steps

### Theme 5 - Invariant Registry + DB-first Validation Documentation

- proof:
  - invariant registry updated
  - infrastructure invariant tests pass (`*infrastructure*_test.rb`)

### Theme 6 - Payment Gap Isolation

- proof:
  - no runtime transition to `failed`
  - docs/ADR explicitly reserve `failed` for payment failures

## Evidence checklist (for PR description)

- [ ] impacted risk areas listed
- [ ] impacted tests listed and executed
- [ ] `bin/check` green
- [ ] `bin/ci` green
- [ ] residual risk stated
- [ ] docs/ADR/invariant registry updated when semantics changed

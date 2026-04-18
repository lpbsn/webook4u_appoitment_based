# Booking Risk Reduction - Technical Backlog

## Technical Goal

Reduire les risques critiques identifies sur le domaine booking en transformant les themes d'amelioration en stories techniques ordonnees, testables et livrables.

## Constraints

- Respect de `db/structure.sql` comme source de verite DB.
- Pas d'introduction de semantics paiement implicites.
- Pas de rupture du flux public pending token-anonyme.
- Toute story doit inclure preuve locale (`bin/check`) et preuve CI (`bin/ci`).

## EPIC 1 - Lifecycle Contract Hardening

### Story 1.1 - Publish lifecycle contract as repository source
- objective: verrouiller les transitions runtime actuelles et les statuts reserves.
- impacted surfaces: `docs/booking_lifecycle_contract.md`, `docs/README.md`.
- tests: coherence documentaire verifiee en revue + references vers tests runtime.
- dependencies: aucune.
- residual risk: derive si les futures PR ne mettent pas a jour le contrat.

### Story 1.2 - Add transition non-regression tests around `failed`
- objective: garantir qu'aucun chemin applicatif courant ne passe un booking a `failed`.
- impacted surfaces: `test/services/bookings/confirm_test.rb`, `test/models/booking_test.rb`.
- tests: nouveaux tests de non-transition vers `failed`.
- dependencies: Story 1.1.
- residual risk: contournement possible hors services si nouveaux points d'entree non testes.

## EPIC 2 - Auth & Public Flow Decision Closure

### Story 2.1 - Enforce and document token-based anonymous pending contract
- objective: supprimer toute ambiguite "auth obligatoire vs anonyme token".
- impacted surfaces: `docs/README.md`, ADR 0001, controller tests.
- tests: `test/integration/booking_authentication_flow_test.rb`.
- dependencies: Story 1.1.
- residual risk: risque de fuite token hors scope applicatif (operational).

### Story 2.2 - Add authz matrix for namespaces and booking token flow
- objective: expliciter les frontieres entre role namespaces et flux public booking.
- impacted surfaces: nouvelle doc `docs/architecture/booking_domain_map.md` (section authz matrix), tests integration role access.
- tests: `test/integration/role_namespaces_access_test.rb`.
- dependencies: Story 2.1.
- residual risk: matrice non maintenue lors d'ajout de nouvelles routes.

## EPIC 3 - Availability/Revalidation Convergence

### Story 3.1 - Define contract test: visible slot should be bookable unless race
- objective: capturer l'ecart potentiel entre slots visibles et create/confirm revalidation.
- impacted surfaces: `test/services/bookings/available_slots_test.rb`, `test/services/bookings/create_pending_staff_revalidation_test.rb`.
- tests: scenarios contractuels relies.
- dependencies: Stories 1.1, 2.1.
- residual risk: cas limites temporels (timezone/minute boundaries) non exhaustifs.

### Story 3.2 - Harmonize failure codes for slot mismatch and slot unavailable
- objective: uniformiser les reponses metier entre grille visible et revalidation.
- impacted surfaces: `app/services/bookings/create_pending.rb`, `app/services/bookings/create_pending_staff_revalidation.rb`, `app/services/bookings/errors.rb`.
- tests: `test/services/bookings/create_pending_test.rb`, `test/integration/booking_flow_test.rb`.
- dependencies: Story 3.1.
- residual risk: regressions UX si wording d'erreur change sans alignement front.

## EPIC 4 - Controller Decomposition & Form Objects

### Story 4.1 - Extract admin onboarding wizard validation to service/form objects
- objective: reduire la complexite du controller admin.
- impacted surfaces: `app/controllers/admin/clients_controller.rb`, nouveaux objets dans `app/services/admin/` ou `app/forms/`.
- tests: `test/integration/admin_client_users_management_test.rb`.
- dependencies: aucune.
- residual risk: regression d'etat session wizard.

### Story 4.2 - Add thin-controller guardrails
- objective: formaliser des regles de decomposition pour les futurs controleurs.
- impacted surfaces: doc architecture + code review checklist.
- tests: n/a (process), verification par revue.
- dependencies: Story 4.1.
- residual risk: adherence humaine variable.

## EPIC 5 - Invariant Registry + DB-first Validation Documentation

### Story 5.1 - Maintain invariant registry with owner and proof links
- objective: tracer chaque invariant critique vers implementation et tests.
- impacted surfaces: `docs/architecture/booking_invariant_registry.md`.
- tests: n/a (doc), verification des liens vers suites tests.
- dependencies: Story 1.1.
- residual risk: registre obsolete si non mis a jour.

### Story 5.2 - Add PR checklist item for DB invariant-sensitive changes
- objective: rendre obligatoire la verification `db/structure.sql` + tests infra.
- impacted surfaces: contribution docs (README/developer guide).
- tests: n/a (process).
- dependencies: Story 5.1.
- residual risk: bypass de process en urgence.

## EPIC 6 - Payment Gap Isolation

### Story 6.1 - Isolate payment-semantics boundary in booking domain
- objective: eviter l'injection prematuree de logique paiement dans confirmation runtime actuelle.
- impacted surfaces: ADR 0002, docs lifecycle.
- tests: non-regression `pending -> confirmed` sans paiement.
- dependencies: Story 1.2.
- residual risk: confusion persistante si champs Stripe sont interpretes comme workflow actif.

### Story 6.2 - Prepare integration seam for future payment session
- objective: definir un point d'extension technique sans changer behavior actuel.
- impacted surfaces: doc architecture + technical design notes.
- tests: n/a immediat (design readiness).
- dependencies: Story 6.1.
- residual risk: seam mal defini si besoins produit paiement evoluent.

## Delivery Order

1. EPIC 1 (Stories 1.1 -> 1.2)
2. EPIC 2 (Stories 2.1 -> 2.2)
3. EPIC 3 (Stories 3.1 -> 3.2)
4. EPIC 5 (Stories 5.1 -> 5.2)
5. EPIC 4 (Stories 4.1 -> 4.2)
6. EPIC 6 (Stories 6.1 -> 6.2)

## Blockers to monitor

- Divergence persistante entre docs cible produit et runtime livre.
- Changement non documente de semantics auth pending.
- Introduction de transitions lifecycle non contractuelles.

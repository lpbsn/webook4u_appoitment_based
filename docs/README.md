# Documentation active

## Rôle des documents

- `README.md` décrit le fonctionnement quotidien du repository et le périmètre runtime réellement livré.
- `docs/EDB-Webook4U-Appointment-Based-V1.md` décrit la cible produit V1 et ne doit pas être lu comme une preuve que toutes les capacités sont déjà implémentées.

## État actuel du runtime

Le runtime actuellement livré dans ce repository couvre :

- page publique de réservation par `slug`
- sélection d'une enseigne
- sélection d'un service
- choix du mode d'assignation entre `automatic` et `specific_staff`
- sélection d'une date
- recherche de créneaux visibles
- création d'un booking temporaire `pending`
- confirmation finale du booking
- page de succès

## Décision explicite sur l'authentification

Pour le périmètre V1 actuellement livré dans ce repository :

- la consultation d'un booking `pending` est anonyme et autorisée par possession d'un `pending_access_token` valide
- la confirmation finale d'un booking `pending` est anonyme et autorisée par possession d'un `pending_access_token` valide
- la navigation publique avant création du `pending` reste accessible sans authentification
- le token `pending_access_token` agit comme capacité d'accès temporaire, avec expiration courte et protections anti-abus (rate limiting)

Cette règle décrit le contrat runtime actuel. Si le produit doit évoluer vers une confirmation authentifiée, cela devra faire l'objet d'une décision produit et d'un changement explicite du code et des tests.

## Contrat lifecycle booking

Le cycle runtime actuellement livré est volontairement restreint :

- transitions actives :
  - `pending` -> `confirmed`
  - `pending` expiré (expiration logique, sans transition de statut)
- statut réservé :
  - `failed` est réservé aux échecs de paiement et doit rester inatteignable tant que le flux paiement n'est pas livré

## Artefacts techniques de référence

- [booking_lifecycle_contract.md](./booking_lifecycle_contract.md) : contrat technique lifecycle/auth/round-robin
- [adr/0001-booking-pending-auth-model.md](./adr/0001-booking-pending-auth-model.md) : ADR auth pending anonyme par token
- [adr/0002-booking-failed-status-reserved-for-payment.md](./adr/0002-booking-failed-status-reserved-for-payment.md) : ADR statut `failed` réservé au paiement
- [architecture/booking_domain_map.md](./architecture/booking_domain_map.md) : cartographie architecture et points de couplage
- [architecture/booking_invariant_registry.md](./architecture/booking_invariant_registry.md) : registre d'invariants DB/modèle/service/tests
- [technical_backlog/booking_risk_reduction_backlog.md](./technical_backlog/booking_risk_reduction_backlog.md) : backlog technique ordonné et preuves attendues
- [quality/booking_proof_gates.md](./quality/booking_proof_gates.md) : quality gates et preuves CI par zone de risque

## Capacités cibles non livrées à ce stade

Les éléments ci-dessous apparaissent dans la cible produit V1 mais ne sont pas livrés dans le runtime audité à ce jour :

- paiement Stripe
- `PaymentSession`
- gestion d'un thème client
- back-office admin Webook4U
- back-office client
- iframe / embed code

## Décision court terme sur la production

Le repository doit être traité comme `local-first`.

Décision actuelle :

- aucun déploiement production n'est considéré comme supporté à court terme
- les fichiers `Dockerfile`, `config/deploy.yml` et la configuration `production` sont conservés comme base future
- le chantier de hardening production est reporté et devra être traité explicitement avant toute mise en ligne

## Documents à consulter

- [README.md](../README.md)
- [EDB-Webook4U-Appointment-Based-V1.md](./EDB-Webook4U-Appointment-Based-V1.md)

# ADR 0002 - `failed` status reserved for payment failures

## Status

Accepted

## Context

La table `bookings` expose `pending`, `confirmed`, `failed`.
Le runtime livre couvre reservation et confirmation sans workflow paiement.

Sans contrat explicite, le statut `failed` peut etre detourne pour representer des erreurs transitoires de reservation, creant une derive semantique et des incompatibilites futures avec le domaine paiement.

## Decision

- `failed` est reserve aux echecs du workflow paiement.
- Tant que le flux paiement n'est pas livre, `failed` est **inatteignable** par les services runtime.
- Les erreurs transitoires create/confirm restent exprimees via `Bookings::Errors` et non par un changement de statut persiste.
- Le seam de transition vers `failed` est borne a `Bookings::PaymentFailureTransition`, sous garde `Bookings::TransitionToFailedFromPayment`.

## Consequences

### Positives

- Semantique lifecycle stable avant integration paiement.
- Evite de melanger erreurs techniques transitoires et etat metier final.
- Reduit le risque de migration complexe lors de l'introduction Stripe.

### Negatives / Risques

- Besoin de discipline forte dans les futurs services.
- Necessite des tests de non-regression explicites.

## Guardrails

- aucun chemin applicatif vers `failed` dans les services actuels
- tests de transition limites a `pending -> confirmed`
- documentation lifecycle explicite

## Alternatives considerees

1. Utiliser `failed` pour toute erreur de confirmation:
   - rejete: confusion entre exception transitoire et statut metier.
2. Supprimer `failed` du schema:
   - rejete: utile pour cible paiement V1, conservation assumee.

## Evidence repository

- `app/models/booking.rb`
- `app/services/bookings/errors.rb`
- `app/services/bookings/confirm.rb`
- `db/structure.sql`

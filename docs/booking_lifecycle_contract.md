# Contrat technique booking lifecycle (runtime actuel)

## Objectif

Verrouiller un contrat technique explicite entre documentation, code applicatif, base PostgreSQL et tests pour eviter les derives de comportement.

## Perimetre

- Reservation publique par `slug`
- Creation de booking temporaire `pending`
- Confirmation finale vers `confirmed`
- Gestion d'expiration logique des `pending`
- Assignation `automatic` et `specific_staff`

## Statuts et transitions autorises

### Statuts existants en base

- `pending`
- `confirmed`
- `failed`

### Transitions actives (runtime livre)

- `pending` -> `confirmed`

### Etats non-transitionnels

- `pending` expire: l'enregistrement reste `pending`, mais devient non confirmable et non bloquant selon les regles `active_pending`.

### Transition interdite tant que paiement absent

- Toute transition vers `failed` est interdite dans le runtime actuel.
- `failed` est reserve au flux paiement.

### Seam d'integration paiement (sans changement runtime)

- Le point d'extension futur doit vivre dans un service dedie de session paiement.
- Le seam runtime reserve est `Bookings::PaymentFailureTransition`.
- La regle d'entree est encapsulee par `Bookings::TransitionToFailedFromPayment`.
- La transition vers `failed` devra etre pilotee uniquement depuis ce seam paiement.
- Tant que ce seam n'est pas implemente, `pending -> confirmed` reste le seul chemin applicatif de confirmation.

## Contrat d'authentification pour pending

- La consultation `GET /:slug/bookings/:token` est anonyme.
- La confirmation `POST /:slug/bookings/:token/confirm` est anonyme.
- La possession d'un `pending_access_token` valide joue le role de capacite d'acces temporaire.
- Les garde-fous actifs sont:
  - forte entropie du token
  - expiration courte (`booking_expires_at`)
  - rate limiting par client + IP pour creation pending et confirmation

## Contrat round-robin

- Le comportement logique est defini par le couple `(enseigne, service)`.
- L'implementation courante est indexee via `service_assignment_cursors.service_id`.
- Le curseur avance uniquement sur `confirmed` en mode `automatic`.
- Le mode `specific_staff` n'avance jamais le curseur.

## Contrat overlap et concurrence

- **Confirmed overlap**: interdit au niveau DB via exclusion constraint.
- **Pending overlap**: protege au niveau applicatif (locks + revalidation metier), pas de contrainte DB temporelle active-pending.
- **Confirm staff revalidation**: le staff assigne doit rester `active`, appartenir a la meme enseigne, et conserver sa capability sur le service confirme.
- Ordre attendu des locks pour les flux transactionnels:
  1. lock rotation service
  2. lock staff

## Points d'alignement obligatoires

Toute evolution doit rester alignee sur les 4 couches suivantes:

1. documentation contractuelle (`docs/`)
2. services booking (`app/services/bookings/`)
3. invariants model/DB (`app/models/booking.rb`, `db/structure.sql`)
4. preuves (`test/services/bookings/`, `test/integration/`, `test/models/*infrastructure*_test.rb`)

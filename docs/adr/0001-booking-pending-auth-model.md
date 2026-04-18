# ADR 0001 - Pending booking auth model

## Status

Accepted

## Context

Le flux public de reservation expose un acces a:

- `GET /:slug/bookings/:token`
- `POST /:slug/bookings/:token/confirm`

Le runtime actuel supporte la confirmation sans authentification de compte, basee sur un token temporaire `pending_access_token`.

La documentation et certaines hypotheses historiques ont diverge sur ce point, generant un risque de regression de comportement.

## Decision

Le modele d'authentification du flux pending est:

- **anonyme par token**
- **temporaire**
- **limite par rate limiting**

`pending_access_token` est le mecanisme d'autorisation pour ce flux uniquement.

## Consequences

### Positives

- Alignement avec UX de reservation publique sans friction.
- Cohesion avec le parcours hosted page.
- Reduction du couplage avec le systeme de comptes pour la conversion publique.

### Negatives / Risques

- Toute fuite de token donne acces au pending concerne.
- La securite depend de l'entropie et de la duree de validite du token.

### Guardrails

- generation de tokens non predictibles
- expiration courte
- rate limit create/confirm
- absence d'exposition de donnees sensibles avant confirmation

## Alternatives considerees

1. Exiger login pour view + confirm pending:
   - rejete pour incoherence avec parcours public actuel.
2. Mode hybride (view anonyme / confirm authentifie):
   - rejete a ce stade pour complexite UX et dette produit non arbitree.

## Evidence repository

- `app/controllers/bookings_controller.rb`
- `app/services/bookings/public_pending_token_resolver.rb`
- `test/integration/booking_authentication_flow_test.rb`

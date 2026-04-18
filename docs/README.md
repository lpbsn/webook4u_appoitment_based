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

- la consultation d'un booking `pending` requiert une authentification utilisateur
- la confirmation finale d'un booking `pending` requiert une authentification utilisateur
- la navigation publique avant création du `pending` reste accessible sans authentification
- aucun flux invité de confirmation finale n'est livré à ce stade

Cette règle décrit le contrat runtime actuel. Si le produit doit évoluer vers une confirmation anonyme, cela devra faire l'objet d'une décision produit et d'un changement explicite du code et des tests.

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

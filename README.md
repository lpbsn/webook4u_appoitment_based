# Webook4u

Moteur de reservation Ruby on Rails en cours de construction.

Ce repository doit d'abord se lire comme un projet exploite par un seul developpeur en local.

Le README sert donc de porte d'entree strictement orientee usage solo local :

- comprendre rapidement le perimetre actif
- lancer l'application en developpement
- verifier la base et les tests utiles
- savoir quel fichier DB fait vraiment foi

## Workflow solo local

Si tu developpes seul en local pour l'instant, concentre-toi sur 3 commandes :

```bash
bin/setup --skip-server
bin/dev
bin/check
```

Elles couvrent l'essentiel :

- `bin/setup --skip-server` valide et prepare l'environnement local
- `bin/dev` lance l'application en developpement
- `bin/check` execute simplement les tests Rails locaux

Pour l'instant, tu peux ignorer :

- Docker
- Kamal / deploy
- CI
- production

Ce repo conserve ces elements pour plus tard, mais ils ne sont pas necessaires a ton usage quotidien local.

## Versions figees

- Ruby `3.4.9`
- Rails `8.1.2`
- Bundler `2.7.2`
- PostgreSQL `17.x`

Verification rapide :

```bash
ruby -v
bundle -v
psql --version
```

## Demarrage rapide

Prerequis locaux reels :

- Ruby `3.4.9`
- Bundler `2.7.2`
- PostgreSQL `17.x` local accessible

Premier bootstrap local :

```bash
bundle install
bin/setup --skip-server
```

Demarrage quotidien :

```bash
bin/dev
```

Validation minimale avant un changement sensible :

```bash
bin/check
```

Alias explicite :

```bash
bin/rails test
```

`bin/check` suppose un environnement deja valide et prepare par `bin/setup --skip-server`.
Si un probleme local vient de Ruby, Bundler, PostgreSQL ou de la base, la remediaton attendue est de repasser par `bin/setup --skip-server`, pas d'ajouter du bootstrap implicite a `bin/check`.

Reset exceptionnel de la base locale :

```bash
bin/setup --reset --skip-server
```

## Usage quotidien

Le workflow recommande pour un usage solo local est :

1. `bin/dev` pour coder et lancer le serveur
2. `bin/check` avant ou apres une modification importante
3. `bin/setup --reset --skip-server` seulement si tu veux remettre la base locale a plat

## Bootstrap local

Le chemin de reference pour preparer le projet en local est :

```bash
bin/setup --skip-server
```

Ce script :

- installe les dependances Ruby si necessaire
- prepare la base de donnees avec `bin/rails db:prepare`
- nettoie les logs et fichiers temporaires

Pour lancer directement l'application apres le setup :

```bash
bin/setup
```

Application disponible sur :

[http://localhost:3000](http://localhost:3000)

Healthcheck :

[http://localhost:3000/up](http://localhost:3000/up)

## Validation locale

Commande minimale recommandee :

```bash
bin/check
```

Commande equivalente :

```bash
bin/rails test
```

`bin/check` reste volontairement un alias court de test local.
Il ne fait ni preflight d'environnement, ni `db:prepare`, ni auto-reparation.

Lancer un fichier de test precis :

```bash
bin/rails test test/integration/booking_flow_test.rb
```

## Documentation

- [docs/DeveloperOnboarding.md](/Users/leobsn/Desktop/webook4u-engine/docs/DeveloperOnboarding.md) : vue d'ensemble technique pour un nouveau developpeur
- [docs/TestOnboarding.md](/Users/leobsn/Desktop/webook4u-engine/docs/TestOnboarding.md) : vue d'ensemble de la strategie et de la structure des tests
- [docs/DatabaseOnboarding.md](/Users/leobsn/Desktop/webook4u-engine/docs/DatabaseOnboarding.md) : vue d'ensemble rapide de la structure de la base et des invariants DB
- [README.md](/Users/leobsn/Desktop/webook4u-engine/README.md) : point d'entree setup, base locale, tests et perimetre courant
- [docs/BookingRules.md](/Users/leobsn/Desktop/webook4u-engine/docs/BookingRules.md) : point d'entree technique vers la documentation de reservation
- [docs/BookingFlow.md](/Users/leobsn/Desktop/webook4u-engine/docs/BookingFlow.md) : reference du flux de reservation et du cycle de vie courant
- [docs/BookingInvariants.md](/Users/leobsn/Desktop/webook4u-engine/docs/BookingInvariants.md) : reference des invariants de domaine, DB et concurrence
- [docs/DatabaseArchitecture.md](/Users/leobsn/Desktop/webook4u-engine/docs/DatabaseArchitecture.md) : architecture de la base, tables, relations et garde-fous PostgreSQL
- [docs/ProductScope.md](/Users/leobsn/Desktop/webook4u-engine/docs/ProductScope.md) : cadrage produit/strategie courant
- [docs/FutureInvariantsChecklist.md](/Users/leobsn/Desktop/webook4u-engine/docs/FutureInvariantsChecklist.md) : memo prospectif a relire seulement si le perimetre evolue

## Base de donnees locale

Le projet utilise PostgreSQL `17.x`.

Configuration locale par defaut :

- base de developpement : `webook4u_development`
- base de test : `webook4u_test`

Par defaut, `config/database.yml` utilise PostgreSQL local avec l'utilisateur systeme courant si aucun `username` n'est renseigne.

PostgreSQL doit donc etre demarre et accessible en local, sauf configuration specifique via `DATABASE_URL`.

Contrat local de `bin/setup` :

- le preflight PostgreSQL part de la config `development` de `config/database.yml`
- si `development.url` est defini, ses attributs remplacent seulement les cles explicites de cette URL
- si `DATABASE_URL` est defini, ses attributs remplacent ensuite seulement les cles explicites qu'il fournit
- le preflight verifie ainsi la meme cible `development` que `bin/rails db:prepare`

Important :

- le serveur PostgreSQL local doit etre en version `17.x`
- PostgreSQL `15` et les versions anterieures ne sont pas compatibles avec le `db/structure.sql` courant
- un client `psql` en version `17.x` ne suffit pas si le serveur local tourne encore en `15`

Doctrine DB actuelle :

- `db/structure.sql` est la seule reference DB serieuse du projet
- `db/schema.rb` reste un artefact Rails secondaire, utile pour une lecture rapide, mais pas une base d'analyse ni une source de verite pour les invariants PostgreSQL avances
- toute analyse DB, revue de migration ou verification d'invariant doit partir de `db/structure.sql`

Si un doute apparait entre les deux fichiers, il faut croire `db/structure.sql`, pas `db/schema.rb`.

## Verification rapide

Une installation est consideree valide si :

- `bin/setup --skip-server` se termine sans erreur
- `bin/rails server` demarre sans erreur
- [http://localhost:3000/up](http://localhost:3000/up) repond
- une page publique seedee s'affiche en local
- `bin/rails test` passe au vert

## Outils avances

Ces elements existent dans le repo mais ne sont pas necessaires a ton usage quotidien local :

- `bin/ci` pour les checks agregees CI
- `bin/brakeman` et `bin/bundler-audit` pour les audits securite
- `bin/rubocop` pour le style
- `Dockerfile` pour l'image de production
- `config/deploy.yml` et `bin/kamal` pour le deploy
- la section `production` de `config/database.yml` pour une future mise en prod

## Perimetre actuel

Le projet couvre aujourd'hui :

- page publique de reservation par `slug`
- selection d'une enseigne
- selection d'une prestation
- selection d'une date
- affichage des creneaux disponibles
- creation d'une reservation temporaire (`pending`)
- confirmation de reservation
- page de succes

Hors perimetre actuel :

- paiement
- gestion metier liee aux echecs de paiement
- exploitation reelle du statut `failed`
- fonctionnement 100% base sur les horaires par enseigne

Regles metier actuelles :

- les prestations sont partagees entre toutes les enseignes d'un meme client
- pour un jour donne, si une enseigne a au moins une plage dans `enseigne_opening_hours`, ces horaires remplacent totalement le fallback `client` pour ce jour
- les horaires `client` ne servent de fallback que lorsqu'aucune plage `enseigne` n'existe pour le jour demande

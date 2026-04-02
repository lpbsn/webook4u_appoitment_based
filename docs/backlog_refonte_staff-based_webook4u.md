# Backlog agile dev-ready - Refonte staff-based Webook4U

## Objectif

Transformer le plan de [refonte_staff-based_webook4u.md](/Users/leobsn/Desktop/webook4u_appoitment_based/docs/refonte_staff-based_webook4u.md) en backlog directement exploitable par un développeur, sans arbitrage hybride pendant l'implémentation.

Le backlog doit garantir que chaque EPIC et chaque US:

- peut partir en développement sans décision métier complémentaire
- est assez précis pour un développeur
- contient les informations nécessaires à son implémentation
- ne laisse pas de flou sur le périmètre, les dépendances ou la validation

Ce backlog couvre uniquement:

- le noyau métier
- le schéma et les invariants DB
- le moteur de disponibilité
- l'assignation transactionnelle
- le flow public
- le nettoyage final complet de l'ancien modèle

Ce backlog ne couvre pas:

- back-office
- Stripe
- iframe
- embed
- CRM
- annulation
- replanification

## Definition of Ready

Une US est considérée `Ready` uniquement si:

- son objectif métier est explicite
- ses dépendances sont explicites
- ses décisions produit sont déjà arbitrées
- aucune alternative d'implémentation structurante n'est laissée ouverte
- sa surface impactée dans le repo est identifiable
- sa sortie attendue est observable
- ses critères d'acceptation sont testables
- ses non-objectifs sont explicites
- la dette transitoire autorisée ou interdite est explicitée
- les questions qu'un développeur ne doit pas réouvrir sont écrites

Statuts autorisés pendant la revue:

- `Ready`
- `Needs split`
- `Needs decision lock`

Objectif du présent backlog:

- tous les items ci-dessous doivent être `Ready`

## Règles de rédaction d'une US dev-ready

Chaque US suit le format suivant:

- `Statut`
- `But`
- `Pourquoi`
- `Entrées / dépendances`
- `Changements attendus`
- `Zones du repo concernées`
- `Critères d'acceptation`
- `Non-objectifs`
- `Blocages / décisions déjà verrouillées`
- `Questions interdites au dev`

Règles de fond:

- une US ne mélange pas deux axes de refonte distincts
- une US ne mélange pas schéma, runtime et cleanup si cela crée deux livrables différents
- une US ne doit pas supposer une compatibilité transitoire qui n'est pas explicitement autorisée
- si une US reste trop large, elle doit être scindée

## Vue d'ensemble des sprints

### Sprint 1

- Epic 1 - Socle cible et invariants de base

### Sprint 2

- Epic 2 - Disponibilité staff-based

### Sprint 3

- Epic 3 - Assignation transactionnelle et round robin

### Sprint 4

- Epic 4 - Flow public staff-based

### Sprint 5

- Epic 5 - Nettoyage final complet

## Epic 1 - Socle cible et invariants de base

Type:

- structurant

Statut après revue:

- Ready

Objectif:

Poser le modèle cible staff-based et les invariants indispensables avant toute réécriture du moteur.

Risque principal:

- reconstruire le runtime sur un schéma encore ambigu entre ancien et nouveau modèle, ou rendre le repository inutilisable entre Epic 1 et Epic 4

Dépendances:

- aucune

Signal de fin:

- le schéma cible existe
- les invariants critiques sont posés
- les seeds et les tests de base peuvent partir sur le nouveau modèle sans fallback ancien
- le runtime critique ne dépend plus du contrat métier `client.services`
- le runtime critique ne dépend plus du fallback `client_opening_hours`
- un rebranchement minimal permet au repository de rester cohérent avant la fin de l'Epic 4

### E1-US1 - Introduire les entités staff-based

Statut:

- Ready

But:

- disposer des entités `Staff`, `StaffAvailability`, `StaffUnavailability`, `StaffServiceCapability` et `ServiceAssignmentCursor`

Pourquoi:

- le domaine cible ne peut pas être exprimé avec une ressource implicite au niveau enseigne

Entrées / dépendances:

- aucune

Changements attendus:

- ajouter les tables et modèles du domaine staff-based
- relier `Staff` à `Enseigne`
- relier les disponibilités et indisponibilités à `Staff`
- relier les capabilities à `Staff` et `Service`
- relier le curseur de rotation à `Service`

Zones du repo concernées:

- `app/models`
- `db/migrate`
- `db/structure.sql`

Critères d'acceptation:

- les entités existent dans le schéma cible
- les relations permettent d'exprimer `Enseigne -> Staff`, `Staff -> Availability`, `Staff -> Unavailability`, `Staff <-> Service`
- le curseur de rotation existe comme entité dédiée par service

Non-objectifs:

- rattachement de `Service` à `Enseigne`
- aucun calcul de disponibilité
- aucune logique de round robin
- aucun branchement du flow public

Blocages / décisions déjà verrouillées:

- pas de `default staff`
- pas de relation implicite `staff <-> service`

Questions interdites au dev:

- "Peut-on porter la rotation sur staff ?" Non
- "Peut-on déduire automatiquement les capabilities ?" Non

### E1-US2 - Rattacher `Service` à `Enseigne`

Statut:

- Ready

But:

- faire de `Service` une entité portée par `Enseigne`

Pourquoi:

- la cible produit exclut le catalogue global par client

Entrées / dépendances:

- E1-US1

Changements attendus:

- rendre `services.enseigne_id` obligatoire
- retirer `services.client_id` du contrat métier
- faire porter la cohérence métier du service par l'enseigne

Zones du repo concernées:

- `app/models/service.rb`
- `db/migrate`
- `db/seeds.rb`

Critères d'acceptation:

- un service ne peut exister que dans une enseigne
- aucune lecture métier n'a besoin de `client.services`
- le schéma cible porte l'appartenance du service à l'enseigne

Non-objectifs:

- affichage public des services
- nettoyage complet des usages historiques
- suppression physique immédiate de tous les reliquats DB

Blocages / décisions déjà verrouillées:

- pas de duplication conservatoire des services existants
- pas de modèle hybride `Client + Enseigne` pour `Service`

Questions interdites au dev:

- "Garde-t-on `client_id` pour compatibilité longue ?" Non
- "Faut-il dupliquer les services existants par enseigne ?" Non

### E1-US3 - Rattacher `Booking` à `Staff`

Statut:

- Ready

But:

- introduire `staff_id` sur `Booking` pour préparer la ressource réservable explicite

Pourquoi:

- la ressource réservable cible est le staff, mais le runtime d'assignation n'existe pas encore à ce stade

Entrées / dépendances:

- E1-US1

Changements attendus:

- ajouter `bookings.staff_id`
- garder `bookings.staff_id` temporairement nullable à ce stade
- préparer `Booking` à référencer `client / enseigne / service / staff`

Zones du repo concernées:

- `app/models/booking.rb`
- `db/migrate`
- `db/structure.sql`

Critères d'acceptation:

- `bookings.staff_id` existe dans le schéma
- le modèle `Booking` expose explicitement la future ressource staff
- la story n'impose pas encore `NOT NULL`

Non-objectifs:

- orchestration `create_pending`
- réécriture du flow public
- passage immédiat de `staff_id` en obligatoire

Blocages / décisions déjà verrouillées:

- pas de ressource implicite au niveau enseigne
- `bookings.staff_id` ne devient pas `NOT NULL` tant que l'assignation staff n'existe pas réellement

Questions interdites au dev:

- "Peut-on rendre `staff_id` obligatoire dès maintenant ?" Non

### E1-US4 - Poser les invariants DB critiques

Statut:

- Ready

But:

- garantir en base la cohérence entre `booking`, `service`, `staff`, `enseigne` et `client`

Pourquoi:

- ces invariants ne doivent pas dépendre uniquement des validations Rails

Entrées / dépendances:

- E1-US2
- E1-US3

Changements attendus:

- ajouter les contraintes DB de cohérence inter-table
- expliciter ce qui est garanti côté DB et ce qui reste côté Rails

Zones du repo concernées:

- `db/migrate`
- `db/structure.sql`
- `app/models/booking.rb`

Critères d'acceptation:

- un booking ne peut pas pointer vers un service d'une autre enseigne
- un booking ne peut pas pointer vers un staff d'une autre enseigne
- un booking ne peut pas être incohérent avec son client et son enseigne
- les invariants critiques sont visibles dans le schéma DB

Non-objectifs:

- disponibilité
- round robin
- contrainte finale d'overlap `confirmed` par staff

Blocages / décisions déjà verrouillées:

- les invariants critiques doivent vivre en DB

Questions interdites au dev:

- "Peut-on garder ces contrôles uniquement en validation Rails ?" Non

### E1-US5 - Poser la stratégie DB de protection `confirmed` par staff

Statut:

- Ready

But:

- verrouiller explicitement la cible DB finale de protection `confirmed` par `staff_id + interval`

Pourquoi:

- le repo utilise déjà des contraintes et triggers SQL avancés; cette décision ne doit pas rester implicite ni être rediscutée pendant le dev

Entrées / dépendances:

- E1-US3
- E1-US4

Changements attendus:

- documenter dans le backlog et la refonte que la protection finale `confirmed` cible `staff_id + interval`
- expliciter que l'Epic 1 ne met pas encore en place la contrainte finale complète
- expliciter que cette cible DB sera implémentée avec le runtime transactionnel concerné

Zones du repo concernées:

- backlog et documentation de refonte

Critères d'acceptation:

- le backlog ne laisse plus entendre que la protection `confirmed` reste portée par l'enseigne
- la protection finale attendue est explicitement portée par le staff
- la story précise que l'implémentation effective de cette contrainte n'est pas attendue dans l'Epic 1

Non-objectifs:

- implémentation de la contrainte finale
- implémentation immédiate du round robin
- verrouillage applicatif

Blocages / décisions déjà verrouillées:

- la protection finale `confirmed` cible le staff, pas l'enseigne

Questions interdites au dev:

- "Peut-on conserver l'overlap `confirmed` par enseigne dans le socle final ?" Non

### E1-US6 - Retirer `client.services` du contrat métier runtime

Statut:

- Ready

But:

- supprimer toute dépendance métier à `client.services`

Pourquoi:

- le runtime ne doit plus porter deux modèles concurrents du service

Entrées / dépendances:

- E1-US2

Changements attendus:

- retirer les lectures runtime critiques de `client.services`
- aligner associations, seeds et tests de base sur `enseigne.services`

Zones du repo concernées:

- `app/models/client.rb`
- `app/services/bookings/public_page.rb`
- `app/controllers/bookings_controller.rb`
- `db/seeds.rb`

Critères d'acceptation:

- aucune logique métier runtime critique n'utilise `client.services`
- les services de test et de seed sont créés via l'enseigne

Non-objectifs:

- suppression finale de tous les artefacts historiques
- nettoyage complet de tous les reliquats de test et de docs

Blocages / décisions déjà verrouillées:

- pas de compatibilité longue avec un catalogue global client

Questions interdites au dev:

- "Peut-on encore lire `client.services` temporairement dans le runtime ?" Non

### E1-US7 - Retirer `client_opening_hours` du contrat métier runtime

Statut:

- Ready

But:

- supprimer toute dépendance métier à `client_opening_hours`

Pourquoi:

- `enseigne_opening_hours` est l'unique source opérationnelle d'ouverture

Entrées / dépendances:

- E1-US1

Changements attendus:

- retirer le fallback runtime vers `client_opening_hours`
- réaligner seeds et tests de base sur `enseigne_opening_hours`

Zones du repo concernées:

- `app/services/bookings/schedule_resolver.rb`
- `app/models/client.rb`
- `db/seeds.rb`

Critères d'acceptation:

- aucune logique métier runtime n'utilise `client_opening_hours`
- une enseigne sans horaires propres est non réservable

Non-objectifs:

- suppression finale du schéma historique
- suppression physique immédiate de la table

Blocages / décisions déjà verrouillées:

- aucun fallback `client_opening_hours`

Questions interdites au dev:

- "Peut-on garder un fallback le temps de la transition ?" Non

### E1-US8 - Rebrancher minimalement le runtime critique sur le nouveau contrat

Statut:

- Ready

But:

- éviter un état intermédiaire où le repository est cassé entre l'Epic 1 et l'Epic 4

Pourquoi:

- la suppression du contrat `client.services` et du fallback `client_opening_hours` impacte déjà des points d'entrée runtime utilisés par le flow public existant

Entrées / dépendances:

- E1-US2
- E1-US6
- E1-US7

Changements attendus:

- rebrancher minimalement le runtime critique sur `enseigne.services`
- rebrancher minimalement le runtime critique sur `enseigne_opening_hours`
- maintenir un repository cohérent avant la refonte complète du flow public et de la disponibilité

Zones du repo concernées:

- `app/services/bookings/public_page.rb`
- `app/controllers/bookings_controller.rb`
- `app/services/bookings/schedule_resolver.rb`

Critères d'acceptation:

- le runtime critique n'utilise plus `client.services`
- le runtime critique n'utilise plus `client_opening_hours`
- le repository reste cohérent avant la fin de l'Epic 4

Non-objectifs:

- disponibilité staff-based finale
- round robin
- flow public final staff-based

Blocages / décisions déjà verrouillées:

- un rebranchement minimal temporaire est autorisé
- ce rebranchement ne doit pas réintroduire de modèle hybride côté métier

Questions interdites au dev:

- "Peut-on laisser le runtime cassé jusqu'à l'Epic 4 ?" Non

### E1-US9 - Refaire les seeds de base sur le modèle cible

Statut:

- Ready

But:

- reconstruire les seeds de base sur le modèle cible

Pourquoi:

- le projet ne conserve pas les données existantes et doit démarrer directement sur le nouveau socle

Entrées / dépendances:

- E1-US2
- E1-US3
- E1-US6
- E1-US7
- E1-US8

Changements attendus:

- réécrire les seeds de base sur `Enseigne -> Service -> Staff`

Zones du repo concernées:

- `db/seeds.rb`

Critères d'acceptation:

- les seeds reconstruisent uniquement le modèle cible

Non-objectifs:

- helpers de test
- réécriture des tests

Blocages / décisions déjà verrouillées:

- les données existantes sont jetables

Questions interdites au dev:

- "Faut-il migrer les anciens jeux de données ?" Non

### E1-US10 - Refaire les helpers de test de base sur le modèle cible

Statut:

- Ready

But:

- reconstruire les helpers de test de base sur le modèle cible

Pourquoi:

- les helpers de test actuels injectent encore l'ancien modèle dans tout le repo

Entrées / dépendances:

- E1-US2
- E1-US3
- E1-US6
- E1-US7
- E1-US8

Changements attendus:

- réécrire les helpers de test de base sur `Enseigne -> Service -> Staff`
- supprimer les helpers de test de base qui créent encore des services au niveau client
- supprimer les helpers de test de base qui créent encore des `client_opening_hours`

Zones du repo concernées:

- `test/test_helper.rb`
- helpers/factories de test de base

Critères d'acceptation:

- les helpers de test de base ne créent plus de services au niveau client
- les helpers de test de base ne créent plus de `client_opening_hours`
- les helpers de test de base permettent de construire le socle cible minimal

Non-objectifs:

- réécriture complète des tests métier
- correction de toute la suite

Blocages / décisions déjà verrouillées:

- les helpers de test doivent enseigner le nouveau modèle, pas l'ancien

Questions interdites au dev:

- "Peut-on conserver les anciens helpers de base pour compatibilité ?" Non

### E1-US11 - Corriger les tests bloquants pour démarrer sur le nouveau socle

Statut:

- Ready

But:

- corriger les tests structurants qui empêchent de démarrer sur le nouveau socle

Pourquoi:

- l'ancien modèle est diffus dans le domaine, les contrôleurs et le flow public; une passe ciblée est nécessaire pour garder un repo exploitable

Entrées / dépendances:

- E1-US9
- E1-US10

Changements attendus:

- réécrire les tests de base les plus structurants qui échouent à cause du nouveau contrat minimal
- réaligner uniquement le sous-ensemble critique suivant sur le nouveau socle:
  - `PublicPage`
  - `BookingsController`
  - `ScheduleResolver`
  - `booking_flow`
  - les helpers/tests de base qui créent encore `client.services`
  - les helpers/tests de base qui créent encore `client_opening_hours`

Zones du repo concernées:

- jeux de tests de base liés au domaine
- contrôleurs critiques
- flow public critique

Critères d'acceptation:

- le sous-ensemble critique explicitement listé démarre sur le modèle cible
- la story traite explicitement l'impact diffus de l'ancien modèle dans la suite

Non-objectifs:

- réécriture complète de tous les tests métier
- nettoyage final complet de la suite
- correction d'autres tests cassés hors du sous-ensemble critique listé

Blocages / décisions déjà verrouillées:

- cette story vise les tests bloquants, pas la perfection de toute la suite

Questions interdites au dev:

- "Doit-on corriger toute la suite de tests dans l'Epic 1 ?" Non
- "Doit-on élargir la story à d'autres fichiers de test cassés ?" Non

### Definition of Done Epic 1

- le schéma cible existe
- les invariants DB critiques sont posés
- la cible DB finale `confirmed by staff` est explicitement verrouillée
- aucune dépendance métier runtime critique à `client.services`
- aucune dépendance métier runtime critique à `client_opening_hours`
- le runtime critique est rebranché minimalement sur le nouveau contrat
- les seeds de base démarrent sur le modèle cible
- les helpers de test de base démarrent sur le modèle cible
- les tests bloquants les plus structurants démarrent sur le modèle cible

## Epic 2 - Disponibilité staff-based

Type:

- structurant

Statut après revue:

- Ready

Objectif:

- remplacer le calcul de disponibilité `enseigne-based` par un calcul `staff-based`

Risque principal:

- mélanger visibilité publique et assignation staff dans le même calcul

Dépendances:

- Epic 1

Signal de fin:

- les slots visibles reflètent les staffs réellement éligibles
- aucune étape de visibilité publique n'assigne un staff

### E2-US1 - Résoudre les staffs éligibles d'un service

Statut:

- Ready

But:

- identifier les staffs candidats d'un service avant tout calcul de disponibilité

Pourquoi:

- le calcul ne doit considérer que les staffs réellement autorisés à exécuter le service

Entrées / dépendances:

- Epic 1 terminé

Changements attendus:

- introduire une résolution explicite des staffs éligibles pour un service
- exclure les staffs inactifs
- exclure les staffs sans capability

Zones du repo concernées:

- services métier de disponibilité
- `app/models/staff.rb`
- `app/models/staff_service_capability.rb`

Critères d'acceptation:

- seuls les staffs de la bonne enseigne sont retenus
- un staff inactif est exclu
- un staff sans capability est exclu

Non-objectifs:

- calcul des créneaux visibles
- assignation transactionnelle

Blocages / décisions déjà verrouillées:

- aucune capability implicite

Questions interdites au dev:

- "Peut-on considérer tous les staffs d'une enseigne comme compatibles par défaut ?" Non

### E2-US2 - Calculer la disponibilité hebdomadaire par staff

Statut:

- Ready

But:

- calculer les fenêtres de base d'un staff à partir de ses disponibilités hebdomadaires

Pourquoi:

- la disponibilité hebdomadaire est un composant distinct du cadre d'ouverture enseigne

Entrées / dépendances:

- E2-US1

Changements attendus:

- produire les fenêtres horaires staff par jour
- porter cette logique séparément des indisponibilités ponctuelles

Zones du repo concernées:

- services métier de disponibilité
- `app/models/staff_availability.rb`

Critères d'acceptation:

- la disponibilité hebdomadaire staff est calculable indépendamment du reste
- un staff sans disponibilité exploitable n'est pas réservable sur la journée

Non-objectifs:

- application des indisponibilités ponctuelles
- agrégation publique des slots

Blocages / décisions déjà verrouillées:

- la disponibilité hebdomadaire staff n'est pas déduite de l'enseigne

Questions interdites au dev:

- "Peut-on se contenter des horaires d'ouverture enseigne ?" Non

### E2-US3 - Appliquer les indisponibilités ponctuelles staff

Statut:

- Ready

But:

- exclure les fenêtres bloquées par les indisponibilités ponctuelles d'un staff

Pourquoi:

- les absences et pauses ponctuelles ne doivent pas être traitées comme des horaires hebdomadaires

Entrées / dépendances:

- E2-US2

Changements attendus:

- retrancher les indisponibilités ponctuelles des fenêtres staff

Zones du repo concernées:

- services métier de disponibilité
- `app/models/staff_unavailability.rb`

Critères d'acceptation:

- toute indisponibilité overlapping retire la portion concernée
- un staff totalement indisponible sur un intervalle n'apparaît pas comme libre

Non-objectifs:

- prise en compte des bookings bloquants

Blocages / décisions déjà verrouillées:

- les indisponibilités ponctuelles sont distinctes des disponibilités hebdomadaires

Questions interdites au dev:

- "Peut-on fusionner indisponibilités et disponibilités dans le même objet métier ?" Non

### E2-US4 - Intersecter horaires enseigne, fenêtres staff et durée du service

Statut:

- Ready

But:

- produire les fenêtres réellement réservables avant prise en compte des bookings

Pourquoi:

- la réservable dépend de l'intersection du cadre enseigne, des fenêtres staff et de la durée du service

Entrées / dépendances:

- E2-US2
- E2-US3

Changements attendus:

- intersecter `enseigne_opening_hours` avec la disponibilité réelle du staff
- exclure les intervalles où la durée du service ne tient pas

Zones du repo concernées:

- services métier de disponibilité
- `app/services/bookings/schedule_resolver.rb` ou son remplaçant

Critères d'acceptation:

- une enseigne sans horaires propres n'est pas réservable
- un intervalle plus court que la durée du service n'est pas exploitable

Non-objectifs:

- prise en compte des bookings bloquants
- agrégation publique des slots

Blocages / décisions déjà verrouillées:

- `enseigne_opening_hours` est la seule source opérationnelle d'ouverture

Questions interdites au dev:

- "Peut-on fallback sur `client_opening_hours` ?" Non

### E2-US5 - Intégrer les bookings bloquants dans la disponibilité staff

Statut:

- Ready

But:

- exclure de la disponibilité staff les intervalles déjà bloqués par les bookings

Pourquoi:

- un staff ne peut pas être proposé sur un créneau déjà réservé ou temporairement verrouillé

Entrées / dépendances:

- E2-US4

Changements attendus:

- intégrer `confirmed` et `pending` actifs comme bookings bloquants
- ignorer les `pending` expirés

Zones du repo concernées:

- services métier de disponibilité
- `app/models/booking.rb`
- services de blocking bookings

Critères d'acceptation:

- un `confirmed` bloque le staff sur son intervalle
- un `pending` actif bloque le staff sur son intervalle
- un `pending` expiré ne bloque plus

Non-objectifs:

- assignation de staff

Blocages / décisions déjà verrouillées:

- le blocage temporaire reste porté par les `pending` actifs

Questions interdites au dev:

- "Peut-on ignorer les pending actifs dans la visibilité ?" Non

### E2-US6 - Agréger les slots visibles sans assignation

Statut:

- Ready

But:

- produire les slots visibles publics à partir de l'union des disponibilités staff

Pourquoi:

- la visibilité publique doit refléter les créneaux possibles sans choisir de staff à ce stade

Entrées / dépendances:

- E2-US5

Changements attendus:

- agréger les slots visibles depuis les disponibilités des staffs éligibles
- ne jamais assigner de `staff_id` à ce stade

Zones du repo concernées:

- `app/services/bookings/available_slots.rb` ou son remplaçant
- `app/services/bookings/public_page.rb`

Critères d'acceptation:

- un slot est visible si au moins un staff compatible est libre
- un slot disparaît uniquement si tous les staffs compatibles sont indisponibles ou bloqués
- aucune assignation staff n'est produite par la visibilité publique

Non-objectifs:

- création du pending
- orchestration round robin

Blocages / décisions déjà verrouillées:

- la visibilité publique n'assigne jamais un staff

Questions interdites au dev:

- "Peut-on choisir un staff dès l'affichage des slots ?" Non

### Definition of Done Epic 2

- la disponibilité est calculée staff par staff
- la visibilité publique repose sur l'union des staffs éligibles
- aucune visibilité publique n'utilise une ressource implicite enseigne
- aucune visibilité publique n'assigne un staff

## Epic 3 - Assignation transactionnelle et round robin

Type:

- structurant

Statut après revue:

- Ready

Objectif:

- assigner un staff de manière déterministe et sûre sous concurrence

Risque principal:

- laisser au développeur des décisions implicites sur l'ordre exact des verrous et de la revalidation

Dépendances:

- Epic 1
- Epic 2

Signal de fin:

- `create_pending` et `confirm` suivent une orchestration non ambiguë
- le curseur de rotation n'avance qu'au `confirmed`
- l'anti-overlap `confirmed` par staff est garanti

### E3-US1 - Formaliser le curseur de rotation par service

Statut:

- Ready

But:

- disposer d'une source de vérité explicite pour la rotation d'un service

Pourquoi:

- la rotation ne doit être ni implicite ni portée par les staffs eux-mêmes

Entrées / dépendances:

- Epic 1 terminé

Changements attendus:

- définir le curseur de rotation par `service`
- définir son ordre initial déterministe

Zones du repo concernées:

- modèle du curseur
- services métier d'assignation

Critères d'acceptation:

- un service possède un état de rotation unique
- l'ordre initial ne dépend pas d'un comportement implicite en mémoire

Non-objectifs:

- lock
- création du pending

Blocages / décisions déjà verrouillées:

- la rotation n'est pas portée par `staff`

Questions interdites au dev:

- "Peut-on utiliser `last_confirmed_assignment_at` sur staff comme source de vérité ?" Non

### E3-US2 - Définir la stratégie de verrouillage

Statut:

- Ready

But:

- verrouiller explicitement l'orchestration de réservation pour éviter tout arbitrage implicite sous concurrence

Pourquoi:

- l'ordre des verrous est un choix structurant du moteur

Entrées / dépendances:

- E3-US1

Changements attendus:

- définir l'ordre exact suivant:
  - lock rotation du service
  - calcul ordre candidats
  - lock staff candidat
  - revalidation
  - création pending ou confirmation
- expliciter la frontière entre lock applicatif et contrainte DB

Zones du repo concernées:

- services d'assignation
- services de lock
- documentation technique du backlog

Critères d'acceptation:

- l'ordre des verrous est écrit et non interprétable
- la responsabilité du lock de rotation et du lock staff est distinguée
- la contrainte DB est présentée comme protection finale, pas comme orchestration primaire

Non-objectifs:

- implémentation du flow public

Blocages / décisions déjà verrouillées:

- lock rotation avant lock staff
- pas de fallback opportuniste hors ordre de rotation

Questions interdites au dev:

- "Peut-on locker directement un staff sans verrouiller la rotation ?" Non

### E3-US3 - Orchestrer `create_pending` sur le round robin

Statut:

- Ready

But:

- créer un pending sur le premier staff valide selon l'ordre de rotation

Pourquoi:

- l'assignation doit être déterministe et compatible avec la rotation

Entrées / dépendances:

- E3-US2

Changements attendus:

- lire le curseur de rotation du service
- tester les staffs candidats dans cet ordre
- verrouiller puis revalider chaque candidat
- créer le pending sur le premier staff valide
- renvoyer `slot_unavailable` si aucun staff n'est valide

Zones du repo concernées:

- `app/services/bookings/create_pending.rb`
- services d'assignation
- services de lock

Critères d'acceptation:

- `create_pending` crée un booking avec `staff_id`
- le pending est créé sur le premier candidat valide
- aucun autre ordre n'est utilisé

Non-objectifs:

- avance du curseur
- réassignation au confirm

Blocages / décisions déjà verrouillées:

- le curseur n'avance pas au `pending`

Questions interdites au dev:

- "Peut-on avancer la rotation lors de `create_pending` ?" Non

### E3-US4 - Orchestrer `confirm` sans réassignation

Statut:

- Ready

But:

- confirmer un pending sur le staff déjà assigné, sans changement de ressource

Pourquoi:

- la confirmation ne doit pas modifier la ressource réservée

Entrées / dépendances:

- E3-US3

Changements attendus:

- verrouiller le staff déjà porté par le pending
- revalider le slot sur ce même staff
- confirmer sans réassigner

Zones du repo concernées:

- `app/services/bookings/confirm.rb`
- services d'assignation

Critères d'acceptation:

- `confirm` conserve le même `staff_id`
- aucun fallback vers un autre staff n'existe

Non-objectifs:

- recherche d'un autre staff si le slot n'est plus valable

Blocages / décisions déjà verrouillées:

- pas de réassignation au `confirm`

Questions interdites au dev:

- "Peut-on essayer un autre staff si celui du pending n'est plus disponible ?" Non

### E3-US5 - Avancer le curseur uniquement au `confirmed`

Statut:

- Ready

But:

- mettre à jour la rotation uniquement quand la réservation devient confirmée

Pourquoi:

- les pending abandonnés ou expirés ne doivent pas influencer la distribution

Entrées / dépendances:

- E3-US4

Changements attendus:

- avancer le curseur de rotation dans la transaction de confirmation
- empêcher toute avance sur pending, expiré ou échec

Zones du repo concernées:

- services d'assignation
- services de confirmation

Critères d'acceptation:

- le curseur n'avance jamais sur `pending`
- le curseur n'avance jamais sur expiration ou échec
- le curseur avance dans la même transaction que le `confirmed`

Non-objectifs:

- changement d'ordre des candidats en dehors du confirmed

Blocages / décisions déjà verrouillées:

- la rotation n'avance qu'au `confirmed`

Questions interdites au dev:

- "Peut-on faire avancer le curseur quand le pending est créé ?" Non

### E3-US6 - Garantir l'anti-overlap `confirmed` par staff

Statut:

- Ready

But:

- protéger l'invariant final d'absence de conflit `confirmed` sur un même staff

Pourquoi:

- la stratégie de concurrence doit s'appuyer sur un garde-fou DB final

Entrées / dépendances:

- E1-US4
- E3-US2

Changements attendus:

- remplacer l'anti-overlap confirmed par une contrainte par `staff_id + interval`

Zones du repo concernées:

- `db/migrate`
- `db/structure.sql`
- `app/services/bookings/errors.rb`

Critères d'acceptation:

- deux `confirmed` overlapping sont refusés sur un même staff
- deux `confirmed` overlapping restent autorisés sur deux staffs distincts
- la protection critique existe côté DB

Non-objectifs:

- blocage des pending actifs

Blocages / décisions déjà verrouillées:

- la contrainte DB protège uniquement l'invariant confirmed

Questions interdites au dev:

- "La contrainte DB suffit-elle pour piloter toute l'orchestration ?" Non

### Definition of Done Epic 3

- la rotation est explicite et non ambiguë
- l'ordre des verrous est fixé
- `create_pending` et `confirm` n'ont plus d'arbitrage implicite
- l'anti-overlap `confirmed` par staff est garanti

## Epic 4 - Flow public staff-based

Type:

- branchable

Statut après revue:

- Ready

Objectif:

- rebrancher le flow public existant sur le noyau staff-based

Risque principal:

- réécrire des comportements publics sans verrouiller les contrats qui doivent rester stables

Dépendances:

- Epic 2
- Epic 3

Signal de fin:

- le parcours public fonctionne de bout en bout sur le nouveau noyau
- les contrats publics utiles restent stables

### E4-US1 - Charger les services publics depuis l'enseigne

Statut:

- Ready

But:

- afficher uniquement les services de l'enseigne sélectionnée

Pourquoi:

- le catalogue global client n'existe plus côté métier

Entrées / dépendances:

- Epic 1 terminé

Changements attendus:

- charger les services via l'enseigne sélectionnée
- supprimer toute dépendance publique à `client.services`

Zones du repo concernées:

- `app/services/bookings/public_page.rb`
- `app/controllers/public_clients_controller.rb`
- vues publiques de sélection service

Critères d'acceptation:

- la page publique ne lit plus `client.services`
- les services affichés appartiennent tous à l'enseigne sélectionnée

Non-objectifs:

- calcul des slots
- création du pending

Blocages / décisions déjà verrouillées:

- pas de catalogue global client dans le flow public

Questions interdites au dev:

- "Peut-on garder une liste globale client puis filtrer ensuite ?" Non

### E4-US2 - Afficher les slots publics depuis l'union des staffs éligibles

Statut:

- Ready

But:

- exposer les slots visibles issus du moteur staff-based

Pourquoi:

- les slots publics doivent refléter le moteur réel sans assigner de staff à l'affichage

Entrées / dépendances:

- Epic 2 terminé

Changements attendus:

- brancher la page publique sur l'agrégateur de slots visibles

Zones du repo concernées:

- `app/services/bookings/public_page.rb`
- `app/services/bookings/available_slots.rb`
- vues publiques de slots

Critères d'acceptation:

- les slots affichés viennent de l'union des staffs éligibles
- la visibilité publique n'assigne pas de staff

Non-objectifs:

- création du pending

Blocages / décisions déjà verrouillées:

- la visibilité publique ne choisit jamais de staff

Questions interdites au dev:

- "Peut-on exposer le staff à ce stade ?" Non

### E4-US3 - Créer le pending staff-based sans changer le contrat public

Statut:

- Ready

But:

- créer un pending avec `staff_id` tout en conservant la structure publique du flow

Pourquoi:

- l'orchestration interne change, mais le parcours utilisateur reste le même

Entrées / dépendances:

- Epic 3 terminé

Changements attendus:

- brancher le POST de création sur `create_pending` staff-based
- persister `staff_id`
- préserver le contrat public `enseigne -> service -> date -> slots -> pending`

Zones du repo concernées:

- `app/controllers/bookings_controller.rb`
- `app/services/bookings/create_pending.rb`
- routes et vues du flow pending

Critères d'acceptation:

- `create_pending` crée un booking avec `staff_id`
- la structure publique du flow reste inchangée

Non-objectifs:

- affichage du staff

Blocages / décisions déjà verrouillées:

- le staff reste interne

Questions interdites au dev:

- "Peut-on changer la structure publique du flow pour refléter le staff ?" Non

### E4-US4 - Conserver un confirm/success sans exposition du staff

Statut:

- Ready

But:

- garder les vues et redirects de confirmation cohérents sans rendre le staff visible

Pourquoi:

- la ressource réservée est interne au moteur, pas au parcours utilisateur

Entrées / dépendances:

- E4-US3

Changements attendus:

- confirmer un pending déjà assigné
- conserver les vues `show` et `success` sans exposition du staff
- conserver les redirects publics sans paramètre staff

Zones du repo concernées:

- `app/controllers/bookings_controller.rb`
- vues `show` et `success`
- `app/services/bookings/confirm.rb`

Critères d'acceptation:

- aucun écran public n'affiche de choix staff
- aucun redirect public n'introduit de notion de staff
- le `confirm` garde le même `staff_id`

Non-objectifs:

- affichage d'informations staff à l'utilisateur

Blocages / décisions déjà verrouillées:

- le staff reste invisible dans toutes les vues et redirects publiques

Questions interdites au dev:

- "Peut-on mentionner le staff sur la page success ?" Non

### Definition of Done Epic 4

- le flow public est branché sur le moteur staff-based
- le contrat public utile reste stable
- le staff reste invisible partout dans l'UX publique

## Epic 5 - Nettoyage final complet

Type:

- cleanup

Statut après revue:

- Ready

Objectif:

- supprimer totalement l'ancien noyau et ses artefacts pour éviter toute dette hybride durable

Risque principal:

- laisser une partie du runtime, des tests ou du socle DB encore attachée à l'ancien modèle

Dépendances:

- Epic 4

Signal de fin:

- runtime propre
- tests et seeds propres
- socle DB propre
- docs propres

### E5-US1 - Supprimer le runtime `enseigne-based`

Statut:

- Ready

But:

- retirer toute logique runtime où l'enseigne est encore traitée comme ressource réservable

Pourquoi:

- l'ancien noyau ne doit plus coexister avec le nouveau

Entrées / dépendances:

- Epic 4 terminé

Changements attendus:

- supprimer les branches runtime `resource = enseigne`
- supprimer les locks applicatifs au niveau enseigne
- supprimer les commentaires de transition devenus faux

Zones du repo concernées:

- services de booking runtime
- helpers et contrôleurs liés au flow de réservation

Critères d'acceptation:

- aucune logique runtime ne suppose encore `une enseigne = une ressource`
- les locks runtime ne sont plus portés au niveau enseigne

Non-objectifs:

- nettoyage DB historique

Blocages / décisions déjà verrouillées:

- aucun dual-run runtime

Questions interdites au dev:

- "Peut-on conserver une branche de compatibilité `enseigne-based` ?" Non

### E5-US2 - Supprimer `client_opening_hours` du runtime, des tests, des seeds et du schéma

Statut:

- Ready

But:

- éliminer totalement `client_opening_hours` du projet

Pourquoi:

- cette notion ne doit plus exister ni au runtime ni dans le socle final

Entrées / dépendances:

- E5-US1

Changements attendus:

- supprimer le runtime lié à `client_opening_hours`
- supprimer les tests et seeds qui l'utilisent
- retirer son support du schéma final

Zones du repo concernées:

- `app/models/client.rb`
- `app/services/bookings/schedule_resolver.rb` ou son remplaçant
- `db/seeds.rb`
- tests liés aux opening hours

Critères d'acceptation:

- aucune règle métier runtime n'utilise `client_opening_hours`
- les tests ne construisent plus de `client_opening_hours`
- les seeds ne créent plus de `client_opening_hours`
- le schéma final n'inclut plus `client_opening_hours`

Non-objectifs:

- nettoyage des docs

Blocages / décisions déjà verrouillées:

- `client_opening_hours` sort complètement du socle cible

Questions interdites au dev:

- "Peut-on garder la table en archive dans le schéma final ?" Non

### E5-US3 - Supprimer `client.services` du runtime, des tests, des seeds et du schéma

Statut:

- Ready

But:

- éliminer totalement le modèle de service global au client

Pourquoi:

- le socle final ne doit plus conserver cette notion

Entrées / dépendances:

- E5-US1

Changements attendus:

- supprimer les associations et usages runtime de `client.services`
- supprimer les tests et seeds qui créent les services via le client
- retirer les reliquats du schéma final

Zones du repo concernées:

- `app/models/client.rb`
- `app/models/service.rb`
- `db/seeds.rb`
- tests domaine et flow public

Critères d'acceptation:

- aucune logique métier n'utilise `client.services`
- les tests créent les services via l'enseigne
- les seeds créent les services via l'enseigne
- le schéma final n'exprime plus de service global client

Non-objectifs:

- nettoyage des docs

Blocages / décisions déjà verrouillées:

- `Service` appartient uniquement à `Enseigne`

Questions interdites au dev:

- "Peut-on conserver `client.services` comme raccourci de lecture ?" Non

### E5-US4 - Nettoyer tests, seeds et helpers obsolètes

Statut:

- Ready

But:

- supprimer tous les artefacts d'accompagnement qui documentent encore l'ancien modèle

Pourquoi:

- un repo propre ne doit pas enseigner un comportement interdit

Entrées / dépendances:

- E5-US2
- E5-US3

Changements attendus:

- supprimer les tests obsolètes
- réécrire les tests devenus faux
- nettoyer les helpers de test et helpers de vues devenus inutiles

Zones du repo concernées:

- `test/`
- `db/seeds.rb`
- helpers liés au flow public

Critères d'acceptation:

- aucun test ne documente encore un comportement désormais interdit
- aucun helper de test ne reconstruit l'ancien modèle
- aucun seed ne reconstruit l'ancien modèle

Non-objectifs:

- nettoyage du schéma historique

Blocages / décisions déjà verrouillées:

- le nettoyage test/seed est obligatoire et non reportable

Questions interdites au dev:

- "Peut-on laisser les anciens tests pour mémoire ?" Non

### E5-US5 - Régénérer un socle DB propre

Statut:

- Ready

But:

- produire un schéma final et un historique DB alignés uniquement avec le modèle cible

Pourquoi:

- le socle DB final ne doit pas conserver les compromis de la transition

Entrées / dépendances:

- E5-US2
- E5-US3

Changements attendus:

- supprimer les migrations et contraintes obsolètes qui n'ont plus de valeur dans le nouveau socle
- régénérer le schéma final
- régénérer `db/structure.sql`

Zones du repo concernées:

- `db/migrate`
- `db/structure.sql`
- `db/schema.rb`

Critères d'acceptation:

- la base peut être reconstruite proprement à partir du nouveau socle
- le schéma final ne contient plus d'artefacts de l'ancien modèle
- `db/structure.sql` reflète uniquement le modèle cible

Non-objectifs:

- nettoyage des docs

Blocages / décisions déjà verrouillées:

- le nettoyage DB/historique n'est pas optionnel

Questions interdites au dev:

- "Peut-on garder les migrations transitoires dans le socle final par commodité ?" Non

### E5-US6 - Nettoyer la documentation obsolète

Statut:

- Ready

But:

- supprimer ou réécrire les documents qui décrivent encore l'ancien noyau

Pourquoi:

- la documentation ne doit pas réintroduire un modèle désormais interdit

Entrées / dépendances:

- E5-US1
- E5-US4
- E5-US5

Changements attendus:

- retirer les docs obsolètes
- réaligner les docs restantes sur le noyau staff-based

Zones du repo concernées:

- `docs/`
- README si nécessaire

Critères d'acceptation:

- les docs actives décrivent uniquement le socle cible
- aucune doc active ne décrit encore `client.services` ou `client_opening_hours` comme runtime métier

Non-objectifs:

- ajout de nouvelles documentations produit hors chantier

Blocages / décisions déjà verrouillées:

- les docs obsolètes doivent être supprimées ou réécrites, pas conservées en l'état

Questions interdites au dev:

- "Peut-on garder les docs obsolètes en archive visible sans signal clair ?" Non

### Definition of Done Epic 5

- runtime propre
- tests et seeds propres
- socle DB propre
- docs propres
- aucune dépendance active à `client.services`
- aucune dépendance active à `client_opening_hours`

## Priorisation finale

### Must have

- Epic 1
- Epic 2
- Epic 3
- Epic 4
- Epic 5

### Won't have dans ce chantier

- back-office
- Stripe
- iframe
- embed
- CRM
- annulation
- replanification

## Définition du MVP de refonte

Le MVP de refonte est atteint à la fin de l'Epic 4 si:

- le schéma cible staff-based est en place
- la disponibilité est calculée correctement par staff
- l'assignation transactionnelle et le round robin sont sûrs
- le flow public fonctionne de bout en bout
- l'utilisateur final ne choisit pas le staff

Le chantier n'est clôturé qu'après l'Epic 5.

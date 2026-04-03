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

- mélanger visibilité publique et assignation staff dans le même calcul, ou continuer à s'appuyer sur une ressource implicite enseigne malgré le socle staff-based déjà livré

Dépendances:

- Epic 1

Signal de fin:

- les slots visibles reflètent les staffs réellement éligibles
- aucune étape de visibilité publique n'assigne un staff
- le calcul visible n'utilise plus `Resource.for_enseigne` comme ressource métier de disponibilité
- le moteur visible ne dépend plus d'un blocage par enseigne
- `ScheduleResolver` reste limité au cadre d'ouverture enseigne
- le moteur visible staff-based repose explicitement sur les staffs, pas sur une abstraction de ressource globale enseigne

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

- services métier de disponibilité visibles
- `app/models/staff.rb`
- `app/models/staff_service_capability.rb`
- `app/models/service.rb`

Critères d'acceptation:

- seuls les staffs de la bonne enseigne sont retenus
- un staff inactif est exclu
- un staff sans capability est exclu

Non-objectifs:

- calcul des créneaux visibles
- assignation transactionnelle
- round robin
- modification de `create_pending` ou `confirm`

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

- services métier de disponibilité visibles
- `app/models/staff_availability.rb`

Critères d'acceptation:

- la disponibilité hebdomadaire staff est calculable indépendamment du reste
- un staff sans disponibilité exploitable n'est pas réservable sur la journée

Non-objectifs:

- application des indisponibilités ponctuelles
- agrégation publique des slots
- prise en compte des bookings
- extension de `ScheduleResolver` au calcul staff-based

Blocages / décisions déjà verrouillées:

- la disponibilité hebdomadaire staff n'est pas déduite de l'enseigne
- `ScheduleResolver` ne devient pas le service central de disponibilité staff-based

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

- services métier de disponibilité visibles
- `app/models/staff_unavailability.rb`

Critères d'acceptation:

- toute indisponibilité overlapping retire la portion concernée
- un staff totalement indisponible sur un intervalle n'apparaît pas comme libre

Non-objectifs:

- prise en compte des bookings bloquants
- agrégation publique des slots

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

- services métier de disponibilité visibles
- `app/services/bookings/schedule_resolver.rb`
- nouveau service dédié aux fenêtres staff visibles
- `app/models/service.rb`

Critères d'acceptation:

- une enseigne sans horaires propres n'est pas réservable
- un intervalle plus court que la durée du service n'est pas exploitable

Non-objectifs:

- prise en compte des bookings bloquants
- agrégation publique des slots
- retour au fallback `client_opening_hours`
- transformation de `ScheduleResolver` en moteur complet de disponibilité staff-based

Blocages / décisions déjà verrouillées:

- `enseigne_opening_hours` est la seule source opérationnelle d'ouverture
- `ScheduleResolver` reste limité aux horaires d'ouverture enseigne
- un service dédié porte les fenêtres visibles staff-based

Questions interdites au dev:

- "Peut-on fallback sur `client_opening_hours` ?" Non
- "Peut-on étendre `ScheduleResolver` pour gérer toute la disponibilité staff-based ?" Non

### E2-US5 - Intégrer les bookings bloquants dans la disponibilité visible par staff

Statut:

- Ready

But:

- exclure de la disponibilité staff les intervalles déjà bloqués par les bookings

Pourquoi:

- un staff ne peut pas être proposé sur un créneau déjà réservé ou temporairement verrouillé; aujourd'hui le code visible bloque encore au niveau enseigne

Entrées / dépendances:

- E2-US4

Changements attendus:

- introduire un filtrage des bookings bloquants par staff
- intégrer `confirmed` et `pending` actifs comme bookings bloquants
- ignorer les `pending` expirés

Zones du repo concernées:

- `app/services/bookings/available_slots.rb`
- `app/services/bookings/blocking_bookings.rb`
- services de lecture des bookings par staff
- `app/models/booking.rb`

Critères d'acceptation:

- un `confirmed` bloque le bon staff sur son intervalle
- un `pending` actif bloque le bon staff sur son intervalle
- un `pending` expiré ne bloque plus
- le blocage visible ne repose plus sur le périmètre global de l'enseigne

Non-objectifs:

- assignation de staff
- changement de l'orchestration transactionnelle de `create_pending`
- prolongation de `Resource.for_enseigne` comme abstraction de disponibilité visible

Blocages / décisions déjà verrouillées:

- le blocage temporaire reste porté par les `pending` actifs
- le visible staff-based ne doit pas réécrire à lui seul la logique de verrou transactionnel
- le moteur visible ne repose plus sur `Resource.for_enseigne`

Questions interdites au dev:

- "Peut-on ignorer les pending actifs dans la visibilité ?" Non
- "Peut-on conserver un blocage visible au niveau enseigne ?" Non
- "Peut-on continuer à utiliser `Resource.for_enseigne` pour le visible ?" Non

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
- tests de visibilité publique

Critères d'acceptation:

- un slot est visible si au moins un staff compatible est libre
- un slot disparaît uniquement si tous les staffs compatibles sont indisponibles ou bloqués
- aucune assignation staff n'est produite par la visibilité publique

Non-objectifs:

- création du pending
- orchestration round robin
- modification de `SlotDecision`

Blocages / décisions déjà verrouillées:

- la visibilité publique n'assigne jamais un staff
- l'agrégation visible ne doit pas dépendre d'un ordre de rotation
- l'agrégation visible repose sur les staffs éligibles et leurs fenêtres, pas sur une ressource enseigne implicite

Questions interdites au dev:

- "Peut-on choisir un staff dès l'affichage des slots ?" Non
- "Peut-on utiliser le round robin pour filtrer les slots visibles ?" Non

### E2-US7 - Réaligner les tests visibles sur le moteur staff-based

Statut:

- Ready

But:

- faire évoluer les tests de disponibilité visibles pour documenter le comportement staff-based réellement attendu

Pourquoi:

- les tests actuels de `AvailableSlots` et une partie des tests de `ScheduleResolver` documentent encore un moteur centré sur l'enseigne

Entrées / dépendances:

- E2-US1
- E2-US2
- E2-US3
- E2-US4
- E2-US5
- E2-US6

Changements attendus:

- réécrire les tests de visibilité pour exprimer:
  - exclusion des staffs inactifs
  - exclusion des staffs sans capability
  - prise en compte des disponibilités staff
  - prise en compte des indisponibilités staff
  - visibilité d'un slot si un seul staff compatible reste disponible
- supprimer les assertions de test qui supposent encore un blocage ou un calcul purement par enseigne

Zones du repo concernées:

- `test/services/bookings/available_slots_test.rb`
- `test/services/bookings/schedule_resolver_test.rb`
- tests de page publique liés aux slots si nécessaire

Critères d'acceptation:

- les tests de visibilité décrivent le moteur staff-based
- aucun test de visibilité active ne suppose encore `une enseigne = une ressource`

Non-objectifs:

- tests transactionnels de `create_pending`
- tests de round robin
- tests de `confirm`

Blocages / décisions déjà verrouillées:

- les tests visibles doivent documenter le moteur staff-based, pas un état transitoire

Questions interdites au dev:

- "Peut-on conserver les anciens tests enseigne-based parce qu'ils passent encore ?" Non

### Definition of Done Epic 2

- la disponibilité est calculée staff par staff
- la visibilité publique repose sur l'union des staffs éligibles
- aucune visibilité publique n'utilise une ressource implicite enseigne
- aucune visibilité publique n'assigne un staff
- le filtrage des bookings visibles est porté par le staff
- les tests de visibilité documentent explicitement le moteur staff-based

## Epic 3 - Assignation transactionnelle et round robin

Type:

- structurant

Statut après revue:

- Ready

Objectif:

- basculer l'orchestration transactionnelle de réservation du modèle `enseigne-based` vers un modèle `staff-based`, avec round robin explicite et sûreté sous concurrence

Risque principal:

- laisser au développeur des décisions implicites sur l'ordre exact des verrous, la revalidation transactionnelle et le point de sortie de `Resource.for_enseigne`

Dépendances:

- Epic 1
- Epic 2

Signal de fin:

- `create_pending` et `confirm` n'utilisent plus `Resource.for_enseigne` comme ressource transactionnelle
- `create_pending` et `confirm` suivent une orchestration staff-based non ambiguë
- le curseur de rotation n'avance qu'au `confirmed`
- l'anti-overlap `confirmed` par staff est garanti
- les tests transactionnels documentent explicitement le moteur staff-based

### E3-US1 - Formaliser l'usage transactionnel du curseur par service

Statut:

- Ready

But:

- disposer d'une source de vérité explicite pour la rotation transactionnelle d'un service à partir de `ServiceAssignmentCursor`

Pourquoi:

- le modèle du curseur existe déjà dans le repo, mais son rôle transactionnel doit être rendu explicite avant de brancher `create_pending` et `confirm`

Entrées / dépendances:

- Epic 1 terminé

Changements attendus:

- définir le curseur de rotation par `service` comme point d'entrée obligatoire de l'assignation
- définir son ordre initial déterministe
- définir le curseur comme un état basé sur `last_confirmed_staff_id`
- définir l'ordre déterministe des candidats comme `staff.id ASC` sur les staffs actifs et compatibles du service
- expliciter le comportement si aucun staff compatible n'a encore jamais été confirmé
- expliciter le comportement si le `last_confirmed_staff_id` n'est plus éligible

Zones du repo concernées:

- `app/models/service_assignment_cursor.rb`
- services métier d'assignation
- tests du curseur et de l'assignation

Critères d'acceptation:

- un service possède un état de rotation unique
- l'ordre initial ne dépend pas d'un comportement implicite en mémoire
- le contrat métier du curseur est exploitable sans arbitrage dans les services transactionnels
- le curseur repose sur `last_confirmed_staff_id`, pas sur un index mutable
- si `last_confirmed_staff_id` est `nil`, la rotation commence au premier staff éligible selon l'ordre déterministe
- si `last_confirmed_staff_id` n'est plus éligible, la rotation repart sur le premier staff éligible suivant avec wrap-around

Non-objectifs:

- lock
- création du pending

Blocages / décisions déjà verrouillées:

- la rotation n'est pas portée par `staff`
- la rotation n'est pas portée par un `current_index`
- le curseur stocke `last_confirmed_staff_id`
- l'ordre déterministe des candidats est `staff.id ASC` sur les staffs actifs et compatibles

Questions interdites au dev:

- "Peut-on utiliser `last_confirmed_assignment_at` sur staff comme source de vérité ?" Non
- "Peut-on utiliser un `current_index` comme source de vérité du round robin ?" Non

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
- remplacer la sérialisation transactionnelle portée par l'enseigne entière
- expliciter la frontière entre lock applicatif et contrainte DB

Zones du repo concernées:

- `app/services/bookings/slot_lock.rb` ou son remplaçant
- services d'assignation
- services de lock
- documentation technique du backlog

Critères d'acceptation:

- l'ordre des verrous est écrit et non interprétable
- la responsabilité du lock de rotation et du lock staff est distinguée
- la contrainte DB est présentée comme protection finale, pas comme orchestration primaire
- aucun verrou transactionnel critique ne reste porté par l'enseigne entière

Non-objectifs:

- implémentation du flow public

Blocages / décisions déjà verrouillées:

- lock rotation avant lock staff
- pas de fallback opportuniste hors ordre de rotation
- la granularité cible du verrou transactionnel est `service` puis `staff`, pas `enseigne`

Questions interdites au dev:

- "Peut-on locker directement un staff sans verrouiller la rotation ?" Non
- "Peut-on conserver `SlotLock` au niveau enseigne comme verrou principal ?" Non

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
- sortir `create_pending` d'une revalidation transactionnelle portée par `Resource.for_enseigne`

Zones du repo concernées:

- `app/services/bookings/create_pending.rb`
- `app/services/bookings/slot_decision.rb` ou son remplaçant transactionnel
- services d'assignation
- services de lock

Critères d'acceptation:

- `create_pending` crée un booking avec `staff_id`
- le pending est créé sur le premier candidat valide
- aucun autre ordre n'est utilisé
- aucun pending n'est créé sans staff assigné
- `create_pending` ne dépend plus d'une ressource transactionnelle globale par enseigne

Non-objectifs:

- avance du curseur
- réassignation au confirm

Blocages / décisions déjà verrouillées:

- le curseur n'avance pas au `pending`
- la revalidation transactionnelle doit être staff-based, pas enseigne-based
- l'ordre des candidats est dérivé de `last_confirmed_staff_id` puis de `staff.id ASC`

Questions interdites au dev:

- "Peut-on avancer la rotation lors de `create_pending` ?" Non
- "Peut-on continuer à déléguer la décision transactionnelle à `Resource.for_enseigne` ?" Non

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
- sortir `confirm` de la sérialisation transactionnelle au niveau enseigne
- limiter la revalidation de `confirm` au slot déjà réservé sur le `staff_id` assigné
- vérifier seulement:
  - que le booking est toujours `pending`
  - qu'il n'est pas expiré
  - que le `staff_id` existe encore et appartient à la bonne enseigne
  - qu'aucun autre booking bloquant ne prend ce slot sur ce même staff, en excluant le booking lui-même

Zones du repo concernées:

- `app/services/bookings/confirm.rb`
- `app/services/bookings/slot_decision.rb` ou son remplaçant transactionnel
- services d'assignation
- services de lock

Critères d'acceptation:

- `confirm` conserve le même `staff_id`
- aucun fallback vers un autre staff n'existe
- `confirm` ne dépend plus d'un verrou principal au niveau enseigne
- `confirm` échoue si le staff assigné a disparu ou n'appartient plus à la bonne enseigne
- `confirm` échoue si le slot n'est plus libre sur ce même staff
- `confirm` ne réévalue pas l'éligibilité complète du staff au sens visibilité/assignation

Non-objectifs:

- recherche d'un autre staff si le slot n'est plus valable
- réévaluation de `staff.active`
- réévaluation de la capability `staff <-> service`
- réévaluation des disponibilités hebdomadaires
- réévaluation des indisponibilités ponctuelles

Blocages / décisions déjà verrouillées:

- pas de réassignation au `confirm`
- le `pending` déjà créé matérialise déjà la réservation temporaire du staff
- `confirm` applique une revalidation minimale de conflit et d'intégrité, pas une recomposition complète d'éligibilité

Questions interdites au dev:

- "Peut-on essayer un autre staff si celui du pending n'est plus disponible ?" Non
- "Faut-il réévaluer `staff.active`, capability ou disponibilité staff au `confirm` ?" Non

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

- `app/services/bookings/confirm.rb`
- services d'assignation
- services de confirmation
- modèle du curseur

Critères d'acceptation:

- le curseur n'avance jamais sur `pending`
- le curseur n'avance jamais sur expiration ou échec
- le curseur avance dans la même transaction que le `confirmed`
- la mise à jour du curseur reflète le staff effectivement confirmé

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
- mettre à jour le mapping d'erreurs applicatif vers la nouvelle contrainte

Zones du repo concernées:

- `db/migrate`
- `db/structure.sql`
- `app/services/bookings/errors.rb`
- tests d'infrastructure DB et tests modèle liés aux conflits `confirmed`

Critères d'acceptation:

- deux `confirmed` overlapping sont refusés sur un même staff
- deux `confirmed` overlapping restent autorisés sur deux staffs distincts
- la protection critique existe côté DB
- les erreurs applicatives reconnaissent la nouvelle contrainte

Non-objectifs:

- blocage des pending actifs

Blocages / décisions déjà verrouillées:

- la contrainte DB protège uniquement l'invariant confirmed

Questions interdites au dev:

- "La contrainte DB suffit-elle pour piloter toute l'orchestration ?" Non

### E3-US7 - Réaligner les tests transactionnels sur l'assignation staff-based

Statut:

- Ready

But:

- faire évoluer les tests transactionnels pour documenter explicitement le moteur staff-based de `create_pending` et `confirm`

Pourquoi:

- le repo contient déjà des tests transactionnels centrés sur `Resource.for_enseigne`, la revalidation par enseigne et l'ancienne protection `confirmed`

Entrées / dépendances:

- E3-US2
- E3-US3
- E3-US4
- E3-US5
- E3-US6

Changements attendus:

- réécrire les tests transactionnels pour exprimer:
  - assignation d'un `staff_id` au `create_pending`
  - conservation du même `staff_id` au `confirm`
  - absence de réassignation au `confirm`
  - usage du round robin uniquement dans le transactionnel
  - refus d'un conflit `confirmed` sur le même staff
  - acceptation de deux `confirmed` overlapping sur deux staffs distincts
- supprimer les assertions de test qui supposent encore:
  - un verrou principal au niveau enseigne
  - une ressource transactionnelle `Resource.for_enseigne`
  - une protection finale `confirmed` portée par l'enseigne

Zones du repo concernées:

- `test/services/bookings/create_pending_test.rb`
- `test/services/bookings/confirm_test.rb`
- `test/services/bookings/slot_decision_test.rb`
- `test/services/bookings/errors_test.rb`
- `test/models/booking_test.rb`
- tests d'infrastructure DB liés aux contraintes de conflit `confirmed`

Critères d'acceptation:

- les tests transactionnels décrivent l'orchestration staff-based réellement attendue
- aucun test transactionnel actif ne documente encore un verrou principal par enseigne
- aucun test transactionnel actif ne documente encore `Resource.for_enseigne` comme ressource de réservation

Non-objectifs:

- tests de visibilité publique déjà couverts par l'Epic 2
- tests d'UI publique du flow complet

Blocages / décisions déjà verrouillées:

- les tests transactionnels doivent documenter le moteur cible, pas un état de transition

Questions interdites au dev:

- "Peut-on conserver les anciens tests enseigne-based parce qu'ils passent encore ?" Non

### Definition of Done Epic 3

- la rotation est explicite et non ambiguë
- l'ordre des verrous est fixé
- `create_pending` et `confirm` n'utilisent plus `Resource.for_enseigne` comme ressource transactionnelle
- `create_pending` et `confirm` n'ont plus d'arbitrage implicite
- l'anti-overlap `confirmed` par staff est garanti
- les tests transactionnels documentent explicitement le moteur staff-based

## Epic 4 - Flow public staff-based

Type:

- branchable

Statut après revue:

- Implémentée

Objectif:

- rebrancher le flow public existant sur le noyau staff-based

Risque principal:

- réintroduire plus tard un contrat public hybride alors que le flow est déjà branché sur le noyau staff-based

Dépendances:

- Epic 2
- Epic 3

Signal de fin:

- le parcours public fonctionne de bout en bout sur le nouveau noyau
- les contrats publics utiles restent stables
- les tests contrôleur et d'intégration documentent déjà ce flow public staff-based

### E4-US1 - Charger les services publics depuis l'enseigne

Statut:

- Implémentée

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
- ce comportement est couvert par le runtime actuel et les tests publics

Non-objectifs:

- calcul des slots
- création du pending

Blocages / décisions déjà verrouillées:

- pas de catalogue global client dans le flow public

Questions interdites au dev:

- "Peut-on garder une liste globale client puis filtrer ensuite ?" Non

### E4-US2 - Afficher les slots publics depuis l'union des staffs éligibles

Statut:

- Implémentée

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
- ce branchement est déjà effectif dans `PublicPage` et le moteur visible

Non-objectifs:

- création du pending

Blocages / décisions déjà verrouillées:

- la visibilité publique ne choisit jamais de staff

Questions interdites au dev:

- "Peut-on exposer le staff à ce stade ?" Non

### E4-US3 - Créer le pending staff-based sans changer le contrat public

Statut:

- Implémentée

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
- ce comportement est déjà couvert par les tests contrôleur et d'intégration du flow

Non-objectifs:

- affichage du staff

Blocages / décisions déjà verrouillées:

- le staff reste interne

Questions interdites au dev:

- "Peut-on changer la structure publique du flow pour refléter le staff ?" Non

### E4-US4 - Conserver un confirm/success sans exposition du staff

Statut:

- Implémentée

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
- ce comportement est déjà couvert par les vues, redirects et tests d'intégration

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
- l'epic est considérée livrée; les éventuels ajustements futurs relèvent d'une correction ciblée ou du nettoyage final, pas d'une refonte supplémentaire du flow public

## Epic 5 - Nettoyage final complet

Type:

- cleanup

Statut après revue:

- Ready

Objectif:

- supprimer le code mort, les reliquats de schéma et la documentation intermédiaire qui subsistent après la bascule effective du moteur staff-based

Risque principal:

- laisser survivre des services morts, des tests historiques et un socle DB hybride alors que le runtime principal est déjà staff-based

Dépendances:

- Epic 4

Signal de fin:

- runtime propre
- tests et seeds propres
- socle DB propre
- docs propres
- aucun artefact mort ne documente encore `enseigne` comme ressource réservable
- `db/schema.rb` et `db/structure.sql` sont réalignés sur le socle final

### E5-US1 - Supprimer les artefacts runtime morts de l'ancien noyau

Statut:

- Ready

But:

- retirer les services et branches mortes encore construits autour de `enseigne` comme ressource réservable

Pourquoi:

- le runtime principal a déjà basculé; il reste surtout du code mort et des commentaires faux qui entretiennent une dette de lecture

Entrées / dépendances:

- Epic 4 terminé

Changements attendus:

- supprimer `Bookings::Resource` s'il n'a plus d'usage métier utile
- supprimer `Bookings::BlockingBookings` s'il n'a plus d'usage métier utile
- supprimer `Bookings::SlotDecision` s'il n'a plus d'usage métier utile
- supprimer `SlotLock.with_resource_lock` s'il n'a plus d'usage métier utile
- supprimer les commentaires de transition devenus faux dans les modèles et services encore conservés

Zones du repo concernées:

- `app/services/bookings/resource.rb`
- `app/services/bookings/blocking_bookings.rb`
- `app/services/bookings/slot_decision.rb`
- `app/services/bookings/slot_lock.rb`
- `app/models/booking.rb`

Critères d'acceptation:

- aucun service runtime actif ne suppose encore `une enseigne = une ressource`
- aucun service runtime actif n'utilise `Resource.for_enseigne`
- aucun service runtime actif n'utilise `SlotLock.with_resource_lock`
- aucun commentaire actif ne décrit encore le moteur courant comme transitoire vers le staff-based

Non-objectifs:

- nettoyage DB historique

Blocages / décisions déjà verrouillées:

- aucun dual-run runtime

Questions interdites au dev:

- "Peut-on conserver une branche de compatibilité `enseigne-based` ?" Non

### E5-US2 - Supprimer physiquement `client_opening_hours`

Statut:

- Ready

But:

- éliminer totalement `client_opening_hours` du code, des tests et du socle DB final

Pourquoi:

- le runtime n'en dépend déjà plus; il reste maintenant à supprimer la notion du projet lui-même

Entrées / dépendances:

- E5-US1

Changements attendus:

- supprimer l'association `client_opening_hours` de `Client`
- supprimer le modèle, les tests et helpers qui construisent encore `client_opening_hours`
- supprimer la table, ses contraintes, ses indexes et les migrations historiques si le socle DB est régénéré
- supprimer les tests de migration/infrastructure spécifiques à `client_opening_hours`

Zones du repo concernées:

- `app/models/client.rb`
- tests liés aux opening hours
- `db/migrate`
- `db/schema.rb`
- `db/structure.sql`

Critères d'acceptation:

- aucun modèle actif ne référence `client_opening_hours`
- aucun test actif ne construit `client_opening_hours`
- aucun seed actif ne construit `client_opening_hours`
- `db/schema.rb` et `db/structure.sql` n'incluent plus `client_opening_hours`

Non-objectifs:

- nettoyage des docs

Blocages / décisions déjà verrouillées:

- `client_opening_hours` sort complètement du socle cible

Questions interdites au dev:

- "Peut-on garder la table en archive dans le schéma final ?" Non

### E5-US3 - Clôturer définitivement le modèle de service global client

Statut:

- Ready

But:

- supprimer les derniers reliquats qui pourraient encore laisser croire à un catalogue global au niveau client

Pourquoi:

- le runtime principal a déjà basculé; il faut maintenant empêcher tout retour implicite du modèle `client.services`

Entrées / dépendances:

- E5-US1

Changements attendus:

- supprimer les helpers, tests ou commentaires qui parlent encore de `client.services`
- supprimer les reliquats de docs techniques ou de code qui suggèrent un service porté par `Client`
- vérifier que le socle final n'expose plus aucun raccourci ou reliquat de lecture vers un catalogue client

Zones du repo concernées:

- `app/models/client.rb`
- `app/models/service.rb`
- tests domaine et flow public
- docs techniques et backlog si nécessaire

Critères d'acceptation:

- aucune logique métier n'utilise `client.services`
- les tests actifs créent les services via l'enseigne
- les seeds actifs créent les services via l'enseigne
- aucune doc active ne présente encore `Service` comme une entité portée par `Client`

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
- supprimer les tests portant uniquement sur des services morts ou des artefacts historiques supprimés
- supprimer les docs de tickets intermédiaires si elles ne décrivent plus un état utile

Zones du repo concernées:

- `test/`
- `db/seeds.rb`
- helpers liés au flow public
- `docs/tickets_technique_epic_*.md`

Critères d'acceptation:

- aucun test ne documente encore un comportement désormais interdit
- aucun helper de test ne reconstruit l'ancien modèle
- aucun seed ne reconstruit l'ancien modèle
- aucun test actif ne cible uniquement `Resource`, `BlockingBookings`, `SlotDecision` ou `client_opening_hours` si ces artefacts ont été supprimés

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
- réaligner `db/schema.rb` et `db/structure.sql` sur le même socle final
- supprimer les reliquats de l'ancien overlap `confirmed` par enseigne

Zones du repo concernées:

- `db/migrate`
- `db/structure.sql`
- `db/schema.rb`

Critères d'acceptation:

- la base peut être reconstruite proprement à partir du nouveau socle
- le schéma final ne contient plus d'artefacts de l'ancien modèle
- `db/structure.sql` reflète uniquement le modèle cible
- `db/schema.rb` ne contient plus `client_opening_hours`
- `db/schema.rb` ne contient plus `index_bookings_on_enseigne_and_start_time_confirmed`
- les contraintes et indexes legacy `confirmed by enseigne` ont disparu du socle final

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
- supprimer ou archiver clairement les documents intermédiaires qui décrivent un état de transition déjà dépassé

Zones du repo concernées:

- `docs/`
- README si nécessaire

Critères d'acceptation:

- les docs actives décrivent uniquement le socle cible
- aucune doc active ne décrit encore `client.services` ou `client_opening_hours` comme runtime métier
- aucune doc active ne décrit encore `Resource.for_enseigne` ou une ressource réservable implicite par enseigne comme moteur courant

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
- aucun artefact actif ou mort n'entretient encore l'ancien noyau `enseigne-based`

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

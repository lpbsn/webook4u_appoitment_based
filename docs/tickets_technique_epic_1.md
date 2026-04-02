## Analyse rapide de la spécification
- Objectif principal : poser un socle `staff-based` exploitable sans attendre la disponibilité et l’assignation finales.
- Ce que la spécification cherche à obtenir : schéma cible, invariants DB, retrait du runtime critique `client.services` / `client_opening_hours`, rebranchement minimal du flow existant, puis réalignement seeds/tests.
- Points flous ou discutables : les zones floues initiales sont désormais bien verrouillées. `E1-US5` est correctement ramenée à une décision cible. `E1-US11` est maintenant suffisamment bornée.
- Incohérences potentielles avec le repository : le repo réel reste encore ancré sur `client.services` dans [public_page.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/public_page.rb) et [bookings_controller.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/controllers/bookings_controller.rb), et sur `client_opening_hours` dans [schedule_resolver.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/schedule_resolver.rb).
- Hypothèses retenues : `bookings.staff_id` reste nullable dans Epic 1, la contrainte finale `confirmed by staff` n’est pas implémentée ici, la suppression physique des reliquats historiques est renvoyée à l’Epic 5.
- Zones du repository probablement concernées : [service.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/service.rb), [booking.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/booking.rb), [client.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/client.rb), [public_page.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/public_page.rb), [schedule_resolver.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/schedule_resolver.rb), [bookings_controller.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/controllers/bookings_controller.rb), [db/seeds.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/seeds.rb), [test/test_helper.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/test/test_helper.rb), tests critiques et migrations DB.

## Stratégie de découpage
- Logique de découpage choisie : un ticket par US, car l’Epic 1 est désormais assez bien découpée pour être exécutée sans re-split supplémentaire.
- Dépendances principales : schéma `Staff*` avant `Booking.staff_id`, `Service -> Enseigne` avant retrait runtime `client.services`, retrait runtime avant seeds/helpers/tests.
- Ordre recommandé d’implémentation : 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11.
- Ce qui doit être traité maintenant vs plus tard : maintenant, le socle, les invariants et le runtime minimal. Plus tard, disponibilité staff-based, round robin, assignation transactionnelle, flow public final, cleanup physique complet.

## Tickets techniques

### Ticket 1
- Titre : Introduire les entités staff-based du domaine
- Objectif : créer le socle `Staff`, `StaffAvailability`, `StaffUnavailability`, `StaffServiceCapability`, `ServiceAssignmentCursor`
- Partie de la spécification couverte : E1-US1
- Problème résolu : le domaine actuel ne sait pas exprimer une ressource réservable explicite ni ses dépendances métier
- Périmètre exact : créer les tables, modèles et associations de base autour de `Staff`, sans brancher le runtime existant
- Hors périmètre : `Service -> Enseigne`, disponibilité calculée, round robin, flow public
- Pourquoi ce ticket est séparé : tout le reste de l’Epic dépend de ce socle de schéma
- Composants potentiellement concernés : `app/models/staff*.rb`, [service.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/service.rb), [enseigne.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/enseigne.rb), `db/migrate`, [db/structure.sql](/Users/leobsn/Desktop/webook4u_appoitment_based/db/structure.sql)
- Comportement attendu : le schéma sait exprimer `Enseigne -> Staff`, `Staff -> Availability`, `Staff -> Unavailability`, `Staff <-> Service`, `Service -> AssignmentCursor`
- Critères d’acceptation : les 5 entités existent, leurs associations sont explicites, aucune capability implicite n’est introduite
- Dépendances : aucune
- Risques / points de vigilance : ne pas glisser vers une implémentation runtime prématurée
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 2
- Titre : Rattacher `Service` à `Enseigne`
- Objectif : basculer le contrat métier `Service` d’un niveau client à un niveau enseigne
- Partie de la spécification couverte : E1-US2
- Problème résolu : le repo porte encore un catalogue global `client.services` incompatible avec la cible
- Périmètre exact : ajouter `services.enseigne_id`, basculer les associations modèle, sortir `services.client_id` du contrat métier
- Hors périmètre : affichage public final, suppression physique immédiate de tous les reliquats DB
- Pourquoi ce ticket est séparé : c’est le changement de propriété métier le plus structurant de l’Epic
- Composants potentiellement concernés : [service.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/service.rb), [client.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/client.rb), [enseigne.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/enseigne.rb), `db/migrate`, [db/seeds.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/seeds.rb)
- Comportement attendu : un service n’existe que dans une enseigne
- Critères d’acceptation : le schéma porte `Service -> Enseigne`, plus aucune lecture métier critique n’a besoin de `client.services`
- Dépendances : Ticket 1
- Risques / points de vigilance : ne pas conserver un modèle hybride durable `Client + Enseigne`
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 3
- Titre : Ajouter `staff_id` sur `Booking` en nullable transitoire
- Objectif : préparer `Booking` à porter explicitement la future ressource staff
- Partie de la spécification couverte : E1-US3
- Problème résolu : `Booking` ne référence encore que `client / enseigne / service`
- Périmètre exact : ajouter `bookings.staff_id`, l’association modèle, et exposer cette relation dans le contrat du modèle sans la rendre obligatoire
- Hors périmètre : `NOT NULL`, create_pending staff-based, confirm staff-based
- Pourquoi ce ticket est séparé : il prépare l’Epic 3 sans casser l’état transitoire du repo
- Composants potentiellement concernés : [booking.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/booking.rb), `app/models/staff.rb`, `db/migrate`, [db/structure.sql](/Users/leobsn/Desktop/webook4u_appoitment_based/db/structure.sql)
- Comportement attendu : un booking peut référencer un staff, mais ce n’est pas encore imposé
- Critères d’acceptation : `bookings.staff_id` existe, `Booking` expose la relation, la nullabilité transitoire est explicite
- Dépendances : Ticket 1
- Risques / points de vigilance : ne pas faire croire que l’assignation staff existe déjà
- Priorité : P1
- Complexité estimée : Faible

### Ticket 4
- Titre : Poser les invariants DB critiques de cohérence métier
- Objectif : garantir en DB la cohérence entre `booking`, `service`, `staff`, `enseigne` et `client`
- Partie de la spécification couverte : E1-US4
- Problème résolu : les validations Rails actuelles ne suffisent pas à protéger le cœur métier
- Périmètre exact : ajouter triggers/contraintes DB empêchant les incohérences inter-table, et réaligner le modèle Rails sur ce contrat
- Hors périmètre : disponibilité, round robin, overlap final `confirmed by staff`
- Pourquoi ce ticket est séparé : c’est le ticket de garde-fous critiques avant toute réécriture du moteur
- Composants potentiellement concernés : [booking.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/booking.rb), `db/migrate`, [db/structure.sql](/Users/leobsn/Desktop/webook4u_appoitment_based/db/structure.sql), tests d’infrastructure DB
- Comportement attendu : la base refuse un booking incohérent avec son client, son enseigne, son service et, si présent, son staff
- Critères d’acceptation : un booking ne peut pas pointer vers un service d’une autre enseigne, ni vers un staff d’une autre enseigne, ni casser la cohérence client/enseigne
- Dépendances : Tickets 2 et 3
- Risques / points de vigilance : réutiliser le pattern SQL déjà présent dans le repo, pas des validations Rails seulement
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 5
- Titre : Verrouiller la cible DB finale `confirmed by staff`
- Objectif : fixer explicitement que la protection finale d’overlap confirmé sera portée par `staff_id + interval`
- Partie de la spécification couverte : E1-US5
- Problème résolu : le repo et la doc pouvaient encore laisser croire que la cible finale restait `confirmed by enseigne`
- Périmètre exact : verrouiller la décision dans le backlog et la doc de refonte, sans implémenter la contrainte finale
- Hors périmètre : mise en place effective de la contrainte finale, round robin, verrous applicatifs
- Pourquoi ce ticket est séparé : c’est un ticket de décision produit/architecture, pas d’implémentation moteur
- Composants potentiellement concernés : [backlog_refonte_staff-based_webook4u.md](/Users/leobsn/Desktop/webook4u_appoitment_based/docs/backlog_refonte_staff-based_webook4u.md), [refonte_staff-based_webook4u.md](/Users/leobsn/Desktop/webook4u_appoitment_based/docs/refonte_staff-based_webook4u.md)
- Comportement attendu : plus aucun artefact de cadrage n’indique que la cible finale est encore portée par l’enseigne
- Critères d’acceptation : la cible `confirmed by staff` est explicitée, et l’Epic 1 indique clairement qu’elle n’est pas encore implémentée
- Dépendances : Tickets 3 et 4
- Risques / points de vigilance : ne pas transformer ce ticket en pseudo-implémentation
- Priorité : P2
- Complexité estimée : Faible

### Ticket 6
- Titre : Retirer `client.services` du contrat métier runtime
- Objectif : supprimer toute lecture runtime critique de `client.services`
- Partie de la spécification couverte : E1-US6
- Problème résolu : le runtime critique reste basé sur un catalogue service au niveau client
- Périmètre exact : retirer les lectures critiques de `client.services` et réaligner le runtime minimal sur `enseigne.services`
- Hors périmètre : suppression physique finale des anciens artefacts
- Pourquoi ce ticket est séparé : c’est un retrait de contrat métier runtime, distinct du changement de schéma
- Composants potentiellement concernés : [client.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/client.rb), [public_page.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/public_page.rb), [bookings_controller.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/controllers/bookings_controller.rb), [db/seeds.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/seeds.rb)
- Comportement attendu : le runtime critique charge les services à partir de l’enseigne, pas du client
- Critères d’acceptation : aucune logique runtime critique n’utilise encore `client.services`
- Dépendances : Ticket 2
- Risques / points de vigilance : plusieurs tests et validations historiques restent encore centrés sur `client.services`
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 7
- Titre : Retirer `client_opening_hours` du contrat métier runtime
- Objectif : supprimer le fallback métier vers `client_opening_hours`
- Partie de la spécification couverte : E1-US7
- Problème résolu : le moteur continue à considérer `client_opening_hours` comme source d’ouverture de secours
- Périmètre exact : retirer le fallback runtime et réaligner le contrat sur `enseigne_opening_hours` uniquement
- Hors périmètre : suppression physique de la table
- Pourquoi ce ticket est séparé : c’est un second retrait de contrat runtime, indépendant du catalogue service
- Composants potentiellement concernés : [schedule_resolver.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/schedule_resolver.rb), [client.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/client.rb), [db/seeds.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/seeds.rb)
- Comportement attendu : une enseigne sans horaires propres est non réservable
- Critères d’acceptation : aucune logique runtime critique n’utilise encore `client_opening_hours`
- Dépendances : Ticket 1
- Risques / points de vigilance : le repo contient encore des tests qui documentent explicitement l’ancien fallback
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 8
- Titre : Rebrancher minimalement le runtime critique sur le nouveau contrat
- Objectif : maintenir un repo cohérent entre l’Epic 1 et l’Epic 4
- Partie de la spécification couverte : E1-US8
- Problème résolu : retirer les anciens contrats sans rebranchement casserait le flow public existant
- Périmètre exact : rebrancher le runtime critique sur `enseigne.services` et `enseigne_opening_hours`, sans implémenter encore la logique staff-based finale
- Hors périmètre : disponibilité staff-based finale, round robin, flow final
- Pourquoi ce ticket est séparé : c’est un ticket d’intégration minimal, distinct des retraits de contrat
- Composants potentiellement concernés : [public_page.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/public_page.rb), [bookings_controller.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/controllers/bookings_controller.rb), [schedule_resolver.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/schedule_resolver.rb)
- Comportement attendu : le flow critique reste cohérent sans réintroduire de modèle hybride
- Critères d’acceptation : le runtime critique n’utilise plus `client.services` ni `client_opening_hours`, et le repo reste exploitable
- Dépendances : Tickets 2, 6 et 7
- Risques / points de vigilance : ne pas laisser de bricolage transitoire durable
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 9
- Titre : Refaire les seeds de base sur le modèle cible
- Objectif : reconstruire les seeds sur `Enseigne -> Service -> Staff`
- Partie de la spécification couverte : E1-US9
- Problème résolu : les seeds actuelles recréent l’ancien modèle et ses contrats interdits
- Périmètre exact : réécrire uniquement [db/seeds.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/seeds.rb) sur le modèle cible
- Hors périmètre : helpers de test, réécriture des tests
- Pourquoi ce ticket est séparé : les seeds doivent pouvoir évoluer indépendamment des helpers et des tests
- Composants potentiellement concernés : [db/seeds.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/seeds.rb)
- Comportement attendu : les seeds ne créent plus de services au niveau client ni de `client_opening_hours`
- Critères d’acceptation : les seeds reconstruisent uniquement le modèle cible
- Dépendances : Tickets 2, 3, 6, 7 et 8
- Risques / points de vigilance : ne pas embarquer des besoins de test dans ce ticket
- Priorité : P2
- Complexité estimée : Faible

### Ticket 10
- Titre : Refaire les helpers de test de base sur le modèle cible
- Objectif : réécrire les helpers de test pour enseigner le nouveau contrat minimal
- Partie de la spécification couverte : E1-US10
- Problème résolu : les helpers de base injectent encore partout `client.services` et `client_opening_hours`
- Périmètre exact : réécrire [test/test_helper.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/test/test_helper.rb) et les helpers/factories de base concernés
- Hors périmètre : correction complète des tests métier
- Pourquoi ce ticket est séparé : le bootstrap test de base doit être stabilisé avant la correction ciblée des tests bloquants
- Composants potentiellement concernés : [test/test_helper.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/test/test_helper.rb), helpers/factories de base
- Comportement attendu : les helpers de base construisent directement `Enseigne -> Service -> Staff`
- Critères d’acceptation : les helpers ne créent plus de services au niveau client, ni de `client_opening_hours`, et permettent de construire le socle minimal cible
- Dépendances : Tickets 2, 3, 6, 7 et 8
- Risques / points de vigilance : éviter de conserver des helpers historiques “pour compatibilité”
- Priorité : P2
- Complexité estimée : Faible

### Ticket 11
- Titre : Corriger les tests bloquants du sous-ensemble critique Epic 1
- Objectif : réaligner uniquement les tests structurants nécessaires pour démarrer sur le nouveau socle
- Partie de la spécification couverte : E1-US11
- Problème résolu : un sous-ensemble critique de tests reste bloquant à cause de l’ancien contrat
- Périmètre exact : corriger uniquement `PublicPage`, `BookingsController`, `ScheduleResolver`, `booking_flow`, et les helpers/tests de base qui créent encore `client.services` ou `client_opening_hours`
- Hors périmètre : tous les autres tests cassés, nettoyage complet de la suite
- Pourquoi ce ticket est séparé : il borne strictement l’impact diffus de l’ancien modèle sans transformer la story en chantier illimité
- Composants potentiellement concernés : tests `PublicPage`, `BookingsController`, `ScheduleResolver`, `booking_flow`, helpers/tests de base ciblés
- Comportement attendu : ce sous-ensemble critique démarre sur le nouveau contrat minimal
- Critères d’acceptation : seuls les tests du sous-ensemble critique sont réalignés, les autres tests cassés restent explicitement hors story
- Dépendances : Tickets 9 et 10
- Risques / points de vigilance : interdiction d’élargir la story pendant le dev
- Priorité : P1
- Complexité estimée : Moyenne

## Recommandation finale
- Tickets à traiter en premier : 1, 2, 3, 4, 6, 7, 8.
- Tickets à regrouper éventuellement : 1 avec 3 si tu veux livrer le socle `Staff` et `Booking.staff_id` ensemble. 9 avec 10 si tu veux un seul ticket “bootstrap dev/test”.
- Tickets à ne pas créer : un ticket “rendre `staff_id` obligatoire” dans Epic 1, un ticket “implémenter la contrainte finale `confirmed by staff`” dans Epic 1, un ticket “supprimer physiquement `client_opening_hours`” dans Epic 1.
- Parties de la spécification à simplifier : aucune simplification critique à ce stade. Le cadrage est désormais suffisant.
- Risques de mauvais découpage à éviter : mélanger retrait de contrat runtime et suppression physique finale, laisser `E1-US11` déborder hors du sous-ensemble critique, transformer `E1-US5` en faux ticket d’implémentation.

Priorisation agile recommandée :
1. P1 immédiat : Tickets 1, 2, 3, 4, 6, 7, 8, 11
2. P2 ensuite : Tickets 5, 9, 10
3. Séquence de livraison conseillée : `1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9 -> 10 -> 11`
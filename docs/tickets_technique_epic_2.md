## Analyse rapide de la spécification
- Objectif principal : remplacer la visibilité publique `enseigne-based` par une visibilité `staff-based`, sans assigner de staff à ce stade.
- Ce que la spécification cherche à obtenir : un moteur visible fondé sur les staffs éligibles, leurs disponibilités réelles, les horaires d’ouverture de l’enseigne, la durée du service et les bookings bloquants par staff.
- Points flous ou discutables : les derniers verrouillages ont supprimé les deux ambiguïtés principales. `ScheduleResolver` reste borné aux horaires d’ouverture enseigne. Le moteur visible ne doit plus dépendre de `Resource.for_enseigne`.
- Incohérences potentielles avec le repository : le visible actuel reste encore centré sur l’enseigne dans [available_slots.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/available_slots.rb#L13), [blocking_bookings.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/blocking_bookings.rb#L15) et [resource.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/resource.rb#L5).
- Hypothèses retenues : Epic 1 est considéré terminé; le moteur visible staff-based peut introduire un ou plusieurs nouveaux services dédiés; `SlotDecision`, `CreatePending` et `Confirm` restent hors scope Epic 2.
- Zones du repository probablement concernées : [available_slots.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/available_slots.rb), [blocking_bookings.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/blocking_bookings.rb), [schedule_resolver.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/schedule_resolver.rb), [public_page.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/public_page.rb), [staff.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/staff.rb), [staff_availability.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/staff_availability.rb), [staff_unavailability.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/staff_unavailability.rb), [available_slots_test.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/test/services/bookings/available_slots_test.rb), [schedule_resolver_test.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/test/services/bookings/schedule_resolver_test.rb).

## Stratégie de découpage
- Logique de découpage choisie : un ticket par US. L’Epic 2 est désormais assez verrouillée pour éviter un re-split supplémentaire.
- Dépendances principales : résolution des staffs éligibles avant fenêtres staff; fenêtres staff avant retrait des indisponibilités; intersections avant blocages; blocages avant agrégation visible; tests en dernier.
- Ordre recommandé d’implémentation : 1. US1, 2. US2, 3. US3, 4. US4, 5. US5, 6. US6, 7. US7.
- Ce qui doit être traité maintenant vs plus tard : maintenant, le moteur visible staff-based; plus tard, assignation transactionnelle, round robin, `create_pending`, `confirm`, contrainte finale `confirmed by staff`.

## Tickets techniques

### Ticket 1
- Titre : Résoudre explicitement les staffs éligibles d’un service
- Objectif : introduire la résolution des staffs candidats à partir du service et de l’enseigne.
- Partie de la spécification couverte : E2-US1
- Problème résolu : le moteur visible ne peut pas rester basé sur une ressource implicite enseigne.
- Périmètre exact : créer un service métier dédié qui retourne les staffs éligibles d’un service, en excluant les staffs inactifs et sans capability.
- Hors périmètre : calcul des créneaux, bookings bloquants, assignation.
- Pourquoi ce ticket est séparé : c’est le point d’entrée de tout le calcul staff-based.
- Composants potentiellement concernés : [staff.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/staff.rb), `app/models/staff_service_capability.rb`, [service.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/service.rb), services visibles de réservation
- Comportement attendu : pour un service donné, seuls les staffs de la bonne enseigne, actifs et explicitement compatibles sont retenus.
- Critères d’acceptation : aucun staff inactif n’est retenu; aucun staff sans capability n’est retenu; aucun staff d’une autre enseigne n’est retenu.
- Dépendances : Epic 1 terminé
- Risques / points de vigilance : ne pas réintroduire de compatibilité implicite “tous les staffs de l’enseigne”.
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 2
- Titre : Calculer les fenêtres hebdomadaires de disponibilité d’un staff
- Objectif : produire les fenêtres de base d’un staff pour une journée donnée.
- Partie de la spécification couverte : E2-US2
- Problème résolu : le repo n’a pas encore de calcul dédié pour convertir les disponibilités hebdomadaires staff en fenêtres exploitables.
- Périmètre exact : créer un service dédié de disponibilité hebdomadaire staff, indépendant des indisponibilités ponctuelles, des bookings et de l’agrégation visible.
- Hors périmètre : indisponibilités ponctuelles, horaires enseigne, bookings, slots visibles.
- Pourquoi ce ticket est séparé : il isole une source métier autonome et réutilisable.
- Composants potentiellement concernés : `app/models/staff_availability.rb`, services visibles staff-based
- Comportement attendu : un staff sans disponibilités exploitables ne produit aucune fenêtre pour la journée.
- Critères d’acceptation : la disponibilité hebdomadaire staff est calculable indépendamment; `ScheduleResolver` n’est pas détourné pour gérer cette logique.
- Dépendances : Ticket 1
- Risques / points de vigilance : ne pas faire de `ScheduleResolver` le moteur central de disponibilité staff.
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 3
- Titre : Retrancher les indisponibilités ponctuelles des fenêtres staff
- Objectif : produire la disponibilité réelle d’un staff avant prise en compte des bookings.
- Partie de la spécification couverte : E2-US3
- Problème résolu : les absences ponctuelles ne sont pas encore déduites du calendrier staff.
- Périmètre exact : appliquer les `StaffUnavailability` sur les fenêtres issues du ticket précédent.
- Hors périmètre : bookings bloquants, agrégation visible.
- Pourquoi ce ticket est séparé : il complète le calcul staff sans le mélanger au reste du moteur visible.
- Composants potentiellement concernés : `app/models/staff_unavailability.rb`, services visibles staff-based
- Comportement attendu : toute indisponibilité overlapping retire la portion concernée; un staff totalement couvert devient indisponible.
- Critères d’acceptation : une indisponibilité partielle tronque la fenêtre; une indisponibilité totale supprime la fenêtre exploitable.
- Dépendances : Ticket 2
- Risques / points de vigilance : ne pas fusionner disponibilité hebdomadaire et indisponibilité dans un seul objet opaque.
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 4
- Titre : Construire les fenêtres visibles staff-based à partir des horaires enseigne et de la durée du service
- Objectif : intersecter le cadre d’ouverture de l’enseigne avec la disponibilité réelle du staff et la durée du service.
- Partie de la spécification couverte : E2-US4
- Problème résolu : le moteur visible n’a pas encore de couche explicite “fenêtres réservables par staff avant bookings”.
- Périmètre exact : conserver [schedule_resolver.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/schedule_resolver.rb) pour les seuls horaires d’ouverture enseigne, et introduire un nouveau service dédié qui intersecte ces horaires avec les fenêtres staff et la durée du service.
- Hors périmètre : bookings bloquants, agrégation multi-staff, fallback `client_opening_hours`.
- Pourquoi ce ticket est séparé : il verrouille la frontière entre `ScheduleResolver` et le nouveau moteur visible staff-based.
- Composants potentiellement concernés : [schedule_resolver.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/schedule_resolver.rb), nouveau service visible staff-based, [service.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/service.rb)
- Comportement attendu : une enseigne sans horaires propres n’est pas réservable; une fenêtre plus courte que la durée du service est écartée.
- Critères d’acceptation : `ScheduleResolver` reste limité aux horaires enseigne; le nouveau service porte explicitement les fenêtres visibles staff-based.
- Dépendances : Tickets 2 et 3
- Risques / points de vigilance : ne pas étendre `ScheduleResolver` au-delà de son rôle verrouillé.
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 5
- Titre : Filtrer les bookings bloquants au niveau staff pour la visibilité
- Objectif : appliquer les bookings `confirmed` et `pending` actifs sur chaque staff visible.
- Partie de la spécification couverte : E2-US5
- Problème résolu : le visible actuel bloque encore au niveau enseigne via [resource.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/resource.rb#L5).
- Périmètre exact : introduire une lecture des bookings bloquants par `staff_id` pour le moteur visible, ignorer les `pending` expirés, et cesser d’utiliser `Resource.for_enseigne` pour la visibilité.
- Hors périmètre : verrous transactionnels, assignation, `create_pending`.
- Pourquoi ce ticket est séparé : c’est la bascule critique qui retire la dépendance visible à l’enseigne comme ressource.
- Composants potentiellement concernés : [available_slots.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/available_slots.rb), [blocking_bookings.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/blocking_bookings.rb), nouveau service de lecture des bookings par staff, [booking.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/booking.rb)
- Comportement attendu : un booking confirmé ou pending actif bloque uniquement le bon staff sur son intervalle; un pending expiré ne bloque plus.
- Critères d’acceptation : le visible ne dépend plus d’un blocage global par enseigne; `Resource.for_enseigne` n’est plus utilisé dans le moteur visible.
- Dépendances : Ticket 4
- Risques / points de vigilance : ne pas toucher à l’orchestration transactionnelle des epics suivants.
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 6
- Titre : Agréger les slots visibles à partir de l’union des staffs éligibles
- Objectif : produire la grille publique finale sans assigner de staff.
- Partie de la spécification couverte : E2-US6
- Problème résolu : le moteur visible doit refléter la disponibilité réelle de plusieurs staffs sans choisir lequel sera réservé.
- Périmètre exact : faire évoluer [available_slots.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/available_slots.rb) ou son remplaçant pour agréger les slots issus des disponibilités staff-based, puis brancher [public_page.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/public_page.rb) sur ce résultat.
- Hors périmètre : `staff_id` choisi, pending, round robin, `SlotDecision`.
- Pourquoi ce ticket est séparé : c’est la sortie fonctionnelle visible de l’Epic 2.
- Composants potentiellement concernés : [available_slots.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/available_slots.rb), [public_page.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/public_page.rb), services visibles staff-based
- Comportement attendu : un slot reste visible tant qu’au moins un staff compatible est libre.
- Critères d’acceptation : aucune assignation staff n’est produite; un slot disparaît seulement si tous les staffs compatibles sont indisponibles ou bloqués.
- Dépendances : Ticket 5
- Risques / points de vigilance : ne pas injecter d’ordre de rotation ou de logique d’assignation dans le visible.
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 7
- Titre : Réécrire les tests de visibilité pour documenter le moteur staff-based
- Objectif : faire des tests visibles la documentation active du nouveau moteur.
- Partie de la spécification couverte : E2-US7
- Problème résolu : les tests actuels documentent encore largement un moteur `une enseigne = une ressource`.
- Périmètre exact : réécrire [available_slots_test.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/test/services/bookings/available_slots_test.rb), adapter [schedule_resolver_test.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/test/services/bookings/schedule_resolver_test.rb) à son rôle borné, et ajuster les tests de page publique liés aux slots si nécessaire.
- Hors périmètre : tests transactionnels de `create_pending`, `confirm`, round robin.
- Pourquoi ce ticket est séparé : il ferme l’Epic 2 en sécurisant le comportement attendu sans mélanger les changements fonctionnels.
- Composants potentiellement concernés : [available_slots_test.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/test/services/bookings/available_slots_test.rb), [schedule_resolver_test.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/test/services/bookings/schedule_resolver_test.rb), tests de visibilité publique
- Comportement attendu : les tests visibles décrivent explicitement exclusion des staffs inactifs, absence de capability, disponibilités staff, indisponibilités staff, visibilité maintenue s’il reste un seul staff libre.
- Critères d’acceptation : aucun test actif de visibilité ne suppose encore `une enseigne = une ressource`; `ScheduleResolver` est testé uniquement sur les horaires enseigne.
- Dépendances : Tickets 1 à 6
- Risques / points de vigilance : ne pas conserver d’anciens tests enseigne-based sous prétexte qu’ils passent encore.
- Priorité : P1
- Complexité estimée : Moyenne

## Recommandation finale
- Tickets à traiter en premier : 1, 2, 3, 4, 5, 6.
- Tickets à regrouper éventuellement : 2 et 3 peuvent être regroupés si l’équipe préfère un seul ticket “disponibilité réelle staff avant bookings”. 4 et 5 peuvent être regroupés si un seul développeur porte toute la couche “fenêtres visibles par staff”.
- Tickets à ne pas créer : un ticket qui étend `ScheduleResolver` à toute la disponibilité staff; un ticket qui continue à utiliser `Resource.for_enseigne` pour le visible; un ticket qui assigne un staff dès l’affichage des slots.
- Parties de la spécification à simplifier : aucune. L’Epic 2 est maintenant assez verrouillée.
- Risques de mauvais découpage à éviter : mélanger visibilité et assignation, garder un blocage global par enseigne dans le visible, transformer les tests en chantier exhaustif hors du scope Epic 2.

Priorisation recommandée :
1. P1 immédiat : Tickets 1, 2, 3, 4, 5, 6, 7
2. Ordre d’exécution conseillé : `1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7`
3. Regroupement pragmatique possible : `1`, `2+3`, `4+5`, `6`, `7`
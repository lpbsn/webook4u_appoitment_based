## Analyse rapide de la spécification
- Objectif principal : basculer l’orchestration transactionnelle de réservation vers un moteur `staff-based` avec round robin explicite.
- Ce que la spécification cherche à obtenir : un `create_pending` qui assigne un `staff_id` selon une rotation déterministe, un `confirm` sans réassignation, un curseur mis à jour uniquement au `confirmed`, et une protection DB finale des conflits `confirmed` par staff.
- Points flous ou discutables : les arbitrages bloquants sont maintenant verrouillés. Le contrat du curseur et la portée exacte de la revalidation au `confirm` sont suffisamment précis.
- Incohérences potentielles avec le repository : le code transactionnel actuel reste encore `enseigne-based` dans [create_pending.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/create_pending.rb), [confirm.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/confirm.rb), [slot_lock.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_lock.rb) et [slot_decision.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_decision.rb).
- Hypothèses retenues : l’Epic 2 est terminée; `create_pending` et `confirm` ne doivent plus utiliser `Resource.for_enseigne`; la mise à jour du curseur reste couplée au `confirmed`, pas au `pending`.
- Zones du repository probablement concernées : [service_assignment_cursor.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/service_assignment_cursor.rb), [create_pending.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/create_pending.rb), [confirm.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/confirm.rb), [slot_lock.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_lock.rb), [slot_decision.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_decision.rb), [errors.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/errors.rb), tests transactionnels et contraintes DB.

## Stratégie de découpage
- Logique de découpage choisie : un ticket = un contrat métier précis. Quand une US mélange refonte d’orchestration et extraction/remplacement d’un service transverse, elle est scindée.
- Dépendances principales : contrat du curseur avant orchestration; primitives de lock avant `create_pending`/`confirm`; services de revalidation avant réécriture des flux; contrainte DB finale avant réalignement complet des tests.
- Ordre recommandé d’implémentation : 1. curseur, 2. primitives de lock, 3. revalidation transactionnelle `create_pending`, 4. orchestration `create_pending`, 5. revalidation minimale `confirm`, 6. orchestration `confirm`, 7. avance du curseur au `confirmed`, 8. contrainte DB `confirmed by staff`, 9. tests transactionnels.
- Ce qui doit être traité maintenant vs plus tard : maintenant, l’assignation transactionnelle et ses garde-fous; plus tard, le flow public final et le nettoyage global.

## Tickets techniques

### Ticket 1
- Titre : Formaliser le contrat transactionnel du curseur par service
- Objectif : rendre exploitable `ServiceAssignmentCursor` comme source de vérité du round robin.
- Partie de la spécification couverte : E3-US1
- Problème résolu : le modèle du curseur existe mais ne porte pas encore de contrat métier transactionnel exploitable.
- Périmètre exact : porter le curseur sur `last_confirmed_staff_id`, fixer l’ordre déterministe `staff.id ASC` sur les staffs actifs et compatibles, définir le comportement quand le curseur est vide ou pointe vers un staff non éligible.
- Hors périmètre : locks, création du pending, confirmation.
- Pourquoi ce ticket est séparé : l’orchestration ne peut pas être développée tant que la source de vérité du round robin reste implicite.
- Composants potentiellement concernés : [service_assignment_cursor.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/service_assignment_cursor.rb), services d’assignation, tests du curseur.
- Comportement attendu : un service a un seul curseur, basé sur `last_confirmed_staff_id`, et l’ordre de rotation est déterministe.
- Critères d’acceptation : pas de `current_index`; si `last_confirmed_staff_id` est `nil`, on part du premier staff éligible; s’il n’est plus éligible, on repart sur le premier staff éligible suivant avec wrap-around.
- Dépendances : Epic 1 terminé
- Risques / points de vigilance : ne pas déplacer la vérité de rotation sur `Staff`.
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 2
- Titre : Introduire les primitives de lock `service` puis `staff`
- Objectif : remplacer la sérialisation transactionnelle au niveau enseigne par des locks dédiés à la rotation du service et au staff candidat.
- Partie de la spécification couverte : E3-US2
- Problème résolu : [slot_lock.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_lock.rb) sérialise encore au niveau enseigne entière.
- Périmètre exact : introduire ou refondre les services de lock pour exprimer explicitement `lock rotation du service` puis `lock staff`.
- Hors périmètre : branchement complet de `create_pending` et `confirm`.
- Pourquoi ce ticket est séparé : c’est une extraction transverse de service d’infrastructure, distincte de l’orchestration métier.
- Composants potentiellement concernés : [slot_lock.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_lock.rb) ou son remplaçant, services de lock, services d’assignation.
- Comportement attendu : l’ordre des verrous est codé et la granularité principale n’est plus l’enseigne.
- Critères d’acceptation : lock rotation avant lock staff; aucun verrou critique principal au niveau enseigne.
- Dépendances : Ticket 1
- Risques / points de vigilance : ne pas laisser subsister un fallback opportuniste hors ordre de rotation.
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 3
- Titre : Extraire la revalidation transactionnelle staff-based pour `create_pending`
- Objectif : disposer d’un service de revalidation transactionnelle par staff pour la création de pending.
- Partie de la spécification couverte : partie transverse de E3-US3
- Problème résolu : `create_pending` s’appuie encore sur [slot_decision.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_decision.rb), pensé autour d’une ressource globale.
- Périmètre exact : créer un service dédié qui revalide un créneau sur un staff candidat sous verrou, avec logique `staff-based` et sans `Resource.for_enseigne`.
- Hors périmètre : lecture du curseur, boucle round robin complète, création du booking.
- Pourquoi ce ticket est séparé : c’est un remplacement de service transverse, distinct de l’orchestration métier.
- Composants potentiellement concernés : [slot_decision.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_decision.rb) ou son remplaçant transactionnel, services d’assignation.
- Comportement attendu : le service sait dire si un staff candidat peut encore prendre le slot dans le contexte transactionnel.
- Critères d’acceptation : la revalidation transactionnelle de `create_pending` n’utilise plus `Resource.for_enseigne`.
- Dépendances : Ticket 2
- Risques / points de vigilance : ne pas fusionner cette logique avec le moteur visible de l’Epic 2.
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 4
- Titre : Réécrire `create_pending` sur le round robin staff-based
- Objectif : créer un pending sur le premier staff valide selon l’ordre de rotation.
- Partie de la spécification couverte : partie orchestration de E3-US3
- Problème résolu : [create_pending.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/create_pending.rb) sérialise encore par enseigne et ne persiste pas de `staff_id`.
- Périmètre exact : lire le curseur du service, calculer l’ordre des candidats, verrouiller/revalider chaque candidat, créer le pending sur le premier staff valide, retourner `slot_unavailable` sinon.
- Hors périmètre : avance du curseur, réassignation au confirm.
- Pourquoi ce ticket est séparé : l’orchestration métier doit rester distincte du remplacement du service de revalidation.
- Composants potentiellement concernés : [create_pending.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/create_pending.rb), services d’assignation, services de lock.
- Comportement attendu : tout pending créé porte un `staff_id`; l’ordre de tentative est celui du curseur puis `staff.id ASC`.
- Critères d’acceptation : aucun pending sans `staff_id`; pas d’usage de `Resource.for_enseigne`; pas d’avance du curseur au `pending`.
- Dépendances : Tickets 1, 2 et 3
- Risques / points de vigilance : ne pas réintroduire un ordre de secours hors rotation.
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 5
- Titre : Extraire la revalidation minimale de `confirm` sur le staff assigné
- Objectif : isoler la logique minimale de revalidation du `confirm`.
- Partie de la spécification couverte : partie transverse de E3-US4
- Problème résolu : le `confirm` actuel repose encore sur [slot_decision.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_decision.rb) et une revalidation trop générique.
- Périmètre exact : créer un service dédié qui vérifie uniquement que le booking est encore `pending`, non expiré, que le `staff_id` existe toujours et appartient à la bonne enseigne, et qu’aucun autre booking bloquant ne prend le slot sur ce staff.
- Hors périmètre : recherche d’un autre staff, réévaluation complète d’éligibilité, mise à jour du curseur.
- Pourquoi ce ticket est séparé : c’est un remplacement de service transverse différent du `create_pending`.
- Composants potentiellement concernés : [confirm.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/confirm.rb), [slot_decision.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_decision.rb) ou son remplaçant transactionnel.
- Comportement attendu : le `confirm` travaille uniquement sur le `staff_id` déjà assigné.
- Critères d’acceptation : aucune réévaluation de `staff.active`, capability, disponibilités hebdo ou indisponibilités ponctuelles.
- Dépendances : Ticket 2
- Risques / points de vigilance : ne pas reconstruire toute l’éligibilité au `confirm`.
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 6
- Titre : Réécrire `confirm` sans réassignation
- Objectif : confirmer un pending sur le staff déjà assigné, sans changer de ressource.
- Partie de la spécification couverte : partie orchestration de E3-US4
- Problème résolu : [confirm.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/confirm.rb) est encore sérialisé au niveau enseigne et non centré sur le `staff_id`.
- Périmètre exact : verrouiller le staff du pending, utiliser la revalidation minimale dédiée, confirmer sans fallback vers un autre staff.
- Hors périmètre : avance du curseur, recherche d’un autre staff.
- Pourquoi ce ticket est séparé : l’orchestration métier du `confirm` doit rester distincte de l’extraction de la revalidation.
- Composants potentiellement concernés : [confirm.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/confirm.rb), services d’assignation, services de lock.
- Comportement attendu : le `confirm` garde le même `staff_id` ou échoue.
- Critères d’acceptation : pas de réassignation; pas de verrou principal au niveau enseigne; échec si le staff a disparu ou si le slot n’est plus libre sur ce même staff.
- Dépendances : Tickets 2 et 5
- Risques / points de vigilance : ne pas laisser subsister un fallback implicite vers un autre staff.
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 7
- Titre : Avancer le curseur uniquement lors du `confirmed`
- Objectif : mettre à jour la rotation seulement quand une réservation est effectivement confirmée.
- Partie de la spécification couverte : E3-US5
- Problème résolu : le curseur ne doit pas être influencé par les pending expirés, abandonnés ou échoués.
- Périmètre exact : avancer `last_confirmed_staff_id` dans la transaction de confirmation, et jamais ailleurs.
- Hors périmètre : changement d’ordre des candidats hors `confirmed`.
- Pourquoi ce ticket est séparé : c’est un contrat métier clair, distinct de l’orchestration du `confirm`.
- Composants potentiellement concernés : [confirm.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/confirm.rb), [service_assignment_cursor.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/service_assignment_cursor.rb), services d’assignation.
- Comportement attendu : le curseur reflète le staff effectivement confirmé.
- Critères d’acceptation : aucune avance sur `pending`, expiration ou échec; avance dans la même transaction que le `confirmed`.
- Dépendances : Tickets 1 et 6
- Risques / points de vigilance : ne pas dissocier l’avance du curseur de la transaction de confirmation.
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 8
- Titre : Remplacer la protection DB `confirmed` par une contrainte `staff_id + interval`
- Objectif : garantir l’invariant final d’absence de conflit `confirmed` sur un même staff.
- Partie de la spécification couverte : E3-US6
- Problème résolu : la contrainte actuelle vise encore l’enseigne au lieu du staff.
- Périmètre exact : remplacer la contrainte DB d’overlap `confirmed`, mettre à jour le mapping d’erreurs applicatif, et adapter les tests d’infrastructure DB.
- Hors périmètre : blocage des pending actifs.
- Pourquoi ce ticket est séparé : c’est un garde-fou DB final, distinct de l’orchestration applicative.
- Composants potentiellement concernés : migrations, [db/structure.sql](/Users/leobsn/Desktop/webook4u_appoitment_based/db/structure.sql), [errors.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/errors.rb), tests DB et modèle liés aux conflits `confirmed`.
- Comportement attendu : deux `confirmed` overlapping sont refusés sur un même staff et autorisés sur deux staffs distincts.
- Critères d’acceptation : la contrainte critique existe côté DB; les erreurs applicatives reconnaissent le nouveau nom de contrainte.
- Dépendances : Tickets 2 et 6
- Risques / points de vigilance : ne pas présenter la contrainte DB comme orchestration primaire.
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 9
- Titre : Réécrire les tests transactionnels sur l’assignation staff-based
- Objectif : faire des tests transactionnels la documentation active du nouveau moteur `create_pending` / `confirm`.
- Partie de la spécification couverte : E3-US7
- Problème résolu : les tests existants documentent encore une orchestration par enseigne et `Resource.for_enseigne`.
- Périmètre exact : réécrire les tests transactionnels pour couvrir affectation du `staff_id` au `create_pending`, conservation au `confirm`, absence de réassignation, round robin transactionnel, conflit `confirmed` sur un même staff, autorisation sur deux staffs distincts.
- Hors périmètre : tests de visibilité publique, UI publique complète.
- Pourquoi ce ticket est séparé : il verrouille le comportement final sans mélanger logique métier et tests.
- Composants potentiellement concernés : tests `create_pending`, `confirm`, `slot_decision` ou son remplaçant, `errors`, `booking`, et tests DB de conflit `confirmed`.
- Comportement attendu : aucun test transactionnel actif ne documente encore un verrou principal par enseigne ou `Resource.for_enseigne` comme ressource transactionnelle.
- Critères d’acceptation : les tests transactionnels décrivent explicitement le moteur staff-based cible.
- Dépendances : Tickets 3 à 8
- Risques / points de vigilance : ne pas conserver des assertions historiques enseigne-based “parce qu’elles passent encore”.
- Priorité : P1
- Complexité estimée : Élevée

## Recommandation finale
- Tickets à traiter en premier : 1, 2, 3, 4, 5, 6, 7, 8.
- Tickets à regrouper éventuellement : 3 avec 4 si le même développeur porte toute la refonte `create_pending`; 5 avec 6 si le même développeur porte toute la refonte `confirm`.
- Tickets à ne pas créer : un ticket qui mélange `create_pending` et `confirm`; un ticket qui mélange refonte des locks et mise à jour des tests; un ticket qui laisse `Resource.for_enseigne` en place “temporairement” dans le transactionnel.
- Parties de la spécification à simplifier : aucune. Le niveau de verrouillage est suffisant.
- Risques de mauvais découpage à éviter : fusionner extraction de service transverse et orchestration métier dans un même ticket; avancer le curseur au `pending`; réévaluer l’éligibilité complète au `confirm`; garder un verrou principal au niveau enseigne.

Priorisation agile recommandée :
1. P1 immédiat : Tickets 1 à 9
2. Ordre d’exécution conseillé : `1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8 -> 9`
3. Séquence plus pragmatique en lots :
   - Lot A : `1 + 2`
   - Lot B : `3 + 4`
   - Lot C : `5 + 6 + 7`
   - Lot D : `8`
   - Lot E : `9`
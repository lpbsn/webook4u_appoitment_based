# Refonte staff-based du moteur de réservation

## Résumé

Objectif: faire converger le repository vers la cible produit de [EDB-Webook4U-Appointment-Based-V1.md](/Users/leobsn/Desktop/webook4u_appoitment_based/docs/EDB-Webook4U-Appointment-Based-V1.md) en remplaçant le noyau actuel `enseigne-based` par un noyau `staff-based`.

Ce chantier couvre uniquement:

- le noyau métier
- la base de données
- le moteur de disponibilité
- l'assignation transactionnelle
- le flow public hébergé

Ce chantier ne couvre pas:

- le back-office
- Stripe
- iframe
- embed
- CRM
- annulation
- replanification

Les données actuelles sont considérées comme jetables. La refonte vise une convergence directe vers le modèle cible, sans migration de conservation métier et sans dual-run long.

La cible opérationnelle est la suivante:

- `Service` appartient à `Enseigne`
- `Booking` appartient à `Staff`, `Service`, `Enseigne`, `Client`
- `enseigne_opening_hours` devient l'unique cadre d'ouverture exploité par le runtime
- le staff reste invisible côté utilisateur final
- le round robin est conservé, avec un curseur dédié par `service` et un verrou de rotation dédié

## Arbitrages verrouillés

- pas de back-office dans ce chantier
- pas de migration de conservation des services ou bookings existants
- pas de compatibilité longue avec l'ancien modèle
- suppression du fallback `client_opening_hours`
- `Service` appartient à `Enseigne`
- `Booking` appartient à `Staff`, `Service`, `Enseigne`, `Client`
- l'utilisateur final ne choisit jamais le staff
- le round robin est porté par `service`, avec un curseur dédié et un verrou dédié
- la protection DB finale des overlaps `confirmed` cible `staff_id + interval` (et non `enseigne_id + interval`)
- dans l'Epic 1, cette protection finale est une cible verrouillée mais n'est pas encore implémentée
- la base actuelle peut être supprimée et reconstruite
- aucun historique métier n'est à préserver
- le repository peut abandonner l'ancien historique DB au profit d'un socle propre
- le round robin reste non configurable en V1

Conséquences directes:

- toute lecture métier de `client.services` doit disparaître
- toute dépendance runtime à `client_opening_hours` doit disparaître
- toute logique de compatibilité transitoire qui maintient l'ancien modèle vivant doit être évitée

Sont explicitement exclus du plan:

- `compatibilité progressive`
- `default staff`
- duplication des services client dans chaque enseigne
- tout héritage runtime ambigu entre `client_opening_hours` et `enseigne_opening_hours`

## Domaine cible

Le domaine canonique cible est:

- `Client`
- `Enseigne`
- `Service`
- `Staff`
- `StaffAvailability`
- `StaffUnavailability`
- `StaffServiceCapability`
- `ServiceAssignmentCursor`
- `Booking`

Relations cibles:

- un `Client` possède une ou plusieurs `Enseigne`
- une `Enseigne` possède ses `Service`
- une `Enseigne` possède ses `Staff`
- un `Staff` possède ses disponibilités hebdomadaires
- un `Staff` possède ses indisponibilités ponctuelles
- un `Staff` est explicitement relié aux `Service` qu'il peut exécuter
- un `ServiceAssignmentCursor` porte l'état de rotation d'un `Service`
- un `Booking` référence un `Client`, une `Enseigne`, un `Service` et un `Staff`

Contrats métier obligatoires:

- un `Service` ne peut être réservé que dans son `Enseigne`
- un `Staff` ne peut être assigné que dans son `Enseigne`
- un `Booking` doit rester cohérent sur `client / enseigne / service / staff`
- un staff inactif n'est jamais réservable
- une enseigne sans `enseigne_opening_hours` n'est pas réservable

## Plan priorisé

### P0. Stabiliser la cible

- geler le périmètre hors Stripe, iframe, embed, CRM, annulation, replanification et back-office
- fixer les invariants métier du modèle staff-based
- fixer le modèle de rotation round robin par `service`
- décider que la base sera reconstruite sur le nouveau socle, sans reprise des données existantes

### P1. Refaire le schéma cible

- ajouter `staffs`
- ajouter `staff_availabilities`
- ajouter `staff_unavailabilities`
- ajouter `staff_service_capabilities`
- ajouter `service_assignment_cursors`
- rendre `services.enseigne_id` obligatoire
- rendre `bookings.staff_id` obligatoire
- retirer la dépendance métier à `services.client_id`
- retirer la dépendance métier à `client_opening_hours`
- verrouiller la cible finale anti-overlap `confirmed` sur `staff_id + interval`, sans implémenter la contrainte finale à ce stade
- ajouter les contraintes de cohérence inter-table nécessaires

Règles de cette phase:

- la base est reconstruite directement sur la structure cible
- les seeds sont réécrits dans le nouveau modèle
- les tests sont réécrits dans le nouveau modèle
- aucune conservation des services ou bookings actuels n'est recherchée

### P2. Refaire le noyau de disponibilité

- remplacer le calcul `enseigne-based` par un calcul `staff-based`
- résoudre les staffs éligibles pour un `service`
- calculer la disponibilité réelle par intersection de:
  - horaires d'ouverture de l'enseigne
  - disponibilités hebdomadaires du staff
  - indisponibilités ponctuelles du staff
  - compatibilité `staff <-> service`
  - bookings bloquants
  - durée du service
- exposer un slot public seulement s'il existe au moins un staff compatible capable de le prendre réellement

### P3. Refaire l'assignation transactionnelle

Sur `create_pending`:

- verrouiller le curseur de rotation du `service`
- calculer l'ordre des staffs candidats à partir de ce curseur
- tester les candidats séquentiellement
- verrouiller le `staff` candidat avant création
- revalider le slot sur ce `staff`
- créer le `pending` sur le premier `staff` valide
- retourner `slot_unavailable` si aucun `staff` candidat ne peut prendre le slot

Sur `confirm`:

- ne jamais réassigner un autre `staff`
- verrouiller le `staff_id` déjà porté par le `pending`
- revalider le slot sur ce `staff`
- confirmer le booking
- avancer le curseur de rotation du `service` dans la même transaction

### P4. Refaire le flow public

- conserver la structure `enseigne -> service -> date -> slots -> pending -> confirm -> success`
- charger les services uniquement depuis l'enseigne sélectionnée
- calculer les slots sur l'union des disponibilités des staffs éligibles
- créer le `pending` avec `staff_id` déjà assigné
- garder le `staff` invisible dans l'expérience utilisateur

### P5. Nettoyage final complet

- supprimer tout l'ancien noyau `enseigne-based`
- supprimer les branches de compatibilité et commentaires de transition
- supprimer les seeds, tests et helpers encore construits autour de `client.services`
- supprimer le fallback `client_opening_hours`
- supprimer les modèles, tables, contraintes et migrations obsolètes si elles ne font plus partie du socle cible
- régénérer un historique DB propre aligné uniquement sur la structure cible
- régénérer `db/structure.sql` sur le nouveau socle

## Règles de disponibilité

Les règles de disponibilité du runtime cible sont les suivantes:

- une enseigne sans `enseigne_opening_hours` n'est pas réservable
- un staff inactif n'est jamais candidat
- un staff sans capability pour le service n'est jamais candidat
- une indisponibilité staff exclut tout slot overlapping
- un booking `confirmed` bloque le même `staff` sur l'intervalle concerné
- un booking `pending` actif bloque le même `staff` sur l'intervalle concerné pendant sa durée de vie
- un slot est visible s'il existe au moins un staff compatible et libre
- un slot disparaît uniquement si tous les staffs compatibles sont indisponibles ou bloqués
- la durée reste portée par le service
- la cadence d'affichage actuelle peut être conservée tant qu'elle reste compatible avec le service
- la notice minimale est conservée
- l'expiration du `pending` est conservée

## Règles d'assignation round robin

Le round robin cible suit les règles suivantes:

- la rotation est portée par un état dédié par `service`, pas par `staff`
- l'ordre initial est déterministe
- les staffs inactifs, incompatibles ou indisponibles sont sautés
- le curseur n'avance jamais sur `pending`
- le curseur n'avance qu'après `confirmed`
- la rotation et la confirmation doivent être cohérentes transactionnellement
- le verrou de rotation protège l'ordre de tentative
- le verrou staff protège la réservation effective
- la contrainte DB protège l'unicité `confirmed` par `staff`

Conséquences métier:

- un staff indisponible au créneau demandé est sauté sans faire avancer le curseur
- un `pending` expiré ou échoué ne modifie pas la rotation
- l'équité de rotation ne doit jamais dégrader l'exactitude de réservation

## Interfaces et contraintes structurantes

Changements structurants à expliciter et à mettre en oeuvre:

- `Service` sort du contrat métier de `Client`
- `PublicPage` ne doit plus lire `client.services`
- `ScheduleResolver` ne doit plus fallback vers `client_opening_hours`
- `Booking` doit valider la cohérence `client / enseigne / service / staff`
- l'anti-overlap `confirmed` passe de `enseigne_id + interval` à `staff_id + interval`
- le verrou applicatif ne se fait plus au niveau enseigne mais au niveau rotation de service puis staff

Contraintes DB attendues:

- un booking ne peut pas pointer vers un `service` d'une autre `enseigne`
- un booking ne peut pas pointer vers un `staff` d'une autre `enseigne`
- un `StaffServiceCapability` ne peut pas être dupliqué
- la protection d'overlap `confirmed` doit s'appliquer par `staff`

## Plan de test et critères d'acceptation

Le plan de test doit couvrir au minimum:

- création de services par enseigne uniquement
- exclusion des staffs inactifs
- exclusion des staffs sans capability
- prise en compte des disponibilités hebdomadaires staff
- prise en compte des indisponibilités ponctuelles staff
- visibilité d'un slot si au moins un staff est libre
- masquage d'un slot si tous les staffs compatibles sont indisponibles
- création d'un `pending` avec `staff_id`
- conservation du même `staff_id` au `confirm`
- round robin qui saute un staff indisponible sans avancer le curseur
- avancement du curseur uniquement sur `confirmed`
- refus de deux `confirmed` overlapping sur un même staff
- autorisation de deux `confirmed` overlapping sur deux staffs différents
- absence totale de dépendance runtime à `client_opening_hours`
- absence totale de dépendance runtime à `client.services`

Critères d'acceptation finaux:

- aucun scénario métier ne doit encore supposer `une enseigne = une ressource`
- aucun scénario métier ne doit encore dépendre d'un service global au client
- aucun scénario métier ne doit encore dépendre du fallback `client_opening_hours`
- le flow public reste `enseigne -> service -> date -> slots -> pending -> confirm -> success`
- le staff reste invisible côté utilisateur final

## Hors périmètre

Les sujets suivants sont hors périmètre de ce chantier:

- back-office admin
- back-office client
- Stripe
- iframe
- embed
- annulation
- replanification
- logique CRM

## Nettoyage final

Le nettoyage du code mort fait partie intégrante du chantier et ne constitue pas une option.

Il doit couvrir:

- suppression du runtime `enseigne-based` encore présent dans le moteur de réservation
- suppression de `client_opening_hours` du runtime, du schéma, des seeds et des tests
- suppression de `client.services` du runtime, des seeds et des tests
- suppression des tests qui documentent un comportement désormais interdit
- suppression des migrations transitoires et héritées si elles n'ont plus de valeur dans le nouveau socle
- suppression des docs obsolètes qui décrivent encore le noyau actuel
- nettoyage des commentaires de transition devenus faux dans les services et modèles

Le chantier n'est terminé que lorsque:

- le runtime n'expose plus aucune dépendance à l'ancien noyau
- les tests ne documentent plus l'ancien modèle
- les seeds ne reconstruisent plus l'ancien modèle
- le schéma et l'historique DB reflètent uniquement le socle cible

## Analyse rapide de la spécification
- Objectif principal : supprimer les reliquats techniques après bascule effective du moteur `staff-based`.
- Ce que la spécification cherche à obtenir : un repo sans runtime mort `enseigne-based`, sans `client_opening_hours`, sans reliquat `client.services`, avec un socle DB final propre et une doc réalignée.
- Points flous ou discutables : le cadrage est globalement bon. Les seules zones à découper sont `E5-US4` et `E5-US5`, trop larges si prises telles quelles.
- Incohérences potentielles avec le repository : il reste encore des artefacts réels à nettoyer, notamment [resource.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/resource.rb), [slot_decision.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_decision.rb), [slot_lock.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_lock.rb), [client.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/client.rb), `client_opening_hours` dans le schéma et plusieurs tests d’infrastructure/migration.
- Hypothèses retenues : Epic 4 est considérée livrée; l’objectif n’est plus de préserver des artefacts de transition; le nettoyage DB final peut aller jusqu’à régénérer un historique de migrations propre.
- Zones du repository probablement concernées : runtime booking, modèles, tests, seeds, helpers, `db/migrate`, [db/schema.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/schema.rb), [db/structure.sql](/Users/leobsn/Desktop/webook4u_appoitment_based/db/structure.sql), `docs/`.

## Stratégie de découpage
- Logique de découpage choisie : conserver les US déjà proches du ticket, et scinder `E5-US4` et `E5-US5` en contrats de cleanup plus serrés.
- Dépendances principales : supprimer le runtime mort avant de supprimer ses tests dédiés; sortir `client_opening_hours` et `client.services` du code avant de régénérer le socle DB; nettoyer les docs en dernier.
- Ordre recommandé d’implémentation : 1. runtime mort, 2. `client_opening_hours`, 3. reliquats `client.services`, 4. seeds/helpers actifs, 5. tests obsolètes, 6. schéma final, 7. historique DB propre, 8. docs.
- Ce qui doit être traité maintenant vs plus tard : tout ce qui suit est du cleanup final. Il n’y a plus de “plus tard” dans ce chantier, seulement un ordre prudent d’exécution.

## Tickets techniques

### Ticket 1
- Titre : Supprimer les artefacts runtime morts de l’ancien noyau
- Objectif : retirer les services et branches runtime encore construits autour de `enseigne` comme ressource réservable.
- Partie de la spécification couverte : E5-US1
- Problème résolu : des artefacts morts entretiennent encore un faux moteur `enseigne-based`.
- Périmètre exact : supprimer `Bookings::Resource`, `Bookings::BlockingBookings`, `Bookings::SlotDecision`, les branches mortes de `SlotLock`, et les commentaires de transition devenus faux si ces artefacts n’ont plus d’usage métier actif.
- Hors périmètre : nettoyage DB historique.
- Pourquoi ce ticket est séparé : c’est le nettoyage du runtime, préalable au reste.
- Composants potentiellement concernés : [resource.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/resource.rb), [blocking_bookings.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/blocking_bookings.rb), [slot_decision.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_decision.rb), [slot_lock.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/services/bookings/slot_lock.rb), [booking.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/booking.rb)
- Comportement attendu : aucun service runtime actif ne suppose encore `une enseigne = une ressource`.
- Critères d’acceptation : aucun service runtime actif n’utilise `Resource.for_enseigne`; aucun commentaire actif ne décrit encore le moteur courant comme transitoire vers le `staff-based`.
- Dépendances : Epic 4 terminée
- Risques / points de vigilance : vérifier l’absence d’usage métier actif avant suppression.
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 2
- Titre : Supprimer physiquement `client_opening_hours` du code actif et du socle final
- Objectif : éliminer totalement `client_opening_hours` du projet.
- Partie de la spécification couverte : E5-US2
- Problème résolu : `client_opening_hours` n’est plus utile métier, mais existe encore dans le code, les tests et le schéma.
- Périmètre exact : supprimer l’association dans [client.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/client.rb), supprimer le modèle et les références actives, supprimer la table et ses artefacts du schéma final.
- Hors périmètre : nettoyage des docs.
- Pourquoi ce ticket est séparé : c’est un reliquat métier distinct, avec impact code + DB.
- Composants potentiellement concernés : [client.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/client.rb), tests opening hours, migrations liées à `client_opening_hours`, [db/schema.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/schema.rb), [db/structure.sql](/Users/leobsn/Desktop/webook4u_appoitment_based/db/structure.sql)
- Comportement attendu : aucun modèle, test ou seed actif ne reconstruit `client_opening_hours`.
- Critères d’acceptation : `client_opening_hours` n’existe plus dans le schéma final; aucun code actif n’y fait référence.
- Dépendances : Ticket 1
- Risques / points de vigilance : plusieurs tests de migration/infrastructure y sont encore attachés.
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 3
- Titre : Clôturer définitivement le modèle global `client.services`
- Objectif : supprimer les derniers reliquats qui pourraient réintroduire un catalogue global au niveau client.
- Partie de la spécification couverte : E5-US3
- Problème résolu : des helpers, tests ou docs peuvent encore suggérer `client.services`.
- Périmètre exact : supprimer les derniers raccourcis, commentaires, helpers et reliquats de lecture laissant croire que `Service` appartient à `Client`.
- Hors périmètre : nettoyage des docs générales.
- Pourquoi ce ticket est séparé : c’est un contrat métier à fermer explicitement.
- Composants potentiellement concernés : [client.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/client.rb), [service.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/app/models/service.rb), tests domaine et flow public
- Comportement attendu : le projet n’expose plus aucun raccourci ni reliquat `client.services`.
- Critères d’acceptation : aucune logique métier, seed ou test actif ne crée encore un service via `Client`.
- Dépendances : Ticket 1
- Risques / points de vigilance : éviter de conserver un raccourci “lecture seule” pour commodité.
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 4
- Titre : Nettoyer les seeds, helpers et supports actifs qui reconstruisent encore l’ancien modèle
- Objectif : supprimer les artefacts d’accompagnement encore utilisés au quotidien qui réinjectent l’ancien modèle.
- Partie de la spécification couverte : première moitié de E5-US4
- Problème résolu : même si le runtime est propre, les seeds et helpers peuvent encore enseigner un comportement interdit.
- Périmètre exact : nettoyer [db/seeds.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/seeds.rb), les helpers de test de base et les helpers de vues/support encore alignés sur l’ancien noyau.
- Hors périmètre : suppression des tests obsolètes dédiés à des artefacts supprimés.
- Pourquoi ce ticket est séparé : c’est le cleanup des supports actifs, distinct du cleanup des tests morts.
- Composants potentiellement concernés : [db/seeds.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/seeds.rb), [test/test_helper.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/test/test_helper.rb), helpers liés au flow public
- Comportement attendu : aucun support actif ne reconstruit l’ancien modèle.
- Critères d’acceptation : aucun seed, helper de test ou helper actif ne reconstruit `client_opening_hours`, `client.services` ou un runtime `enseigne-based`.
- Dépendances : Tickets 2 et 3
- Risques / points de vigilance : ne pas laisser des helpers “historique/compatibilité”.
- Priorité : P1
- Complexité estimée : Moyenne

### Ticket 5
- Titre : Supprimer ou réécrire les tests devenus faux après suppression de l’ancien noyau
- Objectif : faire disparaître les tests qui documentent uniquement des artefacts morts ou un comportement désormais interdit.
- Partie de la spécification couverte : seconde moitié de E5-US4
- Problème résolu : le repo peut rester vert tout en gardant des tests qui enseignent le mauvais modèle.
- Périmètre exact : supprimer les tests dédiés uniquement à `Resource`, `BlockingBookings`, `SlotDecision`, `client_opening_hours` si ces artefacts sont supprimés, et réécrire les tests encore utiles devenus faux.
- Hors périmètre : régénération de l’historique DB.
- Pourquoi ce ticket est séparé : c’est le cleanup du corpus de tests, distinct des supports actifs.
- Composants potentiellement concernés : `test/`, notamment tests de services morts, tests d’infrastructure opening hours, tests migration obsolètes
- Comportement attendu : aucun test actif ne documente encore l’ancien noyau.
- Critères d’acceptation : aucun test actif ne cible uniquement des artefacts supprimés; aucun test actif ne documente encore un comportement désormais interdit.
- Dépendances : Tickets 1, 2, 3 et 4
- Risques / points de vigilance : distinguer les tests réellement obsolètes de ceux qui protègent encore un invariant utile.
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 6
- Titre : Régénérer le schéma final sans artefacts legacy
- Objectif : produire un `db/schema.rb` et un `db/structure.sql` alignés sur le modèle cible final.
- Partie de la spécification couverte : première moitié de E5-US5
- Problème résolu : le schéma contient encore des artefacts de transition comme `client_opening_hours` ou des contraintes legacy `confirmed by enseigne`.
- Périmètre exact : supprimer du socle courant les tables, contraintes, indexes et reliquats legacy, puis réaligner [db/schema.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/schema.rb) et [db/structure.sql](/Users/leobsn/Desktop/webook4u_appoitment_based/db/structure.sql).
- Hors périmètre : pruning complet de l’historique de migrations.
- Pourquoi ce ticket est séparé : c’est le livrable DB final observable, distinct du ménage dans l’historique.
- Composants potentiellement concernés : [db/schema.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/schema.rb), [db/structure.sql](/Users/leobsn/Desktop/webook4u_appoitment_based/db/structure.sql), migrations encore actives du socle final
- Comportement attendu : le schéma final ne contient plus `client_opening_hours` ni les contraintes/indexes `confirmed by enseigne`.
- Critères d’acceptation : `db/schema.rb` et `db/structure.sql` reflètent uniquement le modèle cible; les reliquats legacy ont disparu du socle final.
- Dépendances : Tickets 2 et 3
- Risques / points de vigilance : ne pas laisser diverger `schema.rb` et `structure.sql`.
- Priorité : P1
- Complexité estimée : Élevée

### Ticket 7
- Titre : Régénérer un historique de migrations propre aligné sur le socle final
- Objectif : supprimer les migrations transitoires et héritées qui n’ont plus de valeur dans le socle final.
- Partie de la spécification couverte : seconde moitié de E5-US5
- Problème résolu : l’historique DB actuel mélange création du socle final et étapes de transition désormais dépassées.
- Périmètre exact : reconstruire un historique minimal cohérent avec le modèle final, retirer les migrations de backfill/transition/cleanup sans valeur résiduelle, et garantir qu’une base se reconstruit proprement depuis cet historique.
- Hors périmètre : nettoyage des docs.
- Pourquoi ce ticket est séparé : c’est le ticket DB le plus risqué; il ne doit pas être mélangé au simple réalignement du schéma courant.
- Composants potentiellement concernés : `db/migrate/`, [db/schema.rb](/Users/leobsn/Desktop/webook4u_appoitment_based/db/schema.rb), [db/structure.sql](/Users/leobsn/Desktop/webook4u_appoitment_based/db/structure.sql)
- Comportement attendu : l’historique DB ne conserve plus les compromis de la transition.
- Critères d’acceptation : une base se reconstruit proprement depuis l’historique final; les migrations transitoires obsolètes ont disparu.
- Dépendances : Ticket 6
- Risques / points de vigilance : ticket potentiellement destructurant; nécessite une validation stricte de reconstruction complète.
- Priorité : P2
- Complexité estimée : Élevée

### Ticket 8
- Titre : Nettoyer la documentation obsolète et les documents intermédiaires
- Objectif : supprimer ou réécrire les docs qui décrivent encore l’ancien noyau ou un état de transition dépassé.
- Partie de la spécification couverte : E5-US6
- Problème résolu : la doc peut réintroduire un modèle interdit même si le code est propre.
- Périmètre exact : réaligner `docs/` et le README, supprimer ou archiver clairement les docs intermédiaires, y compris les documents de tickets techniques devenus obsolètes si leur état n’est plus utile.
- Hors périmètre : ajout de nouvelles docs produit hors chantier.
- Pourquoi ce ticket est séparé : la doc doit être nettoyée une fois le runtime, les tests et le socle DB stabilisés.
- Composants potentiellement concernés : `docs/`, README si nécessaire
- Comportement attendu : aucune doc active ne décrit encore `client.services`, `client_opening_hours` ou `Resource.for_enseigne` comme moteur courant.
- Critères d’acceptation : les docs actives décrivent uniquement le socle cible; les docs intermédiaires restantes sont archivées ou signalées explicitement.
- Dépendances : Tickets 1, 5, 6 et 7
- Risques / points de vigilance : distinguer doc active, archive utile, et bruit obsolète.
- Priorité : P2
- Complexité estimée : Moyenne

## Recommandation finale
- Tickets à traiter en premier : 1, 2, 3, 4, 5, 6.
- Tickets à regrouper éventuellement : 4 et 5 si tu veux un seul ticket “cleanup tests/seeds/helpers”, mais seulement si l’équipe accepte un ticket plus large. 6 et 7 ne devraient pas être regroupés.
- Tickets à ne pas créer : un ticket fourre-tout “cleanup final du repo”; un ticket mélangeant suppression runtime, tests, schéma et docs; un ticket qui garde des artefacts legacy “pour mémoire”.
- Parties de la spécification à simplifier : aucune. Le bon ajustement était le split de `E5-US4` et `E5-US5`.
- Risques de mauvais découpage à éviter : faire de l’historique DB un sous-sujet du ticket schéma courant; supprimer des tests avant d’avoir supprimé les artefacts qu’ils couvrent; nettoyer les docs avant stabilisation du socle final.

Priorisation recommandée :
1. P1 immédiat : Tickets 1, 2, 3, 4, 5, 6
2. P2 ensuite : Tickets 7, 8
3. Ordre d’exécution conseillé : `1 -> 2 -> 3 -> 4 -> 5 -> 6 -> 7 -> 8`
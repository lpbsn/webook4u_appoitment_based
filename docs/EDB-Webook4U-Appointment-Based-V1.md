# EDB Webook4U Appointment-Based V1

## 1. Objet du document

Ce document formalise le besoin produit de Webook4U V1 dans sa version `appointment-based`.

Son objectif est de :

- cadrer précisément ce que Webook4U V1 doit être
- fixer les règles métier validées
- éviter le scope creep
- servir de base de travail pour les spécifications fonctionnelles et techniques

Ce document décrit la cible produit de la V1.
Il ne décrit pas uniquement l'état actuel du repository.

## 2. Contexte et opportunité

Le porteur du projet développe des sites vitrines Webflow pour des clients de proximité comme :

- salons de coiffure
- barbiers
- kinés
- coachs
- autres activités de service avec prise de rendez-vous

Ces clients demandent régulièrement un module de réservation.
Les solutions existantes sont souvent perçues comme insatisfaisantes pour les raisons suivantes :

- branding trop générique
- faible personnalisation
- intégration peu fluide sur un site vitrine
- maintenance lourde
- mauvaise expérience de plug and play

Webook4U répond à ce manque avec un moteur de réservation white-label, hébergé, administrable et intégrable progressivement dans les sites vitrines des clients.

## 3. Vision produit

Webook4U est un moteur de réservation white-label multi-tenant pour activités de service sur site.

Sa promesse V1 est :

- permettre à un client Webook4U de proposer une prise de rendez-vous en ligne cohérente avec son branding
- gérer la disponibilité, la sélection de créneau et la réservation
- permettre un paiement Stripe activable par client
- séparer strictement la réservation et le paiement

La logique produit cible est la suivante :

- Webook4U calcule et contrôle la réservation
- Stripe gère le paiement
- la réservation n'est confirmée qu'après succès du paiement si le paiement est activé pour le client
- si le paiement n'est pas activé, la réservation peut être confirmée sans passage par Stripe

## 4. Positionnement V1

### 4.1 Ce que Webook4U V1 est

Webook4U V1 est un moteur `appointment-based`.

Cela signifie que le produit gère :

- un rendez-vous individuel
- pour un service donné
- d'une durée définie
- exécuté par un staff physique
- sur un créneau unique

### 4.2 Ce que Webook4U V1 n'est pas

Webook4U V1 n'est pas :

- un CRM
- un ERP métier
- un logiciel comptable
- un moteur de réservation restaurant
- un moteur de réservation à capacité collective
- un moteur de réservation de ressources complexes
- un moteur d'annulation ou de replanification

## 5. Typologie de réservation retenue

La V1 ne supporte qu'une seule topologie de réservation : `appointment-based`.

### 5.1 Métiers compatibles V1

Le moteur V1 cible les métiers dont la logique principale est :

- `1 réservation = 1 service = 1 durée = 1 staff`

Exemples compatibles :

- coiffeur
- barbier
- kiné
- ostéo
- praticien bien-être
- coach en présentiel
- esthéticienne
- consultant recevant sur rendez-vous

### 5.2 Métiers exclus de la V1

Sont exclus de la V1 :

- restaurant
- réservation de table
- réservation de cours collectifs
- réservation par capacité
- réservation de salle ou de terrain
- réservation nécessitant plusieurs ressources simultanées

### 5.3 Règle d'éligibilité métier

Un métier est compatible V1 si les cinq réponses suivantes sont `oui` :

- le client réserve un rendez-vous individuel
- le service a une durée claire
- un staff identifiable peut exécuter le service
- un seul créneau suffit pour réserver
- la disponibilité dépend principalement du staff et non d'une capacité collective

## 6. Principes structurants validés

Les principes suivants sont considérés comme validés pour la V1 :

- Webook4U est la source de vérité de la réservation
- le paiement est séparé du moteur de réservation
- le paiement est géré par Stripe
- le paiement est activable par client
- le branding repose sur un thème proposé par Webook4U pour chaque client et non sur une UI sur mesure
- la distribution commence par une page hébergée
- l'iframe vient plus tard
- l'embed code vient après l'iframe
- l'onboarding client est manuel au départ

## 7. Périmètre fonctionnel V1

### 7.1 In scope

Webook4U V1 doit permettre :

- la gestion de plusieurs clients
- la gestion d'une ou plusieurs enseignes par client
- la gestion d'un thème par client
- la gestion des services d'une enseigne
- la gestion du prix et de la durée des services
- la gestion du staff par enseigne
- la gestion des staffs spécialisés par service au sein d'une enseigne
- la gestion des disponibilités du staff
- la gestion des horaires d'ouverture de l'enseigne
- la gestion des pauses et indisponibilités du staff
- la sélection publique d'une enseigne
- la sélection publique d'un service
- la sélection publique d'une date
- le calcul public des créneaux disponibles
- l'assignation automatique d'un staff via une logique de round robin parmi les staffs compatibles et disponibles
- la création d'une réservation temporaire bloquante
- le paiement Stripe si activé pour le client
- la confirmation finale de la réservation
- un back-office admin pour créer et gérer les clients
- un back-office client pour gérer son contexte métier

### 7.2 Out of scope

Webook4U V1 n'inclut pas :

- annulation de réservation
- replanification
- choix manuel du staff par l'utilisateur final
- réservation multi-services dans une même commande
- capacité collective
- ressources matérielles complexes
- logique restaurant
- logique piscine ou cours collectifs
- intégration CRM comme dépendance métier
- emails transactionnels dans le périmètre officiel
- multi-devises
- multi-fuseaux horaires
- self-service onboarding

## 8. Cible utilisateurs

### 8.1 Admin Webook4U

L'admin Webook4U est responsable de :

- créer un client
- proposer et configurer son thème
- configurer ses enseignes
- activer ou non le paiement
- superviser le bon fonctionnement de la plateforme

### 8.2 Client Webook4U

Le client Webook4U est responsable de :

- gérer ses enseignes
- gérer ses horaires d'ouverture
- gérer son staff
- définir quels staffs peuvent réaliser quels services
- gérer les disponibilités et pauses du staff
- gérer ses services
- gérer ses prix

### 8.3 Utilisateur final

L'utilisateur final souhaite :

- choisir une enseigne
- choisir une prestation
- choisir une date
- voir des créneaux disponibles
- réserver simplement
- payer si le client l'exige

## 9. Modèle métier cible

### 9.1 Structure racine

Le modèle métier cible V1 est :

- `Client`
- `Theme`
- `Enseigne`
- `OpeningHours`
- `ClosingException`
- `Staff`
- `StaffAvailability`
- `StaffUnavailability`
- `Service`
- `StaffServiceCapability`
- `Booking`
- `PaymentSession`

### 9.2 Hiérarchie conceptuelle

La hiérarchie produit est la suivante :

- un `Client` possède une ou plusieurs `Enseigne`
- une `Enseigne` porte son cadre d'ouverture
- une `Enseigne` possède un ou plusieurs `Staff`
- une `Enseigne` possède un catalogue de `Service`
- un `Staff` peut être habilité à réaliser un ou plusieurs `Service`
- un `Booking` réserve un créneau pour un `Service` assigné à un `Staff`

### 9.3 Principes de portage des données

Les règles de portage des données validées sont :

- le prix dépend du service
- la durée dépend du service
- le prix et la durée sont définis au niveau de l'enseigne
- une enseigne peut choisir un modèle polyvalent où tous les staffs réalisent tous les services
- une enseigne peut choisir un modèle spécialisé où seuls certains staffs réalisent certains services
- la relation `staff <-> service` doit donc être configurable explicitement
- le client final réserve un seul service par réservation
- l'utilisateur final ne choisit pas de staff en V1
- le système assigne automatiquement un staff via une logique de round robin parmi les staffs compatibles et disponibles

### 9.4 Règle de capacité

La ressource réservable cible de la V1 est le `Staff`.

Cela implique :

- l'enseigne définit le cadre d'ouverture général
- le staff définit la disponibilité réelle réservable
- un service n'est réservable que s'il existe au moins un staff disponible habilité à l'exécuter
- un créneau disponible résulte de l'intersection :
  - horaires de l'enseigne
  - compatibilité entre le service choisi et le staff
  - disponibilité du staff
  - indisponibilités du staff
  - durée du service
  - absence de conflit de réservation

### 9.5 Règles de compatibilité staff-service

La V1 doit supporter deux modes métier légitimes :

- `staff polyvalent`
  - tous les staffs d'une enseigne peuvent réaliser tous les services de cette enseigne
- `staff spécialisé`
  - seuls certains staffs peuvent réaliser certains services

Conséquences produit :

- la compatibilité `staff <-> service` ne doit jamais être implicite ou déduite uniquement de l'existence du staff et du service
- elle doit être portée par une relation métier explicite de type `StaffServiceCapability`
- l'absence de compatibilité doit rendre le staff inéligible pour le calcul de disponibilité du service concerné
- l'assignation automatique d'un staff ne doit choisir que parmi les staffs compatibles et disponibles

### 9.6 Règles d'assignation round robin

L'assignation automatique du staff repose en V1 sur une logique de round robin souple.

Cette logique s'applique par couple `enseigne + service`.

Règles validées :

- seuls les staffs actifs, compatibles et potentiellement réservables participent à la rotation
- l'ordre de rotation est propre à chaque couple `enseigne + service`
- lors d'une tentative de réservation, le moteur tente d'abord d'assigner le staff compatible le moins récemment sollicité pour ce service dans cette enseigne
- si ce staff n'est pas disponible sur le créneau choisi, le moteur passe au staff suivant dans l'ordre de rotation jusqu'à trouver un staff compatible et disponible
- le premier staff compatible et disponible trouvé est assigné au booking
- la rotation est mise à jour sur une réservation confirmée et non sur un simple `pending`

Garde-fous validés :

- le round robin n'est pas une recherche d'équité parfaite
- le round robin doit rester un mécanisme simple de répartition et ne doit pas dégrader la réservation
- le round robin ne doit jamais réduire artificiellement les créneaux visibles lorsqu'au moins un staff compatible est disponible
- l'utilisateur final ne choisit pas son staff et n'est pas exposé à la logique de distribution

## 10. Branding et distribution

### 10.1 Branding

Webook4U doit être brandable par client via un système de thème.

En V1, ce thème est proposé et configuré par l'admin Webook4U.
Le client ne gère pas lui-même son branding dans le produit.

Le thème doit au minimum permettre de configurer :

- logo
- couleurs
- typographie
- visuels principaux

Le branding ne doit pas conduire à des variantes métier ou UI sur mesure par client.

### 10.2 Distribution

La stratégie de distribution V1 est :

- page de réservation hébergée par Webook4U
- lien depuis le site vitrine du client

Stratégie ultérieure :

- iframe
- code embed

Le front doit être pensé dès la V1 comme un widget embarquable à terme, même si la première surface de distribution est une page hébergée.

## 11. Workflow utilisateur final

Le parcours public V1 est le suivant :

1. l'utilisateur ouvre la page de réservation hébergée du client
2. il choisit une enseigne
3. il choisit un service
4. il choisit une date
5. le moteur affiche les créneaux disponibles
6. il choisit un créneau
7. le système assigne automatiquement un staff selon une logique de round robin parmi les staffs compatibles et disponibles
8. le système crée une réservation temporaire bloquante
9. si le paiement est activé, l'utilisateur est dirigé vers Stripe
10. si le paiement réussit, la réservation est confirmée
11. si le paiement échoue ou expire, la réservation n'est pas confirmée et le créneau est libéré
12. si le paiement n'est pas activé, la réservation est confirmée directement

Cette assignation reste invisible pour l'utilisateur final.

## 12. Workflow back-office admin

Le back-office admin V1 doit permettre :

- créer un client
- définir et appliquer une identité de marque proposée au client
- activer ou désactiver le paiement
- créer une ou plusieurs enseignes
- superviser la cohérence des données de configuration

Le mode opératoire V1 reste compatible avec un onboarding manuel.

## 13. Workflow back-office client

Le back-office client V1 doit permettre :

- gérer les enseignes
- gérer les horaires d'ouverture par enseigne
- gérer le staff
- définir quels staffs peuvent réaliser quels services
- gérer les pauses et absences du staff
- gérer les services
- définir prix et durée des services

Le back-office client V1 ne doit pas exposer de moteur de distribution complexe.

Règles validées :

- le round robin est actif par défaut comme comportement standard du moteur
- le client peut gérer son staff et ses compatibilités service, mais pas piloter des stratégies avancées de distribution en V1

Explicitement hors périmètre V1 :

- pondérations par staff
- priorités manuelles
- quotas
- règles avancées de répartition de type `least busy`, `VIP first` ou `fixed preferred staff`

## 14. Règles de disponibilité

### 14.1 Règles générales

Les créneaux affichés doivent être calculés par Webook4U.

Un créneau est potentiellement réservable s'il respecte :

- le cadre d'ouverture de l'enseigne
- la disponibilité d'au moins un staff compatible dans la rotation du service
- l'absence d'indisponibilité ou de pause sur ce staff
- la durée du service
- les règles anti-conflit

### 14.2 Distinction entre disponibilité visible et assignation finale

La V1 distingue deux moments métier :

- `disponibilité visible`
  - un créneau doit être affiché dès lors qu'au moins un staff compatible est libre sur ce créneau
- `assignation finale`
  - une fois le créneau choisi, le moteur applique l'ordre round robin du couple `enseigne + service` et assigne le premier staff compatible et disponible trouvé

Règle structurante :

- le round robin intervient au moment de l'assignation et ne doit pas être utilisé comme filtre métier dur s'il réduit artificiellement les créneaux visibles

### 14.3 Granularité

La granularité affichée des créneaux ne repose pas sur un catalogue fixe de durées.

Le calcul doit être compatible avec :

- une durée de service portée par le service sélectionné
- un calcul libre du créneau de fin selon la durée du service

### 14.4 Anti-conflit V1

Les règles anti-conflit validées pour la V1 sont :

- aucun buffer avant ou après service
- un créneau est indisponible si son intervalle overlap un booking `confirmed`
- un créneau est indisponible si son intervalle overlap un booking `pending` actif
- deux réservations consécutives sont autorisées si la seconde commence exactement à l'heure de fin de la première

### 14.5 Réservation temporaire

Lorsqu'un utilisateur choisit un créneau, le système doit créer un verrou fonctionnel temporaire.

Ce verrou doit :

- empêcher qu'un autre utilisateur réserve le même intervalle pendant la fenêtre critique
- être lié à une réservation temporaire
- expirer automatiquement si la réservation n'est pas finalisée

## 15. Paiement

### 15.1 Positionnement

Le paiement est un module séparé de la réservation.

La séparation attendue est la suivante :

- la réservation calcule et verrouille le créneau
- le paiement tente de monétiser la réservation
- la confirmation finale dépend du résultat du paiement quand celui-ci est activé

### 15.2 Règle V1

Le paiement est activable par client.

Deux modes doivent coexister :

- `paiement désactivé`
  - la réservation peut être confirmée sans passage Stripe
- `paiement activé`
  - la réservation n'est confirmée qu'après succès Stripe

### 15.3 Statuts métier attendus

Le cycle de vie métier cible doit couvrir au minimum :

- `available`
- `pending_payment`
- `confirmed`
- `failed`
- `expired`

La traduction technique exacte pourra différer, mais le comportement produit doit couvrir ces états.

## 16. Données minimales du client final

En V1, les données minimales requises pour confirmer une réservation sont :

- prénom
- nom
- email

Le téléphone n'est pas requis en V1.

## 17. Contraintes de localisation V1

La V1 est volontairement simplifiée sur les dimensions géographiques.

Règles validées :

- fuseau horaire cible : Paris
- devise cible : euro

Le multi-fuseaux et la multi-devise sont hors périmètre V1.

## 18. CRM et intégrations externes

La V1 ne doit pas dépendre d'un CRM externe pour fonctionner.

Règles validées :

- Webook4U est la source de vérité du moteur de réservation
- l'intégration CRM est hors cœur V1
- une future synchronisation CRM pourra exister plus tard comme extension secondaire

## 19. Hypothèses d'implémentation à préserver

Pour rester cohérente avec la vision V1, l'implémentation doit préserver les choix suivants :

- ne pas mélanger règles de paiement et règles de réservation dans le même cœur métier
- ne pas dériver vers un modèle capacité ou restaurant
- ne pas rendre le branding dépendant de variations UI ad hoc
- ne pas faire du CRM une dépendance de la réservation
- ne pas introduire annulation ou replanification dans la V1
- ne pas réintroduire une ressource réservable implicite au niveau enseigne
- garder un round robin simple, déterministe et limité au couple `enseigne + service`
- si le prochain staff théorique n'est pas disponible, passer au suivant
- ne pas introduire de stratégie avancée de répartition dans la V1

## 20. Principaux risques produit

Les principaux risques à contrôler sont :

- élargir le scope à plusieurs topologies de réservation
- construire trop tôt des cas métiers non appointment-based
- laisser croire qu'un produit très brandable est un produit sur mesure
- concevoir le paiement comme un simple ajout d'interface et non comme un module transactionnel
- conserver un modèle de capacité par enseigne au lieu d'un modèle de disponibilité par staff
- transformer le round robin en moteur d'orchestration complexe
- sacrifier la disponibilité globale pour une équité théorique
- exposer la distribution staff à l'utilisateur final en V1

## 21. Résumé décisionnel

Webook4U V1 doit être compris comme :

- un moteur white-label multi-tenant
- pour activités à rendez-vous
- avec ressource réservable portée par le staff
- avec calcul interne de disponibilité
- avec assignation automatique du staff via un round robin souple par couple `enseigne + service`
- avec réservation temporaire bloquante
- avec paiement Stripe séparé et activable par client
- avec confirmation instantanée si le créneau est disponible et si les conditions de paiement sont satisfaites

Webook4U V1 ne doit pas être compris comme :

- un moteur universel de réservation tous secteurs
- un CRM
- un produit sur mesure par client
- un moteur restaurant ou capacité

## 22. Décisions ouvertes après V1

Les sujets suivants sont explicitement renvoyés après la V1 :

- iframe
- embed code
- annulation
- replanification
- emails transactionnels dans le périmètre officiel
- choix manuel du staff par l'utilisateur final
- intégrations CRM bidirectionnelles
- topologies capacity-based
- topologies restaurant/table-based

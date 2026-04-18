# Description exhaustive du besoin — Profils utilisateurs

## 1. Contexte

La plateforme de réservation doit introduire un système de **profils utilisateurs structuré et sécurisé** afin d’encadrer les accès, préparer les futurs dashboards, et poser un socle clair avant d’étendre les fonctionnalités métier.

Aujourd’hui, le besoin n’est pas de construire un système complexe de gestion d’identités multi-profils ou multi-rôles, mais de mettre en place une base simple, robuste et cohérente avec un MVP.

L’objectif est de définir :

- qui peut se connecter,
- à quel espace il accède,
- quelles données il peut consulter,
- et selon quel périmètre fonctionnel.

Le besoin s’inscrit dans un contexte de plateforme de réservation où coexistent :

- des administrateurs de la plateforme,
- des clients métier exploitant des enseignes,
- des utilisateurs finaux pouvant réserver,
- ainsi que des réservations anonymes sans compte.

------

## 2. Objectif du besoin

Le besoin consiste à mettre en place un système de **gestion des profils utilisateurs** reposant sur :

- **un modèle utilisateur unique**
- **un rôle unique par compte**
- **un login unifié**
- **des espaces séparés selon le rôle**
- **un contrôle d’accès strict côté serveur**
- **un périmètre de consultation des données dépendant du rôle**

Ce besoin doit permettre de construire un socle d’accès fiable avant d’introduire des écrans métier plus avancés.

L’objectif n’est pas encore de gérer des workflows complexes comme :

- l’annulation de réservation,
- la réattribution d’une réservation anonyme,
- l’impersonation,
- ou un système d’audit complet.

Ces éléments sont explicitement hors périmètre à ce stade.

------

## 3. Modèle cible de gestion des comptes

Le système doit reposer sur **un seul type de compte utilisateur**, représenté par un modèle `User` (confirmé par le cadrage, implémentation exacte à vérifier dans le repo).

Chaque compte utilisateur correspond à une identité unique de connexion.

Un compte utilisateur doit disposer, fonctionnellement, des attributs suivants :

- une adresse email unique globalement
- un mot de passe
- un rôle unique
- un prénom
- un nom
- un état actif ou inactif

Le système ne doit pas permettre, dans ce besoin, qu’un utilisateur possède plusieurs rôles.

------

## 4. Rôles fonctionnels

Trois rôles doivent être supportés.

### 4.1 Admin

Le rôle **Admin** représente un utilisateur interne à la plateforme.

Il a une vision globale et peut accéder à l’espace d’administration.

Il peut consulter l’ensemble des données relevant du périmètre de la plateforme, sans restriction liée à un client métier spécifique.

Son rôle est de piloter, administrer et superviser.

### 4.2 ClientUser

Le rôle **ClientUser** désigne un **compte utilisateur** rattaché à un **Client** métier.

Ce point est critique :

- **ClientUser** = compte de connexion
- **Client** = entité métier

Un `ClientUser` ne doit accéder qu’au périmètre du `Client` auquel il est rattaché.

Il ne doit jamais pouvoir consulter les données d’un autre client métier.

### 4.3 User

Le rôle **User** désigne l’utilisateur final de la plateforme.

C’est lui qui peut s’inscrire et se connecter à l’espace utilisateur.

Il n’a accès qu’à ses propres données et, dans le cadre du présent besoin, uniquement à ses propres réservations liées explicitement à son compte.

------

## 5. Principe fondamental de séparation des espaces

Le besoin impose une séparation claire des espaces applicatifs selon le rôle.

Les espaces cibles sont :

- `/admin/...`
- `/client/...`
- `/user/...`

Cette séparation n’est pas seulement cosmétique ou UX.
Elle porte une exigence de sécurité et de lisibilité produit.

Chaque rôle doit être dirigé vers son propre espace après connexion.

Cette séparation doit aussi être protégée côté serveur.
Un utilisateur connecté ne doit jamais pouvoir accéder à l’espace d’un autre rôle simplement en modifiant l’URL.

------

## 6. Authentification

Le besoin impose une **authentification unifiée**.

Tous les comptes, quel que soit leur rôle, utilisent :

- la même page de connexion
- le même mécanisme de login
- la même logique de base email + mot de passe

Après authentification réussie :

- un Admin est redirigé vers `/admin`
- un ClientUser est redirigé vers `/client`
- un User est redirigé vers `/user`

Le système doit donc déterminer le rôle du compte authentifié puis appliquer la redirection correcte.

------

## 7. Gestion de l’état actif / inactif

Le besoin prévoit qu’un compte utilisateur puisse être **désactivé**.

Le système doit gérer au minimum deux états fonctionnels :

- actif
- inactif

### Règles attendues

- un compte inactif ne peut plus se connecter
- les données historiques liées à ce compte sont conservées
- il n’y a pas de suppression physique imposée par ce besoin

Ce choix correspond à un MVP simple.
Il ne s’agit pas encore de gérer un cycle de vie riche du compte avec des statuts avancés comme :

- pending invitation
- suspended
- archived
- pending activation

Ces états plus riches sont hors périmètre actuel.

------

## 8. Création des comptes

### 8.1 Admin

Le compte admin est créé manuellement.

Ce besoin ne demande pas de self-signup admin.

### 8.2 ClientUser

Le compte `ClientUser` est créé par un admin.

Il doit être rattaché à un `Client` métier.

Un `ClientUser` ne peut pas exister sans périmètre client valide.

### 8.3 User

Le compte `User` peut être créé via un parcours d’inscription dédié.

Ce rôle correspond à l’utilisateur final.

------

## 9. Relation entre ClientUser et Client métier

Le besoin impose qu’un compte de rôle client soit relié à **un seul Client métier**.

Ce lien structure le périmètre d’accès du compte.

Conséquences fonctionnelles :

- un `ClientUser` agit toujours dans le cadre d’un seul `Client`
- il peut voir les données des enseignes de ce `Client`
- il ne peut pas sortir de ce périmètre

Ce besoin ne prévoit pas :

- un compte client rattaché à plusieurs clients métiers
- un compte avec multi-périmètre
- un système de délégation complexe

------

## 10. Réservations anonymes

Le besoin confirme qu’une réservation peut être effectuée **sans compte utilisateur**.

Dans ce cas :

- la réservation existe sans rattachement à un compte `User`
- elle reste indépendante d’une identité authentifiée

C’est un point structurant du modèle.

### Règle métier obligatoire

Une réservation anonyme **ne doit jamais être automatiquement rattachée** à un compte utilisateur sur la simple base d’un email identique.

Le système doit donc refuser toute logique implicite du type :

- “même email = même personne”
- “on rattache automatiquement après inscription”
- “on affiche au user toutes les réservations portant son email”

Le seul lien valable pour qu’une réservation apparaisse dans le dashboard d’un `User` est :

- un rattachement explicite par `user_id`

Cette règle doit être respectée partout.

------

## 11. Visibilité des réservations selon le rôle

## 11.1 Admin

L’admin peut consulter l’ensemble des réservations relevant de la plateforme.

Il a une vision globale.

## 11.2 ClientUser

Le `ClientUser` peut consulter uniquement les réservations relevant du périmètre de son `Client`.

Ce périmètre peut inclure les enseignes de ce client métier.

Le besoin impose ici un **scope strict** :

- pas de vue cross-client
- pas d’accès aux réservations d’un autre client métier

## 11.3 User

Le `User` final peut consulter uniquement ses propres réservations liées explicitement à son compte.

Dans le cadrage actuel, son dashboard affiche **uniquement les réservations `confirmed`** liées à son `user_id`.

Il ne doit pas voir :

- les réservations anonymes faites avec la même adresse email
- les réservations d’un autre utilisateur
- les réservations non liées à son compte

------

## 12. Scoping et sécurité

C’est le point technique le plus critique du besoin.

Le système doit appliquer les restrictions d’accès **côté serveur**.

Il ne suffit pas de :

- masquer des boutons,
- masquer des menus,
- ou rediriger côté front.

Les requêtes doivent être filtrées et validées côté serveur selon :

- le rôle
- l’identité du compte
- le périmètre du client métier
- l’identifiant utilisateur
- les règles d’accès au namespace

### Cas critiques à prévenir

- un `ClientUser` modifie l’URL pour essayer d’accéder aux données d’un autre client
- un `User` tente d’ouvrir un espace `/admin`
- un `User` tente de consulter une réservation d’un autre user
- un `ClientUser` tente d’accéder à un objet qui n’appartient pas à son client métier

La sécurité du besoin repose sur cette logique de scoping.

------

## 13. Nomenclature obligatoire

Le besoin impose une distinction stricte entre :

- **ClientUser** : compte utilisateur avec rôle client
- **Client** : entité métier

Cette distinction est nécessaire pour éviter une dette fonctionnelle et technique immédiate.

Le terme “client” est trop ambigu s’il est utilisé seul.

La nomenclature du projet, des tickets, des échanges et idéalement des objets applicatifs doit rester explicite pour éviter :

- les erreurs de compréhension,
- les bugs de périmètre,
- les associations ambiguës,
- les noms de variables trompeurs.

------

## 14. Backfill des comptes existants

Le besoin précise que **tous les comptes utilisateur déjà existants** doivent être considérés comme des comptes de rôle **`User`**.

Cette règle simplifie fortement la migration.

Conséquences :

- pas de stratégie complexe de classification initiale
- pas de mapping ambigu
- pas de détection heuristique des rôles existants

Le système doit donc prévoir qu’au moment de l’introduction du rôle :

- les comptes existants héritent du rôle `User`

Il faudra simplement vérifier dans le repo s’il existe des comptes particuliers qui devraient être traités autrement, mais la règle fonctionnelle cible est claire :
**par défaut, les comptes existants deviennent des `User`.**

------

## 15. Cas d’usage nominaux

### Cas 1 — Connexion d’un admin

1. l’admin saisit son email et son mot de passe
2. l’authentification réussit
3. le compte est actif
4. il est redirigé vers `/admin`
5. il accède à son espace global

### Cas 2 — Connexion d’un ClientUser

1. le compte client saisit ses identifiants
2. l’authentification réussit
3. le compte est actif
4. il est redirigé vers `/client`
5. il ne voit que les données du `Client` auquel il est rattaché

### Cas 3 — Inscription puis connexion d’un User

1. l’utilisateur final crée un compte
2. il se connecte avec email + mot de passe
3. si le compte est actif, il est redirigé vers `/user`
4. il voit uniquement ses réservations liées à son `user_id`
5. seules les réservations `confirmed` apparaissent dans son dashboard

### Cas 4 — Réservation anonyme

1. un visiteur réserve sans compte
2. la réservation est créée sans rattachement à un `user_id`
3. cette réservation n’apparaît dans aucun dashboard user sur la simple base de l’email

------

## 16. Cas limites et comportements attendus

Le système doit correctement gérer les cas suivants :

- tentative d’accès à un namespace non autorisé
- compte inactif tentant de se connecter
- `ClientUser` sans rattachement valide à un `Client`
- tentative de consultation d’une réservation hors périmètre
- réservation anonyme avec un email identique à celui d’un user existant
- users historiques existants sans rôle avant migration
- accès direct à un identifiant d’objet ne relevant pas du bon client métier

------

## 17. Hors périmètre explicite

Les éléments suivants sont retirés du besoin actuel :

- annulation de réservation par client
- annulation automatique liée à la désactivation d’un compte
- ajout d’un statut `cancelled`
- réattribution ou revendication des réservations anonymes
- impersonation admin
- audit log complet
- gestion multi-rôle
- rattachement d’un compte à plusieurs clients métiers
- suppression physique des comptes

Ces sujets pourront être cadrés plus tard, mais ils ne doivent pas polluer l’implémentation du socle actuel.

------

## 18. Résultat attendu

À l’issue de ce besoin, la plateforme doit disposer d’un socle clair permettant :

- une gestion unifiée des comptes via `User`
- un rôle unique par compte
- une authentification unifiée
- une redirection post-login selon le rôle
- une séparation stricte des espaces
- un blocage des comptes inactifs
- un scoping serveur-side sécurisé
- une consultation des réservations conforme au rôle
- une non-visibilité des réservations anonymes pour les users si elles ne sont pas liées par `user_id`

------

## 19. Synthèse du besoin

Le besoin vise à construire le **socle d’identité et d’autorisation** de la plateforme.

Ce socle doit être :

- simple pour le MVP,
- robuste sur la sécurité,
- clair dans la séparation des responsabilités,
- compatible avec l’évolution future des dashboards et modules métier.

Le cœur du besoin n’est pas seulement “ajouter des rôles”.
Le vrai besoin est :

- **définir qui est qui**
- **définir où chacun peut aller**
- **définir ce que chacun peut voir**
- **garantir que personne ne sort de son périmètre**


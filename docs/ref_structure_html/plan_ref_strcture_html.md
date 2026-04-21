## Ce que leur analyse confirme

### 1. Le flow public est déjà partiellement encapsulé côté backend

`PublicClientsController#show` délègue la construction de l’état de page à `Bookings::PublicPage.new(...).call`, puis hydrate une série d’instance variables pour la vue

Conséquence :

- je **ne recommande plus** de déplacer agressivement la logique du flow vers le controller
- le bon niveau de refactor est plutôt :
  - vue plus légère
  - paramétrage partagé
  - éventuellement un petit presenter de vue, mais **pas** un gros “flow engine” en doublon de `Bookings::PublicPage`

### 2. Le vrai contrat du flow est porté par les params

Le flow public dépend fortement des params :

- `enseigne_id`
- `service_id`
- `assignment_mode`
- `staff_id`
- `search_mode`
- `selected_start_time`
- `date`
- `selected_days_of_week`
- `start_time_min`
- `start_time_max`

Et `BookingsController` reconstruit/rediffuse ces mêmes paramètres dans plusieurs redirections (`redirect_to_pending_selection`, `pending_selection_context`)

Conséquence :

- le **plus gros levier de refactor** n’est pas de “réécrire les étapes”
- c’est de **centraliser le contrat des paramètres du flow**

### 3. Le wizard admin est déjà structuré côté controller

`Admin::ClientsController` est mieux organisé que la vue le laissait penser :

- `process_step_1!` à `process_step_4!`
- `build_forms_for_step`
- `step_*_params`
- `wizard_support`
- gestion de brouillon en session

Conséquence :

- le problème principal du wizard n’est **pas** le controller
- c’est bien la vue `admin/clients/new.html.erb`, qui concentre trop de markup et du JS inline

### 4. `Admin::UsersController` est simple

Il confirme que le refactor sur la zone users doit rester léger :

- vues factorisées
- HTML plus propre
- pas besoin d’introduire une couche complexe ici

------

# Plan de refactor mis à jour

Objectif inchangé : **améliorer la structure HTML et la scalabilité sans changer le comportement fonctionnel**.

La différence par rapport au plan précédent :

- on **réduit l’ambition** sur un gros presenter de flow public
- on **renforce** la centralisation des paramètres de flow
- on **confirme** que la priorité critique reste la vue wizard admin

------

# Phase 1 — gains rapides, très faible risque

## 1. Unifier les blocs HTML récurrents

### À faire

Créer des partials partagés pour :

- header de page
- erreurs formulaire
- flashs
- ligne label/valeur
- barre d’actions

### Fichiers à créer

- `app/views/shared/_page_header.html.erb`
- `app/views/shared/_error_list.html.erb`
- `app/views/shared/_flash_messages.html.erb`
- `app/views/shared/_summary_row.html.erb`
- `app/views/shared/_action_bar.html.erb`

### Pourquoi

Beaucoup de vues répètent le même markup avec peu de variations

### Risque

Faible.

------

## 2. Harmoniser les flashs dans les layouts

### Constat

`application.html.erb` utilise des `<p>` bruts, alors que `booking.html.erb` utilise un composant visuel cohérent

### Action

Rendre le même partial `shared/flash_messages` dans les deux layouts.

### Risque

Très faible.

------

## 3. Introduire un composant de rendu d’erreurs standard

### Constat

Le pattern d’erreur est très répété :

- `@booking.errors`
- `resource.errors`
- `client.errors`
- `client_user.errors`
- `@client_form.errors`
- `@service_form.errors`

### Action

Créer un partial unique qui prend :

- `resource:`
- `title:`
- éventuellement `messages:`

### Risque

Faible.

------

# Phase 2 — flow public : priorité maximale

C’est la zone la plus sensible, car contrôleurs et vues reposent sur le même contrat de params.

## 4. Centraliser le contrat des paramètres du flow public

### Nouveau point clé après lecture des contrôleurs

`PublicClientsController` et `BookingsController` partagent implicitement le même vocabulaire de params

### Action

Créer un helper ou objet très léger dédié, par exemple :

- `PublicClientsFlowParamsHelper`
- ou un module helper dans `app/helpers/public_clients_helper.rb`

Responsabilités :

- construire le hash canonique des params du flow
- rendre les hidden fields communs
- éviter la dérive entre les vues et les redirections du controller

### Méthodes possibles

- `public_flow_params(...)`
- `public_flow_hidden_fields(...)`

### Pourquoi c’est désormais la priorité #1

Parce que le vrai couplage n’est pas “vue ↔ CSS”, mais :

> vues ↔ paramètres ↔ redirections controller

### Risque

Faible à moyen, mais très rentable.

------

## 5. Créer un partial générique de “choice form”

### Cible

Les étapes :

- `_enseigne_step`
- `_service_step`
- `_assignment_step`
- `_search_mode_step`
- une partie de `_date_step`
- une partie de `_slots_step`

### À créer

- `app/views/public_clients/_choice_form.html.erb`

Responsabilité :

- `form_with ... method: :get`
- rendre automatiquement les hidden fields du flow
- rendre le bouton sélectionnable

### Pourquoi

C’est là que tu as le plus de duplication HTML.

### Risque

Faible si tu gardes strictement les mêmes params et les mêmes submit buttons.

------

## 6. Extraire les blocs de contexte “enseigne / service / durée”

### Constat

Beaucoup d’étapes affichent un mini-récap commun :

- enseigne
- service
- durée

### Action

Créer un partial du type :

- `app/views/public_clients/_step_context.html.erb`

### Risque

Très faible.

------

## 7. Ne pas créer un gros presenter de flow tout de suite

### Mise à jour importante

Avant lecture des contrôleurs, un gros `PublicBookingFlowPresenter` semblait pertinent.
Après lecture, ce serait probablement une duplication partielle de `Bookings::PublicPage`

### Recommandation mise à jour

Ne fais pas un presenter métier lourd.

Fais plutôt, si besoin :

- un **petit presenter de vue** ou helper de lisibilité
- limité à des choses comme :
  - `assignment_complete?`
  - `selected_precise_date_mode?`
  - `selected_first_available_mode?`

Mais **pas** de logique de calcul métier ni de reconstruction de l’état du flow.

### Risque évité

Créer deux sources de vérité :

- `Bookings::PublicPage`
- un presenter de flow côté vue

------

## 8. Stabiliser la sélection/récap du flow autour d’un seul contrat

### Action

Faire converger :

- `public_clients/show.html.erb`
- les partials d’étapes
- `BookingsController#redirect_to_pending_selection`
- `BookingsController#pending_selection_context`

vers le même schéma de params

### Recommandation concrète

Créer un “contrat” explicite, même minimal, par convention :

- liste officielle des clés de flow
- ordre stable
- helper partagé

### Pourquoi

C’est le point qui évitera le plus de bugs futurs.

------

# Phase 3 — wizard admin : deuxième priorité critique

## 9. Découper `admin/clients/new.html.erb` par étape

### Confirmé par lecture du controller

Le controller wizard est déjà suffisamment structuré :

- les étapes sont nettes
- les données sont préparées proprement par `build_forms_for_step`

Donc le refactor doit viser la vue, pas le controller.

### À créer

- `app/views/admin/clients/new/_wizard_header.html.erb`
- `app/views/admin/clients/new/_step_client.html.erb`
- `app/views/admin/clients/new/_step_enseignes.html.erb`
- `app/views/admin/clients/new/_step_service.html.erb`
- `app/views/admin/clients/new/_step_staffs.html.erb`

### Résultat

`new.html.erb` devient une simple vue d’orchestration.

------

## 10. Extraire les blocs dynamiques “enseigne” et “staff”

### Constat

Le controller prépare déjà proprement :

- `@enseignes_draft_entries`
- `@staffs_draft_entries`

Donc tu peux découper sans toucher à la logique controller.

### À créer

- `app/views/admin/clients/new/_enseigne_fields.html.erb`
- `app/views/admin/clients/new/_staff_fields.html.erb`

### But

Réduire :

- duplication serveur/template
- taille de la vue
- risque de divergence

------

## 11. Sortir le JS inline de la vue wizard

### Constat

Le controller ne porte pas ce comportement, donc il est normal de l’extraire côté front sans impact fonctionnel

### Recommandation

Étape 1 :

- sortir le JS dans un fichier dédié

Étape 2 éventuelle :

- migrer vers Stimulus

### Important

Ne fais pas la migration Stimulus en même temps que le découpage HTML si tu veux minimiser le risque.

------

## 12. Ne pas refactorer le controller wizard maintenant

### Mise à jour importante

Après lecture, je **ne recommande pas** de refactorer fortement `Admin::ClientsController` dans ce chantier HTML.
Il est déjà assez clair et découpé

Le gain marginal serait faible par rapport au risque.

------

# Phase 4 — surfaces admin/user secondaires

## 13. Factoriser les écrans index répétitifs

### Cible

- `admin/bookings/index`
- `client/bookings/index`
- `user/bookings/index`
- parties de `admin/clients/index`
- `admin/users/index`

### Action

Créer des composants de structure, pas des composants “magiques” :

- `shared/_stats_summary.html.erb`
- `shared/_table_wrapper.html.erb`
- `shared/_status_pill.html.erb`

### Pourquoi

Gains de lisibilité, sans couplage excessif.

------

## 14. Garder `Admin::UsersController` simple

### Mise à jour

Après lecture, inutile d’introduire une abstraction lourde sur la zone users

### Action

Seulement :

- améliorer les partials
- harmoniser le markup
- garder le controller inchangé

------

# Phase 5 — accessibilité et sémantique

## 15. Améliorer la sémantique des résumés

### Action

Migrer progressivement certains couples label/valeur vers :

- `dl`
- `dt`
- `dd`

### Cible

- `_selection_summary`
- `_booking_summary`
- certaines sections de succès / admin wizard

------

## 16. Améliorer l’accessibilité des messages et contrôles

### Action

- `role="alert"` sur erreurs/flashs importants
- meilleur libellé accessible pour le lien retour
- `fieldset/legend` pour groupes de choix pertinents
- meilleure sémantique pour le wizard

### Risque

Très faible.

------

# Phase 6 — CSS, en dernier

## 17. Découper `booking.css`

### Recommandation confirmée

Toujours utile, mais toujours **après** le refactor HTML, pas avant

### Ordre conseillé

- `layout.css`
- `components.css`
- `forms.css`
- `tables.css`
- `public_flow.css`
- `admin_wizard.css`

------

# Nouveau classement des priorités

## Priorité absolue

1. centraliser les params du flow public
2. créer `_choice_form` pour les sélections GET
3. extraire les partials partagés simples (`page_header`, `error_list`, `flash_messages`, `summary_row`)
4. découper `admin/clients/new.html.erb` par étape

## Priorité haute

1. extraire les blocs dynamiques enseigne/staff
2. sortir le JS inline du wizard
3. factoriser les wrappers de tables et status pills

## Priorité moyenne

1. petit helper/presenter de lisibilité pour la vue publique, mais pas de gros presenter métier
2. améliorer la sémantique HTML
3. découper `booking.css`

------

# Recommandation finale mise à jour

La vraie stratégie optimale n’est plus :

> “créer beaucoup d’abstractions de vue”

mais plutôt :

> “sécuriser le contrat de params du flow public, puis réduire la duplication HTML autour de ce contrat”

Et pour l’admin :

> “laisser le controller wizard tranquille, refactorer massivement la vue wizard”

Donc, le meilleur ordre de travail est désormais :

### Lot 1

- `shared/_flash_messages`
- `shared/_page_header`
- `shared/_error_list`
- `shared/_summary_row`

### Lot 2

- helper central des params de flow public
- `public_clients/_choice_form`
- extraction des micro-partials de contexte public

### Lot 3

- découpage de `admin/clients/new.html.erb`
- extraction `_enseigne_fields` / `_staff_fields`
- sortie du JS inline

### Lot 4

- wrappers de tables
- sémantique/accessibilité
- découpage CSS

Si tu veux, l’étape la plus utile maintenant est que je te prépare un **plan opérationnel fichier par fichier**, avec :

- fichier source
- modification exacte
- nouveaux fichiers à créer
- ordre d’implémentation
- niveau de risque par lot.x

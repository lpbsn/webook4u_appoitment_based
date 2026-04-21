Oui. Voici des **prompts Cursor prêts à copier-coller**, structurés pour une exécution par ticket ou par lot cohérent.

Je regroupe certains tickets quand c’est logique et sûr.
Je garde une approche **petites PRs, faible risque, sans changement fonctionnel**.

## Cadre global obligatoire

- Source de vérité unique: `docs/ref_structure_html/backlog_technique_ref_structure_html`
- Pas de règle stricte `1 PR = 1 ticket`; les PR multi-tickets sont autorisées si le scope reste cohérent
- Niveau de preuve minimal pour tout prompt exécuté:
  - smoke test manuel sur le périmètre modifié
  - `bin/check` vert
- Si `app/views/public_clients/_slots_step.html.erb` devient inutile et non référencé après refactor, sa suppression est autorisée

------

# Prompt 1 — Ticket 1

## Composants partagés simples

```text
Mission:
Implémenter le refactor correspondant au TICKET 1:
Créer les partials partagés de base pour réduire la duplication ERB sans changer le comportement fonctionnel.

Objectif:
Créer et intégrer les partials suivants:
- app/views/shared/_page_header.html.erb
- app/views/shared/_error_list.html.erb
- app/views/shared/_flash_messages.html.erb
- app/views/shared/_summary_row.html.erb

Fichiers à modifier:
- app/views/layouts/application.html.erb
- app/views/layouts/booking.html.erb
- app/views/bookings/show.html.erb
- app/views/client/bookings/index.html.erb
- app/views/devise/registrations/new.html.erb
- app/views/devise/sessions/new.html.erb
- app/views/user/bookings/index.html.erb
- app/views/admin/bookings/index.html.erb
- app/views/admin/clients/edit.html.erb
- app/views/admin/clients/index.html.erb
- app/views/admin/clients/new.html.erb
- app/views/admin/users/edit.html.erb
- app/views/admin/users/index.html.erb
- app/views/admin/users/new.html.erb

Contraintes strictes:
- Ne pas changer le comportement fonctionnel
- Ne pas changer les routes
- Ne pas changer les controllers
- Ne pas changer les contrats params du flow booking
- Ne pas changer le wording visible
- Conserver le rendu visuel équivalent
- Réutiliser les classes CSS existantes
- Ne rien inventer hors des fichiers existants
- Ne pas créer d’abstractions inutiles

API attendue des partials:
1. shared/_page_header.html.erb
   - locals minimum: title:, subtitle:
2. shared/_error_list.html.erb
   - locals minimum: messages:, title:
3. shared/_flash_messages.html.erb
   - doit gérer notice et alert
4. shared/_summary_row.html.erb
   - locals minimum: label:, value:

Instructions de travail:
1. Analyse rapidement la duplication actuelle
2. Liste les fichiers que tu vas modifier/créer
3. Implémente uniquement ce ticket
4. Remplace le markup répétitif par des renders de partials
5. Garde le diff aussi petit que possible
6. Si un écran ne se prête pas proprement au partial sans risque, signale-le et n’invente pas

Ce que je veux dans ta réponse:
- analyse rapide
- fichiers créés
- fichiers modifiés
- résumé des changements
- risques éventuels
- validations manuelles à effectuer

Validation manuelle attendue:
- pages booking show/success/index
- pages devise login/register
- pages admin clients/users
- vérification notice/alert dans application layout et booking layout
```

------

# Prompt 2 — Ticket 2

## Centraliser les params du flow public

```text
Mission:
Implémenter le refactor correspondant au TICKET 2:
Centraliser les paramètres du flow public sans changer leur contrat externe.

Objectif:
Créer une petite API helper + un partial technique pour éviter la répétition des hidden fields du flow booking public.

Fichiers à modifier:
- app/helpers/public_clients_helper.rb

Fichiers à créer:
- app/views/public_clients/_flow_hidden_fields.html.erb

Contexte important:
Le contrat de params du flow public est déjà utilisé côté vues et côté controllers.
Tu dois préserver strictement la compatibilité avec:
- PublicClientsController#show
- BookingsController#create_pending
- BookingsController#create
- les redirections internes du flow booking

Clés à couvrir:
- enseigne_id
- service_id
- assignment_mode
- staff_id
- search_mode
- date
- selected_start_time
- selected_days_of_week
- start_time_min
- start_time_max

Contraintes strictes:
- Ne pas changer les noms de params
- Ne pas changer les routes
- Ne pas changer les controllers
- Ne pas changer le comportement visible
- Ne pas supprimer de param aujourd’hui utilisé
- Ne pas introduire de presenter métier
- Ne pas refactorer d’autres zones du repo

Travail attendu:
1. Analyse le contrat implicite de params à partir des fichiers déjà présents dans le repo
2. Ajoute dans PublicClientsHelper une API minimale et claire pour construire les params du flow
3. Crée le partial _flow_hidden_fields.html.erb
4. N’utilise pas encore ce partial partout si cela dépasse le scope; prépare simplement la brique commune proprement

Je veux dans ta réponse:
- l’API helper choisie et pourquoi
- les fichiers créés/modifiés
- les points de compatibilité garantis
- les validations manuelles recommandées

Validation manuelle attendue:
- vérifier que les params générés restent compatibles avec les étapes du flow public
- vérifier qu’aucun comportement n’est changé
```

------

# Prompt 3 — Tickets 3 + 4

## Factoriser les choix GET + contexte commun des étapes publiques

```text
Mission:
Implémenter les TICKETS 3 et 4 ensemble, car ils sont fortement liés:
- créer un partial générique de sélection GET pour le flow public
- extraire le contexte commun des étapes publiques

Objectif:
Réduire la duplication HTML dans le parcours public sans changer le comportement fonctionnel ni la logique métier.

Fichiers à créer:
- app/views/public_clients/_choice_form.html.erb
- app/views/public_clients/_step_context.html.erb

Fichiers à modifier:
- app/views/public_clients/_enseigne_step.html.erb
- app/views/public_clients/_service_step.html.erb
- app/views/public_clients/_assignment_step.html.erb
- app/views/public_clients/_search_mode_step.html.erb
- app/views/public_clients/_first_available_step.html.erb
- app/views/public_clients/_first_available_result_step.html.erb
- app/views/public_clients/_date_step.html.erb

Dépendance:
Tu peux t’appuyer sur le helper / partial technique du ticket précédent s’ils existent déjà:
- public flow params helper
- app/views/public_clients/_flow_hidden_fields.html.erb

Contraintes strictes:
- Ne pas changer le comportement fonctionnel
- Ne pas changer les conditions d’affichage des étapes
- Ne pas changer les routes
- Ne pas changer les controllers
- Ne pas changer les params du flow
- Ne pas changer le wording visible
- Réutiliser les classes CSS existantes
- Ne pas introduire un gros presenter métier du flow

Détail attendu:
1. _choice_form.html.erb doit permettre de factoriser les formulaires GET de sélection:
   - url
   - hidden fields
   - label
   - selected
   - classes bouton
2. _step_context.html.erb doit factoriser le petit bloc répétitif qui affiche:
   - enseigne
   - service
   - durée
3. Refactorer d’abord les fichiers simples:
   - _enseigne_step
   - _service_step
   - _assignment_step
   - _search_mode_step
4. Puis utiliser _step_context dans:
   - _search_mode_step
   - _first_available_step
   - _first_available_result_step
   - _date_step

Important:
- Pour _date_step, ne cherche pas à tout abstraire agressivement si cela augmente le risque
- Fais un refactor pragmatique et sûr
- Garde le diff aussi petit que possible

Je veux dans ta réponse:
- analyse rapide des risques
- liste exacte des fichiers modifiés/créés
- résumé de la nouvelle structure
- validations manuelles recommandées

Validation manuelle attendue:
- sélection enseigne
- sélection service
- sélection staff
- choix du mode de recherche
- affichage correct du contexte dans les étapes concernées
```

------

# Prompt 4 — Ticket 5

## Refactorer les formulaires complexes du flow public

```text
Mission:
Implémenter le TICKET 5:
Refactorer les formulaires complexes restants du flow public pour réduire la duplication sans changer le comportement.

Fichiers à modifier:
- app/views/public_clients/_date_step.html.erb
- app/views/public_clients/_selected_slot_confirmation_step.html.erb
- app/views/public_clients/_first_available_result_step.html.erb
- app/views/public_clients/show.html.erb
- app/views/public_clients/_slots_step.html.erb (à supprimer seulement si non référencé et sans utilité restante)

Dépendances possibles:
- app/views/public_clients/_flow_hidden_fields.html.erb
- app/views/public_clients/_choice_form.html.erb
- app/views/public_clients/_step_context.html.erb

Contraintes strictes:
- Ne pas changer le comportement fonctionnel
- Ne pas changer les routes
- Ne pas changer les controllers
- Ne pas changer les params du flow
- Ne pas changer la logique métier
- Ne pas réécrire Bookings::PublicPage
- Ne pas introduire un presenter métier en doublon
- Conserver le rendu visuel équivalent

Travail attendu:
1. Réduire la répétition de hidden fields via le partial commun
2. Refactorer avec prudence _date_step:
   - navigation semaine précédente / suivante
   - sélection de slots
3. Refactorer _selected_slot_confirmation_step
4. Refactorer _first_available_result_step
5. Nettoyer légèrement public_clients/show.html.erb sans changer son rôle d’orchestration

Important:
- Le flow public repose fortement sur le contrat actuel des params
- Toute modification doit préserver exactement ce contrat
- Si une abstraction semble risquée, choisis la solution la plus sûre

Je veux dans ta réponse:
- analyse des zones à risque
- fichiers créés/modifiés
- détails des parties refactorées
- points explicitement laissés en l’état pour prudence
- résultat de `bin/check`
- validations manuelles recommandées

Validation manuelle attendue:
- flow “Date précise”
- flow “Premier créneau disponible”
- sélection d’un créneau
- accès à la confirmation
- vérification des params transmis à chaque étape
```

------

# Prompt 5 — Ticket 6

## Découper la vue wizard admin par étapes

```text
Mission:
Implémenter le TICKET 6:
Découper la vue wizard admin app/views/admin/clients/new.html.erb par étapes sans toucher au controller.

Objectif:
Réduire fortement la taille et la complexité de la vue du wizard admin en extrayant les étapes dans des partials dédiés.

Fichiers à créer:
- app/views/admin/clients/new/_wizard_header.html.erb
- app/views/admin/clients/new/_step_client.html.erb
- app/views/admin/clients/new/_step_enseignes.html.erb
- app/views/admin/clients/new/_step_service.html.erb
- app/views/admin/clients/new/_step_staffs.html.erb

Fichier à modifier:
- app/views/admin/clients/new.html.erb

Contraintes strictes:
- Ne pas modifier Admin::ClientsController
- Ne pas modifier les params du wizard
- Ne pas modifier la logique du draft en session
- Ne pas modifier le wording visible
- Ne pas modifier le comportement du wizard
- Ne pas extraire encore le JS inline si cela dépasse le scope
- Le rendu visuel doit rester équivalent

Travail attendu:
1. Extraire le header + progression + tabs dans _wizard_header
2. Extraire chaque étape dans un partial dédié
3. Réduire new.html.erb à une vue orchestratrice
4. Laisser temporairement les templates dynamiques / JS inline en place si nécessaire pour rester dans le scope

Important:
- Le controller est déjà structuré; le refactor doit viser la vue, pas la logique controller
- Priorité à la lisibilité et à la sécurité
- Garde une structure simple et explicite

Je veux dans ta réponse:
- analyse rapide
- fichiers créés/modifiés
- nouvelle structure proposée
- risques éventuels
- validations manuelles recommandées

Validation manuelle attendue:
- étape 1 -> 2
- étape 2 -> 3
- étape 3 -> 4
- erreurs sur chaque étape
- retour arrière
- restart du wizard
```

------

# Prompt 6 — Ticket 7

## Extraire les blocs dynamiques enseigne/staff du wizard

```text
Mission:
Implémenter le TICKET 7:
Extraire les blocs dynamiques enseigne/staff du wizard admin pour réduire la duplication HTML.

Fichiers à créer:
- app/views/admin/clients/new/_enseigne_fields.html.erb
- app/views/admin/clients/new/_staff_fields.html.erb

Fichiers à modifier:
- app/views/admin/clients/new/_step_enseignes.html.erb
- app/views/admin/clients/new/_step_staffs.html.erb
- éventuellement app/views/admin/clients/new.html.erb si certains templates y restent encore

Contraintes strictes:
- Ne pas changer les noms de champs HTML name=...
- Ne pas changer les ids si cela risque de casser le JS existant
- Ne pas modifier le parsing controller:
  - step_2_enseignes_params
  - step_4_staffs_params
- Ne pas changer le comportement fonctionnel
- Ne pas changer le wording visible
- Le rendu visuel doit rester équivalent

Travail attendu:
1. Extraire le markup des blocs rendus côté serveur en partials dédiés
2. Réduire la duplication structurelle
3. Rapprocher autant que possible la structure du HTML serveur et celle des templates dynamiques
4. Ne pas chercher une abstraction trop ambitieuse si elle augmente le risque

Important:
- Préserver strictement la compatibilité avec les params attendus par le controller
- Si une mutualisation parfaite entre bloc serveur et template client est trop risquée, le signaler et choisir une solution pragmatique

Je veux dans ta réponse:
- analyse rapide des risques
- fichiers créés/modifiés
- détails des champs/ids/name explicitement préservés
- validations manuelles recommandées

Validation manuelle attendue:
- ajout/suppression d’enseignes
- ajout/suppression de staffs
- soumission étape 2
- soumission étape 4
- vérification des params envoyés
```

------

# Prompt 7 — Ticket 8

## Sortir le JS inline du wizard admin

```text
Mission:
Implémenter le TICKET 8:
Sortir le JS inline du wizard admin vers un fichier dédié, sans changer le comportement.

Objectif:
Retirer le <script> inline de la vue du wizard admin et isoler le comportement dynamique dans un fichier JS dédié compatible avec le setup actuel du repo.

Fichiers à modifier:
- app/views/admin/clients/new.html.erb
- les éventuels fichiers JS d’entrée existants nécessaires au chargement

Fichiers à créer:
- un fichier JS dédié au wizard admin, selon le setup actuel du repository

Contraintes strictes:
- Ne pas migrer tout de suite vers Stimulus si ce n’est pas déjà en place
- Ne pas changer le comportement
- Ne pas changer les ids/data attributes/classes utilisés comme hooks
- Ne pas changer le wording visible
- Le rendu visuel doit rester équivalent

Le JS doit continuer à gérer:
- ajout de blocs
- suppression de blocs
- synchronisation des boutons trash
- activation/désactivation des champs time selon checkbox

Travail attendu:
1. Identifier le meilleur emplacement JS compatible avec le projet
2. Extraire le script inline dans un fichier dédié
3. Mettre à jour la vue pour ne plus contenir ce script inline
4. Conserver strictement le même comportement

Important:
- Ce ticket est un refactor technique, pas une refonte front
- Si le setup JS actuel impose une contrainte, l’expliquer clairement
- Ne pas introduire de dépendance inutile

Je veux dans ta réponse:
- analyse rapide du setup JS observé
- fichiers créés/modifiés
- résumé du comportement conservé
- risques éventuels
- validations manuelles recommandées

Validation manuelle attendue:
- parcours complet du wizard
- ajout/suppression de blocs
- activation/désactivation des time fields
- vérification qu’aucune erreur JS n’apparaît
```

------

# Prompt 8 — Ticket 9

## Factoriser wrappers de tableaux et statuts

```text
Mission:
Implémenter le TICKET 9:
Factoriser les wrappers de tableaux et le rendu des statuts sur les pages index admin/client/user.

Fichiers à créer:
- app/views/shared/_table_wrapper.html.erb
- app/views/shared/_status_pill.html.erb
- optionnel: app/views/shared/_stats_summary.html.erb si cela simplifie proprement

Fichiers à modifier:
- app/views/client/bookings/index.html.erb
- app/views/user/bookings/index.html.erb
- app/views/admin/bookings/index.html.erb
- app/views/admin/clients/index.html.erb
- app/views/admin/users/index.html.erb

Contraintes strictes:
- Ne pas changer les colonnes
- Ne pas changer les actions disponibles
- Ne pas changer le wording visible
- Ne pas changer le comportement fonctionnel
- Réutiliser les classes CSS existantes
- Ne pas introduire de composant trop abstrait ou trop “magique”

Travail attendu:
1. Extraire le wrapper répétitif des tables
2. Extraire le rendu du statut dans un partial partagé
3. Éventuellement extraire le petit bloc stats si cela reste simple et sûr
4. Garder les vues lisibles et explicites

Important:
- Ce ticket doit rester pragmatique
- Si un écran s’écarte trop du pattern, le laisser en l’état et le signaler

Je veux dans ta réponse:
- analyse rapide
- fichiers créés/modifiés
- parties factorisées
- parties volontairement non factorisées
- validations manuelles recommandées

Validation manuelle attendue:
- vérifier les 5 pages index
- vérifier les liens/boutons d’action
- vérifier l’affichage des statuts
```

------

# Prompt 9 — Ticket 10

## Sémantique HTML et accessibilité légère

```text
Mission:
Implémenter le TICKET 10:
Améliorer la sémantique HTML et l’accessibilité légère sans impact fonctionnel ni visuel majeur.

Fichiers à modifier:
- app/views/layouts/booking.html.erb
- app/views/bookings/_booking_summary.html.erb
- app/views/public_clients/_selection_summary.html.erb
- app/views/bookings/success.html.erb
- app/views/shared/_flash_messages.html.erb

Contraintes strictes:
- Ne pas changer le comportement
- Ne pas changer le wording visible sauf pour améliorer l’accessibilité non visible
- Ne pas casser le CSS existant
- Ne pas casser le JS existant
- Le rendu visuel doit rester équivalent

Travail attendu:
1. Améliorer l’accessibilité du bouton retour dans le layout booking
2. Ajouter des attributs utiles pour les messages flash/erreurs si pertinent
3. Migrer prudemment certains blocs résumé vers une structure plus sémantique (ex: dl/dt/dd) si cela n’introduit pas de risque CSS
4. Rester minimaliste et sûr

Important:
- Priorité à la sécurité du refactor
- Si une amélioration sémantique risque de casser le layout, la laisser de côté et le signaler
- Pas de refonte HTML large

Je veux dans ta réponse:
- analyse rapide
- fichiers modifiés
- améliorations sémantiques retenues
- améliorations écartées par prudence
- validations manuelles recommandées

Validation manuelle attendue:
- vérification du bouton retour
- vérification des flashs
- vérification visuelle des résumés booking / selection / success
```

------

# Prompt 10 — Ticket 11

## Découper booking.css

```text
Mission:
Implémenter le TICKET 11:
Découper app/assets/stylesheets/booking.css en plusieurs fichiers sans changer le rendu.

Objectif:
Améliorer la maintenabilité CSS après stabilisation du HTML.

Fichiers à créer:
- app/assets/stylesheets/booking/layout.css
- app/assets/stylesheets/booking/components.css
- app/assets/stylesheets/booking/forms.css
- app/assets/stylesheets/booking/tables.css
- app/assets/stylesheets/booking/public_flow.css
- app/assets/stylesheets/booking/admin_wizard.css

Fichiers à modifier:
- app/assets/stylesheets/application.css

Fichiers à supprimer ou garder temporairement:
- app/assets/stylesheets/booking.css selon la stratégie la plus sûre

Contraintes strictes:
- Ne pas changer le rendu visuel
- Ne pas renommer les classes dans ce ticket
- Ne pas mélanger ce ticket avec une refonte HTML
- Déplacer et organiser seulement
- Préserver l’ordre de cascade nécessaire

Travail attendu:
1. Analyser booking.css
2. Proposer un découpage logique et sûr
3. Déplacer les règles dans les nouveaux fichiers
4. Mettre à jour application.css
5. Choisir la stratégie la plus sûre pour supprimer ou conserver temporairement booking.css

Important:
- Le plus important est de préserver le rendu
- Si certaines règles doivent rester groupées pour éviter un risque, l’expliquer
- Ne pas faire de “cleanup” esthétique non demandé

Je veux dans ta réponse:
- plan de découpage choisi
- fichiers créés/modifiés
- points sensibles de cascade/spécificité
- validations manuelles recommandées

Validation manuelle attendue:
- flow public
- booking show/success
- devise pages
- admin clients new/index/edit
- admin users index/new/edit
```

------

# Prompt 11 — Exécution par lots PR-ready

## Pour Codex/Cursor si tu veux faire une PR complète par lot (sans règle stricte 1 PR = 1 ticket)

### Lot 1

```text
Implémente en une seule PR les refactors suivants
- TICKET 1 uniquement

Contraintes:
- diff petit et sûr
- aucun changement fonctionnel
- aucun changement controller/routes
- rendu équivalent

Je veux:
- analyse rapide
- fichiers créés/modifiés
- implémentation
- résumé final
- validations manuelles
```

### Lot 2

```text
Implémente en une seule PR les refactors suivants dans webook4u_appoitment_based:
- TICKET 2
- TICKET 3
- TICKET 4

Objectif:
Sécuriser et factoriser le flow public autour d’un contrat de params commun, sans changer le comportement.

Contraintes:
- ne pas changer les params externes
- ne pas changer les controllers
- ne pas introduire un presenter métier lourd
- rendu équivalent

Je veux:
- analyse rapide des risques
- fichiers créés/modifiés
- implémentation
- points explicitement laissés en l’état
- validations manuelles complètes sur le flow public
```

### Lot 3

```text
Implémente en une seule PR les refactors suivants dans webook4u_appoitment_based:
- TICKET 5

Objectif:
Finaliser le refactor structurel du flow public sans changer le comportement.

Contraintes:
- ne pas changer la logique métier
- ne pas changer les controllers
- ne pas casser le contrat des params
- rendu équivalent

Je veux:
- analyse des zones à risque
- fichiers créés/modifiés
- implémentation
- validations manuelles détaillées sur les deux branches du flow
```

### Lot 4

```text
Implémente en une seule PR les refactors suivants dans webook4u_appoitment_based:
- TICKET 6
- TICKET 7

Objectif:
Découper et nettoyer la vue wizard admin sans toucher au comportement ni au controller.

Contraintes:
- ne pas modifier Admin::ClientsController
- ne pas changer les params du wizard
- ne pas changer le rendu visible
- garder les hooks HTML nécessaires au JS

Je veux:
- analyse rapide
- fichiers créés/modifiés
- nouvelle structure de fichiers
- validations manuelles sur les 4 étapes
```

### Lot 5

```text
Implémente en une seule PR les refactors suivants dans webook4u_appoitment_based:
- TICKET 8

Objectif:
Sortir le JS inline du wizard admin vers un fichier dédié, à comportement strictement équivalent.

Contraintes:
- pas de migration Stimulus si ce n’est pas déjà en place
- mêmes hooks DOM
- même comportement
- rendu équivalent

Je veux:
- analyse du setup JS
- fichiers créés/modifiés
- implémentation
- validations manuelles avec vérification console JS
```

### Lot 6

```text
Implémente en une seule PR les refactors suivants dans webook4u_appoitment_based:
- TICKET 9
- TICKET 10

Objectif:
Harmoniser les index répétitifs et améliorer légèrement la sémantique/accessibilité sans changement fonctionnel.

Contraintes:
- ne pas changer les colonnes/actions
- ne pas changer le wording visible
- rendu équivalent

Je veux:
- analyse rapide
- fichiers créés/modifiés
- implémentation
- validations manuelles
```

### Lot 7

```text
Implémente en une seule PR les refactors suivants dans webook4u_appoitment_based:
- TICKET 11

Objectif:
Découper booking.css en plusieurs fichiers sans impact visuel.

Contraintes:
- ne pas renommer les classes
- ne pas changer le rendu
- préserver la cascade

Je veux:
- plan de découpage
- fichiers créés/modifiés
- implémentation
- points sensibles de CSS
- validations manuelles
```
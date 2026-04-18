## 1. Présentation du produit

**webook4u** est un **moteur de réservation MVP** permettant à un “client” (ex. salon) d’exposer une page publique, d’afficher des **créneaux disponibles**, puis de laisser un utilisateur **bloquer temporairement** un créneau (booking `pending`) et le **confirmer** (booking `confirmed`) via un formulaire.

- **Problème métier résolu**: éviter les doubles réservations et gérer la concurrence entre utilisateurs lors de la prise de rendez-vous.
- **Périmètre MVP (réel)**:
  - Page publique unique: choix prestation → choix date → affichage des créneaux
  - Création d’un booking **temporaire** (`pending`) lors de l’ouverture du formulaire
  - Confirmation (passage à `confirmed`) via formulaire (prénom/nom/email)
  - Gestion de disponibilité par grille + blocage par overlaps
  - Protection de concurrence (verrou transactionnel) + garde-fou DB
  - Anti-spam (rate limiting IP) sur création pending et confirmation
- **Hors périmètre (non observé)**: annulation, modification, replanification, comptes utilisateurs, capacité multiple (ressources), gestion d’horaires variables/exceptions, paiement obligatoire (Stripe non imposé), notifications.

---

## 2. Acteurs et rôles

- **Utilisateur final (visiteur)**: choisit une prestation, une date, un créneau; renseigne ses infos; confirme.
- **Client (propriétaire du planning)**: entité “tenant” identifiée par `slug`, porte les `services` et les `bookings`.
- **Système**:
  - calcule les créneaux (règles `BookingRules`)
  - bloque temporairement (pending) puis confirme
  - empêche les conflits (lock + index unique partiel)
  - limite le spam par IP (rate limit)

---

## 3. Vue d’ensemble du parcours utilisateur

1. **Accès page publique**: `GET /:slug`
2. **Sélection d’un service**: choix via formulaire GET (param `service_id`)
3. **Sélection d’une date**: choix via champ date (param `date` en ISO `YYYY-MM-DD`)
4. **Affichage des créneaux**: liste de slots (boutons) pour le service et la date
5. **Sélection d’un créneau**: clic sur un slot → `GET /:slug/services/:service_id/bookings/new?start_time=...`
6. **Création booking pending**: le système crée un booking `pending` et affiche le formulaire
7. **Remplissage formulaire**: prénom / nom / email
8. **Confirmation**: `POST /:slug/bookings/:id/confirm`
9. **Page success**: `GET /:slug/bookings/:token/success`

---

## 4. Détail du flux de réservation (étape par étape)

### 4.1 Page publique (sélection service/date/slot)
- **Action utilisateur**: ouvre `/:slug`, choisit une prestation, choisit une date, voit les créneaux.
- **Traitement système**:
  - Charge le `Client` via `slug`
  - Charge les `services` du client
  - Parse la date de manière “safe”:
    - `date` doit être ISO 8601 (`YYYY-MM-DD`)
    - `date` doit être **≥ aujourd’hui**
    - `date` doit être **≤ aujourd’hui + 30 jours**
  - Si service + date présents: calcule les slots via la grille `BookingRules` et retire les slots qui chevauchent des bookings bloquants.
- **Données manipulées**:
  - `client.slug`, `service_id`, `date`
  - liste de slots \(Date+heure\)
- **Résultat attendu**:
  - Affichage d’une étape 1 (services), puis étape 2 (date), puis étape 3 (créneaux)
  - Si aucun slot: message “Aucun créneau n'est disponible pour cette date…”

### 4.2 Ouverture du formulaire (création pending)
- **Action utilisateur**: clique un créneau proposé.
- **Traitement système (avant règle métier)**:
  - Anti-spam: rate limit **par IP et par client**, spécifique à l’action “création pending”
  - Parse `start_time` de manière “safe”:
    - doit être parsable en temps
    - doit être **≥ now**
    - doit être **≤ now + 30 jours**
- **Traitement système (métier)**:
  - Vérifie que le slot est **réellement un slot généré** par la grille (pas un timestamp arbitraire)
  - Vérifie que le créneau **n’est pas bloqué** (overlap) par:
    - un booking `confirmed`
    - ou un booking `pending` **non expiré**
  - Si OK: crée un booking `pending` avec:
    - `booking_start_time`, `booking_end_time` (selon durée du service)
    - `booking_expires_at = now + 5 minutes`
- **Données manipulées**:
  - `Booking`: `booking_status=pending`, `booking_start_time`, `booking_end_time`, `booking_expires_at`, `client_id`, `service_id`
- **Résultat attendu**:
  - Page formulaire affichée, avec récap créneau choisi

### 4.3 Confirmation
- **Action utilisateur**: soumet le formulaire.
- **Traitement système (avant métier)**:
  - Anti-spam: rate limit **par IP et par client**, spécifique à l’action “confirmation”
- **Traitement système (métier)**:
  - Refuse si le booking n’est pas `pending`
  - Refuse si la “session” pending est **expirée**
  - Re-vérifie que le créneau n’est pas devenu bloqué entre-temps (anti course)
  - Met à jour le booking:
    - `booking_status = confirmed`
    - `customer_first_name`, `customer_last_name`, `customer_email`
    - génère un `confirmation_token` (UUID)
  - Si paramètres invalides (ex. email invalide / champs vides): échec de validation, booking reste `pending`
- **Données manipulées**:
  - `Booking`: statut, infos client, `confirmation_token`
- **Résultat attendu**:
  - Si succès: redirection vers la page success
  - Si échec “formulaire”: re-affichage du formulaire (422) avec erreurs
  - Si échec “métier” (slot plus dispo, session expirée, etc.): redirection vers page publique avec message

### 4.4 Page success
- **Action utilisateur**: arrive sur la page success.
- **Traitement système**:
  - Récupère le booking via `confirmation_token` **dans le périmètre du client**
- **Résultat attendu**:
  - Affiche “Votre réservation est confirmée” + récap (client, prestation, prix, créneau, nom, email)

---

## 5. Règles fonctionnelles

### 5.1 Création d’un booking pending
- **Règle: le créneau doit être valide et récent**
  - **Conditions**: `start_time` parsable, `start_time ≥ now`, `start_time ≤ now + 30 jours`
  - **Résultat**: sinon **aucun booking** créé, retour page publique avec message **“Le créneau sélectionné est invalide.”**
- **Règle: le créneau doit appartenir à la grille “réservable”**
  - **Conditions**: le timestamp doit faire partie des slots générés (jours ouvrés + horaires + pas 30 min + min notice + horizon)
  - **Résultat**: sinon refus **“Le créneau sélectionné n'est pas réservable.”**
  - **Implication**: impossible de réserver un créneau “hors grille” même s’il est libre
- **Règle: le créneau ne doit pas être bloqué**
  - **Conditions**: aucun booking bloquant ne chevauche l’intervalle \([start, end)\)
  - **Résultat**: sinon refus **“Le créneau sélectionné n'est plus disponible.”**
- **Règle: création d’une session pending**
  - **Conditions**: slot OK
  - **Résultat**: booking créé en `pending` avec expiration **now + 5 minutes**

### 5.2 Confirmation d’un booking
- **Règle: seul un booking `pending` est confirmable**
  - **Condition**: `booking_status == pending`
  - **Résultat**: sinon refus **“Cette réservation ne peut plus être confirmée. Veuillez recommencer votre sélection.”**
- **Règle: un pending expiré n’est plus confirmable**
  - **Condition**: `booking_expires_at` doit exister et être **> now**
  - **Résultat**: sinon refus **“Votre session a expiré. Veuillez renouveler votre réservation.”**
- **Règle: re-check de disponibilité au moment de confirmer**
  - **Condition**: l’intervalle n’est pas chevauché par un autre booking bloquant (hors lui-même)
  - **Résultat**: sinon refus **“Le créneau sélectionné n'est plus disponible.”**
- **Règle: données client requises en confirmation**
  - **Conditions**: `customer_first_name`, `customer_last_name`, `customer_email` présents, email au format valide
  - **Résultat**: sinon refus **“Le formulaire contient des erreurs.”** et re-render du formulaire
- **Règle: création d’un token de confirmation**
  - **Condition**: confirmation réussie
  - **Résultat**: `confirmation_token` généré et unique, utilisé pour la page success
- **Règle “dernier rempart” contre doubles confirmations**
  - **Condition**: si une course arrive malgré les checks
  - **Résultat**: refus **“Le créneau sélectionné vient d'être réservé par un autre utilisateur.”**

### 5.3 Disponibilité des créneaux
- **Règles de grille (BookingRules)**
  - **Pas**: 30 minutes
  - **Jours réservables**: lundi → vendredi
  - **Horaires**: de 09:00 à 18:00 (le slot doit tenir dans la plage avec la durée du service)
  - **Min notice**: 30 minutes (un slot < now+30min est retiré)
  - **Horizon**: 30 jours (au niveau des entrées date/time)
- **Règle de chevauchement (overlap)**
  - Chevauchement si: `startA < endB` ET `endA > startB`
  - **Conséquence métier importante**: si un booking finit à 10:30, un slot qui commence à 10:30 est **autorisé** (pas de chevauchement au bord)

### 5.4 Gestion des conflits
- **Conflit fonctionnel**: un slot est indisponible si un booking `confirmed` ou `pending` non expiré chevauche l’intervalle.
- **Conflit de concurrence**:
  - Le système sérialise les tentatives sur un même `(client, start_time)` (verrou transactionnel)
  - Et la base interdit 2 bookings `confirmed` pour le même `(client, booking_start_time)`

### 5.5 Expiration des bookings
- **Expiration pending**: 5 minutes
- **Effet réel**:
  - Un pending expiré **ne bloque plus** la disponibilité (il n’est plus “active_pending”)
  - Un pending expiré **ne peut plus** être confirmé
- **Point implicite**: aucun mécanisme observé de purge/annulation automatique; le booking peut rester en base en `pending` mais “expiré” logiquement.

### 5.6 Rate limiting (anti-spam)
- **Portée**:
  - appliqué sur **création pending** (ouverture formulaire) et **confirmation**
  - **pas** appliqué sur la page publique ni la page success
- **Clé fonctionnelle**: limite **par IP** et **par client** (scopée au `client_slug`)
- **Fenêtre de temps**: 10 minutes (600s)
- **Seuils par défaut**:
  - pending creation: **5** tentatives / 10 min
  - confirmation: **8** tentatives / 10 min
  - (valeurs configurables via variables d’environnement; si limite ≤ 0, l’action est bloquée)
- **Comportement UX**:
  - **Création pending bloquée**: pas de booking créé, redirection page publique avec message **“Trop de tentatives. Réessayez dans quelques minutes.”**
  - **Confirmation bloquée**: réponse **HTTP 429** en texte simple, booking reste `pending`

---

## 6. Cycle de vie d’un booking

### Statuts existants
- `pending`
- `confirmed`
- `failed` (**présent mais non utilisé dans le flux observé**)

### Transitions observées
- `pending` → `confirmed`
  - **Conditions**: non expiré + toujours disponible + formulaire valide + pas de conflit DB
- “Expiration logique”
  - `pending` reste `pending` en base mais devient **non bloquant** et **non confirmable** une fois expiré

---

## 7. Gestion des erreurs

### Erreurs côté utilisateur (messages réels)
- **Créneau invalide**: “Le créneau sélectionné est invalide.”
- **Créneau non réservable (hors grille)**: “Le créneau sélectionné n'est pas réservable.”
- **Créneau plus disponible (bloqué/overlap)**: “Le créneau sélectionné n'est plus disponible.”
- **Session expirée**: “Votre session a expiré. Veuillez renouveler votre réservation.”
- **Booking non pending**: “Cette réservation ne peut plus être confirmée. Veuillez recommencer votre sélection.”
- **Formulaire invalide**: “Le formulaire contient des erreurs.”
- **Conflit de dernière milliseconde**: “Le créneau sélectionné vient d'être réservé par un autre utilisateur.”
- **Rate limit**: “Trop de tentatives. Réessayez dans quelques minutes.”

### Mapping comportement (réel)
- **Échec à la création pending (GET new)**: redirection vers page publique (avec `alert`)
- **Échec à la confirmation (POST confirm)**:
  - si erreurs de validation sur le booking: re-render du formulaire en **422**
  - sinon: redirection page publique (avec `alert`)
- **Rate limit confirmation**: réponse **429** (pas de HTML “friendly”)

---

## 8. Hypothèses MVP (déduites du comportement)

- **Calendrier fixe**: horaires 9–18 et uniquement jours ouvrés, sans exceptions.
- **Capacité 1 par client**: pas de notion de ressource (employé/salle), le planning est “global” au client.
- **Slot = grille**: on ne peut pas réserver un timestamp hors slots générés.
- **Paiement non bloquant**: champs Stripe présents en base, mais aucune règle ne conditionne `confirmed` au paiement.
- **Pending non purgés**: l’expiration est logique (scope/conditions), pas de “cleanup” métier visible.

---

## 9. Zones floues / à clarifier (réelles, non inventées)

- **Statut `failed`**: quand doit-il être utilisé (paiement, abandon, erreur externe) ? Aucun flux actuel ne le met.
- **Politique post-expiration**: faut-il afficher/traiter différemment les pending expirés (analytics, support, nettoyage) ?
- **UX du 429 en confirmation**: actuellement texte simple; souhait produit attendu ?
- **Cohérence “horizon 30 jours”**: l’horizon est appliqué via parsing “safe” des params; si d’autres entrées apparaissent plus tard, il faudra confirmer la règle “produit”.

---

## 10. Contraintes métier importantes (invariants observés)

- **Impossible d’avoir 2 bookings `confirmed`** pour le même `(client, booking_start_time)` (contrainte DB).
- **Un booking `confirmed` doit avoir** prénom/nom/email valides (validations conditionnelles).
- **Un booking `pending` doit avoir** `booking_expires_at` (sinon il est considéré expiré).
- **La disponibilité se raisonne en intervalles** \([start, end)\) basés sur la durée du service.
- **Un pending bloque temporairement**, mais cesse de bloquer une fois expiré.

---

## 11. Scénarios utilisateurs (Gherkin-like)

### 11.1 Parcours nominal
**Given** un client public avec une prestation de 30 minutes  
**And** nous sommes le 15/03/2026 08:00  
**When** l’utilisateur ouvre la page publique `/:slug`  
**And** sélectionne la prestation  
**And** sélectionne la date `2026-03-16`  
**And** clique un créneau disponible à `10:00`  
**Then** un booking `pending` est créé avec une expiration à +5 minutes  
**When** l’utilisateur soumet le formulaire avec prénom/nom/email valides  
**Then** le booking passe à `confirmed`  
**And** l’utilisateur est redirigé vers la page success affichant “Votre réservation est confirmée”

### 11.2 Slot indisponible (déjà confirmé)
**Given** un booking `confirmed` existe sur `2026-03-16 10:00–10:30`  
**When** l’utilisateur tente d’ouvrir le formulaire sur `2026-03-16 10:00`  
**Then** aucun booking pending n’est créé  
**And** l’utilisateur est redirigé vers la page publique avec le message “Le créneau sélectionné n'est plus disponible.”

### 11.3 Expiration de session pending
**Given** un booking `pending` existe mais son `booking_expires_at` est dans le passé  
**When** l’utilisateur tente de confirmer ce booking  
**Then** le booking reste `pending`  
**And** l’utilisateur est redirigé vers la page publique avec “Votre session a expiré. Veuillez renouveler votre réservation.”

### 11.4 Rate limit dépassé (création pending)
**Given** la limite de création pending est atteinte pour l’IP de l’utilisateur dans la fenêtre de 10 minutes  
**When** l’utilisateur clique sur un créneau (ouverture du formulaire)  
**Then** aucun booking pending n’est créé  
**And** l’utilisateur est redirigé vers la page publique avec “Trop de tentatives. Réessayez dans quelques minutes.”

### 11.5 Rate limit dépassé (confirmation)
**Given** la limite de confirmation est atteinte pour l’IP de l’utilisateur dans la fenêtre de 10 minutes  
**And** un booking `pending` existe  
**When** l’utilisateur soumet la confirmation  
**Then** le serveur répond HTTP 429 avec “Trop de tentatives. Réessayez dans quelques minutes.”  
**And** le booking reste `pending`
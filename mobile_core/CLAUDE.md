# Sonaiyaa Mobile Core

Shared Flutter package containing the "Core" logic (business and communication) common to both `mobile-partenaire` and `mobile-livreur` applications.

## Content
- **Data Models**: E.g., `Commande`, `User`, `WalletTransaction`. Contains serialization methods `fromJson`/`toJson`.
- **Services**:
  - `ApiService` — single HTTP communication layer with the FastAPI Backend (handles JWT refresh, 401 logout). Exposes a static `ApiService.healthCheck()` for boot-time backend reachability. **Nouveau modèle Crédit/Gains** : côté livreur, `getWallet` / `getWalletTransactions` / `demanderRetrait` (les Gains = solde retirable, positif ; plus de recharge livreur). Côté expéditeur, `getCredit` / `getCreditTransactions` / `rechargeCredit(montant)` (le Crédit prépayé couvre les commissions ; `rechargeCredit` renvoie un `checkout_url` Mobile Money à ouvrir). `WalletTransaction` est **réutilisé** pour l'historique du Crédit (même forme).
  - `NotificationService` — Firebase Messaging + flutter_local_notifications wrapper.
  - `NetworkService` — connectivity monitor used by `OfflineBanner`.
  - `AnalyticsService` (singleton) — Firebase Analytics wrapper exposing typed business events: `logLoginSuccess`, `logCommandeCreated`, `logCourseAccepted`, `logWithdrawalRequested`, `logOnlineToggle`, `logOnboardingCompleted`, `logCourseStatusChange`, `logDocumentUploaded`. Also provides `navigatorObserver` for automatic screen tracking.
- **Constants**: Colors (brand Orange `#FF5A1F`), env variables, base endpoints. `AppCurrency.format()` for GNF, `GuineaPhone.formatPretty()` for `+224 6XX XXX XXX`.
- **Date / Time**: `DateFormatter` for timezone-aware French formatting (`dateTime`, `dateOnly`, `timeOnly`, `relative`). Backend timestamps are UTC; Conakry is GMT+0 so `.toLocal()` is a no-op today, but `DateFormatter` centralises this so a future market change (CFA Senegal, CI, Algeria, …) only requires editing one file.
- **App version**: `AppVersion.warmup()` (call early in `main()`), then `AppVersion.short` / `AppVersion.full` everywhere. Avoids hardcoded version strings in profile screens.
- **Onboarding**: `OnboardingStorage.hasSeen() / .markSeen()` + reusable `OnboardingScreen(slides: [...], onCompleted: …)`. Each app passes its own slides via `OnboardingSlide(icon, title, description)`.
- **Error UX**: `AppErrorScreen` (used as `ErrorWidget.builder` global) replaces Flutter's red box / grey fallback with a branded "Oups…" screen.
- **Empty states**: `EmptyState(icon, title, message, actionLabel, onAction)` reusable widget.
- **Avatars**: `UserAvatar(photoUrl, name, size)` — circular avatar with automatic initials fallback if photo URL is null/missing/fails to load. Used for livreur greeting on home screen; reusable for partenaire profile, admin lists, etc.
- **Brand motif**: `BrandDots(size, color)` — the two-dot signature of the Sönaiyaa logo, réutilisé sur les en-têtes d'accueil et à côté des labels d'argent (Crédit / Gains). Partie de l'identité validée (avec `AppTheme.mono` pour les montants).
- **Splash animé**: `AnimatedSplash(onComplete, logoAsset, duration)` — vrai écran de démarrage (façon app pro) qui prend le relais du splash natif statique. Le logo apparaît en fondu + léger zoom (`easeOutBack`), le wordmark « Sönaiyaa » + deux-points glissent, et trois points de chargement pulsent en bas ; `onComplete` est appelé à la fin (~1,9 s). Le logo est chargé via `Image.asset('assets/branding/logo_mark.png')` **sans** `package:` → résolu depuis le bundle de l'app hôte (les deux apps déclarent `assets/branding/`). Câblé en tête de l'`AuthWrapper` de chaque app (gate `_introDone`) : splash animé → onboarding/login.
- **Onboarding**: `OnboardingScreen` (voir plus bas) — bouton d'action en **orange** (identité premium), slides avec entrée fondu + glissement, halo doux sur l'icône. Textes alignés sur le modèle Crédit/Gains (côté livreur : « Suivez vos Gains », plus « Wallet »).
- **Typography**: `google_fonts` package available for consistent font rendering across both apps. Body/titres = **Manrope** (via `AppTheme`, identité premium validée). **`AppTheme.mono(...)`** = helper chiffres « registre » (Manrope + `FontFeature.tabularFigures()`, chasse fixe) pour les montants — l'argent est le héros sur les écrans Crédit / Gains.
- **Ombres** (`AppTheme.shadowSm/Md/Lg`): halos doux et chauds (couleur `#2A1E12` à faible alpha, `spreadRadius` négatif → l'ombre reste sous la carte, pas de drop lourd). Modifiées dans la fondation → se répercutent sur toutes les cartes des deux apps.

## Specific Rules
- **Data Layer Only**: This package must contain NO user interface logic (no UI files, and ideally no material dependency `flutter/material.dart` except for extremely basic utilities).
- **API Management**: If the backend response structure changes (e.g., the recent addition of pagination on order lists, or new fields like `geniuspay_checkout_url`), the code must be adapted in this package (specifically in `api_service.dart`).
- **Propagating Changes**: After ANY modification in this `mobile_core` folder, do not forget to run `flutter pub get` in both `mobile-partenaire` and `mobile-livreur` so the updated code is applied.
- **New Models**: When the backend adds fields (e.g., `piece_identite_url`, `vehicule_doc_url`, `devanture_url` from R2 migrations), update the corresponding model here first.

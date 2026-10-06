# Livraison Livreur (Flutter)

Application pour les livreurs (taxis-motos) : courses proches, navigation, statut de livraison, notifications.

## Prérequis

- Flutter SDK 3.0+
- Backend API accessible (voir `mobile_core` / configuration du projet)

## Démarrage

```bash
cd mobile-livreur
flutter pub get
flutter run
```

## Identifiants natifs

| Plateforme | Identifiant |
|------------|-------------|
| Android `applicationId` / `namespace` | `com.livraison.livreur` |
| iOS / macOS bundle | `com.livraison.livreur` |
| Linux `APPLICATION_ID` (GTK) | `com.livraison.livreur` |
| Package Dart | `livraison_livreur` |

Après changement de bundle, enregistrer l’app dans **Firebase** et mettre à jour `lib/firebase_options.dart` + `GoogleService-Info.plist` (`flutterfire configure`).

## Structure (réelle)

Le code vit sous `lib/` : écrans auth, home, courses, profil, providers, services partagés via `mobile_core`.

## Licence

Propriétaire

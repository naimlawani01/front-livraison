# 📱 App mobile partenaire — Flutter

Application pour les commerçants partenaires (restaurants, pharmacies, etc.) de la plateforme de livraison.

## 🚀 Installation

### Prérequis

- Flutter SDK 3.0+
- Android Studio ou Xcode
- Un émulateur ou appareil physique

### Setup

```bash
cd mobile-partenaire

flutter pub get

# Lancer sur Android
flutter run

# Ou sur iOS
flutter run -d ios
```

### Firebase (push)

Identifiants natifs : **package Android** et **bundle iOS** = `com.livraison.partenaire`.

Après un renommage, ajoutez (ou mettez à jour) les applications dans la [console Firebase](https://console.firebase.google.com/) avec cet identifiant, puis :

- remplacez `ios/Runner/GoogleService-Info.plist` par le fichier téléchargé ;
- exécutez `flutterfire configure` ou mettez à jour `lib/firebase_options.dart` (`appId`, etc.) pour qu’ils correspondent aux apps enregistrées.

Sans cette étape, les notifications Firebase peuvent échouer au démarrage.

## 📱 Fonctionnalités

- Connexion avec téléphone / mot de passe
- Tableau de bord avec statistiques
- Création de livraisons / commandes
- Liste des commandes (en cours, terminées)
- Profil partenaire

## 🏗️ Structure

```
lib/
├── main.dart
├── firebase_options.dart
├── providers/
├── screens/
└── widgets/
```

## ⚙️ Configuration

URL de l’API : selon votre setup (`mobile_core` ou constantes du projet).

## 📦 Build

```bash
flutter build apk --release
flutter build appbundle --release
flutter build ios --release
```

---

**Dart package** : `livraison_partenaire`

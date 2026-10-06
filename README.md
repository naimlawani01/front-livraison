# 📦 Plateforme de Livraison - Partenaires & Taxis-Motos

Plateforme numérique complète connectant commerces partenaires (restaurants, pharmacies, etc.) avec livreurs (taxis-motos) via géolocalisation en temps réel. **Système 100% opérationnel incluant Backend, Admin Web et Applications Mobiles.**

---

## 🏗️ Architecture Globale

Le système est découplé en quatre modules principaux communiquant via une API REST et WebSockets pour le temps réel.

- **Backend (FastAPI)** : API haute performance, gestion DB async (PostgreSQL), Redis (Cache), WebSocket, et calculs de géolocalisation.
- **Admin-Web (React)** : Dashboard de supervision pour les administrateurs (Stats, Validation des livreurs, Carte en temps réel).
- **Mobile-Partenaire (Flutter)** : Création de commandes, suivi de livraison et gestion de profil commerçant.
- **Mobile-Livreur (Flutter)** : Réception de courses par proximité, navigation GPS, gestion des gains et disponibilité.

---

## 🚀 Démarrage Rapide

### 🐳 Option 1 : Docker (Recommandé)
Déployez l'ensemble de l'infrastructure en une commande :

```bash
docker-compose up -d
```
*Accès : API sur `http://localhost:8000`, DB sur `localhost:5433`, Redis sur `6379`.*

### 🐍 Option 2 : Développement Local (Backend)
```bash
cd backend
python -m venv venv
source venv/bin/activate
pip install -r requirements.txt
cp .env.example .env
# Configurez .env puis lancez :
uvicorn app.main:app --reload
```

---

## 🔑 Accès & Démo

Pour tester la plateforme immédiatement, utilisez les accès administrateur par défaut :

| Service | Accès / URL |
|---------|-------------|
| **API Docs (Swagger)** | [http://localhost:8000/docs](http://localhost:8000/docs) |
| **API ReDoc** | [http://localhost:8000/redoc](http://localhost:8000/redoc) |
| **Compte Admin** | Téléphone : `00000000` / Password : `admin123` |

> [!WARNING]
> Changez impérativement le mot de passe admin et les clés secrètes avant tout déploiement en production.

---

## 🛠️ Stack Technique

- **Backend** : Python 3.11+, FastAPI, SQLAlchemy (Async), Alembic, Pydantic v2.
- **Database** : PostgreSQL 15, Redis 7.
- **Mobile** : Flutter (lib/) avec intégration Google Maps et Firebase.
- **Web Admin** : React/Vite + TypeScript.
- **Services Externes** : Twilio (OTP/SMS), Firebase (Notifications Push).

---

## 🗺️ Fonctionnalités Clés Implémentées

### 🔐 Sécurité & Auth
- Inscription et connexion par téléphone avec **OTP Twilio**.
- Authentification sécurisée via **JWT** et hashing **bcrypt**.
- Gestion fine des rôles (Admin, Partenaire, Livreur).

### 📍 Géolocalisation & Temps Réel
- Matching intelligent des livreurs dans un rayon configurable (Haversine).
- Mise à jour de position GPS en temps réel via **WebSockets**.
- Notifications push aux livreurs environnants via **Firebase**.

### 📦 Gestion des Livraisons
- Cycle de vie complet : `CREEE` ➜ `DIFFUSEE` ➜ `ACCEPTEE` ➜ `EN_RECUPERATION` ➜ `EN_LIVRAISON` ➜ `TERMINEE`.
- Calcul automatique des commissions plateforme (15%) et des gains livreurs.
- Système d'évaluation mutuelle après livraison.

---

## 🎨 Design System
La plateforme utilise un design moderne et cohérent :
- **App Partenaire** : Déclinaisons de gradations Orange (#FF6B35) → Rouge (#E63946).
- **Apps Livreur** : Gradations Vert (#06FFA5) → Bleu (#00B4D8).
- **Composants** : `GradientButton`, `ModernCard`, et animations `easeOutCubic` (1200ms).

---

## 🧪 Tests & Validation
1. **Santé** : `GET /health` doit retourner `{"status":"healthy"}`.
2. **Cycle Commande** :
   - Connectez-vous en tant qu'admin pour valider un livreur.
   - Connectez-vous en tant que partenaire pour créer une commande.
   - Connectez-vous en tant que livreur pour accepter la course.
   - Suivez le changement de statut via `/api/v1/commandes/me`.

---

## 📂 Structure du Projet
```
livraison/
├── backend/            # API FastAPI & Logique métier
├── admin-web/          # Dashboard React d'administration
├── mobile-livreur/     # App Flutter pour les chauffeurs
├── mobile-partenaire/    # App Flutter pour les commerçants
├── docker-compose.yml  # Orchestration des services
└── README.md           # Documentation unique
```

---

**Version**: 1.0.0 | **Statut**: Opérationnel | **Date**: Février 2026

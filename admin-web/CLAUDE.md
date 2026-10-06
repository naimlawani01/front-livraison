# Sonaiyaa Admin Web

Web dashboard for global administration of the Sonaiyaa platform. Allows administrators to validate driver registrations, manage disputes, and approve Wallet withdrawals.

## Status
- Functional locally and against the production backend on Railway.
- **Not yet deployed** to a public domain (no `admin.sonaiyaa.fr` yet). Build artefact (`npm run build` → `dist/`) is ready to be hosted on any static host (Cloudflare Pages, Vercel, Netlify, Railway).
- Branding (favicon, logo in sidebar + login screen) already integrated.

## Tech Stack
- **React Framework**: React 19
- **Build Tool**: Vite
- **Styling**: Tailwind CSS v4
- **Components / Icons**: Lucide React
- **Routing**: React Router DOM v6

## Common Commands
- **Install dependencies**: `npm install`
- **Start dev server**: `npm run dev`
- **Lint code**: `npm run lint`
- **Generate production build**: `npm run build`

## Environment Variables
- `VITE_API_URL` — Backend API base URL (production: `https://api.sonaiyaa.fr/api/v1`). The Railway-generated URL still works as a fallback but the custom domain is preferred.

## Branding assets (already integrated)
- `public/favicon.svg` + `public/favicon-*.png` + `public/apple-touch-icon.png` — brand favicons.
- `public/branding/logo_mark.svg` — used in `Layout.jsx` (sidebar) and `LoginPage.jsx`. ViewBox is tightened so it renders dense at small sizes.
- Theme color (`<meta name="theme-color">`): `#FF5A1F`.

## Pages & Features
- **DashboardPage** — Platform statistics: total users, drivers, orders, revenue, completion rate (from `GET /admin/stats`)
- **ValidationPage** — Driver KYC verification: view pending drivers, review uploaded documents (Cloudflare R2 presigned URLs), approve/reject
- **CommandesPage** — Order management and monitoring
- **RetraitsPage** — Driver withdrawal approval: list pending payout requests, trigger or reject GeniusPay payouts
- **RemboursementsPage** — Clients ayant payé par Mobile Money une course ensuite annulée (`GET /admin/remboursements`) ; bouton « Marquer remboursé » (`POST /admin/remboursements/{course_id}/effectue`) une fois le remboursement fait hors plateforme.
- **CoursesSuspectesPage** — Livraisons validées loin de l'adresse déclarée du client (`GET /admin/courses/suspectes`, seuil configurable) : fausse adresse ou fausse livraison à vérifier.
- **TestAccountsPage** — Creates pre-verified test accounts (Partenaire / Livreur) for App Store / Play Store reviewers and internal QA. Phone numbers must start with `+224600` (an unallocated GN prefix, prevents impersonation if credentials leak). Has one-click presets for the Apple Reviewer accounts. Backed by `POST /admin/test-accounts`, `GET /admin/test-accounts`, `DELETE /admin/test-accounts/{user_id}`.

## Specific Rules
- **Double authentification** : `POST /auth/login` d'un admin avec le bon mot de passe répond **401 `otp_required`** et envoie un code SMS ; la LoginPage affiche alors un champ « Code reçu par SMS » et rappelle `login(phone, password, otpCode)`. `api.login` ne passe **pas** par `handleResponse` (son traitement du 401 — déconnexion + redirection — casserait ce flux).
- **Authentication**: The dashboard consumes the FastAPI API. Strictly handle JWT token expiration by cleanly redirecting to the Login page on a `401 Unauthorized` error.
- **UI Architecture**: Follow a modular architecture based on reusable functional React components. Tailwind is used as the primary styling solution.
- **API Layer**: All HTTP calls must go through `src/services/api.js` — do not use raw `fetch`/`axios` calls outside this service.
- **Document Viewer**: Driver documents come as presigned R2 URLs (time-limited). Display them inline or in a modal; do not store URLs client-side beyond the current session.

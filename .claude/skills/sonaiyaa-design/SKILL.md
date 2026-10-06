---
name: sonaiyaa-design
description: Identité visuelle et règles de design propres à Sönaiyaa (apps Flutter mobile-livreur, mobile-partenaire et admin-web React). À utiliser pour TOUTE création ou modification d'écran, de composant, de maquette (Figma ou code) ou de texte affiché dans ces apps — y compris « rends cet écran plus beau », « refais le design », « ajoute un écran ». Prime sur le skill générique mobile-app-ui-design en cas de conflit.
---

# Design Sönaiyaa

Sönaiyaa met en relation des **expéditeurs** (commerçants) et des **livreurs** à moto, en Guinée.
Le design doit faire ressentir trois choses : **fiable** (l'argent et les colis sont entre de
bonnes mains), **rapide** (une action = un geste), **chaleureux** (une marque locale, humaine).
Chaque décision visuelle doit servir l'un de ces trois mots — sinon on la retire.

> Le skill `mobile-app-ui-design` apporte les bonnes pratiques génériques (8-pt grid, 60/30/10,
> peak-end…). Ce skill-ci apporte la **personnalité** et les **contraintes terrain**. Il l'emporte
> en cas de conflit.

## 1. Fondations — toujours passer par `AppTheme`

Source unique : `mobile_core/lib/theme/app_theme.dart`. **Jamais de couleur, rayon ou ombre en dur**
dans un écran : si un token manque, on l'ajoute à `AppTheme`.

| Rôle | Token | Usage |
|---|---|---|
| Accent (10 %) | `AppTheme.accent` `#FF5A1F` | action principale, état actif, montant clé. Jamais en fond de grande surface. |
| Accent doux | `accentLight` / `accentDark` | fond d'un élément sélectionné / texte sur fond accent clair |
| Fond (60 %) | `background` `#F3F2EE` (blanc chaud) | fond d'écran. Pas de blanc pur en fond. |
| Cartes | `cardBg` (blanc) + `shadowSm/Md` (ombres teintées chaudes) | contenu groupé |
| Texte | `textPrimary` (encre chaude) / `textSecondary` / `textTertiary` | hiérarchie par couleur, pas que par graisse |
| Statuts | `success` / `warning` / `error` / `info` (+ `*Light`) | uniquement pour un statut, jamais décoratif |
| Rayons | `radiusSm 12` · `radiusMd 16` · `radiusLg 20` · `radiusXl 28` | pas d'autres valeurs |

- **Police** : Manrope partout (`GoogleFonts.manrope`). **4 tailles max par écran**, 2 graisses (600 / 800).
- **Montants** : toujours `AppTheme.mono(...)` (chiffres tabulaires) et `AppCurrency.format(...)`.
  La **valeur** est plus grande que son étiquette (« 8 800 GNF » > « Vos gains »).
- **Espacements** : multiples de 4 (4, 8, 12, 16, 20, 24, 32). Écart entre groupes = 2× l'écart interne.
- **Bouton principal** : widget `PrimaryCta` (`mobile_core/lib/widgets/primary_cta.dart`, 64 px,
  `ctaGradient`, état « en cours » anti double appui). Ne pas en recréer un à la main.
- **Dégradé accent** (`accentGradient`) : réservé à **un seul** élément héros par écran
  (carte Gains, CTA principal). Deux dégradés sur un écran = trop.

## 2. Les signatures Sönaiyaa (ce qui nous distingue)

1. **Le motif deux-points `:`** — fil rouge de la marque : séparateur discret dans les cartes de
   montant, puces des étapes, indicateur de chargement. Sobre, jamais décoratif en grand.
2. **La frise de course** `Expéditeur → Livreur → Client` — représentation visuelle unique du statut
   (points reliés, étape courante en accent, étapes faites en `success`). À utiliser partout où un
   statut de course est affiché, au lieu d'un simple badge texte.
3. **Les chiffres en héros** — montants grands, en mono, au premier coup d'œil (Gains, prix, part
   livreur). Le reste du texte s'efface derrière.
4. **Le moment « Course livrée »** (pic + fin de parcours) — animation courte (check + léger
   rebond), montant gagné en grand, message humain (« Bravo, 8 800 GNF pour vous »). C'est l'écran
   dont on doit se souvenir.

## 3. Contraintes terrain (non négociables)

### App livreur — à moto, au soleil, parfois avec des gants
- Zones tactiles **≥ 56 px** pour les actions de course (≥ 48 px ailleurs), action principale
  **en bas de l'écran** (zone du pouce), **une seule** action principale par écran.
- Contraste fort : texte important en `textPrimary` sur fond clair ; pas de texte gris clair pour
  une info utile (adresse, montant, code).
- L'information vitale lisible en < 2 s : **où aller**, **combien**, **quoi faire ensuite**.
- Pas d'effets lourds (flou d'arrière-plan, glassmorphism, grosses animations) : téléphones Android
  d'entrée de gamme, batterie à préserver.

### App expéditeur — commerçant pressé entre deux clients
- Créer une course en **< 30 s** : valeurs par défaut intelligentes (payeur, code de livraison
  coché), champs dans l'ordre de la saisie réelle.
- Toujours montrer **ce que ça coûte** et **qui paie** avant de valider (répartition 88 % / 12 %).

### Réseau faible (tous)
- Chaque écran qui charge des données a ses **4 états dessinés** : chargement (skeleton ou
  `BrandDots`), vide (avec action), erreur (message humain + « Réessayer »), hors ligne.
- Les actions d'argent (payer, retirer, accepter) affichent un état « en cours » et ne se
  déclenchent jamais deux fois.

## 4. Ce qu'on n'utilise pas (même si le skill générique le suggère)
- Glassmorphism / `backdrop-blur`, néon, grandes illustrations 3D génériques, photos de stock.
- Marges « web » (80–96 px entre sections) : sur mobile, 24–32 px.
- Plus d'un dégradé par écran, plus d'une couleur d'accent, du noir pur pour les actions
  (l'orange = action ; le noir a été retiré des éléments primaires).
- Emojis dans les écrans d'argent ou d'erreur.

## 5. Textes affichés
- Vouvoiement, phrases courtes, verbes d'action (« Relancer la course », pas « Relance »).
- Vocabulaire produit : **Expéditeur** (accentué), **course**, **Crédit** (expéditeur),
  **Gains** (livreur), **commission Sönaiyaa**. Jamais « partenaire » ni « commande » à l'écran.
- Les messages d'erreur disent **quoi faire** (« Rechargez votre Crédit puis relancez la course »).
- Montants toujours avec l'unité : « 8 800 GNF ».

## 6. Méthode de travail
1. **Comprendre** : qui utilise l'écran, dans quelle situation, quelle est l'action n°1.
2. **Maquetter avant de coder** : dans Figma (serveur Figma connecté) ou en planche HTML partagée,
   proposer **2 à 3 directions** sur l'écran le plus important quand le changement est visible.
3. **Construire avec les composants existants** (`mobile_core/lib/widgets/`, `AppTheme`) ; créer un
   composant partagé plutôt que dupliquer un style.
4. **Vérifier** avec la checklist ci-dessous, puis `flutter analyze` (aucune nouvelle remarque).

## Checklist avant de livrer un écran
- [ ] Une seule action principale, en bas, en accent ; cibles ≥ 56 px (livreur) / ≥ 48 px.
- [ ] Aucune couleur / rayon / ombre en dur ; montants en `AppTheme.mono` + `AppCurrency.format`.
- [ ] ≤ 4 tailles de texte ; la valeur clé est l'élément le plus visible.
- [ ] États chargement / vide / erreur / hors ligne dessinés.
- [ ] Statut de course affiché avec la frise, pas un simple texte.
- [ ] Textes : vocabulaire produit, vouvoiement, erreurs actionnables, accents corrects.
- [ ] Lisible au soleil (contraste) et utilisable d'une main.

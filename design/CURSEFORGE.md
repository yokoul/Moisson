# Kit de soumission CurseForge — Moisson

Tout ce qu'il faut copier-coller pour créer le projet sur
https://authors.curseforge.com (Create a Project → World of Warcraft).

## Fiche projet

| Champ | Valeur |
|---|---|
| Name | Moisson |
| Slug (URL) | moisson |
| Summary | Full-screen harvest HUD for Classic Era with farm counters and account-wide stock — session, bags, bank, mailbox and alts. |
| Primary Category | Map & Minimap |
| Secondary Category | Professions |
| Game Version | 1.15.8 (Classic Era — cocher les versions 1.15.x proposées) |
| License | GNU General Public License version 3 (GPLv3) |
| Source | https://github.com/yokoul/Moisson |
| Project icon | `design/curseforge-512.png` (ou `curseforge-1024.png`) |

Note : CurseForge exige l'anglais par défaut — la description ci-dessous est
EN d'abord, section française à la suite. L'addon lui-même est enUS par
défaut avec frFR intégral.

## Description (à coller telle quelle)

---

**Moisson** ("harvest" in French) turns your minimap into a full-screen
harvest HUD for WoW Classic Era — and counts everything you gather.

The HUD mechanism is a tribute to FarmHud by Hizuro (GPL): the real minimap
is moved full screen, minimum zoom, near-invisible background — but the code
is a complete rewrite for the modern 1.15 client, built for an
ElvUI + GatherMate2 + Questie setup, and enriched with harvest counters that
do not exist in the original.

**Features**

- **Full-screen HUD** — GatherMate2 and Questie pins stay fully opaque while
  the map background fades out. A placeholder keeps your minimap buttons
  (ElvUI, LibDBIcon…) usable where they always were.
- **Radar rotation** (optional) — the map rotates with your character,
  cardinal points recomputed continuously.
- **Harvest counters** — herbs, ores, gems, leather, cloth, meat,
  elementals: per-item lines with icon, session count and **what is really
  in your bags** (pre-existing stacks included). Persistent per-category
  totals with `/moisson summary`.
- **Bags panel** — what your bags hold for your gathering professions
  (herbalism → herbs, mining → ores and gems, skinning → leather).
- **Account-wide stock** — bags, bank and mailbox of every character you
  play, kept between sessions: `/moisson stock` tells you who holds what and
  where, and an extra column in the HUD gives the account total at a glance —
  hold Alt and hover a counter line to see the breakdown without leaving the
  HUD. Several WoW accounts can be merged by copy-paste (`/moisson export` /
  `import`).
- **Radar mode** — background cycles between hidden, radar (tracking dots
  from Find Herbs/Minerals stay visible over a dimmed terrain) and map.
- **Transient mouse** — hold Alt to inspect pins under the cursor, release
  to keep mouse control of your character.
- **Minimap button** — left click: HUD, right click: options,
  shift-click: background, middle click: mouse. Key bindings available for
  everything (set them directly from the options panel).
- Player coordinates, optional hide-in-combat, item classification embedded
  for the whole Era database (the client's generic Trade Goods class is
  useless for sorting — Moisson ships its own verified item families).

**Languages:** English (default) and French — including slash commands
(`/moisson mouse` = `/moisson souris`).

**Diagnostics:** `/moisson test` runs a self-test of the counting chain;
`/moisson log` shows a persistent trace of recent loot decisions.

---

**Version française**

**Moisson** transforme votre minimap en HUD de récolte plein écran pour
WoW Classic Era — et compte tout ce que vous ramassez.

- **HUD plein écran** : les pins GatherMate2/Questie restent opaques pendant
  que le fond de carte s'efface ; un leurre garde vos boutons de minimap
  utilisables à leur place habituelle.
- **Compteurs de récolte** : herbes, minerais, gemmes, cuirs, tissus,
  viandes, élémentaires — par objet avec icône, récolte de la session et
  quantité réellement en sac (stocks antérieurs compris). Totaux globaux par
  catégorie via `/moisson bilan`.
- **Besace** : le contenu des sacs pour vos métiers de récolte.
- **Stocks du compte** : sacs, banque et boîte aux lettres de chacun de vos
  personnages, conservés d'une session à l'autre. `/moisson stocks` dit qui
  détient quoi et où, et une colonne de plus dans le HUD donne le total du
  compte d'un coup d'œil — Alt maintenue, le survol d'une ligne montre la
  répartition sans quitter le HUD. Plusieurs comptes WoW se fusionnent par
  copier-coller (`/moisson export` / `import`).
- **Mode radar** : fond invisible, radar (détections visibles sur terrain
  éteint) ou carte ; rotation optionnelle avec points cardinaux.
- **Souris fugace** : Alt maintenue = souris pour inspecter les pins.
- **Bouton minimap** : clic gauche = HUD, clic droit = options,
  maj-clic = fond, clic molette = souris. Raccourcis clavier définissables
  depuis le panneau d'options.

Mécanisme inspiré de FarmHud (Hizuro) — réécriture complète. GPLv3.

---

## Changelog v0.10.0 (champ « changelog » de l'upload)

```
Account-wide stock

- Bank, mailbox and alts are now counted, not just the bags you carry.
  Bags update live; bank and mail are recorded each time you open them.
- New "account" column in the harvest panel — quiet when there is nothing
  beyond your own bags. Hold Alt and hover a line: the tooltip names who
  holds the stock and where (bags, bank, mail).
- New window /moisson stock: who holds what and where, filter by category,
  this realm or all realms.
- Several WoW accounts merge by copy-paste: /moisson export, then import.
- /moisson summary now breaks the stock down by category and location.
```

**Version française (champ localisé, si tu en ajoutes un) :**

```
Stocks du compte

- La banque, la boîte aux lettres et les autres persos comptent enfin, et
  plus seulement les sacs qu'on porte. Les sacs suivent en temps réel ; la
  banque et le courrier sont relevés à chaque passage.
- Nouvelle colonne « compte » dans le panneau de récolte — muette quand il
  n'y a rien au-delà de vos propres sacs. Alt maintenue, le survol d'une
  ligne dit qui détient ces stocks et où (sacs, banque, courrier).
- Nouvelle fenêtre /moisson stocks : qui détient quoi et où, filtre par
  catégorie, ce royaume ou tous les royaumes.
- Plusieurs comptes WoW se fusionnent par copier-coller : /moisson export,
  puis import sur l'autre.
- /moisson bilan détaille désormais les stocks par catégorie et par lieu.
```

## Changelog v0.9.2

Correctifs uniquement — aucune fonctionnalité nouvelle.

```
Bug fixes

- Alt+Tab no longer leaves the transient mouse stuck on: the mouse mode now
  cross-checks the real keyboard state instead of trusting key events alone.
- Dragging the minimap button with the HUD open no longer throws it off
  screen — it follows the placeholder, not the full-screen minimap.
- HUD labels (arrow, cardinal points, coordinates) and the harvest panel now
  draw on top of the gathering pins instead of underneath.
- Unchecking "mouse while Alt is held" no longer leaves the mouse stuck on.
- Unchecking "hide in combat" during a fight no longer makes the HUD pop back
  up when combat ends.
- Options panel: keybind capture is properly released when the panel closes,
  only one button listens at a time, and rebinding is refused in combat.
```

**Version française (champ localisé, si tu en ajoutes un) :**

```
Correctifs

- L'Alt+Tab ne laisse plus la souris fugace bloquée : le mode souris recoupe
  l'état réel du clavier au lieu de se fier aux seuls événements de touche.
- Déplacer le bouton minimap HUD ouvert ne l'envoie plus hors de l'écran — il
  suit le leurre, pas la minimap partie en plein écran.
- L'habillage du HUD (flèche, points cardinaux, coordonnées) et le panneau de
  récolte se dessinent désormais au-dessus des pins, et non plus dessous.
- Décocher « souris tant qu'Alt est enfoncée » ne laisse plus la souris bloquée.
- Décocher « masquer en combat » pendant un combat ne fait plus réapparaître
  le HUD à la fin de celui-ci.
- Panneau d'options : la capture de raccourci est bien relâchée à la fermeture,
  un seul bouton écoute à la fois, et la redéfinition est refusée en combat.
```

## Changelog v0.9.1

```
- The on-screen button row is gone: everything lives on the minimap button
  (shift-click: background, middle click: mouse).
- Harvest panel lines now show "session · in bags": the bag count reads your
  real bags (pre-addon stacks included) and follows every bag update.
- Minimap button rebuilt on the standard LibDBIcon anatomy (content icon +
  tracking border) so minimap button skins render it like any other addon.
- New artwork: options panel logo, addon icon, project images.
```

## Upload

1. `./create-release.sh` → `build/Moisson-vX.Y.Z.zip`
2. Upload file → game version 1.15.x → coller le changelog ci-dessus.
3. Type de release : Release (pas Beta) à partir de v1.0.0 ; Beta pour les 0.9.x.

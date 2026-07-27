# Kit de soumission CurseForge — Moisson

Tout ce qu'il faut copier-coller pour créer le projet sur
https://authors.curseforge.com (Create a Project → World of Warcraft).

## Fiche projet

| Champ | Valeur |
|---|---|
| Name | Moisson |
| Slug (URL) | moisson |
| Summary | Full-screen harvest HUD for Classic Era with farm counters — session, bags and per-category totals. |
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
- **Mode radar** : fond invisible, radar (détections visibles sur terrain
  éteint) ou carte ; rotation optionnelle avec points cardinaux.
- **Souris fugace** : Alt maintenue = souris pour inspecter les pins.
- **Bouton minimap** : clic gauche = HUD, clic droit = options,
  maj-clic = fond, clic molette = souris. Raccourcis clavier définissables
  depuis le panneau d'options.

Mécanisme inspiré de FarmHud (Hizuro) — réécriture complète. GPLv3.

---

## Changelog v0.9.1 (champ « changelog » de l'upload)

```
- The on-screen button row is gone: everything lives on the minimap button
  (shift-click: background, middle click: mouse).
- Harvest panel lines now show "session · in bags": the bag count reads your
  real bags (pre-addon stacks included) and follows every bag update.
- Options panel logo and minimap button medallion updated.
```

## Upload

1. `./create-release.sh` → `build/Moisson-vX.Y.Z.zip`
2. Upload file → game version 1.15.x → coller le changelog ci-dessus.
3. Type de release : Release (pas Beta) à partir de v1.0.0 ; Beta pour les 0.9.x.

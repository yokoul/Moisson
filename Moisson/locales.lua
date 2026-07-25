-- Moisson — localisation. enUS par défaut (exigence CurseForge), frFR
-- intégral. Tout libellé visible passe par ns.L ; une clé absente d'une
-- locale retombe sur l'anglais.

local ADDON, ns = ...

local L = {
	-- HUD
	CARDINAUX = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" },
	SOURIS_ACTIVE = "— MOUSE ACTIVE —\n|cffcccccc(hover dots and pins to identify)|r",
	COMBAT_INDISPO = "HUD unavailable in combat.",
	FOND_INVISIBLE = "background hidden.",
	FOND_RADAR = "radar (tracking dots visible, terrain dimmed).",
	FOND_CARTE = "map background shown.",

	-- boutons à l'écran
	BTN_SOURIS = "Mouse (inspect pins)",
	BTN_FOND = "Background: hidden / radar / map",
	BTN_OPTIONS = "Options",
	BTN_FERMER = "Close",

	-- raccourcis clavier
	BIND_TOGGLE = "Show / hide the HUD",
	BIND_MOUSE = "Toggle mouse (HUD open)",
	BIND_FOND = "Cycle map background (HUD open)",

	-- bouton minimap
	MMB_TIP = "Left click: HUD · Right click: options",
	MMB_SESSION = "Session: ",

	-- compteurs
	CAT_HERBES = "Herbs", CAT_MINERAIS = "Ores", CAT_GEMMES = "Gems",
	CAT_CUIRS = "Leather", CAT_TISSUS = "Cloth", CAT_VIANDES = "Meat",
	CAT_ELEMS = "Elementals", CAT_AUTRES = "Other",
	TITRE_RECOLTE = "|cff7fbf3fHarvest|r  |cff808080session · total|r",
	TITRE_BESACE = "|cff7fbf3fBags|r  |cff808080by profession|r",
	RIEN_SESSION = "|cff808080nothing this session|r",
	OBJET_INCONNU = "item %d",
	BILAN_TITRE = "harvest summary (session · total):",
	BILAN_VIDE = "  nothing yet — go gather!",
	RAZ_TOUT = "global and session counters reset.",
	RAZ_SESSION = "session counters reset.",
	TEST_ENTETE = "self-test — %d CHAT_MSG_LOOT message(s) received since login.",
	TEST_OK = "counting chain |cff7fbf3fOK|r (4 fake loots counted then removed).",
	TEST_KO = "|cffff4040FAILED|r: %d counted instead of 4 — run /moisson journal.",
	JOURNAL_VIDE = "journal empty — no CHAT_MSG_LOOT traced yet.",
	JOURNAL_TITRE = "loot journal (%d):",
	ERREUR_COMPTEUR = "|cffff4040counter error:|r ",

	-- journal de diagnostic
	J_COMPTE = "counted: %s x%d (%s, class %s/%s)",
	J_IGNORE = "ignored (not a personal loot): ",
	J_SANS_LIEN = "no item link in: ",
	J_SANS_ID = "no itemID in link: ",
	J_NON_SUIVIE = "%s: class %s/%s → not tracked",
	J_ERREUR = "ERROR: ",

	-- slash
	AIDE = {
		"commands:",
		"  /moisson — show / hide the HUD",
		"  /moisson options — settings panel",
		"  /moisson mouse — enable mouse (pin tooltips)",
		"  /moisson background — cycle hidden / radar / map",
		"  /moisson rotation — fixed or rotating map",
		"  /moisson size 0.3–1.2 · scale 1–2 · alpha 0–1 · cardalpha 0–1",
		"  /moisson counters — harvest panel on/off",
		"  /moisson summary — totals in chat",
		"  /moisson reset — session reset (« reset all »: global)",
		"  /moisson test — counters self-test · log — loot traces",
	},
	ROTATION_ON = "rotation enabled.",
	ROTATION_OFF = "rotation disabled.",
	VAL_TAILLE = "size: %s",
	ERR_TAILLE = "expected size between 0.3 and 1.2.",
	VAL_CARDALPHA = "cardinal points opacity: %s",
	ERR_01 = "expected value between 0 and 1.",
	VAL_ECHELLE = "pin scale: %s",
	ERR_ECHELLE = "expected scale between 1 and 2.",
	VAL_ALPHA = "alpha: %s",
	COMPTEURS_ON = "counters shown.",
	COMPTEURS_OFF = "counters hidden.",
	DEBUG_ON = "loot debug enabled — gather something and read the chat.",
	DEBUG_OFF = "loot debug disabled.",

	-- options
	OPT_SOUSTITRE = "Full-screen harvest HUD — bindings below.  In game: /moisson help",
	OPT_ROTATION = "Radar-style rotation (the map turns with the player)",
	OPT_CARDINAUX = "Cardinal points (N/NE/E/…)",
	OPT_COORDS = "Player coordinates",
	OPT_COMPTEURS = "Harvest counters panel",
	OPT_BOUTONS = "On-screen buttons (mouse, background, options, close)",
	OPT_SOURISALT = "Mouse while Alt is held (hover identification)",
	OPT_COMBAT = "Hide the HUD in combat",
	OPT_TAILLE = "HUD size",
	OPT_ECHELLE = "Pin magnification",
	OPT_ALPHA = "Map background (hidden mode)",
	OPT_ALPHA2 = "Map background (map mode)",
	OPT_RADARFOND = "Radar: map background",
	OPT_RADARVOILE = "Radar: black veil",
	OPT_CARDALPHA = "Cardinal points opacity",
	OPT_BIND_HUD = "Show / hide the HUD",
	OPT_BIND_SOURIS = "Toggle mouse",
	OPT_BIND_FOND = "Cycle map background",
	OPT_NON_DEFINI = "|cff808080not bound|r",
	OPT_APPUIE = "press a key… (Esc: clear)",
	OPT_RAZ_SESSION = "Reset session counters",
	OPT_RAZ_TOUT = "Reset all (global)",
	OPT_CREDITS = "Mechanism inspired by FarmHud (Hizuro) — full rewrite by yokoul. GPLv3.",
}
ns.L = L

if GetLocale() == "frFR" then
	L.CARDINAUX = { "N", "NE", "E", "SE", "S", "SO", "O", "NO" }
	L.SOURIS_ACTIVE = "— SOURIS ACTIVE —\n|cffcccccc(survol des points et pins : identification)|r"
	L.COMBAT_INDISPO = "HUD indisponible en combat."
	L.FOND_INVISIBLE = "fond invisible."
	L.FOND_RADAR = "radar (détections visibles, terrain éteint)."
	L.FOND_CARTE = "carte."

	L.BTN_SOURIS = "Souris (inspecter les pins)"
	L.BTN_FOND = "Fond : invisible / radar / carte"
	L.BTN_OPTIONS = "Options"
	L.BTN_FERMER = "Fermer"

	L.BIND_TOGGLE = "Afficher / masquer le HUD"
	L.BIND_MOUSE = "Basculer la souris (HUD ouvert)"
	L.BIND_FOND = "Basculer le fond de carte (HUD ouvert)"

	L.MMB_TIP = "Clic gauche : HUD · Clic droit : options"
	L.MMB_SESSION = "Session : "

	L.CAT_HERBES = "Herbes"; L.CAT_MINERAIS = "Minerais"; L.CAT_GEMMES = "Gemmes"
	L.CAT_CUIRS = "Cuirs"; L.CAT_TISSUS = "Tissus"; L.CAT_VIANDES = "Viandes"
	L.CAT_ELEMS = "Élémentaires"; L.CAT_AUTRES = "Autres"
	L.TITRE_RECOLTE = "|cff7fbf3fRécolte|r  |cff808080session · total|r"
	L.TITRE_BESACE = "|cff7fbf3fBesace|r  |cff808080selon le métier|r"
	L.RIEN_SESSION = "|cff808080rien cette session|r"
	L.OBJET_INCONNU = "objet %d"
	L.BILAN_TITRE = "bilan de récolte (session · total) :"
	L.BILAN_VIDE = "  rien pour l'instant — va cueillir !"
	L.RAZ_TOUT = "compteurs globaux et session remis à zéro."
	L.RAZ_SESSION = "compteurs de session remis à zéro."
	L.TEST_ENTETE = "auto-test — %d message(s) CHAT_MSG_LOOT reçu(s) depuis la connexion."
	L.TEST_OK = "chaîne de comptage |cff7fbf3fOK|r (4 fictifs comptés puis retirés)."
	L.TEST_KO = "|cffff4040ÉCHEC|r : %d compté(s) au lieu de 4 — lance /moisson journal."
	L.JOURNAL_VIDE = "journal vide — aucun CHAT_MSG_LOOT tracé pour l'instant."
	L.JOURNAL_TITRE = "journal des butins (%d) :"
	L.ERREUR_COMPTEUR = "|cffff4040erreur compteur :|r "

	L.J_COMPTE = "compté : %s x%d (%s, classe %s/%s)"
	L.J_IGNORE = "ignoré (pas un butin personnel) : "
	L.J_SANS_LIEN = "pas de lien d'objet dans : "
	L.J_SANS_ID = "pas d'itemID dans le lien : "
	L.J_NON_SUIVIE = "%s : classe %s/%s → non suivie"
	L.J_ERREUR = "ERREUR : "

	L.AIDE = {
		"commandes :",
		"  /moisson — afficher/masquer le HUD",
		"  /moisson options — panneau de réglages",
		"  /moisson souris — activer la souris (tooltips des pins)",
		"  /moisson fond — cycle invisible / radar (détections) / carte",
		"  /moisson rotation — carte fixe ou rotative",
		"  /moisson taille 0.3–1.2 · echelle 1–2 · alpha 0–1 · cardalpha 0–1",
		"  /moisson compteurs — panneau de récolte on/off",
		"  /moisson bilan — totaux en chat",
		"  /moisson raz — remise à zéro session (« raz tout » : global)",
		"  /moisson test — auto-test des compteurs · journal — traces des butins",
	}
	L.ROTATION_ON = "rotation activée."
	L.ROTATION_OFF = "rotation désactivée."
	L.VAL_TAILLE = "taille : %s"
	L.ERR_TAILLE = "taille attendue entre 0.3 et 1.2."
	L.VAL_CARDALPHA = "transparence des cardinaux : %s"
	L.ERR_01 = "valeur attendue entre 0 et 1."
	L.VAL_ECHELLE = "échelle des pins : %s"
	L.ERR_ECHELLE = "échelle attendue entre 1 et 2."
	L.VAL_ALPHA = "alpha : %s"
	L.COMPTEURS_ON = "compteurs affichés."
	L.COMPTEURS_OFF = "compteurs masqués."
	L.DEBUG_ON = "debug loot activé — ramasse quelque chose et lis le chat."
	L.DEBUG_OFF = "debug loot désactivé."

	L.OPT_SOUSTITRE = "HUD de récolte plein écran — raccourcis définissables ci-dessous.  En jeu : /moisson aide"
	L.OPT_ROTATION = "Rotation façon radar (la carte tourne avec le joueur)"
	L.OPT_CARDINAUX = "Points cardinaux (N/NE/E/…)"
	L.OPT_COORDS = "Coordonnées du joueur"
	L.OPT_COMPTEURS = "Panneau des compteurs de récolte"
	L.OPT_BOUTONS = "Boutons à l'écran (souris, fond, options, fermer)"
	L.OPT_SOURISALT = "Souris tant qu'Alt est enfoncée (identification au survol)"
	L.OPT_COMBAT = "Masquer le HUD en combat"
	L.OPT_TAILLE = "Taille du HUD"
	L.OPT_ECHELLE = "Grossissement des pins"
	L.OPT_ALPHA = "Fond de carte (mode invisible)"
	L.OPT_ALPHA2 = "Fond de carte (mode carte)"
	L.OPT_RADARFOND = "Radar : fond de carte"
	L.OPT_RADARVOILE = "Radar : voile noir"
	L.OPT_CARDALPHA = "Opacité des cardinaux"
	L.OPT_BIND_HUD = "Ouvrir / fermer le HUD"
	L.OPT_BIND_SOURIS = "Basculer la souris"
	L.OPT_BIND_FOND = "Basculer le fond de carte"
	L.OPT_NON_DEFINI = "|cff808080non défini|r"
	L.OPT_APPUIE = "appuie sur une touche… (Échap : effacer)"
	L.OPT_RAZ_SESSION = "RàZ compteurs session"
	L.OPT_RAZ_TOUT = "RàZ tout (global)"
	L.OPT_CREDITS = "Mécanisme inspiré de FarmHud (Hizuro) — réécriture yokoul. GPLv3."
end

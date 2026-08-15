-- Moisson — localisation. enUS par défaut (exigence CurseForge), frFR
-- intégral. Tout libellé visible passe par ns.L ; une clé absente d'une
-- locale retombe sur l'anglais.

local ADDON, ns = ...

local L = {
	-- HUD
	CARDINAUX = { "N", "NE", "E", "SE", "S", "SW", "W", "NW" },
	SOURIS_ACTIVE = "— MOUSE ACTIVE —\n|cffcccccc(hover dots, pins and counters to identify)|r",
	COMBAT_INDISPO = "HUD unavailable in combat.",
	FOND_INVISIBLE = "background hidden.",
	FOND_RADAR = "radar (tracking dots visible, terrain dimmed).",
	FOND_CARTE = "map background shown.",

	-- raccourcis clavier
	BIND_TOGGLE = "Show / hide the HUD",
	BIND_MOUSE = "Toggle mouse (HUD open)",
	BIND_FOND = "Cycle map background (HUD open)",

	-- bouton minimap
	MMB_TIP = "Left click: HUD · Right click: options",
	MMB_TIP2 = "HUD open — Shift-click: background · Middle click: mouse",
	MMB_SESSION = "Session: ",

	-- compteurs
	CAT_HERBES = "Herbs", CAT_MINERAIS = "Ores", CAT_GEMMES = "Gems",
	CAT_CUIRS = "Leather", CAT_TISSUS = "Cloth", CAT_VIANDES = "Meat",
	CAT_ELEMS = "Elementals", CAT_AUTRES = "Other",
	TITRE_RECOLTE = "|cff7fbf3fHarvest|r  |cff808080session · |r|cff7fbf3fbags|r|cff808080 · |r|cff6a9fd8account|r",
	TITRE_BESACE = "|cff7fbf3fBags|r  |cff808080by profession|r",
	RIEN_SESSION = "|cff808080nothing this session|r",
	OBJET_INCONNU = "item %d",
	BILAN_TITRE = "harvest summary (session · looted · |cff6a9fd8stock|r):",
	BILAN_VIDE = "  nothing yet — go gather!",
	BILAN_LIEUX = "  stock: bags %d · bank %d · mailbox %d",
	BILAN_PORTEE = "  scope: %s",
	RAZ_TOUT = "global and session counters reset.",
	RAZ_SESSION = "session counters reset.",
	TEST_ENTETE = "self-test — %d CHAT_MSG_LOOT message(s) received since login.",
	TEST_OK = "counting chain |cff7fbf3fOK|r (4 fake loots counted then removed).",
	TEST_KO = "|cffff4040FAILED|r: %d counted instead of 4 — run /moisson journal.",
	JOURNAL_VIDE = "journal empty — no CHAT_MSG_LOOT traced yet.",
	JOURNAL_TITRE = "loot journal (%d):",
	ERREUR_COMPTEUR = "|cffff4040counter error:|r ",

	-- stocks du compte
	COMPTE_DEFAUT = "account 1",
	PORTEE_ROYAUME = "This realm",
	PORTEE_TOUT = "All realms",
	STOCKS_TITRE = "|cff7fbf3fMoisson|r — account stock",
	STOCKS_ENTETE = "Total |cffffd200%d|r  ·  bags %d · bank %d · mailbox %d",
	STOCKS_PIED = "%d character(s) known — click: expand · right click a character: forget",
	STOCKS_VIDE = "nothing recorded yet — visit your bank and mailbox once.",
	FILTRE_TOUT = "All categories",
	LIEU_SACS = "bags %d",
	LIEU_BANQUE = "bank %d",
	LIEU_MALLE = "mail %d",
	TIP_COMPTE = "account %s · %s",
	TIP_AUCUN = "none anywhere on the account.",
	TIP_AUTRES = "…and %d more character(s)",
	TIP_MAJ = "last seen %s",
	TIP_MAJ_BANQUE = "bank recorded %s",
	TIP_MAJ_MALLE = "mailbox recorded %s",
	TIP_OUBLI = "right click: forget this character",
	BTN_EXPORT = "Export",
	BTN_IMPORT = "Import",
	BTN_TOUT_SELECT = "Select all",
	BTN_IMPORTER = "Import this",
	ECHANGE_TITRE_EXPORT = "|cff7fbf3fMoisson|r — export this account",
	ECHANGE_AIDE_EXPORT = "Ctrl+C to copy, then log into your other WoW account and paste it in Import. Saved variables never cross accounts on their own.",
	ECHANGE_TITRE_IMPORT = "|cff7fbf3fMoisson|r — import another account",
	ECHANGE_AIDE_IMPORT = "Ctrl+V the string exported from your other account, then click Import.",
	IMPORT_VIDE = "nothing to import — paste the exported string first.",
	IMPORT_ILLISIBLE = "unreadable string — expected a Moisson export (MSN1…).",
	IMPORT_MEME_COMPTE = "this export comes from « %s », the current account — rename one of them with /moisson account <name>.",
	IMPORT_OK = "%d character(s) imported from « %s ».",
	OUBLI_CONFIRME = "Forget %s and everything Moisson knows about their stock?",
	OUBLI_FAIT = "%s forgotten.",
	OUBLI_SOI = "the character you are playing cannot be forgotten.",
	OUBLI_TOUT = "%d character(s) forgotten.",
	OUBLI_RIEN = "no matching character.",
	OUBLI_USAGE = "/moisson forget <character> — or « forget all » to wipe every character but this one.",
	COMPTE_NOM = "this account is now named « %s ».",
	COMPTE_ACTUEL = "this account is named « %s » — /moisson account <name> to rename it.",
	VAL_PORTEE = "scope: %s",

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
		"  /moisson stock — bags, bank and mail of every character",
		"  /moisson scope — this realm or all realms",
		"  /moisson export · import — share stock between WoW accounts",
		"  /moisson account <name> — name this account",
		"  /moisson forget <char> — drop a character from the stock",
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
	OPT_STOCKCOMPTE = "Account column (bank, mail and other characters)",
	OPT_PORTEE = "Count all realms, not just this one",
	OPT_STOCKS = "Open the account stock window",
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
	OPT_BIND_COMBAT = "keybindings cannot be changed in combat.",
	OPT_RAZ_SESSION = "Reset session counters",
	OPT_RAZ_TOUT = "Reset all (global)",
	OPT_CREDITS = "Mechanism inspired by FarmHud (Hizuro) — full rewrite by yokoul. GPLv3.",
}
ns.L = L

if GetLocale() == "frFR" then
	L.CARDINAUX = { "N", "NE", "E", "SE", "S", "SO", "O", "NO" }
	L.SOURIS_ACTIVE = "— SOURIS ACTIVE —\n|cffcccccc(survol des points, pins et compteurs : identification)|r"
	L.COMBAT_INDISPO = "HUD indisponible en combat."
	L.FOND_INVISIBLE = "fond invisible."
	L.FOND_RADAR = "radar (détections visibles, terrain éteint)."
	L.FOND_CARTE = "carte."

	L.BIND_TOGGLE = "Afficher / masquer le HUD"
	L.BIND_MOUSE = "Basculer la souris (HUD ouvert)"
	L.BIND_FOND = "Basculer le fond de carte (HUD ouvert)"

	L.MMB_TIP = "Clic gauche : HUD · Clic droit : options"
	L.MMB_TIP2 = "HUD ouvert — Maj-clic : fond · Clic molette : souris"
	L.MMB_SESSION = "Session : "

	L.CAT_HERBES = "Herbes"; L.CAT_MINERAIS = "Minerais"; L.CAT_GEMMES = "Gemmes"
	L.CAT_CUIRS = "Cuirs"; L.CAT_TISSUS = "Tissus"; L.CAT_VIANDES = "Viandes"
	L.CAT_ELEMS = "Élémentaires"; L.CAT_AUTRES = "Autres"
	L.TITRE_RECOLTE = "|cff7fbf3fRécolte|r  |cff808080session · |r|cff7fbf3fen sac|r|cff808080 · |r|cff6a9fd8compte|r"
	L.TITRE_BESACE = "|cff7fbf3fBesace|r  |cff808080selon le métier|r"
	L.RIEN_SESSION = "|cff808080rien cette session|r"
	L.OBJET_INCONNU = "objet %d"
	L.BILAN_TITRE = "bilan de récolte (session · récolté · |cff6a9fd8en stock|r) :"
	L.BILAN_VIDE = "  rien pour l'instant — va cueillir !"
	L.BILAN_LIEUX = "  stock : sacs %d · banque %d · courrier %d"
	L.BILAN_PORTEE = "  portée : %s"

	L.COMPTE_DEFAUT = "compte 1"
	L.PORTEE_ROYAUME = "Ce royaume"
	L.PORTEE_TOUT = "Tous royaumes"
	L.STOCKS_TITRE = "|cff7fbf3fMoisson|r — stocks du compte"
	L.STOCKS_ENTETE = "Total |cffffd200%d|r  ·  sacs %d · banque %d · courrier %d"
	L.STOCKS_PIED = "%d personnage(s) connu(s) — clic : déplier · clic droit sur un perso : oublier"
	L.STOCKS_VIDE = "rien de relevé — passe une fois à ta banque et à ta boîte aux lettres."
	L.FILTRE_TOUT = "Toutes les catégories"
	L.LIEU_SACS = "sacs %d"
	L.LIEU_BANQUE = "banque %d"
	L.LIEU_MALLE = "courrier %d"
	L.TIP_COMPTE = "compte %s · %s"
	L.TIP_AUCUN = "nulle part sur le compte."
	L.TIP_AUTRES = "…et %d autre(s) personnage(s)"
	L.TIP_MAJ = "vu pour la dernière fois le %s"
	L.TIP_MAJ_BANQUE = "banque relevée le %s"
	L.TIP_MAJ_MALLE = "courrier relevé le %s"
	L.TIP_OUBLI = "clic droit : oublier ce personnage"
	L.BTN_EXPORT = "Exporter"
	L.BTN_IMPORT = "Importer"
	L.BTN_TOUT_SELECT = "Tout sélectionner"
	L.BTN_IMPORTER = "Importer ceci"
	L.ECHANGE_TITRE_EXPORT = "|cff7fbf3fMoisson|r — exporter ce compte"
	L.ECHANGE_AIDE_EXPORT = "Ctrl+C pour copier, puis connecte-toi sur ton autre compte WoW et colle la chaîne dans Importer. Les SavedVariables ne franchissent pas seules la frontière d'un compte."
	L.ECHANGE_TITRE_IMPORT = "|cff7fbf3fMoisson|r — importer un autre compte"
	L.ECHANGE_AIDE_IMPORT = "Ctrl+V la chaîne exportée depuis l'autre compte, puis clique sur Importer."
	L.IMPORT_VIDE = "rien à importer — colle d'abord la chaîne exportée."
	L.IMPORT_ILLISIBLE = "chaîne illisible — un export Moisson est attendu (MSN1…)."
	L.IMPORT_MEME_COMPTE = "cet export vient de « %s », le compte courant — renomme l'un des deux avec /moisson compte <nom>."
	L.IMPORT_OK = "%d personnage(s) importé(s) depuis « %s »."
	L.OUBLI_CONFIRME = "Oublier %s et tout ce que Moisson sait de ses stocks ?"
	L.OUBLI_FAIT = "%s oublié."
	L.OUBLI_SOI = "impossible d'oublier le personnage en cours de jeu."
	L.OUBLI_TOUT = "%d personnage(s) oublié(s)."
	L.OUBLI_RIEN = "aucun personnage de ce nom."
	L.OUBLI_USAGE = "/moisson oublie <perso> — ou « oublie tout » pour vider tous les persos sauf celui-ci."
	L.COMPTE_NOM = "ce compte s'appelle désormais « %s »."
	L.COMPTE_ACTUEL = "ce compte s'appelle « %s » — /moisson compte <nom> pour le renommer."
	L.VAL_PORTEE = "portée : %s"
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
		"  /moisson stocks — sacs, banque et courrier de chaque perso",
		"  /moisson portee — ce royaume ou tous les royaumes",
		"  /moisson export · import — partager les stocks entre comptes WoW",
		"  /moisson compte <nom> — nommer ce compte",
		"  /moisson oublie <perso> — retirer un perso des stocks",
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
	L.OPT_STOCKCOMPTE = "Colonne « compte » (banque, courrier et autres persos)"
	L.OPT_PORTEE = "Compter tous les royaumes, pas seulement celui-ci"
	L.OPT_STOCKS = "Ouvrir la fenêtre des stocks du compte"
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
	L.OPT_BIND_COMBAT = "impossible de changer un raccourci en combat."
	L.OPT_RAZ_SESSION = "RàZ compteurs session"
	L.OPT_RAZ_TOUT = "RàZ tout (global)"
	L.OPT_CREDITS = "Mécanisme inspiré de FarmHud (Hizuro) — réécriture yokoul. GPLv3."
end

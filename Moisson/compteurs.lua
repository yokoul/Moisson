-- Moisson — compteurs de récolte (le différenciateur maison).
-- On écoute les messages de butin personnels, on ne retient que les
-- marchandises de farm et on cumule par objet : session + global. Un volet
-- « besace » montre en plus ce que les sacs contiennent pour le(s) métier(s)
-- de récolte du personnage.

local ADDON, ns = ...

-- les globales historiques ont été retirées du client 1.15 → API C_Item
local GetItemInfoInstant = (C_Item and C_Item.GetItemInfoInstant) or _G.GetItemInfoInstant
local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemCount = (C_Item and C_Item.GetItemCount) or _G.GetItemCount
local L = ns.L

-- catégories de farm : définies une fois dans donnees.lua, partagées avec les
-- stocks et la fenêtre de bilan
local CATS, ORDRE_CATS = ns.CATS, ns.ORDRE_CATS
local Categorie = ns.Categorie

local session = {}      -- [itemID] = quantité depuis la connexion
local sessionCats = {}  -- [cat] = quantité
local MAX_LIGNES = 10
local MAX_SACS = 8

-- préfixes localisés des messages de butin personnels (« Vous recevez… »)
local prefixes = {}
for _, g in ipairs({ LOOT_ITEM_SELF, LOOT_ITEM_SELF_MULTIPLE,
	LOOT_ITEM_PUSHED_SELF, LOOT_ITEM_PUSHED_SELF_MULTIPLE }) do
	local p = g and g:match("^(.-)%%")
	if p and p ~= "" then prefixes[p] = true end
end

local function isSelfLoot(msg)
	for p in pairs(prefixes) do
		if msg:sub(1, #p) == p then return true end
	end
	return false
end

-- ------------------------------------------------------------------ journal --

-- Trace persistante (SavedVariables) des derniers messages de butin et de la
-- décision prise : lisible après /reload même si personne ne regardait le
-- chat. /moisson journal pour l'afficher en jeu.
local MAX_JOURNAL = 30

local function journal(s)
	local j = MoissonDB and MoissonDB.journal
	if not j then return end
	j[#j + 1] = date("%H:%M:%S ") .. s
	while #j > MAX_JOURNAL do table.remove(j, 1) end
end

local function dbg(s)
	journal(s)
	if ns.debugLoot then ns.print("|cff808080[debug]|r " .. s) end
end

function ns.Journal()
	local j = MoissonDB.journal
	if not j or #j == 0 then
		ns.print(L.JOURNAL_VIDE)
		return
	end
	ns.print(L.JOURNAL_TITRE:format(#j))
	for _, ligne in ipairs(j) do
		ns.print("  " .. ligne)
	end
end

-- ------------------------------------------------------- métiers de récolte --

-- rangs Apprenti/Compagnon/Expert/Artisan de chaque métier de récolte
local PROFS = {
	{ sorts = { 2366, 2368, 3570, 11993 }, cats = { herbes = true } },                  -- herboristerie
	{ sorts = { 2575, 2576, 3564, 10248 }, cats = { minerais = true, gemmes = true } }, -- minage
	{ sorts = { 8613, 8617, 8618, 10768 }, cats = { cuirs = true } },                   -- dépeçage
}

local function CatsBesace()
	local connu = IsPlayerSpell or IsSpellKnown
	if not connu then return end
	local voulu
	for _, prof in ipairs(PROFS) do
		for _, sort in ipairs(prof.sorts) do
			if connu(sort) then
				voulu = voulu or {}
				for c in pairs(prof.cats) do voulu[c] = true end
				break
			end
		end
	end
	return voulu
end

local function ScanBesace(voulu)
	local totaux = {} -- [itemID] = { n, icone, cat }
	for id, n in pairs(ns.ScanConteneurs(ns.SACS_PORTES)) do
		local cat, icone = ns.CategorieDe(id)
		if cat and voulu[cat] then
			totaux[id] = { n = n, icone = icone, cat = cat }
		end
	end
	return totaux
end

-- ------------------------------------------------------------------ panneau --

local panel  -- construit paresseusement (a besoin de ns.hud)
local souris = false -- le HUD est transparent aux clics tant qu'on ne la demande pas

-- Carré invisible posé sur la seule icône en tête de ligne : c'est elle qui
-- reçoit le survol et sort le tooltip de répartition. Réduire le déclencheur à
-- l'icône évite un tooltip permanent dès qu'on traverse le panneau, et laisse
-- le reste de la ligne transparent. La zone ne mange d'ailleurs la souris que
-- lorsque le HUD l'a activée (Alt maintenue ou /moisson souris) — sinon elle
-- bloquerait les clics de jeu dans le coin gauche de l'écran.
local TAILLE_ICONE = 18

local function ZoneSurvol(parent, ancre)
	local z = CreateFrame("Button", nil, parent)
	z:SetSize(TAILLE_ICONE, TAILLE_ICONE) -- placée par Placer(), selon le bord
	z:EnableMouse(souris)
	z:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight", "ADD")
	z:SetScript("OnEnter", function(self)
		if not self.id then return end
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		ns.TooltipStock(GameTooltip, self.id)
	end)
	z:SetScript("OnLeave", function() GameTooltip:Hide() end)
	z:Hide()
	return z
end

-- suit l'interrupteur de souris du HUD (core.lua)
function ns.CompteursSouris(on)
	souris = on and true or false
	if not panel then return end
	panel.zoneTitre:EnableMouse(souris)
	for i = 1, MAX_LIGNES do panel.zones[i]:EnableMouse(souris) end
	for i = 1, MAX_SACS do panel.sacZones[i]:EnableMouse(souris) end
	if not souris then GameTooltip:Hide() end
end

-- ------------------------------------------------------ placement et repli --

local HAUTEUR = 20 + MAX_LIGNES * 18 + 30 + MAX_SACS * 18
local H_REPLIE = 44 -- titre + résumé de session, rien d'autre

-- Le panneau se pose contre un bord du HUD ; tout bascule en miroir, jusqu'aux
-- icônes, pour qu'elles restent du côté du bord et que les lignes s'alignent
-- proprement au lieu de partir en escalier vers le centre de l'écran.
local function Placer()
	if not panel then return end
	local droite = ns.db.cote == "droite"
	local bord = droite and "RIGHT" or "LEFT"
	local haut = droite and "TOPRIGHT" or "TOPLEFT"
	local bas  = droite and "BOTTOMRIGHT" or "BOTTOMLEFT"

	panel:ClearAllPoints()
	panel:SetPoint(bord, ns.hud, bord, droite and -24 or 24, 0)

	local prev
	for _, e in ipairs(panel.ordre) do
		e.fs:ClearAllPoints()
		if prev then
			e.fs:SetPoint(haut, prev, bas, 0, e.dy)
		else
			e.fs:SetPoint(haut, panel, haut, 0, 0)
		end
		e.fs:SetJustifyH(droite and "RIGHT" or "LEFT")
		if e.zone then
			e.zone:ClearAllPoints()
			e.zone:SetPoint(bord, e.fs, bord, droite and 1 or -1, 0)
		end
		prev = e.fs
	end
end

-- Marqueur de pliage. Une vraie icône se repère bien mieux qu'un signe en
-- texte, mais elle vient du client : si la texture manque, on retombe sur un
-- « + » doré plutôt que d'afficher un carré vide.
local ICONE_PLI = {
	[true]  = "Interface\\Buttons\\UI-PlusButton-Up",  -- replié : on peut ouvrir
	[false] = "Interface\\Buttons\\UI-MinusButton-Up",
}
local iconesOk

local function Marqueur()
	local replie = ns.db.replie and true or false
	if iconesOk == nil then
		local essai = UIParent:CreateTexture()
		essai:SetTexture(ICONE_PLI[true])
		iconesOk = essai:GetTexture() ~= nil
		essai:Hide()
	end
	if iconesOk then return "|T" .. ICONE_PLI[replie] .. ":16|t" end
	return "|cffffd200" .. (replie and "+" or "-") .. "|r"
end

-- Le titre porte le marqueur de repli, du côté du bord lui aussi. Replié, il
-- se réduit au seul mot « Récolte » : la légende des colonnes n'a plus rien à
-- légender, et le but du repli est justement de dégager la vue. Elle reste
-- alors consultable au survol du titre.
local function MajEntete()
	if not panel then return end
	local marque = Marqueur()
	local nom = L.TITRE_RECOLTE
	if not ns.db.replie then nom = nom .. "  " .. L.LEGENDE_COLONNES end
	if ns.db.cote == "droite" then
		panel.titre:SetText(nom .. " " .. marque)
	else
		panel.titre:SetText(marque .. " " .. nom)
	end
	panel:SetHeight(ns.db.replie and H_REPLIE or HAUTEUR)
end

local function BuildPanel()
	panel = CreateFrame("Frame", "MoissonCompteurs", ns.hud)
	panel:SetSize(260, HAUTEUR)
	panel:SetFrameLevel(20) -- au-dessus du cluster de pins (niveau 5)

	panel.ordre = {} -- éléments dans l'ordre vertical, pour Placer()
	local function ajoute(fs, dy, zone)
		panel.ordre[#panel.ordre + 1] = { fs = fs, dy = dy, zone = zone }
	end

	panel.titre = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	ajoute(panel.titre, 0)

	-- replier/déplier au clic : le titre est la poignée naturelle. Comme les
	-- icônes, elle n'écoute qu'en mode souris ; le raccourci clavier et
	-- /moisson replier marchent, eux, à tout moment.
	panel.zoneTitre = CreateFrame("Button", nil, panel)
	panel.zoneTitre:SetAllPoints(panel.titre)
	panel.zoneTitre:EnableMouse(souris)
	panel.zoneTitre:SetScript("OnClick", function() Moisson_ToggleReplier() end)
	panel.zoneTitre:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:ClearLines()
		GameTooltip:AddLine(ns.db.replie and L.TIP_DEPLIER or L.TIP_REPLIER,
			1, 0.82, 0)
		-- replié, le titre a perdu sa légende : on la rend ici
		if ns.db.replie then GameTooltip:AddLine(L.LEGENDE_COLONNES) end
		GameTooltip:Show()
	end)
	panel.zoneTitre:SetScript("OnLeave", function() GameTooltip:Hide() end)

	panel.resume = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	ajoute(panel.resume, -4)

	panel.lignes, panel.zones = {}, {}
	for i = 1, MAX_LIGNES do
		local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		panel.lignes[i] = fs
		panel.zones[i] = ZoneSurvol(panel, fs)
		ajoute(fs, i == 1 and -6 or -4, panel.zones[i])
	end

	panel.sacTitre = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	panel.sacTitre:SetText(L.TITRE_BESACE)
	ajoute(panel.sacTitre, -12)

	panel.sacLignes, panel.sacZones = {}, {}
	for i = 1, MAX_SACS do
		local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		panel.sacLignes[i] = fs
		panel.sacZones[i] = ZoneSurvol(panel, fs)
		ajoute(fs, i == 1 and -6 or -4, panel.sacZones[i])
	end

	Placer()
	MajEntete()
	panel:Hide()
end

-- rejoués depuis les options (core.lua) quand le côté ou le repli changent
function ns.CompteursPlacer()
	Placer()
	MajEntete()
end

-- résumé de session par catégorie (partagé avec le tooltip du bouton minimap)
function ns.SessionResume()
	local resume = {}
	for _, cat in ipairs(ORDRE_CATS) do
		local n = sessionCats[cat]
		if n and n > 0 then
			resume[#resume + 1] = "|T" .. CATS[cat].icone .. ":14|t " .. n
		end
	end
	if #resume > 0 then return table.concat(resume, "   ") end
end

-- Une ligne se lit toujours dans le même ordre ; seule l'icône change de côté,
-- pour rester contre le bord de l'écran.
local function PoseLigne(fs, icone, chiffres, nom)
	if ns.db.cote == "droite" then
		fs:SetFormattedText("%s  %s |T%s:16|t", nom, chiffres, icone)
	else
		fs:SetFormattedText("|T%s:16|t %s  %s", icone, chiffres, nom)
	end
	fs:Show()
end

-- Replié, le panneau garde son titre et le résumé de session : la vue est
-- dégagée sans qu'on devienne aveugle à ce qu'on ramasse.
local function Vider(lignes, zones, n)
	for i = 1, n do
		lignes[i]:Hide()
		zones[i]:Hide()
	end
end

local function Refresh()
	if not panel or not panel:IsShown() then return end

	panel.resume:SetText(ns.SessionResume() or L.RIEN_SESSION)

	if ns.db.replie then
		Vider(panel.lignes, panel.zones, MAX_LIGNES)
		return
	end

	-- lignes par objet, triées par récolte de session
	local tri = {}
	for id, n in pairs(session) do
		tri[#tri + 1] = { id = id, n = n }
	end
	table.sort(tri, function(a, b) return a.n > b.n end)

	for i = 1, MAX_LIGNES do
		local fs, item, zone = panel.lignes[i], tri[i], panel.zones[i]
		zone.id = item and item.id or nil
		zone:SetShown(item ~= nil)
		if item then
			local rec = MoissonDB.objets[item.id]
			local icone = rec and rec.icone or 134400
			local nom = (rec and rec.nom) or GetItemInfo(item.id) or L.OBJET_INCONNU:format(item.id)
			-- « en sac » vient des sacs réels : les stacks d'avant l'addon
			-- comptent aussi (le total, lui, ne cumule que ce qu'on a vu passer)
			local sac = GetItemCount and GetItemCount(item.id) or 0
			PoseLigne(fs, icone, string.format("|cffffd200%d|r |cff7fbf3f· %d|r%s",
				item.n, sac, ns.ColonneCompte(item.id, sac)), nom)
		else
			fs:Hide()
		end
	end
end

-- Troisième colonne : ce que le compte entier possède de cet objet. On la tait
-- quand elle répète la deuxième (rien ailleurs que dans les sacs d'ici).
function ns.ColonneCompte(id, sac)
	if not ns.db.stockcompte or not ns.StockDe then return "" end
	local total = ns.StockDe(id)
	if total <= (sac or 0) then return "" end
	return string.format(" |cff6a9fd8· %d|r", total)
end

local function RefreshBesace()
	if not panel or not panel:IsShown() then return end

	if ns.db.replie then
		panel.sacTitre:Hide()
		Vider(panel.sacLignes, panel.sacZones, MAX_SACS)
		return
	end

	local voulu = CatsBesace()
	if not voulu then
		-- pas de métier de récolte connu : le volet se tait
		panel.sacTitre:Hide()
		Vider(panel.sacLignes, panel.sacZones, MAX_SACS)
		return
	end
	panel.sacTitre:Show()

	local totaux = ScanBesace(voulu)
	local tri = {}
	for id, t in pairs(totaux) do
		tri[#tri + 1] = { id = id, n = t.n, icone = t.icone }
	end
	table.sort(tri, function(a, b) return a.n > b.n end)

	for i = 1, MAX_SACS do
		local fs, item, zone = panel.sacLignes[i], tri[i], panel.sacZones[i]
		zone.id = item and item.id or nil
		zone:SetShown(item ~= nil)
		if item then
			local nom = GetItemInfo(item.id) or L.OBJET_INCONNU:format(item.id)
			PoseLigne(fs, item.icone, string.format("|cffffd200%d|r%s",
				item.n, ns.ColonneCompte(item.id, item.n)), nom)
		else
			fs:Hide()
		end
	end
end

-- ----------------------------------------------------------------- comptage --

local function OnLoot(msg)
	if not isSelfLoot(msg) then
		dbg(L.J_IGNORE .. msg)
		return
	end
	local link = msg:match("|Hitem:.-|h.-|h")
	if not link then
		dbg(L.J_SANS_LIEN .. msg)
		return
	end
	local id = tonumber(link:match("item:(%d+)"))
	if not id then
		dbg(L.J_SANS_ID .. msg)
		return
	end

	local _, _, _, _, icone, classID, subClassID = GetItemInfoInstant(id)
	local cat = Categorie(id, classID, subClassID)
	if not cat then
		dbg(L.J_NON_SUIVIE:format(link, tostring(classID), tostring(subClassID)))
		return
	end

	local qte = tonumber(msg:match("|h|rx(%d+)")) or tonumber(msg:match("x(%d+)%p?$")) or 1

	local rec = MoissonDB.objets[id]
	if not rec then
		rec = { total = 0, cat = cat }
		MoissonDB.objets[id] = rec
	end
	rec.total = rec.total + qte
	rec.icone = icone
	rec.nom = rec.nom or GetItemInfo(id) -- en cache : on vient de le ramasser
	MoissonDB.cats[cat] = (MoissonDB.cats[cat] or 0) + qte

	session[id] = (session[id] or 0) + qte
	sessionCats[cat] = (sessionCats[cat] or 0) + qte
	dbg(L.J_COMPTE:format(link, qte, CATS[cat].nom,
		tostring(classID), tostring(subClassID)))

	Refresh()
end

-- --------------------------------------------------------------- API interne --

function ns.CompteursOnShow()
	if not panel then BuildPanel() end
	panel:SetShown(ns.db.compteurs)
	Refresh()
	RefreshBesace()
end

function ns.CompteursOnHide()
	if panel then panel:Hide() end
end

-- appelé par stocks.lua après chaque relevé (sacs, banque, courrier, import)
function ns.StocksChanges()
	Refresh()
	RefreshBesace()
	if ns.FenetreRefresh then ns.FenetreRefresh() end
end

function ns.Bilan()
	ns.print(L.BILAN_TITRE)
	local stocks, lieux = ns.StockParCategorie and ns.StockParCategorie()
	local rien = true
	for _, cat in ipairs(ORDRE_CATS) do
		local s, g = sessionCats[cat] or 0, MoissonDB.cats[cat] or 0
		local e = stocks and stocks[cat] or 0
		if s > 0 or g > 0 or e > 0 then
			rien = false
			ns.print(string.format("  |T%s:14|t %s : %d · %d · |cff6a9fd8%d|r",
				CATS[cat].icone, CATS[cat].nom, s, g, e))
		end
	end
	if rien then
		ns.print(L.BILAN_VIDE)
		return
	end
	if lieux then
		ns.print(L.BILAN_LIEUX:format(lieux.sacs, lieux.banque, lieux.malle))
		ns.print(L.BILAN_PORTEE:format(ns.db.portee == "tout"
			and L.PORTEE_TOUT or L.PORTEE_ROYAUME))
	end
end

function ns.Raz(tout)
	wipe(session)
	wipe(sessionCats)
	if tout then
		wipe(MoissonDB.objets)
		wipe(MoissonDB.cats)
		ns.print(L.RAZ_TOUT)
	else
		ns.print(L.RAZ_SESSION)
	end
	Refresh()
end

local nbEvents = 0 -- messages CHAT_MSG_LOOT reçus, avant tout filtrage

-- /moisson test : injecte de faux butins (formés avec les globales du client,
-- donc la détection de préfixe est exercée pour de vrai) puis retire les
-- comptes fictifs. Diagnostique toute la chaîne sans quitter la capitale.
function ns.TestCompteurs()
	ns.print(L.TEST_ENTETE:format(nbEvents))
	local lien = "|cffffffff|Hitem:2447::::::::20:::::::|h[Pacifique]|h|r"
	local avant = session[2447] or 0
	OnLoot(LOOT_ITEM_SELF:format(lien))
	OnLoot(LOOT_ITEM_SELF_MULTIPLE:format(lien, 3))
	local delta = (session[2447] or 0) - avant
	if delta == 4 then
		ns.print(L.TEST_OK)
	else
		ns.print(L.TEST_KO:format(delta))
	end
	if delta > 0 then
		session[2447] = avant > 0 and avant or nil
		sessionCats.herbes = (sessionCats.herbes or 0) - delta
		if sessionCats.herbes <= 0 then sessionCats.herbes = nil end
		local rec = MoissonDB.objets[2447]
		if rec then
			rec.total = rec.total - delta
			if rec.total <= 0 then MoissonDB.objets[2447] = nil end
		end
		MoissonDB.cats.herbes = (MoissonDB.cats.herbes or 0) - delta
		if MoissonDB.cats.herbes <= 0 then MoissonDB.cats.herbes = nil end
		Refresh()
	end
end

function ns.InitCompteurs()
	MoissonDB.objets = MoissonDB.objets or {}
	MoissonDB.cats = MoissonDB.cats or {}
	MoissonDB.journal = MoissonDB.journal or {}
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("CHAT_MSG_LOOT")
	ev:RegisterEvent("BAG_UPDATE_DELAYED")
	ev:SetScript("OnEvent", function(_, event, msg)
		if event == "BAG_UPDATE_DELAYED" then
			Refresh() -- la colonne « en sac » suit aussi ventes et dépôts
			RefreshBesace()
			return
		end
		nbEvents = nbEvents + 1
		-- toute erreur remonte en chat ET au journal : rien ne doit s'avaler
		local ok, err = pcall(OnLoot, msg)
		if not ok then
			journal(L.J_ERREUR .. tostring(err))
			ns.print(L.ERREUR_COMPTEUR .. tostring(err))
		end
	end)
end

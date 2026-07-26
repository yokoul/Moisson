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

-- catégories de farm. Le tri fiable vient des listes d'itemIDs (donnees.lua) :
-- la DB2 d'Era classe presque tout en 7/0 générique. Les sous-classes
-- modernes restent en repli, et toute marchandise inconnue part en « autres ».
local CATS = {
	herbes   = { nom = L.CAT_HERBES,   icone = "Interface\\Icons\\Trade_Herbalism" },
	minerais = { nom = L.CAT_MINERAIS, icone = "Interface\\Icons\\Trade_Mining" },
	gemmes   = { nom = L.CAT_GEMMES,   icone = "Interface\\Icons\\INV_Misc_Gem_01" },
	cuirs    = { nom = L.CAT_CUIRS,    icone = "Interface\\Icons\\INV_Misc_LeatherScrap_02" },
	tissus   = { nom = L.CAT_TISSUS,   icone = "Interface\\Icons\\INV_Fabric_Linen_01" },
	viandes  = { nom = L.CAT_VIANDES,  icone = "Interface\\Icons\\INV_Misc_Food_14" },
	elems    = { nom = L.CAT_ELEMS,    icone = "Interface\\Icons\\INV_Stone_05" },
	autres   = { nom = L.CAT_AUTRES,   icone = "Interface\\Icons\\INV_Misc_Bag_08" },
}
local ORDRE_CATS = { "herbes", "minerais", "gemmes", "cuirs", "tissus", "viandes", "elems", "autres" }
local SUB7 = { [9] = "herbes", [7] = "minerais", [6] = "cuirs", [5] = "tissus",
	[8] = "viandes", [10] = "elems" }

local function Categorie(id, classID, subClassID)
	local fam = ns.FAMILLES and ns.FAMILLES[id]
	if fam then return fam end
	if classID == 7 then return SUB7[subClassID] or "autres" end
	if classID == 3 then return "gemmes" end
end

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
	for sac = 0, 4 do
		local slots = (C_Container and C_Container.GetContainerNumSlots(sac))
			or (GetContainerNumSlots and GetContainerNumSlots(sac)) or 0
		for slot = 1, slots do
			local id, n
			if C_Container and C_Container.GetContainerItemInfo then
				local info = C_Container.GetContainerItemInfo(sac, slot)
				if info then id, n = info.itemID, info.stackCount end
			elseif GetContainerItemInfo then
				local _, count, _, _, _, _, _, _, _, itemID = GetContainerItemInfo(sac, slot)
				id, n = itemID, count
			end
			if id then
				local _, _, _, _, icone, classID, subClassID = GetItemInfoInstant(id)
				local cat = Categorie(id, classID, subClassID)
				if cat and voulu[cat] then
					local t = totaux[id]
					if not t then
						t = { n = 0, icone = icone, cat = cat }
						totaux[id] = t
					end
					t.n = t.n + (n or 1)
				end
			end
		end
	end
	return totaux
end

-- ------------------------------------------------------------------ panneau --

local panel  -- construit paresseusement (a besoin de ns.hud)

local function BuildPanel()
	panel = CreateFrame("Frame", "MoissonCompteurs", ns.hud)
	panel:SetSize(260, 20 + MAX_LIGNES * 18 + 30 + MAX_SACS * 18)
	panel:SetPoint("LEFT", ns.hud, "LEFT", 24, 0)

	panel.titre = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	panel.titre:SetPoint("TOPLEFT")
	panel.titre:SetText(L.TITRE_RECOLTE)

	panel.resume = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	panel.resume:SetPoint("TOPLEFT", panel.titre, "BOTTOMLEFT", 0, -4)
	panel.resume:SetJustifyH("LEFT")

	panel.lignes = {}
	local prev = panel.resume
	for i = 1, MAX_LIGNES do
		local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -6 or -4)
		fs:SetJustifyH("LEFT")
		panel.lignes[i] = fs
		prev = fs
	end

	panel.sacTitre = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	panel.sacTitre:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, -12)
	panel.sacTitre:SetText(L.TITRE_BESACE)

	panel.sacLignes = {}
	prev = panel.sacTitre
	for i = 1, MAX_SACS do
		local fs = panel:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		fs:SetPoint("TOPLEFT", prev, "BOTTOMLEFT", 0, i == 1 and -6 or -4)
		fs:SetJustifyH("LEFT")
		panel.sacLignes[i] = fs
		prev = fs
	end
	panel:Hide()
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

local function Refresh()
	if not panel or not panel:IsShown() then return end

	panel.resume:SetText(ns.SessionResume() or L.RIEN_SESSION)

	-- lignes par objet, triées par récolte de session
	local tri = {}
	for id, n in pairs(session) do
		tri[#tri + 1] = { id = id, n = n }
	end
	table.sort(tri, function(a, b) return a.n > b.n end)

	for i = 1, MAX_LIGNES do
		local fs, item = panel.lignes[i], tri[i]
		if item then
			local rec = MoissonDB.objets[item.id]
			local icone = rec and rec.icone or 134400
			local nom = (rec and rec.nom) or GetItemInfo(item.id) or L.OBJET_INCONNU:format(item.id)
			-- « en sac » vient des sacs réels : les stacks d'avant l'addon
			-- comptent aussi (le total, lui, ne cumule que ce qu'on a vu passer)
			local sac = GetItemCount and GetItemCount(item.id) or 0
			fs:SetFormattedText("|T%s:16|t |cffffd200%d|r |cff7fbf3f· %d|r  %s",
				icone, item.n, sac, nom)
			fs:Show()
		else
			fs:Hide()
		end
	end
end

local function RefreshBesace()
	if not panel or not panel:IsShown() then return end

	local voulu = CatsBesace()
	if not voulu then
		-- pas de métier de récolte connu : le volet se tait
		panel.sacTitre:Hide()
		for i = 1, MAX_SACS do panel.sacLignes[i]:Hide() end
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
		local fs, item = panel.sacLignes[i], tri[i]
		if item then
			local nom = GetItemInfo(item.id) or L.OBJET_INCONNU:format(item.id)
			fs:SetFormattedText("|T%s:16|t |cffffd200%d|r  %s", item.icone, item.n, nom)
			fs:Show()
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

function ns.Bilan()
	ns.print(L.BILAN_TITRE)
	local rien = true
	for _, cat in ipairs(ORDRE_CATS) do
		local s, g = sessionCats[cat] or 0, MoissonDB.cats[cat] or 0
		if s > 0 or g > 0 then
			rien = false
			ns.print(string.format("  |T%s:14|t %s : %d · %d",
				CATS[cat].icone, CATS[cat].nom, s, g))
		end
	end
	if rien then ns.print(L.BILAN_VIDE) end
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

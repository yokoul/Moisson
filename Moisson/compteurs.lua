-- Moisson — compteurs de récolte (le différenciateur maison).
-- On écoute les messages de butin personnels, on ne retient que les
-- marchandises de farm (classID 7) et on cumule par objet : session + global.

local ADDON, ns = ...

-- sous-classes de « Trade Goods » en Classic Era
local CATS = {
	[9]  = { nom = "Herbes",        icone = "Interface\\Icons\\Trade_Herbalism" },
	[7]  = { nom = "Minerais",      icone = "Interface\\Icons\\Trade_Mining" },
	[6]  = { nom = "Cuirs",         icone = "Interface\\Icons\\INV_Misc_LeatherScrap_02" },
	[5]  = { nom = "Tissus",        icone = "Interface\\Icons\\INV_Fabric_Linen_01" },
	[8]  = { nom = "Viandes",       icone = "Interface\\Icons\\INV_Misc_Food_14" },
	[10] = { nom = "Élémentaires",  icone = "Interface\\Icons\\INV_Stone_05" },
}
local ORDRE_CATS = { 9, 7, 6, 5, 8, 10 }

local session = {}      -- [itemID] = quantité depuis la connexion
local sessionCats = {}  -- [subClassID] = quantité
local MAX_LIGNES = 10

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

-- ------------------------------------------------------------------ panneau --

local panel  -- construit paresseusement (a besoin de ns.hud)

local function BuildPanel()
	panel = CreateFrame("Frame", "MoissonCompteurs", ns.hud)
	panel:SetSize(240, 20 + MAX_LIGNES * 18)
	panel:SetPoint("LEFT", ns.hud, "LEFT", 24, 0)

	panel.titre = panel:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	panel.titre:SetPoint("TOPLEFT")
	panel.titre:SetText("|cff7fbf3fRécolte|r  |cff808080session · total|r")

	-- la rangée de mini-boutons du HUD vit au-dessus du panneau, pas au
	-- milieu de la vue
	if ns.boutonsRow then
		ns.boutonsRow:ClearAllPoints()
		ns.boutonsRow:SetPoint("BOTTOMLEFT", panel, "TOPLEFT", 44, 10)
	end

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
	panel:Hide()
end

-- résumé de session par catégorie (partagé avec le tooltip du bouton minimap)
function ns.SessionResume()
	local resume = {}
	for _, sub in ipairs(ORDRE_CATS) do
		local n = sessionCats[sub]
		if n and n > 0 then
			resume[#resume + 1] = "|T" .. CATS[sub].icone .. ":14|t " .. n
		end
	end
	if #resume > 0 then return table.concat(resume, "   ") end
end

local function Refresh()
	if not panel or not panel:IsShown() then return end

	panel.resume:SetText(ns.SessionResume() or "|cff808080rien cette session|r")

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
			local nom = (rec and rec.nom) or GetItemInfo(item.id) or ("objet " .. item.id)
			local total = rec and rec.total or item.n
			fs:SetFormattedText("|T%s:16|t |cffffd200%d|r |cff808080· %d|r  %s",
				icone, item.n, total, nom)
			fs:Show()
		else
			fs:Hide()
		end
	end
end

-- ----------------------------------------------------------------- comptage --

local function OnLoot(msg)
	if not isSelfLoot(msg) then return end
	local link = msg:match("|Hitem:.-|h.-|h")
	if not link then return end
	local id = tonumber(link:match("item:(%d+)"))
	if not id then return end

	local _, _, _, _, icone, classID, subClassID = GetItemInfoInstant(id)
	if classID ~= 7 or not CATS[subClassID] then return end

	local qte = tonumber(msg:match("|h|rx(%d+)")) or tonumber(msg:match("x(%d+)%p?$")) or 1

	local rec = MoissonDB.objets[id]
	if not rec then
		rec = { total = 0, cat = subClassID }
		MoissonDB.objets[id] = rec
	end
	rec.total = rec.total + qte
	rec.icone = icone
	rec.nom = rec.nom or GetItemInfo(id) -- en cache : on vient de le ramasser
	MoissonDB.cats[subClassID] = (MoissonDB.cats[subClassID] or 0) + qte

	session[id] = (session[id] or 0) + qte
	sessionCats[subClassID] = (sessionCats[subClassID] or 0) + qte

	Refresh()
end

-- --------------------------------------------------------------- API interne --

function ns.CompteursOnShow()
	if not panel then BuildPanel() end
	panel:SetShown(ns.db.compteurs)
	Refresh()
end

function ns.CompteursOnHide()
	if panel then panel:Hide() end
end

function ns.Bilan()
	ns.print("bilan de récolte (session · total) :")
	local rien = true
	for _, sub in ipairs(ORDRE_CATS) do
		local s, g = sessionCats[sub] or 0, MoissonDB.cats[sub] or 0
		if s > 0 or g > 0 then
			rien = false
			ns.print(string.format("  |T%s:14|t %s : %d · %d",
				CATS[sub].icone, CATS[sub].nom, s, g))
		end
	end
	if rien then ns.print("  rien pour l'instant — va cueillir !") end
end

function ns.Raz(tout)
	wipe(session)
	wipe(sessionCats)
	if tout then
		wipe(MoissonDB.objets)
		wipe(MoissonDB.cats)
		ns.print("compteurs globaux et session remis à zéro.")
	else
		ns.print("compteurs de session remis à zéro.")
	end
	Refresh()
end

function ns.InitCompteurs()
	MoissonDB.objets = MoissonDB.objets or {}
	MoissonDB.cats = MoissonDB.cats or {}
	local ev = CreateFrame("Frame")
	ev:RegisterEvent("CHAT_MSG_LOOT")
	ev:SetScript("OnEvent", function(_, _, msg)
		OnLoot(msg)
	end)
end

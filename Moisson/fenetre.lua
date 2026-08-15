-- Moisson — fenêtre des stocks (/moisson stocks) et boîtes d'échange entre
-- comptes. Une ligne par objet, dépliable sur le détail par personnage et par
-- lieu. Les SavedVariables ne franchissant pas la frontière d'un compte WoW,
-- l'export/import se fait par copier-coller.

local ADDON, ns = ...
local L = ns.L

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo

local NB_LIGNES = 15
local H_LIGNE = 18
local LARGEUR = 460

local cadre, scroll, lignes, entete, pied
local vue = {}          -- lignes à plat : objets et, si dépliés, leurs détenteurs
local deplies = {}      -- [itemID] = true
local filtre            -- catégorie affichée, nil = toutes

-- ------------------------------------------------------------------ données --

local function NomObjet(id)
	return GetItemInfo(id) or L.OBJET_INCONNU:format(id)
end

-- Reconstruit la liste à plat : objets triés par catégorie puis par abondance,
-- chacun suivi de ses détenteurs quand il est déplié.
local function Construire()
	wipe(vue)
	local cats, lieux, objets = ns.StockParCategorie()

	local rang = {}
	for i, cat in ipairs(ns.ORDRE_CATS) do rang[cat] = i end

	local tri = {}
	for id, n in pairs(objets) do
		local cat, icone = ns.CategorieDe(id)
		cat = cat or "autres"
		if not filtre or cat == filtre then
			tri[#tri + 1] = { id = id, n = n, cat = cat, icone = icone }
		end
	end
	table.sort(tri, function(a, b)
		if a.cat ~= b.cat then return (rang[a.cat] or 99) < (rang[b.cat] or 99) end
		if a.n ~= b.n then return a.n > b.n end
		return a.id < b.id
	end)

	for _, o in ipairs(tri) do
		vue[#vue + 1] = { objet = o }
		if deplies[o.id] then
			local _, detail = ns.StockDe(o.id)
			for _, d in ipairs(detail) do
				vue[#vue + 1] = { detail = d, id = o.id }
			end
		end
	end
	return cats, lieux
end

-- ------------------------------------------------------------------ lignes --

local function PeintObjet(ligne, o)
	local fleche = deplies[o.id] and "|cff808080-|r " or "|cff808080+|r "
	ligne.gauche:SetFormattedText("%s|T%s:14|t %s", fleche, o.icone or 134400,
		NomObjet(o.id))
	ligne.droite:SetFormattedText("|cffffd200%d|r", o.n)
	ligne.id, ligne.detail = o.id, nil
end

local function PeintDetail(ligne, d)
	local qui, ou = ns.DecrisDetenteur(d)
	ligne.gauche:SetFormattedText("      %s |cff808080%s|r", qui, ou)
	ligne.droite:SetFormattedText("|cff6a9fd8%d|r", d.total)
	ligne.id, ligne.detail = nil, d
end

local function Rafraichir()
	if not cadre or not cadre:IsShown() then return end
	local cats, lieux = Construire()

	FauxScrollFrame_Update(scroll, #vue, NB_LIGNES, H_LIGNE)
	local offset = FauxScrollFrame_GetOffset(scroll)

	for i = 1, NB_LIGNES do
		local ligne, entree = lignes[i], vue[i + offset]
		if entree then
			if entree.objet then
				PeintObjet(ligne, entree.objet)
			else
				PeintDetail(ligne, entree.detail)
			end
			ligne:Show()
		elseif i == 1 then
			-- ni stock ni filtre qui donne quelque chose : le dire plutôt que
			-- laisser une fenêtre vide qui a l'air cassée
			ligne.gauche:SetText("|cff808080" .. L.STOCKS_VIDE .. "|r")
			ligne.droite:SetText("")
			ligne.id, ligne.detail = nil, nil
			ligne:Show()
		else
			ligne:Hide()
		end
	end

	local total = 0
	for _, n in pairs(cats) do total = total + n end
	entete:SetFormattedText(L.STOCKS_ENTETE, total, lieux.sacs, lieux.banque,
		lieux.malle)
	pied:SetFormattedText(L.STOCKS_PIED, #ns.Personnages())
end
ns.FenetreRefresh = Rafraichir

-- ------------------------------------------------------------- construction --

local function OnLigneClick(self, bouton)
	if self.id then
		deplies[self.id] = not deplies[self.id] or nil
		Rafraichir()
	elseif self.detail and bouton == "RightButton" then
		local d = self.detail
		if ns.EstMoi(d.compte, d.royaume, d.perso) then
			ns.print(L.OUBLI_SOI)
			return
		end
		local popup = StaticPopup_Show("MOISSON_OUBLI", d.perso)
		if popup then popup.data = d end
	end
end

local function OnLigneEnter(self)
	if self.id then
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		ns.TooltipStock(GameTooltip, self.id)
	elseif self.detail then
		local d = self.detail
		GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
		GameTooltip:SetText(d.perso)
		GameTooltip:AddLine(L.TIP_COMPTE:format(ns.NomCompte(d.compte), d.royaume),
			0.7, 0.7, 0.7)
		-- banque et courrier datent du dernier passage : le dire évite de
		-- prendre un vieux relevé pour la réalité d'aujourd'hui
		if d.banque > 0 and d.banquemaj then
			GameTooltip:AddLine(L.TIP_MAJ_BANQUE:format(date("%d/%m %H:%M", d.banquemaj)),
				0.7, 0.7, 0.7)
		end
		if d.malle > 0 and d.mallemaj then
			GameTooltip:AddLine(L.TIP_MAJ_MALLE:format(date("%d/%m %H:%M", d.mallemaj)),
				0.7, 0.7, 0.7)
		end
		if d.maj and d.maj > 0 then
			GameTooltip:AddLine(L.TIP_MAJ:format(date("%d/%m %H:%M", d.maj)),
				0.7, 0.7, 0.7)
		end
		if not ns.EstMoi(d.compte, d.royaume, d.perso) then
			GameTooltip:AddLine(L.TIP_OUBLI, 0.7, 0.7, 0.7)
		end
		GameTooltip:Show()
	end
end

local function BoutonFiltre(parent, cat, x)
	local b = CreateFrame("Button", nil, parent)
	b:SetSize(20, 20)
	b:SetPoint("TOPLEFT", x, -28)
	local t = b:CreateTexture(nil, "ARTWORK")
	t:SetAllPoints()
	t:SetTexture(cat and ns.CATS[cat].icone or "Interface\\Icons\\INV_Misc_Rune_01")
	t:SetTexCoord(0.08, 0.92, 0.08, 0.92)
	b.texture = t
	b:SetScript("OnClick", function()
		filtre = cat
		Rafraichir()
		if parent.MajFiltres then parent.MajFiltres() end
	end)
	b:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_BOTTOM")
		GameTooltip:SetText(cat and ns.CATS[cat].nom or L.FILTRE_TOUT)
		GameTooltip:Show()
	end)
	b:SetScript("OnLeave", function() GameTooltip:Hide() end)
	b.cat = cat
	return b
end

local function Construire_()
	cadre = CreateFrame("Frame", "MoissonStocks", UIParent,
		BackdropTemplateMixin and "BasicFrameTemplateWithInset" or "BasicFrameTemplate")
	cadre:SetSize(LARGEUR, 100 + NB_LIGNES * H_LIGNE)
	cadre:SetPoint("CENTER")
	cadre:SetFrameStrata("HIGH")
	cadre:SetMovable(true)
	cadre:EnableMouse(true)
	cadre:RegisterForDrag("LeftButton")
	cadre:SetScript("OnDragStart", cadre.StartMoving)
	cadre:SetScript("OnDragStop", cadre.StopMovingOrSizing)
	cadre:Hide()
	tinsert(UISpecialFrames, "MoissonStocks") -- Échap referme

	local titre = cadre:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	titre:SetPoint("TOP", 0, -6)
	titre:SetText(L.STOCKS_TITRE)

	-- filtres par catégorie : « tout », puis une icône par famille
	local filtres = { BoutonFiltre(cadre, nil, 12) }
	for i, cat in ipairs(ns.ORDRE_CATS) do
		filtres[#filtres + 1] = BoutonFiltre(cadre, cat, 12 + i * 24)
	end
	function cadre.MajFiltres()
		for _, b in ipairs(filtres) do
			b.texture:SetDesaturated(filtre ~= b.cat)
			b.texture:SetAlpha(filtre == b.cat and 1 or 0.6)
		end
	end

	-- bascule de portée : ce royaume ou tout ce que la base connaît
	local portee = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
	portee:SetSize(110, 20)
	portee:SetPoint("TOPRIGHT", -10, -28)
	local function MajPortee()
		portee:SetText(ns.db.portee == "tout" and L.PORTEE_TOUT or L.PORTEE_ROYAUME)
	end
	portee:SetScript("OnClick", function()
		ns.db.portee = (ns.db.portee == "tout") and "royaume" or "tout"
		MajPortee()
		Rafraichir()
	end)
	MajPortee()
	ns.FenetrePortee = MajPortee -- le panneau d'options bascule la même portée

	entete = cadre:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	entete:SetPoint("TOPLEFT", 14, -54)
	entete:SetJustifyH("LEFT")

	scroll = CreateFrame("ScrollFrame", "MoissonStocksScroll", cadre,
		"FauxScrollFrameTemplate")
	scroll:SetPoint("TOPLEFT", 10, -70)
	scroll:SetSize(LARGEUR - 46, NB_LIGNES * H_LIGNE)
	scroll:SetScript("OnVerticalScroll", function(self, offset)
		FauxScrollFrame_OnVerticalScroll(self, offset, H_LIGNE, Rafraichir)
	end)
	-- FauxScrollFrame ne branche pas la molette lui-même
	scroll:EnableMouseWheel(true)
	scroll:SetScript("OnMouseWheel", function(self, delta)
		local barre = _G[self:GetName() .. "ScrollBar"]
		if barre then barre:SetValue(barre:GetValue() - delta * H_LIGNE * 3) end
	end)

	lignes = {}
	for i = 1, NB_LIGNES do
		local b = CreateFrame("Button", nil, cadre)
		b:SetSize(LARGEUR - 44, H_LIGNE)
		b:SetPoint("TOPLEFT", scroll, "TOPLEFT", 0, -(i - 1) * H_LIGNE)
		b:RegisterForClicks("LeftButtonUp", "RightButtonUp")
		b:SetHighlightTexture("Interface\\QuestFrame\\UI-QuestTitleHighlight",
			"ADD")

		b.gauche = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		b.gauche:SetPoint("LEFT", 2, 0)
		b.gauche:SetJustifyH("LEFT")
		b.droite = b:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
		b.droite:SetPoint("RIGHT", -4, 0)
		b.droite:SetJustifyH("RIGHT")
		-- le nom s'arrête avant le total, jamais dessous
		b.gauche:SetPoint("RIGHT", b.droite, "LEFT", -8, 0)
		b.gauche:SetWordWrap(false)

		b:SetScript("OnClick", OnLigneClick)
		b:SetScript("OnEnter", OnLigneEnter)
		b:SetScript("OnLeave", function() GameTooltip:Hide() end)
		lignes[i] = b
	end

	pied = cadre:CreateFontString(nil, "ARTWORK", "GameFontDisableSmall")
	pied:SetPoint("BOTTOMLEFT", 14, 32)

	local export = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
	export:SetSize(100, 22)
	export:SetPoint("BOTTOMLEFT", 12, 8)
	export:SetText(L.BTN_EXPORT)
	export:SetScript("OnClick", function() ns.OuvrirEchange("export") end)

	local import = CreateFrame("Button", nil, cadre, "UIPanelButtonTemplate")
	import:SetSize(100, 22)
	import:SetPoint("LEFT", export, "RIGHT", 6, 0)
	import:SetText(L.BTN_IMPORT)
	import:SetScript("OnClick", function() ns.OuvrirEchange("import") end)

	cadre.MajFiltres()
	cadre.MajPortee = MajPortee
end

function ns.OuvrirStocks(force)
	if not cadre then Construire_() end
	if force == nil then force = not cadre:IsShown() end
	cadre:SetShown(force)
	if force then
		cadre.MajPortee()
		Rafraichir()
	end
end

-- ---------------------------------------------------- échange entre comptes --

local echange

local function ConstruireEchange()
	echange = CreateFrame("Frame", "MoissonEchange", UIParent,
		BackdropTemplateMixin and "BasicFrameTemplateWithInset" or "BasicFrameTemplate")
	echange:SetSize(500, 300)
	echange:SetPoint("CENTER")
	echange:SetFrameStrata("DIALOG")
	echange:SetMovable(true)
	echange:EnableMouse(true)
	echange:RegisterForDrag("LeftButton")
	echange:SetScript("OnDragStart", echange.StartMoving)
	echange:SetScript("OnDragStop", echange.StopMovingOrSizing)
	echange:Hide()
	tinsert(UISpecialFrames, "MoissonEchange")

	echange.titre = echange:CreateFontString(nil, "ARTWORK", "GameFontNormal")
	echange.titre:SetPoint("TOP", 0, -6)

	echange.aide = echange:CreateFontString(nil, "ARTWORK", "GameFontHighlightSmall")
	echange.aide:SetPoint("TOPLEFT", 14, -28)
	echange.aide:SetPoint("TOPRIGHT", -14, -28)
	echange.aide:SetJustifyH("LEFT")

	local sf = CreateFrame("ScrollFrame", "MoissonEchangeScroll", echange,
		"UIPanelScrollFrameTemplate")
	sf:SetPoint("TOPLEFT", 14, -56)
	sf:SetPoint("BOTTOMRIGHT", -34, 40)

	local eb = CreateFrame("EditBox", nil, sf)
	eb:SetMultiLine(true)
	eb:SetMaxLetters(0)
	eb:SetFontObject(ChatFontNormal)
	eb:SetWidth(430)
	eb:SetAutoFocus(false)
	eb:SetScript("OnEscapePressed", function() echange:Hide() end)
	sf:SetScrollChild(eb)
	echange.edit = eb

	echange.action = CreateFrame("Button", nil, echange, "UIPanelButtonTemplate")
	echange.action:SetSize(140, 22)
	echange.action:SetPoint("BOTTOM", 0, 10)
end

function ns.OuvrirEchange(mode)
	if not echange then ConstruireEchange() end
	local eb = echange.edit

	if mode == "export" then
		echange.titre:SetText(L.ECHANGE_TITRE_EXPORT)
		echange.aide:SetText(L.ECHANGE_AIDE_EXPORT)
		local texte = ns.Exporter()
		eb:SetText(texte)
		eb:HighlightText()
		eb:SetFocus()
		-- la chaîne ne doit pas être modifiable : toute retouche la corromprait
		eb:SetScript("OnTextChanged", function(self, parUser)
			if parUser then self:SetText(texte); self:HighlightText() end
		end)
		echange.action:SetText(L.BTN_TOUT_SELECT)
		echange.action:SetScript("OnClick", function()
			eb:HighlightText()
			eb:SetFocus()
		end)
	else
		echange.titre:SetText(L.ECHANGE_TITRE_IMPORT)
		echange.aide:SetText(L.ECHANGE_AIDE_IMPORT)
		eb:SetScript("OnTextChanged", nil)
		eb:SetText("")
		eb:SetFocus()
		echange.action:SetText(L.BTN_IMPORTER)
		echange.action:SetScript("OnClick", function()
			local n, source, err = ns.Importer(eb:GetText())
			if err then
				ns.print("|cffff4040" .. err .. "|r")
				return
			end
			ns.print(L.IMPORT_OK:format(n, source))
			echange:Hide()
			Rafraichir()
		end)
	end
	echange:Show()
end

-- ------------------------------------------------------------------- oubli --

StaticPopupDialogs["MOISSON_OUBLI"] = {
	text = L.OUBLI_CONFIRME,
	button1 = YES,
	button2 = NO,
	OnAccept = function(self)
		local d = self.data
		if d and ns.OublierFiche(d.compte, d.royaume, d.perso) then
			ns.print(L.OUBLI_FAIT:format(d.perso))
			Rafraichir()
		end
	end,
	timeout = 0,
	whileDead = true,
	hideOnEscape = true,
}

-- Moisson — stocks du compte.
-- « En sac » ne dit rien de ce qui dort en banque, dans la boîte aux lettres
-- ou sur la mule du royaume. On tient donc dans les SavedVariables un relevé
-- par personnage des trois lieux : les sacs suivent en temps réel, la banque
-- et le courrier sont figés au dernier passage (le client n'en sait rien tant
-- qu'on ne les a pas ouverts). Un relevé sait s'exporter en texte pour être
-- recollé sur un autre compte WoW — les SavedVariables ne franchissent pas
-- cette frontière.

local ADDON, ns = ...

local L = ns.L

local GetItemInfo = (C_Item and C_Item.GetItemInfo) or _G.GetItemInfo
local GetItemQualityColor = (C_Item and C_Item.GetItemQualityColor)
	or _G.GetItemQualityColor

local BANQUE    = _G.BANK_CONTAINER or -1
local NB_SACS   = _G.NUM_BAG_SLOTS or 4
local NB_BANQUE = _G.NUM_BANKBAGSLOTS or 6
local MAX_PJ    = _G.ATTACHMENTS_MAX_RECEIVE or 16

-- clé du compte où l'on joue ; les comptes importés portent leur libellé
local ICI = "*"
ns.COMPTE_ICI = ICI

ns.SACS_PORTES = {}
for i = 0, NB_SACS do ns.SACS_PORTES[i + 1] = i end

local SACS_BANQUE = { BANQUE }
for i = NB_SACS + 1, NB_SACS + NB_BANQUE do SACS_BANQUE[#SACS_BANQUE + 1] = i end

ns.LIEUX = { "sacs", "banque", "malle" }

local royaume, moi          -- identité du personnage courant
local banqueOuverte = false
local malleOuverte = false
local enAttente = {}        -- coalescence des rafales d'événements, par relevé

-- ------------------------------------------------------------------ relevés --

local GetContainerNumSlots = (C_Container and C_Container.GetContainerNumSlots)
	or _G.GetContainerNumSlots
local GetContainerItemInfo = (C_Container and C_Container.GetContainerItemInfo)
	or _G.GetContainerItemInfo

-- Relève un jeu de conteneurs et ne garde que les marchandises de récolte.
-- Renvoie [itemID] = quantité (table vide si les conteneurs sont inconnus).
function ns.ScanConteneurs(sacs, dest)
	dest = dest or {}
	for _, sac in ipairs(sacs) do
		local slots = GetContainerNumSlots and GetContainerNumSlots(sac) or 0
		for slot = 1, slots do
			local id, n
			if C_Container and C_Container.GetContainerItemInfo then
				local info = C_Container.GetContainerItemInfo(sac, slot)
				if info then id, n = info.itemID, info.stackCount end
			elseif GetContainerItemInfo then
				local _, count, _, _, _, _, _, _, _, itemID = GetContainerItemInfo(sac, slot)
				id, n = itemID, count
			end
			if id and ns.CategorieDe(id) then
				dest[id] = (dest[id] or 0) + (n or 1)
			end
		end
	end
	return dest
end

-- Pièces jointes de la boîte aux lettres. Seule la boîte ouverte est lisible,
-- et seuls les 50 premiers courriers sont énumérés par le client.
local function ScanMalle()
	local totaux = {}
	if not GetInboxNumItems or not GetInboxItem then return totaux end
	for mail = 1, GetInboxNumItems() do
		for pj = 1, MAX_PJ do
			-- le lien porte l'itemID à coup sûr ; GetInboxItem le rend en
			-- deuxième valeur sur les clients récents seulement
			local id
			local lien = GetInboxItemLink and GetInboxItemLink(mail, pj)
			if lien then id = tonumber(lien:match("item:(%d+)")) end
			local _, brut, _, qte = GetInboxItem(mail, pj)
			id = id or (type(brut) == "number" and brut or nil)
			if id and ns.CategorieDe(id) then
				totaux[id] = (totaux[id] or 0) + (qte or 1)
			end
		end
	end
	return totaux
end

-- --------------------------------------------------------------- écriture DB --

local function Base()
	MoissonDB.persos = MoissonDB.persos or {}
	return MoissonDB.persos
end

-- Fiche d'un personnage ; `creer` la fabrique si elle manque.
function ns.Fiche(compte, roy, nom, creer)
	local base = Base()
	local c = base[compte]
	if not c then
		if not creer then return end
		c = {}
		base[compte] = c
	end
	local r = c[roy]
	if not r then
		if not creer then return end
		r = {}
		c[roy] = r
	end
	local f = r[nom]
	if not f and creer then
		f = { sacs = {}, banque = {}, malle = {} }
		r[nom] = f
	end
	return f
end

local function FicheMoi()
	if not moi then return end
	local f = ns.Fiche(ICI, royaume, moi, true)
	f.classe = f.classe or select(2, UnitClass("player"))
	f.niveau = UnitLevel("player")
	return f
end

-- Un lieu vide est écrit vide, jamais laissé à sa valeur d'avant : c'est ainsi
-- qu'une banque qu'on vient de vider cesse de compter.
local function Poser(lieu, totaux)
	local f = FicheMoi()
	if not f then return end
	f[lieu] = totaux
	f.maj = time()
	f[lieu .. "maj"] = f.maj
	if ns.StocksChanges then ns.StocksChanges() end
end

local function MajSacs()
	Poser("sacs", ns.ScanConteneurs(ns.SACS_PORTES))
end

-- Loin du banquier, GetContainerNumSlots(-1) renvoie 0 : écrire le relevé
-- effacerait ce qu'on sait du dernier passage. On ne se fie donc pas au seul
-- drapeau d'ouverture — on vérifie que les cases répondent encore. Idem pour
-- la boîte aux lettres, que le client oublie dès qu'on s'en éloigne.
local function MajBanque()
	if not banqueOuverte then return end
	if (GetContainerNumSlots and GetContainerNumSlots(BANQUE) or 0) == 0 then return end
	Poser("banque", ns.ScanConteneurs(SACS_BANQUE))
end

local function MajMalle()
	if not malleOuverte then return end
	Poser("malle", ScanMalle())
end

-- Les dépôts en banque déclenchent une rafale d'événements ; on ne relève
-- qu'une fois la poussière retombée.
local function Bientot(fn)
	if enAttente[fn] then return end
	enAttente[fn] = true
	C_Timer.After(0.3, function()
		enAttente[fn] = nil
		fn()
	end)
end

-- Un dépôt suivi d'une fermeture immédiate laisserait un relevé en vol qui
-- s'exécuterait coffre déjà refermé, donc pour rien : on le rattrape.
local function Vider(fn)
	if not enAttente[fn] then return end
	enAttente[fn] = nil
	fn()
end

-- ------------------------------------------------------------- consultation --

-- Portée courante : le royaume où l'on joue (seuls des échanges y sont
-- possibles) ou tout ce que la base connaît.
local function DansLaPortee(roy)
	return ns.db.portee == "tout" or roy == royaume
end

-- Le personnage qu'on incarne : lui seul ne peut pas être oublié.
function ns.EstMoi(compte, roy, nom)
	return compte == ICI and roy == royaume and nom == moi
end

-- Total d'un objet et son détail par personnage, trié du plus fourni au moins
-- fourni. Le personnage courant compte comme les autres : ses sacs sont à jour.
function ns.StockDe(id)
	local total, detail = 0, {}
	for compte, royaumes in pairs(Base()) do
		for roy, persos in pairs(royaumes) do
			if DansLaPortee(roy) then
				for nom, f in pairs(persos) do
					local s = (f.sacs and f.sacs[id]) or 0
					local b = (f.banque and f.banque[id]) or 0
					local m = (f.malle and f.malle[id]) or 0
					local n = s + b + m
					if n > 0 then
						total = total + n
						detail[#detail + 1] = { compte = compte, royaume = roy,
							perso = nom, classe = f.classe, sacs = s, banque = b,
							malle = m, total = n, maj = f.maj,
							-- la banque et le courrier datent du dernier passage :
							-- le tooltip doit pouvoir le dire
							banquemaj = f.banquemaj, mallemaj = f.mallemaj }
					end
				end
			end
		end
	end
	table.sort(detail, function(a, b) return a.total > b.total end)
	return total, detail
end

-- Totaux par catégorie et par lieu, pour le bilan en chat et la fenêtre.
function ns.StockParCategorie()
	local cats, lieux, objets = {}, { sacs = 0, banque = 0, malle = 0 }, {}
	for _, royaumes in pairs(Base()) do
		for roy, persos in pairs(royaumes) do
			if DansLaPortee(roy) then
				for _, f in pairs(persos) do
					for _, lieu in ipairs(ns.LIEUX) do
						for id, n in pairs(f[lieu] or {}) do
							local cat = ns.CategorieDe(id) or "autres"
							cats[cat] = (cats[cat] or 0) + n
							lieux[lieu] = lieux[lieu] + n
							objets[id] = (objets[id] or 0) + n
						end
					end
				end
			end
		end
	end
	return cats, lieux, objets
end

-- Personnages connus, triés (royaume, puis nom) — fenêtre et /moisson oublie.
function ns.Personnages()
	local liste = {}
	for compte, royaumes in pairs(Base()) do
		for roy, persos in pairs(royaumes) do
			for nom, f in pairs(persos) do
				local n = 0
				for _, lieu in ipairs(ns.LIEUX) do
					for _, q in pairs(f[lieu] or {}) do n = n + q end
				end
				liste[#liste + 1] = { compte = compte, royaume = roy, perso = nom,
					classe = f.classe, niveau = f.niveau, maj = f.maj, total = n,
					moi = ns.EstMoi(compte, roy, nom) }
			end
		end
	end
	table.sort(liste, function(a, b)
		if a.royaume ~= b.royaume then return a.royaume < b.royaume end
		return a.perso < b.perso
	end)
	return liste
end

-- Libellé d'un compte : le local porte le nom que l'utilisateur lui a donné.
function ns.NomCompte(compte)
	if compte == ICI then return MoissonDB.compte or L.COMPTE_DEFAUT end
	return compte
end

function ns.CouleurClasse(classe)
	local c = classe and RAID_CLASS_COLORS and RAID_CLASS_COLORS[classe]
	if not c then return "|cffffffff" end
	if c.colorStr then return "|c" .. c.colorStr end
	-- %x exige un entier : les composantes de classe sont des fractions
	return string.format("|cff%02x%02x%02x", math.floor(c.r * 255 + 0.5),
		math.floor(c.g * 255 + 0.5), math.floor(c.b * 255 + 0.5))
end

-- Un détenteur en deux morceaux : qui (coloré par classe, préfixé du compte
-- et suffixé du royaume quand c'est utile) et où (sacs · banque · courrier).
-- Partagé par la fenêtre et le tooltip du HUD : une seule façon de le dire.
function ns.DecrisDetenteur(d)
	local lieux = {}
	if d.sacs > 0 then lieux[#lieux + 1] = L.LIEU_SACS:format(d.sacs) end
	if d.banque > 0 then lieux[#lieux + 1] = L.LIEU_BANQUE:format(d.banque) end
	if d.malle > 0 then lieux[#lieux + 1] = L.LIEU_MALLE:format(d.malle) end

	local qui = ns.CouleurClasse(d.classe) .. d.perso .. "|r"
	if d.compte ~= ICI then
		qui = "|cff8080ff[" .. ns.NomCompte(d.compte) .. "]|r " .. qui
	end
	if ns.db.portee == "tout" then
		qui = qui .. " |cff808080(" .. d.royaume .. ")|r"
	end
	return qui, table.concat(lieux, " · ")
end

-- Répartition d'un objet, en tooltip : la réponse à « j'en ai, mais où ? ».
--
-- Volontairement construit ligne à ligne, sans SetHyperlink : donner un objet
-- au tooltip déclencherait OnTooltipSetItem, où se branchent les addons de
-- prix, d'artisanat et d'enchères. En jeu, notre poignée de chiffres se
-- retrouverait noyée. Ici, personne d'autre ne s'exprime.
local MAX_TIP = 12

function ns.TooltipStock(tip, id)
	local nom, _, qualite = GetItemInfo(id)
	local r, g, b = 1, 1, 1
	if GetItemQualityColor and qualite then r, g, b = GetItemQualityColor(qualite) end

	local total, detail = ns.StockDe(id)
	tip:ClearLines()
	tip:AddDoubleLine(nom or L.OBJET_INCONNU:format(id),
		total > 0 and tostring(total) or "—", r, g, b, 1, 0.82, 0)

	if total == 0 then
		tip:AddLine(L.TIP_AUCUN, 0.6, 0.6, 0.6)
		tip:Show()
		return
	end
	for i, d in ipairs(detail) do
		if i > MAX_TIP then
			tip:AddLine(L.TIP_AUTRES:format(#detail - MAX_TIP), 0.6, 0.6, 0.6)
			break
		end
		local qui, ou = ns.DecrisDetenteur(d)
		tip:AddDoubleLine(qui, ou, 1, 1, 1, 0.8, 0.8, 0.8)
	end
	tip:Show()
end

-- Efface un personnage précis (clic droit dans la fenêtre).
function ns.OublierFiche(compte, roy, nom)
	local base = Base()
	local persos = base[compte] and base[compte][roy]
	if not persos or not persos[nom] then return false end
	persos[nom] = nil
	if not next(persos) then base[compte][roy] = nil end
	if not next(base[compte]) then base[compte] = nil end
	if ns.StocksChanges then ns.StocksChanges() end
	return true
end

-- Efface par nom (slash) ; sans argument, tout sauf le personnage courant.
function ns.Oublier(perso)
	local vise, n = perso and perso:lower(), 0
	for compte, royaumes in pairs(Base()) do
		for roy, persos in pairs(royaumes) do
			for nom in pairs(persos) do
				if not ns.EstMoi(compte, roy, nom)
				and (not vise or nom:lower() == vise) then
					persos[nom] = nil
					n = n + 1
				end
			end
			if not next(persos) then royaumes[roy] = nil end
		end
		if not next(royaumes) then Base()[compte] = nil end
	end
	if ns.StocksChanges then ns.StocksChanges() end
	return n
end

-- ---------------------------------------------------------- export / import --

-- Un enregistrement par personnage, tout sur une ligne :
--   MSN1~compte~royaume~perso~classe~horodatage~s:id=n,…~b:…~m:…
-- Séparateur « ~ » plutôt que « | » : la barre est le caractère d'échappement
-- des codes couleur de WoW et ne survit pas à une EditBox.

local function Serie(t)
	local morceaux = {}
	for id, n in pairs(t or {}) do
		morceaux[#morceaux + 1] = id .. "=" .. n
	end
	table.sort(morceaux)
	return table.concat(morceaux, ",")
end

local function Deserie(s, dest)
	dest = dest or {}
	for id, n in (s or ""):gmatch("(%d+)=(%d+)") do
		dest[tonumber(id)] = tonumber(n)
	end
	return dest
end

function ns.Exporter()
	local enregs = {}
	for compte, royaumes in pairs(Base()) do
		-- on n'exporte que ce compte-ci : ré-exporter les imports ferait
		-- circuler des relevés périmés d'un compte à l'autre
		if compte == ICI then
			for roy, persos in pairs(royaumes) do
				for nom, f in pairs(persos) do
					enregs[#enregs + 1] = table.concat({
						"MSN1", ns.NomCompte(ICI), roy, nom, f.classe or "",
						f.maj or 0,
						"s:" .. Serie(f.sacs),
						"b:" .. Serie(f.banque),
						"m:" .. Serie(f.malle),
					}, "~")
				end
			end
		end
	end
	table.sort(enregs)
	return table.concat(enregs, ";")
end

-- Renvoie nombre de personnages importés, nom du compte source, message d'erreur.
function ns.Importer(txt)
	txt = (txt or ""):gsub("[\r\n\t]", "")
	if txt == "" then return 0, nil, L.IMPORT_VIDE end

	local local_ = ns.NomCompte(ICI)
	local lus, source, refus = 0, nil, false
	for enreg in txt:gmatch("[^;]+") do
		local compte, roy, nom, classe, maj, s, b, m =
			enreg:match("^%s*MSN1~(.-)~(.-)~(.-)~(.-)~(%d*)~s:(.-)~b:(.-)~m:(.-)$")
		if compte and compte ~= "" and roy ~= "" and nom ~= "" then
			if compte == local_ then
				refus = true
			else
				local f = ns.Fiche(compte, roy, nom, true)
				f.classe = classe ~= "" and classe or f.classe
				f.maj = tonumber(maj) or 0
				f.sacs = Deserie(s)
				f.banque = Deserie(b)
				f.malle = Deserie(m)
				lus = lus + 1
				source = compte
			end
		end
	end

	if lus == 0 then
		return 0, nil, refus and L.IMPORT_MEME_COMPTE:format(local_) or L.IMPORT_ILLISIBLE
	end
	if ns.StocksChanges then ns.StocksChanges() end
	return lus, source
end

-- ------------------------------------------------------------------- events --

function ns.InitStocks()
	MoissonDB.persos = MoissonDB.persos or {}
	MoissonDB.compte = MoissonDB.compte or L.COMPTE_DEFAUT

	royaume = GetRealmName and GetRealmName() or "?"
	moi = UnitName("player")

	local ev = CreateFrame("Frame")
	ev:RegisterEvent("PLAYER_ENTERING_WORLD")
	ev:RegisterEvent("BAG_UPDATE_DELAYED")
	ev:RegisterEvent("BANKFRAME_OPENED")
	ev:RegisterEvent("BANKFRAME_CLOSED")
	ev:RegisterEvent("PLAYERBANKSLOTS_CHANGED")
	ev:RegisterEvent("PLAYERBANKBAGSLOTS_CHANGED")
	ev:RegisterEvent("MAIL_SHOW")
	ev:RegisterEvent("MAIL_INBOX_UPDATE")
	ev:RegisterEvent("MAIL_CLOSED")
	ev:SetScript("OnEvent", function(_, event)
		if event == "PLAYER_ENTERING_WORLD" then
			moi = moi or UnitName("player")
			MajSacs()
		elseif event == "BAG_UPDATE_DELAYED" then
			MajSacs()
			if banqueOuverte then Bientot(MajBanque) end
		elseif event == "BANKFRAME_OPENED" then
			banqueOuverte = true
			Bientot(MajBanque)
		elseif event == "BANKFRAME_CLOSED" then
			Vider(MajBanque)
			banqueOuverte = false
		elseif event == "PLAYERBANKSLOTS_CHANGED"
		or event == "PLAYERBANKBAGSLOTS_CHANGED" then
			Bientot(MajBanque)
		elseif event == "MAIL_CLOSED" then
			Vider(MajMalle)
			malleOuverte = false
		else -- MAIL_SHOW, MAIL_INBOX_UPDATE
			malleOuverte = true
			Bientot(MajMalle)
		end
	end)
end

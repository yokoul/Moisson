-- Moisson — HUD de récolte plein écran pour WoW Classic Era.
-- Principe (hommage à FarmHud de Hizuro, réécrit de zéro) : on ne dessine pas
-- de carte, on déplace la vraie Minimap en plein écran, zoom mini, fond
-- invisible. Les pins (GatherMate2, Questie) sont rebranchés sur un calque
-- frère « cluster » pour rester opaques pendant que le fond de carte s'efface.

local ADDON, ns = ...

local Minimap = _G.Minimap
local MT = getmetatable(Minimap).__index
local UpdateRotation = _G.Minimap_UpdateRotationSetting or function() end
local L = ns.L

-- la version du schéma vit dans MoissonDB.version, posée par la dernière
-- migration atteinte (voir ADDON_LOADED)

local DEFAUTS = {
	taille    = 0.95,  -- fraction du plus petit côté de l'écran
	echelle   = 1.4,   -- grossissement des pins (la minimap est réduite puis re-scalée)
	alpha     = 0,     -- fond de carte invisible : seuls les pins restent
	alpha2    = 0.5,   -- alpha du mode « carte »
	fondmode  = "invisible", -- invisible | radar | carte (cycle du bouton fond)
	radarfond  = 0.45, -- mode radar : alpha de la minimap (les détections suivent)
	radarvoile = 0.65, -- mode radar : opacité du voile noir qui éteint le terrain
	rotation  = true,  -- la carte tourne avec le joueur
	coords    = true,
	cardinaux = true,
	cardalpha = 0.5,   -- transparence des points cardinaux
	compteurs = true,
	sourisalt = true,  -- souris fugace : active tant qu'Alt est enfoncée
	combat    = false, -- masquer le HUD en combat (comme FarmHud : non par défaut)
	bouton_angle = 200, -- position du bouton minimap
}

local db                    -- MoissonDB.opts
local saved                 -- instantané de la minimap à restaurer
local moved = {}            -- objets parqués sur le leurre
local coordsTicker, decorTicker
local hiddenByCombat = false

-- Frames anchorées à la minimap sans en être filles (ElvUI & Blizzard).
local EXTERNES = {
	"MinimapBackdrop", "MinimapBorder", "MinimapBorderTop", "MinimapNorthTag",
	"MinimapCompassTexture", "MinimapZoneText", "MinimapToggleButton",
	"MinimapZoomIn", "MinimapZoomOut", "MiniMapTracking", "MiniMapTrackingFrame",
	"MiniMapWorldMapButton", "GameTimeFrame", "TimeManagerClockButton",
	"MiniMapMailFrame", "MiniMapBattlefieldFrame", "LFGMinimapFrame",
	"QueueStatusMinimapButton",
}

-- ------------------------------------------------------------------ frames --

local hud = CreateFrame("Frame", "MoissonHUD", UIParent)
hud:Hide()
hud:EnableMouse(false)
hud:SetFrameStrata("BACKGROUND")
hud:SetFrameLevel(2)
hud:SetPoint("CENTER", WorldFrame, "CENTER")
hud:SetSize(200, 200)
hud.size = 200
ns.hud = hud

-- mode radar : les points de détection (Trouver les herbes/minerais) sont
-- dessinés DANS le rendu de la minimap, inséparables du terrain — l'alpha les
-- avale avec. On garde donc un alpha modéré et on éteint le terrain avec un
-- voile noir circulaire glissé SOUS la minimap.
local radar = CreateFrame("Frame", nil, hud)
radar:SetPoint("CENTER")
radar:SetFrameStrata("BACKGROUND")
radar:SetFrameLevel(0)
radar:Hide()
local voile = radar:CreateTexture(nil, "BACKGROUND")
voile:SetAllPoints()
voile:SetColorTexture(0, 0, 0, 1)
local masque = radar:CreateMaskTexture()
masque:SetAllPoints(voile)
masque:SetTexture("Interface\\CHARACTERFRAME\\TempPortraitAlphaMask",
	"CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
voile:AddMaskTexture(masque)

-- calque des pins : même géométrie que la minimap plein écran, mais frame
-- frère → l'alpha du fond ne l'affecte pas.
local cluster = CreateFrame("Frame", "MoissonCluster", hud)
cluster:SetPoint("CENTER")
cluster:EnableMouse(false)
cluster:Hide()
function cluster:GetZoom() return MT.GetZoom(Minimap) end
function cluster:SetZoom() end

-- leurre : occupe l'ancien emplacement de la minimap pour que les boutons
-- (ElvUI, MinimapButtonButton, LibDBIcon…) restent utilisables.
local leurre = CreateFrame("Button", "MoissonLeurre", UIParent)
leurre:Hide()
leurre:EnableMouse(false)

-- habillage (flèche, cardinaux, coordonnées, « souris active ») : il doit se
-- lire PAR-DESSUS les pins. Sans niveau explicite, texts hérite de hud+1 et
-- passait sous le cluster, posé au niveau 5 à l'ouverture.
local texts = CreateFrame("Frame", nil, hud)
texts:SetAllPoints()
texts:EnableMouse(false)
texts:SetFrameLevel(20)

local coordsFS = texts:CreateFontString(nil, "ARTWORK", "GameFontNormal")
coordsFS:SetTextColor(1, 0.82, 0)
coordsFS:Hide()

local sourisFS = texts:CreateFontString(nil, "ARTWORK", "GameFontNormalLarge")
sourisFS:SetText(L.SOURIS_ACTIVE)
sourisFS:SetTextColor(1, 0.3, 0.3)
sourisFS:SetPoint("CENTER", hud, "CENTER", 0, -24)
sourisFS:Hide()

-- flèche du joueur au centre (le fond étant invisible, celle de la minimap
-- disparaît avec lui)
local fleche = texts:CreateTexture(nil, "OVERLAY")
fleche:SetSize(26, 26)
fleche:SetPoint("CENTER")
fleche:SetTexture("Interface\\Minimap\\MinimapArrow")
fleche:Hide()

local CARDINAUX = L.CARDINAUX
local cards = {}
for i = 1, 8 do
	local principal = (i % 2 == 1)
	local fs = texts:CreateFontString(nil, "ARTWORK",
		principal and "GameFontNormalLarge" or "GameFontNormal")
	fs:SetText(CARDINAUX[i])
	if principal then
		fs:SetTextColor(1, 0.82, 0)
	else
		fs:SetTextColor(0.8, 0.8, 0.8)
	end
	fs:Hide()
	cards[i] = fs
end

-- --------------------------------------------------------------- utilitaires --

local function print_(msg)
	DEFAULT_CHAT_FRAME:AddMessage("|cff7fbf3fMoisson|r " .. tostring(msg))
end
ns.print = print_

local function SetScales()
	local e = UIParent:GetEffectiveScale()
	local w, h = WorldFrame:GetSize()
	hud.smin = math.min(w / e, h / e) -- petit côté de l'écran, en unités UI
	local size = hud.smin * db.taille
	hud:SetSize(size, size)
	hud.size = size
	-- l'échelle grossit blips et pins : minimap réduite puis re-scalée
	local reduit = size / db.echelle
	cluster:SetScale(db.echelle)
	cluster:SetSize(reduit, reduit)
	radar:SetSize(size, size)
	if Minimap:GetParent() == hud then
		MT.SetScale(Minimap, db.echelle)
		MT.SetSize(Minimap, reduit, reduit)
	end
	coordsFS:ClearAllPoints()
	coordsFS:SetPoint("CENTER", hud, "CENTER", 0, -size * 0.17)
end

local function UpdateDecor()
	local f = GetPlayerFacing() or 0
	if db.cardinaux then
		local rot = db.rotation and f or 0
		-- anneau proche du bord du HUD, borné pour rester visible à l'écran
		local r = math.min(hud.size * 0.46, (hud.smin or hud.size) * 0.48)
		for i = 1, 8 do
			local a = rot + (i - 1) * math.pi / 4
			cards[i]:ClearAllPoints()
			cards[i]:SetPoint("CENTER", hud, "CENTER", math.sin(a) * r, math.cos(a) * r)
		end
	end
	-- carte rotative : la flèche pointe en haut ; carte fixe : elle tourne
	fleche:SetRotation(db.rotation and 0 or f)
end

local function UpdateCoords()
	local mapID = C_Map.GetBestMapForUnit("player")
	if mapID then
		local pos = C_Map.GetPlayerMapPosition(mapID, "player")
		if pos then
			local x, y = pos:GetXY()
			if x and x > 0 then
				coordsFS:SetFormattedText("%.1f · %.1f", x * 100, y * 100)
				return
			end
		end
	end
	coordsFS:SetText("")
end

-- ------------------------------------------------- parcage vers le leurre --

-- Les pins de farm ne doivent PAS être parqués : leurs libs les rebranchent
-- elles-mêmes sur le cluster via SetMinimapObject/ReparentMinimapPins.
local function isPin(obj, name)
	if LibStub then
		local hbd = LibStub.libs["HereBeDragons-Pins-2.0"]
		if hbd and hbd.minimapPins and hbd.minimapPins[obj] then return true end
		local hbdq = LibStub.libs["HereBeDragonsQuestie-Pins-2.0"]
		if hbdq and hbdq.minimapPins and hbdq.minimapPins[obj] then return true end
	end
	if name and name:match("GatherMatePin") then return true end
	return false
end

-- Ré-ancre les points d'un objet de `from` vers `to`. Retourne true si touché.
local function retargetPoints(obj, from, to)
	if not obj.GetNumPoints then return false end
	local n, all, touched = obj:GetNumPoints(), {}, false
	for p = 1, n do
		local point, relTo, relPoint, x, y = obj:GetPoint(p)
		if relTo == from then
			relTo = to
			touched = true
		end
		all[p] = { point, relTo, relPoint, x, y }
	end
	if touched then
		obj:ClearAllPoints()
		for _, a in ipairs(all) do
			obj:SetPoint(a[1], a[2], a[3], a[4], a[5])
		end
	end
	return touched
end

-- Déplace (on=true) ou restaure (on=false) un meuble de la minimap.
local function park(obj, on)
	local name = obj.GetName and obj:GetName()
	if obj == hud or obj == cluster or obj == leurre or isPin(obj, name) then
		return
	end
	local from, to = Minimap, leurre
	if not on then from, to = leurre, Minimap end

	local touched = false
	if obj:GetParent() == from then
		-- SetParent réinitialise strata/niveau : on les réapplique.
		local strata, level, layer, sublevel
		if obj.GetFrameLevel then
			strata, level = obj:GetFrameStrata(), obj:GetFrameLevel()
		elseif obj.GetDrawLayer then
			layer, sublevel = obj:GetDrawLayer()
		end
		obj:SetParent(to)
		if strata then
			obj:SetFrameStrata(strata)
			obj:SetFrameLevel(level)
		elseif layer then
			obj:SetDrawLayer(layer, sublevel)
		end
		touched = true
	end
	if retargetPoints(obj, from, to) then touched = true end

	if on and touched then
		moved[#moved + 1] = obj
	end
end

-- ------------------------------------------------------------ pins étrangers --

local function ForeignPins(state)
	local map = state and cluster or Minimap
	local GM2 = _G.GatherMate2
	if GM2 and GM2.GetModule then
		local display = GM2:GetModule("Display", true)
		if display and display.ReparentMinimapPins then
			-- GM2 rabaisse le GameTooltip au niveau du nouveau parent (+2) :
			-- sur le cluster (niveau 5) les tooltips passeraient sous d'autres
			-- frames — on restaure le niveau derrière lui.
			local niveau = GameTooltip:GetFrameLevel()
			display:ReparentMinimapPins(map)
			if GameTooltip:GetFrameLevel() < niveau then
				GameTooltip:SetFrameLevel(niveau)
			end
		end
	end
	if LibStub then
		local hbd = LibStub.libs["HereBeDragons-Pins-2.0"]
		if hbd and hbd.SetMinimapObject then
			hbd:SetMinimapObject(state and map or nil)
		end
		local hbdq = LibStub.libs["HereBeDragonsQuestie-Pins-2.0"]
		if hbdq and hbdq.SetMinimapObject then
			hbdq:SetMinimapObject(state and map or nil)
		end
	end
end

-- ------------------------------------------------------------------- souris --

-- La minimap plein écran DOIT rester transparente aux clics : c'est elle qui
-- couvrait tout l'écran quand un addon (ElvUI…) réactivait sa souris.
local sourisVoulue = false  -- état demandé par l'utilisateur (mode inspection)

local function ForceMouseOff()
	if Minimap:GetParent() == hud and not sourisVoulue then
		MT.EnableMouse(Minimap, false)
		MT.EnableMouseWheel(Minimap, false)
	end
end

hooksecurefunc(Minimap, "EnableMouse", function(_, enabled)
	if enabled and hud:IsShown() and not sourisVoulue then
		MT.EnableMouse(Minimap, false)
	end
end)
hooksecurefunc(Minimap, "EnableMouseWheel", function(_, enabled)
	if enabled and hud:IsShown() then
		MT.EnableMouseWheel(Minimap, false)
	end
end)

local function PingClick()
	local x, y = GetCursorPosition()
	local s = MT.GetEffectiveScale(Minimap)
	x, y = x / s, y / s
	local cx, cy = MT.GetCenter(Minimap)
	x, y = x - cx, y - cy
	if math.sqrt(x * x + y * y) < MT.GetWidth(Minimap) * 0.5 then
		Minimap:PingLocation(x, y)
	end
end

function Moisson_ToggleMouse(force)
	if Minimap:GetParent() ~= hud then return end
	local enable
	if force ~= nil then enable = force else enable = not Minimap:IsMouseEnabled() end
	sourisVoulue = enable
	MT.EnableMouse(Minimap, enable)
	sourisFS:SetShown(enable)
end

-- application du mode de fond courant (invisible / radar / carte)
local FOND_SUIVANT = { invisible = "radar", radar = "carte", carte = "invisible" }
local FOND_LIBELLE = {
	invisible = L.FOND_INVISIBLE,
	radar = L.FOND_RADAR,
	carte = L.FOND_CARTE,
}

local function ApplyFond()
	if Minimap:GetParent() ~= hud then return end
	local mode = db.fondmode
	if mode == "radar" then
		MT.SetAlpha(Minimap, db.radarfond)
		radar:SetAlpha(db.radarvoile)
		radar:Show()
	elseif mode == "carte" then
		MT.SetAlpha(Minimap, db.alpha2)
		radar:Hide()
	else
		MT.SetAlpha(Minimap, db.alpha)
		radar:Hide()
	end
end
ns.ApplyFond = ApplyFond

-- cycle invisible → radar → carte (HUD ouvert uniquement)
function Moisson_ToggleFond()
	if Minimap:GetParent() ~= hud then return end
	db.fondmode = FOND_SUIVANT[db.fondmode] or "invisible"
	ApplyFond()
	print_(FOND_LIBELLE[db.fondmode])
end

-- ------------------------------------------------------- ancrage plein écran --

-- SetPoint peut lever « anchor family connection » selon ce que d'autres
-- addons ont ancré ; on retente puis on retombe sur SetAllPoints.
local function AnchorMinimap()
	for try = 1, 3 do
		MT.ClearAllPoints(Minimap)
		local ok = pcall(function()
			if try < 3 then
				MT.SetPoint(Minimap, "CENTER", hud, "CENTER", 0, 0)
			else
				MT.SetAllPoints(Minimap, hud)
			end
		end)
		if ok then return true end
	end
end

-- --------------------------------------------------------------- Show / Hide --

hud:SetScript("OnShow", function(self)
	-- 1. instantané de la minimap
	saved = {
		parent = Minimap:GetParent(),
		scale  = Minimap:GetScale(),
		width  = Minimap:GetWidth(),
		height = Minimap:GetHeight(),
		strata = Minimap:GetFrameStrata(),
		level  = Minimap:GetFrameLevel(),
		alpha  = Minimap:GetAlpha(),
		zoom   = Minimap:GetZoom(),
		mouse  = Minimap:IsMouseEnabled(),
		wheel  = Minimap:IsMouseWheelEnabled(),
		onUp   = Minimap:GetScript("OnMouseUp"),
		onDown = Minimap:GetScript("OnMouseDown"),
		onWheel = Minimap:GetScript("OnMouseWheel"),
		rotate = C_CVar.GetCVar("rotateMinimap"),
		clusterMouse  = MinimapCluster and MinimapCluster:IsMouseEnabled(),
		backdropMouse = MinimapBackdrop and MinimapBackdrop:IsMouseEnabled(),
		points = {},
	}
	for i = 1, Minimap:GetNumPoints() do
		saved.points[i] = { Minimap:GetPoint(i) }
	end

	-- 2. le leurre prend la place de la minimap
	leurre:SetParent(saved.parent)
	leurre:SetScale(saved.scale)
	leurre:SetSize(saved.width, saved.height)
	leurre:SetFrameStrata(saved.strata)
	leurre:SetFrameLevel(saved.level)
	leurre:ClearAllPoints()
	for _, p in ipairs(saved.points) do
		pcall(leurre.SetPoint, leurre, unpack(p))
	end
	leurre:Show()

	-- 3. parquer les meubles (boutons, textures, cadres ancrés)
	wipe(moved)
	local children = { Minimap:GetChildren() }
	for _, child in ipairs(children) do pcall(park, child, true) end
	local regions = { Minimap:GetRegions() }
	for _, region in ipairs(regions) do pcall(park, region, true) end
	for _, name in ipairs(EXTERNES) do
		local f = _G[name]
		if f then pcall(park, f, true) end
	end

	-- 4. la minimap passe en plein écran
	MT.Hide(Minimap)
	MT.SetParent(Minimap, hud)
	AnchorMinimap()
	MT.SetFrameStrata(Minimap, "BACKGROUND")
	MT.SetFrameLevel(Minimap, 1)
	SetScales()
	MT.SetZoom(Minimap, 0)
	-- SetZoom devient un no-op : fige le zoom sans casser les « danses de
	-- zoom » (Questie sonde l'intérieur/extérieur par SetZoom ±1 successifs)
	saved.setZoomMember = rawget(Minimap, "SetZoom")
	Minimap.SetZoom = function() end
	ApplyFond()
	sourisVoulue = false
	MT.EnableMouse(Minimap, false)
	MT.EnableMouseWheel(Minimap, false)
	MT.SetScript(Minimap, "OnMouseUp", PingClick)
	MT.SetScript(Minimap, "OnMouseDown", nil)
	MT.SetScript(Minimap, "OnMouseWheel", nil)

	-- les conteneurs Blizzard ne doivent pas bloquer les clics non plus
	if MinimapCluster then
		MinimapCluster:EnableMouse(false)
		MinimapCluster:EnableMouseWheel(false)
	end
	if MinimapBackdrop then MinimapBackdrop:EnableMouse(false) end

	-- 5. rotation façon radar
	if (saved.rotate == "1") ~= db.rotation then
		C_CVar.SetCVar("rotateMinimap", db.rotation and "1" or "0")
		UpdateRotation()
	end
	MT.Show(Minimap)

	-- 6. pins de farm sur le calque opaque
	cluster:SetFrameStrata("BACKGROUND")
	cluster:SetFrameLevel(5)
	cluster:Show()
	ForeignPins(true)

	-- ceinture et bretelles : certains addons réactivent la souris après coup
	C_Timer.After(0, ForceMouseOff)
	C_Timer.After(0.5, ForceMouseOff)

	-- 7. habillage
	if db.coords then
		coordsFS:Show()
		UpdateCoords()
		coordsTicker = C_Timer.NewTicker(0.1, UpdateCoords)
	end
	if db.cardinaux then
		for i = 1, 8 do
			cards[i]:SetAlpha(db.cardalpha)
			cards[i]:Show()
		end
	end
	fleche:Show()
	UpdateDecor()
	decorTicker = C_Timer.NewTicker(0.05, UpdateDecor)
	if ns.CompteursOnShow then ns.CompteursOnShow() end
end)

hud:SetScript("OnHide", function(self)
	if not saved then return end

	if coordsTicker then coordsTicker:Cancel(); coordsTicker = nil end
	if decorTicker then decorTicker:Cancel(); decorTicker = nil end
	coordsFS:Hide()
	for i = 1, 8 do cards[i]:Hide() end
	fleche:Hide()
	sourisFS:Hide()
	sourisVoulue = false

	ForeignPins(false)
	cluster:Hide()

	-- restauration intégrale de la minimap
	MT.Hide(Minimap)
	MT.SetParent(Minimap, saved.parent)
	MT.ClearAllPoints(Minimap)
	for _, p in ipairs(saved.points) do
		pcall(MT.SetPoint, Minimap, unpack(p))
	end
	MT.SetScale(Minimap, saved.scale)
	MT.SetSize(Minimap, saved.width, saved.height)
	MT.SetFrameStrata(Minimap, saved.strata)
	MT.SetFrameLevel(Minimap, saved.level)
	MT.SetAlpha(Minimap, saved.alpha)
	MT.EnableMouse(Minimap, saved.mouse)
	MT.EnableMouseWheel(Minimap, saved.wheel)
	MT.SetScript(Minimap, "OnMouseUp", saved.onUp)
	MT.SetScript(Minimap, "OnMouseDown", saved.onDown)
	MT.SetScript(Minimap, "OnMouseWheel", saved.onWheel)
	Minimap.SetZoom = saved.setZoomMember -- nil → retour à la métatable
	local maxZoom = Minimap:GetZoomLevels()
	MT.SetZoom(Minimap, math.min(saved.zoom, maxZoom))

	if MinimapCluster then
		MinimapCluster:EnableMouse(saved.clusterMouse and true or false)
		MinimapCluster:EnableMouseWheel(saved.clusterMouse and true or false)
	end
	if MinimapBackdrop then
		MinimapBackdrop:EnableMouse(saved.backdropMouse and true or false)
	end

	if C_CVar.GetCVar("rotateMinimap") ~= saved.rotate then
		C_CVar.SetCVar("rotateMinimap", saved.rotate)
		UpdateRotation()
	end
	MT.Show(Minimap)

	-- les meubles reviennent du leurre
	for _, obj in ipairs(moved) do
		pcall(park, obj, false)
	end
	wipe(moved)
	leurre:Hide()

	if ns.CompteursOnHide then ns.CompteursOnHide() end
	saved = nil
end)

-- ------------------------------------------------------------------- toggle --

function Moisson_Toggle(force)
	if force == nil then force = not hud:IsShown() end
	if force and InCombatLockdown() and db.combat then
		print_(L.COMBAT_INDISPO)
		return
	end
	hud:SetShown(force)
end

BINDING_HEADER_MOISSON = "Moisson"
BINDING_NAME_MOISSON_TOGGLE = L.BIND_TOGGLE
BINDING_NAME_MOISSON_MOUSE = L.BIND_MOUSE
BINDING_NAME_MOISSON_FOND = L.BIND_FOND

-- ---------------------------------------------------- application des options --

-- Chaque réglage sait s'appliquer à chaud (partagé slash / panneau d'options).
ns.Apply = {
	taille = function(v)
		db.taille = v
		if hud:IsShown() then SetScales(); UpdateDecor() end
	end,
	echelle = function(v)
		db.echelle = v
		if hud:IsShown() then SetScales() end
	end,
	alpha = function(v)
		db.alpha = v
		if hud:IsShown() then ApplyFond() end
	end,
	alpha2 = function(v)
		db.alpha2 = v
		if hud:IsShown() then ApplyFond() end
	end,
	radarfond = function(v)
		db.radarfond = v
		if hud:IsShown() then ApplyFond() end
	end,
	radarvoile = function(v)
		db.radarvoile = v
		if hud:IsShown() then ApplyFond() end
	end,
	rotation = function(v)
		db.rotation = v
		if hud:IsShown() then hud:Hide(); hud:Show() end
	end,
	coords = function(v)
		db.coords = v
		if hud:IsShown() then
			if v then
				coordsFS:Show()
				UpdateCoords()
				coordsTicker = coordsTicker or C_Timer.NewTicker(0.1, UpdateCoords)
			else
				if coordsTicker then coordsTicker:Cancel(); coordsTicker = nil end
				coordsFS:Hide()
			end
		end
	end,
	cardinaux = function(v)
		db.cardinaux = v
		for i = 1, 8 do cards[i]:SetShown(v and hud:IsShown()) end
		if v and hud:IsShown() then UpdateDecor() end
	end,
	cardalpha = function(v)
		db.cardalpha = v
		for i = 1, 8 do cards[i]:SetAlpha(v) end
	end,
	compteurs = function(v)
		db.compteurs = v
		if hud:IsShown() and ns.CompteursOnShow then ns.CompteursOnShow() end
	end,
	sourisalt = function(v)
		db.sourisalt = v
		-- décocher pendant qu'Alt tient la souris laisserait le mode collé
		if not v and ns.AltRelache then ns.AltRelache() end
	end,
	combat = function(v)
		db.combat = v
		-- décocher pendant un combat qui a masqué le HUD : ne pas le faire
		-- ressurgir tout seul à la fin du combat
		if not v then hiddenByCombat = false end
	end,
}

-- ------------------------------------------------------------------- events --

-- ---- souris fugace : survivre à l'Alt+Tab -----------------------------------
--
-- MODIFIER_STATE_CHANGED ne garantit pas qu'un appui soit suivi d'un
-- relâchement : dès que le joueur bascule sur une autre fenêtre, le « LALT = 0 »
-- part à l'OS et jamais au client. Sans garde-fou, le mode clic reste armé et
-- se réarme même tout seul au retour, quand WoW resynchronise ses modificateurs.

local altSouris = false     -- la souris courante a été activée par Alt
local altTouche             -- laquelle des deux Alt a armé le mode
local altTicker             -- sonde le relâchement que l'événement a pu manquer
local derniereFrame = 0     -- horodatage de la dernière frame rendue
local GEL_FOCUS = 0.25      -- au-delà, la frame précédente date d'avant l'Alt+Tab

local function AltRelache()
	if altTicker then altTicker:Cancel(); altTicker = nil end
	altTouche = nil
	if altSouris then
		altSouris = false
		Moisson_ToggleMouse(false)
	end
end
ns.AltRelache = AltRelache

local function AltEnfonce(touche)
	altSouris = true
	altTouche = touche
	Moisson_ToggleMouse(true)
	-- l'événement de relâchement peut se perdre : on sonde l'état réel du
	-- clavier pour ne jamais rester collé en mode clic
	altTicker = altTicker or C_Timer.NewTicker(0.1, function()
		if not IsAltKeyDown() or not hud:IsShown() then AltRelache() end
	end)
end

hud:HookScript("OnUpdate", function() derniereFrame = GetTime() end)
hud:HookScript("OnShow", function() derniereFrame = GetTime() end)
hud:HookScript("OnHide", AltRelache)

local ev = CreateFrame("Frame")
ev:RegisterEvent("ADDON_LOADED")
ev:RegisterEvent("PLAYER_LOGOUT")
ev:RegisterEvent("PLAYER_REGEN_DISABLED")
ev:RegisterEvent("PLAYER_REGEN_ENABLED")
ev:RegisterEvent("MODIFIER_STATE_CHANGED")
ev:SetScript("OnEvent", function(_, event, arg1, arg2)
	if event == "MODIFIER_STATE_CHANGED" then
		-- souris fugace : la minimap ne mange les clics que pendant l'appui
		if db and db.sourisalt and hud:IsShown()
		and (arg1 == "LALT" or arg1 == "RALT") then
			if arg2 == 1 then
				-- appui « orphelin » sur la touche qui a armé : son relâchement
				-- s'est perdu pendant l'Alt+Tab, on désarme au lieu de réarmer
				if altSouris then
					if arg1 == altTouche then AltRelache() end
				-- premier rendu depuis un gel : c'est l'Alt du retour de focus,
				-- pas une intention de cliquer
				elseif GetTime() - derniereFrame > GEL_FOCUS then
					return
				elseif not Minimap:IsMouseEnabled() then
					AltEnfonce(arg1)
				end
			elseif arg1 == altTouche then
				AltRelache()
			end
		end
		return
	end
	if event == "ADDON_LOADED" and arg1 == ADDON then
		MoissonDB = MoissonDB or {}
		MoissonDB.opts = MoissonDB.opts or {}
		for k, v in pairs(DEFAUTS) do
			if MoissonDB.opts[k] == nil then MoissonDB.opts[k] = v end
		end
		-- v2 : défauts recalés sur la config FarmHud d'origine (fond invisible,
		-- pins grossis) — on migre les valeurs posées par la v0.1.0
		if (MoissonDB.version or 1) < 2 then
			MoissonDB.opts.alpha = DEFAUTS.alpha
			MoissonDB.opts.alpha2 = DEFAUTS.alpha2
			MoissonDB.opts.echelle = DEFAUTS.echelle
			MoissonDB.version = 2
		end
		-- v3 : le masquage en combat redevient opt-in (comme FarmHud)
		if MoissonDB.version < 3 then
			MoissonDB.opts.combat = DEFAUTS.combat
			MoissonDB.version = 3
		end
		-- v4 : catégories re-clées en chaînes (herbes, minerais…) + journal
		if MoissonDB.version < 4 then
			MoissonDB.objets = {}
			MoissonDB.cats = {}
			MoissonDB.version = 4
		end
		-- v5 : reclassement selon les familles Era (donnees.lua) — la DB2 du
		-- client range presque tout en 7/0, les premiers comptes étaient
		-- partis en « autres »
		if MoissonDB.version < 5 then
			local fam, cats = ns.FAMILLES or {}, {}
			for id, rec in pairs(MoissonDB.objets or {}) do
				rec.cat = fam[id] or rec.cat or "autres"
				cats[rec.cat] = (cats[rec.cat] or 0) + (rec.total or 0)
			end
			MoissonDB.cats = cats
			MoissonDB.version = 5
		end
		-- v6 : la rangée de boutons à l'écran a disparu (tout vit sur le
		-- bouton minimap)
		if MoissonDB.version < 6 then
			MoissonDB.opts.boutons = nil
			MoissonDB.version = 6
		end
		db = MoissonDB.opts
		ns.db = db
		if ns.InitCompteurs then ns.InitCompteurs() end
		if ns.InitBoutonMinimap then ns.InitBoutonMinimap() end
		if ns.InitOptions then ns.InitOptions() end
	elseif event == "PLAYER_LOGOUT" then
		-- ne pas laisser fuiter la CVar de rotation si on déco HUD ouvert
		if saved and C_CVar.GetCVar("rotateMinimap") ~= saved.rotate then
			C_CVar.SetCVar("rotateMinimap", saved.rotate)
		end
	elseif event == "PLAYER_REGEN_DISABLED" then
		if db and db.combat and hud:IsShown() then
			hiddenByCombat = true
			hud:Hide()
		end
	elseif event == "PLAYER_REGEN_ENABLED" then
		if hiddenByCombat then
			hiddenByCombat = false
			hud:Show()
		end
	end
end)

-- -------------------------------------------------------------------- slash --

function ns.Aide()
	for _, ligne in ipairs(L.AIDE) do
		print_(ligne)
	end
end

-- les commandes existent en français et en anglais
local ALIAS = {
	mouse = "souris", background = "fond", size = "taille", scale = "echelle",
	counters = "compteurs", summary = "bilan", log = "journal", reset = "raz",
	help = "aide", all = "tout",
}

SLASH_MOISSON1 = "/moisson"
SlashCmdList["MOISSON"] = function(input)
	input = (input or ""):lower():gsub("^%s+", "")
	local cmd, arg = input:match("^(%S*)%s*(.*)$")
	cmd = ALIAS[cmd] or cmd
	arg = ALIAS[arg] or arg
	if cmd == "" then
		Moisson_Toggle()
	elseif cmd == "options" then
		if ns.OpenOptions then ns.OpenOptions() end
	elseif cmd == "souris" then
		Moisson_ToggleMouse()
	elseif cmd == "fond" then
		Moisson_ToggleFond()
	elseif cmd == "rotation" then
		ns.Apply.rotation(not db.rotation)
		print_(db.rotation and L.ROTATION_ON or L.ROTATION_OFF)
	elseif cmd == "taille" then
		local v = tonumber(arg)
		if v and v >= 0.3 and v <= 1.2 then
			ns.Apply.taille(v)
			print_(L.VAL_TAILLE:format(v))
		else
			print_(L.ERR_TAILLE)
		end
	elseif cmd == "cardalpha" then
		local v = tonumber(arg)
		if v and v >= 0 and v <= 1 then
			ns.Apply.cardalpha(v)
			print_(L.VAL_CARDALPHA:format(v))
		else
			print_(L.ERR_01)
		end
	elseif cmd == "echelle" then
		local v = tonumber(arg)
		if v and v >= 1 and v <= 2 then
			ns.Apply.echelle(v)
			print_(L.VAL_ECHELLE:format(v))
		else
			print_(L.ERR_ECHELLE)
		end
	elseif cmd == "alpha" then
		local v = tonumber(arg)
		if v and v >= 0 and v <= 1 then
			ns.Apply.alpha(v)
			print_(L.VAL_ALPHA:format(v))
		else
			print_(L.ERR_01)
		end
	elseif cmd == "compteurs" then
		ns.Apply.compteurs(not db.compteurs)
		print_(db.compteurs and L.COMPTEURS_ON or L.COMPTEURS_OFF)
	elseif cmd == "bilan" then
		if ns.Bilan then ns.Bilan() end
	elseif cmd == "debug" then
		ns.debugLoot = not ns.debugLoot
		print_(ns.debugLoot and L.DEBUG_ON or L.DEBUG_OFF)
	elseif cmd == "test" then
		if ns.TestCompteurs then ns.TestCompteurs() end
	elseif cmd == "journal" then
		if ns.Journal then ns.Journal() end
	elseif cmd == "version" then
		local GetMeta = (C_AddOns and C_AddOns.GetAddOnMetadata) or GetAddOnMetadata
		print_("version " .. (GetMeta and GetMeta(ADDON, "Version") or "?"))
	elseif cmd == "raz" then
		if ns.Raz then ns.Raz(arg == "tout") end
	else
		ns.Aide()
	end
end

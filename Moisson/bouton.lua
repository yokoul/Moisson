-- Moisson — bouton minimap (déplaçable sur le pourtour, clic gauche = HUD,
-- clic droit = options, tooltip = résumé de la session).

local ADDON, ns = ...

local mmb

local function UpdatePosition()
	local a = math.rad(ns.db.bouton_angle or 200)
	local r = (Minimap:GetWidth() / 2) + 5
	mmb:ClearAllPoints()
	mmb:SetPoint("CENTER", Minimap, "CENTER", math.cos(a) * r, math.sin(a) * r)
end

local function OnDragUpdate()
	local mx, my = Minimap:GetCenter()
	local cx, cy = GetCursorPosition()
	local s = Minimap:GetEffectiveScale()
	ns.db.bouton_angle = math.deg(math.atan2(cy / s - my, cx / s - mx))
	UpdatePosition()
end

function ns.InitBoutonMinimap()
	if mmb then return end
	mmb = CreateFrame("Button", "MoissonBoutonMinimap", Minimap)
	mmb:SetSize(31, 31)
	mmb:SetFrameStrata("MEDIUM")
	mmb:SetFrameLevel(8)
	mmb:RegisterForClicks("LeftButtonUp", "RightButtonUp")
	mmb:RegisterForDrag("LeftButton")
	mmb:SetHighlightTexture("Interface\\Minimap\\UI-Minimap-ZoomButton-Highlight")

	local overlay = mmb:CreateTexture(nil, "OVERLAY")
	overlay:SetSize(53, 53)
	overlay:SetTexture("Interface\\Minimap\\MiniMap-TrackingBorder")
	overlay:SetPoint("TOPLEFT")

	local icon = mmb:CreateTexture(nil, "BACKGROUND")
	icon:SetSize(20, 20)
	icon:SetTexture("Interface\\Icons\\Trade_Herbalism")
	icon:SetPoint("TOPLEFT", 7, -5)

	mmb:SetScript("OnClick", function(_, button)
		if button == "RightButton" then
			if ns.OpenOptions then ns.OpenOptions() end
		else
			Moisson_Toggle()
		end
	end)
	mmb:SetScript("OnDragStart", function(self)
		self:SetScript("OnUpdate", OnDragUpdate)
	end)
	mmb:SetScript("OnDragStop", function(self)
		self:SetScript("OnUpdate", nil)
	end)
	mmb:SetScript("OnEnter", function(self)
		GameTooltip:SetOwner(self, "ANCHOR_LEFT")
		GameTooltip:SetText("|cff7fbf3fMoisson|r")
		local resume = ns.SessionResume and ns.SessionResume()
		if resume then
			GameTooltip:AddLine("Session : " .. resume, 1, 1, 1)
		end
		GameTooltip:AddLine("Clic gauche : HUD · Clic droit : options", 0.7, 0.7, 0.7)
		GameTooltip:Show()
	end)
	mmb:SetScript("OnLeave", function() GameTooltip:Hide() end)

	UpdatePosition()
end

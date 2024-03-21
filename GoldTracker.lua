GoldTracker = CreateFrame("Frame")
GoldTracker:SetScript("OnEvent", function(self, event, ...)
	if self[event] then
		return self[event](self, event, ...)
	end
end)
GoldTracker:RegisterEvent("ADDON_LOADED")

local GameTooltip = _G.GameTooltip
local currentUnit = nil
local readyFlag = false
local cityFlag = false
local playerName = nil

local MOST_GOLD_OWNED = "334"
local TOTAL_GOLD_ACQUIRED = "328"
local AVG_EARNED_DAILY = "753"


local defaults = {
	WealthType = TOTAL_GOLD_ACQUIRED,
	DisableEnemyFaction = false,
	DisableInCombat = true,
	OnlyInCity = false,
	ShowCoins = true,
	Cache = { player = nil, money = 0 }
}
local db = defaults

local options = {
	type = "group",
	name = "GoldTrackerPro",
	get = function(k) return GoldTrackerDB[k.arg] end,
	set = function(k, v) GoldTrackerDB[k.arg] = v end,
	args = {
		desc = {
			type = "description", order = 0,
			name = " inspect how much gold your mouseover target has made so far.",
		},
		WealthType = {
			name = "Wealth type",
			desc = "Use this statistic for querying wealth",
			type = "select",
			values = {
				[TOTAL_GOLD_ACQUIRED] = "Total gold ever acquired",
				[MOST_GOLD_OWNED] = "Most gold ever owned",
				[AVG_EARNED_DAILY] = "Average gold earned/day"
			},
			arg = "WealthType",
			order = 1,
		},
		DisableEnemyFaction = {
			name = "Disable opposite faction",
			desc = "Disables checking opposite faction wealth even if friendly.",
			type = "toggle",
			arg = "DisableEnemyFaction",
			order = 2, width = "full",
		},
		DisableInCombat = {
			name = "Disable in combat",
			desc = "Disables wealth querying in combat.",
			type = "toggle",
			arg = "DisableInCombat",
			order = 3, width = "full",
		},
		OnlyInCity = {
			name = "Enable only in cities",
			desc = "Enable checking only when inside a major city.",
			type = "toggle",
			arg = "OnlyInCity",
			order = 4, width = "full",
		},
		ShowCoins = {
			name = "Show wealth as coins",
			desc = "Displays wealth with coin graphic if enabled. Formatted as plain text if disabled.",
			type = "toggle",
			arg = "ShowCoins",
			order = 5, width = "full",
		}
	}
}


local doubleLine = false
if TipTop or CowTip then
	doubleLine = true
end

local FormatMoneyPattern = {
	["|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t"] = "g",
	["|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t"] = "s",
	["|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"] = "c"
}

local function ShowTooltip(money)
	if money:sub(1, 1) == "-" then
		money = money:gsub("|TInterface\\MoneyFrame\\UI%-%a+Icon:0:0:2:0|t", "")
		local max = 2147483648
		money = math.abs(math.abs(money) - max) + max
		money = math.floor(money/10000) .. "|TInterface\\MoneyFrame\\UI-GoldIcon:0:0:2:0|t " ..
				math.floor(money%10000/100) .. "|TInterface\\MoneyFrame\\UI-SilverIcon:0:0:2:0|t " ..
				(money%100) .. "|TInterface\\MoneyFrame\\UI-CopperIcon:0:0:2:0|t"
	end
	if not db.ShowCoins then
		money = string.gsub(money, "|TInterface\\MoneyFrame\\UI%-%a+Icon:0:0:2:0|t", FormatMoneyPattern)
	end
	
	if not doubleLine then
		GameTooltip:AddLine("Money: " .. money)
	else
		GameTooltip:AddDoubleLine("Money: ", money)
	end
	GameTooltip:Show()
end

function GoldTracker:INSPECT_ACHIEVEMENT_READY()
	if GameTooltip:GetUnit() == currentUnit then
		local money = GetComparisonStatistic(db.WealthType)
		db.Cache.player = currentUnit
		db.Cache.money = money
		ShowTooltip(money)
	end
	self:UnregisterEvent("INSPECT_ACHIEVEMENT_READY");
	if (AchievementFrameComparison) then
		AchievementFrameComparison:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
	end
	ClearAchievementComparisonUnit()
	ClearInspectPlayer()
	currentUnit = nil
	readyFlag = true
end

function GoldTracker:InspectUnit(unit)
	if not UnitExists(unit) or not UnitIsPlayer(unit) or
			(db.DisableInCombat and InCombatLockdown()) or
			(db.DisableEnemyFaction and not UnitIsFriend("player", unit)) or
			(db.OnlyInCity and not cityFlag) then return end
	
	local unitName = UnitName(unit)
	if unitName == playerName then
		ShowTooltip(GetStatistic(db.WealthType))
		return
	end
	
	if not CheckInteractDistance(unit, 1) then
		ShowTooltip("too far")
		return
	elseif not CanInspect(unit) then
		ShowTooltip("not allowed")
		return
	end
	
	if db.Cache.player == unitName then
		ShowTooltip(db.Cache.money)
		return
	end
	
	if readyFlag then
		if (AchievementFrameComparison) then
			AchievementFrameComparison:UnregisterEvent("INSPECT_ACHIEVEMENT_READY")
		end
		self:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
		SetAchievementComparisonUnit(unit)
		currentUnit = unitName
		readyFlag = false
	end
end

function GoldTracker:UPDATE_MOUSEOVER_UNIT()
	GoldTracker:InspectUnit("mouseover")
end




function GoldTracker:ZONE_CHANGED_NEW_AREA(event)
	if not readyFlag then
		readyFlag = true
	end
	
	self:UnregisterEvent("INSPECT_ACHIEVEMENT_READY");
	if (AchievementFrameComparison) then
		AchievementFrameComparison:RegisterEvent("INSPECT_ACHIEVEMENT_READY")
	end
	
	local channels = {EnumerateServerChannels()}
	for _, chan in pairs(channels) do
		if chan == "Trade" then
			cityFlag = true
			return
		end
	end
	
	cityFlag = false
end

function GoldTracker:ADDON_LOADED(event, name)
	if name ~= "GoldTracker" then return end
	self:UnregisterEvent("ADDON_LOADED")
	
	GoldTrackerDB = GoldTrackerDB or {}
	db = GoldTrackerDB
	for name, value in pairs(defaults) do
		if db[name] == nil then
			 db[name] = value
		end
	end
	LibStub("AceConfigRegistry-3.0"):RegisterOptionsTable("GoldTrackerPro", options)
	LibStub("AceConfigDialog-3.0"):AddToBlizOptions("GoldTrackerPro", "GoldTracker Pro")
	
	self:RegisterEvent("ZONE_CHANGED_NEW_AREA")
	GoldTracker:ZONE_CHANGED_NEW_AREA()
	
	if TGATip then
		TGATip.HookOnTooltipSetUnit(GameTooltip, GoldTracker.InspectUnit)
	else
		self:RegisterEvent("UPDATE_MOUSEOVER_UNIT")
	end
	
	readyFlag = true
	playerName = UnitName("player")
end

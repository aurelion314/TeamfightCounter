local AddonName, TFC = ...

TFC.MainOptionTable = {
	type = "group",
	get = function(info)
        return TFC.settings[info[#info]]
    end, 
	set = function(info, value)
        TFC.settings[info[#info]] = value
		TFC.addon:refreshCallback()
		TFC.addon:Debug("Updated Setting", info[#info], value)
    end,
	args = {
		floatingFrame = {
			type = "group",
			name = "Floating Frame",
			order = 1,
			inline = true,
			args = {
				showFrame = {
					name = "Show Floating Frame",
					type = "toggle",
					width = "full",
					order = 1,
				},
				showOutsideInstance = {
					name = "Show Outside Instance",
					desc = "Show the floating frame even outside of BGs",
					disabled = function(info) return not TFC.settings.showFrame end,
					type = "toggle",
					width = "single",
					order = 2,
				},
				frameOnBaselessMaps = {
					name = "Only node-less maps",
					desc = "Use floating frame instead of map based counters on maps that don't have nodes.",
					disabled = function(info) return not TFC.settings.showFrame end,
					type = "toggle",
					width = "single",
					order = 3,
				},
			}
		},
		showMissing = {
			name = "Show Missing Enemies",
			desc = "Show unaccounted for enemies at the top of the map or above the counter.",
			type = "toggle",
			width = "full",
			order = 4,
		},
		showDebug = {
			name = "Debug Mode",
			type = "toggle",
			width = "full",
			order = 5,
		},
	}
}
		-- frameSize = {
		-- 	name = "Frame Size",
		-- 	desc = "Scale the frame!",
		-- 	type = "range",
		-- 	width = "double",
		-- 	order = 4,
		-- 	min = 1,
		-- 	max = 100,
		-- 	step = 1,
		-- 	-- set = function(_, val) RE.Settings.ArenaStatsLimit = val end,
		-- 	-- get = function(_) return RE.Settings.ArenaStatsLimit end
		-- },
		-- dropdown = {
		-- 	name = "LDB feed display mode",
		-- 	desc = "Rating display always compares the values with the previous week.",
		-- 	type = "select",
		-- 	width = "double",
		-- 	order = 5,
		-- 	values = {
		-- 		[1] = "Current session",
		-- 		[2] = _G.HONOR_TODAY,
		-- 		[3] = _G.GUILD_CHALLENGES_THIS_WEEK
		-- 	},
		-- 	set = function(_, val) RE.Settings.LDBMode = val; RE.LDBUpdate = true; RE:UpdateLDBTime(); RE:UpdateLDB() end,
		-- 	get = function(_) return RE.Settings.LDBMode end
		-- },
		-- button = {
		-- 	name = "Purge database",
		-- 	desc = "WARNING! This operation is not reversible!",
		-- 	type = "execute",
		-- 	width = "double",
		-- 	confirm = true,
		-- 	order = 6,
		-- 	func = function() _G.REFlexDatabase = {}; _G.REFlexHonorDatabase = {}; ReloadUI() end
		-- },


TFC.DefaultSettings = {
	profile= {
		showFrame = false,
		showOutsideInstance = false,
		frameOnBaselessMaps = false,
		showMissing = true,
		showDebug = false,
	}
}

--used for class blips
local classOrder = {
    "DEMONHUNTER",
    "DEATHKNIGHT",
    "WARRIOR",
    "MONK",
    "HUNTER",
    "MAGE",
    "WARLOCK",
    "PRIEST",
    "PALADIN",
    "SHAMAN",
    "DRUID",
    "ROGUE",
}
TFC.classOrder = {}
for i, class in pairs(classOrder) do
	TFC.classOrder[class] = i
end

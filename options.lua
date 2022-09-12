local AddonName, TFC = ...

TFC.MainOptionTable = {
	type = "group",
	get = function(info)
        return TFC.settings[info[#info]]
    end, 
	set = function(info, value)
        TFC.settings[info[#info]] = value
		TFC.addon:refreshCallback()
		TFC.addon:countNearbyFactions()
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
		classBlips = {
			type = "group",
			name = "Class Blips",
			order = 2,
			inline = true,
			args = {
				showClasses = {
					name = "Show Class Blips",
					type = "toggle",
					width = "full",
					order = 1,
				},
				showMissing = {
					name = "Show Missing Enemies",
					desc = "Show unaccounted for enemies at the top of the map or above the counter.",
					type = "toggle",
					width = "full",
					order = 4,
				},
			}
		},

		textScale = {
			name = "Text Scale",
			type = "range",
			width = "single",
			desc = "Requires Reload",
			order = 5,
			min = 0.5,
			max = 1.5,
			step = 0.05,
		},
		blipScale = {
			name = "Blip Scale",
			type = "range",
			width = "single",
			desc = "Requires Reload to fully take effect",
			order = 6,
			min = 0.5,
			max = 1.5,
			step = 0.05,
		},
		newClassOrder = {
			name = "New Class Order",
			type = "toggle",
			desc = "Requires Reload. \n\nNew: Healing classes -> melee -> ranged -> stealth. \n\nOld: Melee -> ranged -> healing -> stealth. \n\nThe new one is closer to BGE order, but not the same.",
			width = "full",
			order = 7,
		},
		showDebug = {
			name = "Debug Mode",
			type = "toggle",
			desc = "This will spam your chat with debug messages. Only enable if you're trying to help me debug something.",
			width = "full",
			order = 8,
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
		showFrame = true,
		showOutsideInstance = true,
		frameOnBaselessMaps = false,
		showMissing = true,
		showClasses = true,
		textScale = 1,
		blipScale = 1,
		newClassOrder = false,
		showDebug = false,
	}
}

--used for class blips. Generally has melee first, ranged, healing classes, then stealth. Mostly just trying to have nice looking shading.
TFC.classOrderOld = {
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
--This is a possible order that is closer to BGE. Still different but it places healing classes first, then melee, then ranged, then stealth.
TFC.classOrderNew = {
    "PRIEST",
    "PALADIN",
    "MONK",
    "SHAMAN",
    "DEMONHUNTER",
    "WARRIOR",
    "DEATHKNIGHT",
    "MAGE",
    "WARLOCK",
    "HUNTER",
    "DRUID",
    "ROGUE",
}


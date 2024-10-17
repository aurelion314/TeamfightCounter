local addonName, addon = ...

addon.MainOptionTable = {
	type = "group",
	get = function(info)
        return addon.settings[info[#info]]
    end, 
	set = function(info, value)
        addon.settings[info[#info]] = value
		addon:refreshCallback()
		addon:countNearbyFactions()
		addon:Debug("Updated Setting", info[#info], value)
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
					width = "single",
					order = 1,
				},
				showOutsideInstance = {
					name = "Show Outside Instance",
					desc = "Show the floating frame even outside of BGs",
					disabled = function(info) return not addon.settings.showFrame end,
					type = "toggle",
					width = "single",
					order = 2,
				},
				frameOnBaselessMaps = {
					name = "Only node-less maps",
					desc = "Use floating frame instead of map based counters on maps that don't have nodes.",
					disabled = function(info) return not addon.settings.showFrame end,
					type = "toggle",
					width = "single",
					order = 3,
				},
				useSavedPosition = {
					name = "Save Position",
					desc = "Store/Configure position via addon data. Works across character. If unchecked, the frame uses WoW's default handling of position, which is per character and may reset with updates.",
					type = "toggle",
					width = "single",
					order = 4,
					set = function(info, value)
						TeamfightCounterDB.useSavedPosition = value
					end,
					get = function(info)
						return TeamfightCounterDB.useSavedPosition
					end,
				},
				lockPosition = {
					name = "Lock Position",
					type = "toggle",
					desc = "Prevent the frame from being moved by mouse.",
					width = "single",
					order = 5,
					set = function(info, value)
						TeamfightCounterDB.lockPosition = value
						_G['TeamfightCounterWindow']:EnableMouse(not value)
					end,
					get = function(info)
						return TeamfightCounterDB.lockPosition
					end,
				},
				framePosition = {
					name = "Frame Position",
					type = "group",
					inline = true,
					order = 6,
					disabled = function(info) return not addon.settings.showFrame or not TeamfightCounterDB.useSavedPosition end,
					args = {
						-- point = {
						-- 	name = "Point",
						-- 	type = "select",
						-- 	width = "single",
						-- 	order = 0,
						-- 	values = { CENTER = "Center", TOP = "Top", BOTTOM = "Bottom", LEFT = "Left", RIGHT = "Right", TOPLEFT = "Top Left", TOPRIGHT = "Top Right", BOTTOMLEFT = "Bottom Left", BOTTOMRIGHT = "Bottom Right" },
						-- 	set = function(info, value)
						-- 		TeamfightCounterDB.framePosition[1] = value
						-- 		local position = TeamfightCounterDB.framePosition;
						-- 		_G['TeamfightCounterWindow']:ClearAllPoints();
						-- 		_G['TeamfightCounterWindow']:SetPoint(position[1], 'UIParent', position[1], position[2], position[3]);
						-- 	end,
						-- 	get = function(info)
						-- 		return TeamfightCounterDB.framePosition[1]
						-- 	end,
						-- },
						x = {
							name = "X",
							type = "range",
							width = "single",
							order = 1,
							min = -1000,
							max = 1000,
							step = 1,
							set = function(info, value)
								TeamfightCounterDB.framePosition[2] = value
								local position = TeamfightCounterDB.framePosition;
								_G['TeamfightCounterWindow']:ClearAllPoints();
								_G['TeamfightCounterWindow']:SetPoint(position[1], 'UIParent', position[1], position[2], position[3]);
							end,
							get = function(info)
								return TeamfightCounterDB.framePosition[2]
							end,
						},
						y = {
							name = "Y",
							type = "range",
							width = "single",
							order = 2,
							min = -1000,
							max = 1000,
							step = 1,
							set = function(info, value)
								TeamfightCounterDB.framePosition[3] = value
								local position = TeamfightCounterDB.framePosition;
								_G['TeamfightCounterWindow']:ClearAllPoints();
								_G['TeamfightCounterWindow']:SetPoint(position[1], 'UIParent', position[1], position[2], position[3]);
							end,
							get = function(info)
								return TeamfightCounterDB.framePosition[3]
							end,
						},
						
					}
				}
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
					desc = "Class blips are the little colored circles which indicate the class of players in the fight.",
					type = "toggle",
					width = "single",
					order = 1,
				},
				showMissing = {
					name = "Show Missing Enemies",
					desc = "Show unaccounted for enemies at the top of the map or above the counter.",
					type = "toggle",
					width = "single",
					order = 4,
				},
			}
		},

		bgeIntegration = {
			type = "group",
			name = "BGE Integration",
			order = 3,
			inline = true,
			args = {
				showBGE = {
					name = "Show on BGE",
					desc = "Shows a counter next to each tracked player in BGE, helping you see which players are in or out of the fight.",
					type = "toggle",
					width = "single",
					order = 1,
				},
				testBGE = {
					name = "Test BGE",
					desc = "Show test counters in BGE. Requires BGE to have testing toggled on.",
					type = "toggle",
					width = "single",
					order = 2,
				},
				bgeXOffset = {
					name = "X Offset",
					type = "range",
					width = "single",
					order = 4,
					min = -400,
					max = 400,
					step = 1,
				},
			}
		},

		textColors = {
			type = "group",
			name = "Text Colors",
			order = 4,
			inline = true,
			args = {
				winColor = {
                    name = "Winning Color",
                    type = "color",
                    width = "single",
                    order = 6,
                    hasAlpha = true, -- Set to true if you want an alpha slider
                    set = function(info, r, g, b, a)
                        addon.settings.winColor = {r, g, b, a}
                    end,
                    get = function(info)
                        local color = addon.settings.winColor
                        return unpack(color)
                    end,
                },
				loseColor = {
					name = "Losing Color",
					type = "color",
					width = "single",
					order = 7,
					hasAlpha = true, -- Set to true if you want an alpha slider
					set = function(info, r, g, b, a)
						addon.settings.loseColor = {r, g, b, a}
					end,
					get = function(info)
						local color = addon.settings.loseColor
						return unpack(color)
					end,
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

addon.DefaultSettings = {
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
		showBGE = true,
		testBGE = false,
		bgeXOffset = 60,
		winColor = {0, 1, 0, 1},
		loseColor = {1, 0, 0, 1},
	}
}

TeamfightCounterDB = TeamfightCounterDB or {
	useSavedPosition = true,
	framePosition = { "CENTER", 0, 0 },
	lockPosition = false,
}

--used for class blips. Generally has melee first, ranged, healing classes, then stealth. Mostly just trying to have nice looking shading.
addon.classOrderOld = {
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
addon.classOrderNew = {
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


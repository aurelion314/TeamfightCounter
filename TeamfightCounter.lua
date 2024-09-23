local addonName, addon = ...
local L = addon.L
_G['TeamfightCounter'] = CreateFrame('Frame')
local addonFrame = _G['TeamfightCounter']
local TeamfightCounterWindow = _G['TeamfightCounterWindow']
local LRC = LibStub("LibRangeCheck-3.0")
local AceComm = LibStub("AceComm-3.0")
local AceEvent = LibStub("AceEvent-3.0")


addon.version = 0.1
addon.timer = 0
addon.timeSinceLastUpdate = 0
addon.texturePath = "Interface\\AddOns\\TeamfightCounter\\Textures\\"

local removedList = {}
local playerData = nil
local playerBGData = {}
local playerList = {}
local displayFrame
local counters = {}
local groups = {}
local POIList = nil
local selfPlayer = {}
local deadEnemies = {}
local missingEnemies = {}
local refreshFrames = false
local Map = nil
local flagCarriers = {}
local messageCounts = {}

--A group tracks everything about that group. The players, counter, frames, etc.
local group = {}

----------------------- SelfCounter tracks who you see
local selfCounter = {}
function selfCounter:addFrame(frame)
    if frame.fullName == nil then addon:Debug("addFrame called with no fullName") end
    if self.frames[frame.fullName] == nil then
        self.frames[frame.fullName] = frame
        self:addPlayer(frame)
    end
end

function selfCounter:removeFrame(frame)
    if frame.fullName == nil then addon:Debug("removeFrame called with no fullName") end
    if self.frames[frame.fullName] ~= nil then
        self.frames[frame.fullName] = nil
        if self.nearby[frame.fullName] == nil then
            self:removePlayer(frame)
        end
    end
end

function selfCounter:addNearbyRaidMember(player)
    if player.fullName == nil then addon:Debug("addNearbyRaidMember called with no fullName") end
    if self.nearby[player.fullName] == nil then
        self.nearby[player.fullName] = player
        self:addPlayer(player)
    end
end

function selfCounter:removeNearbyRaidMember(player)
    if player.fullName == nil then addon:Debug("removeNearbyRaidMember called with no fullName") end
    if self.nearby[player.fullName] ~= nil then
        self.nearby[player.fullName] = nil
        if self.frames[player.fullName] == nil then
            self:removePlayer(player)
        end
    end
end

function selfCounter:addPlayer(player)
    if player.fullName == nil then 
        addon:Debug("addPlayer called with no fullName") 
        return
    end
    if self.players[player.fullName] == nil then
        self.players[player.fullName] = player
        if not player.class then addon:Debug("No class for", player.fullName) end
        addon:SendMsg(player, 'add')
    end
end

function selfCounter:removePlayer(player)
    if player.fullName == nil then addon:Debug("removePlayer called with no fullName") end
    if self.players[player.fullName] ~= nil then
        self.players[player.fullName] = nil
        if not player.class then addon:Debug("No class for", player.fullName) end
        if player.isDead then
            if deadEnemies[player.fullName] == nil then
                deadEnemies[player.fullName] = GetTime()
            end
            addon:SendMsg(player, "dead")
        else
            addon:SendMsg(player, 'remove')
        end
    end
end

function selfCounter:reset()
    if self.players then
        for k, player in pairs(self.players) do
            self:removePlayer(player)
        end
    end
    addon:Debug("SelfCounter reset")
    self.players = {}
    self.frames = {}
    self.nearby = {}
end

------------------Counter tracks who each ally sees. Updated by addonMsgs
local Counter = {}
function Counter:new(name)
    addon:updateSelfPlayer()
    local obj = {}
    setmetatable(obj, self)
    self.__index = self

    obj.name = name
    obj.zone = nil
    obj.players = {}
    obj.nearby = {}
    obj.allyCount = 0
    obj.enemyCount = 0

    local counterOwner = {}
    counterOwner.fullName = addon:getFullName(name)
    local nameparts = addon.utils:splitString(name, '-')
    counterOwner.name, counterOwner.realm = nameparts[0], nameparts[1] or ""
    counterOwner.isAlly = true
    counterOwner.class = nil
    counterOwner.zone = nil
    obj.isSelfOwned = selfPlayer.fullName == counterOwner.fullName
    obj:addPlayer(counterOwner)

    return obj
end

function Counter:addPlayer(player)
    -- addon:Debug("Counter " .. self.name .. " addPlayer", player.fullName)
    if self.players[player.fullName] then
        addon:Debug("Counter " .. self.name .. " already has player", player.fullName)
        return
    end
    self.players[player.fullName] = player

    if player.isAlly then
        self.allyCount = self.allyCount + 1
    else
        self.enemyCount = self.enemyCount + 1
    end
    self.zone = player.zone
    if not playerList[player.fullName] then
        -- addon:updateGroups() --Temporarily disabling for performance
    end
end

function Counter:updatePlayer(player)
    if self.players[player.fullName] == nil then
        self:addPlayer(player)
        return
    end
    -- addon:Debug("Counter" .. self.name .. " updatePlayer", player.fullName)
    self.players[player.fullName] = player
    self.zone = player.zone
end

function Counter:removePlayer(player)
    if self.players[player.fullName] == nil then
        return
    end
    if self.players[player.fullName].isAlly then
        self.allyCount = self.allyCount - 1
    else
        self.enemyCount = self.enemyCount - 1
    end
    self.zone = player.zone

    -- addon:Debug("Counter " .. self.name .. " removePlayer", player.fullName)
    self.players[player.fullName] = nil
end

-------------------------Addon MSGs
--Send an addon message to group
-- function addon:SendMsg(frame, msgType)
--     local zone = addon:getZoneId()
--     --Fix for when player dies and returns to graveyard but their zone remains where their body is.
--     if selfPlayer['isDead'] then
--         zone = nil
--     end

--     -- addon:Debug("MSG", frame.name, frame.realm, frame.class)

--     local msg = addon.version .. ";" .. msgType .. ";" .. frame['fullName'] .. ";" .. (frame['isAlly'] and '1' or '0') .. ";" .. frame['class'] .. ";" .. (zone or "") 
--     if (select(2, IsInInstance()) == "pvp") then
--         C_ChatInfo.SendAddonMessage("TFC", msg, "INSTANCE_CHAT")
--     else
--         C_ChatInfo.SendAddonMessage("TFC", msg, "WHISPER", UnitName('player'))
--     end
--     -- addon:Debug("SendAddonMSG:",msg)
-- end

-- function addon:SendMsg(frame, msgType)
--     local zone = addon:getZoneId()
--     if selfPlayer['isDead'] then
--         zone = nil
--     end

--     local msg = addon.version .. ";" .. msgType .. ";" .. frame['fullName'] .. ";" .. (frame['isAlly'] and '1' or '0') .. ";" .. frame['class'] .. ";" .. (zone or "")

--     local distribution
--     local target

--     local inInstance, instanceType = IsInInstance()
--     if inInstance and (instanceType == "pvp" or instanceType == "arena") then
--         distribution = "INSTANCE_CHAT"
--     else
--         distribution = "WHISPER"
--         target = UnitName('player')
--     end

--     addon:SendCommMessage("TFC", msg, distribution, target)
--     addon:Debug("SendCommMessage:", msgType, frame.fullName)
-- end


-- function addon:DecodeMsg(msg)
--     local data = addon.utils:splitString(msg, ';')

--     local msgType, player, version = '', {}, nil
--     version, msgType, player['fullName'], player['isAlly'], player['class'], player['zone'] = data[1], data[2], data[3], data[4], data[5], data[6]
--     player['isAlly'] = (player['isAlly'] == '1') and true or false
--     if not player['zone'] or player['zone'] == "" then
--         player['zone'] = nil
--     else
--         player['zone'] = addon:getZoneId(player['zone'])
--     end
--     player['fullName'] = addon:getFullName(player['fullName'])

--     return msgType, player
-- end

-- Define mapping tables for msgType and class
local msgTypeCodes = {
    update = '1',
    add = '2',
    remove = '3',
    dead = '4',
}

local msgTypeCodesReverse = {
    ['1'] = 'update',
    ['2'] = 'add',
    ['3'] = 'remove',
    ['4'] = 'dead',
}

local classCodes = {
    WARRIOR = '1',
    PALADIN = '2',
    HUNTER = '3',
    ROGUE = '4',
    PRIEST = '5',
    DEATHKNIGHT = '6',
    SHAMAN = '7',
    MAGE = '8',
    WARLOCK = '9',
    MONK = '10',
    DRUID = '11',
    DEMONHUNTER = '12',
    EVOKER = '13',
}

local classCodesReverse = {}
for k, v in pairs(classCodes) do
    classCodesReverse[v] = k
end

-- Updated SendMsg function
function addon:SendMsg(frame, msgType)
    local zone = addon:getZoneId()
    if selfPlayer['isDead'] then
        zone = nil
    end

    -- Use version '2' for the new encoding
    local version = '2'

    -- Encode msgType and class
    local msgTypeCode = msgTypeCodes[msgType] or msgType
    local classCode = classCodes[frame['class']] or frame['class']
    local isAllyCode = frame['isAlly'] and '1' or '0'
    local zoneCode = zone or ""

    -- Construct the message with encoded fields
    local msg = table.concat({version, msgTypeCode, frame['fullName'], isAllyCode, classCode, zoneCode}, ";")

    local distribution
    local target
    local prio = "ALERT"

    local inInstance, instanceType = IsInInstance()
    if inInstance and (instanceType == "pvp" or instanceType == "arena") then
        distribution = "INSTANCE_CHAT"
    else
        distribution = "WHISPER"
        target = UnitName('player')
    end

    addon:SendCommMessage("TFC", msg, distribution, target, prio)
    messageCounts['sent'] = (messageCounts['sent'] or 0) + 1
    addon:Debug("SendCommMessage:", msgType, frame.fullName)
end

-- Updated DecodeMsg function
function addon:DecodeMsg(msg)
    local data = addon.utils:splitString(msg, ';')

    local version = data[1]
    local msgType, player = '', {}

    if not tonumber(version) then
        -- Old version, adjust indexes
        version = nil
        msgType = data[1]
        player['fullName'] = data[2]
        player['isAlly'] = data[3]
        player['class'] = data[4]
        player['zone'] = data[5]
    else
        msgType = data[2]
        player['fullName'] = data[3]
        player['isAlly'] = data[4]
        player['class'] = data[5]
        player['zone'] = data[6]
    end

    player['isAlly'] = (player['isAlly'] == '1')
    if not player['zone'] or player['zone'] == "" then
        player['zone'] = nil
    else
        player['zone'] = addon:getZoneId(player['zone'])
    end
    player['fullName'] = addon:getFullName(player['fullName'])

    -- Decode msgType and class if version >= 2
    if version and tonumber(version) >= 2 then
        msgType = msgTypeCodesReverse[msgType] or msgType
        player['class'] = classCodesReverse[player['class']] or player['class']
    end

    return msgType, player
end


--------------------------------------------

--Converts zone to numberic zone ID if zone is passed. Otherwise return current players zone ID.
function addon:getZoneId(zone)
    if zone == nil then
        addon:refreshMap()
        zone = GetSubZoneText()
    end
    if tonumber(zone) then return tonumber(zone) end
    POIList = addon:getPOIs()
    if POIList[zone] then
        return tonumber(POIList[zone]['id'])
    end
    return nil
end

function addon:updateSelfPlayer(force)
    local doUpdate = false
    local player = { fullName = addon:getFullName(GetUnitName('player') .. '-' .. (GetRealmName() or "")), name = GetUnitName('player'), realm = GetRealmName(), isAlly = true }
    player['class'] = select(2, UnitClass('player'))
    player['isDead'] = UnitIsDeadOrGhost('player')

    --check if any data about player has changed
    if force or not selfPlayer then
        doUpdate = true
    else
        for k, v in pairs(player) do
            if selfPlayer[k] ~= v then
                doUpdate = true
                break
            end
        end
    end

    if doUpdate then
        local updateType = player['isDead'] and 'remove' or 'update'
        addon:Debug('Self Update', player.fullName, player.isDead, player.class, updateType)
        selfPlayer = player
        addon:SendMsg(player, updateType)
    end
end

-- Update groups based on all player counters. Groups become the teamfight counts.
function addon:updateGroups()
    local next = next
    --Make a list of remaining counters that we can modify on the fly
    local remainingCounters = {}
    for i, counter in pairs(counters) do
        if next(counter.players) ~= nil then
            table.insert(remainingCounters, counter)
        end
    end

    --Ensure we have up to date player data for full BG. Needed for enemy class tracking
    addon:getBattlegroundPlayerData()
    missingEnemies = {}
    for i, player in pairs(playerData.enemy) do
        if deadEnemies[player.fullName] == nil then
            missingEnemies[player.fullName] = player
        end
    end

    if next(remainingCounters) == nil then
        -- addon:Debug('No counters')
        addon:cleanGroupFrames('frame', true)
        addon:cleanGroupFrames('map', true)
        groups = {}
        return
    end

    --First off, clear groups and populate with the first counter
    groups = { addon.utils:deepCopy(table.remove(remainingCounters, 1)) }
    --Keep checking counters until we remove all of them
    while next(remainingCounters) ~= nil do
        for i, group in pairs(groups) do
            --loop all counters and see if one can be added to a group.
            local stop = false
            while not stop do
                stop = true
                for j, counter in pairs(remainingCounters) do
                    --check if any players in counter are in group
                    if addon:hasOverlap(group, counter) then
                        for k, player in pairs(counter.players) do
                            group:addPlayer(player)
                        end
                        if counter.zone then
                            group.zone = counter.zone
                        end
                        if counter.isSelfOwned then
                            group.isSelfOwned = true
                        end
                        table.remove(remainingCounters, j)
                        stop = false
                    end
                end
            end

        end
        --do we have any counters left?
        if next(remainingCounters) ~= nil then
            --we went through all groups already, so now make a new group for the remaining counters
            table.insert(groups, addon.utils:deepCopy(table.remove(remainingCounters, 1)))
        end
    end

    --Build player list and update missing enemies.
    playerList = {}
    flagCarriers.groups = {}
    for i, group in pairs(groups) do
        group['id'] = i
        group['flagCarriers'] = {}
        -- loop players in group and check zone
        for j, player in pairs(group.players) do
            if flagCarriers[player.fullName] ~= nil then
                --track flag carriers
                if group.zone == nil then
                    group.zone = 'Flag' --flagCarriers[player.fullName]
                end
                group.flagCarriers[player.fullName] = flagCarriers[player.fullName]
                --track flag carriers in flagCarriers.groups
                flagCarriers['groups'][i] = group
            end
                
            playerList[player.fullName] = true
            --remove from remaining enemy
            if missingEnemies[player.fullName] then
                missingEnemies[player.fullName] = nil
            end
        end
    end

    --Now that we have the group teamfight counts, render them to screen
    addon:showGroups()
    addon:showGroupsOnMap()

    -- Update BGE with group counts
    addon:updateBGE()
end

function addon:updateBGE()
    -- Access the BattlegroundEnemies addon
    local battlegroundEnemies = _G['BattleGroundEnemies']
    local enemyMainFrame = battlegroundEnemies and battlegroundEnemies['Enemies']
    if not enemyMainFrame then
        -- BGE is not loaded or not in a battleground
        return
    end

    if not addon.settings.showBGE then
        -- BGE integration is disabled. Ensure frame is hidden.
        for playerName, playerButton in pairs(enemyMainFrame.Players) do
            if playerButton.groupTextFrame then
                playerButton.groupTextFrame:Hide()
            end
        end
        return
    end

    local groups = groups
    if addon.settings.testBGE then
        -- Testing: Add some test groups
        groups = {
            {
                allyCount = 3,
                enemyCount = 2,
                players = {
                    ["PlayerOne-RealmName"] = true,
                    ["Enemy2-Realm2"] = true,
                },
            },
            {
                allyCount = 1,
                enemyCount = 1,
                players = {
                    ["Enemy1-Realm1"] = true,
                },
            },
            {
                allyCount = 1,
                enemyCount = 4,
                players = {
                    ["Enemy3-Realm3"] = true,
                },
            },
        }
    end

    -- Loop over all enemy players in BGE
    for playerName, playerButton in pairs(enemyMainFrame.Players) do
        -- Check if this player is in any of our groups
        local groupFound = false
        for _, group in pairs(groups) do
            if group.players[playerName] then
                groupFound = true
                -- Create or update the text next to the player
                if not playerButton.groupTextFrame then
                    addon:makeBGEFrame(playerButton)
                end
                -- Position the text within the groupTextFrame
                playerButton.groupTextFrame:SetPoint('LEFT', playerButton, 'RIGHT', addon.settings.bgeXOffset, 0)
                
                -- Set the group count text
                local text = group.allyCount .. "v" .. group.enemyCount
                playerButton.groupText:SetText(text)
                -- Set the color green or red depending on ally vs enemy
                if group.allyCount > group.enemyCount then
                    playerButton.groupText:SetTextColor(unpack(addon.settings.winColor))
                elseif group.allyCount < group.enemyCount then
                    playerButton.groupText:SetTextColor(unpack(addon.settings.loseColor))
                else
                    playerButton.groupText:SetTextColor(1, 1, 1, 1) -- White
                end

                -- Show Frame
                playerButton.groupTextFrame:Show()
                break -- No need to check other groups
            end
        end
        -- If the player is not in any group, remove any existing text
        if not groupFound and playerButton.groupTextFrame then
            playerButton.groupTextFrame:Hide()
        end
    end
end

function addon:makeBGEFrame(playerButton)
    -- Create a new Frame attached to playerButton with BackdropTemplate
    playerButton.groupTextFrame = CreateFrame('Frame', nil, playerButton, 'BackdropTemplate')
    -- Set frame strata and level higher than the playerButton
    playerButton.groupTextFrame:SetFrameStrata(playerButton:GetFrameStrata())
    playerButton.groupTextFrame:SetFrameLevel(playerButton:GetFrameLevel() + 10) -- Ensure it's above other elements

    -- Set size for the frame
    playerButton.groupTextFrame:SetSize(50, 20) -- Adjust width and height as needed

    -- Position the groupTextFrame relative to the playerButton
    playerButton.groupTextFrame:SetPoint('LEFT', playerButton, 'RIGHT', 0, 0)

    -- Create the FontString attached to the new frame
    playerButton.groupText = playerButton.groupTextFrame:CreateFontString(nil, 'OVERLAY', 'GameFontNormal')
    -- Position the text within the groupTextFrame
    playerButton.groupText:SetPoint('CENTER', playerButton.groupTextFrame, 'CENTER', 0, 0)

    -- Set the backdrop to add a background and border
    playerButton.groupTextFrame:SetBackdrop({
        bgFile = "Interface\\ChatFrame\\ChatFrameBackground", -- Simple background texture
        edgeFile = "Interface\\Tooltips\\UI-Tooltip-Border",  -- Default UI border texture
        tile = false,
        tileSize = 16,
        edgeSize = 16,
        insets = { left = 4, right = 4, top = 4, bottom = 4 }
    })
    -- Set backdrop color (background) and border color
    playerButton.groupTextFrame:SetBackdropColor(0, 0, 0, 0.9)         -- Semi-transparent black background
    playerButton.groupTextFrame:SetBackdropBorderColor(1, 1, 1, 1)     -- Solid white border
end


function addon:showMissingEnemies()
    if displayFrame['missingEnemyFrame'] == nil then
        displayFrame['missingEnemyFrame'] = CreateFrame("Frame", 'missingEnemyFrame', displayFrame)
        displayFrame['missingEnemyFrame']:SetPoint("CENTER", displayFrame:GetName(), "TOP", 0, 0)
        displayFrame['missingEnemyFrame']:SetWidth(50)
        displayFrame['missingEnemyFrame']:SetHeight(10)
    end

    if addon.settings.showMissing then
        displayFrame['missingEnemyFrame']:Show()
    else
        displayFrame['missingEnemyFrame']:Hide()
        return
    end

    addon:showClassBlips({ players = missingEnemies }, displayFrame['missingEnemyFrame'], 'missing')
end

function addon:showMissingEnemiesOnMap()
    if _G['missingEnemyMapFrame'] == nil then
        _G['missingEnemyMapFrame'] = CreateFrame("Frame", 'missingEnemyMapFrame', _G['missingEnemyMapFrame'])
        _G['missingEnemyMapFrame']:SetFrameLevel(16)
        _G['missingEnemyMapFrame']:SetWidth(50)
        _G['missingEnemyMapFrame']:SetHeight(10)
        _G['missingEnemyMapFrame']:SetPoint("CENTER", 'REPorterFrame', "TOP", 0, -5)
    end

    if addon.settings.showMissing then
        _G['missingEnemyMapFrame']:Show()
    else
        _G['missingEnemyMapFrame']:Hide()
        return
    end

    addon:showClassBlips({ players = missingEnemies }, _G['missingEnemyMapFrame'], 'missing')
end

function addon:showGroups()
    addon:cleanGroupFrames('frame')

    local height = -30
    local blipWidth = 6
    -- for i, group in pairs(groups) do
    for i, group in addon.utils:spairs(groups, function(t, a, b) return t[a].isSelfOwned end) do
        -- addon:Debug('Showing group', i)
        local msg = ""
        msg = msg .. group.allyCount .. "v" .. group.enemyCount .. ""
        local xMain, yMain = 0, -15 + (i - 1) * height
        if displayFrame['displayGroup' .. i] == nil then

            displayFrame['displayGroup' .. i] = CreateFrame("Frame", 'TFCGroupCounter' .. i, displayFrame)
            displayFrame['displayGroup' .. i]:SetPoint("CENTER", displayFrame:GetName(), "TOP", xMain, yMain)
            displayFrame['displayGroup' .. i]:SetWidth(50)
            displayFrame['displayGroup' .. i]:SetHeight(height)
            local groupCounterFrame = displayFrame['displayGroup' .. i]

            if groupCounterFrame['groupText'] == nil then
                groupCounterFrame['groupText'] = groupCounterFrame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
            end
            local groupText = groupCounterFrame['groupText']
            groupText:SetPoint("CENTER", 0, 0)
            groupText:SetTextColor(0.5, 0.5, 0.5, 1)
            groupText:SetText('1v0')
        end
        local groupCounterFrame = displayFrame['displayGroup' .. i]
        local groupText = groupCounterFrame['groupText']
        groupText:SetFont("Fonts\\FRIZQT__.TTF", 14*addon.settings.textScale, "OUTLINE")
        --set color depending on ally vs enemy
        if group.allyCount > group.enemyCount then
            groupText:SetTextColor(unpack(addon.settings.winColor))
        elseif group.allyCount < group.enemyCount then
            groupText:SetTextColor(unpack(addon.settings.loseColor))
        else
            groupText:SetTextColor(0.5, 0.5, 0.5, 1)
        end
        groupText:SetText(msg)
        groupCounterFrame:Show()

        addon:showClassBlips(group, groupCounterFrame)
    end
    addon:showMissingEnemies()
end

function addon:showGroupsOnMap()
    addon:cleanGroupFrames('map')

    --have they selected to only use on node maps?
    if addon.settings.showFrame and addon.settings.frameOnBaselessMaps then
        --is this map nodeless?
        addon:getPOIs()
        if not POIList or next(POIList) == nil then return end
    end

    if _G['REPorterFrame'] == nil or not _G['REPorterFrame']:IsShown() then
        -- addon:Debug('Debug: ReporterFrame not available')
        return
    end
    local topFrames = {}
    -- for i, group in pairs(groups) do
    for i, group in addon.utils:spairs(groups, function(t, a, b) return t[a].isSelfOwned end) do
        if group.zone then
            local x, y = addon:getGroupPosition(group)
            -- addon:Debug('Group has zone:', group.zone, x, y)
            local result = addon:showGroupOnMap(group, x, y, 'REPorterFrameCorePOI')
        else
            -- addon:Debug('Group no zone:', group.zone, x, y)
            table.insert(topFrames, group)
        end
    end
    local topCount, width, height = #topFrames, 35, 15
    local xStart                  = width - topCount * width
    local yStart                  = -20
    for i, group in pairs(topFrames) do
        -- local x = xStart + (i - 1) * width
        -- local y = -25
        local x = 0
        local y = yStart - (i - 1) * height
        addon:showGroupOnMap(group, x, y, 'REPorterFrame')
    end
    addon:showMissingEnemiesOnMap()
end

function addon:showGroupOnMap(group, x, y, parentFrameName)
    local fontSize = group.zone and 16 or 12
    local alpha = group.zone and 1 or 0.75
    local frameName = "TFCGroupFrame" .. parentFrameName .. group['id']
    group.frameName, group.parentFrameName = frameName, parentFrameName
    if _G[frameName] == nil then
        local frameMain = CreateFrame("Frame", frameName, _G[parentFrameName])
        frameMain:SetFrameLevel(16) --was 10
        frameMain:SetWidth(50)
        frameMain:SetHeight(50)
        _G[frameName] = frameMain
    end
    local frameMain = _G[frameName]
    if parentFrameName == 'REPorterFrame' then
        --Show at top of map
        frameMain:SetPoint("CENTER", parentFrameName, "TOP", x, y)
    else
        --Show at base or flag position.
        -- addon:Debug('ShowGroupOnMap: ', x, y, frameName, parentFrameName)
        frameMain:SetPoint("CENTER", parentFrameName, "TOPLEFT", x, y)
    end
    frameMain:Show()

    local textName = "TFCGroupText" .. group['id']
    if frameMain[textName] == nil then
        local frameText = frameMain:CreateFontString(nil, nil, nil)
        frameText:SetFont("Fonts\\FRIZQT__.TTF", fontSize*addon.settings.textScale, "OUTLINE")
        frameText:SetPoint("CENTER", 0, 0)
        frameMain[textName] = frameText
    end
    local frameText = frameMain[textName]
    local msg = group.allyCount .. "v" .. group.enemyCount
    frameText:SetText(msg)
    if group.allyCount > group.enemyCount then
        frameText:SetTextColor(0, 1, 0, alpha)
    elseif group.allyCount < group.enemyCount then
        frameText:SetTextColor(1, 0, 0, alpha)
    else
        frameText:SetTextColor(0.5, 0.5, 0.5, alpha)
    end

    addon:showClassBlips(group, frameMain, group.zone and 'enemy' or nil)
end

function addon:showClassBlips(group, parentFrame, reaction)
    --first clear all blips
    if parentFrame['blips'] == nil then
        parentFrame['blips'] = {}
    end
    for i, blip in pairs(parentFrame.blips) do
        blip:Hide()
    end

    if not addon.settings.showClasses and reaction ~= 'missing' then
        return
    end

    local ally, enemy = {}, {}
    if reaction ~= "missing" then
        for i, player in pairs(group.players) do
            if player.isAlly then
                table.insert(ally, player)
            else
                table.insert(enemy, player)
            end
        end
    end

    local x, y
    local blipWidth = 6*addon.settings.blipScale
    if not reaction or reaction == 'ally' then
        local playerNum = 1
        for i, player in addon.utils:spairs(ally, function(t, a, b) return (addon.classOrder[t[b].class] or 0) < (addon.classOrder[t[a].class] or 0) end) do
            if player.class then
                playerNum = playerNum + 1
                x, y = (-15) - blipWidth * playerNum, 0
                addon:showClassBlip(parentFrame, player, x, y, 'ally', playerNum)
            end
        end
    end
    if not reaction or reaction == 'enemy' then
        local playerNum = 1
        for i, player in addon.utils:spairs(enemy, function(t, a, b) return (addon.classOrder[t[b].class] or 0) < (addon.classOrder[t[a].class] or 0) end) do
            if player.class then
                playerNum = playerNum + 1
                x, y = (13) + blipWidth * playerNum, 0
                addon:showClassBlip(parentFrame, player, x, y, 'enemy', playerNum)
            end
        end
    end
    if reaction and reaction == 'missing' then
        local playerNum = 0
        --counter number of players
        local playerCount = 0
        for i, player in pairs(group.players) do
            if player.class then
                playerCount = playerCount + 1
            end
        end
        for i, player in addon.utils:spairs(group.players, function(t, a, b) return (addon.classOrder[t[b].class] or 0) < (addon.classOrder[t[a].class] or 0) end) do
            if player.class then
                playerNum = playerNum + 1
                x, y = -(blipWidth * (playerCount + 1)) / 2 + blipWidth * playerNum, 0
                addon:showClassBlip(parentFrame, player, x, y, 'enemy', playerNum, "BlipCombat")
            end
        end
    end
end

function addon:showClassBlip(parentFrame, player, x, y, faction, playerNum, texture)
    local textureName = "TFCBlipTexture" .. faction .. playerNum
    if parentFrame.blips[textureName] == nil then
        parentFrame.blips[textureName] = parentFrame:CreateTexture("TFCBlipTexture" .. parentFrame:GetName() .. faction .. playerNum)
        if not texture then
            parentFrame.blips[textureName]:SetTexture(addon.texturePath .. "BlipNormal")
        else
            parentFrame.blips[textureName]:SetTexture(addon.texturePath .. texture)
        end
        parentFrame.blips[textureName]:SetWidth(10*addon.settings.blipScale)
        parentFrame.blips[textureName]:SetHeight(10*addon.settings.blipScale)
    end
    local texture = parentFrame.blips[textureName]
    texture:SetPoint("CENTER", parentFrame, x, y)
    local r, g, b = GetClassColor(player.class)
    texture:SetVertexColor(r, g, b, 0.7)
    texture:Show()
    parentFrame.blips[textureName] = texture
end

function addon:getGroupPosition(group)
    --check zone of group. Loop players and select first zone
    addon:refreshMap()
    local verticalOffset = 0.04
    local zone = group.zone
    local flagTextures = {['Horde Flag']= 137218, ['Alliance Flag']= 137200, ['Orange Orb']=137200, ['Flag']=137200}
    
    if zone then
        --Flags
        if flagTextures[zone] ~= nil then
            --loop Flag carriers
            local desiredFlagTexture = nil
            for flagCarrier, flagType in pairs(group.flagCarriers) do
                --debug
                addon:Debug("Flag carrier: " .. flagCarrier .. " flagType: " .. flagType)
                if flagTextures[flagType] ~= nil then
                    desiredFlagTexture = flagTextures[flagType]
                end
            end    
            
            for i = 1, 4 do
                local x, y, flagTexture = C_PvP.GetBattlefieldFlagPosition(i, Map)
                if desiredFlagTexture == flagTexture then
                    if x == nil or y == nil then
                        addon:Debug("Flag possition is nil: ", zone, x, y, flagTexture)
                        break
                    end
                    addon:Debug("Flag possition (GroupUpdate): ", x, y, flagTexture)
                    return addon:getRealCoords(x, y - verticalOffset)
                end
            end
        end
        --Bases
        addon:getPOIs()
        local POIinfo = POIList[zone]
        if POIinfo then
            local x, y = POIinfo.position:GetXY()
            return addon:getRealCoords(x, y - verticalOffset)
        end
    end

    return nil, nil
end

function addon:updateFlagPosition()
    local map = addon:refreshMap()
    if map ~= 1339 and map ~= 206 then
        return
    end
    if flagCarriers.groups == nil then
        return
    end
    
    --First check flag positions
    local hordeFlagTexture, allianceFlagTexture = 137218, 137200
    local hordeFlags, allianceFlags = {}, {}
    for i = 1, 4 do
        local x, y, flagTexture = C_PvP.GetBattlefieldFlagPosition(i, map)
        
        if flagTexture == hordeFlagTexture and x ~= nil and y~=nil then
            table.insert(hordeFlags, {['x']=x, ['y']=y})
        elseif flagTexture == allianceFlagTexture and x ~= nil and y~=nil then
            table.insert(allianceFlags, {['x']=x, ['y']=y})
        end
    end

    --I need to know which groups have flags, how many flags, and who has them (faction).
    for group_id, group in pairs(flagCarriers.groups) do
        local frameName = group.frameName
        local frameMain = _G[frameName]
        local parentFrameName = group.parentFrameName
        
        --If its showing at top, don't update.
        if parentFrameName ~= 'REPorterFrame' then
            local x, y = 0, 0
            local flagCount = 0
            for playerName, flagType in pairs(group.flagCarriers) do
                --get the position of flags
                if flagType == 'Horde Flag' and #hordeFlags > 0 then
                    x = x + hordeFlags[1].x
                    y = y + hordeFlags[1].y
                    flagCount = flagCount + 1
                elseif flagType == 'Alliance Flag' and #allianceFlags > 0 then
                    x = x + allianceFlags[1].x
                    y = y + allianceFlags[1].y
                    flagCount = flagCount + 1
                end
            end
            if flagCount ~= 0 then
                x = x / flagCount
                y = y / flagCount
                
                --now update group positions.
                x, y = addon:getRealCoords(x, y - 0.04)
                frameMain:SetPoint("CENTER", parentFrameName, "TOPLEFT", x, y)
            else
            end
        end
    end

end

--Copied from REPorter. Converts co-ordinates to values used by the map
function addon:getRealCoords(rawX, rawY)
    return rawX * 783, -rawY * 522
end

function addon:cleanGroupFrames(groupType, excludeEnemyBlips)
    for i = 1, 10 do
        if groupType == 'map' then
            if _G['TFCGroupFrame' .. 'REPorterFrame' .. i] then _G['TFCGroupFrame' .. 'REPorterFrame' .. i]:Hide() end
            if _G['TFCGroupFrame' .. 'REPorterFrameCorePOI' .. i] then _G['TFCGroupFrame' .. 'REPorterFrameCorePOI' .. i]:Hide() end
        elseif groupType == 'frame' then
            if displayFrame['displayGroup' .. i] then displayFrame['displayGroup' .. i]:Hide() end
        end
    end
    --Hide enemy blips below, but only if we need to.
    if excludeEnemyBlips then 
        return 
    else 
        if groupType == 'frame' and displayFrame['missingEnemyFrame'] then
            displayFrame['missingEnemyFrame']:Hide()
        end
        if groupType == 'map' and _G['missingEnemyMapFrame'] then
            _G['missingEnemyMapFrame']:Hide()
        end
    end
end

--Gets points of interest for the map. These are the bases.
function addon:getPOIs(refresh)
    if not (select(2, IsInInstance()) == "pvp") then POIList = {} return {} end
    if refresh or (POIList == nil) then
        addon:Debug("Loading POIs")
        if Map == nil then
            addon:refreshMap()
            if Map == nil then
                addon:Debug("No Map")
                return {}
            end
        end
        local POIs = C_AreaPoiInfo.GetAreaPOIForMap(Map)
        POIList = {}
        for i, id in pairs(POIs) do
            local info = C_AreaPoiInfo.GetAreaPOIInfo(Map, id)
            addon:Debug('(POI):', id, info.name, info.position:GetXY())
            info = { ['name'] = info.name, ['id'] = id, ['position'] = info.position }
            POIList[info.name], POIList[id] = info, info
        end
    end
    return POIList
end

--Checks if 2 allies are in the same teamfight.
function addon:hasOverlap(counter1, counter2)
    --if counter zone is the same, always group.
    if counter1.zone and counter2.zone and counter1.zone == counter2.zone then
        return true
    end
    local groupPlayers = {}
    for i, player in pairs(counter1.players) do
        groupPlayers[player.fullName] = true
    end
    for i, player in pairs(counter2.players) do
        if groupPlayers[player.fullName] then
            return true
        end
    end
end

--Checks for allies nearby using raid units.
function addon:checkNearbyAlly()
    -- addon:Debug('Checking nearby allies')
    --check if in instance
    if not IsInInstance() then
        return
    end

    --loop all raid members and check if they are in interact range
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        local player = addon:getUnitDetails(unit)
        if player then
            if addon:inRangeAlly(unit) and not UnitIsDeadOrGhost(unit) then
                selfCounter:addNearbyRaidMember(player)
            else
                selfCounter:removeNearbyRaidMember(player)
            end
        end
    end
end

function addon:inRange(unit)
    -- Are we out of combat?
    local checker, range = LRC["GetHarmMaxChecker"](LRC, 40, true)
    if checker then
        return checker(unit)
    end

    return nil

    -- return IsItemInRange(132511, unit) == 1
    -- if UnitAffectingCombat("player") then
    --     return nil
    -- end
    -- return CheckInteractDistance(unit, 4)
end

function addon:inRangeAlly(unit)
    local checker, range = LRC["GetFriendMaxChecker"](LRC, 40, true)
    if checker then
        return checker(unit)
    end
    return nil
end


function addon:getUnitDetails(unit)
    if not UnitIsPlayer(unit) then
        return
    end

    local details = {}
    details['fullName'] = addon:getFullName(unit, true)
    details["name"], details["realm"] = UnitName(unit)
    details["reaction"] = UnitReaction(unit, "player")
    -- details["isAlly"] = details["reaction"] and (details["reaction"] > 4) or nil
    details["isAlly"] = not UnitIsEnemy("player", unit)
    details["isPlayer"] = UnitIsPlayer(unit)
    details["class"] = select(2, UnitClass(unit))
    details["isClose"] = addon:inRange(unit)
    details["isTarget"] = UnitIsUnit(unit, 'target')
    details["isDead"] = UnitIsDeadOrGhost(unit)
    details["unit"] = unit

    --Reaction can be weird when the player is dead. Thus we must use BG data not the reaction API. The reason we don't always do this is because the floating frame can be used outside BGs where we don't have such data.
    if selfPlayer['isDead'] then
        --check if in pvp
        if not (select(2, IsInInstance()) == "pvp") then
            return nil
        end
        if playerData[details['fullName']] then
            details['isAlly'] = playerData[details['fullName']]['isAlly']
        end
        -- addon:Debug('Self is dead, unit data:', details['fullName'], playerData[details['fullName']]['faction'], 'isAlly:', details['isAlly'])
    end

    --For some reason we get an occasional plate with an 'unknown' name. Filter those out.
    if details['name'] == L['Unknown'] or not details['fullName'] then
        refreshFrames = true
        return nil
    end

    return details
end

function addon:getFullName(fullName, isUnitTag)
    if not fullName or UnitIsPlayer(fullName) or isUnitTag then
        local name, realm = UnitName(fullName)
        if not name then
            addon:Debug("Fullname failed, no name:", fullName, isUnitTag)
            return nil
        end
        fullName = name .. '-' .. (realm or "")
    end

    local parts = addon.utils:splitString(fullName, '-')
    if parts[2] == nil or parts[2] == "" then
        local realm = GetRealmName()
        fullName = fullName .. realm
    end
    return string.gsub(fullName, "%s+", "")
end

function addon:refreshMap(force)
    if Map == nil or force and not select(1, IsActiveBattlefieldArena()) then
        addon:Debug("Setting Map")
        Map = C_Map.GetBestMapForUnit("player")
    end
    return Map
end

function addon:getBattlegroundPlayerData(force)
    local BFNumScores = GetNumBattlefieldScores()
    if (playerData and playerData.count == BFNumScores) and not force then return playerData end
    playerData = { ally = {}, enemy = {}, count = 0 }
    if not (select(2, IsInInstance()) == "pvp") then return playerData end

    local selfPlayerFaction = UnitFactionGroup('player')
    addon:Debug('Battlefield player scores:', BFNumScores)
    for i = 1, BFNumScores do
        local player = {}
        player.fullName, _, _, _, _, player.factionId, player.race, _, player.class, _, _, _, _, _, player.specName = GetBattlefieldScore(i)
        if player.fullName then
            player.fullName             = addon:getFullName(player.fullName)
            player.faction              = player.factionId == 1 and 'Alliance' or 'Horde'
            player.isAlly               = (player.faction == selfPlayerFaction)
            player.allegiance           = player.isAlly and 'ally' or 'enemy'
            
            playerData[player.fullName] = player
            playerData[player.allegiance][player.fullName] = player
            playerData.count = playerData.count + 1
        else
            addon:Debug('No BFScore data:', i, player.fullName, player.factionId, player.faction, player.race, player.class, player.specName)
        end
    end

    return playerData
end

--------------------EVENTS-------------------

-- function addon:CHAT_MSG_ADDON(...)
--     addon:OnEvent(...)
-- end

-- function addon:CHAT_MSG_ADDON(prefix, msg, channel, sender)
--     if prefix == "TFC" then
--         sender = addon:getFullName(sender)
--         -- addon:Debug(prefix, msg, channel, sender)

--         local msgType, player = addon:DecodeMsg(msg)

--         if not counters[sender] then
--             counters[sender] = Counter:new(sender)
--         end

--         if msgType == "add" then
--             counters[sender]:addPlayer(player)
--         elseif msgType == "remove" then
--             counters[sender]:removePlayer(player)
--         elseif msgType == "update" then
--             addon:Debug('Updating player:', player.fullName)
--             counters[sender]:updatePlayer(player)
--         elseif msgType == "dead" then
--             counters[sender]:removePlayer(player)
--             if deadEnemies[player.fullName] == nil then
--                 deadEnemies[player.fullName] = GetTime()
--             end
--         end

--         addon:refreshCallback()
--     end
-- end

function addon:OnCommReceived(prefix, msg, distribution, sender)
    if prefix == "TFC" then
        sender = addon:getFullName(sender)
        
        local msgType, player = addon:DecodeMsg(msg)
        messageCounts['received'] = (messageCounts['received'] or 0) + 1
        addon:Debug("ReceiveCommMessage:", msgType, player.fullName)

        if not counters[sender] then
            counters[sender] = Counter:new(sender)
        end

        if msgType == "add" then
            counters[sender]:addPlayer(player)
        elseif msgType == "remove" then
            counters[sender]:removePlayer(player)
        elseif msgType == "update" then
            addon:Debug('Updating player:', player.fullName)
            counters[sender]:updatePlayer(player)
        elseif msgType == "dead" then
            counters[sender]:removePlayer(player)
            if deadEnemies[player.fullName] == nil then
                deadEnemies[player.fullName] = GetTime()
            end
        end

        addon:refreshCallback()
    end
end

function addon:ZONE_CHANGED_NEW_AREA()
    --clear all counters
    addon:Debug('Zone Area Changed')
    POIList = nil
    addon:refreshMap(true)
    addon:getBattlegroundPlayerData(true)
    removedList = {}
    flagCarriers = {}

    addon:resetCounters()

    addon:countNearbyFactions()
end

function addon:ZONE_CHANGED()
    addon:Debug('Zone Changed:', GetSubZoneText())
    addon:updateSelfPlayer(true)
end

function addon:NAME_PLATE_UNIT_ADDED(unit)
    -- addon:Debug('Frame Added', unit, addon:getFullName(unit))
    if not UnitExists(unit) or UnitIsUnit(unit, 'player') or UnitIsDeadOrGhost('player') then return end
    local frame = addon:getUnitDetails(unit)

    --Ignore in these cases
    if not frame or (frame['isTarget'] and not frame['isClose']) or frame['isDead'] or frame['isAlly'] == nil then return end

    -- addon:Debug('Adding', unit, frame.fullName)
    selfCounter:addFrame(frame)
    --Reset removal timer if they had previously dropped from our vision.
    removedList[frame.fullName] = nil

    addon:countNearbyFactions()
end

function addon:NAME_PLATE_UNIT_REMOVED(unit)
    -- addon:Debug('Frame Removed', unit, addon:getFullName(unit))
    if UnitIsUnit(unit, 'player') then return end

    local frame = addon:getUnitDetails(unit)
    if not frame then return end
    --If the unit is dead, remove from list immediately
    if frame['isDead'] or UnitIsDeadOrGhost('player') then
        selfCounter:removeFrame(frame)
        addon:countNearbyFactions()
    else
        --if alive, set a callback to remove it in a few seconds.
        removedList[frame.fullName] = GetTime()
        C_Timer.After(3, function() addon:removedCallback() end)
    end
end

function addon:PLAYER_ALIVE()
    addon:updateSelfPlayer()
end

function addon:PLAYER_DEAD()
    addon:updateSelfPlayer()
    addon:refreshFrames(true)
end

function addon:PLAYER_UNGHOST()
    addon:updateSelfPlayer()
end

function addon:PLAYER_ENTERING_WORLD()
    addon:resetCounters()
end

function addon:ADDON_LOADED(addonName)
    if addonName == "TeamfightCounter" then
        addon.db = LibStub("AceDB-3.0"):New("TeamfightCounterDB", addon.DefaultSettings, true)
        addon.settings = addon.db.profile

        local config = LibStub("AceConfig-3.0")
        local dialog = LibStub("AceConfigDialog-3.0")

        AceComm:Embed(addon)
        addon:RegisterComm("TFC")

        config:RegisterOptionsTable(addonName, addon.MainOptionTable)
        TFCMainOptions = dialog:AddToBlizOptions(addonName, addonName)

        -- This no longer works as of TWW.
        -- SLASH_TFC1, SLASH_TFC2 = "/tfc", "/teamfightcounter"
        -- function SlashCmdList.TFC(msg, editBox)
        --     InterfaceOptionsFrame_OpenToCategory(TFCMainOptions)
        --     InterfaceOptionsFrame_OpenToCategory(TFCMainOptions)
        -- end

        addon:createTeamfightCounter()
        displayFrame:SetScript("OnMouseDown", TFCCounterFrameOnClick)
        selfCounter:reset()
        addon:countNearbyFactions()

        addon.classOrder = {}
        if addon.settings.newClassOrder then
            for i, class in pairs(addon.classOrderNew) do
                addon.classOrder[class] = i
            end
        else
            for i, class in pairs(addon.classOrderOld) do
                addon.classOrder[class] = i
            end
        end

        
        
        addon:Debug("Loaded")
    end
end

function addon:CHAT_MSG_BG_SYSTEM_ALLIANCE(text, ...)
    local name = text:match("([^%s]+)")
    local playerName = addon:getFullName(name)
    addon:Debug('TFC Alliance Message', text, name, playerName)

    --flag dropped
    if string.find(text, L['dropped']) or string.find(text, L["captured"]) or string.find(text, L["captured2"]) then
        --check empty 
        if flagCarriers[playerName] ~= nil then
            flagCarriers[flagCarriers[playerName]] = nil
        end
        flagCarriers[playerName] = nil
        addon:Debug('Flag Dropped.', playerName)
    end
    --flag pickup
    if string.find(text, L['picked']) then
        local flagType = addon:getFlagFromText(text)
        flagCarriers[playerName] = flagType
        flagCarriers[flagType] = playerName
        addon:Debug('Flag Taken.', playerName, flagType)
    end
end

function addon:CHAT_MSG_BG_SYSTEM_HORDE(text, ...)
    addon:CHAT_MSG_BG_SYSTEM_ALLIANCE(text, ...)
    return
end

-- ON_UPDATE
function addon:ON_UPDATE(elapsed)
    addon.timeSinceLastUpdate = addon.timeSinceLastUpdate + elapsed; 	

    if (addon.timeSinceLastUpdate > 0.1) then
        addon:updateFlagPosition()

        addon.timeSinceLastUpdate = 0;
    end
end
--     addon:Debug('TFC Horde Message', text, playerName, languageName)

--     if string.find(text, L['dropped']) or string.find(text, L["captured"]) then
--         addon:Debug('Flag Dropped.', playerName)
--         local name = addon:getFullName(playerName)
--         flagCarriers[name] = nil
--     end
--     --also check for flag pickup
--     if string.find(text, L['picked']) then
--         local name = addon:getFullName(playerName)
--         local flagType = addon:getFlagFromText(text)
--         flagCarriers[name] = flagType
--         addon:Debug('Flag Taken.', playerName, flagType)
--     end
-- end

function addon:getFlagFromText(text)
    if string.find(text, L['blue Orb']) then
        return 'blue Orb'
    elseif string.find(text, L['green Orb']) then
        return 'green Orb'
    elseif string.find(text, L['purple Orb']) then
        return 'purple Orb'
    elseif string.find(text, L['orange Orb']) then
        return 'orange Orb'
    elseif string.find(text, L['Horde Flag']) then 
        return 'Horde Flag'
    elseif string.find(text, L['Alliance Flag']) then
        return 'Alliance Flag'
    elseif string.find(text, L['Flag']) then
        return 'Flag'
    end
end



--------------------CALLBACKS-------------------
function addon:checkDead()
    local now = GetTime()
    for k, v in pairs(deadEnemies) do
        if now - v > 27 then
            deadEnemies[k] = nil
        end
    end
end

function addon:refreshCallback()
    -- addon:Debug('Refresh timer', GetTime(), GetTime() - TFC.timer)
    if GetTime() - addon.timer < 0.5 then
        return
    end
    addon.timer = GetTime()
    addon:checkDead()
    -- addon:getPOIs()
    addon:refreshFrames(true) --sometimes frames bug and return an 'Unknown' name. If this happens, do a full frame refresh to ensure we don't miss anything.
    addon:updateSelfPlayer()
    addon:checkNearbyAlly()
    addon:updateGroups()
    -- addon:Debug("Refreshed")
    C_Timer.After(1, function() addon:refreshCallback() end)
end

function addon:removedCallback(clear)
    local now = GetTime()
    for name, removedTime in pairs(removedList) do
        if now - removedTime >= 3 or clear then
            -- addon:Debug('Removing', name)
            local player = selfCounter.frames[name]
            if player then
                selfCounter:removeFrame(player)
            else
                addon:Debug("RemovedCallback - Could not find player:", name)
            end
            removedList[name] = nil
        end
    end

    addon:countNearbyFactions()
end

function addon:resetCounters()
    selfCounter:reset()
    counters = {}
    selfPlayer = {}
    addon:refreshCallback()
end

function addon:refreshFrames(force)
    if not refreshFrames and not force then return end
    refreshFrames = false
    if UnitIsDeadOrGhost('player') then 
        addon:Debug('Refreshing Frames While Player Dead.')
    end
    local nameplates = C_NamePlate.GetNamePlates()
    local remainingNameplates = {}
    for i, frame in pairs(nameplates) do
        local unit = frame.namePlateUnitToken
        local fullName = addon:getFullName(unit, true)
        if fullName then
            remainingNameplates[fullName] = unit
        end
    end
    --compare with current frames
    for name, frame in pairs(selfCounter.frames) do
        --Is existing frame not currently visible?
        if not remainingNameplates[name] then
            --Only a problem if they are not queued for removal
            if removedList[name] == nil then
                addon:Debug('Frame refresh found orphaned frame', name)
                selfCounter:removeFrame(frame)
            end
        else
            remainingNameplates[name] = nil
        end
    end
    --add new frames
    for name, unit in pairs(remainingNameplates) do
        if UnitIsPlayer(unit) and not UnitIsUnit(unit, 'player') then
            -- addon:Debug('Frame refresh adding frame', name, unit)
            addon:NAME_PLATE_UNIT_ADDED(unit)
        end
    end

    addon:countNearbyFactions()
end

function addon:shouldFrameShow()
    --is it enabled at all?
    if not addon.settings.showFrame then return false end
    --are we in in instance?
    if select(2, IsInInstance()) == "pvp" then
        --do we show only on nodeless maps?
        if addon.settings.frameOnBaselessMaps then
            --is this map nodeless?
            if not POIList or next(POIList) == nil then return true else return false end
        end
        return true
    end
    --do we show outside instance?
    if addon.settings.showOutsideInstance then return true end

    return false
end

--update frame text
function addon:countNearbyFactions()
    if addon:shouldFrameShow() then
        displayFrame:Show()
    else
        displayFrame:Hide()
        return
    end
    if not addon.settings.showDebug then displayFrame.displayEnemy:Hide(); return end

    local friendly = 0
    local enemy = 0
    for name, f in pairs(selfCounter.frames) do
        if f.isPlayer then
            if f.isAlly then
                friendly = friendly + 1
            else
                enemy = enemy + 1
            end
            -- if f.reaction > 4 then
            --     friendly = friendly + 1
            -- end
            -- if f.reaction < 4 then
            --     enemy = enemy + 1
            -- end
        end
    end
    local nearby = 0
    for name, f in pairs(selfCounter.nearby) do
        nearby = nearby + 1
    end
    local messageSent = messageCounts.sent or 0
    local messageReceived = messageCounts.received or 0
    displayFrame.displayEnemy:SetText('(' .. (friendly + 1) .. 'v' .. enemy .. ') (' .. nearby .. ') (' .. messageSent .. '/' .. messageReceived .. ')')
    displayFrame.displayEnemy:Show()
end

--Setup initial frame
function addon:createTeamfightCounter()
    if displayFrame == nil then
        displayFrame = TeamfightCounterWindow
        displayFrame.displayEnemy = displayFrame:CreateFontString(nil, "OVERLAY", "GameTooltipText")
        displayFrame.displayEnemy:SetPoint("TOP", 0, 20)
        displayFrame.displayEnemy:SetText("(1v0)")
        displayFrame.displayEnemy:SetTextColor(0.5, 0.5, 0.5, 1)
        displayFrame.displayEnemy:SetFont("Fonts\\FRIZQT__.TTF", 14, "OUTLINE")
        displayFrame.displayEnemy:Hide()
    end
end

----------Helper functions------
function addon:Debug(...)
    if addon.settings.showDebug then
        print('TFC Debug:', ...)
    end
end

--------------------INIT---------------------
local function OnEvent(self, event, ...)
    if addon[event] then
        addon[event](self, ...)
    end
end

C_ChatInfo.RegisterAddonMessagePrefix("TFC")
addonFrame:SetScript('OnEvent', OnEvent)
addonFrame:RegisterEvent('PLAYER_ENTERING_WORLD')
addonFrame:RegisterEvent('NAME_PLATE_UNIT_ADDED')
addonFrame:RegisterEvent('NAME_PLATE_UNIT_REMOVED')
addonFrame:RegisterEvent('CHAT_MSG_ADDON')
addonFrame:RegisterEvent('ZONE_CHANGED_NEW_AREA')
addonFrame:RegisterEvent('ZONE_CHANGED')
addonFrame:RegisterEvent('PLAYER_DEAD')
addonFrame:RegisterEvent('PLAYER_ALIVE')
addonFrame:RegisterEvent('PLAYER_UNGHOST')
addonFrame:RegisterEvent('ADDON_LOADED')
addonFrame:RegisterEvent('CHAT_MSG_BG_SYSTEM_ALLIANCE')
addonFrame:RegisterEvent('CHAT_MSG_BG_SYSTEM_HORDE')
TeamfightCounterWindow:SetScript('OnUpdate', function(self, elapsed) addon:ON_UPDATE(elapsed) end)

------------ Testing
function TFCCounterFrameOnClick(self, button)
    if not addon.settings.showDebug then return end
    
    messageCounts = {}

    addon:Debug('Counters:')
    addon.utils:printTable(counters)
    addon:Debug('Self Counter:')
    addon.utils:printTable(selfCounter)
    -- selfCounter:reset()
    -- counters = {}
    -- addon:updateSelfPlayer(true)
    -- addon:Debug('InRange:', IsItemInRange(132511, 'target'))
    -- addon:Debug('InRange:', addon:inRange('target'))


    -- addon:updateGroups()
    -- addon:Debug(unpack(TFC.settings.winColor))
    -- addon:Debug(unpack(TFC.settings.loseColor))
    -- addon:getPOIs(true)
    -- refreshFrames = true
    -- addon:updateSelfPlayer()
    -- addon:checkNearbyAlly()
    -- addon:showGroups()
    -- addon:showGroupsOnMap()
    -- addon:getBattlegroundPlayerData()

    --localization test
    -- print('locale', GetLocale())
    -- print(L['captured'])

    --print map id
    -- addon:Debug('Map ID:', C_Map.GetBestMapForUnit('player'))

    -- for i = 1, 4 do
    --     local uiPosx, uiPosy, flagTexture = C_PvP.GetBattlefieldFlagPosition(i, Map)
    --     addon:Debug("Flag", uiPosx, uiPosy, flagTexture)
    -- end





    --loop and print local variable flagCarriers
    -- for i, v in pairs(flagCarriers) do
    --     addon:Debug('Flag Carrier', i, v)
    -- end
    -- for i, v in pairs(flagCarriers.groups) do
    --     addon:Debug('Flag Groups', i, v)
    -- end


    -- TFC.profiler:print()

    -- local facing

    -- if GetCVar("rotateMinimap") == "0" then
    --     facing = select(49,Minimap:GetChildren()):GetFacing()
    -- else
    --     facing = MiniMapCompassRing:GetFacing()
    -- end

    -- addon:Debug('Facing', facing)
    
    -- for name,c in pairs(counters) do
    --     addon:Debug ('Counter ' .. name.. "(".. c.name .."): ".. c.allyCount.."v"..c.enemyCount.. ". Zone: " .. (c.zone or ""))
    --     for key,f in pairs(c.players) do
    --         addon:Debug("Player: ", key.." ".. (f.class or ''), f.isAlly)
    --     end
    -- end

    -- for i, c in pairs(groups) do
    --     addon:Debug ('Group ' .. i .. ": ".. c.allyCount.."v"..c.enemyCount .. ". Zone: " .. (c.zone or ""))
    --     for key,f in pairs(c.players) do
    --         addon:Debug("Player: ", key, "Zone:",f.zone, 'Class', f.class)
    --     end
    -- end

    -- local POIs = addon:getPOIs()
    -- for i,v in pairs(POIs) do
    --     info = C_AreaPoiInfo.GetAreaPOIInfo(map, v)
    --     print(v, info.name, info.position:GetXY())
    -- end
    -- GetAreaPOIInfo

end

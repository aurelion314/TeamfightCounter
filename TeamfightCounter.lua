local AddonName, TFC = ...
local L = TFC.L
_G['TeamfightCounter'] = CreateFrame('Frame')
local addon = _G['TeamfightCounter']
local TeamfightCounterWindow = _G['TeamfightCounterWindow']
TFC.version = 0.1
TFC.addon = addon
TFC.timer = 0
TFC.timeSinceLastUpdate = 0

local removedList = {}
local playerData = nil
local playerBGData = {}
local playerList = {}
local displayFrame
local counters = {}
local groups = {}
local POIList = nil
local selfPlayer = nil
local deadEnemies = {}
local missingEnemies = {}
local refreshFrames = false
local Map = nil
local flagCarriers = {}

--A group tracks everything about that group. The players, counter, frames, etc.
local group = {}

----------------------- SelfCounter tracks who you see
local selfCounter = {}
function selfCounter:addFrame(frame)
    if self.frames[frame.fullName] == nil then
        self.frames[frame.fullName] = frame
        self:addPlayer(frame)
    end
end

function selfCounter:removeFrame(frame)
    if self.frames[frame.fullName] ~= nil then
        self.frames[frame.fullName] = nil
        if self.nearby[frame.fullName] == nil then
            self:removePlayer(frame)
        end
    end
end

function selfCounter:addNearbyRaidMember(player)
    if self.nearby[player.fullName] == nil then
        self.nearby[player.fullName] = player
        self:addPlayer(player)
    end
end

function selfCounter:removeNearbyRaidMember(player)
    if self.nearby[player.fullName] ~= nil then
        self.nearby[player.fullName] = nil
        if self.frames[player.fullName] == nil then
            self:removePlayer(player)
        end
    end
end

function selfCounter:addPlayer(player)
    if self.players[player.fullName] == nil then
        self.players[player.fullName] = player
        if not player.class then addon:Debug("No class for", player.fullName) end
        addon:SendMsg(player, 'add')
    end
end

function selfCounter:removePlayer(player)
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
    self.players = {}
    self.frames = {}
    self.nearby = {}
end

------------------Counter tracks who each ally sees. Updated by addonMsgs
Counter = {}
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
    local nameparts = TFC.utils:splitString(name, '-')
    counterOwner.name, counterOwner.realm = nameparts[0], nameparts[1] or ""
    counterOwner.isAlly = true
    counterOwner.class = nil
    counterOwner.zone = nil
    obj.isSelfOwned = selfPlayer.fullName == counterOwner.fullName
    obj:addPlayer(counterOwner)

    return obj
end

function Counter:addPlayer(player)
    if self.players[player.fullName] then
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
    if not self.players[player.fullName] then
        self:addPlayer(player)
        return
    end
    self.players[player.fullName] = player
    self.zone = player.zone
end

function Counter:removePlayer(player)
    if self.players[player.fullName] == nil then
        addon:Debug("(Counter " .. self.name .. ") Can't remove because not in list: ", player.fullName)
        return
    end
    if self.players[player.fullName].isAlly then
        self.allyCount = self.allyCount - 1
    else
        self.enemyCount = self.enemyCount - 1
    end
    self.zone = player.zone

    self.players[player.fullName] = nil
end

-------------------------Addon MSGs
--Send an addon message to group
function addon:SendMsg(frame, msgType)
    local zone = self:getZoneId()
    --Fix for when player dies and returns to graveyard but their zone remains where their body is.
    if selfPlayer['isDead'] then
        zone = nil
    end

    -- self:Debug("MSG", frame.name, frame.realm, frame.class)

    local msg = TFC.version .. ";" .. msgType .. ";" .. frame['fullName'] .. ";" .. (frame['isAlly'] and '1' or '0') .. ";" .. frame['class'] .. ";" .. (zone or "") 
    if (select(2, IsInInstance()) == "pvp") then
        C_ChatInfo.SendAddonMessage("TFC", msg, "INSTANCE_CHAT")
    else
        C_ChatInfo.SendAddonMessage("TFC", msg, "WHISPER", UnitName('player'))
    end
    -- self:Debug("SendAddonMSG:",msg)
end

function addon:DecodeMsg(msg)
    local data = TFC.utils:splitString(msg, ';')
    -- self:Debug("ReceiveMSG:",msg)

    local msgType, player, version = '', {}, nil
    version, msgType, player['fullName'], player['isAlly'], player['class'], player['zone'] = data[1], data[2], data[3], data[4], data[5], data[6]
    player['isAlly'] = (player['isAlly'] == '1') and true or false
    if not player['zone'] or player['zone'] == "" then
        player['zone'] = nil
    else
        player['zone'] = self:getZoneId(player['zone'])
    end
    player['fullName'] = self:getFullName(player['fullName'])

    return msgType, player
end

--------------------------------------------

--Converts zone to numberic zone ID if zone is passed. Otherwise return current players zone ID.
function addon:getZoneId(zone)
    if zone == nil then
        self:refreshMap()
        zone = GetSubZoneText()
    end
    if tonumber(zone) then return tonumber(zone) end
    POIList = self:getPOIs()
    if POIList[zone] then
        return tonumber(POIList[zone]['id'])
    end
    return nil
end

function addon:updateSelfPlayer(force)
    local doUpdate = false
    local player = { fullName = self:getFullName(GetUnitName('player') .. '-' .. (GetRealmName() or "")), name = GetUnitName('player'), realm = GetRealmName(), isAlly = true }
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
        -- self:Debug('Self Update', player.fullName, updateType, player.isDead, player.class)
        selfPlayer = player
        self:SendMsg(player, updateType)
    end
end

-- Update groups based on all player counters. Groups become the teamfight counts.
function addon:updateGroups()
    -- addon:Debug(': Update Groups')
    if UnitIsDeadOrGhost('player') then 
        addon:Debug('Update Group while player dead')
    end
    local next = next
    --Make a list of remaining counters that we can modify on the fly
    local remainingCounters = {}
    for i, counter in pairs(counters) do
        if next(counter.players) ~= nil then
            table.insert(remainingCounters, counter)
        end
    end

    --Ensure we have up to date player data for full BG. Needed for enemy class tracking
    self:getBattlegroundPlayerData()
    missingEnemies = {}
    for i, player in pairs(playerData.enemy) do
        if deadEnemies[player.fullName] == nil then
            missingEnemies[player.fullName] = player
        end
    end

    if next(remainingCounters) == nil then
        -- addon:Debug('No counters')
        self:cleanGroupFrames('frame', true)
        self:cleanGroupFrames('map', true)
        groups = {}
        return
    end

    --First off, clear groups and populate with the first counter
    groups = { TFC.utils:deepCopy(table.remove(remainingCounters, 1)) }
    --Keep checking counters until we remove all of them
    while next(remainingCounters) ~= nil do
        for i, group in pairs(groups) do
            --loop all counters and see if one can be added to a group.
            local stop = false
            while not stop do
                stop = true
                for j, counter in pairs(remainingCounters) do
                    --check if any players in counter are in group
                    if self:hasOverlap(group, counter) then
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
            table.insert(groups, TFC.utils:deepCopy(table.remove(remainingCounters, 1)))
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
    self:showGroups()
    self:showGroupsOnMap()
end

function addon:showMissingEnemies()
    if displayFrame['missingEnemyFrame'] == nil then
        displayFrame['missingEnemyFrame'] = CreateFrame("Frame", 'missingEnemyFrame', displayFrame)
        displayFrame['missingEnemyFrame']:SetPoint("CENTER", displayFrame:GetName(), "TOP", 0, 0)
        displayFrame['missingEnemyFrame']:SetWidth(50)
        displayFrame['missingEnemyFrame']:SetHeight(10)
    end

    if TFC.settings.showMissing then
        displayFrame['missingEnemyFrame']:Show()
    else
        displayFrame['missingEnemyFrame']:Hide()
        return
    end

    self:showClassBlips({ players = missingEnemies }, displayFrame['missingEnemyFrame'], 'missing')
end

function addon:showMissingEnemiesOnMap()
    if _G['missingEnemyMapFrame'] == nil then
        _G['missingEnemyMapFrame'] = CreateFrame("Frame", 'missingEnemyMapFrame', _G['missingEnemyMapFrame'])
        _G['missingEnemyMapFrame']:SetFrameLevel(16)
        _G['missingEnemyMapFrame']:SetWidth(50)
        _G['missingEnemyMapFrame']:SetHeight(10)
        _G['missingEnemyMapFrame']:SetPoint("CENTER", 'REPorterFrame', "TOP", 0, -5)
    end

    if TFC.settings.showMissing then
        _G['missingEnemyMapFrame']:Show()
    else
        _G['missingEnemyMapFrame']:Hide()
        return
    end

    self:showClassBlips({ players = missingEnemies }, _G['missingEnemyMapFrame'], 'missing')
end

function addon:showGroups()
    self:cleanGroupFrames('frame')

    local height = -30
    local blipWidth = 6
    -- for i, group in pairs(groups) do
    for i, group in TFC.utils:spairs(groups, function(t, a, b) return t[a].isSelfOwned end) do
        -- self:Debug('Showing group', i)
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
            groupText:SetFont("Fonts\\FRIZQT__.TTF", 14*TFC.settings.textScale, "OUTLINE")
        end
        local groupCounterFrame = displayFrame['displayGroup' .. i]
        local groupText = groupCounterFrame['groupText']
        --set color depending on ally vs enemy
        if group.allyCount > group.enemyCount then
            groupText:SetTextColor(0, 1, 0, 1)
        elseif group.allyCount < group.enemyCount then
            groupText:SetTextColor(1, 0, 0, 1)
        else
            groupText:SetTextColor(0.5, 0.5, 0.5, 1)
        end
        groupText:SetText(msg)
        groupCounterFrame:Show()

        self:showClassBlips(group, groupCounterFrame)
    end
    self:showMissingEnemies()
end

function addon:showGroupsOnMap()
    self:cleanGroupFrames('map')

    --have they selected to only use on node maps?
    if TFC.settings.showFrame and TFC.settings.frameOnBaselessMaps then
        --is this map nodeless?
        self:getPOIs()
        if not POIList or next(POIList) == nil then return end
    end

    if _G['REPorterFrame'] == nil or not _G['REPorterFrame']:IsShown() then
        -- addon:Debug('Debug: ReporterFrame not available')
        return
    end
    local topFrames = {}
    -- for i, group in pairs(groups) do
    for i, group in TFC.utils:spairs(groups, function(t, a, b) return t[a].isSelfOwned end) do
        if group.zone then
            local x, y = self:getGroupPosition(group)
            -- addon:Debug('Group has zone:', group.zone, x, y)
            local result = self:showGroupOnMap(group, x, y, 'REPorterFrameCorePOI')
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
        self:showGroupOnMap(group, x, y, 'REPorterFrame')
    end
    self:showMissingEnemiesOnMap()
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
        frameText:SetFont("Fonts\\FRIZQT__.TTF", fontSize*TFC.settings.textScale, "OUTLINE")
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

    self:showClassBlips(group, frameMain, group.zone and 'enemy' or nil)
end

function addon:showClassBlips(group, parentFrame, reaction)
    --first clear all blips
    if parentFrame['blips'] == nil then
        parentFrame['blips'] = {}
    end
    for i, blip in pairs(parentFrame.blips) do
        blip:Hide()
    end

    if not TFC.settings.showClasses and reaction ~= 'missing' then
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
    local blipWidth = 6*TFC.settings.blipScale
    if not reaction or reaction == 'ally' then
        local playerNum = 1
        for i, player in TFC.utils:spairs(ally, function(t, a, b) return (TFC.classOrder[t[b].class] or 0) < (TFC.classOrder[t[a].class] or 0) end) do
            if player.class then
                playerNum = playerNum + 1
                x, y = (-15) - blipWidth * playerNum, 0
                self:showClassBlip(parentFrame, player, x, y, 'ally', playerNum)
            end
        end
    end
    if not reaction or reaction == 'enemy' then
        local playerNum = 1
        for i, player in TFC.utils:spairs(enemy, function(t, a, b) return (TFC.classOrder[t[b].class] or 0) < (TFC.classOrder[t[a].class] or 0) end) do
            if player.class then
                playerNum = playerNum + 1
                x, y = (13) + blipWidth * playerNum, 0
                self:showClassBlip(parentFrame, player, x, y, 'enemy', playerNum)
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
        for i, player in TFC.utils:spairs(group.players, function(t, a, b) return (TFC.classOrder[t[b].class] or 0) < (TFC.classOrder[t[a].class] or 0) end) do
            if player.class then
                playerNum = playerNum + 1
                x, y = -(blipWidth * (playerCount + 1)) / 2 + blipWidth * playerNum, 0
                self:showClassBlip(parentFrame, player, x, y, 'enemy', playerNum, "Interface\\Addons\\TeamfightCounter\\textures\\BlipCombat")
            end
        end
    end
end

function addon:showClassBlip(parentFrame, player, x, y, faction, playerNum, texture)
    local textureName = "TFCBlipTexture" .. faction .. playerNum
    if parentFrame.blips[textureName] == nil then
        parentFrame.blips[textureName] = parentFrame:CreateTexture("TFCBlipTexture" .. parentFrame:GetName() .. faction .. playerNum)
        if not texture then
            parentFrame.blips[textureName]:SetTexture("Interface\\Addons\\TeamfightCounter\\textures\\BlipNormal")
        else
            parentFrame.blips[textureName]:SetTexture(texture)
        end
        parentFrame.blips[textureName]:SetWidth(10*TFC.settings.blipScale)
        parentFrame.blips[textureName]:SetHeight(10*TFC.settings.blipScale)
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
                -- addon:Debug("Flag", x, y, flagTexture)
                if desiredFlagTexture == flagTexture then
                    if x == nil or y == nil then
                        addon:Debug("Flag possition is nil: ", zone, x, y, flagTexture)
                        break
                    end
                    addon:Debug("Flag possition (GroupUpdate): ", x, y, flagTexture)
                    return self:getRealCoords(x, y - verticalOffset)
                end
            end
        end
        --Bases
        self:getPOIs()
        local POIinfo = POIList[zone]
        if POIinfo then
            local x, y = POIinfo.position:GetXY()
            return self:getRealCoords(x, y - verticalOffset)
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
                -- addon:Debug("Updating flag position for group " .. group_id .. ':', x, y, flagCount, parentFrameName, frameName)
                x, y = self:getRealCoords(x, y - 0.04)
                frameMain:SetPoint("CENTER", parentFrameName, "TOPLEFT", x, y)
            else
                -- addon:Debug("No flag positions for group: " .. group_id, #flagCarriers.groups)
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
    -- self:Debug('Checking nearby allies')
    --check if in instance
    if not IsInInstance() then
        return
    end

    --loop all raid members and check if they are in interact range
    for i = 1, GetNumGroupMembers() do
        local unit = "raid" .. i
        local player = addon:getUnitDetails(unit)
        if player then
            if CheckInteractDistance(unit, 4) and not UnitIsDeadOrGhost(unit) then
                selfCounter:addNearbyRaidMember(player)
            else
                selfCounter:removeNearbyRaidMember(player)
            end
        end
    end
end

function addon:getUnitDetails(unit)
    if not UnitIsPlayer(unit) then
        return
    end

    local details = {}
    details['fullName'] = self:getFullName(unit, true)
    details["name"], details["realm"] = UnitName(unit)
    details["reaction"] = UnitReaction(unit, "player")
    details["isAlly"] = details["reaction"] and (details["reaction"] > 4) or nil
    details["isPlayer"] = UnitIsPlayer(unit)
    details["class"] = select(2, UnitClass(unit))
    details["isClose"] = CheckInteractDistance(unit, 4)
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
    if details['name'] == 'Unknown' or details['name'] == 'Unbekannt' or not details['fullName'] then
        refreshFrames = true
        return nil
    end

    return details
end

function addon:getFullName(fullName, isUnitTag)
    if not fullName or UnitIsPlayer(fullName) or isUnitTag then
        local name, realm = UnitName(fullName)
        if not name then
            self:Debug("Fullname failed, no name:", fullName, isUnitTag)
            return nil
        end
        fullName = name .. '-' .. (realm or "")
    end

    local parts = TFC.utils:splitString(fullName, '-')
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

function addon:CHAT_MSG_ADDON(prefix, msg, channel, sender)
    if prefix == "TFC" then
        sender = self:getFullName(sender)
        -- addon:Debug(prefix, msg, channel, sender)

        local msgType, player = self:DecodeMsg(msg)

        if not counters[sender] then
            counters[sender] = Counter:new(sender)
        end

        if msgType == "add" then
            counters[sender]:addPlayer(player)
        elseif msgType == "remove" then
            counters[sender]:removePlayer(player)
        elseif msgType == "update" then
            counters[sender]:updatePlayer(player)
        elseif msgType == "dead" then
            counters[sender]:removePlayer(player)
            if deadEnemies[player.fullName] == nil then
                deadEnemies[player.fullName] = GetTime()
            end
        end

        self:refreshCallback()
    end
end

function addon:ZONE_CHANGED_NEW_AREA()
    --clear all counters
    addon:Debug('Zone Area Changed')
    POIList = nil
    addon:refreshMap(true)
    selfPlayer = {}
    self:updateSelfPlayer()
    self:getBattlegroundPlayerData(true)
    selfCounter:reset()
    removedList = {}
    flagCarriers = {}
    counters = {}
    counters[selfPlayer.fullName] = Counter:new(selfPlayer.fullName)
    refreshFrames = true

    self:countNearbyFactions()
    self:refreshCallback()
end

function addon:ZONE_CHANGED()
    addon:Debug('Zone Changed:', GetSubZoneText())
    self:updateSelfPlayer(true)
end

function addon:NAME_PLATE_UNIT_ADDED(unit)
    -- self:Debug('Frame Added', unit, self:getFullName(unit))
    if not UnitExists(unit) or UnitIsUnit(unit, 'player') then return end
    local frame = self:getUnitDetails(unit)

    --Ignore in these cases
    if not frame or (frame['isTarget'] and not frame['isClose']) or frame['isDead'] or frame['reaction'] == nil then return end

    -- self:Debug('Adding', unit, frame.fullName)
    selfCounter:addFrame(frame)
    --Reset removal timer if they had previously dropped from our vision.
    removedList[frame.fullName] = nil

    self:countNearbyFactions()
end

function addon:NAME_PLATE_UNIT_REMOVED(unit)
    -- self:Debug('Frame Removed', unit, self:getFullName(unit))
    local frame = self:getUnitDetails(unit)
    if not frame then return end
    --If the unit is dead, remove from list immediately
    if frame['isDead'] or UnitIsDeadOrGhost('player') then
        selfCounter:removeFrame(frame)
        removedList[frame.fullName] = nil
        self:countNearbyFactions()
    else
        --if alive, set a callback to remove it in a few seconds.
        removedList[frame.fullName] = GetTime()
        C_Timer.After(3, function() self:removedCallback() end)
    end
end

function addon:PLAYER_ALIVE()
    self:updateSelfPlayer()
end

function addon:PLAYER_DEAD()
    self:updateSelfPlayer()
end

function addon:PLAYER_UNGHOST()
    self:updateSelfPlayer()
end

function addon:PLAYER_ENTERING_WORLD()
    local fullName = addon:getFullName('player', true)
    counters = {}
    counters[fullName] = Counter:new(fullName)

    self:refreshCallback()
end

function addon:ADDON_LOADED(addon)
    if addon == "TeamfightCounter" then
        TFC.db = LibStub("AceDB-3.0"):New("TeamfightCounterDB", TFC.DefaultSettings, true)
        TFC.settings = TFC.db.profile

        local config = LibStub("AceConfig-3.0")
        local dialog = LibStub("AceConfigDialog-3.0")

        config:RegisterOptionsTable(AddonName, TFC.MainOptionTable)
        TFCMainOptions = dialog:AddToBlizOptions(AddonName, AddonName)

        SLASH_TFC1, SLASH_TFC2 = "/tfc", "/teamfightcounter"
        function SlashCmdList.TFC(msg, editBox)
            InterfaceOptionsFrame_OpenToCategory(TFCMainOptions)
            InterfaceOptionsFrame_OpenToCategory(TFCMainOptions)
        end

        self:countNearbyFactions()

        TFC.classOrder = {}
        if TFC.settings.newClassOrder then
            for i, class in pairs(TFC.classOrderNew) do
                TFC.classOrder[class] = i
            end
        else
            for i, class in pairs(TFC.classOrderOld) do
                TFC.classOrder[class] = i
            end
        end

        self:Debug("Loaded")
    end
end

function addon:CHAT_MSG_BG_SYSTEM_ALLIANCE(text, ...)
    local name = text:match("([^%s]+)")
    local playerName = self:getFullName(name)
    self:Debug('TFC Alliance Message', text, name, playerName)

    --flag dropped
    if string.find(text, L['dropped']) or string.find(text, L["captured"]) or string.find(text, L["captured2"]) then
        --check empty 
        if flagCarriers[playerName] ~= nil then
            flagCarriers[flagCarriers[playerName]] = nil
        end
        flagCarriers[playerName] = nil
        self:Debug('Flag Dropped.', playerName)
    end
    --flag pickup
    if string.find(text, L['picked']) then
        local flagType = addon:getFlagFromText(text)
        flagCarriers[playerName] = flagType
        flagCarriers[flagType] = playerName
        self:Debug('Flag Taken.', playerName, flagType)
    end


end

function addon:CHAT_MSG_BG_SYSTEM_HORDE(text, ...)
    addon:CHAT_MSG_BG_SYSTEM_ALLIANCE(text, ...)
    return
end

-- ON_UPDATE
function addon:ON_UPDATE(elapsed)
    TFC.timeSinceLastUpdate = TFC.timeSinceLastUpdate + elapsed; 	

    if (TFC.timeSinceLastUpdate > 0.1) then
        addon:updateFlagPosition()

        TFC.timeSinceLastUpdate = 0;
    end
end
--     self:Debug('TFC Horde Message', text, playerName, languageName)

--     if string.find(text, L['dropped']) or string.find(text, L["captured"]) then
--         self:Debug('Flag Dropped.', playerName)
--         local name = addon:getFullName(playerName)
--         flagCarriers[name] = nil
--     end
--     --also check for flag pickup
--     if string.find(text, L['picked']) then
--         local name = addon:getFullName(playerName)
--         local flagType = addon:getFlagFromText(text)
--         flagCarriers[name] = flagType
--         self:Debug('Flag Taken.', playerName, flagType)
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
    -- self:Debug('Refresh timer', GetTime(), GetTime() - TFC.timer)
    if GetTime() - TFC.timer < 0.5 then
        return
    end
    TFC.timer = GetTime()
    self:checkDead()
    -- self:getPOIs()
    -- self:removedCallback()
    self:refreshFrames(true) --sometimes frames bug and return an 'Unknown' name. If this happens, do a full frame refresh to ensure we don't miss anything.
    self:updateSelfPlayer()
    self:checkNearbyAlly()
    self:updateGroups()
    -- self:Debug("Refreshed")
    C_Timer.After(1, function() self:refreshCallback() end)
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
                self:Debug("RemovedCallback - Could not find player:", name)
            end
            removedList[name] = nil
        end
    end

    self:countNearbyFactions()
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
        local fullName = self:getFullName(unit, true)
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
                self:Debug('Frame refresh found orphaned frame', name)
                selfCounter:removeFrame(frame)
            end
        else
            remainingNameplates[name] = nil
        end
    end
    --add new frames
    for name, unit in pairs(remainingNameplates) do
        if UnitIsPlayer(unit) and not UnitIsUnit(unit, 'player') and CheckInteractDistance(unit, 4) then
            -- self:Debug('Frame refresh adding frame', name, unit)
            self:NAME_PLATE_UNIT_ADDED(unit)
        end
    end
end

function addon:shouldFrameShow()
    --is it enabled at all?
    if not TFC.settings.showFrame then return false end
    --are we in in instance?
    if select(2, IsInInstance()) == "pvp" then
        --do we show only on nodeless maps?
        if TFC.settings.frameOnBaselessMaps then
            --is this map nodeless?
            if not POIList or next(POIList) == nil then return true else return false end
        end
        return true
    end
    --do we show outside instance?
    if TFC.settings.showOutsideInstance then return true end

    return false
end

--update frame text
function addon:countNearbyFactions()
    if self:shouldFrameShow() then
        displayFrame:Show()
    else
        displayFrame:Hide()
        return
    end
    if not TFC.settings.showDebug then displayFrame.displayEnemy:Hide(); return end

    local friendly = 0
    local enemy = 0
    for name, f in pairs(selfCounter.frames) do
        if f.isPlayer then
            if f.reaction > 4 then
                friendly = friendly + 1
            end
            if f.reaction < 4 then
                enemy = enemy + 1
            end
        end
    end
    local nearby = 0
    for name, f in pairs(selfCounter.nearby) do
        nearby = nearby + 1
    end
    displayFrame.displayEnemy:SetText('(' .. (friendly + 1) .. 'v' .. enemy .. ') (' .. nearby .. ')')
    displayFrame.displayEnemy:Show()
end

--Setup initial frame
function addon:createTeamfightCounter()
    if displayFrame == nil then
        displayFrame = TeamfightCounterWindow
        -- displayFrame.displayAllyDiff = displayFrame:CreateFontString(nil,"OVERLAY", "GameTooltipText")
        -- displayFrame.displayAllyDiff:SetText("(+1)")
        -- displayFrame.displayAllyDiff:SetPoint("TOPLEFT",15,0)
        -- displayFrame.displayAllyDiff:SetTextColor(0,1,0,1)
        -- displayFrame.displayAllyDiff:SetFont("Fonts\\FRIZQT__.TTF", 16, "THICKOUTLINE")
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
    if TFC.settings.showDebug then
        print('TFC Debug:', ...)
    end
end

--------------------INIT---------------------
local function OnEvent(self, event, ...)
    if self[event] then
        self[event](self, ...)
    end
end

C_ChatInfo.RegisterAddonMessagePrefix("TFC")
addon:SetScript('OnEvent', OnEvent)
addon:RegisterEvent('PLAYER_ENTERING_WORLD')
addon:RegisterEvent('NAME_PLATE_UNIT_ADDED')
addon:RegisterEvent('NAME_PLATE_UNIT_REMOVED')
addon:RegisterEvent('CHAT_MSG_ADDON')
addon:RegisterEvent('ZONE_CHANGED_NEW_AREA')
addon:RegisterEvent('ZONE_CHANGED')
addon:RegisterEvent('PLAYER_DEAD')
addon:RegisterEvent('PLAYER_ALIVE')
addon:RegisterEvent('PLAYER_UNGHOST')
addon:RegisterEvent('ADDON_LOADED')
addon:RegisterEvent('CHAT_MSG_BG_SYSTEM_ALLIANCE')
addon:RegisterEvent('CHAT_MSG_BG_SYSTEM_HORDE')
TeamfightCounterWindow:SetScript('OnUpdate', function(self, elapsed) addon:ON_UPDATE(elapsed) end)
selfCounter:reset()
addon:createTeamfightCounter()

------------ Testing
displayFrame:SetScript("OnMouseDown", function(self, arg1)
    if not TFC.settings.showDebug then return end
    -- addon:getPOIs(true)
    -- refreshFrames = true
    -- addon:updateSelfPlayer()
    -- addon:checkNearbyAlly()
    -- addon:updateGroups()
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

    
    -- for name,c in pairs(selfCounter.frames) do
    --     addon:Debug ('Self Frames ', name, c.isAlly, c.class)
    -- end
    -- for name,c in pairs(selfCounter.players) do
    --     addon:Debug ('Self Players ', name, c.isAlly, c.class)
    -- end

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

end)

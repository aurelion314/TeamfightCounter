local AddonName, TFC = ...
local utils = {}
local profiler = {}
TFC.utils = utils
TFC.profiler = profiler

--helper for stringSplit function
function utils:gsplit(text, pattern, plain)
    local splitStart, length = 1, #text
    return function()
        if splitStart then
            local sepStart, sepEnd = string.find(text, pattern, splitStart, plain)
            local ret
            if not sepStart then
                ret = string.sub(text, splitStart)
                splitStart = nil
            elseif sepEnd < sepStart then
                -- Empty separator!
                ret = string.sub(text, splitStart, sepStart)
                if sepStart < length then
                    splitStart = sepStart + 1
                else
                    splitStart = nil
                end
            else
                ret = sepStart > splitStart and string.sub(text, splitStart, sepStart - 1) or ''
                splitStart = sepEnd + 1
            end
            return ret
        end
    end
end

--custom stringsplit that works when there is no character between separators
function utils:splitString(text, pattern, plain)
    TFC.profiler:start("splitString")
    local ret = {}
    for match in self:gsplit(text, pattern, plain) do
        table.insert(ret, match)
    end
    TFC.profiler:stop("splitString")
    return ret
end

-- Create a copy of a table rather than a reference
function utils:deepCopy(orig, copies)
    TFC.profiler:start("deepCopy")
    copies = copies or {}
    local orig_type = type(orig)
    local copy
    if orig_type == 'table' then
        if copies[orig] then
            copy = copies[orig]
        else
            copy = {}
            copies[orig] = copy
            for orig_key, orig_value in next, orig, nil do
                copy[utils:deepCopy(orig_key, copies)] = utils:deepCopy(orig_value, copies)
            end
            setmetatable(copy, utils:deepCopy(getmetatable(orig), copies))
        end
    else -- number, string, boolean, etc
        copy = orig
    end
    TFC.profiler:stop("deepCopy")
    return copy
end

--sorted version of pairs()
function utils:spairs(t, order)
    TFC.profiler:start("spairs")
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys + 1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys
    if order then
        table.sort(keys, function(a, b) return order(t, a, b) end)
    else
        table.sort(keys)
    end
    TFC.profiler:stop("spairs")
    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end

profiler.events = {}
function profiler:start(name)
    -- if true then return end
    -- UpdateAddOnCPUUsage()
    -- local now = GetAddOnCPUUsage('TeamfightCounter')
    if self.events[name] == nil then
        self.events[name] = {
            start = 0,
            count = 0,
            total = 0,
            average = 0
        }
    else
        self.events[name].start = now
    end
end

function profiler:stop(name)
    if true then return end
    -- UpdateAddOnCPUUsage()
    -- local now = GetAddOnCPUUsage('TeamfightCounter')
    if self.events[name] ~= nil then
        local event = self.events[name]
        self.events[name].count = self.events[name].count + 1
        -- self.events[name].total = (GetTime() - self.events[name].start) + self.events[name].total
        event.total = event.total + (now - event.start)
        self.events[name].average = self.events[name].total / self.events[name].count
        if event.total == 0 then
            event.whathtefuck = now .. " - " ..event.start
        end
    end
end

function profiler:print()
    -- UpdateAddOnCPUUsage()
    -- TFC.addon:Debug("GetAddOnCPUUsage", GetAddOnCPUUsage('TeamfightCounter'))
    for name, event in pairs(self.events) do
        -- TFC.addon:Debug("Profiler (" .. name .. ")", "count:" .. event.count, "total:" .. event.total, "average:" .. event.average, "start:" .. event.start, (GetTime() - event.start))
        -- TFC.addon:Debug("Diff", event.whathtefuck or '',  event.total + (GetTime() - event.start))
    end
    local durration, count = GetFunctionCPUUsage(TFC.addon.refreshCallback, true)
    local average = durration/count
    TFC.addon:Debug('refreshCallback', count, average, durration)
    local durration, count = GetFunctionCPUUsage(TFC.addon.updateGroups, true)
    local average = durration/count
    TFC.addon:Debug('updateGroups', count, average, durration)
    local durration, count = GetFunctionCPUUsage(TFC.addon.showGroups, true)
    local average = durration/count
    TFC.addon:Debug('showGroups', count, average, durration)
    local durration, count = GetFunctionCPUUsage(TFC.addon.showGroupsOnMap, true)
    local average = durration/count
    TFC.addon:Debug('showGroupsOnMap', count, average, durration)
    local durration, count = GetFunctionCPUUsage(TFC.addon.showClassBlips, true)
    local average = durration/count
    TFC.addon:Debug('showClassBlips', count, average, durration)
    local durration, count = GetFunctionCPUUsage(TFC.addon.updateSelfPlayer, true)
    local average = durration/count
    TFC.addon:Debug('updateSelfPlayer', count, average, durration)
    local durration, count = GetFunctionCPUUsage(TFC.addon.checkNearbyAlly, true)
    local average = durration/count
    TFC.addon:Debug('checkNearbyAlly', count, average, durration)
    local durration, count = GetFunctionCPUUsage(TFC.addon.countNearbyFactions, true)
    local average = durration/count
    TFC.addon:Debug('countNearbyFactions', count, average, durration)
    local durration, count = GetFunctionCPUUsage(TFC.addon.CHAT_MSG_ADDON, true)
    local average = durration/count
    TFC.addon:Debug('CHAT_MSG_ADDON', count, average, durration)
    local durration, count = GetFunctionCPUUsage(utils.splitString, true)
    local average = durration/count
    TFC.addon:Debug('splitString', count, average, durration)
    local durration, count = GetFunctionCPUUsage(utils.deepCopy, true)
    local average = durration/count
    TFC.addon:Debug('deepCopy', count, average, durration)
    local durration, count = GetFunctionCPUUsage(TFC.addon.getFullName, true)
    local average = durration/count
    TFC.addon:Debug('getFullName', count, average, durration)
    local durration, count = GetFunctionCPUUsage(TFC.addon.DecodeMsg, true)
    local average = durration/count
    TFC.addon:Debug('DecodeMsg', count, average, durration)
end

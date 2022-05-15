local AddonName, TFC = ...
local utils = {}
TFC.utils = utils

--helper for stringSplit function
function utils:gsplit(text, pattern, plain)
    local splitStart, length = 1, #text
    return function ()
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
    local ret = {}
    for match in self:gsplit(text, pattern, plain) do
        table.insert(ret, match)
    end
    return ret
end

-- Create a copy of a table rather than a reference
function utils:deepCopy(orig, copies)
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
    return copy
end

--sorted version of pairs()
function utils:spairs(t, order)
    -- collect the keys
    local keys = {}
    for k in pairs(t) do keys[#keys+1] = k end

    -- if order function given, sort by it by passing the table and keys a, b,
    -- otherwise just sort the keys 
    if order then
        table.sort(keys, function(a,b) return order(t, a, b) end)
    else
        table.sort(keys)
    end

    -- return the iterator function
    local i = 0
    return function()
        i = i + 1
        if keys[i] then
            return keys[i], t[keys[i]]
        end
    end
end
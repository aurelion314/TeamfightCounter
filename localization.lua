local _, TFC = ...

local L = setmetatable({}, {__index = function(L,key)
	return key
end})

TFC.L = L
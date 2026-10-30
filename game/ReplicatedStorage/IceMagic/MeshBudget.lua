--[[
	MeshBudget  (ModuleScript)  ->  ReplicatedStorage/IceMagic/MeshBudget

	One client's EditableMesh memory budget is shared by every kit, skin and wrap that builds meshes (2026-10-19: Terra's
	wrap prewarm and a Cryo wrap's vertex-colour copies left a worn Frost Dragon no room, and it drew the Default all
	session). The order it keeps: a worn skin's own meshes first; optional ones -- a wrap's per-mesh copies, a prewarm
	nobody wears -- give way.
	  Essential(id, on)   a builder whose meshes a worn skin needs is building (on) / done (off)
	  Busy()              whether one is building: an optional builder starts nothing new meanwhile
	  Optional(fn)        a way to free optional meshes: fn() lets go of what it can, without yielding
	  MakeRoom()          an essential build was refused: every Optional fn frees what it can
]]

local MeshBudget = {}

local building = {}          -- [id] = true while that essential build runs
local holders = {}           -- the Optional fns

function MeshBudget.Essential(id, on)
	building[id] = on and true or nil
end

function MeshBudget.Busy()
	return next(building) ~= nil
end

function MeshBudget.Optional(fn)
	holders[#holders + 1] = fn
end

function MeshBudget.MakeRoom()
	for _, fn in ipairs(holders) do
		local ok, err = pcall(fn)
		if not ok then warn("[MeshBudget] " .. tostring(err)) end
	end
end

return MeshBudget

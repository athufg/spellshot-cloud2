--[[
	ChargedRock  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ChargedRock

	Terra's CHARGED ROCK (spec v1.4, blender_scripts/terra/charged_rock.py) in the game: the one material the Bulwark
	Wall (TerraFX_Wall) and the Earthen Tomb (TerraFX_Tomb) reworks are cut from. Written 2026-10-09 to the port's
	contract (vfx_blocking/terra/WALL_TOMB_PORT_SPEC.md, section 3 -- the names and signatures below are that contract;
	both builders code against them, so they do not change).

	THE RECIPE IS THE LIVE BOULDER SHOT'S, NOT TEXTURES (the contract's fixed decision 4: new image uploads do not load in
	this place). One rock piece is up to four MeshParts out of the kit export (blender_scripts/terra/charged_rock_kit.py):
	  <name>        the STONE: white SmoothPlastic, its colour baked into the vertex colours (maroon body with grain off
	                the REST coordinates, the cap on the faces turned up). Never tinted. The only part that casts a shadow.
	  <name>_Brk    the fracture faces: white in the FBX, coloured here -- INNER #4E321A plastic, Neon warm gold in a flare
	  <name>_Lit    the ~40% of the seams that are lit: Neon, an ember-to-gold ramp driven by the level below
	  <name>_Dead   the rest of the seams: dark #241008 plastic, never driven
	Each but the stone is optional (a pebble or a plate is a stone alone).

	THE LEVEL (charged_rock.py's cr_level, added to 1: 0 nominal, -0.55 the 45% ember, +1 double) is the caller's: it
	is the sum of whatever curves apply (STAGE_LEVEL, AfterHit, AfterBreak / AtBreak below -- charged_rock.py's own
	functions, ported 1:1). SetLevel turns it, times the slow pulse, into the Lit and Brk parts' colour and material.

	THE GLOW MAPPING (the owner: "restrained, NOT Voltaic, cracks only"): the lit seam's Neon colour runs from a dark
	ember #5A2A0C at level-mult 0 to GOLD #FFB84D at 2 -- never toward white, no flicker, no PointLight. The nominal seam
	(mult 1.0) is meant to sit UNDER the place's Bloom threshold (1.6); only the flares and the Wall's stage 3-4 should
	bloom. That is a claim to MEASURE ON SCREEN (the toxin-kit rule), which is what Tuning.LitGain / BrkGain are for.

	EXTRAS (not in the contract's section 3; the Wall's budget uses them, the Tomb need not):
	  ChargedRock.Show(piece, kind, on)   hides / shows one optional part ("Brk" / "Lit" / "Dead"); Place skips it
	  ChargedRock.Count(piece)            the piece's parts on screen now
	  ChargedRock.Scale(piece, k)         every part resized by k (number or per-axis Vector3) about the stone, and
	                                      the parts' Rel with it; undone by Release (a pooled piece comes back at 1)
	EVERY NUMBER HERE IS A PROPOSAL, except the charged_rock.py v1.4 constants, which are copied exactly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local ChargedRock = {}

-- the Bulwark Wall's struck slab: its glow by damage stage, [stage + 1] (stage 0..4) -- charged_rock.py STAGE_LEVEL
ChargedRock.STAGE_LEVEL = { 0, 0.2, 0.45, 0.75, 1.1 }
-- ...and its damage round the impact (charged_rock.py STAGE_DMG; carried for completeness -- the Roblox port has no
-- per-texel crazing to drive with it)
ChargedRock.STAGE_DMG = { 0, 0.3, 0.55, 0.8, 1.0 }

ChargedRock.Tuning = {
	-- charged_rock.py v1.4, exactly
	BreakFlare = 0.8,     -- a break: the seams flare...
	FlareTau = 0.06,      -- ...and the flare is gone this fast
	Ember = -0.55,        -- ...then the piece cools to an EMBER (45%) and keeps it
	EmberTau = 0.35,
	HitFlare = 0.6,       -- every hit on it: a flare
	HitTau = 0.08,
	PulseHz = 0.8,        -- the pulse: 1 + PulseA * sin(2 pi PulseHz t - phase) -- a slow swell, out of step
	PulseA = 0.15,
	-- the glow mapping (the contract's fixed decision 4)
	EmberColour = Color3.fromRGB(0x5A, 0x2A, 0x0C),  -- a lit seam's Neon at level-mult 0
	Gold = Color3.fromRGB(0xFF, 0xB8, 0x4D),         -- ...and at GlowSpan (the v1.4 core colour; never past it)
	GlowSpan = 2,
	LitGain = 1,          -- the lit seam's mult x this before the ramp: THE knob to set nominal under Bloom (measure it)
	NeonFrom = 0.08,      -- a seam whose mult is under this is SmoothPlastic EmberColour (below the v1.4 ember's 0.45,
	                      -- so in practice a lit seam is always Neon)
	BrkNeonAt = 0.3,      -- the fracture faces glow only in a FLARE: a LEVEL over this. Under it they are INNER plastic --
	                      -- v1.2 found ember-lit break faces washed the rubble khaki, and a flat Neon face is a wash
	BrkSpan = 1.2,        -- ...and go from EmberColour at BrkNeonAt to Gold this much above it (a break flare reaches it)
	Inner = Color3.fromRGB(0x4E, 0x32, 0x1A),   -- a fresh break, unlit (charged_rock.py brk)
	Dead = Color3.fromRGB(0x24, 0x10, 0x08),    -- a dead seam (charged_rock.py crack_dead)
	Quant = 16,           -- colour steps per unit of mult: a write only when the step changes (TerraFX setGlow's rule)
	PoolPerName = 3,      -- released pieces kept per kit name for reuse (the Wall shows up to 3 copies of its template)
}

local WHITE = Color3.new(1, 1, 1)
local OPTIONAL = { "Brk", "Lit", "Dead" }
-- where a fresh clone waits until its caller places it (same frame): far above anything, never below the map's
-- FallenPartsDestroyHeight
local STASH = CFrame.new(0, 5e4, 0)

local function clamp01(x) return math.clamp(x, 0, 1) end

local fxFolderName = nil
local function fxFolder()
	if not fxFolderName then
		fxFolderName = "IceMagicFX"
		local ice = ReplicatedStorage:FindFirstChild("IceMagic")
		local lib = ice and ice:FindFirstChild("VFXLibrary")
		if lib then
			local ok, VFX = pcall(require, lib)
			if ok and type(VFX) == "table" and type(VFX.Config) == "table" and type(VFX.Config.FXFolderName) == "string" then
				fxFolderName = VFX.Config.FXFolderName
			end
		end
	end
	local f = workspace:FindFirstChild(fxFolderName)
	if not f then
		f = Instance.new("Folder")
		f.Name = fxFolderName
		f.Parent = workspace
	end
	return f
end

--- A pulse phase for a piece the kit gave none (an attribute "Phase" on the stone wins): a hash of its name over two
--- turns, as charged_rock.py's noise is -- deterministic, so every client pulses a piece alike.
local function hashPhase(name)
	local h = 7
	for i = 1, #name do h = (h * 31 + string.byte(name, i)) % 1000003 end
	return (h / 1000003) * 4 * math.pi
end

-- sources[kitFolder][baseName] = { Stone, Parts = { [kind] = part }, Rel = { [kind] = CFrame }, Phase } or false
local sources = setmetatable({}, { __mode = "k" })
-- pools[kitFolder][baseName] = { piece, ... }
local pools = setmetatable({}, { __mode = "k" })
local warned = {}

local function sourceOf(kitFolder, baseName)
	local byKit = sources[kitFolder]
	if not byKit then
		byKit = {}
		sources[kitFolder] = byKit
	end
	local s = byKit[baseName]
	if s ~= nil then return s or nil end
	local stone = kitFolder:FindFirstChild(baseName, true)
	if not (stone and stone:IsA("BasePart")) then
		byKit[baseName] = false
		local key = kitFolder:GetFullName() .. "." .. baseName
		if not warned[key] then
			warned[key] = true
			warn(("[ChargedRock] '%s' not found in %s"):format(baseName, kitFolder:GetFullName()))
		end
		return nil
	end
	s = { Stone = stone, Parts = {}, Rel = {} }
	for _, kind in ipairs(OPTIONAL) do
		local p = kitFolder:FindFirstChild(baseName .. "_" .. kind, true)
		if p and p:IsA("BasePart") then
			s.Parts[kind] = p
			s.Rel[kind] = stone.CFrame:ToObjectSpace(p.CFrame)
		end
	end
	local ph = stone:GetAttribute("Phase")
	s.Phase = type(ph) == "number" and ph or hashPhase(baseName)
	byKit[baseName] = s
	return s
end

local function inert(p, isStone)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
	p.CastShadow = isStone
	p.Transparency, p.Reflectance = 0, 0
	p.Material = Enum.Material.SmoothPlastic
end

--- The piece's colours and materials as cloned: stone white (its vertex colours), Brk INNER, Dead dark; the Lit seam is
--- set by SetLevel.
local function dress(piece)
	local w = piece.Wrap
	piece.Stone.Color = (w and (w.Tint[piece.Kit.Name] or w.Tint.TerraWall2)) or WHITE
	piece.Stone.Material = Enum.Material.SmoothPlastic
	local Tn = w and w.Tn or ChargedRock.Tuning
	if piece.Brk then
		piece.Brk.Material = Enum.Material.SmoothPlastic
		piece.Brk.Color = Tn.Inner
	end
	if piece.Dead then
		piece.Dead.Material = Enum.Material.SmoothPlastic
		piece.Dead.Color = Tn.Dead
	end
	piece._lk, piece._bk = nil, nil
end

--- A copy of one kit rock piece: `baseName` and its "_Brk", "_Lit" and "_Dead" (each optional), cloned out of
--- `kitFolder` (searched by name, recursively), anchored and inert, CastShadow on the stone only, parented to the FX
--- folder and parked out of sight -- PLACE IT IN THE SAME FRAME. Returns
---   { Stone, Brk?, Lit?, Dead?, Rel = { [part] = CFrame relative to the stone }, Phase, Level = 0 }
--- (plus private fields), or nil (warned once) when the kit has no stone of that name. A released piece of the same
--- name is reused before anything is cloned.
-- WRAPS (SkinCatalog, 2026-10-10): `character`'s wrap for Terra's `ability` (validated by SkinCatalog.Chosen off their
-- replicated choice), as what Clone takes -- the kit tints and a copy of the tuning with the magma ramp -- or nil.
local wraps = {}
function ChargedRock.WrapOf(character, ability)
	local Players = game:GetService("Players")
	local plr = typeof(character) == "Instance" and Players:GetPlayerFromCharacter(character) or nil
	if not plr then return nil end
	local mod = ReplicatedStorage:FindFirstChild("Spellshot") and ReplicatedStorage.Spellshot:FindFirstChild("SkinCatalog")
	local ok, S = pcall(require, mod)
	if not ok then return nil end
	local skin = S.Resolve("Terra", ability, S.Chosen(plr, ability))
	if not (type(skin) == "table" and skin.Tint and skin.Seam) then return nil end
	local own = plr == Players.LocalPlayer
	local g = mod:GetAttribute("CrackGlow")
	if type(g) ~= "number" then g = skin.CrackGlow or 0.6 end
	if own then
		local k = mod:GetAttribute("CrackGlowOwn")
		g *= (type(k) == "number" and k) or skin.CrackGlowOwn or 0.8
	end
	local key = skin.Id .. (own and "+" or "") .. math.floor(math.clamp(g, 0, 1) * 20 + 0.5)
	local w = wraps[key]
	if not w then
		local sm = skin.Seam
		w = { Key = key, Skin = skin, Tint = skin.Tint, Tn = setmetatable({ EmberColour = sm.Ember,
			Gold = sm.Ember:Lerp(sm.Hot, math.clamp(0.4 + g, 0, 1)), Inner = sm.Inner, Dead = sm.Dead },
			{ __index = ChargedRock.Tuning }) }
		wraps[key] = w
	end
	return w
end

function ChargedRock.Clone(kitFolder, baseName, wrap)
	if typeof(kitFolder) ~= "Instance" or type(baseName) ~= "string" then return nil end
	local folder = fxFolder()
	local byKit = pools[kitFolder]
	local poolKey = wrap and (baseName .. "@" .. wrap.Key) or baseName
	local pool = byKit and byKit[poolKey]
	while pool and #pool > 0 do
		local piece = table.remove(pool)
		local ok = pcall(function()
			for _, part in ipairs(piece._all) do
				part.CFrame = STASH
				part.Parent = folder
			end
		end)
		if ok then
			piece._released = nil
			piece.Level = 0
			table.clear(piece.Off)
			dress(piece)
			ChargedRock.SetLevel(piece, 0, 0)
			return piece
		end
		for _, part in ipairs(piece._all) do pcall(function() part:Destroy() end) end
	end
	local src = sourceOf(kitFolder, baseName)
	if not src then return nil end
	local stone = src.Stone:Clone()
	inert(stone, true)
	if stone:IsA("MeshPart") then stone.DoubleSided = false end
	local piece = { Stone = stone, Rel = {}, Phase = src.Phase, Level = 0, Name = baseName, Kit = kitFolder,
		Off = {}, _all = { stone }, _base = { [stone] = { Size = stone.Size } }, Wrap = wrap, PoolKey = poolKey }
	for _, kind in ipairs(OPTIONAL) do
		local s = src.Parts[kind]
		if s then
			local p = s:Clone()
			inert(p, false)
			if p:IsA("MeshPart") then p.DoubleSided = false end
			piece[kind] = p
			piece.Rel[p] = src.Rel[kind]
			piece._all[#piece._all + 1] = p
			piece._base[p] = { Size = p.Size, Rel = src.Rel[kind] }
		end
	end
	dress(piece)
	for _, part in ipairs(piece._all) do
		part.CFrame = STASH
		part.Parent = folder
	end
	ChargedRock.SetLevel(piece, 0, 0)
	return piece
end

--- Appends every (shown) part of the piece, the stone at `cf` and the rest at cf * Rel, to the caller's BulkMoveTo
--- lists (`list` of parts and `cfs` of CFrames, kept the same length).
function ChargedRock.Place(piece, cf, list, cfs)
	local n = #list + 1
	list[n], cfs[n] = piece.Stone, cf
	local off = piece.Off
	for part, rel in pairs(piece.Rel) do
		if not off[part] then
			n += 1
			list[n], cfs[n] = part, cf * rel
		end
	end
end

--- The piece at `level` (cr_level) at `t` seconds on the pulse's clock: the Lit seam's and the fracture faces' colour
--- and material. A write happens only when the quantised step changes.
function ChargedRock.SetLevel(piece, level, t)
	local Tn = piece.Wrap and piece.Wrap.Tn or ChargedRock.Tuning
	level = level or 0
	piece.Level = level
	local pulse = 1 + Tn.PulseA * math.sin(2 * math.pi * Tn.PulseHz * (t or 0) - (piece.Phase or 0))
	local m = math.max(0, 1 + level) * pulse
	local lit = piece.Lit
	if lit then
		local v = m * Tn.LitGain
		local key = v >= Tn.NeonFrom and math.floor(v * Tn.Quant + 0.5) or -1
		if piece._lk ~= key then
			piece._lk = key
			if key < 0 then
				lit.Material = Enum.Material.SmoothPlastic
				lit.Color = Tn.EmberColour
			else
				lit.Material = Enum.Material.Neon
				lit.Color = Tn.EmberColour:Lerp(Tn.Gold, clamp01(key / Tn.Quant / Tn.GlowSpan))
			end
		end
	end
	local brk = piece.Brk
	if brk then
		local key = -1
		if level > Tn.BrkNeonAt then
			key = math.floor(clamp01((level - Tn.BrkNeonAt) / Tn.BrkSpan * pulse) * Tn.Quant + 0.5)
		end
		if piece._bk ~= key then
			piece._bk = key
			if key < 0 then
				brk.Material = Enum.Material.SmoothPlastic
				brk.Color = Tn.Inner
			else
				brk.Material = Enum.Material.Neon
				brk.Color = Tn.EmberColour:Lerp(Tn.Gold, key / Tn.Quant)
			end
		end
	end
end

--- charged_rock.level_after_break: `a` s after the piece was broken off or shattered (a < 0: not yet) -- the flare, then
--- the ember it keeps.
function ChargedRock.AfterBreak(a)
	local Tn = ChargedRock.Tuning
	if a < 0 then return 0 end
	return Tn.Ember * (1 - math.exp(-a / Tn.EmberTau)) + Tn.BreakFlare * math.exp(-a / Tn.FlareTau)
end

--- charged_rock.level_at_break: a piece carrying a SUSTAINED level (the Wall's damage stage) when it broke `a` s ago --
--- that level decays under the break's own flare and ember, so a glowing slab flares as it shatters, never dims.
function ChargedRock.AtBreak(sustained, a)
	if a < 0 then return sustained end
	return sustained * math.exp(-a / ChargedRock.Tuning.EmberTau) + ChargedRock.AfterBreak(a)
end

--- charged_rock.level_after_hit: the extra level of a hit's flare `a` s after it (0 before it).
function ChargedRock.AfterHit(a)
	local Tn = ChargedRock.Tuning
	if a < 0 then return 0 end
	return Tn.HitFlare * math.exp(-a / Tn.HitTau)
end

--- Every part of the piece parented to nil, and the piece kept for the next Clone of its name (at most PoolPerName;
--- the rest are destroyed). Returns the piece.
function ChargedRock.Release(piece)
	if type(piece) ~= "table" or piece._released or not piece._all then return piece end
	piece._released = true
	if piece._scaled then ChargedRock.Scale(piece, 1) end
	local ok = pcall(function()
		for _, part in ipairs(piece._all) do part.Parent = nil end
	end)
	local kit = piece.Kit
	if ok and kit then
		local byKit = pools[kit]
		if not byKit then
			byKit = {}
			pools[kit] = byKit
		end
		local pool = byKit[piece.PoolKey or piece.Name]
		if not pool then
			pool = {}
			byKit[piece.PoolKey or piece.Name] = pool
		end
		if #pool < ChargedRock.Tuning.PoolPerName then
			pool[#pool + 1] = piece
			return piece
		end
	end
	for _, part in ipairs(piece._all) do pcall(function() part:Destroy() end) end
	return piece
end

----------------------------------------------------------------------------------------------------
-- extras (see the header)
----------------------------------------------------------------------------------------------------
--- Hides (on = false) or shows one optional part of the piece -- "Brk", "Lit" or "Dead". The stone cannot be hidden.
--- A shown part is where it was last placed: place the piece again this frame.
function ChargedRock.Show(piece, kind, on)
	local part = piece[kind]
	if not part or kind == "Stone" or piece._released then return end
	local hidden = piece.Off[part] == true
	if on and hidden then
		piece.Off[part] = nil
		part.Parent = fxFolder()
	elseif not on and not hidden then
		piece.Off[part] = true
		part.Parent = nil
	end
end

--- The piece's parts on screen.
function ChargedRock.Count(piece)
	local n = 1
	for part in pairs(piece.Rel) do
		if not piece.Off[part] then n += 1 end
	end
	return n
end

--- Every part of the piece at `k` (a number, or a Vector3 per axis of the STONE's frame) times its kit size, and each
--- part's Rel scaled with it. The kit's parts are imported axis-aligned to one another (the importer bakes rotation into
--- the mesh), so a per-axis scale stays a fair stretch of the whole piece.
function ChargedRock.Scale(piece, k)
	local kv = typeof(k) == "Vector3" and k or Vector3.one * (k or 1)
	piece._scaled = kv ~= Vector3.one
	for part, base in pairs(piece._base) do
		part.Size = base.Size * kv
		if base.Rel then
			piece.Rel[part] = CFrame.new(base.Rel.Position * kv) * base.Rel.Rotation
		end
	end
end

return ChargedRock

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
	  (2026-10-25, the Terra wrap ladder -- each gated on a NEW skin field: Default and Obsidian Magma are as before)
	  ChargedRock.DustColor(wrap, lib, kind)   a kit kind's dust in the wrap's Dust colours (a ColorSequence), or nil
	  ChargedRock.TerraWrap()                  the TerraWrap module (its layer and glow helpers), or nil
	  WrapOf copies a wrap's Pulse into the seams' own pulse (Tn.PulseHz / PulseA), and its Flow for SetLevel's colour
	  (2026-10-25, the ladder's round 2 -- each gated on a NEW skin field again; see THE STONE below)
	  ChargedRock.GreyOf(stone, wearer?)       the shared grey copy of a kit stone's mesh (a MeshPart to ApplyMesh), or
	                                           nil until it is built (the ask queues it); `wearer`: the part that will wear
	                                           it, so the budget's freer can put that part back on its own mesh before it
	                                           lets go (a copy handed out with no wearer is kept for the session)
	  ChargedRock.Prewarm(kitFolder)           every stone of the kit queued for its grey copy (background, low priority)
	  ChargedRock.KitHint(kitFolder, hint)     what a builder knows of its kit: { Skip, Height, Faces } (see KitHint)
	  ChargedRock.StoneLook(wrap, kit, stone)  a kit stone's tone, Material and Reflectance under the wrap's Stone, or nil
	  ChargedRock.HasCrystal(wrap, kit, name)  whether a piece of that name carries an Epic crystal (CrystalsBaked)
	  Clone(kit, name, wrap, plain)            `plain`: a piece that is not the kit's stone (the Wall's ground plates,
	                                           which take the floor's colour): no Stone material, no crystal
	  dress applies the Stone (Stone: the grey copy, strata tone, variants), the crystals (CrystalsBaked: a fifth optional
	  part, "Crystal", riding the piece through Place / Show / Release / Scale) and the Mythic Core (Core: every Brk face
	  Neon Core.Color, toward Core.HotColor in a flare); SetLevel drives the Core and the crystals' breath
	EVERY NUMBER HERE IS A PROPOSAL, except the charged_rock.py v1.4 constants, which are copied exactly.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

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

-- (2026-10-25) THE WRAP LADDER's helpers are TerraWrap's (the ladder's contract, section 3): loaded only for a wrap
-- whose skin has Pulse, Flow or Layers (WrapOf, at the cast) -- never for Default or Obsidian Magma; false if it failed
local TerraWrap = nil
function ChargedRock.TerraWrap()
	if TerraWrap == nil then
		local ok, mod = pcall(function() return require(script.Parent:WaitForChild("TerraWrap")) end)
		TerraWrap = ok and type(mod) == "table" and mod or false
		if not TerraWrap then warn("[ChargedRock] TerraWrap did not load (no wrap layers or glow): " .. tostring(mod)) end
	end
	return TerraWrap or nil
end

-- (2026-10-25) A wrap's Dust (SkinCatalog Dust = { Light, Dark, Pale }) takes over VFXLibrary's Terra dust ROLES --
-- BOULDER_DUST -> Light, BOULDER_DUST_DARK -> Dark, AFTERSHOCK_DUST_PALE -> Pale -- keeping each preset's own sequence:
-- [lib .. kind] (A = AFTERSHOCK_KIT, B = BOULDER_KIT, read off VFXLibrary) = its keys, a role or { from, to, lerp }.
-- CloudDark / CloudPuff are Aftershock's two hard-coded slam clouds (#756145, #C2AD8C). The gold kinds (Spark, Ember,
-- Flash) have no dust role and stay as they are.
local DUST_ROLES = {
	AKick = { "Pale", "Light" }, ACloud = { "Light" }, ASkirt = { "Light" }, AGrit = { "Dark", "Light" },
	AFront = { "Light", { "Light", "Dark", 0.45 } }, ALanding = { "Light", { "Light", "Dark", 0.5 } },
	AHaze = { "Pale", "Light" }, ACloudDark = { "Dark" }, ACloudPuff = { "Pale" },
	BGather = { "Dark", "Light" }, BGatherGrit = { "Light", "Dark" }, BKick = { "Light" }, BKickGrit = { "Dark", "Light" },
	BMerge = { "Light" }, BRing = { "Light" }, BTrail = { "Light", "Dark" }, BCloud = { "Light" }, BSettle = { "Light" },
	BLanding = { "Light" },
}
-- ...a role the wrap leaves out keeps Default's
local DUST_DEFAULT = { Light = Color3.fromRGB(179, 158, 125), Dark = Color3.fromRGB(117, 97, 69),
	Pale = Color3.fromRGB(194, 173, 140) }

--- `kind` of VFXLibrary's `lib` ("A" Aftershock / "B" Boulder Shot) in `wrap`'s Dust colours, as a ColorSequence of the
--- preset's own shape -- or nil (no Dust, or a kind with no dust role). Built once per wrap and kind.
function ChargedRock.DustColor(wrap, lib, kind)
	local d = type(wrap) == "table" and type(wrap.Skin) == "table" and wrap.Skin.Dust
	if type(d) ~= "table" then return nil end
	local id = tostring(lib) .. tostring(kind)
	local made = wrap.DustCS
	if not made then
		made = {}
		wrap.DustCS = made
	end
	local cs = made[id]
	if cs == nil then
		cs = false
		local roles = DUST_ROLES[id]
		if roles then
			local function role(name)
				return typeof(d[name]) == "Color3" and d[name] or DUST_DEFAULT[name]
			end
			local cols = {}
			for i, r in ipairs(roles) do
				cols[i] = type(r) == "table" and role(r[1]):Lerp(role(r[2]), r[3]) or role(r)
			end
			cs = #cols == 1 and ColorSequence.new(cols[1]) or ColorSequence.new(cols[1], cols[2])
		end
		made[id] = cs
	end
	return cs or nil
end

-- (2026-10-25) a wrap's Flow at a piece: a Color3 multiplier and its write-key step (the colour's 8-bit channels), held
-- at the piece's last one under Reduce Flashing (`calm`). nil when the field cannot be read.
local function flowAt(piece, calm)
	if calm and piece._fm then return piece._fm, piece._fk end
	local pos = piece.Stone.Position
	local ok, c = pcall(TerraWrap.FlowMul, piece.Wrap.Skin, pos)
	if not (ok and typeof(c) == "Color3") then return nil, 0 end
	local k = math.floor(c.R * 255 + 0.5) * 65536 + math.floor(c.G * 255 + 0.5) * 256 + math.floor(c.B * 255 + 0.5)
	-- (a sample at the STASH -- Clone's own SetLevel, before its caller places the piece -- is never the one held: held,
	-- it gave every piece under Reduce Flashing the stash's one colour)
	if pos.Y < STASH.Y - 1000 then piece._fm, piece._fk = c, k end
	return c, k
end
local function tint(c, m) return Color3.new(c.R * m.R, c.G * m.G, c.B * m.B) end
local FLOW_FOLD = 1024    -- a write key is the brightness step (< FLOW_FOLD) + FLOW_FOLD x the flow step

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

----------------------------------------------------------------------------------------------------
-- (2026-10-25, the wrap ladder's round 2) THE STONE: a wrap's own base material on the baked kits (SkinCatalog Stone)
----------------------------------------------------------------------------------------------------
-- The kit stones carry their colour in their VERTEX colours (~75% near-black maroon, tan caps) and MeshPart.Color only
-- multiplies them, so no Tint ever reaches light sandstone, grey metal or violet crystal. So each unique stone mesh (by
-- MeshId) gets ONE grey copy per client, shared by every wrap: its vertex colours rewritten to the grey
-- k = 0.55 + 0.45 (lum / maxLum)^0.6 (the bake's grain and caps kept, as light and dark). A wrapped piece of a kit its
-- Stone lists wears it (ApplyMesh, its Size kept) under Color = its strata tone -- Tones[band] by its rest height in the
-- kit, band = floor(height / Band) mod #Tones -- times a deterministic Jitter, or a Pieces variant (tone, Material,
-- Reflectance) picked by a hash of its name. The copies are built off the draw path, GREY_JOBS at a time, a cast's own
-- pieces ahead of any prewarm, nothing new while MeshBudget.Busy() (a worn skin building) or just after the budget said
-- no. A mesh is loaded FIXED-size and recoloured in place (a fixed mesh takes colour writes, PyroDraw's toon pieces); if
-- the engine ever refuses that, a RESIZABLE one is recoloured, copied to a fixed one and destroyed on every path, two at
-- a time at most (inside the ~8 a client may hold: TerraWrap keeps 3). Until a piece's copy exists it draws exactly as
-- before (bake x Tint) -- never wrong, just not upgraded yet -- and it upgrades the moment its copy is built, pooled or
-- on screen. MeshBudget's Optional freer lets go of every copy no live piece wears (the pooled ones back on their own
-- mesh first). A piece with no wrap, or a wrap with no Stone (Obsidian Magma), never reaches any of this.
local GREY_JOBS = { Fixed = 3, Resizable = 2 }   -- builds at once (one until the first build has found which way works)
local CRYSTAL_MIN = 0.55   -- studs: a stone smaller than this (its two longest sides' geometric mean) grows no crystal
local CELL_REF = 2.2       -- studs: the stone size a crystal's Size is relative to (TerraWrap's cells)
local grey = {}            -- [MeshId] = { Id, Source, State, Copy, Mesh, Lo, Hi, Top, Users, Parts, Lent, Fails, RetryAt,
                           --   InHi, InLo } -- (Lo / Hi: the mesh's box; InHi / InLo: in that queue)
local greyHi, greyLo = {}, {}           -- the queues: what a cast is drawing now, then the prewarms
local greyRun, greyActive, greyPause = false, 0, 0
local greyResz = 0         -- resizable meshes alive now (greyMake's fallback; never more than GREY_JOBS.Resizable)
local greyFixed = nil      -- does a fixed-size mesh take the colour write? nil until the first build finds out
local greySaid = {}        -- warnings given ("denied", "failed")
local greyFree, greyWorker -- (below: the budget's freer, the builder loop)
local kitInfo = setmetatable({}, { __mode = "k" })     -- [kit] = { Base = the lowest stone's foot (world Y) }
local hints = setmetatable({}, { __mode = "k" })       -- [kit] = KitHint's hint
local prewarmed = setmetatable({}, { __mode = "k" })   -- [kit] = os.clock() when Prewarm last queued its stones
local cryAsked = {}        -- [skin Id] = os.clock() of SetLevel's last crystal-template ask (holding them alive)
local budgetMod = nil      -- MeshBudget (false: not in the place)

--- A number in [0, 1) off the string `s` and `salt` -- deterministic, so every client gives a piece the same strata,
--- variant and crystal.
local function hash01(s, salt)
	local h = 7919 * salt + 17
	for i = 1, #s do h = (h * 131 + string.byte(s, i)) % 2147483629 end
	-- (2026-10-25, checkpoint) three rounds: one left names that differ only at the end ("BW_Slab_01" .. "_12") within
	-- 0.003 of each other, so every slab of a Wall took the same variant and no crystal pick ever passed
	for _ = 1, 3 do h = (h * 48271) % 2147483647 end
	return h / 2147483647
end

-- MeshBudget (the shared EditableMesh budget's order), required on the first grey copy asked for: the freer joins it
local function meshBudget()
	if budgetMod == nil then
		budgetMod = false
		local m = script.Parent:FindFirstChild("MeshBudget")
		local ok, mod = false, nil
		if m and m:IsA("ModuleScript") then ok, mod = pcall(require, m) end
		if ok and type(mod) == "table" then
			budgetMod = mod
			if type(mod.Optional) == "function" then mod.Optional(function() greyFree() end) end
		end
	end
	return budgetMod or nil
end

local function greyIsDenied(e)
	e = string.lower(tostring(e))
	return string.find(e, "permission", 1, true) ~= nil or string.find(e, "not allowed", 1, true) ~= nil
		or string.find(e, "fork", 1, true) ~= nil
end

--- Every vertex colour of `em` to its grey (see above). True when the write took -- the colour that changes most is read
--- back (a fixed-size mesh that refused the write still reads its bake).
local function greyRecolour(em)
	local ids = em:GetColors()
	local cols, lum, top = {}, {}, 0
	for i, id in ipairs(ids) do
		local c = em:GetColor(id)
		cols[i] = c
		lum[i] = c and (0.3 * c.R + 0.59 * c.G + 0.11 * c.B) or 1
		if lum[i] > top then top = lum[i] end
	end
	local probe, want, far = nil, 0, -1
	for i, id in ipairs(ids) do
		local k = top > 1e-4 and (0.55 + 0.45 * math.clamp(lum[i] / top, 0, 1) ^ 0.6) or 1
		local c = cols[i]
		local d = c and math.max(math.abs(c.R - k), math.abs(c.G - k), math.abs(c.B - k)) or 0
		if d > far then probe, want, far = id, k, d end
		em:SetColor(id, Color3.new(k, k, k))
	end
	if probe == nil or far < 0.02 then return true end   -- (nothing to tell apart: it was grey already)
	local c = em:GetColor(probe)
	return c ~= nil and math.abs(c.R - want) < 0.02 and math.abs(c.G - want) < 0.02 and math.abs(c.B - want) < 0.02
end

--- Builds entry `e`'s grey copy: e.Mesh (the fixed EditableMesh, kept while the copy lives), e.Copy (a MeshPart on it,
--- what a stone ApplyMesh-es) and its box (e.Lo / e.Hi, mesh space). Raises on any failure; a resizable mesh never
--- outlives this call.
local function greyMake(e)
	local AS = game:GetService("AssetService")
	local function load(fixed)
		local ok, m = pcall(function()
			return AS:CreateEditableMeshAsync(Content.fromUri(e.Id), { FixedSize = fixed })
		end)
		if not ok then error(greyIsDenied(m) and ("DENIED " .. e.Id) or tostring(m), 0) end
		if not m then error("EditableMesh budget: no room", 0) end
		return m
	end
	local mesh = nil
	if greyFixed ~= false then
		local em = load(true)
		local ok, took = pcall(greyRecolour, em)
		if ok and took then
			greyFixed = true
			mesh = em
		else
			pcall(function() em:Destroy() end)
			if greyFixed == nil then greyFixed = false end
		end
	end
	if not mesh then
		-- the resizable way: recoloured, copied to a fixed-size mesh, and destroyed whatever happened -- at most
		-- GREY_JOBS.Resizable alive at once, whatever the job count (a fixed-way build can land here for one mesh)
		while greyResz >= GREY_JOBS.Resizable do task.wait(0.1) end
		greyResz += 1
		local okL, em = pcall(load, false)
		if not okL then
			greyResz -= 1
			error(em, 0)
		end
		local okC, errC = pcall(greyRecolour, em)
		local okF, fixed = false, nil
		if okC then
			okF, fixed = pcall(function() return AS:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true }) end)
		end
		pcall(function() em:Destroy() end)
		greyResz -= 1
		if not okC then error(errC, 0) end
		if not (okF and fixed) then error("EditableMesh budget: no fixed copy (" .. tostring(fixed) .. ")", 0) end
		mesh = fixed
	end
	local okB, lo, hi = pcall(function()
		local a, b = Vector3.one * 1e9, -Vector3.one * 1e9
		for _, v in ipairs(mesh:GetVertices()) do
			local p = mesh:GetPosition(v)
			a, b = a:Min(p), b:Max(p)
		end
		return a, b
	end)
	local okP, mp = pcall(function()
		return AS:CreateMeshPartAsync(Content.fromObject(mesh), { CollisionFidelity = Enum.CollisionFidelity.Box })
	end)
	if not (okP and mp) then okP, mp = pcall(function() return AS:CreateMeshPartAsync(Content.fromObject(mesh)) end) end
	if not (okP and mp) then
		pcall(function() mesh:Destroy() end)
		error("no MeshPart for the copy: " .. tostring(mp), 0)
	end
	mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch = true, false, false, false
	e.Mesh, e.Copy = mesh, mp
	if okB and lo.X <= hi.X then e.Lo, e.Hi = lo, hi end
end

local greyUpgrade      -- (below, with dress: a piece put on its copy the moment the copy is built)
local function greyBuild(e)
	local ok, err = pcall(greyMake, e)
	if ok then
		e.State, e.UsedAt = "built", os.clock()
		for piece in pairs(e.Users) do
			local okU, errU = pcall(greyUpgrade, piece, e)
			if not okU and not greySaid.upgrade then
				greySaid.upgrade = true
				warn("[ChargedRock] a piece could not take its grey copy: " .. tostring(errU))
			end
		end
		return
	end
	if string.sub(tostring(err), 1, 7) == "DENIED " then
		-- a mesh this place may not copy (another account's upload): refused for the session, said once
		e.State = "denied"
		if not greySaid.denied then
			greySaid.denied = true
			warn("[ChargedRock] no permission to copy kit mesh " .. (string.match(e.Id, "%d+") or e.Id)
				.. " (and any like it): those stones keep their bake under a wrap's Stone")
		end
		return
	end
	-- the budget said no (or the engine did): this mesh waits longer each time, and nothing new starts for a moment
	e.Fails = (e.Fails or 0) + 1
	e.State, e.RetryAt = "failed", os.clock() + math.min(10 * 2 ^ (e.Fails - 1), 160)
	greyPause = math.max(greyPause, os.clock() + 4)
	-- (2026-10-25, checkpoint) the EditableMesh budget itself is full: nothing new starts for 30 s, so the queue waits it
	-- out at one failed try (and one engine warning) per 30 s instead of every queued copy failing in turn -- measured:
	-- a prewarm beside a worn Boulder set that is still building, or the Wall + Tomb + Aftershock all at once (~430
	-- copies), ran out. The queue is kept: the copies build once the budget has room (a set finishes, a freer runs).
	local s = string.lower(tostring(err))
	if string.find(s, "budget", 1, true) or string.find(s, "no room", 1, true) or string.find(s, "memory", 1, true) then
		greyPause = math.max(greyPause, os.clock() + 30)
	end
	if not greySaid.failed then
		greySaid.failed = true
		warn("[ChargedRock] a grey copy was not built (tried again later): " .. tostring(err))
	end
end

greyWorker = function()
	while true do
		local mb = meshBudget()
		while (mb and type(mb.Busy) == "function" and mb.Busy()) or os.clock() < greyPause do task.wait(0.5) end
		local jobs = greyFixed == nil and 1 or (greyFixed and GREY_JOBS.Fixed or GREY_JOBS.Resizable)
		if greyActive >= jobs then
			-- (no slot: wait, then the budget and the pause are asked again -- either may have begun meanwhile)
			task.wait(0.05)
			continue
		end
		local e = nil
		while not e and #greyHi > 0 do
			local x = table.remove(greyHi, 1)
			x.InHi = nil
			if x.State == "queued" then e = x end
		end
		while not e and #greyLo > 0 do
			local x = table.remove(greyLo, 1)
			x.InLo = nil
			if x.State == "queued" then e = x end
		end
		if not e then break end
		e.State = "building"
		greyActive += 1
		task.spawn(function()
			greyBuild(e)
			greyActive -= 1
		end)
	end
	greyRun = false
end

local function greyQueue(e, high)
	if e.State ~= "queued" then return end
	if high and not e.InHi then
		e.InHi = true
		greyHi[#greyHi + 1] = e
	elseif not (e.InHi or e.InLo) then
		e.InLo = true
		greyLo[#greyLo + 1] = e
	end
	if not greyRun then
		greyRun = true
		task.spawn(greyWorker)
	end
end

--- The grey-copy entry of kit stone `stone`'s mesh (any state), queued for its build when it has none yet (`high`: a
--- piece is being drawn with it now) -- or nil (not a client, not a mesh).
local function greyEntry(stone, high)
	if not RunService:IsClient() then return nil end
	if not (typeof(stone) == "Instance" and stone:IsA("MeshPart")) then return nil end
	local id = stone.MeshId
	if type(id) ~= "string" or id == "" then return nil end
	local e = grey[id]
	if not e then
		e = { Id = id, Source = stone, State = "queued", Fails = 0,
			Users = setmetatable({}, { __mode = "k" }), Parts = setmetatable({}, { __mode = "k" }) }
		grey[id] = e
		meshBudget()
	elseif e.State == "failed" and os.clock() >= (e.RetryAt or 0) then
		e.State = "queued"
	end
	if e.State == "queued" then greyQueue(e, high) end
	return e
end

-- the built entry of a kit stone's mesh, or nil (nothing queued)
local function greyBuilt(stone)
	local e = (typeof(stone) == "Instance" and stone:IsA("MeshPart")) and grey[stone.MeshId] or nil
	return (e and e.State == "built") and e or nil
end

-- a kit's stones: its MeshParts but the optional strips and faces (and whatever its hint Skips)
local function isStoneOf(kit, d)
	if not d:IsA("MeshPart") then return false end
	local n = d.Name
	if string.find(n, "_Brk$") or string.find(n, "_Lit$") or string.find(n, "_Dead$") then return false end
	local skip = hints[kit] and hints[kit].Skip
	return not (type(skip) == "table" and skip[n])
end

-- the kit's foot: its lowest stone's bottom (world Y), read once (a hint's Height replaces it)
local function kitOf(kit)
	local k = kitInfo[kit]
	if k then return k end
	local lo = math.huge
	for _, d in ipairs(kit:GetDescendants()) do
		if isStoneOf(kit, d) then
			local cf, s = d.CFrame, d.Size
			local hh = 0.5 * (math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z)
			lo = math.min(lo, cf.Position.Y - hh)
		end
	end
	k = { Base = lo < math.huge and lo or 0 }
	kitInfo[kit] = k
	return k
end

-- a kit stone's rest height over its kit's foot (studs): the strata's input
local function heightOf(kit, src)
	local h = hints[kit]
	if h and type(h.Height) == "function" then
		local ok, y = pcall(h.Height, src)
		if ok and type(y) == "number" and y == y then return y end
	end
	return src.Position.Y - kitOf(kit).Base
end

--- The wrap's Stone, checked once: { Tones, Band, Jitter, Pieces = { { Upto, Tone?, Material?, Reflectance } }, Kits },
--- or nil (no Stone, or one with no tone).
local function stoneSpec(w)
	local s = w.StoneSpec
	if s ~= nil then return s or nil end
	s = false
	local S = type(w.Skin) == "table" and w.Skin.Stone
	if type(S) == "table" and type(S.Kits) == "table" and type(S.Tones) == "table" then
		local tones = {}
		for _, c in ipairs(S.Tones) do
			if typeof(c) == "Color3" then tones[#tones + 1] = c end
		end
		if #tones > 0 then
			local pieces, upto = {}, 0
			for _, v in ipairs(type(S.Pieces) == "table" and S.Pieces or {}) do
				local sh = type(v) == "table" and tonumber(v.Share) or nil
				if sh and sh > 0 then
					upto = math.min(1, upto + sh)
					local mat = nil
					if type(v.Material) == "string" then
						local okM, m = pcall(function() return Enum.Material[v.Material] end)
						if okM and typeof(m) == "EnumItem" then mat = m end
					end
					pieces[#pieces + 1] = { Upto = upto, Tone = typeof(v.Tone) == "Color3" and v.Tone or nil, Material = mat,
						Reflectance = math.clamp(tonumber(v.Reflectance) or 0, 0, 0.3) }
				end
			end
			s = { Tones = tones, Band = math.max(0.05, tonumber(S.Band) or 1), Jitter = math.clamp(tonumber(S.Jitter) or 0, 0, 0.25),
				Pieces = pieces, Kits = S.Kits }
		end
	end
	w.StoneSpec = s
	return s or nil
end

--- A kit stone `src` (piece name `name`) under Stone `spec`: { Tone, Material, Reflectance } -- a Pieces variant by the
--- name's hash, else the strata tone by its rest height; times the Jitter.
local function lookFor(spec, kit, src, name)
	local tone, mat, refl = nil, Enum.Material.SmoothPlastic, 0
	local u = hash01(name, 1)
	for _, v in ipairs(spec.Pieces) do
		if u < v.Upto then
			tone, mat, refl = v.Tone, v.Material or mat, v.Reflectance
			break
		end
	end
	if not tone then
		local n = #spec.Tones
		tone = spec.Tones[math.floor(heightOf(kit, src) / spec.Band) % n + 1] or spec.Tones[1]
	end
	if spec.Jitter > 0 then
		local j = 1 + spec.Jitter * (2 * hash01(name, 2) - 1)
		tone = Color3.new(math.clamp(tone.R * j, 0, 1), math.clamp(tone.G * j, 0, 1), math.clamp(tone.B * j, 0, 1))
	end
	return { Spec = spec, Tone = tone, Material = mat, Reflectance = refl }
end
local function lookOf(piece, spec)
	local lk = piece._look
	if not (lk and lk.Spec == spec) then
		lk = lookFor(spec, piece.Kit, piece._src, piece.Name)
		piece._look = lk
	end
	return lk
end

-- the piece's stone onto its grey copy (its Size kept); false when the engine would not
local function greyWear(piece, e)
	if piece._grey == e then return true end
	local stone = piece.Stone
	local ok = pcall(function()
		local size = stone.Size
		stone:ApplyMesh(e.Copy)
		stone.Size = size
	end)
	if not ok then return false end
	pcall(function() stone.DoubleSided = false end)
	piece._grey = e
	e.Users[piece] = true
	return true
end
-- ...and back onto its kit mesh (the freer, or a copy gone); false when that failed
local function greyOff(piece)
	local stone, src = piece.Stone, piece._src
	piece._grey = nil
	local ok = src ~= nil and pcall(function()
		local size = stone.Size
		stone:ApplyMesh(src)
		stone.Size = size
	end)
	pcall(function()
		stone.DoubleSided = false
		stone.Reflectance = 0
	end)
	return ok
end

----------------------------------------------------------------------------------------------------
-- (2026-10-25, round 2) EPIC CRYSTALS (SkinCatalog CrystalsBaked): TerraWrap's crystal clusters grown out of a share of
-- the stones -- the piece's fifth optional part, "Crystal" (Neon, its Part.Color the Glow grey, breathing DOWN from it
-- with the wrap's Pulse in SetLevel), riding it through Place / Show / Release / Scale and pooled with it. On the face
-- the kit shows (its hint's Faces; else the top), sized to the stone, sunk by the template's own Sink.
----------------------------------------------------------------------------------------------------
-- the stone-local box axis nearest the kit-frame direction `d`
local function localAxis(cf, d)
	local v = cf:VectorToObjectSpace(d)
	local ax, ay, az = math.abs(v.X), math.abs(v.Y), math.abs(v.Z)
	if ax >= ay and ax >= az then return Vector3.new(v.X > 0 and 1 or -1, 0, 0) end
	if ay >= az then return Vector3.new(0, v.Y > 0 and 1 or -1, 0) end
	return Vector3.new(0, 0, v.Z > 0 and 1 or -1)
end
-- a frame whose +Y is `n`, turned `twist` about it
local function axisFrame(n, twist)
	local x = math.abs(n.Y) < 0.9 and Vector3.yAxis:Cross(n).Unit or Vector3.xAxis:Cross(n).Unit
	return CFrame.fromMatrix(Vector3.zero, x, n) * CFrame.Angles(0, twist, 0)
end

--- Where on its copy's mesh the face along part axis `n` really is (the bake's surface, not the box's): a fraction of
--- the mesh's box (x the stone's Size = part space), cast down onto it a little off the face's middle; nil if missed.
local function surfaceAt(e, n)
	if not (e and e.Mesh and typeof(e.Lo) == "Vector3" and typeof(e.Hi) == "Vector3") then return nil end
	e.Top = e.Top or {}
	local key = (n.X + 1) * 9 + (n.Y + 1) * 3 + (n.Z + 1)
	local f = e.Top[key]
	if f == nil then
		f = false
		local ext = e.Hi - e.Lo
		if ext.X > 1e-4 and ext.Y > 1e-4 and ext.Z > 1e-4 then
			local c = (e.Lo + e.Hi) / 2
			local plane = Vector3.new(1 - math.abs(n.X), 1 - math.abs(n.Y), 1 - math.abs(n.Z))
			local off = Vector3.new(hash01(e.Id, 5) - 0.5, hash01(e.Id, 6) - 0.5, hash01(e.Id, 7) - 0.5) * 0.35 * ext * plane
			local depth = math.abs(n:Dot(ext))
			local mesh = e.Mesh
			local ok, p = pcall(function() return mesh:RaycastLocal(c + off + n * (depth * 0.5 + 0.25), -n * (depth + 0.5)) end)
			if ok and typeof(p) == "Vector3" then f = (p - c) / ext end
		end
		e.Top[key] = f
	end
	return f or nil
end

--- Whether (and how) piece `name` of `kit` (kit stone `src`) grows a crystal under wrap `w`: { N (its face, a part
--- axis), K (the scale), Twist, Sink, Glow, V (the variant's pick) } or nil. Deterministic -- the template aside.
local function crystalPick(w, kit, name, src)
	local CB = w and w.Skin.CrystalsBaked
	if type(CB) ~= "table" or not (typeof(src) == "Instance" and src:IsA("BasePart")) then return nil end
	local spec = stoneSpec(w)
	if spec and not spec.Kits[kit.Name] then return nil end
	local share = tonumber(CB.PerPiece) or 0
	if share <= 0 or hash01(name, 3) >= share then return nil end
	local sz = { src.Size.X, src.Size.Y, src.Size.Z }
	table.sort(sz, function(a, b) return a > b end)
	local extent = math.sqrt(sz[1] * sz[2])
	if extent < CRYSTAL_MIN then return nil end
	local d = Vector3.yAxis
	local h = hints[kit]
	if h and type(h.Faces) == "function" then
		local ok, list = pcall(h.Faces, src)
		if ok and type(list) == "table" then
			if #list == 0 then return nil end   -- (no face of it shows)
			d = list[math.floor(hash01(name, 9) * #list) + 1]
		end
	end
	if typeof(d) ~= "Vector3" or d.Magnitude < 1e-3 then return nil end
	local C = type(w.Skin.Crystals) == "table" and w.Skin.Crystals or {}
	return { N = localAxis(src.CFrame, d.Unit), K = (tonumber(CB.Size) or 1) * math.clamp(extent / CELL_REF, 0.45, 1.4),
		Twist = hash01(name, 8) * 2 * math.pi, Sink = math.clamp(tonumber(C.Sink) or 0.3, 0, 0.85),
		Glow = math.clamp(tonumber(CB.Glow) or 1, 0, 1), V = hash01(name, 4) }
end

-- the crystal's frame on its stone (kit size): its root on the face -- on the mesh's own surface when the grey copy
-- exists (`e`), else on the box's face a fifth in -- the clone's centre carried off the root by cr.Ctr (TerraWrap's
-- CrystalRoot: the template is built with its prisms already sunk Sink into the face); a template without the attribute
-- is taken as rooted on its box's axis, Sink of its height up from its foot
local function crystalRel(piece, e)
	local cr = piece._cry
	local size = piece._base[piece.Stone].Size
	local n = cr.N
	local f = surfaceAt(e, n)
	cr.Surf = f ~= nil
	local point = f and f * size or n * (0.4 * math.abs(n:Dot(size)))
	return CFrame.new(point) * axisFrame(n, cr.Twist) * CFrame.new(cr.Ctr or Vector3.new(0, cr.H * (0.5 - cr.Sink), 0))
end

-- the wrap's crystal templates now (TerraWrap.CrystalTemplates; every ask holds them CRYSTAL_HOLD more), or nil
local function crystalTpls(w)
	local TW = ChargedRock.TerraWrap()
	if not (TW and type(TW.CrystalTemplates) == "function") then return nil end
	local ok, tpls = pcall(TW.CrystalTemplates, w.Skin)
	return (ok and type(tpls) == "table" and #tpls > 0) and tpls or nil
end

-- the piece's crystal taken off it and destroyed (its template was let go: the clone would draw nothing)
local function crystalDrop(piece)
	local c = piece.Crystal
	if not c then return end
	piece.Crystal, piece._cry, piece._ck = nil, nil, nil
	piece.Rel[c], piece._base[c], piece.Off[c] = nil, nil, nil
	local all = piece._all
	for i = #all, 1, -1 do
		if all[i] == c then table.remove(all, i) end
	end
	pcall(function() c:Destroy() end)
end

local function crystalFor(piece)
	local c = piece.Crystal
	if c then
		-- a pooled piece: its crystal as it was, its breath written again -- unless TerraWrap has since let its template
		-- go under MeshBudget pressure and handed out others (the clone's mesh is gone with it): grown again from those
		local cr = piece._cry
		local tpls = crystalTpls(piece.Wrap)
		if not (cr and cr.Tpl and tpls and not table.find(tpls, cr.Tpl)) then
			local g = cr and cr.Glow or 1
			c.Color = Color3.new(g, g, g)
			piece._ck = nil
			return
		end
		crystalDrop(piece)
		c = nil
	end
	if piece._noCry then return end
	local w = piece.Wrap
	local plan = crystalPick(w, piece.Kit, piece.Name, piece._src)
	if not plan then
		piece._noCry = true
		return
	end
	local tpls = crystalTpls(w)
	if not tpls then return end   -- (still building: its next dress)
	local tpl = tpls[math.floor(plan.V * #tpls) + 1]
	if not (typeof(tpl) == "Instance" and tpl:IsA("BasePart")) then return end
	local size = piece._base[piece.Stone].Size
	local n = plan.N
	local across = (math.abs(n.X) > 0.5 and math.min(size.Y, size.Z)) or (math.abs(n.Y) > 0.5 and math.min(size.X, size.Z))
		or math.min(size.X, size.Y)
	local k = plan.K
	local foot = math.max(tpl.Size.X, tpl.Size.Z)
	if foot > 1e-3 then k = math.min(k, 0.9 * across / foot) end   -- (no wider than the face it grows from)
	if tpl.Size.Y * k < 0.12 then
		piece._noCry = true
		return
	end
	local okC, made = pcall(function() return tpl:Clone() end)
	if not (okC and made) then return end
	c = made
	c.Name = piece.Name .. "_Crystal"
	c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch, c.Massless, c.CastShadow = true, false, false, false, true, false
	c.Material = Enum.Material.Neon
	c.Transparency, c.Reflectance = 0, 0
	c.Size = tpl.Size * k
	c.Color = Color3.new(plan.Glow, plan.Glow, plan.Glow)
	plan.H = c.Size.Y
	local root = tpl:GetAttribute("CrystalRoot")       -- (TerraWrap: the root in the template's frame, at its size)
	plan.Ctr = typeof(root) == "Vector3" and -root * k or nil
	plan.Tpl = tpl
	piece._cry = plan
	local rel = crystalRel(piece, piece._grey or greyBuilt(piece._src))
	piece.Crystal = c
	piece.Rel[c] = rel
	piece._all[#piece._all + 1] = c
	piece._base[c] = { Size = c.Size, Rel = rel, Uniform = true }
	piece._ck = nil
	c.CFrame = STASH
	c.Parent = fxFolder()
end

--- (round 2) A wrapped piece's Stone and crystals (dress, for a wrap with Stone or CrystalsBaked): on its grey copy in
--- its look once the copy exists (asked for now if not: it upgrades when built), else left as dress made it.
local function dressStone(piece)
	local w = piece.Wrap
	local spec = stoneSpec(w)
	local src = piece._src
	if spec and src and spec.Kits[piece.Kit.Name] then
		local e = greyEntry(src, true)
		if e then
			e.Users[piece] = true
			if e.State == "built" and greyWear(piece, e) then
				e.UsedAt = os.clock()
				local lk = lookOf(piece, spec)
				local st = piece.Stone
				st.Color, st.Material, st.Reflectance = lk.Tone, lk.Material, lk.Reflectance
			elseif piece._grey then
				greyOff(piece)
			end
		end
	elseif piece._grey then
		greyOff(piece)
	end
	if type(w.Skin.CrystalsBaked) == "table" then crystalFor(piece) end
end

--- A copy just built: every piece that asked for it onto it, in its look -- pooled or on screen -- and a crystal that
--- was set on the box's face before it existed moved onto the stone's own surface.
greyUpgrade = function(piece, e)
	if piece._grey == e or piece.Plain or type(piece.Wrap) ~= "table" then return end
	local spec = stoneSpec(piece.Wrap)
	local src = piece._src
	if not (spec and src and spec.Kits[piece.Kit.Name] and src.MeshId == e.Id) then return end
	if not greyWear(piece, e) then return end
	local lk = lookOf(piece, spec)
	local st = piece.Stone
	st.Color, st.Material, st.Reflectance = lk.Tone, lk.Material, lk.Reflectance
	local c = piece.Crystal
	if c and piece._cry and not piece._cry.Surf and not piece._scaled then
		local rel = crystalRel(piece, e)
		piece.Rel[c] = rel
		piece._base[c].Rel = rel
		if c.Parent and not piece.Off[c] and not piece._released then c.CFrame = st.CFrame * rel end
	end
end

--- MeshBudget's Optional: a worn skin's build was refused room. Every grey copy no live piece wears goes (the pooled
--- pieces wearing it back on their kit mesh first, or let go), the prewarms are dropped and nothing new is built for a
--- while; the next ask builds a copy again. A copy lent out with no wearer (GreyOf) is never freed.
greyFree = function()
	greyPause = math.max(greyPause, os.clock() + 15)
	-- (2026-10-25, checkpoint) the prewarm queue is KEPT, paused: dropping it left its entries "queued" in no queue, so
	-- nothing rebuilt them until a later cast happened to ask (measured: a worn Boulder set's one refusal at login left
	-- all 364 Wall / Tomb copies unbuilt)
	table.clear(prewarmed)
	for id, e in pairs(grey) do
		if e.State == "built" and not e.Lent then
			local busy = false
			for piece in pairs(e.Users) do
				if piece._grey == e and not piece._released then
					busy = true
					break
				end
			end
			if not busy then
				for part in pairs(e.Parts) do
					if part.Parent ~= nil then
						busy = true
						break
					end
				end
			end
			if not busy then
				local clean = true
				for piece in pairs(e.Users) do
					if piece._grey == e and not greyOff(piece) then
						-- (no way back onto its own mesh: the pooled piece goes -- Clone throws a dead one away)
						for _, part in ipairs(piece._all or {}) do pcall(function() part:Destroy() end) end
					end
				end
				for part in pairs(e.Parts) do
					local ok = pcall(function()
						local size = part.Size
						part:ApplyMesh(e.Source)
						part.Size = size
					end)
					if ok then e.Parts[part] = nil else clean = false end
				end
				if clean then
					pcall(function() e.Copy:Destroy() end)
					pcall(function() e.Mesh:Destroy() end)
					e.State, e.Copy, e.Mesh = "gone", nil, nil
					grey[id] = nil
				end
			end
		end
	end
end

--- The piece's colours and materials as cloned: stone white (its vertex colours), Brk INNER, Dead dark; the Lit seam is
--- set by SetLevel.
local function dress(piece)
	local w = piece.Wrap
	piece.Stone.Color = (w and (w.Tint[piece.Kit.Name] or w.Tint.TerraWall2)) or WHITE
	piece.Stone.Material = Enum.Material.SmoothPlastic
	-- (2026-10-25, round 2) a wrap's Stone (the grey copy in its look) and Epic crystals -- never a plain piece's (the
	-- Wall's ground plates); a failure leaves the piece as dressed above, never the cast without it
	if w and not piece.Plain and (w.Skin.Stone or w.Skin.CrystalsBaked) then
		local ok, err = pcall(dressStone, piece)
		if not ok and not greySaid.dress then
			greySaid.dress = true
			warn("[ChargedRock] a wrap's Stone / crystals were not applied: " .. tostring(err))
		end
	end
	local Tn = w and w.Tn or ChargedRock.Tuning
	if piece.Brk then
		if Tn.Core then
			-- (2026-10-25, round 2) MYTHIC Core: the fracture faces molten, always (SetLevel heats them in a flare)
			piece.Brk.Material = Enum.Material.Neon
			piece.Brk.Color = Tn.Core.Color
		else
			piece.Brk.Material = Enum.Material.SmoothPlastic
			piece.Brk.Color = Tn.Inner
		end
	end
	if piece.Dead then
		piece.Dead.Material = Enum.Material.SmoothPlastic
		piece.Dead.Color = Tn.Dead
	end
	piece._lk, piece._bk = nil, nil
	piece._fm = nil        -- (2026-10-25) a Flow wrap's held colour (flowAt) is re-read in a reused piece's new place
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
	-- (2026-10-25) Studio: a test rig's WrapStudio previews any Terra wrap (Terra's wraps are Element wraps now)
	local studioId = nil
	if not plr and typeof(character) == "Instance" and game:GetService("RunService"):IsStudio() then
		local ws = character:GetAttribute("WrapStudio")
		if type(ws) == "string" and ws ~= "Default" then studioId = ws end
	end
	if not plr and not studioId then return nil end
	local mod = ReplicatedStorage:FindFirstChild("Spellshot") and ReplicatedStorage.Spellshot:FindFirstChild("SkinCatalog")
	local ok, S = pcall(require, mod)
	if not ok then return nil end
	local skin = S.Resolve("Terra", ability, studioId or S.Chosen(plr, ability))
	if not (type(skin) == "table" and skin.Tint and skin.Seam) then return nil end
	local own = plr ~= nil and plr == Players.LocalPlayer
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
		-- (2026-10-25) the wrap ladder: a Pulse (Epic+) is the seams' own pulse, at its Period and Amp; a Flow (Mythic) is
		-- TerraWrap's world field on the Lit seams and the Brk flares (SetLevel). A wrap with neither (Obsidian Magma)
		-- keeps the Tn above exactly. TerraWrap is loaded here, at the cast, for any wrap that uses it (Layers too).
		if skin.Pulse or skin.Flow or skin.Layers then
			local TW = ChargedRock.TerraWrap()
			local Tn = w.Tn
			local pz = skin.Pulse
			if type(pz) == "table" and type(pz.Period) == "number" and pz.Period > 0 then
				Tn.PulseHz = 1 / pz.Period
				if type(pz.Amp) == "number" then Tn.PulseA = pz.Amp end
			end
			if TW and type(skin.Flow) == "table" and type(TW.FlowMul) == "function" then Tn.Flow = skin.Flow end
			if TW and (skin.Pulse or skin.Flow) and type(TW.Calm) == "function" then Tn.WrapCalm = TW.Calm end
		end
		-- (2026-10-25, round 2) MYTHIC Core (Core.Brk): every fracture face Neon Core.Color always, toward Core.HotColor in
		-- a flare (dress / SetLevel). A wrap without it keeps the INNER faces and their ember-to-gold flare exactly.
		local core = skin.Core
		if type(core) == "table" and core.Brk and typeof(core.Color) == "Color3" then
			w.Tn.Core = { Color = core.Color, Hot = typeof(core.HotColor) == "Color3" and core.HotColor or w.Tn.Gold }
		end
		wraps[key] = w
	end
	return w
end

-- (2026-10-25, round 2) `plain`: a piece that is not the kit's stone (the Wall's ground plates: the floor's colour) --
-- no Stone, no crystal; pooled apart from the stone pieces of its name only for a wrap that has either
function ChargedRock.Clone(kitFolder, baseName, wrap, plain)
	if typeof(kitFolder) ~= "Instance" or type(baseName) ~= "string" then return nil end
	local folder = fxFolder()
	local byKit = pools[kitFolder]
	local poolKey = wrap and (baseName .. "@" .. wrap.Key) or baseName
	if wrap and plain and (wrap.Skin.Stone or wrap.Skin.CrystalsBaked) then poolKey ..= "~" end
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
	if wrap then                    -- (2026-10-25, round 2) the kit stone (its mesh, its rest), and a plain piece's mark
		piece._src = src.Stone
		piece.Plain = plain and true or nil
	end
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

--- (2026-10-19, audit P5B-05) Settings "ReduceFlashing", read at most twice a second (client only; false on the server)
local calmState = { At = -1, On = false }
function ChargedRock.Calm()
	local now = os.clock()
	if now - calmState.At > 0.5 then
		calmState.At = now
		local ok, on = pcall(function()
			local sp = ReplicatedStorage:FindFirstChild("Spellshot")
			local m = sp and sp:FindFirstChild("SpellshotSettings")
			local S = m and require(m)
			return S and S.Get and S.Get("ReduceFlashing")
		end)
		calmState.On = ok and on == true
	end
	return calmState.On
end

--- The piece at `level` (cr_level) at `t` seconds on the pulse's clock: the Lit seam's and the fracture faces' colour
--- and material. A write happens only when the quantised step changes. Under Reduce Flashing the pulse holds at 1.
function ChargedRock.SetLevel(piece, level, t)
	local Tn = piece.Wrap and piece.Wrap.Tn or ChargedRock.Tuning
	level = level or 0
	piece.Level = level
	local calm = ChargedRock.Calm()
	if not calm and Tn.WrapCalm then           -- (2026-10-25) a Pulse / Flow wrap: TerraWrap's Calm (Studio's switch too)
		local ok, on = pcall(Tn.WrapCalm)
		calm = ok and on == true
	end
	local pulse = calm and 1 or (1 + Tn.PulseA * math.sin(2 * math.pi * Tn.PulseHz * (t or 0) - (piece.Phase or 0)))
	local m = math.max(0, 1 + level) * pulse
	-- (2026-10-25) a Mythic wrap's Flow: the Lit seam and the Brk flare times TerraWrap's world field at the piece, its
	-- step folded into the write key (a colour moving at one brightness would never pass the brightness cache)
	local fm, fk = nil, 0
	if Tn.Flow and (piece.Lit or piece.Brk) then fm, fk = flowAt(piece, calm) end   -- (a bare stone has nothing to tint)
	local lit = piece.Lit
	if lit then
		local v = m * Tn.LitGain
		local key = v >= Tn.NeonFrom and math.floor(v * Tn.Quant + 0.5) or -1
		local wk = (fm and key >= 0) and key + FLOW_FOLD * fk or key
		if piece._lk ~= wk then
			piece._lk = wk
			if key < 0 then
				lit.Material = Enum.Material.SmoothPlastic
				lit.Color = Tn.EmberColour
			else
				lit.Material = Enum.Material.Neon
				local c = Tn.EmberColour:Lerp(Tn.Gold, clamp01(key / Tn.Quant / Tn.GlowSpan))
				lit.Color = fm and tint(c, fm) or c
			end
		end
	end
	local brk = piece.Brk
	if brk then
		local key = -1
		if level > Tn.BrkNeonAt then
			key = math.floor(clamp01((level - Tn.BrkNeonAt) / Tn.BrkSpan * pulse) * Tn.Quant + 0.5)
		end
		local core = Tn.Core
		if core then
			-- (2026-10-25, round 2) MYTHIC Core: always Neon -- Core.Color unflared, toward Core.Hot by the flare's step
			-- (the Flow, if any, on both: its step folded in, as on the Lit seam)
			local wk = (key + 1) + (fm and FLOW_FOLD * fk or 0)
			if piece._bk ~= wk then
				piece._bk = wk
				brk.Material = Enum.Material.Neon
				local c = key < 0 and core.Color or core.Color:Lerp(core.Hot, key / Tn.Quant)
				brk.Color = fm and tint(c, fm) or c
			end
		else
			local wk = (fm and key >= 0) and key + FLOW_FOLD * fk or key
			if piece._bk ~= wk then
				piece._bk = wk
				if key < 0 then
					brk.Material = Enum.Material.SmoothPlastic
					brk.Color = Tn.Inner
				else
					brk.Material = Enum.Material.Neon
					local c = Tn.EmberColour:Lerp(Tn.Gold, key / Tn.Quant)
					brk.Color = fm and tint(c, fm) or c
				end
			end
		end
	end
	-- (2026-10-25, round 2) EPIC crystals (CrystalsBaked): their Neon grey breathes DOWN from Glow with the wrap's Pulse
	-- (TerraWrap's rule: a Part.Color cannot pass white), on the piece's own phase; held at Glow under Reduce Flashing
	local cry = piece.Crystal
	local cr = cry and piece._cry
	if cr then
		-- a crystal on screen keeps its template asked for (TerraWrap lets one go CRYSTAL_HOLD after its last ask under
		-- MeshBudget pressure, its clones' mesh with it -- and a Wall can stand for minutes): one ask per wrap every 10 s
		local sid = piece.Wrap and piece.Wrap.Skin.Id
		local nowC = os.clock()
		if sid and nowC - (cryAsked[sid] or -math.huge) > 10 then
			cryAsked[sid] = nowC
			crystalTpls(piece.Wrap)
		end
		local g = cr.Glow
		local P = piece.Wrap and piece.Wrap.Skin.Pulse
		if not calm and type(P) == "table" and type(P.Period) == "number" and P.Period > 0 then
			g *= 1 - (tonumber(P.Amp) or 0) * (1 - math.sin(2 * math.pi * (t or 0) / P.Period - (piece.Phase or 0)))
		end
		local q = math.floor(math.clamp(g, 0, 1) * 48 + 0.5)
		if piece._ck ~= q then
			piece._ck = q
			cry.Color = Color3.new(q / 48, q / 48, q / 48)
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
		-- (2026-10-25, round 2) a crystal (Uniform) keeps its shape: one factor, the stretch's mean; it still rides the face
		part.Size = base.Size * (base.Uniform and (kv.X * kv.Y * kv.Z) ^ (1 / 3) or kv)
		if base.Rel then
			piece.Rel[part] = CFrame.new(base.Rel.Position * kv) * base.Rel.Rotation
		end
	end
end

----------------------------------------------------------------------------------------------------
-- (2026-10-25, round 2) THE STONE's public side (see THE STONE above). Every call is a no-op on the server.
----------------------------------------------------------------------------------------------------
--- The shared grey copy of kit stone `stone`'s mesh -- a MeshPart: `part:ApplyMesh(copy)` (keep part.Size), then
--- part.Color = the wanted tone -- or nil while it is not built (this ask queues it, ahead of the prewarms). `wearer`:
--- the part that will wear it; the budget's freer then puts it back on `stone`'s mesh before letting the copy go. A copy
--- handed out with no wearer is never freed.
function ChargedRock.GreyOf(stone, wearer)
	local e = greyEntry(stone, true)
	if not (e and e.State == "built") then return nil end
	e.UsedAt = os.clock()
	if typeof(wearer) == "Instance" then e.Parts[wearer] = true else e.Lent = true end
	return e.Copy
end

--- (2026-10-25) the grey copies' states, counted ({ queued = n, built = n, failed = n, ... }): read-only, for checks
function ChargedRock.GreyStats()
	local n = {}
	for _, e in pairs(grey) do n[e.State] = (n[e.State] or 0) + 1 end
	return n
end

--- Every stone of `kitFolder` (but its hint's Skip) queued for its grey copy, behind anything a cast asks for, stopped
--- by budget pressure (MeshBudget's freer drops the queue). Cheap again and again: a kit is walked at most every 30 s.
function ChargedRock.Prewarm(kitFolder)
	if typeof(kitFolder) ~= "Instance" or not RunService:IsClient() then return end
	local now = os.clock()
	if prewarmed[kitFolder] and now - prewarmed[kitFolder] < 30 then return end
	prewarmed[kitFolder] = now
	for _, d in ipairs(kitFolder:GetDescendants()) do
		if isStoneOf(kitFolder, d) then greyEntry(d, false) end
	end
end

--- What a builder knows of its kit, for the Stone and the crystals: `hint` = {
---   Skip   = { [name] = true }            parts of the kit that are not its stone (no grey copy is built for them)
---   Height = function(stone) -> studs     a kit stone's rest height over the kit's foot (its strata)
---   Faces  = function(stone) -> { dir }   the directions (the kit's frame) a crystal may grow toward; {} = none
--- }. Without one: every MeshPart of the kit, heights over its lowest stone, crystals growing up.
function ChargedRock.KitHint(kitFolder, hint)
	if typeof(kitFolder) ~= "Instance" then return end
	hints[kitFolder] = type(hint) == "table" and hint or nil
	kitInfo[kitFolder] = nil
	-- a Prewarm that walked the kit before its builder gave this hint (TerraFX.WatchWraps, at the wrap's equip) queued
	-- the Skip parts too: those still only queued, and asked for by nothing, leave the queue (the worker drops them)
	local skip = hints[kitFolder] and hints[kitFolder].Skip
	if type(skip) == "table" then
		for name in pairs(skip) do
			local d = type(name) == "string" and kitFolder:FindFirstChild(name, true) or nil
			local e = d and d:IsA("MeshPart") and grey[d.MeshId] or nil
			if e and e.State == "queued" and next(e.Users) == nil and next(e.Parts) == nil and not e.Lent then
				e.State = "skipped"
				grey[d.MeshId] = nil
			end
		end
	end
end

--- Kit stone `stone` of `kitFolder` under `wrap`'s Stone (a WrapOf object): its tone, Material and Reflectance -- the
--- strata, the variants and the Jitter exactly as its pieces get them -- or nil (no Stone, or not for this kit).
function ChargedRock.StoneLook(wrap, kitFolder, stone)
	if not (type(wrap) == "table" and type(wrap.Skin) == "table" and typeof(kitFolder) == "Instance"
		and typeof(stone) == "Instance" and stone:IsA("BasePart")) then return nil end
	local spec = stoneSpec(wrap)
	if not (spec and spec.Kits[kitFolder.Name]) then return nil end
	local lk = lookFor(spec, kitFolder, stone, stone.Name)
	return lk.Tone, lk.Material, lk.Reflectance
end

--- Whether piece `baseName` of `kitFolder` grows an Epic crystal under `wrap` (CrystalsBaked's share, its size, a face
--- that shows) -- what a budget can plan on before it is cloned (the template's own size may still turn one down).
function ChargedRock.HasCrystal(wrap, kitFolder, baseName)
	if not (type(wrap) == "table" and type(wrap.Skin) == "table" and type(wrap.Skin.CrystalsBaked) == "table") then
		return false
	end
	if typeof(kitFolder) ~= "Instance" or type(baseName) ~= "string" then return false end
	local src = sourceOf(kitFolder, baseName)
	return src ~= nil and crystalPick(wrap, kitFolder, baseName, src.Stone) ~= nil
end

return ChargedRock

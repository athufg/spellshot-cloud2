--[[
	HubShowcaseM1  (ModuleScript)  ->  ReplicatedStorage/Spellshot/HubShowcaseM1

	The wrap pedestal's held prop (2026-10-26, the owner: the statue holds each wrap's REAL M1, not a stand-in sphere).
	One display per Element: M.<Element>(wrapId, cf, parent) -> { Update(t), Destroy() } draws that Element's own combat
	M1 projectile -- its real draw code / assets -- in the wrap's colours, held static at cf (cf.LookVector = its flight
	direction). Client only; no remotes, no damage, no hit tests. Used by HubShowcase.
	Elements drawn: Pyro, Radiant, Cryo, Aqua, Umbra, Toxin (the wrap pedestal), and Terra, Voltaic, Zephyr (2026-10-26,
	the owner's request for the Loadout Altar showcase: every Element's M1 previewed in the hub, no body holding it).
	Voltaic and Zephyr have no wraps: their wrapId is ignored. Each new entry is its Element's REAL draw, held and still
	moving inside itself (Terra's slow turn and glow, the Chain Bolt re-fired in place, the Wind Blade re-released).
	(2026-10-26) SKINS: M.<Element>(wrapId, cf, parent, skinId?) -- a skin id draws that skin's own reworked M1 (Cryo:
	Frostblade / Snow Globe / Frost Lotus / Frost Dragon; Toxin: Pixel Potion / Scorpion / Witch's Brew / Hydra; Radiant:
	Devil). nil or "Default": exactly as before. See SKINS below.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local M = {}

-- ====================================================================================================
-- SKINS (2026-10-26)
-- ====================================================================================================
-- A skin id (one of SkinCatalog.ElementSkins[Element]; nil / "Default": none) draws that skin's own M1. Where the draw
-- needs a caster, an invisible, client-only stand-in Model wears the skin by THE SHOWCASE CONVENTION: the attribute
-- ShowcaseSkin = skinId (and StudioSkin, for Studio tests) on a model no player owns -- every skin kit treats such a model
-- as wearing that skin, live and in Studio, and builds its meshes for it. A wrap goes over the skin only where the
-- catalog allows (SkinCatalog.WrapsOverSkin: a colour wrap with Stops); otherwise the skin is drawn in its own colours.
local function catalog()
	local ok, SC = pcall(function() return require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog")) end)
	return (ok and type(SC) == "table") and SC or nil
end
--- `skinId` when it is one of `element`'s skins, else nil (the Default; an unknown id is warned of)
local function skinOf(element, skinId)
	if type(skinId) ~= "string" or skinId == "" or skinId == "Default" then return nil end
	local SC = catalog()
	if SC and type(SC.ElementSkinAllowed) == "function" and SC.ElementSkinAllowed(element, skinId) then return skinId end
	warn("[HubShowcaseM1] " .. element .. " skin " .. tostring(skinId) .. " unavailable - Default drawn")
	return nil
end
--- the wrap drawn with `skin`: `wrapId` with no skin, or when the catalog lets it go over a skin; else "Default"
local function wrapWith(skin, wrapId, element)
	if not skin then return wrapId end
	if type(wrapId) ~= "string" or wrapId == "Default" then return "Default" end
	-- (2026-10-27, the owner) any of the Element's wraps goes over its skin, as in a duel: CryoWrap / ToxinWrap paint the
	-- skin's own pieces (the stand-in carries ShowcaseWrap). Radiant draws a skin+wrap as one composite Id: colour wraps only
	if element ~= "Radiant" then return wrapId end
	local SC = catalog()
	if type(wrapId) == "string" and wrapId ~= "Default" and SC and type(SC.WrapsOverSkin) == "function"
		and SC.WrapsOverSkin(wrapId) then
		return wrapId
	end
	return "Default"
end
--- the invisible stand-in caster wearing `skin`: no parts and no Humanoid (nothing seen, no worn pieces built on it)
local function standIn(parent, skin, wrap)
	local m = Instance.new("Model")
	m.Name = "ShowcaseSkinStandIn"
	m:SetAttribute("ShowcaseSkin", skin)
	if wrap and wrap ~= "Default" then m:SetAttribute("ShowcaseWrap", wrap) end   -- (2026-10-27) the wrap over the skin
	m:SetAttribute("StudioSkin", skin)
	m:SetAttribute("AllyDummy", true)                    -- (VFXLibrary.IsEnemy: never thinned as an enemy's)
	m.Parent = parent                                    -- (attributes first: the kits' watchers see it wearing the skin)
	return m
end
--- IceMagic.<name> (a skin kit), required, or nil
local function skinKit(name)
	local ice = ReplicatedStorage:WaitForChild("IceMagic", 10)
	local m = ice and ice:WaitForChild(name, 5)
	local ok, k = pcall(function() return m and require(m) end)
	return (ok and type(k) == "table") and k or nil
end
local meshBudget = nil
--- MeshBudget.MakeRoom(): every optional EditableMesh holder (an idle wrap set, wrap copies, a skin kit nobody wears)
--- lets go of what it can -- what a skin's essential build asks when it is refused
local function makeRoom()
	if meshBudget == nil then
		local ok, b = pcall(function()
			return require(ReplicatedStorage:WaitForChild("IceMagic", 10):WaitForChild("MeshBudget", 5))
		end)
		meshBudget = (ok and type(b) == "table") and b or false
	end
	if meshBudget then pcall(meshBudget.MakeRoom) end
end

-- ====================================================================================================
-- PYRO
-- ====================================================================================================
-- PYRO: the real M1 -- PyroFlame_Fire.FireFireball's flight frame (fire_ball + wisps + embers on a PyroDraw canvas),
-- in the wrap's colours, held at cf. Needs at module top: local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PYRO_SHOW_SPEED = 32      -- the virtual flight speed (studs/s) that lays out the tail and the shed tongues behind the
                                -- held ball; the live ball flies at 200 (PyroFX.Tuning.Fireball.Speed) = a 30-stud tail
local PYRO_V = { TailSpan = 0.15, WispRate = 50, WispLife = 0.4, Embers = 45 }   -- PyroFlame_Fire's local V (seen by others)
local pyroTiered = {}
local function pyroWrap(wrapId)
	local SC = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))
	local w = type(wrapId) == "string" and wrapId ~= "Default" and SC.Skins[wrapId]
	if type(w) ~= "table" or w.Wrap ~= "Pyro" or not w.Flame then return nil end
	-- PyroFX's local forTier(w, "Fireball"), copied: the Basic tier's ShedScale shrinks the wrap's Shed layers
	local S, shed = w.ShedScale, w.Shed
	local f = S and shed and (S.Fireball or S.Basic)
	if not f then return w end
	local tier = S.Fireball and "Fireball" or "Basic"
	local key = w.Id .. "/" .. tier
	if pyroTiered[key] then return pyroTiered[key] end
	local list = {}
	for i, L in ipairs(shed) do
		local c = table.clone(L)
		c.Name = L.Name .. "@" .. tier
		c.Size = { L.Size[1] * f.Size, L.Size[2] * f.Size }
		c.Speed = { L.Speed[1] * (f.Speed or 1), L.Speed[2] * (f.Speed or 1) }
		c.Life = { L.Life[1] * (f.Life or 1), L.Life[2] * (f.Life or 1) }
		c.Rise = (L.Rise or 0) * (f.Rise or 1)
		c.PerPart = L.PerPart and L.PerPart * f.Rate
		c.MinRate = L.MinRate and L.MinRate * f.Rate
		c.Burst = L.Burst and L.Burst * f.Rate
		list[i] = c
	end
	local v = setmetatable({ Shed = list, Tier = tier }, { __index = w })
	pyroTiered[key] = v
	return v
end

-- (2026-10-26) THE BARE BALL (the owner: Pyro's M1 sometimes a plain black unlit sphere, with the console's EditableMesh
-- budget warnings). The display asked PyroDraw.Ready() ONCE, when it was made (flame meshes that landed later: nothing,
-- ever), and a wrapped display drew from the first frame its set was whole and never looked again -- though that set's
-- 45 EditableMesh copies are the heaviest in the game and are let go under it (PyroDraw's two-set LRU, MeshBudget's
-- give-back), so the held canvas went on drawing slots whose copies were gone, then a half-rebuilt mix. Nobody asked
-- MeshBudget for room either, as a skin's build does. Now nothing is drawn until the flame meshes are in (asked again
-- every second) and the wrap's whole set is (PyroDraw.new hands no wrap until every copy is in); while it is not,
-- MeshBudget is asked for room every PYRO_ROOM s; and while it is drawn the set is checked every PYRO_CHECK s -- a set
-- let go hides the display until it is whole again. Never a bare ball, never the Default for a wrap.
local PYRO_TRY = 0.25           -- s between tries while the flame meshes or the wrap's set are not in
local PYRO_ROOM = 2             -- s between asks of MeshBudget for room while the wrap's set is not in
local PYRO_CHECK = 1            -- s between checks that the drawn wrap's set is still whole

function M.Pyro(wrapId: string, cf: CFrame, parent: Instance, _skinId: string?)
	local PD = require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("PyroDraw"))
	local w = pyroWrap(wrapId)
	local C, fwd = cf.Position, cf.LookVector
	local alive, cv, tNow, nextTry = true, nil, 0, 0
	local roomAt, checkAt, warned = 0, 0, false
	-- the ball's path in its own frame: centre now, the path it "took" trailing straight back (a camera riding the ball)
	local function ballAt(tq) return C + fwd * (PYRO_SHOW_SPEED * (tq - tNow)) end
	local ballO = { hot = false, scale = 1, span = PYRO_V.TailSpan, tail = 1, seed = 7 }   -- full grown, third person
	local wispO = { hot = false, seed = 19, rate = PYRO_V.WispRate, scale = 1, life = PYRO_V.WispLife }
	local emberO = { id = "trail", hot = false, count = PYRO_V.Embers, t0 = 0.01 }
	local meshesOk = PD.Ready()
	-- (2026-10-27) the set shown a moment ago goes first: kept, it filled the budget and this one waited ~8.5 s
	if w and PD.MakeRoomFor then PD.MakeRoomFor(w) end
	if w and meshesOk then PD.PrewarmWrap(w) end       -- starts the wrap's mesh-set copies (async, EditableMesh)
	local function draw(c, t)                          -- = PyroFlame_Fire's drawFlight at scale 1
		c:fire_ball(ballAt, t, ballO)
		c:wisps(ballAt, t, 0.02, math.huge, wispO)
		c:embers(ballAt, t, emberO)
	end
	--- a canvas in the wrap (nil while its set is not whole: then MeshBudget is asked for room, every PYRO_ROOM s)
	local function canvas(now)
		local c = PD.new("PyroShowcase", { own = true, wrap = w })
		if w and not c.Wrap then                       -- the wrap's set is not whole: nothing, not Default
			c:Destroy()
			if now >= roomAt then
				roomAt = now + PYRO_ROOM
				if PD.MakeRoomFor then PD.MakeRoomFor(w) end
				makeRoom()
			end
			return nil
		end
		return c
	end
	local h = {}
	function h.Update(t: number)
		if not alive then return end
		local now = os.clock()
		if not meshesOk then                           -- (asked again: the flame meshes can land after the display was made)
			if now < nextTry then return end
			nextTry = now + 1
			meshesOk = PD.Ready()
			if meshesOk then                           -- (2026-10-26) landed late: drop the 'missing' records cached before, then prewarm
				PD.SetMeshFolder(nil)
				if w then PD.PrewarmWrap(w) end
			end
			if not meshesOk then
				if not warned then
					warned = true
					warn("[HubShowcaseM1] Pyro: the flame meshes are not in the place yet; nothing drawn until they are")
				end
				return
			end
		end
		if cv and w and now >= checkAt then            -- the drawn set still whole? (an idle set's let-go, MeshBudget's)
			checkAt = now + PYRO_CHECK
			local probe = canvas(now)
			if probe then
				probe:Destroy()
			else
				cv:Destroy()                           -- (hides every part it drew)
				cv = nil
				nextTry = now + PYRO_TRY
			end
		end
		if not cv then
			if now < nextTry then return end
			nextTry = now + PYRO_TRY
			cv = canvas(now)
			if not cv then return end
			checkAt = now + PYRO_CHECK
		end
		tNow = t
		cv:Begin(t)
		local ok, err = pcall(draw, cv, t)
		cv:End()
		if not ok then
			warn("[HubShowcaseM1] Pyro draw failed: " .. tostring(err))
			alive = false
			cv:Destroy()
			cv = nil
		end
	end
	function h.Destroy()
		alive = false
		if cv then cv:Destroy() cv = nil end
	end
	if typeof(parent) == "Instance" then parent.Destroying:Once(h.Destroy) end   -- pooled parts never stay up frozen
	return h
end

-- ====================================================================================================
-- RADIANT
-- ====================================================================================================
-- Radiant M1 = Light Lance: the real beam (RadiantFX_Staff.LanceBeam), held as a segment of this length (studs).
-- In combat it runs from the staff tip to the target (up to RadiantTuning.LightLance.Range); width/rails/glyphs are real size.
local RADIANT_LANCE_LEN = 6

function M.Radiant(wrapId: string, cf: CFrame, parent: Instance, skinId: string?)
	local RS = game:GetService("ReplicatedStorage")
	local caster
	-- (2026-10-26) a skin (Devil): its Light Lance is drawn in the skin's palette, the Devil forms gated on its Id
	-- (RadiantFX_Staff's forge scope); a colour wrap goes over it as "<Skin>+<Wrap>" where the catalog allows
	local skin = skinOf("Radiant", skinId)
	local wrap = wrapWith(skin, wrapId, "Radiant")
	local id = (skin and wrap ~= "Default") and (skin .. "+" .. wrap) or skin or wrapId
	local ok, h = pcall(function()
		local ice = RS:WaitForChild("IceMagic")
		local Staff = require(ice:WaitForChild("RadiantFX_Staff"))
		local RD = require(ice:WaitForChild("RadiantDraw"))
		local SC = require(RS:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))
		local pal = SC.Resolve("Radiant", "LightLance", id)              -- the wrap's / skin's palette (nil = Default)
		-- a stand-in caster: no Head / Root / RadiantAnim staff, so the beam starts at Aim's `from`;
		-- parented, so the effect never reads its caster as gone
		caster = Instance.new("Model")
		caster.Name = "RadiantShowcaseCaster"
		if skin then                                                      -- (2026-10-26) the showcase convention
			caster:SetAttribute("ShowcaseSkin", skin)
			caster:SetAttribute("StudioSkin", skin)
		end
		caster.Parent = parent
		local beam = RD.WithPalette(pal, Staff.LanceBeam, caster, false, nil)
		beam.Effect.Canvas.Owner = nil                                    -- never thinned as an enemy's effect
		local noHit = RaycastParams.new()
		noHit.FilterType = Enum.RaycastFilterType.Include
		noHit.FilterDescendantsInstances = {}
		beam.Ray = noHit                                                  -- wall ray hits nothing: a clean air beam
		local half = cf.LookVector * (RADIANT_LANCE_LEN * 0.5)
		beam:Aim(cf.Position - half, cf.Position + half, false, 1, false) -- full ramp
		return beam
	end)
	if not ok then
		warn("[HubShowcaseM1] Radiant: " .. tostring(h))
		h = nil
	end
	return {
		Update = function(t) end,                                         -- RadiantDraw's own RenderStep animates it
		Destroy = function()
			if h then pcall(function() h:Destroy(true) end) end
			if caster then caster:Destroy() end
		end,
	}
end

-- ====================================================================================================
-- CRYO
-- ====================================================================================================
-- CRYO: the real M1 (VFXLibrary.FireIcicleShard's look: the IS_Cluster ice shard + white tip, glint, wake, flecks) built by
-- the game's own code in the wrap's palette (CryoWrap W.Run swaps IS2 etc. for the call, as the combat hook does), fired
-- once into empty sky, its two parts cloned at full scale and the originals handed back (VFXLibrary destroys them next frame).
-- (2026-10-26) A SKIN's M1 the same way: fired by the invisible stand-in caster wearing the skin (the showcase
-- convention), so VFXLibrary draws the skin's own shot look -- Frostblade's kunai, Frost Lotus's petal dart, Snow Globe's
-- mini globe, Frost Dragon's Wyrmling -- once the skin's kit is built (nothing until then: never the Default shard in its
-- place). What rides a shot in flight rides the held clones: the dart's petal motes (FrostLotusKit.Ride's lines, held
-- along the path it "flew"), the globe's outline (SnowGlobeKit.Ride), the Wyrmling's head, jaw and segments
-- (FrostDragonKit.Ride, its jaw snapping every CRYO_BITE s).
--
-- (2026-10-26) THE OFF-CENTRE / MIS-DRAWN SHARD, the root cause: the shard is a SpecialMesh FileMesh piece (VFXLibrary's
-- ffKitPart) whose Scale VFXLibrary fits to the part's Size in a Size-changed handler -- and this place's signals are
-- DEFERRED (SpellshotService's meter note), so on the release frame, when the clone was taken, that handler had not run
-- yet. The clone copied a STALE Scale -- the IS_Cluster template's own on a freshly made look, the last flight's on a
-- pooled one (shrunk to 45% after the player's own far shots) -- and then multiplied it by 1 / FormFrom: the held shard's
-- drawn mesh no longer matched its part (size, proportions and where the mesh sat round the part's centre), and how far
-- off depended on the look pool's history -- "sometimes". The clone's Scale is now fitted from its own final Size and
-- the mesh's native size (ffKitPart's rule), never copied; a primitive SpecialMesh keeps its relative Scale (it was
-- being scaled twice). Hardened with it: each build fires at its own spot in the sky (not one shared spot every build
-- and display used) and takes exactly one body and one tip (the "body" it centres on was the LAST shard-named part found).
local CRYO_SKIN_KIT = { Frostblade = "FrostbladeKit", SnowGlobe = "SnowGlobeKit", FrostLotus = "FrostLotusKit",
	FrostDragon = "FrostDragonKit" }
local CRYO_LEAD = { FrostDragon = 3 }         -- studs a skin's shot holder is held ahead of cf: the Wyrmling's head sits on
                                              -- the point and its segments trail ~6 studs, so the whole is centred on cf
local CRYO_ROLL = { SnowGlobe = 0, FrostDragon = 0 }   -- the idle roll per skin (rad/s; absent: ROLL): the globe stands
                                                       -- upright, the Wyrmling flies level
local CRYO_TRAIL = 9                          -- studs of the path a riding piece reads behind the held shot
local CRYO_BITE = 1.1                         -- s between the held Wyrmling's bites (its jaw shut, then wide open)
local LOTUS_MOTES = { 0.4, 1.45, 2.5, 3.55, 4.6 }   -- FrostLotusKit's MOTES: the petal motes' distances behind the dart
local cryoSeq = 0                             -- each build fires at its own spot in the sky
local cryoNative = {}                         -- MeshId -> its mesh's native size (ffKitPart's rule) | false: not found

--- the native size of a kit mesh (ffKitPart's rule: MeshSize when it reads, else the template's Size), or nil
local function cryoNativeSize(folderName, meshId)
	local v = cryoNative[meshId]
	if v ~= nil then return v or nil end
	local mf = ReplicatedStorage:FindFirstChild(folderName)
	if not mf then return nil end                 -- (not in yet: asked again next time)
	v = false
	for _, d in ipairs(mf:GetDescendants()) do
		if d:IsA("MeshPart") and d.MeshId == meshId then
			local ok, ms = pcall(function() return d.MeshSize end)
			v = (ok and typeof(ms) == "Vector3" and ms.Magnitude > 1e-4) and ms or d.Size
			break
		end
	end
	cryoNative[meshId] = v
	return v or nil
end

function M.Cryo(wrapId: string, cf: CFrame, parent: Instance, skinId: string?)
	local RS = game:GetService("ReplicatedStorage")
	local Ice = RS:WaitForChild("IceMagic")
	local VFX = require(Ice:WaitForChild("VFXLibrary"))
	local W = require(Ice:WaitForChild("CryoWrap"))
	pcall(function() require(Ice:WaitForChild("CryoFX")).Start() end)    -- idempotent (AbilityFX calls it too): installs the wrap hooks
	-- (2026-10-26) a skin: its kit and the stand-in caster wearing it; a Cryo wrap over it only where the catalog allows
	local skin = skinOf("Cryo", skinId)
	local kitName = skin and CRYO_SKIN_KIT[skin]
	local kit = kitName and skinKit(kitName) or nil
	if skin and not kit then
		warn("[HubShowcaseM1] Cryo skin " .. skin .. ": its kit is not in the place - Default drawn")
		skin = nil
	end
	local stand = skin and standIn(parent, skin, wrapWith(skin, wrapId, "Cryo")) or nil
	local P = W.Palette(wrapWith(skin, wrapId, "Cryo"))                           -- nil (not a Cryo wrap): the Default shard
	local S = VFX.Tuning.IcicleShard
	local s0 = (S.FormTime > 0) and S.FormFrom or 1                       -- the release frame is drawn at FormFrom scale
	local fxName = VFX.Config.FXFolderName
	local meshName = VFX.Config.MeshFolderName or "IceMagicMeshes"
	local AUR = nil
	if P and P.Grad then
		local ok, a = pcall(require, Ice:FindFirstChild("CryoAurora"))
		AUR = (ok and type(a) == "table") and a or nil
	end
	local Fc = CFrame.fromMatrix(cf.Position, -cf.UpVector, cf.LookVector) -- the shot frame: X = -up, +Y = flight
	local ROLL = 0.5                                                      -- idle: a slow roll about the flight axis (rad/s); 0 = still
	if skin and CRYO_ROLL[skin] then ROLL = CRYO_ROLL[skin] end
	local pieces, rels, flow, pulse = {}, {}, {}, {}
	local shift, hasGrad, dead = CFrame.new(), false, false
	local nextTouch, nextTry, rfAt, rf = 0, 1, -1, false
	local retryAt, failAt, biteAt, warnedRun = 0, 0, 0, false
	local ride, bodyPiece = nil, nil                                      -- (2026-10-26) the riders; the held body clone

	-- (2026-10-26) the pieces riding a skin's held shot, let go (every kit rider skips a look with no body)
	local function unride()
		local r = ride
		ride = nil
		if not r then return end
		r.Body, r.Tip = nil, nil
		if r.Edge then pcall(function() r.Edge:Destroy() end) end
		for _, m in ipairs(r.Motes or {}) do pcall(function() m:Destroy() end) end
		local w = r.Wyrm
		if w and kit and kit.Drop then
			pcall(kit.Drop, w.Head)
			pcall(kit.Drop, w.Jaw)
			for _, o in ipairs(w.Segs or {}) do pcall(kit.Drop, o) end
		end
	end

	local function clear()
		unride()
		for _, p in ipairs(pieces) do pcall(function() p:Destroy() end) end
		table.clear(pieces) table.clear(rels) table.clear(flow) table.clear(pulse)
		hasGrad, bodyPiece = false, nil
	end

	-- (2026-10-26) whether the skin's kit is built; until then the stand-in asks for it (a showcase On starts the build,
	-- one at a time, through MeshBudget like any worn skin's), and a failed build is asked again every 15 s
	local function skinReady(now)
		if kit.Built then return true end
		pcall(kit.On, stand)
		if kit.Failed and now >= failAt then
			failAt = now + 15
			pcall(kit.Build)
		end
		return false
	end

	-- (2026-10-26) the skin's riders on the held clones; `hist` the path the shot "flew", straight back from its body
	local function rideOn(body, tip)
		local fw = Fc.YVector
		local hist = {}
		for d = 0, CRYO_TRAIL, 0.5 do hist[#hist + 1] = body.Position - fw * d end
		if skin == "FrostLotus" and type(kit.Kind) == "function" then
			local mk = kit.Kind("BladeMote")
			if mk and mk.Body then
				local motes = {}
				for i = 1, #LOTUS_MOTES do                                -- (FrostLotusKit.Ride's motes, as it makes them)
					local m = mk.Body:Clone()
					m.Size = mk.Size * (1.05 - 0.12 * i)
					m.Transparency = mk.BodyT + 0.1 * (i - 1)
					m.Parent = parent
					motes[i] = m
				end
				ride = { Motes = motes }
			end
		elseif skin == "SnowGlobe" and type(kit.ShotLook) == "function" and type(kit.Ride) == "function" then
			local g = kit.ShotLook()
			if g then
				pcall(function() g.Body:Destroy() g.Tip:Destroy() end)   -- (only its outline is wanted: the clones are the rest)
				ride = { Body = body, Tip = tip, Edge = g.Edge, EdgeSize = g.EdgeSize, EdgeOff = g.EdgeOff, BodySize = body.Size }
				kit.Ride(ride)
			end
		elseif skin == "FrostDragon" and type(kit.Ride) == "function" then
			ride = { Body = body, Tip = tip }
			kit.Ride(ride)
			if ride.Wyrm then
				ride.Wyrm.Hist = hist                                    -- (its segments trail along it)
				ride.Wyrm.Born = os.clock()                              -- (a held flight: no new-flight trail to retune)
			end
		end
	end

	local function build()
		clear()
		cryoSeq += 1
		local origin = cf.Position + Vector3.new(40 * (cryoSeq % 64), 4000, 0)   -- empty sky, this build's own spot: its
		                                                                        -- first-frame ray hits nothing (no impact)
		local fx = workspace:FindFirstChild(fxName)
		local before = {}
		if fx then for _, c in ipairs(fx:GetChildren()) do before[c] = true end end
		local ok, err = pcall(W.Run, P, VFX.FireIcicleShard, origin, origin + Vector3.xAxis * 50, { parent }, nil, nil, stand)
		if not ok then
			if not warnedRun then
				warnedRun = true
				warn("[HubShowcaseM1.Cryo] " .. tostring(err))
			end
			return
		end
		fx = workspace:FindFirstChild(fxName)
		if not fx then return end
		-- this shot's pieces: exactly one body (the shard / kunai / dart / globe / holder, or the plain rod) and one tip
		local found = {}
		for _, c in ipairs(fx:GetChildren()) do
			local nm = c.Name
			if not before[c] and c:IsA("BasePart") and (nm == "IcicleShard" or nm == "IcicleShardTip" or nm == "IcicleShardRod")
				and (c.Position - origin).Magnitude < 12 then
				local key = (nm == "IcicleShardTip") and "Tip" or "Body"
				if not found[key] then found[key] = c end                     -- (another piece: not this shot's, left alone)
			end
		end
		-- a skin whose kit fell short of its look drew the Default shard (a FileMesh copy, or the rod): not held in its place
		local fb = found.Body
		if skin and (not fb or fb.Name == "IcicleShardRod" or fb:FindFirstChildOfClass("SpecialMesh")) then
			for _, c in pairs(found) do c.Parent = nil end
			return
		end
		local F0 = CFrame.fromMatrix(origin, -Vector3.yAxis, Vector3.xAxis)
		local bodyRel, tipClone
		for key, c in pairs(found) do
			local k = (c.Name == "IcicleShardRod") and 1 or 1 / s0
			local rel = F0:ToObjectSpace(c.CFrame)
			local cl = c:Clone()
			-- VFXLibrary's stepper sees it gone: destroyed, never pooled. (2026-10-26) A skin's look is left to fly out of
			-- sight up there and go back to its pool with its riders (FrostLotusKit's rider list keeps every look it gets)
			if not skin then c.Parent = nil end
			cl.Size = c.Size * k
			local sm = cl:FindFirstChildOfClass("SpecialMesh")         -- (ffKitPart's fit() connection is not cloned)
			if sm and sm.MeshType == Enum.MeshType.FileMesh then
				-- fitted here from the clone's own Size, never the original's Scale (stale on the release frame: above)
				local native = cryoNativeSize(meshName, sm.MeshId)
				if native then sm.Scale = cl.Size / native else sm.Scale = sm.Scale * k end
			end
			for _, d in ipairs(cl:GetDescendants()) do
				if d:IsA("Attachment") then d.Position = d.Position * k
				elseif d:IsA("ParticleEmitter") then d.Enabled = true    -- glint on the point, wake + flecks off the heel
				elseif d:IsA("Trail") then d.Enabled = false end          -- (a still shard draws no Frost Line trail)
			end
			rels[cl] = CFrame.new(rel.Position * k) * rel.Rotation
			if key == "Body" then bodyRel, bodyPiece = rels[cl], cl else tipClone = cl end
			if cl:GetAttribute("AuroraGrad") then hasGrad = true end
			pieces[#pieces + 1] = cl
		end
		-- the shard's body centred on cf (a skin's holder led ahead of it: CRYO_LEAD)
		shift = CFrame.new(0, skin and CRYO_LEAD[skin] or 0, 0) * (bodyRel and CFrame.new(-bodyRel.Position) or CFrame.new())
		for _, cl in ipairs(pieces) do
			cl.CFrame = Fc * shift * rels[cl]
			cl.Parent = parent
		end
		if skin and bodyPiece then
			rideOn(bodyPiece, tipClone or bodyPiece)
			biteAt = os.clock() + CRYO_BITE
		end
		if not P then return end
		-- the wrap's live extras, as CryoWrap's own scans would register them on a cast (they only scan its FX folder)
		for _, cl in ipairs(pieces) do
			local list = cl:GetDescendants()
			table.insert(list, cl)
			for _, d in ipairs(list) do
				if P.Flow then                                            -- Mythic (Aurora): the colour flow
					if d:IsA("BasePart") and d:GetAttribute("AuroraGrad") then
						if AUR then pcall(AUR.Assign, d, 0) end
						flow[d] = { P = P, Is = "grad", O = cf.Position, R = 30 }
					elseif d:IsA("BasePart") and d.Transparency < 1 and P._flowHex and P._flowHex[d.Color:ToHex()] then
						if P.Glow and d.Material ~= Enum.Material.Neon then d.Material, d.Reflectance = Enum.Material.Neon, 0 end
						flow[d] = { P = P, Is = "part", Last = d.Color, Crystal = d:FindFirstChildOfClass("SpecialMesh") ~= nil,
							Shadow = P._flowHex[d.Color:ToHex()] == "Shadow", O = cf.Position, R = 30,
							K = (d:IsA("MeshPart") and d.Material == Enum.Material.Neon) and (P.NeonK or 0.62) or 1 }
					elseif (d:IsA("ParticleEmitter") or d:IsA("Trail")) and P._flowHex then
						for _, kp in ipairs(d.Color.Keypoints) do
							if P._flowHex[kp.Value:ToHex()] then
								flow[d] = { P = P, Is = "seq", Last = d.Color, T = 0, Bright = d:IsA("ParticleEmitter"), O = cf.Position, R = 30 }
								break
							end
						end
					end
				elseif P.Pulse and d:IsA("BasePart") then                 -- Epic (Sakura Frost): the glow pieces breathe
					if P.Glow and P._allHex and d.Material ~= Enum.Material.Neon and P._allHex[d.Color:ToHex()] then
						local sm = d:FindFirstChildOfClass("SpecialMesh")
						local k = sm and 1 or P.NeonK or 0.62
						d.Material, d.Reflectance = Enum.Material.Neon, 0
						d.Color = Color3.new(d.Color.R * k, d.Color.G * k * (sm and 0.95 or 1), d.Color.B * k * (sm and 0.78 or 1))
					end
					if d.Material == Enum.Material.Neon and d.Transparency < 1 and P._pulseHex and P._pulseHex[d.Color:ToHex()] then
						pulse[d] = d.Color
					end
				end
			end
		end
	end

	if not skin or skinReady(os.clock()) then build() end

	local function update(t: number)
		if dead then return end
		local now = os.clock()
		if #pieces == 0 then                                         -- (2026-10-26) nothing held yet: built when it can be
			if now >= retryAt then                                   -- (a skin: once its kit is built; else a failed build)
				retryAt = now + (skin and 0.5 or 2)
				if not skin or skinReady(now) then build() end
			end
			return
		end
		if skin and not kit.Built then                               -- (2026-10-26) its kit let go: held again once it is back
			clear()
			return
		end
		local base = Fc * CFrame.Angles(0, t * ROLL, 0) * shift
		local n = #pieces
		local parts, cfs = table.create(n), table.create(n)
		for i, p in ipairs(pieces) do parts[i], cfs[i] = p, base * rels[p] end
		if ride and ride.Motes and bodyPiece then                    -- (2026-10-26) Frost Lotus: the petal motes, held
			local bcf = base * rels[bodyPiece]                       -- along the path behind the dart (FrostLotusKit.Ride's
			local back, rot = bodyPiece.Size.Y * 0.5, bcf.Rotation   -- placement and spin)
			for i, m in ipairs(ride.Motes) do
				parts[#parts + 1] = m
				cfs[#cfs + 1] = CFrame.new(bcf.Position - Fc.YVector * (back + LOTUS_MOTES[i])) * rot
					* CFrame.Angles(now * 11 + i * 2.1, now * 7 + i, 0)
			end
		end
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		if ride and ride.Wyrm and now >= biteAt then                 -- (2026-10-26) the held Wyrmling bites again
			biteAt = now + CRYO_BITE
			ride.Wyrm.Born = now
		end
		if not P then return end
		if P.Flow and W._flowStep then
			for inst, it in pairs(flow) do pcall(W._flowStep, inst, it) end
			if AUR and t >= nextTouch then nextTouch = t + 3 pcall(AUR.Touch) end   -- keeps the gradient copies alive + flowing
			if AUR and not hasGrad and t >= nextTry and t < 30 then        -- copies were still building: rebuild once ready
				nextTry = t + 1
				local mf = RS:FindFirstChild("IceMagicMeshes")
				local tpl = mf and mf:FindFirstChild("IcicleShard") and mf.IcicleShard:FindFirstChild("IS_Cluster")
				local ok, probe = pcall(AUR.KitCopy, P, tpl)
				if ok and typeof(probe) == "Instance" then
					probe:Destroy()
					pcall(W._dropPools, P)                                 -- (as CryoWrap does when copies land: fresh looks)
					build()
				end
			end
		elseif P.Pulse and next(pulse) then                             -- CryoWrap pulseStep's own tone, on fixed bases
			if t >= rfAt then
				rfAt = t + 1
				local ok, v = pcall(function() local st = require(RS.Spellshot.SpellshotSettings) return st.Get and st.Get("ReduceFlashing") end)
				rf = ok and v == true
			end
			local pu = P.Pulse
			local s = rf and 0 or math.sin(2 * math.pi * os.clock() / pu.Period)
			local k, w, tip = 1 + pu.Amp * s, math.max(0, s) * pu.TipDrift, P.Edge.Tip
			for p, c0 in pairs(pulse) do
				local c = c0:Lerp(tip, w)
				p.Color = Color3.new(math.min(1, c.R * k), math.min(1, c.G * k), math.min(1, c.B * k))
			end
		end
	end

	return {
		Update = update,
		Destroy = function()
			dead = true
			clear()
			if stand then pcall(function() stand:Destroy() end) end
		end,
	}
end

-- ====================================================================================================
-- AQUA
-- ====================================================================================================
-- AQUA: RIPTIDE (M1) -- the whitewater crescent AquaFX.Riptide runs along the floor, frozen in flight. Its three roll
-- stages (AK_RT_Wave_1..3, each with its Tideline lip AK_RT_Lip_n) swap every 0.07 s exactly as in combat. The pieces are
-- taken the way AquaFX's take() takes them, inside AquaWrap's own context (Wrap.Call), so the wrap's baked mesh, its
-- Tideline colour, Deep Brine's gloss and AquaWrapLux's Glow / Pulse / Flow / Curtains all come from the real wrap code.
function M.Aqua(wrapId: string, cf: CFrame, parent: Instance, _skinId: string?)   -- (2026-10-26) no Aqua skins
	local RS = game:GetService("ReplicatedStorage")
	local IM = RS:WaitForChild("IceMagic")
	local VFX = require(IM:WaitForChild("VFXLibrary"))
	local A = require(IM:WaitForChild("AquaTuning"))
	local okW, Wrap = pcall(function() return require(IM:WaitForChild("AquaWrap", 5)) end)
	if not okW or type(Wrap) ~= "table" then Wrap = nil end
	local COL = A.Color
	local STAGE_TIME = 0.07                       -- AquaFX's STAGE_TIME (local there): one roll stage
	local HIDE = CFrame.new(0, -10000, 0)         -- AquaFX's HIDE: where a stage not showing waits (Lux skips it)
	local meshes = RS:FindFirstChild(VFX.Config.MeshFolderName or "IceMagicMeshes") or RS:FindFirstChild("IceMagicMeshes")
	local kit = meshes and meshes:FindFirstChild("AquaKit")
	-- the wrap: nil draws Default (no catalog entry, not an Aqua wrap, or AquaWrap's identity guard refused it)
	local P = (Wrap and type(wrapId) == "string") and Wrap.Palette(wrapId) or nil
	if wrapId and wrapId ~= "Default" and not P then warn("[HubShowcaseM1] Aqua wrap " .. tostring(wrapId) .. " unavailable - Default drawn") end

	-- AquaFX's take() + setKind(), line for line (they are locals in AquaFX, so mirrored here)
	local function take(name, kind)
		local t = kit and kit:FindFirstChild(name)
		if not (t and t:IsA("MeshPart")) then return nil end
		t = (Wrap and Wrap.Active and Wrap.Template(t)) or t
		local p = t:Clone()
		p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.Massless = true, false, false, false, true
		p.Reflectance = 0
		pcall(function() p.DoubleSided = false end)
		if kind == "line" then
			p.Material, p.Color, p.Transparency, p.CastShadow = Enum.Material.Neon, COL.Tideline, 0, false
		else
			p.Material, p.Color, p.Transparency, p.CastShadow = Enum.Material.SmoothPlastic, Color3.new(1, 1, 1), 0, true
		end
		if Wrap and Wrap.Active then Wrap.Dress(p, kind) end
		p.CFrame = HIDE
		p.Parent = parent
		return p
	end

	local waves, lips = {}, {}
	local function build()
		for i = 1, 3 do
			waves[i] = take("AK_RT_Wave_" .. i, "solid")
			lips[i] = take("AK_RT_Lip_" .. i, "line")
		end
	end
	if Wrap and P then
		local me = game:GetService("Players").LocalPlayer
		-- Caster = the viewer: Lux treats it as their own effect (no Reduce-Enemy-VFX halving of Maelstrom's curtains)
		local ok, err = pcall(Wrap.Call, { P = P, Caster = me and me.Character, Kind = "Riptide" }, build)
		if not ok then warn("[HubShowcaseM1] Aqua: " .. tostring(err)) end
	else
		build()
	end

	-- AquaFX's place() at scale 1. In combat the stages share the floor-front origin CFrame.lookAt(front, front + dir);
	-- that origin is put where Wave_1's centre lands on cf (about 1.85 studs above and 1.44 behind the front).
	local ofp1 = (waves[1] and waves[1]:GetAttribute("OriginFromPivot")) or Vector3.zero
	local originCF = cf * CFrame.new(ofp1)
	local function place(p)
		if not p then return end
		local ts = p:GetAttribute("TemplateSize") or p.Size
		local ofp = p:GetAttribute("OriginFromPivot") or Vector3.zero
		p.Size = ts
		p.CFrame = originCF * CFrame.new(-ofp)
	end
	local stage = 0
	local function show(t)
		local s = math.floor(t / STAGE_TIME) % 3 + 1
		if s == stage then return end
		for i = 1, 3 do
			if i == s then
				place(waves[i])
				place(lips[i])
			else
				if waves[i] then waves[i].CFrame = HIDE end
				if lips[i] then lips[i].CFrame = HIDE end
			end
		end
		stage = s
	end
	if waves[1] then show(0) else warn("[HubShowcaseM1] AquaKit.AK_RT_Wave_1 missing - nothing drawn") end

	local dead = false
	return {
		Update = function(t)
			if not dead and waves[1] then show(t) end
		end,
		Destroy = function()
			if dead then return end
			dead = true
			for i = 1, 3 do
				if waves[i] then waves[i]:Destroy() end
				if lips[i] then lips[i]:Destroy() end
			end
		end,
	}
end

-- ====================================================================================================
-- UMBRA
-- ====================================================================================================
function M.Umbra(wrapId: string, cf: CFrame, parent: Instance, _skinId: string?)   -- (2026-10-26) no Umbra skins
	local RS = game:GetService("ReplicatedStorage")
	local ice = RS:WaitForChild("IceMagic")
	local tuning = require(ice:WaitForChild("UmbraTuning"))
	local UFX = require(ice:WaitForChild("UmbraFX"))
	local SC = require(RS:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))
	local skin = SC.Skins[wrapId]
	local P = (type(skin) == "table" and skin.Wrap == "Umbra" and type(skin.Palette) == "table") and skin.Palette or nil
	local D, SEGS = tuning.FX.Dart, tuning.FX.RibbonA.Segments

	-- identity-CFrame anchor: the wrap's particle Attachments take world Positions under it (UmbraFX puts them on Terrain)
	local anchor = Instance.new("Part")
	anchor.Name = "UmbraM1Anchor"
	anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.CastShadow = true, false, false, false, false
	anchor.Transparency, anchor.Size, anchor.CFrame = 1, Vector3.one * 0.05, CFrame.identity
	anchor.Parent = parent

	local function density() -- UmbraFX density(WHO=nil)
		local m = RS.Spellshot:FindFirstChild("SpellshotSettings")
		local ok, S = pcall(function() return m and require(m) end)
		local d = ok and type(S) == "table" and S.EffectDensity or 1
		return math.clamp(tonumber(d) or 1, 0.4, 1)
	end
	local function newAsh(A, quads) -- UmbraFX newAsh, verbatim recipe (Burst left out: no cast moment on a pedestal)
		local att = Instance.new("Attachment")
		att.Name = A.Name or "UmbraAsh"
		att.Parent = anchor
		local pe = Instance.new("ParticleEmitter")
		pe.Name = A.Name or "UmbraAsh"
		pe.Texture = A.Texture
		pe.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, A.Colors.Birth), ColorSequenceKeypoint.new(A.At, A.Colors.Mid),
			ColorSequenceKeypoint.new(1, A.Colors.Death) })
		pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, A.Alpha),
			NumberSequenceKeypoint.new(0.7, A.Alpha + 0.15), NumberSequenceKeypoint.new(1, 1) })
		pe.Size = NumberSequence.new(A.Size, A.Size * 0.7)
		local sq = {}
		for i = 0, A.Flutter do sq[#sq + 1] = NumberSequenceKeypoint.new(i / A.Flutter, (i % 2 == 0) and 0.55 or -0.55) end
		pe.Squash = NumberSequence.new(sq)
		pe.Lifetime = NumberRange.new(A.Life[1], A.Life[2])
		pe.Speed = NumberRange.new(A.Speed[1], A.Speed[2])
		pe.SpreadAngle = Vector2.new(180, 180)
		pe.Acceleration = Vector3.new(0, A.Rise, 0)
		pe.Drag = A.Drag
		pe.Rotation = NumberRange.new(0, 360)
		pe.RotSpeed = NumberRange.new(-A.Spin, A.Spin)
		pe.LightEmission, pe.LightInfluence, pe.Brightness = A.Emission or 0, 0, A.Brightness or 1
		pe.Rate = A.Share * quads / ((A.Life[1] + A.Life[2]) / 2) * density()
		pe.Enabled = false -- Ribbon:drawA switches it on and rides it on the ribbon head
		pe.Parent = att
		return pe, att
	end
	local function spots(Mo, q) -- UmbraFX MOT.spots with a fixed per-ribbon seed
		local out, lo, hi = {}, Mo.Min or 0.12, Mo.Max or 0.88
		for i = 1, Mo.N do
			local c = lo + (hi - lo) * ((q * 0.6180339 + (i - 1) / Mo.N) % 1)
			local hw = Mo.Width * (0.75 + 0.5 * (((q * 7 + i * 3) % 5) / 4)) / 2
			out[i] = { c - hw, c + hw, 2 * hw * (Mo.Edge or 0.25) }
		end
		return out
	end

	local h, dead, builtAt = nil, false, -math.huge
	local function build()
		builtAt = os.clock()
		local ok, e = pcall(UFX.Dart, nil) -- nil owner: wrapOf(nil) -> raw Dart, Default; the wrap is applied below
		if not ok or type(e) ~= "table" or rawget(e, "Step") == nil then h = nil return end -- (NULL handle when no FX)
		e.MaxLife = math.huge -- held, not culled at E.MaxLife (12 s)
		e.Start = os.clock() - 10 -- past the release flash (Hold 0.06 + Decay 0.2): the resting in-flight look
		e:Move(cf.Position, cf.LookVector, D.GrowOver + D.Length) -- head fully grown, full 5-stud braid
		if P then
			e.Wrap = P -- the driver sets CUR = e.Wrap for every Step: RibbonA, Glow/Pulse, Rim, light, Flow colours
			local B = e.Ball -- build-time-only reads of newBall (dart = plain: no moon, no orb)
			if B and B.Body then B.Body.ImageColor3 = P.BallBodyTint or Color3.new(1, 1, 1) end
			if B and B.Part and P.Color and P.Color.Void then B.Part.Color = P.Color.Void end
			for j, r in ipairs(e.Ribs) do -- build-time-only reads of newRibbon
				local rib, kind = r.Rib, r.Kind
				local ramp = P.Ramp and P.Ramp[kind] or nil
				rib.Ramp = ramp
				local mo = ramp and P.Mottle
				if mo and mo[kind] then rib.Spots, rib.Spot = spots(mo, j), { C = mo[kind], D = mo.Depth or 1 } end
				local ash = P.Motes or P.Ash
				if ash then
					rib.Ash, rib.AshAtt = newAsh(ash, 2 * SEGS)
					rib.AshLife, rib.AshNear = ash.Life[2], ash.Near or 0
				end
				if P.Twinkle then
					rib.Tw, rib.TwAtt = newAsh(P.Twinkle, 2 * SEGS)
					rib.TwLife, rib.TwNear = P.Twinkle.Life[2], P.Twinkle.Near or 0
				end
				if P.Flow then rib.FlowPh = j * P.Flow.Spread end
			end
		end
		h = e
	end

	local handle = {}
	local conns = {}
	function handle.Destroy()
		if dead then return end
		dead = true
		for _, c in ipairs(conns) do c:Disconnect() end
		if h then h.MaxLife = -1 end -- UmbraFX's driver stops it next render step: Stop frees its Beams/Attachments/ball
		h = nil
		anchor:Destroy()
	end
	function handle.Update(_t: number)
		-- the real braid spin and running bands animate in UmbraFX's own driver; this only revives the dart if
		-- UmbraFX.StopAll() (or a Step error) removed it
		if dead then return end
		if (h == nil or h.Dead) and os.clock() - builtAt > 2 then build() end
	end
	conns[1] = anchor.AncestryChanged:Connect(function()
		if not anchor:IsDescendantOf(game) then handle.Destroy() end -- parent destroyed/cleared: never leak a held dart
	end)
	build()
	return handle
end

-- ====================================================================================================
-- TOXIN
-- ====================================================================================================
-- (Toxin) unique negative bubble Ids in ToxinFX's own `bubbles` table: the server's are positive (ToxinHandler bubbleSeq)
local toxinSeq = 0

--- Toxin's M1 (Toxic Bubbles): the REAL ToxinFX.Handlers.ToxinBubble, drawn in the wrap through ToxinWrap.With, held in
--- place (G = 0, a near-zero velocity along cf.LookVector so the sac keeps its in-flight stretch and live 1.7/2.1 Hz
--- wobble). A sac lives FlightLife + 1 s in ToxinFX, so a fresh one is spawned every SWAP s and cross-faded in.
--- (2026-10-26) A SKIN: the sac's Character is the invisible stand-in caster wearing it (the showcase convention), so
--- ToxinFX's own skin hooks draw the skin's M1 in its place -- Pixel Potion's voxel bottle, Scorpion's venom gland, Witch's
--- Brew's brew glob, the Hydra's venom glob -- and the cross-fade carries them (each reads its fade off the sac's body).
--- Scorpion / Witch's Brew / Hydra draw nothing until their kit is built (never the Default sac in their place; a kit
--- that failed to build draws the Default, as in a duel); Pixel Potion's own stand-in bottle shows while its meshes bake.
local TOXIN_SKIN_KIT = { PixelPotion = "PixelPotionKit", Scorpion = "ScorpionKit", WitchsBrew = "WitchsBrewKit",
	Hydra = "HydraKit" }

function M.Toxin(wrapId: string, cf: CFrame, parent: Instance, skinId: string?)
	local RS = game:GetService("ReplicatedStorage")
	local ice = RS:WaitForChild("IceMagic", 10)
	local okF, FX = pcall(function() return require(ice:WaitForChild("ToxinFX", 10)) end)
	local okW, W = pcall(function() return require(ice:WaitForChild("ToxinWrap", 10)) end)
	local okT, T = pcall(function() return require(ice:WaitForChild("ToxinTuning", 10)) end)
	local okC, Cat = pcall(function() return require(RS:WaitForChild("Spellshot"):WaitForChild("SkinCatalog", 10)) end)
	local H = okF and type(FX) == "table" and FX.Handlers or nil
	-- (2026-10-26) a skin: its kit and the stand-in caster wearing it; a Toxin wrap over it only where the catalog allows
	local skin = skinOf("Toxin", skinId)
	local kitName = skin and TOXIN_SKIN_KIT[skin]
	local kit = kitName and skinKit(kitName) or nil
	if skin and not kit then
		warn("[HubShowcaseM1] Toxin skin " .. skin .. ": its kit is not in the place - Default drawn")
		skin = nil
	end
	local stand = skin and standIn(parent, skin, wrapWith(skin, wrapId, "Toxin")) or nil
	local S = okC and type(Cat) == "table" and Cat.Skins and Cat.Skins[wrapWith(skin, wrapId, "Toxin")] or nil
	-- the same palette ToxinWrap.paletteFor picks for a caster wearing `wrapId` (nil = Default); Mine = full density
	local scope = { P = (type(S) == "table" and S.Wrap == "Toxin") and S.Palette or nil, Mine = true }
	if skin == "WitchsBrew" and not scope.P then scope.P = kit.WrapPalette end   -- (2026-10-26) paletteFor's brew rule
	local FADE = 0.35
	local life = (okT and type(T) == "table" and T.Bubble and T.Bubble.FlightLife) or 2.5
	local SWAP = math.max(0.6, life + 0.9 - FADE - 1.25)   -- (the old sac fades, then its smoke lives out, before ToxinFX ends it)
	local live, now, retryAt, dead = {}, 0, 0, false
	local warnedKit = false

	local function spawnBubble()
		if not (H and H.ToxinBubble) then retryAt = now + 2 return end
		-- (2026-10-26) a skin drawn by its own module waits for its kit (the stand-in asks for the build: On -> Prepare)
		if skin and skin ~= "PixelPotion" and not kit.Built then
			if not kit.Failed then
				pcall(kit.On, stand)
				retryAt = now + 0.5
				return
			elseif not warnedKit then
				warnedKit = true
				warn("[HubShowcaseM1] Toxin skin " .. skin .. ": its kit did not build - the Default drawn, as in a duel")
			end
		end
		toxinSeq += 1
		local id = -1e9 - toxinSeq
		local f0, before = workspace:FindFirstChild("IceMagicFX"), {}
		if f0 then for _, c in ipairs(f0:GetChildren()) do before[c] = true end end
		local d = { Id = id, Origin = cf.Position, Vel = cf.LookVector * 0.002, G = 0,
			T0 = workspace:GetServerTimeNow() - 0.1,                -- (t starts past the 1/15 s release tension)
			Character = stand }                                     -- (2026-10-26) the skin's stand-in caster (nil: Default)
		local ok, err = pcall(function()
			if okW and type(W) == "table" and type(W.With) == "function" then W.With(scope, H.ToxinBubble, d)
			else H.ToxinBubble(d) end
		end)
		local f, model = workspace:FindFirstChild("IceMagicFX"), nil
		for _, c in ipairs(f and f:GetChildren() or {}) do
			if not before[c] and c.Name == "ToxinBubble" and c:IsA("Model") then model = c end
		end
		if not (ok and model) then
			if not ok then warn("[HubShowcaseM1] Toxin bubble failed: " .. tostring(err)) end
			pcall(H.ToxinBubblePop, { Id = id })
			retryAt = now + 2
			return
		end
		model.Parent = parent                                      -- (ToxinFX's updater only needs a Parent)
		local r = { Id = id, Model = model, Born = now, Base = {}, Lit = {}, Emit = {} }
		for _, x in ipairs(model:GetDescendants()) do
			if x:IsA("BasePart") then r.Base[x] = x.Transparency x.Transparency = 1
			elseif x:IsA("Light") then r.Lit[x] = x.Brightness x.Brightness = 0
			elseif x:IsA("ParticleEmitter") then table.insert(r.Emit, x) end
		end
		table.insert(live, r)
	end

	local function step(t: number)
		if dead then return end
		now = t
		local cur = live[#live]
		if (not cur or not cur.Model.Parent or now - cur.Born >= SWAP) and now >= retryAt then
			for _, r in ipairs(live) do
				if not r.Out then
					r.Out = now
					for _, e in ipairs(r.Emit) do e.Enabled = false end  -- (its smoke already out lives on)
				end
			end
			spawnBubble()
		end
		for i = #live, 1, -1 do
			local r = live[i]
			if not r.Model.Parent then
				table.remove(live, i)                              -- (timed out in ToxinFX, which cleared its own record)
			else
				local w = math.clamp((now - r.Born) / FADE, 0, 1)
				if r.Out then w = math.min(w, 1 - math.clamp((now - r.Out) / FADE, 0, 1)) end
				if w ~= r.W then
					r.W = w
					for p, b in pairs(r.Base) do p.Transparency = 1 - (1 - b) * w end
					for l, b in pairs(r.Lit) do l.Brightness = b * w end
				end
			end
		end
	end

	local function destroy()
		if dead then return end
		dead = true
		for _, r in ipairs(live) do
			if H then pcall(H.ToxinBubblePop, { Id = r.Id }) end    -- (no Position: drops ToxinFX's record + model, no burst)
			pcall(function() r.Model:Destroy() end)
		end
		table.clear(live)
		if stand then pcall(function() stand:Destroy() end) end      -- (2026-10-26) the skin's stand-in caster
	end

	spawnBubble()
	step(0)
	return { Update = step, Destroy = destroy }
end

-- a handle that draws nothing: what an entry hands back when its Element's draw code is not in the place
local function nothing()
	return { Update = function(_t) end, Destroy = function() end }
end

-- ====================================================================================================
-- TERRA
-- ====================================================================================================
-- TERRA: Boulder Shot's charged rock -- the REAL held rock (TerraFX.Charge: the TerraM1 kit's cells, their seams and the
-- two tiers of cracks of light, the core's gold PointLight, the slow two-axis turn it is held with, the dust and grit it
-- gathers off the floor), in the wrap's TerraWrap set (TerraFX.WrapSet: fissures, pale rim, stage glow, a Rare+ wrap's
-- breath / flow / added layers), its centre on cf. Charge tears the rock out of the floor on the press; here it is whole
-- from its first frame, as FireBoulder's assembled rock is (every cell home, no feeding stones, the full-charge squeeze
-- and the tier flares long past), then held for as long as it is shown. Destroy ends TerraFX's hold step without the drop
-- (Thrown: no falling apart) and takes the rock away.
local TERRA_CHARGE = 1          -- the charge held (0..1): 1 = both crack tiers lit, the biggest rock (~4.1 studs across)
local TERRA_GATHER = true       -- the hold's floor dust and grit (and a Rare+ wrap's hold layers, a share of their rate);
                                -- false = the rock alone, nothing on the floor under it
local TERRA_WRAP_WAIT = 1       -- s a wrap's set may take to build (EditableMesh, off the render loop) before the Default
                                -- rock is shown meanwhile; the wrapped rock takes over the moment its set lands
                                -- (2026-10-27: was 10 -- the Loadout's pedestal stood empty 10.8 s on every Terra wrap)
local TERRA_ROOM = 2            -- s between asks of MeshBudget for room while the wrap's set is not in

function M.Terra(wrapId: string, cf: CFrame, parent: Instance, _skinId: string?)   -- (2026-10-26) no Terra skins
	local RS = game:GetService("ReplicatedStorage")
	local TFX, skin = nil, nil
	local okL, errL = pcall(function()
		local ice = RS:WaitForChild("IceMagic", 10)
		TFX = require(ice:WaitForChild("TerraFX", 10))
		if type(wrapId) == "string" and wrapId ~= "Default" then
			-- the wrap's Boulder Shot data (nil: not a live Terra wrap -- staged, another Element's -- so Default is drawn)
			skin = require(ice:WaitForChild("TerraWrap", 10)).Skin("BoulderShot", wrapId)
		end
	end)
	if not okL or type(TFX) ~= "table" or type(TFX.Charge) ~= "function" then
		warn("[HubShowcaseM1] Terra: TerraFX unavailable - nothing drawn (" .. tostring(errL) .. ")")
		return nothing()
	end
	if type(wrapId) == "string" and wrapId ~= "Default" and not skin then
		warn("[HubShowcaseM1] Terra wrap " .. wrapId .. " unavailable - Default drawn")
	end

	local born = os.clock()
	local rock, wrapped, set = nil, false, nil        -- the live rock, whether it wears the set, the wrap's built set
	local dead, nextAsk, touchAt, retryAt = false, 0, 0, 0
	local roomAt = os.clock() + 0.5
	local function hand() return cf, nil, nil end     -- third person, no eye; Exact puts the rock's centre on it
	local function drop()
		local r = rock
		rock, wrapped = nil, false
		if not r then return end
		r.Thrown = true                                -- TerraFX's hold step returns false on its next frame: no break
		pcall(function()
			for _, m in ipairs(r.Marks or {}) do m.Host:Destroy() end
			if r.BurstHost then r.BurstHost:Destroy() end   -- (in the FX folder, not the rock's model)
			TFX.DestroyRock(r)
		end)
	end
	local function build(s)
		drop()
		local okB, r = pcall(TFX.Charge, function() return TERRA_CHARGE end, hand, { Wrap = s })
		if not (okB and type(r) == "table" and r.Model) then
			warn("[HubShowcaseM1] Terra rock failed: " .. tostring(r))
			retryAt = os.clock() + 5
			return
		end
		-- set before its first frame (Charge's step runs on the next render step)
		r.Exact = true
		r.T0 = os.clock() - 5                          -- past every beat of the gathering: every cell home on frame one
		for _, f in ipairs(r.Feeders or {}) do f.Done = true end   -- (all 24 would land, swell and burst on frame one)
		r.FullAt, r.RingDone = -10, true               -- the full-charge squeeze, seam flare and dust ring: long past
		for n, tier in ipairs({ 1 / 3, 2 / 3 }) do
			if TERRA_CHARGE >= tier then r.TierAt[n] = -10 end   -- its cracks already lit, without the flare (FireBoulder's)
		end
		if not TERRA_GATHER then r.Tu = 0 end          -- "the button came up at the press": the gather stays off
		rock, wrapped = r, s ~= nil
	end

	local function step(_t: number)
		if dead then return end
		local now = os.clock()
		if skin and not set and now >= nextAsk then
			nextAsk = now + 0.5
			local okS, s = pcall(TFX.WrapSet, wrapId)  -- nil while TerraWrap builds it (each ask may start the build)
			if okS and type(s) == "table" then set, touchAt = s, now + 2
			elseif now >= roomAt then                  -- (2026-10-27) not in: the idle sets give way, as Pyro's display asks
				roomAt = now + TERRA_ROOM
				makeRoom()
			end
		elseif set and now >= touchAt then
			-- the set in use: TerraWrap's give-backs (MakeRoom, a worn wrap's dropUnworn) leave a set asked for in the last
			-- 6 s alone, and a held rock never asks again on its own
			touchAt = now + 2
			pcall(TFX.WrapSet, wrapId)
		end
		if rock and not (rock.Model and rock.Model.Parent) then
			rock, wrapped = nil, false                 -- TerraFX took it away (a frame error's clean-up): rebuilt below
			retryAt = math.max(retryAt, now + 2)
		end
		if now >= retryAt then
			if set and not wrapped then
				build(set)                             -- the wrap is in: it takes over from the Default rock
			elseif not rock and (not skin or now - born >= TERRA_WRAP_WAIT) then
				build(nil)
			end
		end
	end

	local h = {}
	function h.Update(t: number)
		local ok, err = pcall(step, t)
		if not ok and not dead then
			warn("[HubShowcaseM1] Terra: " .. tostring(err))
			h.Destroy()
		end
	end
	function h.Destroy()
		if dead then return end
		dead = true
		drop()
	end
	if typeof(parent) == "Instance" then parent.Destroying:Once(h.Destroy) end
	h.Update(0)
	return h
end

-- ====================================================================================================
-- VOLTAIC
-- ====================================================================================================
-- VOLTAIC: Chain Bolt -- the REAL cast, ChainBoltFX.Fire (the ChainBolt broadcast's own drawing): the cast pulse's arcs and
-- palm glow, leg 1 at full length and intensity on its first frame (the core + glow Beam chain, its forks, the leg light),
-- the relay star, the hit's flash and the cooling shards. Re-fired every VOLT_EVERY s from VOLT_SPAN / 2 behind cf to
-- VOLT_SPAN / 2 ahead of it along cf.LookVector, a fresh zigzag every time (its seed is the moment). Voltaic has no wraps.
-- Fired as nobody's own cast (Own = false): a caster's own first hit kicks the whole screen's Bloom, which every shot
-- would pulse. Reduce Flashing (steady legs, a soft flash) and the thin look are ChainBoltFX's own, as in a duel; with no
-- caster it is nobody's enemy (VFXLibrary.IsEnemy(nil) is false), so only Graphics Quality thins it, never Reduce Enemy VFX.
local VOLT_EVERY = 0.6          -- s between shots
local VOLT_SPAN = 6             -- studs from the palm (the pulse) to the hit (the star)

function M.Voltaic(_wrapId: string, cf: CFrame, parent: Instance, _skinId: string?)   -- (2026-10-26) no skins
	local CB = nil
	local okL, errL = pcall(function()
		CB = require(game:GetService("ReplicatedStorage"):WaitForChild("IceMagic", 10):WaitForChild("ChainBoltFX", 10))
	end)
	if not (okL and type(CB) == "table" and type(CB.Fire) == "function") then
		warn("[HubShowcaseM1] Voltaic: ChainBoltFX unavailable - nothing drawn (" .. tostring(errL) .. ")")
		return nothing()
	end
	local fwd = cf.LookVector
	local from, to = cf.Position - fwd * (VOLT_SPAN / 2), cf.Position + fwd * (VOLT_SPAN / 2)
	-- the broadcast's fields Fire reads: one point, a hit on it (#Hits), no caster (the leg leaves Origin), no T0 (never stale)
	local shot = { Origin = from, Dir = fwd, Side = "R", Points = { to }, Hits = { true }, End = to }
	local casts, dead, nextAt, firing, warned = {}, false, 0, false, false

	local function fire()
		if firing then return end
		firing = true
		-- (a thread of its own: ChainBoltFX's first call loads VoltaicKit with timed waits, never the caller's frame's)
		task.spawn(function()
			local ok, c = pcall(CB.Fire, shot, { Own = false })
			firing = false
			if not ok and not warned then
				warned = true
				warn("[HubShowcaseM1] Voltaic shot failed: " .. tostring(c))
			end
			if ok and type(c) == "table" and type(c.Destroy) == "function" then
				if dead then pcall(c.Destroy) else casts[#casts + 1] = { Cast = c, At = os.clock() } end
			end
		end)
	end

	local function update(t: number)
		if dead then return end
		if t < nextAt then return end
		nextAt += VOLT_EVERY
		if nextAt <= t then nextAt = t + VOLT_EVERY end  -- (not called for a while: no catch-up volley)
		-- a cast clears itself in ~0.3 s (its watchdog: MaxLife 1.6 s); only the young ones are kept for Destroy
		local now = os.clock()
		for i = #casts, 1, -1 do
			if now - casts[i].At > 3 then table.remove(casts, i) end
		end
		fire()
	end

	local h = {}
	function h.Update(t: number)
		local ok, err = pcall(update, t)
		if not ok and not dead then
			warn("[HubShowcaseM1] Voltaic: " .. tostring(err))
			h.Destroy()
		end
	end
	function h.Destroy()
		if dead then return end
		dead = true
		for _, c in ipairs(casts) do pcall(c.Cast.Destroy) end   -- (Cast:Destroy hands its pooled pieces back)
		table.clear(casts)
	end
	if typeof(parent) == "Instance" then parent.Destroying:Once(h.Destroy) end
	h.Update(0)
	return h
end

-- ====================================================================================================
-- ZEPHYR
-- ====================================================================================================
-- ZEPHYR: Wind Blade -- the REAL crescent, ZephyrFX_WindBlade's drawBlade at the release (the v6 lens sliver, the white-hot
-- core thread on its leading face, the teal rim, the two accent arcs, the vapor wake and the two-arc spiral wake), right
-- hand, in that module's own Tuning, on a ZephyrDraw canvas (Budget WindBlade), held at cf. drawBlade is a local there and
-- every blade it draws is flying at 200 studs/s, so its crescent's lines are mirrored here with the blade's distance flown
-- held at the release (no fade, no own-view rules). The texture streaks scroll along it on the canvas clock. Every
-- ZEPHYR_EVERY s it is released again, as a burst's next blade: the real hand swirl (ZephyrFX.WindBladeSwirl) winds at
-- the hand Trigger ahead, then the release's squash-stretch, the release puff, the ripple ring left off the hand and the
-- flight light (bladeLight's Flight W fading over FlightTime). Zephyr has no wraps.
local ZEPHYR_SHOW_SPEED = 40    -- the virtual flight speed (studs/s) that lays out the wakes behind the held crescent: the
                                -- kit sizes them in seconds of its flight (vapor 0.12 s, spiral 0.07 s at 150 studs/s), so
                                -- 4.8 / 2.8 studs here (the live blade keeps the kit's 18 / 10.5 studs); the hand (the
                                -- swirl, the puff) sits at the vapor wake's tail
local ZEPHYR_EVERY = 0.75       -- s between releases

function M.Zephyr(_wrapId: string, cf: CFrame, parent: Instance, _skinId: string?)   -- (2026-10-26) no skins
	local ZD, ZFX, WT, lead = nil, nil, nil, 0.06
	local okL, errL = pcall(function()
		local ice = game:GetService("ReplicatedStorage"):WaitForChild("IceMagic", 10)
		ZD = require(ice:WaitForChild("ZephyrDraw", 10))
		ZFX = require(ice:WaitForChild("ZephyrFX", 10))
		WT = require(ice:WaitForChild("ZephyrFX_WindBlade", 10)).Tuning
		lead = ZFX.Tuning.WindBlade.Trigger or lead       -- the press -> release lead the swirl winds over
	end)
	if not (okL and type(ZD) == "table" and type(ZD.new) == "function" and type(WT) == "table") then
		warn("[HubShowcaseM1] Zephyr: the Wind Blade look is unavailable - nothing drawn (" .. tostring(errL) .. ")")
		return nothing()
	end
	local sin, cos, exp, max, pi = math.sin, math.cos, math.exp, math.max, math.pi
	local function spow(x, e) return x > 0 and x ^ e or 0 end
	local function lerp(a, b, u) return a + (b - a) * u end

	-- the shot's frame, as newBlade / prepareLook build it: Up = world up off the flight wherever it can be, the
	-- crescent's span axis leant Tilt off it toward the right hand ("/" seen from behind), the spiral wake's E1 / E2
	local C, dir = cf.Position, cf.LookVector
	local up = Vector3.yAxis - dir * dir.Y
	if up.Magnitude < 0.2 then up = cf.UpVector - dir * dir:Dot(cf.UpVector) end
	up = up.Unit
	local right = dir:Cross(up)
	local arc = WT.Arc.R
	local R, SPAN = arc.Radius, math.rad(arc.Span)
	local tilt = math.rad(WT.Tilt) * (WT.HandSign.R or 1)
	local upS = right * sin(tilt) + up * cos(tilt)
	local e1, e2 = right, dir:Cross(right)
	local k = ZEPHYR_SHOW_SPEED / WT.BlenderSpeed
	local wakeLen, spiralLen = WT.Wake.Studs * k, WT.Spiral.Studs * k
	local handAt = C - dir * wakeLen                       -- where the blade left: the vapor wake drains back to it
	local rippleAt = handAt + dir * math.min(WT.Ripple.At, wakeLen)
	local lightAt = C - Vector3.yAxis * WT.Light.Drop

	-- drawBlade's option tables and point buffers, made once (ZephyrDraw reads them and keeps neither)
	local K = WT.Knots
	local O_LENS, O_CORE, O_RIM, O_ACC = { tag = "lens" }, { tag = "core" }, { tag = "rim" }, { tag = "accent" }
	local O_WAKE, O_SPIRAL, O_RIPPLE, O_LIGHT = { tag = "wake" }, { tag = "spiral" }, { tag = "ripple" }, {}
	local P_LENS, P_CORE, W_CORE, P_RIM, W_RIM = {}, {}, {}, {}, {}
	local P_ACC, W_ACC = { {}, {} }, { {}, {} }
	local P_WAKE, W_WAKE, P_SPIRAL = {}, {}, { {}, {} }
	local Pf = WT.Puff
	local O_PUFF = { speed = Pf.Speed, life = Pf.Life, size = Pf.Size, dir = dir, cone = Pf.Cone, grow = Pf.Grow,
		up = Pf.Up or WT.Debris.Up }

	--- drawBlade at the release, `tc` s after it (the squash-stretch, the ripple, the light run on it); `puff`: the release frame
	local function draw(cv, tc, puff)
		local st = 1 + WT.Stretch * exp(-tc / WT.StretchTau)
		local back = WT.Back * st
		-- THE LENS SLIVER (v5): an nu x nv "surf" Sheet, u along the arc, v from the leading face to the back
		local L = WT.Lens
		local nu, nv = K.Lens, K.LensRows
		for i = 1, nu do
			local sa = (i - 1) / (nu - 1)
			local a = (sa - 0.5) * SPAN
			local base = C + upS * (sin(a) * R) - dir * ((1 - cos(a)) * R * back)
			local thick = max(L.Min, L.Thick * spow(sin(pi * sa), L.Power) * st)
			for j = 1, nv do
				P_LENS[(i - 1) * nv + j] = base + dir * (thick * lerp(L.Lead, L.Tail, (j - 1) / (nv - 1)))
			end
		end
		O_LENS.fade, O_LENS.alpha, O_LENS.glow, O_LENS.maxSpans = 1, L.Alpha, L.Glow, nu - 1
		O_LENS.e0, O_LENS.e1, O_LENS.a0 = L.E0, L.E1, L.A0
		cv:Sheet(P_LENS, nu, nv, "surf", O_LENS)
		-- THE CORE THREAD on the leading face and THE RIM
		local Cc, Rm = WT.Core, WT.Rim
		local n = K.Core
		for i = 1, n do
			local sa = (i - 1) / (n - 1)
			local a = (sa - 0.5) * SPAN
			P_CORE[i] = C + upS * (sin(a) * R) - dir * ((1 - cos(a)) * R * back - Cc.Lead)
			W_CORE[i] = Cc.Width * spow(sin(pi * sa), WT.WidthPower) + Cc.Min
		end
		O_CORE.fade, O_CORE.glow, O_CORE.tail, O_CORE.maxSpans = 1, Cc.Glow, Cc.Fray, n - 1
		cv:Ribbon(P_CORE, W_CORE, "core", O_CORE)
		n = K.Rim
		for i = 1, n do
			local sa = (i - 1) / (n - 1)
			local a = (sa - 0.5) * SPAN
			P_RIM[i] = C + upS * (sin(a) * R) - dir * ((1 - cos(a)) * R * back)
			W_RIM[i] = Rm.Width * spow(sin(pi * sa), WT.WidthPower) + Rm.Min
		end
		O_RIM.fade, O_RIM.alpha, O_RIM.glow, O_RIM.tail, O_RIM.maxSpans = Rm.Fade, Rm.Alpha, Rm.Glow, Rm.Fray, n - 1
		cv:Ribbon(P_RIM, W_RIM, "glow", O_RIM)
		-- THE ACCENT ARCS: a share of the span, offset along it, dropped back behind the crescent
		local A = WT.Accent
		n = K.Accent
		O_ACC.fade, O_ACC.alpha, O_ACC.glow, O_ACC.tail, O_ACC.maxSpans = A.Fade, A.Alpha, A.Glow, A.Fray, n - 1
		for ai, acc in ipairs(WT.Accents) do
			local PA, WA = P_ACC[ai], W_ACC[ai]
			if PA then
				for i = 1, n do
					local u = (i - 1) / (n - 1)
					local ss = (u - 0.5) * SPAN * A.Share + acc.Offset
					PA[i] = C + upS * (sin(ss) * acc.Radius) - dir * ((1 - cos(ss)) * acc.Radius * A.Back + A.Drop)
					WA[i] = A.Width * spow(sin(lerp(A.W0, A.W1, u)), A.Power)
				end
				cv:Ribbon(PA, WA, "arc", O_ACC)
			end
		end
		-- THE VAPOR WAKE: the blade's own path back to the hand
		local W = WT.Wake
		n = K.Wake
		for i = 1, n do
			local u = (i - 1) / (n - 1)
			P_WAKE[i] = C - dir * (wakeLen * u)
			W_WAKE[i] = lerp(W.Head, W.Tail, u) * spow(sin(pi * lerp(0.02, 0.98, u)), W.Power)
		end
		O_WAKE.fade, O_WAKE.alpha, O_WAKE.tail, O_WAKE.maxSpans = W.Fade, W.Alpha, W.Fray, n - 1
		cv:Ribbon(P_WAKE, W_WAKE, "vapor", O_WAKE)
		-- THE SPIRAL WAKE: two arcs half a turn apart round the path, on the kit's seconds behind the blade
		local Sp = WT.Spiral
		n = K.Spiral
		O_SPIRAL.fade, O_SPIRAL.alpha, O_SPIRAL.glow, O_SPIRAL.tail, O_SPIRAL.maxSpans = Sp.Fade, Sp.Alpha, Sp.Glow, Sp.Fray, n - 1
		for kk = 0, 1 do
			local P2 = P_SPIRAL[kk + 1]
			for i = 1, n do
				local s = spiralLen * (i - 1) / (n - 1)
				local tsB = s / ZEPHYR_SHOW_SPEED            -- = the kit's (its studs / BlenderSpeed): the whole corkscrew
				local ang = Sp.Twist * tsB + kk * pi
				local rr = Sp.R0 + Sp.Grow * tsB
				P2[i] = C - dir * s + e1 * (rr * cos(ang)) + e2 * (rr * sin(ang))
			end
			cv:Ribbon(P2, Sp.Width, "arc", O_SPIRAL)
		end
		-- THE RIPPLE RING left in the air off the hand, on its own fade
		local Rp = WT.Ripple
		local kr = math.clamp(tc / Rp.Time, 0, 1)
		if kr > 0 and kr < 1 then
			local v = 1 - kr
			O_RIPPLE.fade, O_RIPPLE.alpha = v * Rp.Fade, Rp.Alpha
			cv:RingK(rippleAt, Rp.R0 + Rp.Grow * (1 - v * v * v), dir, Rp.Width * v + Rp.Min, "vapor", O_RIPPLE)
		end
		-- THE LIGHT riding the blade: Flight W at the release, out over FlightTime
		local Lt = WT.Light
		if tc >= 0 and tc < Lt.FlightTime then
			local e = Lt.Flight * (1 - tc / Lt.FlightTime)
			if e > 0.5 then
				O_LIGHT.range, O_LIGHT.flicker = Lt.Range, Lt.Flicker
				cv:Light(lightAt, e, O_LIGHT)
			end
		end
		-- THE RELEASE PUFF off the hand (releaseLook's, on this canvas: ZephyrDraw's Burst)
		if puff then cv:Burst("puff", handAt + dir * Pf.Ahead, Pf.Count, O_PUFF) end
	end

	local cv, dead = nil, false
	local relT, releaseAt, swirlAt, puffDue = nil, nil, 0, false
	local function update(t: number)
		if dead then return end
		if t >= swirlAt then
			swirlAt += ZEPHYR_EVERY
			if swirlAt <= t then swirlAt = t + ZEPHYR_EVERY end
			releaseAt = t + lead
			-- the press: the real swirl winds into the hand over the lead (ZephyrFX_WindBlade's own hands canvas and light);
			-- no blade comes for it, so it lets go Linger after its lead
			pcall(ZFX.WindBladeSwirl, handAt, "R", "Down", dir)
		end
		if releaseAt and t >= releaseAt then
			relT, releaseAt, puffDue = releaseAt, nil, true
		end
		if not cv then
			local okC, c = pcall(ZD.new, "WindBladeShowcase", nil, { Own = true, Budget = "WindBlade" })
			if not (okC and type(c) == "table") then
				warn("[HubShowcaseM1] Zephyr: no ZephyrDraw canvas - nothing drawn (" .. tostring(c) .. ")")
				dead = true
				return
			end
			cv = c
		end
		cv:Begin(t)                                         -- (the canvas clock: the streaks keep scrolling across releases)
		local ok, err = pcall(draw, cv, relT and (t - relT) or 1e6, puffDue)
		cv:End()
		puffDue = false
		if not ok then
			warn("[HubShowcaseM1] Zephyr draw failed: " .. tostring(err))
			dead = true
			cv:Destroy()
			cv = nil
		end
	end

	local h = {}
	function h.Update(t: number)
		local ok, err = pcall(update, t)
		if not ok and not dead then
			warn("[HubShowcaseM1] Zephyr: " .. tostring(err))
			h.Destroy()
		end
	end
	function h.Destroy()
		dead = true
		if cv then
			pcall(function() cv:Destroy() end)
			cv = nil
		end
	end
	if typeof(parent) == "Instance" then parent.Destroying:Once(h.Destroy) end
	h.Update(0)
	return h
end

return M

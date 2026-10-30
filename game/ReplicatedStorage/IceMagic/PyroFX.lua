--[[
	PyroFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/PyroFX

	The Pyro kit's visuals, from the approved Build Prompt #20 meshes in ReplicatedStorage.FireMagicMeshes and
	the Build Prompt #21 timings (wired 2026-09-14). Also the kit's shared numbers (Tuning) and the flight maths,
	which PyroHandler on the server requires so both sides fly the same Fireball and draw the same ring.

	  Fireball       Charge (the fire gathering on the fist), FireFireball (the straight shot, its ember trail and
	                 the starburst where it stops), hot meshes while Immolate is up
	  Immolate       Immolate (three motes ignite at the chest and orbit, one popping per buffed hit),
	                 EmberRefund (the Passive: the orbit flares as a ring of flame)
	  Ring of Fire   RingOfFire: the hand drawing the flame line round the pointed spot by itself, then the
	                 seal, eruption and IGNITE!; RingStartAngle / RingDrawPoint, the draw both sides share;
	                 SteerRing / LockRing / RingSteerable, the circle following the crosshair until the snap
	  Detonate       (a Pyro-only Technique, 2026-09-24) DetonateFlick, the snap and embers off the flicking
	                 fingertips; DetonateMark, the Flame Crown over the victim's head (DetonateCrown2 since round 2), its
	                 three flame points (DetonateCrownFlame) burning down with the fuse (also started off RX_Primed);
	                 DetonateBlast, the explosion scaled by the damage, KABOOM! only on a kill; DetonateFizzle
	  Scorching Lash (a Technique anyone may equip; HELD since round 2, 2026-09-24) LashHold, the burning whip -- a
	                 simulated rope of LashWhipLink pieces and a LashWhipTip -- trailing behind from the hand while the key
	                 is held; Lash, the SWEEP (round 3): the whip swung round the right side and across the front as a
	                 35-stud curve, flames left along its tip's path, the burst at its tip on the crack, the recoil;
	                 LashHit, a pop on each body struck; WatchBurnStacks, one flame per burn stack on every burning
	                 body, off RX_Burning_Stacks

	TOON RULES. The flame meshes are Cryo's kind: baked vertex bands, an inverted-hull outline, SmoothPlastic,
	white, DoubleSided off, opaque -- so nothing here fades them. They pop, grow, shrink and sink, and a
	piece that must vanish for a moment is hidden whole (LocalTransparencyModifier 1).

	Pivot offsets are from the import records (pyro/import_results*.md): a MeshPart's pivot is its bounding-
	box centre, so each part sits at designOrigin * CFrame.new(offset * scale).

	Frame-stepped sequences (the pops and scales) were authored at 30 fps and are sampled at that rate here.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting = game:GetService("Lighting")

local PyroFX = {}

----------------------------------------------------------------------------------------------------
-- tuning (read by PyroHandler too). Every number is a stand-in chosen at wiring time.
----------------------------------------------------------------------------------------------------
PyroFX.Tuning = {
	Fireball = {
		-- a straight shot down the crosshair at Speed, no drop (asked for 2026-09-14; it was a lob). Speed x Life
		-- is how far it flies before it burns out: 166 studs, past the aim ray's Range (2026-10-17 balance pass: it was
		-- 65 x 2.5 = 162; now faster, with about the same reach)
		Speed = 200, Life = 0.83,   --[[one speed for every M1 projectile since 2026-10-17; was 110 / 1.5]]
		Radius = 1.0,                      -- slack on the server's line check for the ball's own size
		Direct = 18, Splash = 9, SplashRadius = 6,
		Trigger = 0.42,                    -- the release beat of both punch animations
		ChargeFrom = 0.04, ChargePeakTP = 0.5, ChargePeakFP = 0.11,
		GrowTP = 0.12, GrowFP = 0.1,       -- after release the ball reaches full size this fast
		Merge = 0.1,                       -- your own fireball eases from the fist onto the crosshair line
		EmberEvery = 1 / 60, EmberLife = 14 / 30, EmberLifeOwn = 10 / 30, EmberBack = 1.9, EmberRise = 0.9,
		EmberMax = 160,
		BurstScale = { 0.55, 1.15, 1.0, 1.03, 0.98, 0.95, 0.82, 0.62, 0.42, 0.22, 0.07, 0.0 },
		BurstSpin = { 0, 6, -4, 3, -2, 1, 0, 0, 0, 0, 0, 0 },
		BurstNear = 4.0,                   -- closer to the camera than this, the burst plays small
	},
	Immolate = {
		Stacks = 3, BurnTicks = 3, BurnDamage = 4, BurnInterval = 0.5,
		Trigger = 0.22, OrbitAt = 0.42, OrbitRadius = 2.0, OrbitSpeed = 180, Chest = Vector3.new(0, 0.5, -1.1),
		PopIn = { 0.4, 1.25, 1.0 }, Spend = { 0.7, 0.35, 0.0 }, Pop = { 0.5, 1.1, 1.0, 0.9, 0.7, 0.45, 0.2, 0.0 },
	},
	EmberRefund = {
		Share = 0.3,
		-- what sets it off (2026-10-17, the owner's pick): "LowHealth" = a hit of the Pyro's that takes an enemy from
		-- Below of their max health or more to under it (in a duel, once a round unless they are healed back over);
		-- "Kill" = the rule before, a kill (which ends a duel round, so it never paid out there)
		Trigger = "LowHealth",
		Below = 0.30,
		Ring = { 0.2, 1.35, 1.0, 1.1, 1.0, 1.0, 0.95, 0.8, 0.6, 0.4, 0.2, 0.05, 0.0 },
	},
	RingOfFire = {
		-- pointed, and the hand draws a Radius circle round the spot by itself over DrawTime (2026-09-14). DrawnRadius
		-- is the size the seal and eruption meshes were drawn at. Radius 8 -> 11.2 (40% bigger, asked for 2026-09-14)
		-- -> 25 (2026-09-17, "a way bigger circle": 2.23x) -> 17.5 (2026-10-05, the owner's call with the flame look, for
		-- BOTH looks). It is the BURNING radius too: PyroHandler reads this one number both for the draw and for the fire
		-- (reach = Radius -- 17.5 studs; it was 25. The Hot fields are unused since Heat Rush left, 2026-10-27).
		-- TraceStep 1.4 -> 1.8 keeps the line's pieces under MAX_SEGMENTS (2*pi*25/1.8 = 87 of 90; 61 at 17.5), and
		-- FireScale grows with it so they still overlap. DrawTime 0.8 -> 0.5 and SettleTime 0.30 -> 0.20 (2026-09-17,
		-- "speed up the circle"): the whole cast, the press to the eruption, is DrawTime + SettleTime + SnapBeat --
		-- 0.93 s, was 1.33 s. SnapBeat is NOT a free number: it is the Trigger frame of RingOfFirePoint in CastPose
		-- and in Viewmodel, the frame the hand flicks out on, so the fire lands with the point. Leave it at 7 / 30.
		Radius = 17.5, DrawnRadius = 8, DrawTime = 0.5, TraceStep = 1.8,
		SettleTime = 0.20, SnapBeat = 7 / 30,
		-- until the snap the circle follows its caster's crosshair: the caster moves their own every frame and sends
		-- the spot every SteerInterval; everyone else's copy eases to it at SteerEase. The caster stops LockLead
		-- before the snap, so the spot they last saw reaches the server before the fire does
		SteerInterval = 1 / 15, SteerEase = 18, LockLead = 0.1,
		-- the flames drawn bigger than their meshes, for looks only: the area that burns is still Radius. FireScale
		-- 1.5 -> 1.9 with TraceStep (2026-09-17): the two together are what makes the line of fire join up, and
		-- 1.9 / 1.8 is a touch over the old 1.5 / 1.4. EruptHeight 1.6 -> 3.6 (2026-09-17, "the fire in the middle
		-- bigger in height"): the column stands 34.8 studs over the spot, was 15.4. Its WIDTH needed nothing -- that
		-- is k * EruptWidth and k is Radius / DrawnRadius, so it grew with the circle (61 studs across, was 27) and
		-- the column keeps its shape. FlickerRate is how fast the three flame variants swap round the ring (they
		-- crawl round it), a second. WordAside: how far IGNITE! steps aside, as a share of the radius (the word).
		FireScale = 1.9, EruptWidth = 1.1, EruptHeight = 3.6, FlickerRate = 18, WordAside = 0.8,
		Damage = 55, HotDamage = 75, HotHeat = 0.67, HotReach = 1.2, Height = 8,
		BurnTicks = 3, BurnDamage = 5, BurnInterval = 0.5,
		SegPop = { 0.3, 1.2, 1.0 }, SegBurn = { 0.7, 0.4, 0.15, 0.0 },
		Seal = { 0.85, 1.18, 1.0, 1.0, 1.0, 0.8, 0.45, 0.0 }, Rise = { 0.15, 0.6, 1.25, 1.1, 1.0 },
		EruptHold = 0.6, EruptSink = 8 / 30,
		Word = { 0.4, 1.35, 1.0 }, WordHold = 10 / 30, WordOut = { 0.7, 0.35, 0.0 }, WordAbove = 4.85,
	},
	-- DETONATE, a Pyro-only Technique (Pyro's default in Q; 2026-09-23, round 2 2026-09-24). PyroHandler reads these for the
	-- mark and the blast, the client for its target check and its M1 gate. Every timing here is divided by
	-- VFXLibrary.ShotTimeScale() on both sides, as the Fireball's are. Stand-ins until the owner tunes them.
	Detonate = {
		Trigger = 0.27,      -- the backhand flick lands: the mark is applied (approved animation)
		M1Lock = 0.78,       -- the clip's length: no Fireball while it plays
		Window = 4.0,        -- s after a qualifying hit that the victim stays Detonate's target
		Range = 120,         -- studs from the caster's root at the press (no line of sight needed)
		Fuse = 1.5,          -- s from the mark to the explosion
		Base = 12,           -- damage at full health ...
		Bonus = 36,          -- ... plus up to this much more, linearly with missing health ...
		FullAt = 0.25,       -- ... reaching Base + Bonus (48) at 25% health or lower
	},
	-- SCORCHING LASH (2026-09-23; round 2, 2026-09-24): a HELD Technique any Element may equip, in either keyed slot.
	-- The burning whip trails behind while the key is down; letting go SWEEPS it (round 3, 2026-09-24, the owner: "if u
	-- release it comes all the way from the side like in a curve path and hits anything in that path"). The caster's
	-- client gathers what the sweep caught with these numbers (LashSweepHas, below) and PyroHandler checks the claim
	-- against the same ones (plus its slack); the burn it leaves is its own STACKING channel, beside Immolate's and Ring
	-- of Fire's replacing one.
	ScorchingLash = {
		Trigger = 0.22,      -- s after the RELEASE: the sweep reaches the front-left and cracks; the strike is resolved here
		ClipEnd = 0.75,      -- the sweep clip's length: the body is back on its stance
		M1Lock = 0.75,       -- = ClipEnd: no M1 while the sweep plays (and none at all while the whip is held)
		-- THE SWEEP: degrees in the horizontal plane round the caster's root, from the FLAT aim at the release
		-- (0 = the aim, NEGATIVE = the caster's right, positive = the left)
		WhipStart = -160,    -- where the whip starts, behind-right (that part of the swing, behind the caster, hits nothing)
		SweepFrom = -110,    -- what it hits: from here, round the right side and across the front ...
		SweepTo = 40,        -- ... to here, front-left, where it cracks
		Reach = 35,          -- flat studs from the caster's root (the whip's full length) ...
		Inner = 3,           -- ... plus anything within this many flat studs at any angle (a hug cannot beat it)
		Down = 3, Up = 6,    -- and between root - Down and root + Up
		Chest = 1.5,         -- studs above the root: where the line of sight starts, on both sides
		MaxTargets = 5,
		Damage = 12,         -- per target struck
		BurnPerStack = 2,    -- burn damage per stack per tick
		Interval = 0.5,      -- tick period (every Pyro burn ticks at 0.5 s)
		Ticks = 8,           -- a hit resets the remaining ticks to this (a stack lives 4 s: a 2.5 s cooldown can build them)
		MaxStacks = 3,       -- per victim, all casters combined
		HoldMax = 6,         -- s the whip can be held; at this it cracks by itself (the row's HoldMax wins if it has one)
		Slack = 1.5,         -- server-side extra reach for lag (studs), like Cross-Slash's (PyroHandler adds its own angle)
	},
}

local T = PyroFX.Tuning

--- Whether `rel` (a point from the caster's root) is inside Scorching Lash's SWEEP round the flat aim `aim` (round 3):
--- out to Reach flat studs between SweepFrom and SweepTo degrees from the aim, or within Inner flat studs at any angle,
--- and between root - Down and root + Up. `slack`: the server's allowances for lag, { Angle, Reach, Inner, Height };
--- nil for the caster's own gathering, which is exact. Server and client both ask this, so the two shapes are one.
function PyroFX.LashSweepHas(rel, aim, slack)
	local L = T.ScorchingLash
	local sa, sr, si, sh = 0, 0, 0, 0
	if slack then sa, sr, si, sh = slack.Angle, slack.Reach, slack.Inner, slack.Height end
	if rel.Y < -L.Down - sh or rel.Y > L.Up + sh then return false end
	local dist = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
	if dist <= L.Inner + si then return true end
	if dist > L.Reach + sr then return false end
	-- the angle from the aim, positive toward the caster's left (the left of a flat aim is (aim.Z, 0, -aim.X))
	local angle = math.deg(math.atan2(rel.X * aim.Z - rel.Z * aim.X, rel.X * aim.X + rel.Z * aim.Z))
	return angle >= L.SweepFrom - sa and angle <= L.SweepTo + sa
end

----------------------------------------------------------------------------------------------------
-- shared maths (server and client)
----------------------------------------------------------------------------------------------------
--- A Fireball's velocity for an aim direction (unit).
function PyroFX.FireballVelocity(dir)
	return dir * T.Fireball.Speed
end

--- Where a Fireball launched from `origin` at `v0` is after `t` seconds of flight: a straight line.
function PyroFX.FireballPoint(origin, v0, t)
	return origin + v0 * t
end

--- Ring of Fire's draw starts on the side of the circle facing `from` (the caster): its angle round `center`.
function PyroFX.RingStartAngle(center, from)
	local d = from - center
	if d.X * d.X + d.Z * d.Z < 0.01 then return 0 end
	return math.atan2(d.Z, d.X)
end

--- Where the drawing hand is on the ring `u` (0..1) of the way through the draw.
function PyroFX.RingDrawPoint(center, radius, startAngle, u)
	local a = startAngle + 2 * math.pi * u
	return center + Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
end


----------------------------------------------------------------------------------------------------
-- colour: the kit's heat ramp, coolest to hottest
----------------------------------------------------------------------------------------------------
local RAMP = {
	Color3.fromRGB(107, 23, 8),     -- Dark #6B1708
	Color3.fromRGB(194, 42, 10),    -- EmberRed #C22A0A
	Color3.fromRGB(242, 92, 13),    -- Base #F25C0D
	Color3.fromRGB(255, 199, 77),   -- Light #FFC74D
	Color3.fromRGB(255, 244, 214),  -- WhiteHot #FFF4D6
}

--- A colour at `pos` along the ramp, 0 (Dark) to 4 (WhiteHot).
--- `ramp`: a wrap's ToonRamp (the same five steps in its colours), else Pyro's own (2026-10-25)
local function rampColour(pos, ramp)
	ramp = ramp or RAMP
	pos = math.clamp(pos, 0, #ramp - 1)
	local i = math.min(#ramp - 2, math.floor(pos))
	return ramp[i + 1]:Lerp(ramp[i + 2], pos - i)
end
PyroFX.RampColour = rampColour


----------------------------------------------------------------------------------------------------
-- client helpers
----------------------------------------------------------------------------------------------------
local MESH_FOLDER = "FireMagicMeshes"
local warned = {}
local Viewmodel, VFXLibrary, Settings = nil, nil, nil

-- WRAPS (SkinCatalog, 2026-10-10): `character`'s wrap for Pyro's `ability` (their replicated, validated choice), or nil;
-- withWrap runs fn under it, so every flame its canvases draw -- and any canvas made inside their frames -- wears it.
-- (2026-10-24) an ELEMENT wrap, like Umbra's (2026-10-19), Cryo's and Toxin's: the caster's one ElementWrap_Pyro
-- (SkinCatalog.ElementWrap), in Studio a WrapStudio attribute on the caster's model -- no longer a Skin_<ability> per
-- ability through Offer. Drawn on the same six abilities Offer listed: the flame-look ones. A borrowed Pyro Technique and a Pyro skin keep Default, as before.
local SkinCat, PDraw = nil, nil
local burnWraps = setmetatable({}, { __mode = "k" })   -- [victim model] = { W = the wrap of the last Lash that hit it, At }
local FLAME_WRAP = { Fireball = true, Immolate = true, EmberRefund = true, RingofFire = true, Detonate = true, ScorchingLash = true }
-- (2026-10-24, the owner on the showreel: the added layers hid the fight on normal moves) each ability's TIER, from
-- PyroHandler's own headers: the Ultimate (Ring of Fire), a Technique (Scorching Lash); the rest are Basics (M1
-- Fireball, Primary Immolate, Passive Ember Refund, Mobility Detonate). A wrap's ShedScale[tier] shrinks its Shed
-- layers -- size, rate, speed, life, lift -- for that tier; the Ultimate (no entry) draws them at full scale.
local TIER = { RingofFire = "Ultimate", ScorchingLash = "Technique" }
local tiered = {}
local function forTier(w, ability)
	local S, shed = w.ShedScale, w.Shed
	local tier = TIER[ability] or "Basic"
	local f = S and shed and (S[ability] or S[tier])               -- (2026-10-24: an ability's own entry wins over its tier's)
	if not f then return w end
	if S[ability] then tier = ability end
	local key = w.Id .. "/" .. tier
	local v = tiered[key]
	if v then return v end
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
	v = setmetatable({ Shed = list, Tier = tier }, { __index = w })
	tiered[key] = v
	return v
end
local function wrapOf(character, ability)
	if typeof(character) ~= "Instance" or not FLAME_WRAP[ability] then return nil end
	SkinCat = SkinCat or require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SkinCatalog"))
	local id = RunService:IsStudio() and character:GetAttribute("WrapStudio") or nil
	if not id then
		local plr = Players:GetPlayerFromCharacter(character)
		if not plr or plr:GetAttribute("Element") ~= "Pyro" then return nil end
		if SkinCat.ElementSkin(plr, "Pyro") ~= "Default" then return nil end      -- (a material wrap never goes over a skin)
		id = SkinCat.ElementWrap(plr, "Pyro")
	end
	local w = type(id) == "string" and id ~= "Default" and SkinCat.Skins[id]
	return (type(w) == "table" and w.Wrap == "Pyro" and w.Flame) and forTier(w, ability) or nil
end
local TOON_PIECES = { "RingOfFireIgnite" }   -- (2026-10-25: the toon pieces with Pyro's colours baked in)
local function prewarmToon(w)
	if not (w and w.ToonRamp) then return end
	local folder = ReplicatedStorage:FindFirstChild("FireMagicMeshes")
	if not folder then return end
	for _, n in ipairs(TOON_PIECES) do
		local src = folder:FindFirstChild(n)
		if src then PDraw.WrapPiece(w, src) end
	end
end
local function withWrap(character, ability, fn, ...)
	local w = wrapOf(character, ability)
	if not w then return fn(...) end
	PDraw = PDraw or require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("PyroDraw"))
	PDraw.PrewarmWrap(w)
	prewarmToon(w)
	return PDraw.WithWrap(w, fn, ...)
end

local function libs()
	if not Viewmodel then
		local ice = ReplicatedStorage:WaitForChild("IceMagic")
		VFXLibrary = require(ice:WaitForChild("VFXLibrary"))
		Viewmodel = require(ice:WaitForChild("Viewmodel"))
		Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
	end
end

----------------------------------------------------------------------------------------------------
-- THE LOOK (Pyro Phase 3, 2026-10-05)
----------------------------------------------------------------------------------------------------
-- "toon": the Build Prompt #20 meshes, every draw in this file. "flame": the owner-confirmed V1 "Layered blaze+" look
-- (flames only), drawn by PyroFlame_Fire / PyroFlame_Ring / PyroFlame_Tech through PyroDraw from the PF_ meshes in
-- ReplicatedStorage.FireMagicMeshes.Flame. Fireball, Immolate, Ember Refund, Ring of Fire, Detonate, Scorching Lash and
-- the burn-stack flames have both looks. The comic
-- words (IGNITE!, KABOOM!) are this file's in either look. No mechanic reads the look: Tuning, the flight maths and
-- every hit test are the same code for both.
-- THE KILL SWITCH: PyroFX.Look is the default; the ReplicatedStorage attribute "PyroLook" ("toon" | "flame") overrides
-- it live, for testing. With "toon" (here, or on the attribute) nothing of the flame look runs. The look is read when
-- an effect STARTS (one that is running keeps its look), and it falls back to "toon" by itself while the flame modules
-- or meshes are not in the place, or when a flame draw fails to start. The wiring is near the foot of this file (THE
-- LOOK SWITCH), where the tables both looks share are in scope.
PyroFX.Look = "flame"
local look, flameOn = nil, nil

--- Starts the flame look's `fn` (of "Fire" | "Ring" | "Tech") in place of the toon draw. True, and what it returned,
--- when the look is "flame" and it started; false -- the caller then draws the toon one -- when the look is "toon",
--- the flame look is not in the place, or it failed (warned once).
local function viaFlame(name, fn, ...)
	local m = flameOn(name)
	if not m then return false end
	local ok, res = pcall(m[fn], ...)
	if ok then return true, res end
	if not warned["flame:" .. fn] then
		warned["flame:" .. fn] = true
		warn(("[PyroFX] the flame look's %s.%s failed; the toon one is drawn: %s"):format(name, fn, tostring(res)))
	end
	return false
end

local function fxFolder()
	libs()
	local name = VFXLibrary.Config.FXFolderName
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

--- A copy of one approved mesh, anchored and inert, keeping the material, colour and transparency it was set
--- up with. nil (with one warning) when the place does not have it.
--- (2026-10-25) the wrap a toon piece made right now wears: the canvas wrap in force (an entry's withWrap), if it paints
--- the toon look (ToonRamp)
local function toonWrapNow()
	local w = PDraw and PDraw.CurrentWrap()
	return (type(w) == "table" and w.ToonRamp) and w or nil
end
local function piece(name, w)
	local folder = ReplicatedStorage:FindFirstChild(MESH_FOLDER)
	local src = folder and folder:FindFirstChild(name)
	if not (src and src:IsA("BasePart")) then
		if not warned[name] then
			warned[name] = true
			warn(("[PyroFX] mesh '%s' not found in ReplicatedStorage.%s"):format(name, MESH_FOLDER))
		end
		return nil
	end
	w = w or toonWrapNow()
	if w and PDraw then                                  -- (2026-10-25) the wrap's copy, its colours swapped for the wrap's
		local t = PDraw.WrapPiece(w, src)
		if t then src = t end
	end
	local p = src:Clone()
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Massless = true
	p.LocalTransparencyModifier = 1           -- hidden until its first placement
	p.Parent = fxFolder()
	return p
end

--- Places a piece at `origin` with its pivot offset, scaled per axis (sx, sy, sz), and shows it.
local function place(p, origin, pivot, sx, sy, sz, base)
	if not p then return end
	sy = sy or sx
	sz = sz or sx
	base = base or p:GetAttribute("BaseSize")
	if not base then
		base = p.Size
		p:SetAttribute("BaseSize", base)
	end
	if sx <= 0.001 or sy <= 0.001 or sz <= 0.001 then
		p.LocalTransparencyModifier = 1
		return
	end
	p.Size = Vector3.new(base.X * sx, base.Y * sy, base.Z * sz)
	p.CFrame = origin * CFrame.new(pivot.X * sx, pivot.Y * sy, pivot.Z * sz)
	p.LocalTransparencyModifier = 0
end

local function hide(p)
	if p then p.LocalTransparencyModifier = 1 end
end

local function destroy(list)
	for _, p in pairs(list) do
		if typeof(p) == "Instance" then p:Destroy() end
	end
end

--- A 30 fps sequence sampled `t` seconds in: its value, or `after` once it has run out.
local function seq(list, t, after)
	local k = math.floor(t * 30 + 1e-4) + 1
	if k < 1 then return list[1] end
	local v = list[k]
	if v == nil then return after end
	return v
end

local function easeOutQuad(x)
	x = math.clamp(x, 0, 1)
	return 1 - (1 - x) * (1 - x)
end

local function easeInQuad(x)
	x = math.clamp(x, 0, 1)
	return x * x
end

--- The os.clock() moment that a server-time stamp corresponds to on this machine.
local function localClock(serverT0)
	if type(serverT0) ~= "number" then return os.clock() end
	return os.clock() - (workspace:GetServerTimeNow() - serverT0)
end

local function flatUnit(v, fallback)
	local h = Vector3.new(v.X, 0, v.Z)
	return h.Magnitude > 1e-3 and h.Unit or fallback
end

local function isLocal(character)
	return character ~= nil and character == Players.LocalPlayer.Character
end

--- (2026-10-19, audit P5F-06) Reduce Enemy VFX's "not an enemy's": yours or a teammate's (VFXLibrary.IsEnemy)
local function spared(character)
	if typeof(character) ~= "Instance" then return false end      -- (no caster known: thinned, as before)
	if VFXLibrary and type(VFXLibrary.IsEnemy) == "function" then return not VFXLibrary.IsEnemy(character) end
	return isLocal(character)
end

--- Whether the local player is looking through their own eyes (the only view this game has today, but the
--- flag is FirstPersonController's to own).
local function firstPerson()
	return Players.LocalPlayer.CameraMode == Enum.CameraMode.LockFirstPerson
end

----------------------------------------------------------------------------------------------------
-- one render step for everything that moves
----------------------------------------------------------------------------------------------------
-- After the camera (Camera), the slide roll (+1), the viewmodel (+2) and the shards (+3): what rides the
-- viewmodel's arms is placed against the arms as they will be drawn.
local effects = {}
local failHooks = {}             -- [effect fn] = what to run if it errors (addEffect's onFail)
local bound = false

local function step(dt)
	local now = os.clock()
	for i = #effects, 1, -1 do
		local ok, alive = pcall(effects[i], now, dt)
		if not ok then
			if not warned.step then
				warned.step = true
				warn("[PyroFX] an effect failed: " .. tostring(alive))
			end
			alive = false
			-- (2026-10-19, audit P5B-18) the effect's own cleanup (addEffect's onFail), so its pieces do not stay behind
			local onFail = failHooks[effects[i]]
			if onFail then pcall(onFail) end
		end
		if not alive then
			failHooks[effects[i]] = nil
			table.remove(effects, i)
		end
	end
	if #effects == 0 and bound then
		RunService:UnbindFromRenderStep("SpellshotPyroFX")
		bound = false
	end
end

--- Runs fn(now, dt) every frame until it returns false; `onFail` (optional) cleans up if fn errors.
local function addEffect(fn, onFail)
	if onFail then failHooks[fn] = onFail end
	table.insert(effects, fn)
	if not bound then
		bound = true
		RunService:BindToRenderStep("SpellshotPyroFX", Enum.RenderPriority.Camera.Value + 4, step)
	end
end

----------------------------------------------------------------------------------------------------
-- M1: FIREBALL
----------------------------------------------------------------------------------------------------
local function meshSet(stem, hot)
	local s = hot and (stem .. "Hot_0") or (stem .. "_0")
	return { s .. "1", s .. "2", s .. "3" }
end

-- embers are small and many, so they are pooled per mesh
local emberPool = {}
local embersLive = 0

local function takeEmber(name, w)
	local key = w and (name .. "@" .. w.Id) or name          -- (2026-10-25: a wrap's pieces pool apart)
	local pool = emberPool[key]
	while pool and #pool > 0 do
		local p = table.remove(pool)
		if p.Parent then return p end
	end
	return piece(name, w)
end

local function giveEmber(name, p, w)
	p.LocalTransparencyModifier = 1
	local key = w and (name .. "@" .. w.Id) or name
	local pool = emberPool[key]
	if not pool then
		pool = {}
		emberPool[key] = pool
	end
	if #pool < 60 and p.Parent then table.insert(pool, p) else p:Destroy() end
end

--- One ember of a fireball's trail: dropped at the tail, drifting up, shrinking to nothing over its life.
local function ember(name, at, scale, life)
	if embersLive >= T.Fireball.EmberMax then return end
	local p = takeEmber(name)
	if not p then return end
	embersLive += 1
	local born = os.clock()
	local rot = CFrame.Angles(math.rad(math.random(-40, 40)), math.rad(math.random(0, 359)), math.rad(math.random(-40, 40)))
	local pos = at + Vector3.new((math.random() - 0.5) * 0.4, (math.random() - 0.5) * 0.4, (math.random() - 0.5) * 0.2)
	local s0 = scale * (0.8 + math.random() * 0.4)
	addEffect(function(now)
		local age = now - born
		if age >= life or not p.Parent then
			embersLive -= 1
			giveEmber(name, p)
			return false
		end
		place(p, CFrame.new(pos + Vector3.new(0, T.Fireball.EmberRise * age, 0)) * rot, Vector3.zero, s0 * (1 - age / life))
		return true
	end)
end

--- The impact: the layered starburst turned to the camera, popping with a little spin, then shrinking away.
function PyroFX.Burst(position)
	libs()
	if viaFlame("Fire", "Burst", position) then return end
	local p = piece("FireballBurst")
	if not p then return end
	local F = T.Fireball
	local born = os.clock()
	local cam = workspace.CurrentCamera
	local k = (cam and (position - cam.CFrame.Position).Magnitude < F.BurstNear) and 0.4 or 1
	addEffect(function(now)
		local t = now - born
		local s = seq(F.BurstScale, t, 0)
		if s <= 0 or not p.Parent then
			p:Destroy()
			return false
		end
		local spin = 0
		for i = 1, math.min(math.floor(t * 30) + 1, #F.BurstSpin) do spin += F.BurstSpin[i] end
		local camPos = workspace.CurrentCamera.CFrame.Position
		place(p, CFrame.lookAt(position, camPos) * CFrame.Angles(0, 0, math.rad(spin)), Vector3.zero, s * k)
		return true
	end)
end

--- The fire gathering on a fist through the punch's windup, gone at the release. `ownView`: on your own
--- viewmodel fist, and small, because that fist is a stud from your eye; otherwise on the character's hand.
function PyroFX.Charge(character, side, hot, ownView, startClock)
	libs()
	if viaFlame("Fire", "Charge", character, side, hot, ownView, startClock) then return end
	-- `ownView` is the CALLER's claim that this is the local player's own charge, and the two call
	-- sites pass a hardcoded literal (true from SpellshotInput, false from AbilityFX). Whether the
	-- gathering fireball is drawn on the viewmodel's fist or on the body's hand is the CAMERA's
	-- business, though, not ownership's: in the third-person testing view the arms are not on screen,
	-- so this falls through to the body branch below -- the same one every other player already sees,
	-- at its own size (ChargePeakTP rather than ChargePeakFP).
	ownView = ownView and firstPerson()
	local F = T.Fireball
	local parts = {}
	for i, name in ipairs(meshSet("FireballCore", hot)) do parts[i] = piece(name) end
	local start = startClock or os.clock()
	local handName = (side == "L") and "LeftHand" or "RightHand"
	addEffect(function(now)
		local u = (now - start) * VFXLibrary.ShotTimeScale()
		if u >= F.Trigger or not character.Parent then
			destroy(parts)
			return false
		end
		for _, p in ipairs(parts) do hide(p) end
		if u < F.ChargeFrom then return true end
		local peak = ownView and F.ChargePeakFP or F.ChargePeakTP
		local s = peak * easeOutQuad((u - F.ChargeFrom) / (F.Trigger - F.ChargeFrom))
		local pos
		if ownView then
			local armCF = Viewmodel.GetArmCFrame(side)
			if not armCF then return true end
			pos = (armCF * CFrame.new(0, 0, -1.25 - 0.25 * s)).Position
		else
			local hand = character:FindFirstChild(handName)
			if not hand then return true end
			pos = (hand.CFrame * CFrame.new(0, -0.15 - (0.05 + 0.62 * s), 0)).Position
		end
		-- front down, so the flames lick upward while it gathers; the variant flickers every other frame
		place(parts[math.floor(now * 15) % 3 + 1], CFrame.lookAt(pos, pos - Vector3.yAxis, Vector3.zAxis), Vector3.zero, s)
		return true
	end)
end

--- A fireball's flight. `origin` and `dir` are the throw itself, the line everybody agrees on (FireballPoint).
--- `visualFrom`, when given, is where it is SEEN to leave -- your own fist -- and it eases from there onto the
--- line over Merge seconds. `onHit(result)` marks this client's own throw: it is called where the fireball
--- stops, and that is what is reported to the server. `hot`: the Immolate-buffed meshes.
function PyroFX.FireFireball(origin, dir, exclude, visualFrom, onHit, hot)
	libs()
	local F = T.Fireball
	if dir.Magnitude < 0.1 then return end
	-- the flame look flies the same line with the same raycast and reports the same hit (PyroFlame_Fire.FireFireball)
	if viaFlame("Fire", "FireFireball", origin, dir, exclude, visualFrom, onHit, hot) then return end
	local v0 = PyroFX.FireballVelocity(dir.Unit)
	local own = onHit ~= nil
	local parts = {}
	for i, name in ipairs(meshSet("FireballCore", hot)) do parts[i] = piece(name) end
	local embers = meshSet("FireballEmber", hot)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local list = { fxFolder() }
	for _, inst in ipairs(exclude or {}) do list[#list + 1] = inst end
	params.FilterDescendantsInstances = list
	local start = os.clock()
	local lastT = 0
	local offset = visualFrom and (visualFrom - origin) or nil
	local cam = workspace.CurrentCamera
	local camStart = cam and cam.CFrame.Position or origin
	local nextEmber = 0
	-- (2026-10-19, audit P5F-06) a teammate's ball is not an enemy's (the thrower is exclude[1], both callers)
	local thin = (Settings.EffectDensity or 1) < 0.75 or (Settings.ThinEnemyVFX and not (own or spared(exclude and exclude[1])))
	addEffect(function(now)
		local t = math.min((now - start) * VFXLibrary.ShotTimeScale(), F.Life)
		local a = PyroFX.FireballPoint(origin, v0, lastT)
		local b = PyroFX.FireballPoint(origin, v0, t)
		local hit = t > lastT and workspace:Raycast(a, b - a, params)
		lastT = t
		if hit or t >= F.Life then
			destroy(parts)
			if hit then
				-- the hit report first: nothing cosmetic may stand between a hit and the server hearing of it
				if onHit then task.spawn(onHit, hit) end
				PyroFX.Burst(hit.Position + hit.Normal * 0.3)
			end
			return false
		end
		local pos = b
		local w = offset and (1 - easeOutQuad(t / F.Merge)) or 0
		if w > 0 then
			local travel = cam and (cam.CFrame.Position - camStart) or Vector3.zero
			pos += (offset + travel) * w
		end
		local peak = own and F.ChargePeakFP or F.ChargePeakTP
		local s = peak + (1 - peak) * easeOutQuad(t / (own and F.GrowFP or F.GrowTP))
		local fwd = v0.Unit
		for _, p in ipairs(parts) do hide(p) end
		place(parts[math.floor(now * 15) % 3 + 1], CFrame.lookAt(pos, pos + fwd), Vector3.zero, s)
		if now >= nextEmber and not (own and t < 0.05) then
			nextEmber = now + F.EmberEvery * (thin and 2 or 1)
			ember(embers[math.random(1, 3)], pos - fwd * F.EmberBack * s, own and 0.7 or 1,
				own and F.EmberLifeOwn or F.EmberLife)
		end
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: IMMOLATE, and the PASSIVE: EMBER REFUND
----------------------------------------------------------------------------------------------------
local moteControllers = {}      -- [character] = controller

--- Immolate on `character`: three motes ignite at the chest on the sweep's beat and spiral out into their orbit
--- round the body. From then on they follow the character's Stacks_Primary: each buffed hit spent shrinks the
--- next mote out and pops a small starburst where it was.
function PyroFX.Immolate(character, serverT0)
	libs()
	if viaFlame("Fire", "Immolate", character, serverT0) then return end
	local I = T.Immolate
	local old = moteControllers[character]
	if old then old.Stopped = true end
	local ctl = { Stopped = false, Seen = false }
	moteControllers[character] = ctl
	local start = localClock(serverT0) + I.Trigger
	local slots = {}
	for i = 1, 3 do
		local variants = {}
		for v = 1, 3 do variants[v] = piece("ImmolateMote_0" .. v) end
		slots[i] = { Variants = variants }
	end
	local function cleanup()
		for _, slot in ipairs(slots) do
			destroy(slot.Variants)
			if slot.Pop then slot.Pop:Destroy() end
		end
		if moteControllers[character] == ctl then moteControllers[character] = nil end
	end
	addEffect(function(now)
		local root = character:FindFirstChild("HumanoidRootPart")
		if ctl.Stopped or not (root and character.Parent) then
			cleanup()
			return false
		end
		for _, slot in ipairs(slots) do
			for _, p in ipairs(slot.Variants) do hide(p) end
		end
		local u = now - start
		if u < 0 then return true end
		-- the count arrives as an attribute; nothing is spent until it has been seen at all
		local stacks = character:GetAttribute("Stacks_Primary") or 0
		if stacks > 0 then ctl.Seen = true end
		local grow = easeOutQuad(u / (I.OrbitAt - I.Trigger))
		local r = 0.25 + (I.OrbitRadius - 0.25) * grow
		local chest = root.CFrame:VectorToWorldSpace(I.Chest) * (1 - grow)
		local any = false
		for i, slot in ipairs(slots) do
			local a = math.rad(-90 + 120 * (i - 1) + I.OrbitSpeed * u)
			local pos = root.Position + chest
				+ Vector3.new(math.cos(a) * r, 0.12 * math.sin(now * 10.5 + i * 2), math.sin(a) * r)
			local s = seq(I.PopIn, u, 1) * (0.35 + 0.65 * grow)
			if ctl.Seen and i > stacks and not slot.SpentAt then
				slot.SpentAt = now
				slot.Pop = piece("ImmolatePop")
				slot.PopPos = pos
			end
			if slot.SpentAt then s *= seq(I.Spend, now - slot.SpentAt, 0) end
			if s > 0.001 then
				any = true
				local tangent = Vector3.new(-math.sin(a), 0, math.cos(a))
				place(slot.Variants[(math.floor(now * 15) + i) % 3 + 1], CFrame.lookAt(pos, pos + tangent), Vector3.zero, s)
			end
			if slot.Pop then
				local ps = seq(I.Pop, now - slot.SpentAt, 0)
				if ps > 0 then
					any = true
					place(slot.Pop, CFrame.lookAt(slot.PopPos, workspace.CurrentCamera.CFrame.Position), Vector3.zero, ps)
				else
					slot.Pop:Destroy()
					slot.Pop = nil
				end
			end
		end
		if not any and ctl.Seen then
			cleanup()
			return false
		end
		return true
	end)
end

--- The Passive: the orbit flares as a ring of flame round the character, shooting up in height and settling
--- away. Its base stays at orbit height; it turns slowly as it goes.
--- `from` (optional, a Vector3: where the enemy fell, off the server's broadcast since 2026-10-05) is for the flame
--- look's streak only; the toon ring does not use it.
function PyroFX.EmberRefund(character, from)
	libs()
	if viaFlame("Fire", "EmberRefund", character, from) then return end
	local p = piece("ImmolateFlareRing")
	if not p then return end
	local base = p.Size
	local born = os.clock()
	addEffect(function(now)
		local root = character:FindFirstChild("HumanoidRootPart")
		local t = now - born
		local z = seq(T.EmberRefund.Ring, t, 0)
		if z <= 0 or not (root and p.Parent) then
			p:Destroy()
			return false
		end
		local xz = 1 + 0.05 * math.min(1, z)
		local at = root.Position
		place(p, CFrame.new(at.X, at.Y - 0.1 + base.Y * z / 2, at.Z) * CFrame.Angles(0, math.rad(90 * t), 0),
			Vector3.zero, xz, z, xz, base)
		return true
	end)
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE: RING OF FIRE
----------------------------------------------------------------------------------------------------
-- POINTED, not traced (asked for 2026-09-14): the caster points at a spot and their hand draws the circle round
-- it by itself. Everyone plays it off the server's T0: a stretch of flame goes down every TraceStep studs as the
-- hand passes, starting on the caster's side (each popping in and flickering between its three variants); the
-- seal flashes as it closes; the settle; and on the snap-and-point's ignition frame the eruption rises out of
-- the circle with IGNITE! above it while the line burns off. The seal and eruption were drawn for an 8-stud
-- circle and are scaled across to the real one, and every flame is drawn bigger than its mesh (FireScale,
-- EruptWidth, EruptHeight) -- looks only, the area that burns is the server's.
-- Until the snap the whole circle, line and all, FOLLOWS its caster's crosshair (asked for 2026-09-14): SteerRing
-- moves it, LockRing pins it where the server lit it.
local TRACE_PIVOT = Vector3.new(0.178, 0.844, 0)
local SEAL_PIVOT = Vector3.new(-0.03, 1.696, 0.023)
local ERUPT_PIVOT = { Normal = Vector3.new(-0.1, 3.866, 0.192), Hot = Vector3.new(0.295, 8.422, 0.255) }
local WORD_PIVOT = Vector3.new(-0.429, -0.248, 0.17)
local MAX_SEGMENTS = 90
local rings = setmetatable({}, { __mode = "k" })     -- [character] = the newest Ring of Fire: { Center, Target, LockAt, Locked }

--- Moves `character`'s Ring of Fire toward `point` while it can still be moved. `exact` puts it there this frame
--- (the caster's own aim); otherwise it eases there at SteerEase (someone else's, heard a few times a second).
function PyroFX.SteerRing(character, point, exact)
	local ring = rings[character]
	if not ring or ring.Locked then return end
	ring.Target = point
	if exact then ring.Center = point end
end

--- The server lit `character`'s Ring of Fire at `point`: it moves no more, bar settling onto that spot.
function PyroFX.LockRing(character, point)
	local ring = rings[character]
	if not ring then return end
	ring.Locked = true
	if point then ring.Target = point end
end

--- True while `character`'s Ring of Fire is still following its caster's aim (up to LockLead before the snap).
function PyroFX.RingSteerable(character)
	local ring = rings[character]
	return ring ~= nil and not ring.Locked and os.clock() < ring.LockAt - T.RingOfFire.LockLead
end

--- IGNITE! by itself, for the flame look (the toon draw below carries its own inside its one effect): the live word
--- on the live maths. The piece RingOfFireIgnite, WORD_PIVOT, Word / WordHold / WordOut from the snap (ring.LockAt),
--- WordAbove over the TOON eruption's height (read off the template, which the flame look never draws), about the
--- ring's centre as it is each frame. SIDEWAYS it is not the live spot: `asideStuds` along the camera's right (the
--- owner's call, 2026-10-05: the flame look's word moves OUT to the design's 1.45 x the drawn radius, so the wildfire
--- does not hide it; nil = the live WordAside of the radius, which the toon draw below keeps).
local function igniteWord(ring, radius, hot, asideStuds)
	local R = T.RingOfFire
	local word = piece("RingOfFireIgnite")
	if not word then return end
	local folder = ReplicatedStorage:FindFirstChild(MESH_FOLDER)
	local erupt = folder and folder:FindFirstChild(hot and "RingOfFireEruptionHot" or "RingOfFireEruption")
	local eruptY = (erupt and erupt:IsA("BasePart")) and erupt.Size.Y or 1
	local snap = ring.LockAt
	local asideBy = asideStuds or radius * R.WordAside
	addEffect(function(now)
		local u = now - snap
		local ws = 0
		if u >= 0 then
			ws = (u < R.WordHold) and seq(R.Word, u, 1) or seq(R.WordOut, u - R.WordHold, 0)
		end
		if not word.Parent or (u >= R.WordHold and ws <= 0.001) then
			word:Destroy()
			return false
		end
		if ws > 0.001 then
			local cam = workspace.CurrentCamera
			local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
			local aside = (right.Magnitude > 1e-3) and right.Unit * asideBy or Vector3.zero
			local at = ring.Center + aside + Vector3.new(0, eruptY + R.WordAbove, 0)
			place(word, CFrame.lookAt(at, cam.CFrame.Position), WORD_PIVOT, ws)
		else
			hide(word)
		end
		return true
	end)
end

--- Ring of Fire round `center`. `startAngle` is where the draw begins (RingStartAngle), and `onDraw(point)`, when
--- given, is told every frame where the drawing hand is on the ring, then nil once the circle has closed.
function PyroFX.RingOfFire(character, center, radius, hot, serverT0, startAngle, onDraw)
	libs()
	local R = T.RingOfFire
	radius = radius or R.Radius
	startAngle = startAngle or 0
	do
		-- the flame look draws the line and the fire and keeps the same `rings` record (PyroFlame_Ring.Bind), so the
		-- steering below serves it unchanged; nil back = it started nothing, and the toon ring is drawn
		local ok, ring = viaFlame("Ring", "RingOfFire", character, center, radius, hot, serverT0, startAngle, onDraw)
		if ok and ring then
			-- IGNITE! stands OUT of the flame look's fire: PyroFlame_Ring.Visual.WordAside (1.45) x the radius its line is
			-- DRAWN at (a HOT line is drawn at the reach when Visual.HotLineAtReach: 21 studs, not 17.5)
			local m = flameOn("Ring")
			local RV = m and m.Visual
			local asideStuds = nil
			if RV and type(RV.WordAside) == "number" then
				asideStuds = radius * ((hot and RV.HotLineAtReach) and R.HotReach or 1) * RV.WordAside
			end
			igniteWord(ring, radius, hot, asideStuds)
			return
		end
	end
	-- (2026-10-19, audit P5B-01) the toon ring is drawn where the fire really ends, the area the server burns
	-- (PyroHandler: radius x HotReach when hot, 21 studs, not 17.5), as the flame look's HotLineAtReach does: the line,
	-- the hand's draw point, the seal and the eruption all go by the reach
	radius = radius * ((hot and R.HotReach) or 1)
	-- (2026-10-19, audit P5B-05) Reduce Flashing: the trace's variants hold still instead of swapping at FlickerRate (18 Hz)
	local calm = Settings and Settings.Get and Settings.Get("ReduceFlashing") == true
	local t0 = localClock(serverT0)
	local closed = t0 + R.DrawTime
	local snap = closed + R.SettleTime + R.SnapBeat
	local k = radius / R.DrawnRadius
	local count = math.clamp(math.floor(2 * math.pi * radius / R.TraceStep + 0.5), 8, MAX_SEGMENTS)
	local segs = {}
	local seal = piece("RingOfFireSeal")
	local erupt = piece(hot and "RingOfFireEruptionHot" or "RingOfFireEruption")
	local word = piece("RingOfFireIgnite")
	local eruptBase = erupt and erupt.Size or Vector3.one
	local eruptPivot = hot and ERUPT_PIVOT.Hot or ERUPT_PIVOT.Normal
	local ring = { Center = center, Target = center, LockAt = snap, Locked = false }
	if character then rings[character] = ring end
	local drawing = onDraw ~= nil
	addEffect(function(now, dt)
		local done = true
		local gap = ring.Target - ring.Center
		if gap.Magnitude > 0.01 then
			ring.Center += gap * (1 - math.exp(-R.SteerEase * (dt or 0)))
		else
			ring.Center = ring.Target
		end
		center = ring.Center
		local origin = CFrame.new(center)
		if gap.Magnitude > 0.01 then done = false end
		local drawn = (now - t0) / R.DrawTime
		-- the line: a stretch goes down as the hand passes the start of it
		while #segs < count and drawn >= #segs / count do
			local i = #segs + 1
			local a = startAngle + 2 * math.pi * (i - 0.5) / count
			local offset = Vector3.new(math.cos(a) * radius, 0, math.sin(a) * radius)
			local dir = Vector3.new(-math.sin(a), 0, math.cos(a))          -- the way the hand is going
			local parts = {}
			for n = 1, 3 do parts[n] = piece("RingOfFireTrace_0" .. n) end
			-- the stretch runs along its own -X (the import turned Blender's +X round); kept relative to the centre,
			-- so it moves with the circle
			segs[i] = { Parts = parts, Offset = offset, Dir = dir, Born = now }
		end
		if #segs < count then done = false end
		local burning = now >= snap
		local f = R.FireScale
		for i, seg in ipairs(segs) do
			local s = burning and seq(R.SegBurn, now - snap, 0) or seq(R.SegPop, now - seg.Born, 1)
			local shown = (math.floor(calm and 0 or now * R.FlickerRate) + i) % 3 + 1   -- the variants crawl round the ring
			local cf = CFrame.fromMatrix(center + seg.Offset, -seg.Dir, Vector3.yAxis)
			for n, p in ipairs(seg.Parts) do
				if n == shown and s > 0.001 then place(p, cf, TRACE_PIVOT, f, s * f, s * f) else hide(p) end
			end
			if s > 0.001 then done = false end
		end
		if drawing then
			if now < closed then
				onDraw(PyroFX.RingDrawPoint(center, radius, startAngle, math.clamp(drawn, 0, 1)))
			else
				drawing = false
				onDraw(nil)
			end
		end
		-- the seal, as the circle closes
		local ss = (now >= closed) and seq(R.Seal, now - closed, 0) or 0
		if seal then
			if ss > 0 then place(seal, origin, SEAL_PIVOT, ss * k, 1, ss * k) else hide(seal) end
		end
		if now - closed < #R.Seal / 30 then done = false end
		local u = now - snap
		if u < R.EruptHold + R.EruptSink then done = false end
		local w, h = k * R.EruptWidth, R.EruptHeight
		if erupt then
			local z = 0
			if u >= 0 and u < R.EruptHold then
				z = seq(R.Rise, u, 1 + 0.05 * math.sin(math.floor(u * 30) * 1.9))
			elseif u >= R.EruptHold then
				z = math.max(0, 1 - (u - R.EruptHold) / R.EruptSink)        -- it sinks back, never fades
			end
			if z > 0.001 then place(erupt, origin, eruptPivot, w, z * h, w, eruptBase) else hide(erupt) end
		end
		if word then
			local ws = 0
			if u >= 0 then
				ws = (u < R.WordHold) and seq(R.Word, u, 1) or seq(R.WordOut, u - R.WordHold, 0)
			end
			if ws > 0.001 then
				-- at the eruption's DRAWN height, not its taller shown one: above that, IGNITE! leaves the top of the
				-- view from normal casting range (seen 2026-09-14 at 30 studs). The taller column (2026-09-17) now reaches
				-- well past that height, so the word steps ASIDE rather than standing inside the fire: WordAside of the
				-- radius along the camera's right, at the same height and the same distance off, so it reads beside the
				-- pillar and still cannot leave the top of the view. WordAside = 0 puts it back on the axis.
				local cam = workspace.CurrentCamera
				local right = Vector3.new(cam.CFrame.RightVector.X, 0, cam.CFrame.RightVector.Z)
				local aside = (right.Magnitude > 1e-3) and right.Unit * (radius * R.WordAside) or Vector3.zero
				local at = center + aside + Vector3.new(0, eruptBase.Y + R.WordAbove, 0)
				place(word, CFrame.lookAt(at, cam.CFrame.Position), WORD_PIVOT, ws)
			else
				hide(word)
			end
		end
		if done then
			for _, seg in ipairs(segs) do destroy(seg.Parts) end
			if seal then seal:Destroy() end
			if erupt then erupt:Destroy() end
			if word then word:Destroy() end
			if character and rings[character] == ring then rings[character] = nil end
			return false
		end
		return true
	end, function()                  -- (2026-10-19, audit P5B-18) an error takes the ring's pieces with it
		for _, seg in ipairs(segs) do destroy(seg.Parts) end
		if seal then seal:Destroy() end
		if erupt then erupt:Destroy() end
		if word then word:Destroy() end
		if character and rings[character] == ring then rings[character] = nil end
	end)
end

----------------------------------------------------------------------------------------------------
-- PHASE TWO (2026-09-24): what Detonate and Scorching Lash share
----------------------------------------------------------------------------------------------------
-- Their pieces come and go several times a fight, so every one is POOLED by mesh name (takeEmber / giveEmber, the
-- embers' pool) rather than cloned and destroyed per cast. Pivot offsets are read off the templates
-- (-PivotOffset.Position, the rule checked on three Pyro meshes on 2026-09-23) instead of typed in here, because the
-- new meshes are imported after this was written. A mesh the place does not have yet simply draws nothing: piece()
-- warns once and returns nil, and place, hide and release all let a nil through.
local pivots = {}

--- A mesh's pivot offset (its design origin to its bounding-box centre), from its template; zero while it is missing.
local function pivotOf(name)
	local v = pivots[name]
	if v then return v end
	local folder = ReplicatedStorage:FindFirstChild(MESH_FOLDER)
	local src = folder and folder:FindFirstChild(name)
	if not (src and src:IsA("BasePart")) then return Vector3.zero end
	v = -src.PivotOffset.Position
	pivots[name] = v
	return v
end

local function release(name, p)
	if p then giveEmber(name, p) end
end

--- Whether the place has the mesh `name` (round 2: the new crown and the whip are drawn only when imported).
local function hasMesh(name)
	local folder = ReplicatedStorage:FindFirstChild(MESH_FOLDER)
	local src = folder and folder:FindFirstChild(name)
	return src ~= nil and src:IsA("BasePart")
end

--- A pooled ember that counts against the kit's EmberMax (nil past it), and its return.
local function takeCounted(name)
	if embersLive >= T.Fireball.EmberMax then return nil end
	local p = takeEmber(name)
	if p then embersLive += 1 end
	return p
end

local function giveCounted(name, p)
	if not p then return end
	embersLive -= 1
	giveEmber(name, p)
end

--- A one-shot turned to the camera and left where it happened: `scale` times the 30 fps `list` (on the shot clock),
--- turned `spin` degrees about the view.
local function popAt(name, position, scale, list, spin)
	local p = takeEmber(name)
	if not p then return end
	local pivot = pivotOf(name)
	local turn = CFrame.Angles(0, 0, math.rad(spin or 0))
	local born = os.clock()
	addEffect(function(now)
		local s = seq(list, (now - born) * VFXLibrary.ShotTimeScale(), 0)
		if s <= 0.001 or not p.Parent then
			giveEmber(name, p)
			return false
		end
		place(p, CFrame.lookAt(position, workspace.CurrentCamera.CFrame.Position) * turn, pivot, s * scale)
		return true
	end)
end

--- Upright at `at`, turned about the vertical only so that its front faces the camera.
local function yawToCamera(at, fallback)
	return CFrame.lookAt(at, at + flatUnit(workspace.CurrentCamera.CFrame.Position - at, fallback))
end

----------------------------------------------------------------------------------------------------
-- MOBILITY, Pyro's own (Q): DETONATE
----------------------------------------------------------------------------------------------------
-- Wired 2026-09-24 on the owner's picks of 2026-09-23: the FLAME CROWN mark, and KABOOM! only on a Detonate that
-- kills. Timings, scales and placements are the shape builder's runtime plan (pyropack detonate_shapes.py and
-- detonate_context.py, VFX_PLANS.md), stand-ins until the owner tunes them; every clock runs on ShotTimeScale.
--   the flick   DetonateFlick: on the clip's Trigger a small ImmolatePop snaps at the right fingertips and four
--               embers flick off along the arm and the swing, shrinking away. The caster's own, in first person: on
--               the viewmodel's fingertip, and small (the snap at 0.3x, the embers at 0.4x -- the embers' own-view size
--               is not in the plan, it is the snap's 0.3 / 0.75, as Fireball's charge is small on your own fist)
--   the mark    DetonateMark: an ImmolatePop lands on the victim's chest and the DetonateCrown pops in over their
--               head, turned about the vertical to each viewer, carrying three FireballEmber_01 licks that burn down
--               one per third of the fuse -- screen left, screen right, the tall middle one last -- each shrinking to
--               40% about its base, then popping off: 3, 2, 1, boom. It is started off the victim's RX_Primed
--               attributes as well (WatchBurnStacks looks), so a late joiner still sees it; a mark whose flag goes
--               down early fizzles, and one whose flag goes down at the end waits a moment for its blast
--   the blast   DetonateBlast: the mark goes, and the DetonateBlast explosion pops on the chest, stepped toward each
--               viewer so the body's forward-held arms can't draw over it, 1.0x at 12 damage up to 1.8x at 48
--               (d.Scale), embers flung out round it in the camera plane; KABOOM! (DetonateWord) above it only when it
--               killed. Reduce Flashing plays blast, embers and word at 0.75x, as TerraBurst does
--   the fizzle  DetonateFizzle: the mark plays its pop-in backwards; no blast
-- A victim's own crown and blast are not drawn in their own first person: the crown sits round their eye and the blast
-- would open on the lens. Their countdown is the HUD's (StatusReactions).
local DETONATE_FX = {
	-- the flick: the snap's pop (0.75x on a body's fingertip, 0.3x on your own viewmodel's, turned SnapSpin degrees);
	-- four embers { mesh, start distance, scale } thrown along 0.65 arm + 0.35 swing + 0.22 up at Fling studs a second,
	-- each pushed apart by its Spread (growing with the distance) and shrinking to nothing over FlickLife
	Snap = { 0.5, 1.1, 1.0, 0.8, 0.5, 0.2 }, SnapTP = 0.75, SnapFP = 0.3, SnapSpin = 20,
	Flick = {
		{ "FireballEmber_01", 0.5, 1.1 }, { "FireballEmber_02", 1.1, 0.95 },
		{ "FireballEmber_03", 1.7, 0.8 }, { "FireballEmber_01", 2.3, 0.6 },
	},
	Spread = { Vector3.new(0, 0.25, 0), Vector3.new(0, -0.15, 0.2), Vector3.new(0, 0.45, -0.2), Vector3.new(0, 0.05, 0.3) },
	Fling = 6.5, FlickLife = 0.35, FlickFP = 0.4,
	-- the mark: the landing pop (the snap's sequence at Land, on the chest -- Chest over the root -- a LandStep toward
	-- the viewer); the crown's pop-in, played backwards for a fizzle; the crown over the root, the licks on its front
	-- arc (degrees from the viewer, scale, and the third of the fuse each burns in: the screen-left one, slot 3,
	-- first), their feet over the band's bottom, the lick's base under its centre, how far one burns down before it pops
	Land = 1.6, LandStep = 1.0, Chest = 0.55,
	PopIn = { 0.4, 1.25, 1.0 }, PopOut = { 1.0, 1.25, 0.4 },
	CrownY = 2.55, CrownR = 1.3, LickDeg = { -62, 0, 62 }, LickScale = { 1.9, 2.4, 1.9 }, LickOrder = { 1, 2, 0 },
	LickFoot = 0.16, LickBase = 0.26, LickLeft = 0.4, LickPop = 0.8,
	-- THE BETTER CROWN (round 2, 2026-09-24; the owner: "make the crown design a little better"): DetonateCrown2, a
	-- sturdier band with bevelled rims, jagged spikes, ember jewels and a Ben-Day patch, with three empty sockets on its
	-- front for three BIG flame points (DetonateCrownFlame, one mesh placed three times, its origin at its foot). The
	-- sockets are the mesh builder's (pyropack/pyro_round2.py FLAME_DEG / FLAME_R / FLAME_Y / FLAME_SCALE / FLAME_ROLL):
	-- degrees round from the crown's front toward its +X, their radius and height over the band's bottom, each flame's
	-- size, and the side flames' lean out (degrees about the view axis). They burn down in the same order and on the same
	-- thirds of the fuse as the licks did (LickOrder, LickLeft) and pop off the same way. Without the new meshes in the
	-- place, the old crown and its licks are drawn instead.
	FlameDeg = { -60, 0, 60 }, FlameR = 1.35, FlameY = 0.55, FlameScale = { 1.0, 1.2, 1.0 }, FlameRoll = { 12, 0, -12 },
	-- a flag that goes down at the end waits Grace for its blast; a mark nothing ends goes out Timeout after its end
	Grace = 0.5, Timeout = 1.5,
	-- the blast: its uniform scale runs BlastScale[1]..[2] with d.Scale, and it steps Step[1] + Step[2] * scale toward
	-- the viewer; its size and spin (degrees, each frame's own, not added up) by frame. The embers from frame 3:
	-- Debris of them (DebrisBig at DebrisBigAt damage or more) at scale * (Fly[1] + Fly[2] * age) from its centre,
	-- tips in, shrinking to nothing over DebrisLife
	Blast = { 0.45, 1.2, 1.08, 1.0, 0.97, 0.9, 0.78, 0.6, 0.4, 0.2, 0.06, 0.0 },
	BlastSpin = { 0, 9, -5, 3, -2, 2, 6, 10, 16, 24, 30, 30 },
	BlastScale = { 1.0, 1.8 }, Step = { 1.8, 0.9 },
	DebrisFrom = 3 / 30, DebrisLife = 0.4, Fly = { 2.5, 14 }, DebrisScale = 1.05,
	Debris = 6, DebrisBig = 10, DebrisBigAt = 30,
	-- KABOOM!: scale * Above[1] + Above[2] over the blast, tilted Tilt degrees; it pops, holds ten frames and shrinks
	-- out as IGNITE! does. Baked at the size it is shown
	Word = { 0.4, 1.3, 1.0 }, WordHold = 13 / 30, WordOut = { 0.7, 0.35, 0.0 }, Above = { 3.3, 3.2 }, Tilt = -4,
	ReduceFlashing = 0.75,
}
local markControllers = {}                                 -- [victim model] = the mark drawn on it
local lastMark = setmetatable({}, { __mode = "k" })        -- [victim model] = the Expires of the newest mark drawn on it

--- The flick off `character`'s right fingertips, on the clip's Trigger after the server's `t0`.
function PyroFX.DetonateFlick(character, t0)
	libs()
	if not (character and character.Parent) then return end
	if viaFlame("Tech", "DetonateFlick", character, t0) then return end
	local D = DETONATE_FX
	local own = isLocal(character) and firstPerson()
	local start = localClock(t0)
	local snap, embers = nil, {}
	local lastTip, fling = nil, nil
	local function finish()
		release("ImmolatePop", snap)
		for _, e in ipairs(embers) do giveCounted(e.Name, e.Part) end
		return false
	end
	addEffect(function(now)
		local age = (now - start) * VFXLibrary.ShotTimeScale() - T.Detonate.Trigger
		if age >= D.FlickLife or not character.Parent then return finish() end
		-- the fingertip, and the way the arm points
		local tip, arm
		local armCF = own and Viewmodel.GetArmCFrame("R")
		if armCF then
			tip, arm = (armCF * CFrame.new(0, 0, -1.25)).Position, armCF.LookVector
		else
			local hand = character:FindFirstChild("RightHand")
			if not hand then return finish() end
			local upper = character:FindFirstChild("RightUpperArm")
			tip = (hand.CFrame * CFrame.new(0, -0.25, 0)).Position
			arm = upper and (tip - upper.Position) or -hand.CFrame.UpVector
		end
		if age < 0 then
			lastTip = tip
			return true
		end
		if not fling then
			-- off the fingertips along the outstretched arm, carried by the swing and lifted a little: along the swing
			-- alone (which ends moving back and down) they read as dripping. Nothing is aimed
			local swing = lastTip and (tip - lastTip) or Vector3.zero
			local v = (arm.Magnitude > 1e-3 and arm.Unit * 0.65 or Vector3.zero)
				+ (swing.Magnitude > 1e-3 and swing.Unit * 0.35 or Vector3.zero) + Vector3.new(0, 0.22, 0)
			fling = v.Unit
			snap = takeEmber("ImmolatePop")
			for i, e in ipairs(D.Flick) do
				embers[i] = { Name = e[1], Part = takeCounted(e[1]), From = e[2], Scale = e[3] }
			end
		end
		local cam = workspace.CurrentCamera.CFrame.Position
		place(snap, CFrame.lookAt(tip, cam) * CFrame.Angles(0, 0, math.rad(D.SnapSpin)), pivotOf("ImmolatePop"),
			seq(D.Snap, age, 0) * (own and D.SnapFP or D.SnapTP))
		local k = own and D.FlickFP or 1
		for i, e in ipairs(embers) do
			local d = e.From + D.Fling * age
			local s = e.Scale * k * math.max(0, 1 - age / D.FlickLife)
			if s < 0.03 then
				hide(e.Part)
			else
				-- tips trailing
				local p = tip + fling * d + D.Spread[i] * (0.4 + d)
				place(e.Part, CFrame.lookAt(p, p - fling) * CFrame.Angles(math.rad(-90), 0, 0), pivotOf(e.Name), s)
			end
		end
		return true
	end, finish)                     -- (2026-10-19, audit P5B-18) an error releases its pieces too
end

--- The Flame Crown on `model` for the mark that goes off at server time `expires`, `fuse` seconds after it landed.
--- `landing`: pop the ImmolatePop on the chest (not for a mark found already running).
local function startMark(model, expires, fuse, landing, own)
	libs()
	-- the flame look's mark keeps the same books (markControllers, lastMark: PyroFlame_Tech.Share), so the blast, the
	-- fizzle and watchMark serve either look's. `own`: not an enemy's cast (the flame look's thinning only)
	if viaFlame("Tech", "StartMark", model, expires, fuse, landing, own) then return end
	local D = DETONATE_FX
	local old = markControllers[model]
	local carry = nil
	if old then
		if math.abs(old.Expires - expires) < 0.05 then                -- the broadcast and the attributes: one mark
			-- (2026-10-19, audit GB-03) unless the watcher (attributes) won the race and this is the broadcast's call:
			-- it upgrades that mark -- drawn again under the caller's wrap, with its `own`, the landing pop while the
			-- crown is still new -- keeping its clock and what it has seen, instead of being dropped
			if landing ~= true or old.Cast then return end
			carry = old
			landing = os.clock() - old.Born < 0.2
		end
		old.Kill = true
	end
	fuse = math.max(fuse, 0.05)
	local ctl = { Expires = expires, Start = localClock(expires - fuse), Born = os.clock(), Shown = {}, Cast = carry ~= nil or landing == true }
	if carry then
		ctl.Born, ctl.Seen, ctl.OffAt, ctl.FizzleAt, ctl.FizzleAsked = carry.Born, carry.Seen, carry.OffAt, carry.FizzleAt, carry.FizzleAsked
	end
	markControllers[model] = ctl
	lastMark[model] = expires
	local root = model:FindFirstChild("HumanoidRootPart")
	if landing and root and not (isLocal(model) and firstPerson()) then
		local chest = root.Position + Vector3.new(0, D.Chest, 0)
		local toCam = workspace.CurrentCamera.CFrame.Position - chest
		if toCam.Magnitude > D.LandStep * 2 then chest += toCam.Unit * D.LandStep end
		popAt("ImmolatePop", chest, D.Land, D.Snap, 0)
	end
	-- round 2: the better crown and its three flame points, when the place has them; else the first crown and its licks
	local better = hasMesh("DetonateCrown2") and hasMesh("DetonateCrownFlame")
	local crownName = better and "DetonateCrown2" or "DetonateCrown"
	local lickName = better and "DetonateCrownFlame" or "FireballEmber_01"
	local crown = takeEmber(crownName)
	local licks = {}
	for i = 1, 3 do licks[i] = takeEmber(lickName) end
	local function finish()
		release(crownName, crown)
		for i = 1, 3 do release(lickName, licks[i]) end
		if markControllers[model] == ctl then markControllers[model] = nil end
		return false
	end
	addEffect(function(now)
		root = model.Parent and model:FindFirstChild("HumanoidRootPart")
		if ctl.Kill or not root then return finish() end
		local ts = VFXLibrary.ShotTimeScale()
		-- whether the victim is still flagged with THIS mark: a flag that goes down early fizzles it, one that goes
		-- down at its end waits Grace for the blast, and a fizzle broadcast is taken only once the flag is down (so the
		-- fizzle of a flick that never landed leaves a live mark alone)
		local on = model:GetAttribute("RX_Primed") == true
			and math.abs((tonumber(model:GetAttribute("RX_Primed_Expires")) or 0) - expires) < 0.05
		if on then
			ctl.Seen = true
		elseif ctl.Seen and not ctl.OffAt then
			ctl.OffAt = now
		end
		local due = ctl.Start + fuse
		if not ctl.FizzleAt then
			if (ctl.OffAt and (ctl.OffAt < due - 0.15 or now - ctl.OffAt > D.Grace))
				or (ctl.FizzleAsked and not on) or now > due + D.Timeout then
				ctl.FizzleAt = now
			end
			ctl.FizzleAsked = nil
		end
		local s = seq(D.PopIn, (now - ctl.Born) * ts, 1)
		if ctl.FizzleAt then
			s = seq(D.PopOut, (now - ctl.FizzleAt) * ts, 0)
			if s <= 0.001 then return finish() end
		end
		if isLocal(model) and firstPerson() then
			hide(crown)
			for i = 1, 3 do hide(licks[i]) end
			return true
		end
		local F = yawToCamera((root.CFrame * CFrame.new(0, D.CrownY, 0)).Position, flatUnit(root.CFrame.LookVector, Vector3.zAxis))
		place(crown, F, pivotOf(crownName), s)
		local u = (now - ctl.Start) / fuse
		if better then
			-- the three flame points in their sockets, facing the viewer with the crown: each burns DOWN toward its foot
			-- over its third of the fuse, to LickLeft, then pops off (3, 2, 1, boom)
			local flamePivot = pivotOf(lickName)
			for i = 1, 3 do
				local burnt = u * 3 - D.LickOrder[i]
				local psi = math.rad(D.FlameDeg[i])
				local foot = Vector3.new(math.sin(psi) * D.FlameR, D.FlameY, -math.cos(psi) * D.FlameR) * s
				local size = D.FlameScale[i] * s
				if burnt >= 1 then
					hide(licks[i])
					if ctl.Shown[i] and not ctl.FizzleAt then
						ctl.Shown[i] = false
						local at = F * CFrame.new(foot + Vector3.new(0, flamePivot.Y * size * D.LickLeft, 0))
						popAt("ImmolatePop", at.Position, D.LickPop * size, T.Immolate.Pop, 0)
					end
				else
					ctl.Shown[i] = true
					local w = 1 - (1 - D.LickLeft) * math.max(0, burnt)
					place(licks[i], F * CFrame.new(foot) * CFrame.Angles(0, 0, math.rad(D.FlameRoll[i])), flamePivot, size * w)
				end
			end
			return true
		end
		for i = 1, 3 do
			local burnt = u * 3 - D.LickOrder[i]               -- 0..1 through this lick's third of the fuse
			local psi = math.rad(D.LickDeg[i])
			local foot = Vector3.new(math.sin(psi) * D.CrownR, D.LickFoot, -math.cos(psi) * D.CrownR) * s
			if burnt >= 1 then
				hide(licks[i])
				if ctl.Shown[i] and not ctl.FizzleAt then
					ctl.Shown[i] = false
					local at = F * CFrame.new(foot + Vector3.new(0, D.LickBase * D.LickScale[i] * D.LickLeft * s, 0))
					popAt("ImmolatePop", at.Position, D.LickPop * s, T.Immolate.Pop, 0)
				end
			else
				-- it burns DOWN toward its base on the band (a lick shrinking to nothing hid behind the band's teeth for
				-- its last moments, so they stop at LickLeft and pop off)
				ctl.Shown[i] = true
				local w = 1 - (1 - D.LickLeft) * math.max(0, burnt)
				place(licks[i], F * CFrame.new(foot), pivotOf("FireballEmber_01") + Vector3.new(0, D.LickBase, 0),
					D.LickScale[i] * s * w)
			end
		end
		return true
	end, finish)                     -- (2026-10-19, audit P5B-18) an error releases its pieces too
end

--- A mark on the victim's RX_Primed attributes that nothing is drawing (a late joiner, a broadcast that never came).
local function watchMark(model)
	if model:GetAttribute("RX_Primed") ~= true then return end
	local expires, total = model:GetAttribute("RX_Primed_Expires"), model:GetAttribute("RX_Primed_Total")
	if type(expires) ~= "number" or type(total) ~= "number" then return end
	local last = lastMark[model]
	if last and math.abs(last - expires) < 0.05 then return end     -- drawn already, or drawn and gone off
	if workspace:GetServerTimeNow() >= expires then return end     -- due: its blast (or fizzle) is on the way
	startMark(model, expires, total, false)
end

--- The mark landed: { Character, Victim, Position, T0 (server time it landed), Fuse (seconds to the blast) }.
function PyroFX.DetonateMark(d)
	local model = d.Victim
	if not (typeof(model) == "Instance" and model.Parent) then return end
	libs()
	local fuse = tonumber(d.Fuse) or T.Detonate.Fuse / VFXLibrary.ShotTimeScale()
	local t0 = tonumber(d.T0) or workspace:GetServerTimeNow()
	startMark(model, t0 + fuse, fuse, true, spared(d.Character))   -- (2026-10-19, audit P5F-06) own: not an enemy's cast
end

--- It went off: { Character, Victim, Position, Amount, Scale (0..1), Lethal, T0 }.
function PyroFX.DetonateBlast(d)
	libs()
	local D = DETONATE_FX
	local model = typeof(d.Victim) == "Instance" and d.Victim or nil
	local ctl = model and markControllers[model]
	if ctl then ctl.Kill = true end                                   -- the mark goes on the blast's frame
	if model and isLocal(model) and firstPerson() then return end
	local root = model and model.Parent and model:FindFirstChild("HumanoidRootPart")
	local at = root and root.Position or d.Position
	if typeof(at) ~= "Vector3" then return end
	local k = (Settings.Get and Settings.Get("ReduceFlashing")) and D.ReduceFlashing or 1
	local base = (D.BlastScale[1] + (D.BlastScale[2] - D.BlastScale[1]) * math.clamp(tonumber(d.Scale) or 0, 0, 1)) * k
	local chest = at + Vector3.new(0, D.Chest, 0)
	local count = ((tonumber(d.Amount) or 0) >= D.DebrisBigAt) and D.DebrisBig or D.Debris
	-- the flame look draws the fire (PyroFlame_Tech.DetonateBlast); KABOOM! stays this function's, on the numbers above
	local flameBlast = viaFlame("Tech", "DetonateBlast", d)
	if flameBlast then count = 0 end
	local blast = (not flameBlast) and takeEmber("DetonateBlast") or nil
	local word = (d.Lethal == true) and takeEmber("DetonateWord") or nil
	if flameBlast and not word then return end
	local debris = nil
	local born = os.clock()
	local function finish()
		release("DetonateBlast", blast)
		release("DetonateWord", word)
		for _, e in ipairs(debris or {}) do giveCounted(e.Name, e.Part) end
		return false
	end
	addEffect(function(now)
		local t = (now - born) * VFXLibrary.ShotTimeScale()
		local cam = workspace.CurrentCamera.CFrame.Position
		-- stepped toward THIS viewer so it covers the body (centred in the chest, the forward-held arms drew in front
		-- of it), but never onto the lens from close up
		local c = chest
		local toCam = cam - chest
		if toCam.Magnitude > 2 then c += toCam.Unit * math.min(D.Step[1] + D.Step[2] * base, toCam.Magnitude - 2) end
		local F = CFrame.lookAt(c, cam)
		local going = false
		local s = seq(D.Blast, t, 0)
		if s > 0.001 then
			going = true
			local spin = seq(D.BlastSpin, t, D.BlastSpin[#D.BlastSpin])
			place(blast, F * CFrame.Angles(0, 0, math.rad(spin)), pivotOf("DetonateBlast"), base * s)
		else
			hide(blast)
		end
		-- the embers, from the frame after the peak (on the peak they sat on the star as clutter), in the camera plane
		local u = t - D.DebrisFrom
		if u < 0 then
			going = true
		else
			if not debris then
				debris = {}
				for i = 1, count do
					local name = (i % 2 == 0) and "FireballEmber_03" or "FireballEmber_01"
					debris[i] = { Name = name, Part = takeCounted(name) }
				end
			end
			local ds = base * D.DebrisScale * math.max(0, 1 - u / D.DebrisLife)
			for i, e in ipairs(debris) do
				if ds > 0.02 then
					going = true
					local a = 2 * math.pi * (i - 0.7) / count
					local r = base * (D.Fly[1] + D.Fly[2] * u) * ((i % 2 == 0) and 1 or 0.85)
					place(e.Part, F * CFrame.new(math.cos(a) * r, math.sin(a) * r, -0.5) * CFrame.Angles(0, 0, a + math.pi / 2),
						pivotOf(e.Name), ds)
				else
					hide(e.Part)
				end
			end
		end
		if word then
			local ws = (t < D.WordHold) and seq(D.Word, t, 1) or seq(D.WordOut, t - D.WordHold, 0)
			if ws > 0.001 then
				going = true
				local w = c + Vector3.new(0, base * D.Above[1] + D.Above[2], 0)
				place(word, CFrame.lookAt(w, cam) * CFrame.Angles(0, 0, math.rad(D.Tilt)), pivotOf("DetonateWord"), ws * k)
			else
				hide(word)
			end
		end
		if not going then return finish() end
		return true
	end, finish)                     -- (2026-10-19, audit P5B-18) an error releases its pieces too
end

--- The mark went out without a blast: { Victim, Position }. The mark's own frame takes it once the victim's flag is
--- down (startMark).
function PyroFX.DetonateFizzle(d)
	local model = typeof(d.Victim) == "Instance" and d.Victim or nil
	local ctl = model and markControllers[model]
	if ctl then ctl.FizzleAsked = true end
end

----------------------------------------------------------------------------------------------------
-- A TECHNIQUE: SCORCHING LASH (any Element, either keyed slot)
----------------------------------------------------------------------------------------------------
-- Wired 2026-09-24 as smear frames; REBUILT the same day (round 2) as a REAL burning whip -- the owner: "it doesnt look
-- like a whip on fire, something else it looks like entirely", and "if you hold ability of whip, then the whip should be
-- there just you holding it". The smear frames (LashWhipUnroll / Crack / Slack) and LashCrescent stay in
-- FireMagicMeshes, unused.
--   the whip    a ROPE: WHIP.Links pieces of LashWhipLink (a dark ember-red braided cord with flame tongues, built with its
--               rear joint at the origin and one stud long down its -Z) and a LashWhipTip on the end, laid joint to
--               joint by CFrame.lookAt, uniformly thinner toward the tip (S0 -> S1) and stretched along their length to
--               span their joints. The joints are a verlet chain simulated here, every client for every whip, pinned to
--               the caster's right hand (the viewmodel's fist in your own first person): gravity, damping, the floor.
--   the hold    LashHold: while the key is held it hangs from the hand -- drawn back behind the body since round 3 --
--               Hang studs of it, dragging on the floor as the caster moves, and what lies on the floor slides round
--               behind them (Creep), so it trails BEHIND; it pops in on the press, and a hold that ends without a crack
--               shrinks it away, tip first
--   the sweep   Lash (round 3, 2026-09-24, the owner: "if u release it comes all the way from the side like in a curve
--               path and hits anything in that path"): from the release to the Trigger the chain is DRIVEN round the
--               caster (whipSwept) -- the hand's angle from WhipStart, behind-right, round the right side and across the
--               front to SweepTo, front-left; the rope laid from the hand as a CURVE whose every link lags the one before
--               it, so the tip trails the hand and the line bends; grown from Hang to Reach (35 studs) while still
--               behind -- and on the tip's path, from SweepFrom on, a LashBurn every TrailStep degrees shows what it
--               swept. The tip cracks at the Trigger with a FireballBurst; FollowThru to Snap, then the rope again, its
--               rest length shrinking back to the hanging length by Recoil (the whip recoils into the hand), and, the
--               hold being over, it shrinks away. Never faded. Every client draws it from the caster's hand and the flat
--               aim the release carried (Dir)
--   the hits    LashHit: an ImmolatePop on each body the server confirmed, on the chest's side toward the caster
--   the burn    WatchBurnStacks: every body's RX_Burning_Stacks as that many LashBurn flames -- over the right
--               shoulder, then the left, then a taller one behind the head -- leaning out, flickering by a half turn
--               about their own up (one mesh, not three variants), popping in per stack and shrinking out together
--               when the burn goes out. Not drawn on your own body in your own first person, like your heat lines
-- The chain's layout is the mesh builder's (pyropack/pyro_round2.py chain_at / joint_offsets / hang_chain): link i rolled
-- (i mod 3) x 120 degrees about its own axis so its big flame tongue cycles round the braid, scaled (s, s, max(spacing /
-- LinkLength, SZMin x s)), the joints spaced in proportion to the links' scales; the tip on the last joint at S1 / 0.5.
-- A mesh the place does not have draws nothing (piece() warns once).
local WHIP = {
	Links = 18, S0 = 1.0, S1 = 0.45, SZMin = 0.75, TipAt = 0.5,
	Hang = 6,                  -- studs of whip hanging from the hand
	Gravity = 60, Damp = 0.985, Step = 1 / 120, MaxSteps = 4, Iter = 6,
	Ground = 0.14, GroundRay = 14,
	Creep = 4,                 -- studs/s the part lying on the floor slides toward the caster's back (it trails behind)
	PopIn = { 0.4, 1.15, 1.0 }, Out = 0.3,
	-- the sweep, seconds after the release on the sweep clip (so on ShotTimeScale): driven from the release (taking the
	-- rope over from where it lay within Blend), the crack at the Trigger (Tuning), on by FollowThru degrees to Snap, then
	-- the rope again, recoiled into the hanging length by Recoil
	Blend = 0.05, Snap = 0.30, Recoil = 0.62, FollowThru = 12,
	GrowU = 0.33,              -- share of the sweep by which it is Reach long (the part of the swing behind the caster)
	Bend = 45,                 -- degrees the tip lags the hand mid-sweep (x sin(pi u): straight as it starts and at the crack)
	Drop = 1.5,                -- studs the tip is below the hand
	Crack = { 1.0, 1.15, 1.0, 0.95, 0.8, 0.6, 0.4, 0.2, 0.05, 0.0 }, CrackScale = 1.1,
	-- the swept area: a LashBurn on the tip's path every TrailStep degrees from SweepFrom to SweepTo, popping in and
	-- shrinking out (30 fps: 0.33 s)
	TrailStep = 10, TrailScale = 0.8, Trail = { 0.5, 1.15, 1.0, 0.85, 0.7, 0.55, 0.4, 0.25, 0.1, 0.0 },
	OwnGrip = 1.25,            -- studs from the viewmodel arm's root to its fist
	OwnScale = 0.7,            -- your own whip in your own first person, where its grip end is a stud from the lens
}
local LASH_FX = {
	-- a hit: HitUp over the UpperTorso's centre (HitChest over the reported root without one), HitOut toward the caster
	Hit = { 0.8, 1.15, 1.0, 0.85, 0.6, 0.35, 0.12, 0.0 }, HitScale = 1.3, HitUp = 0.1, HitOut = 0.7, HitChest = 0.55,
	-- the burn: { UpperTorso-local seat, size, lean out in degrees } per stack; every flame a little bigger with the count
	BurnSlots = {
		{ Vector3.new(1.55, 0.7, 0.1), 1.0, -12 }, { Vector3.new(-1.55, 0.7, 0.1), 1.0, 12 }, { Vector3.new(0, 0.8, 1.1), 1.3, 0 },
	},
	BurnGrow = { 1.0, 1.08, 1.16 }, BurnScale = 0.9, BurnPop = { 0.4, 1.2, 1.0 }, BurnOut = 4 / 30, BurnFlicker = 15,
}
local HALF_TURN = CFrame.Angles(0, math.pi, 0)
local whips = {}                -- [character] = the whip being drawn on it
local burnControllers = {}      -- [model] = the burn flames on it

-- the links' scales, grip to tip, and each joint's distance along a whip `length` long (spacing in proportion to the
-- scales, so every link is stretched by the same ratio)
local whipScales, whipFractions = {}, { [0] = 0 }
do
	local total = 0
	for i = 1, WHIP.Links do
		whipScales[i] = WHIP.S0 + (WHIP.S1 - WHIP.S0) * (i - 1) / math.max(1, WHIP.Links - 1)
		total += whipScales[i]
	end
	local acc = 0
	for i = 1, WHIP.Links do
		acc += whipScales[i]
		whipFractions[i] = acc / total
	end
end

--- The grip: the right fist -- the viewmodel's in your own first person, else the body's hand.
local function whipGrip(ctl)
	local character = ctl.Character
	if ctl.Own and firstPerson() then
		local arm = Viewmodel.GetArmCFrame("R")
		if arm then return (arm * CFrame.new(0, 0, -WHIP.OwnGrip)).Position end
	end
	local hand = character:FindFirstChild("RightHand")
	if hand then return (hand.CFrame * CFrame.new(0, -0.15, 0)).Position end
	local arm = character:FindFirstChild("Right Arm")
	return arm and (arm.CFrame * CFrame.new(0, -1, 0)).Position or nil
end

--- The floor under the caster (one ray a frame per whip), for the rope to lie on.
local function whipGround(ctl, root)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { ctl.Character, fxFolder(), workspace.CurrentCamera }
	params.RespectCanCollide = true
	local hit = workspace:Raycast(root.Position, Vector3.new(0, -WHIP.GroundRay, 0), params)
	return hit and hit.Position.Y or -math.huge
end

--- One verlet step of the rope: gravity and damping on every joint but the grip, the floor with friction (and the part
--- on it sliding toward `back`, the caster's back, round 3), then the joints pulled back to their spacing (`stretch` x
--- the hanging spacing) a few times over.
local function whipStep(ctl, grip, ground, stretch, h, back)
	local P, Q, n = ctl.P, ctl.Q, WHIP.Links
	local fall = Vector3.new(0, -WHIP.Gravity * h * h, 0)
	local floor = ground + WHIP.Ground
	local creep = back and back * (WHIP.Creep * h) or Vector3.zero
	for i = 1, n do
		local v = (P[i] - Q[i]) * WHIP.Damp
		Q[i] = P[i]
		local p = P[i] + v + fall
		if p.Y < floor then
			p = Vector3.new(p.X, floor, p.Z) + creep
			Q[i] = Vector3.new(p.X, Q[i].Y, p.Z)          -- friction on the floor
		end
		P[i] = p
	end
	for _ = 1, WHIP.Iter do
		P[0] = grip
		for i = 1, n do
			local d = P[i] - P[i - 1]
			local len = d.Magnitude
			if len > 1e-6 then
				local rest = (whipFractions[i] - whipFractions[i - 1]) * WHIP.Hang * stretch
				local corr = d * ((len - rest) / len)
				if i == 1 then
					P[i] -= corr
				else
					P[i - 1] += corr * 0.5
					P[i] -= corr * 0.5
				end
			end
		end
	end
	P[0] = grip
end

--- The SWEEP's joints `t` seconds after the release (round 3), laid from `grip` round the flat `aim` (`left`: its left).
--- The hand's angle (0 = the aim, negative = the caster's right) runs WhipStart -> SweepTo over the Trigger, then on by
--- FollowThru to Snap. The rope is a CURVE: each link's heading lags the one before it (the tip by Bend x sin(pi u)
--- degrees, u the share of the sweep: straight as it leaves from behind, bent most mid-sweep, straight at the crack), level
--- but for Drop to the tip, and Hang long at the release, Reach long from GrowU of the sweep on.
local function whipSwept(grip, aim, left, t)
	local L = T.ScorchingLash
	local u = math.clamp(t / L.Trigger, 0, 1)
	local hand = L.WhipStart + (L.SweepTo - L.WhipStart) * u
	if t > L.Trigger then
		hand = L.SweepTo + WHIP.FollowThru * easeOutQuad((t - L.Trigger) / math.max(1e-3, WHIP.Snap - L.Trigger))
	end
	local bend = WHIP.Bend * math.sin(math.pi * u)
	local length = WHIP.Hang + (L.Reach - WHIP.Hang) * easeOutQuad(u / WHIP.GrowU)
	local out = { [0] = grip }
	local at = grip
	for i = 1, WHIP.Links do
		local f0, f1 = whipFractions[i - 1], whipFractions[i]
		local a = math.rad(hand - bend * (f0 + f1) * 0.5)
		at = at + (aim * math.cos(a) + left * math.sin(a)) * (length * (f1 - f0)) - Vector3.new(0, WHIP.Drop * (f1 - f0), 0)
		out[i] = at
	end
	return out
end

--- The angle of `rel` (from the caster's root) round the flat `aim`, as the Tuning measures it: positive to the left.
--- Behind the caster, past the back, it counts on below -180 rather than wrapping round to the front-left.
local function sweepAngle(rel, aim, left)
	local a = math.deg(math.atan2(rel:Dot(left), rel:Dot(aim)))
	if a > T.ScorchingLash.SweepTo + 60 then a -= 360 end
	return a
end

--- One flame of the swept area, upright at `position` and turned to the camera: it pops in and shrinks away.
local function trailFlame(position)
	local p = takeEmber("LashBurn")
	if not p then return end
	local pivot = pivotOf("LashBurn")
	local born = os.clock()
	addEffect(function(now)
		local s = seq(WHIP.Trail, (now - born) * VFXLibrary.ShotTimeScale(), 0)
		if s <= 0.001 or not p.Parent then
			giveEmber("LashBurn", p)
			return false
		end
		place(p, yawToCamera(position, Vector3.new(0, 0, -1)), pivot, s * WHIP.TrailScale)
		return true
	end)
end

--- The swept area as the tip sweeps it: a flame at each TrailStep from SweepFrom up to SweepTo that the tip has reached,
--- on that exact angle round the caster at the tip's distance and height -- so a long frame, or a sweep first seen
--- partway through (a late broadcast), still leaves them evenly along the arc rather than in a pile at the tip.
local function whipTrail(ctl, centre, aim, left, tip)
	local L = T.ScorchingLash
	local rel = tip - centre
	local a = sweepAngle(rel, aim, left)
	local r = math.sqrt(rel.X * rel.X + rel.Z * rel.Z)
	ctl.TrailNext = ctl.TrailNext or L.SweepFrom
	while ctl.TrailNext <= L.SweepTo and a >= ctl.TrailNext - 1e-3 do
		local b = math.rad(ctl.TrailNext)
		trailFlame(centre + (aim * math.cos(b) + left * math.sin(b)) * r + Vector3.new(0, rel.Y, 0))
		ctl.TrailNext += WHIP.TrailStep
	end
end

--- Draws the rope: each link from its joint to the next, rolled round the braid, thinner to the tip, stretched to span
--- its joints; `grow` scales the whole whip, `shrink(i)` each link (the whip going out, tip first).
local function whipDraw(ctl, grow, shrink)
	local P, n = ctl.P, WHIP.Links
	local pivot = pivotOf("LashWhipLink")
	local linkLength = ctl.LinkLength
	for i = 1, n do
		local part = ctl.Parts[i]
		local a, b = P[i - 1], P[i]
		local d = b - a
		local len = d.Magnitude
		local s = whipScales[i] * grow * (shrink and shrink(i) or 1)
		if not part or len < 1e-3 or s < 0.02 then
			hide(part)
		else
			local upHint = math.abs(d.Unit.Y) > 0.98 and Vector3.xAxis or Vector3.yAxis
			local cf = CFrame.lookAt(a, b, upHint) * CFrame.Angles(0, 0, math.rad(120 * (i % 3)))
			place(part, cf, pivot, s, s, math.max(len / linkLength, WHIP.SZMin * s))
		end
	end
	local a, b = P[n - 1], P[n]
	local d = b - a
	local st = WHIP.S1 / WHIP.TipAt * grow * (shrink and shrink(n) or 1)
	if d.Magnitude < 1e-3 or st < 0.02 then
		hide(ctl.Tip)
	else
		local upHint = math.abs(d.Unit.Y) > 0.98 and Vector3.xAxis or Vector3.yAxis
		place(ctl.Tip, CFrame.lookAt(b, b + d.Unit, upHint), pivotOf("LashWhipTip"), st)
	end
end

--- The whip on `character`, made (or found) and running: the rope, hanging from the grip, stepped and drawn every frame
--- until it has gone out.
local function whipFor(character, isOwn)
	local ctl = whips[character]
	if ctl then
		if isOwn then ctl.Own = true end
		return ctl
	end
	libs()
	do
		-- the flame look's whip is made by PyroFlame_Tech and kept in the same `whips` table with the same fields, so
		-- LashHold and Lash drive it unchanged
		local ok, made = viaFlame("Tech", "WhipFor", character, isOwn)
		if ok then return made end
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	ctl = { Character = character, Own = isOwn == true, Parts = {}, P = {}, Q = {}, Born = os.clock(), Acc = 0 }
	-- the link's length at scale 1: twice its bounding box's centre from its rear-joint origin (1 stud, as built)
	local pz = math.abs(pivotOf("LashWhipLink").Z)
	ctl.LinkLength = pz > 0.2 and 2 * pz or 1
	for i = 1, WHIP.Links do ctl.Parts[i] = takeEmber("LashWhipLink") end
	ctl.Tip = takeEmber("LashWhipTip")
	whips[character] = ctl
	-- it starts hanging behind the hand, and settles from there
	local grip = whipGrip(ctl) or root.Position
	local back = -flatUnit(root.CFrame.LookVector, Vector3.new(0, 0, -1))
	for i = 0, WHIP.Links do
		local f = whipFractions[i] * WHIP.Hang
		ctl.P[i] = grip + Vector3.new(0, -f * 0.8, 0) + back * (f * 0.5)
		ctl.Q[i] = ctl.P[i]
	end
	local function finish()
		for i = 1, WHIP.Links do release("LashWhipLink", ctl.Parts[i]) end
		release("LashWhipTip", ctl.Tip)
		if whips[character] == ctl then whips[character] = nil end
		return false
	end
	addEffect(function(now, dt)
		root = character.Parent and character:FindFirstChild("HumanoidRootPart")
		local grip = root and whipGrip(ctl)
		if ctl.Kill or not grip then return finish() end
		local ts = VFXLibrary.ShotTimeScale()
		local L = T.ScorchingLash
		-- the sweep, on its own clock from the release
		local t = ctl.CrackAt and (now - ctl.CrackAt) * ts or nil
		local stretch = 1
		local driven = false
		if t and t >= 0 and t < WHIP.Snap then
			driven = true
			if not ctl.From then
				ctl.From = table.clone(ctl.P)                  -- where the rope lay: the drive blends out of it
			end
			local aim = ctl.Dir
			local left = Vector3.new(aim.Z, 0, -aim.X)
			local target = whipSwept(grip, aim, left, t)
			local w = math.clamp(t / WHIP.Blend, 0, 1)
			for i = 0, WHIP.Links do
				ctl.P[i] = ctl.From[i]:Lerp(target[i], w)
				ctl.Q[i] = ctl.P[i]                             -- it hands back to the rope at rest
			end
			ctl.P[0] = grip
			local tip = ctl.P[WHIP.Links]
			whipTrail(ctl, root.Position, aim, left, tip)
			if t >= L.Trigger and not ctl.Cracked then
				ctl.Cracked = true
				popAt("FireballBurst", tip, WHIP.CrackScale, WHIP.Crack, 0)
			end
		elseif t and t >= WHIP.Snap and t < WHIP.Recoil then
			-- the recoil: the rope again, its spacing shrinking from the full reach back to hanging
			local v = (t - WHIP.Snap) / (WHIP.Recoil - WHIP.Snap)
			stretch = (L.Reach / WHIP.Hang) + (1 - L.Reach / WHIP.Hang) * easeOutQuad(v)
		elseif t and t >= WHIP.Recoil and not ctl.Recoiled then
			ctl.Recoiled = true
			if not ctl.Holding and not ctl.OutAt then ctl.OutAt = now end    -- the crack ended the hold: it goes
		end
		if not driven then
			local ground = whipGround(ctl, root)
			ctl.Acc = math.min(ctl.Acc + dt * ts, WHIP.Step * WHIP.MaxSteps)
			local back = -flatUnit(root.CFrame.LookVector, Vector3.new(0, 0, -1))
			while ctl.Acc >= WHIP.Step do
				ctl.Acc -= WHIP.Step
				whipStep(ctl, grip, ground, stretch, WHIP.Step, back)
			end
			ctl.P[0] = grip
		end
		-- going out: every link shrinks to nothing, the tip end first
		local shrink = nil
		if ctl.OutAt then
			local k = (now - ctl.OutAt) * ts / WHIP.Out
			if k >= 1 then return finish() end
			shrink = function(i)
				return math.clamp(1 - k * (1 + whipFractions[i]), 0, 1)
			end
		end
		local grow = seq(WHIP.PopIn, (now - ctl.Born) * ts, 1) * ((ctl.Own and firstPerson()) and WHIP.OwnScale or 1)
		whipDraw(ctl, grow, shrink)
		return true
	end, finish)                     -- (2026-10-19, audit P5B-18) an error releases its pieces too
	return ctl
end

--- The whip HELD (round 2): `on` hangs it from `character`'s hand (or keeps the one already there); off lets a hold that
--- ended without a crack go -- it shrinks away. `isOwn`: the local player's own, drawn off the viewmodel's fist while the
--- camera is really in first person. The press calls this on the caster's own client at once, and the server's
--- ScorchingLashHold again for everyone: the second call finds the whip already there.
function PyroFX.LashHold(character, on, t0, isOwn)
	if not (typeof(character) == "Instance" and character.Parent) then return end
	if isOwn == nil then isOwn = isLocal(character) end
	local ctl = whips[character]
	if on then
		if ctl and ctl.CrackAt and not ctl.Recoiled then return end   -- a crack still out: it goes when that is over
		if ctl and ctl.OutAt then
			ctl.OutAt = nil                                  -- going out: back in the hand
			ctl.Born = os.clock()
		end
		ctl = ctl or whipFor(character, isOwn)
		if not ctl then return end
		ctl.Holding = true
		ctl.CrackAt, ctl.From, ctl.Cracked, ctl.Recoiled = nil, nil, nil, nil
	elseif ctl then
		ctl.Holding = false
		if not ctl.CrackAt or ctl.Recoiled then
			ctl.OutAt = ctl.OutAt or os.clock()
		end
	end
end

--- THE SWEEP of `character`'s whip (round 3), from the server's `t0` (nil: now -- your own client's release). `dir`: the
--- aim the release carried, flat (anything else is flattened); `isOwn`: the local player's own. A whip that was never seen
--- in the hand (a late joiner, a tap whose hold came in the same instant) is made first. Your own client sweeps it on the
--- release; the server's broadcast of the same sweep, a round trip later, finds it already sweeping and changes nothing.
function PyroFX.Lash(character, t0, dir, isOwn)
	libs()
	if not (typeof(character) == "Instance" and character.Parent) then return end
	if isOwn == nil then isOwn = isLocal(character) end
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then return end
	local ctl = whips[character]
	local start = localClock(t0)
	if ctl and ctl.CrackStarted and os.clock() - ctl.CrackStarted < 0.6 then return end   -- this crack, heard again
	ctl = ctl or whipFor(character, isOwn)
	if not ctl then return end
	ctl.CrackStarted = os.clock()
	ctl.CrackAt = start
	local look = flatUnit(root.CFrame.LookVector, Vector3.new(0, 0, -1))
	ctl.Dir = typeof(dir) == "Vector3" and flatUnit(dir, look) or look
	ctl.Holding = false                                        -- a sweep ends the hold
	ctl.OutAt, ctl.From, ctl.Cracked, ctl.Recoiled = nil, nil, nil, nil
	ctl.TrailNext = nil
end

--- The bodies the server says the crack caught: { Character, Victims = { model, ... }, Positions = { Vector3, ... } }.
--- A victim can arrive nil (streamed out); its Position still places the pop.
function PyroFX.LashHit(d)
	libs()
	if viaFlame("Tech", "LashHit", d) then return end
	local L = LASH_FX
	local caster = typeof(d.Character) == "Instance" and d.Character:FindFirstChild("HumanoidRootPart") or nil
	local victims = type(d.Victims) == "table" and d.Victims or {}
	local positions = type(d.Positions) == "table" and d.Positions or {}
	for i = 1, T.ScorchingLash.MaxTargets do
		local model, seen = victims[i], positions[i]
		local torso = typeof(model) == "Instance" and model.Parent
			and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) or nil
		local chest = (torso and (torso.CFrame * CFrame.new(0, L.HitUp, 0)).Position)
			or (typeof(seen) == "Vector3" and seen + Vector3.new(0, L.HitChest, 0)) or nil
		if chest then
			local toward = (caster and caster.Position or workspace.CurrentCamera.CFrame.Position) - chest
			popAt("ImmolatePop", chest + flatUnit(toward, Vector3.zero) * L.HitOut, L.HitScale, L.Hit, 0)
		end
	end
end

--- The burn flames on `model`, following its RX_Burning_Stacks until they have shrunk away.
local function startBurn(model)
	libs()
	if viaFlame("Tech", "StartBurn", model) then return end
	local L = LASH_FX
	local ctl = { Flames = {}, Last = 1 }
	burnControllers[model] = ctl
	local function finish()
		for _, f in pairs(ctl.Flames) do release("LashBurn", f.Part) end
		if burnControllers[model] == ctl then burnControllers[model] = nil end
		return false
	end
	addEffect(function(now)
		local torso = model.Parent and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso"))
		if not torso then return finish() end
		local ts = VFXLibrary.ShotTimeScale()
		local n = math.clamp(math.floor(tonumber(model:GetAttribute("RX_Burning_Stacks")) or 0), 0, #L.BurnSlots)
		if n > 0 then
			if ctl.OutAt then                          -- lit again while going out: they pop back in
				ctl.OutAt = nil
				for _, f in pairs(ctl.Flames) do f.Born = now end
			end
			ctl.Last = n
		elseif not ctl.OutAt then
			ctl.OutAt = now
		end
		local out = ctl.OutAt and 1 - (now - ctl.OutAt) * ts / L.BurnOut or 1
		if out <= 0 then return finish() end
		local hideOwn = isLocal(model) and firstPerson()
		for k, slot in ipairs(L.BurnSlots) do
			local f = ctl.Flames[k]
			if n > 0 and k <= n and not f then
				f = { Part = takeEmber("LashBurn"), Born = now }
				ctl.Flames[k] = f
			elseif n > 0 and k > n and f then          -- fewer stacks without going out (the server never does): it goes
				release("LashBurn", f.Part)
				ctl.Flames[k] = nil
				f = nil
			end
			if f then
				if hideOwn then
					hide(f.Part)
				else
					local s = L.BurnScale * slot[2] * L.BurnGrow[ctl.Last] * seq(L.BurnPop, (now - f.Born) * ts, 1) * out
					-- seated on the UpperTorso in its own turn, leaning out; the flicker is a half turn about its up
					local cf = torso.CFrame * CFrame.new(slot[1]) * CFrame.Angles(0, 0, math.rad(slot[3]))
					if (math.floor(now * L.BurnFlicker) + k) % 2 == 1 then cf *= HALF_TURN end
					place(f.Part, cf, pivotOf("LashBurn"), s)
				end
			end
		end
		return true
	end, finish)                     -- (2026-10-19, audit P5B-18) an error releases its pieces too
end

----------------------------------------------------------------------------------------------------
-- THE LOOK SWITCH (Pyro Phase 3, 2026-10-05): the wiring for PyroFX.Look, declared near the top
----------------------------------------------------------------------------------------------------
-- The flame modules are required lazily and on a client only (the server requires this file for Tuning and the flight
-- maths, and must stay inert), then handed this file's own books: its render step (addEffect) and the tables other
-- functions here reach into whichever look drew the thing -- moteControllers (a re-cast stops the old motes), rings
-- (SteerRing / LockRing / RingSteerable), markControllers and lastMark (DetonateBlast, DetonateFizzle, watchMark),
-- whips (LashHold, Lash) and burnControllers (WatchBurnStacks).
local flameSet, flameRetry = nil, 0
local poseApply = nil      -- installPoses': puts the body clips of the look now in force into CastPose
-- [model] = os.clock() when WatchBurnStacks first saw it at 0 health, kept only while the flame look is loaded: the Ember
-- Refund streak's FALLBACK, the body that fell last (PyroFlame_Fire's fallenNear), used only when the broadcast's From
-- is missing (the victim had no root on the server; From is the normal path -- doc corrected 2026-10-19, audit GB-05)
local fallen = setmetatable({}, { __mode = "k" })

local function flameLibs()
	if flameSet then return flameSet end
	if not RunService:IsClient() or os.clock() < flameRetry then return nil end
	flameRetry = os.clock() + 5                    -- not in the place (yet): look again in a while, not every frame
	local ok, res = pcall(function()
		local ice = ReplicatedStorage:FindFirstChild("IceMagic")
		local mDraw = ice and ice:FindFirstChild("PyroDraw")
		local mFire, mRing, mTech = ice and ice:FindFirstChild("PyroFlame_Fire"), ice and ice:FindFirstChild("PyroFlame_Ring"),
			ice and ice:FindFirstChild("PyroFlame_Tech")
		if not (mDraw and mFire and mRing and mTech) then return nil end
		libs()
		-- THE GATE: every mesh of the library (PyroDraw.Ready), not a sample of it. A mesh that is not there draws
		-- nothing and throws nothing, so on a partial import a piece would be invisible with no toon fallback
		local draw = require(mDraw)
		local ready, missing, total = draw.Ready()
		if not ready then
			if not warned.flameMeshes then
				warned.flameMeshes = true
				local where = "ReplicatedStorage." .. tostring(draw.Config.MeshFolderName)
				if #missing >= total then
					warn(("[PyroFX] the flame look is asked for but its %d meshes are not in %s; the toon look is drawn"):format(total, where))
				else
					warn(("[PyroFX] the flame look is asked for but %d of its %d meshes in %s are missing or the wrong size; the toon look is drawn: %s")
						:format(#missing, total, where, table.concat(missing, ", ")))
				end
			end
			return nil
		end
		local set = { Draw = draw, Fire = require(mFire), Ring = require(mRing), Tech = require(mTech) }
		set.Fire.Init({ PyroFX = PyroFX, AddEffect = addEffect, MoteControllers = moteControllers, Fallen = fallen })
		set.Ring.Bind({ Rings = rings, PyroFX = PyroFX, Viewmodel = Viewmodel, PyroDraw = set.Draw })
		set.Tech.Share({ Marks = markControllers, LastMark = lastMark, Whips = whips, Burns = burnControllers })
		return set
	end)
	if ok then
		if res and not flameSet then
			flameSet = res
			-- the look in force has just become "flame" with no change of the PyroLook attribute (the modules or the
			-- meshes came after the first look): the body clips follow it now, not at the attribute's next change
			if poseApply then poseApply() end
		end
	elseif not warned.flameLibs then
		warned.flameLibs = true
		warn("[PyroFX] the flame look could not load; the toon look is drawn: " .. tostring(res))
	end
	return flameSet
end

--- The look an effect starting now is drawn in: "flame" only when it is asked for AND it can draw.
look = function()
	local want = ReplicatedStorage:GetAttribute("PyroLook")
	if want ~= "toon" and want ~= "flame" then want = PyroFX.Look end
	if want == "flame" and flameLibs() then return "flame" end
	return "toon"
end
PyroFX.CurrentLook = look

flameOn = function(name)
	if look() ~= "flame" then return nil end
	return flameSet[name]
end

--- The flame look's body clips (PyroPoseTable: key data put into CastPose's eight Pyro clips while the look is "flame",
--- the live keys put back for "toon"; CastPose's own source is not edited). Once per client, from WatchBurnStacks.
--- The table's Bind applies the look now and at every change of the PyroLook attribute; poseApply is the same for
--- flameLibs, when the look in force changes without the attribute.
local function installPoses()
	local ok, err = pcall(function()
		local ice = ReplicatedStorage:FindFirstChild("IceMagic")
		local mTable, mPose = ice and ice:FindFirstChild("PyroPoseTable"), ice and ice:FindFirstChild("CastPose")
		if mTable and mPose then
			local poses, castPose = require(mTable), require(mPose)
			poses.Bind(castPose, look)
			poseApply = function()
				local ok2, err2 = pcall(poses.Apply, castPose, look())
				if not ok2 then warn("[PyroFX] the flame look's body clips were not applied: " .. tostring(err2)) end
			end
		end
	end)
	if not ok then warn("[PyroFX] the flame look's body clips were not installed: " .. tostring(err)) end
end

-- Burn stacks and Detonate marks draw themselves off the attributes: every player's body and every
-- range dummy is looked at each frame, the list refreshed each second (TerraFX.WatchStagger's pattern). A mark's own
-- broadcast starts it sooner; this is what a late joiner, or a client that missed it, has. Started once per client
-- (AbilityFX), and does nothing on the server.
local watchingBurns = false
function PyroFX.WatchBurnStacks()
	if watchingBurns or not RunService:IsClient() then return end
	watchingBurns = true
	libs()
	installPoses()
	local candidates, hums, nextScan = {}, {}, 0
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now >= nextScan then
			nextScan = now + 1
			candidates, hums = {}, {}
			for _, plr in ipairs(Players:GetPlayers()) do
				if plr.Character then
					candidates[#candidates + 1] = plr.Character
					hums[#candidates] = plr.Character:FindFirstChildOfClass("Humanoid") or false
				end
			end
			local ground = workspace:FindFirstChild("TrainingGround")
			if ground then
				for _, h in ipairs(ground:GetDescendants()) do
					if h:IsA("Humanoid") and h.Parent then
						candidates[#candidates + 1] = h.Parent
						hums[#candidates] = h
					end
				end
			end
			-- the flame look asked for but not loaded yet (its modules or meshes came after the first look): tried here,
			-- so it and its body clips are in before the next cast, not during it (flameLibs paces itself: 5 s)
			if not flameSet then look() end
		end
		local book = flameSet and fallen or nil            -- the flame look only: who fell when (Ember Refund's streak)
		for i, m in ipairs(candidates) do
			if m.Parent then
				if not burnControllers[m] and (tonumber(m:GetAttribute("RX_Burning_Stacks")) or 0) > 0 then
					-- the burn wears the wrap of whoever lit it. (2026-10-19, audit GB-02) the server's stamp when it has one
					-- (RX_Burning_By: the source player's UserId, RX_Burning_Src: the ability that lit it -- every burn
					-- source writes them); else the Lash that hit this body in the last second (LashHit below) -- a Lash
					-- from long ago no longer names a burn that a Ring, an Immolate hit or a reaction lit
					local w = nil
					local by, src = m:GetAttribute("RX_Burning_By"), m:GetAttribute("RX_Burning_Src")
					local bp = type(by) == "number" and Players:GetPlayerByUserId(by) or nil
					if bp then
						-- (2026-10-25) any flame-look source, drawn at the Basics' scale (a Ring burn on every body is not the Ultimate)
						w = type(src) == "string" and FLAME_WRAP[src] and bp.Character and wrapOf(bp.Character, "Immolate") or nil
					else
						local e = burnWraps[m]
						w = e and os.clock() - e.At < 1 and e.W or nil
					end
					if w then
						PDraw = PDraw or require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("PyroDraw"))
						PDraw.WithWrap(w, startBurn, m)
					else
						startBurn(m)
					end
				end
				watchMark(m)
				if book then
					local h = hums[i]
					if h then
						if h.Health > 0 then book[m] = nil elseif not book[m] then book[m] = now end
					end
				end
			end
		end
	end)
end

-- every entry that draws a caster's ability runs under that caster's wrap (Default when none): the character is the first
-- argument, the broadcast table's Character, or -- FireFireball -- the first thing its shot excludes (the thrower)
do
	local ENTRY = { Charge = "Fireball", FireFireball = "Fireball", Immolate = "Immolate", EmberRefund = "EmberRefund",
		SteerRing = "RingofFire", LockRing = "RingofFire",
		RingOfFire = "RingofFire", DetonateFlick = "Detonate", DetonateMark = "Detonate", DetonateBlast = "Detonate",
		DetonateFizzle = "Detonate", LashHold = "ScorchingLash", Lash = "ScorchingLash", LashHit = "ScorchingLash" }
	for name, ability in pairs(ENTRY) do
		local orig = PyroFX[name]
		if type(orig) == "function" then
			PyroFX[name] = function(a, b, c, ...)
				local ch = (type(a) == "table" and a.Character) or (name == "FireFireball" and type(c) == "table" and c[1]) or a
				if name == "LashHit" and type(a) == "table" and type(a.Victims) == "table" then
					local w = wrapOf(ch, ability)
					for _, v in ipairs(a.Victims) do
						if typeof(v) == "Instance" then burnWraps[v] = { W = w, At = os.clock() } end
					end
				end
				return withWrap(ch, ability, orig, a, b, c, ...)
			end
		end
	end
	-- the local Pyro's own wrap is built the moment they are Pyro, before the first cast
	task.defer(function()
		local lp = Players.LocalPlayer
		if not lp then return end
		local function warm()
			PDraw = PDraw or require(ReplicatedStorage:WaitForChild("IceMagic"):WaitForChild("PyroDraw"))
			local ch = lp.Character
			if lp:GetAttribute("Element") ~= "Pyro" or not ch then
				PDraw.PinWrap(nil)                       -- (2026-10-25: not Pyro: no set is kept for them)
				return
			end
			for _, a in pairs(ENTRY) do
				local w = wrapOf(ch, a)
				if w then
					PDraw.PinWrap(w.Id)                  -- (2026-10-25: their own wrap's set is never let go)
					PDraw.PrewarmWrap(w)
					prewarmToon(w)
					return
				end
			end
			PDraw.PinWrap(nil)
		end
		lp.AttributeChanged:Connect(function(n)
			if n == "Element" or n == "ElementWrap_Pyro" or n == "ElementSkin_Pyro" then warm() end   -- (2026-10-24: was Skin_*)
		end)
		warm()
	end)
end

return PyroFX

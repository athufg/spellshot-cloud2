--[[
	RadiantFX_Staff  (ReplicatedStorage.IceMagic.RadiantFX_Staff, ModuleScript, CLIENT ONLY)   Radiant Phase 5, 2026-09-29

	The three STAFF pieces' VFX -- LIGHT LANCE, HALO, BENEDICTION -- ported from the owner-confirmed Phase 4 round-3
	Blender scripts (SPELLSHOT_Backup/radiant_rework_2026_09_29/phase4_r3/<piece>/<piece>_r2.py, benediction_r3.py):
	each frame(t) below follows its frame_fn(t) call for call through RadiantDraw (the kit's primitives, the r3 glow).
	Benediction is round 3 WITHOUT the per-pulse arm pull / chest dip (the owner's "twitching"): the palm is read live
	from the (now steady) pose, and the pulses are light only (the ring reaching the palm, the palm flare, the conduit).

	THE DEVIL SKIN (2026-10-13): a caster whose palette is the Devil skin (the effect canvas's Palette.Id == "Devil")
	draws the forged devil forms of radiant_devil_skin_2026_10_12 (kit/devil_look.py, the edits of mk_devil.py and
	mk_halo_devil.py) through RadiantDevilForge, call for call in place of the shapes they replace:
	  Light Lance   the barbed chain gaining links + its spade hook (core, rails, ring glyphs), a thorn star at the
	                muzzle (rosette), horn spikes at the hit (rosette), a pentagram brand burned in from the hit (ring)
	  Halo          horns on the head (rings, dashes, studs; sparkles round the head), bat wings on the same wing
	                tracks (the feathered wings), floor spikes on landing (ring), the devil heal (the gold bond)
	  Benediction   the horned gate, the column rising out of the pit with its spiral chains, embers and surges (the
	                heaven), the torn pit and its cracks to the allies (ground sigil, cracks), ember chains (threads),
	                pact seals (rosettes), a chain racing up the shaft per pulse, embers on each heal (rising ring)
	and no flare has a shock ring. Keys, timings and the pose are the original's. Every other skin never loads the forge
	and draws exactly as before.

	CLOCKS (clip seconds = the Blender scripts' t; RadiantDraw's time scale applies):
	  Lance        clip 0.10 (the press) = the handle's creation (own: the click; others: RadiantLanceOn's T0)
	               -> gather 0.10-0.30, fire 0.30, the ramp is the SERVER's (SetRamp / Aim's ramp), tail on Destroy
	  Halo         clip 0.10 = RadiantHaloCharge's T0 and the lock (1.00) = T0 + Windup (the windup is stretched to
	               the live Windup: 0.9 s once RadiantTuning says 0.9); after RadiantHaloStart clip = 1.00 + (now-T0);
	               the window holds (idle flap, glide while airborne) until RadiantHaloEnd, then fold/drop/unwind
	  Benediction  clip 0.44 (the plant) = RadiantBenedictionStart's T0 (2026-09-30: press + WindUp; the payload's WindUp
	               maps onto the authored 0.12..0.44 lift-and-drive); HELD: a pulse every Every lands on the server's
	               pulse times (T0 + k * Every) for as long as the channel runs; the retract starts at the End, or when
	               no pulse and no End came for Every + EndTimeout (a missed End)

	API (the integrator, from RadiantClient's handlers)
	  Staff.SetAnchors{ Tip = fn(character) -> Vector3?,              the staff tip (world) this frame: the anim module
	                    Palm = fn(character) -> Vector3?, Vector3?,   left palm centre + normal (1P: the viewmodel palm)
	                    Lines = fn(character) -> {BasePart}?,         the staff's engraved line parts (StaffGlow)
	                    FirstPerson = fn(character) -> boolean?,     override the "camera in the head" test
	                    Allies = fn(character, at, radius) -> {Model}? }  Benediction: allies in range BEFORE pulse 1
	  Staff.Prewarm()                                  fills RadiantDraw's shared pool (no hitch on the first click)
	  LIGHT LANCE   (drop-in for RadiantFX.LanceBeam)
	    h = Staff.LanceBeam(character, own, opts?)    opts.T0 = RadiantLanceOn's T0 (others), nil = from now
	    h:Aim(from, to, onBody, ramp?, onSurface?)     every frame, as today (from = eye/head: used only with no Tip)
	    h:SetRamp(r)                                   the server's Ramp 0..1 (RadiantLance)
	    h:Destroy(immediate?)                          the release tail (default) or gone now; h:Release() = tail
	  HALO / BENEDICTION   Staff.Handlers[kind](d) for kind in
	    RadiantHaloCharge, RadiantHaloCancel, RadiantHaloStart, RadiantHaloEnd,
	    RadiantBenedictionStart, RadiantBenedictionPulse, RadiantBenedictionEnd
	  Staff.HaloShare(character, models)               a heal-share flicker (no broadcast carries it yet)
	  Staff.SetGlow(character, key, level|nil)         shared staff-engraving level (max over keys), for the hand pieces
	  Staff.StopAll()                                  this module's effects only
]]

local Players = game:GetService("Players")

local RD = require(script.Parent:WaitForChild("RadiantDraw"))

local Staff = {}

local Config = {
	RootHeight = 3.0,                -- the kit's ROOT_H: HumanoidRootPart centre over the floor
	FloorLift = 0.05,                -- flat ground linework over the floor (the kit's FLOOR_Z 0.012 z-fights in Roblox)
	StaffTipZ = 3.52, StaffButtZ = -1.88,
	Lance = {
		StartAt = 0.10,              -- clip time at creation: 0.10 = the Blender press (0.2 s gather); 0.30 = fire at once
		GlyphTravel = 0.75,          -- ring glyphs cross the beam in at most this long (the demo: 15 studs at 20/s); 0 = 20/s
		RaycastWalls = true,         -- a beam with no body stops at the first wall from the tip (others get no wall point)
		FirstPersonScale = 0.35,     -- the own muzzle (flares, gather glint, rosette) in first person
		AirTaper = 2.5,              -- a beam into the air tapers its far end over this many studs
		RampRate = 12,               -- the shown ramp chases the server's (10 Hz) at this rate, extrapolating between reports
	},
	Halo = {
		HeadLift = 0.75,             -- the halo ring 0.75 over the head top (R_HALO 1.2)
		WingsFirstPerson = false,    -- the own wings are behind the camera
		HornsFirstPerson = false,    -- Devil: the own horns grow out of the head round the camera (a mesh at the near plane)
		MinAir = 0.25,               -- a flight shorter than this is not a landing
		Blend = 0.12,                -- wing pose blend on a state change (idle / rise / glide / land / fold)
	},
	Benediction = {
		SkyHeight = 180,             -- the sky sigil over the caster's floor: the column (~175) is the map-wide signal
		SkyOpenAt = 0.36,            -- Blender 0.22: shifted so the sigil draws on after the (unknowable) cast
		PlantRight = 1.7, PlantFwd = 1.0,   -- the staff's plant point, body frame (benediction keys: plant_body_right_fwd)
		PalmRight = -1.51, PalmFwd = -0.03, -- the raised palm, body frame (keys: heaven.above_palm_xy)
		PalmHeight = 4.56,           -- the palm over the floor at the plant (column widths are measured from it)
		MaxTargets = 4,              -- bonded allies drawn at once
	},
}
Staff.Config = Config

----------------------------------------------------------------------------------------------------
-- shared helpers
----------------------------------------------------------------------------------------------------
local sin, cos, abs, max, min, floor, sqrt, pi, rad = math.sin, math.cos, math.abs, math.max, math.min, math.floor,
	math.sqrt, math.pi, math.rad
local TAU = 2 * pi
local HUGE = math.huge
local UP = RD.UP
local DOWN = -UP
local ZERO = Vector3.new(0, 0, 0)
local clamp, smooth, ramp, env, ease, lerp = RD.clamp, RD.smooth, RD.ramp, RD.env, RD.ease, RD.lerp

local function up01(t, t0, t1)
	return clamp((t - t0) / max(t1 - t0, 1e-6), 0, 1)
end

local tuning = nil
local function tnum(section, key, default)
	if tuning == nil then
		tuning = false
		local m = script.Parent:FindFirstChild("RadiantTuning")
		if m then
			local ok, t = pcall(require, m)
			if ok and type(t) == "table" then tuning = t end
		end
	end
	local s = tuning and tuning[section]
	local v = type(s) == "table" and s[key] or nil
	return type(v) == "number" and v or default
end

local anchors = {}
function Staff.SetAnchors(fns)
	anchors = type(fns) == "table" and fns or {}
end

local function call(fn, ...)
	if fn then
		local ok, a, b = pcall(fn, ...)
		if ok then return a, b end
	end
	return nil, nil
end

local function part(c, name)
	local p = c and c:FindFirstChild(name)
	return (p and p:IsA("BasePart")) and p or nil
end

local function chestOf(m)
	local p = part(m, "UpperTorso") or part(m, "HumanoidRootPart") or (m and m.PrimaryPart)
	return p and p.Position or nil
end

local function fxFolder()
	return workspace:FindFirstChild(RD.Config.FXFolderName)
end

local function rayParamsFor(c)
	local rp = RaycastParams.new()
	rp.FilterType = Enum.RaycastFilterType.Exclude
	local list = { c }
	local cam = workspace.CurrentCamera
	if cam then list[#list + 1] = cam end
	local f = fxFolder()
	if f then list[#list + 1] = f end
	rp.FilterDescendantsInstances = list
	return rp
end

local function floorBelow(p, rp, depth)
	local res = workspace:Raycast(p, Vector3.new(0, -(depth or 30), 0), rp)
	return res and res.Position.Y or nil
end

-- the camera, read once per frame (the kit's _cam_dir)
local camP = Vector3.new(0, 0, 10)
local function camRefresh()
	local cam = workspace.CurrentCamera
	if cam then camP = cam.CFrame.Position end
end
local function camDir(p)
	local d = camP - p
	local m = d.Magnitude
	if m > 1e-6 then return d / m end
	return Vector3.new(0, 0, -1)
end

local function firstPerson(c)
	if anchors.FirstPerson then
		local v = call(anchors.FirstPerson, c)
		if v ~= nil then return v == true end
	end
	local lp = Players.LocalPlayer
	if not lp or c ~= lp.Character then return false end
	local head, cam = part(c, "Head"), workspace.CurrentCamera
	return head ~= nil and cam ~= nil and (cam.CFrame.Position - head.Position).Magnitude < 2.5
end

--- the root's yaw frame (upright, facing the root's flat look)
local function yawCF(root)
	local cf = root.CFrame
	local lv = cf.LookVector
	local flat = Vector3.new(lv.X, 0, lv.Z)
	if flat.Magnitude < 1e-4 then flat = Vector3.new(0, 0, -1) end
	return CFrame.lookAt(cf.Position, cf.Position + flat.Unit)
end

--- the kit's CARRY hold (right_hand, CARRY_AXIS (0.05, 1, 0.14) body frame): the fallback staff tip
local function carryTip(c)
	local root = part(c, "HumanoidRootPart")
	if not root then return nil end
	local hand = part(c, "RightHand")
	local cf = root.CFrame
	if not hand then return cf.Position + cf.UpVector * 2.4 + cf.RightVector * 0.9 end
	local grip = hand.CFrame:PointToWorldSpace(Vector3.new(0, -0.05, 0))
	local ax = (cf.RightVector * 0.05 + cf.UpVector * 1.0 + cf.LookVector * 0.14).Unit
	return grip + ax * Config.StaffTipZ
end

local function anchorTip(c)
	local p = call(anchors.Tip, c)
	return typeof(p) == "Vector3" and p or nil
end

local function palmOf(c)
	local p, n = call(anchors.Palm, c)
	if typeof(p) == "Vector3" then
		return p, (typeof(n) == "Vector3" and n.Magnitude > 1e-6) and n.Unit or UP
	end
	local hand = part(c, "LeftHand")
	if hand then return RD.Palm(hand.CFrame) end
	return nil, nil
end

-- the staff's skin: its caster's Light Lance skin (SkinCatalog; nil = Default), the staff being the M1's own
local SkinCatalog = nil
local function skinCatalog()
	if SkinCatalog == nil then
		local m = game:GetService("ReplicatedStorage"):FindFirstChild("Spellshot")
		m = m and m:FindFirstChild("SkinCatalog")
		local ok, mod = pcall(function() return m and require(m) end)
		SkinCatalog = (ok and mod) or false
	end
	return SkinCatalog or nil
end

local function staffPalette(c)
	if not skinCatalog() then return nil end
	local plr = game:GetService("Players"):GetPlayerFromCharacter(c)
	return plr and SkinCatalog.Resolve("Radiant", "LightLance", SkinCatalog.Chosen(plr, "LightLance")) or nil
end

-- THE DEVIL SKIN: the forge (RadiantDevilForge) is required on the first Devil effect only; each Devil effect owns a
-- forge scope (h.Dv) opened round its frame, so a form it does not draw in a frame is hidden. No scope = as before.
local Forge = nil
local devilWarm = {}
local function isDevil(pal)
	return type(pal) == "table" and pal.Id == "Devil"
end

local function devilForge()
	if Forge == nil then
		local m = script.Parent:FindFirstChild("RadiantDevilForge")
		local ok, mod = pcall(function() return m and require(m) end)
		Forge = (ok and type(mod) == "table") and mod or false
		if not Forge then warn("[RadiantFX_Staff] RadiantDevilForge unavailable: the Devil skin draws its plain shapes") end
	end
	return Forge or nil
end

--- the piece's forms built ahead (once per client per piece: its first Devil cast, or the own choice at Prewarm)
local function devilPrewarm(piece)
	if devilWarm[piece] or not devilForge() then return end
	devilWarm[piece] = true
	Forge.PrewarmPiece(piece)
end

--- a forge scope for an effect drawn with palette `pal` (its canvas's), or nil when the skin is not Devil
local function devilScope(pal, piece)
	if not isDevil(pal) or not devilForge() or not Forge.IsDevil(pal) then return nil end
	devilPrewarm(piece)
	return Forge.Scope(piece)
end

--- frame(h, cv, t, dt) with the effect's Devil scope open round it (Begin / End); no scope = the frame alone
local function devilFrame(h, frame, cv, t, dt)
	local sc = h.Dv
	if not sc then return frame(h, cv, t, dt) end
	sc:Begin(cv)
	local keep = frame(h, cv, t, dt)
	sc:End()
	return keep
end

-- devil_look's flare(): no shock ring on any flare. A flare's options as they are (no scope), or a copy with
-- shock = false (one per options table, refreshed each call so the frame's varying fields carry over)
local NOSHOCK = {}
local function noShock(o, dv)
	if not dv then return o end
	local d = NOSHOCK[o]
	if not d then
		d = {}
		NOSHOCK[o] = d
	end
	for k, v in pairs(o) do d[k] = v end
	d.shock = false
	return d
end

-- the staff engraving: every effect (and the hand pieces) asks for a level; the max wins
local glowReq = setmetatable({}, { __mode = "k" })
function Staff.SetGlow(c, key, level)
	if not c then return end
	local g = glowReq[c]
	if not g then
		g = {}
		glowReq[c] = g
	end
	g[key] = level
	local lines = call(anchors.Lines, c)
	if type(lines) ~= "table" then return end
	local m = 0
	for _, v in pairs(g) do
		if v > m then m = v end
	end
	RD.StaffGlow(lines, m, staffPalette(c))
end

--- the kit's track(): piecewise eased by the DESTINATION key's style ("InOut" default, "Linear", "In", ease styles)
local function track(keys, t)
	if t <= keys[1][1] then return keys[1][2] end
	for i = 2, #keys do
		local b = keys[i]
		if t <= b[1] then
			local a = keys[i - 1]
			local u = clamp((t - a[1]) / max(b[1] - a[1], 1e-6), 0, 1)
			local st = b[3] or "InOut"
			if st == "InOut" then
				u = 0.5 - 0.5 * cos(pi * u)
			elseif st == "In" then
				u = u * u
			elseif st ~= "Linear" then
				u = ease(st, u)
			end
			return a[2] + (b[2] - a[2]) * u
		end
	end
	return keys[#keys][2]
end

--- the kit's _cut into `out`: the first fraction u (by length) of a polyline
local function cutInto(src, n, u, out)
	for k = #out, 1, -1 do out[k] = nil end
	if u <= 0 or n < 1 then return out end
	out[1] = src[1]
	if u >= 1 then
		for i = 2, n do out[i] = src[i] end
		return out
	end
	local tot = 0
	for i = 2, n do tot += (src[i] - src[i - 1]).Magnitude end
	local goal, acc = tot * u, 0
	for i = 2, n do
		local l = (src[i] - src[i - 1]).Magnitude
		if acc + l < goal then
			out[#out + 1] = src[i]
			acc += l
		else
			out[#out + 1] = src[i - 1]:Lerp(src[i], (goal - acc) / max(l, 1e-9))
			break
		end
	end
	return out
end

local live = {}                        -- this module's RadiantDraw handles

local function play(name, fn, opts)
	local e = RD.Play(name, fn, opts)
	live[e] = true
	return e
end

function Staff.StopAll()
	for e in pairs(live) do e:Stop() end
	table.clear(live)
end

-- the shared pool, filled before the first cast (review fix 2026-09-29): sized to the peak the pool reached in Play
-- (Lance, then Halo: 209 spans; Benediction: ~276 spans; sprites and lights never passed 96 / 6; RadiantDraw's
-- PoolKeep.Spans raised to 288 to keep them), and made a few slots per frame so filling it never costs one long frame.
-- RadiantClient calls this only once some player's Element is Radiant.
--- the Devil skin's staff forms built ahead, every piece (RadiantClient: when the local player puts the skin on)
function Staff.PrewarmDevil()
	for _, piece in ipairs({ "LightLance", "Halo", "Benediction" }) do devilPrewarm(piece) end
end

local PREWARM = { Spans = 280, Sprites = 96, Lights = 6, StepSpans = 24, StepSprites = 12, StepLights = 2 }
local prewarmed = false
function Staff.Prewarm()
	if prewarmed then return end
	prewarmed = true
	-- the Devil skin's forms too, for the pieces the local player wears it on (another caster's: on their first cast)
	local lp, S = Players.LocalPlayer, skinCatalog()
	if lp and S then
		for _, piece in ipairs({ "LightLance", "Halo", "Benediction" }) do
			if isDevil(S.Resolve("Radiant", piece, S.Chosen(lp, piece))) then devilPrewarm(piece) end
		end
	end
	task.spawn(function()
		local held = {}
		local s, g, l = PREWARM.Spans, PREWARM.Sprites, PREWARM.Lights
		local hb = game:GetService("RunService").Heartbeat
		while s > 0 or g > 0 or l > 0 do
			local a, b, k = min(s, PREWARM.StepSpans), min(g, PREWARM.StepSprites), min(l, PREWARM.StepLights)
			held[#held + 1] = RD.new("RadiantStaffPrewarm", { Spans = a, Sprites = b, Lights = k })
			s, g, l = s - a, g - b, l - k
			hb:Wait()
		end
		for _, cv in ipairs(held) do cv:Destroy() end
	end)
end

----------------------------------------------------------------------------------------------------
-- LIGHT LANCE   (light_lance_r2.py: frame(t); r3 glow)
----------------------------------------------------------------------------------------------------
local LL_PRESS, LL_FIRE, LL_DRAW, LL_RAIL, LL_RET, LL_SPEED = 0.10, 0.30, 0.07, 0.45, 0.10, 20.0

local Lance = {}
Lance.__index = Lance

function Lance:Aim(from, to, onBody, ramp_, onSurface)
	if self.Rel or self.WantRel then return end
	if typeof(from) == "Vector3" then self.From = from end
	if typeof(to) == "Vector3" then self.To = to end
	self.OnBody = onBody == true
	self.OnSurface = onSurface == true
	if type(ramp_) == "number" then self:SetRamp(ramp_) end
end

function Lance:SetRamp(r)
	r = clamp(r, 0, 1)
	if r ~= self.RT then
		self.RT, self.RTAt = r, self.T
	end
end

function Lance:Destroy(immediate)
	if immediate then
		self.Effect:Stop()
		return
	end
	self.WantRel = true
end

function Lance:Release()
	self:Destroy(false)
end

local function beamLevel(r)
	return 0.5 + 0.5 * r ^ 1.2
end

local O_RING_GLYPH = { a0 = 0, ticks = 4, long_every = 1, tick_len = { 0, 0 }, rigid = true, tag = "lance" }
local O_SHIM = { n = 5, seed = 21, level = 1, size = 0.1, life = 0.45, t0 = 0, t1 = HUGE, drift = ZERO, region = nil,
	spin = 1.5, tag = "shimmer" }
local SHIM_WAVES = { { 5, 21 }, { 5, 22 }, { 6, 23 } }

-- review fix 2026-09-29: the frame's option tables, hoisted (RadiantDraw reads options and never keeps them); the
-- changing fields are written before each call, so a Light Lance frame allocates no option tables
local LO = {
	AURA = { light = true, sparkle = true, tag = "staff" },
	GATHER = { radius = 1.05, n = 10, level = 1.0, size = 0.065, glint_size = 0, t = 0, tag = "gather" },
	CORE = { w = 0, taper = { 0, 0 }, lo = { 0, 0 }, tag = "lance" },
	RAIL = { w = 0, taper = { 0, 0 }, lo = { 0, 0 }, tag = "lance" },
	MFL1 = { size = 1.0, level = 1.0, rot = 0.2, tag = "muzzle" },
	MFL2 = { size = 0.8, level = 1.0, rot = 0.6, shock = false, tag = "muzzle" },
	MROS = { spokes = 8, phase = 0, u = 0, grow = true, tag = "muzzle" },
	HFL1 = { size = 1.15, level = 1.0, rot = 0.1, tag = "hit" },
	HFL2 = { size = 1.6, level = 1.0, rot = 0.5, tag = "hit" },
	HFL3 = { size = 0.75, level = 0.9, rot = 0.3, tag = "hit" },
	HROS = { spokes = 8, phase = 0, u = 0, grow = true, tag = "hit" },
	HRING = { a0 = 0, u = 0, ticks = 12, long_every = 3, rigid = false, tag = "hit" },
	HRAYS = { n = 9, r0 = 0.34, length = 0, width = 0, level = 0, seed = 5, t = 0, v = 0, tag = "hit" },
	HSP1 = { n = 6, seed = 31, level = 1.0, size = 0, life = 0.5, t0 = 0, t1 = 0, drift = UP * 0.5, region = "shell",
		tag = "hit" },
	HSP2 = { n = 8, seed = 32, level = 1.0, size = 0.13, life = 0.55, t0 = 0, t1 = 0, drift = UP * 0.45, region = "shell",
		tag = "hit" },
	HMOTE = { n = 6, seed = 33, level = 0.9, size = 0.06, rise = 1.1, life = 0.75, t0 = 0, t1 = 0, tag = "hit" },
	LIGHT = { tag = "light" },
	-- the Devil skin's (mk_devil.py light_lance)
	MTHORN = { rot = 0, n_pts = 8, tag = "muzzle" },
	BRAND = { u = 0, w = 0, tag = "hit" },
}

local function lanceFrame(h, cv, t, dt)
	h.T = t
	local c = h.C
	local dv = h.Dv or nil
	camRefresh()
	-- release: the button came up (Destroy), or the caster is gone
	if not h.Rel and (h.WantRel or not (c and c.Parent)) then
		h.Rel = t
		h.RelBody = h.HitOn ~= nil and h.HitEnd == nil and h.Kind == "body"
		if h.HitOn and not h.HitEnd then h.HitEnd, h.HitRel = t, true end
	end
	local rel = h.Rel
	if rel and t > rel + ((rel < LL_FIRE) and 0.45 or 1.25) then return false end
	local fp = h.Own and firstPerson(c)
	local k1 = fp and Config.Lance.FirstPersonScale or 1

	-- where: the staff tip and the far end (frozen once released)
	local tip, hit
	if rel then
		tip, hit = h.LTip, h.LHit
	else
		tip = anchorTip(c)
		if not tip then                                          -- no anim module: about where the two-handed muzzle is
			local cam = workspace.CurrentCamera
			local head, root = part(c, "Head"), part(c, "HumanoidRootPart")
			if fp and cam then
				local cf = cam.CFrame
				tip = cf.Position + cf.LookVector * 2.2 + cf.RightVector * 0.7 - cf.UpVector * 0.6
			elseif head and root then
				tip = head.Position + yawCF(root).LookVector * 1.2 - UP * 0.4
			else
				tip = h.From
			end
		end
		hit = h.To
		local kind = nil
		if hit and tip then
			if h.OnBody then
				kind = "body"
			elseif h.OnSurface then
				kind = "surface"
			elseif Config.Lance.RaycastWalls then
				h.Ray = h.Ray or rayParamsFor(c)
				local res = workspace:Raycast(tip, hit - tip, h.Ray)
				if res then
					hit, kind = res.Position, "surface"
				end
			end
		end
		h.Kind = kind
		h.LTip, h.LHit = tip, hit
	end
	if not tip then return true end

	-- the ramp: the server's, extrapolated between its reports, eased; frozen after release
	if not rel then
		local goal = h.RT
		if h.RT > 0 and h.Kind == "body" then goal = min(1, h.RT + max(0, t - h.RTAt) / tnum("LightLance", "RampTime", 2.0)) end
		h.R += (goal - h.R) * min(1, dt * Config.Lance.RampRate)
	end
	local r = h.R

	-- contact bookkeeping (the kit's T_HIT / T_FULL become events)
	if not rel and hit and t >= LL_FIRE + LL_DRAW then
		if h.Kind then
			if not h.HitOn or h.HitEnd or (h.HitP and (hit - h.HitP).Magnitude > 4) or h.Kind ~= h.HitKind then
				h.HitOn, h.HitEnd, h.HitRel, h.Full, h.HitKind = t, nil, false, nil, h.Kind
			end
			h.HitP = hit
		elseif h.HitOn and not h.HitEnd then
			h.HitEnd = t
		end
		if h.HitOn and not h.HitEnd and h.HitKind == "body" and r >= 0.995 then
			h.Full = h.Full or t
		elseif r < 0.5 then
			h.Full = nil
		end
		-- the shimmer's 2nd / 3rd waves: the ramp passing 0.4 / 0.75 (the demo's T_FIRE + 0.8 / + 1.5)
		for w = 2, 3 do
			local th = (w == 2) and 0.4 or 0.75
			if r >= th and (not h.W[w] or h.WE[w]) then
				h.W[w], h.WE[w] = t, nil
			elseif h.W[w] and not h.WE[w] and r < th - 0.15 then
				h.WE[w] = t
			end
		end
	end

	-- the staff: glow + aura, the gather
	local g = 0.5 * ramp(t, LL_PRESS, LL_FIRE - LL_PRESS)
	if t >= LL_FIRE then g = beamLevel(r) end
	g *= 1 - ramp(t, rel or HUGE, 0.38)
	Staff.SetGlow(c, h, g)
	cv:Tag("staff")
	LO.AURA.sparkle = t < LL_FIRE + 0.15
	cv:StaffAura(tip, g, t, LO.AURA)
	if LL_PRESS < t and t < LL_FIRE + 0.25 and not (rel and rel < LL_FIRE) then
		LO.GATHER.glint_size, LO.GATHER.t = 0.46 * (1 - ramp(t, LL_FIRE, 0.22)) * k1, t
		cv:Gather(tip, clamp((t - LL_PRESS) / (LL_FIRE - LL_PRESS), 0, 1), LO.GATHER)
	end
	if t < LL_FIRE or not hit or (rel and rel < LL_FIRE) then return true end

	local D = hit - tip
	local L = D.Magnitude
	if L < 0.3 then return true end
	local d = D / L
	local side = UP - d * d.Y
	side = (side.Magnitude > 1e-3) and side.Unit or Vector3.new(1, 0, 0)
	local side2 = d:Cross(side).Unit
	local lev = beamLevel(r)
	local a = L * ramp(t, rel or HUGE, LL_RET, "Linear")        -- the back end (runs to the target on release)
	local b = L * ramp(t, LL_FIRE, LL_DRAW, "Linear")           -- the front end (draws on)
	h.D, h.L, h.Side, h.Side2 = d, L, side, side2

	-- the beam: core in its sleeve, rails, travelling ring glyphs (Devil: devil_chain -- a taut barbed chain from the
	-- tip gaining links with the ramp, its spade hook at the target; a beam into the air has no target, so no hook)
	cv:Tag("lance")
	if dv then
		Forge.DevilChain(dv, tip, d, a, b, h.Kind and L or L + 1, r, t)
	elseif b - a > 1e-3 then
		local tail = (a > 0) and min(0.9, (b - a) * 0.35) or 0
		local head, loH = 0, 0.3
		if b < L - 1e-3 then
			head = 0.35
		elseif not h.Kind and not rel then
			head, loH = min(Config.Lance.AirTaper, (b - a) * 0.3), 0     -- into the air: no hit, a soft end
		end
		h.P3[1], h.P3[2], h.P3[3] = tip + d * a, tip + d * (a + (b - a) * 0.5), tip + d * b
		LO.CORE.w = 0.05 + 0.07 * r
		LO.CORE.taper[1], LO.CORE.taper[2], LO.CORE.lo[2] = tail, head, loH
		cv:Stroke(h.P3, lev, LO.CORE)
		local ur = ramp(t, LL_FIRE + LL_RAIL, 0.22)
		if ur > 0 then
			local off = 0.13 + 0.11 * r
			local e = min(b, (L - 0.25) * ur)
			local a2 = max(a, 0.12)
			if e - a2 > 0.05 then
				local tp = min(0.5, (e - a2) * 0.3)
				for sg = 1, -1, -2 do
					h.P2[1], h.P2[2] = tip + d * a2 + side * (off * sg), tip + d * e + side * (off * sg)
					LO.RAIL.w = RD.lw(lev) * (0.8 + 0.4 * r)
					LO.RAIL.taper[1], LO.RAIL.taper[2] = tp, tp
					cv:Stroke(h.P2, lev * 0.92, LO.RAIL)
				end
			end
		end
	end
	-- glyph emission: every 0.40 s at the start, every 0.10 s at full ramp (until the release; none for the chain)
	if not rel and not dv then
		while h.NextEmit <= t do
			h.EN += 1
			h.ET[h.EN], h.ER[h.EN] = h.NextEmit, r
			h.NextEmit += 0.40 - 0.30 * r
		end
	end
	local speed = LL_SPEED
	if Config.Lance.GlyphTravel > 0 then speed = max(speed, L / Config.Lance.GlyphTravel) end
	local i = h.EHead
	while i <= h.EN do
		local age = t - h.ET[i]
		if age < 0 then break end
		local dist = age * speed
		if dist > L + 1 and i == h.EHead then
			h.EHead = i + 1
		elseif dist >= a and dist <= L - 0.35 then
			local s = smooth(dist / 0.9) * smooth((L - 0.35 - dist) / 0.9) * smooth((dist - a) / 0.6)
			if s >= 0.05 then
				O_RING_GLYPH.a0 = age * 7.0
				O_RING_GLYPH.tick_len[1], O_RING_GLYPH.tick_len[2] = 0.07 * s, 0.12 * s
				cv:Ring(tip + d * dist, (0.20 + 0.20 * h.ER[i]) * s, d, lev, O_RING_GLYPH)
			end
		end
		i += 1
	end
	if h.EHead > 48 then                                        -- compact the emit list
		local n = 0
		for j = h.EHead, h.EN do
			n += 1
			h.ET[n], h.ER[n] = h.ET[j], h.ER[j]
		end
		for j = n + 1, h.EN do h.ET[j], h.ER[j] = nil, nil end
		h.EN, h.EHead = n, 1
	end

	-- the shimmer: travelling glints along the beam, thickening in three waves
	h.ShimLo = a / L + 0.02
	O_SHIM.level, O_SHIM.size, O_SHIM.drift, O_SHIM.region = min(1, 0.65 + 0.35 * r), 0.07 + 0.07 * r, d * 5.0, h.Region
	for w = 1, 3 do
		local t0 = (w == 1) and (LL_FIRE + LL_DRAW) or h.W[w]
		if t0 then
			O_SHIM.n, O_SHIM.seed = SHIM_WAVES[w][1], SHIM_WAVES[w][2]
			O_SHIM.t0 = t0
			O_SHIM.t1 = min(rel or HUGE, (w > 1 and h.WE[w]) or HUGE)
			cv:Sparkles(tip, 0.0, t, O_SHIM)
		end
	end

	-- the muzzle (Devil: a thorn star, not the rosette)
	cv:Tag("muzzle")
	local mp = tip + d * 0.05
	LO.MFL1.size = 1.0 * k1
	cv:Flare(mp, (t - LL_FIRE) / 0.42, noShock(LO.MFL1, dv))
	if h.Full then
		LO.MFL2.size = 0.8 * k1
		cv:Flare(mp, (t - h.Full) / 0.45, LO.MFL2)
	end
	local um = ramp(t, LL_FIRE, 0.14) * (1 - ramp(t, rel or HUGE, 0.2))
	if um > 0.02 then
		if dv then
			LO.MTHORN.rot = t * 3.0
			Forge.ThornStar(cv, tip + d * 0.14, d, (0.18 + 0.12 * r) * um * (fp and 0.6 or 1), lev, LO.MTHORN)
		else
			LO.MROS.phase, LO.MROS.u = t * 3.0, um
			cv:Rosette(tip + d * 0.14, d, (0.15 + 0.11 * r) * (fp and 0.6 or 1), lev, LO.MROS)
		end
	end

	-- the target: flare on arrival, the turning mark, rays, glints, the full-ramp payoff, the closing flare, motes
	cv:Tag("hit")
	local pay = 0
	if h.HitOn then
		local hp = h.HitP
		local body = h.HitKind == "body"
		local fade0 = (h.HitEnd or HUGE) + (h.HitRel and LL_RET or 0)
		LO.HFL1.size = body and 1.15 or 0.7
		cv:Flare(hp - d * 0.1, (t - h.HitOn) / 0.45, noShock(LO.HFL1, dv))
		if h.Full then
			cv:Flare(hp - d * 0.1, (t - h.Full) / 0.55, noShock(LO.HFL2, dv))
			pay = env(t, h.Full - 0.02, h.Full + 0.7, 0.06, 0.5)
		end
		if h.RelBody then
			cv:Flare(hp - d * 0.1, (t - (rel + LL_RET)) / 0.40, noShock(LO.HFL3, dv))
		end
		local uh = ramp(t, h.HitOn, 0.10) * (1 - ramp(t, fade0, 0.16))
		if uh > 0.02 then
			if dv then                                           -- hit_horns: horn spikes erupt from the target
				Forge.HitHorns(dv, hp, d, uh, h.Full and ramp(t, h.Full, 0.2) or 0)
			else
				LO.HROS.phase, LO.HROS.u = t * 2.5, uh
				cv:Rosette(hp - d * 0.02, d, (0.30 + 0.08 * r) * (body and 1 or 0.7), lev, LO.HROS)
			end
		end
		if body and dv then                                     -- the brand: burned in from the hit (the payoff ring's place)
			local ub = ramp(t, h.HitOn, 0.2) * (1 - ramp(t, fade0, 0.3))
			if ub > 0.02 then
				LO.BRAND.u, LO.BRAND.w = ub, 0.07 + 0.05 * r
				Forge.Pentagram(cv, hp - d * 0.06, d, 0.5 + 0.18 * r, 0.45 + 0.55 * r, LO.BRAND)
			end
		end
		if body then
			if h.Full and not dv then
				local uo = ramp(t, h.Full, 0.18) * (1 - ramp(t, min(rel or HUGE, h.HitEnd or HUGE), 0.14))
				if uo > 0.02 then
					LO.HRING.a0, LO.HRING.u, LO.HRING.rigid = -t * 1.5, uo, uo >= 0.999
					cv:Ring(hp - d * 0.03, 0.66, d, 1.0, LO.HRING)
				end
			end
			local hc = hp + camDir(hp) * 0.55                    -- rays centred in front of the body (never hidden by it)
			LO.HRAYS.length, LO.HRAYS.width = 0.55 + 0.75 * r + 0.45 * pay, 0.12 + 0.06 * r
			LO.HRAYS.level, LO.HRAYS.t, LO.HRAYS.v = min(1, 0.62 + 0.38 * r), t, ramp(t, (h.HitEnd or HUGE) + 0.04, 0.32)
			cv:HolyRays(hc, ramp(t, h.HitOn, 0.30, "Linear"), LO.HRAYS)
			LO.HSP1.size, LO.HSP1.t0, LO.HSP1.t1 = 0.06 + 0.06 * r, h.HitOn, h.HitEnd or HUGE
			cv:Sparkles(hp - d * 0.2, 0.5, t, LO.HSP1)
			if h.Full then
				LO.HSP2.t0, LO.HSP2.t1 = h.Full, h.Full + 0.12
				cv:Sparkles(hp - d * 0.2, 0.9, t, LO.HSP2)
			end
			if h.RelBody then
				LO.HMOTE.t0, LO.HMOTE.t1 = rel + 0.05, rel + 0.3
				cv:MoteField(hp - d * 0.4 - UP * 1.0, 0.5, t, LO.HMOTE)
			end
			cv:Tag("light")
			local hl = (0.35 + 0.75 * r + 0.6 * pay) * env(t, h.HitOn - 0.03, (h.HitEnd or HUGE) + 0.5, 0.08, 0.42)
			cv:LightPool(hp - d * 0.55, hl, LO.LIGHT)
		end
		if h.HitEnd and t > h.HitEnd + 0.9 and not rel then h.HitOn = nil end
	end
	cv:Tag("light")
	local ml = (0.25 + 0.45 * r) * env(t, LL_FIRE, (rel or HUGE) + 0.2, 0.1, 0.3)
	cv:LightPool(tip + d * (L * 0.5) - UP * 0.6, ml, LO.LIGHT)
	return true
end

--- the Light Lance beam (drop-in for RadiantFX.LanceBeam(character, own)): opts.T0 = the server's T0
function Staff.LanceBeam(character, own, opts)
	opts = type(opts) == "table" and opts or {}
	local h = setmetatable({
		C = character, Own = own == true, T = Config.Lance.StartAt, From = nil, To = nil, OnBody = false,
		OnSurface = false, RT = 0, RTAt = 0, R = 0, W = {}, WE = {}, ET = {}, ER = {}, EN = 0, EHead = 1,
		NextEmit = LL_FIRE + 0.04, P2 = {}, P3 = {}, D = UP, L = 1, Side = UP, Side2 = UP, ShimLo = 0.02,
	}, Lance)
	h.Region = function(rnd)                                   -- the kit's along(rng, lo): a point round the beam
		local f = h.ShimLo + (0.94 - h.ShimLo) * rnd()
		local ang = rnd() * TAU
		local rr = 0.04 + (0.08 + 0.14 * h.R) * rnd()
		return h.D * (h.L * f) + (h.Side * cos(ang) + h.Side2 * sin(ang)) * rr
	end
	local clock = RD.Clock(type(opts.T0) == "number" and opts.T0 or nil, Config.Lance.StartAt)
	h.Effect = play("RadiantLance", function(cv, t, dt)
		return devilFrame(h, lanceFrame, cv, t, dt)
	end, {
		Clock = clock, MaxLife = HUGE, Prewarm = nil,
		OnEnd = function(e)
			live[e] = nil
			Staff.SetGlow(character, h, nil)
			if h.Dv then h.Dv:Destroy() end
		end,
	})
	h.Dv = devilScope(h.Effect.Canvas.Palette, "LightLance")
	return h
end
Staff.Lance = Staff.LanceBeam

----------------------------------------------------------------------------------------------------
-- HALO   (halo_r2.py: frame(t); r3 glow)
----------------------------------------------------------------------------------------------------
local H_KEY, H_UP, H_SPIN0, H_WIDE, H_LOCK = 0.10, 0.24, 0.20, 0.54, 1.00
local H_WING0, H_WING1 = 1.02, 1.50
local H_APEX, H_LAND = 2.10 + 50 / 98.1, 2.10 + 100 / 98.1   -- the demo jump's keys (the wing tracks are timed on it)
local H_END, H_FOLD1, H_DROP0, H_DROP1, H_UNW0, H_UNW1 = 3.95, 4.42, 4.18, 4.46, 4.48, 4.74
local R_HALO = 1.20
local IDLE_TAU, GLIDE_TAU, RISE_TAU0 = 1.50, H_APEX + 0.14, 2.08

-- the staff tip at the two holds (halo_r2 hold_targets: grip + axis * tip_z), body frame (right, fwd, over the floor)
local function holdTip(lat, fwd, zr, theta, phi)
	local th, ph, L = rad(theta), rad(phi), Config.StaffTipZ
	return { lat - sin(th) * cos(ph) * L, fwd + sin(ph) * L, zr + cos(th) * cos(ph) * L }
end
local TIP_IN = holdTip(0.25, 0.35, 2.85, 18.0, 5.0)
local TIP_OUT = holdTip(0.55, 0.45, 3.0, 55.0, 8.0)          -- = the lock: radius 2.49 at 5.00 (keys: 2.487, 5.003)
local H_LOCK_Z = TIP_OUT[3]

local function spinDeg(t)
	if t <= H_SPIN0 then return 0 end
	if t <= H_WIDE then return 360 * (t - H_SPIN0) / (H_WIDE - H_SPIN0) end
	return 360 + 360 * min(1, (t - H_WIDE) / (H_LOCK - H_WIDE))
end

local function spinInv(deg)
	if deg <= 360 then return H_SPIN0 + (H_WIDE - H_SPIN0) * deg / 360 end
	return H_WIDE + (H_LOCK - H_WIDE) * (deg - 360) / 360
end

--- the windup's tip path round the caster (the Blender tip path: the hold lerped IN -> OUT under the 720 deg spin)
local function spiralTip(yaw, tt)
	local k = clamp((tt - H_UP) / (H_WIDE - H_UP), 0, 1)
	local r = TIP_IN[1] + (TIP_OUT[1] - TIP_IN[1]) * k
	local f = TIP_IN[2] + (TIP_OUT[2] - TIP_IN[2]) * k
	local z = TIP_IN[3] + (TIP_OUT[3] - TIP_IN[3]) * k
	local a = rad(spinDeg(tt))
	local ca, sa = cos(a), sin(a)
	local x, zz = r, -f                                          -- Roblox body local: +X right, -Z forward
	return yaw:PointToWorldSpace(Vector3.new(x * ca + zz * sa, z - Config.RootHeight, -x * sa + zz * ca))
end

-- the wings (halo keys.json notes.wings; the tracks are the demo's, the jump part is replayed per flight)
local S_W, ROW = 0.8, 0.42
local ARM = { { 0.0, 0.0 }, { 0.30, 0.55 }, { 0.80, 1.05 }, { 1.45, 1.35 }, { 2.15, 1.42 }, { 2.75, 1.25 }, { 3.15, 0.95 } }
local FEA = { { 0.22, -96.0, 0.95 }, { 0.34, -88.0, 1.20 }, { 0.46, -78.0, 1.45 }, { 0.58, -66.0, 1.70 },
	{ 0.70, -52.0, 1.95 }, { 0.82, -38.0, 2.10 }, { 0.93, -24.0, 2.15 } }
local W_FEA = { 0.10, 0.11, 0.12, 0.13, 0.14, 0.14, 0.14 }
local FEA_MEAN = 0
for _, f in ipairs(FEA) do FEA_MEAN += f[2] / #FEA end
local ALPHA = { { 0.0, -35.0 }, { 1.02, -35.0 }, { 1.46, 10.0, "Back" }, { 1.95, 10.0 }, { 2.08, 28.0 }, { 2.26, -24.0 },
	{ 2.43, 24.0 }, { 2.609684, -4.0 }, { 2.749684, 6.0 }, { 3.019368, 6.0 }, { 3.159368, 22.0 }, { 3.479368, 10.0 },
	{ 3.95, 10.0 }, { 4.21, -40.0 }, { 5.0, -40.0 } }
local SPREAD = { { 0.0, 0.3 }, { 1.02, 0.3 }, { 1.48, 1.0, "Back" }, { 2.08, 0.95 }, { 2.26, 1.08 }, { 2.43, 0.75 },
	{ 2.609684, 1.05 }, { 2.749684, 1.15 }, { 3.019368, 1.15 }, { 3.219368, 1.0 }, { 3.95, 1.0 }, { 4.2, 0.3 }, { 5.0, 0.3 } }
local FXS = { { 0.0, 0.35 }, { 1.02, 0.35 }, { 1.44, 1.0, "Back" }, { 2.26, 1.0 }, { 2.43, 0.82 }, { 2.609684, 1.0 },
	{ 2.749684, 1.06 }, { 3.019368, 1.06 }, { 3.219368, 1.0 }, { 3.95, 1.0 }, { 4.2, 0.35 }, { 5.0, 0.35 } }
local BETA = { { 0.0, 65.0 }, { 1.02, 65.0 }, { 1.44, 20.0 }, { 2.08, 24.0 }, { 2.26, 6.0 }, { 2.43, 32.0 },
	{ 2.609684, 12.0 }, { 2.749684, 10.0 }, { 3.019368, 10.0 }, { 3.219368, 20.0 }, { 3.95, 20.0 }, { 4.23, 68.0 },
	{ 5.0, 68.0 } }
local WLEV = { { 0.0, 0.95 }, { 1.32, 0.95 }, { 1.82, 0.55 }, { 3.95, 0.55 }, { 4.15, 0.65 } }

-- the arm's Catmull-Rom (the kit's _catmull, 8 per span) in 2D, its lengths, and the feather bases on it
local function catm2(P, i, s)
	local p0, p1, p2, p3 = P[max(i - 1, 1)], P[i], P[i + 1], P[min(i + 2, #P)]
	local s2, s3 = s * s, s * s * s
	local function c(k)
		return 0.5 * ((2 * p1[k]) + (-p0[k] + p2[k]) * s + (2 * p0[k] - 5 * p1[k] + 4 * p2[k] - p3[k]) * s2
			+ (-p0[k] + 3 * p1[k] - 3 * p2[k] + p3[k]) * s3)
	end
	return c(1), c(2)
end
local ARM_C, ARM_L = {}, { 0 }
for i = 1, #ARM - 1 do
	for j = 0, 7 do
		local x, y = catm2(ARM, i, j / 8)
		ARM_C[#ARM_C + 1] = { x, y }
	end
end
ARM_C[#ARM_C + 1] = { ARM[#ARM][1], ARM[#ARM][2] }
for i = 2, #ARM_C do
	local dx, dy = ARM_C[i][1] - ARM_C[i - 1][1], ARM_C[i][2] - ARM_C[i - 1][2]
	ARM_L[i] = ARM_L[i - 1] + sqrt(dx * dx + dy * dy)
end
local ARM_TOT = ARM_L[#ARM_L]

--- the curve parameter (span, s) at length fraction fr of ARM_C
local function armParam(fr)
	local goal = ARM_TOT * clamp(fr, 0, 1)
	for i = 2, #ARM_C do
		if ARM_L[i] >= goal then
			local f = (goal - ARM_L[i - 1]) / max(ARM_L[i] - ARM_L[i - 1], 1e-9)
			local gp = (i - 2 + f) / 8
			local span = min(floor(gp) + 1, #ARM - 1)
			return span, gp - (span - 1)
		end
	end
	return #ARM - 1, 1
end
local FEA_B = {}
for k, f in ipairs(FEA) do                                    -- the kit's arm_at(fr): along the ARM_C polyline
	local goal = ARM_TOT * f[1]
	for i = 2, #ARM_C do
		if ARM_L[i] >= goal then
			local u = (goal - ARM_L[i - 1]) / max(ARM_L[i] - ARM_L[i - 1], 1e-9)
			FEA_B[k] = { lerp(ARM_C[i - 1][1], ARM_C[i][1], u), lerp(ARM_C[i - 1][2], ARM_C[i][2], u) }
			break
		end
	end
end

local function wingW(ws, x, y, lift)
	x *= ws.fx
	return ws.A + ws.o * ((x * ws.ca - y * ws.sa) * S_W) + ws.U * ((x * ws.sa + y * ws.ca) * S_W) + ws.n * lift
end

local function featherPoint(f, u)
	local L = f.L
	return wingW(f.ws, f.bx + f.dx * L * u + f.px * 0.05 * L * u * u, f.by + f.dy * L * u + f.py * 0.05 * L * u * u, f.lift)
end

local Halo = {}
Halo.__index = Halo
local halos = setmetatable({}, { __mode = "k" })            -- [character] = the current handle

local function haloClock(h)
	local now = RD.ServerNow()
	if h.CancelAt then return h.CancelClip + (now - h.CancelAt) * h.Scale end
	if h.StartT0 then return H_LOCK + (now - h.StartT0) * h.Scale end
	if h.ChargeT0 then
		local u = (now - h.ChargeT0) / max(h.Windup, 1e-3)
		return min(H_KEY + max(u, 0) * (H_LOCK - H_KEY), H_LOCK - 1e-3)
	end
	return 0
end

--- the yaw frame at clip time tt (history: the wake / wing motes stay where they were born)
local function yawAt(h, tt)
	local n = h.HN
	for k = 0, #h.HT - 1 do
		local i = ((n - 1 - k) % #h.HT) + 1
		local ht = h.HT[i]
		if ht and ht <= tt then return h.HC[i] end
	end
	return h.Yaw
end

local function wingState(h, t, air, vy)
	local st, tau
	if h.EndT then
		st, tau = "end", H_END + (t - h.EndT)
	elseif t < IDLE_TAU then
		st, tau = "unfold", t
	elseif air and h.AirT then
		local since = t - h.AirT
		if h.AirRise and since < GLIDE_TAU - RISE_TAU0 then
			st, tau = "rise", RISE_TAU0 + since
		elseif h.AirRise or since > 0.15 then
			st, tau = "glide", GLIDE_TAU
		else
			st, tau = "idle", IDLE_TAU
		end
	elseif h.LandT and t - h.LandT < 0.46 then
		st, tau = "land", H_LAND + (t - h.LandT)
	else
		st, tau = "idle", IDLE_TAU
	end
	local al, sp, fx, be = track(ALPHA, tau), track(SPREAD, tau), track(FXS, tau), track(BETA, tau)
	if st ~= h.WSt then
		if h.WSt then h.WFrom[1], h.WFrom[2], h.WFrom[3], h.WFrom[4] = h.WP[1], h.WP[2], h.WP[3], h.WP[4] end
		h.WSt, h.WSw = st, t
	end
	local u = h.WFrom[1] and smooth((t - h.WSw) / Config.Halo.Blend) or 1
	if u < 1 then
		al, sp = lerp(h.WFrom[1], al, u), lerp(h.WFrom[2], sp, u)
		fx, be = lerp(h.WFrom[3], fx, u), lerp(h.WFrom[4], be, u)
	end
	h.WP[1], h.WP[2], h.WP[3], h.WP[4] = al, sp, fx, be
	-- the idle flap (+-6 deg, 1.3 s) and the glide tremble (1.2 deg at 6 Hz), weights eased in / out
	local dtw = h.DT or 0
	local iwT = (st == "idle" or (st == "unfold" and t >= 1.45)) and 1 or 0
	local gwT = (st == "glide") and 1 or 0
	h.IW += clamp(iwT - h.IW, -dtw / 0.1, dtw / 0.15)
	h.GW += clamp(gwT - h.GW, -dtw / 0.1, dtw / 0.1)
	al += 6 * h.IW * sin(TAU * (t - 1.45) / 1.3) + 1.2 * sin(TAU * 6 * t) * h.GW
	return al, sp, fx, be, st
end

local O_FEATHER = { w = 0.1, taper = { 0, 0 }, lo = { 0.35, 0.0 }, n = UP, smooth_k = 3, tag = "wings" }
local O_ARM = { w = 0.075, taper = { 0, 0 }, lo = { 0.5, 0.15 }, n = UP, smooth_k = 8, pieces = 2, tag = "wings" }
local O_COVERT = { w = 0.05, taper = { 0.15, 0.15 }, lo = { 0.3, 0.3 }, n = UP, smooth_k = 4, pieces = 6, tag = "wings" }

--- (Devil) draw_bat: a bat wing per side on the same wing frames (Forge.BatWing: the bones, the thumb claw, 4 clawed
--- fingers fanned by the spread, the scalloped membrane); finger k grows as feather 2k - 1 (feather_grow(t, 2k)).
--- Returns the live fingers ({Q = 6 world points base -> tip, G}), for the wing glints.
local function drawBats(h, dv, t, tb, ga, sp, ended)
	local liveB, grow = h.LiveB, h.BG
	table.clear(liveB)
	for k = 1, 4 do
		local kk = 2 * k - 1
		grow[k] = ramp(t, H_WING0 + 0.06 + 0.03 * (kk - 1), 0.24)
			* (1 - (ended and ramp(tb, H_END + 0.20 + 0.015 * (7 - kk), 0.2) or 0))
	end
	for si = 1, 2 do
		local out = h.BO[si]
		if Forge.BatWing(dv, (si == 1) and 1 or -1, h.WS[si], ga, sp, grow, out) > 0 then
			for k = 1, 4 do
				if out[k] and out[k].G > 0.3 then liveB[#liveB + 1] = out[k] end
			end
		end
	end
	return liveB
end

--- the wings: per side the arched arm, 7 hanging feathers, the scalloped covert row. Returns the live feathers.
--- dv (the Devil scope): bat wings on the same frames instead (drawBats), returning the live fingers.
local function drawWings(h, cv, t, tb, al, sp, fx, be, dv)
	local ut = part(h.C, "UpperTorso")
	if not ut then return nil end
	local ended = h.EndT ~= nil
	local lv = ended and track(WLEV, tb) or track(WLEV, min(t, H_END))
	local ga = ramp(t, H_WING0, 0.22) * (1 - (ended and ramp(tb, H_END + 0.30, 0.16) or 0))
	local cf = ut.CFrame
	local X_, Y_, Z_ = cf.XVector, cf.YVector, cf.ZVector
	local b = rad(be)
	local ca, sa = cos(rad(al)), sin(rad(al))
	for si = 1, 2 do                                            -- the anchors (shoulder blades) and wing planes
		local s = (si == 1) and 1 or -1
		local ws = h.WS[si]
		ws.A = cf:PointToWorldSpace(Vector3.new(s * 0.36, 0.30, 0.56))
		ws.o = X_ * (s * cos(b)) + Z_ * sin(b)
		ws.U = Y_
		ws.n = ws.o:Cross(ws.U).Unit
		ws.fx, ws.ca, ws.sa = fx, ca, sa
	end
	local liveF = h.LiveF
	table.clear(liveF)
	if ga <= 0.001 then return liveF end
	cv:Tag("wings")
	if dv then return drawBats(h, dv, t, tb, ga, sp, ended) end
	for si = 1, 2 do
		local s = (si == 1) and 1 or -1
		local ws = h.WS[si]
		-- the arm (the leading edge), cut by the grow
		local q = h.ArmQ
		table.clear(q)
		if ga >= 0.999 then
			for i = 1, #ARM do q[i] = wingW(ws, ARM[i][1], ARM[i][2], 0) end
		else
			local span, sp_ = armParam(ga)
			for i = 1, span do q[i] = wingW(ws, ARM[i][1], ARM[i][2], 0) end
			local cx, cy = catm2(ARM, span, sp_)
			if sp_ > 1e-3 or #q < 2 then q[#q + 1] = wingW(ws, cx, cy, 0) end
		end
		if #q >= 2 then
			local La = 0
			for i = 2, #q do La += (q[i] - q[i - 1]).Magnitude end
			O_ARM.taper[1], O_ARM.taper[2] = min(0.2, La * 0.2), min(0.6, La * 0.3)
			O_ARM.n = ws.n
			cv:Stroke(q, min(1, lv + 0.12), O_ARM)
		end
		-- the feathers
		local sideF = h.SideF[si]
		table.clear(sideF)
		for k = 1, 7 do
			local fe = FEA[k]
			local fg = ramp(t, H_WING0 + 0.06 + 0.03 * (k - 1), 0.24)
				* (1 - (ended and ramp(tb, H_END + 0.20 + 0.015 * (7 - k), 0.2) or 0))
			local g = fg * smooth((ga - fe[1] + 0.05) / 0.1)
			if g > 0 then
				local f = h.FP[si][k]
				local a = rad(FEA_MEAN + (fe[2] - FEA_MEAN) * sp)
				f.dx, f.dy = cos(a), sin(a)
				f.px, f.py = -f.dy, f.dx
				if f.px < 0 then f.px, f.py = -f.px, -f.py end       -- the curve bows toward the wing tip
				f.bx, f.by, f.L, f.lift, f.g, f.k, f.s, f.ws = FEA_B[k][1], FEA_B[k][2], fe[3] * g, 0.012 * (k - 1) * s, g,
					k, s, ws
				local p0, p1 = featherPoint(f, 0), featherPoint(f, 1)
				f.q0, f.q1 = p0, p1
				local Lf = (p1 - p0).Magnitude
				if Lf >= 0.06 then
					local fq = h.FQ
					fq[1], fq[2], fq[3] = p0, featherPoint(f, 0.5), p1
					O_FEATHER.w = W_FEA[k] * (0.55 + 0.45 * g)
					O_FEATHER.taper[1], O_FEATHER.taper[2] = Lf * 0.35, Lf * 0.6
					O_FEATHER.n = ws.n
					cv:Stroke(fq, (k % 2 == 1) and lv or lv * 0.86, O_FEATHER)
				end
				sideF[#sideF + 1] = f
				if g > 0.3 then liveF[#liveF + 1] = f end
			end
		end
		-- the covert row across the feathers, scalloped
		local ok = #sideF == 7
		if ok then
			for _, f in ipairs(sideF) do
				if f.g < 0.3 then ok = false end
			end
		end
		if ok then
			local cq = h.CovQ
			table.clear(cq)
			local lift = ws.n * (0.03 * s)
			for j, f in ipairs(sideF) do
				local p = featherPoint(f, ROW) + lift
				cq[#cq + 1] = p
				if j < 7 then
					local f2 = sideF[j + 1]
					local p2 = featherPoint(f2, ROW)
					local dm = ((f.q1 - f.q0).Unit + (f2.q1 - f2.q0).Unit).Unit
					cq[#cq + 1] = (p + p2) * 0.5 + dm * 0.13 + lift
				end
			end
			O_COVERT.n = ws.n
			cv:Stroke(cq, lv * 0.92, O_COVERT)
		end
	end
	return liveF
end

-- review fix 2026-09-29: the frame's option tables, hoisted (see LO above the Light Lance frame)
local HO = {
	AURA = { light = true, sparkle = true, tag = "staff" },
	GATHER = { radius = 1.0, n = 9, level = 1.0, size = 0.06, glint_size = 0, t = 0, tag = "gather" },
	SPIRAL = { w = 0, taper = { 0, 0.22 }, lo = { 0, 0.45 }, smooth_k = 1, pieces = 1, tag = "spiral" },
	TRAIL = { w = 0.1, tag = "spiral" },
	WAKE = { n = 12, seed = 41, level = 1.0, size = 0.1, life = 0.5, t0 = H_SPIN0 + 0.02, t1 = 0, drift = DOWN * 0.25,
		tag = "wake" },
	RING1 = { a0 = 0, u = 0, ticks = 12, long_every = 3, rigid = false, tag = "halo", face = true },
	RING2 = { a0 = 0, u = 0, dashes = 8, duty = 0.6, rigid = false, tag = "halo", face = true },
	HSPARK = { n = 6, seed = 45, level = 1.0, size = 0.1, life = 0.9, t0 = H_LOCK + 0.3, t1 = 0, region = "ring",
		normal = UP, drift = UP * 0.1, tag = "halo" },
	LIGHT = { tag = "halo_light" },
	BFL = { size = 1.7, level = 1.0, rot = 0.2, tag = "burst" },
	BRAYS = { n = 16, r0 = 1.25, length = 2.5, width = 0.26, level = 1.0, seed = 9, t = 0, v = 0, tag = "burst" },
	BSPARK = { n = 12, seed = 43, level = 1.0, size = 0.15, life = 0.6, t0 = H_LOCK, t1 = H_LOCK + 0.12, region = "ring",
		normal = UP, drift = UP * 0.35, tag = "burst" },
	DFL = { size = 0.9, level = 1.0, rot = 0.4, tag = "drop" },
	DSPARK = { n = 8, seed = 47, level = 1.0, size = 0.11, life = 0.5, t0 = H_DROP1, t1 = H_DROP1 + 0.1, region = "ring",
		normal = UP, drift = UP * 0.5, tag = "drop" },
	WSPARK = { n = 8, seed = 51, level = 1.0, size = 0.1, life = 0.9, t0 = H_WING0 + 0.15, t1 = 0, drift = DOWN * 0.15,
		region = nil, tag = "wing_fx" },
	WMOTE = { n = 3, seed = 61, level = 0.8, size = 0.05, rise = 0.5, life = 1.6, t0 = H_WING1, t1 = 0, sink = true,
		height = 0.4, tag = "wing_fx" },
	FSPARK = { n = 12, seed = 71, level = 1.0, size = 0.1, life = 0.8, t0 = 0, t1 = 0, drift = DOWN * 0.2, tag = "float" },
	LRING = { w = 0, rigid = true, tag = "float" },
	LSPARK = { n = 8, seed = 73, level = 1.0, size = 0.1, life = 0.5, t0 = 0, t1 = 0, region = "disc", normal = UP,
		drift = UP * 0.5, tag = "float" },
	BOND = { src_sigil = false, pulse = true, period = 0.35, tag = "heal" },
	HMOTE = { n = 5, seed = 0, level = 0.8, size = 0.05, rise = 2.0, life = 0.9, t0 = 0, t1 = 0, tag = "heal" },
	-- the Devil skin's (mk_halo_devil.py)
	DHSPARK = { n = 6, seed = 45, level = 1.0, size = 0.1, life = 0.9, t0 = H_LOCK + 0.3, t1 = 0, drift = UP * 0.1,
		tag = "halo" },
	DDSPARK = { n = 8, seed = 47, level = 1.0, size = 0.11, life = 0.5, t0 = H_DROP1, t1 = H_DROP1 + 0.1,
		drift = DOWN * 0.6, tag = "drop" },
	LSPIKE = { n = 10, r0 = 0.45, length = 1.9, width = 0.12, normal = UP, level = 0, seed = 13, t = 0, v = 0,
		tag = "float" },
	DHEAL = { tag = "heal" },
}

local function haloFrame(h, cv, t, dt)
	h.T, h.DT = t, dt
	local c = h.C
	local dv = h.Dv or nil
	local root = part(c, "HumanoidRootPart")
	if not (c and c.Parent and root) then return false end
	camRefresh()
	local now = RD.ServerNow()
	if h.CancelAt and t > h.CancelClip + 0.45 then return false end
	if not h.StartT0 and not h.CancelAt and h.ChargeT0 and now > h.ChargeT0 + h.Windup + 3 then return false end
	if h.StartT0 and not h.EndT and h.Until and now > h.Until + 1.5 then h.EndT = t end   -- the End never came
	local ended = h.EndT ~= nil
	local tb = ended and (H_END + (t - h.EndT)) or 0
	if ended and tb > H_UNW1 + 0.55 then return false end
	if ended and tb >= H_DROP0 and not h.EndFloor then              -- the halo lets go of the head: it drops here
		h.EndXZ = root.Position
		h.EndFloor = floorBelow(root.Position, h.Ray) or (root.Position.Y - Config.RootHeight)
	end

	local yaw = yawCF(root)
	h.Yaw = yaw
	h.HN = (h.HN % #h.HT) + 1
	h.HT[h.HN], h.HC[h.HN] = t, yaw
	local fp = firstPerson(c)
	local started = h.StartT0 ~= nil and t >= H_LOCK
	local tCancel = h.CancelClip

	-- airborne (every client: a short ray under the root); flights, landings
	local hum = c:FindFirstChildOfClass("Humanoid")
	local reach = (hum and hum.HipHeight or 2) + root.Size.Y * 0.5 + 0.8
	local res = workspace:Raycast(root.Position, Vector3.new(0, -reach, 0), h.Ray)
	local air = res == nil
	local vy = root.AssemblyLinearVelocity.Y
	if air then
		if not h.AirT then h.AirT, h.AirRise, h.FlightEnd = t, vy > 8, nil end
	elseif h.AirT then
		if t - h.AirT >= Config.Halo.MinAir and started then
			h.LandT, h.LandP, h.FlightEnd = t, res.Position, t
		end
		h.AirT = nil
	end

	-- the staff: glow, aura, the gather
	local g = ramp(t, H_KEY, H_LOCK - H_KEY) - 0.4 * ramp(t, H_LOCK + 0.1, 0.4)
	g *= (1 - (ended and ramp(tb, H_END, 0.45) or 0)) * (1 - ramp(t, tCancel or HUGE, 0.3))
	Staff.SetGlow(c, h, max(0, g))
	local tipNow = anchorTip(c)
	if not tipNow then
		tipNow = (t >= H_SPIN0 and t <= H_LOCK) and spiralTip(yaw, t) or carryTip(c)
	end
	if tipNow then
		HO.AURA.sparkle = t < H_LOCK + 0.1
		cv:StaffAura(tipNow, max(0, g), t, HO.AURA)
		if H_KEY < t and t < H_SPIN0 + 0.2 and not tCancel then
			HO.GATHER.glint_size, HO.GATHER.t = 0.4 * (1 - ramp(t, H_SPIN0 + 0.02, 0.16)), t
			cv:Gather(tipNow, ramp(t, H_KEY, 0.2), HO.GATHER)
		end
	end

	-- the windup: the spiral traced by the tip (a sliding one-turn window), its riding trail, the wake
	if H_SPIN0 < t and (t < H_LOCK or (tCancel and t < tCancel + 0.25)) and not started then
		local tt = t
		if tCancel ~= nil and tCancel < t then tt = tCancel end
		local deg = spinDeg(tt)
		local d0 = max(0, deg - 360)
		if tCancel then d0 += (deg - d0) * ramp(t, tCancel, 0.2, "Linear") end   -- cancelled: runs into the lead
		local q = h.TraceQ
		table.clear(q)
		local k = floor(d0 / 22.5) + 1
		q[1] = spiralTip(yaw, spinInv(d0))
		while k * 22.5 < deg - 1e-6 do
			q[#q + 1] = spiralTip(yaw, spinInv(k * 22.5))
			k += 1
		end
		q[#q + 1] = spiralTip(yaw, tt)
		if #q >= 2 then
			local Lq = 0
			for i = 2, #q do Lq += (q[i] - q[i - 1]).Magnitude end
			local upv = up01(tt, H_SPIN0, H_LOCK)
			local tail = Lq * 0.42 * (1 - ramp(deg, 560, 160))
			HO.SPIRAL.w, HO.SPIRAL.taper[1] = 0.055 + 0.02 * upv, tail
			HO.SPIRAL.pieces = max(1, math.ceil((deg - d0) / 90 - 1e-6))
			cv:Stroke(q, 0.55 + 0.35 * upv, HO.SPIRAL)
			if not tCancel then
				cv:Trail(RD.trail_fn(h.TipAt, tt, 0.09, 8, H_SPIN0, h.TrailQ), 1.0, HO.TRAIL)
			end
		end
	end
	HO.WAKE.t1 = min(H_LOCK, tCancel or HUGE)
	cv:Sparkles(h.TipAt, 0.22, t, HO.WAKE)
	if not started then return true end
	if not h.ALock then                                          -- the ring starts where the tip closed it
		local p = spiralTip(yaw, H_LOCK) - yaw.Position
		h.ALock = math.atan2(p.Z, -p.X)                          -- the kit's atan2(y, x), Blender (x, y) = (-X, Z)
	end

	-- the halo: the traced ring rises and contracts over the head, turns; the drop and unwind at the end
	local head = part(c, "Head")
	local us = ramp(t, H_LOCK + 0.04, 0.45)
	local rp = root.Position
	local cx, cz = rp.X, rp.Z
	if head then cx, cz = lerp(rp.X, head.Position.X, us), lerp(rp.Z, head.Position.Z, us) end
	local zLock = rp.Y + (H_LOCK_Z - Config.RootHeight)
	local zHalo = head and (head.Position.Y + head.Size.Y * 0.5 + Config.Halo.HeadLift) or (rp.Y + 2.95)
	local zr = zLock + (zHalo - zLock) * ramp(t, H_LOCK + 0.04, 0.42)
	local z = zr + 0.05 * sin(TAU * 0.8 * (t - H_LOCK)) * ramp(t, H_LOCK + 0.4, 0.4)
	if h.EndFloor then
		local uf = up01(tb, H_DROP0, H_DROP1)
		cx, cz = h.EndXZ.X, h.EndXZ.Z
		z += (h.EndFloor + 0.03 - z) * uf * uf                      -- drops (accelerating) to the floor
	end
	local center = Vector3.new(cx, z, cz)
	local R = h.RLock + (R_HALO - h.RLock) * us
	local lv = 1 - 0.3 * ramp(t, H_LOCK + 0.12, 0.45)
	for _, sh in ipairs(h.Shares) do
		lv = max(lv, 0.72 + 0.2 * env(t, sh.T, sh.T + 0.4, 0.08, 0.2))
	end
	local uo = 1 - (ended and ramp(tb, H_UNW0, H_UNW1 - H_UNW0) or 0)
	local ui = ramp(t, H_LOCK + 0.05, 0.16) * (1 - (ended and ramp(tb, H_DROP0, 0.16) or 0))
	local ss = ramp(t, H_LOCK + 0.25, 0.25) * (1 - (ended and ramp(tb, H_DROP1, 0.14) or 0))
	local w_ = 0.9 * (t - H_LOCK)
	local A = h.ALock
	-- (Devil) the head top (devil_look head_top): the horns' sparkles, the drop, the heal's source
	local headTop = dv and (head and (head.Position + UP * (head.Size.Y * 0.5)) or (rp + UP * 2.25))
	cv:Tag("halo")
	if dv then
		-- the horns take the halo's place: grown out of the head as the spiral closes (the halo's rise), retracted
		-- where it dropped; sparkles round the head, not in a ring
		h.HeadUp = headTop.Y - rp.Y
		local hg = ease("Back", up01(t, H_LOCK + 0.04, H_LOCK + 0.46))
			* (1 - (ended and ease("Quad", up01(tb, H_DROP0, H_DROP1)) or 0))
		if head and not (fp and not Config.Halo.HornsFirstPerson) then Forge.Horns(dv, head.CFrame, hg) end
		HO.DHSPARK.t1 = ended and (h.EndT + (H_DROP0 - H_END)) or HUGE
		cv:Sparkles(h.HeadTop, 0.55, t, HO.DHSPARK)
	else
		if uo > 0.005 then
			HO.RING1.a0, HO.RING1.u, HO.RING1.rigid = A + w_, uo, uo >= 0.999
			cv:Ring(center, R, UP, lv, HO.RING1)                                    -- Phase 5: seen from head height it must not vanish edge-on
		end
		if ui > 0.02 then
			HO.RING2.a0, HO.RING2.u, HO.RING2.rigid = A - 1.4 * w_, ui, ui >= 0.999
			cv:Ring(center, R * 0.8, UP, lv * 0.85, HO.RING2)
		end
		if ss > 0.03 then
			for j = 0, 3 do
				local a = A + w_ + pi / 4 + j * pi / 2
				cv:StarStud(center + RD.B(cos(a), sin(a), 0) * R, nil, 0.11 * ss, min(1, lv + 0.15), 4, 0.3 * t, "halo")
			end
		end
		HO.HSPARK.t1 = ended and (h.EndT + (H_DROP0 - H_END)) or HUGE
		cv:Sparkles(center, R, t, HO.HSPARK)
	end
	cv:LightPool(center - UP * 0.25, (0.55 + 1.3 * env(t, H_LOCK - 0.02, H_LOCK + 0.7, 0.05, 0.5))
		* (1 - (ended and ramp(tb, H_DROP1, 0.4) or 0)), HO.LIGHT)
	-- the lock burst: the tip flare, the sunburst behind the head, a ring of glints
	if t < H_LOCK + 0.8 then
		cv:Tag("burst")
		cv:Flare(spiralTip(yaw, H_LOCK), (t - H_LOCK) / 0.55, noShock(HO.BFL, dv))
		local cl = Vector3.new(rp.X, zr, rp.Z)
		HO.BRAYS.t, HO.BRAYS.v = t, ramp(t, H_LOCK + 0.28, 0.4)
		cv:HolyRays(cl - camDir(cl) * 1.3, ramp(t, H_LOCK, 0.2, "Linear"), HO.BRAYS)
		cv:Sparkles(center, R, t, HO.BSPARK)
	end
	if dv then
		if ended and tb > H_DROP0 then                       -- the horns crack back into the head: a flare there, embers falling
			cv:Tag("drop")
			cv:Flare(headTop + camDir(headTop) * 0.4, (tb - H_DROP1) / 0.45, noShock(HO.DFL, dv))
			cv:Sparkles(headTop, 0.5, tb, HO.DDSPARK)
		end
	elseif h.EndFloor and tb > H_DROP0 then
		cv:Tag("drop")
		local fl = Vector3.new(cx, h.EndFloor + 0.06, cz)
		cv:Flare(fl + camDir(fl) * 0.4, (tb - H_DROP1) / 0.45, HO.DFL)
		cv:Sparkles(Vector3.new(cx, h.EndFloor + 0.05, cz), R_HALO, tb, HO.DSPARK)
	end

	-- the wings (not the own ones in first person: they are behind the camera); Devil: bat wings
	local showWings = not (fp and not Config.Halo.WingsFirstPerson)
	local al, sp, fx, be = wingState(h, t, air, vy)
	if showWings then
		local liveF = drawWings(h, cv, t, tb, al, sp, fx, be, dv)
		cv:Tag("wing_fx")
		for si = 1, 2 do
			local ws = h.WS[si]
			if ws.A then
				cv:Glint(ws.A, 0.36 * env(t, H_WING0 - 0.04, H_WING0 + 0.30, 0.06, 0.2), 1.0, 0.3 * t, nil, 0.45, "wing_fx")
				if ended then
					cv:Glint(ws.A, 0.30 * env(tb, H_FOLD1 - 0.10, H_FOLD1 + 0.22, 0.06, 0.15), 1.0, 0.3 * t, nil, 0.45,
						"wing_fx")
				end
			end
		end
		if liveF and #liveF > 0 then
			HO.WSPARK.t1, HO.WSPARK.region = ended and h.EndT or HUGE, dv and h.BatRegion or h.WingRegion
			cv:Sparkles(ZERO, 0.0, t, HO.WSPARK)
		end
		for si = 1, 2 do
			HO.WMOTE.seed, HO.WMOTE.t1 = (si == 1) and 61 or 59, ended and h.EndT or HUGE
			cv:MoteField(h.WingC[si], 0.8, t, HO.WMOTE)
		end
		-- the float: a wake of glints over each flight
		if h.AirT or h.FlightEnd then
			HO.FSPARK.t0, HO.FSPARK.t1 = h.AirT or h.FlightStart or t, h.AirT and HUGE or (h.FlightEnd - 0.05)
			cv:Sparkles(h.BodyC, 0.8, t, HO.FSPARK)
		end
	end
	if h.AirT then h.FlightStart = h.AirT end
	-- the landing: a soft gold ring and a splash of glints (Devil: a burst of floor spikes, not a ring)
	if h.LandT then
		cv:Tag("float")
		local ul = ramp(t, h.LandT, 0.4, "Quad")
		local lp = h.LandP + UP * Config.FloorLift
		if ul > 0 and ul < 0.98 then
			if dv then
				HO.LSPIKE.level, HO.LSPIKE.t, HO.LSPIKE.v = 0.9 - 0.4 * ul, t, ramp(t, h.LandT + 0.18, 0.3)
				cv:HolyRays(lp, ramp(t, h.LandT, 0.12, "Linear"), HO.LSPIKE)
			else
				HO.LRING.w = 0.07 * (1 - ul) + 0.008
				cv:Ring(lp, 0.5 + 1.9 * ul, UP, 0.9 - 0.4 * ul, HO.LRING)
			end
		end
		HO.LSPARK.t0, HO.LSPARK.t1 = h.LandT, h.LandT + 0.08
		cv:Sparkles(h.LandP + UP * 0.1, 0.9, t, HO.LSPARK)
	end

	-- heal share: quiet Bond flickers from the halo to the allies, motes rising round them (Devil: devil_heal from
	-- between the horns -- a dark thread, barbed chevrons gliding to the ally, embers; nothing gold)
	cv:Tag("heal")
	for i = #h.Shares, 1, -1 do
		local sh = h.Shares[i]
		if t > sh.T + 1.3 then
			table.remove(h.Shares, i)
		else
			local u = ramp(t, sh.T, 0.12) * (1 - ramp(t, sh.T + 0.34, 0.14))
			for j, m in ipairs(sh.Models) do
				local ch = chestOf(m)
				local mr = part(m, "HumanoidRootPart")
				if ch and j <= 3 then
					local dxy = Vector3.new(ch.X - cx, 0, ch.Z - cz)
					if u > 0.01 and not ended and dxy.Magnitude > 1e-3 then
						if dv then
							local src = headTop + dxy.Unit * 0.35
							Forge.DevilHeal(cv, src, RD.ReceivePoint(ch, src), u, t, sh.T, HO.DHEAL)
						else
							local src = center + dxy.Unit * R
							cv:Bond(src, RD.ReceivePoint(ch, src), u, 0.35, HO.BOND)
						end
					end
					local fy = (mr and mr.Position.Y or ch.Y) - Config.RootHeight
					HO.HMOTE.seed, HO.HMOTE.t0, HO.HMOTE.t1 = 80 + i * 7 + j, sh.T + 0.1, sh.T + 0.3
					cv:MoteField(Vector3.new(ch.X, fy + 0.1, ch.Z), 0.7, t, HO.HMOTE)
				end
			end
		end
	end
	return true
end

local function newHalo(c)
	local h = setmetatable({
		C = c, T = 0, DT = 0, Scale = RD.TimeScale(), Windup = 0.9, Shares = {}, TraceQ = {}, TrailQ = {}, ArmQ = {},
		CovQ = {}, FQ = {}, LiveF = {}, SideF = { {}, {} }, WS = { {}, {} }, FP = { {}, {} }, WP = { 0, 0, 0, 0 },
		WFrom = {}, IW = 0, GW = 0, HT = table.create(90), HC = table.create(90), HN = 0,
	}, Halo)
	for k = 1, 7 do
		h.FP[1][k], h.FP[2][k] = {}, {}
	end
	for i = 1, 90 do h.HT[i] = false end
	h.Ray = rayParamsFor(c)
	-- the lock: the ring starts where the tip closed it (radius, angle in the kit's convention)
	local lx, lz = TIP_OUT[1], -TIP_OUT[2]
	h.RLock = sqrt(lx * lx + lz * lz)
	h.TipAt = function(tt) return spiralTip(h.Yaw or CFrame.new(), tt) end
	h.BodyC = function(tt) return RD.Body(yawAt(h, tt), 0, 0.4, -0.3) end
	h.WingC = {
		function(tt) return RD.Body(yawAt(h, tt), 1.6, 0.6, -0.9) end,
		function(tt) return RD.Body(yawAt(h, tt), -1.6, 0.6, -0.9) end,
	}
	h.WingRegion = function(rnd)
		local lf = h.LiveF
		if #lf == 0 then return ZERO end
		local f = lf[min(#lf, floor(rnd() * #lf) + 1)]
		return featherPoint(f, 0.35 + 0.65 * rnd())
	end
	h.Effect = play("RadiantHalo", function(cv, t, dt)
		return devilFrame(h, haloFrame, cv, t, dt)
	end, {
		Clock = function() return haloClock(h) end, MaxLife = HUGE,
		OnEnd = function(e)
			live[e] = nil
			h.Dead = true
			Staff.SetGlow(c, h, nil)
			if halos[c] == h then halos[c] = nil end
			if h.Dv then h.Dv:Destroy() end
		end,
	})
	h.Dv = devilScope(h.Effect.Canvas.Palette, "Halo")
	if h.Dv then                                               -- the bat wings' grow, fingers, live fingers; the head top
		h.BG, h.BO, h.LiveB, h.HeadUp = { 0, 0, 0, 0 }, { {}, {} }, {}, 2.25
		h.BatRegion = function(rnd)                            -- devil_look's wing_point on a live finger (0.35 .. 1)
			local lb = h.LiveB
			if #lb == 0 then return ZERO end
			local f = lb[min(#lb, floor(rnd() * #lb) + 1)]
			local x = (0.35 + 0.65 * rnd()) * 5
			local i = min(floor(x), 4)
			return f.Q[i + 1]:Lerp(f.Q[i + 2], x - i)
		end
		h.HeadTop = function(tt) return yawAt(h, tt).Position + UP * h.HeadUp end
	end
	halos[c] = h
	return h
end

--- the current Halo handle of a character; a new one when the old one is ending
local function haloFor(c, create)
	local h = halos[c]
	if h and (h.Dead or h.EndT or h.CancelAt) then
		if not create then return nil end
		h = nil
	end
	if not h and create then h = newHalo(c) end
	return h
end

function Staff.HaloCharge(d)
	local c = type(d) == "table" and d.Character
	if not c then return end
	local old = halos[c]
	if old and not old.Dead and not old.EndT and not old.CancelAt then
		old.Dead = true                                          -- a live one (a lost End): gone, not reused
		old.Effect:Stop()
	end
	local h = haloFor(c, true)
	h.ChargeT0 = type(d.T0) == "number" and d.T0 or RD.ServerNow()
	h.Windup = (type(d.Windup) == "number" and d.Windup > 0) and d.Windup
		or tnum("Halo", "Windup", 0.9) / max(h.Scale, 1e-3)
end

function Staff.HaloCancel(d)
	local h = type(d) == "table" and d.Character and haloFor(d.Character, false)
	if h and not h.StartT0 then
		h.CancelClip = h.T
		h.CancelAt = RD.ServerNow()
	end
end

function Staff.HaloStart(d)
	local c = type(d) == "table" and d.Character
	if not c then return end
	local h = haloFor(c, true)
	h.StartT0 = type(d.T0) == "number" and d.T0 or RD.ServerNow()
	h.Until = type(d.Until) == "number" and d.Until or (h.StartT0 + tnum("Halo", "Duration", 6.0) / max(h.Scale, 1e-3))
end

function Staff.HaloEnd(d)
	local h = type(d) == "table" and d.Character and haloFor(d.Character, false)
	if not h then return end
	if not h.StartT0 then
		h.CancelClip = h.T
		h.CancelAt = RD.ServerNow()
		return
	end
	h.EndT = max(h.T, H_LOCK)
	h.Reason = d.Reason
end

--- a heal-share flicker from the halo to these allies (call on a Halo heal share; nothing broadcasts one yet)
function Staff.HaloShare(c, models)
	local h = c and haloFor(c, false)
	if not (h and h.StartT0) or type(models) ~= "table" then return end
	if #h.Shares >= 3 then table.remove(h.Shares, 1) end
	h.Shares[#h.Shares + 1] = { T = h.T, Models = models }
end

----------------------------------------------------------------------------------------------------
-- BENEDICTION   (benediction_r3.py: frame(t), the per-pulse arm pull / chest dip removed; r3 glow)
----------------------------------------------------------------------------------------------------
local B_PRESS, B_RAISE, B_PLANT = 0.12, 0.34, 0.44
local B_TRAVEL, B_BODY = 0.15, 0.20
local SIG_R, SINK = 2.3, 0.30
local D_K = 0.636
local LIFT_R, LIFT_P = D_K + 0.30, D_K + 0.35
local RET, DESC = 0.32, 0.5
local OPEN = 1e6                                  -- a held channel's end before its End arrives (clip s)

--- the pulse schedule, grown to cover clip time `upto` (2026-09-30: held, so its length is unknown): Arr[k] = a pulse's
--- arrival (B_PLANT + k * Every), Pulls[k] = the palm's pull that feeds it
local function bene_pulses(h, upto)
	local k = #h.Arr
	while B_PLANT + (k + 1) * h.Every <= upto do
		k += 1
		h.Arr[k] = B_PLANT + k * h.Every
		h.Pulls[k] = h.Arr[k] - B_TRAVEL - B_BODY
	end
end
local SKY_R1, SKY_R2 = 12.0, 7.5
local CRACKS = {                                  -- benediction_r3 CRACKS (random.Random(12)), Blender XY off the plant
	{ { 0.2200, -0.0028 }, { 0.6385, 0.0385 }, { 1.0545, -0.1135 }, { 1.4719, -0.1557 }, { 1.8916, -0.0241 } },
	{ { 0.1477, 0.1631 }, { 0.3059, 0.4673 }, { 0.5533, 0.6906 }, { 0.7944, 0.9197 }, { 1.0381, 1.1465 } },
	{ { -0.0552, 0.2130 }, { -0.0641, 0.6433 }, { -0.2490, 1.0280 }, { -0.2787, 1.4529 }, { -0.4753, 1.8346 } },
	{ { -0.2134, 0.0535 }, { -0.5098, 0.0359 }, { -0.7338, 0.3069 }, { -1.0503, 0.2095 }, { -1.3123, 0.3292 } },
	{ { -0.2053, -0.0790 }, { -0.5079, -0.2981 }, { -0.9276, -0.2125 }, { -1.2604, -0.3532 }, { -1.5532, -0.5976 } },
	{ { -0.0037, -0.2200 }, { -0.1247, -0.6025 }, { 0.1197, -0.9912 }, { 0.1019, -1.3754 }, { -0.0297, -1.7578 } },
	{ { 0.1015, -0.1952 }, { 0.1793, -0.5664 }, { 0.3919, -0.8675 }, { 0.6371, -1.1516 }, { 0.7754, -1.4914 } },
}

local function colR(hh) return 0.40 + 0.024 * max(0, hh) end        -- guide-strand radius, hh studs over the palm
local function colW(hh) return 0.14 + 0.0065 * max(0, hh) end       -- core width (1.3 at the top)
local function strandW(hh) return 0.045 + 0.0036 * max(0, hh) end
local function ringW(hh) return 0.055 + 0.0045 * max(0, hh) end
local function fallH(age) return (1 - clamp(age, 0, 1)) ^ 2.5 end   -- a glyph ring's height fraction (1 sky, 0 palm)

local Bene = {}
Bene.__index = Bene
local benes = setmetatable({}, { __mode = "k" })
local beneLast = setmetatable({}, { __mode = "k" })         -- [character] = the latest handle, kept after it ends

local VB_FR = { 0, 0.04, 0.12, 0.3, 0.6, 1 }         -- vbeam knots (fractions of `head` from the low end); then the top

--- the kit's vbeam: one tapering vertical beam p_lo -> p_hi, width wfun(height over z0), the low end tapered over head
local function vbeam(h, cv, pLo, pHi, level, wfun, z0, head)
	local Ld = (pHi - pLo).Magnitude
	if Ld < 0.05 then return end
	local q, prof = h.VQ, h.VP
	table.clear(q)
	table.clear(prof)
	local wm = max(wfun(pLo.Y - z0), wfun(pHi.Y - z0))
	local function push(f)
		local p = pLo:Lerp(pHi, f)
		local m = wfun(p.Y - z0) / wm
		if head > 0 then m *= 0.3 + 0.7 * smooth(min(1, (p - pLo).Magnitude / head)) end
		q[#q + 1], prof[#prof + 1] = p, m
	end
	if head > 0 and head < Ld then
		for _, fr in ipairs(VB_FR) do push(fr * head / Ld) end
	else
		push(0)
	end
	push(1)
	if cv:Line(q, level, wm, nil, true, prof) then cv:Count(1) end
end

local SO = {                                     -- review fix 2026-09-29: sigilRot's rings, hoisted
	R1 = { a0 = 0, u = 0, ticks = 12, long_every = 3, tick_in = true, tick_len = { 0.12, 0.22 }, tag = "_tmp" },
	R2 = { a0 = 0, u = 0, tag = "_tmp" },
	R3 = { a0 = 0, u = 0, tag = "_tmp" },
}

local function sigilRot(cv, c, r, level, u, phase, tag)
	local p0 = cv.Pieces
	SO.R1.a0, SO.R1.u = phase, u
	cv:Ring(c, r * 0.98, UP, level, SO.R1)
	SO.R2.a0, SO.R2.u = phase, u
	cv:Ring(c, r * 0.78, UP, level, SO.R2)
	SO.R3.a0, SO.R3.u = -phase, u
	cv:Ring(c, r * 0.30, UP, level, SO.R3)
	local ux, vx = RD.basis(UP)
	local full = u >= 1 - 1e-6
	for j = 0, 11 do
		local rel = (j + 0.5) * TAU / 12
		if rel > TAU * u + 1e-9 then break end
		local g = full and 1 or smooth((TAU * u - rel) / 0.4)
		if g >= 0.03 then
			local a = phase + rel
			local e = ux * cos(a) + vx * sin(a)
			cv:Seg(c + e * (r * 0.30), c + e * (r * (0.30 + 0.48 * g)), level, RD.lw(level) * 0.9 * (0.5 + 0.5 * g), UP, true,
				"_tmp")
		end
	end
	for j = 0, 3 do
		local rel = j * TAU / 4
		if rel > TAU * u + 1e-9 then break end
		local g = full and 1 or smooth((TAU * u - rel) / 0.4)
		local a = phase + rel
		local e = ux * cos(a) + vx * sin(a)
		cv:StarStud(c + e * (r * 0.98) + UP * 0.02, UP, 0.16 * g, min(1, level + 0.2), 4, a, "_tmp")
	end
	local strokes = cv.Pieces - p0
	cv:Count(-strokes, "_tmp")
	cv:Count(full and 1 or strokes, tag)
end

--- the kit's path_slice: the part of polyline P (n points) between lengths s0 and s1, into out
local function pathSlice(P, n, s0, s1, out)
	table.clear(out)
	local tot = 0
	for i = 2, n do tot += (P[i] - P[i - 1]).Magnitude end
	s0, s1 = max(0, s0), min(tot, s1)
	local acc = 0
	for i = 1, n - 1 do
		local l = (P[i + 1] - P[i]).Magnitude
		local a, b = acc, acc + l
		if not (b < s0 or a > s1) then
			local pa = P[i]:Lerp(P[i + 1], (max(a, s0) - a) / max(l, 1e-9))
			local pb = P[i]:Lerp(P[i + 1], (min(b, s1) - a) / max(l, 1e-9))
			if #out == 0 or (out[#out] - pa).Magnitude > 1e-5 then out[#out + 1] = pa end
			out[#out + 1] = pb
		end
		acc = b
	end
	return out, tot
end

local CONDUIT = { { "LeftLowerArm", nil, 0.62 }, { "LeftUpperArm", Vector3.new(0, 0.45, 0), 0.62 },
	{ "UpperTorso", false, 0.62 }, { "RightUpperArm", Vector3.new(0, 0.45, 0), 0.62 }, { "RightLowerArm", nil, 0.62 },
	{ "RightHand", Vector3.new(0, -0.05, 0), 0.5 } }

--- palm -> left arm -> shoulders -> right arm -> hand -> staff head, lifted toward the camera over the body blocks
local function conduitPath(h, c, pc, tip, fp)
	local P = h.CP
	table.clear(P)
	P[1] = pc + camDir(pc) * 0.1
	if not fp then
		for _, e in ipairs(CONDUIT) do
			local p = part(c, e[1])
			if not p then
				table.clear(P)
				P[1] = pc + camDir(pc) * 0.1
				break
			end
			local w
			if e[2] == false then
				w = p.Position + UP * 0.35
			elseif e[2] then
				w = p.CFrame:PointToWorldSpace(e[2])
			else
				w = p.Position
			end
			P[#P + 1] = w + camDir(w) * e[3]
		end
	end
	P[#P + 1] = tip + camDir(tip) * 0.1
	return P
end

-- review fix 2026-09-29: the frame's option tables, hoisted (see LO above the Light Lance frame)
local BO = {
	AURA = { light = true, sparkle = true, tag = "staff" },
	SFL = { size = 0.9, level = 1.0, rot = 0.2, shock = false, tag = "staff" },
	GATHER = { radius = 1.0, n = 9, level = 1.0, size = 0.06, glint_size = 0, t = 0, tag = "gather" },
	DTRAIL = { w = 0.09, tag = "gather" },
	SKY1 = { a0 = 0, u = 0, w = 0.8, rigid = false, tag = "heaven" },
	SKY2 = { a0 = 0, u = 0, w = 0.6, rigid = false, tag = "heaven" },
	SKYRAYS = { n = 8, r0 = SKY_R1 + 0.9, length = 9.0, width = 2.2, normal = UP, level = 0, seed = 23, stagger = 0.25,
		v = 0, t = 0, tag = "heaven" },
	SKYFL = { size = 16.0, level = 1.0, rot = 0.4, shock = false, tag = "heaven" },
	COL1 = { a0 = 0, ticks = 8, long_every = 2, tick_in = true, w = 0, rigid = true, tag = "column" },
	COLK = { a0 = 0, ticks = 8, long_every = 2, tick_in = true, w = 0, rigid = true, tag = "column" },
	COLS = { a0 = 0, w = 0, rigid = true, tag = "column" },
	MOTES = { size = 1.5, sizes = nil, trails = nil, trail_len = 4.0, as_particles = true, tag = "column" },
	PROS = { spokes = 8, s_in = 1.22, s_out = 1.8, u = 0, grow = true, tag = "palm" },
	PLIGHT = { tag = "palm" },
	PFL = { size = 0.95, level = 1.0, rot = 0, tag = "palm" },
	CTRAIL = { w = 0.12, tag = "conduit" },
	IFL = { size = 1.5, level = 1.0, rot = 0.2, tag = "impact" },
	IRING = { w = 0, rigid = true, tag = "impact" },
	ISPARK = { n = 12, seed = 91, level = 1.0, size = 0.14, life = 0.55, t0 = B_PLANT, t1 = B_PLANT + 0.1, region = "disc",
		normal = UP, drift = UP * 0.9, tag = "impact" },
	CRACK = { w = 0.055, taper = { 0, 0 }, lo = { 1.0, 0.0 }, n = UP, tag = "ground" },
	PRING = { w = 0, rigid = true, tag = "ground" },
	GMOTE = { n = 5, seed = 93, level = 0.85, size = 0.055, rise = 1.3, life = 1.3, t0 = B_PLANT + 0.1, t1 = 0,
		tag = "ground" },
	LIGHT = { tag = "light" },
	RANGE = { ticks = 0, long_every = 6, tick_in = true, rigid = false, w = 0.14, tag = "range" },
	BOND = { src_sigil = false, seal = false, pulse = false, tag = "bond" },
	BTRAIL = { w = 0.11, tag = "bond" },
	BROS = { spokes = 6, s_in = 1.21, s_out = 1.79, phase = 0, u = 0, grow = true, tag = "bond" },
	HFL = { size = 0.75, level = 1.0, rot = 0, tag = "healed" },
	HRING = { w = 0, rigid = true, tag = "healed" },
	HMOTE = { n = 5, seed = 0, level = 0.85, size = 0.05, rise = 2.2, life = 0.9, t0 = 0, t1 = 0, tag = "healed" },
	OFL = { size = 0.8, level = 1.0, rot = 0.5, tag = "pullout" },
	OSPARK = { n = 8, seed = 99, level = 1.0, size = 0.1, life = 0.55, t0 = 0, t1 = 0, region = "disc", normal = UP,
		drift = UP * 0.8, tag = "pullout" },
	OMOTE = { n = 5, seed = 101, level = 0.8, size = 0.05, rise = 1.1, life = 0.8, t0 = 0, t1 = 0, tag = "pullout" },
	-- the Devil skin's (devil_look devil_heaven, mk_devil.py benediction)
	DPFL = { size = 11.0, level = 1.0, rot = 0.2, shock = false, tag = "heaven" },
	DEMBER = { n = 8, seed = 131, level = 1.0, size = 0.12, life = 0.6, t0 = B_PLANT, t1 = 0, drift = UP * 9.0,
		region = nil, tag = "column" },
	DHSPARK = { n = 2, seed = 0, level = 1.0, size = 0.1, life = 0.6, t0 = 0, t1 = 0, drift = UP * 1.8, tag = "healed" },
}

local PIT_D = 2.6                                -- devil_look PIT_D: the column rises from the pit's depths

--- (Devil) devil_heaven (pass 1; the column's base at the pass-4 pit's depth): the horned inverted-pentagram GATE
--- opens H_SKY up; on the plant a thick dark column RISES out of the pit under the planted trident to the gate, wound
--- with two barbed chains; embers race up it; each pulse a surge climbs it and the gate flares; at the end it sinks
--- back into the pit and the gate closes. The heaven's timings: us / uc its open / close, the pulses K0..K1.
local function devilHeaven(h, cv, dv, t, us, uc, OFF, K0, K1)
	local sky = h.Sky
	local pe = 0
	for k = K0, K1 do
		local tp = h.Pulls[k]
		if h.Arr[k] <= OFF + 0.05 then pe = max(pe, env(t, tp - 0.05, tp + 0.35, 0.05, 0.25)) end
	end
	Forge.Gate(dv, sky, SKY_R1, min(us, uc), pe, t)
	BO.SKYRAYS.level, BO.SKYRAYS.v, BO.SKYRAYS.t = min(1, 0.8 + 0.2 * pe), ramp(t, OFF + 0.22, 0.24), t
	cv:HolyRays(sky, ramp(t, Config.Benediction.SkyOpenAt + 0.1, 0.26, "Linear"), BO.SKYRAYS)
	cv:Flare(sky, (t - B_PLANT) / 0.6, BO.SKYFL)
	for k = K0, K1 do
		if h.Arr[k] <= OFF + 0.05 then cv:Flare(sky, (t - h.Pulls[k]) / 0.5, BO.DPFL) end
	end
	if t < B_PLANT then return end
	local base = h.Plant - UP * PIT_D
	local top
	local tCol = h.Pulls[1]
	if t < tCol then
		top = base:Lerp(sky, ease("Quad", up01(t, B_PLANT, tCol)))
	elseif t <= OFF then
		top = sky
	else
		local e = up01(t, OFF, OFF + RET) ^ 1.5
		if e >= 1 then return end
		top = sky:Lerp(base, e)
	end
	cv:Tag("column")
	local Ht = top.Y - h.FloorY                                -- the top over the floor (the surges' heights)
	local sg = h.DSurge
	table.clear(sg)
	for k = K0, K1 do
		local u = up01(t, h.Pulls[k] - 0.45, h.Pulls[k])
		if h.Arr[k] <= OFF + 0.05 and u > 0 and u < 1 then sg[#sg + 1] = u ^ 1.6 * Ht end
	end
	Forge.HellColumn(dv, base, top, t, sg)
	Forge.SpiralChains(dv, base, top, t)
	h.ColBase, h.ColTop, h.ColH = base, top, max(Ht, 1e-3)
	BO.DEMBER.t1, BO.DEMBER.region = OFF, h.EmberAt
	cv:Sparkles(ZERO, 0, t, BO.DEMBER)
end

local function beneFrame(h, cv, t, dt)
	h.T = t
	local c = h.C
	local dv = h.Dv or nil
	if not (c and c.Parent) then return false end
	camRefresh()
	-- a missed End (2026-09-30): no pulse for Every + Timeout past the last one (or the plant) lets go by itself; a pulse
	-- after it takes that back (Staff.BenedictionPulse: the review's provisional timeout)
	if not h.EndT and t > (h.LastPulseT or B_PLANT) + h.Every + h.Timeout then h.EndT, h.Reason = t, "Timeout" end
	local OFF = h.EndT and min(h.OffSched, max(h.EndT, B_PLANT)) or h.OffSched
	if t > OFF + 1.1 then return false end
	-- the pulses near now, the window every per-pulse piece below walks (the schedule grows while the channel runs)
	bene_pulses(h, min(t, OFF) + 1.2)
	local K0, K1 = max(1, floor((t - B_PLANT - 1.6) / h.Every)), #h.Arr
	local fp = firstPerson(c)
	local P3 = h.Plant                                       -- the plant point on the floor (sigil, cracks)
	local floorLift = UP * Config.FloorLift
	local T_OUT = OFF + 0.051                                 -- the butt leaves the ground
	local T_PULL = OFF + 0.26

	-- the pulse schedule (only the pulses before the channel ended)
	local pulseEnv, pullEnv = 0, 0
	for k = K0, K1 do
		local ta = h.Arr[k]
		if ta <= OFF + 0.05 then
			pulseEnv = max(pulseEnv, env(t, ta - B_TRAVEL, ta + 0.2, 0.06, 0.25))
			local tp = h.Pulls[k]
			pullEnv = max(pullEnv, env(t, tp - 0.05, tp + 0.3, 0.05, 0.25))
		end
	end

	-- the staff head (the anim's tip; else the planted staff, pulled out, back to the carry)
	local plantTip = P3 + UP * (Config.StaffTipZ - Config.StaffButtZ - SINK)
	local tip = anchorTip(c)
	if not tip then
		if t <= OFF then
			tip = plantTip
		elseif t < T_PULL then
			tip = plantTip + UP * (LIFT_P * ease("Sine", up01(t, OFF, T_PULL)))
		else
			tip = carryTip(c) or plantTip
		end
	end

	-- the staff: glow, aura, the pulse glints / flares at the head, the gather, the drive
	local g
	if t < B_PLANT then
		g = 0.6 * ramp(t, B_PRESS, B_PLANT - B_PRESS)
	else
		g = max(1 - 0.3 * ramp(t, B_PLANT + 0.05, 0.4), 0.7 + 0.3 * pulseEnv)
	end
	g *= 1 - ramp(t, OFF, 0.5)
	Staff.SetGlow(c, h, g)
	cv:Tag("staff")
	BO.AURA.sparkle = t < B_PLANT + 0.1
	cv:StaffAura(tip, g, t, BO.AURA)
	for k = K0, K1 do
		local ta = h.Arr[k]
		if ta <= OFF + 0.05 then
			cv:Glint(tip + camDir(tip) * 0.05, 0.55 * env(t, ta - B_TRAVEL - 0.04, ta - B_TRAVEL + 0.22, 0.05, 0.16), 1.0,
				0.4 * t, nil, 0.45, "staff")
			cv:Flare(tip + camDir(tip) * 0.1, (t - (ta - B_TRAVEL - 0.02)) / 0.35, BO.SFL)
		end
	end
	if B_PRESS < t and t < B_PLANT + 0.1 then
		BO.GATHER.glint_size, BO.GATHER.t = 0.42 * (1 - ramp(t, B_PLANT, 0.1)), t
		cv:Gather(tip, ramp(t, B_PRESS, B_PLANT - B_PRESS - 0.04), BO.GATHER)
	end
	if B_RAISE < t and t < B_PLANT + 0.06 then
		cv:Trail(RD.trail_fn(h.DriveAt, t, 0.07, 6, B_RAISE, h.DQ), 1.0, BO.DTRAIL)
	end
	if dv then
		-- (Devil) the pulses' arrivals near now (the pit's cracks and the shaft surge); shaft_surge: a short barbed
		-- chain and embers race up the planted shaft into the head (the world staff in first person)
		local arr = h.DArr
		table.clear(arr)
		for k = K0, K1 do
			if h.Arr[k] <= OFF + 0.05 then arr[#arr + 1] = h.Arr[k] end
		end
		Forge.ShaftSurge(dv, P3 - UP * SINK, fp and plantTip or tip, t, arr, B_TRAVEL)
	end

	-- THE HEAVEN: the sky sigil 180 over the caster, the column into the palm, the stream down it (Devil: the horned
	-- gate and the column out of the pit, devilHeaven)
	cv:Tag("heaven")
	local sky = h.Sky
	local skyOpen = Config.Benediction.SkyOpenAt
	local us = ramp(t, skyOpen, 0.22, "Linear")
	local uc = 1 - ramp(t, OFF + 0.28, 0.26, "Linear")
	local pc, pn = palmOf(c)
	if dv then
		if us > 0 and uc > 0 then devilHeaven(h, cv, dv, t, us, uc, OFF, K0, K1) end
	elseif us > 0 and uc > 0 then
		local ph = 0.22 * t
		local skLv = min(1, 0.85 + 0.15 * pullEnv)
		local u1 = min(us, uc)
		BO.SKY1.a0, BO.SKY1.u, BO.SKY1.rigid = ph, u1, u1 >= 1 - 1e-6
		cv:Ring(sky, SKY_R1, UP, skLv, BO.SKY1)
		local u2 = min(ramp(t, skyOpen + 0.05, 0.2, "Linear"), uc)
		if u2 > 0 then
			BO.SKY2.a0, BO.SKY2.u, BO.SKY2.rigid = -ph + 1.0, u2, u2 >= 1 - 1e-6
			cv:Ring(sky, SKY_R2, UP, skLv, BO.SKY2)
		end
		BO.SKYRAYS.level, BO.SKYRAYS.v, BO.SKYRAYS.t = skLv, ramp(t, OFF + 0.22, 0.24), t
		cv:HolyRays(sky, ramp(t, skyOpen + 0.1, 0.26, "Linear"), BO.SKYRAYS)
		cv:Glint(sky, 6.0 * min(us, uc) * (1 + 0.12 * pullEnv), 1.0, 0.1 * t, nil, 0.45, "heaven")
		cv:Flare(sky, (t - B_PLANT) / 0.6, BO.SKYFL)
		if pc and t >= B_PLANT then
			local pz = pc + UP * 0.03
			if t <= OFF then h.POff = pz end
			local z0 = h.PalmZ0
			local lo, head
			local tCol = h.Pulls[1]
			if t < tCol then
				lo, head = sky:Lerp(pz, 1 - fallH(up01(t, B_PLANT, tCol))), 3.0
			elseif t <= OFF then
				lo, head = pz, 0
			else
				local e = up01(t, OFF, OFF + RET) ^ 2.2
				lo, head = (e < 1) and (h.POff or pz):Lerp(sky, e) or nil, 3.0
			end
			if lo then
				cv:Tag("column")
				vbeam(h, cv, lo, sky, min(1, 0.8 + 0.2 * pullEnv), colW, z0, head)
				local tw = 0.5 * t
				for j = 0, 3 do                                     -- 4 guide strands: a slim cone, turning slowly
					local a = tw + j * pi / 2 + pi / 4
					local e2 = RD.B(cos(a), sin(a), 0)
					vbeam(h, cv, lo + e2 * colR(lo.Y - z0), sky + e2 * colR(sky.Y - z0), 0.5, strandW, z0, head * 0.6)
				end
				-- glyph rings streaming down (each a whole ring that moves and shrinks: 1 piece)
				if t < tCol then
					local cc = pz:Lerp(sky, fallH(up01(t, B_PLANT, tCol)))
					BO.COL1.a0, BO.COL1.w = 3.0 * t, ringW(cc.Y - z0)
					cv:Ring(cc, colR(cc.Y - z0) * 1.3, UP, 1.0, BO.COL1)
				end
				if t <= OFF then
					for k = K0, K1 - 1 do                           -- a ring per period: sky -> palm, landing on the next pull
						local tp1 = h.Pulls[k + 1]
						if tp1 and tp1 <= OFF + 0.05 then
							local age = up01(t, h.Pulls[k], tp1)
							if age > 0 and age < 1 then
								local cc = pz:Lerp(sky, fallH(age))
								BO.COLK.a0, BO.COLK.w = 3.0 * t + k, ringW(cc.Y - z0)
								cv:Ring(cc, colR(cc.Y - z0) * 1.3, UP, 1.0, BO.COLK)
							end
						end
					end
					-- the small glyph rings: 4 per pulse period, off the beat, from the first pull to the end (computed
					-- here now: the channel is held, so there is no list to make up front)
					local j0 = max(0, floor((t - DESC - tCol) / 0.125) - 1)
					for j = j0, j0 + floor(DESC / 0.125) + 2 do
						local s0 = tCol + 0.125 * (j + 1)
						local q = (s0 - tCol) / h.Every
						local age = up01(t, s0, s0 + DESC)
						if s0 + DESC <= OFF + 1e-6 and abs(q - math.round(q)) > 1e-3 and age > 0 and age < 1 then
							local cc = pz:Lerp(sky, fallH(age))
							BO.COLS.a0, BO.COLS.w = -2.0 * t, ringW(cc.Y - z0) * 0.8
							cv:Ring(cc, colR(cc.Y - z0) * 0.95, UP, 0.6, BO.COLS)
						end
					end
					-- motes falling down the column (the kit's _cycles(t, 8, DESC, T_COL, T_OFF - DESC, 131))
					local mp, ms, mt = h.MP, h.MS, h.MT
					table.clear(mp)
					table.clear(ms)
					table.clear(mt)
					for i = 0, 7 do
						local ph0 = RD.Rand(131, i, 0x51, 1) * DESC
						local since = t - tCol - ph0
						if since >= 0 then
							local cyc = floor(since / DESC)
							local born = tCol + ph0 + cyc * DESC
							local okc = true
							if born > OFF - DESC then
								cyc -= 1
								born -= DESC
								okc = cyc >= 0 and t - born < DESC
							end
							if okc then
								local age = (t - born) / DESC
								local cc = pz:Lerp(sky, fallH(age))
								local hh = cc.Y - z0
								local a = RD.Rand(131 * 7919 + i * 131, cyc, 17, 1) * TAU + 2.0 * age
								local rr = colR(hh) * (0.25 + 0.55 * RD.Rand(131 * 7919 + i * 131, cyc, 17, 2))
								mp[#mp + 1] = cc + RD.B(cos(a), sin(a), 0) * rr
								ms[#ms + 1] = (0.07 + 0.008 * hh) * sin(pi * min(1, age * 1.15)) ^ 0.5
								mt[#mt + 1] = DOWN
							end
						end
					end
					if #mp > 0 then
						BO.MOTES.sizes, BO.MOTES.trails = ms, mt
						cv:Motes(mp, 1.0, BO.MOTES)
					end
				end
			end
		end
	end

	-- the palm (steady: the r3 pull-down is gone) and the conduit through the body into the staff head
	if pc and t >= B_PLANT then
		cv:Tag("palm")
		local alive = min(ramp(t, h.Pulls[1] - 0.02, 0.16), 1 - ramp(t, OFF, 0.2))
		if alive > 0 then
			BO.PROS.u = alive
			cv:Rosette(pc + pn * 0.03, pn, 0.5, 0.9, BO.PROS)
			cv:Glint(pc + pn * 0.2 + camDir(pc) * 0.1, (0.28 + 0.2 * pullEnv) * alive, 1.0, 0.3 * t, nil, 0.45, "palm")
			cv:LightPool(pc + pn * 0.7, 0.55 * alive + 0.5 * pullEnv, BO.PLIGHT)
		end
		for k = K0, K1 do
			local tp = h.Pulls[k]
			if h.Arr[k] <= OFF + 0.05 then
				BO.PFL.rot = 0.4 * (k - 1)
				cv:Flare(pc + pn * 0.15 + camDir(pc) * 0.15, (t - tp) / 0.35, noShock(BO.PFL, dv))
			end
		end
		cv:Tag("conduit")
		for k = K0, K1 do
			local tp = h.Pulls[k]
			local uu = up01(t, tp, tp + B_BODY)
			if h.Arr[k] <= OFF + 0.05 and ((uu > 0 and uu < 1) or (uu >= 1 and t < tp + B_BODY + 0.05)) then
				local P = conduitPath(h, c, pc, tip, fp)
				local Lp = 0
				for i = 2, #P do Lp += (P[i] - P[i - 1]).Magnitude end
				local sh = Lp * ease("Sine", min(uu, 1))
				local tail = 2.8 * (1 - ramp(t, tp + B_BODY, 0.05, "Linear"))
				local q = pathSlice(P, #P, sh - max(tail, 0.05), sh, h.CQ)
				if #q >= 2 then cv:Trail(q, 1.0, BO.CTRAIL) end
				cv:Glint(q[#q] or P[1], 0.22, 1.0, 5.0 * t, nil, 0.4, "conduit")
			end
		end
	end
	if t < B_PLANT then return true end

	-- the impact: flare, the shockwave ring, glints
	cv:Tag("impact")
	local ent = P3 + UP * 0.05
	cv:Flare(ent + camDir(ent) * 0.35, (t - B_PLANT) / 0.5, noShock(BO.IFL, dv))
	local usw = ramp(t, B_PLANT, 0.5, "Quad")
	if usw > 0 and usw < 0.99 then
		BO.IRING.w = 0.1 * (1 - usw) + 0.01
		cv:Ring(P3 + floorLift, 0.35 + 7.5 * usw, UP, 1 - 0.5 * usw, BO.IRING)
	end
	cv:Sparkles(ent, 1.2, t, BO.ISPARK)

	-- the ground: cracks, the turning sigil, pulse rings, motes, the warm light (Devil: hell_cracks out to the allies,
	-- flaring per pulse; the torn pit (pass 4) in the sigil's place, on its own timing: it seals after the column; the
	-- light low, spilling out of the pit)
	cv:Tag("ground")
	local ucr = ramp(t, B_PLANT, 0.09, "Linear") * (1 - ramp(t, OFF + 0.1, 0.22))
	local gx = nil
	if dv then
		gx = h.DCtx
		gx.TOff = OFF
		-- the cracks' allies: each bonded ally in range, its crack fixed where it stood when first seen; the list re-read
		-- each frame until the end (2026-10-13: read once at the plant, the bond list had not arrived yet -- the cracks
		-- ran at random -- and a later bond got none)
		if t < OFF then
			local list = h.AlliesFn and call(anchors.Allies, c, h.RangeC, h.Radius)
			if type(list) == "table" then
				h.DAllySeen = h.DAllySeen or {}
				for _, m in ipairs(list) do
					-- found as the bond finds it (chestOf: an R6 body has no UpperTorso)
					local p = typeof(m) == "Instance" and m ~= c and not h.DAllySeen[m] and chestOf(m)
					if p and #gx.Allies < Config.Benediction.MaxTargets then
						if Vector3.new(p.X - h.RangeC.X, 0, p.Z - h.RangeC.Z).Magnitude <= h.Radius then
							h.DAllySeen[m] = true
							gx.Allies[#gx.Allies + 1] = Vector3.new(p.X, h.FloorY, p.Z)
						end
					end
				end
			end
		end
		if ucr > 0.01 then Forge.HellCracks(dv, t, ucr, gx) end
	elseif ucr > 0.01 then
		local cl = max(1 - 0.55 * ramp(t, B_PLANT + 0.1, 0.35), 0.45 + 0.4 * pulseEnv)
		for ci = 1, #CRACKS do
			local qq = cutInto(h.CrackW[ci], 5, ucr, h.CrackQ)
			if #qq >= 2 then
				local Lc = 0
				for i = 2, #qq do Lc += (qq[i] - qq[i - 1]).Magnitude end
				BO.CRACK.taper[2] = min(0.5, Lc * 0.4)
				cv:Stroke(qq, cl, BO.CRACK)
			end
		end
	end
	local usg = ramp(t, B_PLANT, 0.14, "Linear")
	local sk = 1 - ramp(t, OFF + 0.19, 0.24)
	if dv then
		if usg > 0.005 then Forge.HellGround(dv, t, gx) end
	elseif usg > 0.005 and sk > 0.02 then
		local ls = max(1 - 0.52 * ramp(t, B_PLANT + 0.12, 0.3), 0.48 + 0.4 * pulseEnv)
		sigilRot(cv, P3 + floorLift, SIG_R * sk, ls, usg, 0.25 * (t - B_PLANT) + 2.5 * (1 - sk) ^ 2, "ground")
	end
	for k = K0, K1 do
		local ta = h.Arr[k]
		local ur = up01(t, ta - B_TRAVEL, ta - B_TRAVEL + 0.3)
		if ta <= OFF + 0.05 and ur > 0 and ur < 1 then
			BO.PRING.w = 0.07 * (1 - ur) + 0.01
			cv:Ring(P3 + floorLift * 1.3, 0.5 + (SIG_R - 0.5) * ease("Quad", ur), UP, 1 - 0.3 * ur,
				BO.PRING)
		end
	end
	BO.GMOTE.t1 = OFF - 0.3
	cv:MoteField(P3, SIG_R * 0.95, t, BO.GMOTE)
	cv:Tag("light")
	local pl = (1.6 * env(t, B_PLANT - 0.02, B_PLANT + 0.8, 0.04, 0.6) + 0.75 + 0.35 * pulseEnv) * (1 - ramp(t, OFF, 0.45))
	if dv then
		cv:LightPool(P3 + UP * 0.3, pl * 1.3, BO.LIGHT)
	else
		cv:LightPool(P3 + UP * 1.2, pl, BO.LIGHT)
	end

	-- the range ring: runs out to the heal radius (round the server's heal centre), locks, runs back in
	cv:Tag("range")
	local rr
	local T_R0, T_R1 = B_PLANT + 0.13, B_PLANT + 0.45
	if t >= T_R0 and t <= OFF + 0.18 then
		if t <= OFF then
			rr = SIG_R + (h.Radius - SIG_R) * ease("Quint", up01(t, T_R0, T_R1))
		else
			rr = h.Radius - (h.Radius - SIG_R) * ease("Quad", up01(t, OFF, OFF + 0.18))
		end
		local locked = t >= T_R1 and t <= OFF
		BO.RANGE.ticks, BO.RANGE.rigid, BO.RANGE.w = locked and 24 or 0, locked, locked and 0.22 or 0.14
		cv:Ring(h.RangeC + floorLift, rr, UP, locked and 0.4 or 1.0, BO.RANGE)
	end

	-- the Bond threads staff head -> allies in range, the heal comets on each pulse, the seal at the ally (Devil:
	-- chain_bond -- an ember chain sliding to the ally; pact_seal -- the carved seal stamped under it)
	cv:Tag("bond")
	if h.AlliesFn and not h.AlliesDone and t >= T_R0 then
		h.AlliesDone = true
		local list = call(anchors.Allies, c, h.RangeC, h.Radius)
		if type(list) == "table" then
			for _, m in ipairs(list) do
				local ch = chestOf(m)
				if ch and m ~= c and not h.Targets[m] and h.NT < Config.Benediction.MaxTargets then
					local dist = Vector3.new(ch.X - h.RangeC.X, 0, ch.Z - h.RangeC.Z).Magnitude
					if dist <= h.Radius then
						-- when the running-out range ring reaches it
						local tb = T_R0
						while tb < T_R1 and SIG_R + (h.Radius - SIG_R) * ease("Quint", up01(tb, T_R0, T_R1)) < dist do
							tb += 0.004
						end
						h.NT += 1
						h.Targets[m] = { Since = tb }
					end
				end
			end
		end
	end
	for m, rec in pairs(h.Targets) do
		local ch = chestOf(m)
		if ch then
			local u = min(ramp(t, rec.Since, 0.16, "Linear"), 1 - ramp(t, OFF, 0.12, "Linear"))
			if u > 0 then
				local dst = RD.ReceivePoint(ch, tip)
				local Dv = dst - tip
				local L = Dv.Magnitude
				if L > 0.3 then
					local d = Dv / L
					if dv then
						if not rec.Ord then                          -- the ally's forms (its chain, its seal)
							h.DN += 1
							rec.Ord = h.DN
						end
						Forge.ChainBond(dv, rec.Ord, tip, dst, u, t)
					else
						cv:Bond(tip, dst, u, 0.45, BO.BOND)
					end
					local ls = 0
					for k = K0, K1 do
						local ta = h.Arr[k]
						if ta <= OFF + 0.05 then
							local fpr = up01(t, ta - B_TRAVEL, ta)
							if fpr > 0 and fpr < 1 and u >= 1 and rec.Since <= ta - B_TRAVEL then
								local a2, b2 = max(0, L * fpr - 1.3), L * fpr
								local tq = h.TQ
								for k = 0, 5 do tq[k + 1] = tip + d * (a2 + (b2 - a2) * k / 5) end
								cv:Trail(tq, 1.0, BO.BTRAIL)
								cv:Glint(tip + d * b2, 0.22, 1.0, 3.0 * t, nil, 0.4, "bond")
							end
							ls = max(ls, env(t, ta, ta + 0.3, 0.03, 0.2))
						end
					end
					if u > 0.9 then
						if dv then                                   -- on the floor under the ally's root
							local mr = part(m, "HumanoidRootPart")
							local rp = mr and mr.Position or ch
							Forge.PactSeal(dv, rec.Ord, rp - UP * Config.RootHeight, 0.5 + 0.5 * ls, min(1, (u - 0.9) / 0.1))
						else
							BO.BROS.u = min(1, (u - 0.9) / 0.1)
							cv:Rosette(dst, d, 0.28, 0.5 + 0.5 * ls, BO.BROS)
						end
					end
				end
			end
		end
	end

	-- the healed: a flare at the chest, a ring rising round the body, motes (per Pulse message)
	cv:Tag("healed")
	for i = #h.Heals, 1, -1 do
		local hr = h.Heals[i]
		if t > hr.T + 0.95 then
			table.remove(h.Heals, i)
		else
			local m = hr.Model
			local ch = chestOf(m)
			local mr = part(m, "HumanoidRootPart")
			if ch then
				local dst = (m == c) and ch or RD.ReceivePoint(ch, tip)
				BO.HFL.rot = 0.3 * hr.K
				cv:Flare(dst, (t - hr.T) / 0.4, noShock(BO.HFL, dv))
				local uh = up01(t, hr.T, hr.T + 0.45)
				local fyA = (mr and mr.Position.Y or ch.Y) - Config.RootHeight
				if dv then                                           -- the heal lands: embers rise (not a ring)
					BO.DHSPARK.seed, BO.DHSPARK.t0, BO.DHSPARK.t1 = 150 + hr.K, hr.T, hr.T + 0.1
					cv:Sparkles(Vector3.new(ch.X, fyA + 1.4, ch.Z), 0.8, t, BO.DHSPARK)
				elseif uh > 0 and uh < 1 then
					BO.HRING.w = 0.07 * (1 - uh) + 0.01
					cv:Ring(Vector3.new(ch.X, fyA + 0.15 + 4.4 * ease("Quad", uh), ch.Z), 1.3 * (1 - 0.25 * uh), UP,
						0.9 - 0.4 * uh, BO.HRING)
				end
				BO.HMOTE.seed, BO.HMOTE.t0, BO.HMOTE.t1 = 97 + i, hr.T, hr.T + 0.1
				cv:MoteField(Vector3.new(ch.X, fyA + 0.1, ch.Z), 0.8, t, BO.HMOTE)
			end
		end
	end

	-- the pull-out: a flare at the hole, glints, motes
	cv:Tag("pullout")
	local hole = P3 + UP * 0.05
	cv:Flare(hole + camDir(hole) * 0.3, (t - T_OUT) / 0.4, noShock(BO.OFL, dv))
	BO.OSPARK.t0, BO.OSPARK.t1 = T_OUT, T_OUT + 0.08
	cv:Sparkles(hole, 0.5, t, BO.OSPARK)
	BO.OMOTE.t0, BO.OMOTE.t1 = T_OUT, T_OUT + 0.2
	cv:MoteField(hole, 0.35, t, BO.OMOTE)
	return true
end

--- `resume`: a channel whose effect timed out here and ended while the server kept channelling starts again on the
--- same Start, at the server's clock now (the wind-up and the impact are over; the missed-End clock counts from now).
function Staff.BenedictionStart(d, resume)
	local c = type(d) == "table" and d.Character
	if not c then return end
	local old = benes[c]
	if old and not old.Dead then old.Effect:Stop() end
	local root = part(c, "HumanoidRootPart")
	local at = typeof(d.At) == "Vector3" and d.At or (root and root.Position)
	if not at then return end
	local yaw = root and yawCF(root) or CFrame.new(at)
	local rp = rayParamsFor(c)
	local fy = floorBelow(at, rp, 12) or (at.Y - Config.RootHeight)
	local B = Config.Benediction
	local h = setmetatable({
		C = c, T = B_PLANT, FloorY = fy, Targets = {}, NT = 0, Heals = {}, VQ = {}, VP = {}, CP = {}, CQ = {}, TQ = {},
		DQ = {}, MP = {}, MS = {}, MT = {}, CrackW = {}, CrackQ = {}, Small = {}, Arr = {}, Pulls = {},
	}, Bene)
	-- HELD (2026-09-30): open until RadiantBenedictionEnd (or the missed-End timeout); a pulse every Every clip s
	h.Every = (type(d.Every) == "number" and d.Every > 0) and d.Every * RD.TimeScale()
		or tnum("Benediction", "PulseEvery", 0.5)
	h.Timeout = tnum("Benediction", "EndTimeout", 1.5)
	h.Radius = tnum("Benediction", "Radius", 25)
	bene_pulses(h, B_PLANT + 2 * h.Every)
	h.OffSched = OPEN
	local pp = RD.Body(yaw, B.PlantRight, 0, B.PlantFwd)
	h.Plant = Vector3.new(pp.X, fy, pp.Z)
	h.RangeC = Vector3.new(at.X, fy, at.Z)
	local sp = RD.Body(yaw, B.PalmRight, 0, B.PalmFwd)
	h.Sky = Vector3.new(sp.X, fy + B.SkyHeight, sp.Z)
	h.PalmZ0 = fy + B.PalmHeight
	for ci, cr in ipairs(CRACKS) do                            -- the cracks, turned with the caster (the demo faced -Y)
		local w = {}
		for k, p in ipairs(cr) do
			w[k] = h.Plant + UP * Config.FloorLift + yaw:VectorToWorldSpace(RD.B(p[1], p[2], 0))
		end
		h.CrackW[ci] = w
	end
	local plantTip = h.Plant + UP * (Config.StaffTipZ - Config.StaffButtZ - SINK)
	h.DriveAt = function(tt)                                   -- the drive: lifted LIFT_R, driven down (u^1.6)
		return plantTip + UP * (LIFT_R * (1 - up01(tt, B_RAISE, B_PLANT) ^ 1.6))
	end
	h.AlliesFn = anchors.Allies ~= nil
	local scale = RD.TimeScale()
	local T0 = type(d.T0) == "number" and d.T0 or RD.ServerNow()
	-- the WIND-UP (2026-09-30): WindUp real s from the press to the plant (T0) map onto the authored B_PRESS..B_PLANT,
	-- so the gather, the drive and the impact land with the staff whatever the tuning (no WindUp: the old 1:1 clock)
	local wind = (type(d.WindUp) == "number" and d.WindUp > 0) and d.WindUp * scale or nil
	local function clock()
		local r = (RD.ServerNow() - T0) * scale
		if r >= 0 or not wind then return B_PLANT + r end
		return B_PLANT + r * (B_PLANT - B_PRESS) / wind
	end
	h.Start = d
	if resume then
		h.T = max(B_PLANT, clock())
		h.LastPulseT = h.T
	end
	h.Effect = play("RadiantBenediction", function(cv, t, dt)
		return devilFrame(h, beneFrame, cv, t, dt)
	end, {
		Clock = clock,
		MaxLife = HUGE,                                          -- open-ended: beneFrame ends it (the End, or the timeout)
		OnEnd = function(e)
			live[e] = nil
			h.Dead = true
			Staff.SetGlow(c, h, nil)
			if benes[c] == h then benes[c] = nil end
			if h.Dv then h.Dv:Destroy() end
		end,
	})
	h.Dv = devilScope(h.Effect.Canvas.Palette, "Benediction")
	if h.Dv then                                               -- the pulses near now, the column's surges, the ground's ctx
		h.DArr, h.DSurge, h.DN = {}, {}, 0
		h.DCtx = { Plant = h.Plant, Caster = h.RangeC, TOff = OPEN, TPlant = B_PLANT, Ret = RET, Allies = {}, Arr = h.DArr,
			Travel = B_TRAVEL }
		h.ColBase, h.ColTop, h.ColH = h.Plant, h.Plant, 1
		h.EmberAt = function(rnd)                              -- the embers racing up the column's first 40 studs
			local p = h.ColBase:Lerp(h.ColTop, rnd() * min(1, 40 / h.ColH))
			return p + Vector3.new(rnd() * 1.2 - 0.6, 0, rnd() * 1.2 - 0.6)
		end
	end
	benes[c] = h
	beneLast[c] = h
end

function Staff.BenedictionPulse(d)
	local c = type(d) == "table" and d.Character
	local h = c and benes[c]
	-- the missed-End timeout is provisional (2026-09-30 review): a pulse after it means the server is still channelling
	-- (a stall past Every + Timeout). Still drawing: the let-go is taken back. Already over: it starts again, once.
	local L = c and beneLast[c]
	if L and L.Reason == "Timeout" and L.EndT then
		if L == h and not h.Dead then
			h.EndT, h.Reason = nil, nil
		elseif not L.Resumed and L.Start then
			L.Resumed = true
			Staff.BenedictionStart(L.Start, true)
			h = benes[c]
		end
	end
	if not h or h.Dead then return end
	local n = type(d.N) == "number" and d.N or 0
	bene_pulses(h, B_PLANT + (n + 1) * h.Every)
	local ta = h.Arr[n]
	local at = (ta and abs(h.T - ta) < 0.3) and ta or h.T
	h.LastPulseT = max(h.LastPulseT or 0, h.T)                -- the missed-End timeout counts from the latest pulse
	if d.Self then
		h.Heals[#h.Heals + 1] = { Model = c, T = at, K = n }
		return
	end
	if type(d.Targets) ~= "table" then return end
	for _, m in ipairs(d.Targets) do
		if typeof(m) == "Instance" and m ~= c then
			if not h.Targets[m] and h.NT < Config.Benediction.MaxTargets then
				h.NT += 1
				h.Targets[m] = { Since = h.T }
			end
			if h.Targets[m] then h.Heals[#h.Heals + 1] = { Model = m, T = at, K = n } end
		end
	end
end

function Staff.BenedictionEnd(d)
	local c = type(d) == "table" and d.Character
	local h = c and benes[c]
	if h and not h.Dead and not h.EndT then
		h.EndT = h.T
		h.Reason = d.Reason
	end
end

----------------------------------------------------------------------------------------------------
-- the broadcast kinds this module draws
----------------------------------------------------------------------------------------------------
Staff.Handlers = {
	RadiantHaloCharge = Staff.HaloCharge,
	RadiantHaloCancel = Staff.HaloCancel,
	RadiantHaloStart = Staff.HaloStart,
	RadiantHaloEnd = Staff.HaloEnd,
	RadiantBenedictionStart = Staff.BenedictionStart,
	RadiantBenedictionPulse = Staff.BenedictionPulse,
	RadiantBenedictionEnd = Staff.BenedictionEnd,
}

return Staff

--[[
	VoltaicFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/VoltaicFX

	The Voltaic kit's client visuals. Voltaic is castable since 2026-09-25: VoltaicClient.Handlers (merged into AbilityFX)
	route the CascadeGather / CascadeStrike / CascadeEnd broadcasts to this module, and the server's VoltaicHandler
	REQUIRES it to read Tuning.Cascade (Strikes, ZoneRadius, BellyHeight). So nothing at its top level may touch
	Players.LocalPlayer, the camera or an untimed WaitForChild: every require here is lazy, inside a function. The rest of
	the kit draws from its own modules (ChainBoltFX, OverchargeFX, RailspikeFX, VoltOrbFX, CascadeFX, the shared
	VoltaicKit).
	Ground Surge v3 below is kept but UNWIRED: Volt Orb took its Technique slot. What it holds:

	GROUND SURGE, v3 (2026-09-23) -- the four-pole rectangle cage. THE KIT'S ONE REALISTIC-LIGHTING EXCEPTION.
	The owner waived the comic pipeline for this ability alone (Opus5-5_Voltaic_GroundSurge_Rework): Neon poles, Beam
	arcs, transparent glowing particles and PointLights, in Voltaic's colours. v1 (the dot field + centre node + ring of
	arcs) and v2 (the crown wall + charging glyph) are discarded whole, meshes and all. The rest of the kit has since been
	re-lit in its own modules (ChainBoltFX, VoltOrbFX, OverchargeFX, RailspikeFX, CascadeFX), each to its own showcase;
	do not copy this section's technique into them.
	Four beats, all driven from here (vfx_blocking/voltaic/INTEGRATION_ground_surge_v3.md is the wiring spec):
	  1 AIM        GroundSurgePreview(point, yaw) / GroundSurgePreviewEnd(locked) -- the caster's own thin outline;
	  2 PLACEMENT  GroundSurgePlant(data) -- four bolts strike the corners and stand as poles;
	  3 ARMED      (the same handle) arcs crackle along the four edges and crawl the floor, surging harder to the end;
	  4 DISCHARGE  (the same handle, on its own clock, or at once on :Pop()) -- the zap, then the poles retract.
	The review render (blender_scripts/voltaic/ground_surge3_bl.py) PARSES Tuning.GroundSurge out of this file and
	replays this logic, so the numbers below are the render's numbers.

	CASCADE, RE-LIT (2026-09-27) -- the Ultimate. The comic build that lived here (2026-09-25: the 22 VT3_Cascade_* toon
	meshes, VFXLibrary's Cascade emitters) is replaced whole by the re-lit port of blender_scripts/voltaic/cascade_bl.py
	in ReplicatedStorage.IceMagic.CascadeFX. What stays HERE:
	  * Tuning.Cascade, the storm's CLOCK and ZONE, which the server reads (Strikes, ZoneRadius, BellyHeight) and
	    CascadeFX is handed (Windup, StormStrikes). Windup puts the caster's windup in front of the storm: Strikes (from
	    the key, what VoltaicHandler schedules) = Windup + StormStrikes, so the damage moved with the storm; Windup = 0
	    is the comic build's timing exactly;
	  * the three broadcast handlers, now a thin hand-off to CascadeFX (the CASCADE section at the end of this file),
	    CascadeFX required lazily and on a client only;
	  * the ARCSTORM! payoff stays the server's (VoltaicHandler -> Callouts.Pop "arcstorm").
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local VoltaicFX = {}

----------------------------------------------------------------------------------------------------
-- Cascade's CLOCK and ZONE (the look's numbers are CascadeFX.Tuning). The server reads Strikes / ZoneRadius /
-- BellyHeight from here (VoltaicHandler cascadeNumbers), the harness reads Strikes / ZoneRadius, and CascadeFX is handed
-- the whole table. EVERY NUMBER IS A PROPOSAL; damage and range are VoltaicTuning.Cascade's.
----------------------------------------------------------------------------------------------------
VoltaicFX.Tuning = {
	Cascade = {
		-- THE WINDUP (the re-lit build, 2026-09-27): both arms go up over the head and the charge leaves the hands this long
		-- after the key; the storm's own clock (S) starts then. 0 puts the storm back on the key: the comic build's timing.
		Windup = 0.50,
		-- the five strikes on the STORM's clock, the comic build's (0.067 / 0.067 / 0.100 / 0.067 apart): 1-4 are the
		-- fan's ground forks re-striking, 5 the dominant bolt's contact (the hitpause is held on it, visuals only)
		StormStrikes = { 1.2333, 1.3000, 1.3667, 1.4667, 1.5333 },
		-- Strikes: seconds from the CAST (T0, the key) -- what VoltaicHandler schedules and the harness fakes. Filled just
		-- below as Windup + StormStrikes (1.7333 / 1.80 / 1.8667 / 1.9667 / 2.0333 at Windup 0.50).
		BellyHeight = 14.0,            -- studs from the marked ground point to the cloud's belly plane
		ZoneRadius = 11.0,             -- the strike zone (INTEGRATION.md's earlier proposal, carried over)
	},
}
do
	local C = VoltaicFX.Tuning.Cascade
	C.Strikes = {}
	for i, s in ipairs(C.StormStrikes) do C.Strikes[i] = C.Windup + s end
end

----------------------------------------------------------------------------------------------------
-- GROUND SURGE v3: the numbers. Seconds are from the cast (the server's T0) unless named. EVERY NUMBER IS A PROPOSAL
-- (2026-09-23) except the two kept from v1/v2: the 0.38 s lead-in (matched to Flash Freeze) and the 0.90 s arm, so
-- the zap still lands at 1.28 s. The zone SHAPE is new and is the owner's call -- see Width/Depth.
----------------------------------------------------------------------------------------------------
VoltaicFX.Tuning.GroundSurge = {
	-- THE ZONE. A rectangle, its long side ACROSS the caster's aim, with the SAME AREA as the old 7.0-stud ring
	-- (153.9 studs^2 -> 14 x 11 = 154): the zone neither grew nor shrank, it changed shape. The server's instant ring
	-- test becomes a box test on these half-extents (7.0 x 5.5) -- flagged, not decided here.
	Width = 14.0, Depth = 11.0,

	-- 1 AIM: the caster's own preview (untimed -- it lasts as long as they aim)
	PreviewLine = 0.10,            -- studs wide, the outline
	PreviewTall = 0.04,
	PreviewCorner = 1.6,           -- each corner bracket's arms, studs -- marks where a pole will land
	PreviewCornerLine = 0.20,
	PreviewLift = 0.05,
	PreviewTransparency = { 0.30, 0.55 },   -- pulses between these
	PreviewPulseHz = 1.6,
	LockFlash = 0.08, LockFade = 0.22, LockWiden = 1.6,   -- on the confirm: it snaps bright and wide, then goes

	-- 2 PLACEMENT: four bolts strike the corners, clockwise from the far-left one, and stand as poles
	Lands = { 0.20, 0.26, 0.32, 0.38 },     -- the last lands on the lead-in and closes the cage
	Leader = 0.06,                 -- the stepped leader drawing down before each lands
	StrikeFrom = 34,               -- studs above the ground the strike leaves from
	StrikeDrift = 3.5,             -- ...and this far off to one side of it
	StrikeAmp = 3.2,               -- the strike's biggest sideways kick
	ReturnStroke = 0.07,           -- the whole channel held at full after it lands
	SkyFade = 0.10,                -- then the part above the pole goes
	StrikeCore = { 0.10, 0.45 }, StrikeGlow = { 0.9, 4.0 }, StrikeBright = { 4, 12 },  -- leader, return stroke
	PoleHeight = 5.0,              -- a 5-stud body's height: a fence post, not a banner
	PoleWidth = 0.26, PoleKink = 0.16,
	PoleIn = 0.10, PoleInWiden = 1.8,       -- lands fat and settles
	PoleGlowWidth = { 1.6, 1.0 }, PoleAuraWidth = { 3.0, 2.0 },
	ImpactSparks = 18, ImpactDust = 4,
	LandPunch = 0.10, ClosePunch = 0.16, PunchReach = 60,
	LandLight = { 3.5, 16, 0.14 }, -- Brightness, Range, life of each landing's flash (7 washed a white map out)

	-- 3 ARMED: ArmFrom = the lead-in, unchanged
	ArmFrom = 0.38, ArmTime = 0.90,
	Ramp = 1.7,                    -- u ^ Ramp: the surge builds slowly, then hard at the end
	Reroll = { 0.055, 0.020 },     -- seconds between re-jags, calm -> frantic
	EdgeArcs = { 1, 3 },           -- arcs per edge
	EdgeAmp = 0.09,                -- sideways kick, x the arc's length
	EdgeDrop = 0.15,               -- the chance an edge arc skips a tick -- a crackle has gaps
	-- (the first in-engine look had 0.07-0.11 cores and 0.8-1.3 glows: pale wire against a bright sky -- doubled up)
	EdgeCore = { 0.10, 0.16 }, CoreBright = { 4.0, 8.0 }, GlowWidth = { 1.0, 1.7 }, GlowBright = { 1.6, 3.2 },
	CrawlRate = { 4, 20 },         -- interior arcs born per second
	CrawlLife = { 0.22, 0.12 },
	CrawlLen = { 2.5, 6.0 },
	CrawlSpeed = 9,                -- studs/s a crawler's foot slides across the floor
	CrawlArch = 0.6,               -- studs a crawler bows up off the floor
	LeapShare = 0.25,              -- the share of interior arcs that leap pole to pole across the zone instead
	CrawlCore = 0.09, CrawlGlow = 1.2,
	PoleLight = { 0.5, 1.4, 10 },  -- Brightness calm -> frantic, Range (3.5 lit the whole Hub floor yellow in Studio)
	PoleSparkRate = { 4, 28 },
	PoleFlicker = { 0.15, 0.45 },
	FloorLine = { 0.55, 0.15 },    -- the ground edge line's Transparency, calm -> frantic
	FloorLineWidth = 0.10,

	-- 4 DISCHARGE, at ArmFrom + ArmTime (1.28 s): the zap
	DischargeLife = 0.36,
	Restrikes = { 0.09, 0.19 },    -- the centre bolt goes dark and strikes again twice, as a real strike does
	RestrikeLife = { 0.07, 0.05, 0.04 }, RestrikeBright = { 1.0, 0.75, 0.5 },
	CentreCore = 0.9, CentreGlow = 6.0, CentreBright = 16,   -- (0.45 / 3.4 read as a thin wire from 17 studs)
	PoleBolts = 0.14,              -- every pole fires into the centre, this long
	WebArcs = 10, WebLife = 0.24, WebReroll = 0.03,
	CentreLight = { 5, 22, 0.30 },  -- (12 / 28 turned the whole screen white-yellow in Studio: a flash, not a flood)
	FountainSparks = 60, DischargeSmoke = 10, DischargeDust = 6,
	DischargePunch = 0.24,

	-- 5 RETRACT: the poles cool and sink back into the ground
	RetractTime = 0.50,
	EmberFor = 0.45,
	Cleanup = 3.4,                 -- everything, the last smoke included, is gone by here
}

----------------------------------------------------------------------------------------------------
-- plumbing
----------------------------------------------------------------------------------------------------
local T = VoltaicFX.Tuning
local VFXLibrary, Settings, Viewmodel = nil, nil, nil
local function libs()
	if VFXLibrary then return end
	local ice = ReplicatedStorage:WaitForChild("IceMagic")
	VFXLibrary = require(ice:WaitForChild("VFXLibrary"))
	Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))
	local ok, vm = pcall(require, ice:WaitForChild("Viewmodel"))
	Viewmodel = ok and vm or nil
end

-- Voltaic's shipped colours (SpellshotConfig.Elements.Voltaic)
local COL = {
	Base = Color3.fromRGB(245, 199, 15), Light = Color3.fromRGB(255, 245, 115), Dark = Color3.fromRGB(74, 26, 140),
}
-- Yellow is mostly ALPHA-BLENDED: additive yellow over a blue sky sums to white (Cascade's realistic test). Brightness
-- carries it past the place's Bloom threshold instead. The violet halo is allowed more add -- it is a glow on the floor.
local YELLOW_EMISSION = 0.25
local VIOLET_EMISSION = 0.3
local GLOW_TEX = "rbxasset://textures/particles/explosion01_implosion_main.dds"    -- = VFXLibrary.Config.Textures.Glow
local GLOW_ALPHA = 0.85                     -- a glow beam's opacity at a core's full strength (0.65 vanished on a bright map)
local POLE_TAPER = { 1.0, 0.9, 0.78, 0.55 } -- the pole's four segments, foot to tip

local function lerp(a, b, u) return a + (b - a) * u end
local function clamp01(x) return math.clamp(x, 0, 1) end
local function span(t, a, b) return clamp01((t - a) / (b - a)) end
local function easeOutCubic(u) return 1 - (1 - u) ^ 3 end
local function easeInQuad(u) return u * u end
local function pair(p, u) return lerp(p[1], p[2], u) end

local function fxFolder()
	local name = VFXLibrary.Config.FXFolderName
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local function inert(p)
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow, p.Massless = true, false, false, false, false, true
	return p
end

--- An invisible, inert, anchored Part: a host for attachments, emitters and lights.
local function host(name, size, cf, parent)
	local p = inert(Instance.new("Part"))
	p.Name, p.Size, p.Transparency, p.CFrame = name, size, 1, cf
	p.Parent = parent
	return p
end

--- A glowing Neon part (the poles, the floor line, the preview).
local function neon(name, color, parent)
	local p = inert(Instance.new("Part"))
	p.Name, p.Material, p.Color, p.TopSurface, p.BottomSurface = name, Enum.Material.Neon, color,
		Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Size = Vector3.new(0.2, 0.2, 0.2)
	p.Transparency = 1
	p.Parent = parent
	return p
end

local function attach(parent, worldPos)
	local a = Instance.new("Attachment")
	a.Parent = parent
	a.WorldPosition = worldPos
	return a
end

--- A camera punch for whoever is near, fading to nothing at `reach` studs -- through the Viewmodel's own punch, so
--- the Camera Shake setting scales it and Reduce Flashing takes it away (TerraFX.CameraPunch, same rule).
local function punchNear(position, amount, reach)
	local cam = workspace.CurrentCamera
	if not (Viewmodel and Viewmodel.Punch and cam) then return end
	local d = (cam.CFrame.Position - position).Magnitude
	if d >= reach then return end
	Viewmodel.Punch(amount * (1 - d / reach))
end

----------------------------------------------------------------------------------------------------
-- ARCS: a jagged polyline drawn as a camera-facing Beam per segment -- a hot core and a soft glow along the same
-- points. Pooled per cage: the points move only when the arc RE-JAGS (that step IS the crackle -- frame-stepped, never
-- interpolated); its look is set every frame, but only when it changed.
----------------------------------------------------------------------------------------------------
local function newBeam(a0, a1, color, emission, soft, parent)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = 1
	b.CurveSize0, b.CurveSize1 = 0, 0
	b.Color = ColorSequence.new(color)
	b.LightEmission, b.LightInfluence = emission, 0
	if soft then
		-- the soft disc stretched along its segment, so it fades at its ends as well as its sides and a bolt's segments
		-- overlap into one glowing line (a band that fades only across its width draws each segment as a bar: the
		-- realistic Cascade's bolts came out as ladders)
		b.Texture = GLOW_TEX
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
	end
	b.Enabled = false
	b.Parent = parent
	return b
end

local function newArc(parent, maxPts, glowColor, glowEmission)
	local A = { atts = {}, core = {}, glow = {}, max = maxPts, n = 0, shown = 0, on = false }
	for i = 1, maxPts do
		local at = Instance.new("Attachment")
		at.Parent = parent
		A.atts[i] = at
	end
	for i = 1, maxPts - 1 do
		A.core[i] = newBeam(A.atts[i], A.atts[i + 1], COL.Light, YELLOW_EMISSION, false, parent)
		A.glow[i] = newBeam(A.atts[i], A.atts[i + 1], glowColor, glowEmission, true, parent)
	end
	return A
end

local function arcShape(A, pts)
	local n = math.min(#pts, A.max)
	for i = 1, n do A.atts[i].WorldPosition = pts[i] end
	A.n = n
end

local function arcHide(A)
	if A.shown == 0 then return end
	for i = 1, A.shown do
		A.core[i].Enabled = false
		A.glow[i].Enabled = false
	end
	A.shown = 0
	A.look = nil
end

--- The arc's look: core and glow widths, their Brightness, a Transparency (0 = full), and `reveal` (0..1: the share
--- of its segments drawn from the first point -- a leader drawing down; nil = all).
local function arcLook(A, coreW, glowW, coreB, glowB, tr, reveal)
	local segs = A.n - 1
	local shown = reveal and math.clamp(math.ceil(segs * clamp01(reveal) - 1e-6), 0, segs) or segs
	if shown <= 0 or coreW <= 0.002 or tr >= 0.995 then
		arcHide(A)
		return
	end
	local L = A.look
	if L and L[1] == shown and math.abs(L[2] - coreW) < 0.004 and math.abs(L[3] - glowW) < 0.01
		and math.abs(L[4] - coreB) < 0.05 and math.abs(L[5] - glowB) < 0.05 and math.abs(L[6] - tr) < 0.01 then
		return
	end
	A.look = { shown, coreW, glowW, coreB, glowB, tr }
	local ct = NumberSequence.new(tr)
	local gt = NumberSequence.new(1 - (1 - tr) * GLOW_ALPHA)
	for i = 1, A.max - 1 do
		local c, g = A.core[i], A.glow[i]
		if i <= shown then
			c.Width0, c.Width1, c.Brightness, c.Transparency = coreW, coreW, coreB, ct
			g.Width0, g.Width1, g.Brightness, g.Transparency = glowW, glowW, glowB, gt
			c.Enabled, g.Enabled = true, true
		elseif i <= A.shown then
			c.Enabled, g.Enabled = false, false
		end
	end
	A.shown = shown
end

--- A random unit vector square to `d`; `flatten` (0..1) squashes its vertical part (arcs that hug the floor).
local function perp(d, rng, flatten)
	local r = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	local p = r - d * r:Dot(d)
	if flatten then p = Vector3.new(p.X, p.Y * flatten, p.Z) end
	if p.Magnitude < 1e-4 then p = d:Cross(Vector3.yAxis) end
	if p.Magnitude < 1e-4 then p = d:Cross(Vector3.xAxis) end
	return p.Unit
end

--- Lightning's shape: midpoint displacement, `depth` halvings (2^depth segments), each midpoint kicked sideways by up
--- to `amp`, halving to 0.55 of it per level -- big jogs with finer crackle inside them, never a sawtooth. `floorY`
--- keeps it above the ground. Appends to `out` (which should already hold `a`) and returns it.
local function jag(a, b, depth, amp, rng, floorY, flatten, out)
	out = out or { a }
	local function sub(p, q, dep, am)
		if dep == 0 then
			out[#out + 1] = q
			return
		end
		local d = q - p
		local len = d.Magnitude
		local m = (p + q) / 2
		if len > 1e-4 then m += perp(d / len, rng, flatten) * rng:NextNumber(0.35, 1) * am end
		if floorY and m.Y < floorY then m = Vector3.new(m.X, floorY + (floorY - m.Y) * 0.3, m.Z) end
		sub(p, m, dep - 1, am * 0.55)
		sub(m, q, dep - 1, am * 0.55)
	end
	sub(a, b, depth, amp)
	return out
end

----------------------------------------------------------------------------------------------------
-- 1 AIM: the preview. Caster-local; the input layer calls it every frame between the first press and the second
-- (INTEGRATION_ground_surge_v3.md section 1). A thin outline plus corner brackets marking where the poles will land --
-- lightweight on purpose: no light, no particle, no arc.
----------------------------------------------------------------------------------------------------
local preview = nil

local function previewParts()
	libs()
	local K = T.GroundSurge
	if preview and preview.folder.Parent then return preview end
	local f = Instance.new("Folder")
	f.Name = "GroundSurgePreview"
	f.Parent = fxFolder()
	preview = { folder = f, edges = {}, arms = {}, born = os.clock(), widen = 1, alpha = nil }
	for i = 1, 4 do preview.edges[i] = neon("Edge", COL.Base, f) end
	for i = 1, 8 do preview.arms[i] = neon("Corner", COL.Base, f) end
	return preview
end

local function previewPose(pv, point, yaw, widen, transparency)
	local K = T.GroundSurge
	local cf = CFrame.new(point + Vector3.new(0, K.PreviewLift, 0)) * CFrame.Angles(0, yaw, 0)
	local hw, hd = K.Width / 2, K.Depth / 2
	local c = { Vector3.new(-hw, 0, -hd), Vector3.new(hw, 0, -hd), Vector3.new(hw, 0, hd), Vector3.new(-hw, 0, hd) }
	local lw, cw, tall = K.PreviewLine * widen, K.PreviewCornerLine * widen, K.PreviewTall
	for i = 1, 4 do
		local a, b = c[i], c[i % 4 + 1]
		local e = pv.edges[i]
		e.Size = Vector3.new(lw, tall, (b - a).Magnitude)
		e.CFrame = cf * CFrame.lookAt((a + b) / 2, b)
		e.Transparency = transparency
		-- the corner bracket at `a`: an arm along each of its two edges
		local prev = c[(i + 2) % 4 + 1]
		for k, toward in ipairs({ b, prev }) do
			local dir = (toward - a).Unit
			local arm = pv.arms[(i - 1) * 2 + k]
			local len = K.PreviewCorner
			arm.Size = Vector3.new(cw, tall * 1.5, len + cw / 2)
			arm.CFrame = cf * CFrame.lookAt(a + dir * (len / 2 - cw / 4), toward)
			arm.Transparency = transparency * 0.6
		end
	end
end

--- Shows or moves the preview: the ground point under the crosshair (SpellshotInput's ringCentre, pulled in to the
--- ability's Range) and the caster's aim yaw (VoltaicFX.GroundSurgeYaw). Call it every frame while aiming. `now`
--- (REVIEW ONLY) replaces os.clock() for the pulse, so a slowed review slows it too.
function VoltaicFX.GroundSurgePreview(point, yaw, now)
	if typeof(point) ~= "Vector3" then return end
	local K = T.GroundSurge
	local pv = previewParts()
	pv.point, pv.yaw = point, tonumber(yaw) or 0
	local w = 0.5 + 0.5 * math.sin(((now or os.clock()) - (now and 0 or pv.born)) * K.PreviewPulseHz * 2 * math.pi)
	previewPose(pv, pv.point, pv.yaw, 1, pair(K.PreviewTransparency, w))
end

--- Ends the preview. `locked` (the cast went): it snaps bright and wide for LockFlash, then fades out over LockFade
--- where it stood. Otherwise (cancelled, refused, died) it goes at once. `timeScale` is REVIEW ONLY (slow motion).
function VoltaicFX.GroundSurgePreviewEnd(locked, timeScale)
	local pv = preview
	preview = nil
	if not (pv and pv.folder.Parent) then return end
	if not (locked and pv.point) then
		pv.folder:Destroy()
		return
	end
	local K = T.GroundSurge
	local t0 = os.clock()
	local k = math.clamp(tonumber(timeScale) or 1, 0.05, 1)
	local conn
	conn = RunService.RenderStepped:Connect(function()
		local a = (os.clock() - t0) * k
		if a >= K.LockFlash + K.LockFade then
			conn:Disconnect()
			pv.folder:Destroy()
			return
		end
		if a < K.LockFlash then
			previewPose(pv, pv.point, pv.yaw, K.LockWiden, 0)
		else
			local f = (a - K.LockFlash) / K.LockFade
			previewPose(pv, pv.point, pv.yaw, lerp(K.LockWiden, 1, f), f)
		end
	end)
end

--- The yaw the zone faces for a look direction (the camera's): its long side goes across the aim.
function VoltaicFX.GroundSurgeYaw(look)
	if typeof(look) ~= "Vector3" then return 0 end
	return math.atan2(-look.X, -look.Z)
end

----------------------------------------------------------------------------------------------------
-- 2-4 THE CAGE: GroundSurgePlant plays placement, the armed surge, the discharge and the retract on ONE clock
----------------------------------------------------------------------------------------------------
local CAGES = {}

local function floorFinder(exclude)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.RespectCanCollide = true
	return function(p, fallbackY)
		local ex = table.clone(exclude)
		params.FilterDescendantsInstances = ex
		for _ = 1, 4 do
			local hit = workspace:Raycast(Vector3.new(p.X, fallbackY + 6, p.Z), Vector3.new(0, -14, 0), params)
			if not hit then break end
			local model = hit.Instance:FindFirstAncestorOfClass("Model")
			if not (model and model:FindFirstChildOfClass("Humanoid")) then return hit.Position end
			table.insert(ex, model)      -- a body is not the floor: look through it
			params.FilterDescendantsInstances = ex
		end
		return Vector3.new(p.X, fallbackY, p.Z)
	end
end

--- Plays Ground Surge from the placement on. Returns a handle, or nil if there is nothing left to draw.
--- data:
---   At         the zone's centre on the ground (the confirmed preview point)
---   Yaw        which way the zone faces (VoltaicFX.GroundSurgeYaw of the caster's aim at the confirm)
---   T0         server time of the cast (workspace:GetServerTimeNow()), so a late client joins in step
---   Character  the caster -- the key GroundSurgePop / GroundSurgeClear find the cage by
---   Thin       somebody else's cast: Reduce Enemy VFX applies
---   Seed       the jitter; default from the point, so every client draws the same cage
---   TimeScale  REVIEW ONLY: < 1 plays it in slow motion
---   HoldAt     REVIEW ONLY: stop the clock at this time (handle.HoldAt can be changed while it runs)
--- The discharge fires on the cage's own clock at ArmFrom + ArmTime. handle:Pop() fires it now if the server's pop
--- arrives first; handle:Clear() (a miss) skips it and retracts; handle:Destroy() removes everything at once.
function VoltaicFX.GroundSurgePlant(data)
	libs()
	local K = T.GroundSurge
	if type(data) ~= "table" or typeof(data.At) ~= "Vector3" then return nil end
	local key = data.Character or data.At
	if CAGES[key] then CAGES[key]:Destroy() end

	local tD0 = K.ArmFrom + K.ArmTime
	local late = 0
	if type(data.T0) == "number" then
		late = math.max(0, workspace:GetServerTimeNow() - data.T0)
		if late >= tD0 then return nil end          -- the zap has been and gone: draw nothing stale
	end
	local ts = math.clamp(tonumber(data.TimeScale) or 1, 0.05, 1)
	local thin = data.Thin == true
	local flat = VFXLibrary.FlatLit()
	local calm = Settings.Get and Settings.Get("ReduceFlashing") == true
	local density = (Settings.EffectDensity or 1) * ((thin and Settings.ThinEnemyVFX) and 0.5 or 1)
	local lite = density < 0.6                       -- low Graphics Quality, or somebody else's cast thinned
	local brightK = flat and 0.7 or 1                -- emitter()'s own flat-light toning, kept on the beams too
	local at, yaw = data.At, tonumber(data.Yaw) or 0
	local seed = tonumber(data.Seed) or (math.floor(at.X * 7 + at.Z * 13) % 100000)

	-- every emitter runs at the cage's own speed (REVIEW slow motion; 1 in a match)
	local function slow(pe)
		if pe and ts ~= 1 then pe.TimeScale = ts end
		return pe
	end
	local function burst(parent, kind, count, extra) return slow(VFXLibrary.GroundSurgeBurst(parent, kind, count, thin, extra)) end

	local folder = Instance.new("Folder")
	folder.Name = "GroundSurge"
	folder.Parent = fxFolder()
	local zoneCF = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
	local hub = host("SurgeHub", Vector3.new(0.2, 0.2, 0.2), zoneCF, folder)
	local floorAt = floorFinder({ folder, fxFolder() })
	local hw, hd = K.Width / 2, K.Depth / 2
	local LOCAL = { Vector3.new(-hw, 0, -hd), Vector3.new(hw, 0, -hd), Vector3.new(hw, 0, hd), Vector3.new(-hw, 0, hd) }
	local centre = at

	-- the poles, each with its strike bolt
	local rng0 = Random.new(seed)
	local poles = {}
	for i = 1, 4 do
		local base = floorAt(zoneCF:PointToWorldSpace(LOCAL[i]), at.Y)
		local P = { base = base, landT = K.Lands[i], landed = false, flick = 1, color = nil }
		P.pts = { Vector3.zero }
		for s = 1, 4 do
			local kx = s < 4 and rng0:NextNumber(-1, 1) * K.PoleKink or 0
			local kz = s < 4 and rng0:NextNumber(-1, 1) * K.PoleKink or 0
			P.pts[s + 1] = Vector3.new(kx, K.PoleHeight * s / 4, kz)
		end
		P.parts = {}
		for s = 1, 4 do P.parts[s] = neon("Pole", COL.Base, folder) end
		P.attB = attach(hub, base + Vector3.new(0, 0.3, 0))
		P.attT = attach(hub, base + P.pts[5])
		P.glow = newBeam(P.attB, P.attT, COL.Base, YELLOW_EMISSION, true, hub)
		P.aura = newBeam(P.attB, P.attT, COL.Dark, VIOLET_EMISSION, true, hub)
		P.glow.Width0, P.glow.Width1 = K.PoleGlowWidth[1], K.PoleGlowWidth[2]
		P.aura.Width0, P.aura.Width1 = K.PoleAuraWidth[1], K.PoleAuraWidth[2]
		P.foot = attach(hub, base + Vector3.new(0, 0.15, 0))
		P.tip = attach(hub, base + P.pts[5])
		if not flat then
			local la = attach(hub, base + Vector3.new(0, K.PoleHeight * 0.6, 0))
			P.light = Instance.new("PointLight")
			P.light.Color, P.light.Range, P.light.Brightness, P.light.Shadows = COL.Base, K.PoleLight[3], 0, false
			P.light.Parent = la
			P.lightAtt = la
		end
		P.sparks = slow(VFXLibrary.GroundSurgeEmitter(P.tip, "PoleSpark", thin))
		P.sparks.Enabled = false
		P.bolt = newArc(hub, 17, COL.Base, YELLOW_EMISSION)
		poles[i] = P
	end

	local function posePole(P, sink, wk, color)
		for s = 1, 4 do
			local a = P.base + P.pts[s] - Vector3.new(0, sink, 0)
			local b = P.base + P.pts[s + 1] - Vector3.new(0, sink, 0)
			local w = K.PoleWidth * POLE_TAPER[s] * wk
			local part = P.parts[s]
			part.Size = Vector3.new(w, w, (b - a).Magnitude + w * 0.5)       -- overlapped at the joints
			part.CFrame = CFrame.lookAt((a + b) / 2, b)
			part.Transparency = 0
		end
		if P.color ~= color then
			P.color = color
			for s = 1, 4 do P.parts[s].Color = color end
		end
		P.attB.WorldPosition = P.base + Vector3.new(0, 0.3 - sink, 0)
		P.attT.WorldPosition = P.base + P.pts[5] - Vector3.new(0, sink, 0)
		P.tip.WorldPosition = P.attT.WorldPosition
	end

	-- the edges: arcs pole to pole, and a thin line on the ground
	local edges = {}
	for e = 1, 4 do
		local E = { a = poles[e], b = poles[e % 4 + 1], arcs = {} }
		for j = 1, (lite and 2 or K.EdgeArcs[2]) do E.arcs[j] = newArc(hub, 9, COL.Base, YELLOW_EMISSION) end
		E.line = neon("FloorLine", COL.Base, folder)
		local a, b = E.a.base + Vector3.new(0, 0.03, 0), E.b.base + Vector3.new(0, 0.03, 0)
		E.line.Size = Vector3.new(K.FloorLineWidth, 0.05, (b - a).Magnitude)
		E.line.CFrame = CFrame.lookAt((a + b) / 2, b)
		edges[e] = E
	end

	-- the interior: crawlers and leaps, scheduled for the whole arm up front (an exponential gap at the rate of the
	-- moment), each claiming a pooled arc while it lives. Violet glow on a yellow core -- the field, not the fence.
	local crawlPool = {}
	for j = 1, (lite and 3 or 6) do crawlPool[j] = newArc(hub, 9, COL.Dark, VIOLET_EMISSION) end
	local events = {}
	do
		local r = Random.new(seed + 17)
		local t = K.ArmFrom
		while true do
			local u = span(t, K.ArmFrom, tD0)
			local rate = pair(K.CrawlRate, u ^ K.Ramp) * (lite and 0.5 or 1)
			t += -math.log(1 - r:NextNumber(0, 0.95)) / rate
			if t >= tD0 then break end
			u = span(t, K.ArmFrom, tD0)
			local ev = { t0 = t, life = pair(K.CrawlLife, u), seed = r:NextInteger(1, 1e6) }
			if r:NextNumber() < K.LeapShare then
				ev.leap = r:NextInteger(1, 4)
				ev.to = (r:NextNumber() < 0.6) and ((ev.leap + 1) % 4 + 1) or (ev.leap % 4 + 1)   -- mostly the diagonal
			else
				ev.s = Vector3.new(r:NextNumber(-0.85, 0.85) * hw, 0, r:NextNumber(-0.85, 0.85) * hd)
				local ang = r:NextNumber(0, 2 * math.pi)
				ev.dir = Vector3.new(math.cos(ang), 0, math.sin(ang))
				ev.len = pair(K.CrawlLen, u) * r:NextNumber(0.8, 1.2)
			end
			events[#events + 1] = ev
		end
	end

	-- the discharge's own arcs (made now, hidden: no Instance churn at the zap itself)
	local centreBolt = newArc(hub, 17, COL.Base, YELLOW_EMISSION)
	local forks = { newArc(hub, 5, COL.Base, YELLOW_EMISSION), newArc(hub, 5, COL.Base, YELLOW_EMISSION) }
	local web = {}
	for j = 1, (lite and 6 or K.WebArcs) do web[j] = newArc(hub, 5, COL.Base, YELLOW_EMISSION) end

	-- lights: one flash moved to each landing, one for the zap
	local flashLight, centreLight
	if not flat then
		flashLight = Instance.new("PointLight")
		flashLight.Color, flashLight.Brightness, flashLight.Shadows = COL.Light, 0, false
		flashLight.Parent = attach(hub, at + Vector3.new(0, 2, 0))
		centreLight = Instance.new("PointLight")
		centreLight.Color, centreLight.Brightness, centreLight.Range, centreLight.Shadows = COL.Light, 0, K.CentreLight[2], false
		centreLight.Parent = attach(hub, at + Vector3.new(0, 3, 0))
	end
	local centreAtt = attach(hub, at + Vector3.new(0, 0.3, 0))

	local handle = { Folder = folder, HoldAt = data.HoldAt }
	local dischargeAt, missAt = tD0, nil
	local lastReroll, rerollN = -1, 0
	local landFlashAt = -1
	local fired = {}
	local conn

	-- the cage's own time: real seconds x TimeScale from `late`, PAUSED while it sits at a review HoldAt (clearing
	-- HoldAt resumes it from there rather than jumping ahead)
	local simT, lastClock = late, os.clock()
	local function clock()
		local now = os.clock()
		simT += (now - lastClock) * ts
		lastClock = now
		if handle.HoldAt and simT > handle.HoldAt then simT = handle.HoldAt end
		return simT
	end
	handle.Time = clock

	local function toWorld(p) return zoneCF:PointToWorldSpace(p) end
	local function inside(p)
		return Vector3.new(math.clamp(p.X, -hw * 0.95, hw * 0.95), 0, math.clamp(p.Z, -hd * 0.95, hd * 0.95))
	end
	-- where a ray from the centre at `ang` leaves the rectangle (zone-local)
	local function rim(ang)
		local d = Vector3.new(math.cos(ang), 0, math.sin(ang))
		local kx = math.abs(d.X) > 1e-4 and hw / math.abs(d.X) or math.huge
		local kz = math.abs(d.Z) > 1e-4 and hd / math.abs(d.Z) or math.huge
		return d * math.min(kx, kz)
	end

	local function land(P, i, stale)
		for s = 1, 4 do P.parts[s].Transparency = 0 end
		P.glow.Enabled, P.aura.Enabled = true, true
		P.sparks.Enabled = true
		if stale then return end
		burst(P.foot, "Impact", K.ImpactSparks)
		burst(P.foot, "Dust", K.ImpactDust)
		burst(P.foot, "Flash", 1, calm and { Size = NumberSequence.new(1.05, 2.7) } or nil)
		if flashLight then
			flashLight.Parent.WorldPosition = P.base + Vector3.new(0, 2, 0)
			flashLight.Range = K.LandLight[2]
			landFlashAt = P.landT
		end
		punchNear(P.base, i == 4 and K.ClosePunch or K.LandPunch, K.PunchReach)
	end

	local function discharge(t)
		fired.discharge = true
		if t - dischargeAt > 0.15 then return end    -- joined too late for the bang itself
		punchNear(centre, K.DischargePunch, K.PunchReach)
		burst(centreAtt, "Fountain", K.FountainSparks)
		burst(centreAtt, "Flash", 1, { Size = NumberSequence.new(calm and 2.6 or 3.5, calm and 6 or 8) })
		burst(centreAtt, "Dust", K.DischargeDust)
		local smokeHost = host("SurgeSmoke", Vector3.new(K.Width * 0.9, 0.4, K.Depth * 0.9), zoneCF + Vector3.new(0, 0.6, 0), folder)
		burst(smokeHost, "Smoke", K.DischargeSmoke)
	end

	local function step()
		local t = clock()
		local tD = dischargeAt
		local tR = missAt or (tD + K.DischargeLife)
		local tEnd = tR + K.RetractTime
		local u = span(t, K.ArmFrom, tD0)
		local r = u ^ K.Ramp
		local d = t - tD                              -- time since the zap (negative before it)
		local zap = d >= 0 and not missAt

		-- the re-jag clock: faster as the countdown runs out, fastest through the zap; a third as often under Reduce
		-- Flashing (Railspike v2's rule for a 30 Hz shape change on bright yellow)
		local iv = (zap and t < tR) and K.WebReroll or pair(K.Reroll, r)
		if calm then iv *= 3 end
		local reroll = t - lastReroll >= iv or t < lastReroll
		if reroll then
			lastReroll = t
			rerollN += 1
		end
		local rr = Random.new(seed * 31 + rerollN)

		-- 2 PLACEMENT and the poles' life
		for i, P in ipairs(poles) do
			local a = t - (P.landT - K.Leader)
			local strikeOn = a >= 0 and a < K.Leader + K.ReturnStroke + K.SkyFade and t < tR
			if strikeOn then
				if not P.strikePts then
					local sr = Random.new(seed + i * 101)
					local top = P.base + P.pts[5]
					local sky = top + Vector3.new(sr:NextNumber(-1, 1) * K.StrikeDrift, K.StrikeFrom, sr:NextNumber(-1, 1) * K.StrikeDrift)
					P.strikePts = jag(sky, top, 4, K.StrikeAmp, sr)
					arcShape(P.bolt, P.strikePts)
				end
				if a < K.Leader then
					arcLook(P.bolt, K.StrikeCore[1], K.StrikeGlow[1], K.StrikeBright[1] * brightK, 1.2 * brightK, 0.2, a / K.Leader)
				elseif a < K.Leader + K.ReturnStroke then
					arcLook(P.bolt, K.StrikeCore[2], K.StrikeGlow[2], K.StrikeBright[2] * brightK, 3 * brightK, 0)
				else
					local f = (a - K.Leader - K.ReturnStroke) / K.SkyFade
					arcLook(P.bolt, K.StrikeCore[2] * (1 - f), K.StrikeGlow[2] * (1 - f), K.StrikeBright[2] * brightK,
						3 * brightK, f)
				end
			elseif P.strikePts and not zap then
				arcHide(P.bolt)
			end
			if a >= K.Leader and not P.landed and t < tR then
				P.landed = true
				land(P, i, t - P.landT > 0.15)
			end
			if P.landed then
				local ap = t - P.landT
				local wk = ap < K.PoleIn and lerp(K.PoleInWiden, 1, easeOutCubic(ap / K.PoleIn)) or 1
				local sink, color, glowK = 0, COL.Base, 1
				if t >= tR then
					local v = span(t, tR, tEnd)
					sink = K.PoleHeight * easeInQuad(v)
					color = COL.Base:Lerp(COL.Dark, math.min(1, v * 1.6))
					wk *= lerp(1, 0.6, v)
					glowK = 1 - v
					if not P.embers then
						P.embers = slow(VFXLibrary.GroundSurgeEmitter(P.foot, "Ember", thin))
						P.sparks.Enabled = false
					end
					if P.embers.Enabled and t >= tR + K.EmberFor then P.embers.Enabled = false end
				end
				if t >= tEnd then
					for s = 1, 4 do P.parts[s].Transparency = 1 end
					P.glow.Enabled, P.aura.Enabled = false, false
					if P.light then P.light.Brightness = 0 end
				else
					posePole(P, sink, wk, color)
					if reroll then P.flick = 1 + rr:NextNumber(-1, 1) * pair(K.PoleFlicker, r) end
					local zapK = (zap and d < 0.2) and lerp(2.2, 1, d / 0.2) or 1
					local gb = pair(K.GlowBright, r) * P.flick * zapK * glowK * brightK
					P.glow.Brightness = gb
					P.glow.Transparency = NumberSequence.new(1 - GLOW_ALPHA * math.min(1, glowK * 1.2))
					P.aura.Brightness = 1.5 * glowK
					P.aura.Transparency = NumberSequence.new(1 - 0.45 * glowK * math.min(1, 0.6 + r))
					if P.light then P.light.Brightness = pair(K.PoleLight, r) * P.flick * zapK * glowK end
					if not zap and t < tR then
						VFXLibrary.GroundSurgeRate(P.sparks, pair(K.PoleSparkRate, r), thin)
					elseif P.sparks.Enabled then
						P.sparks.Enabled = false
					end
				end
			end
		end
		if flashLight then
			local f = (t - landFlashAt) / K.LandLight[3]
			flashLight.Brightness = (f >= 0 and f < 1) and K.LandLight[1] * (1 - f) ^ 2 * (calm and 0.5 or 1) or 0
		end

		-- 3 ARMED: the fence -- arcs pole to pole along each edge, at fresh heights on every re-jag
		for _, E in ipairs(edges) do
			local live = E.a.landed and E.b.landed and t < tEnd
			local n = 0
			if live then
				if t >= tR then
					n = 1                                                   -- the retract's last sputter
				elseif zap then
					n = d < 0.12 and #E.arcs or 0                            -- the zap: every arc at once, then gone
				else
					n = math.min(#E.arcs, math.floor(pair(K.EdgeArcs, r) + 0.5))
				end
			end
			local sink = t >= tR and K.PoleHeight * easeInQuad(span(t, tR, tEnd)) or 0
			for j, A in ipairs(E.arcs) do
				if j > n then
					A.on = false
				elseif reroll or not A.shaped then
					A.shaped = true
					local dying = t >= tR and rr:NextNumber() > (1 - span(t, tR, tEnd)) * 0.6
					A.on = not dying and not (not zap and rr:NextNumber() < K.EdgeDrop)
					if A.on then
						local top = K.PoleHeight - sink
						local h0 = rr:NextNumber(0.4, math.max(0.5, top - 0.3))
						local h1 = math.clamp(h0 + rr:NextNumber(-1.4, 1.4), 0.3, math.max(0.4, top - 0.2))
						local p0 = E.a.base + Vector3.new(0, h0, 0)
						local p1 = E.b.base + Vector3.new(0, h1, 0)
						arcShape(A, jag(p0, p1, 3, K.EdgeAmp * (p1 - p0).Magnitude * rr:NextNumber(0.6, 1.2), rr, at.Y + 0.1))
					end
				end
				if A.on then
					local k = (zap and t < tR) and 1.8 or (t >= tR and 0.6 or 1)
					arcLook(A, pair(K.EdgeCore, r) * k, pair(K.GlowWidth, r) * math.min(k, 1.3),
						pair(K.CoreBright, r) * k * brightK, pair(K.GlowBright, r) * math.min(k, 1.4) * brightK,
						t >= tR and 0.3 or 0)
				else
					arcHide(A)
				end
			end
			if live then
				local tr = t >= tR and lerp(K.FloorLine[1], 1, span(t, tR, tEnd)) or pair(K.FloorLine, r)
				if zap and t < tR then tr = 0 end
				E.line.Transparency = tr
			else
				E.line.Transparency = 1
			end
		end

		-- 3 ARMED: the field -- crawlers along the floor and leaps across it
		for _, ev in ipairs(events) do
			local age = t - ev.t0
			local alive = age >= 0 and age < ev.life and not zap and t < tR
			if alive and not ev.arc then
				for _, A in ipairs(crawlPool) do
					if not A.busy then
						A.busy, ev.arc = true, A
						break
					end
				end
			end
			local A = ev.arc
			if A then
				if not alive then
					arcHide(A)
					A.busy, ev.arc = false, nil
				else
					if reroll or not ev.shaped then
						ev.shaped = true
						local er = Random.new(ev.seed + rerollN)
						if ev.leap then
							local P0, P1 = poles[ev.leap], poles[ev.to]
							local p0 = P0.base + Vector3.new(0, er:NextNumber(2.2, K.PoleHeight - 0.2), 0)
							local p1 = P1.base + Vector3.new(0, er:NextNumber(2.0, K.PoleHeight - 0.2), 0)
							arcShape(A, jag(p0, p1, 3, 0.12 * (p1 - p0).Magnitude, er, at.Y + 0.2))
						else
							local s = inside(ev.s + ev.dir * K.CrawlSpeed * age)
							local c, sn = math.cos(er:NextNumber(-0.45, 0.45)), nil
							sn = math.sin(math.acos(c)) * (er:NextNumber() < 0.5 and -1 or 1)
							local dir = Vector3.new(ev.dir.X * c - ev.dir.Z * sn, 0, ev.dir.X * sn + ev.dir.Z * c)
							local e = inside(s + dir * ev.len * er:NextNumber(0.8, 1.2))
							local sw, ew = toWorld(s) + Vector3.new(0, 0.12, 0), toWorld(e) + Vector3.new(0, 0.12, 0)
							local apex = (sw + ew) / 2 + Vector3.new(0, K.CrawlArch * er:NextNumber(0.4, 1), 0)
							local pts = jag(sw, apex, 2, 0.16 * ev.len, er, at.Y + 0.05, 0.45)
							arcShape(A, jag(apex, ew, 2, 0.16 * ev.len, er, at.Y + 0.05, 0.45, pts))
						end
					end
					local f = age / ev.life
					local tr = f < 0.2 and (1 - f / 0.2) * 0.5 or (f > 0.65 and (f - 0.65) / 0.35 or 0)
					arcLook(A, K.CrawlCore, K.CrawlGlow, pair(K.CoreBright, r) * 0.8 * brightK, 1.4 * brightK, tr)
				end
			end
		end

		-- 4 DISCHARGE
		if zap and not fired.discharge then discharge(t) end
		if zap and t < tR then
			-- the centre bolt: strikes, goes dark, strikes again twice (once under Reduce Flashing)
			local wins = calm and { { 0, 0.12, 1 } } or {
				{ 0, K.RestrikeLife[1], K.RestrikeBright[1] },
				{ K.Restrikes[1], K.Restrikes[1] + K.RestrikeLife[2], K.RestrikeBright[2] },
				{ K.Restrikes[2], K.Restrikes[2] + K.RestrikeLife[3], K.RestrikeBright[3] },
			}
			local win = nil
			for wi, w in ipairs(wins) do
				if d >= w[1] and d < w[2] then win = wi end
			end
			if win then
				if fired.centreWin ~= win then
					fired.centreWin = win
					local cr = Random.new(seed + 900 + win)
					local ground = centre + Vector3.new(0, 0.2, 0)
					local sky = ground + Vector3.new(cr:NextNumber(-3, 3), K.StrikeFrom + 6, cr:NextNumber(-3, 3))
					local pts = jag(sky, ground, 4, K.StrikeAmp * 1.3, cr)
					arcShape(centreBolt, pts)
					for fi, F in ipairs(forks) do
						local from = pts[fi == 1 and 7 or 11]
						local out = Vector3.new(cr:NextNumber(-1, 1), 0, cr:NextNumber(-1, 1))
						out = out.Magnitude > 1e-3 and out.Unit or Vector3.xAxis
						local to = from + out * cr:NextNumber(3, 6) - Vector3.new(0, cr:NextNumber(2.5, 5), 0)
						arcShape(F, jag(from, to, 2, 1.2, cr))
					end
				end
				local k = wins[win][3]
				arcLook(centreBolt, K.CentreCore * k, K.CentreGlow * k, K.CentreBright * k * brightK, 3.5 * k * brightK, 0)
				for _, F in ipairs(forks) do
					arcLook(F, K.CentreCore * 0.4 * k, K.CentreGlow * 0.45 * k, K.CentreBright * 0.7 * k * brightK, 2.5 * k * brightK, 0)
				end
			else
				arcHide(centreBolt)
				for _, F in ipairs(forks) do arcHide(F) end
			end
			-- every pole fires into the centre
			for _, P in ipairs(poles) do
				if d < K.PoleBolts then
					if reroll or fired.poleBolts ~= rerollN then
						local top = P.base + P.pts[5]
						local mid = centre + Vector3.new(0, 1.2, 0)
						arcShape(P.bolt, jag(top, mid, 3, 0.10 * (mid - top).Magnitude, rr, at.Y + 0.3))
					end
					arcLook(P.bolt, 0.24, 2.2, 9 * brightK, 3 * brightK, span(d, K.PoleBolts * 0.6, K.PoleBolts))
				else
					arcHide(P.bolt)
				end
			end
			fired.poleBolts = rerollN
			-- the floor web: arcs racing out from the centre to the edges, thinning out
			local shown = math.floor(lerp(#web, 0, span(d, 0.10, K.WebLife)) + 0.5)
			for j, A in ipairs(web) do
				if j <= shown then
					if reroll or not A.webbed then
						A.webbed = true
						local ang = (j / #web) * 2 * math.pi + rr:NextNumber(-0.25, 0.25) + yaw
						local e = toWorld(rim(ang - yaw) * rr:NextNumber(0.85, 1.0)) + Vector3.new(0, 0.1, 0)
						local s = centre + Vector3.new(0, 0.15, 0)
						arcShape(A, jag(s, e, 2, 0.16 * (e - s).Magnitude, rr, at.Y + 0.05, 0.3))
					end
					arcLook(A, 0.14, 1.6, 8 * brightK, 2.6 * brightK, span(d, 0.08, K.WebLife))
				else
					arcHide(A)
				end
			end
			if centreLight then
				local f = d / K.CentreLight[3]
				local b = f < 1 and K.CentreLight[1] * (1 - f) ^ 2 or 0
				if not calm then
					for wi = 2, 3 do
						local w = wins[wi]
						if w and d >= w[1] and d < w[2] then b = math.max(b, K.CentreLight[1] * 0.6 * w[3]) end
					end
				end
				centreLight.Brightness = b * (calm and 0.5 or 1)
			end
		elseif fired.discharge then
			arcHide(centreBolt)
			for _, F in ipairs(forks) do arcHide(F) end
			for _, A in ipairs(web) do arcHide(A) end
			for _, P in ipairs(poles) do arcHide(P.bolt) end
			if centreLight then centreLight.Brightness = 0 end
		end

		if t >= math.max(K.Cleanup, tEnd + 1.2) then handle:Destroy() end
	end

	function handle:Pop()
		local t = clock()
		if not missAt and t < dischargeAt then dischargeAt = t end
	end
	function handle:Clear()
		local t = clock()
		if not missAt and t < dischargeAt then missAt = t end
	end
	function handle:Destroy()
		if conn then conn:Disconnect() end
		conn = nil
		if folder.Parent then folder:Destroy() end
		if CAGES[key] == handle then CAGES[key] = nil end
	end

	CAGES[key] = handle
	conn = RunService.RenderStepped:Connect(function()
		local ok, err = pcall(step)
		if not ok then
			warn("[VoltaicFX] Ground Surge: " .. tostring(err))
			handle:Destroy()
		end
	end)
	step()
	return handle
end

--- The server's pop arrived (GroundSurgePop { Character, At, T0 }): the cage discharges now if its own clock has not
--- got there yet. With no cage for that caster (a late joiner) there is nothing stale to draw.
function VoltaicFX.GroundSurgePop(data)
	local h = type(data) == "table" and CAGES[data.Character or data.At]
	if h then h:Pop() end
end

--- A miss (GroundSurgeMiss { Character, Reason }: the caster died or was interrupted): no zap, the poles retract.
function VoltaicFX.GroundSurgeClear(data)
	local h = type(data) == "table" and CAGES[data.Character or data.At]
	if h then h:Clear() end
end

--- REVIEW ONLY: the whole sequence at `point` facing `yaw`, on a local clock (no server time), for the showcase.
function VoltaicFX.GroundSurge(point, yaw, opts)
	opts = opts or {}
	return VoltaicFX.GroundSurgePlant({ At = point, Yaw = yaw, Seed = opts.Seed, TimeScale = opts.TimeScale,
		HoldAt = opts.HoldAt, Thin = opts.Thin, Character = opts.Character })
end

----------------------------------------------------------------------------------------------------
-- CASCADE (the Voltaic Ultimate), RE-LIT (2026-09-27): the client side is CascadeFX
----------------------------------------------------------------------------------------------------
-- The comic build that lived here (the 22 VT3_Cascade_* toon meshes, VFXLibrary's CascadeOrbit* / CascadeImpact /
-- CascadeAfterglowEmitter particles) is replaced whole by the re-lit port of blender_scripts/voltaic/cascade_bl.py:
-- ReplicatedStorage.IceMagic.CascadeFX (its header documents the port). The three broadcasts still arrive here --
-- VoltaicHandler -> VoltaicClient.Handlers -> VoltaicFX, their names and payloads unchanged -- and are handed on:
--   CascadeGather { Character, Point, T0 }         -> CascadeFX.Gather  (the windup at the hands, then the storm, all
--                                                     on the clock from T0, the key)
--   CascadeStrike { Character, Point, N, At, T0 }   -> CascadeFX.Strike  (strike N's ground point re-aims its bolt;
--                                                     with no storm for it the storm is built, already caught up)
--   CascadeEnd    { Character, T0 }                 -> CascadeFX.End     (no more strikes; before any: no release)
-- SERVER-SAFE: CascadeFX is required lazily, on a client only (VoltaicHandler requires THIS module for Tuning.Cascade),
-- with timed waits, and is handed Tuning.Cascade so the storm every client draws runs on the server's clock. A place
-- without CascadeFX draws no storm and says so once (retried every few seconds).

local cascadeMod, cascadeRetryAt, cascadeLoading, cascadeWarned = nil, 0, false, false

local function cascadeFX()
	if cascadeMod then return cascadeMod end
	if not RunService:IsClient() then return nil end
	if cascadeLoading then
		local give = os.clock() + 12
		while cascadeLoading and os.clock() < give do task.wait() end
		return cascadeMod
	end
	if os.clock() < cascadeRetryAt then return nil end
	cascadeLoading = true
	local ok, res = pcall(function()
		local ice = ReplicatedStorage:FindFirstChild("IceMagic") or ReplicatedStorage:WaitForChild("IceMagic", 10)
		local m = ice and (ice:FindFirstChild("CascadeFX") or ice:WaitForChild("CascadeFX", 10))
		if not (m and m:IsA("ModuleScript")) then return "ReplicatedStorage.IceMagic.CascadeFX not found -- no storm is drawn" end
		local fine, mod = pcall(require, m)
		if not (fine and type(mod) == "table") then return "CascadeFX failed to load -- " .. tostring(mod) end
		return mod
	end)
	cascadeLoading = false
	if ok and type(res) == "table" then
		cascadeMod = res
		if type(res.Bind) == "function" then res.Bind(T.Cascade) end
		return res
	end
	cascadeRetryAt = os.clock() + 5
	if not cascadeWarned then
		cascadeWarned = true
		warn("[VoltaicFX] Cascade: " .. tostring(res))
	end
	return nil
end

--- CascadeGather { Character, Point, T0 }: the windup, then the storm over Point. Returns CascadeFX's handle (a table
--- with :Destroy()), or nil (not a client, no CascadeFX, a bad payload, or long over).
function VoltaicFX.CascadeGather(data)
	if not RunService:IsClient() then return nil end
	local C = cascadeFX()
	if not (C and C.Gather) then return nil end
	return C.Gather(data)
end

--- CascadeStrike { Character, Point, N, At, T0 }: strike N (1..5) landed at At.
function VoltaicFX.CascadeStrike(data)
	if not RunService:IsClient() then return end
	local C = cascadeFX()
	if C and C.Strike then C.Strike(data) end
end

--- CascadeEnd { Character, T0 }: the server has no more strikes for this storm.
function VoltaicFX.CascadeEnd(data)
	if not RunService:IsClient() then return end
	local C = cascadeMod                                 -- an End never loads the module: nothing to end without it
	if C and C.End then C.End(data) end
end

return VoltaicFX

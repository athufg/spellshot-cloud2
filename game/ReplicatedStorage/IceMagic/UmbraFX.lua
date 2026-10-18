--[[
	UmbraFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/UmbraFX

	UMBRA's look (Phase 4 stage A, 2026-09-28): the owner's APPROVED Phase 3 "ribbon streams" (agent A rounds 3-4: the
	dart's charge, the dart, the hit, the glossy ball; agent B rounds 3-4: Shadow Step, Decoy Double option A, Eclipse and
	its world and screen), built as Roblox instances. UmbraClient is the only caller: it maps every server broadcast and
	every local click to one function here. CLIENT-ONLY: nothing here replicates, nothing here decides a hit.

	EVERY NUMBER IS UmbraTuning's: T.FX (timing, size, colour, strength, the per-ribbon tables), T.Textures (asset ids,
	nil until uploaded), T.Color (the palette) and T.Eclipse.RevealColor. The only literals below are the ribbon EQUATIONS'
	own shape coefficients, quoted from the build specs beside each formula (a spiral's "0.5 per radian", a braid's
	"2 pi j / 3"). Without T.FX (the Phase 4 block not pasted into UmbraTuning) every function returns an inert handle and
	warns once: the kit still plays, it just draws nothing.

	THE RIBBON ENGINE. Every ribbon is a chain of Beams on script-moved Attachments (never Trails: a Trail is world-space
	history, and would streak across Shadow Step's jump and smear across a turning first-person camera). A chain of k
	Beams rides k + 1 Attachments parented to workspace.Terrain (world space), each written every frame at a point of the
	ribbon's analytic curve with its Axis (X) on the curve's tangent; each Beam's CurveSize0/1 = |curve'| x step / 3 (a
	Hermite fit), so the Beams draw the curve the renders drew. Two languages, both approved:
	  A-STYLE (agent A: the charge, the dart, the hit, the Mark headshot) -- the colour is Beam.Color x a white-edged strip;
	      the RUNNING LIGHT is a triangular lift in the Color sequence rewritten every frame; TextureSpeed 0; the charge and
	      the hit are FaceCamera false (the width on the Attachment's SecondaryAxis), the dart's streamers FaceCamera true.
	  B-STYLE (agent B: Shadow Step, Decoy Double, Eclipse) -- colour and band are baked into the strip (Color white),
	      TextureSpeed runs the band toward the head, FaceCamera true, the whole-ribbon Transparency sliced per Beam.
	Beams and Attachments are POOLED (Engine.PoolBeams / PoolAttachments) and every live effect is stepped by ONE render
	step (Camera + Engine.RenderPriority: after the Viewmodel has placed the arms this frame), bound only while something
	is alive. An effect that errors, outlives Engine.MaxLife or loses its body is torn down and its instances given back.

	THE BALL RECIPE (A_r4, all four balls: the dart's charge ball, the dart head, the hit's core, Eclipse's core): a glossy
	void sphere, a faint shade rim + halo on a camera-facing billboard, a small violet PointLight. The gloss needs a
	SurfaceAppearance, which a game script may not author at runtime, so the ball is a CLONE of a template built at
	install time (ReplicatedStorage.IceMagicMeshes.UmbraKit.UmbraBall: a sphere MeshPart carrying its SurfaceAppearance).
	No template: a Block Part with a Sphere SpecialMesh, SmoothPlastic + Reflectance (Ball.FallbackReflectance) -- the same
	silhouette and light, a cheaper gloss, nothing errors. No rim image: a thin stroked ring on the same billboard.
	SINCE 2026-09-28 (the owner: a glossy part mirrors the map and the sky; "exactly how it was in the video"): with
	T.Textures.BallBody1P / BallBody3P set, the ball's body is the preview's own render baked into a sprite under the rim
	on that billboard, and the part is kept only for the light and the third-person shadow (see newBall).

	THE TELL (the owner): concealment breaking -- the dart fired, a hit landed, the decoy failing -- floods the ribbons
	with glint (the running band widens and whitens, Brightness 1 -> 4.5, LightEmission up), and the balls' rims go glint
	with their light doubled; subdued otherwise. UmbraFX.Tell(character, reason) registers the moment: every live
	body-attached ribbon and ball of that character reads it (the domain's wave, wisps and screen never do: they would
	strobe the arena on every dart under Eclipse). Others also see a brief glint on the chest (Tell.BodyLight).

	  UmbraFX.Enabled()                                     T.FX is there
	  UmbraFX.LocalFirstPerson()                            the local arms are drawn this frame (Viewmodel.GetFistCFrame)
	  UmbraFX.Tell(character, reason)                       "Fire" | "Hit" | "Decoy"
	  UmbraFX.DartCharge(character, start, due)             -> h: h:Release(), h:Cancel(), h:BallPosition()
	  UmbraFX.Dart(owner)                                   -> h: h:Move(pos, dir, travelled), h:Impact(point, dir), h:Expire()
	  UmbraFX.Hit(point, dir, opts)                         the splash (opts: Owner, FlightTime)
	  UmbraFX.MarkHeadshot(point, dir, opts)                the hit's curls at the head, brighter, and a glint flash
	  UmbraFX.StepOut(character, from, to, opts)            opts: Start, Dissolve, FirstPerson (the stepper's own view)
	  UmbraFX.DecoyPeel(owner, decoy, opts)                 opts: Start, FirstPerson (the caster's arm copy)
	  UmbraFX.DecoyBreak(decoy, opts)                       opts: Owner, HitAt, Seed, Lit
	  UmbraFX.Eclipse(caster, opts)                         -> h: h:Open(openClock, untilClock, opts), h:End(clock), h:Cancel()
	  UmbraFX.GradePush(key) / UmbraFX.GradePop(key)        the V4 world grade, per viewer, refcounted, restored after
	  UmbraFX.RevealStart(untilServer, bodiesFn) / RevealStop()   the caster's light-purple outlines
	  UmbraFX.StopAll()

	Clocks: `start` / `clock` arguments are os.clock() values (UmbraClient converts a broadcast's server T0 with
	os.clock() - (GetServerTimeNow() - T0)). Every drawing runs on its spec's own clock, scaled by VFXLibrary.ShotTimeScale
	(the filming slow-down) like every other kit.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer

local UmbraFX = {}

----------------------------------------------------------------------------------------------------
-- modules (never a wait on anyone's input path: UmbraClient has already waited for UmbraTuning)
----------------------------------------------------------------------------------------------------
local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[UmbraFX] " .. tostring(msg))
end

local iceFolder = script.Parent
local T = nil
do
	local m = iceFolder and (iceFolder:FindFirstChild("UmbraTuning") or iceFolder:WaitForChild("UmbraTuning", 5))
	local ok, mod = pcall(function() return m and require(m) end)
	if ok and type(mod) == "table" then T = mod else warnOnce("tuning", "UmbraTuning unavailable: " .. tostring(mod)) end
end
local FX = T and T.FX or nil
local TX = T and T.Textures or {}
if T and not FX then warnOnce("nofx", "UmbraTuning has no FX table (paste the Phase 4 block): Umbra draws nothing") end
local E = FX and FX.Engine or nil
-- WRAPS (SkinCatalog, 2026-10-11): colour only. CUR is the wrap the code now running draws under (a SkinCatalog skin's
-- Shadow block), nil for Default: set while an entry point builds its effect (the WRAPS block at the end of this file),
-- stamped on every effect run() starts, and put back by the driver round that effect's own Step and by the entry
-- round every method of the handle it returned. PAL and wrapped() read it; with CUR nil each returns UmbraTuning's
-- own value, so Default draws exactly as before.
local CUR = nil
local BASE_PAL = T and T.Color or nil
local PAL = BASE_PAL and setmetatable({}, { __index = function(_, k)
	local c = CUR and CUR.Color
	return (c and c[k]) or BASE_PAL[k]
end }) or nil
local function wrapped(key, base)        -- the wrap's `key`, or UmbraTuning's `base`
	local v = CUR and CUR[key]
	if v == nil then return base end
	return v
end

local WHERE = { VFXLibrary = "IceMagic", Viewmodel = "IceMagic", SpellshotConfig = "Spellshot" }
local mods, failedAt = {}, {}
local function need(name)
	local m = mods[name]
	if m then return m end
	if failedAt[name] == true or (failedAt[name] and os.clock() - failedAt[name] < 2) then return nil end
	local folder = (WHERE[name] == "IceMagic" and iceFolder) or ReplicatedStorage:FindFirstChild(WHERE[name] or "IceMagic")
	local inst = folder and folder:FindFirstChild(name)
	if not inst then
		failedAt[name] = os.clock()
		return nil
	end
	local ok, res = pcall(require, inst)
	if not ok or type(res) ~= "table" then
		failedAt[name] = true
		warnOnce("broken:" .. name, name .. " failed to load: " .. tostring(res))
		return nil
	end
	mods[name] = res
	return res
end

local function timeScale()
	local V = need("VFXLibrary")
	local ok, s = pcall(function() return V and V.ShotTimeScale() end)
	return (ok and type(s) == "number" and s > 0) and s or 1
end

--- The Viewmodel's call, guarded: nil when the module, the function or the rig is not there.
local function vmCall(fn, ...)
	local VM = need("Viewmodel")
	local f = VM and VM[fn]
	if type(f) ~= "function" then return nil end
	local ok, res = pcall(f, ...)
	return ok and res or nil
end

function UmbraFX.Enabled()
	return FX ~= nil
end

--- Whether the local player's arms are the viewmodel's this frame (first person, rig built and placed).
function UmbraFX.LocalFirstPerson()
	return typeof(vmCall("GetFistCFrame", "R")) == "CFrame"
end

-- an inert handle: every method is a no-op (the kit keeps playing without its look)
local NULL = setmetatable({}, { __index = function() return function() return nil end end })

----------------------------------------------------------------------------------------------------
-- maths (the specs' helpers, verbatim)
----------------------------------------------------------------------------------------------------
local TAU = 2 * math.pi
local V3 = Vector3.new
local function clamp01(u) return if u < 0 then 0 elseif u > 1 then 1 else u end
local function sstep(a, b, x)
	local u = clamp01((x - a) / (b - a))
	return u * u * (3 - 2 * u)
end
local function sio(u) return 0.5 - 0.5 * math.cos(math.pi * clamp01(u)) end              -- Sine InOut
local function qout(u) u = clamp01(u) return 1 - (1 - u) * (1 - u) end                   -- Quad Out
local function qinout(u)                                                                 -- Quad InOut
	u = clamp01(u)
	return if u < 0.5 then 2 * u * u else 1 - (2 - 2 * u) ^ 2 / 2
end
local function finite(v) return v.X == v.X and v.Y == v.Y and v.Z == v.Z and v.Magnitude < 1e6 end
local function unitOr(v, fallback)
	local m = v.Magnitude
	if m > 1e-6 and m == m then return v / m end
	return fallback
end
--- agent A's perp: d x Y (d x X when d is vertical), then d x that
local function perpA(d)
	local a = d:Cross(Vector3.yAxis)
	if a.Magnitude < 1e-3 then a = d:Cross(Vector3.xAxis) end
	a = a.Unit
	return a, d:Cross(a).Unit
end
--- agent B's perp: n x X (n x Y when n is near X), then n x that
local function perpB(n)
	local o1 = if math.abs(n.X) > 0.85 then n:Cross(Vector3.yAxis) else n:Cross(Vector3.xAxis)
	o1 = o1.Unit
	return o1, n:Cross(o1).Unit
end
local function rotate(axis, angle, v) return CFrame.fromAxisAngle(axis, angle) * v end
local function flat(v) return V3(v.X, 0, v.Z) end
--- the triangular band lift: max over the centres of 1 - |s - c| / hw
local function tri(s, centres, hw)
	local f = 0
	for _, c in ipairs(centres) do
		local x = 1 - math.abs(s - c) / hw
		if x > f then f = x end
	end
	return f
end
--- the band centres c = (k + offset) / spacing for every integer k with lo < c < hi
local function bandCentres(offset, spacing, lo, hi)
	local out = {}
	for k = math.ceil(lo * spacing - offset), math.floor(hi * spacing - offset) do
		out[#out + 1] = (k + offset) / spacing
	end
	return out
end
--- A's Tell envelope: 1 for `hold`, then an exponential decay
local function envA(u, hold, decay)
	if u < 0 then return 0 end
	if u < hold then return 1 end
	return math.exp(-(u - hold) / decay)
end
--- B's Tell envelope: rises (Quad Out), holds, falls (Quad InOut); -> u 0..1
local function envB(age)
	local F = FX.Tell.Flare
	if age == nil or age < 0 then return 0 end
	if age < F.Rise then return qout(age / F.Rise) end
	if age < F.Hold then return 1 end
	if age < F.Fall then return 1 - qinout((age - F.Hold) / (F.Fall - F.Hold)) end
	return 0
end

local function texture(key)
	local v = TX[key]
	if type(v) == "number" then return "rbxassetid://" .. tostring(v) end
	if type(v) == "string" and v ~= "" then return v end
	return nil
end

----------------------------------------------------------------------------------------------------
-- folders
----------------------------------------------------------------------------------------------------
local function fxFolder()
	local V = need("VFXLibrary")
	local name = V and V.Config and V.Config.FXFolderName or "IceMagicFX"
	local f = workspace:FindFirstChild(name)
	if not f then
		f = Instance.new("Folder")
		f.Name = name
		f.Parent = workspace
	end
	return f
end

local own = nil
--- IceMagicFX.UmbraFX: every Beam and part of this module (inside the FX folder every shot's filter already skips)
local function ownFolder()
	if own and own.Parent then return own end
	local parent = fxFolder()
	own = parent:FindFirstChild("UmbraFX")
	if not own then
		own = Instance.new("Folder")
		own.Name = "UmbraFX"
		own.Parent = parent
	end
	return own
end

local function camera()
	return workspace.CurrentCamera
end

local function far(pos)
	local cam = camera()
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude > E.CullDistance
end

----------------------------------------------------------------------------------------------------
-- the pool: Attachments on Terrain, Beams in our folder
----------------------------------------------------------------------------------------------------
local pool = { Atts = {}, Beams = {} }

local function takeAttachment()
	local terrain = workspace.Terrain
	while #pool.Atts > 0 do
		local a = table.remove(pool.Atts)
		if a.Parent == terrain then return a end
	end
	local a = Instance.new("Attachment")
	a.Name = "UmbraKnot"
	a.Parent = terrain
	return a
end

local function giveAttachment(a)
	if a.Parent ~= workspace.Terrain or #pool.Atts >= E.PoolAttachments then
		a:Destroy()
		return
	end
	pool.Atts[#pool.Atts + 1] = a
end

local function takeBeam()
	local folder = ownFolder()
	while #pool.Beams > 0 do
		local b = table.remove(pool.Beams)
		if b.Parent == folder then return b end
	end
	local b = Instance.new("Beam")
	b.Name = "UmbraRibbon"
	b.Enabled = false
	b.Parent = folder
	return b
end

local function giveBeam(b)
	b.Enabled = false
	b.Attachment0 = nil
	b.Attachment1 = nil
	if b.Parent ~= ownFolder() or #pool.Beams >= E.PoolBeams then
		b:Destroy()
		return
	end
	pool.Beams[#pool.Beams + 1] = b
end

----------------------------------------------------------------------------------------------------
-- THE RIBBON: k Beams chained on k + 1 Attachments
----------------------------------------------------------------------------------------------------
local Ribbon = {}
Ribbon.__index = Ribbon

local EPS_A = 0.004           -- A's fit: the tangent by +-0.004 in s (one-sided at the chain's ends)
local EPS_B = 1 / 480         -- B's fit: the tangent by +-1/480 s of path time
local MAX_KEYS = 20           -- a ColorSequence / NumberSequence holds at most 20 keypoints
local STD_COLOUR = { 0.33, 0.67 }
local STD_ALPHA = { 0.1, 0.25, 0.5, 0.75, 0.9 }

--- style "A" | "B"; kind "light" | "shadow"; beams 1 | 2; faceCamera (A only: B is always true); speed (B's TextureSpeed)
local function newRibbon(style, kind, beams, segments, faceCamera, speed)
	local self = setmetatable({ Style = style, Kind = kind, K = beams, Atts = {}, Beams = {}, LastAlpha = -1,
		FaceCamera = faceCamera }, Ribbon)
	for j = 0, beams do self.Atts[j] = takeAttachment() end
	local texKey = (style == "A") and (kind == "light" and "RibbonLightA" or "RibbonShadowA")
		or (kind == "light" and "RibbonLightB" or "RibbonShadowB")
	local tex = texture(texKey)
	self.Textured = tex ~= nil
	local wb = (style ~= "A") and wrapped("RibbonB", nil) or nil      -- a wrap's multiply and gain for B's baked strip
	self.Gain = (wb and wb.Gain[kind]) or 1
	for j = 1, beams do
		local b = takeBeam()
		b.Attachment0, b.Attachment1 = self.Atts[j - 1], self.Atts[j]
		b.Segments = segments
		b.FaceCamera = faceCamera
		b.LightInfluence = 0
		b.ZOffset = 0
		b.TextureMode = Enum.TextureMode.Stretch
		b.TextureLength = 1
		b.Texture = tex or ""
		b.Brightness = 1
		b.Width0, b.Width1, b.CurveSize0, b.CurveSize1 = 0, 0, 0, 0
		b.Transparency = NumberSequence.new(1)
		if style == "A" then
			b.TextureSpeed = 0
			b.Color = ColorSequence.new(FX.RibbonA[kind].Rest)            -- rewritten every frame (the running band)
			b.LightEmission = FX.RibbonA[kind].Emission
		else
			b.TextureSpeed = speed * E.TextureSpeedSign
			-- no strip uploaded yet: the body colour the strip would have carried
			b.Color = ColorSequence.new(tex and (wb and wb.Tint[kind] or Color3.new(1, 1, 1))
				or (wb or FX.RibbonB).Untextured[kind])
			b.LightEmission = FX.RibbonB.Quiet[kind]
		end
		b.Enabled = false
		self.Beams[j] = b
	end
	return self
end

--- B's per-ribbon TextureSpeed, +-SpeedJitter by index (no texture offset exists, so the bands must not march in step)
local function jitterSpeed(base, i)
	local j = FX.RibbonB.SpeedJitter
	return base * (1 - j + 2 * j * (((i * 7) % 11) / 10))
end

function Ribbon:hide()
	for _, b in ipairs(self.Beams) do
		if b.Enabled then b.Enabled = false end
	end
end

function Ribbon:free()
	for _, b in ipairs(self.Beams) do giveBeam(b) end
	for j = 0, self.K do giveAttachment(self.Atts[j]) end
	self.Beams, self.Atts = {}, {}
end

--- One knot: the Attachment at p with its Axis (X) on the tangent. wv = the strip's width direction (FaceCamera false)
--- or nil (FaceCamera true: only the axis matters).
local function placeKnot(att, p, axis, wv)
	local y
	if wv then
		wv = wv - axis * wv:Dot(axis)
		if wv.Magnitude < 1e-5 then wv = (perpA(axis)) end
		wv = wv.Unit
		y = if E.WidthOnSecondaryAxis then wv else axis:Cross(wv)
	else
		local up = if math.abs(axis.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
		y = (up - axis * up:Dot(axis)).Unit
	end
	att.WorldCFrame = CFrame.fromMatrix(p, axis, y)
end

--- The sample points of one Beam's sequence over [sa, sb]: its ends, the standard fractions and every knot inside,
--- ascending, de-duplicated, at most MAX_KEYS, the first exactly sa and the last exactly sb.
local function sampleSpan(sa, sb, std, knots)
	local ds = sb - sa
	local list = { sa, sb }
	for _, f in ipairs(std) do list[#list + 1] = sa + ds * f end
	if knots then
		for _, x in ipairs(knots) do
			if x > sa and x < sb then list[#list + 1] = x end
		end
	end
	table.sort(list)
	local out, last = {}, -math.huge
	for _, x in ipairs(list) do
		if x - last > ds * 1e-3 then
			out[#out + 1] = x
			last = x
		end
	end
	out[#out] = sb
	if #out > MAX_KEYS then
		local thin = { out[1] }
		local n = #out
		for m = 1, MAX_KEYS - 2 do thin[#thin + 1] = out[1 + math.floor(m * (n - 1) / (MAX_KEYS - 1) + 0.5)] end
		thin[#thin + 1] = out[n]
		out = thin
	end
	return out
end

local function colourSeq(fn, sa, sb, knots)
	local xs = sampleSpan(sa, sb, STD_COLOUR, knots)
	local ds = sb - sa
	local kps, lastT = {}, -1
	for idx, x in ipairs(xs) do
		local t = if idx == 1 then 0 elseif idx == #xs then 1 else clamp01((x - sa) / ds)
		if t > lastT then
			kps[#kps + 1] = ColorSequenceKeypoint.new(t, fn(x))
			lastT = t
		end
	end
	if #kps < 2 then return ColorSequence.new(fn(sa), fn(sb)) end
	return ColorSequence.new(kps)
end

local function alphaSeq(fn, sa, sb, knots)
	local xs = sampleSpan(sa, sb, STD_ALPHA, knots)
	local ds = sb - sa
	local kps, lastT = {}, -1
	for idx, x in ipairs(xs) do
		local t = if idx == 1 then 0 elseif idx == #xs then 1 else clamp01((x - sa) / ds)
		if t > lastT then
			kps[#kps + 1] = NumberSequenceKeypoint.new(t, math.clamp(1 - fn(x), 0, 1))
			lastT = t
		end
	end
	if #kps < 2 then return NumberSequence.new(math.clamp(1 - fn(sa), 0, 1)) end
	return NumberSequence.new(kps)
end

--- AGENT A'S FIT (A_r3 common.beam_chain_fit). a = {
---   C(s) -> Vector3 (s = 0 at the ribbon's leading end), SMax, Side(s, p, axis) -> width direction or nil,
---   Width(s), Colour(s) -> Color3, ColourKnots, Alpha(s) -> opacity 0..1, AlphaKnots, Brightness, Emission }
function Ribbon:drawA(a)
	local k, smax = self.K, a.SMax
	if not (smax > 1e-3) then return self:hide() end
	local nodes = {}
	for j = 0, k do
		local s = smax * j / k
		local lo, hi = math.max(0, s - EPS_A), math.min(smax, s + EPS_A)
		local p = a.C(s)
		if not finite(p) then return self:hide() end
		local d = (a.C(hi) - a.C(lo)) / math.max(hi - lo, 1e-9)
		local sp = d.Magnitude
		local axis
		if sp > 1e-7 and sp == sp then
			axis = d / sp
		else
			sp = 0
			axis = (j > 0 and nodes[j - 1].Axis) or Vector3.zAxis
		end
		local w = a.Side and a.Side(s, p, axis) or nil
		if w and j > 0 and nodes[j - 1].W and w:Dot(nodes[j - 1].W) < 0 then w = -w end   -- a flat strip: keep sides aligned
		nodes[j] = { P = p, Axis = axis, Speed = sp, W = w, S = s }
	end
	for j = 0, k do
		local n = nodes[j]
		placeKnot(self.Atts[j], n.P, n.Axis, (not self.FaceCamera) and n.W or nil)
	end
	for j = 1, k do
		local b = self.Beams[j]
		local n0, n1 = nodes[j - 1], nodes[j]
		local ds = n1.S - n0.S
		b.CurveSize0 = n0.Speed * ds / 3
		b.CurveSize1 = n1.Speed * ds / 3 * E.CurveSize1Sign
		b.Width0 = math.max(0, a.Width(n0.S))
		b.Width1 = math.max(0, a.Width(n1.S))
		b.Color = colourSeq(a.Colour, n0.S, n1.S, a.ColourKnots)
		b.Transparency = alphaSeq(a.Alpha, n0.S, n1.S, a.AlphaKnots)
		b.Brightness = a.Brightness
		b.LightEmission = a.Emission
		if not b.Enabled then b.Enabled = true end
	end
end

-- B's width profile along the chain (f = 0 tail .. 1 head): tail 0.25, full by the middle, head 0.85
local function profileB(f) return 0.25 + 0.75 * sstep(0, 0.5, f) - 0.15 * f end

local function seqAt(keys, f)
	if f <= keys[1][1] then return keys[1][2] end
	for i = 1, #keys - 1 do
		local p, q = keys[i], keys[i + 1]
		if f <= q[1] then return p[2] + (q[2] - p[2]) * (f - p[1]) / math.max(q[1] - p[1], 1e-9) end
	end
	return keys[#keys][2]
end

--- the slice [f0, f1] of B's whole-ribbon Transparency, re-based to 0..1 and faded by alphaMul
local function subSeq(f0, f1, alphaMul)
	local keys = FX.RibbonB.Transparency
	local function tr(v) return math.clamp(1 - (1 - v) * alphaMul, 0, 1) end
	local pts = { NumberSequenceKeypoint.new(0, tr(seqAt(keys, f0))) }
	for _, kk in ipairs(keys) do
		if kk[1] > f0 + 1e-4 and kk[1] < f1 - 1e-4 then
			pts[#pts + 1] = NumberSequenceKeypoint.new((kk[1] - f0) / (f1 - f0), tr(kk[2]))
		end
	end
	pts[#pts + 1] = NumberSequenceKeypoint.new(1, tr(seqAt(keys, f1)))
	return NumberSequence.new(pts)
end

--- AGENT B'S FIT (B_r3 RibbonBeams:draw). path(tau) -> Vector3; the head at tau, the tail span seconds back; W the full
--- width; alphaMul 0..1; brightness and flare 0..1 (the Tell, or Eclipse's shade swell); twist(tau) -> radians or nil.
function Ribbon:drawB(path, tau, span, W, alphaMul, brightness, flareU, twist)
	if alphaMul <= 0.004 or W <= 1e-3 or span <= 1e-4 then return self:hide() end
	local k = self.K
	local h = span / k
	local P, D = {}, {}
	for j = 0, k do
		local x = tau - span + j * h
		P[j] = path(x)
		D[j] = (path(x + EPS_B) - path(x - EPS_B)) / (2 * EPS_B)
		if not (finite(P[j]) and finite(D[j])) then return self:hide() end
	end
	local len = 0
	for j = 1, k do len += (P[j] - P[j - 1]).Magnitude end
	if len < 0.03 then return self:hide() end
	for j = 0, k do
		local d = D[j]
		if d.Magnitude < 1e-6 then d = if j < k then P[j + 1] - P[j] else P[j] - P[j - 1] end
		placeKnot(self.Atts[j], P[j], unitOr(d, Vector3.zAxis), nil)
	end
	local q, fl = FX.RibbonB.Quiet[self.Kind], FX.RibbonB.Flare[self.Kind]
	local le = q + (fl - q) * flareU
	local rewriteT = math.abs(alphaMul - self.LastAlpha) > 0.01
	for j = 1, k do
		local b = self.Beams[j]
		local f0, f1 = (j - 1) / k, j / k
		local w0, w1 = W * profileB(f0), W * profileB(f1)
		if twist then
			w0 *= 0.35 + 0.65 * math.abs(math.cos(twist(tau - span + (j - 1) * h)))
			w1 *= 0.35 + 0.65 * math.abs(math.cos(twist(tau - span + j * h)))
		end
		b.Width0, b.Width1 = w0, w1
		b.CurveSize0 = D[j - 1].Magnitude * h / 3
		b.CurveSize1 = D[j].Magnitude * h / 3 * E.CurveSize1Sign
		if rewriteT then b.Transparency = subSeq(f0, f1, alphaMul) end
		b.Brightness = brightness * self.Gain
		b.LightEmission = le
		if not b.Enabled then b.Enabled = true end
	end
	if rewriteT then self.LastAlpha = alphaMul end
end

-- A's colours for a kind at Tell level L. Roblox multiplies the strip by Color; with no strip uploaded yet the Color
-- itself is multiplied by the strip's body colour (Untextured), so a shadow ribbon still reads dark.
local function mulC(a, b) return Color3.new(a.R * b.R, a.G * b.G, a.B * b.B) end
local function texturedA(kind) return texture(kind == "light" and "RibbonLightA" or "RibbonShadowA") ~= nil end
local function restA(kind)
	local R = wrapped("RibbonA", FX.RibbonA)[kind]
	return if texturedA(kind) then R.Rest else mulC(R.Rest, R.Untextured)
end
local function bandA(kind, L)
	local A = wrapped("RibbonA", FX.RibbonA)
	local R = A[kind]
	local band = R.Band:Lerp(A.Lit, L)
	return if texturedA(kind) then band else mulC(band, R.Untextured)
end
local function brightA(L) return 1 + FX.RibbonA.BrightnessGain * L end
local function emissionA(kind, L) return FX.RibbonA[kind].Emission + FX.RibbonA[kind].EmissionGain * L end

----------------------------------------------------------------------------------------------------
-- THE BALL RECIPE (A_r4)
----------------------------------------------------------------------------------------------------
local Ball = {}
Ball.__index = Ball

local function ballTemplate()
	local meshes = ReplicatedStorage:FindFirstChild("IceMagicMeshes")
	local kit = meshes and meshes:FindFirstChild("UmbraKit")
	local t = kit and kit:FindFirstChild(FX.Ball.Template)
	return (t and t:IsA("BasePart")) and t or nil
end

--- rangeRadius: the ball's full radius (the light's Range is LightRangeK x this x the scale passed to put)
local function newBall(rangeRadius, firstPerson, plain)
	local B = FX.Ball
	-- THE BODY (2026-09-28, the owner: the balls mirrored the map and the sky, "i want it exactly how it was in the
	-- video"): the r4 ball as the preview rendered it, baked into a sprite drawn on the rim's own billboard, under the
	-- rim -- BallBody1P for the caster's own first-person balls, BallBody3P for every other view, the two angles the
	-- video shows. A sphere looks the same from every side, so the sprite is the ball; nothing on it reflects. The
	-- part stays for the PointLight and, in third person, the ball's shadow (B.ShadowOnly: nearly invisible, and a
	-- semi-transparent part still casts a full shadow). No sprite: the old glossy part, template or fallback.
	local moon = (not plain) and wrapped("BallMoon", nil) or nil     -- a wrap's own body for the round balls
	local bodyImg = moon and moon.Image or texture(firstPerson and "BallBody1P" or "BallBody3P")
	local part = nil
	if not bodyImg then
		local tpl = ballTemplate()
		if tpl then
			local ok, c = pcall(function() return tpl:Clone() end)
			if ok and c then part = c end
		end
	end
	if not part then
		if not bodyImg then
			warnOnce("template", "no ReplicatedStorage.IceMagicMeshes.UmbraKit." .. tostring(B.Template)
				.. ": the balls use the SmoothPlastic fallback (no gloss map)")
		end
		part = Instance.new("Part")
		part.Shape = Enum.PartType.Block
		part.Reflectance = if bodyImg then 0 else B.FallbackReflectance
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = part
	end
	part.Name = "UmbraBall"
	part.Material = Enum.Material.SmoothPlastic
	part.Color = PAL.Void
	part.Anchored, part.CanCollide, part.CanQuery, part.CanTouch = true, false, false, false
	part.CastShadow = not firstPerson
	part.Massless = true
	part.Transparency = 1
	part.Size = Vector3.one * 0.05
	part.Parent = ownFolder()
	local light = Instance.new("PointLight")
	light.Color = PAL.Shade
	light.Shadows = false
	light.Brightness = 0
	light.Enabled = false
	light.Parent = part
	-- the rim + halo: one camera-facing billboard, moved every frame half way out on the ball's near side
	local att = Instance.new("Attachment")
	att.Name = "UmbraBallRim"
	att.Parent = workspace.Terrain
	local bb = Instance.new("BillboardGui")
	bb.Name = "UmbraBallRim"
	bb.Adornee = att
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Brightness = 1
	bb.ClipsDescendants = false
	bb.ResetOnSpawn = false
	bb.MaxDistance = B.MaxDistance
	bb.Enabled = false
	local img = texture("BallRimHalo")
	local rim, stroke
	if img then
		rim = Instance.new("ImageLabel")
		rim.Image = img
		rim.BackgroundTransparency = 1
		rim.ImageColor3 = PAL.Shade
		rim.AnchorPoint = Vector2.new(0.5, 0.5)
		rim.Position = UDim2.fromScale(0.5, 0.5)
		rim.Size = UDim2.fromScale(1, 1)
		rim.Parent = bb
	else
		-- no rim image yet: a thin stroked ring on the silhouette (1 / RimExtent of the billboard)
		rim = Instance.new("Frame")
		rim.BackgroundTransparency = 1
		rim.AnchorPoint = Vector2.new(0.5, 0.5)
		rim.Position = UDim2.fromScale(0.5, 0.5)
		rim.Size = UDim2.fromScale(1 / B.RimExtent, 1 / B.RimExtent)
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = rim
		stroke = Instance.new("UIStroke")
		stroke.Color = PAL.Shade
		stroke.Transparency = 0.35
		stroke.Thickness = 1
		stroke.Parent = rim
		rim.Parent = bb
	end
	rim.ZIndex = 2
	local body = nil
	if bodyImg then
		-- the sprite's disc fills its image edge to edge: 1 / RimExtent of the billboard is the ball's silhouette
		body = Instance.new("ImageLabel")
		body.Name = "Body"
		body.Image = bodyImg
		body.ImageColor3 = wrapped("BallBodyTint", Color3.new(1, 1, 1))
		if moon then
			-- the image's disc cut out of its black square, shaded from its lit limb to its dark one
			body.ImageColor3 = Color3.new(1, 1, 1)
			body.ImageRectOffset, body.ImageRectSize = moon.RectOffset, moon.RectSize
			local round = Instance.new("UICorner")
			round.CornerRadius = UDim.new(0.5, 0)
			round.Parent = body
			local shade = Instance.new("UIGradient")
			shade.Color = ColorSequence.new(moon.Lit, moon.Dark)
			shade.Rotation = moon.Rotation
			shade.Parent = body
		end
		body.BackgroundTransparency = 1
		body.AnchorPoint = Vector2.new(0.5, 0.5)
		body.Position = UDim2.fromScale(0.5, 0.5)
		body.Size = UDim2.fromScale(1 / B.RimExtent, 1 / B.RimExtent)
		body.ZIndex = 1
		body.Parent = bb
	end
	bb.Parent = att
	return setmetatable({ Part = part, Light = light, Att = att, Gui = bb, Rim = rim, Stroke = stroke, Body = body,
		PartT = if body then (if firstPerson then 1 else B.ShadowOnly) else 0,
		RangeRadius = rangeRadius, Shown = false }, Ball)
end

function Ball:hide()
	if not self.Shown then return end
	self.Shown = false
	self.Part.Transparency = 1
	self.Light.Enabled = false
	self.Gui.Enabled = false
end

function Ball:free()
	self.Att:Destroy()
	self.Part:Destroy()
end

--- Place the ball: cf, size (its full Size), g (its growth 0..1, for the light), L (the Tell), shape "sphere" | "dart",
--- scale (the light's range scale: S, sd or 1), attachK (the sphere's billboard offset toward the camera in radii;
--- nil = Ball.AttachK). The billboard is flat, so anything between it and the camera cuts the sprite along a straight
--- line: the first-person charge ball sits at the fist and passes a larger attachK, which lifts its billboard in
--- front of the fist -- the same place and size on screen, never sliced by the knuckles (the owner, 2026-09-30).
function Ball:put(cf, size, g, L, shape, scale, attachK)
	local B = FX.Ball
	if not (size and size.X > 0.008 and finite(cf.Position)) then return self:hide() end
	self.Shown = true
	local part = self.Part
	part.Size = size
	part.CFrame = cf
	if part.Transparency ~= self.PartT then part.Transparency = self.PartT end
	local glint = PAL.Shade:Lerp(PAL.Glint, L)
	local light = self.Light
	light.Enabled = true
	light.Color = glint
	light.Range = B.LightRangeK * self.RangeRadius * (scale or 1)
	light.Brightness = B.LightBrightness * clamp01(g) * (1 + B.TellLightGain * L)
	-- the rim
	local cam = camera()
	if not cam then
		self.Gui.Enabled = false
		return
	end
	local camCF = cam.CFrame
	local camPos = camCF.Position
	local c = cf.Position
	local gui, rim = self.Gui, self.Rim
	if self.Stroke then self.Stroke.Color = glint elseif rim:IsA("ImageLabel") then rim.ImageColor3 = glint end
	if shape == "dart" then
		-- an ellipsoid a across, b along the flight: the image centred on the projected tips, stretched and turned
		local a, b = size.X / 2, size.Z / 2
		local axis = cf.LookVector
		local fwd = camCF.LookVector
		local toward = camPos - c
		local d = toward.Magnitude
		local function depth(p) return (p - camPos):Dot(fwd) end
		if d < 1e-3 or depth(c) < 1 or depth(c + axis * b) <= 0.05 or depth(c - axis * b) <= 0.05 then
			gui.Enabled = false              -- the projection divides by depth: never a huge billboard for a frame
			return
		end
		toward /= d
		local ct = axis:Dot(toward)
		local rdep = math.sqrt(math.max(a * a * (1 - ct * ct) + b * b * ct * ct, 1e-9))
		if d * d - rdep * rdep <= 1e-6 then
			gui.Enabled = false
			return
		end
		local q0 = c + toward * (B.AttachK * rdep)
		local dq = depth(q0)
		local function onPlane(p) return camPos + (p - camPos) * (dq / depth(p)) end
		local n, tl = onPlane(c + axis * b), onPlane(c - axis * b)
		self.Att.WorldPosition = (n + tl) / 2
		local st = (axis - fwd * axis:Dot(fwd)).Magnitude
		local kk = (dq / depth(c)) * d / math.sqrt(d * d - rdep * rdep)
		local half = (n - tl).Magnitude / 2
		local major = math.max(half + (math.sqrt(b * b * st * st + a * a * (1 - st * st)) - b * st) * kk, a * kk)
		local side = 2 * B.RimExtent * major
		gui.Size = UDim2.fromScale(side, side)
		local u = unitOr(n - tl, camCF.RightVector)
		local minor = math.clamp(a * kk / math.max(major, 1e-6), 0.02, 1)
		if rim:IsA("ImageLabel") then
			rim.Size = UDim2.fromScale(1, minor)
		else
			rim.Size = UDim2.fromScale(1 / B.RimExtent, minor / B.RimExtent)
		end
		rim.Rotation = -math.deg(math.atan2(u:Dot(camCF.UpVector), u:Dot(camCF.RightVector)))
		if self.Body then
			self.Body.Size = UDim2.fromScale(1 / B.RimExtent, minor / B.RimExtent)
			self.Body.Rotation = rim.Rotation
		end
	else
		local R = (size.X + size.Y) / 4                                    -- a stretched ball: the mean half size
		local toward = camPos - c
		local d = toward.Magnitude
		if d <= R * 1.2 then
			gui.Enabled = false
			return
		end
		local rOff = math.min((attachK or B.AttachK) * R, 0.5 * d)
		self.Att.WorldPosition = c + toward / d * rOff
		local k = (d - rOff) / math.sqrt(math.max(d * d - R * R, 1e-6))
		local side = 2 * B.RimExtent * R * k
		gui.Size = UDim2.fromScale(side, side)
		if self.Body then
			-- the body keeps a stretched ball's proportions (Eclipse's core pulled wide at the open: X along cf's right)
			self.Body.Size = UDim2.fromScale(size.X / (2 * R) / B.RimExtent, size.Y / (2 * R) / B.RimExtent)
		end
	end
	if self.Stroke then
		local px = rim.AbsoluteSize.X
		self.Stroke.Thickness = math.clamp(px * 0.05, 1, 6)
	end
	if not gui.Enabled then gui.Enabled = true end
end

----------------------------------------------------------------------------------------------------
-- THE DRIVER: one render step for every live effect
----------------------------------------------------------------------------------------------------
local live = {}
local bound = false
local STEP_NAME = "UmbraFX"

local function stopEffect(e)
	if e.Dead then return end
	e.Dead = true
	if e.Stop then
		local prev = CUR
		CUR = e.Wrap
		local ok, err = pcall(e.Stop, e)
		CUR = prev
		if not ok then warnOnce("stop:" .. tostring(e.Name), tostring(e.Name) .. " cleanup failed: " .. tostring(err)) end
	end
end

local function driver(dt)
	local now = os.clock()
	if camera() then
		for i = #live, 1, -1 do
			local e = live[i]
			local alive = false
			if not e.Dead and now - e.Born <= e.MaxLife then
				CUR = e.Wrap
				local ok, res = pcall(e.Step, e, now, dt)
				CUR = nil
				if ok then
					alive = res ~= false
				else
					warnOnce("step:" .. tostring(e.Name), tostring(e.Name) .. " failed and was removed: " .. tostring(res))
				end
			end
			if not alive then
				stopEffect(e)
				table.remove(live, i)
			end
		end
	end
	if #live == 0 and bound then
		bound = false
		RunService:UnbindFromRenderStep(STEP_NAME)
	end
end

--- Start an effect: e.Step(e, now, dt) -> false when done; e.Stop(e) gives its instances back.
local function run(e)
	e.Born = e.Born or os.clock()
	e.Wrap = e.Wrap or CUR
	e.MaxLife = e.MaxLife or (E.MaxLife / timeScale())
	live[#live + 1] = e
	if not bound then
		bound = true
		RunService:BindToRenderStep(STEP_NAME, Enum.RenderPriority.Camera.Value + E.RenderPriority, driver)
	end
	return e
end

function UmbraFX.StopAll()
	for i = #live, 1, -1 do
		stopEffect(live[i])
		live[i] = nil
	end
end

local function freeAll(list)
	for _, r in pairs(list) do
		if type(r) == "table" and r.free then r:free() elseif type(r) == "table" and r.Rib then r.Rib:free() end
	end
end

----------------------------------------------------------------------------------------------------
-- THE TELL
----------------------------------------------------------------------------------------------------
local tellAt = setmetatable({}, { __mode = "k" })        -- [character] = { At, Reason, Scale }

--- A's level for a character's body-attached ribbons and balls: the last Tell's envelope (0 when none)
local function tellA(character, now)
	local rec = character and tellAt[character]
	if not rec then return 0 end
	local env = (rec.Reason == "Hit") and FX.Tell.Hit or FX.Tell.Release
	return envA((now - rec.At) * rec.Scale, env.Hold, env.Decay)
end

--- B's level (0..1) for the same
local function tellB(character, now)
	local rec = character and tellAt[character]
	if not rec then return 0 end
	return envB((now - rec.At) * rec.Scale)
end

local function torsoOf(character)
	return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
		or character:FindFirstChild("HumanoidRootPart")
end

function UmbraFX.Tell(character, reason)
	if not FX or typeof(character) ~= "Instance" then return end
	tellAt[character] = { At = os.clock(), Reason = reason, Scale = timeScale() }
	-- the glint on the chest, for everyone else (your own lights your own view in first person: skipped)
	local BL = FX.Tell.BodyLight
	if not (BL and BL.Brightness > 0) then return end
	if character == player.Character and UmbraFX.LocalFirstPerson() then return end
	local torso = torsoOf(character)
	if not torso then return end
	local old = torso:FindFirstChild("UmbraTell")
	if old then old:Destroy() end
	local l = Instance.new("PointLight")
	l.Name = "UmbraTell"
	l.Color = PAL.Glint
	l.Range = BL.Range
	l.Shadows = false
	l.Brightness = BL.Brightness
	l.Parent = torso
	local scale = timeScale()
	run({
		Name = "TellLight", Start = os.clock(),
		Step = function(e, now)
			local u = (now - e.Start) * scale
			if u >= BL.Time or not l.Parent then return false end
			l.Brightness = BL.Brightness * (1 - qout(u / BL.Time))
			return true
		end,
		Stop = function() if l.Parent then l:Destroy() end end,      -- a newer Tell may have replaced it already
	})
end

----------------------------------------------------------------------------------------------------
-- M1: SHADOW DART -- THE CHARGE (A_r3 charge + A_r4 ball)
----------------------------------------------------------------------------------------------------
--- Where the charge is drawn this frame: the local player's viewmodel fist (first person), else the body's right hand.
local function chargeFrame(character)
	local C = FX.DartCharge
	local cam = camera()
	if character == player.Character then
		local fist = vmCall("GetFistCFrame", "R")
		if typeof(fist) == "CFrame" and cam then
			local pos = (fist * CFrame.new(C.FistBall)).Position
			local dist = (pos - cam.CFrame.Position).Magnitude
			local S1 = C.Scale1P
			return { FirstPerson = true, C = pos, S = S1.K * math.clamp(dist / S1.Near, S1.Min, 1) ^ S1.Power }
		end
	end
	local hand = character:FindFirstChild("RightHand")
	if hand then
		local palm = (hand.CFrame * CFrame.new(C.Palm)).Position
		local lower = character:FindFirstChild("RightLowerArm")
		local upper = character:FindFirstChild("RightUpperArm")
		local p1 = lower and (lower.CFrame * CFrame.new(C.LowerArm)).Position or palm + Vector3.yAxis
		local p2 = upper and (upper.CFrame * CFrame.new(C.UpperArm)).Position or p1 + Vector3.yAxis
		return { FirstPerson = false, C = palm, S = 1, Arm = { palm, p1, p2 } }
	end
	local arm = character:FindFirstChild("Right Arm")                   -- R6
	if arm then
		local palm = (arm.CFrame * CFrame.new(0, -arm.Size.Y / 2, 0)).Position
		return { FirstPerson = false, C = palm, S = 1, Arm = { palm, arm.Position, (arm.CFrame * CFrame.new(0, arm.Size.Y / 2, 0)).Position } }
	end
	return nil
end

--- the point at fraction f of the arm polyline's length from the palm, and that segment's direction
local function armPoint(pts, f)
	local total = 0
	local segs = {}
	for i = 1, #pts - 1 do
		segs[i] = (pts[i + 1] - pts[i]).Magnitude
		total += segs[i]
	end
	local d = clamp01(f) * total
	for i = 1, #segs do
		if d <= segs[i] or i == #segs then
			local u = clamp01(d / math.max(segs[i], 1e-6))
			return pts[i]:Lerp(pts[i + 1], u), unitOr(pts[i + 1] - pts[i], Vector3.yAxis)
		end
		d -= segs[i]
	end
	return pts[1], Vector3.yAxis
end

--- The charge on `character`'s right hand (or the local viewmodel's fist): started at `start` (os.clock), releasing
--- `due` seconds later (Windup / M1RateMult / ShotTimeScale). The drawing's own clock (DartCharge.SpecWindup) is mapped
--- onto the real charge, so an Eclipse-quickened charge plays the same drawing faster.
function UmbraFX.DartCharge(character, start, due)
	if not FX or typeof(character) ~= "Instance" then return NULL end
	local C = FX.DartCharge
	local W = C.SpecWindup
	local e = { Name = "DartCharge", Character = character, Start = start or os.clock(), Due = math.max(due or W, 0.05),
		Scale = timeScale(), Released = false, CancelAt = nil, BallPos = nil, Ribs = {} }
	e.Ball = newBall(C.CoreRadius, character == player.Character)
	for i, def in ipairs(C.Ribbons) do
		local i0 = i - 1
		local n = def.Normal.Unit
		local o1, o2 = perpA(n)
		e.Ribs[i] = { Rib = newRibbon("A", def.Kind, 2, FX.RibbonA.Segments, false), Kind = def.Kind, I = i0,
			O1 = o1, O2 = o2, K = def.Precess.Unit, Phi0 = 1.7 * i0, Psi0 = 2.1 * i0 + 0.4, Chi0 = 1.3 * i0 }
	end

	local function clock(now)
		local el = now - e.Start
		if el <= e.Due then return el * (W / e.Due) end
		return W + (el - e.Due) * e.Scale
	end

	function e.Release(self)
		self.Released = true
		local el = os.clock() - self.Start
		if el < self.Due then self.Due = math.max(el, 0.05) end        -- an early release (a late start) snaps to it
	end
	function e.Cancel(self)
		self.CancelAt = self.CancelAt or os.clock()
	end
	--- the server counts a longer charge (Eclipse ended between the click and its arrival): only ever lengthened
	function e.SetDue(self, newDue)
		if type(newDue) == "number" and newDue > self.Due and not self.Released then self.Due = newDue end
	end
	function e.BallPosition(self)
		return self.BallPos
	end

	e.Step = function(self, now)
		local c = self.Character
		if not c.Parent then return false end
		local t = clock(now)
		local ur = t - W
		local fade = 1
		if self.CancelAt then
			fade = 1 - clamp01((now - self.CancelAt) / C.CancelFade)
			if fade <= 0 then return false end
		end
		if ur > C.LastFor then return false end
		local fr = chargeFrame(c)
		local cam = camera()
		if not fr or (not fr.FirstPerson and far(fr.C)) then
			self.Ball:hide()
			for _, r in ipairs(self.Ribs) do r.Rib:hide() end
			return true
		end
		local camPos = cam.CFrame.Position
		local S = fr.S
		local L = 0
		if self.Released and not self.CancelAt then L = envA(ur, FX.Tell.Release.Hold, FX.Tell.Release.Decay) end
		L = math.max(L, tellA(c, now))
		-- the core: grows over the long gather, collapses at the release
		local rc = S * C.CoreRadius * sio((t - C.CoreFrom) / C.CoreGrow) * (1 - sstep(0, C.CoreCollapse, ur)) * fade
		self.Ball:put(CFrame.new(fr.C) * CFrame.Angles(0, C.CoreSpin * t, 0), Vector3.one * (2 * rc),
			rc / (C.CoreRadius * S), L, "sphere", S, if fr.FirstPerson then C.AttachK1P else nil)
		self.BallPos = fr.C
		-- the four ribbons
		local urp = math.max(0, ur)
		local R = S * (C.Orbit - C.Tighten.By * sstep(C.Tighten.From, C.Tighten.To, t)) * (1 - sstep(0, C.Collapse, urp))
		local births = fr.FirstPerson and C.Births1P or C.Births3P
		for _, rb in ipairs(self.Ribs) do
			local b = births[rb.I + 1]
			local rib = rb.Rib
			if t < b + 0.03 or ur > 0.11 then
				rib:hide()
				continue
			end
			local kind = rb.Kind
			local function orbit(tau)
				local pr = 0.45 * tau                                          -- the loop's plane precesses
				local o1, o2 = rotate(rb.K, pr, rb.O1), rotate(rb.K, pr, rb.O2)
				local psi = rb.Psi0 + TAU * tau + TAU * 3 * urp * urp / 0.1   -- one turn a second; whips round at the release
				return fr.C + (o1 * math.cos(psi) + o2 * math.sin(psi)) * R
			end
			local function head(tau)
				local u = (tau - b) / C.SpiralIn
				local o = orbit(tau)
				if u >= 1 then return o end
				if fr.FirstPerson then return fr.C + (o - fr.C) * (1 + 0.35 * (1 - sio(u))) end
				-- 3P: in along the forearm on a spiral, then onto the loop
				local ee = sio(u)
				local pt, dir = armPoint(fr.Arm, 0.8 * (1 - ee))
				local n1, n2 = perpA(dir)
				local phi = rb.Phi0 + TAU * 1.3 * (tau - b)
				local inflow = pt + (n1 * math.cos(phi) + n2 * math.sin(phi)) * (S * (0.85 - 0.50 * ee))
				return inflow:Lerp(o, sstep(0.55, 1, u))
			end
			local life = sstep(b, b + 0.25, t) * (1 - sstep(0.02, 0.10, ur)) * fade
			local smax = math.min(1, (t - b) / C.Length)
			local Wd = C.Width[kind] * S * life
			local hw = 0.07 + 0.30 * L
			local cents = bandCentres(0.5 - 1.1 * t - 0.37 * rb.I, 1.4, -hw, smax + hw)   -- runs toward the ball
			local knots = {}
			for _, cc in ipairs(cents) do
				knots[#knots + 1] = cc - hw
				knots[#knots + 1] = cc
				knots[#knots + 1] = cc + hw
			end
			local rest, band = restA(kind), bandA(kind, L)
			rib:drawA({
				C = function(s) return head(math.max(b, t - C.Length * s)) end,
				SMax = smax,
				Side = function(s, p, axis)
					local tau = t - C.Length * s
					local side = unitOr(axis:Cross(camPos - p), (perpA(axis)))       -- facing the camera...
					local chi = C.Twist * math.sin(math.pi * tau + rb.Chi0)         -- ...plus the slow silk twist
					return side * math.cos(chi) + axis:Cross(side) * math.sin(chi)
				end,
				Width = function(s) return Wd * (0.6 + 0.4 * sstep(0, 0.10, s)) * (1 - 0.75 * sstep(0.45, 1, s)) end,
				Colour = function(s) return rest:Lerp(band, tri(s, cents, hw)) end,
				ColourKnots = knots,
				Alpha = function(s) return 0.95 * (1 - s ^ 1.6) * (0.55 + 0.45 * sstep(0, 0.05, s)) end,
				Brightness = brightA(L),
				Emission = emissionA(kind, L),
			})
		end
		return true
	end
	e.Stop = function(self)
		self.Ball:free()
		freeAll(self.Ribs)
	end
	return run(e)
end

----------------------------------------------------------------------------------------------------
-- M1: SHADOW DART -- IN FLIGHT (A_r3 dart + A_r4 head). UmbraClient flies it and moves this every Heartbeat.
----------------------------------------------------------------------------------------------------
function UmbraFX.Dart(owner)
	if not FX then return NULL end
	local D = FX.Dart
	local W = FX.DartCharge.SpecWindup
	local e = { Name = "Dart", Character = owner, Start = os.clock(), Scale = timeScale(), Pos = nil, Dir = nil, Tr = 0,
		ImpactAt = nil, Expiring = false, Ribs = {} }
	e.Ball = newBall(D.LightRadius, false, true)
	for j, kind in ipairs(D.Kinds) do
		e.Ribs[j] = { Rib = newRibbon("A", kind, 2, FX.RibbonA.Segments, true), Kind = kind, J = j - 1 }
	end

	function e.Move(self, pos, dir, travelled)
		if self.ImpactAt or typeof(pos) ~= "Vector3" or typeof(dir) ~= "Vector3" then return end
		self.Pos, self.Dir, self.Tr = pos, unitOr(dir, self.Dir or Vector3.zAxis), travelled or self.Tr
	end
	local function sdOf(tr) return D.GrowFrom + (1 - D.GrowFrom) * clamp01(tr / D.GrowOver) end
	--- the head is absorbed, nose on the surface; the streamers pour into the impact
	function e.Impact(self, point, dir)
		if self.ImpactAt then return end
		local d = unitOr(typeof(dir) == "Vector3" and dir or (self.Dir or Vector3.zAxis), Vector3.zAxis)
		if typeof(point) == "Vector3" then self.Pos = point - d * (D.HeadSize.Z / 2 * sdOf(self.Tr)) end
		self.Dir = d
		self.ImpactAt = os.clock()
	end
	--- spent at range: the same pour, the head shrinking instead of absorbed
	function e.Expire(self)
		if self.ImpactAt then return end
		self.Expiring = true
		self.ImpactAt = os.clock()
	end

	e.Step = function(self, now)
		local ur = (now - self.Start) * self.Scale
		if not self.Pos then
			self.Ball:hide()
			return ur < 3
		end
		local uh = self.ImpactAt and (now - self.ImpactAt) * self.Scale or -1
		if uh > D.GoneAfter then return false end
		local h, d = self.Pos, self.Dir
		if far(h) then
			self.Ball:hide()
			for _, r in ipairs(self.Ribs) do r.Rib:hide() end
			return true
		end
		local sd = sdOf(self.Tr)
		local L = envA(ur, FX.Tell.Release.Hold, FX.Tell.Release.Decay)
		if uh >= 0 and not self.Expiring then L = math.max(L, envA(uh, FX.Tell.Hit.Hold, FX.Tell.Hit.Decay)) end
		L = math.max(L, tellA(self.Character, now))
		if uh < 0 then
			self.Ball:put(CFrame.lookAt(h, h + d), D.HeadSize * sd, 1, L, "dart", sd)
		elseif self.Expiring then
			local k = 1 - clamp01(uh / D.PourTime)
			self.Ball:put(CFrame.lookAt(h, h + d), D.HeadSize * (sd * k), k, L, "dart", sd)
		else
			self.Ball:hide()
		end
		local Lb = math.min(D.Length * sd, self.Tr + 0.25)
		local fade = 1
		if uh >= 0 then
			Lb *= 1 - qout(uh / D.PourTime)
			fade = 1 - sstep(0.05, 0.14, uh)
		end
		if Lb < 0.05 or fade <= 0.01 then
			for _, r in ipairs(self.Ribs) do r.Rib:hide() end
			return true
		end
		local e1, e2 = perpA(d)
		local tspec = W + ur
		local hw = 0.08 + 0.35 * L
		for _, r in ipairs(self.Ribs) do
			local kind, j0 = r.Kind, r.J
			local cents = bandCentres(0.5 + D.BandSpeed * tspec - 0.33 * j0, D.BandSpacing, -hw, 1 + hw)   -- runs BACK
			local knots = {}
			for _, cc in ipairs(cents) do
				knots[#knots + 1] = cc - hw
				knots[#knots + 1] = cc
				knots[#knots + 1] = cc + hw
			end
			local rest, band = restA(kind), bandA(kind, L)
			local Wd = D.Width[kind] * sd * fade
			r.Rib:drawA({
				C = function(s)
					local th = TAU * j0 / 3 + TAU * D.Braid * s - TAU * D.Spin * ur              -- the braid
					local amp = D.Amp * sd * sstep(0, 0.5, s)
					return h - d * (D.Lead * sd + Lb * s) + (e1 * math.cos(th) + e2 * math.sin(th)) * amp
				end,
				SMax = 1,
				Width = function(s) return Wd * (1 - 0.8 * s) end,
				Colour = function(s) return rest:Lerp(band, tri(s, cents, hw)) end,
				ColourKnots = knots,
				Alpha = function(s) return 0.95 * (1 - s ^ 1.3) end,
				Brightness = brightA(L),
				Emission = emissionA(kind, L),
			})
		end
		return true
	end
	e.Stop = function(self)
		self.Ball:free()
		freeAll(self.Ribs)
	end
	return run(e)
end

----------------------------------------------------------------------------------------------------
-- THE HIT (A_r3 hit + A_r4 core): five unequal curls over the side facing the shooter
----------------------------------------------------------------------------------------------------
--- the tightening spiral, closed form: e^-k psi, x along the surface-out direction, y toward the shooter
local function curl(psi, k)
	local ek = math.exp(-k * psi)
	local den = 1 + k * k
	return (ek * (math.sin(psi) - k * math.cos(psi)) + k) / den, (1 - ek * (k * math.sin(psi) + math.cos(psi))) / den
end

--- opts: Owner (the shooter), FlightTime (release to impact, sets the curls' phase), SizeMul, BrightMul, Hold, Decay
function UmbraFX.Hit(point, dir, opts)
	if not FX or typeof(point) ~= "Vector3" then return NULL end
	opts = opts or {}
	local H = FX.Hit
	local d = unitOr(typeof(dir) == "Vector3" and dir or Vector3.zAxis, Vector3.zAxis)
	local e = { Name = "Hit", Character = opts.Owner, Start = os.clock(), Scale = timeScale(), P = point - d * H.Inset,
		N = -d, FlightTime = opts.FlightTime or 0.1, SizeMul = opts.SizeMul or 1, BrightMul = opts.BrightMul or 1,
		Hold = opts.Hold or FX.Tell.Hit.Hold, Decay = opts.Decay or FX.Tell.Hit.Decay, Ribs = {} }
	e.E1, e.E2 = perpA(d)
	e.Ball = newBall(H.CoreRadius, false)
	for j, def in ipairs(H.Ribbons) do
		e.Ribs[j] = { Rib = newRibbon("A", def.Kind, 2, FX.RibbonA.Segments, false), Def = def }
	end
	local Phi = math.rad(H.CurlTurn)

	e.Step = function(self, now)
		local u = (now - self.Start) * self.Scale
		if u > H.Life then return false end
		if far(self.P) then
			self.Ball:hide()
			for _, r in ipairs(self.Ribs) do r.Rib:hide() end
			return true
		end
		local Lh = envA(u, self.Hold, self.Decay)
		-- the void core: blooms, holds, closes
		local kc
		if u < H.CoreBloom then kc = qout(u / H.CoreBloom)
		elseif u < H.CoreHold then kc = 1
		else kc = 1 - sio((u - H.CoreHold) / H.CoreClose) end
		local rc = H.CoreRadius * kc * self.SizeMul
		self.Ball:put(CFrame.new(self.P + self.N * H.CoreOut) * CFrame.Angles(0, H.CoreSpin * u, 0), Vector3.one * (2 * rc),
			kc, Lh, "sphere", self.SizeMul)
		local spin = H.Spin * u
		for _, r in ipairs(self.Ribs) do
			local def, rib = r.Def, r.Rib
			local v = u - def.Delay
			if v <= 0.004 then
				rib:hide()
				continue
			end
			local th0 = TAU * def.Azimuth + TAU * H.Phase - TAU * FX.Dart.Spin * self.FlightTime + spin
			local rv = self.E1 * math.cos(th0) + self.E2 * math.sin(th0)
			local bb = unitOr(self.N:Cross(rv), self.E2)
			local ph = Phi * (1 - (1 - clamp01(v / H.Run)) ^ 3)                       -- weightless: fast out, long glide
			local front = Phi * H.DissolveOver * sio((v - H.DissolveFrom) / H.DissolveTime)   -- root -> tip
			local pa = math.max(0, front - H.Soft)
			local span = ph - pa
			if span < 0.05 or front > ph + 0.02 then
				rib:hide()
				continue
			end
			local rho = def.Size * H.SizeK * self.SizeMul
			local P, N = self.P, self.N
			local function Q(psi)
				local x, y = curl(math.clamp(psi, 0, Phi), H.CurlK)
				local be = def.Swirl * psi / Phi
				return P + N * (def.Rise * rho * y) + (rv * math.cos(be) + bb * math.sin(be)) * (H.Reach * rho * x)
			end
			local grow = 0.55 + 0.45 * qout(v / H.Grow)
			local Wd = H.Width[def.Kind] * def.Size * grow * self.SizeMul
			local psb = H.BandRun * Phi * v                                            -- the band runs OUT
			local cents = { (ph - psb) / span }
			local hw = (H.BandWidth + H.BandLitWidth * Lh) / span
			local knots = { cents[1] - hw, cents[1], cents[1] + hw }
			local rest, band = restA(def.Kind), bandA(def.Kind, Lh)
			rib:drawA({
				C = function(s) return Q(ph - span * s) end,
				SMax = 1,
				Side = function(s, p, axis)
					local psi = ph - span * s
					local be = def.Swirl * psi / Phi
					local wv = bb * math.cos(be) - rv * math.sin(be)                   -- the curl plane's normal
					local chi = 0.5 * psi / Phi                                         -- + a gentle silk twist
					return wv * math.cos(chi) + axis:Cross(wv) * math.sin(chi)
				end,
				Width = function(s)
					local psi = ph - span * s
					return Wd * (0.35 + 0.65 * sstep(0, 1, psi)) * (1 - 0.35 * sstep(0.6 * Phi, Phi, psi))
				end,
				Colour = function(s) return rest:Lerp(band, tri(s, cents, hw)) end,
				ColourKnots = knots,
				Alpha = function(s)
					local psi = ph - span * s
					return 0.95 * sstep(front, front + H.Soft, psi) * (0.55 + 0.45 * sstep(0, 0.2, ph - psi))
				end,
				AlphaKnots = { (ph - front) / span, (ph - front - H.Soft) / span },
				Brightness = brightA(Lh) * self.BrightMul,
				Emission = emissionA(def.Kind, Lh),
			})
		end
		return true
	end
	e.Stop = function(self)
		self.Ball:free()
		freeAll(self.Ribs)
	end
	return run(e)
end

--- OWNER: the Mark HEADSHOT payoff -- the hit's curls at the head, bigger and brighter and lit longer, and a glint flash
--- (a light and the rim image in glint swelling out and fading). Under half a second, like the plain hit.
function UmbraFX.MarkHeadshot(point, dir, opts)
	if not FX or typeof(point) ~= "Vector3" then return NULL end
	opts = opts or {}
	local M = FX.MarkHeadshot
	UmbraFX.Hit(point, dir, { Owner = opts.Owner, FlightTime = opts.FlightTime, SizeMul = M.Size, BrightMul = M.Brightness,
		Hold = M.Hold, Decay = M.Decay })
	local att = Instance.new("Attachment")
	att.Name = "UmbraHeadshotFlash"
	att.WorldPosition = point
	att.Parent = workspace.Terrain
	local light = Instance.new("PointLight")
	light.Color = PAL.Glint
	light.Range = M.FlashRange
	light.Shadows = false
	light.Brightness = 0
	light.Parent = att
	local bb = Instance.new("BillboardGui")
	bb.Adornee = att
	bb.AlwaysOnTop = false
	bb.LightInfluence = 0
	bb.Brightness = 1
	bb.Size = UDim2.fromScale(M.FlashSize.From, M.FlashSize.From)
	local img = texture("BallRimHalo")
	local disc
	if img then
		disc = Instance.new("ImageLabel")
		disc.Image = img
		disc.ImageColor3 = PAL.Glint
		disc.BackgroundTransparency = 1
	else
		disc = Instance.new("Frame")
		disc.BackgroundColor3 = PAL.Glint
		disc.BorderSizePixel = 0
		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(0.5, 0)
		corner.Parent = disc
	end
	disc.Size = UDim2.fromScale(1, 1)
	disc.Parent = bb
	bb.Parent = att
	local scale = timeScale()
	return run({
		Name = "HeadshotFlash", Start = os.clock(),
		Step = function(e, now)
			local u = (now - e.Start) * scale
			if u > M.FlashRise + M.FlashFall then return false end
			local env = if u < M.FlashRise then qout(u / M.FlashRise) else 1 - sio((u - M.FlashRise) / M.FlashFall)
			light.Brightness = M.FlashBrightness * env
			local sz = M.FlashSize.From + (M.FlashSize.To - M.FlashSize.From) * qout(u / (M.FlashRise + M.FlashFall))
			bb.Size = UDim2.fromScale(sz, sz)
			if disc:IsA("ImageLabel") then disc.ImageTransparency = 1 - env else disc.BackgroundTransparency = 1 - 0.6 * env end
			return true
		end,
		Stop = function() att:Destroy() end,
	})
end

----------------------------------------------------------------------------------------------------
-- PRIMARY: SHADOW STEP (B_r3): unravel at the origin, weave at the destination, nothing between; the stepper's iris
----------------------------------------------------------------------------------------------------
--- opts: Start (os.clock of ShadowStepOut), Dissolve (the real dissolve seconds), FirstPerson (the stepper's own view:
--- the veil and the arm ribbons instead of the world set), LandedAt (first person: fn() -> the os.clock this client's
--- body really re-formed, or nil while it has not -- UmbraAnim.OwnStepLandedAt -- so the veil opens on the frame the view
--- jumps; held just short of the re-form until then, for at most Step.LandWait)
function UmbraFX.StepOut(character, from, to, opts)
	if not FX or typeof(from) ~= "Vector3" or typeof(to) ~= "Vector3" then return NULL end
	opts = opts or {}
	local S = FX.Step
	local e = { Name = "ShadowStep", Character = character, Start = opts.Start or os.clock(), Scale = timeScale(),
		Dissolve = math.max(opts.Dissolve or S.SpecDissolve, 0.02), FP = opts.FirstPerson == true, Sets = {},
		LandedAt = opts.LandedAt, Landed = nil }
	local function clock(now)
		local el = now - e.Start
		if e.FP and type(e.LandedAt) == "function" then
			if not e.Landed then
				local ok, at = pcall(e.LandedAt)
				if ok and type(at) == "number" and at >= e.Start then e.Landed = at end
			end
			if e.Landed then return S.SpecDissolve + math.max(0, now - e.Landed) * e.Scale end
			if el < e.Dissolve + S.LandWait then
				return math.min(el * (S.SpecDissolve / e.Dissolve), S.SpecDissolve - 0.001)   -- veiled, waiting on the jump
			end
			return S.SpecDissolve + (el - e.Dissolve - S.LandWait) * e.Scale                -- never heard: open anyway
		end
		if el <= e.Dissolve then return el * (S.SpecDissolve / e.Dissolve) end
		return S.SpecDissolve + (el - e.Dissolve) * e.Scale
	end
	local function quiet(now)                          -- into concealment: quiet, unless a Tell lands meanwhile
		local u = tellB(character, now)
		return 1 + FX.RibbonA.BrightnessGain * u, u
	end

	if not e.FP then
		-- THE ORIGIN: five ribbons wound diagonally round the body unwind outward, drifting up OR down
		local O = S.Origin
		local floorO = from.Y - S.RootAboveFloor
		for i, kind in ipairs(O.Kinds) do
			local i0 = i - 1
			local h, theta0, sgn, ts = 0.7 + 0.9 * i0, 0.3 + 2.4 * i0, (i0 % 2 == 0) and 1 or -1, 0.035 + 0.006 * i0
			local tilt, dy = O.Tilt[i], O.Dy[i]
			local az = 0.4 + 1.3 * i0 + ((i0 % 2 == 1) and math.pi or 0)
			local n = V3(math.sin(tilt) * math.cos(az), math.cos(tilt), math.sin(tilt) * math.sin(az))
			local e1, e2 = perpB(n)
			local base = V3(from.X, floorO, from.Z)
			e.Sets[#e.Sets + 1] = { Rib = newRibbon("B", kind, 2, O.Segments, true, jitterSpeed(O.TextureSpeed, i0)),
				Draw = function(rib, tc, now)
					if tc > O.Life then return rib:hide() end
					local function path(tau)
						local theta, r, y
						if tau <= ts then
							theta, r, y = theta0 + sgn * 9 * tau, 1.15, h
						else
							local u = tau - ts
							theta = theta0 + sgn * (9 * ts + 9 * (1 - math.exp(-2.5 * u)) / 2.5)
							r = 1.15 + 4.2 * (1 - math.exp(-3.2 * u))
							y = h + dy * (1 - math.exp(-3 * u))
						end
						return base + Vector3.yAxis * y + (e1 * math.cos(theta) + e2 * math.sin(theta)) * r
					end
					local a = sstep(-0.005, 0.03, tc)
					local br, fl = quiet(now)
					rib:drawB(path, tc, O.Span, O.Width * a * (1 - 0.75 * sstep(0.10, 0.42, tc)),
						a * (1 - sstep(0.22, 0.46, tc)), br, fl, nil)
				end, Anchor = from }
		end
		-- THE DESTINATION: five ribbons converge from all round and weave the body back, alternate ones crossing
		local Dn = S.Destination
		local floorD = to.Y - S.RootAboveFloor
		for i, kind in ipairs(Dn.Kinds) do
			local i0 = i - 1
			local h = 0.7 + 0.9 * i0
			local hs = h + Dn.Hs[i]
			local theta0, sgn = 1.1 + 2.4 * i0, (i0 % 2 == 0) and -1 or 1
			local tilt = ((i0 % 2 == 0) and 1 or -1) * Dn.Tilt
			local az = 1.0 + 1.1 * i0
			local n = V3(math.sin(tilt) * math.cos(az), math.cos(tilt), math.sin(tilt) * math.sin(az))
			local e1, e2 = perpB(n)
			local base = V3(to.X, floorD, to.Z)
			local k24 = math.pi / 0.24
			e.Sets[#e.Sets + 1] = { Rib = newRibbon("B", kind, 2, Dn.Segments, true, jitterSpeed(Dn.TextureSpeed, i0 + 5)),
				Draw = function(rib, tc, now)
					if tc > Dn.Life then return rib:hide() end
					local function path(tau)
						local theta, r, y
						if tau <= 0 then                                   -- the same spiral run backwards: tails trail in
							theta = theta0 + sgn * 30 * tau
							r = math.min(5.4, 3.8 - 2.65 * k24 * tau)
							y = hs + math.clamp((h - hs) * k24 * tau, -0.6, 0.6)
						elseif tau <= 0.12 then
							local ee = math.sin(math.pi / 2 * tau / 0.12)
							r = 1.15 + 2.65 * (1 - ee)
							y = hs + (h - hs) * ee
							theta = theta0 + sgn * 30 * tau
						else
							local u = tau - 0.12
							r = 1.15 - 0.15 * sstep(0, 0.3, u)
							y = h
							theta = theta0 + sgn * (3.6 + 30 * (1 - math.exp(-4 * u)) / 4)
						end
						return base + Vector3.yAxis * y + (e1 * math.cos(theta) + e2 * math.sin(theta)) * r
					end
					local w = if tc <= 0.12 then 30 else 30 * math.exp(-4 * (tc - 0.12))
					local span = math.clamp(2.2 / w, 0.07, 0.30)       -- a long sweep rushing in, a short wrap once bound
					local a = sstep(-0.005, 0.025, tc)
					local br, fl = quiet(now)
					rib:drawB(path, tc, span, Dn.Width * a * (1 - 0.7 * sstep(0.18, 0.48, tc)),
						a * (1 - sstep(0.30, 0.52, tc)), br, fl, nil)
				end, Anchor = to }
		end
		e.Life = math.max(O.Life, Dn.Life)
	else
		-- THE STEPPER'S VIEW: four wide ribbons sweep in from beyond the edges like an iris and veil the view, then unwind
		-- out past the edges after the jump (camera-locked: the 22 studs never smear them)
		local Vv = S.Veil
		for i, kind in ipairs(Vv.Kinds) do
			local i0 = i - 1
			local phi0 = Vv.Phi0[i]
			local z = -Vv.Depth - 0.08 * i0
			local k24 = math.pi / 0.24
			e.Sets[#e.Sets + 1] = { Rib = newRibbon("B", kind, 2, Vv.Segments, true, jitterSpeed(Vv.TextureSpeed, i0)),
				Draw = function(rib, tc, now)
					if tc < 0 or tc > Vv.Life then return rib:hide() end
					local camCF = camera().CFrame
					local function path(tau)
						local r, phi
						if tau <= 0 then
							r, phi = 3.5 - 2.4 * k24 * tau, phi0 + 2 * tau / 0.12
						elseif tau <= 0.12 then
							local ee = tau / 0.12
							r, phi = 3.5 - 2.4 * math.sin(math.pi / 2 * ee), phi0 + 2 * ee
						else
							local u = tau - 0.12
							r = 1.1 + 3.4 * (1 - math.exp(-6 * u)) ^ 2
							phi = phi0 + 2 + (2 / 0.12 / 5) * (1 - math.exp(-5 * u))
						end
						return camCF:PointToWorldSpace(V3(Vv.Aspect * r * math.cos(phi), r * math.sin(phi), z))
					end
					local br, fl = quiet(now)
					rib:drawB(path, tc, Vv.Span, Vv.Width * (1 - 0.6 * sstep(0.14, 0.4, tc)), 1 - sstep(0.2, 0.42, tc),
						br, fl, nil)
				end }
		end
		-- ...and a ribbon peels off each forearm as it vanishes, then winds back onto the rising arm
		local Am = S.Arms
		for side, sgn in pairs({ R = 1, L = -1 }) do
			e.Sets[#e.Sets + 1] = { Rib = newRibbon("B", Am.Kinds[side], 1, Am.Segments, true, jitterSpeed(Am.TextureSpeed, sgn + 3)),
				Draw = function(rib, tc, now)
					local root = vmCall("GetArmCFrame", side)
					if tc > Am.Life or typeof(root) ~= "CFrame" then return rib:hide() end
					local peel = tc < 0.12
					local function path(tau)
						local theta, r, z
						if peel then
							theta = 1 + sgn * 16 * tau
							z = -0.95 + 0.9 * clamp01(tau / 0.06)
							r = if tau <= 0.045 then 0.24 else 0.24 + 1.1 * (1 - math.exp(-6 * (tau - 0.045)))
						else
							local u = tau - 0.12
							theta = 2 - sgn * 14 * u
							local ee = sio(u / 0.12)
							r = 0.24 + 1.0 * (1 - ee)
							z = -0.1 - 0.85 * ee
						end
						return root:PointToWorldSpace(V3(r * math.cos(theta) + 0.3 * sgn * (r - 0.24),
							r * math.sin(theta) - 0.2 * (r - 0.24), z))
					end
					local a, alpha
					if peel then
						a = sstep(0, 0.02, tc)
						alpha = a * (1 - sstep(0.07, 0.12, tc))
					else
						a = sstep(0.12, 0.14, tc)
						alpha = a * (1 - sstep(0.24, 0.34, tc))
					end
					local br, fl = quiet(now)
					rib:drawB(path, tc, Am.Span, Am.Width * a, alpha, br, fl, nil)
				end }
		end
		e.Life = math.max(Vv.Life, Am.Life)
	end

	e.Step = function(self, now)
		local tc = clock(now)
		if tc > self.Life then return false end
		for _, set in ipairs(self.Sets) do
			if set.Anchor and far(set.Anchor) then set.Rib:hide() else set.Draw(set.Rib, tc, now) end
		end
		return true
	end
	e.Stop = function(self) freeAll(self.Sets) end
	return run(e)
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: DECOY DOUBLE (B_r3 option A)
----------------------------------------------------------------------------------------------------
local broken = setmetatable({}, { __mode = "k" })      -- [decoy] = true once its break has hidden it

--- A model's body parts (direct BasePart children, not the root) keyed by name.
local function bodyParts(model)
	local out = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then out[p.Name] = p end
	end
	return out
end

--- LocalTransparencyModifier over a whole model (parts and decals), or one part and its decals
local function veil(inst, on)
	local v = on and 1 or 0
	local function set(x)
		if x:IsA("BasePart") or x:IsA("Decal") then x.LocalTransparencyModifier = v end
	end
	pcall(function()
		set(inst)
		for _, d in ipairs(inst:GetDescendants()) do set(d) end
	end)
end

--- A local shadow-skin copy of a decoy part: its mesh, nothing else of it
local function peelCopy(part)
	local ok, c = pcall(function() return part:Clone() end)
	if not (ok and c) then
		c = Instance.new("Part")
		c.Size = part.Size
	end
	for _, ch in ipairs(c:GetChildren()) do
		if not (ch:IsA("SpecialMesh") or ch:IsA("Decal")) then ch:Destroy() end
	end
	for _, ch in ipairs(c:GetChildren()) do
		if ch:IsA("Decal") then ch.Transparency = 1 end
	end
	if c:IsA("MeshPart") then pcall(function() c.TextureID = "" end) end
	c.Name = "UmbraPeel"
	c.Anchored, c.CanCollide, c.CanQuery, c.CanTouch = true, false, false, false
	c.Massless = true
	c.CastShadow = true
	c.Material = Enum.Material.SmoothPlastic
	c.Color = wrapped("ShadowSkin", FX.Decoy.ShadowSkin)
	c.Transparency = 1
	c.LocalTransparencyModifier = 0
	c.Parent = ownFolder()
	return c
end

--- The Viewmodel pose frame (Viewmodel.solveArm, without the sway): camera * (X, Y, Z) * (pitch, yaw, roll) * wrist
local function vmPoseCF(camCF, p)
	return camCF * CFrame.new(p.X, p.Y, p.Z) * CFrame.Angles(math.rad(p.Pitch), math.rad(p.Yaw), math.rad(p.Roll))
		* CFrame.Angles(math.rad(p.Wrist * 0.35), 0, 0)
end

--- A shadow-skin copy of the local right viewmodel arm and each piece's offset from the arm's root, or nil
local function ghostArm()
	local cam = camera()
	local vm = cam and cam:FindFirstChild("SpellshotViewmodel")
	local arm = vm and vm:FindFirstChild("ArmR")
	local root = vmCall("GetArmCFrame", "R")
	if not (arm and typeof(root) == "CFrame" and UmbraFX.LocalFirstPerson()) then return nil end
	local ok, copy = pcall(function() return arm:Clone() end)
	if not (ok and copy) then return nil end
	local pieces = {}
	for _, d in ipairs(copy:GetDescendants()) do
		if d:IsA("Highlight") or d:IsA("Light") then
			d:Destroy()
		elseif d:IsA("BasePart") then
			d.Anchored, d.CanCollide, d.CanQuery, d.CanTouch, d.CastShadow = true, false, false, false, false
			local ink = d.Name:find("Ink") ~= nil or d.Transparency >= 1
			if not ink then
				d.Material = Enum.Material.SmoothPlastic
				d.Color = wrapped("ShadowSkin", FX.Decoy.ShadowSkin)
			end
			pieces[#pieces + 1] = { Part = d, Offset = root:ToObjectSpace(d.CFrame) }
		end
	end
	copy.Name = "UmbraGhostArm"
	copy.Parent = cam
	return copy, pieces
end

--- THE PEEL: the decoy's copy peels off the caster to the side, right side first, each piece a shadow-skin copy that
--- flies from the caster's part to the decoy's, streamers flowing from its edges; landed, it tweens to the real part's
--- colour and hands over to the real (hidden meanwhile) decoy part -- which looks exactly like Umbra (option A).
--- opts: Start (os.clock of DecoySpawn), FirstPerson (the caster's own view: the arm copy sliding out of the edge)
function UmbraFX.DecoyPeel(owner, decoy, opts)
	if not FX or typeof(decoy) ~= "Instance" then return NULL end
	opts = opts or {}
	local Dc = FX.Decoy
	local P, Sm = Dc.Peel, Dc.Streamers
	local droot = decoy:FindFirstChild("HumanoidRootPart") or decoy.PrimaryPart
	if not droot then return NULL end
	local e = { Name = "DecoyPeel", Character = owner, Start = opts.Start or os.clock(), Scale = timeScale(), Entries = {},
		ByName = {}, Ribs = {}, Decoy = decoy }
	local rootCF = droot.CFrame
	local ownerParts = (typeof(owner) == "Instance") and bodyParts(owner) or {}
	local oroot = typeof(owner) == "Instance" and owner:FindFirstChild("HumanoidRootPart")
	local casterRot = (oroot and oroot.CFrame or rootCF).Rotation
	veil(decoy, true)
	for name, part in pairs(bodyParts(decoy)) do
		local src = ownerParts[name]
		local restX = math.clamp(rootCF:PointToObjectSpace(part.Position).X, -1.5, 1.5)
		local ent = { Part = part, Copy = peelCopy(part), Src = src and src.CFrame or part.CFrame,
			Delay = P.Stagger * (1 - (restX + 1.5) / 3), Size = part.Size, Colour = part.Color, Done = false }
		e.Entries[#e.Entries + 1] = ent
		e.ByName[name] = ent
	end
	local lastLand = 0
	for _, ent in ipairs(e.Entries) do lastLand = math.max(lastLand, ent.Delay + P.Travel + P.Recolour) end

	--- a piece's CFrame and size at clock tau (the travel: Quad Out, a lift and a tilt, 1.04 -> 1.00)
	local function pieceAt(ent, tau)
		local u = clamp01((tau - ent.Delay) / P.Travel)
		local ee = qout(u)
		local dst = ent.Part.Parent and ent.Part.CFrame or ent.Src
		local cf = ent.Src:Lerp(dst, ee) + Vector3.yAxis * (P.Lift * math.sin(math.pi * ee))
		cf *= CFrame.Angles(0, 0, math.rad(-P.Tilt) * math.sin(math.pi * ee))
		return cf, ent.Size * (P.Scale - (P.Scale - 1) * ee), u
	end

	-- the streamers: their heads ride the travelling pieces' edges, their free ends float out of both silhouettes
	for i, anchor in ipairs(Sm.Anchors) do
		local ent = e.ByName[anchor[1]]
		if ent then
			local i0 = i - 1
			local billow = unitOr(casterRot * Sm.Billow[i], Vector3.yAxis)
			local frac = anchor[2]
			local land = ent.Delay + P.Travel
			e.Ribs[#e.Ribs + 1] = { Rib = newRibbon("B", Sm.Kinds[i], 1, Sm.Segments, true, jitterSpeed(Sm.TextureSpeed, i0)),
				Draw = function(rib, tc)
					local amp = Sm.Amp * math.sin(math.pi * clamp01((tc - ent.Delay) / P.Travel))
					local function path(tau)
						local cf, size, u = pieceAt(ent, tau)
						local w = Sm.Wave * math.sin(TAU * 2.2 * tau + 0.9 * i0) * math.sin(math.pi * u)
						local back = clamp01((tc - tau) / Sm.Span)
						return cf:PointToWorldSpace(frac * size / 2) + Vector3.yAxis * w + cf:VectorToWorldSpace(V3(0, 0, 0.6 * w))
							+ billow * amp * back ^ 1.3
					end
					local a = sstep(ent.Delay - 0.02, ent.Delay + 0.04, tc)
					rib:drawB(path, tc, Sm.Span, Sm.Width * a, a * (1 - sstep(land + 0.02, land + 0.2, tc)), 1, 0, nil)
				end, Last = land + 0.2 }
		end
	end

	-- the caster's first person: the shadow-skin arm copy slides out of the right edge, two ribbons off its outer edge
	local A1 = Dc.Arm1P
	if opts.FirstPerson then
		e.Ghost, e.GhostPieces = ghostArm()
		local function ghostRoot(camCF, tau)
			local u = 0.06 + 0.94 * qinout(tau / A1.Slide)
			local p = {}
			for key, v in pairs(A1.Idle) do p[key] = v + (A1.Move[key] or 0) * u end
			return vmPoseCF(camCF, p)
		end
		e.GhostRoot = ghostRoot
		for i, anchor in ipairs(A1.Anchors) do
			local i0 = i - 1
			e.Ribs[#e.Ribs + 1] = { Rib = newRibbon("B", A1.Kinds[i], 1, A1.Segments, true, jitterSpeed(A1.TextureSpeed, i0 + 7)),
				Draw = function(rib, tc)
					if tc > A1.Life then return rib:hide() end
					local camCF = camera().CFrame
					local function path(tau)
						return ghostRoot(camCF, tau):PointToWorldSpace(anchor)
							+ camCF.UpVector * (0.12 * math.sin(TAU * 2.4 * tau + 1.3 * i0) * math.sin(math.pi * clamp01(tau / 0.3)))
					end
					local a = sstep(0, 0.04, tc)
					rib:drawB(path, tc, A1.Span, A1.Width * a, a * (1 - sstep(0.24, 0.36, tc)), 1, 0, nil)
				end, Last = A1.Life }
		end
		lastLand = math.max(lastLand, A1.Life)
	end

	e.Step = function(self, now)
		local tc = (now - self.Start) * self.Scale
		if not self.Decoy.Parent or broken[self.Decoy] then return false end   -- it broke mid-peel: the break owns it now
		-- the pieces
		for _, ent in ipairs(self.Entries) do
			if ent.Done then continue end
			local copy = ent.Copy
			if not ent.Part.Parent then
				ent.Done = true
				copy:Destroy()
				continue
			end
			if tc < ent.Delay then
				copy.Transparency = 1
				continue
			end
			local cf, size, u = pieceAt(ent, tc)
			copy.CFrame = cf
			copy.Size = size
			copy.Transparency = 0
			if u >= 1 then
				local k = clamp01((tc - ent.Delay - P.Travel) / P.Recolour)
				copy.Color = wrapped("ShadowSkin", Dc.ShadowSkin):Lerp(ent.Colour, k)
				if k >= 1 then
					ent.Done = true
					veil(ent.Part, false)                            -- the real part takes over, exactly as Umbra looks
					copy:Destroy()
				end
			else
				copy.Color = wrapped("ShadowSkin", Dc.ShadowSkin)
			end
		end
		-- the streamers
		for _, r in ipairs(self.Ribs) do
			if tc > r.Last then r.Rib:hide() else r.Draw(r.Rib, tc) end
		end
		-- the first-person arm copy
		if self.Ghost then
			if tc > A1.Life then
				self.Ghost:Destroy()
				self.Ghost = nil
			else
				local g = self.GhostRoot(camera().CFrame, tc)
				for _, pc in ipairs(self.GhostPieces) do pc.Part.CFrame = g * pc.Offset end
			end
		end
		return tc <= lastLand + 0.05
	end
	e.Stop = function(self)
		for _, ent in ipairs(self.Entries) do
			if not ent.Done then ent.Copy:Destroy() end
		end
		if self.Decoy.Parent and not broken[self.Decoy] then veil(self.Decoy, false) end
		if self.Ghost then self.Ghost:Destroy() end
		freeAll(self.Ribs)
	end
	return run(e)
end

--- A seed every client derives alike when the server sends none: the decoy's (anchored) spot and its owner
local function seedFor(pos, ownerId)
	local s = math.floor(pos.X * 7.31 + pos.Y * 13.7 + pos.Z * 17.3) + (tonumber(ownerId) or 0)
	return s % 2147483647
end

--- Where the hit came from when the server did not say: the nearest other living body's side of the decoy
local function guessHit(decoy, rootCF, owner)
	local best, bestD = nil, 300
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local r = c and c ~= owner and c:FindFirstChild("HumanoidRootPart")
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if r and hum and hum.Health > 0 then
			local d = (r.Position - rootCF.Position).Magnitude
			if d < bestD then best, bestD = r.Position, d end
		end
	end
	if best then
		return rootCF.Position + unitOr(flat(best - rootCF.Position), -rootCF.LookVector) * 0.8 + Vector3.yAxis * 0.5
	end
	return rootCF:PointToWorldSpace(FX.Decoy.Break.Fallback)
end

--- THE BREAK: the copy is gone at once; eight ribbons leave its parts' volumes and whip away from the hit on decaying
--- curls (weightless), with the Tell's flare when it failed to a hit (opts.Lit). opts: Owner, HitAt, Seed, Lit
function UmbraFX.DecoyBreak(decoy, opts)
	if not FX or typeof(decoy) ~= "Instance" then return NULL end
	opts = opts or {}
	local Bk = FX.Decoy.Break
	local droot = decoy:FindFirstChild("HumanoidRootPart") or decoy.PrimaryPart
	if not droot then return NULL end
	local rootCF = droot.CFrame
	local hit = typeof(opts.HitAt) == "Vector3" and opts.HitAt or guessHit(decoy, rootCF, opts.Owner)
	local ownerId = nil
	if typeof(opts.Owner) == "Instance" then
		local p = Players:GetPlayerFromCharacter(opts.Owner)
		ownerId = p and p.UserId
	end
	local rnd = Random.new(tonumber(opts.Seed) or seedFor(rootCF.Position, ownerId or decoy:GetAttribute("DecoyOwner")))
	local function U(a, b) return rnd:NextNumber(a, b) end
	local e = { Name = "DecoyBreak", Start = os.clock(), Scale = timeScale(), Ribs = {}, Lit = opts.Lit == true, At = rootCF.Position }
	broken[decoy] = true
	veil(decoy, true)                                  -- gone at once (the server removes the model a beat later)
	for i, partName in ipairs(Bk.Parts) do
		local i0 = i - 1
		local part = decoy:FindFirstChild(partName) or droot
		local pcf, ps = part.CFrame, part.Size
		local p0 = pcf:PointToWorldSpace(V3(U(-Bk.Spread, Bk.Spread) * ps.X, U(-Bk.Spread, Bk.Spread) * ps.Y,
			U(-Bk.Spread, Bk.Spread) * ps.Z))
		local rel = rootCF:VectorToObjectSpace(p0 - hit)
		local d = unitOr(rootCF:VectorToWorldSpace(V3(rel.X, 0, rel.Z * 0.4)), -rootCF.LookVector)
		d = rotate(Vector3.yAxis, (i0 / (#Bk.Parts - 1) - 0.5) * Bk.Fan + U(-Bk.Jitter, Bk.Jitter), d)      -- a fan
		d = unitOr(d + V3(0, U(-Bk.Lift, Bk.Lift), 0), d)
		local up = unitOr(V3(U(-0.5, 0.5), 1, U(-0.5, 0.5)), Vector3.yAxis)
		local q2 = unitOr(up:Cross(d), (perpB(d)))                                                     -- the curl plane
		local w = U(Bk.Spin[1], Bk.Spin[2]) * ((i0 % 2 == 0) and 1 or -1)
		local v0 = U(Bk.Speed[1], Bk.Speed[2])
		local za, zb = -Bk.Damp, w
		local den = za * za + zb * zb
		e.Ribs[#e.Ribs + 1] = { Rib = newRibbon("B", Bk.Kinds[i], 2, Bk.Segments, true, jitterSpeed(Bk.TextureSpeed, i0)),
			Path = function(tau)
				if tau < 0 then return p0 + d * (0.5 * v0 * tau) end                 -- the tail starts inside the body
				-- F = v0 (e^(z tau) - 1) / z, z = -Damp + i w: snaps out and curls to rest ~|v0 / z| off
				local ex = math.exp(za * tau)
				local ar, ai = ex * math.cos(zb * tau) - 1, ex * math.sin(zb * tau)
				local re, im = (ar * za + ai * zb) / den, (ai * za - ar * zb) / den
				return p0 + d * (v0 * re) + q2 * (v0 * im)
			end }
	end
	e.Step = function(self, now)
		local u = (now - self.Start) * self.Scale
		if u > Bk.Life then return false end
		if far(self.At) then
			for _, r in ipairs(self.Ribs) do r.Rib:hide() end
			return true
		end
		local fl = self.Lit and envB(u) or 0
		for _, r in ipairs(self.Ribs) do
			r.Rib:drawB(r.Path, u, Bk.Span, Bk.Width * (1 - 0.7 * sstep(0.05, 0.4, u)), 1 - sstep(0.2, 0.45, u),
				1 + FX.RibbonA.BrightnessGain * fl, fl, nil)
		end
		return true
	end
	e.Stop = function(self) freeAll(self.Ribs) end
	return run(e)
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE: ECLIPSE (B_r3 vortex + B_r4 ball, world and screen)
----------------------------------------------------------------------------------------------------
--- The ground under the caster at the open, facing the caster's way: the domain's centre C.
local function groundFrame(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then return nil end
	local look = unitOr(flat(root.CFrame.LookVector), -Vector3.zAxis)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local ex = { fxFolder() }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then ex[#ex + 1] = p.Character end
	end
	params.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(root.Position, V3(0, -12, 0), params)
	local floor = hit and hit.Position or (root.Position - V3(0, FX.Step.RootAboveFloor, 0))
	return CFrame.lookAt(floor, floor + look), params
end

--- THE SCREEN LAYER (B_r4 screen): the vignette and four flowing edge strips, sized off the ScreenGui (never
--- Camera.ViewportSize), who = "caster" (lighter) or "enemy" (stronger). Returns nil without its textures.
local function newScreen(who)
	local Sc = FX.Eclipse.Screen
	local s = Sc[who]
	local vigImg, edgeImg = texture("EclipseVignette"), texture("EclipseEdge")
	local pg = player:FindFirstChildOfClass("PlayerGui")
	if not (s and pg and (vigImg or edgeImg)) then return nil end
	local sg = Instance.new("ScreenGui")
	sg.Name = "UmbraEclipseScreen"
	sg.IgnoreGuiInset = true
	sg.ResetOnSpawn = false
	sg.DisplayOrder = Sc.DisplayOrder
	sg.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	local vig = nil
	if vigImg then
		vig = Instance.new("ImageLabel")
		vig.Name = "Vignette"
		vig.Image = vigImg
		vig.ImageColor3 = wrapped("VignetteTint", Color3.new(1, 1, 1))
		vig.BackgroundTransparency = 1
		vig.Size = UDim2.fromScale(1, 1)
		vig.ScaleType = Enum.ScaleType.Stretch
		vig.ImageTransparency = 1
		vig.ZIndex = 1
		vig.Parent = sg
	end
	local strips = {}
	if edgeImg then
		local fade = {}
		for _, kk in ipairs(Sc.StripFade) do fade[#fade + 1] = NumberSequenceKeypoint.new(kk[1], kk[2]) end
		for e, name in ipairs({ "Top", "Right", "Bottom", "Left" }) do
			local im = Instance.new("ImageLabel")
			im.Name = "Edge" .. name
			im.Image = edgeImg
			im.ImageColor3 = wrapped("EdgeTint", Color3.new(1, 1, 1))
			im.BackgroundTransparency = 1
			im.ImageTransparency = 1
			im.AnchorPoint = Vector2.new(0.5, 0.5)
			im.ScaleType = Enum.ScaleType.Stretch
			im.ZIndex = 2
			im.Visible = false
			local g = Instance.new("UIGradient")
			g.Transparency = NumberSequence.new(fade)
			g.Parent = im
			im.Parent = sg
			strips[e] = im
		end
	end
	sg.Parent = pg
	return { Gui = sg, Vig = vig, Strips = strips, S = s }
end

--- tc = the Eclipse clock (the open at SpecWindup), tEnd = the domain's end on it. Returns false once all is gone.
local function stepScreen(scr, tc, tEnd)
	local Sc = FX.Eclipse.Screen
	local s = scr.S
	local open = FX.Eclipse.SpecWindup
	local size = scr.Gui.AbsoluteSize
	local Wd, Ht = size.X, size.Y
	if Wd < 2 or Ht < 2 then return tc < tEnd + Sc.Out + 0.5 end
	local env = sio((tc - (open + Sc.VignetteDelay)) / Sc.VignetteIn) * (1 - sio((tc - tEnd) / Sc.Out))
	local br = if tc > open + Sc.BreatheFrom then math.sin(TAU * (tc - open - Sc.BreatheFrom) / Sc.BreathePeriod) else 0
	if scr.Vig then
		local breathe = if s.Breathe > 0 then 1 + Sc.BreatheVignette * br else 1
		scr.Vig.ImageTransparency = math.clamp(1 - (1 - s.Vignette) * env * breathe, 0, 1)
	end
	local alive = env > 0.001 or tc < open + 0.05
	for e, im in ipairs(scr.Strips) do
		local e0 = e - 1
		local te = open + Sc.Stagger * e0
		local sOut = sio((tc - tEnd - Sc.OutStagger * e0) / Sc.Out)
		if tc < te or sOut >= 1 then
			im.Visible = false
			continue
		end
		alive = true
		im.Visible = true
		local sIn = qout((tc - te) / Sc.SlideIn)
		local away = (1 - sIn) + sOut
		local d = (s.Inset + s.Breathe * br - away * (s.Inset + 0.8 * s.Thick)) * Ht
		local along = Sc.Along + Sc.Drift * math.sin(TAU * tc / Sc.DriftPeriod + 1.3 * e0)
		local horiz = (e == 1 or e == 3)
		local len = Sc.StripLength * (if horiz then Wd else Ht)
		im.Size = UDim2.fromOffset(len, s.Thick * Ht)
		im.ImageRectSize = Vector2.new(512 * len / (1.1 * Wd), 128)          -- the same texture scale on all four edges
		local u = tc - te
		local off = 512 * (s.Flow * u + Sc.Whip * (1 - math.exp(-5 * u)) / 5)  -- whips along at the open, then slows
		im.ImageRectOffset = Vector2.new(off % 512, 0)
		im.Rotation = 90 * e0 + Sc.Swing * (1 - sIn)
		im.ImageTransparency = math.clamp(1 - (1 - s.Strip) * sstep(te, te + Sc.FadeIn, tc) * (1 - sOut), 0, 1)
		if e == 1 then
			im.Position = UDim2.fromOffset(Wd * (0.5 + along), d)
		elseif e == 2 then
			im.Position = UDim2.fromOffset(Wd - d, Ht * (0.5 + along))
		elseif e == 3 then
			im.Position = UDim2.fromOffset(Wd * (0.5 - along), Ht - d)
		else
			im.Position = UDim2.fromOffset(d, Ht * (0.5 - along))
		end
	end
	return alive
end

--- The Eclipse: from the cast (the windup vortex round the core between the hands) through the open (the sweep, the
--- ground wave, the pulse, the wisps, the screen layer) to the domain's end. opts: Start (os.clock of EclipseCharge),
--- Windup (the real windup seconds; 0 = it is opening now), FirstPerson (the caster's own client: the first-person
--- vortex and core instead of the world ones).
function UmbraFX.Eclipse(caster, opts)
	if not FX or typeof(caster) ~= "Instance" then return NULL end
	opts = opts or {}
	local X = FX.Eclipse
	local Vx = X.Vortex
	local OPEN = X.SpecWindup
	local e = { Name = "Eclipse", Character = caster, Start = opts.Start or os.clock(), Windup = math.max(opts.Windup or 0, 0),
		Scale = timeScale(), FP = opts.FirstPerson == true, OpenAt = nil, UntilAt = nil, EndAt = nil, CancelAt = nil,
		Ribs = {}, Domain = nil, Screen = nil }
	e.MaxLife = (X.SpecWindup + (T.Eclipse.Duration or 7) + 4) / e.Scale + e.Windup + 2
	e.Core = newBall(e.FP and X.Core.Radius1P or X.Core.Radius3P, e.FP)
	for i, kind in ipairs(Vx.Kinds) do
		e.Ribs[i] = { Rib = newRibbon("B", kind, 2, Vx.Segments, true, jitterSpeed(Vx.TextureSpeed, i - 1)), I = i - 1 }
	end
	if e.Windup <= 0 then e.OpenAt = e.Start end

	local function clock(now)
		if e.OpenAt and now >= e.OpenAt then return OPEN + (now - e.OpenAt) * e.Scale end
		if e.Windup <= 0 then return OPEN end
		return math.min(OPEN, (now - e.Start) * OPEN / e.Windup)          -- held at the open until EclipseStart
	end
	local function endTc()
		local stop = e.EndAt or e.UntilAt
		if stop and e.OpenAt then return OPEN + (stop - e.OpenAt) * e.Scale end
		return OPEN + (T.Eclipse.Duration or 7)
	end

	--- opts2: Domain (bool: this viewer is in the duel -- the wave, pulse and wisps), Screen ("caster" | "enemy" | nil)
	function e.Open(self, openClock, untilClock, opts2)
		opts2 = opts2 or {}
		local now = os.clock()
		if not self.OpenAt then self.OpenAt = math.min(openClock or now, now) end
		self.UntilAt = untilClock
		if opts2.Domain and not self.Domain then self.Domain = self:MakeDomain() end
		if opts2.Screen and not self.Screen then self.Screen = newScreen(opts2.Screen) end
	end
	function e.End(self, clockAt)
		local at = clockAt or os.clock()
		if not self.EndAt or at < self.EndAt then self.EndAt = at end
		if not self.OpenAt then self.CancelAt = self.CancelAt or os.clock() end
	end
	function e.Cancel(self)
		self.CancelAt = self.CancelAt or os.clock()
	end

	--- the per-frame frame: the caster's body (world) or the local viewmodel (first person)
	local function frame()
		local cam = camera()
		if e.FP then
			local r, l = vmCall("GetFistCFrame", "R"), vmCall("GetFistCFrame", "L")
			if typeof(r) == "CFrame" and typeof(l) == "CFrame" then
				local c = (r.Position + l.Position) / 2 + cam.CFrame:VectorToWorldSpace(V3(0, 0.03, -0.06))
				return { C = c, Rm = cam.CFrame.Rotation, K = Vx.Scale1P, FP = true, Look = cam.CFrame.LookVector }
			end
		end
		local root = caster:FindFirstChild("HumanoidRootPart")
		if not root then return nil end
		local rh, lh = caster:FindFirstChild("RightHand"), caster:FindFirstChild("LeftHand")
		local mid = (rh and lh) and (rh.Position + lh.Position) / 2 or root.CFrame:PointToWorldSpace(V3(0, 0.9, -1))
		return { C = mid + root.CFrame:VectorToWorldSpace(V3(0, 0.1, -0.45)), Rm = root.CFrame.Rotation, K = 1, FP = false,
			Root = root.CFrame }
	end

	-- the vortex's per-ribbon constants, for the world axis and the first-person one
	local consts = {}
	local function constsFor(fp)
		if consts[fp] then return consts[fp] end
		local A = (fp and Vx.Axis1P or Vx.Axis3P).Unit
		local t1, t2 = perpB(A)
		local list = {}
		for i = 0, #Vx.Kinds - 1 do
			local ti = t1 * math.cos(TAU * i / 6) + t2 * math.sin(TAU * i / 6)
			list[i + 1] = { N0 = rotate(ti, 0.75 + 0.12 * (i % 3), A), Prec = ((i % 2 == 0) and 1 or -1) * Vx.Precession,
				B = 0.02 + 0.055 * i, R0 = 3.0 + 0.35 * (i % 3), Z0 = Vx.Z0[i + 1], Theta0 = 0.4 + TAU * i / 6, Chi0 = 1.3 * i }
		end
		consts[fp] = { A = A, List = list }
		return consts[fp]
	end

	local function stepVortex(now, tc, fr)
		local uo = tc - OPEN
		local cancel = 1
		if e.CancelAt then cancel = 1 - clamp01((now - e.CancelAt) / X.CancelFade) end
		-- the core: forms between the hands, pressed; pulled wide at the open; shrinks away (never fades)
		local Cc = X.Core
		local k = fr.FP and Vx.Scale1P or 1
		local d1 = Cc.Diameter * k * (1 - Cc.Press)
		local size
		if tc < OPEN then
			size = Vector3.one * (Cc.Diameter * k * sio((tc - 0.08) / 0.55) * (1 - Cc.Press * sio((tc - 0.45) / 0.55)))
		elseif tc < OPEN + 0.10 then
			local q = qout(uo / 0.10)
			size = V3(d1 * (1 + 0.9 * q), d1 * (1 - 0.2 * q), d1 * (1 - 0.2 * q))
		elseif tc < OPEN + 0.16 then
			size = V3(1.9, 0.8, 0.8) * (d1 * (1 - clamp01((uo - 0.10) / 0.06)) ^ 1.5)
		end
		if size and cancel > 0 then
			size *= cancel
			local rFull = fr.FP and Cc.Radius1P or Cc.Radius3P
			e.Core:put(CFrame.new(fr.C) * fr.Rm, size, math.max(size.X, size.Y, size.Z) / (2 * rFull), tellA(caster, now),
				"sphere", 1)
		else
			e.Core:hide()
		end
		-- the six ribbons: stream in, weave a tightening vortex (the held beat), sweep out at the open
		local cs = constsFor(fr.FP)
		local A = cs.A
		local sw = if uo > 0 then math.sin(math.pi * clamp01(uo / Vx.SwellTime)) else 0
		for _, r in ipairs(e.Ribs) do
			local c = cs.List[r.I + 1]
			if uo > 0.75 or cancel <= 0 then
				r.Rib:hide()
				continue
			end
			local function nAt(tau) return rotate(A, c.Prec * math.min(tau, OPEN), c.N0) end
			local function Rv(tau) return fr.K * (1.15 - 0.37 * sio((tau - 0.35) / 0.65)) end
			local function path(tau)
				local g = math.min(tau, OPEN)
				local th = c.Theta0 + TAU * (0.9 * g + 0.5 * math.max(0, g - 0.2) ^ 2)
				local n, R, z, centre
				if tau <= OPEN then
					n = nAt(tau)
					local ee = sio((tau - c.B) / 0.5)
					R = c.R0 * fr.K * (1 - ee) + Rv(tau) * ee
					z = c.Z0 * fr.K * (1 - ee) * (fr.FP and 0.3 or 1)
					centre = fr.C
				else
					local u = tau - OPEN
					th += TAU * 1.7 * (1 - math.exp(-2 * u)) / 2                  -- 1.7 turns a second, slowing
					local n1 = nAt(OPEN)
					if fr.FP then                                                   -- an iris of silk in the view plane
						local f = sio(u / 0.4)
						n = unitOr(n1 * (1 - f) + A * f, A)
						R = Rv(OPEN) + 2.3 * qout(u / 0.6)
						z = 0
						centre = fr.C + fr.Look * (1.2 * sio(u / 0.45))
					else                                                            -- the planes lie down round Umbra
						local f = 0.9 * sio(u / 0.22)
						n = unitOr(n1 * (1 - f) + Vector3.yAxis * f, Vector3.yAxis)
						R = Rv(OPEN) + 4.6 * qout(u / 0.75)
						z = 0.55 * c.Z0 * sio(u / 0.5)
						centre = fr.C:Lerp(fr.Root:PointToWorldSpace(V3(0, 0.9, -0.2)), sio(u / 0.4))
					end
				end
				local o1, o2 = perpB(n)
				return centre + fr.Rm * ((o1 * math.cos(th) + o2 * math.sin(th)) * R + n * z)
			end
			local g = sstep(c.B, c.B + 0.15, tc)
			local width = fr.FP and Vx.Width1P * (if uo > 0 then 1 + 0.8 * sio(uo / 0.5) else 1) or Vx.Width3P
			local thin = 1 - 0.8 * sstep(0.1, 0.6, uo)
			local chi0 = c.Chi0
			r.Rib:drawB(path, tc, Vx.Span, width * g * thin, g * (1 - sstep(0.3, 0.75, uo)) * cancel,
				1 + Vx.Swell * sw, Vx.SwellFlare * sw, function(tau) return 0.9 * math.sin(math.pi * tau + chi0) end)
		end
		return uo <= 0.75 and cancel > 0
	end

	--- THE DOMAIN (every viewer in the duel): the ground wave, the violet pulse, the wisps, anchored at C at the open
	function e.MakeDomain(self)
		local Cf, params = groundFrame(caster)
		if not Cf then return nil end
		local Wv, Wp, Pu = X.Wave, X.Wisps, X.Pulse
		local dom = { C = Cf, Wave = {}, Wisps = {} }
		for i = 0, Wv.Count - 1 do
			local kind = (i % 3 == 0) and "light" or "shadow"
			dom.Wave[i + 1] = { Rib = newRibbon("B", kind, 2, Wv.Segments, true, jitterSpeed(Wv.TextureSpeed, i)), I = i }
		end
		for i, def in ipairs(Wp.Centres) do
			local i0 = i - 1
			local localC = def[1]
			-- keep a wisp out of the walls: pulled in short of the first thing between C's height and it
			local from = Cf:PointToWorldSpace(V3(0, localC.Y, 0))
			local target = Cf:PointToWorldSpace(localC)
			local hit = workspace:Raycast(from, target - from, params)
			if hit then
				local dist = (hit.Position - from).Magnitude - Wp.WallPad
				if dist < 4 then continue end
				target = from + (target - from).Unit * dist
			end
			local rh = math.max(flat(target - Cf.Position).Magnitude, Wv.Start + 0.01)
			local uAt = if rh < Wv.Start + Wv.Reach * 0.99 then -math.log(1 - (rh - Wv.Start) / Wv.Reach) / Wv.Rate else 9
			dom.Wisps[#dom.Wisps + 1] = { Rib = newRibbon("B", def[2], 2, Wp.Segments, true, jitterSpeed(Wp.TextureSpeed, i0)),
				Centre = target, Tb = OPEN + uAt, W = (0.55 + 0.04 * i0) * ((i0 % 2 == 0) and 1 or -1), A = 0.9 * i0,
				B = 1.7 * i0, Chi = 1.1 * i0 }
		end
		-- the pulse: a big soft light over C and a ColorCorrection Enabled ONLY while it pulses (two stacked
		-- ColorCorrections once cut every blue to 0.83: this one must be inert the rest of the time)
		local att = Instance.new("Attachment")
		att.Name = "UmbraPulse"
		att.WorldPosition = Cf:PointToWorldSpace(V3(0, Pu.LightHeight, 0))
		att.Parent = workspace.Terrain
		local light = Instance.new("PointLight")
		light.Color = PAL.Shade
		light.Range = Pu.LightRange
		light.Shadows = false
		light.Brightness = 0
		light.Parent = att
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "UmbraPulse"
		cc.Enabled = false
		cc.Parent = Lighting
		dom.Att, dom.Light, dom.CC = att, light, cc
		return dom
	end

	local function stepDomain(dom, now, tc, tEnd)
		local Wv, Wp, Pu = X.Wave, X.Wisps, X.Pulse
		local u = tc - OPEN
		local C = dom.C
		local busy = false
		local cull = far(C.Position)
		-- the ground wave: twelve ribbons race outward low along the ground on pinwheel arms
		local sw = if u > 0 then math.sin(math.pi * clamp01(u / Vx.SwellTime)) else 0
		for _, r in ipairs(dom.Wave) do
			if u <= 0 or u > Wv.Life or cull then
				r.Rib:hide()
				continue
			end
			busy = true
			local i = r.I
			local function radius(x)
				if x < 0 then return Wv.Start * math.exp(Wv.Reach * Wv.Rate / Wv.Start * x) end
				return Wv.Start + Wv.Reach * (1 - math.exp(-Wv.Rate * x))
			end
			local function path(tau)
				local rr = radius(tau - OPEN)
				local phi = TAU * i / Wv.Count + 0.2 + Wv.Curl * math.log(math.max(rr, 1e-4) / Wv.Start)
				return C:PointToWorldSpace(V3(rr * math.cos(phi), Wv.Height + Wv.Ripple * math.sin(0.3 * rr + i), rr * math.sin(phi)))
			end
			local aIn = sstep(0, 0.06, u)
			r.Rib:drawB(path, tc, Wv.Span, Wv.Width * aIn * (1 - 0.45 * sstep(0.4, 1.6, u)), aIn * (1 - sstep(0.8, 1.6, u)),
				1 + Vx.Swell * sw, Vx.SwellFlare * sw, nil)
		end
		-- the wisps: slow upright loops in the air for the whole domain, born as the wave passes under them
		for _, w in ipairs(dom.Wisps) do
			local aIn = sstep(w.Tb, w.Tb + Wp.FadeIn, tc)
			local out = 1 - sstep(tEnd, tEnd + Wp.FadeOut, tc)
			if out > 0 then busy = true end
			if aIn <= 0 or out <= 0 or cull then
				w.Rib:hide()
				continue
			end
			local function path(tau)
				return w.Centre + C:VectorToWorldSpace(V3(Wp.Loop.X * math.cos(w.W * tau + w.A), Wp.Loop.Y * math.sin(w.W * tau + w.A),
					Wp.Loop.Z * math.sin(0.5 * w.W * tau + w.B)))
			end
			w.Rib:drawB(path, tc, Wp.Span, Wp.Width * aIn, Wp.Alpha * aIn * out, 1, 0,
				function(tau) return 0.9 * math.sin(TAU * 0.25 * tau + w.Chi) end)
		end
		-- the pulse
		local p = 0
		if u >= 0 then p = if u < Pu.Rise then qout(u / Pu.Rise) else 1 - sio((u - Pu.Rise) / Pu.Fall) end
		dom.Light.Brightness = Pu.LightBrightness * p
		local on = p > 0.001
		if dom.CC.Enabled ~= on then dom.CC.Enabled = on end
		if on then
			busy = true
			dom.CC.TintColor = Color3.new(1, 1, 1):Lerp(wrapped("PulseTint", Pu.Tint), p)
			dom.CC.Brightness = Pu.Brightness * p
			dom.CC.Saturation = Pu.Saturation * p
			dom.CC.Contrast = 0
		end
		return busy or u < Wv.Life
	end

	e.Step = function(self, now)
		local tc = clock(now)
		local tEnd = endTc()
		local busy = false
		local cam = camera()
		local fr = self.Character.Parent and frame() or nil
		if fr and (fr.FP or not far(fr.C)) then
			busy = stepVortex(now, tc, fr) or busy
		else
			self.Core:hide()
			for _, r in ipairs(self.Ribs) do r.Rib:hide() end
			busy = tc < OPEN + 0.75 and not self.CancelAt
		end
		if self.CancelAt and not self.OpenAt then
			return now - self.CancelAt < X.CancelFade + 0.05
		end
		if self.Domain then busy = stepDomain(self.Domain, now, tc, tEnd) or busy end
		if self.Screen then busy = stepScreen(self.Screen, tc, tEnd) or busy end
		-- the domain lasts until its end (EclipseEnd, or Until as a backstop) and its fade
		if self.OpenAt and tc < tEnd + math.max(X.Wisps.FadeOut, X.Screen.Out) + 0.2 then busy = true end
		if not self.OpenAt and not self.CancelAt then busy = true end         -- the windup, waiting on the open
		return busy and cam ~= nil
	end
	e.Stop = function(self)
		self.Core:free()
		freeAll(self.Ribs)
		local dom = self.Domain
		if dom then
			freeAll(dom.Wave)
			freeAll(dom.Wisps)
			dom.Att:Destroy()
			dom.CC:Destroy()
		end
		if self.Screen then self.Screen.Gui:Destroy() end
	end
	return run(e)
end

----------------------------------------------------------------------------------------------------
-- THE WORLD GRADE ("V4", per viewer): refcounted by key, the map's own values recorded at the start and put back after
----------------------------------------------------------------------------------------------------
local grade = { Keys = {}, Count = 0, Saved = nil, Tweens = {}, CC = nil, Atmo = nil, AtmoMade = false, Map = nil,
	Fading = false, FadeToken = nil }

local LIGHTING_PROPS = { "Brightness", "ExposureCompensation", "Ambient", "OutdoorAmbient" }
local ATMO_PROPS = { "Density", "Color", "Decay", "Haze" }

local function stopGradeTweens()
	for _, tw in ipairs(grade.Tweens) do tw:Cancel() end
	grade.Tweens = {}
end

local function tweenTo(inst, props, time, style, dir)
	local tw = TweenService:Create(inst, TweenInfo.new(time, style, dir), props)
	grade.Tweens[#grade.Tweens + 1] = tw
	tw:Play()
	return tw
end

--- whether `v` still lies between the map's value and ours (so nothing else has written it meanwhile)
local function between(v, a, b)
	if typeof(v) == "number" then
		return v >= math.min(a, b) - 1e-3 and v <= math.max(a, b) + 1e-3
	elseif typeof(v) == "Color3" then
		return between(v.R, a.R, b.R) and between(v.G, a.G, b.G) and between(v.B, a.B, b.B)
	end
	return false
end

--- the grade a wrap darkens the world with: UmbraTuning's own with the wrap's five colours (built once per wrap)
local gradeOf = setmetatable({}, { __mode = "k" })
local function wrapGrade()
	local W = wrapped("Grade", nil)
	if not W then return nil end
	local g = gradeOf[W]
	if not g then
		local B = FX.Eclipse.Grade
		g = { InTime = B.InTime, OutTime = B.OutTime, Lighting = table.clone(B.Lighting),
			Atmosphere = table.clone(B.Atmosphere), ColorCorrection = table.clone(B.ColorCorrection) }
		g.Lighting.Ambient, g.Lighting.OutdoorAmbient = W.Ambient, W.OutdoorAmbient
		g.Atmosphere.Color, g.Atmosphere.Decay = W.AtmosphereColor, W.AtmosphereDecay
		g.ColorCorrection.TintColor = W.TintColor
		gradeOf[W] = g
	end
	return g
end

local function gradeIn()
	local G = grade.G or FX.Eclipse.Grade
	stopGradeTweens()
	grade.Fading = false                    -- pushed again during a fade-out: the same records and instances go on
	if not grade.Saved then
		-- RECORD the map's own values (never assumed); a push during a fade-out keeps the values recorded first
		local saved = { Lighting = {}, Atmosphere = nil }
		for _, k in ipairs(LIGHTING_PROPS) do saved.Lighting[k] = Lighting[k] end
		local atmo = Lighting:FindFirstChildOfClass("Atmosphere")
		if atmo then
			saved.Atmosphere = {}
			for _, k in ipairs(ATMO_PROPS) do saved.Atmosphere[k] = atmo[k] end
			grade.Atmo, grade.AtmoMade = atmo, false
		else
			-- none: a temporary one, starting from nothing
			atmo = Instance.new("Atmosphere")
			atmo.Name = "UmbraEclipseAtmosphere"
			atmo.Density, atmo.Haze, atmo.Glare, atmo.Offset = 0, 0, 0, 0
			atmo.Color, atmo.Decay = G.Atmosphere.Color, G.Atmosphere.Decay
			atmo.Parent = Lighting
			saved.Atmosphere = { Density = 0, Color = atmo.Color, Decay = atmo.Decay, Haze = 0 }
			grade.Atmo, grade.AtmoMade = atmo, true
		end
		grade.Saved = saved
		grade.Map = player:GetAttribute("Map")
	end
	if not (grade.CC and grade.CC.Parent) then
		local cc = Instance.new("ColorCorrectionEffect")
		cc.Name = "UmbraEclipseGrade"
		cc.Brightness, cc.Contrast, cc.Saturation, cc.TintColor = 0, 0, 0, Color3.new(1, 1, 1)
		cc.Parent = Lighting
		grade.CC = cc
	end
	local style, dir = Enum.EasingStyle.Quad, Enum.EasingDirection.Out
	tweenTo(Lighting, G.Lighting, G.InTime, style, dir)
	if grade.Atmo and grade.Atmo.Parent then tweenTo(grade.Atmo, G.Atmosphere, G.InTime, style, dir) end
	tweenTo(grade.CC, G.ColorCorrection, G.InTime, style, dir)
end

local function gradeOut()
	local G = grade.G or FX.Eclipse.Grade
	local saved = grade.Saved
	stopGradeTweens()
	if not saved then return end
	local style, dir = Enum.EasingStyle.Sine, Enum.EasingDirection.InOut
	local sameMap = player:GetAttribute("Map") == grade.Map
	-- back to the map's values -- each one only while it is still ours (a map loaded meanwhile keeps its own lighting)
	if sameMap then
		local back = {}
		for _, k in ipairs(LIGHTING_PROPS) do
			if between(Lighting[k], saved.Lighting[k], G.Lighting[k]) then back[k] = saved.Lighting[k] end
		end
		if next(back) then tweenTo(Lighting, back, G.OutTime, style, dir) end
	end
	local atmo, made = grade.Atmo, grade.AtmoMade
	if atmo and atmo.Parent and saved.Atmosphere and (made or sameMap) then
		local back = {}
		for _, k in ipairs(ATMO_PROPS) do
			if made or between(atmo[k], saved.Atmosphere[k], G.Atmosphere[k]) then back[k] = saved.Atmosphere[k] end
		end
		if next(back) then tweenTo(atmo, back, G.OutTime, style, dir) end
	end
	local cc = grade.CC
	if cc and cc.Parent then
		tweenTo(cc, { Brightness = 0, Contrast = 0, Saturation = 0, TintColor = Color3.new(1, 1, 1) }, G.OutTime, style, dir)
	end
	-- once faded (and not pushed again meanwhile: gradeIn clears Fading and reuses all of this), our own instances go
	grade.Fading = true
	local token = {}
	grade.FadeToken = token
	task.delay(G.OutTime + 0.05, function()
		if grade.FadeToken ~= token or not grade.Fading or grade.Count > 0 then return end
		grade.Fading = false
		if cc and cc.Parent then cc:Destroy() end
		if made and atmo and atmo.Parent then atmo:Destroy() end
		grade.Saved, grade.Atmo, grade.AtmoMade, grade.CC, grade.Map = nil, nil, false, nil, nil
	end)
end

--- Darken this viewer's world for one Eclipse (key: the caster's UserId). The first push records the map's values.
function UmbraFX.GradePush(key)
	if not FX or key == nil or grade.Keys[key] then return end
	grade.Keys[key] = true
	grade.Count += 1
	if grade.Count == 1 then
		grade.G = wrapGrade()               -- the first Eclipse's wrap grades the view; a second one joins it
		local ok, err = pcall(gradeIn)
		if not ok then warnOnce("gradein", "the Eclipse grade failed: " .. tostring(err)) end
	end
end

function UmbraFX.GradePop(key)
	if not FX or key == nil or not grade.Keys[key] then return end
	grade.Keys[key] = nil
	grade.Count = math.max(0, grade.Count - 1)
	if grade.Count == 0 then
		local ok, err = pcall(gradeOut)
		if not ok then warnOnce("gradeout", "restoring the map's lighting failed: " .. tostring(err)) end
	end
end

----------------------------------------------------------------------------------------------------
-- THE REVEAL (the caster only): a light-purple outline on the nearest RevealMax enemies, through walls
----------------------------------------------------------------------------------------------------
local reveal = nil         -- { Until (server time), Bodies (fn), Highlights = { [model] = Highlight }, Conn, Acc }

function UmbraFX.RevealStop()
	if not reveal then return end
	if reveal.Conn then reveal.Conn:Disconnect() end
	for _, h in pairs(reveal.Highlights) do h:Destroy() end
	reveal = nil
end

local function refreshReveal()
	if not reveal then return end
	local me = player.Character
	local root = me and me:FindFirstChild("HumanoidRootPart")
	if not root or workspace:GetServerTimeNow() >= reveal.Until then return UmbraFX.RevealStop() end
	local Ec = T.Eclipse
	local list = {}
	local ok, bodies = pcall(reveal.Bodies)
	for _, m in ipairs(ok and type(bodies) == "table" and bodies or {}) do
		local r = m:FindFirstChild("HumanoidRootPart") or m.PrimaryPart
		local h = m:FindFirstChildOfClass("Humanoid")
		if r and h and h.Health > 0 then
			local d = (r.Position - root.Position).Magnitude
			if d <= Ec.RevealRange then list[#list + 1] = { M = m, D = d } end
		end
	end
	table.sort(list, function(a, b) return a.D < b.D end)
	local keep = {}
	for i = 1, math.min(#list, Ec.RevealMax) do keep[list[i].M] = true end
	for m, h in pairs(reveal.Highlights) do
		if not keep[m] or not m.Parent then
			h:Destroy()
			reveal.Highlights[m] = nil
		end
	end
	local colour = reveal.Colour or Ec.RevealColor or PAL.Shade
	for m in pairs(keep) do
		if not reveal.Highlights[m] then
			local h = Instance.new("Highlight")
			h.Name = "UmbraReveal"
			h.Adornee = m
			h.FillTransparency = 1
			h.OutlineTransparency = 0
			h.OutlineColor = colour
			h.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
			h.Parent = m
			reveal.Highlights[m] = h
		end
	end
end

--- untilServer: the server time the reveal ends; bodies(): the enemy models this caster may see
function UmbraFX.RevealStart(untilServer, bodies)
	if not T then return end
	UmbraFX.RevealStop()
	reveal = { Until = untilServer or (workspace:GetServerTimeNow() + T.Eclipse.Duration), Bodies = bodies, Highlights = {},
		Acc = 0, Colour = wrapped("RevealColor", nil) }
	reveal.Conn = RunService.Heartbeat:Connect(function(dt)
		if not reveal then return end
		reveal.Acc += dt
		if reveal.Acc < 0.5 then return end
		reveal.Acc = 0
		refreshReveal()
	end)
	refreshReveal()
end

----------------------------------------------------------------------------------------------------
-- WRAPS (SkinCatalog, 2026-10-11): every entry point draws under its caster's wrap for the ability it belongs to --
-- the caster's own replicated, validated choice (the player attribute Skin_<ability>). A wrap changes colour only:
-- no shape, count, timing or mechanic reads it. No wrap: the entry runs exactly as it always has.
----------------------------------------------------------------------------------------------------
local SkinCat = nil
local function wrapOf(character, ability)
	local plr = typeof(character) == "Instance" and Players:GetPlayerFromCharacter(character) or nil
	if not plr then return nil end
	if SkinCat == nil then
		local folder = ReplicatedStorage:FindFirstChild("Spellshot")
		local m = folder and folder:FindFirstChild("SkinCatalog")
		local ok, mod = pcall(function() return m and require(m) end)
		SkinCat = (ok and type(mod) == "table") and mod or false
	end
	if not SkinCat then return nil end
	local ok, skin = pcall(function() return SkinCat.Resolve("Umbra", ability, SkinCat.Chosen(plr, ability)) end)
	return (ok and type(skin) == "table" and type(skin.Shadow) == "table") and skin.Shadow or nil
end

--- The four palette colours `character`'s `ability` draws with: its wrap's, else Umbra's own (UmbraClient's marker)
function UmbraFX.Palette(character, ability)
	local w = wrapOf(character, ability)
	return (w and w.Color) or BASE_PAL
end

local function under(w, fn, ...)
	local prev = CUR
	CUR = w
	local r = table.pack(pcall(fn, ...))
	CUR = prev
	if not r[1] then error(r[2], 0) end
	return table.unpack(r, 2, r.n)
end
local function ownerOf(opts) return type(opts) == "table" and opts.Owner or nil end

local ENTRIES = {
	DartCharge = function(character) return wrapOf(character, "ShadowDart") end,
	Dart = function(owner) return wrapOf(owner, "ShadowDart") end,
	Hit = function(_, _, opts) return wrapOf(ownerOf(opts), "ShadowDart") end,
	MarkHeadshot = function(_, _, opts) return wrapOf(ownerOf(opts), "Mark") end,
	StepOut = function(character) return wrapOf(character, "ShadowStep") end,
	DecoyPeel = function(owner) return wrapOf(owner, "DecoyDouble") end,
	DecoyBreak = function(_, opts) return wrapOf(ownerOf(opts), "DecoyDouble") end,
	Eclipse = function(caster) return wrapOf(caster, "Eclipse") end,
	-- the Tell lights whichever move broke the concealment
	Tell = function(character, reason) return wrapOf(character, reason == "Decoy" and "DecoyDouble" or "ShadowDart") end,
	GradePush = function(key)
		local plr = type(key) == "number" and Players:GetPlayerByUserId(key) or nil
		return wrapOf(plr and plr.Character, "Eclipse")
	end,
	RevealStart = function() return wrapOf(player.Character, "Eclipse") end,
}
for name, pick in pairs(ENTRIES) do
	local raw = UmbraFX[name]
	if type(raw) == "function" then
		UmbraFX[name] = function(...)
			local w = pick(...)
			if not w then return raw(...) end
			local res = under(w, raw, ...)
			-- the handle's own methods build and recolour too (Release, Impact, Open ...): each under the same wrap
			if type(res) == "table" then
				for k, v in pairs(res) do
					if type(v) == "function" and k ~= "Step" and k ~= "Stop" then
						res[k] = function(...) return under(w, v, ...) end
					end
				end
			end
			return res
		end
	end
end

return UmbraFX

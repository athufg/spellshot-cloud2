--[[
	ToxinFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/ToxinFX

	TOXIN's look, matched to the Blender v4 showcase (vfx_blocking/toxin/<piece>/v4/, TOXIN_KIT_SPEC.md v4; the developer's
	clips toxin1..6). Rev 2, 2026-10-01: the first build's smoke-sprite clouds and glass bubble are replaced by the
	showcase's own reads. Client only; every piece is drawn from a ToxinHandler broadcast (ToxinClient.Handlers calls in
	here, guarded). Nothing here decides gameplay.

	THE FOUR LOCKED FAMILIES (ToxinTuning.Color), as Roblox builds them:
	  GAS       a lobed CUMULUS: overlapping sphere-mesh lobes (a near-opaque core inside a thin halo), dark shadow-olive at
	            the base and the heart, lit-olive crowns; every silhouette softened by smoke particles emitted from the lobe
	            surfaces (LightInfluence 1); flat on the ground with a pooling skirt and a soft dark contact patch (flat,
	            ground-lying particles); lobes grow in one by one, then breathe (+-5% at 0.5 Hz, each on its own phase) and
	            drift. Virulence sits INSIDE as one soft glow (a PointLight and a few faint additive particles at the core).
	  LIQUID    smooth olive blobs and teardrops with a wet sheen (SmoothPlastic + Reflectance): drops stretch as they fall and
	            land as raised splats (flattened spheres) that linger; residue runs down a target.
	  MEMBRANE  the Toxic Bubble: a thin olive sac (translucent body + a ForceField-material shell for the dense, lighter rim)
	            over a dark murk ball with slow smoke inside and a small dim steady glow.
	  VIRULENCE Neon or light only. STEADY for active states; ACCELERATING toward a payoff (Patient Zero's gears
	            0.6 -> 1.8 -> 4.6 Hz, then a solid fuse; the Corroded rim as its stacks near the cap). The Passive carries none.
	THREADS    (the lifesteal tick, the Vent's cleanse): chains of Beams through moving attachments -- thin, curling, tapered,
	            translucent grey-olive strands, a head that draws out and a tail that follows.
	THE HARD RULE: Toxin's shipped identity colours (#80D421, #CCF570, #4A1A6B) are UI and uniform only. Every colour this
	module draws goes through safe(), which refuses anything within 12/255 per channel of them; the palette is checked on load.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local T = require(script.Parent:WaitForChild("ToxinTuning"))
local C = T.Color
local player = Players.LocalPlayer

local ToxinFX = {}
ToxinFX.Handlers = {}
local H = ToxinFX.Handlers

----------------------------------------------------------------------------------------------------
-- the hard rule, in code
----------------------------------------------------------------------------------------------------
local function nearShipped(c)
	for _, s in ipairs(T.Shipped) do
		if math.abs(c.R - s.R) * 255 <= 12 and math.abs(c.G - s.G) * 255 <= 12 and math.abs(c.B - s.B) * 255 <= 12 then
			return true
		end
	end
	return false
end

local function safe(c)
	if nearShipped(c) then
		warn("[ToxinFX] refused a shipped identity colour on an effect: " .. tostring(c))
		return C.Gas
	end
	return c
end

for name, c in pairs(C) do
	if nearShipped(c) then
		warn("[ToxinFX] palette entry " .. name .. " sits on a shipped identity colour; drawn as Gas instead")
		C[name] = C.Gas
	end
end

-- THE DISPLAY TABLE (ToxinTuning.Display, measured on the Training Ground): an effect names its colour by its locked
-- SOURCE hex; what is built is the input that DISPLAYS as that source's showcase colour under the place's own lighting and
-- grade. Contexts: Lobe (Plaster gas), Particle, Solid (SmoothPlastic), Neon, Glow (additive particles, PointLights).
local DISPLAY = T.Display or {}
for ctx, tbl in pairs(DISPLAY) do
	for name, c in pairs(tbl) do
		if nearShipped(c) then
			warn("[ToxinFX] display entry " .. ctx .. "." .. name .. " sits on a shipped identity colour; the source is used")
			tbl[name] = nil
		end
	end
end
local function disp(ctx, name)
	local src = C[name]
	local t = DISPLAY[ctx]
	return safe((t and t[name]) or src)
end
local function context(ctx)
	return setmetatable({}, { __index = function(_, name) return disp(ctx, name) end })
end
local LOBE, PART, SOLID, NEON, GLOW = context("Lobe"), context("Particle"), context("Solid"), context("Neon"), context("Glow")

local function seq(...)
	local cols = { ... }
	if T.Hard and #cols > 1 then                         -- (a hard-banded wrap draws: steps, no blending)
		local keys, n = {}, #cols
		for i, c in ipairs(cols) do
			keys[#keys + 1] = ColorSequenceKeypoint.new((i - 1) / n, safe(c))
			keys[#keys + 1] = ColorSequenceKeypoint.new(i == n and 1 or i / n - 0.001, safe(c))
		end
		return ColorSequence.new(keys)
	end
	local keys = {}
	for i, c in ipairs(cols) do
		keys[i] = ColorSequenceKeypoint.new((i - 1) / math.max(1, #cols - 1), safe(c))
	end
	if #keys == 1 then keys[2] = ColorSequenceKeypoint.new(1, keys[1].Value) end
	return ColorSequence.new(keys)
end

local function nseq(points)
	local keys = {}
	for i, p in ipairs(points) do keys[i] = NumberSequenceKeypoint.new(p[1], p[2], p[3] or 0) end
	return NumberSequence.new(keys)
end

----------------------------------------------------------------------------------------------------
-- plumbing
----------------------------------------------------------------------------------------------------
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local TAU = math.pi * 2

local function serverNow()
	return workspace:GetServerTimeNow()
end

local function fxFolder()
	local f = workspace:FindFirstChild("IceMagicFX")
	if not f then
		f = Instance.new("Folder")
		f.Name = "IceMagicFX"
		f.Parent = workspace
	end
	return f
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.SmoothPlastic
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Size = Vector3.new(1, 1, 1)
	for k, v in pairs(props or {}) do
		if k == "Color" then v = safe(v) end
		p[k] = v
	end
	return p
end

--- An ellipsoid: a block part carrying a sphere mesh, sized by the PART (so emitters on it emit from its true shape).
local flowTag, flowAdd, FLOW_MODE   -- (pH Indicator: assigned with the flow, below)
local function ball(color, transparency, parent, props)
	local p = part(props)
	p.Color = safe(color)
	if T.Bands and T.Bands.Flow and flowTag then flowTag(p, color) end   -- (pH Indicator: the flow)
	p.Transparency = transparency or 0
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	p.Parent = parent or fxFolder()
	return p
end

local function light(parent, range, brightness)
	local l = Instance.new("PointLight")
	l.Color = GLOW.Virulence
	if FLOW_MODE and flowAdd then flowAdd(l, T.Bands.Flow, "Glow", "Virulence") end
	l.Range = range
	l.Brightness = brightness
	l.Shadows = false
	l.Parent = parent
	return l
end

local function easeOut(k)
	return 1 - (1 - k) ^ 3
end

local function backOut(k)
	local c1 = 1.1
	return 1 + (c1 + 1) * (k - 1) ^ 3 + c1 * (k - 1) ^ 2
end

--- THE FX CLOCK. Every piece runs on it: real time, times ToxinFX.TimeScale -- 1 always in play. SetTimeScale is a
--- review tool (slow a beat to a near-standstill to frame-match it against the showcase); particles follow it too.
local clock = 0
ToxinFX.TimeScale = 1
local function fxNow()
	return clock
end

local scaleHooked = false
function ToxinFX.SetTimeScale(scale)
	ToxinFX.TimeScale = math.max(0, scale)
	local f = workspace:FindFirstChild("IceMagicFX")
	if not f then return end
	for _, e in ipairs(f:GetDescendants()) do
		if e:IsA("ParticleEmitter") then e.TimeScale = math.clamp(ToxinFX.TimeScale, 0, 1) end
	end
	if not scaleHooked then
		scaleHooked = true
		f.DescendantAdded:Connect(function(e)
			if e:IsA("ParticleEmitter") and ToxinFX.TimeScale ~= 1 then
				e.TimeScale = math.clamp(ToxinFX.TimeScale, 0, 1)
			end
		end)
	end
end

--- One RenderStepped loop for every live piece: fn(dt, now) returns false when the piece is done.
local updaters = {}
RunService.RenderStepped:Connect(function(rdt)
	local dt = rdt * ToxinFX.TimeScale
	clock += dt
	local now = clock
	for key, fn in pairs(updaters) do
		local ok, keep = pcall(fn, dt, now)
		if not ok then
			warn("[ToxinFX] an updater failed: " .. tostring(keep))
			updaters[key] = nil
			-- (2026-10-19, audit P5B-18) its parts go with it: the key is the piece (a part, a folder) or its record
			pcall(function()
				local inst = (typeof(key) == "Instance" and key) or (type(key) == "table" and (key.Model or key.Folder)) or nil
				if typeof(inst) == "Instance" then inst:Destroy() end
			end)
		elseif keep == false then
			updaters[key] = nil
		end
	end
end)

local function rootOf(model)
	return model and (model:FindFirstChild("HumanoidRootPart") or model.PrimaryPart) or nil
end

local function torsoOf(model)
	return model and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso") or rootOf(model)) or nil
end

local function worldParams(extra)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	local exclude = { fxFolder(), workspace.CurrentCamera }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then exclude[#exclude + 1] = p.Character end
	end
	if extra then exclude[#exclude + 1] = extra end
	params.FilterDescendantsInstances = exclude
	return params
end

local function floorY(pos, reach, exclude)
	local hit = workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -(reach or 30), 0), worldParams(exclude))
	return hit and hit.Position.Y or nil
end

--- Flat, ground-lying particles (the contact patch, the pooling skirt): velocity straight up, faces perpendicular to it.
local function flatEmitter(holder, o)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Orientation = Enum.ParticleOrientation.VelocityPerpendicular
	e.EmissionDirection = Enum.NormalId.Top
	e.Speed = NumberRange.new(0.01)
	e.SpreadAngle = Vector2.new(0, 0)
	e.Color = seq(o.Color, o.Color)
	e.LightInfluence = o.LightInfluence or 1
	e.LightEmission = 0
	e.Size = nseq({ { 0, o.Size * 0.8 }, { 1, o.Size } })
	e.Transparency = nseq({ { 0, 1 }, { 0.25, o.Alpha }, { 0.75, o.Alpha }, { 1, 1 } })
	e.Lifetime = NumberRange.new(o.Life or 2.5, (o.Life or 2.5) * 1.3)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-6, 6)
	e.Shape = Enum.ParticleEmitterShape.Box
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	e.Rate = o.Rate or 2
	e.ZOffset = o.ZOffset or 0
	e.Parent = holder
	return e
end

--- The faint additive glow at a gas core: soft, few, pushed toward the camera so it reads through the front lobes.
local function glowEmitter(holder, size, alpha, zoff, rate)
	local e = Instance.new("ParticleEmitter")
	e.Texture = SMOKE
	e.Color = seq(GLOW.Virulence, GLOW.Virulence)
	if FLOW_MODE and flowAdd then flowAdd(e, T.Bands.Flow, "Glow", "Virulence") end
	e.LightEmission = 1
	e.LightInfluence = 0
	e.Size = nseq({ { 0, size * 0.8 }, { 1, size } })
	e.Transparency = nseq({ { 0, 1 }, { 0.3, alpha }, { 0.7, alpha }, { 1, 1 } })
	e.Lifetime = NumberRange.new(1.0, 1.6)
	e.Speed = NumberRange.new(0)
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = NumberRange.new(-20, 20)
	e.ZOffset = zoff or 0
	e.Rate = rate or 3
	e.Parent = holder
	return e
end

----------------------------------------------------------------------------------------------------
-- LIQUID: raised splats, falling drops, residue runs
----------------------------------------------------------------------------------------------------
local splatCount = 0
local SPLAT_CAP = 70

--- A raised wet splat (a flattened sphere) on the floor at `pos`: it spreads with a little rebound, lingers, soaks away.
--- (a wrap's wet finish, T.Finish) the Reflectance of a `k` site, else Default's `v`
local function wet(v, k) return T.Finish and T.Finish[k] or v end
local Settings = (function()
	local ok, m = pcall(function() return require(game:GetService("ReplicatedStorage").Spellshot.SpellshotSettings) end)
	return ok and m or nil
end)()
--- (a wrap's extra emitters) their scale: 0 at low Graphics Quality (the plain recolour), halved for somebody else's
--- effect under Reduce Enemy VFX and, for a pulsing wrap, under Reduce Flashing
local function extraScale()
	if not Settings then return 1 end
	local d = Settings.EffectDensity or 1
	if d < 0.75 then return 0 end
	local k = math.clamp(d, 0.4, 1)
	if Settings.ThinEnemyVFX and not T.Mine then k *= 0.5 end
	if T.Bands and T.Bands.Pulse and Settings.Get and Settings.Get("ReduceFlashing") then k *= 0.5 end
	return k
end
--- (2026-10-19, audit P5B-04) the DEFAULT pieces' scale -- smoke and glow rates, drops, Acid Rain's globs, thread
--- strands: Graphics Quality (0.4 .. 1), halved for an enemy's effect under Reduce Enemy VFX (T.Mine false: ToxinWrap.Run
--- sets it while each broadcast is drawn; nil in a piece drawn later counts as not an enemy's). Read when an effect is
--- made. The hazards' shapes and edges (the lobes, the pooling skirt, the wave's ring) keep their full count.
--- (2026-10-19, audit P5B-05) Reduce Flashing: read when an effect is made (Patient Zero's pulse, the bursts' lights,
--- the Corroded rim, the Vent's grille, Acid Rain's glow)
local function calm()
	return Settings ~= nil and Settings.Get ~= nil and Settings.Get("ReduceFlashing") == true
end
local function density()
	if not Settings then return 1 end
	local k = math.clamp(Settings.EffectDensity or 1, 0.4, 1.15)   -- (2026-10-23: ULTRA's 115%, the graphics table)
	if Settings.ThinEnemyVFX and T.Mine == false then k *= 0.5 end
	return k
end
--- (an Epic wrap, T.Bands.Pulse) its glow pieces breathe together: a part's Color or an emitter's LightEmission,
--- k = 1 +/- Amp over Period seconds, held at 1 under Reduce Flashing. Virulence and the mark's countdown never join
local glowSet = setmetatable({}, { __mode = "k" })
local glowPulse
--- (an Epic wrap, T.Bands.Eyes) the eye-spot: the bubble's painted ring as an image -- a dark pupil, the bright inner ring,
--- the saturated ring, its deep edge and a soft glow -- drawn once per palette into an EditableImage; nil if unavailable
local eyeImgs = {}
local function eyeImage(E)
	local c = eyeImgs[E]
	if c ~= nil then return c or nil end
	eyeImgs[E] = false
	local ok, im = pcall(function()
		local N = 64
		local img = game:GetService("AssetService"):CreateEditableImage({ Size = Vector2.new(N, N) })
		local buf = buffer.create(N * N * 4)
		local Pu, In, Rg, Ed = SOLID[E.Pupil], SOLID[E.Inner], SOLID[E.Ring], SOLID[E.Edge]
		local function sm(e0, e1, x) local t = math.clamp((x - e0) / (e1 - e0), 0, 1) return t * t * (3 - 2 * t) end
		for y = 0, N - 1 do
			for x = 0, N - 1 do
				local r = math.sqrt((x + 0.5 - N / 2) ^ 2 + (y + 0.5 - N / 2) ^ 2) / (N / 2)
				local col = Pu:Lerp(In, sm(0.24, 0.32, r))
				col = col:Lerp(Rg, sm(0.46, 0.54, r))
				col = col:Lerp(Ed, sm(0.66, 0.74, r))
				local a = r < 0.74 and 1 or (1 - sm(0.74, 1, r)) * 0.55     -- (solid to the deep edge, then the soft glow)
				local o = (y * N + x) * 4
				buffer.writeu8(buf, o, math.floor(col.R * 255 + 0.5))
				buffer.writeu8(buf, o + 1, math.floor(col.G * 255 + 0.5))
				buffer.writeu8(buf, o + 2, math.floor(col.B * 255 + 0.5))
				buffer.writeu8(buf, o + 3, math.floor(math.clamp(a, 0, 1) * 255 + 0.5))
			end
		end
		img:WritePixelsBuffer(Vector2.zero, Vector2.new(N, N), buf)
		return img
	end)
	eyeImgs[E] = ok and im or false
	return ok and im or nil
end
--- an eye-spot on `part` (a puff), `size` studs, offset in the world (`spread`) and toward the camera (`front`): it rides
--- the puff, faces the camera, is self-lit and breathes with the wrap; it fades with the puff (drawLobe)
local function eyeOn(part, E, spread, front, size)
	local img = eyeImage(E)
	if not img then return nil end
	local g = Instance.new("BillboardGui")
	g.Size = UDim2.fromScale(size, size)
	g.StudsOffsetWorldSpace = spread
	g.StudsOffset = Vector3.new(0, 0, front)
	g.LightInfluence, g.Brightness, g.AlwaysOnTop = 0, E.Bright or 1.4, false
	g.Adornee = part
	local l = Instance.new("ImageLabel")
	l.Size, l.BackgroundTransparency = UDim2.fromScale(1, 1), 1
	l.ImageContent = Content.fromObject(img)
	l.ImageColor3, l.ImageTransparency = Color3.new(0.87, 0.87, 0.87), 1
	l.Parent = g
	g.Parent = part
	if T.Bands and T.Bands.Pulse then glowPulse(l, T.Bands.Pulse) end   -- (2026-10-19, audit P5B-12) guarded
	return l
end
--- (an Epic wrap, T.Bands.RingTex) `n` of its glowing rings at `pos`, drifting up and fading: the palette is read now
local function ringBurst(pos, n, size)
	local B = T.Bands
	n = math.floor((n or 0) * extraScale() + 0.5)
	if not (B and B.RingTex) or n < 1 then return end
	local p = part({ Transparency = 1, Size = Vector3.new(1.5, 1.5, 1.5) })
	p.CFrame = CFrame.new(pos)
	p.Parent = fxFolder()
	local e = Instance.new("ParticleEmitter")
	e.Texture = B.RingArt or B.RingTex
	e.Color = B.RingArt and ColorSequence.new(Color3.new(1, 1, 1)) or seq(SOLID[B.Speckle], SOLID[B.Speckle])
	e.LightEmission, e.LightInfluence = B.MoteGlow or 0.5, 0
	e.Size = NumberSequence.new(size or 1.6)
	e.Transparency = nseq({ { 0, 1 }, { 0.15, 0.05 }, { 0.75, 0.15 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(1.4, 1.9)
	e.Speed = NumberRange.new(0.8, 1.6)
	e.SpreadAngle = Vector2.new(60, 60)
	e.Acceleration = Vector3.new(0, 1, 0)
	e.ZOffset = 0.6
	e.Rate = 0
	e.Parent = p
	e:Emit(n)
	if B.Pulse then glowPulse(e, B.Pulse) end
	Debris:AddItem(p, 2.5)
end
function glowPulse(obj, P)
	if not (P and obj) then return end
	local first = next(glowSet) == nil
	glowSet[obj] = { Base = obj:IsA("ParticleEmitter") and obj.LightEmission or (obj:IsA("ImageLabel") and obj.ImageColor3 or obj.Color), P = P }
	if not first then return end
	updaters[glowSet] = function(_, now)
		local hold = Settings and Settings.Get and Settings.Get("ReduceFlashing")
		local any = false
		for o, g in pairs(glowSet) do
			if o.Parent then
				any = true
				local k = hold and 1 or (1 + g.P.Amp * math.sin(TAU * now / g.P.Period))
				if o:IsA("ParticleEmitter") then o.LightEmission = math.clamp(g.Base * k, 0, 1)
				elseif o:IsA("ImageLabel") then o.ImageColor3 = Color3.new(math.min(1, g.Base.R * k), math.min(1, g.Base.G * k), math.min(1, g.Base.B * k))
				else o.Color = Color3.new(math.min(1, g.Base.R * k), math.min(1, g.Base.G * k), math.min(1, g.Base.B * k)) end
			else
				glowSet[o] = nil
			end
		end
		return any
	end
end

-- (2026-10-20, pH Indicator -- the Mythic wrap's FLOW) ONE shared, slow world field: every gas / liquid / membrane piece
-- a wrapped broadcast builds (T.Bands.Flow) is registered here and recoloured each frame from where it is now, so
-- neighbours share a colour and the scale (acid red -> amber -> green -> basic teal) travels through the whole body as
-- one front. A piece keeps its Default lightness role (core darker, edge lighter). FLOW_MODE (set by a handler while it
-- builds) swaps the world field for a time sweep (the Patient Zero mark). Gated: Default never registers anything.
local flowItems = setmetatable({}, { __mode = "k" })
local flowOn = false
local FLOW_ROLE = { GasCore = 0.62, GasShadow = 0.78, Gas = 0.92, GasLit = 1, GasEdge = 1.06, Liquid = 0.92, LiquidDeep = 0.6,
	Membrane = 0.96, Mottle = 0.45, LiquidSpec = -0.55, MembraneHi = -0.45, Virulence = 1 }
local flowLut = setmetatable({}, { __mode = "k" })
local function flowBuild(F)
	local L = flowLut[F]
	if L then return L end
	L = {}
	for ctx, st in pairs(F.Stops) do
		local lut = {}
		for i = 0, 48 do
			local u, j = i / 48, 1
			while j < #F.Pos - 1 and u > F.Pos[j + 1] do j += 1 end
			local c = st[j]:Lerp(st[j + 1], math.clamp((u - F.Pos[j]) / (F.Pos[j + 1] - F.Pos[j]), 0, 1))
			if nearShipped(c) then c = c:Lerp(Color3.new(0.5, 0.5, 0.5), 0.15) end
			lut[i] = c
		end
		L[ctx] = lut
	end
	flowLut[F] = L
	return L
end
local function flowClock(F)
	return calm() and (F.Hold or 0) * (F.Period or 14) or os.clock()
end
local function flowU(F, p, t)
	local w, P = F.Wave or 16, F.Period or 14
	local a = 0.5 + 0.4 * math.sin(TAU * ((p.X * 0.6 + p.Z * 0.8) / w + p.Y / (F.WaveY or 10) - t / P))
	return math.clamp(a + 0.1 * math.sin(TAU * ((p.Z * 0.86 - p.X * 0.5) / (w * 1.7) - t / (P * 1.6))), 0, 1)
end
-- (each piece's lightness role sets its place on the scale -- core acidic, edge basic -- and the shared wave drifts it)
local KEY_U = { GasCore = 0.02, GasShadow = 0.16, Gas = 0.36, GasLit = 0.62, GasEdge = 0.94, Mottle = 0.1, Liquid = 0.3, LiquidDeep = 0.15,
	LiquidSpec = 0.3, Membrane = 0.58, MembraneHi = 0.58, Virulence = 0.6 }
local function flowU2(F, key, p, t)
	local amp = (key == "Membrane" or key == "MembraneHi" or key:sub(1, 6) == "Liquid") and 0.4 or 0.3
	return math.clamp((KEY_U[key] or 0.5) + amp * (2 * flowU(F, p, t) - 1), 0, 1)
end
local function flowSeam(u)                                       -- (1 at the middle of a colour transition)
	local m = 0
	for _, q in ipairs({ 1 / 6, 0.5, 5 / 6 }) do m = math.max(m, math.exp(-((u - q) / 0.07) ^ 2)) end
	return m
end
local function flowCol(F, ctx, key, u)
	local lut = flowBuild(F)[ctx] or flowBuild(F).Lobe
	local c = lut[math.clamp(math.floor(u * 48 + 0.5), 0, 48)]
	local r = FLOW_ROLE[key] or 1
	if r >= 0 then c = Color3.new(math.min(1, c.R * r), math.min(1, c.G * r), math.min(1, c.B * r)) else c = c:Lerp(Color3.new(1, 1, 1), -r) end
	return c
end
local flowProf = { n = 0, sum = 0, max = 0, t = 0 }
local function flowStep(dt, now)
	local c0 = os.clock()
	local any, tick = false, (math.floor(c0 * 10) ~= flowProf.t)
	flowProf.t = math.floor(c0 * 10)
	for o, it in pairs(flowItems) do
		any = true
		local host = o:IsA("BasePart") and o or (o.Parent and o.Parent:IsA("BasePart") and o.Parent)
		if not o.Parent or not host then
			flowItems[o] = nil
		elseif o:IsA("ParticleEmitter") and not tick then
			-- (emitters at 10 Hz: one ColorSequence recolours every live particle)
		else
			local F, u = it.F
			if it.Mode then
				local M = it.Mode
				local k = math.clamp((now - M.T0) / math.max(0.1, M.Dur * 0.9), 0, 1)
				u = math.clamp(F.Sweep.U0 + (F.Sweep.U1 - F.Sweep.U0) * k * k * (3 - 2 * k) + (it.Off or 0), 0, 1)
			else
				u = flowU2(F, it.Key, host.Position, flowClock(F))
			end
			local col = flowCol(F, it.Ctx, it.Key, u)
			if not nearShipped(col) then
				if o:IsA("ParticleEmitter") then
					if it.Fizz then
						o.Color = ColorSequence.new(col:Lerp(Color3.new(1, 1, 1), 0.45))
						local src = it.Src
						local base = (src and src.Parent and src.Rate) or it.Rate or 0
						it.W, it.BaseNow, it.G = 0.15 + flowSeam(u), base, it.G or host.Parent
					else
						o.Color = ColorSequence.new(col)
					end
				elseif o:IsA("PointLight") then
					o.Color = col
				elseif glowSet[o] then
					glowSet[o].Base = col                              -- (a pulsing piece: the pulse breathes the flow colour)
				else
					o.Color = col
				end
			end
		end
	end
	if tick then                                                -- (the fizz: per effect, its total pinned at Share x the effect's own rate,
		local grp = {}                                             -- each emitter's part of it weighted toward the colour seams)
		for o, it in pairs(flowItems) do if it.W and it.G then local g = grp[it.G] or { 0, 0 } g[1] += it.W g[2] += 1 grp[it.G] = g end end
		for o, it in pairs(flowItems) do if it.W and it.G and o.Parent then local g = grp[it.G] o.Rate = it.BaseNow * it.Fizz * it.W / math.max(1e-3, g[1] / g[2]) end end
	end
	local d = os.clock() - c0
	flowProf.n += 1 flowProf.sum += d flowProf.max = math.max(flowProf.max, d)
	if RunService:IsStudio() and flowProf.n % 30 == 0 then
		workspace:SetAttribute("PHProf", string.format("%.3f avg / %.3f max ms over %d frames", flowProf.sum / flowProf.n * 1000, flowProf.max * 1000, flowProf.n))
	end
	if not any then flowOn = false return false end
	return true
end
function flowAdd(o, F, ctx, key, extra)
	local it = { F = F, Ctx = ctx, Key = key, Mode = FLOW_MODE }
	if FLOW_MODE then FLOW_MODE.N += 1 it.Off = (((FLOW_MODE.N - 1) % 9) / 8 - 0.5) * 0.22 end
	if extra then for k, v in pairs(extra) do it[k] = v end end
	flowItems[o] = it
	if not flowOn then flowOn = true updaters[flowItems] = flowStep end
	return it
end
local FLOW_CTX = { "Lobe", "Solid", "Neon" }
--- the palette name and context `color` was drawn with, when the wrap flows (a reverse lookup, at creation only)
function flowTag(o, color)
	local F = T.Bands and T.Bands.Flow
	if not F then return nil end
	for _, cx in ipairs(FLOW_CTX) do
		local tbl = (cx == "Lobe" and LOBE) or (cx == "Solid" and SOLID) or NEON
		for key in pairs(FLOW_ROLE) do
			local ok, v = pcall(function() return tbl[key] end)
			if ok and v == color then return flowAdd(o, F, cx, key) end
		end
	end
	return nil
end
--- a fizz emitter on `host` (pH Indicator's twinkle: bright, crisp motes where the scale crosses from one band into the next)
local function flowFizz(host, F, ctx, key, src, rate, share)
	local Fz = F.Fizz
	if not Fz or extraScale() <= 0 then return end
	local e = Instance.new("ParticleEmitter")
	e.Name = "PHFizz"
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.LightEmission, e.LightInfluence = 0.35, 0
	e.Size = nseq({ { 0, Fz.Size or 0.3 }, { 0.5, (Fz.Size or 0.3) * 0.7 }, { 1, 0 } })
	e.Transparency = nseq({ { 0, 0.1 }, { 0.7, 0.3 }, { 1, 1 } })
	e.Lifetime = NumberRange.new(0.25, 0.45)
	e.Speed = NumberRange.new(0.2, 0.6)
	e.Shape = Enum.ParticleEmitterShape.Sphere
	e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	e.ZOffset = 0.4
	e.Rate = 0
	e.Parent = host
	flowAdd(e, F, ctx, key, { Fizz = share * extraScale(), Src = src, Rate = rate })
	return e
end
--- (pH Indicator) the printed reference chart baked into the Patient Zero mark's shell: a band of seven printed swatches
--- (the scale, acid to basic), ink rules between them and small printed numbers above -- static print, no live value
local GLYPH = { ["0"] = "111101101101111", ["1"] = "010110010010111", ["2"] = "111001111100111", ["3"] = "111001111001111",
	["4"] = "101101111001001", ["5"] = "111100111001111", ["6"] = "111100111101111", ["7"] = "111001010010010",
	["8"] = "111101111101111", ["9"] = "111101111001111" }
local function chartPaint(S, d)
	local u = (math.atan2(d.Z, d.X) / TAU) % 1
	local v = math.acos(math.clamp(d.Y, -1, 1)) / math.pi
	local ink = S.Ink or Color3.fromRGB(70, 60, 50)
	if v > 0.455 and v < 0.565 then
		local cell = u * 7
		local i, fr = math.floor(cell), cell % 1
		if fr < 0.035 or fr > 0.965 or v < 0.462 or v > 0.558 then return ink, 1 end
		return S.Swatch[i + 1], 1
	end
	if v > 0.385 and v < 0.44 then                               -- (the printed numbers: 1 3 5 7 9 11 13)
		local cell = u * 7
		local i, fr = math.floor(cell), cell % 1
		local txt = tostring(1 + 2 * i)
		local gx = (fr - 0.5) * 7 + #txt * 2                      -- (glyph cells, 4 per digit with a gap)
		local gy = (v - 0.385) / 0.055 * 5
		local di, cx = math.floor(gx / 4), math.floor(gx % 4)
		local ch = txt:sub(di + 1, di + 1)
		local g = GLYPH[ch]
		if g and cx < 3 and gy >= 0 and gy < 5 and g:sub(math.floor(gy) * 3 + cx + 1, math.floor(gy) * 3 + cx + 1) == "1" then return ink, 1 end
	end
	return ink, 0
end

-- PIXEL POTION (2026-10-20; Toxin's Uncommon Element skin, PixelPotionKit): a caster who wears it has every Toxin piece
-- drawn as a voxel potion bottle, on the Default's own beats. Each hook hides the Default shape on this client
-- (LocalTransparencyModifier) and leaves its particle emitters and lights running: the particle count stays the Default's.
local potionKit = nil
local potionLook                                                 -- (Toxin's own colours: a skin has no palette; the liquid's shades,
do                                                               --  read once at load, outside any caster's wrap scope: the mesh bakes them)
	local look = { Liquid = SOLID.Liquid, LiquidDeep = SOLID.LiquidDeep, LiquidHi = SOLID.Membrane, Glint = SOLID.LiquidSpec }
	potionLook = function() return look end
end
local function potion()
	if potionKit == nil then
		local m = script.Parent:FindFirstChild("PixelPotionKit")
		local ok, k = pcall(function() return m and require(m) end)
		potionKit = (ok and type(k) == "table") and k or false
		if potionKit then potionKit.Look = potionLook() end    -- (before On() starts the bottle's mesh build)
	end
	return potionKit or nil
end
local function potionOn(character)
	local k = potion()
	return k ~= nil and typeof(character) == "Instance" and k.On(character) == true
end
local function bottle(kind, parent)
	return potion().New(kind, parent or fxFolder(), potionLook())
end
local function hide(a, b, c)
	for _, p in ipairs({ a, b, c }) do if typeof(p) == "Instance" and p:IsA("BasePart") then p.LocalTransparencyModifier = 1 end end
end
local NECK_FIRST = CFrame.Angles(-math.pi / 2, 0, 0)             -- (a bottle's up turned to a piece's -Z: neck first along its travel)

local function splat(pos, size, linger, onY, pp)
	if splatCount >= SPLAT_CAP then return end
	local y = onY or floorY(pos, 12)
	if not y then return end
	splatCount += 1
	local s = size or 1
	local p = ball(SOLID.LiquidDeep, 0.05, nil, { Reflectance = wet(0.18, "Liquid") })   -- (a flat splat catches the full sun: the deep entry displays as the liquid)
	local cf = CFrame.new(pos.X, y + 0.02, pos.Z) * CFrame.Angles(0, math.random() * TAU, 0)
	local sheen = (math.random() < 0.4) and ball(SOLID.LiquidSpec, 0.35, p) or nil
	local pb = pp and bottle("Compact") or nil                     -- (Pixel Potion: a bottle on its side)
	if pb then hide(p, sheen) end
	local t0 = fxNow()
	local life = linger or 2.5
	local aspect = 0.75 + math.random() * 0.25
	updaters[p] = function(_, now)
		local t = now - t0
		if t > life + 0.8 or not p.Parent then
			p:Destroy()
			if pb then potion().Drop(pb) end
			splatCount -= 1
			return false
		end
		-- spread with a small viscous rebound, hold, then soak in (flatter and paler)
		local k = math.min(1, t / 0.16)
		local spread = s * (easeOut(k) + 0.08 * math.sin(math.min(1, t / 0.4) * math.pi) * (1 - k * 0.5))
		local soak = math.clamp((t - life) / 0.8, 0, 1)
		local h = s * 0.14 * (1 - 0.7 * soak)
		p.Size = Vector3.new(spread, math.max(0.02, h), spread * aspect)
		p.CFrame = cf * CFrame.new(0, h * 0.35, 0)
		p.Transparency = 0.05 + 0.95 * soak
		if pb then
			potion().Place(pb, cf * CFrame.new(0, s * 0.42 * 4 / 15, 0) * CFrame.Angles(0, 0, math.pi / 2), s * 0.42)
			potion().Fade(pb, soak)
		end
		if sheen then
			sheen.Size = Vector3.new(spread * 0.3, math.max(0.01, h * 0.4), spread * aspect * 0.22)
			sheen.CFrame = cf * CFrame.new(spread * 0.12, h * 0.75, -spread * 0.1)
			sheen.Transparency = 0.35 + 0.65 * soak
		end
		return true
	end
end

--- A teardrop body (the round belly and its drawn tip), oriented along `dir` (the tip trails it).
local speckN = 0                                                -- (a speckled wrap: every third droplet is the accent)
local function teardrop(parent)
	local col = SOLID.Liquid
	if T.Bands and T.Bands.Speckle then speckN += 1 if speckN % 3 == 0 then col = SOLID[T.Bands.Speckle] end end
	local body = ball(col, 0.02, parent, { Reflectance = wet(0.2, "Liquid") })
	local tip = ball(col, 0.02, parent, { Reflectance = wet(0.2, "Liquid") })
	return body, tip
end

local function drawTeardrop(body, tip, pos, dir, size, stretch)
	local d = (dir and dir.Magnitude > 1e-3) and dir.Unit or Vector3.new(0, -1, 0)
	local cf = CFrame.lookAt(pos, pos + d)                -- -Z along the travel
	body.Size = Vector3.new(size, size, size * (1 + stretch * 0.4))
	body.CFrame = cf
	tip.Size = Vector3.new(size * 0.42, size * 0.42, size * (0.9 + stretch))
	tip.CFrame = cf * CFrame.new(0, 0, size * (0.45 + stretch * 0.35))
end

--- (2026-10-19, audit P5B-11) `f`, for a piece drawn LATER (from an updater): it re-enters the wrap (and Mine) of the
--- broadcast being drawn now (ToxinWrap.Capture / With), so a deferred burst, splat or drip keeps its cast's colours
--- instead of the Default olive the moment the handler returned. Outside a broadcast: `f` itself.
local wrapMod
local function scoped(f)
	if wrapMod == nil then
		local m = script.Parent:FindFirstChild("ToxinWrap")
		local ok, w = pcall(function() return m and require(m) end)
		wrapMod = (ok and type(w) == "table" and type(w.Capture) == "function" and type(w.With) == "function") and w or false
	end
	local sc = wrapMod and wrapMod.Capture()
	if not sc then return f end
	return function(...) return wrapMod.With(sc, f, ...) end
end
--- (2026-10-20) a handler's own view of `updaters`: every piece it registers runs in the wrap of the broadcast drawing it
local function scopedUpdaters()
	return setmetatable({}, { __index = updaters, __newindex = function(_, k, fn) updaters[k] = type(fn) == "function" and scoped(fn) or fn end })
end

-- TOXIN'S OWN-MODULE SKINS (2026-10-20): WITCH'S BREW (Epic: WitchsBrewKit + WitchsBrewFX), SCORPION (Rare:
-- ScorpionKit + ScorpionFX) and HYDRA (Mythic, 2026-10-21: HydraKit + HydraFX). One table, for the 200-local limit. BREW.on(character) is the FX module of the skin that
-- body wears (its kit built), else nil; every call into it goes through BREW.call (pcall, one warning per hook), so a
-- fault there leaves the Default drawing. Both share these hook sites (the "second skin shares the first's hooks"
-- pattern); a hook a skin does not define is simply skipped. BREW.Kit / BREW.FX stay Witch's Brew's (its palette).
local BREW = { Warned = {}, Skins = { { Kit = "WitchsBrewKit", FX = "WitchsBrewFX" }, { Kit = "ScorpionKit", FX = "ScorpionFX" },
	{ Kit = "HydraKit", FX = "HydraFX" } } }
function BREW.load(i)
	local sk = BREW.Skins[i]
	if sk.K == nil then
		local m = script.Parent:FindFirstChild(sk.Kit)
		local ok, k = pcall(function() return m and require(m) end)
		sk.K = (ok and type(k) == "table") and k or false
	end
	if sk.F == nil and sk.K then
		local m = script.Parent:FindFirstChild(sk.FX)
		local ok, f = pcall(function() return m and require(m) end)
		sk.F = (ok and type(f) == "table") and f or false
		if sk.F then
			local okI, err = pcall(sk.F.Init, { fxFolder = fxFolder, density = density, calm = calm, fxNow = fxNow,
				updaters = updaters, SMOKE = SMOKE,
				Look = { Brew = NEON.Virulence, Herb = NEON.Virulence, BrewSkin = SOLID.Liquid, Steam = LOBE.GasLit } }, sk.K)
			if not okI then
				warn("[ToxinFX] " .. sk.FX .. " did not start: " .. tostring(err))
				sk.F = false
			end
		end
	end
	if i == 1 then BREW.Kit, BREW.FX = sk.K, sk.F end
	return sk
end
function BREW.kit() return BREW.load(1).K or nil end
function BREW.fx() return BREW.load(1).F or nil end
function BREW.on(character)
	if typeof(character) ~= "Instance" then return nil end
	for i = 1, #BREW.Skins do
		local sk = BREW.load(i)
		if sk.K and sk.K.On(character) and sk.K.Built then return sk.F or nil end
	end
	return nil
end
function BREW.call(fx, name, ...)
	local fn = fx and fx[name]
	if not fn then return nil end
	local r = table.pack(pcall(fn, ...))
	if not r[1] then
		if not BREW.Warned[name] then
			BREW.Warned[name] = true
			warn("[ToxinFX] skin hook " .. name .. ": " .. tostring(r[2]))
		end
		return nil
	end
	return table.unpack(r, 2, r.n)
end
if RunService:IsClient() then                                    -- (each skin's worn-piece manager starts with the client)
	task.defer(function() for i = 1, #BREW.Skins do BREW.load(i) end end)
end

--- Liquid drops flung from `pos` (velocity spread `speed`) that land as splats.
local function drops(pos, n, speed, size, pp)
	if n > 1 then n = math.max(1, math.floor(n * density() + 0.5)) end   -- (2026-10-19, audit P5B-04)
	local land = scoped(splat)                                       -- (2026-10-19, audit P5B-11) in the cast's wrap
	for _ = 1, n do
		local pb = pp and bottle("Compact") or nil                 -- (Pixel Potion: the bottle alone -- a teardrop hosts nothing)
		local body, tip
		if not pb then body, tip = teardrop() end
		local v = Vector3.new(math.random() * 2 - 1, 0.5 + math.random() * 0.9, math.random() * 2 - 1).Unit * (speed or 9)
		local t0 = fxNow()
		local sz = (size or 0.28) * (0.8 + math.random() * 0.4)
		local fy = floorY(pos, 14)
		updaters[body or pb] = function(_, now)
			local t = now - t0
			local p = pos + v * t + Vector3.new(0, -0.5 * 35 * t * t, 0)
			local vel = v + Vector3.new(0, -35 * t, 0)
			if pb then
				potion().Place(pb, CFrame.lookAt(p, p + vel) * NECK_FIRST, sz * 1.6)
			else
				drawTeardrop(body, tip, p, vel, sz, math.min(1.2, vel.Magnitude * 0.04))
			end
			if (fy and p.Y <= fy + 0.05) or t > 1.6 then
				if pb then potion().Drop(pb) else body:Destroy() tip:Destroy() end
				land(p, sz * 3.2, 2.2 + math.random(), fy, pp)
				return false
			end
			return true
		end
	end
end

--- Residue stuck to a body (a raised liquid splat on `hostPart` at world `at`, facing out along `normal`) with viscous runs
--- crawling down it, each ending in a bead; it rides the body and soaks away after `life`.
local function residue(hostPart, at, normal, size, runs, life, pp)
	if not (hostPart and hostPart.Parent) then return end
	if pp then                                                    -- (Pixel Potion: a little bottle stuck where it burst)
		local pb = bottle("Compact")
		local rel = hostPart.CFrame:ToObjectSpace(CFrame.lookAt(at, at + normal))
		local t0, key = fxNow(), {}
		updaters[key] = function(_, now)
			local t = now - t0
			if t > (life or 2.6) or not hostPart.Parent then potion().Drop(pb) return false end
			potion().Place(pb, hostPart.CFrame * rel * NECK_FIRST, (size or 0.55) * 1.3)
			potion().Fade(pb, math.clamp((t - (life or 2.6) + 0.4) / 0.4, 0, 1))
			return true
		end
		return
	end
	local rel = hostPart.CFrame:ToObjectSpace(CFrame.lookAt(at, at + normal))
	local blob = ball(SOLID.LiquidDeep, 0.05, nil, { Reflectance = wet(0.2, "Liquid") })
	local list = {}
	for i = 1, (runs or 3) do
		list[i] = {
			Run = ball(SOLID.Liquid, 0.05, nil, { Reflectance = wet(0.2, "Liquid") }),
			Bead = ball(SOLID.Liquid, 0.02, nil, { Reflectance = wet(0.22, "Liquid") }),
			X = (i - (runs + 1) / 2) * size * 0.3 + (math.random() - 0.5) * 0.1,
			Len = size * (1.4 + math.random() * 1.6),
			Speed = 0.9 + math.random() * 0.8,
		}
	end
	local t0 = fxNow()
	life = life or 2.6
	updaters[blob] = function(_, now)
		local t = now - t0
		if t > life + 0.6 or not hostPart.Parent then
			blob:Destroy()
			for _, r in ipairs(list) do r.Run:Destroy() r.Bead:Destroy() end
			return false
		end
		local fade = math.clamp((t - life) / 0.6, 0, 1)
		local cf = hostPart.CFrame * rel                   -- -Z is out of the surface
		local k = math.min(1, t / 0.12)
		blob.Size = Vector3.new(size * easeOut(k), size * 0.85 * easeOut(k), size * 0.22)
		blob.CFrame = cf
		blob.Transparency = 0.05 + 0.95 * fade
		-- runs crawl straight down the world, lying on the surface
		local down = Vector3.new(0, -1, 0)
		local right = Vector3.new(cf.RightVector.X, 0, cf.RightVector.Z)
		right = right.Magnitude > 1e-3 and right.Unit or Vector3.xAxis
		for _, r in ipairs(list) do
			local len = math.min(r.Len, math.max(0, t - 0.1) * r.Speed * size)
			local top = cf * Vector3.new(r.X, -size * 0.2, -size * 0.05)
			local mid = top + down * (len / 2)
			r.Run.Size = Vector3.new(size * 0.14, math.max(0.02, len), size * 0.1)
			r.Run.CFrame = CFrame.fromMatrix(mid, right, Vector3.yAxis)
			r.Bead.Size = Vector3.new(size * 0.22, size * 0.26, size * 0.18)
			r.Bead.CFrame = CFrame.fromMatrix(top + down * len, right, Vector3.yAxis)
			r.Run.Transparency = 0.1 + 0.9 * fade
			r.Bead.Transparency = 0.05 + 0.95 * fade
		end
		return true
	end
end

----------------------------------------------------------------------------------------------------
-- GAS: the lobe, and the cumulus built from lobes
----------------------------------------------------------------------------------------------------
-- tier -> core colour, halo colour, core transparency
-- (the halo is always the lit murk: the v4 gas lifts its thinning rims toward GAS_LIT)
local TIER = {
	core = { "GasCore", "GasLit", 0.28 },
	base = { "GasShadow", "GasLit", 0.42 },
	mid = { "Gas", "GasLit", 0.46 },
	crown = { "GasLit", "GasLit", 0.52 },
	skirt = { "GasShadow", "GasShadow", 0.62 },
}
-- Plaster: a smooth matte material (SmoothPlastic's specular glint read as glossy jelly; Sand's mottle as melon rind)
local GAS_MATERIAL = Enum.Material.Plaster
local HALO_SCALE, HALO_ALPHA = 1.1, 0.86

local skinOf                                                     -- (the painted-sphere copies: defined with the bubble)
local function newLobe(parent, tier, emitRate, radius, band, pp)
	local t = TIER[tier] or TIER.mid
	local c1, c2 = t[1], t[2]
	if band then c1, c2 = band[1], band[2] end                 -- (a hard-banded wrap: this lobe's band, core + halo)
	local L = {
		Core = ball(LOBE[c1], 1, parent, { Material = GAS_MATERIAL }), Halo = ball(LOBE[c2], 1, parent, { Material = GAS_MATERIAL }),
		Alpha = t[3],
		Phase = math.random() * TAU, Tier = tier,
	}
	local ls = T.Bands and T.Bands.LobeSkin                       -- (an Epic wrap: the puff wears the bubble's painted rings)
	local lsLit = ls and ls.Texture and T.Bands.SelfLit and T.Bands.SelfLit[c1]
	if lsLit then                                                -- (a glowing puff: a plain Neon ball under a textured pattern shell)
		local ot = skinOf(ls, c1 .. "~over", LOBE[c1])
		if ot then
			local o = ot:Clone()
			o.Material, o.CastShadow, o.Transparency = Enum.Material.SmoothPlastic, false, 1
			o.Parent = L.Core.Parent
			L.Over, L.Rot, L.OverAlpha = o, CFrame.Angles(0, math.random() * TAU, 0), math.min(0.85, (L.Alpha or 0.4) * 1.8)
		end
	elseif ls then
		local tpl = skinOf(ls, c1, LOBE[c1])
		if tpl then
			local m = tpl:Clone()
			m.Material, m.Transparency, m.CastShadow = L.Core.Material, L.Core.Transparency, false
			m.Parent = L.Core.Parent
			L.Core:Destroy()
			L.Core, L.Rot = m, CFrame.Angles(0, math.random() * TAU, 0)
		end
	end
	local gl = T.Bands and T.Bands.Gloss                          -- (a glossy wrap: wet puffs; the band's rim a bright ForceField shell)
	if gl then
		L.Core.Material = Enum.Material[gl.Material]
		L.Core.Reflectance = (band and band[1] == T.Bands.Mottle) and 0 or gl.Reflectance   -- (black stays matte: a mirror reads sky-blue)
		if band and band.Rim then L.Halo.Material = Enum.Material.ForceField end
	end
	local lit = T.Bands and T.Bands.SelfLit and T.Bands.SelfLit[c1]   -- (an Epic wrap: this band glows from within)
	if lit then
		L.Core.Material, L.Core.Reflectance = Enum.Material.Neon, 0
		if T.Bands.Pulse then glowPulse(L.Core, T.Bands.Pulse) end
	end
	if emitRate and emitRate > 0 then
		local e = Instance.new("ParticleEmitter")
		e.Texture = SMOKE
		local pc = band and band[3] or c1                    -- (a banded wrap: the band's own smoke)
		e.Color = seq(PART[pc], PART[band and band[4] or pc])   -- (a gradient wrap: the smoke fades to the next band out)
		e.LightInfluence = lit and 0 or 1
		e.LightEmission = 0
		e.Size = nseq({ { 0, radius * 1.3, radius * 0.2 }, { 1, radius * 2.0, radius * 0.2 } })
		e.Transparency = nseq({ { 0, 1 }, { 0.25, 0.45 }, { 0.7, 0.6 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(2.2, 3.2)
		e.Speed = NumberRange.new(0.2, 0.5)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-10, 10)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
		e.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
		e.Acceleration = Vector3.new(0, (tier == "crown") and 0.25 or -0.1, 0)
		e.Drag = 0.8
		e.Rate = 0
		e.Parent = L.Core
		L.Emit, L.EmitRate = e, emitRate
	end
	local FL = T.Bands and T.Bands.Flow                           -- (pH Indicator: the flow, the fizz, the chart)
	if FL then
		local it = flowItems[L.Core]
		if it and L.Core.Material == Enum.Material.Neon then it.Ctx = "Neon" end
		local key = it and it.Key or c1
		if flowItems[L.Halo] then flowItems[L.Halo].Key = key end   -- (the halo follows its own puff's band, not one lit colour over all)
		if L.Emit then flowAdd(L.Emit, FL, "Particle", key) flowFizz(L.Core, FL, "Lobe", key, L.Emit, emitRate, FLOW_MODE and FL.Fizz.MarkShare or (FL.Fizz.Shares and L.Core.Parent and FL.Fizz.Shares[L.Core.Parent.Name]) or FL.Fizz.Share) end
		local ch = T.Bands.Chart
		if FLOW_MODE and ch then
			local ot = skinOf(ch, "chart~over", LOBE.Gas)
			if ot then
				local o = ot:Clone()
				o.Material, o.CastShadow, o.Transparency = Enum.Material.SmoothPlastic, false, 1
				o.Parent = L.Core.Parent
				L.Over, L.Rot, L.OverAlpha = o, CFrame.Angles(0, math.random() * TAU, 0), math.min(0.9, (L.Alpha or 0.5) * 1.8)
			end
		end
	end
	if pp then                                                    -- (Pixel Potion: a cloud's lobe is a blocky voxel gas chunk;
		L.Vox = potion().Gas(L.Core)                             --  "Big": Patient Zero's, larger than the lobe it replaces)
		L.VoxScale = (pp == "Big") and 1.35 or nil
		hide(L.Core, L.Halo, L.Over)
	end
	return L
end

--- (a hard-banded wrap, T.Bands) the { core, halo, smoke } colour names of a lobe `dn` of the way from the centre to the rim
local function bandOf(dn)
	for _, s in ipairs(T.Bands.Radial or {}) do if dn < s[1] then return { s[2], s[3], s[4], s[5], Body = s.Body, Rim = s.Rim } end end
end

local function drawLobe(L, cf, rx, ry, vis)
	rx, ry = math.max(0.02, rx), math.max(0.02, ry)
	L.Core.CFrame = L.Rot and cf * L.Rot or cf                   -- (a painted puff: its own yaw, so no two read alike)
	L.Core.Size = Vector3.new(2 * rx, 2 * ry, 2 * rx)
	L.Halo.CFrame = cf
	L.Halo.Size = Vector3.new(2 * rx * HALO_SCALE, 2 * ry * HALO_SCALE, 2 * rx * HALO_SCALE)
	L.Core.Transparency = 1 - (1 - L.Alpha) * vis
	L.Halo.Transparency = 1 - (1 - HALO_ALPHA) * vis
	if L.Vox then                                                 -- (axis-aligned, the lobe's own size, colour and see-through)
		local v = L.Vox
		v.CFrame, v.Size = CFrame.new(cf.Position), L.Core.Size * (L.VoxScale or 1)
		v.Color, v.Material, v.Transparency = L.Core.Color, L.Core.Material, L.Core.Transparency
	end
	if L.Eye then L.Eye.ImageTransparency = 1 - vis end
	if L.Over then L.Over.CFrame = L.Rot and cf * L.Rot or cf L.Over.Size = Vector3.new(2 * rx, 2 * ry, 2 * rx) * 1.01 L.Over.Transparency = 1 - L.OverAlpha * vis end
end

-- Layouts, in units of the cloud's radius (x, y up from the ground, z), each lobe: offset, radius, squash, tier, grow time.
-- CORROSIVE: the v4 order -- crown-left first, then back-right, base-right, crown-right, back-left, base-left, and the
-- big front-centre base lobe LAST.
local LAYOUT = {}
LAYOUT.Corrosive = {
	{ V = Vector3.new(0, 0.26, 0), R = 0.32, Sq = 0.8, Tier = "core", At = 0.02 },
	{ V = Vector3.new(-0.3, 0.62, -0.05), R = 0.34, Tier = "crown", At = 0.0, E = 3 },
	{ V = Vector3.new(0.36, 0.42, -0.34), R = 0.38, Tier = "mid", At = 0.045, E = 3 },
	{ V = Vector3.new(0.6, 0.18, 0.08), R = 0.34, Sq = 0.62, Tier = "base", At = 0.085, E = 2 },
	{ V = Vector3.new(0.22, 0.68, 0.06), R = 0.31, Tier = "crown", At = 0.13, E = 3 },
	{ V = Vector3.new(-0.46, 0.4, -0.3), R = 0.38, Tier = "mid", At = 0.17, E = 3 },
	{ V = Vector3.new(0.02, 0.2, -0.6), R = 0.36, Sq = 0.62, Tier = "base", At = 0.19, E = 2 },
	{ V = Vector3.new(-0.62, 0.18, 0.1), R = 0.34, Sq = 0.62, Tier = "base", At = 0.21, E = 2 },
	{ V = Vector3.new(-0.26, 0.4, 0.34), R = 0.34, Tier = "mid", At = 0.23, E = 2 },
	{ V = Vector3.new(0.3, 0.38, 0.36), R = 0.32, Tier = "mid", At = 0.24, E = 2 },
	{ V = Vector3.new(0, 0.2, 0.56), R = 0.4, Sq = 0.6, Tier = "base", At = 0.26, E = 3 },
	-- the pooling skirt: low, flat lobes at the rim
	{ V = Vector3.new(0.86, 0.06, -0.35), R = 0.24, Sq = 0.4, Tier = "skirt", At = 0.32 },
	{ V = Vector3.new(-0.84, 0.06, -0.4), R = 0.24, Sq = 0.4, Tier = "skirt", At = 0.34 },
	{ V = Vector3.new(0.7, 0.06, 0.62), R = 0.24, Sq = 0.4, Tier = "skirt", At = 0.36 },
	{ V = Vector3.new(-0.7, 0.06, 0.6), R = 0.24, Sq = 0.4, Tier = "skirt", At = 0.38 },
}
-- PATIENT ZERO's settled mass: wider, a ring of base lobes round a two-storey heart; it billows OUTWARD from the centre.
LAYOUT.Mass = {
	{ V = Vector3.new(0, 0.26, 0), R = 0.34, Sq = 0.8, Tier = "core", At = 0.0 },
	{ V = Vector3.new(0, 0.5, 0), R = 0.26, Tier = "crown", At = 0.1, E = 3 },
	{ V = Vector3.new(-0.26, 0.42, 0.12), R = 0.24, Tier = "crown", At = 0.16, E = 2 },
	{ V = Vector3.new(0.28, 0.4, -0.1), R = 0.24, Tier = "crown", At = 0.18, E = 2 },
}
for i = 1, 6 do
	local a = i / 6 * TAU + 0.3
	table.insert(LAYOUT.Mass, { V = Vector3.new(math.cos(a) * 0.46, 0.26, math.sin(a) * 0.46), R = 0.26, Tier = "mid",
		At = 0.22 + i * 0.03, E = 2 })
end
for i = 1, 9 do
	local a = i / 9 * TAU
	table.insert(LAYOUT.Mass, { V = Vector3.new(math.cos(a) * 0.78, 0.14, math.sin(a) * 0.78), R = 0.25, Sq = 0.6,
		Tier = "base", At = 0.4 + i * 0.03, E = (i % 2 == 0) and 2 or nil })
end
-- ACID RAIN's overhead cloud: FLAT-BOTTOMED (every bottom lobe's underside on one plane), dark below, lit on top.
LAYOUT.Rain = {}
for i = 1, 7 do
	local a = i / 7 * TAU
	table.insert(LAYOUT.Rain, { V = Vector3.new(math.cos(a) * 0.55, 0.0, math.sin(a) * 0.55), R = 0.38, Sq = 0.3,
		Tier = "base", At = 0.1 + i * 0.05, E = 2 })
end
table.insert(LAYOUT.Rain, { V = Vector3.new(0, 0.02, 0), R = 0.5, Sq = 0.4, Tier = "core", At = 0.0 })
for i = 1, 5 do
	local a = i / 5 * TAU + 0.5
	table.insert(LAYOUT.Rain, { V = Vector3.new(math.cos(a) * 0.32, 0.22, math.sin(a) * 0.32), R = 0.32, Tier = "mid",
		At = 0.25 + i * 0.05, E = 2 })
end
table.insert(LAYOUT.Rain, { V = Vector3.new(-0.1, 0.4, 0.05), R = 0.28, Tier = "crown", At = 0.5, E = 2 })
table.insert(LAYOUT.Rain, { V = Vector3.new(0.18, 0.36, -0.12), R = 0.26, Tier = "crown", At = 0.55 })
-- the small wet burst out of a torn sac
LAYOUT.Puff = {
	{ V = Vector3.new(0, 0, 0), R = 0.5, Tier = "mid", At = 0 },
	{ V = Vector3.new(0.6, 0.15, 0), R = 0.4, Tier = "crown", At = 0.02 },
	{ V = Vector3.new(-0.55, 0.1, 0.2), R = 0.42, Tier = "mid", At = 0.03 },
	{ V = Vector3.new(0.1, 0.3, 0.5), R = 0.38, Tier = "crown", At = 0.04 },
	{ V = Vector3.new(-0.1, -0.1, -0.55), R = 0.4, Tier = "base", At = 0.05 },
}

-- (a hard-banded wrap, T.Bands) the same lobes re-placed in concentric bands, each band stacked over the next out so
-- its inner part hides under the band above: black heart, narrow yellow ring, red body, narrow yellow lit edge. Same
-- lobes, order, timing and emitters (smoke at its Default size), the same outer reach; only where they sit, their size
-- and their band (s.B).
local function banded(src, f)
	local out = {}
	for i, s in ipairs(src) do local c = table.clone(s) c.R0 = s.R f(c) out[i] = c end
	return out
end
local function onRing(c, d)
	local h = Vector2.new(c.V.X, c.V.Z)
	h = h.Magnitude > 1e-3 and h.Unit * d or Vector2.zero
	c.V = Vector3.new(h.X, c.V.Y, h.Y)
end
local BANDED = {
	[LAYOUT.Corrosive] = banded(LAYOUT.Corrosive, function(c)
		if c.Tier == "core" then c.B, c.V, c.R = "K", Vector3.new(0, 0.42, 0), 0.3
		elseif c.Tier == "crown" then c.B, c.R = "K", 0.26 onRing(c, 0.12)
		elseif c.Tier == "mid" then c.B, c.R = "Yin", 0.26 onRing(c, 0.3)
		elseif c.Tier == "base" then c.B, c.R = "R", 0.5 onRing(c, 0.5)
		else c.B, c.R = "Yout", 0.42 onRing(c, 0.8) end
	end),
	[LAYOUT.Mass] = banded(LAYOUT.Mass, function(c)
		if c.Tier == "core" or c.Tier == "crown" then c.B = "K" onRing(c, 0.12)
		elseif c.Tier == "mid" then c.B, c.R = "Yin", 0.2 onRing(c, 0.44)
		else c.B = "R" end
	end),
}
-- the detonation wave's 40 lobes in four lanes, inner to outer: { band, lobes, centre and radius (x the front's swell),
-- height (x the swell, over the next lane out) }; and the mark's 9-lobe wreath in three: { band, ring x, size x, rise }
local WAVE_LANES = { { "K", 6, -1.5, 0.9, 0.7 }, { "Yin", 8, -1.0, 0.8, 0.45 }, { "R", 10, 0.1, 1.1, 0.22 }, { "Yout", 16, 0.9, 0.7, 0 } }
local MARK_LANES = { { "Yin", 0.62, 0.8, 0.35 }, { "R", 1.0, 1.0, 0 }, { "Yout", 1.35, 0.6, -0.3 } }

--- A cumulus of lobes. o: Center (the ground point under it, or its base point), R (radius, studs), Layout, GrowScale
--- (the layout's At times are multiplied by it), GrowTime (each lobe's own growth), From (world point the lobes swell
--- out of), Glow (brightness, 0 = none), GlowAt (0..1 up the cloud), Grounded (the contact patch and the skirt),
--- FlatBottom (the rain cloud's underside plane), Duration (then it fades), Fade.
local function newCumulus(o)
	local R = o.R
	local folder = Instance.new("Folder")
	folder.Name = o.Name or "ToxinGas"
	folder.Parent = fxFolder()
	local cf = CFrame.new(o.Center) * CFrame.Angles(0, o.Yaw or math.random() * TAU, 0)
	local self = { Folder = folder, CF = cf, R = R, Lobes = {}, T0 = fxNow(), Fade = o.Fade or 1.4,
		Breathe = o.Breathe or 0.05, FromLocal = o.From and cf:PointToObjectSpace(o.From) or nil }
	local dn = o.Dens or density()                                 -- (2026-10-19, audit P5B-04) the smoke and glow rates
	local B, rim = T.Bands, 1e-3                                  -- (a hard-banded wrap: concentric bands, rim = 1)
	local layout = B and B.Lanes and BANDED[o.Layout] or o.Layout
	local mot, blot, eyes = 0, 0, 0
	if B then for _, s in ipairs(layout) do rim = math.max(rim, Vector2.new(s.V.X, s.V.Z).Magnitude) end end
	for _, s in ipairs(layout) do
		local r = s.R * R
		local band = B and ((s.B and B[s.B]) or (s.Tier == "skirt" and B.Edge) or bandOf(Vector2.new(s.V.X, s.V.Z).Magnitude / rim)) or nil
		local L = newLobe(folder, s.Tier, s.E and (s.E * (o.EmitMul or 1) * dn) or nil, (s.R0 or s.R) * R, band, o.PP)   -- (smoke at its own size)
		local E = B and B.Eyes                                      -- (an Epic wrap: eye-spots scattered on its puffs)
		if E and eyes < (E.Max or 8) and (s.Tier == "mid" or s.Tier == "base" or s.Tier == "crown") then
			eyes += 1
			local h = Vector3.new((math.random() - 0.5) * 0.9, 0.25 + math.random() * 0.45, (math.random() - 0.5) * 0.9) * r   -- (on its upper face)
			L.Eye = eyeOn(L.Core, E, h, r * 0.8, E.Size or 1.4)
		end
		if band and band.Body and B.Mottle and L.Emit and s.Tier ~= "crown" then   -- (a mottled wrap: every other body lobe's smoke starts dark; not the crowns, whose smoke rises to the edge)
			mot += 1
			if mot % 2 == 1 then L.Emit.Color = seq(PART[B.Mottle], PART[B.Mottle], PART[band[4] or band[3]]) end   -- (dark half its life, ends lit)
			if B.Blotch and s.Tier == "mid" then blot += 1 if blot % 4 ~= 0 then L.Core.Color, L.Core.Reflectance = LOBE[B.Mottle], 0 end end
		end
		L.Off = s.V * R
		if o.FlatBottom then L.Off = Vector3.new(L.Off.X, L.Off.Y + r * (s.Sq or 1), L.Off.Z) end
		L.R, L.Sq = r, s.Sq or 1
		L.At = s.At * (o.GrowScale or 1)
		L.GrowTime = (o.GrowTime or 0.3) * (0.85 + math.random() * 0.3)
		table.insert(self.Lobes, L)
	end
	if o.FlatBottom then
		-- the underside: one dark flat plane the bottom lobes sit on (its rim hides inside them)
		local under = ball(LOBE.GasCore, 1, folder, { Material = GAS_MATERIAL })
		self.Under = under
	end
	if o.Grounded then
		local g = part({ Transparency = 1, Size = Vector3.new(R * 1.2, 0.2, R * 1.2) })
		g.CFrame = CFrame.new(o.Center + Vector3.new(0, 0.12, 0))
		g.Parent = folder
		self.Patch = flatEmitter(g, { Color = PART.GasCore, Size = R * 2.1, Alpha = 0.42, Rate = 0, Life = 2.4, LightInfluence = 0.25 })
		local sk = part({ Transparency = 1, Size = Vector3.new(R * 1.7, 0.2, R * 1.7) })
		sk.CFrame = CFrame.new(o.Center + Vector3.new(0, 0.2, 0))
		sk.Parent = folder
		self.Skirt = flatEmitter(sk, { Color = PART.GasShadow, Size = R * 0.9, Alpha = 0.5, Rate = 0, Life = 3.2 })
		self.PatchRate, self.SkirtRate = math.max(2, R * 0.25) * dn, math.max(3, R * 0.6)   -- (the skirt is the edge: full)
	end
	if (o.Glow or 0) > 0 then
		local gp = part({ Transparency = 1, Size = Vector3.new(R * 0.4, R * 0.3, R * 0.4) })
		gp.CFrame = cf * CFrame.new(0, R * (o.GlowAt or 0.28), 0)
		gp.Parent = folder
		self.Light = light(gp, R * (o.GlowRange or 0.6), 0)
		self.GlowFx = glowEmitter(gp, R * (o.GlowSize or 0.35), o.GlowAlpha or 0.84, R * 1.1, 0)
		self.GlowPart, self.GlowLevel = gp, o.Glow
		if B and B.Light then                                       -- (a wrap's own gas light and glow sprite: no hot core)
			self.Light.Color = GLOW[B.Light]
			self.GlowFx.Color = seq(GLOW[B.Glow], GLOW[B.Glow])
		end
		self.GlowRate = (o.GlowRate or 2.5) * dn
	end
	if B and B.Speckle then                                       -- (a speckled wrap: motes through the body, B.Share (Rare 8%) over Default's rate)
		local base = ((self.PatchRate or 0) + (self.GlowRate or 0)) / dn + (self.SkirtRate or 0)   -- (Default's rate, before dn)
		for _, s in ipairs(layout) do base += (s.E or 0) * (o.EmitMul or 1) end
		local sp = part({ Transparency = 1, Size = Vector3.new(R * 1.8, R * 0.8, R * 1.8) })
		sp.CFrame = cf * CFrame.new(0, R * 0.42, 0)
		sp.Parent = folder
		local e = Instance.new("ParticleEmitter")
		e.Texture = B.RingArt or B.MoteTex or "rbxasset://textures/particles/sparkles_main.dds"   -- (a crisp mote: the soft smoke blurs grey over cobalt)
		e.Color = B.RingArt and ColorSequence.new(Color3.new(1, 1, 1)) or seq(SOLID[B.Speckle], SOLID[B.Speckle])
		e.LightEmission, e.LightInfluence = B.MoteGlow or 0, 0     -- (unlit; not additive unless the wrap glows)
		e.Size = NumberSequence.new(math.max(0.45, R * (B.MoteSize or 0.11)))
		e.ZOffset = R * (B.MoteZ or 0.35)                          -- (drawn just in front of the puff it sits in)
		if B.RingRise then e.Acceleration = Vector3.new(0, B.RingRise, 0) end
		e.Transparency = B.Shimmer and nseq({ { 0, 1 }, { 0.1, 0.1 }, { 0.3, 0.5 }, { 0.5, 0.1 }, { 0.7, 0.5 }, { 0.85, 0.15 }, { 1, 1 } })
			or nseq({ { 0, 1 }, { 0.15, 0.05 }, { 0.8, 0.1 }, { 1, 1 } })   -- (an Epic wrap's motes shimmer)
		e.Lifetime = B.MoteLife and NumberRange.new(B.MoteLife, B.MoteLife * 1.15) or NumberRange.new(2.2, 3)
		e.Speed = NumberRange.new(0.1, 0.3)
		e.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
		e.Rate = 0
		e.Parent = sp
		local total = base * (B.Share or 0.08) * extraScale()
		local stain = (B.StainRings and self.Patch) and total * (B.StainFrac or 0.25) or 0   -- (ring marks on the ground stain)
		local shim = B.ShimmerColor and total * (B.ShimmerFrac or 0.3) or 0                -- (crisp shimmer motes)
		local reroute = 0
		if B.GlowReroute and self.GlowFx then reroute, self.GlowRate = self.GlowRate or 0, 0 end   -- (the dark glow sprite's share: rings, same count)
		self.Speck, self.SpeckRate = e, total - stain - shim + reroute * extraScale()
		if shim > 0 then
			local m = e:Clone()
			m.Texture = "rbxasset://textures/particles/sparkles_main.dds"
			m.Color = seq(SOLID[B.ShimmerColor], SOLID[B.ShimmerColor])
			m.Acceleration = Vector3.zero
			m.LightEmission, m.LightInfluence = B.ShimmerGlow or 1, 0
			m.Size = NumberSequence.new(math.max(0.7, R * 0.13))
			m.Lifetime = NumberRange.new(2, 2.6)
			m.Transparency = nseq({ { 0, 1 }, { 0.12, 0 }, { 0.25, 0.7 }, { 0.4, 0 }, { 0.55, 0.7 }, { 0.7, 0.05 }, { 0.85, 0.6 }, { 1, 1 } })
			m.Parent = sp
			self.Shim, self.ShimRate = m, shim
		end
		if B.Pulse then glowPulse(e, B.Pulse) end
		if stain > 0 then
			local se = flatEmitter(self.Patch.Parent, { Color = SOLID[B.Speckle], Size = R * 0.16, Alpha = 0.25, Rate = 0, Life = 2.6, LightInfluence = 0 })
			se.Texture, se.LightEmission = B.MoteTex or se.Texture, B.MoteGlow or 0
			self.Stain, self.StainRate = se, stain
		end
	end
	self.Duration = o.Duration
	return self
end

local function cumulusEnd(self, fast)
	if self.EndAt then return end
	self.EndAt = fxNow()
	if fast then self.Fade = 0.4 end
	for _, L in ipairs(self.Lobes) do
		if L.Emit then L.Emit.Rate = 0 end
	end
	if self.Patch then self.Patch.Rate = 0 self.Skirt.Rate = 0 end
	if self.GlowFx then self.GlowFx.Rate = 0 end
	if self.Speck then self.Speck.Rate = 0 end
	if self.Stain then self.Stain.Rate = 0 end
	if self.Shim then self.Shim.Rate = 0 end
	Debris:AddItem(self.Folder, self.Fade + 3.5)
end

--- One frame. Returns false once it has faded out.
local function cumulusStep(self, now)
	local t = now - self.T0
	if self.Duration and not self.EndAt and t >= self.Duration then cumulusEnd(self) end
	local fade = self.EndAt and math.clamp((now - self.EndAt) / self.Fade, 0, 1) or 0
	local spin = CFrame.Angles(0, t * 0.025, 0)
	local R = self.R
	local grown = 0
	for _, L in ipairs(self.Lobes) do
		local k = math.clamp((t - L.At) / L.GrowTime, 0, 1)
		if k <= 0 then
			L.Core.Transparency, L.Halo.Transparency = 1, 1
		else
			grown += 1
			local g = backOut(k)
			local pos = L.Off
			if self.FromLocal then pos = self.FromLocal:Lerp(L.Off, easeOut(k)) end
			local b = 1 + self.Breathe * math.sin(TAU * 0.5 * t + L.Phase)
			local drift = Vector3.new(math.sin(t * 0.31 + L.Phase), 0.6 * math.sin(t * 0.23 + L.Phase * 1.7),
				math.cos(t * 0.27 + L.Phase)) * (0.03 * R)
			local r = L.R * g * b * (1 - 0.12 * fade)
			local cfL = self.CF * spin * CFrame.new(pos + drift - Vector3.new(0, fade * 0.06 * R, 0))
			drawLobe(L, cfL, r, r * L.Sq, math.min(1, k * 2.2) * (1 - fade))
			if L.Emit and not L.EmitOn and k > 0.2 and not self.EndAt then
				L.Emit.Rate, L.EmitOn = L.EmitRate, true
			end
		end
	end
	if self.Under then
		local k = math.clamp(t / 0.5, 0, 1)
		self.Under.Size = Vector3.new(R * 1.5 * easeOut(k), R * 0.05, R * 1.5 * easeOut(k))
		self.Under.CFrame = self.CF * CFrame.new(0, R * 0.03, 0)
		self.Under.Transparency = 1 - 0.8 * math.min(1, k * 2) * (1 - fade)
	end
	if self.Patch and not self.EndAt and grown > 0 and self.Patch.Rate == 0 then
		self.Patch.Rate, self.Skirt.Rate = self.PatchRate, self.SkirtRate
		self.Patch:Emit(2)
		self.Skirt:Emit(3)
	end
	if self.Speck and not self.EndAt and grown > 0 and self.Speck.Rate == 0 then self.Speck.Rate = self.SpeckRate end
	if self.Stain and not self.EndAt and grown > 0 and self.Stain.Rate == 0 then self.Stain.Rate = self.StainRate end
	if self.Shim and not self.EndAt and grown > 0 and self.Shim.Rate == 0 then self.Shim.Rate = self.ShimRate end
	if self.Light then
		-- STEADY Virulence inside the churn: a gentle 1 Hz breathe, never accelerating; the caller may override
		local lvl = self.GlowOverride or (self.GlowLevel * (0.85 + 0.15 * math.sin(now * TAU)))
		local on = math.min(1, t / 0.4) * (1 - fade)
		self.Light.Brightness = lvl * on
		if not self.EndAt and self.GlowFx.Rate == 0 and t > 0.2 then self.GlowFx.Rate = self.GlowRate end
	end
	return fade < 1
end

--- A cumulus that runs itself (the updater loop), returned for its caller to end.
local function runCumulus(o)
	local c = newCumulus(o)
	updaters[c] = function(_, now)
		return cumulusStep(c, now)
	end
	return c
end

----------------------------------------------------------------------------------------------------
-- THREADS: thin curling strands (Beams chained through moving attachments)
----------------------------------------------------------------------------------------------------
local function terrainAttachment()
	local a = Instance.new("Attachment")
	a.Parent = workspace.Terrain
	return a
end

--- o: From(), To() -> Vector3 each frame; Strands (widths list); Duration; HeadTime (0..1 of Duration the head takes to
--- arrive); Arc (studs of lift at the middle); Wave (lateral curl amplitude); Colors; Alpha; OnArrive().
local function thread(o)
	local N = 12
	local strands = {}
	local widths = o.Strands or { 0.3, 0.22, 0.17 }
	-- (2026-10-19, audit P5B-04) thinned (Graphics Quality / an enemy's under Reduce Enemy VFX): two strands at most
	if #widths > 2 and density() < 0.75 then widths = { widths[1], widths[2] } end
	for si, width in ipairs(widths) do
		local atts = {}
		for i = 1, N do atts[i] = terrainAttachment() end
		local beams = {}
		for i = 1, N - 1 do
			local b = Instance.new("Beam")
			b.Attachment0, b.Attachment1 = atts[i], atts[i + 1]
			b.Texture = SMOKE
			b.TextureMode = Enum.TextureMode.Stretch
			b.TextureSpeed = 0.8
			b.Color = seq(table.unpack(o.Colors or { PART.GasShadow, PART.Gas }))
			b.LightInfluence = 1
			b.LightEmission = 0
			b.FaceCamera = true
			b.Segments = 8
			b.Width0 = width
			b.Width1 = width
			b.Transparency = NumberSequence.new(1)
			if o.Hide then b.Enabled = false end
			b.Parent = atts[i]
			beams[i] = b
		end
		strands[si] = { Atts = atts, Beams = beams, Width = width, Phase = si * 2.1 + math.random(), Split = 0.12 + si * 0.05 }
	end
	local t0 = fxNow()
	local hb = o.PP and bottle("Compact") or nil                  -- (Pixel Potion: a bottle rides the head)
	local dur = o.Duration or 0.75
	local arrived = false
	local key = {}
	updaters[key] = function(_, now)
		local t = (now - t0) / dur
		local a, b = o.From(), o.To()
		if t >= 1 or not (a and b) then
			for _, s in ipairs(strands) do
				for _, at in ipairs(s.Atts) do at:Destroy() end
			end
			if hb then potion().Drop(hb) end
			return false
		end
		local head = math.clamp(t / (o.HeadTime or 0.55), 0, 1)
		local tail = math.clamp((t - (o.TailStart or 0.4)) / (1 - (o.TailStart or 0.4)), 0, 1)
		if head >= 1 and not arrived then
			arrived = true
			if o.OnArrive then task.spawn(o.OnArrive) end
		end
		local d = b - a
		local len = d.Magnitude
		if len < 0.05 then return true end
		local fwd = d / len
		local side = fwd:Cross(Vector3.yAxis)
		if side.Magnitude < 1e-3 then side = Vector3.xAxis end
		side = side.Unit
		local up = side:Cross(fwd).Unit
		if hb then
			local hp = a + d * head + up * ((o.Arc or 1.2) * math.sin(math.pi * head))
			potion().Place(hb, CFrame.lookAt(hp, hp + fwd) * NECK_FIRST, 0.55)
			potion().Fade(hb, (head >= 1 and tail > 0.5) and 1 or 0)
		end
		local tt = now - t0
		for _, s in ipairs(strands) do
			for i = 1, N do
				local u = (i - 1) / (N - 1)
				-- the head leads (points past it wait on it), the tail follows (points behind it collapse onto it)
				local su = math.clamp(u, tail, math.max(tail, head))
				local wave = (o.Wave or 0.45) * math.sin(TAU * 1.6 * su + s.Phase + tt * 4.5) * math.sin(math.pi * su)
				local twist = s.Split * math.cos(TAU * 2.2 * su + tt * 4.5 + s.Phase)
				local lift = (o.Arc or 1.2) * math.sin(math.pi * su)
				s.Atts[i].WorldPosition = a + d * su + side * (wave + twist) + up * (lift + twist * 0.5)
			end
			for i, bm in ipairs(s.Beams) do
				local u0, u1 = (i - 1) / (N - 1), i / (N - 1)
				local alive = (u1 > tail and u0 < head)
				local alpha = o.Alpha or 0.5
				-- fray toward both ends, thin over the last of the path
				local e0 = alive and math.clamp(alpha + (1 - alpha) * (1 - math.min(u0 - tail, head - u0) * 3.5), alpha, 1) or 1
				local e1 = alive and math.clamp(alpha + (1 - alpha) * (1 - math.min(u1 - tail, head - u1) * 3.5), alpha, 1) or 1
				bm.Transparency = NumberSequence.new(e0, e1)
				local taper = 1 - 0.7 * math.clamp((u1 - 0.84) / 0.16, 0, 1)
				bm.Width0 = s.Width * (1 - 0.7 * math.clamp((u0 - 0.84) / 0.16, 0, 1))
				bm.Width1 = s.Width * taper
			end
		end
		return true
	end
end

----------------------------------------------------------------------------------------------------
-- M1: TOXIC BUBBLES
----------------------------------------------------------------------------------------------------
local bubbles = {}           -- [id] = sac

--- (a patterned wrap, T.Bands.Skin) the membrane's painted sphere: one EditableMesh copy per palette, cobalt with crisp
--- irregular black blotches, small yellow-green dots and a white-blue wet glint (face colours, so the edges are crisp);
--- nil until it is built (the plain ball stands in)
local skins = {}
local skinKeep = {}          -- the fixed-size copies the built skins' MeshParts show
function skinOf(S, key, baseColor)
	local bucket = skins[S]
	if not bucket then bucket = {} skins[S] = bucket end
	key = key or "_"
	local c = bucket[key]
	if c ~= nil then return c or nil end
	bucket[key] = false
	local over = key:sub(-5) == "~over"                          -- (an overlay: only the pattern, clear elsewhere, worn over a glowing ball)
	local tex = S.Texture and (over or not (T.Bands and T.Bands.SelfLit and T.Bands.SelfLit[key]))
	-- (2026-10-19, audits P5B-09 / P5B-10) the whole build runs in its own thread, under one pcall, a few rows a frame
	-- (it was ~100k EditableMesh calls inside the broadcast's handler, and an error there lost the cast); the colours are
	-- read NOW, while this broadcast's wrap stands in the palette. The finished mesh is copied into a FIXED-SIZE one and
	-- the resizable original let go (TerraWrap.makePart's rule: only ~8 resizable meshes may live on a client, and these
	-- used to hold theirs for the session). Until it is built -- or if it fails -- the plain ball stands in; a failed
	-- build may be tried again after a pause.
	local snap = {}
	for _, n in ipairs({ "GlintColor", "RingCentre", "RingInner", "RingColor", "RingEdge", "DotColor", "BlotchColor", "BaseColor" }) do
		if S[n] ~= nil then
			local okc, cc = pcall(function() return SOLID[S[n]] end)
			if okc then snap[S[n]] = cc end
		end
	end
	local base0 = baseColor or snap[S.BaseColor]
	task.spawn(function()
		local AS = game:GetService("AssetService")
		local em, texImg
		local okB, faces = pcall(function()
			em = AS:CreateEditableMesh()
			if not em then error("no EditableMesh", 0) end
			local kh = 0 if S.SeedPerKey then for i = 1, #key do kh += key:byte(i) * i end end   -- (each puff colour its own pattern)
			local rnd, blot, dots = Random.new(S.Seed + kh), {}, {}
			local function fib(i, n) local y = 1 - 2 * (i - 0.5) / n local r = math.sqrt(math.max(0, 1 - y * y)) local ph = i * 2.39996 + rnd:NextNumber() * 0.6
				return Vector3.new(math.cos(ph) * r, y, math.sin(ph) * r) end   -- (S.Spread: evenly over the sphere, jittered)
			for i = 1, S.Blotches do blot[i] = { rnd:NextUnitVector(), 0.3 + rnd:NextNumber() * 0.2, rnd:NextNumber() * 9 } end
			if S.Spread then for i = 1, #blot do blot[i][1] = fib(i, #blot) end end
			for i = 1, S.Dots do dots[i] = { rnd:NextUnitVector(), 0.07 + rnd:NextNumber() * 0.05 } end
			if S.DotRows then                                   -- (sucker rows: staggered pairs of dots tapering along arcs)
				dots = {}
				for a = 1, S.DotRows do
					local c = S.Spread and fib(a, S.DotRows) or rnd:NextUnitVector()
					local ax = c:Cross(rnd:NextUnitVector()).Unit local p0, p1 = c, ax:Cross(c)   -- (a row starts at c and walks a great circle)
					local n, th = math.floor(S.Dots / S.DotRows), S.Spread and -0.4 or rnd:NextNumber() * TAU
					for j = 0, n - 1 do
						local r = S.DotSize * (1 - 0.5 * j / math.max(1, n - 1))
						dots[#dots + 1] = { (p0 * math.cos(th) + p1 * math.sin(th) + ax * ((j % 2 == 0) and 1 or -1) * r * 1.05).Unit, r }
						th += r * 1.15
					end
				end
			end
			local Lg, cols = S.Light.Unit, {}
			local function col(name) cols[name] = cols[name] or em:AddColor(snap[name], 1) return cols[name] end
			local rings = {}
			for i = 1, S.Rings or 0 do rings[i] = { rnd:NextUnitVector(), (S.RingSize or 0.16) + rnd:NextNumber() * 0.08 } end
			local function paint(d)
				if d:Dot(Lg) > S.Glint then return col(S.GlintColor) end
				for _, q in ipairs(rings) do                           -- (a ring: its dark rosette, the ring, its deep edge)
					local a = math.acos(math.clamp(d:Dot(q[1]), -1, 1))
					if a < q[2] * 0.3 then return col(S.RingCentre)
					elseif a < q[2] * 0.62 then return col(S.RingInner or S.RingColor)
					elseif a < q[2] * 0.86 then return col(S.RingColor)
					elseif a < q[2] then return col(S.RingEdge) end
				end
				for _, q in ipairs(dots) do if d:Dot(q[1]) > math.cos(q[2]) then return col(S.DotColor) end end
				for _, b in ipairs(blot) do
					local wob = 1 + 0.3 * math.sin(5 * math.atan2(d.Z, d.X) + b[3]) * math.sin(4 * d.Y + b[3])   -- (an irregular edge)
					if math.acos(math.clamp(d:Dot(b[1]), -1, 1)) < b[2] * wob then return col(S.BlotchColor) end
				end
				return col(S.BaseColor)
			end
			local function sm(e0, e1, x) local t = math.clamp((x - e0) / (e1 - e0), 0, 1) return t * t * (3 - 2 * t) end
			--- (S.Smooth) a vertex's colour: a soft centre spot -> the bright inner ring -> the saturated ring -> the deep edge -> base
			-- (S.BlotchTint: a blotch is the puff's own colour darkened toward rust, so a self-lit puff gets no hot spot;
			-- S.DotMix: a sucker dot is blended from the puff's colour toward its DotColor)
			local bt = S.BlotchTint
			local blotC = (bt and base0) and Color3.new(base0.R * bt[1], base0.G * bt[2], base0.B * bt[3]) or snap[S.BlotchColor]
			local dotC = (S.DotMix and base0) and base0:Lerp(snap[S.DotColor], S.DotMix) or snap[S.DotColor]
			local function paintC(d)
				local base = base0
				for _, q in ipairs(rings) do
					local x = math.acos(math.clamp(d:Dot(q[1]), -1, 1)) / q[2]
					if x < 1.15 then
						local c = snap[S.RingCentre]:Lerp(snap[S.RingInner or S.RingColor], sm(0.2, 0.38, x))
						c = c:Lerp(snap[S.RingColor], sm(0.52, 0.68, x))
						c = c:Lerp(snap[S.RingEdge], sm(0.8, 0.92, x))
						return c:Lerp(base, sm(0.94, 1.12, x))
					end
				end
				for _, b in ipairs(blot) do                             -- (S.Smooth blotches: a soft, wobbly edge)
					local wob = 1 + 0.3 * math.sin(5 * math.atan2(d.Z, d.X) + b[3]) * math.sin(4 * d.Y + b[3])
					local x = math.acos(math.clamp(d:Dot(b[1]), -1, 1)) / (b[2] * wob)
					local e = S.EdgeSoft or 0.15 if x < 1 + e then base = blotC:Lerp(base, sm(1 - e, 1 + e, x)) break end   -- (S.EdgeSoft: a crisper edge)
				end
				for _, q in ipairs(dots) do                             -- (S.Smooth dots, over the blotches: soft round spots)
					local x = math.acos(math.clamp(d:Dot(q[1]), -1, 1)) / q[2]
					local e = S.EdgeSoft or 0.2 if x < 1 + e then local dc = S.DotCup and dotC:Lerp(base, S.DotCup * (1 - sm(0.4 - e, 0.4 + e, x))) or dotC return dc:Lerp(base, sm(1 - e, 1 + e, x)) end   -- (DotCup: a sucker's pinker cup inside its pale rim)
				end
				return base
			end
			if tex then                                       -- (S.Texture on a key that is not self-lit: the pattern painted into an image on a light UV sphere -- crisp spots at a fraction of the mesh budget; Neon ignores textures, so the glowing key stays vertex-painted)
				local TW, TH = S.TexSize and S.TexSize[1] or 512, S.TexSize and S.TexSize[2] or 256
				local buf = buffer.create(TW * TH * 4)
				for y = 0, TH - 1 do
					if y % 12 == 11 then task.wait() end
					local th = (y + 0.5) / TH * math.pi
					local st, ct = math.sin(th), math.cos(th)
					for x = 0, TW - 1 do
						local ph = (x + 0.5) / TW * TAU
						local dv = Vector3.new(st * math.cos(ph), ct, st * math.sin(ph))
						local c, ca = paintC(dv), nil
						if S.Chart then c, ca = chartPaint(S, dv) end
						local o = (y * TW + x) * 4
						buffer.writeu8(buf, o, math.clamp(math.floor(c.R * 255 + 0.5), 0, 255))
						buffer.writeu8(buf, o + 1, math.clamp(math.floor(c.G * 255 + 0.5), 0, 255))
						buffer.writeu8(buf, o + 2, math.clamp(math.floor(c.B * 255 + 0.5), 0, 255))
						buffer.writeu8(buf, o + 3, ca and math.floor(ca * 255) or over and math.clamp(math.floor(math.sqrt((c.R - base0.R) ^ 2 + (c.G - base0.G) ^ 2 + (c.B - base0.B) ^ 2) / 0.12 * 255), 0, 255) or 255)
					end
				end
				texImg = AS:CreateEditableImage({ Size = Vector2.new(TW, TH) })
				if not texImg then error("no EditableImage", 0) end
				texImg:WritePixelsBuffer(Vector2.zero, Vector2.new(TW, TH), buf)
				local R2, SG, U, nf = S.TexRes and S.TexRes[1] or 20, S.TexRes and S.TexRes[2] or 40, {}, 0
				for r = 0, R2 do
					U[r] = {}
					local th = r / R2 * math.pi
					for k = 0, SG do                              -- (the seam column doubled so the image wraps cleanly)
						local ph = k / SG * TAU
						local d = Vector3.new(math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph))
						U[r][k] = { em:AddVertex(d * 0.5), em:AddNormal(d), d, em:AddUV(Vector2.new(k / SG, r / R2)) }
					end
				end
				for r = 0, R2 - 1 do
					for k = 0, SG - 1 do
						local a, b, c2, e = U[r][k], U[r][k + 1], U[r + 1][k], U[r + 1][k + 1]
						for _, t in ipairs({ r > 0 and { a, c2, b } or false, r < R2 - 1 and { b, c2, e } or false }) do
							if t then
								local p1, p2, p3 = t[1][3], t[2][3], t[3][3]
								if (p2 - p1):Cross(p3 - p1):Dot(p1 + p2 + p3) < 0 then t[2], t[3] = t[3], t[2] end
								local f = em:AddTriangle(t[1][1], t[2][1], t[3][1])
								em:SetFaceNormals(f, { t[1][2], t[2][2], t[3][2] })
								em:SetFaceUVs(f, { t[1][4], t[2][4], t[3][4] })
								nf += 1
							end
						end
					end
				end
				return nf
			end
			local RINGS, SEGS, V = S.Res and S.Res[1] or 30, S.Res and S.Res[2] or 60, {}
			for r = 0, RINGS do
				if r % 8 == 7 then task.wait() end                       -- (a few rows a frame: no hitch on the first bubble)
				V[r] = {}
				local th = r / RINGS * math.pi
				for k = 0, SEGS - 1 do
					local ph = k / SEGS * TAU
					local d = Vector3.new(math.sin(th) * math.cos(ph), math.cos(th), math.sin(th) * math.sin(ph))
					V[r][k] = { em:AddVertex(d * 0.5), em:AddNormal(d), d, S.Smooth and em:AddColor(paintC(d), 1) or nil }
				end
			end
			local faces = 0
			for r = 0, RINGS - 1 do
				if r % 8 == 7 then task.wait() end
				for k = 0, SEGS - 1 do
					local a, b, c2, e = V[r][k], V[r][(k + 1) % SEGS], V[r + 1][k], V[r + 1][(k + 1) % SEGS]
					for _, t in ipairs({ r > 0 and { a, c2, b } or false, r < RINGS - 1 and { b, c2, e } or false }) do
						if t then
							local p1, p2, p3 = t[1][3], t[2][3], t[3][3]
							if (p2 - p1):Cross(p3 - p1):Dot(p1 + p2 + p3) < 0 then t[2], t[3] = t[3], t[2] end
							local f = em:AddTriangle(t[1][1], t[2][1], t[3][1])
							em:SetFaceNormals(f, { t[1][2], t[2][2], t[3][2] })
							if S.Smooth then em:SetFaceColors(f, { t[1][4], t[2][4], t[3][4] })
							else local cid = paint((p1 + p2 + p3).Unit) em:SetFaceColors(f, { cid, cid, cid }) end
							faces += 1
						end
					end
				end
			end
			return faces
		end)
		local fixed
		if okB then
			local okF, f = pcall(function() return AS:CreateEditableMeshAsync(Content.fromObject(em), { FixedSize = true }) end)
			if okF then fixed = f end
		end
		if em then pcall(function() em:Destroy() end) end
		local mp
		if fixed then
			local ok2, m = pcall(function() return AS:CreateMeshPartAsync(Content.fromObject(fixed)) end)
			if ok2 then mp = m end
		end
		if not mp then
			if fixed then pcall(function() fixed:Destroy() end) end
			if texImg then pcall(function() texImg:Destroy() end) end
			if not okB then warn("[ToxinFX] wrap skin build failed: " .. tostring(faces)) end
			task.delay(10, function() if bucket[key] == false then bucket[key] = nil end end)
			return
		end
		if texImg then mp.TextureContent = Content.fromObject(texImg) skinKeep[#skinKeep + 1] = texImg end
		skinKeep[#skinKeep + 1] = fixed                         -- (the MeshPart's content: kept for the session)
		mp.Anchored, mp.CanCollide, mp.CanQuery, mp.CanTouch, mp.CastShadow = true, false, false, false, false
		mp.Material, mp.Color, mp.Size = Enum.Material[S.Material or "SmoothPlastic"], Color3.new(1, 1, 1), Vector3.one
		mp:SetAttribute("SkinFaces", faces)
		bucket[key] = mp
	end)
	return nil
end

local function makeBubble(pos)
	local R = T.Bubble.Radius
	local model = Instance.new("Model")
	model.Name = "ToxinBubble"
	-- the murk first (drawn inside), then the thin body, then the dense lighter rim (ForceField shades by facing)
	local murk = ball(LOBE.GasCore, 0.12, model, { Material = GAS_MATERIAL })
	local body = ball(SOLID.Membrane, 0.32, model, { Reflectance = wet(0.03, "Membrane") })
	local skin = T.Bands and T.Bands.Skin and skinOf(T.Bands.Skin)
	if T.Bands and T.Bands.Chart then skinOf(T.Bands.Chart, "chart~over", LOBE.Gas) end   -- (pH Indicator: warm the mark's chart)
	if T.Bands and T.Bands.Flow and T.Bands.Flow.Fizz then flowFizz(body, T.Bands.Flow, "Solid", "Membrane", nil, T.Bands.Flow.Fizz.BubbleRate or 2.2, 1) end   -- (and its fizz)
	if T.Bands and T.Bands.LobeSkin then for _, n in ipairs({ "GasCore", "GasShadow", "Gas", "GasLit", "GasEdge" }) do skinOf(T.Bands.LobeSkin, (T.Bands.LobeSkin.Texture and T.Bands.SelfLit and T.Bands.SelfLit[n]) and n .. "~over" or n, LOBE[n]) end end
	if skin then                                                  -- (a patterned wrap: the painted membrane in the ball's place)
		local mb = skin:Clone()
		mb.Transparency, mb.Reflectance = body.Transparency, body.Reflectance
		if T.Bands.Pulse then mb.Color = Color3.new(0.8, 0.8, 0.8) glowPulse(mb, T.Bands.Pulse) end   -- (an Epic membrane: self-lit, breathing round 80%, room to swell)
		mb.Parent = model
		body:Destroy()
		body = mb
	end
	-- the rim: a thin, lighter shell -- the edge, where no murk sits behind it, reads lighter than the middle
	local rim = ball(SOLID.MembraneHi, 0.8, model, { Reflectance = wet(0.05, "MembraneHi") })
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = SMOKE
	smoke.Color = (T.Bands and T.Bands.Mottle) and seq(PART.GasCore, PART[T.Bands.Mottle], PART.GasShadow) or seq(PART.GasCore, PART.GasShadow)
	smoke.LightInfluence = 0.6
	smoke.Size = nseq({ { 0, R * 0.7 }, { 1, R * 0.9 } })
	smoke.Transparency = nseq({ { 0, 1 }, { 0.3, 0.55 }, { 0.7, 0.6 }, { 1, 1 } })
	smoke.Lifetime = NumberRange.new(0.8, 1.2)
	smoke.Speed = NumberRange.new(0)
	smoke.Rotation = NumberRange.new(0, 360)
	smoke.RotSpeed = NumberRange.new(-40, 40)
	smoke.Rate = 5 * density()                                    -- (2026-10-19, audit P5B-04)
	smoke.Parent = murk
	-- the heart: a small, dim, steady glow low in the murk
	local heart = part({ Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) })
	heart.Parent = model
	local glow = light(heart, R * 2.5, 0.12)
	local gfx = glowEmitter(heart, R * 0.4, 0.82, R * 1.05, 3 * density())
	model.Parent = fxFolder()
	return {
		Model = model, Murk = murk, Body = body, Rim = rim, Heart = heart, Light = glow, GlowFx = gfx, Smoke = smoke,
		Pos = pos, R = R, Seed = math.random() * 10,
	}
end

--- Draw the sac at `pos`: sx/sy/sz its squash (the caller keeps the volume), `look` its travel axis.
local function drawBubble(b, pos, look, sx, sy, sz, drain)
	local R = b.R
	local rot = (look and look.Magnitude > 1e-3) and (CFrame.lookAt(pos, pos + look) - pos) or CFrame.new()
	local cf = CFrame.new(pos) * rot
	local size = Vector3.new(sx, sy, sz) * (2 * R)
	b.Body.CFrame, b.Body.Size = cf, size
	b.Rim.CFrame, b.Rim.Size = cf, size * 1.04
	-- the murk pools low inside (and drains out as it deflates)
	local m = 1 - (drain or 0)
	b.Murk.CFrame = CFrame.new(pos - Vector3.new(0, R * sy * 0.2, 0)) * rot
	b.Murk.Size = Vector3.new(sx * 0.74, sy * 0.62, sz * 0.74) * (2 * R) * math.max(0.05, m)
	b.Heart.CFrame = CFrame.new(pos - Vector3.new(0, R * sy * 0.32, 0))
	if b.Pot then                                                  -- (Pixel Potion: the bottle in the sac's place)
		local box = Vector3.new(sx, sy, sz) * (2 * R)
		if look and look.Magnitude > 1e-3 then
			potion().Place(b.Pot, cf * NECK_FIRST, Vector3.new(box.X, box.Z, box.Y))
		else
			potion().Place(b.Pot, cf, box)
		end
		potion().Fade(b.Pot, math.clamp((b.Body.Transparency - 0.32) / 0.68, 0, 1))
	end
	if b.Brew then                                                 -- (Witch's Brew: the glob in the sac's place)
		BREW.call(b.Brew, "BubbleDraw", b, cf, Vector3.new(sx, sy, sz) * (2 * R),
			math.clamp((b.Body.Transparency - 0.32) / 0.68, 0, 1), look)
	end
end

local function killBubble(id)
	local b = bubbles[id]
	if not b then return nil end
	bubbles[id] = nil
	return b
end

local function contactShadow(b, floorAt)
	local g = part({ Transparency = 1, Size = Vector3.new(b.R, 0.1, b.R) })
	g.CFrame = CFrame.new(floorAt + Vector3.new(0, 0.08, 0))
	g.Parent = b.Model
	local e = flatEmitter(g, { Color = PART.GasCore, Size = b.R * 3.2, Alpha = 0.5, Rate = 1.5, Life = 1.6, LightInfluence = 0.2 })
	e:Emit(1)
	b.Shadow = e
end

H.ToxinBubble = function(d)
	if type(d.Id) ~= "number" or typeof(d.Origin) ~= "Vector3" or typeof(d.Vel) ~= "Vector3" then return end
	local b = makeBubble(d.Origin)
	if potionOn(d.Character) then                                  -- (Pixel Potion: the Id's later events reuse b.PP)
		b.PP, b.Pot = true, bottle("Full", b.Model)
		hide(b.Body, b.Rim, b.Murk)
	end
	b.Brew = not b.PP and BREW.on(d.Character) or nil              -- (Witch's Brew: a glob of brew spouted from the cauldron)
	if b.Brew then
		BREW.call(b.Brew, "BubbleStart", b, d.Character, d.Origin)
		if b.WB then
			hide(b.Body, b.Rim, b.Murk)
			if b.GlowFx then b.GlowFx.Enabled = false end
			if b.Smoke then b.Smoke.Enabled = false end
			if b.Light then b.Light.Enabled = false end
		else
			b.Brew = nil
		end
	end
	b.Mode = "Fly"
	bubbles[d.Id] = b
	local g = type(d.G) == "number" and d.G or T.Bubble.Gravity
	local t0 = fxNow() - math.max(0, serverNow() - (type(d.T0) == "number" and d.T0 or serverNow()))
	local caster = d.Character
	local last = d.Origin
	updaters[b] = function(_, now)
		if not b.Model.Parent then return false end
		local st = now + b.Seed
		if b.Mode == "Fly" then
			local t = math.max(0, now - t0)
			local p = d.Origin + d.Vel * t + Vector3.new(0, -0.5 * g * t * t, 0)
			-- this client's own world: a sac that reaches something waits there for the server's word
			local seg = p - last
			if seg.Magnitude > 1e-3 then
				local hit = workspace:Spherecast(last, b.R * 0.9, seg, worldParams(caster))
				if hit then
					p = hit.Position + hit.Normal * b.R * 0.8
					b.Mode = "Hold"
				end
			end
			last = p
			b.Pos = p
			local vel = d.Vel + Vector3.new(0, -g * t, 0)
			-- the canonical wobble: off-axis 1.7 / 2.1 Hz squash-stretch, stretched along travel, volume kept; the release
			-- tension (8% longer) for the first 1/15 s
			local a = 1 + 0.07 * math.sin(st * TAU * 1.7)
			local c = 1 + 0.06 * math.sin(st * TAU * 2.1 + 1.3)
			local stretch = 1.08 + (t < 0.067 and 0.08 * (1 - t / 0.067) or 0)
			local q = math.sqrt(stretch)
			drawBubble(b, p, vel, a / q, c / q, stretch / (a * c))
			if t > T.Bubble.FlightLife + 1 then
				b.Model:Destroy()
				if bubbles[d.Id] == b then bubbles[d.Id] = nil end
				return false
			end
			return true
		elseif b.Mode == "Hold" then
			b.HoldAt = b.HoldAt or now
			local a = 1 + 0.05 * math.sin(st * TAU * 3)
			drawBubble(b, b.Pos, nil, a, 1 / (a * a), a)
			if now - b.HoldAt > 6 then
				b.Model:Destroy()
				for id, o in pairs(bubbles) do
					if o == b then bubbles[id] = nil end
				end
				return false
			end
			return true
		elseif b.Mode == "Rest" then
			-- resting: a soft contact flatten and a damped jiggle on landing, then it sags and widens through its life, a
			-- small tremor, and a slow steady Virulence breathe (0.5 Hz)
			local tr = now - b.RestAt
			local k = math.clamp(tr / T.Bubble.RestLife, 0, 1)
			local land = math.exp(-tr / 0.18) * math.cos(tr * TAU * 4.5)
			local sy = (0.86 - 0.36 * k) * (1 - 0.2 * land)
			sy = sy * (1 + 0.035 * math.sin(now * TAU * 0.5)) * (1 + 0.01 * math.sin(st * TAU * 3.1))
			local sx = 1 / math.sqrt(sy)
			drawBubble(b, Vector3.new(b.Pos.X, b.Floor + b.R * sy, b.Pos.Z), nil, sx, sy, sx * 1.04)
			local breathe = 0.5 + 0.5 * math.sin(now * TAU * 0.5)
			b.Light.Brightness = 0.1 + 0.08 * breathe
			-- (2026-10-19, audit P5B-18) a rest the server never ended (a dropped Expire): gone 2 s past its life, as
			-- Fly and Hold have their own timeouts
			if tr > T.Bubble.RestLife + 2 then
				b.Model:Destroy()
				for id, o in pairs(bubbles) do
					if o == b then bubbles[id] = nil end
				end
				return false
			end
			return true
		end
		return false
	end
end

H.ToxinBubbleRest = function(d)
	local b = bubbles[d.Id]
	if not b or typeof(d.Position) ~= "Vector3" then return end
	b.Mode = "Rest"
	b.Pos = d.Position
	b.RestAt = fxNow()
	b.Floor = floorY(d.Position, 6) or (d.Position.Y - b.R * 0.8)
	contactShadow(b, Vector3.new(d.Position.X, b.Floor, d.Position.Z))
	if b.Brew then BREW.call(b.Brew, "BubbleRest", b) end          -- (Witch's Brew: it lands and bubbles)
end

--- The wet burst: the torn skin peels into floppy petals, the murk squirts out as a small gas puff, and the Virulence
--- swells once.
local function burst(pos, normal, withDrops, pp)
	local R = T.Bubble.Radius
	local n = (normal and normal.Magnitude > 1e-3) and normal.Unit or Vector3.yAxis
	for i = 1, 5 do
		local petal = ball(SOLID.Membrane, 0.35)
		local pb = pp and bottle("Compact") or nil                 -- (Pixel Potion: the petals are small bottles)
		if pb then hide(petal) end
		local ang = (i / 5) * TAU + math.random() * 0.6
		local side = n:Cross(Vector3.yAxis)
		if side.Magnitude < 1e-3 then side = Vector3.xAxis end
		side = side.Unit
		local up = side:Cross(n).Unit
		local out = (side * math.cos(ang) + up * math.sin(ang) + n * 0.5).Unit
		local t0 = fxNow()
		local base = CFrame.lookAt(pos, pos + out)
		local spin = (math.random() - 0.5) * 3
		updaters[petal] = function(_, now)
			local t = now - t0
			if t > 0.55 or not petal.Parent then petal:Destroy() if pb then potion().Drop(pb) end return false end
			-- the peel (tip first, recoiling), a damped 5 Hz flop, a droop under its own weight
			local peel = math.min(1.9, t * 9)
			local flop = 0.35 * math.sin(t * TAU * 5) * math.exp(-t / 0.2)
			local p = pos + out * (R * 0.7 + 2.6 * t) + Vector3.new(0, -0.5 * 22 * t * t, 0)
			petal.CFrame = CFrame.new(p) * (base - base.Position) * CFrame.Angles(peel + flop, spin * t, 0)
			local sh = 1 - t * 1.0
			petal.Size = Vector3.new(R * 1.05 * sh, R * 0.1, R * 0.8 * sh)
			petal.Transparency = 0.35 + math.max(0, t - 0.2) * 1.9
			if pb then
				potion().Place(pb, petal.CFrame, R * 0.6 * sh)
				potion().Fade(pb, math.max(0, t - 0.2) * 1.9)
			end
			return true
		end
	end
	local puff = runCumulus({ Name = "ToxinPuff", PP = pp, Center = pos, R = R * 1.3, Layout = LAYOUT.Puff, GrowScale = 1,
		GrowTime = 0.12, Duration = 0.2, Fade = 0.26, Breathe = 0 })
	if T.Bands and T.Bands.BurstRings then ringBurst(pos, T.Bands.BurstRings, 1.4) end   -- (an Epic wrap: a few of its rings)
	local fl = part({ Transparency = 1 })
	fl.CFrame = CFrame.new(pos)
	fl.Parent = fxFolder()
	local l = light(fl, 7, calm() and 0.5 or 1.3)                -- (2026-10-19, audit P5B-05) softer under Reduce Flashing
	TweenService:Create(l, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	Debris:AddItem(fl, 0.6)
	if withDrops then drops(pos, 4, 8, 0.24, pp) end
	return puff
end

H.ToxinBubblePop = function(d)
	local b = killBubble(d.Id)
	if b then b.Model:Destroy() end
	if typeof(d.Position) ~= "Vector3" then return end
	local target = typeof(d.Target) == "Instance" and d.Target or nil
	local torso = target and torsoOf(target)
	local normal = torso and (d.Position - torso.Position) or nil
	if not (b and b.WB and b.WB.OwnBurst) then burst(d.Position, normal, true, b and b.PP) end   -- (Scorpion: it cracks open instead)
	if b and b.Brew then BREW.call(b.Brew, "Splash", d.Position, normal, false, b) end
	-- the residue stuck where it burst, with three viscous runs down the body
	if torso and normal then
		local n = Vector3.new(normal.X, 0, normal.Z)
		n = n.Magnitude > 1e-3 and n.Unit or torso.CFrame.LookVector
		residue(torso, d.Position, n, 0.55, 3, 2.6, b and b.PP)
	end
end

H.ToxinBubbleConvert = function(d)
	local b = killBubble(d.Id)
	local pos = typeof(d.Position) == "Vector3" and d.Position or (b and b.Pos)
	if not pos then return end
	if b then
		-- the strain: the sac swells 12%, rounds up off its sag and quivers at 13 Hz for 0.1 s -- then the wet tear
		local t0 = fxNow()
		local from = b.Pos
		-- (2026-10-19, audit P5B-11) the tear is drawn 0.1 s on, in the converting cast's wrap
		local tear = scoped(function()
			if not (b.WB and b.WB.OwnBurst) then burst(pos, Vector3.yAxis, false, b.PP) end
			drops(pos, 3, 4, 0.22, b.PP)
			if b.Brew then BREW.call(b.Brew, "Splash", pos, Vector3.yAxis, true, b) end
		end)
		updaters[b] = function(_, now)
			local t = now - t0
			if t >= 0.1 then
				b.Model:Destroy()
				tear()
				return false
			end
			local s = 1 + 0.12 * (t / 0.1)
			local q = 1 + 0.045 * math.sin(now * TAU * 13) * (t / 0.1)
			drawBubble(b, from:Lerp(pos, 0.5), nil, s / math.sqrt(q), s * q, s / math.sqrt(q))
			b.Light.Brightness = 0.35 + 0.5 * (t / 0.1)
			return true
		end
	else
		burst(pos, Vector3.yAxis, false)
	end
end

H.ToxinBubbleExpire = function(d)
	local b = killBubble(d.Id)
	if not b then return end
	if b.Brew then BREW.call(b.Brew, "BubbleExpire", b) end       -- (Scorpion: the gland cracks open as its rest runs out)
	-- the deflate: the sac settles into a flat disc as the murk drains out of it, holds a moment, then soaks away
	local pos = b.Pos
	local fy = b.Floor or floorY(pos, 6) or (pos.Y - b.R)
	local t0 = fxNow()
	if b.Shadow then b.Shadow.Rate = 0 end
	b.GlowFx.Rate = 0
	b.Smoke.Rate = 0
	b.Body.Material = GAS_MATERIAL
	b.Body.Reflectance = 0
	b.Light.Enabled = false
	updaters[b] = function(_, now)
		local t = now - t0
		if t >= 1.5 or not b.Model.Parent then
			b.Model:Destroy()
			return false
		end
		local k = math.clamp(t / 0.7, 0, 1)
		local sy = 0.5 - 0.44 * easeOut(k)
		local sx = 1.05 + 0.55 * easeOut(k)
		drawBubble(b, Vector3.new(pos.X, fy + b.R * sy, pos.Z), nil, sx, sy, sx, k)
		local gone = math.clamp((t - 0.9) / 0.6, 0, 1)
		b.Body.Transparency = 0.32 + 0.68 * gone
		b.Rim.Transparency = 0.8 + 0.2 * math.max(k, gone)
		b.Murk.Transparency = (k > 0.95) and 1 or (0.18 + 0.82 * k)
		return true
	end
end

----------------------------------------------------------------------------------------------------
-- CLOUDS: Corrosive Cloud (and Patient Zero's lingering mass, below)
----------------------------------------------------------------------------------------------------
local clouds = {}            -- [id] = cumulus

H.ToxinCloud = function(d)
	if type(d.Id) ~= "number" or typeof(d.Center) ~= "Vector3" then return end
	local R = d.Radius or T.Cloud.Radius
	local form = d.FormTime or T.Cloud.FormTime
	clouds[d.Id] = runCumulus({
		Name = "ToxinCorrosiveCloud", PP = potionOn(d.Character), Center = d.Center, R = R, Layout = LAYOUT.Corrosive,
		-- the v4 engorgement: lobes swell one by one out of the conversion point (the last at 0.26 of 0.6 s)
		GrowScale = form / 0.6 * 1.6, GrowTime = 0.34, From = typeof(d.Point) == "Vector3" and d.Point or d.Center,
		Glow = 1.5, GlowAt = 0.14, GlowRange = 0.6, GlowSize = 0.46, GlowAlpha = 0.52,
		Grounded = true, Duration = form + (d.Duration or T.Cloud.Duration), Fade = 1.3,
	})
	local brew = BREW.on(d.Character)                              -- (Witch's Brew: the steam tether back to the cauldron)
	if brew and clouds[d.Id] then BREW.call(brew, "Cloud", clouds[d.Id], d.Character, d.Center, form, nil) end
end

H.ToxinCloudEnd = function(d)
	local c = clouds[d.Id]
	if c then
		clouds[d.Id] = nil
		cumulusEnd(c, true)
	end
end

----------------------------------------------------------------------------------------------------
-- PASSIVE: SYMBIOSIS -- the lifesteal thread (no Virulence) and the self-damage edge tell
----------------------------------------------------------------------------------------------------
H.ToxinLifesteal = function(d)
	local fromM, toM = d.From, d.To
	local from, to = torsoOf(fromM), torsoOf(toM)
	if not (from and to) then return end
	if T.Bands and T.Bands.RibbonRings then ringBurst(from.Position:Lerp(to.Position, 0.5) + Vector3.new(0, 1, 0), T.Bands.RibbonRings, 1.2) end
	-- three thin, translucent, fraying strands peel off the target and dissolve into the caster's chest
	local brew = BREW.on(toM)                                      -- (Witch's Brew: the siphon ribbon, target to cauldron)
	thread({
		From = function() return from.Parent and (from.Position + Vector3.new(0, 0.3, 0)) or nil end,
		To = function() return to.Parent and to.Position or nil end,
		Strands = { 0.26, 0.19, 0.14 }, Duration = 0.9, HeadTime = 0.5, TailStart = 0.45, Arc = 1.4, Wave = 0.55,
		Colors = { PART.GasCore, PART.GasCore }, Alpha = 0.0, PP = potionOn(toM), Hide = brew ~= nil,
	})
	if brew then BREW.call(brew, "Siphon", toM, from) end
end

local tellGui, tellCC, tellFrames = nil, nil, {}
local function buildTell()
	local pg = player and player:FindFirstChildOfClass("PlayerGui")
	if not pg then return false end
	tellGui = Instance.new("ScreenGui")
	tellGui.Name = "ToxinSelfTell"
	tellGui.IgnoreGuiInset = true
	tellGui.ResetOnSpawn = false
	tellGui.DisplayOrder = -5
	-- four edge bands, each fading inward: an unlit desaturated tint (#8A9488) creeping in from the frame edges
	local specs = {
		{ Vector2.new(0, 0), UDim2.fromScale(0.22, 1), 0 },
		{ Vector2.new(1, 0), UDim2.fromScale(0.22, 1), 180 },
		{ Vector2.new(0, 0), UDim2.fromScale(1, 0.26), 90 },
		{ Vector2.new(0, 1), UDim2.fromScale(1, 0.26), 270 },
	}
	for _, s in ipairs(specs) do
		local f = Instance.new("Frame")
		f.AnchorPoint = s[1]
		f.Position = UDim2.fromScale(s[1].X, s[1].Y)
		f.Size = s[2]
		f.BorderSizePixel = 0
		f.BackgroundColor3 = safe(C.Desat)
		f.BackgroundTransparency = 1
		local g = Instance.new("UIGradient")
		g.Rotation = s[3]
		g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
		g.Parent = f
		f.Parent = tellGui
		table.insert(tellFrames, f)
	end
	tellGui.Parent = pg
	tellCC = Instance.new("ColorCorrectionEffect")
	tellCC.Name = "ToxinSelfTell"
	tellCC.Parent = Lighting
	return true
end

local tellLevel = { Value = 0 }
H.ToxinSelfTick = function()
	if not (tellGui and tellGui.Parent) then
		tellFrames = {}
		if not buildTell() then return end
	end
	local t0 = fxNow()
	updaters[tellLevel] = function(_, now)
		local t = now - t0
		local v = (t < 0.1) and (t / 0.1) or math.max(0, 1 - (t - 0.1) / 0.6)
		for _, f in ipairs(tellFrames) do f.BackgroundTransparency = 1 - 0.85 * v end
		tellCC.Saturation = -0.3 * v
		return t < 0.75
	end
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE: PATIENT ZERO
----------------------------------------------------------------------------------------------------
local marks = setmetatable({}, { __mode = "k" })      -- [target model] = mark

local function endMark(target, burstIt)
	local m = marks[target]
	if not m then return end
	marks[target] = nil
	m.Ended = true
	m.EndAt = fxNow()
	m.Burst = burstIt
	if m.WB and m.WB.End then pcall(m.WB.End, burstIt) end         -- (Witch's Brew: erupt, or come home)
	for _, L in ipairs(m.Lobes) do
		if L.Emit then L.Emit.Rate = 0 end
	end
	m.GlowFx.Rate = 0
	Debris:AddItem(m.Folder, 2.5)
end

--- The telegraph law, in its visible gears: 0.6 Hz, then 1.8, then 4.6, then the solid fuse.
local function gearHz(k)
	if k < 0.36 then return T.PatientZero.PulseFrom end
	if k < 0.7 then return 1.8 end
	return T.PatientZero.PulseTo
end

H.ToxinPZMark = function(d)
	local target = d.Target
	if typeof(target) ~= "Instance" or not target.Parent then return end
	endMark(target)
	local P = T.PatientZero
	local telegraph = d.Telegraph or P.Telegraph
	local fuse = d.Fuse or P.Fuse
	local t0 = fxNow() - math.max(0, serverNow() - (type(d.T0) == "number" and d.T0 or serverNow()))
	local folder = Instance.new("Folder")
	folder.Name = "ToxinPZMark"
	folder.Parent = fxFolder()
	local m = { Folder = folder, Lobes = {}, Target = target }
	-- the mark: a liquid glob thrown from the caster's hand, then stuck on the target's chest
	local torso = torsoOf(target)
	local caster = d.Character
	local hand = caster and (caster:FindFirstChild("RightHand") or caster:FindFirstChild("Right Arm") or torsoOf(caster))
	local blob = ball(SOLID.LiquidDeep, 0.05, folder, { Reflectance = 0.2 })
	local pp = potionOn(caster)
	local blobPot = pp and potion().Gas(folder) or nil             -- (Pixel Potion: the thrown, stuck mark is a blocky voxel glob)
	if blobPot then hide(blob) end
	local brew = (not pp) and BREW.on(caster) or nil               -- (Witch's Brew: the cauldron flies over and locks on)
	m.WB = brew and BREW.call(brew, "Mark", caster, target, telegraph, fuse) or nil
	if m.WB then hide(blob) end
	local blobLight = light(blob, 5, 0.3)
	-- (2026-10-19, audit P5B-18) never nil: a rig with no hand and no torso yet throws from beside the target's pivot
	local throwFrom = hand and hand.Position or (torso and torso.Position + Vector3.new(0, 0, 4))
		or (target:GetPivot().Position + Vector3.new(0, 0, 4))
	local stuckRel = nil
	-- the wreath: murky lobes on a ring round the torso, growing through the telegraph
	local count = 9
	for i = 1, count do
		local q = T.Bands and T.Bands.Lanes and MARK_LANES[(i - 1) % 3 + 1]          -- (a hard-banded wrap: three concentric lanes)
		local mk = not q and T.Bands and T.Bands.Mark
		local L = newLobe(folder, (i % 3 == 0) and "base" or "mid", 2.5, 1.5,
			q and T.Bands[q[1]] or (mk and ((i % 4 == 2) and mk.Blotch or ((i % 3 == 0) and mk.Outer or mk.Body))) or nil, pp and "Big")
		L.A = i / count * TAU
		L.Y = (math.random() - 0.5) * 0.8
		L.Rs = 0.85 + math.random() * 0.3
		L.Alpha = 0.5
		if q then L.Rm, L.Sz, L.Y = q[2], q[3], q[4] end
		if mk and T.Bands.Eyes and i % 3 == 1 then L.Eye = eyeOn(L.Core, T.Bands.Eyes, Vector3.zero, 1.1, (T.Bands.Eyes.Size or 1.4) * 0.9) end
		if m.WB then hide(L.Core, L.Halo, L.Over) end              -- (Witch's Brew: the cauldron is the mark)
		table.insert(m.Lobes, L)
	end
	-- the heart of it: one soft core glow (the pulse) and its light
	local core = part({ Transparency = 1, Size = Vector3.new(0.4, 0.4, 0.4) })
	core.Parent = folder
	local glow = light(core, 4, 0.2)
	m.Dn = density()                                              -- (2026-10-19, audit P5B-04) the wreath's smoke and glow
	m.Calm = calm()                                               -- (2026-10-19, audit P5B-05) the pulse, below
	m.GlowFx = glowEmitter(core, 2.2, 0.7, 1.8, 6 * m.Dn)
	if T.Bands and T.Bands.Speckle then                           -- (a speckled wrap: motes round the target, 8% over the wreath's rate)
		local e = Instance.new("ParticleEmitter")
		local Bm = T.Bands
		e.Texture = Bm.RingArt or Bm.MoteTex or "rbxasset://textures/particles/sparkles_main.dds"
		e.Color = Bm.RingArt and ColorSequence.new(Color3.new(1, 1, 1)) or seq(SOLID[Bm.Speckle], SOLID[Bm.Speckle])
		e.LightEmission, e.LightInfluence = Bm.MoteGlow or 0, 0
		e.Size = NumberSequence.new(Bm.MarkRingSize or (Bm.MoteTex and 1.0 or 0.45))
		e.ZOffset = 0.5
		e.Transparency = Bm.Shimmer and nseq({ { 0, 1 }, { 0.1, 0.1 }, { 0.3, 0.5 }, { 0.5, 0.1 }, { 0.7, 0.5 }, { 0.85, 0.15 }, { 1, 1 } })
			or nseq({ { 0, 1 }, { 0.15, 0.05 }, { 0.8, 0.1 }, { 1, 1 } })
		e.Lifetime = NumberRange.new(1.6, 2.2)
		e.Speed = NumberRange.new(0.6, 1.1)
		e.Shape = Enum.ParticleEmitterShape.Sphere
		e.Rate = count * 2.5 * (Bm.Share or 0.08) * extraScale()
		e.Parent = core
		if Bm.Pulse then glowPulse(e, Bm.Pulse) end
	end
	m.GlowFx.Lifetime = NumberRange.new(0.35, 0.5)
	if m.WB and m.WB.HideCore then                                -- (Scorpion: the sigil under the target is the mark)
		m.GlowFx.Enabled, glow.Enabled, blobLight.Enabled = false, false, false
	end
	local phase, spin = 0, 0
	local nextDrip = fxNow() + 0.6
	local drip = scoped(drops)                                      -- (2026-10-19, audit P5B-11) in the mark's wrap
	marks[target] = m
	updaters[m] = function(dt, now)
		local r = torsoOf(target)
		if not (r and target.Parent) then
			if not m.Ended then endMark(target) end
			return false
		end
		local t = now - t0
		local tt = math.max(0, t)
		-- the glob: 0.3 s of flight, then stuck to the chest facing the thrower
		if not stuckRel then
			local k = math.clamp(tt / 0.3, 0, 1)
			local to = r.Position + r.CFrame.LookVector * (r.Size.Z * 0.5)
			local p = throwFrom:Lerp(to, k) + Vector3.new(0, math.sin(k * math.pi) * 1.2, 0)
			blob.Size = Vector3.new(0.5, 0.5, 0.7)
			blob.CFrame = CFrame.lookAt(p, to + (to - throwFrom).Unit)
			if blobPot then blobPot.CFrame, blobPot.Size = CFrame.new(blob.Position), Vector3.new(0.7, 0.7, 0.7) end
			if k >= 1 then
				local face = throwFrom - r.Position
				face = Vector3.new(face.X, 0, face.Z)
				face = face.Magnitude > 1e-3 and face.Unit or r.CFrame.LookVector
				local at = r.Position + face * (r.Size.Z * 0.5 + 0.05)
				stuckRel = r.CFrame:ToObjectSpace(CFrame.lookAt(at, at + face))
			end
		else
			blob.CFrame = r.CFrame * stuckRel
			blob.Size = Vector3.new(0.85, 1.0, 0.22)
			if blobPot then blobPot.CFrame, blobPot.Size = CFrame.new(blob.Position), Vector3.new(0.95, 0.95, 0.95) end
			if now >= nextDrip and not m.Ended then
				nextDrip = now + 0.55 + math.random() * 0.4
				local at = m.WB and m.WB.DripAt                      -- (Scorpion: from the sting's wound, once it has landed)
				local dp
				if at then
					local okD, p = pcall(at)
					dp = okD and typeof(p) == "Vector3" and p or nil
				else
					dp = blob.Position - Vector3.new(0, 0.4, 0)
				end
				if dp then drip(dp, 1, 1.5, 0.2) end
			end
		end
		local pulseEnd = telegraph - fuse
		local level
		if m.Ended then
			level = m.Burst and math.max(0, 1 - (now - m.EndAt) / 0.2) or 0
		elseif t < pulseEnd then
			local k = math.clamp(t / pulseEnd, 0, 1)
			if m.Calm then
				-- (2026-10-19, audit P5B-05) Reduce Flashing: never past 1 Hz and a shallow breathe (the 4.6 Hz gear sat in
				-- the photosensitive band); the countdown still reads in the wreath's growth and the solid fuse
				phase += TAU * math.min(gearHz(k), 1) * dt
				level = (0.7 + 0.15 * (0.5 - 0.5 * math.cos(phase))) * (0.4 + 0.6 * k)
			else
				phase += TAU * gearHz(k) * dt
				level = (0.5 - 0.5 * math.cos(phase)) * (0.4 + 0.6 * k)
			end
		else
			level = 1                                             -- the solid fuse
		end
		local k = math.clamp(tt / telegraph, 0, 1)
		local radius = P.AuraFrom + (P.AuraTo - P.AuraFrom) * easeOut(k)
		spin += dt * (0.4 + 0.8 * k)
		local c = r.Position
		local fade = m.Ended and math.clamp((now - m.EndAt) / (m.Burst and 0.3 or 0.6), 0, 1) or 0
		local swell = (m.Burst and 1.1 or 1)
		for i, L in ipairs(m.Lobes) do
			local grow = math.clamp((tt - 0.3 - i * 0.05) / 0.45, 0, 1)
			local a = spin + L.A
			local lr = (0.9 + 0.8 * k) * L.Rs * backOut(grow) * swell * (1 + 0.05 * math.sin(TAU * 0.5 * now + L.Phase)) * (L.Sz or 1)
			local rm = radius * (L.Rm or 1)
			local pos = c + Vector3.new(math.cos(a) * rm, L.Y + 0.25 * math.sin(a * 2 + spin), math.sin(a) * rm) * swell
			drawLobe(L, CFrame.new(pos), lr, lr * 0.9, math.min(1, grow * 2) * (1 - fade))
			if L.Emit and not L.EmitOn and grow > 0.3 and not m.Ended then L.Emit.Rate, L.EmitOn = 2.5 * (m.Dn or 1), true end
		end
		core.CFrame = CFrame.new(stuckRel and blob.Position or c)
		glow.Brightness = (0.15 + 1.6 * level) * (1 - fade * (m.Burst and 0 or 1))
		glow.Range = 4 + 2 * k
		blobLight.Brightness = 0.2 + 1.2 * level
		m.GlowFx.Transparency = nseq({ { 0, 1 }, { 0.3, 1 - 0.6 * level }, { 0.7, 1 - 0.6 * level }, { 1, 1 } })
		blob.Transparency = 0.05 + 0.95 * fade
		if blobPot then blobPot.Color, blobPot.Material, blobPot.Transparency = blob.Color, blob.Material, blob.Transparency end
		if m.Ended and fade >= 1 then
			folder:Destroy()
			return false
		end
		if t > telegraph + 2 then endMark(target) end
		return true
	end
end

H.ToxinPZCancel = function(d)
	if typeof(d.Target) == "Instance" then endMark(d.Target, false) end
end

do                                                              -- (pH Indicator: the mark sweeps the scale with its countdown)
	local baseMark = H.ToxinPZMark
	H.ToxinPZMark = function(d)
		local F = T.Bands and T.Bands.Flow
		if not (F and F.Sweep) then return baseMark(d) end
		local P = T.PatientZero
		FLOW_MODE = { T0 = fxNow() - math.max(0, serverNow() - (type(d.T0) == "number" and d.T0 or serverNow())), Dur = d.Telegraph or P.Telegraph, N = 0 }
		local ok, err = pcall(baseMark, d)
		FLOW_MODE = nil
		if not ok then error(err, 0) end
	end
end

H.ToxinPZBurst = function(d)
	if typeof(d.Target) == "Instance" then endMark(d.Target, true) end
	local pp = potionOn(d.Character)                              -- (Pixel Potion)
	local pos = typeof(d.Position) == "Vector3" and d.Position
	if not pos then return end
	local P = T.PatientZero
	local R = d.Radius or P.Radius
	local center = typeof(d.Center) == "Vector3" and d.Center or pos
	local skin = (not pp) and BREW.on(d.Character) or nil
	local own = skin and BREW.call(skin, "PZBurst", d.Character, d.Target, pos, center, R) == true
	if not own then                                               -- (a skin's PZBurst returning true keeps this flash out --
	-- the light-crack: 0.05 s held at the heart, then falling fast (a flash halo, no core)   Scorpion's; the wave stays)
	local flashP = part({ Transparency = 1, Size = Vector3.new(1, 1, 1) })
	flashP.CFrame = CFrame.new(pos)
	flashP.Parent = fxFolder()
	local soft = calm()                                           -- (2026-10-19, audit P5B-05) Reduce Flashing: a soft crack
	local fl = light(flashP, R * 1.5, soft and 1.4 or 4)
	local flare = glowEmitter(flashP, 7, 0.35, 3, 0)
	flare.Lifetime = NumberRange.new(0.25, 0.35)
	flare:Emit(soft and 2 or 4)
	task.delay(0.05, function()
		TweenService:Create(fl, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	end)
	Debris:AddItem(flashP, 1)
	end
	-- the pressure wave: a low ring of gas rolling out along the floor, radius 3 -> R as 1 - e^(-t/0.28)
	local folder = Instance.new("Folder")
	folder.Name = "ToxinPZWave"
	folder.Parent = fxFolder()
	local ring = {}
	local n = 40
	local lanes = T.Bands and T.Bands.Lanes and {} or nil                          -- (a hard-banded wrap: the lobes in concentric lanes)
	if lanes then for _, w in ipairs(WAVE_LANES) do for j = 1, w[2] do lanes[#lanes + 1] = { w, j / w[2] * TAU + #lanes * 0.37 } end end end
	for i = 1, n do
		-- two of every three lobes are the body of the front; every third rides ahead of it, thinner (the leading edge)
		local lead = (i % 3 == 0)
		local q = lanes and lanes[i]
		local wv = not q and T.Bands and T.Bands.Wave             -- (a patterned wrap's wave: deep body, lit rim, blotches)
		local L = newLobe(folder, lead and "mid" or ((i % 2 == 0) and "base" or "mid"), (i % 2 == 0) and 6 or nil, 2.4,
			q and T.Bands[q[1][1]] or (wv and (lead and wv.Lead or (i % 5 == 1 and wv.Blotch or wv.Body))) or nil, pp and "Big")
		L.A = i / n * TAU + (math.random() - 0.5) * 0.08
		L.Lead = lead
		L.Alpha = lead and 0.7 or 0.32
		if q then L.A, L.Lane, L.Lead, L.Alpha = q[2], q[1], false, 0.32 end
		ring[i] = L
	end
	local wdn = density()                                         -- (2026-10-19, audit P5B-04) the wave's smoke
	local t0 = fxNow()
	updaters[folder] = function(_, now)
		local t = now - t0
		local radius = 3 + (R * 1.3 - 3) * (1 - math.exp(-t / 0.28))
		local fade = math.clamp((t - 0.55) / 0.9, 0, 1)
		for _, L in ipairs(ring) do
			local lr = (1.6 + 1.0 * math.min(1, t / 0.5)) * (1 + 0.06 * math.sin(TAU * 1.2 * t + L.Phase))
			local rr = radius + (L.Lead and lr * 0.7 or 0)
			local sz = L.Lead and 0.7 or 1
			local p = center + Vector3.new(math.cos(L.A) * rr, lr * 0.4 * sz, math.sin(L.A) * rr)
			local w = L.Lane
			if w then
				rr = math.max(0.3, radius + lr * w[3])
				p = center + Vector3.new(math.cos(L.A) * rr, lr * (0.3 + w[5]), math.sin(L.A) * rr)
			end
			drawLobe(L, CFrame.new(p) * CFrame.Angles(0, -L.A, 0), w and lr * w[4] or lr * 1.3 * sz, w and lr * 0.38 * w[4] or lr * 0.5 * sz,
				math.min(1, t / 0.06) * (1 - fade))
			if L.Emit and not L.EmitOn then L.Emit.Rate, L.EmitOn = 6 * wdn, true end
			if L.Emit and t > 0.7 then L.Emit.Rate = 0 end
		end
		if fade >= 1 then
			Debris:AddItem(folder, 2.5)
			return false
		end
		return true
	end
	-- residue flung onto the floor round the burst
	drops(pos, 6, 10, 0.26)
	-- the billow: the big lingering mass, swelling lobe by lobe outward from the centre, then settling and breathing
	if type(d.CloudId) == "number" then
		clouds[d.CloudId] = runCumulus({
			Name = "ToxinPZMass", PP = pp and "Big", Center = center, R = R, Layout = LAYOUT.Mass, GrowScale = 1.4, GrowTime = 0.4,
			Glow = 1.3, GlowAt = 0.12, GlowRange = 0.55, GlowSize = 0.38, GlowAlpha = 0.58, Grounded = true,
			Duration = 0.25 + (d.Duration or P.CloudDuration), Fade = 1.5,
		})
		local brew = (not pp) and BREW.on(d.Character) or nil      -- (Witch's Brew: a simmering pot of bubbles)
		if brew then BREW.call(brew, "Bubblify", clouds[d.CloudId], { Big = true }) end
	end
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: ANTITOXIN VENT -- the gas mask
----------------------------------------------------------------------------------------------------
local masks = setmetatable({}, { __mode = "k" })      -- [character] = mask

--- The mask, laid out in HEAD space (forward is -Z; the face is the head's -Z side). Returns the model, the body (the
--- weld root), the seat (the body's place on the head) and the pieces that glow.
local function buildMask(head)
	local s, sx, sz = head.Size.Y, head.Size.X, head.Size.Z
	local face = -0.5 * sz
	local model = Instance.new("Model")
	model.Name = "ToxinVentMask"
	local seat = CFrame.new(0, -0.06 * s, face)
	local function piece(props, headOffset, sphere)
		local p = part(props)
		if sphere then
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = p
		end
		p.Anchored = false
		p.Massless = true
		p.CastShadow = true
		p:SetAttribute("Offset", seat:Inverse() * headOffset)
		p.Parent = model
		return p
	end
	-- the body: a rubber dome over the face, on a darker seam that outlines it
	local body = piece({ Color = SOLID.MaskBody, Size = Vector3.new(1.02 * sx, 0.95 * s, 0.6 * s) }, seat, true)
	local seam = piece({ Color = SOLID.MaskDark, Size = Vector3.new(1.08 * sx, 1.01 * s, 0.56 * s) }, seat * CFrame.new(0, 0, 0.035 * s), true)
	local fwdDown = CFrame.Angles(math.rad(-20), math.rad(90), 0)       -- a cylinder's axis (X) turned forward, tipped down
	-- the filter canister: a dark drum with pale ribs and a grille that flashes on each absorption
	local canCF = CFrame.new(0, -0.25 * s, face - 0.25 * s) * fwdDown
	local canister = piece({ Shape = Enum.PartType.Cylinder, Color = SOLID.MaskDark, Size = Vector3.new(0.22 * s, 0.34 * s, 0.34 * s) }, canCF)
	local ribs = {}
	for i, x in ipairs({ -0.05, 0.02, 0.09 }) do
		ribs[i] = piece({ Shape = Enum.PartType.Cylinder, Color = SOLID.MaskPale, Size = Vector3.new(0.03 * s, 0.37 * s, 0.37 * s) },
			canCF * CFrame.new(x * s, 0, 0))
	end
	local grille = piece({ Shape = Enum.PartType.Cylinder, Color = SOLID.MaskDark, Size = Vector3.new(0.025 * s, 0.27 * s, 0.27 * s) },
		canCF * CFrame.new(0.12 * s, 0, 0))
	-- the straps
	piece({ Color = SOLID.MaskDark, Size = Vector3.new(0.06 * s, 0.11 * s, 0.92 * sz) }, CFrame.new(0.51 * sx, 0.2 * s, 0.03 * sz))
	piece({ Color = SOLID.MaskDark, Size = Vector3.new(0.06 * s, 0.11 * s, 0.92 * sz) }, CFrame.new(-0.51 * sx, 0.2 * s, 0.03 * sz))
	piece({ Color = SOLID.MaskDark, Size = Vector3.new(1.06 * sx, 0.11 * s, 0.06 * s) }, CFrame.new(0, 0.2 * s, 0.52 * sz))
	-- the lenses: dark tinted glass (the one glass-like detail) inside thick rims that glow Virulence while active
	local rims, lenses = {}, {}
	for _, x in ipairs({ -0.21, 0.21 }) do
		local toward = CFrame.Angles(0, math.rad(90 + (x < 0 and 12 or -12)), math.rad(8))
		rims[#rims + 1] = piece({ Shape = Enum.PartType.Cylinder, Color = SOLID.MaskDark, Size = Vector3.new(0.06 * s, 0.4 * s, 0.4 * s) },
			CFrame.new(x * sx, 0.15 * s, face - 0.22 * s) * toward)
		local lens
		lens = piece({ Shape = Enum.PartType.Cylinder, Color = SOLID.Lens, Material = Enum.Material.Glass, Transparency = 0.25,
			Reflectance = 0.2, Size = Vector3.new(0.05 * s, 0.26 * s, 0.26 * s) },
			CFrame.new(x * sx, 0.15 * s, face - 0.255 * s) * toward)
		lens.CastShadow = false
		lenses[#lenses + 1] = lens
	end
	return model, body, seat, { Rims = rims, Ribs = ribs, Seam = seam, Grille = grille, Canister = canister, Body = body,
		Lenses = lenses }
end

-- the eight skin sites the cleanse tendrils peel off (R15 names first, R6 second), in the part's own space
local SITES = {
	{ { "UpperTorso", "Torso" }, Vector3.new(-0.3, 0.35, -0.5) },
	{ { "LowerTorso", "Torso" }, Vector3.new(0.3, -0.35, -0.5) },
	{ { "LeftUpperArm", "Left Arm" }, Vector3.new(-0.5, 0.3, 0) },
	{ { "RightUpperArm", "Right Arm" }, Vector3.new(0.5, 0.3, 0) },
	{ { "LeftLowerArm", "Left Arm" }, Vector3.new(-0.5, -0.3, 0) },
	{ { "RightLowerArm", "Right Arm" }, Vector3.new(0.5, -0.3, 0) },
	{ { "LeftUpperLeg", "Left Leg" }, Vector3.new(0, 0.2, -0.5) },
	{ { "RightUpperLeg", "Right Leg" }, Vector3.new(0, 0.2, -0.5) },
}

local function siteOf(character, i)
	local s = SITES[i]
	for _, name in ipairs(s[1]) do
		local p = character:FindFirstChild(name)
		if p and p:IsA("BasePart") then return p, s[2] * p.Size end
	end
	return nil
end

local function dropMask(character, fast)
	local updaters = scopedUpdaters()                           -- (2026-10-20: the Techniques' later pieces keep the caster's wrap)
	local m = masks[character]
	if not m then return end
	masks[character] = nil
	if m.Brew then                                                -- (Witch's Brew round 6: no mask -- the vapor fades, the flap shuts)
		m.Ended = true
		BREW.call(m.FX or BREW.FX, "VentEnd", character, fast)
		return
	end
	if m.WB and BREW.FX then BREW.call(BREW.FX, "VentOff", character, fast and 0.6 or 2.2) end   -- (Witch's Brew: back on the rim once it has fallen)
	m.Ended = true
	-- the lenses go dark, and the dead mask drops off, lands and rocks, then goes
	for _, rim in ipairs(m.G.Rims) do
		rim.Material = Enum.Material.SmoothPlastic
		rim.Color = SOLID.MaskDark
	end
	m.G.Seam.Material = Enum.Material.SmoothPlastic
	m.G.Seam.Color = SOLID.MaskDark
	m.G.Grille.Material = Enum.Material.SmoothPlastic
	m.G.Grille.Color = SOLID.MaskDark
	for _, rib in ipairs(m.G.Ribs) do
		rib.Material = Enum.Material.SmoothPlastic
		rib.Color = SOLID.MaskPale
	end
	m.Light.Enabled = false
	m.CanLight.Enabled = false
	if m.Weld then m.Weld:Destroy() end
	local pieces = {}
	for _, p in ipairs(m.Model:GetChildren()) do
		if p:IsA("BasePart") then
			p.Anchored = true
			p.LocalTransparencyModifier = 0
			pieces[#pieces + 1] = { P = p, Rel = m.G.Body.CFrame:ToObjectSpace(p.CFrame) }
		end
	end
	local start = m.G.Body.CFrame
	local fy = floorY(start.Position, 12, character) or (start.Position.Y - 4)
	local vx = (math.random() - 0.5) * 3
	local t0 = fxNow()
	updaters[m.Model] = function(_, now)
		local t = now - t0
		if t > (fast and 0.6 or 2.2) or not m.Model.Parent then
			m.Model:Destroy()
			return false
		end
		local y = start.Position.Y - 0.5 * 35 * t * t
		local landed = y <= fy + 0.3
		if landed then
			m.LandAt = m.LandAt or t
			y = fy + 0.3
		end
		local rock = landed and 0.25 * math.exp(-(t - m.LandAt) / 0.25) * math.sin((t - m.LandAt) * TAU * 3) or 0
		local tilt = math.min(1.4, t * 3.2)
		local cf = CFrame.new(start.Position.X + vx * math.min(t, m.LandAt or t), y, start.Position.Z)
			* (start - start.Position) * CFrame.Angles(-tilt + rock, 0, 0.3 * tilt)
		local gone = math.clamp((t - (fast and 0.2 or 1.4)) / 0.5, 0, 1)
		for _, x in ipairs(pieces) do
			x.P.CFrame = cf * x.Rel
			if x.P.Material ~= Enum.Material.Glass then x.P.Transparency = gone end
		end
		return true
	end
end

H.ToxinVent = function(d)
	local updaters = scopedUpdaters()                           -- (2026-10-20: the Techniques' later pieces keep the caster's wrap)
	local character = d.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	dropMask(character, true)
	local V = T.Vent
	local duration = d.Duration or V.Duration
	local pp = potionOn(character)
	local model, body, seat, G, brewFrom, brewVia
	local brew = (not pp) and BREW.on(character) or nil            -- (Witch's Brew: the herb satchel, from the cauldron's rim)
	if brew then                                                  -- (Witch's Brew, round 6: NOTHING worn -- the pouch on the cauldron
		local v = BREW.call(brew, "Vent", character, duration)       --  pops open, a herb goes into the brew, ward-vapor wisps round
		if v then                                                 --  the head; the cleanse threads draw into the brew. On a failure
			local m = { WB = true, Brew = true, FX = brew }           --  the Default mask below draws instead)
			masks[character] = m
			local n = (d.Cleansed or 0) > 0 and 8 or 3
			for i = 1, n do
				local site, off = siteOf(character, i)
				if site then
					local rel = CFrame.new(off)
					task.delay(0.42 + (i - 1) * 0.09, function()
						if m.Ended then return end
						thread({
							From = function() return site.Parent and (site.CFrame * rel).Position or nil end,
							To = v.Mouth,
							Strands = { 0.14, 0.1 }, Duration = 0.75, HeadTime = 0.62, TailStart = 0.55, Arc = 0.6, Wave = 0.3,
							Colors = v.Colors or { BREW.Kit.Look.BrewSkin, BREW.Kit.Look.Brew }, Alpha = 0.5,
							OnArrive = v.Arrive,
						})
					end)
				end
			end
			local t0 = fxNow()
			updaters[m] = function(_, now)
				if m.Ended then return false end
				if not (head.Parent and character.Parent) then dropMask(character, true) return false end
				if now - t0 >= duration then dropMask(character) return false end
				return true
			end
			return
		end
	end
	if brew then model, body, seat, G, brewFrom, brewVia = BREW.call(brew, "Mask", head, character) end
	local brewMask = model ~= nil
	if not model then model, body, seat, G = buildMask(head) end
	if pp then body, G = potion().Voxelize(model, body, G) end   -- (Pixel Potion: the Default's mask, voxelized)
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p ~= body then
			local off = p:GetAttribute("Offset")
			p.CFrame = body.CFrame * off
			local w = Instance.new("Weld")
			w.Part0 = body
			w.Part1 = p
			w.C0 = off
			w.Parent = p
		end
	end
	local weld = Instance.new("Weld")
	weld.Part0 = head
	weld.Part1 = body
	weld.C0 = brewFrom or (seat * CFrame.new(0, 1.4 * head.Size.Y, -0.4) * CFrame.Angles(math.rad(-50), 0, math.rad(12)))
	weld.Parent = body
	model.Parent = fxFolder()
	local glow = light(body, 1.2, 0)
	local canLight = light(G.Canister, 3, 0)
	if brewMask and BREW.Kit then glow.Color, canLight.Color = BREW.Kit.Look.Brew, BREW.Kit.Look.Brew end
	local m = { Model = model, Weld = weld, G = G, Light = glow, CanLight = canLight, WB = brewMask }
	masks[character] = m
	-- beat 1: it drops onto the face
	if brewFrom and brewVia then                                  -- (Witch's Brew: off the rim, up over the shoulder, tied on)
		local up = TweenService:Create(weld, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = brewVia })
		up.Completed:Connect(function()
			if weld.Parent then
				TweenService:Create(weld, TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { C0 = seat }):Play()
			end
		end)
		up:Play()
	else
		TweenService:Create(weld, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { C0 = seat }):Play()
	end
	-- the cleanse: eight thin murk tendrils peel off the skin and draw into the canister, each arrival a hot pulse
	local arrivals, pulse = 0, 0
	local n = (d.Cleansed or 0) > 0 and 8 or 3
	for i = 1, n do
		local site, off = siteOf(character, i)
		if site then
			local rel = CFrame.new(off)
			task.delay(0.42 + (i - 1) * 0.09, function()
				if m.Ended then return end
				thread({
					From = function() return site.Parent and (site.CFrame * rel).Position or nil end,
					To = function() return G.Grille.Parent and G.Grille.Position or nil end,   -- (Pixel Potion: no bottles on the mask's threads)
					Strands = { 0.14, 0.1 }, Duration = 0.75, HeadTime = 0.62, TailStart = 0.55, Arc = 0.6, Wave = 0.3,
					Colors = (brewMask and BREW.Kit) and { BREW.Kit.Look.BrewSkin, BREW.Kit.Look.Brew } or { PART.GasCore, PART.GasShadow },
					Alpha = 0.5,
					OnArrive = function()
						arrivals += 1
						pulse = 1
					end,
				})
			end)
		end
	end
	local t0 = fxNow()
	local soft = calm()
	updaters[m] = function(dt, now)
		if m.Ended then return false end
		if not (head.Parent and character.Parent) then dropMask(character, true) return false end
		local t = now - t0
		-- the lenses step up with each arrival, then settle into ONE steady 1 Hz glow (0.25 <-> 0.45), never accelerating
		local level = 0
		if t >= V.AssembleTime then
			if t < 2.0 then
				level = 0.22 + 0.23 * math.min(1, arrivals / math.max(1, n))
			else
				level = 0.35 + 0.1 * math.sin((t - 2.0) * TAU)
			end
		end
		pulse = math.max(0, pulse - dt / 0.14)
		if soft then pulse = math.min(pulse, 0.5) end               -- (2026-10-19, audit P5B-05) the grille flash, halved
		local k = math.clamp(level / 0.45, 0, 1)
		local vir = NEON.Virulence
		for _, rim in ipairs(G.Rims) do
			rim.Material = (k > 0.05) and Enum.Material.Neon or Enum.Material.SmoothPlastic
			rim.Color = SOLID.MaskDark:Lerp(vir, k * 0.8)
		end
		for _, lens in ipairs(G.Lenses) do lens.Color = SOLID.Lens:Lerp(vir, k * 0.3) end
		for _, rib in ipairs(G.Ribs) do
			rib.Material = (k > 0.05) and Enum.Material.Neon or Enum.Material.SmoothPlastic
			rib.Color = SOLID.MaskPale:Lerp(vir, k * 0.7)
		end
		-- the grille flashes hot only on an absorption
		G.Grille.Material = (pulse > 0.05) and Enum.Material.Neon or Enum.Material.SmoothPlastic
		G.Grille.Color = SOLID.MaskDark:Lerp(vir, pulse)
		glow.Brightness = level * 0.35
		canLight.Brightness = pulse * 1.6
		-- the wearer's own first-person camera sits inside it: hidden for them alone
		local cam = workspace.CurrentCamera
		local near = player ~= nil and character == player.Character and cam ~= nil
			and (cam.CFrame.Position - head.Position).Magnitude < 2
		for _, p in ipairs(model:GetChildren()) do
			if p:IsA("BasePart") then p.LocalTransparencyModifier = near and 1 or 0 end
		end
		if t >= duration then dropMask(character) return false end
		return true
	end
end

H.ToxinVentEnd = function(d)
	if d.Character then dropMask(d.Character, true) end
end

----------------------------------------------------------------------------------------------------
-- TECHNIQUE: ACID RAIN
----------------------------------------------------------------------------------------------------
H.ToxinAcidRain = function(d)
	local updaters = scopedUpdaters()                           -- (2026-10-20: the Techniques' later pieces keep the caster's wrap)
	local center = typeof(d.Center) == "Vector3" and d.Center
	if not center then return end
	local A = T.AcidRain
	local R = d.Radius or A.Radius
	local height = d.Height or A.Height
	local gather = d.Gather or A.GatherTime
	local rainTime = d.RainTime or A.RainTime
	local t0 = fxNow() - math.max(0, serverNow() - (d.T0 or serverNow()))
	-- the hold: a wisp of gas curls up off the caster's raised hand
	local caster = d.Character
	local pp = potionOn(caster)                                   -- (Pixel Potion)
	local brew = (not pp) and BREW.on(caster) or nil              -- (Witch's Brew: the cauldron boils over and flings bubbles)
	local rainHook = brew and BREW.call(brew, "AcidRain", caster, center, height, R, gather, rainTime, t0) or nil
	local brewRain = rainHook == true                             -- (true: the whole rain is the skin's -- no cloud overhead)
	local ownDrops = brewRain or rainHook == "drops"              -- ("drops", Scorpion: its spines fall from the cloud)
	local hand = caster and (caster:FindFirstChild("RightHand") or caster:FindFirstChild("Right Arm"))
	if hand and not ownDrops then
		runCumulus({ Name = "ToxinRainHold", PP = pp, Center = hand.Position + Vector3.new(0, 1.2, 0), R = 0.9, Layout = LAYOUT.Puff,
			GrowScale = 2, GrowTime = 0.25, Duration = 0.5, Fade = 0.4 })
	end
	-- the overhead mass: flat-bottomed, dark below, gathering lobe by lobe
	local cloud = newCumulus({ Name = "ToxinAcidRainCloud", PP = pp, Center = center + Vector3.new(0, height, 0), R = R * 1.05,
		Layout = LAYOUT.Rain, GrowScale = gather / 0.6, GrowTime = 0.4, FlatBottom = true, Fade = 1.6, EmitMul = 1.2 })
	-- its Virulence rolls in patches on the underside: two roaming soft glows and one diffuse light
	local patches = {}
	for i = 1, 2 do
		local gp = part({ Transparency = 1, Size = Vector3.new(R * 0.5, 0.4, R * 0.5) })
		gp.Parent = cloud.Folder
		patches[i] = { P = gp, Fx = glowEmitter(gp, R * 0.5, 0.72, 1.2, 0), A = i * math.pi, Rr = R * (0.2 + 0.2 * i) }
		patches[i].Fx.Lifetime = NumberRange.new(1.2, 1.8)
	end
	local lp = part({ Transparency = 1 })
	lp.Parent = cloud.Folder
	local glow = light(lp, R * 1.2, 0)
	local globs = {}
	local spawnAcc = 0
	local dn = density()                                          -- (2026-10-19, audit P5B-04) the globs and patch glows
	local rainCalm = calm()                                       -- (2026-10-19, audit P5B-05)
	local key = {}
	updaters[key] = function(dt, now)
		local t = now - t0
		local k = math.clamp(t / gather, 0, 1)
		local raining = t >= gather * 0.8 and t < gather + rainTime
		local over = t >= gather + rainTime or not cloud.Folder.Parent
		if over and not cloud.EndAt then cumulusEnd(cloud) end        -- the rain stops; the cloud gutters
		local alive = cumulusStep(cloud, now)
		local lvl = over and 0 or k * (0.55 + (rainCalm and 0 or 0.2 * math.sin(now * TAU * 1.2)))   -- (P5B-05: steady when calm)
		glow.Brightness = brewRain and 0 or (lvl * (cloud.EndAt and 0 or 1))
		if brewRain then                                         -- (Witch's Brew: no cloud overhead -- it times the rain unseen)
			for _, x in ipairs(cloud.Folder:GetDescendants()) do
				if x:IsA("BasePart") then x.LocalTransparencyModifier = 1
				elseif x:IsA("ParticleEmitter") then x.Enabled = false end
			end
		end
		local base = cloud.CF.Position
		for i, pa in ipairs(patches) do
			pa.A += dt * (0.35 + 0.15 * i)
			pa.P.CFrame = CFrame.new(base + Vector3.new(math.cos(pa.A) * pa.Rr, -0.3, math.sin(pa.A) * pa.Rr))
			pa.Fx.Rate = (not brewRain and not over and k > 0.3) and 2.2 * dn or 0
		end
		lp.CFrame = CFrame.new(base + Vector3.new(0, -1, 0))
		if raining and not ownDrops then
			spawnAcc += dt * 38 * dn
			while spawnAcc >= 1 do
				spawnAcc -= 1
				local a, rr = math.random() * TAU, math.sqrt(math.random()) * R
				local x, z = center.X + math.cos(a) * rr, center.Z + math.sin(a) * rr
				local top = Vector3.new(x, base.Y - 0.2, z)
				local body, tip = teardrop()
				local px = pp and potion().RainDrop(body) or nil  -- (Pixel Potion: a cubical pixel drop in the teardrop's own colour)
				if px then
					px.Color, px.Transparency = body.Color, body.Transparency
				elseif brew then                                 -- (Witch's Brew: a glowing drop of brew)
					px = BREW.call(brew, "RainDrop", body)
				end
				if px then hide(body, tip) end
				local sz = 0.34 + math.random() * 0.2
				globs[#globs + 1] = { Px = px, PxSize = (px and not pp) and Vector3.new(sz * 0.55, sz * 0.95, sz * 0.55) or nil,
					Body = body, Tip = tip, X = x, Z = z, Y = top.Y, Floor = floorY(top, height + 6) or center.Y,
					V = 6 + math.random() * 4, S = sz }
			end
		end
		for i = #globs, 1, -1 do
			local g = globs[i]
			g.V += 34 * dt
			g.Y -= g.V * dt
			if g.Y <= g.Floor + 0.1 then
				g.Body:Destroy()
				g.Tip:Destroy()
				table.remove(globs, i)
				if math.random() < 0.45 then splat(Vector3.new(g.X, g.Floor, g.Z), g.S * 3.2, 1.8 + math.random() * 1.2, g.Floor, pp) end
			else
				-- a teardrop falls tip-up, stretching with its speed
				if g.Px then                                    -- (a cube: a pixel of rain)
					g.Px.CFrame, g.Px.Size = CFrame.new(g.X, g.Y, g.Z), g.PxSize or (Vector3.new(g.S, g.S, g.S) * 0.8)
				else
					drawTeardrop(g.Body, g.Tip, Vector3.new(g.X, g.Y, g.Z), Vector3.new(0, -1, 0), g.S, math.min(0.8, g.V * 0.02))
				end
			end
		end
		if over and #globs == 0 and (not alive or not cloud.Folder.Parent) then
			cloud.Folder:Destroy()
			return false
		end
		return true
	end
end

-- CORRODED: a translucent wet glaze creeping down each body caught, an olive lip at its lower edge, and a thin Virulence
-- rim line under the lip that pulses faster as the stacks near the cap (none at one stack)
local glazes = setmetatable({}, { __mode = "k" })     -- [model] = glaze

local function glazeTargets(model)
	local list = {}
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" and p.Transparency < 0.9 then list[#list + 1] = p end
	end
	return list
end

local function watchGlaze(model)
	local updaters = scopedUpdaters()                           -- (2026-10-20: the Techniques' later pieces keep the caster's wrap)
	if glazes[model] or not model.Parent then return end
	local folder = Instance.new("Folder")
	folder.Name = "ToxinCorroded"
	folder.Parent = fxFolder()
	local g = { Folder = folder, Parts = {}, Cover = 0, Phase = 0, NextDrip = fxNow() + 0.5, Calm = calm() }
	for _, p in ipairs(glazeTargets(model)) do
		g.Parts[#g.Parts + 1] = {
			Host = p,
			Shell = part({ Color = SOLID.Liquid, Transparency = 1, Reflectance = 0, Parent = folder }),
			Lip = part({ Color = SOLID.LiquidDeep, Transparency = 1, Reflectance = 0.2, Parent = folder }),
			Rim = part({ Color = NEON.Virulence, Material = Enum.Material.Neon, Transparency = 1, Parent = folder }),
		}
	end
	glazes[model] = g
	updaters[g] = function(dt, now)
		local untilT = model.Parent and model:GetAttribute("ToxinVulnUntil")
		local stacks = model.Parent and model:GetAttribute("ToxinVuln") or 0
		local live = untilT and serverNow() <= untilT and stacks > 0
		local max = T.AcidRain.VulnMaxStacks
		local target = live and math.clamp(stacks / max, 0, 1) or 0
		-- the sheen advances (creeping down) toward the stacks' share of the body; it withdraws when it lapses
		g.Cover += (target - g.Cover) * math.min(1, dt * (live and 2.2 or 3.5))
		if not live and g.Cover < 0.02 then
			folder:Destroy()
			glazes[model] = nil
			return false
		end
		local top, bottom = -math.huge, math.huge
		for _, x in ipairs(g.Parts) do
			local h = x.Host
			if h.Parent then
				top = math.max(top, h.Position.Y + h.Size.Y / 2)
				bottom = math.min(bottom, h.Position.Y - h.Size.Y / 2)
			end
		end
		local threshold = top - g.Cover * (top - bottom)
		local f = 0.8 * (1.55 ^ math.max(0, stacks - 1))
		if g.Calm then f = math.min(f, 0.8) end                     -- (2026-10-19, audit P5B-05) never faster than 0.8 Hz
		g.Phase += TAU * f * dt
		local rim = (live and stacks >= 2) and (0.5 - 0.5 * math.cos(g.Phase)) * (0.35 + 0.65 * target) or 0
		local lipParts = {}
		for _, x in ipairs(g.Parts) do
			local h = x.Host
			local sz = h.Size
			local pt, pb = h.Position.Y + sz.Y / 2, h.Position.Y - sz.Y / 2
			local frac = h.Parent and math.clamp((pt - threshold) / math.max(0.01, pt - pb), 0, 1) or 0
			if frac < 0.02 then
				x.Shell.Transparency, x.Lip.Transparency, x.Rim.Transparency = 1, 1, 1
			else
				local sh = frac * sz.Y
				x.Shell.Size = Vector3.new(sz.X + 0.06, sh + 0.03, sz.Z + 0.06)
				x.Shell.CFrame = h.CFrame * CFrame.new(0, sz.Y / 2 - sh / 2 + 0.025, 0)
				x.Shell.Transparency = 0.7
				if frac < 0.98 then
					x.Lip.Size = Vector3.new(sz.X + 0.1, 0.06, sz.Z + 0.1)
					x.Lip.CFrame = h.CFrame * CFrame.new(0, sz.Y / 2 - sh, 0)
					x.Lip.Transparency = 0.35
					x.Rim.Size = Vector3.new(sz.X + 0.12, 0.018, sz.Z + 0.12)
					x.Rim.CFrame = h.CFrame * CFrame.new(0, sz.Y / 2 - sh - 0.035, 0)
					x.Rim.Transparency = 1 - rim
					lipParts[#lipParts + 1] = x
				else
					x.Lip.Transparency, x.Rim.Transparency = 1, 1
				end
			end
		end
		-- drips gather at the lip and fall
		if live and now >= g.NextDrip and #lipParts > 0 then
			g.NextDrip = now + 0.5 + math.random() * 0.5
			local x = lipParts[math.random(1, #lipParts)]
			local at = x.Lip.CFrame * Vector3.new((math.random() - 0.5) * x.Lip.Size.X, -0.05, -x.Lip.Size.Z / 2)
			drops(at, 1, 0.6, 0.18)
		end
		return true
	end
end

H.ToxinAcidTick = function(d)
	if type(d.Hit) ~= "table" then return end
	local skin = (not potionOn(d.Character)) and BREW.on(d.Character) or nil
	for _, model in ipairs(d.Hit) do
		if typeof(model) == "Instance" and model:IsA("Model") then
			if not (skin and BREW.call(skin, "Corrode", model) == true) then watchGlaze(model) end   -- (Scorpion: chitin cracks)
		end
	end
end

return ToxinFX

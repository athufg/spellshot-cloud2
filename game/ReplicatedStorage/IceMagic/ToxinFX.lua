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
local function ball(color, transparency, parent, props)
	local p = part(props)
	p.Color = safe(color)
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
	if T.Bands.Pulse then glowPulse(l, T.Bands.Pulse) end
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

local function splat(pos, size, linger, onY)
	if splatCount >= SPLAT_CAP then return end
	local y = onY or floorY(pos, 12)
	if not y then return end
	splatCount += 1
	local s = size or 1
	local p = ball(SOLID.LiquidDeep, 0.05, nil, { Reflectance = wet(0.18, "Liquid") })   -- (a flat splat catches the full sun: the deep entry displays as the liquid)
	local cf = CFrame.new(pos.X, y + 0.02, pos.Z) * CFrame.Angles(0, math.random() * TAU, 0)
	local sheen = (math.random() < 0.4) and ball(SOLID.LiquidSpec, 0.35, p) or nil
	local t0 = fxNow()
	local life = linger or 2.5
	local aspect = 0.75 + math.random() * 0.25
	updaters[p] = function(_, now)
		local t = now - t0
		if t > life + 0.8 or not p.Parent then
			p:Destroy()
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

--- Liquid drops flung from `pos` (velocity spread `speed`) that land as splats.
local function drops(pos, n, speed, size)
	for _ = 1, n do
		local body, tip = teardrop()
		local v = Vector3.new(math.random() * 2 - 1, 0.5 + math.random() * 0.9, math.random() * 2 - 1).Unit * (speed or 9)
		local t0 = fxNow()
		local sz = (size or 0.28) * (0.8 + math.random() * 0.4)
		local fy = floorY(pos, 14)
		updaters[body] = function(_, now)
			local t = now - t0
			local p = pos + v * t + Vector3.new(0, -0.5 * 35 * t * t, 0)
			local vel = v + Vector3.new(0, -35 * t, 0)
			drawTeardrop(body, tip, p, vel, sz, math.min(1.2, vel.Magnitude * 0.04))
			if (fy and p.Y <= fy + 0.05) or t > 1.6 then
				body:Destroy()
				tip:Destroy()
				splat(p, sz * 3.2, 2.2 + math.random(), fy)
				return false
			end
			return true
		end
	end
end

--- Residue stuck to a body (a raised liquid splat on `hostPart` at world `at`, facing out along `normal`) with viscous runs
--- crawling down it, each ending in a bead; it rides the body and soaks away after `life`.
local function residue(hostPart, at, normal, size, runs, life)
	if not (hostPart and hostPart.Parent) then return end
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
local function newLobe(parent, tier, emitRate, radius, band)
	local t = TIER[tier] or TIER.mid
	local c1, c2 = t[1], t[2]
	if band then c1, c2 = band[1], band[2] end                 -- (a hard-banded wrap: this lobe's band, core + halo)
	local L = {
		Core = ball(LOBE[c1], 1, parent, { Material = GAS_MATERIAL }), Halo = ball(LOBE[c2], 1, parent, { Material = GAS_MATERIAL }),
		Alpha = t[3],
		Phase = math.random() * TAU, Tier = tier,
	}
	local ls = T.Bands and T.Bands.LobeSkin                       -- (an Epic wrap: the puff wears the bubble's painted rings)
	if ls then
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
	if L.Eye then L.Eye.ImageTransparency = 1 - vis end
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
	local B, rim = T.Bands, 1e-3                                  -- (a hard-banded wrap: concentric bands, rim = 1)
	local layout = B and B.Lanes and BANDED[o.Layout] or o.Layout
	local mot, blot, eyes = 0, 0, 0
	if B then for _, s in ipairs(layout) do rim = math.max(rim, Vector2.new(s.V.X, s.V.Z).Magnitude) end end
	for _, s in ipairs(layout) do
		local r = s.R * R
		local band = B and ((s.B and B[s.B]) or (s.Tier == "skirt" and B.Edge) or bandOf(Vector2.new(s.V.X, s.V.Z).Magnitude / rim)) or nil
		local L = newLobe(folder, s.Tier, s.E and (s.E * (o.EmitMul or 1)) or nil, (s.R0 or s.R) * R, band)   -- (smoke at its own size)
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
		self.PatchRate, self.SkirtRate = math.max(2, R * 0.25), math.max(3, R * 0.6)
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
		self.GlowRate = o.GlowRate or 2.5
	end
	if B and B.Speckle then                                       -- (a speckled wrap: motes through the body, B.Share (Rare 8%) over Default's rate)
		local base = (self.PatchRate or 0) + (self.SkirtRate or 0) + (self.GlowRate or 0)
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
	for si, width in ipairs(o.Strands or { 0.3, 0.22, 0.17 }) do
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
			b.Parent = atts[i]
			beams[i] = b
		end
		strands[si] = { Atts = atts, Beams = beams, Width = width, Phase = si * 2.1 + math.random(), Split = 0.12 + si * 0.05 }
	end
	local t0 = fxNow()
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
function skinOf(S, key, baseColor)
	local bucket = skins[S]
	if not bucket then bucket = {} skins[S] = bucket end
	key = key or "_"
	local c = bucket[key]
	if c ~= nil then return c or nil end
	bucket[key] = false
	local AS = game:GetService("AssetService")
	local ok, em = pcall(function() return AS:CreateEditableMesh() end)
	if not (ok and em) then return nil end
	local rnd, blot, dots = Random.new(S.Seed), {}, {}
	for i = 1, S.Blotches do blot[i] = { rnd:NextUnitVector(), 0.3 + rnd:NextNumber() * 0.2, rnd:NextNumber() * 9 } end
	for i = 1, S.Dots do dots[i] = { rnd:NextUnitVector(), 0.07 + rnd:NextNumber() * 0.05 } end
	local Lg, cols = S.Light.Unit, {}
	local function col(name) cols[name] = cols[name] or em:AddColor(SOLID[name], 1) return cols[name] end
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
	local function paintC(d)
		local base = baseColor or SOLID[S.BaseColor]
		for _, q in ipairs(rings) do
			local x = math.acos(math.clamp(d:Dot(q[1]), -1, 1)) / q[2]
			if x < 1.15 then
				local c = SOLID[S.RingCentre]:Lerp(SOLID[S.RingInner or S.RingColor], sm(0.2, 0.38, x))
				c = c:Lerp(SOLID[S.RingColor], sm(0.52, 0.68, x))
				c = c:Lerp(SOLID[S.RingEdge], sm(0.8, 0.92, x))
				return c:Lerp(base, sm(0.94, 1.12, x))
			end
		end
		return base
	end
	local RINGS, SEGS, V = S.Res and S.Res[1] or 30, S.Res and S.Res[2] or 60, {}
	for r = 0, RINGS do
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
	task.spawn(function()
		local ok2, mp = pcall(function() return AS:CreateMeshPartAsync(Content.fromObject(em)) end)
		if not (ok2 and mp) then return end
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
	if T.Bands and T.Bands.LobeSkin then for _, n in ipairs({ "GasCore", "GasShadow", "Gas", "GasLit", "GasEdge" }) do skinOf(T.Bands.LobeSkin, n, LOBE[n]) end end
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
	smoke.Rate = 5
	smoke.Parent = murk
	-- the heart: a small, dim, steady glow low in the murk
	local heart = part({ Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) })
	heart.Parent = model
	local glow = light(heart, R * 2.5, 0.12)
	local gfx = glowEmitter(heart, R * 0.4, 0.82, R * 1.05, 3)
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
end

--- The wet burst: the torn skin peels into floppy petals, the murk squirts out as a small gas puff, and the Virulence
--- swells once.
local function burst(pos, normal, withDrops)
	local R = T.Bubble.Radius
	local n = (normal and normal.Magnitude > 1e-3) and normal.Unit or Vector3.yAxis
	for i = 1, 5 do
		local petal = ball(SOLID.Membrane, 0.35)
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
			if t > 0.55 or not petal.Parent then petal:Destroy() return false end
			-- the peel (tip first, recoiling), a damped 5 Hz flop, a droop under its own weight
			local peel = math.min(1.9, t * 9)
			local flop = 0.35 * math.sin(t * TAU * 5) * math.exp(-t / 0.2)
			local p = pos + out * (R * 0.7 + 2.6 * t) + Vector3.new(0, -0.5 * 22 * t * t, 0)
			petal.CFrame = CFrame.new(p) * (base - base.Position) * CFrame.Angles(peel + flop, spin * t, 0)
			local sh = 1 - t * 1.0
			petal.Size = Vector3.new(R * 1.05 * sh, R * 0.1, R * 0.8 * sh)
			petal.Transparency = 0.35 + math.max(0, t - 0.2) * 1.9
			return true
		end
	end
	local puff = runCumulus({ Name = "ToxinPuff", Center = pos, R = R * 1.3, Layout = LAYOUT.Puff, GrowScale = 1,
		GrowTime = 0.12, Duration = 0.2, Fade = 0.26, Breathe = 0 })
	if T.Bands and T.Bands.BurstRings then ringBurst(pos, T.Bands.BurstRings, 1.4) end   -- (an Epic wrap: a few of its rings)
	local fl = part({ Transparency = 1 })
	fl.CFrame = CFrame.new(pos)
	fl.Parent = fxFolder()
	local l = light(fl, 7, 1.3)
	TweenService:Create(l, TweenInfo.new(0.35, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	Debris:AddItem(fl, 0.6)
	if withDrops then drops(pos, 4, 8, 0.24) end
	return puff
end

H.ToxinBubblePop = function(d)
	local b = killBubble(d.Id)
	if b then b.Model:Destroy() end
	if typeof(d.Position) ~= "Vector3" then return end
	local target = typeof(d.Target) == "Instance" and d.Target or nil
	local torso = target and torsoOf(target)
	local normal = torso and (d.Position - torso.Position) or nil
	burst(d.Position, normal, true)
	-- the residue stuck where it burst, with three viscous runs down the body
	if torso and normal then
		local n = Vector3.new(normal.X, 0, normal.Z)
		n = n.Magnitude > 1e-3 and n.Unit or torso.CFrame.LookVector
		residue(torso, d.Position, n, 0.55, 3, 2.6)
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
		updaters[b] = function(_, now)
			local t = now - t0
			if t >= 0.1 then
				b.Model:Destroy()
				burst(pos, Vector3.yAxis, false)
				drops(pos, 3, 4, 0.22)
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
		Name = "ToxinCorrosiveCloud", Center = d.Center, R = R, Layout = LAYOUT.Corrosive,
		-- the v4 engorgement: lobes swell one by one out of the conversion point (the last at 0.26 of 0.6 s)
		GrowScale = form / 0.6 * 1.6, GrowTime = 0.34, From = typeof(d.Point) == "Vector3" and d.Point or d.Center,
		Glow = 1.5, GlowAt = 0.14, GlowRange = 0.6, GlowSize = 0.46, GlowAlpha = 0.52,
		Grounded = true, Duration = form + (d.Duration or T.Cloud.Duration), Fade = 1.3,
	})
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
	thread({
		From = function() return from.Parent and (from.Position + Vector3.new(0, 0.3, 0)) or nil end,
		To = function() return to.Parent and to.Position or nil end,
		Strands = { 0.26, 0.19, 0.14 }, Duration = 0.9, HeadTime = 0.5, TailStart = 0.45, Arc = 1.4, Wave = 0.55,
		Colors = { PART.GasCore, PART.GasCore }, Alpha = 0.0,
	})
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
	local blobLight = light(blob, 5, 0.3)
	local throwFrom = hand and hand.Position or (torso and torso.Position + Vector3.new(0, 0, 4))
	local stuckRel = nil
	-- the wreath: murky lobes on a ring round the torso, growing through the telegraph
	local count = 9
	for i = 1, count do
		local q = T.Bands and T.Bands.Lanes and MARK_LANES[(i - 1) % 3 + 1]          -- (a hard-banded wrap: three concentric lanes)
		local mk = not q and T.Bands and T.Bands.Mark
		local L = newLobe(folder, (i % 3 == 0) and "base" or "mid", 2.5, 1.5,
			q and T.Bands[q[1]] or (mk and ((i % 4 == 2) and mk.Blotch or ((i % 3 == 0) and mk.Outer or mk.Body))) or nil)
		L.A = i / count * TAU
		L.Y = (math.random() - 0.5) * 0.8
		L.Rs = 0.85 + math.random() * 0.3
		L.Alpha = 0.5
		if q then L.Rm, L.Sz, L.Y = q[2], q[3], q[4] end
		if mk and T.Bands.Eyes and i % 3 == 1 then L.Eye = eyeOn(L.Core, T.Bands.Eyes, Vector3.zero, 1.1, (T.Bands.Eyes.Size or 1.4) * 0.9) end
		table.insert(m.Lobes, L)
	end
	-- the heart of it: one soft core glow (the pulse) and its light
	local core = part({ Transparency = 1, Size = Vector3.new(0.4, 0.4, 0.4) })
	core.Parent = folder
	local glow = light(core, 4, 0.2)
	m.GlowFx = glowEmitter(core, 2.2, 0.7, 1.8, 6)
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
	local phase, spin = 0, 0
	local nextDrip = fxNow() + 0.6
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
			if now >= nextDrip and not m.Ended then
				nextDrip = now + 0.55 + math.random() * 0.4
				drops(blob.Position - Vector3.new(0, 0.4, 0), 1, 1.5, 0.2)
			end
		end
		local pulseEnd = telegraph - fuse
		local level
		if m.Ended then
			level = m.Burst and math.max(0, 1 - (now - m.EndAt) / 0.2) or 0
		elseif t < pulseEnd then
			local k = math.clamp(t / pulseEnd, 0, 1)
			phase += TAU * gearHz(k) * dt
			level = (0.5 - 0.5 * math.cos(phase)) * (0.4 + 0.6 * k)
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
			if L.Emit and not L.EmitOn and grow > 0.3 and not m.Ended then L.Emit.Rate, L.EmitOn = 2.5, true end
		end
		core.CFrame = CFrame.new(stuckRel and blob.Position or c)
		glow.Brightness = (0.15 + 1.6 * level) * (1 - fade * (m.Burst and 0 or 1))
		glow.Range = 4 + 2 * k
		blobLight.Brightness = 0.2 + 1.2 * level
		m.GlowFx.Transparency = nseq({ { 0, 1 }, { 0.3, 1 - 0.6 * level }, { 0.7, 1 - 0.6 * level }, { 1, 1 } })
		blob.Transparency = 0.05 + 0.95 * fade
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

H.ToxinPZBurst = function(d)
	if typeof(d.Target) == "Instance" then endMark(d.Target, true) end
	local pos = typeof(d.Position) == "Vector3" and d.Position
	if not pos then return end
	local P = T.PatientZero
	local R = d.Radius or P.Radius
	local center = typeof(d.Center) == "Vector3" and d.Center or pos
	-- the light-crack: 0.05 s held at the heart, then falling fast (a flash halo, no core)
	local flashP = part({ Transparency = 1, Size = Vector3.new(1, 1, 1) })
	flashP.CFrame = CFrame.new(pos)
	flashP.Parent = fxFolder()
	local fl = light(flashP, R * 1.5, 4)
	local flare = glowEmitter(flashP, 7, 0.35, 3, 0)
	flare.Lifetime = NumberRange.new(0.25, 0.35)
	flare:Emit(4)
	task.delay(0.05, function()
		TweenService:Create(fl, TweenInfo.new(0.4, Enum.EasingStyle.Exponential, Enum.EasingDirection.Out), { Brightness = 0 }):Play()
	end)
	Debris:AddItem(flashP, 1)
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
			q and T.Bands[q[1][1]] or (wv and (lead and wv.Lead or (i % 5 == 1 and wv.Blotch or wv.Body))) or nil)
		L.A = i / n * TAU + (math.random() - 0.5) * 0.08
		L.Lead = lead
		L.Alpha = lead and 0.7 or 0.32
		if q then L.A, L.Lane, L.Lead, L.Alpha = q[2], q[1], false, 0.32 end
		ring[i] = L
	end
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
			if L.Emit and not L.EmitOn then L.Emit.Rate, L.EmitOn = 6, true end
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
			Name = "ToxinPZMass", Center = center, R = R, Layout = LAYOUT.Mass, GrowScale = 1.4, GrowTime = 0.4,
			Glow = 1.3, GlowAt = 0.12, GlowRange = 0.55, GlowSize = 0.38, GlowAlpha = 0.58, Grounded = true,
			Duration = 0.25 + (d.Duration or P.CloudDuration), Fade = 1.5,
		})
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
	local m = masks[character]
	if not m then return end
	masks[character] = nil
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
	local character = d.Character
	local head = character and character:FindFirstChild("Head")
	if not head then return end
	dropMask(character, true)
	local V = T.Vent
	local duration = d.Duration or V.Duration
	local model, body, seat, G = buildMask(head)
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
	weld.C0 = seat * CFrame.new(0, 1.4 * head.Size.Y, -0.4) * CFrame.Angles(math.rad(-50), 0, math.rad(12))
	weld.Parent = body
	model.Parent = fxFolder()
	local glow = light(body, 1.2, 0)
	local canLight = light(G.Canister, 3, 0)
	local m = { Model = model, Weld = weld, G = G, Light = glow, CanLight = canLight }
	masks[character] = m
	-- beat 1: it drops onto the face
	TweenService:Create(weld, TweenInfo.new(0.24, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { C0 = seat }):Play()
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
					To = function() return G.Grille.Parent and G.Grille.Position or nil end,
					Strands = { 0.14, 0.1 }, Duration = 0.75, HeadTime = 0.62, TailStart = 0.55, Arc = 0.6, Wave = 0.3,
					Colors = { PART.GasCore, PART.GasShadow }, Alpha = 0.5,
					OnArrive = function()
						arrivals += 1
						pulse = 1
					end,
				})
			end)
		end
	end
	local t0 = fxNow()
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
	local hand = caster and (caster:FindFirstChild("RightHand") or caster:FindFirstChild("Right Arm"))
	if hand then
		runCumulus({ Name = "ToxinRainHold", Center = hand.Position + Vector3.new(0, 1.2, 0), R = 0.9, Layout = LAYOUT.Puff,
			GrowScale = 2, GrowTime = 0.25, Duration = 0.5, Fade = 0.4 })
	end
	-- the overhead mass: flat-bottomed, dark below, gathering lobe by lobe
	local cloud = newCumulus({ Name = "ToxinAcidRainCloud", Center = center + Vector3.new(0, height, 0), R = R * 1.05,
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
	local key = {}
	updaters[key] = function(dt, now)
		local t = now - t0
		local k = math.clamp(t / gather, 0, 1)
		local raining = t >= gather * 0.8 and t < gather + rainTime
		local over = t >= gather + rainTime or not cloud.Folder.Parent
		if over and not cloud.EndAt then cumulusEnd(cloud) end        -- the rain stops; the cloud gutters
		local alive = cumulusStep(cloud, now)
		local lvl = over and 0 or k * (0.55 + 0.2 * math.sin(now * TAU * 1.2))
		glow.Brightness = lvl * (cloud.EndAt and 0 or 1)
		local base = cloud.CF.Position
		for i, pa in ipairs(patches) do
			pa.A += dt * (0.35 + 0.15 * i)
			pa.P.CFrame = CFrame.new(base + Vector3.new(math.cos(pa.A) * pa.Rr, -0.3, math.sin(pa.A) * pa.Rr))
			pa.Fx.Rate = (not over and k > 0.3) and 2.2 or 0
		end
		lp.CFrame = CFrame.new(base + Vector3.new(0, -1, 0))
		if raining then
			spawnAcc += dt * 38
			while spawnAcc >= 1 do
				spawnAcc -= 1
				local a, rr = math.random() * TAU, math.sqrt(math.random()) * R
				local x, z = center.X + math.cos(a) * rr, center.Z + math.sin(a) * rr
				local top = Vector3.new(x, base.Y - 0.2, z)
				local body, tip = teardrop()
				local sz = 0.34 + math.random() * 0.2
				globs[#globs + 1] = { Body = body, Tip = tip, X = x, Z = z, Y = top.Y, Floor = floorY(top, height + 6) or center.Y,
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
				if math.random() < 0.45 then splat(Vector3.new(g.X, g.Floor, g.Z), g.S * 3.2, 1.8 + math.random() * 1.2, g.Floor) end
			else
				-- a teardrop falls tip-up, stretching with its speed
				drawTeardrop(g.Body, g.Tip, Vector3.new(g.X, g.Y, g.Z), Vector3.new(0, -1, 0), g.S, math.min(0.8, g.V * 0.02))
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
	if glazes[model] or not model.Parent then return end
	local folder = Instance.new("Folder")
	folder.Name = "ToxinCorroded"
	folder.Parent = fxFolder()
	local g = { Folder = folder, Parts = {}, Cover = 0, Phase = 0, NextDrip = fxNow() + 0.5 }
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
	for _, model in ipairs(d.Hit) do
		if typeof(model) == "Instance" and model:IsA("Model") then watchGlaze(model) end
	end
end

return ToxinFX

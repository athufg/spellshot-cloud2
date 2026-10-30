--[[
	WitchsBrewFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/WitchsBrewFX

	Toxin's WITCH'S BREW (2026-10-20; an EPIC Element skin): the pieces, drawn on the Default's own beats. ToxinFX calls
	in through its BREW table (Init once, then one call per hook), gated on WitchsBrewKit.On + Built; every call is
	pcall-wrapped there. The Default's particle emitters and lights keep running (its shapes are hidden on this client).
	THE WORN CAULDRON (the one flagged avatar-reaching exception: the owner asked for the backpack). A manager keeps one
	on the back of every body that wears the skin (FX.Start), with its two straps and the ward-herb satchel on its rim;
	it has idle life (a steam wisp, lazy surface bubbles) and boils over during Acid Rain.
	ONE WITCH KIT (round 4): every glint is a painted star or crescent moon (droplets, bubbles, embers: a soft dot), and
	every cast flashes a rune circle under the caster's feet (FX.Rune, sub-second). All purple, black iron.
	Organic sequencing, per ability:
	  M1 Toxic Bubbles        SPOUT: the glob leaps out of the cauldron and tumbles, a captured swirl of brew turning
	                          inside it, trailing embers and motes; at rest it bubbles; a pop/convert splashes out
	  Primary Corrosive Cloud SIMMERING POT: a steam tether reaches the splash; the cloud is a cluster of glowing bubbles
	                          that roil and reform (pop, swell back), embers drifting off the top like steam
	  Passive Symbiosis       SIPHON: a shimmering ribbon from the target into the cauldron; droplets bead on the target
	                          and run it, and the cauldron flares as each lands
	  Ultimate Patient Zero   LAUNCH -> CLAMP -> STIR -> ERUPT -> HOMECOMING: the full cauldron leaves the back (a faded,
	                          emptied husk stays strapped on), arcs onto the target's head and clamps on there, stirs itself
	                          faster as the fuse closes, erupts (a bubble cloud), then flies home full; embers trail
	                          off its vents the whole time it is away
	  Antitoxin Vent          THE HERB IN THE BREW: the pouch on the cauldron pops its flap, a sprig of ward herb (a
	                          plain plant) is tossed into the brew, the brew flares, ripples and puffs vapor, and for
	                          the Vent's length a trail of ward-vapor wisps over the shoulder and round the head --
	                          nothing is worn on the face
	  Acid Rain               BOIL OVER: the cauldron tips back, boils over and flings bubbles over the zone; some
	                          twinkle with a star, and each pops in a splash and a sparkle shimmer ring
	Luminous: every main piece carries a self-lit core -- the brew surface (Neon + light), the glob's core (Neon + light),
	the bubbles' hearts (Neon), the tether and ribbon (Beams, LightInfluence 0), the satchel's bead and rune.
	Particles: the BASE layer (steam, bubbling, splash, embers) scales with Graphics Quality; the GLINT layer (stars and
	crescents) sits on its own switch (WitchsBrewKit.SparklesOn) and halves under Reduce Flashing. FX.Stats counts
	both (particles spawned), for the checkpoint's glint-over-base percentage.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FX = {}
FX.Stats = { Base = 0, Glint = 0 }
local H, K = nil, nil
local packs = {}                              -- [character] = the worn cauldron record
local live = setmetatable({}, { __mode = "k" }) -- [emitter] = "Base" | "Glint" (continuous ones, integrated per frame)
local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local TAU = math.pi * 2

local function now() return H.fxNow() end
local function easeOut(k) return 1 - (1 - k) * (1 - k) end
local function steamColor() return (K.Palette() == "Purple") and K.Look.Accent or K.Look.Steam end
-- THE CASTER'S BODY (2026-10-23): the CastPose clip that acts with the pot (CastPose.Clips.WB*, generated from
-- vfx_blocking/toxin/witchs_brew_2026_10_20/blender/wb_body.py and previewed with the pot's moves), started from the
-- hook that moves the pot. The passive's pulse never interrupts another clip. Required on first use (CastPose requires
-- VFXLibrary); cosmetic, client-side, every client poses every caster.
local castPose = nil
local function body(char, clip)
	if castPose == nil then
		local ice = game:GetService("ReplicatedStorage"):FindFirstChild("IceMagic")
		local m = ice and ice:FindFirstChild("CastPose")
		local ok, mod = pcall(function() return m and require(m) end)
		castPose = (ok and mod and mod.Clips and mod.Clips.WBSplash) and mod or false
	end
	if not (castPose and typeof(char) == "Instance") then return end
	if clip == "WBPulse" and castPose.CurrentClip and castPose.CurrentClip(char) ~= nil then return end
	pcall(castPose.Play, char, clip)
end

----------------------------------------------------------------------------------------------------
-- EMITTERS (the base layer scales with Graphics Quality; the glint layer is its own switch)
----------------------------------------------------------------------------------------------------
local glintN = 0
local function emitter(parent, layer, o)
	if layer == "Glint" and not K.SparklesOn() then return nil end
	local e = Instance.new("ParticleEmitter")
	e.Name = "WB_" .. layer
	e.Texture = o.Texture or (layer == "Glint" and SPARKLE) or H.SMOKE
	-- THE SHARED GLINT SHAPES: every glint in the kit is a star or a crescent moon (alternating); droplets, bubbles and
	-- embers a soft dot -- never the stock round sparkle
	local tx = K.Tex()
	if tx then
		local shape = o.Shape
		if not shape and layer == "Glint" then
			glintN += 1
			shape = (glintN % 2 == 0) and "Crescent" or "Star"
		end
		if not shape and o.Texture == SPARKLE then shape = "Dot" end
		if shape and tx[shape] then e.TextureContent = tx[shape] end
	end
	e.Color = ColorSequence.new(o.Color or K.Look.Brew)
	e.LightInfluence = o.LightInfluence or 0
	e.LightEmission = o.LightEmission or (layer == "Glint" and 1 or 0.3)
	e.Size = o.Size or NumberSequence.new(0.2)
	e.Transparency = o.Transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.3),
		NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = o.Life or NumberRange.new(0.6, 1)
	e.Speed = o.Speed or NumberRange.new(0.5, 1)
	e.SpreadAngle = o.Spread or Vector2.new(25, 25)
	e.Acceleration = o.Accel or Vector3.zero
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = o.RotSpeed or NumberRange.new(-30, 30)
	e.EmissionDirection = o.Dir or Enum.NormalId.Top
	e.LockedToPart = o.Locked or false
	local d = H.density()
	if layer == "Glint" and H.calm() then d *= 0.5 end
	e.Rate = (o.Rate or 0) * d
	e:SetAttribute("Density", d)
	e.Parent = parent
	if e.Rate > 0 then live[e] = layer end
	return e
end
local function emit(e, n)
	if not e then return end
	local k = math.max(0, math.floor(n * (e:GetAttribute("Density") or 1) + 0.5))
	if k > 0 then
		e:Emit(k)
		local layer = (e.Name == "WB_Glint") and "Glint" or "Base"
		FX.Stats[layer] += k
	end
end

local function part2(props, parent)                             -- (an anchored, non-colliding piece)
	local q = Instance.new("Part")
	q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch, q.CastShadow = true, false, false, false, false
	q.TopSurface, q.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do q[k] = v end
	q.Parent = parent
	return q
end
local function anchoredHost(cf, parent)
	local p = Instance.new("Part")
	p.Name = "WB_Host"
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Transparency, p.Size, p.CFrame = 1, Vector3.new(0.2, 0.2, 0.2), cf
	p.Parent = parent or H.fxFolder()
	return p
end
-- a one-shot burst at `cf`: base splash (droplets + steam) and glints -- stars and crescents together
local function burstAt(cf, base, glint, steam, spread)
	local h = anchoredHost(cf)
	local e = emitter(h, "Base", { Shape = "Dot", Color = K.Look.Brew, Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.18),
		NumberSequenceKeypoint.new(1, 0.04) }), Life = NumberRange.new(0.35, 0.6), Speed = NumberRange.new(6, 11),
		Spread = Vector2.new(spread or 55, spread or 55), Accel = Vector3.new(0, -30, 0), LightEmission = 0.6 })
	emit(e, base or 0)
	if steam and steam > 0 then
		local sm = emitter(h, "Base", { Color = steamColor(), LightInfluence = 0.6, LightEmission = 0.1,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.4) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Life = NumberRange.new(0.6, 1.0), Speed = NumberRange.new(1, 3), Spread = Vector2.new(60, 60) })
		emit(sm, steam)
	end
	if glint and glint > 0 then
		for _, shape in ipairs({ "Star", "Crescent" }) do
			local g = emitter(h, "Glint", { Shape = shape, Color = K.Look.Glint,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.35, 0.3),
					NumberSequenceKeypoint.new(1, 0.04) }), Life = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(2, 5),
				Spread = Vector2.new(180, 180), RotSpeed = NumberRange.new(-60, 60) })
			emit(g, (shape == "Star") and math.ceil(glint / 2) or math.floor(glint / 2))
		end
	end
	task.delay(2, function() h:Destroy() end)
end

-- the floor under `pos` (characters and the effects ignored); pos.Y when there is none in reach
local rayParams = nil
--- `skip` (a caster): it is left out, and the ray starts at `pos` itself (under a roof, the floor -- not the roof)
local function groundAt(pos, skip)
	if not rayParams then
		rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
	end
	local ex = { H.fxFolder(), workspace.CurrentCamera }
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then ex[#ex + 1] = plr.Character end end
	if skip then ex[#ex + 1] = skip end
	rayParams.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos + Vector3.new(0, skip and 0 or 8, 0), Vector3.new(0, -24, 0), rayParams)
	return hit and hit.Position.Y or pos.Y
end

-- a self-lit painted image on `host`'s `face` (LightInfluence 0: it glows)
local function surfaceImage(host, face, content, color, canvas)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.LightInfluence, sg.Brightness = 0, 2.5
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(canvas or 256, canvas or 256)
	sg.Parent = host
	local im = Instance.new("ImageLabel")
	im.BackgroundTransparency, im.Size, im.ImageContent, im.ImageColor3 = 1, UDim2.fromScale(1, 1), content, color
	im.AnchorPoint, im.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	im.Parent = sg
	return im
end
-- a camera-facing painted sprite riding `host` (the M1's vortex, Acid Rain's star glints)
local function sprite(host, content, color, studs, offset)
	local bg = Instance.new("BillboardGui")
	bg.LightInfluence, bg.Brightness = 0, 1.8
	bg.Size = UDim2.new(studs, 0, studs, 0)
	bg.StudsOffset = offset or Vector3.zero
	bg.Adornee = host
	bg.Parent = host
	local im = Instance.new("ImageLabel")
	im.BackgroundTransparency, im.Size, im.ImageContent, im.ImageColor3 = 1, UDim2.fromScale(1, 1), content, color
	im.AnchorPoint, im.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	im.Parent = bg
	return { G = bg, I = im }
end

--- THE SPELLCASTING TELL (every cast in the kit): a rune circle flashes under the caster's feet -- it blooms in (0.13 s),
--- turns, and fades (the whole flash `dur`, 0.6 s by default; the M1's is smaller and quicker); glints rise off it.
function FX.Rune(caster, scale, dur)
	local tx = K.Tex()
	local root = typeof(caster) == "Instance" and caster:FindFirstChild("HumanoidRootPart")
	if not (tx and tx.Rune and root) then return end
	local d = 5 * (scale or 1)
	local pos = root.Position
	local y = groundAt(pos, caster)
	if pos.Y - y > 6 or y >= pos.Y then y = pos.Y - 3 end        -- (high in the air, or nothing below: under the feet anyway)                       -- (in the air: under the feet anyway)
	local pr = part2({ Name = "WB_Rune", Transparency = 1, Size = Vector3.new(d, 0.05, d) }, H.fxFolder())
	pr.CFrame = CFrame.new(pos.X, y + 0.06, pos.Z)
	local im = surfaceImage(pr, Enum.NormalId.Top, tx.Rune, K.Look.Herb, 256)
	im.ImageTransparency = 1
	local lt = Instance.new("PointLight")
	lt.Color, lt.Range, lt.Brightness, lt.Shadows = K.Look.Brew, d * 0.7, 0, false
	lt.Parent = pr
	local t0, dd, calm = now(), dur or 0.6, H.calm()
	local key = {}
	H.updaters[key] = function()
		local k = (now() - t0) / dd
		if k >= 1 or not pr.Parent then
			pcall(function() pr:Destroy() end)
			return false
		end
		local a = easeOut(math.clamp(k / 0.22, 0, 1)) * (1 - math.clamp((k - 0.45) / 0.55, 0, 1))
		im.ImageTransparency = 1 - 0.95 * a
		im.Rotation = k * 45
		local sc = 0.72 + 0.28 * easeOut(math.clamp(k / 0.3, 0, 1))
		im.Size = UDim2.fromScale(sc, sc)
		lt.Brightness = (calm and 0.6 or 1.8) * a
		return true
	end
	burstAt(CFrame.new(pos.X, y + 0.15, pos.Z), 0, (scale or 1) < 0.8 and 2 or 4, 0, 25)
end

----------------------------------------------------------------------------------------------------
-- THE WORN CAULDRON
----------------------------------------------------------------------------------------------------
local function torsoOf(c) return c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso") end
local PACK = 1.725                                               -- (the worn cauldron's scale; owner 2026-10-20: 50% bigger)

local function dropPack(char)
	local p = packs[char]
	if not p then return end
	packs[char] = nil
	H.updaters[p] = nil
	if p.Away and p.Away.Kill then pcall(p.Away.Kill) end
	pcall(function() p.Model:Destroy() end)
end

local function buildPack(char)
	local torso = torsoOf(char)
	if not torso then return nil end
	local model = Instance.new("Model")
	model.Name = "WitchsBrewBackpack"
	local c = K.Cauldron(PACK, model)
	if not c then return nil end
	c.Root.Anchored = false
	local sz, sy = torso.Size.Z, torso.Size.Y
	local base = CFrame.new(0, 0, sz * 0.5 + 0.55 * c.H + 0.06) * CFrame.Angles(math.rad(10), 0, 0)   -- (its belly just clears the back)
	local w = Instance.new("Weld")
	w.Part0, w.Part1, w.C0 = torso, c.Root, base
	w.Parent = c.Root
	c.Root.CFrame = torso.CFrame * base
	K.Straps(torso, model)
	-- the ward-herb satchel hangs against the cauldron's side below the rim, its flap and ward out, on a short violet strap
	-- up over the lip (the Vent unhooks it and ties it on)
	local sat = K.Satchel(PACK / 1.15, model)
	local satRel = sat and CFrame.new(-(0.515 * c.H + sat.BackZ - 0.03), 0.24 * c.H, 0.05) * CFrame.Angles(0, math.rad(90), 0)
		* CFrame.Angles(math.rad(8), 0, 0)
	local sw, hanger = nil, {}
	if sat then
		sat.Root.Anchored = false
		sw = Instance.new("Weld")
		sw.Part0, sw.Part1, sw.C0 = c.Root, sat.Root, satRel
		sw.Parent = sat.Root
		sat.Root.CFrame = c.Root.CFrame * satRel
		local pts = { (satRel * CFrame.new(0, sat.TopY - 0.02 * sat.S, sat.BackZ * 0.5)).Position,
			Vector3.new(-0.585 * c.H, 0.47 * c.H, 0.05), Vector3.new(-0.5 * c.H, 0.545 * c.H, 0.05) }
		for i = 1, #pts - 1 do
			local a, b = pts[i], pts[i + 1]
			local q = Instance.new("Part")
			q.Name = "SatchelStrap"
			q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch, q.CastShadow, q.Massless = false, false, false, false, false, true
			q.Material, q.Color = Enum.Material.Fabric, K.Look.Flap
			q.Size = Vector3.new(0.12 * sat.S, 0.03 * sat.S, (b - a).Magnitude + 0.02)
			local rel = CFrame.lookAt((a + b) / 2, b)
			q.CFrame = c.Root.CFrame * rel
			local qw = Instance.new("Weld")
			qw.Part0, qw.Part1, qw.C0 = c.Root, q, rel
			qw.Parent = q
			q.Parent = model
			hanger[#hanger + 1] = q
		end
	end
	-- the base layer on the brew: slow steam, a few bubbles; the glint layer: glints on the brew surface
	-- a thin wisp of steam, always: a narrow column whose drift wanders (its Acceleration turns in the updater), so it curls
	local steam = emitter(c.Brew, "Base", { Color = steamColor(), LightInfluence = 0.6, LightEmission = 0.1, Rate = 9,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(0.5, 0.42), NumberSequenceKeypoint.new(1, 0.8) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.5),
			NumberSequenceKeypoint.new(0.7, 0.75), NumberSequenceKeypoint.new(1, 1) }), Life = NumberRange.new(1.8, 2.6),
		Speed = NumberRange.new(1.3, 1.8), Spread = Vector2.new(4, 4), Dir = Enum.NormalId.Right, RotSpeed = NumberRange.new(-20, 20) })
	local bubbles = emitter(c.Brew, "Base", { Texture = SPARKLE, Color = K.Look.Brew, LightEmission = 0.6, Rate = 2.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.6, 0.11),
			NumberSequenceKeypoint.new(1, 0) }), Life = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(0.3, 0.8),
		Spread = Vector2.new(40, 40), Dir = Enum.NormalId.Right })
	local glints = emitter(c.Brew, "Glint", { Color = Color3.new(1, 1, 1):Lerp(K.Look.Brew, 0.4), Rate = 0.4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.2),
			NumberSequenceKeypoint.new(1, 0) }), Life = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0.1, 0.3),
		Spread = Vector2.new(70, 70), Dir = Enum.NormalId.Right })
	model.Parent = H.fxFolder()
	local parts, satParts = {}, {}
	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			parts[#parts + 1] = d
			if sat and (d:IsDescendantOf(sat.Model) or table.find(hanger, d)) then satParts[d] = true end
		end
	end
	local p = { Char = char, Torso = torso, Model = model, C = c, Weld = w, Base = base, Satchel = sat, SatWeld = sw,
		SatRel = satRel, Steam = steam, Bubbles = bubbles, Glints = glints, Tip = 0, TipUntil = 0, Pulse = 0, Seed = math.random() * 10,
		Parts = parts, SatParts = satParts, Shown = nil, Pops = {}, NextPop = 0, BoilUntil = 0, TipAngle = 55 }
	H.updaters[p] = function(dt, t)
		if not (char.Parent and torso.Parent and model.Parent) then
			dropPack(char)
			return false
		end
		-- the wearer's own first-person view never sees it (the Default mask's rule); the Vent hides the rim satchel
		local head = char:FindFirstChild("Head")
		local near = char == Players.LocalPlayer.Character and head ~= nil
			and (workspace.CurrentCamera.CFrame.Position - head.Position).Magnitude < 2
		local state = (near and "near" or "far") .. (p.VentOn and "+vent" or "")
		if state ~= p.Shown then
			p.Shown = state
			for _, bp in ipairs(p.Parts) do
				bp.LocalTransparencyModifier = (near or (p.VentOn and p.SatParts[bp])) and 1 or 0
			end
			-- the rim satchel's rune image and the bead's light and halo ignore LocalTransparencyModifier: they go out with it
			for _, x in ipairs(p.Satchel and p.Satchel.Glows or {}) do x.Enabled = not (near or p.VentOn) end
		end
		-- the wisp curls: its drift wanders round (slow, two rates, so it never repeats)
		if steam then steam.Acceleration = Vector3.new(math.sin(t * 1.3 + p.Seed) * 1.8, 0.35, math.cos(t * 0.9 + p.Seed) * 1.8) end
		-- lazy bubbles swell and pop on the brew's surface (fast and big while it boils over: Acid Rain)
		local boiling = t < p.BoilUntil
		local brewCF = c.Root.CFrame * c.Mouth
		local top = c.Brew.Size.X * 0.5
		if not c.Husk and t >= p.NextPop and #p.Pops < (boiling and 7 or 3) then
			p.NextPop = t + (boiling and (0.05 + math.random() * 0.06) or (0.45 + math.random() * 0.55))
			local a, rr = math.random() * TAU, math.sqrt(math.random()) * c.Brew.Size.Y * 0.36
			local bb = K.Bubble(p.Model)
			for _, bp in ipairs(bb.Model:GetChildren()) do if bp:IsA("BasePart") then bp.LocalTransparencyModifier = near and 1 or 0 end end
			p.Pops[#p.Pops + 1] = { B = bb, X = math.cos(a) * rr, Z = math.sin(a) * rr, T0 = t,
				Life = boiling and (0.25 + math.random() * 0.2) or (0.5 + math.random() * 0.45),
				D = c.H * (boiling and (0.12 + math.random() * 0.12) or (0.07 + math.random() * 0.08)) }
		end
		for i = #p.Pops, 1, -1 do
			local q = p.Pops[i]
			local u = (t - q.T0) / q.Life
			if u >= 1 or c.Husk then
				if u >= 1 and not near then burstAt(CFrame.new(q.B.Skin.Position), boiling and 4 or 2, 1, 0, 70) end
				q.B.Model:Destroy()
				table.remove(p.Pops, i)
			else
				local dd = q.D * (0.3 + 0.7 * easeOut(u))
				K.PlaceBubble(q.B, (brewCF * CFrame.new(0, top + dd * 0.12, 0) * CFrame.new(q.X, 0, q.Z)).Position, dd, 0)
				local m = near and 1 or 0
				for _, bp in ipairs(q.B.Model:GetChildren()) do if bp:IsA("BasePart") then bp.LocalTransparencyModifier = m end end
			end
		end
		if steam then steam.Rate = (near and 0 or (boiling and 22 or 9)) * (steam:GetAttribute("Density") or 1) end
		if p.Bubbles then p.Bubbles.Rate = (near and 0 or 2.4) * (p.Bubbles:GetAttribute("Density") or 1) end
		if p.Glints then p.Glints.Rate = (near and 0 or 0.4) * (p.Glints:GetAttribute("Density") or 1) end
		-- the brew breathes (0.5 Hz) and answers a siphon tick or a refill with a ripple
		p.Pulse = math.max(0, p.Pulse - dt * 1.6)
		if not c.Husk then
			local breathe = 0.5 + 0.5 * math.sin((t + p.Seed) * math.pi)
			c.Light.Brightness = 0.8 + 0.25 * breathe + 2.6 * p.Pulse          -- (a siphon drop landing: it flares)
			c.Light.Range = 6 * PACK * (1 + 0.4 * p.Pulse)
			c.Brew.Color = K.Look.Brew:Lerp(Color3.fromRGB(125, 105, 255), p.Pulse)   -- (a brighter violet: toward white it bloomed pink)
		end
		-- Acid Rain's tip: back over 0.2 s (it shudders while it boils over), hold, home over 0.25 s
		local want = (t < p.TipUntil) and 1 or 0
		local rate = (want > p.Tip) and 5 or 4
		p.Tip = math.clamp(p.Tip + (want - p.Tip) * math.min(1, dt * rate * 2), 0, 1)
		local shudder = boiling and math.sin(t * 38) * 0.035 or 0
		w.C0 = base * CFrame.Angles(math.rad(p.TipAngle) * easeOut(p.Tip) + shudder, 0, shudder * 0.6)
		return true
	end
	return p
end

--- The worn cauldron of `char`, when it wears the skin (built on demand).
function FX.Pack(char)
	if typeof(char) ~= "Instance" then return nil end
	local p = packs[char]
	if p and p.Model.Parent then return p end
	if not (K.Built and K.On(char)) then return nil end
	p = buildPack(char)
	packs[char] = p
	return p
end
local function mouth(p) return p.C.Root.CFrame * p.C.Mouth end

-- the manager: every half second, every body that should wear one does
local started = false
function FX.Start()
	if started or not RunService:IsClient() then return end
	started = true
	-- (2026-10-26) the kit let go of its meshes (MeshBudget / the Altar's ReleaseNow: nobody here wears it): every worn
	-- cauldron (and one away on a flight) goes with them, so none keeps drawing a destroyed mesh; the manager builds them
	-- again once it is rebuilt
	if K.OnRelease then K.OnRelease(function() for char in pairs(packs) do dropPack(char) end end) end
	task.spawn(function()
		while true do
			local seen = {}
			local function consider(m)
				if typeof(m) == "Instance" and m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
					seen[m] = true
					local on = K.On(m)
					if on and K.Built and not packs[m] then
						local ok, p = pcall(buildPack, m)
						if ok and p then packs[m] = p end
					elseif not on and packs[m] then
						dropPack(m)
					end
				end
			end
			for _, plr in ipairs(Players:GetPlayers()) do consider(plr.Character) end
			if RunService:IsStudio() then                         -- (the StudioSkin stand-ins: workspace and the dummies)
				for _, m in ipairs(workspace:GetChildren()) do if m:GetAttribute("StudioSkin") == K.Id then consider(m) end end
				local tg = workspace:FindFirstChild("TrainingGround")
				local dm = tg and tg:FindFirstChild("Dummies")
				if dm then for _, m in ipairs(dm:GetChildren()) do if m:GetAttribute("StudioSkin") == K.Id then consider(m) end end end
			end
			-- (2026-10-26) the showcase stand-ins (ShowcaseSkin, live and in Studio), wherever in the workspace they are
			if K.Showcased then for _, m in ipairs(K.Showcased()) do consider(m) end end
			for char in pairs(packs) do if not seen[char] then dropPack(char) end end
			task.wait(0.5)
		end
	end)
	-- the base/glint integrator for the checkpoint's counts (continuous emitters: rate x time)
	local shown = 0
	H.updaters[FX.Stats] = function(dt, t)
		for e, layer in pairs(live) do
			if e.Parent and e.Enabled then FX.Stats[layer] += e.Rate * dt end
		end
		if t - shown > 0.25 then                                -- (published for the checkpoint's measurements)
			shown = t
			local f = H.fxFolder()
			f:SetAttribute("WB_StatBase", math.floor(FX.Stats.Base + 0.5))
			f:SetAttribute("WB_StatGlint", math.floor(FX.Stats.Glint + 0.5))
		end
		return true
	end
end

function FX.Init(helpers, kit)
	H, K = helpers, kit
	-- (the kit's own purple Look stands: the owner's locked palette; ToxinFX's Default colours are not copied in)
	FX.Start()
end

----------------------------------------------------------------------------------------------------
-- M1 TOXIC BUBBLES: the spout, the glob, the splash
----------------------------------------------------------------------------------------------------
-- a few droplets leap from the cauldron's mouth to `to` over `time` (the spout's cascade)
local function spout(p, to, n, time, lift, from)
	from = from or mouth(p).Position
	local drops = {}
	for i = 1, n do
		local d = K.Drop(H.fxFolder())
		drops[i] = { P = d, Delay = (i - 1) * 0.035, Off = Vector3.new(math.random() - 0.5, math.random() - 0.5, math.random() - 0.5) * 0.4 }
	end
	local t0 = now()
	local key = {}
	H.updaters[key] = function()
		local alive = false
		for _, d in ipairs(drops) do
			local k = math.clamp((now() - t0 - d.Delay) / time, 0, 1)
			if k < 1 then alive = true end
			local pos = from:Lerp(to + d.Off, k) + Vector3.new(0, math.sin(k * math.pi) * (lift or 1.2), 0)
			d.P.CFrame = CFrame.new(pos)
			d.P.Size = Vector3.new(0.16, 0.22, 0.16) * (1 - 0.5 * k)
			d.P.Transparency = (k <= 0 or k >= 1) and 1 or 0.1
		end
		if not alive then
			for _, d in ipairs(drops) do d.P:Destroy() end
			return false
		end
		return true
	end
	p.Pulse = math.max(p.Pulse, 0.6)
end

-- THE LADLE THROW (2026-10-23, owner: the throw comes from a ladle; the cauldron stays the passive source). On the
-- body's WBSplash keys: the hand takes the ladle out of the brew over the shoulder (Grab), it dips and comes up full
-- (Scoop: the brew splashes), the fling lets the glob go (Release: a spray off the bowl) and the hand puts it back (Back).
-- The glob itself is the Default's projectile from the press: FX.BubbleDraw draws it in the bowl until the Release and
-- joins it to its true path by Join (the first 0.14 s of how it is drawn; Hydra's spit does the same from its mouth).
local LADLE = { Grab = 0.04, Scoop = 0.07, Release = 0.10, Join = 0.14, Back = 0.42 }
-- THE LADLE IN FIRST PERSON (2026-10-23, owner): the wearer's own camera draws the Viewmodel's arms, not the body (the
-- pack and the body's ladle are hidden for them), so the throw gets its own ladle in the throwing fist -- the kit's
-- ladle at a viewmodel size, tipped up out of the fist, full of brew from the scoop to the release, gone at the put-back;
-- the glob is drawn from ITS bowl for them. One per wearer, reused by a quick next throw; placed after the arms each
-- frame (RenderPriority Camera + 4, as Frostblade's held kunai). Third person and every other viewer: the body's ladle.
local FPL = { Scale = 0.55, Tilt = math.rad(115) }
local vmod = nil
local function viewmodel()
	if vmod == nil then
		local ice = game:GetService("ReplicatedStorage"):FindFirstChild("IceMagic")
		local m = ice and ice:FindFirstChild("Viewmodel")
		local ok, mod = pcall(function() return m and require(m) end)
		vmod = (ok and type(mod) == "table" and mod.GetFistCFrame) and mod or false
	end
	return vmod or nil
end
local function fpLadle(p, C, w, t0)
	local vm = viewmodel()
	if not (vm and vm.GetFistCFrame("R")) then return end            -- (third person, or no arms drawn)
	local side = (vm.ShotPlaying and vm.ShotPlaying("L", "IcicleShard") and not vm.ShotPlaying("R", "IcicleShard")) and "L" or "R"
	local f = p.FPLadle
	if not (f and f.Model.Parent) then
		local model = Instance.new("Model")
		model.Name = "WB_FPLadle"
		local function copy(src)
			local q = src:Clone()
			for _, ch in ipairs(q:GetChildren()) do if not ch:IsA("SpecialMesh") then ch:Destroy() end end
			q.Anchored, q.CanCollide, q.CanQuery, q.CanTouch, q.CastShadow = true, false, false, false, false
			q.Size = src.Size * FPL.Scale
			q.LocalTransparencyModifier = 0
			q.Parent = model
			return q
		end
		f = { Model = model, Handle = copy(C.Ladle), Bowl = copy(C.LadleBowl), Fill = copy(C.LadleFill) }
		f.Handle.Transparency, f.Bowl.Transparency = 0, 0
		model.Parent = workspace.CurrentCamera
		p.FPLadle = f
	end
	f.T0, f.Side = t0, side
	w.Ladle.VMBowl = f.Bowl
	if f.Bound then return end
	f.Bound = "WB_FPLadle_" .. tostring(f)
	local hs = C.H * FPL.Scale
	RunService:BindToRenderStep(f.Bound, Enum.RenderPriority.Camera.Value + 4, function()
		local t = now() - f.T0
		local fist = vm.GetFistCFrame(f.Side)
		if t >= LADLE.Back or not fist or not f.Model.Parent then
			pcall(function() RunService:UnbindFromRenderStep(f.Bound) end)
			f.Bound = nil
			pcall(function() f.Model:Destroy() end)
			p.FPLadle = nil
			return
		end
		local handle = fist * CFrame.Angles(FPL.Tilt, 0, 0) * CFrame.new(0, -(0.05 + 0.4 * hs), 0)
		f.Fill.Transparency = (t >= LADLE.Grab and t < LADLE.Release) and 0.05 or 1
		workspace:BulkMoveTo({ f.Handle, f.Bowl, f.Fill },
			{ handle, handle * CFrame.new(0, -0.42 * hs, 0), handle * CFrame.new(0, -0.39 * hs, 0) },
			Enum.BulkMoveMode.FireCFrameChanged)
	end)
end
local function ladleThrow(p, caster, w, origin)
	local C = p.C
	local weld = C.Ladle and C.Ladle:FindFirstChildOfClass("Weld")
	local hand = caster:FindFirstChild("RightHand") or caster:FindFirstChild("Right Arm")
	if not (weld and hand and C.LadleBowl and C.LadleFill) then  -- (no ladle or no hand: the old spout from the mouth)
		spout(p, origin, 4, 0.16, 0.8)
		burstAt(mouth(p), 3, 2, 2, 40)
		return
	end
	p.LadleGen = (p.LadleGen or 0) + 1
	local gen, t0, key = p.LadleGen, now(), {}
	local grip = CFrame.new(0, -0.1 - 0.4 * C.H, 0)                -- (the handle runs on down the hand; the bowl at its end)
	local held, scooped, released = false, false, false
	w.Ladle = { T0 = t0, Bowl = C.LadleBowl }
	if caster == Players.LocalPlayer.Character then pcall(fpLadle, p, C, w, t0) end   -- (the wearer's own first person)
	H.updaters[key] = function()
		if p.LadleGen ~= gen or not (weld.Parent and hand.Parent and C.Body.Parent) then return false end
		local t = now() - t0
		if t >= LADLE.Grab and not held then
			held = true
			weld.Part0, weld.C0 = hand, grip
		end
		if t >= LADLE.Scoop - 0.02 and not scooped then
			scooped = true
			burstAt(mouth(p), 3, 2, 2, 40)                        -- (the dip: the brew splashes, the pot answers)
			p.Pulse = math.max(p.Pulse, 0.6)
			C.LadleFill.Transparency = 0.05
		end
		if t >= LADLE.Release and not released then
			released = true
			C.LadleFill.Transparency = 1
			local from = C.LadleBowl.Position
			local dir = (origin - from).Magnitude > 0.1 and (origin - from).Unit or hand.CFrame.LookVector
			spout(p, from + dir * 3, 3, 0.12, 0.3, from)          -- (a spray of brew off the bowl as it flings)
		end
		if t >= LADLE.Back then
			weld.Part0, weld.C0 = C.Body, C.LadleRel
			return false
		end
		return true
	end
end

function FX.BubbleStart(b, caster, origin)
	local p = FX.Pack(caster)
	b.WB = { G = K.Glob("M1", b.Model), Pack = p, Ang = 0 }
	-- its own light (a glowing heart that lights what it passes)
	local g = b.WB.G
	local lt = Instance.new("PointLight")
	lt.Color, lt.Range, lt.Brightness, lt.Shadows = K.Look.Brew, 7, 1.4, false
	lt.Parent = g.Core
	b.WB.Light = lt
	-- THE CAPTURED VORTEX: a spiral of brew turning inside the glob (a camera-facing sprite: it reads from any side)
	local tx = K.Tex()
	if tx and tx.Spiral then b.WB.Swirl = sprite(g.Core, tx.Spiral, K.Look.Glint, 1) end
	b.WB.Motes = emitter(g.Core, "Glint", { Color = K.Look.Glint, Rate = 10,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.26), NumberSequenceKeypoint.new(1, 0) }),
		Life = NumberRange.new(0.45, 0.8), Speed = NumberRange.new(0.4, 1.4), Spread = Vector2.new(180, 180), RotSpeed = NumberRange.new(-90, 90) })
	-- EMBERS trail behind it and drift up (no comet streak)
	b.WB.Trail = emitter(g.Core, "Base", { Shape = "Dot", Color = K.Look.Ember, LightEmission = 0.45, Rate = 22,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.16), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Life = NumberRange.new(0.4, 0.9), Speed = NumberRange.new(0.1, 0.5), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, 2.5, 0) })
	if p and typeof(origin) == "Vector3" then
		body(caster, "WBSplash")                                  -- (over the shoulder for the ladle, scoop, fling)
		ladleThrow(p, caster, b.WB, origin)
	end
	FX.Rune(caster, 0.6, 0.4)
end
function FX.BubbleDraw(b, cf, size, fade, look)
	local w = b.WB
	if not w then return end
	if w.Light then w.Light.Brightness = 1.4 * (1 - fade) end
	-- it TUMBLES (fast in flight, lazily at rest): its squash, its swirls and its vortex all turn with it
	local tn = now()
	local dt = math.clamp(tn - (w.Last or tn), 0, 0.1)
	w.Last = tn
	w.Ang += dt * (w.Rest and 1.4 or 7.5)
	local ld = w.Ladle                                            -- (the first 0.14 s: in the ladle's bowl, then to its path)
	if ld and ld.Bowl.Parent then
		local e = tn - ld.T0
		if e < LADLE.Join then
			local b = (ld.VMBowl and ld.VMBowl.Parent) and ld.VMBowl or ld.Bowl   -- (first person: the viewmodel's ladle)
			local bowl = b.Position + Vector3.new(0, b.Size.Y * 0.5, 0)
			if e < LADLE.Scoop then fade = 1 end                  -- (not out of the brew yet)
			local k = math.clamp((e - LADLE.Release) / (LADLE.Join - LADLE.Release), 0, 1)
			size = size * (0.3 + 0.7 * k)
			cf = CFrame.new(bowl:Lerp(cf.Position, k)) * cf.Rotation
		else
			w.Ladle = nil
		end
	end
	K.PlaceGlob(w.G, cf * CFrame.Angles(w.Ang * 0.8, w.Ang * 0.35, w.Ang * 0.55), size * 0.92, fade, nil)
	if w.Swirl then
		local d = size.X * 0.92 * 0.85
		w.Swirl.G.Size = UDim2.new(d, 0, d, 0)
		w.Swirl.G.StudsOffset = Vector3.new(0, 0, size.X * 0.3)   -- (toward the camera: in front of the opaque core, inside the skin)
		w.Swirl.I.Rotation = math.deg(w.Ang) * 1.6
		w.Swirl.I.ImageTransparency = 0.15 + 0.85 * fade
	end
end
function FX.BubbleRest(b)
	local w = b.WB
	if not w or w.Rest then return end
	if w.Motes then w.Motes.Rate = 3 * (w.Motes:GetAttribute("Density") or 1) end      -- (at rest: a few lazy motes)
	if w.Trail then w.Trail.Enabled = false end
	w.Rest = emitter(w.G.Core, "Base", { Shape = "Dot", Color = K.Look.Brew, LightEmission = 0.6, Rate = 3,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.06), NumberSequenceKeypoint.new(0.6, 0.14),
			NumberSequenceKeypoint.new(1, 0) }), Life = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(0.5, 1.2),
		Spread = Vector2.new(35, 35) })
	burstAt(CFrame.new(w.G.Core.Position), 5, 2, 0, 70)
end
function FX.Splash(pos, normal, big)
	local up = (typeof(normal) == "Vector3" and normal.Magnitude > 1e-3) and normal.Unit or Vector3.yAxis
	burstAt(CFrame.lookAt(pos, pos + up) * CFrame.Angles(-math.pi / 2, 0, 0), big and 14 or 8, big and 6 or 3, big and 4 or 2, 60)
end

----------------------------------------------------------------------------------------------------
-- PRIMARY CORROSIVE CLOUD: the steam tether
----------------------------------------------------------------------------------------------------
local function beam(a0, a1, o, parent)
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Color = ColorSequence.new(o.Color)
	b.LightInfluence, b.LightEmission = o.LightInfluence or 0, o.LightEmission or 1
	b.Width0, b.Width1 = o.W0, o.W1
	b.Transparency = NumberSequence.new(o.T or 0)
	b.Segments = o.Segments or 16
	b.FaceCamera = true
	b.CurveSize0, b.CurveSize1 = o.C0 or 0, o.C1 or 0
	if o.Texture then b.Texture, b.TextureSpeed, b.TextureLength = o.Texture, o.TextureSpeed or 0.5, o.TextureLength or 2 end
	if o.TextureMode then b.TextureMode = o.TextureMode end
	if o.TextureContent then
		b.TextureContent, b.TextureMode = o.TextureContent, Enum.TextureMode.Wrap
		b.TextureSpeed, b.TextureLength = o.TextureSpeed or 1, o.TextureLength or 1
	end
	b.Parent = parent
	return b
end

--- A cumulus (Corrosive Cloud; Patient Zero's mass) made a SIMMERING POT OF BUBBLES: the Default lobes' haze, smoke and
--- glow sprite are hidden on this client; every lobe becomes a glowing brew bubble at the lobe's place and size that ROILS
--- (drifts round its lobe, breathes) and REFORMS (now and then one pops in a splash and glints and swells back from
--- nothing); a glowing heart sits low in it, and embers and star/crescent motes drift off the top like steam.
function FX.Bubblify(c, opts)
	if not (c and c.Folder and c.Lobes and c.CF) then return end
	opts = opts or {}
	for _, L in ipairs(c.Lobes) do
		for _, q in ipairs({ L.Core, L.Halo, L.Over }) do
			if typeof(q) == "Instance" and q:IsA("BasePart") then q.LocalTransparencyModifier = 1 end
		end
		if L.Emit then L.Emit.Enabled = false end
	end
	if c.GlowFx then c.GlowFx.Enabled = false end
	if c.Light then c.Light.Enabled = false end
	local R = c.R or 9
	local center = c.CF.Position
	local heart = part2({ Name = "WB_Heart", Material = Enum.Material.Neon, Color = K.Look.Brew, Transparency = 1,
		Size = Vector3.new(R * 0.5, R * 0.3, R * 0.5) }, c.Folder)
	local hm = Instance.new("SpecialMesh")
	hm.MeshType = Enum.MeshType.Sphere
	hm.Parent = heart
	heart.CFrame = CFrame.new(center + Vector3.new(0, R * 0.18, 0))
	local heartLight = Instance.new("PointLight")
	heartLight.Color, heartLight.Range, heartLight.Brightness, heartLight.Shadows = K.Look.Brew, R * 1.4, 0, false
	heartLight.Parent = heart
	local cells = {}
	local t0 = now()
	for _, L in ipairs(c.Lobes) do
		if L.Core then
			local bb = K.Bubble(c.Folder)                              -- (a brew-tinted, barely mirrored skin: it glows, not shines)
			bb.Skin.Color, bb.Skin.Reflectance = K.Look.Brew:Lerp(Color3.new(1, 1, 1), 0.3), 0.08
			cells[#cells + 1] = { L = L, B = bb, Seed = math.random() * 10, Born = t0 - math.random() * 0.7,
				Pop = t0 + 1.5 + math.random() * 4 }
		end
	end
	local top = anchoredHost(CFrame.new(center + Vector3.new(0, R * 0.5, 0)), c.Folder)
	top.Size = Vector3.new(R * 1.1, 0.4, R * 1.1)
	local big = opts.Big and 1.5 or 1
	local embers = emitter(top, "Base", { Shape = "Dot", Color = K.Look.Ember, LightEmission = 0.45, Rate = 22 * big,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.38), NumberSequenceKeypoint.new(0.6, 0.24), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.1, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Life = NumberRange.new(1.6, 2.8), Speed = NumberRange.new(1, 2.2), Spread = Vector2.new(25, 25), Accel = Vector3.new(0, 0.8, 0) })
	local motes = emitter(top, "Glint", { Color = K.Look.Glint, Rate = 8 * big,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.55), NumberSequenceKeypoint.new(1, 0) }),
		Life = NumberRange.new(1.2, 2), Speed = NumberRange.new(0.8, 1.6), Spread = Vector2.new(35, 35), Accel = Vector3.new(0, 0.6, 0),
		RotSpeed = NumberRange.new(-60, 60) })
	local popPart = anchoredHost(CFrame.new(center), c.Folder)
	local popDrops = emitter(popPart, "Base", { Shape = "Dot", Color = K.Look.Brew, LightEmission = 0.8,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 0.03) }),
		Life = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(3, 6), Spread = Vector2.new(70, 70), Accel = Vector3.new(0, -20, 0) })
	local popGlints = emitter(popPart, "Glint", { Shape = "Star", Color = K.Look.Glint,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.32), NumberSequenceKeypoint.new(1, 0) }),
		Life = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(1, 2.5), Spread = Vector2.new(90, 90) })
	local function clear()
		for _, cl in ipairs(cells) do pcall(function() cl.B.Model:Destroy() end) end
		pcall(function() heart:Destroy() top:Destroy() popPart:Destroy() end)
	end
	local key = {}
	H.updaters[key] = function()
		local t = now()
		if not c.Folder.Parent then
			clear()
			return false
		end
		local fade = c.EndAt and math.clamp((t - c.EndAt) / math.max(0.05, c.Fade or 1.2), 0, 1) or 0
		local grow = math.clamp((t - t0) / 0.6, 0, 1)
		local breath = 0.5 + 0.5 * math.sin(t * 2.4)
		heart.Transparency = 1 - (0.22 + 0.06 * breath) * grow * (1 - fade)
		heartLight.Brightness = (1.2 + 0.4 * breath) * grow * (1 - fade)
		for _, cl in ipairs(cells) do
			local q = cl.L.Core
			if q and q.Parent then
				if fade <= 0 and t >= cl.Pop then                    -- (it reforms: a pop, a splash, a glint; it swells back)
					popPart.CFrame = cl.B.Skin.CFrame
					emit(popDrops, 6)
					emit(popGlints, 2)
					cl.Born, cl.Pop = t, t + 2.5 + math.random() * 4
				end
				local regrow = easeOut(math.clamp((t - cl.Born) / 0.7, 0, 1))
				local a = t * 0.35 + cl.Seed
				local sz = q.Size.X
				local d = sz * 0.82 * (0.94 + 0.06 * math.sin(t * 1.7 + cl.Seed)) * regrow
				local off = Vector3.new(math.cos(a) * sz * 0.08, math.sin(a * 1.3) * sz * 0.06, math.sin(a) * sz * 0.08)
				local al = cl.L.Alpha or 0.5
				local lf = math.clamp((q.Transparency - al) / math.max(0.05, 1 - al), 0, 1)
				K.PlaceBubble(cl.B, q.Position + off, math.max(0.05, d), math.max(lf, fade), true)
			end
		end
		if embers then embers.Enabled = fade < 0.4 end
		if motes then motes.Enabled = fade < 0.4 end
		if fade >= 1 then
			clear()
			return false
		end
		return true
	end
end

function FX.Cloud(c, caster, center, form, endAt)
	if not (c and c.Folder) then return end
	FX.Bubblify(c)
	FX.Rune(caster, 1)
	local p = FX.Pack(caster)
	if not p then return end
	if (form or 0.6) >= 0.55 then body(caster, "WBDirect") end      -- (the cast only: a regrown cloud has a shorter form)
	-- the steam tether, from the cauldron to the splash (beads of brew run out along it)
	local a0 = Instance.new("Attachment")
	a0.Name = "WB_Tether"
	a0.Parent = p.C.Brew                                          -- (its Axis is up: the tether rises out of the brew)
	local endP = anchoredHost(mouth(p), c.Folder)
	local a1 = Instance.new("Attachment")
	a1.Axis = Vector3.yAxis                                       -- (so the tether comes down into the cloud from above)
	a1.Parent = endP
	local core = beam(a0, a1, { Color = K.Look.Brew, W0 = 0.16, W1 = 0.3, T = 0, C0 = 3, C1 = -2 }, c.Folder)
	local halo = beam(a0, a1, { Color = K.Look.Brew, W0 = 0.5, W1 = 0.9, T = 0.75, C0 = 3, C1 = -2 }, c.Folder)
	local steam = beam(a0, a1, { Color = steamColor(), W0 = 0.9, W1 = 1.8, T = 0.35, C0 = 3, C1 = -2, LightInfluence = 0.6,
		LightEmission = 0.15, Texture = H.SMOKE, TextureSpeed = 1.2, TextureLength = 3 }, c.Folder)
	burstAt(mouth(p), 0, 2, 5, 30)
	local target = center + Vector3.new(0, 1.2, 0)
	local t0 = now()
	local arrived = false
	local beads, nextBead = {}, t0
	local function onCurve(u)                                     -- (the beam's own bezier)
		local P0, P3 = a0.WorldPosition, a1.WorldPosition
		local C1, C2 = P0 + a0.WorldAxis * core.CurveSize0, P3 - a1.WorldAxis * core.CurveSize1
		local v = 1 - u
		return P0 * v * v * v + C1 * 3 * v * v * u + C2 * 3 * v * u * u + P3 * u * u * u
	end
	local function clear()
		pcall(function() a0:Destroy() end)
		pcall(function() endP:Destroy() core:Destroy() halo:Destroy() steam:Destroy() end)
		for _, b in ipairs(beads) do pcall(function() b.P:Destroy() end) end
	end
	H.updaters[a0] = function()
		local t = now() - t0
		if not (c.Folder.Parent and a0.Parent) then
			clear()
			return false
		end
		local k = easeOut(math.clamp(t / math.max(0.2, form), 0, 1))
		endP.CFrame = CFrame.new(mouth(p).Position:Lerp(target, k))
		if k >= 1 and not arrived then
			arrived = true
			burstAt(CFrame.new(target), 4, 3, 2, 180)
		end
		local fade = c.EndAt and math.clamp((now() - c.EndAt) / math.max(0.05, c.Fade or 1.2), 0, 1) or 0
		core.Transparency = NumberSequence.new(fade)
		halo.Transparency = NumberSequence.new(0.75 + 0.25 * fade)
		steam.Transparency = NumberSequence.new(0.35 + 0.65 * fade)
		if fade < 0.5 and now() >= nextBead then
			nextBead = now() + 0.32
			local d = K.Drop(c.Folder)
			d.Size = Vector3.new(0.26, 0.26, 0.26)
			beads[#beads + 1] = { P = d, T0 = now() }
		end
		for i = #beads, 1, -1 do
			local b = beads[i]
			local u = (now() - b.T0) / 0.7
			if u >= 1 then
				b.P:Destroy()
				table.remove(beads, i)
			else
				b.P.CFrame = CFrame.new(onCurve(math.clamp(u, 0, 1) * k))
				b.P.Transparency = 0.05 + 0.95 * fade
			end
		end
		if fade >= 1 then
			clear()
			return false
		end
		return true
	end
end

----------------------------------------------------------------------------------------------------
-- PASSIVE SYMBIOSIS: the siphon line and its droplet
----------------------------------------------------------------------------------------------------
--- THE SIPHON: a shimmering RIBBON (the painted ribbon flowing along it, inside a soft glow) from the poisoned target
--- (`victimPart`, its torso) up and over into the caster's cauldron. It appears with the first tick and stays while the
--- ticks keep coming; each tick, three drops of brew BEAD up and travel it, glinting, and every one that lands makes the
--- cauldron flare. One ribbon per target.
function FX.Siphon(caster, victimPart)
	local p = FX.Pack(caster)
	if not (p and typeof(victimPart) == "Instance") then return end
	body(caster, "WBPulse")                                       -- (a small inhale on the tick; yields to any cast clip)
	p.Siphons = p.Siphons or {}
	local s = p.Siphons[victimPart]
	if not (s and s.A0.Parent) then
		local a0 = Instance.new("Attachment")
		a0.Name = "WB_Siphon"
		a0.Parent = p.C.Brew                                      -- (its Axis is up: the ribbon drops into the brew from above)
		local host = anchoredHost(victimPart.CFrame, p.Model)
		local a1 = Instance.new("Attachment")
		a1.Axis = Vector3.yAxis                                   -- (it rises off the target ...)
		a1.Parent = host
		local tx = K.Tex()
		local line = beam(a1, a0, { Color = K.Look.Glint, W0 = 0.32, W1 = 0.42, T = 1, C0 = 3, C1 = -2,
			TextureContent = tx and tx.Ribbon or nil, TextureSpeed = 1.6, TextureLength = 1.4 }, p.Model)
		local halo = beam(a1, a0, { Color = K.Look.Brew, W0 = 0.8, W1 = 1.0, T = 1, C0 = 3, C1 = -2 }, p.Model)
		s = { A0 = a0, A1 = a1, Host = host, Line = line, Halo = halo, Last = 0, Drops = {} }
		p.Siphons[victimPart] = s
		local function kill()
			pcall(function() a0:Destroy() host:Destroy() line:Destroy() halo:Destroy() end)
			for _, d in ipairs(s.Drops) do pcall(function() d.P:Destroy() end) end
			p.Siphons[victimPart] = nil
		end
		H.updaters[s] = function()
			if not (victimPart.Parent and host.Parent and a0.Parent) then
				kill()
				return false
			end
			host.CFrame = victimPart.CFrame
			local t = now()
			-- on with the first tick, held while ticks keep coming (at most every 0.8 s), gone 2.5 s after the last; it shimmers
			local idle = t - s.Last
			local vis = math.clamp(1 - (idle - 2.0) / 0.5, 0, 1)
			local shimmer = 0.85 + 0.15 * math.sin(t * 13)
			line.Transparency = NumberSequence.new(1 - 0.95 * vis * shimmer)
			halo.Transparency = NumberSequence.new(1 - 0.32 * vis)
			local P0, P3 = a1.WorldPosition, a0.WorldPosition
			local C1, C2 = P0 + a1.WorldAxis * line.CurveSize0, P3 - a0.WorldAxis * line.CurveSize1
			for i = #s.Drops, 1, -1 do
				local d = s.Drops[i]
				local k = (t - d.T0) / 0.6
				if k >= 1 then
					d.P:Destroy()
					table.remove(s.Drops, i)
					p.Pulse = 1                                     -- (it lands: the cauldron flares)
					burstAt(mouth(p), 2, 3, 0, 60)
				elseif k >= 0 then
					-- it BEADS on the target (swells out of the ribbon's end), then runs the ribbon, nose first
					local kk = 0.1 + 0.9 * k                            -- (it beads just clear of the torso the ribbon starts in)
					local u = 1 - kk
					local pos = P0 * u * u * u + C1 * 3 * u * u * kk + C2 * 3 * u * kk * kk + P3 * kk * kk * kk
					local tan = (C1 - P0) * 3 * u * u + (C2 - C1) * 6 * u * kk + (P3 - C2) * 3 * kk * kk
					local bead = easeOut(math.clamp(k / 0.18, 0, 1))
					d.P.Size = Vector3.new(0.42, 0.62, 0.42) * math.max(0.05, bead)
					d.P.CFrame = tan.Magnitude > 1e-3 and (CFrame.lookAt(pos, pos + tan) * CFrame.Angles(-math.pi / 2, 0, 0)) or CFrame.new(pos)
					d.P.Transparency = 0.02
					if d.Glow then d.Glow.G.Enabled = true end
					if d.G then d.G.Enabled = true end
				end
			end
			if vis <= 0 and #s.Drops == 0 then
				kill()
				return false
			end
			return true
		end
	end
	s.Last = now()
	for i = 1, 3 do                                               -- (three drops bead up and run the ribbon, one after another)
		local d = K.Drop(p.Model)
		d.Size = Vector3.new(0.02, 0.02, 0.02)
		d.Transparency = 1
		local dtx = K.Tex()
		local glow = dtx and dtx.Dot and sprite(d, dtx.Dot, K.Look.Brew, 1.5)   -- (a soft glow round each bead)
		if glow then glow.G.Enabled = false end
		local g = emitter(d, "Glint", { Color = K.Look.Glint, Rate = 12,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.24), NumberSequenceKeypoint.new(1, 0) }),
			Life = NumberRange.new(0.3, 0.55), Speed = NumberRange.new(0.2, 0.8), Spread = Vector2.new(180, 180) })
		if g then g.Enabled = false end
		s.Drops[#s.Drops + 1] = { P = d, G = g, Glow = glow, T0 = now() + 0.1 + (i - 1) * 0.11 }
	end
	burstAt(victimPart.CFrame, 3, 2, 0, 70)                        -- (the brew is drawn off the target)
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE PATIENT ZERO: launch -> lock -> stir -> erupt -> homecoming
----------------------------------------------------------------------------------------------------
function FX.Mark(caster, target, telegraph, fuse)
	local p = FX.Pack(caster)
	local torsoT = typeof(target) == "Instance" and torsoOf(target)
	if not (p and torsoT) or p.Away then return nil end
	local F = K.Cauldron(PACK, H.fxFolder())                       -- (the same pot that left the back)
	if not F then return nil end
	F.Root.CFrame = p.C.Root.CFrame
	K.Husk(p.C, true)
	p.Steam.Enabled, p.Bubbles.Enabled = false, false
	if p.Glints then p.Glints.Enabled = false end
	-- its middle to its iron underside: it sits ON the crown on its belly (its three feet are set wider than a head, so
	-- they come down round the sides of the head and grip it)
	local BELLY = F.Body.Size.Y * 0.5
	-- brew oozing out from under it, running down the sides of the head while it is clamped on (Neon: lit)
	local ooze = {}
	for i = 1, 3 do
		local o = part2({ Name = "WB_Ooze", Material = Enum.Material.Neon, Color = K.Look.Brew, Transparency = 1,
			Size = Vector3.new(0.09, 0.2, 0.09) }, F.Model)
		local m = Instance.new("SpecialMesh")
		m.MeshType = Enum.MeshType.Sphere
		m.Parent = o
		ooze[i] = { P = o, A = ({ math.pi * 0.6, -math.pi * 0.6, math.pi })[i], Off = (i - 1) / 3 }   -- (sides and back: never over the face)
	end
	local bubbles = emitter(F.Brew, "Base", { Texture = SPARKLE, Color = K.Look.Brew, LightEmission = 0.6, Rate = 4,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.08), NumberSequenceKeypoint.new(0.6, 0.18),
			NumberSequenceKeypoint.new(1, 0) }), Life = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(0.8, 2),
		Spread = Vector2.new(35, 35), Dir = Enum.NormalId.Right })
	local steam = emitter(F.Brew, "Base", { Color = steamColor(), LightInfluence = 0.6, LightEmission = 0.1, Rate = 3,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 1.3) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.6),
			NumberSequenceKeypoint.new(1, 1) }), Life = NumberRange.new(1, 1.5), Speed = NumberRange.new(1, 2),
		Spread = Vector2.new(15, 15), Dir = Enum.NormalId.Right })
	local motes = emitter(F.Brew, "Glint", { Color = Color3.new(1, 1, 1):Lerp(K.Look.Brew, 0.35), Rate = 2,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.5, 0.24),
			NumberSequenceKeypoint.new(1, 0) }), Life = NumberRange.new(0.6, 1), Speed = NumberRange.new(1, 2.5),
		Spread = Vector2.new(60, 60), Dir = Enum.NormalId.Right, RotSpeed = NumberRange.new(-90, 90) })
	local rec = { F = F, Pack = p, Phase = "Launch", T0 = now(), Stir = 0, Spin = 0 }
	body(caster, "WBLaunch")                                      -- (the heave that releases it; lighter while it is away)
	FX.Rune(caster, 1.2)
	-- an EMBER TRAIL streams off its glowing vents the whole time it is away (the flight out, the hover, the flight home)
	local trail = {}
	for _, dpart in ipairs(F.Drips or {}) do
		trail[#trail + 1] = emitter(dpart, "Base", { Shape = "Dot", Color = K.Look.Ember, LightEmission = 0.45, Rate = 24,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.34), NumberSequenceKeypoint.new(0.6, 0.22), NumberSequenceKeypoint.new(1, 0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.7, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			Life = NumberRange.new(0.8, 1.3), Speed = NumberRange.new(0.4, 1.1), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, 1.2, 0) })
	end
	trail[#trail + 1] = emitter(F.Body, "Glint", { Color = K.Look.Glint, Rate = 9,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.3, 0.34), NumberSequenceKeypoint.new(1, 0) }),
		Life = NumberRange.new(0.5, 0.8), Speed = NumberRange.new(0.3, 1), Spread = Vector2.new(180, 180) })
	p.Away = rec
	local start = F.Root.CFrame
	-- CLAMPED ON: its belly pressed onto the crown of the target's head (sunk a hair: no gap under it), its feet down round
	-- the sides of the head, tipped a little toward the caster; `press` pushes it down further (the landing thud),
	-- `rattle` shakes it about the contact point
	local headT = target:FindFirstChild("Head")
	local SINK = 0.06
	local function crown()
		local hd = (headT and headT.Parent) and headT or torsoT
		return hd, (hd.CFrame * CFrame.new(0, hd.Size.Y * 0.5, 0)).Position
	end
	local function lockCF(press, rattle)
		local _, top = crown()
		local root = p.Char:FindFirstChild("HumanoidRootPart")
		local cp = root and root.Position or (top + Vector3.new(0, 0, 1))
		local flat = Vector3.new(cp.X, top.Y, cp.Z)
		local base = ((flat - top).Magnitude < 0.1) and CFrame.new(top) or CFrame.lookAt(top, flat)
		return base * CFrame.Angles(math.rad(-8), 0, 0) * (rattle or CFrame.new())
			* CFrame.new(0, BELLY - SINK - (press or 0), 0)
	end
	-- (on the target's own client, in first person, it would sit in their camera: hidden there, the way the Default
	-- hides its own pieces from a victim's view)
	local hidV = false
	local function hideForVictim(on)
		if on == hidV then return end
		hidV = on
		for _, d in ipairs(F.Model:GetDescendants()) do
			if d:IsA("BasePart") then d.LocalTransparencyModifier = on and 1 or 0
			elseif d:IsA("ParticleEmitter") or d:IsA("Light") then d.Enabled = not on end
		end
	end
	local function setOoze(show, t)
		local hd = crown()
		for _, o in ipairs(ooze) do
			if not show then
				o.P.Transparency = 1
			else
				local u = ((t * 0.55) + o.Off) % 1                    -- (each run creeps down, thins and starts again)
				local sc = math.max(0.4, hd.Size.X / 1.2)
				local rr, hw, Y = 0.5 * math.max(hd.Size.X, hd.Size.Z), 0.045 * sc, hd.Size.Y
				local rad, hy
				if u < 0.3 then                                       -- (over the crown's rounded edge)
					local k = u / 0.3
					rad, hy = rr * (0.55 + 0.45 * k) + hw, Y * (0.5 - 0.12 * k) + hw * (1 - k)
				else                                                  -- (straight down the side, on the surface)
					rad, hy = rr + hw, Y * (0.38 - 0.45 * (u - 0.3) / 0.7)
				end
				o.P.CFrame = hd.CFrame * CFrame.Angles(0, o.A, 0) * CFrame.new(0, hy, -rad)
				o.P.Size = Vector3.new(0.09, 0.12 + 0.16 * u, 0.09) * sc
				o.P.Transparency = 0.05 + 0.95 * math.max(0, (u - 0.75) / 0.25)
			end
		end
	end
	local function home()
		if p.Model.Parent then
			K.Husk(p.C, false)
			p.Steam.Enabled, p.Bubbles.Enabled = true, true
			if p.Glints then p.Glints.Enabled = true end
			p.Pulse = 1
			burstAt(mouth(p), 4, 4, 3, 70)
		end
		p.Away = nil
	end
	local fromCF, endAt, burst = nil, nil, false
	function rec.End(didBurst)
		if rec.Phase == "Launch" or rec.Phase == "Lock" then
			rec.Phase = didBurst and "Erupt" or "Return"
			if rec.Phase == "Return" then body(caster, "WBCatch") end      -- (home now: the body reaches up to catch it)
			burst = didBurst
			endAt = now()
			fromCF = F.Root.CFrame
		end
	end
	function rec.Kill()
		pcall(function() F.Model:Destroy() end)
		home()
	end
	H.updaters[rec] = function(dt)
		local t = now() - rec.T0
		if not F.Model.Parent then home() return false end
		if not p.Model.Parent and rec.Phase ~= "Return" then rec.End(false) end
		local stirK = 0
		if rec.Phase == "Launch" then
			-- the arc from the back down onto the target's head (the Default blob's 0.3 s throw)
			local k = math.clamp(t / 0.3, 0, 1)
			local to = lockCF()
			local pos = start.Position:Lerp(to.Position, easeOut(k)) + Vector3.new(0, math.sin(k * math.pi) * 2.5, 0)
			F.Root.CFrame = CFrame.new(pos) * (start - start.Position):Lerp(to - to.Position, easeOut(k))
				* CFrame.Angles(0, k * TAU, math.sin(k * math.pi) * 0.4)
			if k >= 1 then
				rec.Phase = "Lock"
				rec.Land = t
				local _, top = crown()
				burstAt(CFrame.new(top), 8, 5, 2, 160)                -- (THUD: brew splashes out from under it)
			end
		elseif rec.Phase == "Lock" then
			-- clamped on: it sits pressed onto the target's head (it follows the head), stirs itself faster as the
			-- countdown closes and rattles in place near the end; brew oozes out from under it down the head
			stirK = math.clamp(t / math.max(0.5, telegraph), 0, 1)
			local shake = (stirK > 0.8) and (stirK - 0.8) * 0.5 or 0
			local thud = math.clamp(1 - (t - (rec.Land or t)) / 0.22, 0, 1)
			local press = 0.16 * thud * thud                           -- (the landing squashes it down, then it settles)
			local rattle = CFrame.Angles((math.random() - 0.5) * shake, 0, (math.random() - 0.5) * shake)
			F.Root.CFrame = lockCF(press, rattle)
			local hd = crown()
			hideForVictim(target == Players.LocalPlayer.Character and (workspace.CurrentCamera.CFrame.Position - hd.Position).Magnitude < 2.5)
			setOoze(not hidV, t)
		elseif rec.Phase == "Erupt" then
			-- it heaves and spews (the Default draws the cloud), then turns for home
			local k = math.clamp((now() - endAt) / 0.35, 0, 1)
			F.Root.CFrame = fromCF * CFrame.new(0, 0.8 * math.sin(k * math.pi), 0) * CFrame.Angles(math.sin(k * math.pi) * 0.35, 0, 0)
			hideForVictim(false)
			setOoze(false)
			stirK = 1
			if not rec.Erupted then
				rec.Erupted = true
				burstAt(F.Root.CFrame * F.Mouth, 18, 8, 6, 50)
				F.Light.Brightness = 3
			end
			if k >= 1 then
				rec.Phase = "Return"
				body(caster, "WBCatch")                           -- (its 0.6 s flight home: the catch lands with it)
				endAt = now()
				fromCF = F.Root.CFrame
			end
		elseif rec.Phase == "Return" then
			-- homecoming: an arc back onto the back, refilled
			hideForVictim(false)
			setOoze(false)
			local k = math.clamp((now() - endAt) / 0.6, 0, 1)
			local to = p.Model.Parent and p.C.Root.CFrame or fromCF
			local pos = fromCF.Position:Lerp(to.Position, easeOut(k)) + Vector3.new(0, math.sin(k * math.pi) * 2, 0)
			F.Root.CFrame = CFrame.new(pos) * (fromCF - fromCF.Position):Lerp(to - to.Position, easeOut(k)) * CFrame.Angles(0, -k * TAU, 0)
			if k >= 1 then
				F.Model:Destroy()
				home()
				return false
			end
		end
		-- the stir: the ladle sweeps round the brew, faster and faster (0.4 -> 4 turns a second)
		if rec.Phase ~= "Return" then
			local turns = 0.4 + 3.6 * stirK * stirK
			rec.Spin += dt * turns * TAU
			local r = F.H * 0.16
			local ladle = F.Ladle:FindFirstChildOfClass("Weld")
			if ladle then
				ladle.C0 = CFrame.new(math.cos(rec.Spin) * r, F.Mouth.Y + F.H * 0.2, math.sin(rec.Spin) * r)
					* CFrame.Angles(0, -rec.Spin, math.rad(-22))
			end
			F.Light.Brightness = math.max(F.Light.Brightness - dt * 4, 0.6 + 1.6 * stirK)
			if bubbles then bubbles.Rate = (4 + 26 * stirK) * (bubbles:GetAttribute("Density") or 1) end
			if motes then motes.Rate = (1.5 + 4.5 * stirK) * (motes:GetAttribute("Density") or 1) end
			if steam then steam.Rate = (3 + 6 * stirK) * (steam:GetAttribute("Density") or 1) end
		end
		return true
	end
	return rec
end

----------------------------------------------------------------------------------------------------
-- ANTITOXIN VENT: a herb from the pouch into the brew, and a trail of ward-vapor round the head
----------------------------------------------------------------------------------------------------
--- ANTITOXIN VENT -- THE HERB IN THE BREW (owner round 6: nothing is worn on the face). The pouch on the cauldron's side
--- pops its flap open, a sprig of ward herb lifts out (a plain plant: a woody stem and green leaves -- no glow) and is
--- tossed in an arc into the cauldron's mouth; the BREW answers -- it flares, a ripple runs across it, bubbles pop, a puff
--- of vapor rises -- and for the Vent's length a thin trail of ward-vapor drifts up out of the cauldron, over the
--- shoulder and loosely round the head and collar, mist breaking off it, now and then a crescent glint (the "Vent is
--- active" tell). FX.VentEnd fades the trail and the flap closes. Called by ToxinFX's H.ToxinVent, which draws the
--- cleanse threads into the brew: returns { Mouth (fn: where they end), Arrive (fn: one landed -- the brew flares) }.
local function backOut(k) local c = 1.7 return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2 end
function FX.Vent(caster, duration)
	local p = FX.Pack(caster)
	local head = typeof(caster) == "Instance" and caster:FindFirstChild("Head")
	local sat = p and p.Satchel
	if not (sat and sat.FlapWeld and head) then return nil end
	body(caster, "WBHerb")                                        -- (the hand to the pouch, the herb flicked into the brew)
	if p.Vent then FX.VentEnd(caster, true) end                 -- (a re-cast: the old trail goes at once)
	FX.Rune(caster, 1)
	local rec = { T0 = now() }
	p.Vent = rec
	local S = sat.S
	local hs, hsx, hsz = head.Size.Y, head.Size.X, head.Size.Z
	local side = (head.CFrame:PointToObjectSpace(sat.Pouch.Position).X >= 0) and 1 or -1   -- (the pouch's side of the head)
	local up = Vector3.yAxis
	local herb, tossFrom, sinkAt = nil, nil, nil
	-- the trail's pieces, made when the herb lands
	local trail = nil
	local function makeTrail()
		local a0 = Instance.new("Attachment")
		a0.Name = "WB_Vapor"
		a0.Parent = p.C.Brew                                      -- (its Axis is up: the trail rises out of the brew)
		local hostA = anchoredHost(head.CFrame, H.fxFolder())
		local hostB = anchoredHost(head.CFrame, H.fxFolder())
		local a1 = Instance.new("Attachment")
		a1.Axis = Vector3.new(-side, 0, -0.35).Unit               -- (it arrives round the cheek, sweeping in across the mouth)
		a1.Parent = hostA
		local a2 = Instance.new("Attachment")
		a2.Axis = Vector3.new(side, 0, -0.35).Unit
		a2.Parent = hostB
		local col = K.Look.Steam                                  -- (the brew's lavender vapor: light enough to read on sky and floor)
		local b1 = beam(a0, a1, { Color = col, W0 = 0.42, W1 = 0.9, T = 1, C0 = 1.6, C1 = 0.8, LightInfluence = 0.3,
			LightEmission = 0.45, Texture = H.SMOKE, TextureMode = Enum.TextureMode.Wrap, TextureSpeed = 0.5, TextureLength = 1.6,
			Segments = 20 }, H.fxFolder())
		local b2 = beam(a0, a2, { Color = col, W0 = 0.3, W1 = 0.62, T = 1, C0 = 2.2, C1 = 0.8, LightInfluence = 0.3,
			LightEmission = 0.4, Texture = H.SMOKE, TextureMode = Enum.TextureMode.Wrap, TextureSpeed = 0.35, TextureLength = 2.0,
			Segments = 20 }, H.fxFolder())
		-- mist breaking off the trail's middle, wisps round the head and collar, now and then a crescent
		local midHost = anchoredHost(head.CFrame, H.fxFolder())
		local collar = anchoredHost(head.CFrame, H.fxFolder())
		collar.Size = Vector3.new(1.5 * hsx, 0.7 * hs, 1.4 * hsz)
		local mist = emitter(midHost, "Base", { Color = col, LightInfluence = 0.4, LightEmission = 0.35, Rate = 3,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.35), NumberSequenceKeypoint.new(1, 1.0) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Life = NumberRange.new(1.2, 1.8), Speed = NumberRange.new(0.1, 0.35), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, 0.3, 0) })
		local wisps = emitter(collar, "Base", { Color = col, LightInfluence = 0.4, LightEmission = 0.35, Rate = 5,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 0.95) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.25, 0.5), NumberSequenceKeypoint.new(1, 1) }),
			Life = NumberRange.new(1.4, 2.2), Speed = NumberRange.new(0.15, 0.4), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, 0.35, 0),
			RotSpeed = NumberRange.new(-20, 20) })
		-- THE VEIL: where the trails pour in, the vapor gathers thick over mouth and nose -- a dense core and a softer haze,
		-- locked to the head (it stays over the mouth as the wearer moves): it reads as the mouth covered by the brew's mist
		local veil = anchoredHost(head.CFrame, H.fxFolder())
		veil.Size = Vector3.new(0.95 * hsx, 0.42 * hs, 0.3 * hsz)
		local veilCore = emitter(veil, "Base", { Color = col, LightInfluence = 0.6, LightEmission = 0.15, Rate = 34, Locked = true,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.5, 0.75), NumberSequenceKeypoint.new(1, 0.95) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.12, 0.06),
				NumberSequenceKeypoint.new(0.7, 0.22), NumberSequenceKeypoint.new(1, 1) }),
			Life = NumberRange.new(0.7, 1.1), Speed = NumberRange.new(0.05, 0.15), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, 0.1, 0),
			RotSpeed = NumberRange.new(-25, 25) })
		local veilHaze = emitter(veil, "Base", { Color = col, LightInfluence = 0.5, LightEmission = 0.2, Rate = 10, Locked = true,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.9), NumberSequenceKeypoint.new(1, 1.5) }),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.2, 0.35), NumberSequenceKeypoint.new(1, 1) }),
			Life = NumberRange.new(1.0, 1.6), Speed = NumberRange.new(0.1, 0.25), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, 0.2, 0),
			RotSpeed = NumberRange.new(-15, 15) })
		if veilCore then veilCore.Brightness = 1.4 end
		if veilHaze then veilHaze.Brightness = 1.2 end
		-- under the swirl, a soft disc of the same mist hangs over the mouth (it faces the camera: covered from any side)
		local veilGui = nil
		local tx = K.Tex()
		if tx and tx.Dot then
			local bg = Instance.new("BillboardGui")
			bg.LightInfluence, bg.Brightness = 0.4, 1.15
			bg.Size = UDim2.new(1.3 * hsx, 0, 0.72 * hs, 0)
			bg.Adornee = veil
			bg.Parent = veil
			veilGui = Instance.new("ImageLabel")
			veilGui.BackgroundTransparency, veilGui.Size, veilGui.ImageContent, veilGui.ImageColor3, veilGui.ImageTransparency =
				1, UDim2.fromScale(1, 1), tx.Dot, col, 1
			veilGui.Parent = bg
		end
		local glints = emitter(collar, "Glint", { Shape = "Crescent", Color = K.Look.Glint, Rate = 1.2,
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.4, 0.24), NumberSequenceKeypoint.new(1, 0) }),
			Life = NumberRange.new(0.6, 1.0), Speed = NumberRange.new(0.2, 0.5), Spread = Vector2.new(180, 180), RotSpeed = NumberRange.new(-40, 40) })
		trail = { A0 = a0, A1 = a1, HostA = hostA, HostB = hostB, Mid = midHost, Collar = collar, Veil = veil, VeilGui = veilGui, B1 = b1, B2 = b2,
			Emit = { mist, wisps, veilCore, veilHaze, glints },
			Base = { 0.32, 0.46 }, Vis = 0 }
	end
	local function cleanup()
		if herb then pcall(function() herb.Model:Destroy() end) herb = nil end
		if trail then
			for _, x in ipairs({ trail.B1, trail.B2, trail.A0, trail.HostA, trail.HostB, trail.Mid, trail.Collar, trail.Veil }) do
				pcall(function() x:Destroy() end)
			end
			trail = nil
		end
	end
	H.updaters[rec] = function(dt)
		if p.Vent ~= rec or not (p.Model.Parent and head.Parent) then  -- (re-cast, or the wearer is gone)
			cleanup()
			if p.Vent == rec then p.Vent = nil end
			return false
		end
		local u = now() - rec.T0
		local c = p.C
		local brewCF = c.Root.CFrame * c.Mouth
		-- THE FLAP: pops open (with a little overshoot); after the end, once the trail has faded, it shuts again
		local open
		if rec.EndAt then
			local e = now() - rec.EndAt
			open = 1 - math.clamp((e - (rec.Fast and 0.15 or 0.6)) / 0.2, 0, 1)
			if not rec.Opened then open = math.min(open, math.clamp(u / 0.16, 0, 1)) end
		else
			open = backOut(math.clamp(u / 0.16, 0, 1))
			if u >= 0.16 then rec.Opened = true end
		end
		sat.FlapWeld.C0 = CFrame.new(sat.Hinge) * CFrame.Angles(math.rad(112) * open, 0, 0) * CFrame.new(-sat.Hinge) * sat.FlapRel
		-- THE HERB: lifts out of the pouch, then is tossed in an arc into the brew
		local pc = sat.Pouch.CFrame
		if u >= 0.1 and not herb and not rec.Landed and not rec.EndAt then
			herb = K.Herb(0.72 * S, H.fxFolder())
			if herb then herb.Root.CFrame = pc * CFrame.new(0, sat.TopY - 0.12 * S, 0) end   -- (in the pouch, never at the origin)
		end
		if herb and not rec.Landed then
			local inside = pc * CFrame.new(0, sat.TopY - 0.12 * S, 0)
			local lifted = pc * CFrame.new(0, sat.TopY + 0.3 * S, -0.06 * S)
			if u < 0.45 then
				local k = easeOut(math.clamp((u - 0.1) / 0.3, 0, 1))
				herb.Root.CFrame = inside:Lerp(lifted, k) * CFrame.Angles(0, 0, math.sin(u * 22) * 0.18 * (1 - k))
			else
				tossFrom = tossFrom or lifted.Position                -- (from the lift point: a hitch may have skipped the lift)
				local k = math.clamp((u - 0.45) / 0.45, 0, 1)
				local to = brewCF.Position + up * 0.04
				local arc = 0.9 + (to - tossFrom).Magnitude * 0.2
				local pos = tossFrom:Lerp(to, k) + up * (arc * 4 * k * (1 - k))
				herb.Root.CFrame = CFrame.new(pos) * CFrame.Angles(k * TAU * 1.1, k * 2.2, k * TAU * 0.6)
				if k >= 1 then
					-- THE BREW ANSWERS: it flares and briefly boils, a ripple crosses it, bubbles pop, vapor puffs up
					rec.Landed, sinkAt = true, now()
					p.Pulse = 1
					p.BoilUntil = math.max(p.BoilUntil, now() + 0.7)
					burstAt(brewCF, 10, 4, 0, 50)
					burstAt(brewCF * CFrame.new(0, 0.1, 0), 0, 0, 9, 25)
					local tx = K.Tex()
					if tx and tx.Ring then
						local rp = part2({ Name = "WB_Ripple", Transparency = 1, Size = Vector3.new(0.3, 0.02, 0.3) }, H.fxFolder())
						local im = surfaceImage(rp, Enum.NormalId.Top, tx.Ring, K.Look.Herb, 128)
						local r0, rk, dmax = now(), {}, c.Brew.Size.Y * 1.05
						H.updaters[rk] = function()
							local q = (now() - r0) / 0.5
							if q >= 1 or not rp.Parent or not c.Brew.Parent then pcall(function() rp:Destroy() end) return false end
							local dd = dmax * (0.15 + 0.85 * easeOut(q))
							rp.Size = Vector3.new(dd, 0.02, dd)
							rp.CFrame = c.Root.CFrame * c.Mouth * CFrame.new(0, c.Brew.Size.X * 0.5 + 0.01, 0)
							im.ImageTransparency = 0.1 + 0.9 * q
							return true
						end
					end
					makeTrail()
				end
			end
		end
		if herb and rec.Landed then                                -- (it sinks into the brew)
			local q = math.clamp((now() - sinkAt) / 0.12, 0, 1)
			herb.Root.CFrame = CFrame.new(brewCF.Position - up * 0.12 * q) * (herb.Root.CFrame - herb.Root.Position)
			if q >= 1 then pcall(function() herb.Model:Destroy() end) herb = nil end
		end
		-- THE WARD-VAPOR TRAIL: fades in after the brew answers, out at the end; out of the wearer's own first-person view
		if trail then
			local want = rec.EndAt and 0 or 1
			trail.Vis = math.clamp(trail.Vis + (want - trail.Vis) * math.min(1, dt * (rec.EndAt and (rec.Fast and 8 or 3) or 2.2)), 0, 1)
			local cam = workspace.CurrentCamera
			local near = caster == Players.LocalPlayer.Character and cam ~= nil and (cam.CFrame.Position - head.Position).Magnitude < 2
			local vis = near and 0 or trail.Vis
			local hc = head.CFrame
			trail.HostA.CFrame = hc * CFrame.new(side * 0.28 * hsx, -0.22 * hs, -0.62 * hsz)
			trail.HostB.CFrame = hc * CFrame.new(-side * 0.28 * hsx, -0.28 * hs, -0.6 * hsz)
			trail.Collar.CFrame = hc * CFrame.new(0, -0.3 * hs, 0)
			trail.Veil.CFrame = hc * CFrame.new(0, -0.2 * hs, -0.58 * hsz)
			local P0, P3 = trail.A0.WorldPosition, trail.HostA.Position
			local C1 = P0 + trail.A0.WorldAxis * trail.B1.CurveSize0
			local C2 = P3 - trail.A1.WorldAxis * trail.B1.CurveSize1       -- (the beam's own bezier)
			trail.Mid.CFrame = CFrame.new(P0 * 0.125 + C1 * 0.375 + C2 * 0.375 + P3 * 0.125)
			trail.B1.Transparency = NumberSequence.new(1 - (1 - trail.Base[1]) * vis)
			trail.B2.Transparency = NumberSequence.new(1 - (1 - trail.Base[2]) * vis)
			for i, e in ipairs(trail.Emit) do
				if e then e.Rate = ({ 4, 7, 34, 10, 1.2 })[i] * vis * (e:GetAttribute("Density") or 1) end
			end
			if trail.VeilGui then                                     -- (the mist disc breathes a little)
				trail.VeilGui.ImageTransparency = 1 - 0.95 * vis * (0.93 + 0.07 * math.sin(now() * 3))
			end
		end
		-- done: the trail has faded and the flap is shut
		if rec.EndAt and open <= 0 and (not trail or trail.Vis <= 0.01) then
			sat.FlapWeld.C0 = sat.FlapRel
			cleanup()
			p.Vent = nil
			return false
		end
		return true
	end
	return {
		Mouth = function() return (p.Model.Parent and p.C.Brew.Parent) and (p.C.Root.CFrame * p.C.Mouth).Position or nil end,
		Arrive = function() if rec.Landed then p.Pulse = math.max(p.Pulse, 0.7) end end,
	}
end
--- The Vent is over (its time ran out, a re-cast, a clear): the trail fades, then the flap closes. `fast`: quickly.
function FX.VentEnd(caster, fast)
	local p = packs[caster]
	local rec = p and p.Vent
	if not rec or rec.EndAt then return end
	rec.EndAt, rec.Fast = now(), fast and true or false
end

----------------------------------------------------------------------------------------------------
-- ACID RAIN: the cauldron boils over and flings bubbles
----------------------------------------------------------------------------------------------------
--- ACID RAIN (replaces the Default's cloud and rain for a wearer): the cauldron tips back and BOILS OVER -- its surface
--- seething with bubbles, steam pouring off -- and flings brew BUBBLES up out of it: translucent, shining, each with a
--- faint glowing heart; they arc over and come down across the zone (the Default rain's radius and window) and POP on
--- the ground in a splash, a fizz ring and a few glints. `fin` = gather + rainTime (when the Default rain stops).
function FX.AcidRain(caster, center, height, R, gather, rainTime, t0)
	local p = FX.Pack(caster)
	if not p then return false end
	t0 = t0 or now()                                              -- (ToxinFX's backdated start, on the same fx clock)
	local fin = gather + (rainTime or 4)
	p.TipAngle = 30
	p.TipUntil = t0 + fin - 0.2
	body(caster, "WBTip")                                         -- (leaning back with the tipping pot)
	p.BoilUntil = t0 + fin
	burstAt(mouth(p), 8, 3, 6, 25)
	FX.Rune(caster, 1.1)
	local tx = K.Tex()
	-- the impact: a SHIMMER RING (the painted ring, flat on the floor, opening out and fading) and a few glints
	local function shimmer(at, dd)
		burstAt(CFrame.new(at + Vector3.new(0, 0.15, 0)), 4, 4, 1, 70)
		if not (tx and tx.Ring) then return end
		local rp = part2({ Name = "WB_Shimmer", Transparency = 1, Size = Vector3.new(dd, 0.05, dd) }, H.fxFolder())
		rp.CFrame = CFrame.new(at + Vector3.new(0, 0.07, 0))
		local im = surfaceImage(rp, Enum.NormalId.Top, tx.Ring, K.Look.Glint, 128)
		local r0, rk = now(), {}
		H.updaters[rk] = function()
			local k = (now() - r0) / 0.4
			if k >= 1 or not rp.Parent then
				pcall(function() rp:Destroy() end)
				return false
			end
			local w = dd * (0.5 + 2.4 * easeOut(k))
			rp.Size = Vector3.new(w, 0.05, w)
			im.ImageTransparency = 0.05 + 0.95 * k
			im.Rotation = k * 30
			return true
		end
	end
	local dn = H.density()
	local lastMouth = mouth(p)
	-- each bubble is planned by when it LANDS: from the Default rain's first drop (gather * 0.8) to its last (fin), at
	-- ~14 a second; it leaves the cauldron one flight-time earlier (or now, if that is already past)
	local live = {}
	local nextLand = t0 + gather * 0.8
	local lastLand = t0 + fin
	local key = {}
	H.updaters[key] = function()
		local t = now()
		if p.Model.Parent then lastMouth = mouth(p) end
		while nextLand <= lastLand do
			local a, rr = math.random() * TAU, math.sqrt(math.random()) * R
			local land = center + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr)
			local from = lastMouth.Position + Vector3.new((math.random() - 0.5) * 0.4, 0.2, (math.random() - 0.5) * 0.4)
			local dist = (Vector3.new(land.X, 0, land.Z) - Vector3.new(from.X, 0, from.Z)).Magnitude
			local dur = math.clamp(0.85 + dist / 45, 0.85, 1.7)
			if nextLand - dur > t then break end                  -- (not time to launch it yet)
			land = Vector3.new(land.X, groundAt(land), land.Z)
			local start = math.max(t, nextLand - dur)
			local bb = K.Bubble(H.fxFolder())
			local dd = 1.1 + math.random() * 0.8
			-- (about a third of them carry the kit's star glint, twinkling on the bubble)
			local star = (tx and tx.Star and math.random() < 0.35) and sprite(bb.Skin, tx.Star, K.Look.Glint, 0.55 * dd,
				Vector3.new(0.3 * dd, 0.3 * dd, 0)) or nil
			live[#live + 1] = { B = bb, Star = star, From = from, To = land, T0 = start, Dur = math.max(0.35, nextLand - start),
				Hgt = 5 + dist * 0.12 + math.max(0, land.Y - from.Y), D = dd, Wob = math.random() * 10 }
			nextLand += 1 / (14 * dn)
		end
		for i2 = #live, 1, -1 do
			local q = live[i2]
			local u = (t - q.T0) / q.Dur
			if u >= 1 then
				-- POP: a shimmer ring and glints (no flat splat)
				shimmer(q.To, q.D)
				q.B.Model:Destroy()
				table.remove(live, i2)
			else
				local uu = math.max(0, u)
				local pos = q.From:Lerp(q.To, uu) + Vector3.new(0, 4 * q.Hgt * uu * (1 - uu), 0)
				local wob = math.sin((t - q.T0) * 11 + q.Wob) * 0.07
				K.PlaceBubble(q.B, pos, q.D * (0.7 + 0.3 * math.min(1, uu * 3)) * (1 + wob), 0)
				if q.Star then
					q.Star.I.Rotation = (t - q.T0) * 140
					q.Star.I.ImageTransparency = 0.05 + 0.35 * (0.5 + 0.5 * math.sin((t - q.T0) * 9 + q.Wob))
				end
			end
		end
		return nextLand <= lastLand or #live > 0
	end
	return true
end
--- One brew raindrop (unused since the bubbles; kept for the API).
function FX.RainDrop(parent)
	return K.Drop(parent)
end

return FX

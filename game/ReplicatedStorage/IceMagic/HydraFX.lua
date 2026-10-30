--[[
	HydraFX  (ModuleScript)  ->  ReplicatedStorage/IceMagic/HydraFX

	Toxin's HYDRA (2026-10-21; the MYTHIC Element skin): one venomous many-headed serpent, performed across all six of
	Toxin's slots on the Default's own beats. ToxinFX calls in through its skin table (BREW: Init once, then one call per
	hook, each pcall-wrapped there), gated on HydraKit.On + Built; until then, or on any fault, the Default draws. Every
	number it times itself by is read from ToxinTuning; none is changed. Every piece is made of HydraKit's part classes
	(Scale, Coil, Fang, Frill, Glow, Core), so the same creature reads in every ability.
	RESTING PRESENCE: one head coiled up out of the right shoulder blade, dormant (a slow breath, its core dim), and the
	Vent's helm: its back half worn, its faceplate standing raised above the forehead (a visor flipped up). The Ultimate's three heads and Acid Rain's small heads come out
	only on the cast. All of it is hidden in the wearer's own first-person view.
	The performed beat, per ability:
	  M1 Toxic Bubbles        BITE-AND-SPIT: on the throw the shoulder head snaps forward down the aim, jaw wide, and spits
	                          the venom glob (glass round a glowing core); it bursts where the sac would, scorching
	  Primary Corrosive Cloud WIND-UP-AND-EXHALE: the shoulder head rears back (0.18 s), then breathes the miasma out at the
	                          cloud's heart for the rest of FormTime; the ground etches and bubbles, shed scales and
	                          glints drift through the gas
	  Passive Symbiosis       PULSE-AND-GLOW: a thin venom thread runs from the enemy into the shoulder head's mouth; it
	                          gulps and a light runs down the throat vein, head to shoulder (the creature feeding)
	  Ultimate Patient Zero   STRIKE-COIL-STRIKE: three heads burst out of the ground round the target and bite (0.3 s) --
	                          the bite delivers the mark: a glyph on the wound hinges down into the sigil ring; through the
	                          countdown the necks coil round the target and tighten on the Default's beat (0.6 -> 1.8 ->
	                          4.6 Hz); at the fuse they rear high and at the burst strike down together as the Default's
	                          cloud erupts (its flash stays out)
	  Antitoxin Vent          HINGE-CLOSE: the helm (hydra-themed armour, its back half worn always) closes: the faceplate --
	                          ONE rigid piece on ONE hinge at the top front of the head -- swings down in front of the face
	                          in AssembleTime until flush, enclosing the head, holds for the whole Duration (its narrow
	                          face-slit lit throughout), then swings back up to stand above the forehead
	  Acid Rain               EMERGE-AND-SPIT: inside the 0.7 s GatherTime three small heads come up out of the back beside
	                          the shoulder head, all four spit venom up into the Default's cloud and sink back; it comes
	                          down as fang-spines on the Default's rain window, sticking and corroding; a struck enemy's
	                          scales crack and glow with their Corroded stacks
	  Kill effect             THE HYDRA'S DUE: three heads rise round the fallen and strike down together (HydraKillHook)
	Glow: a Neon venom core in every head and the glob (Core), Neon edge ribbons on the hard edges -- brows, joint seams,
	eye-slits, the throat vein (Glow). Particles: BASE (steam, the breath) scales with Graphics Quality; FLECK (venom drops,
	shed scales: HydraFlecks) and GLINT (four-point glints off the scales: HydraGlints, halved under Reduce Flashing) sit on
	their own switches and scale the same way. FX.Stats counts all three.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local FX = {}
FX.Stats = { Base = 0, Fleck = 0, Glint = 0 }
local H, K, T = nil, nil, nil
local rigs = {}                               -- [character] = the resting creature on its wearer
local live = setmetatable({}, { __mode = "k" }) -- [emitter] = layer (continuous ones, integrated per frame)
local TAU = math.pi * 2
local started = false

local function now() return H.fxNow() end
local function easeOut(k) return 1 - (1 - k) * (1 - k) end
local function easeIn(k) return k * k end
local function smooth(k) k = math.clamp(k, 0, 1) return k * k * (3 - 2 * k) end
local function backOut(k) local c = 1.7 return 1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2 end

-- an emitter on `parent`: the BASE layer always (scaled by Graphics Quality); the FLECK and GLINT layers only while their
-- switches are on (scaled the same way). Shapes: "Flake" (shed scales), "Dot" (droplets), "Glint"; else the Default smoke
local function emitter(parent, layer, o)
	if layer == "Fleck" and not K.FlecksOn() then return nil end
	if layer == "Glint" and not K.GlintsOn() then return nil end
	local e = Instance.new("ParticleEmitter")
	e.Name = "HY_" .. layer
	local tx = K.Tex()
	if tx and o.Shape and tx[o.Shape] then e.TextureContent = tx[o.Shape] else e.Texture = o.Texture or H.SMOKE end
	e.Color = ColorSequence.new(o.Color or K.Look.Dust)
	e.LightInfluence = o.LightInfluence or 1
	e.LightEmission = o.LightEmission or 0
	e.Size = o.Size or NumberSequence.new(0.2)
	e.Transparency = o.Transparency or NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.2),
		NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = o.Life or NumberRange.new(0.6, 1)
	e.Speed = o.Speed or NumberRange.new(0.5, 1)
	e.SpreadAngle = o.Spread or Vector2.new(25, 25)
	e.Acceleration = o.Accel or Vector3.zero
	e.Rotation = NumberRange.new(0, 360)
	e.RotSpeed = o.RotSpeed or NumberRange.new(-60, 60)
	e.EmissionDirection = o.Dir or Enum.NormalId.Top
	e.LockedToPart = o.Locked or false
	if o.Drag then e.Drag = o.Drag end
	local d = H.density()
	e.Rate = (o.Rate or 0) * d
	e:SetAttribute("Density", d)
	e:SetAttribute("Layer", layer)
	e.Parent = parent
	if e.Rate > 0 then live[e] = layer end
	return e
end
local function emit(e, n)
	if not (e and n and n > 0) then return end
	local k = math.max(1, math.floor(n * (e:GetAttribute("Density") or 1) + 0.5))
	e:Emit(k)
	local layer = e:GetAttribute("Layer") or "Base"
	FX.Stats[layer] = (FX.Stats[layer] or 0) + k
end

local function part2(props, parent)                             -- (an anchored, non-colliding piece)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for k, v in pairs(props) do p[k] = v end
	p.Parent = parent or H.fxFolder()
	return p
end
local function anchoredHost(cf, parent)
	local p = part2({ Name = "HY_Host", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2) }, parent)
	p.CFrame = cf
	return p
end
-- a one-shot puff at `cf`: Rare droplets/chips (Fleck) and a little Base steam
-- a puff source: one host, re-aimed before each burst, with its droplet (Rare layer) and steam (Base) emitters made on
-- first use -- a piece that puffs many times (the cloud's beads, the rain's spines) keeps two emitters, not two a puff.
-- p.At(cf, fleck, steam, spread, speed) bursts; p.Done() lets the last particles finish, then clears it.
local function puffer(color)
	local h = anchoredHost(CFrame.new())
	local fl, st
	local p = {}
	function p.At(cf, fleck, steam, spread, speed)
		h.CFrame = cf
		if fleck and fleck > 0 then
			fl = fl or emitter(h, "Fleck", { Shape = "Dot", Color = color or K.Look.Venom, LightInfluence = 0.6,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0.03) }),
				Life = NumberRange.new(0.35, 0.6), Accel = Vector3.new(0, -26, 0) })
			if fl then
				fl.Speed = speed or NumberRange.new(4, 8)
				fl.SpreadAngle = Vector2.new(spread or 55, spread or 55)
				emit(fl, fleck)
			end
		end
		if steam and steam > 0 then
			st = st or emitter(h, "Base", { Color = K.Look.Dust:Lerp(Color3.fromRGB(150, 150, 110), 0.5), LightInfluence = 0.8,
				Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1.0) }),
				Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
				Life = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.8, 2), Spread = Vector2.new(30, 30) })
			emit(st, steam)
		end
	end
	function p.Done() task.delay(2, function() h:Destroy() end) end
	return p
end
local function puffAt(cf, fleck, steam, color, spread, speed)
	local p = puffer(color)
	p.At(cf, fleck, steam, spread, speed)
	p.Done()
end
-- shed scale chips flung from `cf` (the Rare layer)
local function chipsAt(cf, n, speed, spread)
	local h = anchoredHost(cf)
	local e = emitter(h, "Fleck", { Shape = "Flake", Color = K.Look.Scale:Lerp(K.Look.ScaleEdge, 0.5), LightInfluence = 1,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.22), NumberSequenceKeypoint.new(1, 0.12) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.8, 0.1), NumberSequenceKeypoint.new(1, 1) }),
		Life = NumberRange.new(0.6, 1.0), Speed = speed or NumberRange.new(6, 12), Spread = Vector2.new(spread or 60, spread or 60),
		Accel = Vector3.new(0, -34, 0), RotSpeed = NumberRange.new(-360, 360) })
	emit(e, n)
	task.delay(2, function() h:Destroy() end)
end

-- the floor under `pos` (characters and the effects ignored; `skip` too, and then the ray starts at `pos`)
local rayParams = nil
local function groundAt(pos, skip)
	if not rayParams then
		rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
	end
	local ex = { H.fxFolder(), workspace.CurrentCamera }
	for _, plr in ipairs(Players:GetPlayers()) do if plr.Character then ex[#ex + 1] = plr.Character end end
	if skip then ex[#ex + 1] = skip end
	rayParams.FilterDescendantsInstances = ex
	local hit = workspace:Raycast(pos + Vector3.new(0, skip and 0 or 6, 0), Vector3.new(0, -40, 0), rayParams)
	return hit and hit.Position.Y or (pos.Y - 3)
end
-- a self-lit painted image on `host`'s `face` (its lines glow: LightInfluence 0)
local function surfaceImage(host, face, content, color, canvas, brightness)
	local sg = Instance.new("SurfaceGui")
	sg.Face = face
	sg.LightInfluence, sg.Brightness = 0, brightness or 1.5
	sg.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	sg.CanvasSize = Vector2.new(canvas or 256, canvas or 256)
	sg.Parent = host
	local im = Instance.new("ImageLabel")
	im.BackgroundTransparency, im.Size, im.ImageContent, im.ImageColor3 = 1, UDim2.fromScale(1, 1), content, color
	im.AnchorPoint, im.Position = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5)
	im.Parent = sg
	return im, sg
end
local function torsoOf(c) return c and (c:FindFirstChild("UpperTorso") or c:FindFirstChild("Torso")) end
local function nearCam(pos, r)
	local cam = workspace.CurrentCamera
	return cam ~= nil and (cam.CFrame.Position - pos).Magnitude < (r or 1.6)
end
local function setLTM(parts, v) for _, p in ipairs(parts) do p.LocalTransparencyModifier = v end end
-- a uniform Catmull-Rom curve through `P` (s 0..1, end to end)
local function catmull(P)
	local n = #P
	return function(s)
		local f = math.clamp(s, 0, 1) * (n - 1)
		local i = math.min(n - 1, math.floor(f) + 1)
		local t = f - (i - 1)
		local p0, p1, p2, p3 = P[math.max(1, i - 1)], P[i], P[i + 1], P[math.min(n, i + 2)]
		local t2, t3 = t * t, t * t * t
		return 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
	end
end

----------------------------------------------------------------------------------------------------
-- THE CREATURE ON ITS WEARER (the resting presence): one head coiled up out of the right shoulder blade, dormant (a slow
-- breath, its core dim) until an ability wakes it, and the faceplate raised behind the head as a crest. The Ultimate's
-- and Acid Rain's heads come out only on the cast. In the wearer's own first-person view all of it is hidden.
----------------------------------------------------------------------------------------------------
local RIG = { Neck = 0.85, Head = 0.88, Plates = 5 }
local function basis(r)
	local cf = r.UT.CFrame
	return cf, cf.LookVector, cf.UpVector, cf.RightVector
end
local POSES = {}
-- each pose: the neck's 4 points (shoulder blade to the head's hinge) and the jaw; `r.Aim` (a unit vector) aims a strike
function POSES.Rest(r, tau)
	local cf, fwd, up, right = basis(r)
	local hp = r.Head.Position
	local base = cf.Position + right * (r.UT.Size.X * 0.3) + up * (r.UT.Size.Y * 0.3) - fwd * (r.UT.Size.Z * 0.42)
	local breath = math.sin(tau * 1.4 + r.Seed) * 0.04
	-- (2026-10-23: the v2 head is bigger -- it rides beside and a little above the wearer's head, as in Blender's rest)
	return { base, base + up * 0.35 + right * 0.22 - fwd * 0.12, base + up * (1.05 + breath) + right * 0.6 - fwd * 0.1,
		hp + right * 1.1 + up * (0.6 + breath) }, 0.02 + 0.02 * math.max(0, math.sin(tau * 1.4 + r.Seed))
end
function POSES.Spit(r, tau)                                       -- (the M1: snap forward down the aim, jaw wide, spit)
	local P = POSES.Rest(r, 0)
	local aim = r.Aim or basis(r).LookVector
	local k = tau < 0.09 and backOut(tau / 0.09) or 1
	P[3] += aim * 0.3 * k
	P[4] += aim * 0.75 * k
	return P, (tau < 0.2) and 0.85 * math.min(1, tau / 0.05) or 0.85 * (1 - math.min(1, (tau - 0.2) / 0.15))
end
function POSES.Rear(r, tau)                                       -- (the Primary's wind-up: back and up, jaw parting)
	local cf, fwd, up, right = basis(r)
	local P = POSES.Rest(r, 0)
	local k = smooth(tau / 0.16)
	P[3] = P[3]:Lerp(P[1] + up * 1.15 + right * 0.35 - fwd * 0.25, k)
	P[4] = P[4]:Lerp(r.Head.Position + right * 0.72 + up * 0.85 - fwd * 0.35, k)
	return P, 0.25 * k
end
function POSES.Exhale(r, tau)                                     -- (the Primary's release: thrust at the cloud, jaw wide)
	local P = POSES.Rest(r, 0)
	local aim = r.Aim or basis(r).LookVector
	local k = backOut(math.min(1, tau / 0.12))
	P[3] += aim * 0.28 * k
	P[4] += aim * 0.7 * k
	return P, 0.95
end
function POSES.Fire(r, tau)                                       -- (Acid Rain: up at the sky over the area, a spit)
	local cf, fwd, up, right = basis(r)
	local P = POSES.Rest(r, 0)
	local aim = r.Aim or up
	local k = smooth(tau / 0.16)
	P[3] = P[3]:Lerp(P[1] + up * 0.95 + right * 0.3, k)
	P[4] = P[4]:Lerp(P[3] + aim * 0.7 + up * 0.35, k)
	local spat = r.SpitAt and (now() - r.SpitAt) or -1
	return P, (spat >= 0 and spat < 0.2) and 0.9 or 0.15 * k
end
function POSES.Gulp(r, tau)                                       -- (Symbiosis: a swallow as the thread arrives)
	local P, jaw = POSES.Rest(r, tau)
	return P, jaw + 0.35 * math.sin(math.clamp(tau / 0.3, 0, 1) * math.pi)
end

-- THE BAKED SHOULDER CLIPS (2026-10-23, the approved Blender animations): each pose is a clip of HydraAnimData, anchored
-- on the UpperTorso (Rest loops every 9 s); the Cloud's wind-up and release are one clip (Exhale); the gulp's clip is
-- joined 0.12 s in, at the thread's arrival
local BAKED = { Rest = "Rest", Spit = "Spit", Rear = "Exhale", Exhale = "Exhale", Gulp = "Gulp", Fire = "Fire" }
local BAKED_IN = { Gulp = 0.12 }
local function rigPose(char, pose, dur, back)                      -- (`back`: seconds before it settles to Rest by itself)
	local r = rigs[char]
	if not r then return nil end
	if r.Baked and pose ~= "Rest" and BAKED[pose] == BAKED[r.Pose] then
		r.BackAt = back and (now() + back) or r.BackAt
		return r
	end
	local t = now()
	r.From = { Name = r.Pose, T0 = r.PoseT0 }
	r.Pose, r.PoseT0, r.BlendT0, r.BlendDur = pose, t, t, dur or 0.12
	r.BackAt = back and (t + back) or nil
	return r
end

-- THE CASTER'S BODY (2026-10-23): the CastPose clip that performs with the creature (CastPose.Clips.Hydra*, generated
-- from the Blender animation's hydra_body.py and timed to it), started from the same hook as the creature's beat.
-- Required on first use (CastPose requires VFXLibrary, which may require this module). Cosmetic: CastPose writes are
-- client-side, every client poses every caster.
local castPose = nil
local function body(char, clip)
	if castPose == nil then
		local ice = game:GetService("ReplicatedStorage"):FindFirstChild("IceMagic")
		local m = ice and ice:FindFirstChild("CastPose")
		local ok, mod = pcall(function() return m and require(m) end)
		castPose = (ok and mod and mod.Clips and mod.Clips.HydraSpit) and mod or false
	end
	if not (castPose and char) then return end
	if clip == "HydraGulp" and castPose.CurrentClip and castPose.CurrentClip(char) ~= nil then return end   -- (the passive yields)
	pcall(castPose.Play, char, clip)
end

-- ONE HEAD, LIT (every head in the kit is made here): its venom gem and throat crystal (Core, Neon) carry a PointLight and
-- a soft core glow -- the luminous core -- and glitter motes drift off its scales (the Glint layer, on its own switch,
-- halved under Reduce Flashing)
local function newHead(scale)
	local h = K.Head(scale, H.fxFolder())
	if not h then return nil end
	local L = Instance.new("PointLight")
	L.Color, L.Range, L.Brightness, L.Shadows = K.Look.Core, 4.5 * scale, 1.25, false
	L.Parent = h.Core
	h.Light = L
	h.CoreGlow = emitter(h.Core, "Base", { Shape = "Dot", Color = K.Look.Core, LightInfluence = 0, LightEmission = 1, Rate = 6,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45 * scale), NumberSequenceKeypoint.new(1, 0.8 * scale) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Life = NumberRange.new(0.4, 0.6), Speed = NumberRange.new(0, 0.05), Spread = Vector2.new(180, 180), Locked = true })
	h.Motes = emitter(h.Skull.G.Scale, "Glint", { Shape = "Glint", Color = K.Look.Eye, LightInfluence = 0, LightEmission = 0.8, Rate = 3,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.03), NumberSequenceKeypoint.new(0.35, 0.2 * scale + 0.08), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.05), Life = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.1, 0.4), Spread = Vector2.new(180, 180) })
	if h.Motes and H.calm() then h.Motes.Rate *= 0.5 end
	return h
end

--- A BAKED CLIP's creatures (HydraAnimData): per creature in the clip, a lit head (newHead: its core's light and glow, its
--- motes) and its neck segments. { Clip, Items = { { Pc, Set } }, Heads, All (every part), Destroy }; nil if not built.
local function bakedRig(name, keep)
	local clip = K.Clip(name)
	if not clip then return nil end
	local rig = { Clip = clip, Items = {}, Heads = {}, All = {}, Models = {}, ByName = {} }
	for _, pc in ipairs(clip.Pieces) do
		local who, what = string.match(pc.Name, "^(.-)_(.+)$")
		rig.ByName[pc.Name] = pc
		if keep and not keep(pc.Name) then
			-- (not this rig's piece)
		elseif what == "Skull" or what == "Jaw" then
			local hd = rig.Heads[who]
			if not hd then
				hd = newHead(1)
				if not hd then return nil end
				rig.Heads[who] = hd
				rig.Models[#rig.Models + 1] = hd.Model
				for _, q in ipairs(hd.Parts) do rig.All[#rig.All + 1] = q end
			end
			rig.Items[#rig.Items + 1] = { Pc = pc, Set = (what == "Skull") and hd.Skull or hd.Jaw }
		else
			local piece = K.Piece(pc.Asset, H.fxFolder())
			if not piece then return nil end
			rig.Models[#rig.Models + 1] = piece.Model
			for _, q in ipairs(piece.Parts) do rig.All[#rig.All + 1] = q end
			rig.Items[#rig.Items + 1] = { Pc = pc, Set = piece.Set }
		end
	end
	function rig.Place(anchor, t, lift, parts, cfs)               -- (every piece at clip time t, sunk `lift` studs)
		local down = CFrame.new(0, -(lift or 0), 0)
		for _, it in ipairs(rig.Items) do
			local cf, sc = K.Sample(it.Pc, clip, t)
			K.PlaceSet(it.Set, down * anchor * cf, sc, parts, cfs)
		end
	end
	function rig.Destroy()
		for _, m in ipairs(rig.Models) do pcall(function() m:Destroy() end) end
	end
	function rig.Mouth(anchor, who, t)                            -- (a head's mouth at clip time t)
		local pc = rig.ByName[who .. "_Skull"]
		if not pc then return nil end
		local cf, sc = K.Sample(pc, clip, t)
		return (anchor * cf * CFrame.new(0, -0.05 * sc.X, -0.85 * sc.X)).Position
	end
	return rig
end

--- THE SHOULDER HEAD, baked: its neck segments (one piece each, in the Rest clip's order: shoulder blade to head) and a
--- lit head; neck.Map names every piece's set for the clips. nil if the clips or the meshes are not there (then the
--- procedural creature draws).
local function bakedShoulder()
	local clip = K.Clip("Rest")
	if not clip then return nil end
	local hd = newHead(1)
	if not hd then return nil end
	local model = Instance.new("Model")
	model.Name = "HydraNeck"
	local neck = { Model = model, Segs = {}, Parts = {}, S = 1, Map = { Shoulder_Skull = hd.Skull, Shoulder_Jaw = hd.Jaw } }
	for _, pc in ipairs(clip.Pieces) do
		local what = string.match(pc.Name, "^Shoulder_(.+)$")
		if what and what ~= "Skull" and what ~= "Jaw" then
			local piece = K.Piece(pc.Asset, model)
			if not piece then pcall(function() hd.Model:Destroy() model:Destroy() end) return nil end
			neck.Segs[#neck.Segs + 1] = { Set = piece.Set, Vein = piece.Set.G.Glow, W = 1 }
			neck.Map[pc.Name] = piece.Set
			for _, q in ipairs(piece.Parts) do neck.Parts[#neck.Parts + 1] = q end
		end
	end
	model.Parent = H.fxFolder()
	return neck, hd
end
local shoulderCache = {}
local function shoulderOf(name)                                   -- (a clip's shoulder pieces, by name)
	local c = shoulderCache[name]
	if c then return c end
	local clip = K.Clip(name)
	if not clip then return nil end
	c = { Clip = clip, List = {}, ByName = {} }
	for _, pc in ipairs(clip.Pieces) do
		if string.sub(pc.Name, 1, 9) == "Shoulder_" then c.List[#c.List + 1] = pc c.ByName[pc.Name] = pc end
	end
	shoulderCache[name] = c
	return c
end

local function dropRig(char)
	local r = rigs[char]
	if not r then return end
	rigs[char] = nil
	H.updaters[r] = nil
	pcall(function() r.Neck.Model:Destroy() r.Hd.Model:Destroy() r.Helm.Model:Destroy() end)
	for _, p in ipairs(r.Hidden or {}) do pcall(function() p.LocalTransparencyModifier = 0 end) end
end

local function buildRig(char)
	local ut = char:FindFirstChild("UpperTorso") or char:FindFirstChild("Torso")
	local head = char:FindFirstChild("Head")
	if not (ut and head) then return nil end
	local neck, hd = bakedShoulder()
	local baked = neck ~= nil
	if not baked then
		neck = K.Neck(RIG.Neck, RIG.Plates, H.fxFolder())
		hd = newHead(RIG.Head)
	end
	local helm = K.Helm(1, H.fxFolder())
	if not (neck and hd and helm) then
		pcall(function() neck.Model:Destroy() hd.Model:Destroy() helm.Model:Destroy() end)
		return nil
	end
	local r = { Char = char, UT = ut, Head = head, Neck = neck, Hd = hd, Helm = helm, Pose = "Rest", PoseT0 = now(), BlendT0 = 0,
		BlendDur = 0.2, Seed = math.random() * 10, SkullOpen = 1, Feed = 0, Shown = nil, KGen = K.Gen, Baked = baked }
	-- the helm's eye-slits light the face while it is shut, glitter motes along them
	r.SlitLight = Instance.new("PointLight")
	r.SlitLight.Color, r.SlitLight.Range, r.SlitLight.Brightness, r.SlitLight.Shadows = K.Look.Eye, 3, 0.3, false
	r.SlitLight.Parent = helm.Slit
	r.HelmMotes = emitter(helm.Slit, "Glint", { Shape = "Glint", Color = K.Look.Eye, LightInfluence = 0, LightEmission = 0.8, Rate = 5,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.03), NumberSequenceKeypoint.new(0.35, 0.2), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.05), Life = NumberRange.new(0.4, 0.7), Speed = NumberRange.new(0.1, 0.3), Spread = Vector2.new(180, 180) })
	if r.HelmMotes then r.HelmMotes.Enabled = false end
	local all = {}
	for _, p in ipairs(neck.Parts) do all[#all + 1] = p end
	for _, p in ipairs(hd.Parts) do all[#all + 1] = p end
	for _, p in ipairs(helm.Parts) do all[#all + 1] = p end
	-- the helm encloses the head: hats and hair would poke through it -- hidden under it, on every client (restored when it goes)
	r.Hidden = {}
	for _, acc in ipairs(char:GetChildren()) do
		local hd2 = acc:IsA("Accessory") and acc:FindFirstChild("Handle")
		local w = hd2 and hd2:FindFirstChildWhichIsA("Weld")
		if w and (w.Part0 == head or w.Part1 == head) then hd2.LocalTransparencyModifier = 1 table.insert(r.Hidden, hd2) end
	end
	r.All = all
	r.Calm = H.calm()
	local parts, cfs = {}, {}
	H.updaters[r] = function(dt)
		if not (char.Parent and ut.Parent and head.Parent and neck.Model.Parent) then
			dropRig(char)
			return false
		end
		local tn = now()
		if r.BackAt and tn >= r.BackAt then rigPose(char, "Rest", 0.25) end
		local w = math.clamp((tn - r.BlendT0) / math.max(0.01, r.BlendDur), 0, 1)
		table.clear(parts)
		table.clear(cfs)
		if r.Baked then
			-- the clip of the pose (blended from the last one), on the UpperTorso
			local function at(pose, t0)
				local c = shoulderOf(BAKED[pose] or "Rest") or shoulderOf("Rest")
				local t = tn - (t0 or tn) + (BAKED_IN[pose] or 0)
				if c.Clip == K.Clip("Rest") then t = t % c.Clip.Duration end
				return c, t
			end
			local ca, ta = at(r.Pose, r.PoseT0)
			local cb, tb
			if r.From and w < 1 then cb, tb = at(r.From.Name, r.From.T0) elseif w >= 1 then r.From = nil end
			local e = smooth(w)
			local anchor = ut.CFrame
			for _, pc in ipairs(ca.List) do
				local cf, sc = K.Sample(pc, ca.Clip, ta)
				local pb = cb and cb.ByName[pc.Name]
				if pb then
					local cfb, scb = K.Sample(pb, cb.Clip, tb)
					cf, sc = cfb:Lerp(cf, e), scb:Lerp(sc, e)
				end
				local set = neck.Map[pc.Name]
				if set then K.PlaceSet(set, anchor * cf, sc, parts, cfs) end
				if pc.Name == "Shoulder_Skull" then
					r.HeadCF = anchor * cf
					r.Mouth = (r.HeadCF * CFrame.new(0, -0.05 * sc.X, -0.85 * sc.X)).Position
				end
			end
		else
			local fn = POSES[r.Pose] or POSES.Rest
			local P, jaw = fn(r, tn - r.PoseT0)
			if r.From and w < 1 then
				local Q, jq = (POSES[r.From.Name] or POSES.Rest)(r, tn - (r.From.T0 or tn))
				local e = smooth(w)
				for i = 1, #P do P[i] = Q[i]:Lerp(P[i], e) end
				jaw = jq + (jaw - jq) * e
			elseif w >= 1 then
				r.From = nil
			end
			local endCF = K.PlaceNeck(neck, catmull(P), r.UT.CFrame.RightVector, parts, cfs)
			r.HeadCF = endCF
			K.PlaceHead(hd, endCF, jaw, 0, parts, cfs)
			r.Mouth = (endCF * CFrame.new(0, -0.02 * hd.S, -0.95 * hd.S)).Position
		end
		local helmCF = head.CFrame
		if r.JoltAt then                                           -- (the lock's jolt: down and a nod, decaying)
			local d = tn - r.JoltAt
			if d > 0.35 then r.JoltAt = nil else
				local ks = head.Size.Y / 1.18
				helmCF *= CFrame.new(0, -0.03 * ks * math.exp(-d / 0.05) * math.cos(2 * math.pi * d / 0.07), 0)
					* CFrame.Angles(math.rad(2 * math.exp(-d / 0.06) * math.sin(2 * math.pi * d / 0.09)), 0, 0)
			end
		end
		K.PlaceHelm(helm, helmCF, head.Size.Y, r.SkullOpen, parts, cfs)
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		-- the core breathes (slow, steady -- never a flash); feeding (Symbiosis) runs a light down the throat vein
		local breathe = 0.5 + 0.5 * math.sin(tn * 1.2 + r.Seed)
		hd.Core.Color = K.Look.Core:Lerp(K.Look.Glass, 0.45 - 0.25 * breathe)
		if hd.Light then hd.Light.Brightness = r.Calm and 1.1 or (0.85 + 0.55 * breathe) end
		local shut = r.SkullOpen < 0.25
		if shut ~= r.HelmShut then
			r.HelmShut = shut
			if r.HelmMotes then r.HelmMotes.Enabled = shut end
		end
		-- the POWER-ON (Blender: eyes 0.3 -> 12 -> 3 -> 16 -> 9, the core 0.6 -> 8 -> 4.5, from 0.02 s after the lock);
		-- 1 = lit steady, over 1 = the flash; Reduce Flashing keeps it at steady
		local eyes, core = 0.05, 0.15
		if r.LockAt and tn >= r.LockAt then
			local d = tn - r.LockAt
			eyes = d < 0.02 and 0.05 or d < 0.03 and 1.33 or d < 0.04 and 0.33 or d < 0.06 and 1.78
				or 1.78 - 0.78 * math.clamp((d - 0.06) / 0.17, 0, 1)
			core = d < 0.03 and 0.15 or d < 0.09 and 0.15 + 1.63 * (d - 0.03) / 0.06
				or 1.78 - 0.78 * math.clamp((d - 0.09) / 0.19, 0, 1)
			if r.Calm then
				eyes = d < 0.02 and 0.05 or 1
				core = d < 0.03 and 0.15 or math.min(1, 0.15 + 0.85 * (d - 0.03) / 0.06)
			end
		end
		if eyes ~= r.EyesLit or core ~= r.CoreLit then
			r.EyesLit, r.CoreLit = eyes, core
			local slit, vc = helm.Slit, helm.Face.G.Core
			slit.Transparency = 0.75 * (1 - math.clamp(eyes, 0, 1))
			slit.Color = K.Look.Eye:Lerp(Color3.fromRGB(236, 255, 190), math.clamp(eyes - 1, 0, 1))
			r.SlitLight.Brightness = 0.2 + 1.4 * eyes
			if vc then
				vc.Transparency = 0.7 * (1 - math.clamp(core, 0, 1))
				vc.Color = K.Look.Core:Lerp(Color3.fromRGB(220, 255, 160), math.clamp(core - 1, 0, 1))
			end
		end
		r.Feed = math.max(0, r.Feed - dt)
		local n = #neck.Segs
		for i, sg in ipairs(neck.Segs) do
			local wave = 0
			if r.FeedAt then                                       -- (a pulse running from the head down to the shoulder)
				local x = (tn - r.FeedAt) / 0.45 - (n - i) / n
				wave = math.exp(-((x - 0.15) / 0.12) ^ 2) * (r.FeedCalm and 0.5 or 1)
			end
			sg.Vein.Color = K.Look.Vein:Lerp(K.Look.Eye, wave)
		end
		-- the wearer's own first-person camera sits inside it: hidden for them alone
		local near = char == Players.LocalPlayer.Character and nearCam(head.Position, 1.8)
		if near ~= r.Shown then
			r.Shown = near
			setLTM(all, near and 1 or 0)
		end
		return true
	end
	return r
end

--- The creature manager: every wearer (players, and in Studio the StudioSkin stand-ins) gets the resting creature.
function FX.Start()
	if started or not RunService:IsClient() then return end
	started = true
	K.OldSetInUse = function()
		for _, r in pairs(rigs) do if r.KGen ~= K.Gen then return true end end
		return false
	end
	-- (2026-10-26) the kit let go of its meshes (MeshBudget / the Altar's ReleaseNow: nobody here wears it): every resting
	-- creature goes with them, so none keeps drawing a destroyed mesh; the manager builds them again once it is rebuilt
	if K.OnRelease then K.OnRelease(function() for char in pairs(rigs) do dropRig(char) end end) end
	task.spawn(function()
		while true do
			local seen = {}
			local function consider(m)
				if typeof(m) == "Instance" and m:IsA("Model") and m:FindFirstChildOfClass("Humanoid") then
					seen[m] = true
					local on = K.On(m)
					local r0 = rigs[m]                                     -- (the other mesh set: rebuilt at rest only)
					if on and r0 and r0.KGen ~= K.Gen and r0.Pose == "Rest" and not r0.BackAt and r0.SkullOpen >= 1
						and not r0.LockAt then dropRig(m) end
					if on and K.Built and not rigs[m] then
						local ok, r = pcall(buildRig, m)
						if ok and r then rigs[m] = r end
					elseif not on and rigs[m] then
						dropRig(m)
					end
				end
			end
			for _, plr in ipairs(Players:GetPlayers()) do consider(plr.Character) end
			if RunService:IsStudio() then
				for _, m in ipairs(workspace:GetChildren()) do if m:GetAttribute("StudioSkin") == K.Id then consider(m) end end
				local tg = workspace:FindFirstChild("TrainingGround")
				local dm = tg and tg:FindFirstChild("Dummies")
				if dm then for _, m in ipairs(dm:GetChildren()) do if m:GetAttribute("StudioSkin") == K.Id then consider(m) end end end
			end
			-- (2026-10-26) the showcase stand-ins (ShowcaseSkin, live and in Studio), wherever in the workspace they are
			if K.Showcased then for _, m in ipairs(K.Showcased()) do consider(m) end end
			for char in pairs(rigs) do if not seen[char] then dropRig(char) end end
			task.wait(0.5)
		end
	end)
	-- the layer counts for the checkpoint (continuous emitters: rate x time), published on the fx folder
	local shown = 0
	H.updaters[FX.Stats] = function(dt, t)
		for e, layer in pairs(live) do
			if e.Parent and e.Enabled then FX.Stats[layer] = (FX.Stats[layer] or 0) + e.Rate * dt end
		end
		if t - shown > 0.25 then
			shown = t
			local f = H.fxFolder()
			f:SetAttribute("HY_StatBase", math.floor(FX.Stats.Base + 0.5))
			f:SetAttribute("HY_StatFleck", math.floor((FX.Stats.Fleck or 0) + 0.5))
			f:SetAttribute("HY_StatGlint", math.floor((FX.Stats.Glint or 0) + 0.5))
		end
		return true
	end
	FX.StartKills()
end

function FX.Init(helpers, kit)
	H, K = helpers, kit
	local m = script.Parent:FindFirstChild("ToxinTuning")
	T = m and require(m) or nil
	FX.Start()
end
local function tune(group, key, fallback)
	local g = T and T[group]
	local v = g and g[key]
	return (type(v) == "number") and v or fallback
end
function FX.Rig(char) return rigs[char] end                     -- (the stage reads it)
FX.Poses = POSES

-- glints off the scales (the Epic layer: its own switch, scaled by Graphics Quality, halved under Reduce Flashing)
local function glintsAt(cf, n, spread, speed)
	local h = anchoredHost(cf)
	local e = emitter(h, "Glint", { Shape = "Glint", Color = K.Look.Eye, LightInfluence = 0, LightEmission = 0.6,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.3, 0.32), NumberSequenceKeypoint.new(1, 0) }),
		Transparency = NumberSequence.new(0.1), Life = NumberRange.new(0.25, 0.45), Speed = speed or NumberRange.new(1, 3),
		Spread = Vector2.new(spread or 180, spread or 180), RotSpeed = NumberRange.new(-90, 90) })
	emit(e, (H.calm() and math.ceil(n / 2) or n))
	task.delay(1.5, function() h:Destroy() end)
end

----------------------------------------------------------------------------------------------------
-- M1 TOXIC BUBBLES: BITE-AND-SPIT -- the shoulder head snaps forward down the aim, jaw wide, and spits the venom glob
-- (on the Default's throw beat); the glob bursts where the sac would
----------------------------------------------------------------------------------------------------
local function burstGlob(w, pos, big)
	if w.Done then return end
	w.Done = true
	puffAt(CFrame.new(pos), big and 12 or 8, big and 3 or 2, K.Look.Venom, 80, NumberRange.new(4, 9))
	chipsAt(CFrame.new(pos), big and 5 or 3, NumberRange.new(4, 8), 80)
	glintsAt(CFrame.new(pos), big and 5 or 3)
	local fy = groundAt(pos)
	local tx = K.Tex()
	if tx and tx.Etch then                                        -- (a scorched splash where it broke)
		local m = part2({ Name = "HY_Splash", Transparency = 1, Size = Vector3.new(big and 2.6 or 1.8, 0.05, big and 2.6 or 1.8) })
		m.CFrame = CFrame.new(pos.X, fy + 0.03, pos.Z) * CFrame.Angles(0, math.random() * TAU, 0)
		local dc = Instance.new("Decal")
		dc.Face, dc.TextureContent, dc.Color3, dc.Transparency = Enum.NormalId.Top, tx.Etch, K.Look.Etch, 0.2
		dc.Parent = m
		local t0, key = now(), {}
		H.updaters[key] = function()
			local s = now() - t0
			dc.Transparency = 0.2 + 0.8 * math.clamp((s - 0.6) / 1.2, 0, 1)
			if s >= 1.8 then m:Destroy() return false end
			return true
		end
	end
	pcall(function() w.G.Part:Destroy() w.G.Core:Destroy() w.G.Seam:Destroy() end)
end

function FX.BubbleStart(b, caster, origin)
	local g = K.Glob(H.fxFolder())
	local gl = Instance.new("PointLight")                         -- (its venom core is self-lit)
	gl.Color, gl.Range, gl.Brightness, gl.Shadows = K.Look.Core, 3, 1.4, false
	gl.Parent = g.Core
	local w = { G = g, OwnBurst = true, T0 = now(), Caster = caster, Spin = 0 }
	b.WB = w
	local r = rigs[caster]
	if r then
		local head = caster:FindFirstChild("Head")
		r.Aim = head and head.CFrame.LookVector or r.Aim
		rigPose(caster, "Spit", 0.05, 0.42)                       -- (the bite-and-spit, on the throw)
		body(caster, "HydraSpit")                                 -- (the body leans into the lunge)
		w.From = r.Mouth
	end
	w.Trail = emitter(g.Part, "Fleck", { Shape = "Dot", Color = K.Look.Venom, LightInfluence = 0.6, Rate = 10,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.12), NumberSequenceKeypoint.new(1, 0.02) }),
		Life = NumberRange.new(0.3, 0.5), Speed = NumberRange.new(0.2, 0.8), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, -14, 0) })
	w.Sparkle = emitter(g.Part, "Glint", { Shape = "Glint", Color = K.Look.Eye, LightInfluence = 0, LightEmission = 0.6, Rate = 3,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.3, 0.26), NumberSequenceKeypoint.new(1, 0) }),
		Life = NumberRange.new(0.25, 0.4), Speed = NumberRange.new(0, 0.3), Spread = Vector2.new(180, 180) })
	-- a bubble cleared without a hit, a conversion or an expiry (a round reset): its glob goes with it
	local key = {}
	H.updaters[key] = function()
		if w.Done then return false end
		if b.Model and b.Model.Parent then return true end
		w.GoneAt = w.GoneAt or now()
		if now() - w.GoneAt > 0.12 then w.Done = true pcall(function() g.Part:Destroy() g.Core:Destroy() g.Seam:Destroy() end) return false end
		return true
	end
end

function FX.BubbleDraw(b, cf, size, fade, look)
	local w = b.WB
	if not (w and w.G and not w.Done) then return end
	local r = rigs[w.Caster]
	if r and look and look.Magnitude > 1e-3 and not w.Aimed then   -- (the strike follows the throw's own line)
		w.Aimed = true
		r.Aim = look.Unit
	end
	local tn = now()
	local t = tn - w.T0
	local pos = cf.Position
	if w.From and t < 0.1 and not w.Rest then pos = w.From:Lerp(pos, smooth(t / 0.1)) end   -- (it leaves the mouth)
	w.Pos = pos
	local d = math.clamp(size.X * 0.9, 0.3, 1.6)                  -- (no wider than the hit: the sac's own size)
	local squash = 1
	if w.Rest then
		local s = math.clamp((tn - (w.RestAt or tn)) / 0.3, 0, 1)
		squash = 1 - 0.18 * math.sin(s * math.pi) * (1 - s) - 0.12 * s
	end
	w.Spin += 0.05
	local o = CFrame.new(pos) * CFrame.Angles(0, w.Spin, 0)
	w.G.Part.Size = Vector3.new(d, d * squash, d)
	w.G.Part.CFrame = o
	w.G.Core.Size = Vector3.new(d, d * squash, d) * 0.48
	w.G.Core.CFrame = o
	w.G.Seam.Size = Vector3.new(0.04, d * 1.02, d * 1.02)
	w.G.Seam.CFrame = o * CFrame.Angles(0, 0, math.pi / 2) * CFrame.Angles(w.Spin * 2, 0, 0)
	w.G.Part.Transparency = 0.3 + 0.7 * fade
	w.G.Core.Transparency, w.G.Seam.Transparency = fade, fade
	if w.Trail then w.Trail.Enabled = not w.Rest and fade < 0.5 end
end

function FX.BubbleRest(b)
	local w = b.WB
	if not w then return end
	w.Rest, w.RestAt = true, now()
	if w.Pos then puffAt(CFrame.new(w.Pos), 3, 0, K.Look.Venom, 70, NumberRange.new(1, 3)) end
end
function FX.Splash(pos, normal, big, b)
	local w = b and b.WB
	if w and w.G then burstGlob(w, w.Pos or pos, big) end
end
function FX.BubbleExpire(b)
	local w = b and b.WB
	if w and w.G then burstGlob(w, w.Pos or (b.Pos or Vector3.zero), false) end
end

----------------------------------------------------------------------------------------------------
-- PRIMARY CORROSIVE CLOUD: WIND-UP-AND-EXHALE -- the shoulder head rears back, then breathes the miasma out at the cloud's
-- heart over its FormTime; the ground under the cloud etches and bubbles, shed scales and glints drift in it
----------------------------------------------------------------------------------------------------
local function etchCloud(c, center, form, etchK)
	if not (c and c.Folder) then return end
	etchK = etchK or 1.95                                         -- (the etch's width over the cloud's radius)
	local R = c.R or tune("Cloud", "Radius", 9)
	form = form or tune("Cloud", "FormTime", 0.6)
	local tx = K.Tex()
	local fy = groundAt(center)
	-- the etch: corroded ground spreading out from the centre under the gas
	local etch = part2({ Name = "HY_Etch", Transparency = 1, Size = Vector3.new(0.4, 0.05, 0.4) }, c.Folder)
	etch.CFrame = CFrame.new(center.X, fy + 0.03, center.Z) * CFrame.Angles(0, math.random() * TAU, 0)
	local decal = nil
	if tx and tx.Etch then
		decal = Instance.new("Decal")
		decal.Face = Enum.NormalId.Top
		decal.TextureContent = tx.Etch
		decal.Color3 = K.Look.Etch
		decal.Transparency = 1
		decal.Parent = etch
	end
	-- shed scales drifting through the gas (the Fleck layer)
	local dustHost = anchoredHost(CFrame.new(center + Vector3.new(0, 1.6, 0)), c.Folder)
	dustHost.Size = Vector3.new(R * 1.3, 2.6, R * 1.3)
	local dust = emitter(dustHost, "Fleck", { Shape = "Flake", Color = K.Look.Dust, LightInfluence = 1, Rate = 14,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(0.5, 0.18), NumberSequenceKeypoint.new(1, 0.08) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.15), NumberSequenceKeypoint.new(0.85, 0.3), NumberSequenceKeypoint.new(1, 1) }),
		Life = NumberRange.new(2.2, 3.4), Speed = NumberRange.new(0.2, 0.6), Spread = Vector2.new(180, 180), Accel = Vector3.new(0, 0.15, 0),
		RotSpeed = NumberRange.new(-120, 120), Drag = 0.6 })
	-- glints off shed scales in the gas (the Epic layer)
	local motes = emitter(dustHost, "Glint", { Shape = "Glint", Color = K.Look.Eye, LightInfluence = 0, LightEmission = 0.8, Rate = 9,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.05), NumberSequenceKeypoint.new(0.4, 0.34), NumberSequenceKeypoint.new(1, 0) }),
		Life = NumberRange.new(0.5, 0.9), Speed = NumberRange.new(0.1, 0.4), Spread = Vector2.new(180, 180) })
	chipsAt(CFrame.new(center + Vector3.new(0, 0.6, 0)), 8, NumberRange.new(4, 9), 70)  -- (the eruption)
	-- the bubbling: venom beads swell out of the etch and pop
	local beads = {}
	local pops = puffer(K.Look.Venom)                             -- (every bead's pop shares one puff source)
	local nextBead = now() + form * 0.6
	local t0 = now()
	local key = {}
	local dn = H.density()
	H.updaters[key] = function()
		local t = now() - t0
		local gone = not c.Folder.Parent
		local ending = gone or c.EndAt ~= nil
		local fade = ending and (gone and 1 or math.clamp((now() - c.EndAt) / math.max(0.3, c.Fade or 1.3), 0, 1)) or 0
		local spread = easeOut(math.clamp(t / (form * 1.2), 0, 1))
		local d = R * etchK * spread
		etch.Size = Vector3.new(math.max(0.4, d), 0.05, math.max(0.4, d))
		if decal then decal.Transparency = 0.12 + 0.88 * math.max(1 - math.min(1, t / 0.25), fade) end
		if dust then dust.Enabled = not ending end
		if motes then motes.Enabled = not ending end
		if not ending and now() >= nextBead then
			nextBead = now() + (0.18 + math.random() * 0.22) / math.max(0.3, dn)
			local a, rr = math.random() * TAU, math.sqrt(math.random()) * R * 0.85 * spread
			local p = Vector3.new(center.X + math.cos(a) * rr, fy, center.Z + math.sin(a) * rr)
			local bd = part2({ Name = "HY_Bead", Color = K.Look.Venom, Transparency = 0.3, Reflectance = 0.15, Size = Vector3.new(0.05, 0.05, 0.05) }, c.Folder)
			local m = Instance.new("SpecialMesh")
			m.MeshType = Enum.MeshType.Sphere
			m.Parent = bd
			beads[#beads + 1] = { P = bd, Pos = p, T0 = now(), Life = 0.35 + math.random() * 0.3, D = 0.22 + math.random() * 0.22 }
		end
		for i = #beads, 1, -1 do
			local q = beads[i]
			local u = (now() - q.T0) / q.Life
			if u >= 1 or gone then
				if not gone then pops.At(CFrame.new(q.Pos + Vector3.new(0, q.D * 0.4, 0)), 2, 1, 70, NumberRange.new(1.5, 3)) end
				pcall(function() q.P:Destroy() end)
				table.remove(beads, i)
			else
				local dd = q.D * easeOut(u)
				q.P.Size = Vector3.new(dd, dd * 0.8, dd)
				q.P.CFrame = CFrame.new(q.Pos + Vector3.new(0, dd * 0.3, 0))
			end
		end
		if (gone or fade >= 1) and #beads == 0 then
			pcall(function() etch:Destroy() dustHost:Destroy() end)
			pops.Done()
			return false
		end
		return true
	end
end

function FX.Cloud(c, caster, center, form)
	if not (c and c.Folder) then return end
	form = form or tune("Cloud", "FormTime", 0.6)
	etchCloud(c, center, form, 1.95)
	local r = rigs[caster]
	if not (r and r.Mouth) then return end
	local t0 = now()
	r.Aim = (center - r.Mouth).Magnitude > 1e-3 and (center - r.Mouth).Unit or r.Aim
	rigPose(caster, "Rear", 0.08)                                 -- (the wind-up)
	if form >= tune("Cloud", "FormTime", 0.6) - 1e-3 then body(caster, "HydraExhale") end   -- (the torso: the cast only)
	-- the breath: a jet of the miasma from the mouth to the cloud's heart, over the release
	local host = anchoredHost(CFrame.new(r.Mouth), c.Folder)
	local jet = emitter(host, "Base", { Color = H.Look and H.Look.Steam or K.Look.VenomDeep, LightInfluence = 0.8, Dir = Enum.NormalId.Front,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.4), NumberSequenceKeypoint.new(1, 2.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.7, 0.6), NumberSequenceKeypoint.new(1, 1) }),
		Life = NumberRange.new(0.4, 0.5), Spread = Vector2.new(7, 7) })
	local spit = emitter(host, "Fleck", { Shape = "Dot", Color = K.Look.Venom, LightInfluence = 0.6, Dir = Enum.NormalId.Front,
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.14), NumberSequenceKeypoint.new(1, 0.04) }),
		Life = NumberRange.new(0.35, 0.45), Spread = Vector2.new(10, 10) })
	local dn = H.density()
	local released, key = false, {}
	local WIND = 0.18
	H.updaters[key] = function()
		local t = now() - t0
		if not (r.Mouth and host.Parent) then pcall(function() host:Destroy() end) return false end
		if not released and t >= WIND then
			released = true
			r.Aim = (center - r.Mouth).Magnitude > 1e-3 and (center - r.Mouth).Unit or r.Aim
			rigPose(caster, "Exhale", 0.05, math.max(0.1, form - WIND) + 0.08)   -- (the release, held to the end of FormTime)
			glintsAt(CFrame.new(r.Mouth), 3, 40, NumberRange.new(2, 4))
		end
		local m = r.Mouth
		local dist = (center + Vector3.new(0, 1.2, 0) - m).Magnitude
		host.CFrame = CFrame.lookAt(m, center + Vector3.new(0, 1.2, 0))
		local on = released and t < form
		if jet then
			jet.Speed = NumberRange.new(dist / 0.5 * 0.85, dist / 0.45)
			jet.Rate = on and 60 * dn or 0
		end
		if spit then
			spit.Speed = NumberRange.new(dist / 0.45 * 0.8, dist / 0.4)
			spit.Rate = on and 14 * dn or 0
		end
		if t > form + 0.7 then host:Destroy() return false end
		return true
	end
end

--- The Ultimate's mass (ToxinFX's cloud hook on it): the same etch, scales, glints and beads.
function FX.Bubblify(c)
	if not (c and c.Folder and c.CF) then return end
	etchCloud(c, c.CF.Position, 0.4, 1.2)                         -- (a tighter etch: the mass is wide)
end

----------------------------------------------------------------------------------------------------
-- PASSIVE SYMBIOSIS: PULSE-AND-GLOW -- a thin venom thread runs from the afflicted enemy into the shoulder head's mouth; as
-- it lands the head gulps and a light runs down the throat vein (the creature feeding). Short, small, steady
----------------------------------------------------------------------------------------------------
function FX.Siphon(caster, victimPart)
	local r = rigs[caster]
	if not (r and r.Mouth and victimPart and victimPart.Parent) then return end
	body(caster, "HydraGulp")                                     -- (the chest opens to the thread, hunches on the gulp)
	local hostA = anchoredHost(victimPart.CFrame)
	local hostB = anchoredHost(CFrame.new(r.Mouth))
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Parent, a1.Parent = hostA, hostB
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.Color = ColorSequence.new(K.Look.Glow)
	b.LightInfluence, b.LightEmission = 0, 1
	b.Width0, b.Width1 = 0.07, 0.05
	b.FaceCamera = true
	b.Segments = 16
	b.CurveSize0, b.CurveSize1 = 1.4, -0.6
	b.Transparency = NumberSequence.new(1)
	b.Parent = hostA
	local t0, key = now(), {}
	local arrived = false
	H.updaters[key] = function()
		local t = now() - t0
		if t >= 0.8 or not (victimPart.Parent and r.Mouth and rigs[caster] == r) then
			pcall(function() hostA:Destroy() hostB:Destroy() end)
			return false
		end
		hostA.CFrame = victimPart.CFrame
		hostB.CFrame = CFrame.new(r.Mouth)
		-- the head runs out to the mouth (0.22 s); the thread then dissolves from the enemy's end (0.35 -> 0.75 s)
		local head = easeOut(math.clamp(t / 0.22, 0, 1))
		local tail = smooth((t - 0.35) / 0.4)
		local kp = { NumberSequenceKeypoint.new(0, 1) }
		local function add(x, v) if x > kp[#kp].Time + 1e-3 and x < 1 then kp[#kp + 1] = NumberSequenceKeypoint.new(x, v) end end
		add(math.max(0.002, tail * 0.98), 1)
		add(math.max(0.004, tail * 0.98 + 0.01), 0.2)
		add(math.max(0.006, head - 0.01), 0.2)
		add(math.max(0.008, head), 1)
		kp[#kp + 1] = NumberSequenceKeypoint.new(1, head >= 0.999 and (tail < 0.98 and 0.2 or 1) or 1)
		b.Transparency = NumberSequence.new(kp)
		if head >= 1 and not arrived then
			arrived = true
			r.FeedAt, r.FeedCalm = now(), H.calm()
			rigPose(caster, "Gulp", 0.05, 0.32)
			puffAt(CFrame.new(r.Mouth), 2, 0, K.Look.Venom, 90, NumberRange.new(0.5, 1.5))
		end
		return true
	end
end

----------------------------------------------------------------------------------------------------
-- ULTIMATE PATIENT ZERO: STRIKE-COIL-STRIKE (two beats). Beat one, at the cast: three heads burst out of the ground
-- round the target and bite -- the bite delivers the mark: the sigil spreads from the wound to the ground. Through the
-- countdown their necks coil round the target and tighten on the Default's accelerating beat. Beat two, at the fuse:
-- they rear up high and, at the burst, strike down together; the Default's cloud erupts. Every number is the Default's.
----------------------------------------------------------------------------------------------------
local function gearHz(k)
	if k < 0.36 then return tune("PatientZero", "PulseFrom", 0.6) end
	if k < 0.7 then return 1.8 end
	return tune("PatientZero", "PulseTo", 4.6)
end
local PZ = {
	Heads = 3, Scale = 1.5, Plates = 7,
	Ring = 3.6,           -- (studs out from the target the heads come up)
	Rise = 0.16,          -- (out of the ground, poised over the target: 0 -> 0.16)
	Bite = 0.3,           -- (the lunge lands: the mark)
	Hold = 0.12,          -- (jaws clamped)
	Coil = 0.6,           -- (wound round the target by here, for the countdown)
	Rear = 0.25,          -- (the fuse: they rear high, beat two's wind-up)
	Strike = 0.1,         -- (at the burst: down together)
	Sink = 0.6,           -- (then back into the ground)
	Spread = 0.35,        -- (the sigil: from the wound to the ground ring)
}
FX.PZ = PZ
local function flatUnit(v, fb) v = Vector3.new(v.X, 0, v.Z) return v.Magnitude > 1e-3 and v.Unit or fb end
local function yaw(v, a) local c, s = math.cos(a), math.sin(a) return Vector3.new(v.X * c - v.Z * s, 0, v.X * s + v.Z * c) end

function FX.Mark(caster, target, telegraph, fuse)
	local torso = torsoOf(target)
	local tx = K.Tex()
	if not (torso and tx and tx.Sigil) then return nil end
	telegraph = telegraph or tune("PatientZero", "Telegraph", 3.5)
	fuse = fuse or tune("PatientZero", "Fuse", 0.35)
	body(caster, "HydraPZ")                                       -- (the caster summons, braces, squeezes, slams)
	local pulseEnd = math.max(0.1, telegraph - fuse)
	local up = Vector3.yAxis
	local D = 9.5
	-- the sigil (the hydra's), hidden until the bite
	local host = part2({ Name = "HY_Sigil", Transparency = 1, Size = Vector3.new(0.2, 0.05, 0.2) })
	local outer = surfaceImage(host, Enum.NormalId.Top, tx.Sigil, K.Look.Glow, 512, 1.4)
	local inner = Instance.new("ImageLabel")
	inner.BackgroundTransparency, inner.ImageContent, inner.ImageColor3 = 1, tx.Sigil, K.Look.Venom
	inner.AnchorPoint, inner.Position, inner.Size = Vector2.new(0.5, 0.5), UDim2.fromScale(0.5, 0.5), UDim2.fromScale(0.44, 0.44)
	inner.Parent = outer.Parent
	outer.ImageTransparency, inner.ImageTransparency = 1, 1
	-- the heads: one from behind the target (its bite is the mark), two more a third of the way round either side
	local back0 = flatUnit(-torso.CFrame.LookVector, Vector3.zAxis)
	-- THE HEADS (2026-10-23): the approved Blender performance, baked (HydraAnimData.Ultimate) -- three heads climbing one
	-- spiral each out of the ground round the target's hitbox into the bite at 0.30, on up to its face for the countdown
	-- (squeezing and hissing on the Default's gears, baked from the cast), rearing over the fuse, striking at the burst
	local baked = bakedRig("Ultimate")
	local heads = baked and { baked } or {}
	local calm = H.calm()
	local t0 = now()
	local phase, spin, beat = 0, 0, 0
	local rec = { HideCore = true }
	local endAt, burst, strikeAt = nil, false, nil
	local hitAt, woundLocal, backHit, axis = nil, nil, nil, nil
	local lastS = 0.2
	local function deliver(woundWorld)
		if hitAt then return end
		hitAt = now()
		woundLocal = torso.CFrame:PointToObjectSpace(woundWorld)
		backHit = flatUnit(-torso.CFrame.LookVector, back0)
		axis = up:Cross(backHit)
	end
	function rec.End(didBurst)
		if endAt then return end
		endAt, burst = now(), didBurst and true or false
		if burst then strikeAt = now() end
	end
	--- (ToxinFX) where the Default's mark drips from: the bite wound, on the skin, once it has landed
	function rec.DripAt()
		if not (woundLocal and torso.Parent) then return nil end
		return torso.CFrame:PointToWorldSpace(woundLocal + Vector3.new(0, 0, 0.25)) - Vector3.new(0, 0.25, 0)
	end
	local all = baked and baked.All or {}
	local g = PZ.Scale / 1.5
	local surfaced, bitten, struck = false, false, false
	local parts, cfs = {}, {}
	local key = {}
	H.updaters[key] = function(dt)
		local tn = now()
		local t = tn - t0
		local alive = target.Parent and torso.Parent
		-- the BEAT keeps the Default's gears from the cast (0.6 -> 1.8 -> 4.6 Hz over the telegraph less the fuse); the
		-- ring beats by scale and spin, the necks tighten on it
		if t < pulseEnd and not endAt then
			local k = math.clamp(t / pulseEnd, 0, 1)
			local hz = calm and math.min(gearHz(k), 1) or gearHz(k)
			phase += TAU * hz * dt
			beat = math.max(0, math.cos(phase)) ^ 6 * (calm and 0.4 or 1)
			spin += dt * (0.25 + 0.9 * k)
		else
			beat = 0
		end
		local tp = alive and torso.Position or (heads[1] and heads[1].Last) or Vector3.zero
		local fy = alive and groundAt(tp, target) or (tp.Y - 3)
		-- THE HEADS: the baked clip on the cast's clock; its fuse (3.15 -> 3.50) mapped onto this cast's fuse, held struck
		-- until the burst arrives, then on to the sink; a cancelled cast sinks where it is
		local cutAt = endAt and not burst and endAt or nil
		local done = true
		if baked then
			table.clear(parts)
			table.clear(cfs)
			local tc
			if t < pulseEnd then tc = 3.15 * t / pulseEnd
			else tc = 3.15 + 0.35 * math.clamp((t - pulseEnd) / math.max(0.05, telegraph - pulseEnd), 0, 1) end
			local lift = 0
			if strikeAt then
				tc = 3.5 + (tn - strikeAt)
				if tc < baked.Clip.Duration then done = false end
			elseif cutAt then
				tc = math.min(tc, 3.5)
				lift = 12 * easeIn(math.clamp((tn - cutAt) / PZ.Sink, 0, 1))
				if tn - cutAt < PZ.Sink then done = false end
			else
				done = false
			end
			if not cutAt then baked.Tc = tc end
			local face = alive and flatUnit(torso.CFrame.LookVector, -back0) or -back0
			local anchor = CFrame.lookAt(Vector3.new(tp.X, fy, tp.Z), Vector3.new(tp.X, fy, tp.Z) + face)
			baked.Place(anchor, cutAt and (baked.Tc or tc) or tc, lift, parts, cfs)
			heads[1].Last = tp
			workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
			local mine = target == Players.LocalPlayer.Character and alive and nearCam(tp, 4)
			setLTM(all, mine and 1 or 0)
		end
		if not surfaced then
			surfaced = true
			for i = 1, PZ.Heads do                               -- (the three holes the climbs come out of)
				local gi = Vector3.new(tp.X, fy, tp.Z) + yaw(back0, (i - 1) * 2 * math.pi / PZ.Heads + 0.7) * PZ.Ring * g
				chipsAt(CFrame.new(gi + up * 0.3), 6, NumberRange.new(5, 10), 45)
				puffAt(CFrame.new(gi + up * 0.4), 0, 3, nil, 50)
			end
		end
		-- THE BITE: the mark is delivered at the first head's snout (on the back), whatever the frame rate did
		if not bitten and t >= PZ.Bite and alive and not cutAt then
			bitten = true
			local wound = tp + back0 * (torso.Size.Z * 0.5 + 0.04) + up * (torso.Size.Y * 0.2)
			deliver(wound)
			puffAt(CFrame.new(wound + back0 * 0.3), 8, 2, K.Look.Venom, 80, NumberRange.new(3, 7))
			glintsAt(CFrame.new(tp), 6, 180, NumberRange.new(2, 5))
		end
		if not hitAt and not cutAt and alive and (#heads == 0 and t >= PZ.Bite or t > PZ.Bite + 0.25) then
			deliver(tp + back0 * (torso.Size.Z * 0.5 + 0.04))     -- (the heads could not be made: the mark still lands)
		end
		if strikeAt and not struck and tn - strikeAt >= PZ.Strike then
			struck = true
			puffAt(CFrame.new(tp), 14, 6, K.Look.Venom, 70, NumberRange.new(6, 12))
			glintsAt(CFrame.new(tp + up), 10, 180, NumberRange.new(3, 7))
			chipsAt(CFrame.new(Vector3.new(tp.X, fy + 0.3, tp.Z)), 10, NumberRange.new(6, 12), 55)
		end
		-- THE SIGIL
		if endAt then
			local k = math.clamp((tn - endAt) / (burst and 0.3 or 0.5), 0, 1)
			if hitAt then
				local s = burst and D * (1 + 0.5 * easeOut(k)) or lastS * (1 - 0.3 * k)
				host.Size = Vector3.new(math.max(0.2, s), 0.05, math.max(0.2, s))
				local a = math.max(outer.ImageTransparency, k)
				outer.ImageTransparency, inner.ImageTransparency = a, a
			end
			if k >= 1 and host.Parent then host:Destroy() end
			if done and not host.Parent then
				if baked then baked.Destroy() end
				return false
			end
			return true
		end
		if not alive then rec.End(false) return true end
		if hitAt then
			-- SPREAD (0.35 s): a small glyph stamped on the bite, hinging down about the target's right into the ring
			local ks = math.clamp((tn - hitAt) / PZ.Spread, 0, 1)
			local skin = torso.CFrame:PointToWorldSpace(woundLocal)
			local from = CFrame.fromMatrix(skin, axis, backHit)
			local to = CFrame.fromMatrix(Vector3.new(tp.X, fy + 0.06, tp.Z), axis, up)
			local rot = (from - from.Position):Lerp(to - to.Position, easeOut(math.min(1, ks * 1.5)))
			local place = CFrame.new(from.Position:Lerp(to.Position, smooth(ks))) * rot
			local bloom = 0.06 + 0.94 * backOut(math.clamp((ks - 0.2) / 0.8, 0, 1))
			local fuseK = (t >= pulseEnd) and easeOut(math.clamp((t - pulseEnd) / 0.12, 0, 1)) or 0
			local s = D * bloom * (1 + 0.07 * beat) * (1 - 0.22 * fuseK)
			host.Size = Vector3.new(math.max(0.2, s), 0.05, math.max(0.2, s))
			host.CFrame = place
			lastS = math.max(0.2, s)
			outer.Rotation = math.deg(spin)
			inner.Rotation = -math.deg(spin * 2.2)
			inner.Size = UDim2.fromScale(0.44 * (1 + 0.12 * beat), 0.44 * (1 + 0.12 * beat))
			outer.ImageTransparency = 1 - math.min(1, (tn - hitAt) / 0.08)
			inner.ImageTransparency = outer.ImageTransparency
		end
		return true
	end
	return rec
end

--- The burst (ToxinFX's PZBurst hook): the heads' strike (beat two) runs from the mark's End(true); the Default's flash
--- stays out (true) -- the wave and the mass (etched by FX.Bubblify) erupt from the strike.
function FX.PZBurst(caster, target, pos, center, R)
	return true
end

----------------------------------------------------------------------------------------------------
-- ANTITOXIN VENT: HINGE-CLOSE -- the helm's faceplate (one rigid piece, standing raised above the forehead at rest, a
-- visor flipped up) pivots down on its one hinge at the top front of the head, sweeping down in front of the face in
-- AssembleTime until it is flush on the helm's back half, enclosing the head; it holds shut for the whole Duration (its
-- face-slit lit throughout: it is part of the plate), then pivots back up the same way
----------------------------------------------------------------------------------------------------
-- THE CLOSE (approved in Blender, hydra_helm_anim.py, 2026-10-22): at AssembleTime 0.35 -- the UNLATCH (0-0.05: the
-- plate lifts 6 degrees past open), the DROP (0.05-0.27: accelerating all the way, no braking), the LOCK at 0.27 (a
-- hard stop: the helm jolts down and nods, the plate rebounds 3 degrees and settles), then the eyes power on behind
-- it (see the rig's update). Times scale with `dur`. The REOPEN: the eyes go dark, then the plate swings up past open
-- and settles back (an ease-out overshoot).
local LIFT, T_UNLATCH, T_LOCK = 6 / 195, 0.05 / 0.35, 0.27 / 0.35
local function swingTo(r, to, dur)
	r.VentGen = (r.VentGen or 0) + 1
	local gen, from, t0, key = r.VentGen, r.SkullOpen, now(), {}
	dur = math.max(0.01, dur)
	local closing = to < 0.5
	if closing and from <= 0.01 then                              -- (already shut: stay shut, lit)
		r.SkullOpen = to
		r.LockAt = r.LockAt or t0
		return
	end
	r.LockAt = nil
	if closing then r.LockAt = t0 + T_LOCK * dur end
	local locked = false
	H.updaters[key] = function()
		if rigs[r.Char] ~= r or r.VentGen ~= gen then return false end
		local t = now() - t0
		if closing then
			local tu, tl = T_UNLATCH * dur, T_LOCK * dur
			if t < tu then
				r.SkullOpen = from + LIFT * from * math.sin(0.5 * math.pi * t / tu)
			elseif t < tl then
				r.SkullOpen = (from + LIFT * from) * (1 - ((t - tu) / (tl - tu)) ^ 2.4)
			else
				local d = t - tl
				r.SkullOpen = (5 / 195) * math.exp(-d / 0.03) * math.abs(math.sin(math.pi * d / 0.032))
				if not locked then                                -- (the lock: venom off the seam, glints, the jolt)
					locked = true
					r.JoltAt = now()
					local slit = r.Helm and r.Helm.Slit
					if slit and slit.Parent then
						pcall(puffAt, slit.CFrame, 3, 0, K.Look.Venom, 150, NumberRange.new(0.6, 1.6))
						pcall(glintsAt, slit.CFrame, 8, 180, NumberRange.new(0.5, 2.2))
					end
				end
				if d > 0.15 then r.SkullOpen = to return false end
			end
			return true
		end
		local k = math.clamp(t / dur, 0, 1)
		local c = 1.25
		r.SkullOpen = from + (to - from) * (1 + (c + 1) * (k - 1) ^ 3 + c * (k - 1) ^ 2)
		if k >= 1 then r.SkullOpen = to return false end
		return true
	end
end
function FX.Vent(caster, duration)
	local r = rigs[caster]
	if not r then return nil end                                  -- (no creature yet: the Default mask draws)
	local assemble = tune("Vent", "AssembleTime", 0.35)
	body(caster, "HydraVent")                                     -- (the hand draws the plate down; the body takes the lock)
	swingTo(r, 0, assemble)                                       -- (down on the one hinge; its eye-slits lit throughout)
	return {
		Mouth = function()                                        -- (the cleanse threads end on the face-slit)
			local s = r.Helm.Slit
			return s.Parent and s.Position or nil
		end,
		Arrive = function()
			local s = r.Helm.Slit
			if s.Parent then puffAt(s.CFrame, 2, 0, K.Look.Venom, 120, NumberRange.new(0.5, 1.2)) end
		end,
		Colors = { K.Look.VenomDeep, K.Look.Venom },
	}
end
--- The Vent is over: the faceplate swings back up to rest as the crest (fast on a re-cast or a clear).
function FX.VentEnd(caster, fast)
	local r = rigs[caster]
	if not r then return end
	swingTo(r, 1, fast and 0.2 or tune("Vent", "AssembleTime", 0.35))
end

----------------------------------------------------------------------------------------------------
-- ACID RAIN: EMERGE-AND-SPIT -- inside the GatherTime three small heads come up out of the caster's back beside the
-- shoulder head, all four aim at the sky over the area and spit venom up into the Default's cloud, and sink back by
-- 0.7 s; the venom comes down from the cloud as fang-spines on the Default's rain window, sticking and corroding
----------------------------------------------------------------------------------------------------
local RAIN = {
	Emerge = 0.16,       -- (out of the back: 0 -> 0.16)
	Spit = { 0.22, 0.27, 0.32, 0.37 },   -- (each head's spit; the shoulder head's is the last)
	Flight = 0.2,        -- (to the cloud: the last there at 0.57)
	Retract = 0.45,      -- (back into the body: 0.45 -> 0.68, inside the 0.7 s GatherTime)
	Spines = 26,         -- (a second, at full density)
	Fall = 0.3,
	Scale = 0.55,
}
FX.RainTiming = RAIN
function FX.AcidRain(caster, center, height, R, gather, rainTime, t0)
	local r = rigs[caster]
	if not r then return nil end                                  -- (no creature yet: the Default rain draws)
	gather = gather or tune("AcidRain", "GatherTime", 0.7)
	rainTime = rainTime or tune("AcidRain", "RainTime", 4)
	t0 = t0 or now()
	local up = Vector3.yAxis
	local sky = center + Vector3.new(0, height, 0)
	-- the shoulder head joins the volley (its spit is the last)
	r.Aim = r.Mouth and (sky - r.Mouth).Unit or up
	r.SpitAt = t0 + RAIN.Spit[4]
	rigPose(caster, "Fire", 0.08, RAIN.Retract + 0.2)
	body(caster, "HydraRain")                                     -- (the back splits, then both arms to the sky)
	-- three more heads out of the back: the left shoulder blade, the spine, the right hip
	local ut = r.UT
	local small = {}
	-- (2026-10-23) the approved Blender performance: the baked Fire clip's three small heads out of the back, the shoulder
	-- head (the rig's own Fire clip) spitting first, then each small head in turn
	local bk = bakedRig("Fire", function(n) return string.sub(n, 1, 4) == "Rain" end)
	local bkAims = {}
	if bk then
		for i = 1, 3 do
			local a, rr = math.random() * TAU, math.sqrt(math.random()) * R * 0.5
			bkAims[i] = sky + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr)
		end
	end
	for i, at in ipairs(bk and {} or { { -0.3, 0.3, -1 }, { 0.0, 0.08, 0 }, { 0.3, -0.18, 1 } }) do
		local neck = K.Neck(RAIN.Scale, 4, H.fxFolder())
		local hd = newHead(RAIN.Scale)
		if neck and hd then
			local a, rr = math.random() * TAU, math.sqrt(math.random()) * R * 0.5
			small[#small + 1] = { Neck = neck, Hd = hd, X = at[1], Y = at[2], Lean = at[3], Spit = RAIN.Spit[i],
				Aim = sky + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr) }
		end
	end
	local all = bk and bk.All or {}
	for _, s in ipairs(small) do
		for _, p in ipairs(s.Neck.Parts) do all[#all + 1] = p end
		for _, p in ipairs(s.Hd.Parts) do all[#all + 1] = p end
	end
	local bkShot = {}
	local dn = H.density()
	local shots, spines = {}, {}
	local sizzle = puffer(K.Look.Venom)                           -- (every spine's sizzle shares one puff source)
	local burst = false
	local nextLand = t0 + math.max(gather * 0.8, RAIN.Spit[4] + RAIN.Flight + RAIN.Fall)
	local lastLand = t0 + gather + rainTime
	local fired = false
	local function shoot(from, to, tn)
		local gl = K.Glob(H.fxFolder())
		shots[#shots + 1] = { G = gl, From = from, To = to, T0 = tn }
		puffAt(CFrame.new(from), 3, 1, K.Look.Venom, 40, NumberRange.new(2, 4))
	end
	local key = {}
	local parts, cfs = {}, {}
	H.updaters[key] = function()
		local tn = now()
		local t = tn - t0
		local live = ut.Parent and r.Char.Parent
		-- THE HEADS (baked): the clip on the UpperTorso; each spits at its turn, from its mouth
		if bk then
			if live and t < bk.Clip.Duration then
				table.clear(parts)
				table.clear(cfs)
				bk.Place(ut.CFrame, t, 0, parts, cfs)
				workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
				local mine = r.Char == Players.LocalPlayer.Character and nearCam(r.Head.Position, 1.8)
				setLTM(all, mine and 1 or 0)
				for i = 1, 3 do
					if not bkShot[i] and t >= RAIN.Spit[i + 1] then
						bkShot[i] = true
						local m = bk.Mouth(ut.CFrame, "Rain" .. (i - 1), t)
						if m then shoot(m, bkAims[i], tn) end
					end
				end
			else
				bk.Destroy()
				bk = nil
			end
		end
		-- THE HEADS: out (0 -> Emerge), aimed and spitting, back in (Retract -> 0.68)
		if #small > 0 then
			if live and t < RAIN.Retract + 0.25 then
				table.clear(parts)
				table.clear(cfs)
				local cf = ut.CFrame
				local back, upv, right = -cf.LookVector, cf.UpVector, cf.RightVector
				local k = (t < RAIN.Emerge) and backOut(t / RAIN.Emerge) or (1 - smooth((t - RAIN.Retract) / 0.23))
				k = math.clamp(k, 0.02, 1.1)
				for _, s in ipairs(small) do
					local root = cf.Position + right * (ut.Size.X * s.X) + upv * (ut.Size.Y * s.Y) + back * (ut.Size.Z * 0.42)
					local p3 = root + back * 0.5 + upv * 0.85 + right * 0.35 * s.Lean
					local aim = (s.Aim - p3).Unit
					local P = { root, root + back * 0.32 + upv * 0.2, p3, p3 + aim * 0.65 }
					for j = 2, 4 do P[j] = root + (P[j] - root) * k end
					local spat = t - s.Spit
					local endCF = K.PlaceNeck(s.Neck, catmull(P), right, parts, cfs)
					K.PlaceHead(s.Hd, endCF, (spat >= -0.05 and spat < 0.16) and 0.9 or 0.15, 0, parts, cfs)
					if not s.Shot and spat >= 0 then
						s.Shot = true
						shoot((endCF * CFrame.new(0, 0, -0.92 * s.Hd.S)).Position, s.Aim, tn)
					end
				end
				workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
				local mine = r.Char == Players.LocalPlayer.Character and nearCam(r.Head.Position, 1.8)
				setLTM(all, mine and 1 or 0)
			else
				for _, s in ipairs(small) do pcall(function() s.Neck.Model:Destroy() s.Hd.Model:Destroy() end) end
				table.clear(small)
			end
		end
		-- the shoulder head's spit (the first, as in Blender; the procedural heads' order kept it last)
		if not fired and t >= RAIN.Spit[(r.Baked and bkAims[1]) and 1 or 4] then
			fired = true
			if r.Mouth then shoot(r.Mouth, sky, tn) end
		end
		for i = #shots, 1, -1 do
			local q = shots[i]
			local u = math.clamp((tn - q.T0) / RAIN.Flight, 0, 1)
			local pos = q.From:Lerp(q.To, easeOut(u))
			local d = 0.38
			q.G.Part.Size, q.G.Core.Size = Vector3.new(d, d, d * 1.3), Vector3.new(d, d, d * 1.3) * 0.5
			local o = CFrame.lookAt(pos, pos + (q.To - q.From).Unit)
			q.G.Part.CFrame, q.G.Core.CFrame = o, o
			q.G.Seam.Size = Vector3.new(0.03, d * 1.02, d * 1.02)
			q.G.Seam.CFrame = o * CFrame.Angles(0, math.pi / 2, 0)
			if u >= 1 then
				if not burst then
					burst = true
					puffAt(CFrame.new(sky), 6, 4, K.Look.Venom, 180, NumberRange.new(2, 5))   -- (into the cloud: a spray)
					glintsAt(CFrame.new(sky), 5, 180, NumberRange.new(2, 5))
				end
				pcall(function() q.G.Part:Destroy() q.G.Core:Destroy() q.G.Seam:Destroy() end)
				table.remove(shots, i)
			end
		end
		-- RAIN: fang-spines, each planned by when it LANDS inside the Default rain's window, falling point-first
		while fired and nextLand <= lastLand and nextLand - RAIN.Fall <= tn do
			local a, rr = math.random() * TAU, math.sqrt(math.random()) * R
			local land = center + Vector3.new(math.cos(a) * rr, 0, math.sin(a) * rr)
			land = Vector3.new(land.X, groundAt(land), land.Z)
			local from = Vector3.new(land.X + (math.random() - 0.5) * 2, sky.Y, land.Z + (math.random() - 0.5) * 2)
			local sp = K.Barb(1.2, 0.42, H.fxFolder(), true)
			if sp then
				spines[#spines + 1] = { S = sp, From = from, To = land, T0 = math.max(tn, nextLand - RAIN.Fall), Land = nextLand,
					Roll = math.random() * TAU }
			end
			nextLand += 1 / (RAIN.Spines * math.max(0.3, dn))
		end
		for i = #spines, 1, -1 do
			local q = spines[i]
			local u = (tn - q.T0) / math.max(0.05, q.Land - q.T0)
			if u < 1 then
				local tip = q.From:Lerp(q.To, easeIn(math.clamp(u, 0, 1)))
				local dir = (q.To - q.From).Unit
				local bk = tip - dir * 1.1                          -- (point first: the base trails its tip)
				local base = CFrame.lookAt(bk, bk + dir) * CFrame.Angles(0, math.pi, 0) * CFrame.Angles(0, 0, q.Roll)
				q.S.Part.CFrame = K.BarbCF(q.S, base)
				if q.S.Seam then
					q.S.Seam.Size = Vector3.new(0.03, 0.18, 0.18)
					q.S.Seam.CFrame = CFrame.lookAt(bk, bk + dir) * CFrame.Angles(0, math.pi / 2, 0)
				end
			else
				if not q.Stuck then                                -- (it sticks, sizzling; a corrode mark spreads under it)
					q.Stuck = tn
					sizzle.At(CFrame.new(q.To + Vector3.new(0, 0.1, 0)), 2, 1, 70, NumberRange.new(1.5, 3))
					local tx = K.Tex()
					if tx and tx.Etch then
						local m = part2({ Name = "HY_Mark", Transparency = 1, Size = Vector3.new(1.7, 0.05, 1.7) })
						m.CFrame = CFrame.new(q.To + Vector3.new(0, 0.03, 0)) * CFrame.Angles(0, math.random() * TAU, 0)
						local dc = Instance.new("Decal")
						dc.Face, dc.TextureContent, dc.Color3, dc.Transparency = Enum.NormalId.Top, tx.Etch, K.Look.Etch, 0.25
						dc.Parent = m
						q.Mark, q.Decal = m, dc
					end
				end
				local s = tn - q.Stuck
				if q.Decal then q.Decal.Transparency = 0.25 + 0.75 * math.clamp((s - 0.4) / 1.1, 0, 1) end
				local fade = math.clamp((s - 0.45) / 0.3, 0, 1)
				q.S.Part.Transparency = fade
				if q.S.Seam then q.S.Seam.Transparency = fade end
				if s >= 1.6 then
					pcall(function() q.S.Part:Destroy() end)
					if q.S.Seam then pcall(function() q.S.Seam:Destroy() end) end
					if q.Mark then pcall(function() q.Mark:Destroy() end) end
					table.remove(spines, i)
				end
			end
		end
		local alive = (nextLand <= lastLand) or #spines > 0 or #shots > 0 or #small > 0 or not fired
		if not alive then sizzle.Done() end
		return alive
	end
	return "drops"                                                -- (the spines are the drops: the Default's cloud stays)
end

--- CORRODED (ToxinFX's acid tick, per body caught): glowing cracked scales over the body that track the Corroded
--- stacks (ToxinVuln, while ToxinVulnUntil holds) and fade as they lapse; true = the Default glaze is not drawn.
local cracked = setmetatable({}, { __mode = "k" })
function FX.Corrode(model)
	local tx = K.Tex()
	if not (tx and tx.Crack) then return nil end
	if cracked[model] then return true end
	local maxS = tune("AcidRain", "VulnMaxStacks", 4)
	local guis = {}
	for _, name in ipairs({ "UpperTorso", "LowerTorso", "Head", "Torso", "LeftUpperArm", "RightUpperArm", "LeftUpperLeg", "RightUpperLeg" }) do
		local p = model:FindFirstChild(name)
		if p and p:IsA("BasePart") then
			for _, face in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
				local im, sg = surfaceImage(p, face, tx.Crack, K.Look.Seam, 128, 1.1)
				im.ImageTransparency = 1
				im.Rotation = math.random(0, 3) * 90
				guis[#guis + 1] = { Im = im, Sg = sg }
			end
		end
	end
	if #guis == 0 then return nil end
	local rec = { Cover = 0 }
	cracked[model] = rec
	local key = {}
	H.updaters[key] = function(dt)
		local untilT = model.Parent and model:GetAttribute("ToxinVulnUntil")
		local stacks = model.Parent and model:GetAttribute("ToxinVuln") or 0
		local liveS = untilT and workspace:GetServerTimeNow() <= untilT and stacks > 0
		local want = liveS and math.clamp(stacks / maxS, 0, 1) or 0
		rec.Cover += (want - rec.Cover) * math.min(1, dt * (liveS and 4 or 2.5))
		local mine = model == Players.LocalPlayer.Character and nearCam((model:FindFirstChild("Head") or model:GetPivot()).Position, 2)
		for _, g in ipairs(guis) do
			g.Im.ImageTransparency = 1 - 0.6 * rec.Cover
			g.Sg.Enabled = not mine
		end
		if (not liveS and rec.Cover < 0.02) or not model.Parent then
			for _, g in ipairs(guis) do pcall(function() g.Sg:Destroy() end) end
			cracked[model] = nil
			return false
		end
		return true
	end
	return true
end

----------------------------------------------------------------------------------------------------
-- THE KILL EFFECT, "THE HYDRA'S DUE" (cosmetic only): on a kill by a Hydra wearer the server's HydraKillHook stamps the
-- killer's character (HydraKillFX: the server time; HydraKillFXVictim: the victim's name; HydraKillFXVictimRef: the
-- victim model), and every client plays it here: three heads burst out of the ground round where the victim fell, rear,
-- strike down on them together and drag the venom down with them as they sink; cracked-scale glow over the body, a
-- corroded stain left behind. About 1.6 s; nothing persists, nothing is read or changed but the stamp.
----------------------------------------------------------------------------------------------------
-- (2026-10-23: rebuilt at the Ultimate's scale -- the baked HydraAnimData.Kill: three full heads rise round the fallen,
-- rear and ROAR, strike together at 0.95; a big venom bloom; they sink by 2.3)
local KILL = { Scale = 1.5, Rise = 0.35, Rear = 0.62, Roar = 0.85, Strike = 0.95, Hold = 1.3, End = 2.4 }
FX.Kill = KILL
local function playKill(killer, victim)
	local at = victim and victim.Parent and (torsoOf(victim) or victim.PrimaryPart)
	local tp = at and at.Position or (victim and victim:GetPivot().Position)
	if not tp then return end
	local up = Vector3.yAxis
	local fy = groundAt(tp, victim)
	local kp = killer and killer:GetPivot().Position
	local face = kp and flatUnit(kp - tp, Vector3.zAxis) or Vector3.zAxis
	local baked = bakedRig("Kill")
	if not baked then return end
	local all = baked.All
	local anchor = CFrame.lookAt(Vector3.new(tp.X, fy, tp.Z), Vector3.new(tp.X, fy, tp.Z) + face)
	-- cracked-scale glow over the body (on this client only), fading out with the sink
	local guis = {}
	local tx = K.Tex()
	if tx and tx.Crack and victim then
		for _, name in ipairs({ "UpperTorso", "LowerTorso", "Head", "Torso" }) do
			local p = victim:FindFirstChild(name)
			if p and p:IsA("BasePart") then
				for _, f in ipairs({ Enum.NormalId.Front, Enum.NormalId.Back }) do
					local im, sg = surfaceImage(p, f, tx.Crack, K.Look.Glow, 128, 1.3)
					im.ImageTransparency = 1
					guis[#guis + 1] = { Im = im, Sg = sg }
				end
			end
		end
	end
	chipsAt(CFrame.new(Vector3.new(tp.X, fy + 0.3, tp.Z)), 10, NumberRange.new(5, 10), 50)
	local t0, key = now(), {}
	local struck = false
	local parts, cfs = {}, {}
	H.updaters[key] = function()
		local t = now() - t0
		if t >= KILL.End then
			baked.Destroy()
			for _, q in ipairs(guis) do pcall(function() q.Sg:Destroy() end) end
			return false
		end
		table.clear(parts)
		table.clear(cfs)
		baked.Place(anchor, t, 0, parts, cfs)
		workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
		local mine = victim == Players.LocalPlayer.Character and nearCam(tp, 4)
		setLTM(all, mine and 1 or 0)
		if not struck and t >= KILL.Strike then
			struck = true
			-- THE BLOOM: a big venom cloud over the body (the core puff, a ring of puffs round it, rising)
			puffAt(CFrame.new(tp), 22, 10, K.Look.Venom, 90, NumberRange.new(6, 13))
			for k = 0, 5 do
				local d = yaw(Vector3.xAxis, k * TAU / 6)
				puffAt(CFrame.new(Vector3.new(tp.X, fy + 0.8, tp.Z) + d * 3.2), 4, 4, K.Look.Venom, 70, NumberRange.new(2, 5))
			end
			glintsAt(CFrame.new(tp + up), 14, 180, NumberRange.new(3, 8))
			local m = tx and tx.Etch and part2({ Name = "HY_KillStain", Transparency = 1, Size = Vector3.new(6, 0.05, 6) })
			if m then
				m.CFrame = CFrame.new(tp.X, fy + 0.04, tp.Z) * CFrame.Angles(0, math.random() * TAU, 0)
				local dc = Instance.new("Decal")
				dc.Face, dc.TextureContent, dc.Color3, dc.Transparency = Enum.NormalId.Top, tx.Etch, K.Look.Etch, 0.15
				dc.Parent = m
				task.delay(KILL.End - KILL.Strike, function() pcall(function() m:Destroy() end) end)
			end
		end
		local glowK = (t < KILL.Strike) and 0 or math.clamp(1 - (t - KILL.Strike - 0.5) / 0.6, 0, 1)
		for _, q in ipairs(guis) do q.Im.ImageTransparency = 1 - 0.75 * glowK end
		return true
	end
end

local watched = setmetatable({}, { __mode = "k" })
local function watchKills(character)
	if typeof(character) ~= "Instance" or watched[character] then return end
	watched[character] = true
	character:GetAttributeChangedSignal("HydraKillFX"):Connect(function()
		local stamp = character:GetAttribute("HydraKillFX")
		if type(stamp) ~= "number" or math.abs(workspace:GetServerTimeNow() - stamp) > 2 then return end
		local ref = character:FindFirstChild("HydraKillFXVictimRef")
		local victim = ref and ref:IsA("ObjectValue") and ref.Value or nil
		if not (victim and victim.Parent) then                    -- (by name, as the hook also stamps it)
			local name = character:GetAttribute("HydraKillFXVictim")
			local plr = name and Players:FindFirstChild(name)
			victim = plr and plr.Character or nil
		end
		pcall(playKill, character, victim)
	end)
end
--- Watches every character (and, in Studio, the stand-ins) for the kill stamp.
function FX.StartKills()
	local function onPlayer(plr)
		if plr.Character then watchKills(plr.Character) end
		plr.CharacterAdded:Connect(watchKills)
	end
	for _, plr in ipairs(Players:GetPlayers()) do onPlayer(plr) end
	Players.PlayerAdded:Connect(onPlayer)
	if RunService:IsStudio() then
		task.spawn(function()
			while true do
				for _, m in ipairs(workspace:GetDescendants()) do
					if m:IsA("Model") and m:GetAttribute("StudioSkin") == K.Id then watchKills(m) end
				end
				task.wait(2)
			end
		end)
	end
	-- (2026-10-26) the showcase stand-ins (ShowcaseSkin, live and in Studio), wherever in the workspace they are
	if K.Showcased then
		task.spawn(function()
			while true do
				for _, m in ipairs(K.Showcased()) do watchKills(m) end
				task.wait(2)
			end
		end)
	end
end
FX.PlayKill = playKill                                            -- (the stage previews it)

return FX

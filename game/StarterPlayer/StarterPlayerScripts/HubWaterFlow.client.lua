--[[
	HubWaterFlow (LocalScript, StarterPlayerScripts) -- 2026-10-15, on request: the Arcane Observatory hub's wall
	waterfalls feel like water running down instead of standing still.

	The waterfalls are geometry baked into the hub's merged OBS_Water_Lit_01 mesh: four falls of four streaks each.
	Their places were measured from that mesh (hub/observatory_2026_10_07/water_flow/streaks.py) into FALLS below.
	Nothing of the hub is changed; on this client each fall gets:
	  * FLOW: a Beam laid on every streak, just in front of it, its soft texture scrolling DOWN the streak -- the water
	    running; the short streaks fade out where they end;
	  * DRIPS: bright elongated droplets sliding down every streak, each living exactly until that streak's foot;
	  * SPLASH: droplets kicked up where the full-height streaks land in the basin, and a faint mist over it.
	Built-in textures only (new image uploads do not load in this place). Particles pause while the camera is far.
]]

local RunService = game:GetService("RunService")

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Centre = Vector3.new(8000, 0, 8000),
	FarAway = 400,                       -- the splashes stop emitting past this (the beams are left; they cost nothing)
	InFront = 0.16,                      -- studs the flow sits in front of its streak, so the wall never hides it
	Flow = {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Length = 0.9,                    -- studs of streak per texture repeat (one bright bead each)
		Speed = 2.6,                     -- texture repeats a second, downward
		Width = 1.6,                     -- times the streak's width (the streak itself is already Neon: the beads
		                                 -- must spill past its edges to read over it)
		Colour = { Color3.fromRGB(255, 255, 255), Color3.fromRGB(190, 240, 255) },   -- top, bottom
		Transparency = 0.05,
		Light = 1,
	},
	Drips = { Rate = 4, Speed = 7, Gravity = 10, Size = 0.14, Squash = 1.6 },   -- droplets sliding down each streak
	Splash = { Rate = 14, Life = { 0.3, 0.55 }, Speed = { 2, 4 }, Size = 0.13, Spread = 55, Gravity = 18 },
	Mist = { Rate = 3, Life = { 1.0, 1.6 }, Size = { 0.6, 1.5 }, Transparency = 0.82 },
	SplashColour = Color3.fromRGB(170, 235, 255),
}

-- { Normal (the fall's face, toward the hub), Basin (the landing, its lowest streak foot), Streaks = { { x, z, yBottom,
-- yTop, width } } } -- world studs, measured 2026-10-15
local FALLS = {
	{ Normal = Vector3.new(-0.698, 0, -0.716), Basin = Vector3.new(8033.48, 1.30, 8034.03), Streaks = { { 8032.98, 8034.43, 1.30, 8.75, 0.48 }, { 8033.37, 8034.19, 3.16, 8.75, 0.25 }, { 8033.70, 8033.92, 5.02, 8.75, 0.19 }, { 8033.88, 8033.56, 1.30, 8.75, 0.45 } } },
	{ Normal = Vector3.new(-0.891, 0, 0.454), Basin = Vector3.new(8036.13, 1.50, 7988.08), Streaks = { { 8035.85, 7987.42, 1.50, 10.99, 0.51 }, { 8036.09, 7987.84, 3.87, 10.99, 0.35 }, { 8036.30, 7988.31, 6.25, 10.99, 0.25 }, { 8036.28, 7988.75, 1.50, 10.99, 0.57 } } },
	{ Normal = Vector3.new(-0.941, 0, 0.338), Basin = Vector3.new(8097.16, 1.10, 8004.31), Streaks = { { 8097.02, 8003.80, 1.10, 8.06, 0.39 }, { 8097.21, 8004.81, 1.10, 8.06, 0.42 }, { 8097.16, 8004.12, 2.84, 8.06, 0.26 }, { 8097.27, 8004.49, 4.58, 8.06, 0.18 } } },
	{ Normal = Vector3.new(-0.850, 0, -0.526), Basin = Vector3.new(8092.79, 1.10, 8029.18), Streaks = { { 8093.02, 8028.72, 1.10, 7.40, 0.41 }, { 8092.46, 8029.62, 1.10, 7.40, 0.36 }, { 8092.72, 8029.34, 2.68, 7.40, 0.24 }, { 8092.94, 8029.05, 4.25, 7.40, 0.18 } } },
}

local folder = Instance.new("Folder")
folder.Name = "HubWaterFlow"
folder.Parent = workspace

local emitters = {}

local function attach(host, at, name)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Parent = host
	a.WorldPosition = at
	return a
end

local function flow(host, top, bottom, width, full)
	local F = Tuning.Flow
	local a0, a1 = attach(host, top, "FlowTop"), attach(host, bottom, "FlowFoot")
	local b = Instance.new("Beam")
	b.Attachment0, b.Attachment1 = a0, a1
	b.FaceCamera = true
	b.Segments = 1
	b.Width0, b.Width1 = width * F.Width, width * F.Width
	b.Texture = F.Texture
	b.TextureMode = Enum.TextureMode.Wrap
	b.TextureLength = F.Length
	b.TextureSpeed = F.Speed
	b.LightEmission, b.LightInfluence = F.Light, 0
	b.Color = ColorSequence.new(F.Colour[1], F.Colour[2])
	-- a full streak stays visible into the basin; a short one fades where it ends
	b.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(0.12, F.Transparency),
		NumberSequenceKeypoint.new(0.85, full and F.Transparency or 0.6),
		NumberSequenceKeypoint.new(1, full and 0.4 or 1),
	})
	b.ZOffset = 0.2
	b.Parent = host
	-- droplets sliding the length of the streak, living exactly until its foot
	local D = Tuning.Drips
	local h = (top - bottom).Magnitude
	local life = (-D.Speed + math.sqrt(D.Speed * D.Speed + 2 * D.Gravity * h)) / D.Gravity
	local pe = Instance.new("ParticleEmitter")
	pe.Name = "Drips"
	pe.Texture = F.Texture
	pe.Rate = D.Rate * (0.75 + 0.5 * math.random())        -- each streak on its own beat, never in lockstep
	pe.Lifetime = NumberRange.new(life)
	pe.Speed = NumberRange.new(D.Speed * 0.95, D.Speed * 1.05)
	pe.SpreadAngle = Vector2.new(0, 0)
	pe.EmissionDirection = Enum.NormalId.Bottom
	pe.Acceleration = Vector3.new(0, -D.Gravity, 0)
	-- upright in the world, so Squash stretches it DOWN the streak (VelocityParallel laid it across: 2026-10-15)
	pe.Orientation = Enum.ParticleOrientation.FacingCameraWorldUp
	pe.Squash = NumberSequence.new(D.Squash)
	pe.Size = NumberSequence.new(math.min(D.Size, width * 0.6))
	pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(0.15, 0),
		NumberSequenceKeypoint.new(0.85, 0), NumberSequenceKeypoint.new(1, full and 0.2 or 1) })
	pe.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255))
	pe.LightEmission, pe.LightInfluence = 1, 0
	pe.ZOffset = 0.3
	pe.Parent = a0
	table.insert(emitters, pe)
end

local function splash(host, at)
	local S, M = Tuning.Splash, Tuning.Mist
	local a = attach(host, at, "Splash")
	local drops = Instance.new("ParticleEmitter")
	drops.Name = "Drops"
	drops.Texture = Tuning.Flow.Texture
	drops.Rate = S.Rate
	drops.Lifetime = NumberRange.new(S.Life[1], S.Life[2])
	drops.Speed = NumberRange.new(S.Speed[1], S.Speed[2])
	drops.SpreadAngle = Vector2.new(S.Spread, S.Spread)
	drops.EmissionDirection = Enum.NormalId.Top
	drops.Acceleration = Vector3.new(0, -S.Gravity, 0)
	drops.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, S.Size), NumberSequenceKeypoint.new(1, S.Size * 0.3) })
	drops.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	drops.Color = ColorSequence.new(Tuning.SplashColour)
	drops.LightEmission, drops.LightInfluence = 0.7, 0
	drops.Parent = a
	local mist = Instance.new("ParticleEmitter")
	mist.Name = "Mist"
	mist.Texture = Tuning.Flow.Texture
	mist.Rate = M.Rate
	mist.Lifetime = NumberRange.new(M.Life[1], M.Life[2])
	mist.Speed = NumberRange.new(0.3, 0.8)
	mist.SpreadAngle = Vector2.new(35, 35)
	mist.EmissionDirection = Enum.NormalId.Top
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, M.Size[1]), NumberSequenceKeypoint.new(1, M.Size[2]) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, M.Transparency),
		NumberSequenceKeypoint.new(1, 1) })
	mist.Color = ColorSequence.new(Tuning.SplashColour)
	mist.LightEmission, mist.LightInfluence = 0.4, 0
	mist.Parent = a
	table.insert(emitters, drops)
	table.insert(emitters, mist)
end

for i, fall in ipairs(FALLS) do
	local host = Instance.new("Part")
	host.Name = "Fall_" .. i
	host.Anchored, host.CanCollide, host.CanQuery, host.CanTouch = true, false, false, false
	host.Transparency, host.Size = 1, Vector3.new(0.2, 0.2, 0.2)
	host.CFrame = CFrame.new(fall.Basin)
	host.Parent = folder
	local out = fall.Normal * Tuning.InFront
	local feet = {}
	for _, s in ipairs(fall.Streaks) do
		local x, z, y0, y1, w = s[1], s[2], s[3], s[4], s[5]
		local full = y0 <= fall.Basin.Y + 0.3
		flow(host, Vector3.new(x, y1, z) + out, Vector3.new(x, y0, z) + out, w, full)
		if full then feet[#feet + 1] = Vector3.new(x, y0 + 0.15, z) + out * 2 end
	end
	for _, at in ipairs(feet) do splash(host, at) end
end

-- the splashes rest while nobody near can see them
local on = true
RunService.Heartbeat:Connect(function()
	local camera = workspace.CurrentCamera
	local near = camera and (camera.CFrame.Position - Tuning.Centre).Magnitude <= Tuning.FarAway or false
	if near ~= on then
		on = near
		for _, e in ipairs(emitters) do e.Enabled = near end
	end
end)

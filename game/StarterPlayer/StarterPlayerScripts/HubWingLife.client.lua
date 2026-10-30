--[[
	HubWingLife  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/HubWingLife

	THE HUB, ALIVE: each wing's own moving decor (2026-10-25, the owner's hub-rebuild brief, step 1). Client only, built on
	this client and never replicated; nothing of the hub's own meshes is changed except Terra's archway pieces, which are
	hidden HERE (locally) because Terra's new arch replaces them. Runs only while HubLife.On() (Studio until the owner's
	review). Everything scales with Graphics Quality's effect density (LOW 45% .. ULTRA 115%); Reduce Flashing keeps every
	pulse slow and soft.

	  PYRO (the Store's bowl gate, its stair and the Store's counter fires) -- the flames themselves already lick and sway
	    (HubFireFlicker): here their LIGHT flickers with them (the gate's four PointLights; the stair and counter fires get
	    a light of their own), the gate braziers shed a second, longer ember stream in Pyro's colours (gold -> orange ->
	    ember red) that rises well above the bowl, and a soft heat glow breathes behind each gate flame.
	  AQUA -- in HubWaterfall (the four falls rebuilt as moving water, with their foam, splash and ripple rings).
	  ZEPHYR (the Duels crescents) -- an AIR RIBBON winds round each crescent (two trails each, out of phase), LEAVES and
	    flecks loop round the whole archway on a gust, and two Zephyr PENNANTS hang from the frame's top corners and sway.
	    (The hub's own banners stay still: HubBannerWave was retired on 2026-10-20 because the wave lagged the game; the
	    pennants are a handful of rigid segments.)
	  TERRA (the Loadout archway) -- a new identity: the cracked stone arch with its crystal cluster and rough rock pillars,
	    modelled in Blender (hub/hub_life_2026_10_25/terra_arch, HubTerraArchData). The old neon frame, its crystal growths
	    and ivy are hidden on this client; the floor stripe the frame carried is redrawn from the same data. The crystal
	    vein pulses (a wave running down it), the crystal cluster glows, and pebbles trickle out of the pillars' cracks.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end

local hub = workspace:WaitForChild(HubLife.Hub, 60)
if not hub then return end
local W = HubLife.Wing

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Pyro = {
		GateLights = { "Light_BowlGateNewel", "Light_BowlGateTopNewel", "Light_BowlGateWall", "Light_BowlGateTopWall" },
		GateFlames = { "Flame_01_Outer", "Flame_02_Outer", "Flame_03_Outer", "Flame_04_Outer" },
		OwnLight = { "Flame_05_Outer", "Flame_06_Outer", "Flame_07_Outer", "Flame_08_Outer", "Flame_09_Outer" },
		Light = { Brightness = 0.7, Range = 12, Hz = 6.5, Amp = 0.32 },
		Embers = { Rate = 7, Life = { 1.6, 2.6 }, Speed = { 3.5, 6 }, Size = { 0.16, 0.06 }, Spread = 14, Rise = 1.2 },
		Glow = { Rate = 1.4, Life = 1.3, Size = { 1.6, 2.6 }, Transparency = 0.86 },
		-- the Store's centrepiece gem (measured 2026-10-25: OBS_Decor_Glass_01's triangles in this box)
		Gem = { Mesh = "OBS_Decor_Glass_01", Lo = Vector3.new(8060.0, 15.5, 8009.3), Hi = Vector3.new(8063.1, 18.6, 8012.4),
			Colour = Color3.fromHex("B3300F"), Grow = 1.03 },
	},
	Zephyr = {
		Crescents = { Vector3.new(7974.7, 11.1, 8039.15), Vector3.new(8025.3, 11.1, 8039.15) },   -- centres of the neon blades
		Ribbon = { Height = 9.4, Side = 2.9, Depth = 2.2, Period = 3.4, Life = 0.95, Width = 0.62 },
		-- leaves loop round each crescent (a tall loop in front of and behind the blade), tumbling
		Leaves = { PerCrescent = 8, A = 3.6, B = 9.2, Depth = 2.6, Period = { 4.5, 7.5 }, Jitter = 0.9, Size = Vector3.new(0.62, 0.05, 0.36) },
		Pennants = { { At = Vector3.new(7979.5, 21.6, 8041.3) }, { At = Vector3.new(8020.5, 21.6, 8041.3) } },
		Pennant = { Segments = 5, Length = 1.45, Width = 1.3, Sway = 10, Hz = 0.5, Lag = 0.55 },
	},
	Terra = {
		Vein = { Dim = Color3.fromHex("6A5820"), Peak = Color3.fromHex("FFF0A8"), Calm = 0.35 },
		Pebbles = { Every = 1.6, Gravity = 70, Bounce = 0.32, Fade = 0.5, Pool = 6 },
		-- the LOADOUT plaques either side of the arch (their black screens, OBS_Screen_Dark_01): centre, along-the-wall T,
		-- out-to-the-plaza N, half-width W and half-height H, each with ~0.4 of frame margin
		Plaques = {
			{ C = Vector3.new(7955.35, 7.7, 7978.6), T = Vector3.new(-0.525, 0, 0.85), N = Vector3.new(0.85, 0, 0.525), W = 3.6, H = 3.3 },
			{ C = Vector3.new(7965.3, 7.7, 8035.45), T = Vector3.new(0.719, 0, 0.695), N = Vector3.new(0.695, 0, -0.719), W = 3.6, H = 3.3 },
		},
		CrystalLight = { Brightness = 1.1, Range = 14 },
	},
}

local folder = Instance.new("Folder")
folder.Name = "HubLife_Wings"
folder.Parent = workspace

local function part(props)
	local p = Instance.new("Part")
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.TopSurface, p.BottomSurface = Enum.SurfaceType.Smooth, Enum.SurfaceType.Smooth
	for k, v in pairs(props) do p[k] = v end
	if not props.Parent then p.Parent = folder end
	return p
end

local function noise(t, seed) return math.noise(t, seed, 0.37) end
local function seedOf(s)
	local h = 0
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
	return h / 1000003 * 100
end

local calm, density, quality = HubLife.Calm(), HubLife.Density(), HubLife.Quality()
local emitters = {}          -- { emitter, base rate, off on LOW }
local function rateOf(pe, base, lowOff)
	emitters[#emitters + 1] = { pe, base, lowOff }
	pe.Rate = (lowOff and quality <= 1) and 0 or base * density
end
HubLife.OnSettings(function()
	calm, density, quality = HubLife.Calm(), HubLife.Density(), HubLife.Quality()
	for _, e in ipairs(emitters) do e[1].Rate = (e[3] and quality <= 1) and 0 or e[2] * density end
end)

local tickers = {}           -- fn(t, dt), run each frame while the camera is near the hub
local function onTick(fn) tickers[#tickers + 1] = fn end

----------------------------------------------------------------------------------------------------
-- PYRO
----------------------------------------------------------------------------------------------------
do
	local P = Tuning.Pyro
	local lights = {}
	-- the gate's lights stream (hub.Lights is not Persistent, unlike Fires): bound as each arrives, again if one comes
	-- back as a new copy; an entry whose light has gone is dropped by the clock below
	local gateNames = {}
	for _, n in ipairs(P.GateLights) do gateNames[n] = true end
	local function bindGate(holder)
		if not gateNames[holder.Name] then return end
		local l = holder:FindFirstChildWhichIsA("PointLight") or holder:WaitForChild("PointLight", 5)
		if not (l and l:IsA("PointLight")) then return end
		for _, L in ipairs(lights) do
			if L.Light == l then return end
		end
		lights[#lights + 1] = { Light = l, Base = l.Brightness, Range = l.Range, Colour = l.Color, Seed = seedOf(holder.Name) }
	end
	task.spawn(function()
		local lightsFolder = hub:WaitForChild("Lights", 60)
		if not lightsFolder then return end
		lightsFolder.ChildAdded:Connect(function(c) task.spawn(bindGate, c) end)
		for _, c in ipairs(lightsFolder:GetChildren()) do task.spawn(bindGate, c) end
	end)
	local fires = hub:WaitForChild("Fires", 30)
	if fires then
		for _, n in ipairs(P.OwnLight) do
			local f = fires:FindFirstChild(n)
			if f and f:IsA("BasePart") then
				local a = Instance.new("Attachment")
				a.Name = "HubLifeLight"
				a.Position = Vector3.new(0, f.Size.Y * 0.2, 0)
				a.Parent = f
				local l = Instance.new("PointLight")
				l.Color, l.Brightness, l.Range, l.Shadows = W.Pyro.Base, P.Light.Brightness, P.Light.Range, false
				l.Parent = a
				lights[#lights + 1] = { Light = l, Base = P.Light.Brightness, Range = P.Light.Range, Seed = seedOf(n), Own = true }
			end
		end
		local E, G = P.Embers, P.Glow
		for _, n in ipairs(P.GateFlames) do
			local f = fires:FindFirstChild(n)
			if f and f:IsA("BasePart") then
				local a = Instance.new("Attachment")
				a.Name = "HubLifeEmbers"
				a.Position = Vector3.new(0, f.Size.Y * 0.3, 0)
				a.Parent = f
				local pe = Instance.new("ParticleEmitter")
				pe.Name = "HubLifeEmbers"
				pe.Texture = "rbxasset://textures/particles/sparkles_main.dds"
				pe.Lifetime = NumberRange.new(E.Life[1], E.Life[2])
				pe.Speed = NumberRange.new(E.Speed[1], E.Speed[2])
				pe.SpreadAngle = Vector2.new(E.Spread, E.Spread)
				pe.EmissionDirection = Enum.NormalId.Top
				pe.Acceleration = Vector3.new(0, E.Rise, 0)
				pe.Drag = 1.1
				pe.RotSpeed = NumberRange.new(-120, 120)
				pe.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, E.Size[1]), NumberSequenceKeypoint.new(1, E.Size[2]) })
				pe.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.7, 0.2),
					NumberSequenceKeypoint.new(1, 1) })
				pe.Color = ColorSequence.new({ ColorSequenceKeypoint.new(0, W.Pyro.Light), ColorSequenceKeypoint.new(0.45, W.Pyro.Base),
					ColorSequenceKeypoint.new(1, W.Pyro.Dark) })
				pe.LightEmission, pe.LightInfluence = 1, 0
				pe.Parent = a
				rateOf(pe, E.Rate, true)            -- (LOW: no embers, the hub's own rule in HubFireFlicker)
				local g = Instance.new("ParticleEmitter")
				g.Name = "HubLifeHeat"
				g.Texture = "rbxasset://textures/particles/smoke_main.dds"
				g.Lifetime = NumberRange.new(G.Life)
				g.Speed = NumberRange.new(0.3, 0.6)
				g.EmissionDirection = Enum.NormalId.Top
				g.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, G.Size[1]), NumberSequenceKeypoint.new(1, G.Size[2]) })
				g.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.3, G.Transparency),
					NumberSequenceKeypoint.new(1, 1) })
				g.Color = ColorSequence.new(W.Pyro.Base)
				g.LightEmission, g.LightInfluence, g.ZOffset = 1, 0, -1
				g.Parent = a
				rateOf(g, G.Rate)
			end
		end
	end
	-- (2026-10-29, the owner) the Store's centrepiece ruby display is removed (hub/store_front_2026_10_29 fix 2): its Pyro
	-- shell is gone with it (P.Gem kept as data only)
	local steady = W.Pyro.Base:Lerp(W.Pyro.Light, 0.35)
	onTick(function(t)
		for i = #lights, 1, -1 do
			local L = lights[i]
			if not L.Light.Parent then
				table.remove(lights, i)                -- (streamed out: its new copy is bound when it comes back)
			elseif calm then
				-- Reduce Flashing: a held colour and a slow, shallow swell (as HubFireFlicker / HubLanternFlicker hold)
				L.Light.Brightness = L.Base * (1 + 0.05 * math.sin(t * 0.4 * math.pi * 2 + L.Seed))
				L.Light.Range = L.Range
				L.Light.Color = steady
			else
				local n = noise(t * P.Light.Hz, L.Seed) * 0.75 + noise(t * P.Light.Hz * 2.7, L.Seed + 9) * 0.25
				L.Light.Brightness = L.Base * math.max(0.2, 1 + n * P.Light.Amp * 2)
				L.Light.Range = L.Range * (1 + n * P.Light.Amp * 0.25)
				L.Light.Color = W.Pyro.Base:Lerp(W.Pyro.Light, math.clamp(0.35 + n * 0.9, 0, 1))
			end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- AQUA: the falls' foam, splash and ripple rings moved to HubWaterfall (2026-10-25), with the falls rebuilt as real
-- moving water
----------------------------------------------------------------------------------------------------

----------------------------------------------------------------------------------------------------
-- ZEPHYR
----------------------------------------------------------------------------------------------------
do
	local Z = Tuning.Zephyr
	-- the air ribbons: an invisible carrier per ribbon moved round its crescent, a Trail between two attachments on it
	local ribbons = {}
	local RB = Z.Ribbon
	for ci, c in ipairs(Z.Crescents) do
		for k = 1, 2 do
			local carrier = part({ Name = "HubLife_ZephyrRibbon", Transparency = 1, Size = Vector3.new(0.1, 0.1, 0.1), CFrame = CFrame.new(c) })
			local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
			a0.Position, a1.Position = Vector3.new(0, RB.Width / 2, 0), Vector3.new(0, -RB.Width / 2, 0)
			a0.Parent, a1.Parent = carrier, carrier
			local tr = Instance.new("Trail")
			tr.Attachment0, tr.Attachment1 = a0, a1
			tr.Lifetime = RB.Life
			tr.FaceCamera = true
			tr.LightEmission, tr.LightInfluence = 1, 0
			tr.Color = ColorSequence.new(W.Zephyr.Light, W.Zephyr.Base)
			tr.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(0.6, 0.35),
				NumberSequenceKeypoint.new(1, 1) })
			tr.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.2) })
			tr.Parent = carrier
			ribbons[#ribbons + 1] = { Part = carrier, Centre = c, Phase = (k - 1) * 0.5 + ci * 0.21,
				Side = (ci == 1) and -1 or 1, Scale = (k == 1) and 1 or 0.82 }
		end
	end
	-- the leaves: small flat lozenges caught in a loop of wind round each crescent
	local L = Z.Leaves
	local leafColours = { W.Zephyr.Base, W.Zephyr.Light, Color3.fromHex("9FE8E0"), W.Zephyr.Dark }
	local leaves = {}
	local perMax = math.max(1, math.floor(L.PerCrescent * 1.15 + 0.5))
	for ci, c in ipairs(Z.Crescents) do
		for j = 1, perMax do
			local i = #leaves + 1
			local p = part({ Name = "HubLife_ZephyrLeaf", Size = L.Size, Material = Enum.Material.SmoothPlastic,
				Color = leafColours[(i % #leafColours) + 1], CFrame = CFrame.new(c) })
			local mesh = Instance.new("SpecialMesh")
			mesh.MeshType = Enum.MeshType.Sphere            -- a lozenge: a squashed sphere reads as a leaf
			mesh.Parent = p
			leaves[i] = { Part = p, Centre = c, Side = (ci == 1) and -1 or 1, Index = j,
				Phase = j / L.PerCrescent + math.random() * 0.06, Period = L.Period[1] + math.random() * (L.Period[2] - L.Period[1]),
				R = (math.random() * 2 - 1) * L.Jitter, Spin = math.random() * 10, Seed = i * 7.3 }
		end
	end
	-- the pennants: rigid segments hung from the frame's top corners, each segment lagging the one above
	local pennants = {}
	local PN = Z.Pennant
	for pi, pdef in ipairs(Z.Pennants) do
		local segs = {}
		for s = 1, PN.Segments do
			local w = PN.Width * (1 - (s - 1) / PN.Segments * 0.45)
			local p = part({ Name = "HubLife_ZephyrPennant", Size = Vector3.new(w, PN.Length, 0.06), Material = Enum.Material.SmoothPlastic,
				Color = (s % 2 == 1) and W.Zephyr.Base or W.Zephyr.Dark, CFrame = CFrame.new(pdef.At) })
			local edge = part({ Name = "HubLife_ZephyrPennantEdge", Size = Vector3.new(w + 0.1, 0.08, 0.08), Material = Enum.Material.Neon,
				Color = W.Zephyr.Light, CFrame = CFrame.new(pdef.At) })
			segs[s] = { Part = p, Edge = edge }
		end
		pennants[pi] = { At = pdef.At, Segs = segs, Seed = pi * 3.1 }
	end

	local moveParts, moveCFs = {}, {}
	onTick(function(t)
		table.clear(moveParts)
		table.clear(moveCFs)
		-- ribbons
		for _, r in ipairs(ribbons) do
			local th = ((t / RB.Period) + r.Phase) * math.pi * 2
			local s = r.Scale
			local pos = r.Centre + Vector3.new(r.Side * (0.4 + math.cos(th) * RB.Side * s), math.sin(th) * RB.Height * s,
				math.cos(th * 2) * RB.Depth)
			moveParts[#moveParts + 1] = r.Part
			moveCFs[#moveCFs + 1] = CFrame.new(pos)
		end
		-- leaves: up in front of the blade, over its tip, down behind it (a tall tilted loop), each on its own clock
		for _, l in ipairs(leaves) do
			local th = ((t / l.Period) + l.Phase) * math.pi * 2
			local a, b = L.A + l.R, L.B + l.R * 0.5
			local pos = l.Centre + Vector3.new(l.Side * (0.6 + math.cos(th) * a * 0.55) + math.sin(t * 1.3 + l.Seed) * 0.35,
				math.sin(th) * b, math.cos(th) * L.Depth + math.sin(t * 0.9 + l.Seed) * 0.4)
			local spin = t * (2.5 + l.Spin * 0.2) + l.Seed
			moveParts[#moveParts + 1] = l.Part
			moveCFs[#moveCFs + 1] = CFrame.new(pos) * CFrame.Angles(spin, spin * 0.7, th)
		end
		-- pennants: each segment hangs from the bottom of the one above, swaying a little more and a little later
		local sway = calm and PN.Sway * 0.5 or PN.Sway
		for _, pn in ipairs(pennants) do
			local cf = CFrame.new(pn.At)
			for s, seg in ipairs(pn.Segs) do
				local ang = math.rad(sway) * (0.35 + s * 0.22) * math.sin(t * PN.Hz * math.pi * 2 - s * PN.Lag + pn.Seed)
					+ math.rad(sway * 0.3) * noise(t * 0.4, pn.Seed + s)
				local twist = math.rad(sway * 0.5) * math.sin(t * PN.Hz * 1.3 * math.pi * 2 - s * PN.Lag + pn.Seed)
				cf = cf * CFrame.Angles(ang, twist * 0.3, ang * 0.25)
				local centre = cf * CFrame.new(0, -PN.Length / 2, 0)
				moveParts[#moveParts + 1] = seg.Part
				moveCFs[#moveCFs + 1] = centre
				moveParts[#moveParts + 1] = seg.Edge
				moveCFs[#moveCFs + 1] = cf * CFrame.new(0, -PN.Length + 0.04, 0.0)
				cf = cf * CFrame.new(0, -PN.Length, 0)
			end
		end
		workspace:BulkMoveTo(moveParts, moveCFs, Enum.BulkMoveMode.FireCFrameChanged)
	end)
	-- fewer leaves at lower density (hidden, not destroyed, so the count follows the setting both ways)
	HubLife.OnSettings(function()
		local n = HubLife.Count(L.PerCrescent, 2)
		for _, l in ipairs(leaves) do l.Part.Transparency = (l.Index <= n) and 0 or 1 end
	end)
end

----------------------------------------------------------------------------------------------------
-- TERRA: the new cracked arch (HubTerraArchData)
----------------------------------------------------------------------------------------------------
task.spawn(function()
	local mod = spell:WaitForChild("HubTerraArchData", 20)
	if not mod then return end
	local ok, D = pcall(require, mod)
	if not ok or type(D) ~= "table" or type(D.Pieces) ~= "table" then
		warn("[HubWingLife] HubTerraArchData unreadable: " .. tostring(D))
		return
	end
	local T = Tuning.Terra
	local arch = Instance.new("Folder")
	arch.Name = "HubLife_TerraArch"
	arch.Parent = folder
	local function vec(s, k)
		local a = string.split(s, ",")
		return Vector3.new(tonumber(a[1]), tonumber(a[2]), tonumber(a[3])) / (k or 1000)
	end
	local classes = D.Classes or {}
	local veins, built, failed = {}, 0, 0
	local meshes, given = {}, false
	-- OPTIONAL meshes (MeshBudget): built only while no skin's essential build runs; if one needs the room, the arch is
	-- given back and the old archway shows again
	local hidden = {}
	local function giveBack()
		if given then return end
		given = true
		for _, m in ipairs(meshes) do HubLife.Release(m) end
		table.clear(meshes)
		pcall(function() arch:Destroy() end)
		local visual = hub:FindFirstChild("Visual")
		for n, tr in pairs(hidden) do
			local p = visual and visual:FindFirstChild(n)
			if p then p.Transparency = tr end
		end
		folder:SetAttribute("TerraArchGivenBack", true)
	end
	local B = HubLife.Budget()
	if false and B then B.Optional(giveBack) end   -- (2026-10-27) stays: the first skin / wrap build released it for the session
	-- (2026-10-26, the owner) the rock stays off the two LOADOUT wall plaques beside the arch: the few pillar vertices that
	-- bulge over a plaque (seen from the plaza) are pushed back along the wall, just clear of it; nothing else moves
	local function clearPlaques(pc)
		local C = vec(pc.C)
		local a = string.split(pc.V, ",")
		local moved = false
		for i = 1, #a - 2, 3 do
			local w = C + Vector3.new(tonumber(a[i]), tonumber(a[i + 1]), tonumber(a[i + 2])) / 1000
			for _, Q in ipairs(T.Plaques) do
				local rel = w - Q.C
				local along, out = rel:Dot(Q.T), rel:Dot(Q.N)
				if math.abs(rel.Y) < Q.H and out > -1 and out < 6 and math.abs(along) < Q.W then
					w = w + Q.T * (((along >= 0) and Q.W or -Q.W) - along)
					local q = (w - C) * 1000
					a[i], a[i + 1], a[i + 2] = tostring(math.round(q.X)), tostring(math.round(q.Y)), tostring(math.round(q.Z))
					moved = true
				end
			end
		end
		return moved and table.concat(a, ",") or pc.V
	end

	for _, pc in ipairs(D.Pieces) do
		HubLife.WaitBudget()
		if given then return end
		local m = HubLife.DataMesh(clearPlaques(pc), pc.T)
		if m then
			meshes[#meshes + 1] = m
			local cls = classes[pc.Class] or {}
			local p = m.Part
			p.Name = "HubLife_Terra_" .. tostring(pc.Name)
			p.Color = Color3.fromHex(cls.Color or "826B24")
			p.Material = (cls.Material == "Neon") and Enum.Material.Neon or Enum.Material.SmoothPlastic
			p.Transparency = cls.Transparency or 0
			p.CastShadow = cls.Material ~= "Neon"
			p.CFrame = CFrame.new(vec(pc.C) + m.Off)
			p.Parent = arch
			built += 1
			local seg = string.match(tostring(pc.Name), "^Vein_(%d+)")
			if seg then veins[#veins + 1] = { Part = p, Index = tonumber(seg), Base = p.Color } end
		else
			failed += 1
		end
		if built % 6 == 0 then task.wait() end
	end
	if given then return end
	if built == 0 or failed > 0 then
		-- all or nothing: a half-built arch is worse than the old one
		warn("[HubWingLife] Terra arch: " .. failed .. " of " .. #D.Pieces .. " pieces did not build; the old archway stays")
		giveBack()
		return
	end
	-- the old frame, its growths and ivy, hidden on this client only (and again if streaming sends them back)
	local function hide()
		local visual = hub:FindFirstChild("Visual")
		for _, n in ipairs(D.Hide or {}) do
			local p = visual and visual:FindFirstChild(n)
			if p and p:IsA("BasePart") and p.Transparency < 1 then
				hidden[n] = hidden[n] or p.Transparency
				p.Transparency = 1
			end
		end
	end
	hide()
	task.spawn(function()
		while arch.Parent and not given do
			task.wait(3)
			if not given then hide() end
		end
	end)
	table.sort(veins, function(a, b) return a.Index < b.Index end)
	local nV = math.max(1, #veins)
	local period = (D.Vein and D.Vein.Period) or 2.4
	-- the crystal cluster's light(s)
	local glow = {}
	for _, L in ipairs(D.Lights or {}) do
		local holder = part({ Name = "HubLife_TerraLight", Transparency = 1, Size = Vector3.new(0.2, 0.2, 0.2), CFrame = CFrame.new(vec(L.At)),
			Parent = arch })
		local l = Instance.new("PointLight")
		l.Color = Color3.fromHex(L.Color or "CCBA5C")
		l.Range = L.Range or T.CrystalLight.Range
		l.Brightness = L.Brightness or T.CrystalLight.Brightness
		l.Shadows = false
		l.Parent = holder
		glow[#glow + 1] = { Light = l, Base = l.Brightness }
	end
	-- the pebble trickle
	local PB = T.Pebbles
	local pebbleTemplate, sources, pebbles = nil, {}, {}
	if D.Pebbles and D.Pebbles.V and D.Pebbles.Sources then
		local m = HubLife.DataMesh(D.Pebbles.V, D.Pebbles.T)
		if m then
			meshes[#meshes + 1] = m
			pebbleTemplate = m.Part
			pebbleTemplate.Color = W.Terra.Base
			for _, s in ipairs(D.Pebbles.Sources) do sources[#sources + 1] = vec(s) end
		end
	end
	local floorY = (D.Pebbles and D.Pebbles.Floor) or 0
	local nextPebble = 0
	onTick(function(t, dt)
		if not arch.Parent then return end
		-- the vein: a bright wave running down the segments in order, every `period` seconds (Reduce Flashing: a slow,
		-- shallow swell instead)
		local per = calm and period * 2.2 or period
		for _, v in ipairs(veins) do
			local ph = ((t / per) - (v.Index - 1) / nV * 0.6) % 1
			local k = math.max(0, 1 - math.abs(ph - 0.15) / 0.15)
			k = k * k * (3 - 2 * k)
			if calm then k = k * T.Vein.Calm + 0.15 end
			local base = T.Vein.Dim:Lerp(v.Base, 0.6 + 0.4 * math.sin(t * 1.3 + v.Index))
			v.Part.Color = base:Lerp(T.Vein.Peak, k)
		end
		local crown = 0.5 + 0.5 * math.sin((t / per) * math.pi * 2)
		for _, g in ipairs(glow) do g.Light.Brightness = g.Base * (0.75 + 0.35 * (calm and 0.5 or crown)) end
		-- pebbles
		if pebbleTemplate and #sources > 0 and t >= nextPebble then
			nextPebble = t + PB.Every / math.max(0.3, density) * (0.7 + math.random() * 0.6)
			local pb = nil
			for _, x in ipairs(pebbles) do
				if not x.Live then pb = x break end
			end
			if not pb and #pebbles < PB.Pool then
				pb = { Part = pebbleTemplate:Clone() }
				pb.Part.Parent = arch
				pebbles[#pebbles + 1] = pb
			end
			if pb then
				local src = sources[math.random(1, #sources)]
				pb.Live, pb.Pos, pb.Bounced, pb.Fade = true, src, false, nil
				pb.Vel = Vector3.new(0.6 + math.random() * 0.8, -0.5, (math.random() * 2 - 1) * 0.6)
				pb.Spin = Vector3.new(math.random() * 6, math.random() * 6, math.random() * 6)
				pb.Rot = CFrame.Angles(math.random() * 6, math.random() * 6, math.random() * 6)
				pb.Part.Color = (math.random() < 0.5) and W.Terra.Base or Color3.fromHex("6E5A2A")
				pb.Part.Transparency = 0
			end
		end
		for _, pb in ipairs(pebbles) do
			if pb.Live then
				pb.Vel += Vector3.new(0, -PB.Gravity * dt, 0)
				pb.Pos += pb.Vel * dt
				pb.Rot = pb.Rot * CFrame.Angles(pb.Spin.X * dt, pb.Spin.Y * dt, pb.Spin.Z * dt)
				local half = pebbleTemplate.Size.Y * 0.5
				if pb.Pos.Y <= floorY + half then
					pb.Pos = Vector3.new(pb.Pos.X, floorY + half, pb.Pos.Z)
					if not pb.Bounced and math.abs(pb.Vel.Y) > 2 then
						pb.Bounced = true
						pb.Vel = Vector3.new(pb.Vel.X * 0.5, -pb.Vel.Y * PB.Bounce, pb.Vel.Z * 0.5)
					else
						pb.Vel = Vector3.zero
						pb.Spin = Vector3.zero
						pb.Fade = pb.Fade or t
					end
				end
				if pb.Fade then
					local k = (t - pb.Fade) / PB.Fade
					pb.Part.Transparency = math.clamp(k, 0, 1)
					if k >= 1 then
						pb.Live = false
						pb.Part.Transparency = 1
					end
				end
				pb.Part.CFrame = CFrame.new(pb.Pos) * pb.Rot
			end
		end
	end)
	arch:SetAttribute("Pieces", built)
	arch:SetAttribute("Failed", failed)
	arch:SetAttribute("Veins", #veins)
end)

----------------------------------------------------------------------------------------------------
-- the clock: everything above runs while this client's camera is near the hub
----------------------------------------------------------------------------------------------------
local t0 = os.clock()
local broken = {}
RunService.RenderStepped:Connect(function(dt)
	if not HubLife.Close() then return end
	local t = os.clock() - t0
	for i, fn in ipairs(tickers) do
		if not broken[i] then
			local ok, err = pcall(fn, t, math.min(dt, 0.1))
			if not ok then
				broken[i] = true          -- one warning, then that piece stands still rather than spam every frame
				warn("[HubWingLife] " .. tostring(err))
			end
		end
	end
end)
folder:SetAttribute("Ready", true)

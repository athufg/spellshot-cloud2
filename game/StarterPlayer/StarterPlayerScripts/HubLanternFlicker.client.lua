--[[
	HubLanternFlicker (LocalScript, StarterPlayerScripts) -- 2026-10-15, on request: the Arcane Observatory hub's lanterns
	flicker like flames.

	(2026-10-27) The lanterns are NEW: real parts in hub.Lanterns, a Persistent model built in Edit by
	hub/lanterns_2026_10_27/build_lanterns.lua -- 62 models Lantern_<Name> (Kind Wall / Post / Standing). Each one has a
	Neon flame of three SpecialMesh spheres (Flame, FlameTip, FlamePoint; attribute FlameY = the part centre's height
	above the flame's base), half see-through amber Neon panes ("Glass"), a Neon "Ceiling" plate catching the glow
	inside the housing, and its own PointLight "LanternLight" in the Flame (attribute RestBrightness). On this client
	every lantern, on its own clock and tempo:
	  * its light's Brightness and the Neon colour of its flame, panes and ceiling move together -- a slow waver, a
	    gentle drift and now and then a soft gutter (the 2026-10-15 curve, unchanged);
	  * its flame flutters: taller and slimmer, shorter and rounder, leaning a little side to side, scaled about the
	    flame's base (SpecialMesh Scale + Offset, so no part ever moves). A gutter also shrinks the flame.
	The merged glow mesh (Visual.OBS_Lantern_Glow_01) is no longer split or hidden here -- no EditableMesh at all. The old
	hub.Lights.Light_Lantern* PointLights are disabled in Edit (kept, never deleted) and left alone. Nothing changes on
	the server.
	(2026-10-19, audit P6A-11) Reduce Flashing holds every lantern steady at its own brightness (no waver, no gutter);
	(2026-10-27) its flame keeps its size and only sways slowly.
]]

local RunService = game:GetService("RunService")
local Settings = require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Hub = "ArcaneObservatoryHub",
	Lanterns = "Lanterns",
	Centre = Vector3.new(8000, 0, 8000),
	FarAway = 500,                       -- no updates while the camera is further than this
	Near = 140,                          -- (2026-10-27) studs: only lanterns this close to the camera are animated
	Rate = 1 / 30,                       -- (2026-10-27) seconds between updates
	-- 2026-10-15, owner: "too fast -- every lantern should flick slowly and randomly". All noise now (no regular sine),
	-- slow, and each lantern on its own tempo (Tempo: a per-lantern multiplier picked from this range)
	Waver = { Hz = 0.45, Amount = 0.14 },
	Drift = { Hz = 1.1, Amount = 0.05 },                -- a gentler, quicker layer on top, still smooth
	Sputter = { Hz = 0.08, From = 0.34, Dip = 0.3 },    -- now and then (when the slowest noise passes From) it gutters
	Tempo = { 0.6, 1.4 },
	GlowMax = 1.35,                      -- the flame's, panes' and ceiling's brightest, as a multiple of their colour
	-- (2026-10-27) the flame's shape
	Flutter = { Hz = 1.6, Amount = 0.09 },   -- height wobble (x rest height)
	Slim = 0.5,                              -- width moves against height by this much (taller = slimmer)
	Gutter = 0.6,                            -- how much a dip in brightness shortens the flame
	Lean = { Hz = 0.7, Amount = 0.1 },       -- sideways shear, studs per stud of height
	ReduceLean = 0.5,                        -- Reduce Flashing keeps this much of the lean, nothing else
}

local hub = workspace:WaitForChild(Tuning.Hub, 60)
if not hub then return end
local root = hub:WaitForChild(Tuning.Lanterns, 60)
if not root then return end

local function seed(s)
	local h = 0
	for i = 1, #s do h = (h * 31 + s:byte(i)) % 1000003 end
	return h / 1000003 * 100
end

-- the lanterns: [model] = { Phase, At, Light, Brightness, Flames = { { Part, Mesh, Y, Colour } }, Glows = { { Part, Colour } } }
local lanterns = {}
local function add(m)
	if lanterns[m] or not m:IsA("Model") then return end
	local l = { Phase = seed(m.Name), At = m:GetPivot().Position, Flames = {}, Glows = {} }
	for _, p in ipairs(m:GetChildren()) do
		if p:IsA("BasePart") then
			local y = p:GetAttribute("FlameY")
			local mesh = p:FindFirstChildWhichIsA("SpecialMesh")
			if y and mesh then
				table.insert(l.Flames, { Part = p, Mesh = mesh, Y = y, Colour = p.Color })
				table.insert(l.Glows, { Part = p, Colour = p.Color })
				local light = p:FindFirstChild("LanternLight")
				if light and light:IsA("Light") then
					l.Light = light
					l.Brightness = light:GetAttribute("RestBrightness") or light.Brightness
				end
			elseif p.Name == "Ceiling" or p.Name == "Glass" then   -- the amber Neon panes breathe with the flame
				table.insert(l.Glows, { Part = p, Colour = p.Color })
			end
		end
	end
	if #l.Flames == 0 then return end
	lanterns[m] = l
end
for _, m in ipairs(root:GetChildren()) do add(m) end
root.ChildAdded:Connect(function(m) task.delay(0.5, add, m) end)

local noise = math.noise
local function level(phase, t)
	if Settings.Get("ReduceFlashing") then return 1 end   -- (P6A-11) steady
	local W, D, P = Tuning.Waver, Tuning.Drift, Tuning.Sputter
	-- this lantern's own tempo, fixed by its phase (so its light and its flame always agree)
	local lo, hi = Tuning.Tempo[1], Tuning.Tempo[2]
	t *= lo + (hi - lo) * ((phase * 7.31) % 1)
	local b = 1 + W.Amount * 2 * noise(t * W.Hz, phase) + D.Amount * 2 * noise(t * D.Hz, phase + 25)
	local slow = noise(t * P.Hz, phase + 50)
	if slow > P.From then b -= P.Dip * math.min((slow - P.From) / 0.15, 1) end
	return math.max(b, 0.35)
end

local function shade(c, b)
	return Color3.new(math.min(c.R * b, 1), math.min(c.G * b, 1), math.min(c.B * b, 1))
end

local t0 = os.clock()
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < Tuning.Rate then return end
	acc = 0
	local camera = workspace.CurrentCamera
	if not camera then return end
	local eye = camera.CFrame.Position
	if (eye - Tuning.Centre).Magnitude > Tuning.FarAway then return end
	local t = os.clock() - t0
	local reduce = Settings.Get("ReduceFlashing")
	local F, Ln = Tuning.Flutter, Tuning.Lean
	for m, l in pairs(lanterns) do
		if not m.Parent then
			lanterns[m] = nil
		elseif (l.At - eye).Magnitude <= Tuning.Near then
			local phase = l.Phase
			local b = level(phase, t)
			local lean = Ln.Amount * 2 * noise(t * Ln.Hz, phase + 100)
			local h, w = 1, 1
			if reduce then
				lean *= Tuning.ReduceLean
			else
				h = 1 + F.Amount * 2 * noise(t * F.Hz, phase + 75) + (math.min(b, 1) - 1) * Tuning.Gutter
				w = 1 - (h - 1) * Tuning.Slim
			end
			if l.Light then l.Light.Brightness = l.Brightness * b end
			local g = math.min(b, Tuning.GlowMax)
			for _, f in ipairs(l.Glows) do f.Part.Color = shade(f.Colour, g) end
			-- each sphere scaled about the flame's base: its centre (FlameY above the base) rides up or down with the
			-- height and over with the lean
			for _, f in ipairs(l.Flames) do
				f.Mesh.Scale = Vector3.new(w, h, w)
				f.Mesh.Offset = Vector3.new(lean * f.Y * h, f.Y * (h - 1), 0)
			end
		end
	end
end)

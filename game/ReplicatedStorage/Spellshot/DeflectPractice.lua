--[[
	DeflectPractice  (ModuleScript)  ->  ReplicatedStorage/Spellshot/DeflectPractice

	The range's PRACTICE SHOT (the "snowball"), shared half: its numbers, the flight maths and the parry window the server
	and every client agree on, the client's list of shots in flight, and the look of the practice shot -- a plain thrown
	ball and a plain hit, deliberately NOT Zephyr's.

	STATUS 2026-10-11: back in the game at the owner's request. The Zephyr v6 import (2026-10-06) retired this rig together
	with Deflect Gust, and left the range's SNOWBALLS pad switching nothing. Nothing parries the shot today (Deflect Gust
	is gone; CombatCore's OnParry / TryParry hooks are still there), so it simply flies at you and lands. Everything below
	about the parry describes the window a future parry would use.

	WHAT IT IS. Something live to parry, in the range:
	  * a training dummy with the Thrower attribute throws a practice shot at the nearest player in the range, one at
	    a time, a short pause after the last one ended (TrainingGround, server)
	  * Deflect Gust is an equippable Defense (2026-09-16): with it equipped, the Defense key (E by default) swings the
	    lead hand and asks the server for the cast (SpellshotInput). The server starts its 12 s cooldown on every press
	    it accepts, caught or whiffed (SpellshotService), and then checks the catch (ZephyrHandler -> CombatCore.TryParry
	    -> TrainingGround): a shot aimed at you that is inside the window is turned round where it is and flies back at
	    the dummy, unchanged -- same look, same Damage, same Kind. With nothing in the window the press is a whiff, and
	    the cooldown runs all the same
	  * the Parry Arc and the Wind Shear play where the shot turned round and the Trail rides it home (ZephyrFX)
	  * wherever the shot lands -- on you, or back on the dummy -- it plays its own plain hit and nothing else

	WHAT IT IS NOT YET: a parry of anything else. The only thing Deflect Gust can catch is this server-flown practice
	shot, and the catch is the client's claim, checked against the server's copy of the shot with ServerSlack. In a duel
	the defender must recognise somebody else's client-flown shot and substitute a new path. That is later work, and a
	press anywhere else is a whiff.

	A SHOT, as the server broadcasts it:
	  Id, Origin, Dir (unit), Speed, T0 (workspace:GetServerTimeNow()), Damage, Kind, Owner (the dummy), Target (a Player)
	  its position at server time t is Origin + Dir * Speed * (t - T0), out to Range studs. A returned shot is the same
	  shot with a new Origin (the contact), Dir (at the dummy) and T0.
]]

local TweenService = game:GetService("TweenService")

local DeflectPractice = {}

DeflectPractice.Tuning = {
	-- THE THROW (a Thrower dummy may override ThrowEvery / ThrowRange with attributes of the same names)
	ThrowEvery = 1.6,      -- s of quiet after a shot ends before the next wind-up
	ThrowRange = 70,       -- studs: the dummy throws at the nearest player in the range within this
	WindUp = 0.35,         -- s between turning to face you and letting go
	Speed = 42,            -- studs/s: quick enough to need a reaction, slow enough to read
	Range = 80,            -- studs a shot flies before it is spent
	Radius = 0.55,         -- the ball's radius, and its hit test
	Damage = 10,           -- carried by the shot, and carried back unchanged when it is returned
	Kind = "PracticeShot",
	HitFloor = 1,          -- a practice shot never takes a player below this much health: it is practice
	-- THE PARRY (the key is the Defense bind, and the cooldown is the ability's: VFXLibrary row DeflectGust)
	Window = 0.30,         -- s: a parry catches a shot that will reach you within this long ...
	BodyDepth = 1.5,       -- ... counted to your body, which it touches about this far before your root ...
	Behind = 0.5,          -- ... or has only just reached it ...
	Lateral = 4,           -- ... and is on a line that passes within this of you (studs)
	PressLatch = 0.5,      -- s at least that the client holds the next press back after one (2 x ping + 0.1 when that is
	                       -- longer), covering the moment before the server's cooldown reaches it (and the only spacing
	                       -- there is while a dev has No Cooldowns on)
	ServerSlack = 5,       -- studs the server allows over the client's view of the window (frame timing, ping)
}
local T = DeflectPractice.Tuning

--- Where a shot is at server time t, and how far it has flown.
function DeflectPractice.PositionAt(shot, t)
	local flown = math.clamp((t - shot.T0) * shot.Speed, 0, T.Range)
	return shot.Origin + shot.Dir * flown, flown
end

--- Whether a shot on its way OUT is inside the parry window for a body whose root is at `rootPos`, at server time t:
--- it will reach the body within Window, it is not already past it, and its line passes near. `slack` (studs) widens
--- every edge -- 0 for the client's own test, ServerSlack for the server's check of that claim. Returns ok, where the
--- shot is, and how far it still has to go along its path.
function DeflectPractice.InWindow(shot, rootPos, t, slack)
	slack = slack or 0
	local pos = DeflectPractice.PositionAt(shot, t)
	local to = rootPos - pos
	local ahead = to:Dot(shot.Dir)
	local lateral = (to - shot.Dir * ahead).Magnitude
	local ok = ahead <= shot.Speed * T.Window + T.BodyDepth + slack and ahead >= -T.Behind - slack * 0.5
		and lateral <= T.Lateral + slack
	return ok, pos, ahead
end

-- THE SHOTS IN FLIGHT, as this client has them: [id] = { Shot = the broadcast, State = "Out" | "Back", ... }. Filled by
-- DeflectGustPractice (client), which draws them; read by SpellshotInput for the catch claim. Every LocalScript that
-- requires this module shares the one table. On the server it stays empty (TrainingGround keeps its own).
DeflectPractice.Live = {}

--- The shot a parry by `player` would catch right now, from this client's view: aimed at them, still on its way out,
--- inside the window, the nearest one. Returns its Id and where it is (the contact), or nil.
function DeflectPractice.Catchable(player, rootPos, t)
	local bestId, bestAhead, bestPos = nil, math.huge, nil
	for id, s in pairs(DeflectPractice.Live) do
		local shot = s.Shot
		if s.State == "Out" and shot and shot.Target == player then
			local ok, pos, ahead = DeflectPractice.InWindow(shot, rootPos, t, 0)
			if ok and ahead < bestAhead then
				bestId, bestAhead, bestPos = id, ahead, pos
			end
		end
	end
	return bestId, bestPos
end

--- The aim point on a character: the upper torso (or the root).
function DeflectPractice.ChestOf(model)
	local torso = model and (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")
		or model:FindFirstChild("HumanoidRootPart"))
	return torso and torso.Position or nil
end

----------------------------------------------------------------------------------------------------
-- the practice shot's own look (client)
----------------------------------------------------------------------------------------------------
-- A plain white ball with a short white streak, and a plain white pop where it lands. Deflect Gust returns whatever
-- attack it catches with that attack's own look, so this stand-in is neutral on purpose: no teal, no ink, and it is
-- exactly the same ball, streak and pop on the way back.
local WHITE = Color3.fromRGB(245, 245, 245)

local function plainPart(name, size, parent)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = Enum.PartType.Ball
	p.Size = size
	p.Material = Enum.Material.SmoothPlastic
	p.Color = WHITE
	p.Anchored, p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = true, false, false, false, false
	p.Parent = parent
	return p
end

function DeflectPractice.MakeBall(parent)
	local p = plainPart("PracticeShot", Vector3.one * (T.Radius * 2), nil)
	local a0, a1 = Instance.new("Attachment"), Instance.new("Attachment")
	a0.Position, a1.Position = Vector3.new(0, T.Radius * 0.55, 0), Vector3.new(0, -T.Radius * 0.55, 0)
	a0.Parent, a1.Parent = p, p
	local streak = Instance.new("Trail")
	streak.Attachment0, streak.Attachment1 = a0, a1
	streak.Lifetime = 0.12
	streak.Color = ColorSequence.new(WHITE)
	streak.Transparency = NumberSequence.new(0.25, 1)
	streak.LightEmission = 0
	streak.FaceCamera = true
	streak.Parent = p
	p.Parent = parent
	return p
end

--- The shot's own hit: a plain white pop that swells and shrinks away (no fade, nothing else).
function DeflectPractice.Impact(position, parent)
	local p = plainPart("PracticeShotHit", Vector3.one * (T.Radius * 2), parent)
	p.CFrame = CFrame.new(position)
	local grow = TweenService:Create(p, TweenInfo.new(0.06, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Size = Vector3.one * 3.0 })
	local shrink = TweenService:Create(p, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = Vector3.one * 0.05 })
	grow.Completed:Connect(function() shrink:Play() end)
	shrink.Completed:Connect(function() p:Destroy() end)
	grow:Play()
end

return DeflectPractice

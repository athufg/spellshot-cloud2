--[[
	TrainingGround  (Script)  ->  ServerScriptService/TrainingGround

	Runs the test range in workspace.TrainingGround.

	Since 2026-10-20 it is THE one practice space, about 360 x 400 at the origin, for both SOLO TEST and the Hub's Training
	portal (both land on the spawn facing -Z, on map "TrainingGround"). Three zones run downrange (-Z) from the firing line
	at z 0: CLOSE (0-40, the dense cluster), MID + BOARDS (40-150, the boards' lane at x 80-130) and OPEN (150-350, the
	movers). The plain floor, the 25-stud distance lines and the low walls are TrainingGround.Set; the gate back to the Hub
	is TrainingGround.Interact.TG_ReturnPortal_Pane (HubServer wires it). How to undo: maps\training_grounds\CHANGES.md.

	DUMMIES  (Models with a Humanoid and the TrainingDummy attribute)
	  * take real damage from every ability, and pop each hit's number above the head (callouts then
	    grow and shrink with each viewer's distance -- PopupScaler, client)
	  * show the M1's Chill stacks as they land (CHILL x1, x2) and FROZEN! on the root, and Scorching
	    Lash's burn stacks as they build (BURN x1, x2, x3)
	  * cannot die: at 0 health they show KO and are straight back to full, so no hit is ever lost
	    on a dummy that is down
	  * refill to full REFILL_AFTER seconds after the last hit
	  * a dummy with StrafeA / StrafeB attributes walks back and forth between them, for practising
	    leading a moving target
	  * a dummy with PatrolA, PatrolB, PatrolC (and PatrolD) loops them in order at PatrolSpeed (2026-10-20)
	  * an anchored dummy with FlickerRadius / FlickerEvery jumps to a new spot in that disc every FlickerEvery
	    seconds, for flick-aim practice (2026-10-20)
	  * a dummy with the Thrower attribute throws a plain practice shot (the "snowball") at you, and the SNOWBALLS pad in
	    the range (ThrowerSwitch) pauses and starts it -- see THE THROWER and THE THROWER SWITCH below

	BOARDS  (Models with the TargetBoard attribute; the plate with the rings is the part "Face")
	  AbilityHandler fires ServerStorage.ShotImpact for every M1 impact. A hit on a board leaves a mark
	  where it landed and pops the ring score: 10 in the bull, then 8 / 6 / 4 / 2 outward.
	  (2026-10-20) So do the other kits' M1 handlers: Pyro, Zephyr, Terra, Voltaic and Umbra already did, and Aqua's
	  Riptide (and Sidearm) and Toxin's bubble now do too. Radiant's Light Lance claims bodies only, never a world point,
	  so it cannot score a board. A board scores only inside workspace.TrainingGround.

	THE CALLOUTS THEMSELVES ARE NOT THIS SCRIPT'S ANY MORE. They were, and that was a bug: every
	damage number and KO! in the game was built here and attached only to dummies, so hitting a real
	player showed nothing. The builder is Spellshot.Callouts now, and CombatFeedback gives players
	the same ones. The range still draws its own, through the same module.
]]

local ServerStorage = game:GetService("ServerStorage")
local Debris = game:GetService("Debris")
local spellFolder = game:GetService("ReplicatedStorage"):WaitForChild("Spellshot")
local Config = require(spellFolder:WaitForChild("SpellshotConfig"))
local Callouts = require(spellFolder:WaitForChild("Callouts"))
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local Practice = require(spellFolder:WaitForChild("DeflectPractice"))

local ground = workspace:WaitForChild("TrainingGround", 30)
if not ground then return end

local REFILL_AFTER = 3        -- seconds without a hit before a dummy is back to full
local MARK_LIFE = 8           -- seconds a hit mark stays on a board
local MARKS_PER_BOARD = 30

local INK = Color3.fromRGB(17, 17, 17)
local WHITE = Color3.new(1, 1, 1)
local RED = Color3.fromRGB(229, 38, 31)

local function make(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

----------------------------------------------------------------------------------------------------
-- THE THROWER: the range's practice shot (the "snowballs")
----------------------------------------------------------------------------------------------------
-- A dummy with the Thrower attribute throws a plain practice shot at the nearest player standing in the range, one
-- shot at a time, ThrowEvery seconds after the last one ended. The shot is flown HERE, from the moment it leaves the
-- dummy's hand; every client draws it from the broadcasts on the server's clock (DeflectGustPractice). It ends one of
-- three ways:
--   it reaches the player       -> they take its Damage (never below HitFloor -- it is practice) and it plays its hit
--   something parries it        -> it turns round where it is, unchanged, and flies back at the dummy, where it does
--                                  the same Damage (the range pops the number as for any hit) and plays the same hit
--   it flies out of Range       -> spent
-- HISTORY. This was the Deflect Gust practice rig. The Zephyr v6 import (2026-10-06) retired it with Deflect Gust and
-- left the SNOWBALLS pad in the range switching nothing; the owner asked for it back on 2026-10-11. Deflect Gust is
-- still gone, so nothing parries the shot today: tryParry stays registered with CombatCore's generic OnParry hook for
-- whatever parries next. The numbers and the look are ReplicatedStorage.Spellshot.DeflectPractice's.
-- A dummy with the ThrowerOff attribute set does not throw (the pad sets it; a tool may set it by hand).
local PT = Practice.Tuning

local practiceRemote = spellFolder:FindFirstChild("DeflectPracticeRemote")
if not practiceRemote then
	practiceRemote = Instance.new("RemoteEvent")
	practiceRemote.Name = "DeflectPracticeRemote"
	practiceRemote.Parent = spellFolder
end
-- Server -> client only (the shot broadcasts). Anything a client fires at it is drained and ignored, rather than left
-- queued: a parry goes through a cast and CombatCore.TryParry, never through here.
practiceRemote.OnServerEvent:Connect(function() end)

local shots = {}          -- [id] = the live shot
local shotSerial = 0

local function inRange(player)
	-- never a duellist (2026-10-19, audit P1-04): the thrower is the Solo Test's, and its TakeDamage skips every shield
	return player:GetAttribute("Zone") == "Arena" and player:GetAttribute("Map") == "TrainingGround"
		and player:GetAttribute("DuelMatch") == nil
end

local function broadcast(action, shot, extra)
	local d = {
		Id = shot.Id, Origin = shot.Origin, Dir = shot.Dir, Speed = shot.Speed, T0 = shot.T0,
		Damage = shot.Damage, Kind = shot.Kind, Owner = shot.Owner, Target = shot.Target,
	}
	for k, v in pairs(extra or {}) do d[k] = v end
	practiceRemote:FireAllClients(action, d)
end

--- The shot's sweep from `from` to `to` against the one body it can land on (the player on the way out, the dummy on
--- the way back) and any standing Bulwark Wall (2026-10-14, on request: a wall is cover, so a snowball that reaches one
--- stops there and damages it, as any enemy hit does). Anything else in the range it passes straight through: it is a
--- timing drill, not a firing lane.
local walls = {}          -- [model] = true: the Bulwark Walls standing in Workspace (TerraHandler parents them there)
local function trackWall(model)
	if not model:IsA("Model") then return end
	task.defer(function()   -- WallOwner is set before the parent, but defer in case a wall is ever built the other way
		if model.Parent == workspace and model:GetAttribute("WallOwner") ~= nil then walls[model] = true end
	end)
end
for _, child in ipairs(workspace:GetChildren()) do trackWall(child) end
workspace.ChildAdded:Connect(trackWall)
workspace.ChildRemoved:Connect(function(child) walls[child] = nil end)

local function wallOf(instance)
	for model in pairs(walls) do
		if instance:IsDescendantOf(model) then return model end
	end
	return nil
end

local sweepParams = RaycastParams.new()
sweepParams.FilterType = Enum.RaycastFilterType.Include
local function sweep(from, to, body)
	local delta = to - from
	if delta.Magnitude < 1e-3 then return nil end
	local list = {}
	if body and body.Parent then list[1] = body end
	for model in pairs(walls) do
		local humanoid = model.Parent and model:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then list[#list + 1] = model end
	end
	if #list == 0 then return nil end
	sweepParams.FilterDescendantsInstances = list
	return workspace:Spherecast(from, PT.Radius, delta, sweepParams)
end

local Core = nil          -- CombatCore, once it has loaded (below): the wall's hits go through Core.DealDamage
-- What one snowball takes off a Bulwark Wall (2026-10-14, on request: the wall must actually come down). The shot's
-- own Damage (10) would need 20 hits on a 200 HP wall, far longer than a wall stands, so it only ever cracked: at 70
-- the third snowball breaks it. EVERY NUMBER HERE IS A PROPOSAL.
local WALL_DAMAGE = 70

local function land(shot, position, body)
	shots[shot.Id] = nil
	local humanoid = body and body:FindFirstChildOfClass("Humanoid")
	if body and walls[body] then
		-- a Bulwark Wall: WALL_DAMAGE, from no caster (an enemy to every wall), through Core.DealDamage so the wall's
		-- own hit listener (TerraHandler) plays the hit at `position` and breaks it at 0 -- the TerraTestServer path
		if humanoid and humanoid.Health > 0 then
			if Core then
				Core.DealDamage(nil, humanoid, WALL_DAMAGE, { Ranged = true, From = position })
			else
				humanoid:TakeDamage(WALL_DAMAGE)
			end
		end
	elseif humanoid and humanoid.Health > 0 then
		local amount = shot.Damage
		if shot.State == "Out" then
			-- 2026-10-23: nothing once the target has left the range (a shot still in flight after the Hub refill)
			amount = inRange(shot.Target) and math.min(amount, math.max(0, humanoid.Health - PT.HitFloor)) or 0
		end
		if amount > 0 then humanoid:TakeDamage(amount) end
	end
	broadcast("Land", shot, { Position = position, On = body })
end

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for id, shot in pairs(shots) do
		local pos, flown = Practice.PositionAt(shot, now)
		local from = shot.Last or shot.Origin
		shot.Last = pos
		local body = (shot.State == "Out") and (shot.Target and shot.Target.Character) or shot.Owner
		local hit = sweep(from, pos, body)
		if hit then
			land(shot, hit.Position, wallOf(hit.Instance) or body)
		elseif flown >= PT.Range then
			shots[id] = nil
			broadcast("Spent", shot, { Position = pos })
		end
	end
end)

--- THE PARRY: a catch claim, checked against where the SERVER has the shot. It must be aimed at them, still on its way
--- out, near, and not already past them (ServerSlack allows for frame timing). A claim that fails catches nothing --
--- the shot carries on and lands. Only CombatCore.TryParry calls this, from a cast the server has already accepted;
--- nothing a client fires reaches it directly. Returns whether it caught. (2026-10-19, audit P3-24) Nothing calls TryParry
--- today -- Deflect Gust was retired on 2026-10-06 (see HISTORY above) -- so this is kept for whatever parries next.
local function tryParry(player, claim)
	if type(claim) ~= "table" or type(claim.Id) ~= "number" then return false end
	local shot = shots[claim.Id]
	if not (shot and shot.State == "Out" and shot.Target == player) then return false end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid and humanoid.Health > 0 and inRange(player)) then return false end
	local now = workspace:GetServerTimeNow()
	local ok, pos = Practice.InWindow(shot, root.Position, now, PT.ServerSlack)
	if not ok then return false end
	-- it turns round where the parrier saw it, if that is near where it really is
	local contact = pos
	if typeof(claim.Contact) == "Vector3" and (claim.Contact - pos).Magnitude <= PT.ServerSlack then
		contact = claim.Contact
	end
	local aim = Practice.ChestOf(shot.Owner) or (shot.Origin - shot.Dir)
	local incoming = shot.Dir
	shot.State, shot.Parrier = "Back", player
	shot.Origin, shot.Dir, shot.T0, shot.Last = contact, (aim - contact).Unit, now, nil
	-- Speed, Damage and Kind are left exactly as they were: it is the same attack, going home
	broadcast("Return", shot, { Incoming = incoming, Parrier = player })
	return true
end

-- Registered with CombatCore without holding the range up: CombatCore waits on SpellshotService's bindables, and the
-- dummies and boards must work whether or not it is there.
task.spawn(function()
	local ok, core = pcall(require, script.Parent:WaitForChild("CombatCore"))
	if ok and type(core) == "table" then Core = core end
	if ok and type(core) == "table" and core.OnParry then
		core.OnParry(tryParry)
	else
		warn("[TrainingGround] CombatCore unavailable - the thrower's shots cannot be parried: " .. tostring(core))
	end
end)

local function setupThrower(model, root)
	local hand = model:FindFirstChild("RightHand") or root
	task.spawn(function()
		while model.Parent do
			task.wait(model:GetAttribute("ThrowEvery") or PT.ThrowEvery)
			if model:GetAttribute("ThrowerOff") then continue end
			local target, best = nil, model:GetAttribute("ThrowRange") or PT.ThrowRange
			for _, p in ipairs(Players:GetPlayers()) do
				local c = p.Character
				local h = c and c:FindFirstChildOfClass("Humanoid")
				local chest = Practice.ChestOf(c)
				if inRange(p) and h and h.Health > 0 and chest then
					local d = (chest - root.Position).Magnitude
					if d < best then target, best = p, d end
				end
			end
			if target then
				-- turn to face them (about the root, on the flat), wind up, and let go at where they are then
				local chest = Practice.ChestOf(target.Character)
				local offset = root.CFrame:ToObjectSpace(model:GetPivot())
				model:PivotTo(CFrame.lookAt(root.Position, Vector3.new(chest.X, root.Position.Y, chest.Z)) * offset)
				task.wait(PT.WindUp)
				chest = target.Character and Practice.ChestOf(target.Character)
				if chest and model.Parent and inRange(target) and not model:GetAttribute("ThrowerOff") then
					local origin = hand.Position
					shotSerial += 1
					local shot = {
						Id = shotSerial, Origin = origin, Dir = (chest - origin).Unit, Speed = PT.Speed,
						T0 = workspace:GetServerTimeNow(), Damage = PT.Damage, Kind = PT.Kind,
						Owner = model, Target = target, State = "Out",
					}
					shots[shot.Id] = shot
					broadcast("Throw", shot)
					while shots[shot.Id] and model.Parent do
						task.wait(0.05)
					end
				end
			end
		end
	end)
end

----------------------------------------------------------------------------------------------------
-- dummies
----------------------------------------------------------------------------------------------------
local function setupDummy(model)
	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local head = model:FindFirstChild("Head")
	local root = model:FindFirstChild("HumanoidRootPart")
	if not (humanoid and head and root) then return end
	-- a player's health, so a dummy takes as many hits to KO as a real opponent
	humanoid.MaxHealth = Config.MaxHealth
	humanoid.Health = Config.MaxHealth
	humanoid.BreakJointsOnDeath = false
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	-- health can reach 0 without the Humanoid dying, so the dummy just refills
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Dead, false)

	-- overhead health bar, in the HUD's ink-outlined style. Sized in STUDS, not pixels, so it shrinks
	-- with distance like the dummy does -- a pixel-sized bar is as big on a far dummy as a near one,
	-- and the bars of a row of dummies pile up on top of each other.
	local bb = make("BillboardGui", {
		Name = "DummyBar", Adornee = head, Size = UDim2.fromScale(3.6, 1.1), StudsOffset = Vector3.new(0, 2.1, 0),
		LightInfluence = 0, MaxDistance = 160,
	}, head)
	local title = make("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.42), Font = Enum.Font.GothamBlack,
		Text = "TRAINING DUMMY", TextColor3 = WHITE, TextScaled = true,
	}, bb)
	make("UIStroke", { Color = INK, Thickness = 1.2 }, title)
	local trough = make("Frame", {
		BackgroundColor3 = WHITE, BorderSizePixel = 0, Position = UDim2.fromScale(0.04, 0.5), Size = UDim2.fromScale(0.92, 0.46),
	}, bb)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, trough)
	make("UIStroke", { Color = INK, Thickness = 1.5 }, trough)
	local fill = make("Frame", { BackgroundColor3 = RED, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1) }, trough)
	make("UICorner", { CornerRadius = UDim.new(0.3, 0) }, fill)
	local number = make("TextLabel", {
		BackgroundTransparency = 1, Size = UDim2.fromScale(1, 0.9), Position = UDim2.fromScale(0, 0.05),
		Font = Enum.Font.LuckiestGuy, Text = "100", TextColor3 = WHITE, TextScaled = true, ZIndex = 2,
	}, trough)
	make("UIStroke", { Color = INK, Thickness = 1 }, number)

	local shown = humanoid.Health
	local lastHit = 0
	local knockedOut = false
	local function refresh()
		fill.Size = UDim2.fromScale(math.clamp(humanoid.Health / humanoid.MaxHealth, 0, 1), 1)
		number.Text = tostring(math.max(0, math.floor(humanoid.Health + 0.5)))
	end
	humanoid.HealthChanged:Connect(function(health)
		local lost = shown - health
		shown = health
		refresh()
		if lost > 0.05 then
			lastHit = os.clock()
			Callouts.Pop(head, Vector3.new(0, 1.2, 0), tostring(math.floor(lost + 0.5)), "damage")
			if health <= 0 and not knockedOut then
				knockedOut = true
				Callouts.Pop(head, Vector3.new(0, 2.8, 0), "KO!", "ko")
				-- straight back up. It used to sit at 0 for 1.5 s, and a dummy at 0 takes no damage, so about
				-- one hit in six at the full fire rate landed on a downed dummy and did nothing
				task.defer(function()
					knockedOut = false
					humanoid.Health = humanoid.MaxHealth
				end)
			end
		end
	end)
	task.spawn(function()
		while model.Parent do
			task.wait(0.5)
			if not knockedOut and humanoid.Health < humanoid.MaxHealth and os.clock() - lastHit > REFILL_AFTER then
				humanoid.Health = humanoid.MaxHealth
			end
		end
	end)
	refresh()

	-- the M1's Chill stacks as they land: CHILL x1, x2, x3 (the third is the deepest slow, 2026-10-08)
	model:GetAttributeChangedSignal("RX_Chilled_Stacks"):Connect(function()
		local n = model:GetAttribute("RX_Chilled_Stacks")
		if n and n >= 1 then
			Callouts.Pop(head, Vector3.new(0, 2.6, 0), "CHILL x" .. n, "chill")
		end
	end)

	-- Scorching Lash's burn stacks as they build (2026-09-23), exactly as CombatFeedback pops them over a player: BURN xN
	-- in a slot of its own ("burn"), and only on a RISE. PyroHandler owns the count; the refill never touches it
	local burnShown = model:GetAttribute("RX_Burning_Stacks") or 0
	model:GetAttributeChangedSignal("RX_Burning_Stacks"):Connect(function()
		local n = model:GetAttribute("RX_Burning_Stacks") or 0
		if n > burnShown then
			Callouts.Pop(head, Vector3.new(0, 2.6, 0), "BURN x" .. n, "burn")
		end
		burnShown = n
	end)

	-- FROZEN! stays up for as long as the dummy is actually frozen, whatever froze it (the M1's third
	-- stack, Flash Freeze, Chill Aura, the Beam): it follows the IceFrozenState that
	-- VFXLibrary.ApplyFrozenState puts on the character, and lets go when that goes. A re-freeze
	-- replaces the state object, so a removal is only believed if nothing replaced it that frame.
	local releaseFrozen
	local function freezeChanged()
		local frozen = model:FindFirstChild("IceFrozenState") ~= nil
		if frozen and not releaseFrozen then
			releaseFrozen = Callouts.Pop(head, Vector3.new(0, 2.6, 0), "FROZEN!", "frozen", true)
		elseif not frozen and releaseFrozen then
			releaseFrozen()
			releaseFrozen = nil
		end
	end
	model.ChildAdded:Connect(function(c)
		if c.Name == "IceFrozenState" then freezeChanged() end
	end)
	model.ChildRemoved:Connect(function(c)
		if c.Name == "IceFrozenState" then task.defer(freezeChanged) end
	end)

	-- THE WALKERS (the strafer, the patroller) share one setup: unanchored, walking at their pace, the server owning
	-- their physics. A slow or a root (from any ability) caps their speed; nothing puts a non-player's speed back, so the
	-- pace is restored here whenever the cap changes or clears. (2026-10-20: was the strafer's alone.)
	local function walker(speed)
		root.Anchored = false
		humanoid.WalkSpeed = speed
		local pace = speed
		model:GetAttributeChangedSignal("SpeedCapSlow"):Connect(function()
			local cap = model:GetAttribute("SpeedCapSlow")
			humanoid.WalkSpeed = cap and math.min(pace, cap) or pace
		end)
		pcall(function() root:SetNetworkOwner(nil) end)
	end

	-- 2026-10-23: MoveTo, then MoveToFinished with a timeout. A walker destroyed mid-walk never fires MoveToFinished, so a
	-- bare :Wait() held its loop forever; this gives up after 9 s (Roblox's own MoveTo timeout is 8). Returns whether it got there.
	local function walkTo(goal)
		humanoid:MoveTo(goal)
		local thread = coroutine.running()
		local timeout
		local finished = humanoid.MoveToFinished:Once(function(reached)
			task.cancel(timeout)
			task.spawn(thread, reached)
		end)
		timeout = task.delay(9, function()
			finished:Disconnect()
			task.spawn(thread, false)
		end)
		return coroutine.yield() == true
	end

	-- the strafer: StrafeA <-> StrafeB
	local a, b = model:GetAttribute("StrafeA"), model:GetAttribute("StrafeB")
	local path = {}
	for _, key in ipairs({ "PatrolA", "PatrolB", "PatrolC", "PatrolD" }) do
		local p = model:GetAttribute(key)
		if typeof(p) == "Vector3" then path[#path + 1] = p end
	end
	if typeof(a) == "Vector3" and typeof(b) == "Vector3" then
		walker(model:GetAttribute("StrafeSpeed") or 16)
		task.spawn(function()
			local goal = b
			while model.Parent do
				walkTo(goal)
				goal = (goal == b) and a or b
				task.wait(0.2)
			end
		end)
	elseif #path >= 3 then
		-- (2026-10-20) THE PATROLLER: PatrolA, B, C (and D) in order, round and round, at PatrolSpeed. A MoveTo that gives
		-- up (Roblox's 8-second timeout, or held still by a root) is sent to the same point once more before going on.
		walker(model:GetAttribute("PatrolSpeed") or 16)
		task.spawn(function()
			local i = 1
			while model.Parent do
				local goal = path[i]
				if not walkTo(goal) and model.Parent then
					walkTo(goal)
				end
				i = i % #path + 1
				task.wait(0.2)
			end
		end)
	end

	-- (2026-10-20) THE FLICKER: an anchored dummy that jumps to a new spot every FlickerEvery seconds, for flick-aim
	-- practice. Its pivot at setup is the centre; each new spot is in the FlickerRadius disc round it, at least 0.4 x the
	-- radius from where it stands, at the same height and facing. It holds still while frozen (IceFrozenState), rooted
	-- (SpeedCapSlow 0) or down, so FROZEN! and a root still read. The hitbox twins are welded and go with it; CombatCore
	-- keeps a second of where it was, so a shot fired at the old spot just before a hop still counts.
	local radius, every = model:GetAttribute("FlickerRadius"), model:GetAttribute("FlickerEvery")
	if type(radius) == "number" and radius > 0 and type(every) == "number" and every > 0 then
		local centre = model:GetPivot()
		task.spawn(function()
			while model.Parent do
				task.wait(every)
				local held = knockedOut or model:FindFirstChild("IceFrozenState") ~= nil
					or model:GetAttribute("SpeedCapSlow") == 0
				if not held and model.Parent then
					local here = model:GetPivot().Position
					for _ = 1, 12 do
						local angle, r = math.random() * 2 * math.pi, radius * math.sqrt(math.random())
						local spot = centre.Position + Vector3.new(math.cos(angle) * r, 0, math.sin(angle) * r)
						if (spot - here).Magnitude >= 0.4 * radius then
							model:PivotTo(centre.Rotation + spot)
							break
						end
					end
				end
			end
		end)
	end

	if model:GetAttribute("Thrower") then
		setupThrower(model, root)
	end
end

----------------------------------------------------------------------------------------------------
-- boards
----------------------------------------------------------------------------------------------------
local marks = {}   -- [board] = { frames in order }

local function boardHit(board, position)
	local face = board:FindFirstChild("Face")
	local gui = face and face:FindFirstChild("Rings")
	if not gui then return end
	local rel = face.CFrame:PointToObjectSpace(position)
	-- 0 at the centre, 1 at the rim of the outer ring (the rings fill the plate's width)
	local r = Vector2.new(rel.X, rel.Y).Magnitude / (face.Size.X * 0.5)
	local score = (r <= 0.2 and 10) or (r <= 0.4 and 8) or (r <= 0.6 and 6) or (r <= 0.8 and 4) or (r <= 1 and 2) or 0

	-- the mark, where the shard landed. The Front face is seen looking along the part's +Z, so the
	-- viewer's right is the part's -X.
	local u = 0.5 - rel.X / face.Size.X
	local v = 0.5 - rel.Y / face.Size.Y
	local mark = make("Frame", {
		Name = "Mark", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(u, v),
		Size = UDim2.fromScale(0.05, 0.05), BackgroundColor3 = Color3.fromRGB(90, 180, 255), BorderSizePixel = 0, ZIndex = 20,
	}, gui)
	make("UICorner", { CornerRadius = UDim.new(0.5, 0) }, mark)
	make("UIStroke", { Color = INK, Thickness = 2 }, mark)
	local list = marks[board] or {}
	marks[board] = list
	list[#list + 1] = mark
	if #list > MARKS_PER_BOARD then
		local oldest = table.remove(list, 1)
		if oldest.Parent then oldest:Destroy() end
	end
	task.delay(MARK_LIFE, function()
		if mark.Parent then mark:Destroy() end
		local i = table.find(list, mark)
		if i then table.remove(list, i) end
	end)

	Callouts.Pop(face, Vector3.new(0, face.Size.Y * 0.5 + 1, 0), score > 0 and ("+" .. score) or "EDGE",
		score >= 10 and "bull" or "score")
end

local shotImpact = ServerStorage:WaitForChild("ShotImpact", 30)
if shotImpact then
	shotImpact.Event:Connect(function(part, position)
		local board = part and part:FindFirstAncestorWhichIsA("Model")
		if board and board:GetAttribute("TargetBoard") and board:IsDescendantOf(ground) then
			boardHit(board, position)
		end
	end)
end

for _, d in ipairs(ground:GetDescendants()) do
	if d:IsA("Model") and d:GetAttribute("TrainingDummy") then setupDummy(d) end
end

----------------------------------------------------------------------------------------------------
-- THE THROWER SWITCH: the SNOWBALLS pad in the range (ThrowerSwitch) that pauses and starts the Thrower dummies
----------------------------------------------------------------------------------------------------
-- Step onto the pad to toggle. OFF sets ThrowerOff on every Thrower dummy, which setupThrower reads before it winds up;
-- a shot already in the air finishes its flight. The sign and the pad's colour follow. The 2026-09-26 original went in
-- the Zephyr v6 import and no copy of it was left on this PC, so this is a rewrite to the same behaviour (2026-10-11).
-- Who is on the pad is polled a few times a second rather than read from Touched: a player standing still fires no
-- touch events, and a lost TouchEnded would leave the pad stuck.
local switch = ground:FindFirstChild("ThrowerSwitch")
local switchButton = switch and switch:FindFirstChild("Button")
if switchButton and switchButton:IsA("BasePart") then
	local sign = switch:FindFirstChild("State", true)
	local PAD_ON, PAD_OFF = Color3.fromRGB(46, 204, 113), RED
	local throwing = true
	for _, d in ipairs(ground:GetDescendants()) do
		if d:IsA("Model") and d:GetAttribute("Thrower") and d:GetAttribute("ThrowerOff") then throwing = false end
	end
	local function paint()
		for _, d in ipairs(ground:GetDescendants()) do
			if d:IsA("Model") and d:GetAttribute("Thrower") then
				d:SetAttribute("ThrowerOff", (not throwing) or nil)
			end
		end
		if sign and sign:IsA("TextLabel") then sign.Text = throwing and "SNOWBALLS: ON" or "SNOWBALLS: OFF" end
		switchButton.Color = throwing and PAD_ON or PAD_OFF
	end
	paint()
	task.spawn(function()
		-- the space a player's legs are in when they stand on the pad (the pad is a disc lying flat, 6.5 across)
		local top = switchButton.Position.Y + 0.5
		local box = CFrame.new(switchButton.Position.X, top + 2, switchButton.Position.Z)
		local size = Vector3.new(5, 4, 5)
		local onPad = {}   -- [player] = true while they stand on it
		while switch.Parent do
			task.wait(0.15)
			local seen = {}
			for _, part in ipairs(workspace:GetPartBoundsInBox(box, size)) do
				local player = Players:GetPlayerFromCharacter(part.Parent)
				if player then seen[player] = true end
			end
			for player in pairs(seen) do
				if not onPad[player] then
					throwing = not throwing
					paint()
				end
			end
			onPad = seen
		end
	end)
end
----------------------------------------------------------------------------------------------------

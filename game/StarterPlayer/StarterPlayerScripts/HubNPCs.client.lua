--[[
	HubNPCs  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/HubNPCs

	THE HUB's TWO NPCs (2026-10-25, the owner's hub-rebuild brief, step 3). No dialogue: each greets you and offers the one
	thing its wing does. Client only, runs only while HubLife.On() (Studio until the owner's review).

	  LOADOUT KEEPER (Terra)  on the Loadout room's floor in front of the altar. His prompt is HubServer's own altar prompt
	                          ("Loadout Altar" / "Choose Techniques"), which HubLifeServer hangs beside him.
	  SHOP MERCHANT (Pyro)    leaning on the Store's counter. His prompt ("Store" / "Shop") is made here and opens the shop
	                          the way the HUD's SHOP chip does (SpellshotShop.Command "open"); it is parented into the hub
	                          model so HubClient gives it the player's Interact bind like every hub prompt.

	BOTH are the R15 mannequin (ReplicatedStorage.Spellshot.HubLifeMannequin) wearing accessories modelled in Blender, with an
	idle loop and a greet authored in Blender on that rig's skeleton and baked to Motor6D Transforms (HubNPCData, made by
	hub/hub_life_2026_10_25/npcs). Nothing is animated by hand here: this script only samples the baked clips, poses the
	rig by forward kinematics (every part anchored, one BulkMoveTo a frame) and adds three things the clips cannot know:
	  * the greet fires when YOU come within the NPC's Greet distance (again once you have walked past Leave);
	  * the head turns toward you (a look-at yaw/pitch on the Neck, on top of the clip, clamped and eased);
	  * the prompt stays hidden until the greet's PromptAt moment (the greet plays before the prompt appears).
	Clip changes crossfade (Tuning.Crossfade). The glow channels (the Keeper's tablet and chest inlay, the Merchant's
	lantern) drive their Neon pieces' colour and their lights.
	MESHES: built from the data as EditableMesh copies, after any essential skin build (MeshBudget.Busy), and given back
	if an essential build needs the room (MeshBudget.Optional): the NPCs then stand down for the session.

	(2026-10-27) SEVEN AMBIENT NPCs (HubNPCData Ambient = true; marks in HubLife.NPC): TrainingDrill and TrainingWatch
	(Training), DuelsWatchA / DuelsWatchB (Duels terrace), StoreTalk / StoreListen / StoreLean (by the Store's stair).
	Built exactly like the two above (the same rig, pieces and body) but they ONLY loop their Idle: no prompt, no greet,
	no look-at (their head turns are baked into the clip's Neck), nothing reacting to players. Each starts at its own
	point in its loop (the mark's Phase), so the pairs never move in step. The Keeper and Merchant are built first.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end

local player = Players.LocalPlayer
local hub = workspace:WaitForChild(HubLife.Hub, 60)
if not hub then return end
local dataModule = spell:WaitForChild("HubNPCData", 60)
if not dataModule then return end
local okD, D = pcall(require, dataModule)
if not okD or type(D) ~= "table" or type(D.NPCs) ~= "table" then
	warn("[HubNPCs] HubNPCData unreadable: " .. tostring(D))
	return
end

-- EVERY NUMBER HERE IS A PROPOSAL
local Tuning = {
	Crossfade = 0.25,
	Look = { Yaw = 55, Pitch = 15, Speed = 7, Range = 26 },
	Rearm = 6,                         -- seconds before the same NPC greets again (after you walked past Leave)
	SameFloor = 6,                     -- studs of height difference within which an NPC notices you
	GlowLight = { Lo = 0.45, Hi = 1.6 },
	Far = 140,                         -- no posing past this from the NPC
	Prompts = {
		-- reach 7: from the counter's front a player is ~5 away; from the Training room under the Store floor (a jump puts
		-- the root at about y 8) the prompt (y 16.3) is over 8 away
		Merchant = { Object = "Store", Action = "Shop", Hold = 0.2, Distance = 8 },
	},
}

local Budget = nil
pcall(function()
	local ice = ReplicatedStorage:FindFirstChild("IceMagic")
	local m = ice and ice:FindFirstChild("MeshBudget")
	Budget = m and require(m) or nil
end)

local folder = Instance.new("Folder")
folder.Name = "HubLife_NPCs"
folder.Parent = workspace

-- the Keeper's prompt is HubServer's altar prompt (HubLifeServer hangs it beside him): hidden from the moment it is
-- found until his greet lands; given back (shown) if the Keeper cannot be built, is released, or fails
local keeperPrompt, keeperDown = nil, false
local function keeperFallback()
	keeperDown = true
	if keeperPrompt then
		local link = keeperPrompt:FindFirstChild("BubbleAt")     -- (its balloon goes back to the prompt's own part)
		if link then link:Destroy() end
		keeperPrompt.Enabled = true
	end
end
task.spawn(function()
	local anchor = hub:WaitForChild("TechniqueTablePrompt", 60)
	local pp = anchor and (anchor:FindFirstChildWhichIsA("ProximityPrompt") or anchor:WaitForChild("ProximityPrompt", 10))
	if pp and pp:IsA("ProximityPrompt") then
		keeperPrompt = pp
		pp.Enabled = keeperDown
	end
end)

local function ints(s)
	local t = string.split(s or "", ",")
	for i, v in ipairs(t) do t[i] = tonumber(v) or 0 end
	return t
end
local function hex(s) return Color3.fromHex(s or "CCCCCC") end
-- (2026-10-27, the owner) skin is skin: the bare mannequin greys (the body showing past the outfit) and the "*Skin"
-- shell classes draw in one warm skin tone instead; clothing colours (the slate undersuits) are untouched
local SKIN = Color3.fromHex("EAB892")
local function skinOr(c)
	local _, sat, val = c:ToHSV()
	return (sat < 0.2 and val > 0.5) and SKIN or c
end

-- a clip's tracks decoded once: joints (qw,qx,qy,qz,px,py,pz per frame), props (px,py,pz,qw,qx,qy,qz), glow (0..1000)
local function decode(clip)
	local c = { Fps = clip.Fps or 30, N = clip.N or 1, Loop = clip.Loop == true, PromptAt = clip.PromptAt, J = {}, P = {}, G = {} }
	c.Duration = c.N / c.Fps
	for name, s in pairs(clip.Joints or {}) do c.J[name] = ints(s) end
	for name, s in pairs(clip.Props or {}) do c.P[name] = ints(s) end
	for name, s in pairs(clip.Glow or {}) do c.G[name] = ints(s) end
	return c
end
local function frameAt(c, t)
	local f = t * c.Fps
	local i0, i1, a
	if c.Loop then
		f = f % c.N
		i0 = math.floor(f)
		i1 = (i0 + 1) % c.N
	else
		f = math.clamp(f, 0, c.N - 1)
		i0 = math.floor(f)
		i1 = math.min(i0 + 1, c.N - 1)
	end
	a = f - i0
	return i0, i1, a
end
local function jointCF(arr, i)
	local b = i * 7
	return CFrame.new(arr[b + 5] / 1000, arr[b + 6] / 1000, arr[b + 7] / 1000, arr[b + 2] / 1000, arr[b + 3] / 1000, arr[b + 4] / 1000, arr[b + 1] / 1000)
end
local function propCF(arr, i)
	local b = i * 7
	return CFrame.new(arr[b + 1] / 1000, arr[b + 2] / 1000, arr[b + 3] / 1000, arr[b + 5] / 1000, arr[b + 6] / 1000, arr[b + 7] / 1000, arr[b + 4] / 1000)
end
--- the clip's pose at time t: T[joint], P[prop] (relative to the root), G[channel] (0..1)
local function sample(c, t, T, P, G)
	local i0, i1, a = frameAt(c, t)
	for name, arr in pairs(c.J) do T[name] = jointCF(arr, i0):Lerp(jointCF(arr, i1), a) end
	for name, arr in pairs(c.P) do P[name] = propCF(arr, i0):Lerp(propCF(arr, i1), a) end
	for name, arr in pairs(c.G) do G[name] = ((arr[i0 + 1] or 0) * (1 - a) + (arr[i1 + 1] or 0) * a) / 1000 end
end

----------------------------------------------------------------------------------------------------
-- building one NPC
----------------------------------------------------------------------------------------------------
local npcs = {}
local released = false
local built = {}            -- every DataMesh made, for MeshBudget's give-back

local function build(name, def, stage)
	local ambient = def.Ambient == true or stage.Ambient == true      -- (2026-10-27) Idle only: no prompt / greet / look-at
	local rig = HubLife.Mannequin()
	if not rig then return nil end
	local model = rig.Model
	model.Name = "HubLife_" .. name
	local body = def.Body or {}
	local hidden = {}
	for _, n in ipairs(body.Hide or {}) do hidden[n] = true end
	for _, p in ipairs(model:GetChildren()) do
		if p:IsA("BasePart") and p ~= rig.Root then
			p.Color = skinOr(hex(body.Color))
			p.Material = Enum.Material.SmoothPlastic
			p.CastShadow = true
			if hidden[p.Name] then p.Transparency = 1 end
		end
	end
	local classes = D.Classes or {}
	local pieces, glowPieces = {}, {}
	for _, pc in ipairs(def.Pieces or {}) do
		if released then return nil end
		local m = HubLife.DataMesh(pc.V, pc.T)
		if m then
			built[#built + 1] = m
			local cls = classes[pc.Class] or {}
			local p = m.Part
			p.Name = tostring(pc.Name)
			p.Color = string.find(tostring(pc.Class), "Skin$") and SKIN or hex(cls.Color)   -- (2026-10-27) only the skin shells
			p.Material = (cls.Material == "Neon") and Enum.Material.Neon or Enum.Material.SmoothPlastic
			p.Transparency = cls.Transparency or 0
			p.CastShadow = cls.Material ~= "Neon"
			p.Parent = model
			local piece = { Part = p, Ride = pc.Ride, Off = CFrame.new(m.Off), Base = p.Color }
			if pc.Ride == "Head" and not ambient then
				-- its highest points (head space): the prompt balloon's anchor rests over the real top, not the box's corner
				local vs, tops = string.split(pc.V or "", ","), {}
				for i = 1, #vs - 2, 3 do
					tops[#tops + 1] = Vector3.new(tonumber(vs[i]) or 0, tonumber(vs[i + 1]) or 0, tonumber(vs[i + 2]) or 0) / 1000
				end
				table.sort(tops, function(u, v) return u.Y > v.Y end)
				piece.Tops = table.move(tops, 1, math.min(#tops, 12), 1, {})
			end
			pieces[#pieces + 1] = piece
			if cls.Glow then
				piece.Glow = cls.Glow
				glowPieces[#glowPieces + 1] = piece
			end
		else
			warn("[HubNPCs] " .. name .. "." .. tostring(pc.Name) .. " did not build")
		end
	end
	local props = {}
	for pname, pdef in pairs(def.Props or {}) do
		local a = ints(pdef.Rest)
		props[pname] = CFrame.new(a[1] / 1000, a[2] / 1000, a[3] / 1000, a[5] / 1000, a[6] / 1000, a[7] / 1000, a[4] / 1000)
	end
	local lights = {}
	for _, L in ipairs(def.Lights or {}) do
		local holder = Instance.new("Part")
		holder.Name = "Light"
		holder.Anchored, holder.CanCollide, holder.CanQuery, holder.CanTouch, holder.Transparency = true, false, false, false, 1
		holder.Size = Vector3.new(0.1, 0.1, 0.1)
		holder.Parent = model
		local l = Instance.new("PointLight")
		l.Color, l.Range, l.Brightness, l.Shadows = hex(L.Color), L.Range or 8, L.Brightness or 1, false
		l.Parent = holder
		local at = ints(L.At)
		lights[#lights + 1] = { Part = holder, Light = l, Ride = L.Ride, At = CFrame.new(at[1] / 1000, at[2] / 1000, at[3] / 1000),
			Base = L.Brightness or 1, Glow = L.Glow }
	end
	local clips = {}
	for cname, c in pairs(def.Clips or {}) do clips[cname] = decode(c) end
	if not clips.Idle then
		warn("[HubNPCs] " .. name .. " has no Idle clip")
		return nil
	end
	-- the prompt: the Keeper's is HubServer's altar prompt (HubLifeServer hangs it beside him); the Merchant's is made here
	local prompt = nil
	local npc = nil
	if ambient then
		-- (2026-10-27) an ambient NPC: no prompt and no balloon anchor; it starts at its own point in its loop
		model.Parent = folder
		return {
			Name = name, Rig = rig, Model = model, Stage = stage, Pieces = pieces, GlowPieces = glowPieces, Props = props,
			Lights = lights, Clips = clips, Ambient = true, Mode = "Idle", T = (stage.Phase or 0) * clips.Idle.Duration,
		}
	end
	if name ~= "Keeper" then          -- (the Keeper's is HubServer's altar prompt: keeperPrompt, found at the top)
		local P = Tuning.Prompts[name]
		if P then
			local anchor = Instance.new("Part")
			anchor.Name = "HubLife_" .. name .. "Prompt"
			anchor.Anchored, anchor.CanCollide, anchor.CanQuery, anchor.CanTouch, anchor.Transparency = true, false, false, false, 1
			anchor.Size = Vector3.new(1, 1, 1)
			anchor.CFrame = stage.CFrame * stage.PromptAt
			local pp = Instance.new("ProximityPrompt")
			pp.ObjectText, pp.ActionText = P.Object, P.Action
			pp.HoldDuration, pp.MaxActivationDistance = P.Hold, P.Distance
			pp.RequiresLineOfSight = false
			pp.KeyboardKeyCode, pp.GamepadKeyCode = Enum.KeyCode.G, Enum.KeyCode.ButtonB   -- HubClient applies the player's bind
			pp.Enabled = false
			pp.Parent = anchor
			anchor.Parent = hub                       -- inside the hub model: HubClient's prompt binding finds it
			pp.Triggered:Connect(function()
				local shop = player:WaitForChild("PlayerGui"):FindFirstChild("SpellshotShop")
				local cmd = shop and shop:FindFirstChild("Command")
				if cmd then cmd:Fire("open") end
			end)
			prompt = pp
		end
	end
	-- the prompt balloon's anchor (HubPrompts hangs the balloon on it): over the centre of the actual head, at the top of
	-- the head and what it wears (hood, goggles), moved with the pose every frame
	local bubbleAt = Instance.new("Part")
	bubbleAt.Name = "BubbleAt"
	bubbleAt.Anchored, bubbleAt.CanCollide, bubbleAt.CanQuery, bubbleAt.CanTouch, bubbleAt.Transparency = true, false, false, false, 1
	bubbleAt.Size = Vector3.new(0.2, 0.2, 0.2)
	bubbleAt.Parent = model
	model.Parent = folder
	npc = {
		Name = name, Rig = rig, Model = model, Stage = stage, Pieces = pieces, GlowPieces = glowPieces, Props = props, Lights = lights,
		Clips = clips, Prompt = prompt, Mode = "Idle", T = 0, GT = 0, Greeted = false, LastGreet = -math.huge,
		Look = Vector2.zero, PrevUT = nil, Head = model:FindFirstChild("Head"), BubbleAt = bubbleAt,
	}
	return npc
end

----------------------------------------------------------------------------------------------------
-- running them
----------------------------------------------------------------------------------------------------
local function glowColour(base, g)
	local dim = base:Lerp(Color3.new(0, 0, 0), 0.45)
	if g <= 0.6 then return dim:Lerp(base, g / 0.6) end
	return base:Lerp(Color3.new(1, 1, 1), (g - 0.6) / 0.4 * 0.45)
end

local function poseOf(n, clipName, t)
	local T, P, G = {}, {}, {}
	sample(n.Clips[clipName], t, T, P, G)
	return { T = T, P = P, G = G }
end
local function blend(a, b, k)
	local out = { T = {}, P = {}, G = {} }
	for key, cf in pairs(a.T) do out.T[key] = cf:Lerp(b.T[key] or CFrame.identity, k) end
	for key, cf in pairs(b.T) do if not a.T[key] then out.T[key] = CFrame.identity:Lerp(cf, k) end end
	for key, cf in pairs(a.P) do out.P[key] = cf:Lerp(b.P[key] or cf, k) end
	for key, cf in pairs(b.P) do if not a.P[key] then out.P[key] = cf end end
	for key, g in pairs(a.G) do out.G[key] = g + ((b.G[key] or g) - g) * k end
	for key, g in pairs(b.G) do if not a.G[key] then out.G[key] = g end end
	return out
end

local parts, cfs = {}, {}
local function step(n, dt, now)
	local idle, greet = n.Clips.Idle, n.Clips.Greet
	local stage = n.Stage
	local root = stage.CFrame
	local ch = player.Character
	local hrp = ch and ch:FindFirstChild("HumanoidRootPart")
	local dist = math.huge
	local ambient = n.Ambient                   -- (2026-10-27) loops its Idle and nothing else: you are never noticed
	if hrp and not ambient then
		local d = hrp.Position - root.Position
		-- only on the NPC's own floor: the Merchant stands over the Training room's path (as HubServer's vault notes)
		if math.abs(d.Y) < Tuning.SameFloor then dist = Vector3.new(d.X, 0, d.Z).Magnitude end
	end
	-- greet on approach; re-arm once you have walked past Leave (back again within Rearm: no second greet, the prompt
	-- simply shows)
	if ambient then
		-- (2026-10-27) no greet
	elseif dist > stage.Leave then
		n.Greeted = false
	elseif not n.Greeted and dist < stage.Greet then
		n.Greeted = true
		if greet and now - n.LastGreet > Tuning.Rearm then
			n.LastGreet = now
			n.FadeFrom = n.Current
			n.FadeT = 0
			n.Mode, n.GT = "Greet", 0
		end
	end
	n.T += dt
	local target
	if n.Mode == "Greet" then
		n.GT += dt
		if n.GT >= greet.Duration then
			n.FadeFrom = poseOf(n, "Greet", greet.Duration)
			n.FadeT = 0
			n.Mode = "Idle"
			target = poseOf(n, "Idle", n.T)
		else
			target = poseOf(n, "Greet", n.GT)
		end
	else
		target = poseOf(n, "Idle", n.T)
	end
	if n.FadeFrom then
		n.FadeT += dt
		local k = math.clamp(n.FadeT / Tuning.Crossfade, 0, 1)
		k = k * k * (3 - 2 * k)
		target = blend(n.FadeFrom, target, k)
		if k >= 1 then n.FadeFrom = nil end
	end
	n.Current = target
	-- the prompt: shown once the greet has landed, while you are near
	local pp = n.Prompt or (n.Name == "Keeper" and keeperPrompt) or nil
	if pp then
		local landed = n.Greeted and (n.Mode == "Idle" or (greet and greet.PromptAt and n.GT >= greet.PromptAt) or (greet and not greet.PromptAt))
		pp.Enabled = landed and true or false
		if n.BubbleLink ~= pp then                 -- (the balloon hangs over the head: HubPrompts reads this link)
			n.BubbleLink = pp
			local link = pp:FindFirstChild("BubbleAt") or Instance.new("ObjectValue")
			link.Name, link.Value, link.Parent = "BubbleAt", n.BubbleAt, pp
		end
	end
	-- the look-at, from last frame's UpperTorso (one frame behind is invisible)
	local T = table.clone(target.T)
	if not ambient then                         -- (2026-10-27) an ambient NPC's head turns are baked into its Neck
		local want = Vector2.zero
		if hrp and dist < Tuning.Look.Range and n.PrevUT then
			local head = ch:FindFirstChild("Head")
			local aim = head and head.Position or hrp.Position + Vector3.new(0, 1.5, 0)
			local d = n.PrevUT:VectorToObjectSpace(aim - (n.PrevUT.Position + n.PrevUT.UpVector * 1.4))
			local yaw = math.atan2(-d.X, -d.Z)
			local pitch = math.atan2(d.Y, math.sqrt(d.X * d.X + d.Z * d.Z))
			if math.abs(yaw) < math.rad(110) then
				want = Vector2.new(math.clamp(yaw, -math.rad(Tuning.Look.Yaw), math.rad(Tuning.Look.Yaw)),
					math.clamp(pitch, -math.rad(Tuning.Look.Pitch), math.rad(Tuning.Look.Pitch)))
			end
		end
		n.Look = n.Look:Lerp(want, 1 - math.exp(-Tuning.Look.Speed * dt))
		T.Neck = CFrame.fromEulerAnglesYXZ(n.Look.Y, n.Look.X, 0) * (T.Neck or CFrame.identity)
	end
	-- pose: the body, then every piece on its part or prop, then the lights
	table.clear(parts)
	table.clear(cfs)
	local cf = HubLife.Pose(n.Rig, root, T, parts, cfs)
	local ut = n.Model:FindFirstChild("UpperTorso")
	n.PrevUT = ut and cf[ut] or nil
	local propCFs = {}
	for pname, rest in pairs(n.Props) do propCFs[pname] = root * (target.P[pname] or rest) end
	-- the head's top (its own box and the highest points of every piece riding it): where the prompt balloon hangs
	local head = n.Head and cf[n.Head]
	local function topOf(c, s)
		return c.Y + 0.5 * (math.abs(c.RightVector.Y) * s.X + math.abs(c.UpVector.Y) * s.Y + math.abs(c.LookVector.Y) * s.Z)
	end
	local top = head and topOf(head, n.Head.Size) or 0
	local tops = n.TopPts or {}
	n.TopPts = tops
	table.clear(tops)
	for _, pc in ipairs(n.Pieces) do
		local ride = pc.Ride or ""
		local base
		if string.sub(ride, 1, 5) == "Prop:" then
			base = propCFs[string.sub(ride, 6)]
		else
			local rp = n.Model:FindFirstChild(ride)
			base = rp and cf[rp]
		end
		if base then
			local c = base * pc.Off
			parts[#parts + 1], cfs[#cfs + 1] = pc.Part, c
			if head and pc.Tops then
				for _, v in ipairs(pc.Tops) do
					local p = base * v
					tops[#tops + 1] = p
					top = math.max(top, p.Y)
				end
			end
		end
	end
	if head then
		-- on screen the anchor sits level with the highest of those points: a hood brim or goggle rim nearer the camera
		-- than the head's centre stands higher from a low camera, so it rises (on the centre line) until it clears them
		local cam = workspace.CurrentCamera
		local y = top
		if cam and #tops > 0 then
			local want = math.huge
			for _, p in ipairs(tops) do
				local v = cam:WorldToViewportPoint(p)
				if v.Z > 0 then want = math.min(want, v.Y) end
			end
			local lo, hi = top, top + 3
			local v0 = cam:WorldToViewportPoint(Vector3.new(head.X, lo, head.Z))
			if want < math.huge and v0.Z > 0 and v0.Y > want then
				for _ = 1, 10 do
					local mid = (lo + hi) / 2
					if cam:WorldToViewportPoint(Vector3.new(head.X, mid, head.Z)).Y > want then lo = mid else hi = mid end
				end
				y = hi
			end
		end
		parts[#parts + 1], cfs[#cfs + 1] = n.BubbleAt, CFrame.new(head.X, y, head.Z)
	end
	-- glow: Reduce Flashing turns every flare (pieces AND their lights) into a gentle swell
	local calm = HubLife.Calm()
	local glow = {}
	for chan, g in pairs(target.G) do
		if calm then g = 0.45 + (g - 0.45) * 0.4 end
		glow[chan] = math.clamp(g, 0, 1)
	end
	for _, L in ipairs(n.Lights) do
		local ride = L.Ride or ""
		local base
		if string.sub(ride, 1, 5) == "Prop:" then
			base = propCFs[string.sub(ride, 6)]
		else
			local rp = n.Model:FindFirstChild(ride)
			base = rp and cf[rp]
		end
		if base then parts[#parts + 1], cfs[#cfs + 1] = L.Part, base * L.At end
		local g = L.Glow and glow[L.Glow]
		if g then L.Light.Brightness = L.Base * (Tuning.GlowLight.Lo + (Tuning.GlowLight.Hi - Tuning.GlowLight.Lo) * g) end
	end
	workspace:BulkMoveTo(parts, cfs, Enum.BulkMoveMode.FireCFrameChanged)
	for _, pc in ipairs(n.GlowPieces) do
		local g = glow[pc.Glow]
		if g then pc.Part.Color = glowColour(pc.Base, g) end
	end
end

----------------------------------------------------------------------------------------------------
-- build (after any essential skin build), then run
----------------------------------------------------------------------------------------------------
-- (2026-10-27, the owner: the Store and Loadout NPCs were gone) the NPCs no longer give way to MeshBudget: ~4k triangles,
-- the hub's own hosts, and the first MakeRoom of any skin or wrap build released them for the whole session. The room a
-- skin needs comes from the big optional sets (Pyro wrap sets, the Devil forge, CryoWrap / TerraWrap copies) instead.
if false and Budget then
	Budget.Optional(function()
		released = true
		for _, n in pairs(npcs) do
			if n.Prompt then n.Prompt.Parent.Parent = nil end      -- (the Merchant's own prompt goes with him)
			n.Model:Destroy()
		end
		table.clear(npcs)
		keeperFallback()
		for _, m in ipairs(built) do HubLife.Release(m) end
		table.clear(built)
		folder:SetAttribute("Released", true)
	end)
end
task.spawn(function()
	while Budget and Budget.Busy() do task.wait(0.5) end
	-- (2026-10-27) the Keeper and the Merchant (the ones you use) first, then the ambient NPCs
	local order = {}
	for name in pairs(D.NPCs) do order[#order + 1] = name end
	table.sort(order, function(a, b)
		local fa, fb = D.NPCs[a].Ambient == true, D.NPCs[b].Ambient == true
		if fa ~= fb then return fb end
		return a < b
	end)
	for _, name in ipairs(order) do
		local def = D.NPCs[name]
		local stage = HubLife.NPC[name]
		if stage and not released then
			local ok, n = pcall(build, name, def, stage)
			if ok and n and not released then
				npcs[name] = n
			else
				if not ok then warn("[HubNPCs] " .. name .. ": " .. tostring(n)) end
				if ok and n then n.Model:Destroy() end
				if name == "Keeper" then keeperFallback() end
			end
		end
	end
	if not npcs.Keeper then keeperFallback() end
	folder:SetAttribute("NPCs", (function() local c = 0 for _ in pairs(npcs) do c += 1 end return c end)())
	folder:SetAttribute("Tris", HubLife.Tris)
	folder:SetAttribute("Ready", true)
end)

local last = os.clock()
RunService.RenderStepped:Connect(function()
	local now = os.clock()
	local dt = math.min(now - last, 0.1)
	last = now
	if released or not HubLife.Close() then return end
	local cam = workspace.CurrentCamera
	for _, n in pairs(npcs) do
		if cam and (cam.CFrame.Position - n.Stage.CFrame.Position).Magnitude < Tuning.Far then
			local ok, err = pcall(step, n, dt, now)
			if not ok then
				warn("[HubNPCs] " .. n.Name .. ": " .. tostring(err))
				n.Broken = true
				npcs[n.Name] = nil
				if n.Name == "Keeper" then keeperFallback() end
				if n.Prompt then n.Prompt.Enabled = false end
			end
		end
	end
end)

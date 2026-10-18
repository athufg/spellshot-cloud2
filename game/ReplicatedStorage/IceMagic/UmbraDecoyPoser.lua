--[[
	UmbraDecoyPoser  (ModuleScript)  ->  ReplicatedStorage/IceMagic/UmbraDecoyPoser

	Poses every Decoy Double copy in workspace.UmbraDecoys with CastPose.Clips.UmbraDecoyReady, LOOPED, for as long as it
	stands (Phase 4 stage A, 2026-09-28; B's DecoyReady idle, approved). Client only: UmbraAnim.Start() starts it, and
	UmbraAnim's DecoySpawn handler asks for the new copy too (whichever comes first wins; the second is a no-op).

	WHY IT HAS TO EXIST. UmbraHandler.castDecoy clones the caster's body on the SERVER, strips its scripts and attributes,
	anchors its root and parents it under workspace.UmbraDecoys. Every pose a body shows is CastPose's, written on each
	client into the joints' Attachment0.CFrame -- client writes, never replicated -- so the server's copy carries the rig's
	REST values: without this it would stand with its arms hanging, which no living Umbra ever does.

	CASTPOSE CAN POSE IT, SO THIS IS NOT A POSER OF ITS OWN. CastPose's API takes any model with a Humanoid and
	AnimationConstraint (or Motor6D) joints -- stateFor() asks for nothing else -- and the copy keeps its Humanoid (the
	server needs it: the first damage breaks the decoy). So one PlayClocked per copy is the whole job, with the same
	channel maths, blend and rig adapters every other body gets, and nothing to keep in step by hand. What that means on a
	copy, checked against CastPose.lua:
	  * The copy has no MoveState (the server clears its attributes), so it rests on the Ready stance -- and every key of
	    UmbraDecoyReady names both arms, both legs and the torso (OffKeys, Off legs), so the stance never shows anyway.
	  * Its root is anchored, so stanceTarget reads it as standing: no walk cycle, ever.
	  * No BaseHipHeight attribute: `sunk` is 0, and the clip never keys Drop.
	  * CastPose.Start never hooks it (it hooks players' characters), so no MoveState, TombPhase or wall watchers run on
	    it -- only this clip.
	  * When the copy is destroyed (0.35 s after its break) step() drops it by itself: character.Parent is nil.
	  * Streaming: a limb that arrives after the model is picked up by CastPose's own jointsStale / re-collect.
	THE LOOP IS OURS, as CycloneForm's is ZephyrFX's: CastPose never reads LoopFrom / LoopLength, so the clock handed to
	PlayClocked plays [0, LoopFrom) once and then wraps [LoopFrom, LoopFrom + LoopLength) -- the clip's last key is its
	first, so the wrap has no seam. The clock starts when this client first sees the copy, so it opens on the loop's first
	key, which is exactly the Ready stance the caster was standing in when it peeled off.

	THE ONE THING IT CANNOT DO is start on the pose: CastPose blends a new body in from zero at the clip's Rate (10), so a
	copy is on the Ready pose ~0.3 s after it appears. Decoy Double's peel (the VFX) hides the real copy for ~0.45 s while
	the per-part copies travel, which covers it. If the peel is ever dropped, that 0.3 s of arms rising is the thing to
	look at (TRIGGERS.md, test 9).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local iceFolder = ReplicatedStorage:WaitForChild("IceMagic")

local DecoyPoser = {}

local CLIP = "UmbraDecoyReady"
local FOLDER = "UmbraDecoys"

local warned = {}
local function warnOnce(key, msg)
	if warned[key] then return end
	warned[key] = true
	warn("[UmbraDecoyPoser] " .. tostring(msg))
end

-- CastPose, found lazily and guarded: a place without it (or without the clip) poses nothing and breaks nothing
local castPose = nil
local function needCastPose()
	if castPose ~= nil then return castPose or nil end
	local m = iceFolder:FindFirstChild("CastPose")
	local ok, mod = pcall(function()
		return m and require(m)
	end)
	castPose = (ok and type(mod) == "table" and mod) or false
	if not castPose then warnOnce("castpose", "CastPose unavailable, decoys stand in the rest pose: " .. tostring(mod)) end
	return castPose or nil
end

local posed = setmetatable({}, { __mode = "k" })      -- [decoy model] = true: asked for once

--- The loop's clock, ZephyrFX.CycloneLoopClock's rule: [0, LoopFrom) plays once, then [LoopFrom, LoopFrom + LoopLength)
--- repeats. No LoopLength: it plays once and holds its last key (the clip is Hold).
local function loopClock(clip)
	local from = tonumber(clip.LoopFrom) or 0
	local length = tonumber(clip.LoopLength) or 0
	local t0 = os.clock()
	return function()
		local t = os.clock() - t0
		if t < from or length <= 0 then return t end
		return from + (t - from) % length
	end
end

--- Pose one decoy copy (idempotent). True if it was, or is being, posed.
function DecoyPoser.Pose(model)
	if typeof(model) ~= "Instance" or not model:IsA("Model") then return false end
	if posed[model] then return true end
	local CP = needCastPose()
	local clip = CP and CP.Clips and CP.Clips[CLIP]
	if not clip then
		if CP then warnOnce("clip", "CastPose.Clips." .. CLIP .. " is missing: install castpose_umbra_clips first") end
		return false
	end
	posed[model] = true
	task.spawn(function()
		-- the Humanoid can land a beat after the model (streaming); CastPose will not take a body without one
		local hum = model:FindFirstChildOfClass("Humanoid") or model:WaitForChild("Humanoid", 5)
		if not (hum and hum:IsA("Humanoid") and model.Parent) then
			posed[model] = nil
			return
		end
		local ok, err = pcall(CP.PlayClocked, model, CLIP, loopClock(clip))
		if not ok then
			posed[model] = nil
			warnOnce("play", "could not pose " .. model:GetFullName() .. ": " .. tostring(err))
		end
	end)
	return true
end

local started = false

--- Watch workspace.UmbraDecoys: every copy already there, and every one that arrives. The folder is the server's
--- (UmbraHandler makes it when it loads); if it is not there yet, it is picked up the moment it is.
function DecoyPoser.Start()
	if started then return end
	started = true
	local function watch(folder)
		folder.ChildAdded:Connect(function(child)
			DecoyPoser.Pose(child)
		end)
		for _, child in ipairs(folder:GetChildren()) do
			DecoyPoser.Pose(child)
		end
	end
	local folder = workspace:FindFirstChild(FOLDER)
	if folder then
		watch(folder)
		return
	end
	local conn
	conn = workspace.ChildAdded:Connect(function(child)
		if child.Name == FOLDER and child:IsA("Folder") then
			conn:Disconnect()
			watch(child)
		end
	end)
end

return DecoyPoser

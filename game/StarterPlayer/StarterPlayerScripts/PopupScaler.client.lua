--[[
	PopupScaler  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/PopupScaler

	Comic callouts (BillboardGuis named "Popup", built by TrainingGround) appear at a fixed on-screen
	size -- the size that reads well at the moment they pop. From then on they behave as if they were
	attached above the target: back away, or let the target move away, and they shrink; close in and
	they grow. The scale is the camera distance when a popup appeared over the distance now, so at
	twice the distance it is half the size.

	It lives on the client because it is per viewer: everyone sees a popup from their own camera.
	The server marks each popup with BaseW / BaseH (its size in pixels when it pops) and wraps its
	contents in a frame named "Distance" carrying a UIScale; this scales both, so the popup's
	contents and its SizeOffset spacing from the other callouts shrink and grow together.
]]

local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Settings = require(ReplicatedStorage:WaitForChild("Spellshot"):WaitForChild("SpellshotSettings"))

local MIN_SCALE, MAX_SCALE = 0.3, 3    -- never vanishes, never fills the screen
local live = {}                        -- [BillboardGui] = { D0, W, H, Scale }

local function worldPosition(bb)
	local part = bb.Adornee or bb.Parent
	if not (part and part:IsA("BasePart")) then return nil end
	return part.Position + bb.StudsOffsetWorldSpace
end

-- DAMAGE NUMBERS. The server tags each callout with the style it was built in; the damage ones
-- are the only kind this row hides. Hidden per viewer, not per server: turning them off is a choice
-- about your own screen, and the callout still exists for everyone else.
local damageOnes = setmetatable({}, { __mode = "k" })

local function applyDamageNumbers()
	local on = Settings.Get("DamageNumbers")
	for bb in pairs(damageOnes) do
		if bb.Parent then bb.Enabled = on end
	end
end
Settings.OnChange("DamageNumbers", applyDamageNumbers)

local function track(bb)
	if bb.Name ~= "Popup" or not bb:IsA("BillboardGui") then return end
	if bb:GetAttribute("Style") == "damage" then
		damageOnes[bb] = true
		bb.Enabled = Settings.Get("DamageNumbers")
	end
	local w, h = bb:GetAttribute("BaseW"), bb:GetAttribute("BaseH")
	local frame = bb:FindFirstChild("Distance")
	local scale = frame and frame:FindFirstChildOfClass("UIScale")
	local at = worldPosition(bb)
	local camera = workspace.CurrentCamera
	if not (w and h and scale and at and camera) then return end
	live[bb] = { D0 = math.max(1, (at - camera.CFrame.Position).Magnitude), W = w, H = h, Scale = scale }
end

workspace.DescendantAdded:Connect(track)

-- after the camera has moved for the frame, so the distance is the one about to be drawn
RunService:BindToRenderStep("SpellshotPopupScale", Enum.RenderPriority.Camera.Value + 4, function()
	local camera = workspace.CurrentCamera
	if not camera then return end
	local eye = camera.CFrame.Position
	for bb, rec in pairs(live) do
		if not bb.Parent then
			live[bb] = nil
		else
			local at = worldPosition(bb)
			if at then
				local k = math.clamp(rec.D0 / math.max(1, (at - eye).Magnitude), MIN_SCALE, MAX_SCALE)
				rec.Scale.Scale = k
				bb.Size = UDim2.fromOffset(rec.W * k, rec.H * k)
			end
		end
	end
end)

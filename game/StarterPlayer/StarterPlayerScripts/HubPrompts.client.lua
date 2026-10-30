--[[
	HubPrompts  (LocalScript)  ->  StarterPlayer/StarterPlayerScripts/HubPrompts

	SPELLSHOT's OWN INTERACT PROMPT (2026-10-25, the owner: replace the stock Roblox prompt everywhere with one custom
	SPELLSHOT-styled UI). Client only, runs only while HubLife.On() (Studio until the owner's review): until then every
	prompt keeps Roblox's default look.

	ONE component for every ProximityPrompt in the game (the Hub's: Loadout Altar, the nine Duel Pads' SOLO TEST, the Cache
	Vault, the Shop Merchant -- and any made later, anywhere): on this client each prompt's Style is set to Custom and,
	when ProximityPromptService shows it, this script draws the SPELLSHOT prompt instead. What a prompt DOES is untouched:
	its key, reach, hold time, Enabled and Triggered are the prompts' own (HubServer, HubNPCs, HubClient's key binds).

	THE LOOK -- the Hub's corner chips (SHOP / PLAY / LOADOUT: CardKit.shopChip) and the REACTIONS board's comic panel:
	a cream Pill face with an ink outline and one solid ink shadow, a faint halftone dot screen; the KEY on the left as a
	gold keycap (keyboard: the player's own Interact bind; gamepad: its button; touch: TAP); the small label (ObjectText) in
	GothamBold caps over the bold action (ActionText) in Bangers.
	2026-10-26 polish (the owner): a COMPACT callout (about two thirds of the first size); it sits ABOVE its anchor (its
	bottom edge on it -- the NPCs' prompts hang over their heads, HubLife.NPC); it POPS in (scale + fade up) and out; the
	hold-charge bar has its OWN row under the text and never touches it. Holding presses the keycap into its shadow.
	2026-10-26 (the owner's sketch): a SPEECH BALLOON -- the panel itself is a rounded balloon (a superellipse round the
	content, painted into an EditableImage with its thin outline, shadow and dots), one small clean triangle tail under
	its middle, the tip a few px OVER the anchor (it never touches the head). An NPC's prompt anchors on the top of the
	NPC's actual head (HubNPCs' BubbleAt: the head's centre, over the hood / goggles), not on the prompt's own part.
	No EditableImage room: a plain round-ended panel and tail in Frames instead.
	Touch: the panel is the button (hold it), only where the prompt is clickable (HubClient makes Hub prompts clickable on
	touch only, so a mouse in first person never gets a button under the cursor).
	Studio check hook: SpellshotPrompts:SetAttribute("TestHold", 0..1) shows every open prompt's bar at that fill.
]]

local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ProximityPromptService = game:GetService("ProximityPromptService")
local TweenService = game:GetService("TweenService")
local TextService = game:GetService("TextService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local spell = ReplicatedStorage:WaitForChild("Spellshot")
local HubLife = require(spell:WaitForChild("HubLife"))
if not HubLife.On() then return end
local K = require(spell:WaitForChild("HubLifeKit"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

-- EVERY NUMBER HERE IS A PROPOSAL (px)
local Tuning = {
	H = 44, TouchH = 50,              -- the content row's height (key + the two lines + the bar), incl. the old shadow
	Shadow = 3, Border = 1.4,
	-- the balloon: a superellipse (N 2 = an ellipse, higher = boxier) PadY over and under the content, as wide as the
	-- content's corners need (+ Margin); the tail a TailW x TailL triangle; its tip Gap px over the anchor; painted at Res x
	Balloon = { N = 3.4, PadY = 7, Margin = 1, TailW = 13, TailL = 10, Gap = 6, Res = 2, ShadowAlpha = 0.85,   -- (the owner's pick)
		Dot = { Pitch = 6, R = 1.3, Alpha = 0.1 } },
	Key = { Pad = 6, Shadow = 2, Border = 1.4, Radius = 4, TextSize = 21, TouchTextSize = 13 },
	Label = { Size = 10, Y = 4, H = 11 },
	Action = { Size = 19, Y = 13, H = 19, MaxW = 210 },
	Bar = { H = 4, Gap = 2 },         -- its own row under the action line
	Gap = 7, Right = 10,
	Pop = { In = 0.16, Out = 0.11, From = 0.55 },
}

local gui = Instance.new("ScreenGui")
gui.Name = "SpellshotPrompts"
gui.ResetOnSpawn = false
gui.Parent = playerGui

----------------------------------------------------------------------------------------------------
-- every prompt draws custom (this client only)
----------------------------------------------------------------------------------------------------
local styled = setmetatable({}, { __mode = "k" })
local function adopt(d)
	if d:IsA("ProximityPrompt") and not styled[d] then
		styled[d] = d.Style
		d.Style = Enum.ProximityPromptStyle.Custom
	end
end
for _, d in ipairs(workspace:GetDescendants()) do adopt(d) end
workspace.DescendantAdded:Connect(adopt)

----------------------------------------------------------------------------------------------------
-- the key's face
----------------------------------------------------------------------------------------------------
local PAD = {
	ButtonA = "A", ButtonB = "B", ButtonX = "X", ButtonY = "Y", ButtonL1 = "LB", ButtonR1 = "RB", ButtonL2 = "LT", ButtonR2 = "RT",
	ButtonL3 = "LS", ButtonR3 = "RS", DPadUp = "UP", DPadDown = "DN", DPadLeft = "LT", DPadRight = "RT", ButtonSelect = "SEL", ButtonStart = "STA",
}
local function keyText(prompt, inputType)
	if inputType == Enum.ProximityPromptInputType.Touch then return "TAP" end
	if inputType == Enum.ProximityPromptInputType.Gamepad then
		local code = prompt.GamepadKeyCode
		return PAD[code.Name] or code.Name
	end
	local code = prompt.KeyboardKeyCode
	local s = ""
	pcall(function() s = UserInputService:GetStringForKeyCode(code) end)
	if s == nil or s == "" or s == " " then s = code.Name end
	s = string.upper(s)
	if #s > 4 then s = string.sub(s, 1, 4) end
	return s
end

local function textW(text, size, font)
	local ok, v = pcall(function() return TextService:GetTextSize(text, size, font, Vector2.new(1000, 200)) end)
	return ok and v.X or (#text * size * 0.6)
end

----------------------------------------------------------------------------------------------------
-- the balloon: its measures round a content box, and its painting (one per size, shared)
----------------------------------------------------------------------------------------------------
local AssetService = game:GetService("AssetService")

--- the balloon round a cw x ch content box (px): semi-axes A, B; centre CX, CY; the tail's tip TipY; the image W x H
local function balloonLayout(cw, ch)
	local B = Tuning.Balloon
	local n, t = B.N, Tuning.Border
	local b = ch / 2 + B.PadY
	local a = (cw / 2 + B.Margin + t) / (1 - ((ch / 2 + B.Margin + t) / b) ^ n) ^ (1 / n)
	local tipY = 1 + 2 * b + B.TailL
	return { A = a, B = b, CX = 1 + a, CY = 1 + b, TipY = tipY,
		W = math.ceil(2 * a + Tuning.Shadow + 2), H = math.ceil(tipY + Tuning.Shadow + B.Gap) }
end

-- the signed distance to a triangle (Inigo Quilez's): < 0 inside
local function triSD(px, py, x0, y0, x1, y1, x2, y2)
	local e0x, e0y, e1x, e1y, e2x, e2y = x1 - x0, y1 - y0, x2 - x1, y2 - y1, x0 - x2, y0 - y2
	local v0x, v0y, v1x, v1y, v2x, v2y = px - x0, py - y0, px - x1, py - y1, px - x2, py - y2
	local t0 = math.clamp((v0x * e0x + v0y * e0y) / (e0x * e0x + e0y * e0y), 0, 1)
	local t1 = math.clamp((v1x * e1x + v1y * e1y) / (e1x * e1x + e1y * e1y), 0, 1)
	local t2 = math.clamp((v2x * e2x + v2y * e2y) / (e2x * e2x + e2y * e2y), 0, 1)
	local q0x, q0y, q1x, q1y, q2x, q2y = v0x - e0x * t0, v0y - e0y * t0, v1x - e1x * t1, v1y - e1y * t1, v2x - e2x * t2, v2y - e2y * t2
	local s = (e0x * e2y - e0y * e2x) > 0 and 1 or -1
	local d = math.min(q0x * q0x + q0y * q0y, q1x * q1x + q1y * q1y, q2x * q2x + q2y * q2y)
	local w = math.min(s * (v0x * e0y - v0y * e0x), s * (v1x * e1y - v1y * e1x), s * (v2x * e2y - v2y * e2x))
	return (w > 0) and -math.sqrt(d) or math.sqrt(d)
end

local painted, paintedN = {}, 0         -- "A:B" -> the RGBA buffer (every prompt of one size shares one painting)
--- the balloon's pixels at Res x: its shadow, the thin ink outline round body AND tail as one shape, the cream face, the dots
local function paintBalloon(L)
	local key = string.format("%.2f:%.2f", L.A, L.B)
	if painted[key] then return painted[key] end
	local t0 = os.clock()
	local B = Tuning.Balloon
	local S, n = B.Res, B.N
	local W, H = L.W * S, L.H * S
	local a, b, cx, cy = L.A, L.B, L.CX, L.CY
	local t = Tuning.Border
	-- the body's distance is the superellipse's first-order one, (F - 1) / |grad F|, worked only in the band round its
	-- edge; deeper in or further out it is just "in" / "out" (F >= the edge's support distance >= b keeps that honest)
	local gIn, gOut, BIG = (1 - (t + 2) / b) ^ n, (1 + 2 / b) ^ n, 1e4
	local tipX, tipY, half = cx, L.TipY, B.TailW / 2
	local baseY = cy + b - 4                                -- (the tail's base sits inside the body: one clean union)
	local uxs, uxn = table.create(W), table.create(W)
	for i = 0, W - 1 do
		local ux = math.abs((i + 0.5) / S - cx) / a
		uxs[i + 1], uxn[i + 1] = ux, ux ^ n
	end
	local dist = buffer.create(W * H * 4)
	for j = 0, H - 1 do
		local y = (j + 0.5) / S
		local uy = math.abs(y - cy) / b
		local uyn = uy ^ n
		local tailRow = y > baseY - 1 and y < tipY + 2
		for i = 0, W - 1 do
			local ux, un = uxs[i + 1], uxn[i + 1]
			local G = un + uyn
			local v
			if G < gIn then
				v = -BIG
			elseif G > gOut then
				v = BIG
			else
				local F = G ^ (1 / n)
				local k = F / G                             -- F ^ (1 - n)
				local gx = (ux > 0) and k * un / ux / a or 0
				local gy = (uy > 0) and k * uyn / uy / b or 0
				v = (F - 1) / math.sqrt(gx * gx + gy * gy)
			end
			if tailRow then
				local x = (i + 0.5) / S
				if math.abs(x - tipX) < half + 2 then
					v = math.min(v, triSD(x, y, tipX - half, baseY, tipX + half, baseY, tipX, tipY))
				end
			end
			buffer.writef32(dist, (j * W + i) * 4, v)
		end
	end
	local ink, face = K.C.Ink, K.C.Pill
	local iR, iG, iB = ink.R * 255, ink.G * 255, ink.B * 255
	local fR, fG, fB = face.R * 255, face.G * 255, face.B * 255
	local D = B.Dot
	local sh, SA = Tuning.Shadow * S, B.ShadowAlpha
	local px = buffer.create(W * H * 4)
	for j = 0, H - 1 do
		local y = (j + 0.5) / S
		local gy = (y % D.Pitch) - D.Pitch / 2
		for i = 0, W - 1 do
			local o = (j * W + i) * 4
			local v = buffer.readf32(dist, o)
			local c = math.clamp(0.5 - v * S, 0, 1)
			local cs = 0
			if i >= sh and j >= sh then
				cs = SA * math.clamp(0.5 - buffer.readf32(dist, ((j - sh) * W + i - sh) * 4) * S, 0, 1)
			end
			local ao = c + cs * (1 - c)
			if ao > 0 then
				local ci = math.clamp(0.5 - (v + t) * S, 0, 1)          -- inside the outline: the face
				local r, g, bl = iR, iG, iB
				if ci > 0 then
					local gx = (((i + 0.5) / S) % D.Pitch) - D.Pitch / 2
					local dot = D.Alpha * math.clamp(0.5 - (math.sqrt(gx * gx + gy * gy) - D.R) * S, 0, 1)
					r = iR + ((fR + (iR - fR) * dot) - iR) * ci
					g = iG + ((fG + (iG - fG) * dot) - iG) * ci
					bl = iB + ((fB + (iB - fB) * dot) - iB) * ci
				end
				local under = cs * (1 - c)
				buffer.writeu8(px, o, math.floor((r * c + iR * under) / ao + 0.5))
				buffer.writeu8(px, o + 1, math.floor((g * c + iG * under) / ao + 0.5))
				buffer.writeu8(px, o + 2, math.floor((bl * c + iB * under) / ao + 0.5))
				buffer.writeu8(px, o + 3, math.floor(ao * 255 + 0.5))
			end
		end
	end
	if paintedN >= 12 then table.clear(painted) paintedN = 0 end
	painted[key], paintedN = px, paintedN + 1
	gui:SetAttribute("PaintMs", math.floor((os.clock() - t0) * 10000 + 0.5) / 10)     -- (Studio check: the last painting's cost)
	return px
end

--- the painted balloon as an EditableImage (nil: no room -- the caller draws Frames)
local function balloonImage(L)
	local S = Tuning.Balloon.Res
	local ok, im = pcall(function() return AssetService:CreateEditableImage({ Size = Vector2.new(L.W * S, L.H * S) }) end)
	if not ok or not im then return nil end
	local wrote = pcall(function() im:WritePixelsBuffer(Vector2.zero, im.Size, paintBalloon(L)) end)
	if not wrote then
		im:Destroy()
		return nil
	end
	return im
end

-- where a prompt's balloon hangs: an NPC's head (HubNPCs links its BubbleAt), else the prompt's own part
local function anchorOf(prompt)
	local link = prompt:FindFirstChild("BubbleAt")
	local at = link and link:IsA("ObjectValue") and link.Value
	if at and at.Parent then return at end
	return prompt.Parent
end

----------------------------------------------------------------------------------------------------
-- one prompt's panel
----------------------------------------------------------------------------------------------------
local function build(prompt, inputType)
	local touch = inputType == Enum.ProximityPromptInputType.Touch
	local H = touch and Tuning.TouchH or Tuning.H
	local KT = Tuning.Key
	local faceH = H - Tuning.Shadow
	local keySize = faceH - KT.Pad * 2 - KT.Shadow
	local bb = Instance.new("BillboardGui")
	bb.Name = "SpellshotPrompt"
	bb.AlwaysOnTop = true
	bb.LightInfluence = 0
	bb.ResetOnSpawn = false
	bb.Adornee = anchorOf(prompt)
	bb.SizeOffset = Vector2.new(0, 0.5)             -- its bottom edge on the anchor: it sits above, never over, its owner
	bb.Active = prompt.ClickablePrompt
	bb.Parent = gui

	-- the whole balloon fades and scales as one (a CanvasGroup), from under the tail's tip
	local holder = K.make("CanvasGroup", { Name = "Holder", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 1),
		Position = UDim2.fromScale(0.5, 1), Size = UDim2.fromScale(1, 1), GroupTransparency = 1 }, bb)
	local scale = K.make("UIScale", { Scale = Tuning.Pop.From }, holder)
	-- THE BALLOON: the painted image (its size follows the words: refresh); Frames only when there is no EditableImage room
	local body = K.make("ImageLabel", { Name = "Balloon", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 1 }, holder)
	local image, shapeKey, fb = nil, nil, nil
	local function shape(L)
		local key = string.format("%d:%d:%.2f:%.2f", L.W, L.H, L.A, L.B)
		if key == shapeKey then return end
		shapeKey = key
		if not fb then
			local im = balloonImage(L)
			if im then
				body.ImageContent = Content.fromObject(im)
				if image then image:Destroy() end
				image = im
				return
			end
			if image then return end                 -- (a new size found no room: the last painting stretches)
			-- no room at all: a round-ended panel, its shadow, and a turned square behind it for the tail
			body.Visible = false
			fb = {}
			fb.Shadow = K.make("Frame", { Name = "Shadow", BackgroundColor3 = K.C.Ink, BackgroundTransparency = 0.15, BorderSizePixel = 0,
				ZIndex = 1 }, holder)
			fb.Tail = K.make("Frame", { Name = "Tail", BackgroundColor3 = K.C.Pill, BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = 45, ZIndex = 1 }, holder)
			K.outline(fb.Tail, Tuning.Border)
			fb.Face = K.make("Frame", { Name = "Body", BackgroundColor3 = K.C.Pill, BorderSizePixel = 0, ZIndex = 2 }, holder)
			K.outline(fb.Face, Tuning.Border)
			fb.Corners = { K.corner(fb.Shadow, 0), K.corner(fb.Face, 0) }
		end
		local size = UDim2.fromOffset(math.floor(2 * L.A), math.floor(2 * L.B))
		fb.Face.Position, fb.Face.Size = UDim2.fromOffset(1, 1), size
		fb.Shadow.Position, fb.Shadow.Size = UDim2.fromOffset(1 + Tuning.Shadow, 1 + Tuning.Shadow), size
		for _, c in ipairs(fb.Corners) do c.CornerRadius = UDim.new(0, math.floor(L.B)) end
		local hd = Tuning.Balloon.TailL + 3                    -- (its upper corner hides behind the panel)
		fb.Tail.Size = UDim2.fromOffset(hd * 1.4142, hd * 1.4142)
		fb.Tail.Position = UDim2.fromOffset(L.CX, L.TipY - hd)
	end
	-- the content (key, the two lines, the bar) sits on the face: now just their frame, centred in the balloon by refresh
	local face = K.make("Frame", { Name = "Face", BackgroundTransparency = 1, BorderSizePixel = 0, ZIndex = 2 }, holder)

	-- the keycap
	local kx, ky = KT.Pad, KT.Pad
	local keyShadow = K.make("Frame", { Name = "KeyShadow", BackgroundColor3 = K.C.Ink, BorderSizePixel = 0,
		Position = UDim2.fromOffset(kx + KT.Shadow, ky + KT.Shadow), Size = UDim2.fromOffset(keySize, keySize), ZIndex = 3 }, face)
	K.corner(keyShadow, KT.Radius)
	local key = K.make("Frame", { Name = "Key", BackgroundColor3 = K.C.Gold, BorderSizePixel = 0,
		Position = UDim2.fromOffset(kx, ky), Size = UDim2.fromOffset(keySize, keySize), ZIndex = 4 }, face)
	K.corner(key, KT.Radius)
	K.outline(key, KT.Border)
	local keyLabel = K.make("TextLabel", { Name = "KeyText", BackgroundTransparency = 1, Font = Enum.Font.LuckiestGuy,
		TextColor3 = K.C.Ink, Size = UDim2.fromScale(1, 1), Position = UDim2.fromOffset(0, 1), ZIndex = 5 }, key)

	-- the two lines, then the bar's own row
	local tx = kx + keySize + KT.Shadow + Tuning.Gap
	local label = K.make("TextLabel", { Name = "Label", BackgroundTransparency = 1, Font = Enum.Font.GothamBold, TextSize = Tuning.Label.Size,
		TextColor3 = K.C.LockedInk, TextXAlignment = Enum.TextXAlignment.Left, Position = UDim2.fromOffset(tx, Tuning.Label.Y),
		Size = UDim2.new(1, -tx - Tuning.Right, 0, Tuning.Label.H), ZIndex = 5 }, face)
	local action = K.make("TextLabel", { Name = "Action", BackgroundTransparency = 1, Font = Enum.Font.Bangers, TextSize = Tuning.Action.Size,
		TextColor3 = K.C.Ink, TextXAlignment = Enum.TextXAlignment.Left, TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(tx, Tuning.Action.Y), Size = UDim2.new(1, -tx - Tuning.Right, 0, Tuning.Action.H), ZIndex = 5 }, face)
	local barY = Tuning.Action.Y + Tuning.Action.H + Tuning.Bar.Gap
	-- the content's box on the face (what the balloon must hold): the keycap's left edge .. the words' end; the label's top
	-- (or the keycap's) .. the bar's bottom (or the keycap shadow's)
	local cy0 = math.min(Tuning.Label.Y, ky)
	local cy1 = math.max(barY + Tuning.Bar.H, ky + keySize + KT.Shadow)
	local track = K.make("Frame", { Name = "HoldTrack", BackgroundColor3 = K.C.Track, BorderSizePixel = 0, Visible = false,
		Position = UDim2.fromOffset(tx, barY), Size = UDim2.new(1, -tx - Tuning.Right, 0, Tuning.Bar.H), ZIndex = 5 }, face)
	K.corner(track, 2)
	K.outline(track, 1)
	local fill = K.make("Frame", { Name = "Fill", BackgroundColor3 = K.C.Gold, BorderSizePixel = 0, Size = UDim2.fromScale(0, 1), ZIndex = 6 }, track)
	K.corner(fill, 2)

	-- fill in the words and size the panel to them
	local function refresh()
		local kt = keyText(prompt, inputType)
		keyLabel.Text = kt
		keyLabel.TextSize = (#kt > 1) and (touch and KT.TouchTextSize or math.floor(KT.TextSize * (#kt > 2 and 0.6 or 0.78))) or KT.TextSize
		local obj = string.upper(prompt.ObjectText or "")
		local act = string.upper(prompt.ActionText or "")
		label.Text = obj
		action.Text = act
		label.Visible = obj ~= ""
		action.Position = UDim2.fromOffset(tx, (obj ~= "") and Tuning.Action.Y or math.floor((faceH - Tuning.Action.H - Tuning.Bar.H) / 2))
		local w = math.max(textW(act, Tuning.Action.Size, Enum.Font.Bangers), textW(obj, Tuning.Label.Size, Enum.Font.GothamBold))
		w = math.min(w, Tuning.Action.MaxW)
		local cw, ch = tx + w - kx, cy1 - cy0
		local L = balloonLayout(cw, ch)
		face.Size = UDim2.fromOffset(math.ceil(tx + w + Tuning.Right), faceH)
		face.Position = UDim2.fromOffset(math.floor(L.CX - cw / 2 - kx + 0.5), math.floor(L.CY - ch / 2 - cy0 + 0.5))
		bb.Size = UDim2.fromOffset(L.W, L.H)
		shape(L)
	end
	refresh()

	local conns = {}
	for _, prop in ipairs({ "ActionText", "ObjectText", "KeyboardKeyCode", "GamepadKeyCode" }) do
		conns[#conns + 1] = prompt:GetPropertyChangedSignal(prop):Connect(refresh)
	end

	-- holding and triggering
	local holdTween = nil
	local function press(on)
		key.Position = on and UDim2.fromOffset(kx + KT.Shadow, ky + KT.Shadow) or UDim2.fromOffset(kx, ky)
	end
	local function showBar(k)
		track.Visible = k ~= nil
		fill.Size = UDim2.fromScale(k or 0, 1)
	end
	conns[#conns + 1] = prompt.PromptButtonHoldBegan:Connect(function()
		press(true)
		if prompt.HoldDuration > 0 then
			showBar(0)
			if holdTween then holdTween:Cancel() end
			holdTween = TweenService:Create(fill, TweenInfo.new(prompt.HoldDuration, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(1, 1) })
			holdTween:Play()
		end
	end)
	conns[#conns + 1] = prompt.PromptButtonHoldEnded:Connect(function()
		press(false)
		if holdTween then holdTween:Cancel() holdTween = nil end
		showBar(nil)
	end)
	conns[#conns + 1] = prompt.Triggered:Connect(function()
		press(false)
		showBar(nil)
		scale.Scale = 1.1
		TweenService:Create(scale, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	end)
	conns[#conns + 1] = gui:GetAttributeChangedSignal("TestHold"):Connect(function()
		local k = gui:GetAttribute("TestHold")
		press(type(k) == "number")
		showBar(type(k) == "number" and math.clamp(k, 0, 1) or nil)
	end)
	if type(gui:GetAttribute("TestHold")) == "number" then showBar(gui:GetAttribute("TestHold")) end

	-- touch: the balloon is the button (only where the prompt is clickable)
	if prompt.ClickablePrompt then
		local hit = K.make("TextButton", { Name = "Hit", Text = "", AutoButtonColor = false, BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1), ZIndex = 10 }, holder)
		local down = false
		conns[#conns + 1] = hit.InputBegan:Connect(function(input)
			if (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1)
				and input.UserInputState ~= Enum.UserInputState.Change then
				down = true
				prompt:InputHoldBegin()
			end
		end)
		conns[#conns + 1] = hit.InputEnded:Connect(function(input)
			if down and (input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1) then
				down = false
				prompt:InputHoldEnd()
			end
		end)
	end

	-- pop in (Reduce Flashing changes nothing here: a scale and fade, no flash)
	local P = Tuning.Pop
	TweenService:Create(scale, TweenInfo.new(P.In, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	TweenService:Create(holder, TweenInfo.new(P.In * 0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { GroupTransparency = 0 }):Play()

	local closed = false
	local function gone()
		bb:Destroy()
		if image then image:Destroy() image = nil end
	end
	return function(now)
		if closed then return end
		closed = true
		for _, c in ipairs(conns) do c:Disconnect() end
		if holdTween then holdTween:Cancel() end
		if now then
			gone()
			return
		end
		-- pop out, then go
		TweenService:Create(scale, TweenInfo.new(P.Out, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Scale = P.From }):Play()
		local fade = TweenService:Create(holder, TweenInfo.new(P.Out, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { GroupTransparency = 1 })
		fade.Completed:Once(gone)
		fade:Play()
	end
end

----------------------------------------------------------------------------------------------------
-- shown / hidden: popping in and out
----------------------------------------------------------------------------------------------------
local open = {}
ProximityPromptService.PromptShown:Connect(function(prompt, inputType)
	if prompt.Style ~= Enum.ProximityPromptStyle.Custom then return end
	if open[prompt] then open[prompt](true) end        -- (shown again mid pop-out: the old one goes at once)
	local ok, closer = pcall(build, prompt, inputType)
	if not ok then
		warn("[HubPrompts] " .. tostring(closer))
		return
	end
	open[prompt] = closer
	local hidden
	hidden = prompt.PromptHidden:Connect(function()
		hidden:Disconnect()
		if open[prompt] == closer then open[prompt] = nil end
		closer(false)
	end)
end)
gui:SetAttribute("Ready", true)

--[[
	Callouts  (ModuleScript)  ->  ReplicatedStorage/Spellshot/Callouts

	The comic callouts that pop over a target: the damage number, KO!, CHILL x2, BURN x2, FROZEN!,
	and the target board's score.

	THIS USED TO LIVE INSIDE TrainingGround, AND THAT WAS THE BUG. Every callout in the game was
	built by the training range and attached only to models carrying the TrainingDummy attribute, so
	shooting a real player did full damage, stacked Chill and rooted them -- and showed nothing at
	all. The machinery is here now, and CombatFeedback attaches it to players; the range keeps using
	the same builder for its dummies and its boards, so the two can never drift apart.

	Called on the SERVER. The BillboardGui replicates, so every client sees the callout, and
	PopupScaler (client) reads BaseW / BaseH and the Distance frame to grow and shrink it with each
	viewer's own distance.

	  Callouts.Pop(adornee, offset, text, style)          pops, drifts up, fades
	  Callouts.Pop(adornee, offset, text, style, true)    stays until the returned function is called
]]

local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")

local Callouts = {}

local INK = Color3.fromRGB(17, 17, 17)
local RED = Color3.fromRGB(229, 38, 31)
local GOLD = Color3.fromRGB(245, 184, 0)
local TEAL = Color3.fromRGB(42, 126, 147)      -- the darker cyan the kit sets CRYO display type in
local ICY = Color3.fromRGB(205, 236, 252)      -- FROZEN!'s burst is light icy blue rather than white
local EMBER = Color3.fromRGB(242, 92, 13)      -- Pyro's Base (SpellshotConfig), the colour BURN xN is set in

-- The kit's plain white impact burst (PopArtAssets Overlay.Burst): ink rim and hard shadow baked in.
local PLAIN_BURST = "rbxassetid://88718198034720"
-- The same burst dressed for comics (vmarm/make_comic_bursts.py) -- graded Ben-Day dots toward the rim
-- and a pale inner burst behind the word, painted only on the white fill. ELEMENTAL callouts only, one
-- per Element in that Element's colour; everything else stays on the plain burst.
local ELEMENT_BURST = {
	Cryo = "rbxassetid://128548591023421",
	-- Voltaic's: textures/Burst_Comic_Voltaic.png (tools/make_voltaic_burst.py), uploaded 2026-09-25 with the
	-- owner's go (the Voltaic import). `arcstorm` below picks it up.
	Voltaic = "rbxassetid://126789467686888",
}

-- One look per kind of callout. The everyday ones (damage numbers, CHILL stacks, ordinary scores) are
-- plain kit lettering with a small random tilt. The big moments are the layouts picked from the A-E
-- sheet on 2026-09-11: FROZEN! is C (counter-tilt) on the icy comic burst, KO! is E (bold) on the
-- plain burst, and the bullseye is E's lettering with no burst at all.
-- Lettering is a FIXED TextSize, and the frame is sized to fit both the burst and the whole word, so a
-- word may run past its burst's edges -- which reads better than a word squeezed inside it.
-- `Shift` moves a callout in SCREEN space by fractions of its own size (BillboardGui SizeOffset),
-- which keeps the kinds apart at any distance -- an offset in studs shrinks to a few pixels far away.
-- `Slot`: a new callout replaces the one already showing in its slot on that target, so callouts of
-- one kind never stack; damage numbers have no slot and get a little sideways jitter.
local STYLES = {
	damage = { TextSize = 24, Stroke = 1.7, Color = RED, Tilt = 6, Life = 0.7, Shift = Vector2.new(0, 0), Jitter = 0.35 },
	chill = { TextSize = 20, Stroke = 1.5, Color = TEAL, Tilt = 6, Life = 0.8, Shift = Vector2.new(0.55, 0.3), Slot = "status" },
	-- BURN xN (2026-09-23) is Scorching Lash's stacking burn and CHILL xN's twin: the same everyday lettering (no
	-- burst), in Pyro's colour rather than the damage red, so it is never taken for a damage number. CombatFeedback
	-- and TrainingGround pop it as RX_Burning_Stacks rises. It has its OWN slot, so a burn stack never knocks a CHILL
	-- off the same target (only a dummy can carry both). It also has its own line: CHILL's side but the opposite
	-- vertical shift, which keeps it apart from CHILL and from FROZEN! / the payoff words, and puts it on the opposite
	-- side from KO!, which a dummy pops when a lash hit empties it.
	burn = { TextSize = 20, Stroke = 1.5, Color = EMBER, Tilt = 6, Life = 0.8, Shift = Vector2.new(0.55, -0.6), Slot = "burn" },
	score = { TextSize = 24, Stroke = 1.7, Color = RED, Tilt = 6, Life = 0.9, Shift = Vector2.new(0, 0), Slot = "score" },
	frozen = { Burst = ELEMENT_BURST.Cryo, Tint = ICY, BurstPx = 96, BurstRot = 10, TextSize = 28, Stroke = 2.2, TextRot = -6,
		Color = TEAL, Life = 1.1, Shift = Vector2.new(0.5, 0.45), Slot = "frozen" },
	ko = { Burst = PLAIN_BURST, BurstPx = 96, BurstRot = -3, TextSize = 34, Stroke = 3.0, TextRot = -3,
		Color = RED, Life = 1.1, Shift = Vector2.new(-0.5, 0.45), Slot = "ko" },
	bull = { TextSize = 28, Stroke = 2.5, TextRot = -3, Color = GOLD, Life = 1.0, Shift = Vector2.new(0, 0), Slot = "score" },
	-- ENTOMBED! -- Earthen Tomb's burst landing (2026-09-19), the Terra kit's ONE payoff word, the way FROZEN! is Cryo's.
	-- FROZEN!'s structure in Terra's colours: the plain burst tinted a pale sand (as FROZEN!'s is a pale ice), the word
	-- in Terra's Base, KO!'s bold size, a counter-tilt. (Proposed 2026-09-18 as 'slam' for Seismic Slam, which never had
	-- a cast path and is replaced; the style carries over.)
	entombed = { Burst = PLAIN_BURST, Tint = Color3.fromRGB(240, 228, 170), BurstPx = 104, BurstRot = 8, TextSize = 34,
		Stroke = 3.0, TextRot = 5, Color = Color3.fromRGB(130, 107, 36), Life = 1.1, Shift = Vector2.new(0.5, 0.45),
		Slot = "payoff" },
	-- ARCSTORM! -- Cascade's kill moment (2026-09-22), the Voltaic kit's ONE payoff word, the way FROZEN! is
	-- Cryo's and ENTOMBED! is Terra's. NO NEW LETTERING: ARCSTORM is already rendered and uploaded as
	-- PopArtAssets.Overlay.Word.Voltaic.ARCSTORM, the Voltaic entry in the per-Element payoff word set
	-- (Cryo's FROZENOUT, Terra's GROUNDED, Zephyr's BLOWNAWAY). That set is art that no code reads yet, so
	-- this style reuses the WORD, not the image -- a callout is kit lettering, not a picture.
	-- THE COLOURS ARE THE WHOLE POINT. Voltaic's Base #F5C70F sits within a few points of Radiant's
	-- #F5C230 and of the "Ultimate ready" UI gold #F5B800, and Voltaic is one of two Elements that do NOT
	-- change under Colourblind-Safe (SpellshotSettings.ElementColors), so a gold-tinted burst with gold
	-- lettering would read as "somebody's ult is up" rather than as Voltaic. The word is therefore set in
	-- the VIOLET Dark #4A1A8C, which nothing else in the game uses, on a near-white burst tinted a hair
	-- toward lilac -- the same trick the built Voltaic comic burst plays with its dots.
	arcstorm = { Burst = ELEMENT_BURST.Voltaic or PLAIN_BURST, Tint = Color3.fromRGB(236, 230, 250),
		BurstPx = 104, BurstRot = -7, TextSize = 34, Stroke = 3.0, TextRot = 4,
		Color = Color3.fromRGB(74, 26, 140), Life = 1.1, Shift = Vector2.new(0.5, 0.45), Slot = "payoff" },
	-- ELEMENTAL APPLICATION (2026-09-24): the everyday callouts of the statuses StatusEffects runs, in CHILL / BURN's
	-- lettering, each on its own slot and line so none knocks another off. Colours: Toxin's Base; Voltaic's violet Dark (the
	-- ARCSTORM! reasoning: its gold reads as "an ult is up", and Radiant's gold is four points away); Umbra's LIGHT, because
	-- its Base is within a few points of that same violet; Radiant's Base. The status HUD will separate them by SHAPE too.
	poison = { TextSize = 20, Stroke = 1.5, Color = Color3.fromRGB(128, 212, 33), Tilt = 6, Life = 0.8,
		Shift = Vector2.new(-0.55, 0.3), Slot = "poison" },
	charged = { TextSize = 20, Stroke = 1.5, Color = Color3.fromRGB(74, 26, 140), Tilt = 6, Life = 0.8,
		Shift = Vector2.new(-0.55, -0.6), Slot = "charged" },
	marked = { TextSize = 22, Stroke = 1.7, Color = Color3.fromRGB(181, 140, 240), Tilt = 4, Life = 1.0,
		Shift = Vector2.new(0, 0.95), Slot = "marked" },
	-- HUNTED! -- Umbra's Mark landing (2026-09-27), in FROZEN!'s place in the kit: the owner asked for it "like FROZEN" and
	-- "there for a bit of time", so it holds twice as long (UmbraTuning.Mark.HuntedHold). The plain burst tinted Umbra's
	-- glint (pale lavender), the word in its deep violet (dusk) -- dark on light, the kit's rare light accent.
	hunted = { Burst = PLAIN_BURST, Tint = Color3.fromRGB(232, 222, 255), BurstPx = 104, BurstRot = -6, TextSize = 34,
		Stroke = 3.0, TextRot = 4, Color = Color3.fromRGB(52, 28, 92), Life = 2.2, Shift = Vector2.new(0.5, 0.45),
		Slot = "payoff" },
	blessed = { TextSize = 22, Stroke = 1.7, Color = Color3.fromRGB(245, 194, 48), Tilt = 4, Life = 1.0,
		Shift = Vector2.new(0, -1.2), Slot = "blessed" },
}
Callouts.Styles = STYLES

local showing = setmetatable({}, { __mode = "k" })   -- [adornee] = { [slot] = BillboardGui }

local function make(class, props, parent)
	local i = Instance.new(class)
	for k, v in pairs(props) do i[k] = v end
	i.Parent = parent
	return i
end

--- A comic callout in the Pop-Art HUD Kit's formula: lettering built the way the kit builds its
--- display type -- colour fill, ink outline, and a solid ink copy knocked down-right behind it --
--- and, for the big moments, a burst behind it. It pops in with an overshoot, then drifts up and
--- fades; with `held` it stays until the returned function lets it go.
function Callouts.Pop(adornee, offset, text, styleName, held)
	if not (adornee and adornee.Parent) then return end
	local st = STYLES[styleName] or STYLES.damage
	if st.Slot then
		local slots = showing[adornee] or {}
		showing[adornee] = slots
		local old = slots[st.Slot]
		if old and old.Parent then old:Destroy() end
	end
	-- big enough for the burst and for the whole word, which is allowed to run past the burst
	local w = math.max(st.BurstPx or 0, math.floor(st.TextSize * (#text * 0.62 + 1)))
	local h = math.max(st.BurstPx or 0, math.floor(st.TextSize * 1.6))
	local shift = st.Shift + Vector2.new(st.Jitter and (math.random() * 2 - 1) * st.Jitter or 0, 0)
	-- built whole and parented LAST, so a client never sees a half-made popup: PopupScaler (client)
	-- reads BaseW / BaseH and the Distance frame the moment the popup arrives, then grows and shrinks
	-- it with that viewer's distance from the target, as if it were attached above the target's head
	local bb = make("BillboardGui", {
		Name = "Popup", Adornee = adornee, Size = UDim2.fromOffset(w, h), SizeOffset = shift,
		StudsOffsetWorldSpace = offset, AlwaysOnTop = true, LightInfluence = 0, MaxDistance = 300,
	}, nil)
	bb:SetAttribute("BaseW", w)
	bb:SetAttribute("BaseH", h)
	-- which kind of callout this is, so a client can act on it -- the HUD's Damage Numbers row
	-- hides the damage ones and leaves the rest alone
	bb:SetAttribute("Style", STYLES[styleName] and styleName or "damage")
	if st.Slot then showing[adornee][st.Slot] = bb end
	local distance = make("Frame", {
		Name = "Distance", BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(w, h),
	}, bb)
	make("UIScale", { Scale = 1 }, distance)
	local panel = make("Frame", {
		BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
	}, distance)
	local pop = make("UIScale", { Scale = 0.4 }, panel)
	local burst
	if st.Burst then
		burst = make("ImageLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(st.BurstPx, st.BurstPx), Rotation = st.BurstRot or 0, Image = st.Burst,
			ImageColor3 = st.Tint or Color3.new(1, 1, 1), ZIndex = 1,
		}, panel)
	end
	-- the word sits dead centre on the burst: the burst art's white body is centred in its image
	local rot = st.TextRot or math.random(-st.Tilt, st.Tilt)
	local function lettering(colour, dx, dy, z)
		local l = make("TextLabel", {
			BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.new(0.5, dx, 0.5, dy),
			Size = UDim2.fromScale(1, 1), Font = Enum.Font.LuckiestGuy, Text = text, TextSize = st.TextSize,
			TextColor3 = colour, Rotation = rot, ZIndex = z,
		}, panel)
		return l, make("UIStroke", { Color = INK, Thickness = st.Stroke }, l)
	end
	local extrude, extrudeInk = lettering(INK, 2, 3, 2)
	local face, faceInk = lettering(st.Color, 0, 0, 3)
	bb.Parent = adornee

	TweenService:Create(pop, TweenInfo.new(0.16, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	local function letGo(rise, delay, fadeTime)
		TweenService:Create(bb, TweenInfo.new(rise, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ StudsOffsetWorldSpace = offset + Vector3.new(0, 1.6, 0) }):Play()
		local fade = TweenInfo.new(fadeTime, Enum.EasingStyle.Quad, Enum.EasingDirection.In, 0, false, delay)
		if burst then TweenService:Create(burst, fade, { ImageTransparency = 1 }):Play() end
		for _, l in ipairs({ extrude, face }) do TweenService:Create(l, fade, { TextTransparency = 1 }):Play() end
		for _, k in ipairs({ extrudeInk, faceInk }) do TweenService:Create(k, fade, { Transparency = 1 }):Play() end
		Debris:AddItem(bb, delay + fadeTime + 0.05)
	end
	if held then
		-- stays exactly where it popped until the caller lets it go, then drifts off and fades quickly
		return function()
			if bb.Parent then letGo(0.45, 0.1, 0.3) end
		end
	end
	letGo(st.Life, st.Life * 0.6, st.Life * 0.35)
end

return Callouts

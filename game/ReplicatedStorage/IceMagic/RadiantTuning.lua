--[[
	RadiantTuning  (ModuleScript)  ->  ReplicatedStorage/IceMagic/RadiantTuning

	EVERY RADIANT NUMBER, and nothing else (pure data: RadiantHandler, RadiantClient, RadiantFX and VFXLibrary's rows all
	read this one table). Radiant rework, Phase 3 (build prompt Opus55_Radiant_Rework_Build.md; manual v0.21), 2026-09-29.

	EVERY NUMBER HERE IS A PLACEHOLDER, proposed and flagged to the owner -- none is final. Where the prompt named a
	starting point it is used: Position Trade takes Lightstep's cooldown (14), Benediction takes Cleansing Ring's (17),
	Halo's windup takes Eclipse's 1.0 s. Blessing's shield itself (absorb, duration) stays StatusEffects' live preset
	(A/B/C, the Blessed row) -- it was already tuned there, and the prompt keeps Blessing unchanged.

	Units: studs, seconds, health points (MaxHealth 150), mana points (MaxMana 100, +7/s). Durations are divided by
	VFXLibrary.ShotTimeScale() where they are used.
]]

local T = {}

-- M1: LIGHT LANCE -- a held channel beam. The click (the M1's CastRequest: SpellshotService's rate gate and StartCost)
-- starts it; the client streams its aim; letting go, an empty mana bar, death or a clear stops it. Damage ramps the
-- longer the beam stays on ONE target: DpsStart on first contact, DpsMax after RampTime on it. Off the target for longer
-- than RampGrace and the ramp starts again.
T.LightLance = {
	FireInterval = 0.25,     -- the M1 gate between one channel's end and the next click
	StartCost = 2,           -- paid once on the click (the row's ManaCost, as every M1)
	ManaPerSecond = 7.5,     -- drained while the beam is on (SpendMana); mana regen is 7/s, so it is nearly sustainable
	Range = 60,
	Tick = 0.25,             -- damage is dealt in ticks of this length (every tick pops a damage number: not faster)
	DpsStart = 16,
	DpsMax = 32,             -- ~5.2 s to down a full 150 HP target while tracking it the whole time (Icicle Shard: 6.25 s)
	RampTime = 2.0,
	RampGrace = 0.4,
	AimRate = 15,            -- the client's aim reports per second (the server drops anything over 2x this)
	ClaimFresh = 0.3,        -- a claimed target counts this long after the last report that named it
	HitSlack = 3.0,          -- a claimed point may sit this far off the server's aim line (lag)
	OriginSlack = 6,         -- the aim's claimed origin (3P: the camera focus, ~3 off the head) may be this far from the
	                         -- server's head, plus speed * (0.35 + ping) (UmbraTuning's rule; review fix 2026-09-29)
	AimSlack = 0.75,         -- ...and the reported aim this far (unit-vector distance, ~44 deg) off the body's facing
	BroadcastRate = 10,      -- the beam's aim is told to every client this often (the placeholder beam draws from it)
}

-- PRIMARY: BLESSING -- the ally nearest the aim line gets the Blessed shield; no ally there, the caster does.
T.Blessing = {
	Cooldown = 12,
	ManaCost = 25,
	Range = 45,
	LockRadius = 3.5,        -- how far off the aim line an ally may stand and still be picked
	RangeSlack = 3,
}

-- PASSIVE: OVERFLOW LIGHT -- a Blessed shield that runs out its whole duration with absorb left: that leftover x
-- ConvertPct heals whoever had it. Emptied by damage, or cleared, it converts nothing.
T.OverflowLight = {
	ConvertPct = 0.6,        -- a 35-absorb shield never touched heals 21
	MinHeal = 1,
}

-- ULTIMATE: HALO -- the charge is spent on the cast. The WINDUP (the staff's growing spiral) slows the caster to
-- WindupSpeed; then for Duration, every point of health the caster's own damage removes ALSO heals, x HealPct, shared
-- evenly between the caster and every ally within TeamRadius (all of it to the caster when alone). ADDITIVE, as the
-- manual specifies: enemies still take the full damage. (The standing concern -- that additive healing bypasses the
-- no-regen health economy -- is flagged in the report, not decided here.)
T.Halo = {
	Windup = 0.9,            -- the owner, Phase 4 (2026-09-29): 0.9 s
	WindupSpeed = 8,         -- walk speed cap during the windup (normal 16)
	Duration = 6.0,
	HealPct = 1.0,
	HealCap = 60,            -- the owner, 2026-09-29: one Halo heals at most this much in all (then it ends)
	TeamRadius = 40,
	-- the FLOAT (the owner, Phase 4): while the Halo is up (HaloUntil, i.e. the 6 s window or until the 60 HP cap ends
	-- it), the caster's gravity is x FloatGravity and the fall is capped at FallCap studs/s: the wings glide them down.
	-- Client-side (RadiantFloat), in the air only; ends with the Halo.
	FloatGravity = 0.5,
	FallCap = 12,
}

-- TECHNIQUE (Mobility): POSITION TRADE -- swap places with the body nearest the aim line: an ally, an enemy, a
-- training dummy. Both dissolve for DissolveTime, then each is moved to where the other stood, facing as they faced.
T.PositionTrade = {
	Cooldown = 14,           -- Lightstep's, per the prompt
	ManaCost = 18,
	Range = 45,
	LockRadius = 3.5,
	RangeSlack = 3,
	DissolveTime = 0.12,     -- the proposed flash (Shadow Step's); the owner has not reacted to the animation yet
	FloorProbe = 10,         -- both bodies need ground within this many studs below them: nobody is swapped over a drop
}

-- TECHNIQUE (Defense slot; the manual's "Sustain"): BENEDICTION -- plant the staff: the caster is ROOTED (no walking, no
-- jumping, no Light Lance, no Position Trade) from the press. HELD since 2026-09-30 (the owner: "as long as u hold it, it
-- can be used"; the row is Held, so the press pays ManaCost and the release ends it): WindUp after the press the staff
-- is in the ground, then a heal pulse every PulseEvery for as long as the key is held -- each heals every ally within
-- Radius by HealPerPulse, or the caster when no ally is in range -- while mana drains ManaPerSecond. A tap still plants
-- and pulses once. It ends on the release, an empty bar, the leash, the floor going, death or a clear; the cooldown
-- starts when it ends. (Channel 2.0 / Pulses 4, the fixed channel, are retired.)
T.Benediction = {
	Cooldown = 17,           -- Cleansing Ring's, per the prompt; from the channel's END
	ManaCost = 20,           -- the start cost, paid on the press
	WindUp = 0.5,            -- press -> the staff hits the ground (the lift and the drive; the impact lands at T0)
	PulseEvery = 0.5,        -- the first pulse PulseEvery after the plant, then every PulseEvery while held
	ManaPerSecond = 10,      -- PLACEHOLDER: drained from the plant while held (regen is 7/s: about 3/s net)
	MaxChannel = 8, --[[30 until the 2026-10-17 balance pass: at most ~120 HP a cast, was ~450]]         -- seconds from the plant before it lets go by itself (0 = no cap). A server backstop
	                         -- (2026-09-30 review): past a full bar's hold (about 27-35 s), so only FREE MANA or a
	                         -- lost key-up meets it
	EndTimeout = 4,          -- clients: no pulse and no End for PulseEvery + this -> the End was missed, let go (a
	                         -- pulse after it takes that back; 1.5 until the 2026-09-30 review: a hitch ended it)
	HealPerPulse = 7.5,      -- 15 a second per ally (or to the caster) while held
	Radius = 25,
	FloorProbe = 4.5,        -- the staff is planted on the ground: no Benediction in mid-air
	LeashRadius = 2.5,       -- moved (knocked, swapped, walked) further than this from the staff and the channel ends
}

-- the heal readout (a Callouts style RadiantHandler registers at load; the Radiant anchor colour, not green: green
-- reads as Toxin)
T.HealPop = { TextSize = 21, Stroke = 1.6, Colour = Color3.fromRGB(255, 247, 214), Life = 0.9 }

return T

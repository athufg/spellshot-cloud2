--[[
	VoltaicTuning  (ModuleScript)  ->  ReplicatedStorage/IceMagic/VoltaicTuning

	Every gameplay number in Voltaic's castable kit (2026-09-25), in one table the server (VoltaicHandler) and the
	clients (VoltaicClient, ChainBoltFX, OverchargeFX, RailspikeFX, VoltOrbFX) all read. Pure data: no requires, no
	services, nothing that touches a player -- safe to require on the server and on the client at load.

	EVERY NUMBER HERE IS A STAND-IN PROPOSAL FOR THE OWNER TO TUNE. None was set by the owner. They were picked at build
	time against the live kits (D:\voltkit_scratch\design.md section 1, "Calibration against the existing kits"):
	  * Chain Bolt 8 per 0.32 s = 25 damage/s at build time (10 since 2026-10-18, handoff #7: ~31 damage/s), against
	    Icicle Shard 24, Wind Blade 25, Fireball 30; (2026-10-19, audit P5D-18)
	  * Railspike 30 per pierced body, against Bulwark Charge 35 and Aftershock 20;
	  * Volt Orb peaks at 28 + 8 (a direct hit at the centre);
	  * Cascade 5 x 14 = 70 at most on one body, against Maw's 65 bite and Tomb's 75 crit.
	Times are seconds of SHOT time: the server divides every delay and window by VFXLibrary.ShotTimeScale() and the
	clients run on VoltaicKit.clock(), so a slowed review slows all of it together.

	What is NOT here, on purpose:
	  * cooldowns, mana, fire rate and range of the ability ROWS live in VFXLibrary's rows (the one exception is
	    Overcharge.Cooldown, which Chain Reaction's refund needs as a number);
	  * the Charged status's numbers stay in StatusEffects.Presets;
	  * Cascade's Strikes, ZoneRadius and BellyHeight are READ from VoltaicFX.Tuning.Cascade (Strikes
	    {1.2333, 1.30, 1.3667, 1.4667, 1.5333}, ZoneRadius 11, belly 14) so the storm the clients draw and the strikes the
	    server lands cannot drift apart.
]]

return {
	-- M1: Chain Bolt. Hitscan to Range; the body hit is Charged and a leg jumps to the nearest other body within
	-- ChainRadius (PrimedLegs legs while Overcharge's prime is up, consumed by any M1 fired while primed).
	-- 2026-10-18 (handoff #7, the owner: 55 / 10, the values the 3v3 sim validated -- Voltaic 42 -> 50%): Range 55 --[[30
	-- until 2026-10-18; 10 until 2026-10-13]], Damage 10 --[[8 until 2026-10-18]]
	ChainBolt = { Range = 55,
		 HitRadius = 0.865, HitSlack = 2.4, OriginSlack = 6, Bucket = 3,
		Damage = 10, ChainDamage = 5, ChainRadius = 16, ChainLegs = 1, PrimedLegs = 3, ChainDelay = 4 / 60, Charged = true },

	-- Primary: Overcharge. An 11-stud dash along the flattened camera look, then the next M1 is primed for PrimedFor.
	Overcharge = { Distance = 11, Time = 0.16, MaxTime = 0.30, MinCap = 16, --[[12 until the 2026-10-17 balance pass]] ThroughCharacters = true,
		PrimedFor = 6.0, TellDelay = 0.23, Watchdog = 6.45, StartSlack = 6, Cooldown = 9 },

	-- Passive: Chain Reaction. Any kill refunds this share of Overcharge's cooldown (Pyro's Ember Refund is the precedent).
	-- Passive: Chain Reaction. What sets it off (2026-10-17, the owner's pick): "MaxStacks" = every time Charged fills on a
	-- target (and goes off), MaxStackCut seconds come off what is left of Overcharge's cooldown; "Kill" = the rule before,
	-- a kill takes Share of Overcharge's full cooldown off (a kill ends a duel round, so it never paid out there).
	ChainReaction = { Share = 0.30, Trigger = "MaxStacks", MaxStackCut = 2 },

	-- Mobility: Railspike. A fixed ChargeTime windup on a press, then a piercing hitscan rail to Range.
	Railspike = { ChargeTime = 0.55, Range = 90, Damage = 30, MaxPierce = 6, HitSlack = 2.0,
		EarlySlack = 0.12, GiveUp = 1.0, Hold = 0.40, OnScreen = 0.54 },

	-- Defense: Volt Orb. A lobbed orb released ReleaseAt into the cast; it bursts on contact with anything solid or at
	-- the Fuse, and its damage lands StrikeDelay after, with radius falloff and a direct-hit bonus. One live orb a caster.
	-- (2026-10-13) HOLD TO AIM: the key held shows the arc, letting go throws -- ReleaseAt 0.31 -> 0.12 after the release
	VoltOrb = { ReleaseAt = 0.12, Speed = 48, Lift = 52, MinElev = 20, MaxElev = 80, Gravity = 72, Fuse = 1.25,
		HitRadius = 1.0, HandOffset = Vector3.new(0.9, -0.7, -1.4), StrikeDelay = 0.12,
		DamageRadius = 7.5, CenterDamage = 28, EdgeDamage = 14, DirectBonus = 8, MaxLive = 1, Range = 60 },

	-- Ultimate: Cascade. A storm over the aimed ground point; five strikes, each on the enemy in the zone struck fewest
	-- times so far, or on a fixed pentagram filler point when the zone is empty.
	Cascade = { Range = 60, GroundProbe = 40, StrikeDamage = 14,
		Spread = { {0.84, 0}, {0.46, 144}, {0.78, 288}, {0.55, 72}, {0.66, 216} } },  -- filler: {share of ZoneRadius, degrees}
		-- Strikes, ZoneRadius and BellyHeight are READ from VoltaicFX.Tuning.Cascade (Strikes {1.2333,1.30,1.3667,1.4667,1.5333}, ZoneRadius 11, belly 14)
}

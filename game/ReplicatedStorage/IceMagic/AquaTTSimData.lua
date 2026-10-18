--[[
	AquaTTSimData  (ModuleScript)  ->  ReplicatedStorage/IceMagic/AquaTTSimData

	Twin Tide's CRASH FLIPBOOK as data: everything AquaFX.TwinTide needs to play AK_TT_Sim_01..37 that is NOT on the kit
	parts' attributes (TemplateSize, OriginFromPivot, Kind and the P_<point>s are). Converted, values copied exactly, from
	vmarm/aqua_kit/manifests/tt_sim.json (v4 round 2 (2026-09-26)) and tt_sim_drops.json (version 3): the
	frame times, which frames carry a Tideline (AK_TT_SimLine_NN), the drops the sim's tracers shed, the hanging foam
	flecks, the second-slam crowns, the line colours and the flood's footprint. Pure data, no requires.

	AXES. Every Vector3 here is in the FLIPBOOK ORIGIN frame = the frames' own part axes (tt_sim_drops.json "frame", the
	same as tt_sim.json points_lane_roblox): origin on the floor at the lane's centre, on the seam; +X along the lane (the
	part's X); +Y up; +Z toward the side +1 wall's back (-Z, that wall's LookVector, points at the side -1 wall). In
	AquaFX.TwinTide that frame is seam[1]: the side +1 wall's rotation with its origin on the floor at the lane's centre
	(the frame the collar, the jets and every flipbook frame are placed in). A point is seam[1] * v, a velocity
	seam[1]:VectorToWorldSpace(v).

	TIMES are seconds after the cast (the server's T0), like the pose table's. Frame k shows over [t_k, t_k + frameTime).
]]

return {
	format = "tt_sim v4 round 2",
	source = { sim = "tt_sim.json v4 round 2 (2026-09-26), 37 frames", drops = "tt_sim_drops.json version 3" },
	fps = 20,
	frameTime = 0.05,
	firstTime = 1.1,                 -- frame 1 replaces the skinned walls here (CloseTime; the server's crush)
	lastTime = 2.9,                  -- the last frame's time: dark wet puddles, handed over to AquaFX.WetLane

	-- the Twin Tide lines: AK_TT_SimLine_NN Neon in lineColour while their water moves; the last one lineColourDark
	-- (SmoothPlastic) the frame its water stops (tt_sim.json line_colour_note). lineFade is information only: the lines
	-- taper geometrically over it (t0, t1, width factor at t1) -- no transparency, nothing for the game to do.
	lineColour = Color3.fromRGB(38, 144, 228),        -- #2690E4
	lineColourDark = Color3.fromRGB(12, 74, 146),     -- #0C4A92
	lineFade = { 2.28, 2.5, 0.25 },

	-- one entry per frame, in order: its game time, its mesh, and its Tideline mesh (nil: that frame's water has stopped)
	frames = {
		{ t = 1.1, mesh = "AK_TT_Sim_01", line = "AK_TT_SimLine_01" },
		{ t = 1.15, mesh = "AK_TT_Sim_02", line = "AK_TT_SimLine_02" },
		{ t = 1.2, mesh = "AK_TT_Sim_03", line = "AK_TT_SimLine_03" },
		{ t = 1.25, mesh = "AK_TT_Sim_04", line = "AK_TT_SimLine_04" },
		{ t = 1.3, mesh = "AK_TT_Sim_05", line = "AK_TT_SimLine_05" },
		{ t = 1.35, mesh = "AK_TT_Sim_06", line = "AK_TT_SimLine_06" },
		{ t = 1.4, mesh = "AK_TT_Sim_07", line = "AK_TT_SimLine_07" },
		{ t = 1.45, mesh = "AK_TT_Sim_08", line = "AK_TT_SimLine_08" },
		{ t = 1.5, mesh = "AK_TT_Sim_09", line = "AK_TT_SimLine_09" },
		{ t = 1.55, mesh = "AK_TT_Sim_10", line = "AK_TT_SimLine_10" },
		{ t = 1.6, mesh = "AK_TT_Sim_11", line = "AK_TT_SimLine_11" },
		{ t = 1.65, mesh = "AK_TT_Sim_12", line = "AK_TT_SimLine_12" },
		{ t = 1.7, mesh = "AK_TT_Sim_13", line = "AK_TT_SimLine_13" },
		{ t = 1.75, mesh = "AK_TT_Sim_14", line = "AK_TT_SimLine_14" },
		{ t = 1.8, mesh = "AK_TT_Sim_15", line = "AK_TT_SimLine_15" },
		{ t = 1.85, mesh = "AK_TT_Sim_16", line = "AK_TT_SimLine_16" },
		{ t = 1.9, mesh = "AK_TT_Sim_17", line = "AK_TT_SimLine_17" },
		{ t = 1.95, mesh = "AK_TT_Sim_18", line = "AK_TT_SimLine_18" },
		{ t = 2, mesh = "AK_TT_Sim_19", line = "AK_TT_SimLine_19" },
		{ t = 2.05, mesh = "AK_TT_Sim_20", line = "AK_TT_SimLine_20" },
		{ t = 2.1, mesh = "AK_TT_Sim_21", line = "AK_TT_SimLine_21" },
		{ t = 2.15, mesh = "AK_TT_Sim_22", line = "AK_TT_SimLine_22" },
		{ t = 2.2, mesh = "AK_TT_Sim_23", line = "AK_TT_SimLine_23" },
		{ t = 2.25, mesh = "AK_TT_Sim_24", line = "AK_TT_SimLine_24" },
		{ t = 2.3, mesh = "AK_TT_Sim_25", line = "AK_TT_SimLine_25" },
		{ t = 2.35, mesh = "AK_TT_Sim_26", line = "AK_TT_SimLine_26" },
		{ t = 2.4, mesh = "AK_TT_Sim_27", line = "AK_TT_SimLine_27" },
		{ t = 2.45, mesh = "AK_TT_Sim_28", line = "AK_TT_SimLine_28" },
		{ t = 2.5, mesh = "AK_TT_Sim_29" },
		{ t = 2.55, mesh = "AK_TT_Sim_30" },
		{ t = 2.6, mesh = "AK_TT_Sim_31" },
		{ t = 2.65, mesh = "AK_TT_Sim_32" },
		{ t = 2.7, mesh = "AK_TT_Sim_33" },
		{ t = 2.75, mesh = "AK_TT_Sim_34" },
		{ t = 2.8, mesh = "AK_TT_Sim_35" },
		{ t = 2.85, mesh = "AK_TT_Sim_36" },
		{ t = 2.9, mesh = "AK_TT_Sim_37" },
	},

	-- the flood's reach, for the wet ground left behind (studs, origin frame): `pool` = the union of the frames' boxes
	-- once the water is a pool (t >= 2.05: frames 20..37), `last` = frame 37's box alone. along = X, across = Z.
	footprint = {
		pool = { along = 41.7585, across = 53.8547, centre = Vector3.new(-0.0394, 0, -0.0011) },
		last = { along = 39.8595, across = 42.3769, centre = Vector3.new(-0.0018, 0, -2.0906) },
		top = 14.619,                -- the highest any frame reaches (the curtain)
	},

	-- DROPS (tt_sim_drops.json): one AK_WG_Drop each, from t at pos with velocity vel, radius as given (the drop's width is
	-- 2 x radius), AIMED along its velocity and stretched along it by 1 + min(speed, 60) / 30, falling at `gravity`
	-- (studs/s^2 down: the sim's own 0.6 x 196.2). landOn: where the SAME arc meets the flipbook's water at landT / landPos:
	-- "pool" = a small crown there (AK_SA_Splash ~1x); "absorbed" = gone into a mound or strand (no crown); "floor" = dry
	-- floor (gone, no crown); "none" = still airborne after 3 s. src: "rim" (the torn rim pinching off, 1.2-1.72 s),
	-- "rain" (shed by the falling curtain), "island" (a blob the sim pinched off). Capped: skip rain first, then island,
	-- then rim.
	drops = {
		gravity = 117.72,
		list = {
			{ t = 1.15, src = "rim", pos = Vector3.new(-4.839, 13.125, 0.134), vel = Vector3.new(0.765, 14.703, 5.727), radius = 0.32, landT = 1.725, landOn = "pool", landPos = Vector3.new(-4.4, 2.291, 3.427) },
			{ t = 1.15, src = "rim", pos = Vector3.new(4.63, 13.071, 0.004), vel = Vector3.new(0.25, 14.989, -5.913), radius = 0.32, landT = 1.708, landOn = "absorbed", landPos = Vector3.new(4.77, 3.091, -3.297) },
			{ t = 1.15, src = "rim", pos = Vector3.new(-3.763, 12.798, -2.79), vel = Vector3.new(0.123, -8.054, 21.266), radius = 0.32, landT = 1.492, landOn = "pool", landPos = Vector3.new(-3.721, 3.348, 4.476) },
			{ t = 1.2, src = "rim", pos = Vector3.new(3.491, 12.078, 2.235), vel = Vector3.new(0.09, -13.933, -21.005), radius = 0.32, landT = 1.492, landOn = "absorbed", landPos = Vector3.new(3.517, 3.007, -3.892) },
			{ t = 1.2, src = "rim", pos = Vector3.new(-5.711, 12.077, -1.595), vel = Vector3.new(0.121, -12.081, 20.011), radius = 0.32, landT = 1.508, landOn = "pool", landPos = Vector3.new(-5.673, 3.025, 4.575) },
			{ t = 1.25, src = "rim", pos = Vector3.new(6.38, 11.959, 0.024), vel = Vector3.new(1.458, -8.756, -14.157), radius = 0.32, landT = 1.533, landOn = "absorbed", landPos = Vector3.new(6.793, 4.753, -3.987) },
			{ t = 1.25, src = "rim", pos = Vector3.new(-3.976, 11.521, -1.299), vel = Vector3.new(-0.35, -15.487, 19.066), radius = 0.32, landT = 1.517, landOn = "pool", landPos = Vector3.new(-4.07, 3.308, 3.786) },
			{ t = 1.25, src = "rim", pos = Vector3.new(3.482, 11.226, 1.467), vel = Vector3.new(0.286, -17.711, -19.924), radius = 0.32, landT = 1.508, landOn = "absorbed", landPos = Vector3.new(3.556, 2.723, -3.68) },
			{ t = 1.3, src = "rim", pos = Vector3.new(-4.624, 10.243, -1.037), vel = Vector3.new(-1.462, -19.538, 15.971), radius = 0.32, landT = 1.558, landOn = "absorbed", landPos = Vector3.new(-5.002, 1.267, 3.089) },
			{ t = 1.3, src = "rim", pos = Vector3.new(4.226, 9.814, 1.428), vel = Vector3.new(0.726, -25.094, -19.936), radius = 0.32, landT = 1.558, landOn = "absorbed", landPos = Vector3.new(4.413, -0.597, -3.722) },
			{ t = 1.35, src = "rim", pos = Vector3.new(-5.936, 11.611, 1.548), vel = Vector3.new(-0.432, -11.435, 10.061), radius = 0.32, landT = 1.617, landOn = "absorbed", landPos = Vector3.new(-6.051, 4.376, 4.231) },
			{ t = 1.35, src = "rim", pos = Vector3.new(-8.359, 9.052, 1.014), vel = Vector3.new(-8.974, -17.86, 5.202), radius = 0.32, landT = 1.558, landOn = "pool", landPos = Vector3.new(-10.228, 2.8, 2.098) },
			{ t = 1.4, src = "rim", pos = Vector3.new(0.167, 11.953, 1.894), vel = Vector3.new(-0.243, -17.562, 2.745), radius = 0.32, landT = 1.658, landOn = "absorbed", landPos = Vector3.new(0.104, 3.489, 2.603) },
			{ t = 1.4, src = "rim", pos = Vector3.new(-6.641, 10.227, 1.368), vel = Vector3.new(-1.77, -20.906, 11.646), radius = 0.32, landT = 1.625, landOn = "pool", landPos = Vector3.new(-7.039, 2.965, 3.988) },
			{ t = 1.4, src = "rim", pos = Vector3.new(2.59, 10.137, -2.237), vel = Vector3.new(0.198, -23.18, -6.199), radius = 0.32, landT = 1.625, landOn = "pool", landPos = Vector3.new(2.635, 3.337, -3.632) },
			{ t = 1.45, src = "rim", pos = Vector3.new(-1.966, 13.394, 1.153), vel = Vector3.new(-0.745, -15.673, 4.819), radius = 0.32, landT = 1.758, landOn = "absorbed", landPos = Vector3.new(-2.196, 2.966, 2.639) },
			{ t = 1.45, src = "rim", pos = Vector3.new(1.721, 12.918, -1.005), vel = Vector3.new(1.067, -16.966, -2.884), radius = 0.32, landT = 1.708, landOn = "absorbed", landPos = Vector3.new(1.997, 4.607, -1.75) },
			{ t = 1.5, src = "rim", pos = Vector3.new(-1.905, 12.513, 1.241), vel = Vector3.new(-0.754, -21.465, 4.835), radius = 0.32, landT = 1.767, landOn = "absorbed", landPos = Vector3.new(-2.106, 2.604, 2.53) },
			{ t = 1.5, src = "rim", pos = Vector3.new(1.682, 12.018, -0.95), vel = Vector3.new(0.841, -23.043, -2.424), radius = 0.32, landT = 1.742, landOn = "pool", landPos = Vector3.new(1.885, 3.114, -1.535) },
			{ t = 1.5, src = "rim", pos = Vector3.new(-4.006, 11.945, 2.376), vel = Vector3.new(0.101, -22.745, 7.482), radius = 0.32, landT = 1.742, landOn = "pool", landPos = Vector3.new(-3.981, 3.125, 4.184) },
			{ t = 1.6, src = "island", pos = Vector3.new(0.951, 4.255, -4.286), vel = Vector3.new(-3.247, -1.216, -32.489), radius = 0.2, landT = 1.733, landOn = "pool", landPos = Vector3.new(0.518, 3.29, -8.618) },
			{ t = 1.6, src = "rain", pos = Vector3.new(0.736, 4.325, -4.199), vel = Vector3.new(-4.843, 0.491, -31.055), radius = 0.33, landT = 1.733, landOn = "pool", landPos = Vector3.new(0.09, 3.413, -8.34) },
			{ t = 1.65, src = "rain", pos = Vector3.new(0.748, 5.319, 2.469), vel = Vector3.new(11.299, 5.892, 8.852), radius = 0.29, landT = 1.9, landOn = "pool", landPos = Vector3.new(3.572, 3.135, 4.683) },
			{ t = 1.65, src = "rain", pos = Vector3.new(-7.779, 4.546, 5.275), vel = Vector3.new(-13.173, 6.73, 23.853), radius = 0.29, landT = 1.867, landOn = "pool", landPos = Vector3.new(-10.634, 3.307, 10.443) },
			{ t = 1.7, src = "rain", pos = Vector3.new(-6.254, 4.014, 7.446), vel = Vector3.new(-1.225, -3.633, 27.847), radius = 0.29, landT = 1.792, landOn = "pool", landPos = Vector3.new(-6.366, 3.196, 9.998) },
			{ t = 1.85, src = "island", pos = Vector3.new(-8.496, 3.519, 10.401), vel = Vector3.new(-4.586, -20.744, 21.813), radius = 0.4, landT = 1.908, landOn = "pool", landPos = Vector3.new(-8.764, 2.125, 11.673) },
		},
	},

	-- FOAM FLECKS: slow foam pieces (AK_RT_Foam_1..4, `size` studs long) thrown off the curtain's top that HANG: gravity
	-- 49.05 (0.25 x 196.2) with linear drag 1.2 /s (a = -g - drag x v), a slow tumble; `hang` = seconds to reach the water
	-- under that model, endPos where. Shrink them over their last 0.3 s.
	flecks = {
		gravity = 49.05,
		drag = 1.2,
		list = {
			{ t = 1.25, pos = Vector3.new(-3.035, 14.641, 0.472), vel = Vector3.new(0.419, 5.583, 5.769), size = 0.52, hang = 1.02, endPos = Vector3.new(-2.79, 0.166, 3.834) },
			{ t = 1.25, pos = Vector3.new(1.647, 14.558, 0.12), vel = Vector3.new(1.123, 4.98, -3.54), size = 0.51, hang = 1, endPos = Vector3.new(2.296, 0.188, -1.926) },
			{ t = 1.3, pos = Vector3.new(-3.127, 14.9, 0.672), vel = Vector3.new(-0.009, 2.179, 5.583), size = 0.63, hang = 0.95, endPos = Vector3.new(-3.132, 0.293, 3.813) },
			{ t = 1.3, pos = Vector3.new(-0.919, 14.806, 0.22), vel = Vector3.new(-1.591, 2.983, 4.891), size = 0.69, hang = 0.97, endPos = Vector3.new(-1.823, 0.199, 2.998) },
			{ t = 1.35, pos = Vector3.new(-1.43, 14.919, 0.484), vel = Vector3.new(-2.075, 1.333, 6.289), size = 0.79, hang = 0.93, endPos = Vector3.new(-2.586, 0.293, 3.989) },
			{ t = 1.35, pos = Vector3.new(-3.655, 14.719, 1.201), vel = Vector3.new(1.697, 0.62, 7.97), size = 0.54, hang = 0.92, endPos = Vector3.new(-2.718, 0.151, 5.6) },
		},
	},

	-- THE SECOND SLAM: where the falling curtain hits the pool, one crown (AK_SA_Splash) per 3-stud station along the seam,
	-- sitting on the pool top (pos, its Y = poolH). crownScale is the builder's size number; the manifest reads it as
	-- "v4 smaller: ~3-4 studs across" (AquaFX converts it to that width). The frames carry the low skirt splash themselves.
	slam = {
		{ t = 1.7, pos = Vector3.new(-2.949, 2.506, 3.417), poolH = 2.51, crownScale = 2.6, impactSpeed = 42.1 },
		{ t = 1.7, pos = Vector3.new(-0.251, 2.697, 0.465), poolH = 2.7, crownScale = 2.56, impactSpeed = 40.8 },
		{ t = 1.7, pos = Vector3.new(3.241, 2.848, -2.949), poolH = 2.85, crownScale = 2.66, impactSpeed = 43.7 },
	},
}

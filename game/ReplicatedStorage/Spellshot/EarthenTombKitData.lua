--[[
	EarthenTombKitData  (ModuleScript)  ->  ReplicatedStorage/Spellshot/EarthenTombKitData

	GENERATED 2026-10-09 by blender_scripts/terra/earthen_tomb_kit_export.py -- do not edit by hand; re-run the exporter.
	Terra's Earthen Tomb rework (earthen_tomb_bl.py) for the kit export/terra_kit/TerraTomb2.fbx (folder
	ReplicatedStorage.EarthMagicMeshes.TerraTomb2, set up by tools/terra_wall_tomb_kit_setup.lua). LOOK ONLY: every
	server number, time and broadcast stays live (vfx_blocking/terra/WALL_TOMB_PORT_SPEC.md).

	AXES AND FRAMES. Every vector / CFrame here is in ROBLOX KIT axes (Blender (x, y, z) -> (-x, z, y)) in the TARGET'S
	FEET FRAME: origin the catch point on the floor (TombCatch At), +Y up, +Z toward the caster. Place it with
	  frame * Turn * <kit CFrame>,   frame = CFrame.lookAt(At, At + Face)   (Face: flat, toward Terra)
	Turn = CFrame.Angles(0, math.pi, 0) carries kit +Z onto the LookVector; the integrator may correct it after
	measuring the import. Times are on the CATCH clock: seconds after TombCatch's T0 (the ground tearing loose).
	PARTS. A piece is up to four MeshParts sharing ONE pivot: Name, Name.._Brk, Name.._Lit, Name.._Dead (ChargedRock.Clone;
	any but the stone may be missing). The setup script makes every PivotOffset a pure translation, so a part goes to
	pivot CFrame P with part.CFrame = P * part.PivotOffset:Inverse(). A piece with Interior = true has no outside: its
	stone part IS its break faces, baked INNER, and it has no _Brk.

	FIELDS (spec section 2, plus the additions marked +):
	  Heap[r] (r = 1..39, bottom ring first) = { Ring (1..5), Rel (the rock's centre, feet frame), EruptAt,
	    Travel (+: it waits this far under the slab top), Pull (+: and pulled in this, Vector3), Axis (+: the tumble's
	    axis), Dir (+: its flat outward direction, for the burst), Struck (+: a boulder slams into it at the top),
	    Pieces = { {Name, Rel (the piece's pivot, FEET frame), Local (+: the same, relative to the rock's Rel), Phase, Vol} } }
	    A rock at catch time c, p = punch((c - EruptAt) / Timing.EruptTime) (0 before):
	      piece = frame * Turn * CF(Pull*(1-min(p,1)) - (0, Travel*(1-p), 0)) * Rel * Angles(Axis, (1-min(p,1))*Timing.Tumble) * Local
	      punch(u) = (1 - (1-u)^3) * (1 + Timing.PunchOver * sin(pi u)), u clamped to 0..1
	    (all of it rides up with the slab: frame * CF(0, slabY, 0) * ...)
	  Boulders[b] (b = 1..8) = { TearAt (torn out of the ground), From (where it is buried, feet frame at rest),
	    Control (+: the Bezier's control point), Gather (feet frame at rest: it includes the slab's height at Converge,
	    GatherSlabY (+)), StopAt (relative to the chest: Dir * REnd), Dir (+), REnd (+), Spin (+ rad/s), Axis (+), Q0 (+:
	    its rest orientation), Size (+), Radius (+),
	    Pieces = { {Name, Rel (to the boulder's centre), Phase, Vol} } }
	    Path: TearAt..Timing.ConvergeAt: quadratic Bezier From -> Control -> Gather, eased out (1-(1-u)^3); then to Top:
	    chest + Dir * (REnd + (Timing.BoulderFrom - REnd) * (1 - e^2)), e = (c - ConvergeAt) / (Top - ConvergeAt), the chest
	    = slab top + (0, Timing.ChestUp, 0). Spin: CFrame.fromAxisAngle(Axis, Spin * (min(c, Top) - TearAt)) * Q0.
	  Slab = { Outline (Vector2 X, Z; the slab's edge, CCW seen from above), Depth, Clod, Top (+: the torn-loose ground,
	    one part), Mouth (+: the dark hole, at the floor), Centre (+), PitR (+), Wobble, Tremble, Ring, Thud (+: laws below) }
	    Clod, Top and Mouth all pivot at the feet: Clod/Top ride frame * Turn * CF(0, slabY, 0); Mouth stays at the floor.
	  Ground (+) = { Plates = { {Name, Rel (top centroid, feet frame; tops at Y = 0), Kind ("shove"|"rim"), ...} } }
	    shove: Dly, H, Tilt, Sh -- from c = Dly: on = (1-exp(-a/0.035))(1+0.18exp(-a/0.1)sin(38a)); up H*on, out (from the
	      feet) Sh*on, tipped Tilt*on about the horizontal axis across that outward line (outer edge up)
	    rim: T, H, Tr -- from c = T: k = (1-exp(-a/0.03))(1+0.2exp(-a/0.1)sin(40a)); up H*k, outer edge up Tr*k
	  Burst (the throw at TombBurst; spec 2.6 minus the camera's "aside"), Timing, Dust (+), Pebbles (+), Parts (+).
	EVERY NUMBER HERE IS A PROPOSAL where it is look tuning (the showcase's T); the live server numbers win.
]]

return {
	Version = 1,
	Turn = CFrame.Angles(0, math.pi, 0),
	Heap = {
		{ Ring = 1, Rel = CFrame.new(-1.8784, 0.425, -0.671), EruptAt = 0.0362, Travel = 1.4151, Pull = Vector3.new(0.475, 0, 0.1562), Axis = Vector3.new(-0.8104, -0.062, -0.5826), Dir = Vector3.new(-0.95, 0, -0.3123), Struck = false,
			Pieces = {
				{ Name = "ET_H01_1", Rel = CFrame.new(-1.7251, 0.6729, -0.6402), Local = CFrame.new(0.1533, 0.2478, 0.0308), Phase = 3.008, Vol = 0.2477 },
				{ Name = "ET_H01_2", Rel = CFrame.new(-1.9522, 0.2785, -0.8262), Local = CFrame.new(-0.0738, -0.1466, -0.1552), Phase = 3.0326, Vol = 0.1919 },
				{ Name = "ET_H01_3", Rel = CFrame.new(-1.9579, 0.3237, -0.5465), Local = CFrame.new(-0.0795, -0.1013, 0.1244), Phase = 3.2651, Vol = 0.3453 },
			} },
		{ Ring = 1, Rel = CFrame.new(-1.8829, 0.3887, 0.5444), EruptAt = 0.0234, Travel = 1.3631, Pull = Vector3.new(0.4876, 0, -0.1105), Axis = Vector3.new(0.383, -0.735, -0.5595), Dir = Vector3.new(-0.9753, 0, 0.2209), Struck = false,
			Pieces = {
				{ Name = "ET_H02_1", Rel = CFrame.new(-2.0447, 0.3437, 0.4678), Local = CFrame.new(-0.1618, -0.045, -0.0766), Phase = 7.7874, Vol = 0.5333 },
				{ Name = "ET_H02_2", Rel = CFrame.new(-1.9007, 0.6405, 0.6167), Local = CFrame.new(-0.0177, 0.2519, 0.0723), Phase = 7.5535, Vol = 0.3014 },
				{ Name = "ET_H02_3", Rel = CFrame.new(-1.7034, 0.1818, 0.5487), Local = CFrame.new(0.1795, -0.2069, 0.0043), Phase = 7.3603, Vol = 0.2024 },
			} },
		{ Ring = 1, Rel = CFrame.new(-1.3011, 0.3239, 1.3058), EruptAt = 0.0268, Travel = 1.311, Pull = Vector3.new(0.3352, 0, -0.371), Axis = Vector3.new(0.0893, 0.3092, 0.9468), Dir = Vector3.new(-0.6705, 0, 0.7419), Struck = false,
			Pieces = {
				{ Name = "ET_H03_1", Rel = CFrame.new(-1.5613, 0.2203, 1.3992), Local = CFrame.new(-0.2603, -0.1035, 0.0933), Phase = 7.5406, Vol = 0.3184 },
				{ Name = "ET_H03_2", Rel = CFrame.new(-1.1209, 0.6283, 1.1902), Local = CFrame.new(0.1802, 0.3044, -0.1156), Phase = 8.8599, Vol = 0.2212 },
				{ Name = "ET_H03_3", Rel = CFrame.new(-1.221, 0.123, 1.3281), Local = CFrame.new(0.0801, -0.2009, 0.0223), Phase = 7.33, Vol = 0.3556 },
			} },
		{ Ring = 1, Rel = CFrame.new(-0.0877, 0.4364, 1.4511), EruptAt = 0.0472, Travel = 1.4324, Pull = Vector3.new(0.0306, 0, -0.4991), Axis = Vector3.new(0.8608, -0.2862, 0.4208), Dir = Vector3.new(-0.0611, 0, 0.9981), Struck = false,
			Pieces = {
				{ Name = "ET_H04_1", Rel = CFrame.new(-0.0193, 0.2469, 1.3439), Local = CFrame.new(0.0684, -0.1896, -0.1072), Phase = 9.1515, Vol = 0.332 },
				{ Name = "ET_H04_2", Rel = CFrame.new(-0.2305, 0.3307, 1.6504), Local = CFrame.new(-0.1428, -0.1057, 0.1993), Phase = 9.8784, Vol = 0.2443 },
				{ Name = "ET_H04_3", Rel = CFrame.new(-0.0133, 0.7317, 1.359), Local = CFrame.new(0.0744, 0.2953, -0.0921), Phase = 10.0597, Vol = 0.2203 },
			} },
		{ Ring = 1, Rel = CFrame.new(0.9338, 0.479, 1.1848), EruptAt = 0.0438, Travel = 1.4376, Pull = Vector3.new(-0.3119, 0, -0.3908), Axis = Vector3.new(-0.6498, -0.1905, 0.7358), Dir = Vector3.new(0.6239, 0, 0.7815), Struck = false,
			Pieces = {
				{ Name = "ET_H05_1", Rel = CFrame.new(1.2333, 0.5497, 1.27), Local = CFrame.new(0.2995, 0.0707, 0.0852), Phase = 10.6055, Vol = 0.6107 },
				{ Name = "ET_H05_2", Rel = CFrame.new(0.8286, 0.191, 1.1197), Local = CFrame.new(-0.1052, -0.288, -0.065), Phase = 11.0931, Vol = 0.1992 },
				{ Name = "ET_H05_3", Rel = CFrame.new(0.7395, 0.6962, 1.1646), Local = CFrame.new(-0.1943, 0.2173, -0.0202), Phase = 11.7363, Vol = 0.1881 },
			} },
		{ Ring = 1, Rel = CFrame.new(1.9332, 0.3195, 0.5902), EruptAt = 0.0264, Travel = 1.3689, Pull = Vector3.new(-0.4842, 0, -0.1248), Axis = Vector3.new(-0.2273, -0.9432, 0.2424), Dir = Vector3.new(0.9683, 0, 0.2497), Struck = false,
			Pieces = {
				{ Name = "ET_H06_1", Rel = CFrame.new(1.8139, 0.457, 0.4174), Local = CFrame.new(-0.1193, 0.1375, -0.1727), Phase = 6.3951, Vol = 0.4016 },
				{ Name = "ET_H06_2", Rel = CFrame.new(2.1745, 0.2842, 0.5597), Local = CFrame.new(0.2413, -0.0353, -0.0304), Phase = 7.4261, Vol = 0.2172 },
				{ Name = "ET_H06_3", Rel = CFrame.new(1.8111, 0.2172, 0.7934), Local = CFrame.new(-0.122, -0.1022, 0.2032), Phase = 7.528, Vol = 0.2255 },
			} },
		{ Ring = 1, Rel = CFrame.new(1.9041, 0.3477, -0.5328), EruptAt = 0.0439, Travel = 1.4349, Pull = Vector3.new(-0.4794, 0, 0.1421), Axis = Vector3.new(0.7349, 0.4536, -0.5041), Dir = Vector3.new(0.9588, 0, -0.2841), Struck = false,
			Pieces = {
				{ Name = "ET_H07_1", Rel = CFrame.new(2.0371, 0.1439, -0.5811), Local = CFrame.new(0.133, -0.2039, -0.0484), Phase = 5.0507, Vol = 0.2188 },
				{ Name = "ET_H07_2", Rel = CFrame.new(1.5925, 0.4175, -0.478), Local = CFrame.new(-0.3116, 0.0697, 0.0547), Phase = 6.163, Vol = 0.2665 },
				{ Name = "ET_H07_3", Rel = CFrame.new(2.0827, 0.4819, -0.5391), Local = CFrame.new(0.1786, 0.1342, -0.0064), Phase = 5.845, Vol = 0.435 },
			} },
		{ Ring = 1, Rel = CFrame.new(1.267, 0.3579, -1.2946), EruptAt = 0.0209, Travel = 1.2949, Pull = Vector3.new(-0.334, 0, 0.3721), Axis = Vector3.new(-0.1674, -0.9715, -0.1676), Dir = Vector3.new(0.6681, 0, -0.7441), Struck = false,
			Pieces = {
				{ Name = "ET_H08_1", Rel = CFrame.new(1.2377, 0.6314, -1.2867), Local = CFrame.new(-0.0294, 0.2734, 0.008), Phase = 1.7359, Vol = 0.3864 },
				{ Name = "ET_H08_2", Rel = CFrame.new(1.5791, 0.1621, -1.4337), Local = CFrame.new(0.3121, -0.1959, -0.139), Phase = 2.129, Vol = 0.2782 },
				{ Name = "ET_H08_3", Rel = CFrame.new(0.9843, 0.2804, -1.1636), Local = CFrame.new(-0.2827, -0.0775, 0.1311), Phase = 2.3319, Vol = 0.3306 },
			} },
		{ Ring = 1, Rel = CFrame.new(0.1624, 0.3943, -1.4876), EruptAt = 0.0271, Travel = 1.4586, Pull = Vector3.new(-0.0462, 0, 0.4979), Axis = Vector3.new(0.5187, 0.8359, -0.1796), Dir = Vector3.new(0.0925, 0, -0.9957), Struck = false,
			Pieces = {
				{ Name = "ET_H09_1", Rel = CFrame.new(0.1651, 0.6575, -1.5538), Local = CFrame.new(0.0027, 0.2632, -0.0662), Phase = 2.6556, Vol = 0.3466 },
				{ Name = "ET_H09_2", Rel = CFrame.new(0.1013, 0.2659, -1.2077), Local = CFrame.new(-0.0611, -0.1284, 0.2799), Phase = 3.8459, Vol = 0.2578 },
				{ Name = "ET_H09_3", Rel = CFrame.new(0.2208, 0.2596, -1.7013), Local = CFrame.new(0.0584, -0.1348, -0.2137), Phase = 2.8056, Vol = 0.2568 },
			} },
		{ Ring = 1, Rel = CFrame.new(-0.9773, 0.3979, -1.3293), EruptAt = 0.0445, Travel = 1.3736, Pull = Vector3.new(0.2982, 0, 0.4013), Axis = Vector3.new(-0.2061, 0.9629, 0.174), Dir = Vector3.new(-0.5964, 0, -0.8027), Struck = false,
			Pieces = {
				{ Name = "ET_H10_1", Rel = CFrame.new(-1.1823, 0.467, -1.1889), Local = CFrame.new(-0.205, 0.0691, 0.1404), Phase = 6.3672, Vol = 0.4749 },
				{ Name = "ET_H10_2", Rel = CFrame.new(-0.6483, 0.5263, -1.2706), Local = CFrame.new(0.329, 0.1284, 0.0587), Phase = 6.6633, Vol = 0.295 },
				{ Name = "ET_H10_3", Rel = CFrame.new(-1.1012, 0.2003, -1.5283), Local = CFrame.new(-0.1239, -0.1976, -0.199), Phase = 7.26, Vol = 0.2944 },
			} },
		{ Ring = 2, Rel = CFrame.new(-2.854, 1.8539, -0.0026), EruptAt = 0.0766, Travel = 2.67, Pull = Vector3.new(0.5, 0, 0), Axis = Vector3.new(-0.8578, 0.0117, 0.5138), Dir = Vector3.new(-1, 0, 0), Struck = false,
			Pieces = {
				{ Name = "ET_H11_1", Rel = CFrame.new(-2.9106, 1.8047, 0.2644), Local = CFrame.new(-0.0566, -0.0492, 0.267), Phase = 12.5664, Vol = 0.6546 },
				{ Name = "ET_H11_2", Rel = CFrame.new(-2.8938, 2.0825, -0.1845), Local = CFrame.new(-0.0398, 0.2286, -0.1819), Phase = 12.5664, Vol = 0.3126 },
				{ Name = "ET_H11_3", Rel = CFrame.new(-2.7575, 1.6746, -0.0876), Local = CFrame.new(0.0964, -0.1793, -0.0851), Phase = 12.5664, Vol = 0.478 },
			} },
		{ Ring = 2, Rel = CFrame.new(-2.0042, 1.7183, 1.245), EruptAt = 0.0781, Travel = 2.6676, Pull = Vector3.new(0.3963, 0, -0.3049), Axis = Vector3.new(0.1105, -0.966, -0.2338), Dir = Vector3.new(-0.7925, 0, 0.6098), Struck = false,
			Pieces = {
				{ Name = "ET_H12_1", Rel = CFrame.new(-1.3922, 1.7807, 1.1854), Local = CFrame.new(0.612, 0.0624, -0.0596), Phase = 9.8623, Vol = 0.6485 },
				{ Name = "ET_H12_2", Rel = CFrame.new(-2.5456, 1.6043, 1.2911), Local = CFrame.new(-0.5414, -0.114, 0.0461), Phase = 7.1509, Vol = 0.365 },
				{ Name = "ET_H12_3", Rel = CFrame.new(-2.0748, 1.7699, 1.2586), Local = CFrame.new(-0.0706, 0.0516, 0.0135), Phase = 8.4643, Vol = 0.7151 },
			} },
		{ Ring = 2, Rel = CFrame.new(-0.3369, 1.8474, 1.2718), EruptAt = 0.0926, Travel = 2.7297, Pull = Vector3.new(0.1238, 0, -0.4844), Axis = Vector3.new(-0.3915, 0.1781, 0.9028), Dir = Vector3.new(-0.2475, 0, 0.9689), Struck = false,
			Pieces = {
				{ Name = "ET_H13_1", Rel = CFrame.new(-0.3236, 1.6255, 1.3755), Local = CFrame.new(0.0133, -0.2219, 0.1037), Phase = 2.8879, Vol = 0.3049 },
				{ Name = "ET_H13_2", Rel = CFrame.new(-0.4758, 2.0694, 1.32), Local = CFrame.new(-0.1389, 0.2221, 0.0482), Phase = 3.6751, Vol = 0.1351 },
				{ Name = "ET_H13_3", Rel = CFrame.new(-0.2113, 1.8472, 1.1198), Local = CFrame.new(0.1256, -0.0002, -0.1519), Phase = 3.1338, Vol = 0.1675 },
			} },
		{ Ring = 2, Rel = CFrame.new(0.393, 1.6756, 1.2402), EruptAt = 0.0969, Travel = 2.7097, Pull = Vector3.new(-0.1529, 0, -0.4761), Axis = Vector3.new(-0.3413, 0.4273, 0.8372), Dir = Vector3.new(0.3057, 0, 0.9521), Struck = false,
			Pieces = {
				{ Name = "ET_H14_1", Rel = CFrame.new(0.3834, 1.6406, 1.3178), Local = CFrame.new(-0.0096, -0.0351, 0.0776), Phase = 8.8823, Vol = 0.2328 },
				{ Name = "ET_H14_2", Rel = CFrame.new(0.3558, 2.0051, 1.2092), Local = CFrame.new(-0.0372, 0.3295, -0.031), Phase = 7.8672, Vol = 0.1172 },
				{ Name = "ET_H14_3", Rel = CFrame.new(0.4398, 1.3812, 1.1937), Local = CFrame.new(0.0468, -0.2944, -0.0466), Phase = 9.3826, Vol = 0.0751 },
			} },
		{ Ring = 2, Rel = CFrame.new(1.4387, 1.7979, 1.1549), EruptAt = 0.0916, Travel = 2.7184, Pull = Vector3.new(-0.3897, 0, -0.3133), Axis = Vector3.new(-0.0527, 0.8509, -0.5226), Dir = Vector3.new(0.7793, 0, 0.6266), Struck = false,
			Pieces = {
				{ Name = "ET_H15_1", Rel = CFrame.new(1.8647, 1.6535, 1.2038), Local = CFrame.new(0.426, -0.1444, 0.0489), Phase = 8.9551, Vol = 0.779 },
				{ Name = "ET_H15_2", Rel = CFrame.new(1.0681, 1.6465, 1.11), Local = CFrame.new(-0.3706, -0.1514, -0.045), Phase = 7.197, Vol = 0.2416 },
				{ Name = "ET_H15_3", Rel = CFrame.new(1.3833, 2.0937, 1.151), Local = CFrame.new(-0.0554, 0.2958, -0.004), Phase = 6.9733, Vol = 0.3893 },
			} },
		{ Ring = 2, Rel = CFrame.new(2.8027, 1.6942, -0.0001), EruptAt = 0.0727, Travel = 2.6996, Pull = Vector3.new(-0.5, 0, 0), Axis = Vector3.new(-0.0555, 0.027, -0.9981), Dir = Vector3.new(1, 0, 0), Struck = false,
			Pieces = {
				{ Name = "ET_H16_1", Rel = CFrame.new(2.9334, 1.7456, -0.0046), Local = CFrame.new(0.1307, 0.0514, -0.0045), Phase = 9.0203, Vol = 0.573 },
				{ Name = "ET_H16_2", Rel = CFrame.new(2.7502, 1.6044, -0.3791), Local = CFrame.new(-0.0526, -0.0898, -0.3789), Phase = 9.3373, Vol = 0.3681 },
				{ Name = "ET_H16_3", Rel = CFrame.new(2.7246, 1.7327, 0.3833), Local = CFrame.new(-0.0781, 0.0384, 0.3834), Phase = 9.3655, Vol = 0.3589 },
			} },
		{ Ring = 2, Rel = CFrame.new(1.8483, 1.6374, -1.2579), EruptAt = 0.0754, Travel = 2.604, Pull = Vector3.new(-0.3968, 0, 0.3042), Axis = Vector3.new(-0.6684, -0.5729, -0.4743), Dir = Vector3.new(0.7937, 0, -0.6083), Struck = false,
			Pieces = {
				{ Name = "ET_H17_1", Rel = CFrame.new(1.212, 1.7758, -1.1853), Local = CFrame.new(-0.6363, 0.1384, 0.0726), Phase = 6.2568, Vol = 0.3477 },
				{ Name = "ET_H17_2", Rel = CFrame.new(2.4355, 1.4807, -1.3079), Local = CFrame.new(0.5872, -0.1567, -0.0501), Phase = 4.904, Vol = 0.435 },
				{ Name = "ET_H17_3", Rel = CFrame.new(1.8973, 1.6558, -1.2804), Local = CFrame.new(0.0491, 0.0184, -0.0225), Phase = 5.8499, Vol = 0.7842 },
			} },
		{ Ring = 2, Rel = CFrame.new(0.4459, 1.649, -1.4071), EruptAt = 0.0871, Travel = 2.6357, Pull = Vector3.new(-0.148, 0, 0.4776), Axis = Vector3.new(0.7945, -0.567, 0.2175), Dir = Vector3.new(0.2959, 0, -0.9552), Struck = false,
			Pieces = {
				{ Name = "ET_H18_1", Rel = CFrame.new(0.3849, 1.9232, -1.3652), Local = CFrame.new(-0.061, 0.2743, 0.0419), Phase = 5.4922, Vol = 0.2505 },
				{ Name = "ET_H18_2", Rel = CFrame.new(0.3409, 1.4131, -1.295), Local = CFrame.new(-0.105, -0.2359, 0.1121), Phase = 6.4706, Vol = 0.1527 },
				{ Name = "ET_H18_3", Rel = CFrame.new(0.6119, 1.6106, -1.5611), Local = CFrame.new(0.166, -0.0384, -0.154), Phase = 6.2514, Vol = 0.1989 },
			} },
		{ Ring = 2, Rel = CFrame.new(-0.3904, 1.6843, -1.2995), EruptAt = 0.0842, Travel = 2.7065, Pull = Vector3.new(0.1436, 0, 0.4789), Axis = Vector3.new(0.692, 0.7066, 0.1481), Dir = Vector3.new(-0.2873, 0, -0.9578), Struck = false,
			Pieces = {
				{ Name = "ET_H19_1", Rel = CFrame.new(-0.3967, 1.9505, -1.3663), Local = CFrame.new(-0.0063, 0.2662, -0.0668), Phase = 6.5864, Vol = 0.2067 },
				{ Name = "ET_H19_2", Rel = CFrame.new(-0.4843, 1.5625, -1.4721), Local = CFrame.new(-0.0939, -0.1218, -0.1727), Phase = 6.1686, Vol = 0.2797 },
				{ Name = "ET_H19_3", Rel = CFrame.new(-0.2901, 1.5398, -1.06), Local = CFrame.new(0.1003, -0.1445, 0.2395), Phase = 6.1628, Vol = 0.129 },
			} },
		{ Ring = 2, Rel = CFrame.new(-1.8957, 1.5645, -1.3096), EruptAt = 0.077, Travel = 2.5155, Pull = Vector3.new(0.3986, 0, 0.3019), Axis = Vector3.new(-0.8897, -0.0246, 0.4558), Dir = Vector3.new(-0.7972, 0, -0.6037), Struck = false,
			Pieces = {
				{ Name = "ET_H20_1", Rel = CFrame.new(-1.7234, 1.3265, -1.3125), Local = CFrame.new(0.1723, -0.238, -0.0029), Phase = 6.3302, Vol = 0.4436 },
				{ Name = "ET_H20_2", Rel = CFrame.new(-2.3152, 1.4814, -1.3088), Local = CFrame.new(-0.4196, -0.0831, 0.0009), Phase = 5.069, Vol = 0.6756 },
				{ Name = "ET_H20_3", Rel = CFrame.new(-1.6484, 1.8855, -1.3076), Local = CFrame.new(0.2473, 0.3211, 0.002), Phase = 6.8268, Vol = 0.387 },
			} },
		{ Ring = 3, Rel = CFrame.new(-2.8606, 3.0756, 0.0703), EruptAt = 0.1385, Travel = 4.0779, Pull = Vector3.new(0.5, 0, 0), Axis = Vector3.new(-0.4336, 0.0116, -0.901), Dir = Vector3.new(-1, 0, 0), Struck = true,
			Pieces = {
				{ Name = "ET_H21_1", Rel = CFrame.new(-2.9576, 3.2099, 0.336), Local = CFrame.new(-0.097, 0.1343, 0.2657), Phase = 2.6073, Vol = 0.3201 },
				{ Name = "ET_H21_2", Rel = CFrame.new(-2.9141, 3.077, -0.2417), Local = CFrame.new(-0.0534, 0.0014, -0.312), Phase = 1.7211, Vol = 0.5271 },
				{ Name = "ET_H21_3", Rel = CFrame.new(-2.7101, 2.9399, 0.1166), Local = CFrame.new(0.1505, -0.1357, 0.0463), Phase = 1.3353, Vol = 0.4643 },
			} },
		{ Ring = 3, Rel = CFrame.new(-1.6711, 2.9771, 1.294), EruptAt = 0.1497, Travel = 4.0424, Pull = Vector3.new(0.3768, 0, -0.3287), Axis = Vector3.new(-0.1744, -0.9281, -0.329), Dir = Vector3.new(-0.7536, 0, 0.6574), Struck = false,
			Pieces = {
				{ Name = "ET_H22_1", Rel = CFrame.new(-1.6985, 3.0118, 1.3314), Local = CFrame.new(-0.0273, 0.0347, 0.0375), Phase = 9.0485, Vol = 0.873 },
				{ Name = "ET_H22_2", Rel = CFrame.new(-1.0263, 3.0112, 1.2288), Local = CFrame.new(0.6448, 0.0341, -0.0652), Phase = 9.4943, Vol = 0.3959 },
				{ Name = "ET_H22_3", Rel = CFrame.new(-2.2887, 2.9083, 1.3217), Local = CFrame.new(-0.6175, -0.0688, 0.0277), Phase = 8.2324, Vol = 0.4714 },
			} },
		{ Ring = 3, Rel = CFrame.new(-0.0015, 3.1042, 1.3911), EruptAt = 0.1469, Travel = 4.0704, Pull = Vector3.new(0.0027, 0, -0.5), Axis = Vector3.new(-0.2508, 0.4952, 0.8318), Dir = Vector3.new(-0.0055, 0, 1), Struck = false,
			Pieces = {
				{ Name = "ET_H23_1", Rel = CFrame.new(0.0516, 2.9032, 1.3223), Local = CFrame.new(0.053, -0.2009, -0.0688), Phase = 3.6969, Vol = 0.3873 },
				{ Name = "ET_H23_2", Rel = CFrame.new(0.111, 3.3526, 1.2945), Local = CFrame.new(0.1125, 0.2485, -0.0966), Phase = 2.1605, Vol = 0.1997 },
				{ Name = "ET_H23_3", Rel = CFrame.new(-0.167, 3.0566, 1.5566), Local = CFrame.new(-0.1655, -0.0475, 0.1655), Phase = 3.7884, Vol = 0.1853 },
			} },
		{ Ring = 3, Rel = CFrame.new(1.6313, 2.9514, 1.2245), EruptAt = 0.1243, Travel = 3.9695, Pull = Vector3.new(-0.375, 0, -0.3307), Axis = Vector3.new(0.9718, -0.1015, -0.213), Dir = Vector3.new(0.75, 0, 0.6615), Struck = true,
			Pieces = {
				{ Name = "ET_H24_1", Rel = CFrame.new(1.5905, 3.0575, 1.2342), Local = CFrame.new(-0.0408, 0.1061, 0.0097), Phase = 6.5536, Vol = 0.7634 },
				{ Name = "ET_H24_2", Rel = CFrame.new(1.0914, 2.9753, 1.121), Local = CFrame.new(-0.5399, 0.0239, -0.1035), Phase = 6.2083, Vol = 0.3081 },
				{ Name = "ET_H24_3", Rel = CFrame.new(2.212, 2.8214, 1.3183), Local = CFrame.new(0.5807, -0.13, 0.0938), Phase = 6.382, Vol = 0.5211 },
			} },
		{ Ring = 3, Rel = CFrame.new(2.7603, 3.0599, -0.0345), EruptAt = 0.1371, Travel = 4.1584, Pull = Vector3.new(-0.5, 0, 0), Axis = Vector3.new(0.8196, 0.2036, 0.5356), Dir = Vector3.new(1, 0, 0), Struck = true,
			Pieces = {
				{ Name = "ET_H25_1", Rel = CFrame.new(2.849, 3.242, 0.2245), Local = CFrame.new(0.0886, 0.182, 0.259), Phase = 4.1333, Vol = 0.5098 },
				{ Name = "ET_H25_2", Rel = CFrame.new(2.76, 3.1618, -0.3872), Local = CFrame.new(-0.0003, 0.1018, -0.3528), Phase = 5.297, Vol = 0.4324 },
				{ Name = "ET_H25_3", Rel = CFrame.new(2.6721, 2.7761, 0.0593), Local = CFrame.new(-0.0883, -0.2839, 0.0938), Phase = 3.9131, Vol = 0.24 },
			} },
		{ Ring = 3, Rel = CFrame.new(1.6879, 2.8715, -1.1534), EruptAt = 0.1322, Travel = 3.9933, Pull = Vector3.new(-0.3916, 0, 0.3109), Axis = Vector3.new(-0.5091, -0.7665, 0.3914), Dir = Vector3.new(0.7832, 0, -0.6218), Struck = false,
			Pieces = {
				{ Name = "ET_H26_1", Rel = CFrame.new(2.1955, 2.9081, -1.1942), Local = CFrame.new(0.5076, 0.0366, -0.0407), Phase = 11.1004, Vol = 0.6349 },
				{ Name = "ET_H26_2", Rel = CFrame.new(1.2971, 3.1239, -1.1719), Local = CFrame.new(-0.3909, 0.2524, -0.0185), Phase = 11.2647, Vol = 0.432 },
				{ Name = "ET_H26_3", Rel = CFrame.new(1.5713, 2.5825, -1.0942), Local = CFrame.new(-0.1167, -0.289, 0.0592), Phase = 12.348, Vol = 0.3696 },
			} },
		{ Ring = 3, Rel = CFrame.new(-0.0087, 3.0881, -1.3032), EruptAt = 0.1285, Travel = 4.1128, Pull = Vector3.new(-0.0205, 0, 0.4996), Axis = Vector3.new(-0.6989, 0.4658, 0.5428), Dir = Vector3.new(0.0409, 0, -0.9992), Struck = false,
			Pieces = {
				{ Name = "ET_H27_1", Rel = CFrame.new(0.2134, 2.9799, -1.336), Local = CFrame.new(0.2221, -0.1082, -0.0328), Phase = 1.6425, Vol = 0.3283 },
				{ Name = "ET_H27_2", Rel = CFrame.new(0.0075, 3.3757, -1.3029), Local = CFrame.new(0.0162, 0.2876, 0.0003), Phase = 3.7737, Vol = 0.2795 },
				{ Name = "ET_H27_3", Rel = CFrame.new(-0.2471, 2.9087, -1.2707), Local = CFrame.new(-0.2383, -0.1794, 0.0325), Phase = 1.9936, Vol = 0.2185 },
			} },
		{ Ring = 3, Rel = CFrame.new(-1.9515, 3.0348, -1.2665), EruptAt = 0.1256, Travel = 4.0528, Pull = Vector3.new(0.3785, 0, 0.3267), Axis = Vector3.new(-0.9128, 0.3905, -0.1195), Dir = Vector3.new(-0.7571, 0, -0.6533), Struck = true,
			Pieces = {
				{ Name = "ET_H28_1", Rel = CFrame.new(-1.5193, 3.1581, -1.2396), Local = CFrame.new(0.4321, 0.1233, 0.0269), Phase = 11.5351, Vol = 0.9562 },
				{ Name = "ET_H28_2", Rel = CFrame.new(-2.1013, 2.7531, -1.2369), Local = CFrame.new(-0.1498, -0.2818, 0.0296), Phase = 11.812, Vol = 0.3485 },
				{ Name = "ET_H28_3", Rel = CFrame.new(-2.2338, 3.1933, -1.3229), Local = CFrame.new(-0.2823, 0.1585, -0.0565), Phase = 11.6095, Vol = 0.2902 },
			} },
		{ Ring = 4, Rel = CFrame.new(-1.1025, 4.5939, -0.6046), EruptAt = 0.189, Travel = 5.4853, Pull = Vector3.new(0, 0, 0), Axis = Vector3.new(-0.314, 0.8633, -0.3951), Dir = Vector3.new(-0.9233, 0, -0.384), Struck = false,
			Pieces = {
				{ Name = "ET_H29_1", Rel = CFrame.new(-1.1763, 4.463, -0.4879), Local = CFrame.new(-0.0738, -0.1309, 0.1167), Phase = 3.3765, Vol = 0.2588 },
				{ Name = "ET_H29_2", Rel = CFrame.new(-1.025, 4.8024, -0.4869), Local = CFrame.new(0.0775, 0.2085, 0.1177), Phase = 3.9112, Vol = 0.143 },
				{ Name = "ET_H29_3", Rel = CFrame.new(-1.1063, 4.5164, -0.839), Local = CFrame.new(-0.0038, -0.0775, -0.2344), Phase = 3.8378, Vol = 0.0964 },
			} },
		{ Ring = 4, Rel = CFrame.new(-1.1699, 4.5425, 0.4881), EruptAt = 0.1764, Travel = 5.5126, Pull = Vector3.new(0, 0, 0), Axis = Vector3.new(0.2475, -0.7546, -0.6077), Dir = Vector3.new(-0.9244, 0, 0.3814), Struck = false,
			Pieces = {
				{ Name = "ET_H30_1", Rel = CFrame.new(-1.0846, 4.7138, 0.6062), Local = CFrame.new(0.0854, 0.1714, 0.1181), Phase = 3.9651, Vol = 0.2723 },
				{ Name = "ET_H30_2", Rel = CFrame.new(-1.0546, 4.6101, 0.296), Local = CFrame.new(0.1153, 0.0676, -0.1921), Phase = 3.5635, Vol = 0.1606 },
				{ Name = "ET_H30_3", Rel = CFrame.new(-1.3706, 4.3035, 0.5621), Local = CFrame.new(-0.2007, -0.239, 0.074), Phase = 3.3053, Vol = 0.1827 },
			} },
		{ Ring = 4, Rel = CFrame.new(-0.4887, 4.4949, 1.2053), EruptAt = 0.1931, Travel = 5.4717, Pull = Vector3.new(0, 0, 0), Axis = Vector3.new(-0.8065, 0.5906, 0.0273), Dir = Vector3.new(-0.3502, 0, 0.9367), Struck = true,
			Pieces = {
				{ Name = "ET_H31_1", Rel = CFrame.new(-0.6025, 4.6703, 1.22), Local = CFrame.new(-0.1138, 0.1755, 0.0147), Phase = 11.2899, Vol = 0.2766 },
				{ Name = "ET_H31_2", Rel = CFrame.new(-0.2204, 4.5408, 1.1175), Local = CFrame.new(0.2683, 0.0459, -0.0879), Phase = 11.1932, Vol = 0.1548 },
				{ Name = "ET_H31_3", Rel = CFrame.new(-0.6432, 4.2735, 1.2785), Local = CFrame.new(-0.1545, -0.2214, 0.0732), Phase = 10.8392, Vol = 0.1565 },
			} },
		{ Ring = 4, Rel = CFrame.new(0.6512, 4.4586, 1.1534), EruptAt = 0.1708, Travel = 5.4875, Pull = Vector3.new(0, 0, 0), Axis = Vector3.new(-0.5361, 0.585, 0.6085), Dir = Vector3.new(0.4147, 0, 0.91), Struck = false,
			Pieces = {
				{ Name = "ET_H32_1", Rel = CFrame.new(0.5734, 4.6875, 1.1645), Local = CFrame.new(-0.0778, 0.2289, 0.0111), Phase = 1.5078, Vol = 0.2524 },
				{ Name = "ET_H32_2", Rel = CFrame.new(0.526, 4.2444, 1.1929), Local = CFrame.new(-0.1252, -0.2141, 0.0396), Phase = 1.9738, Vol = 0.1385 },
				{ Name = "ET_H32_3", Rel = CFrame.new(0.8542, 4.4438, 1.1026), Local = CFrame.new(0.203, -0.0148, -0.0507), Phase = 2.5489, Vol = 0.0856 },
			} },
		{ Ring = 4, Rel = CFrame.new(1.22, 4.5743, 0.5654), EruptAt = 0.1962, Travel = 5.4792, Pull = Vector3.new(0, 0, 0), Axis = Vector3.new(0.7847, -0.5103, 0.3519), Dir = Vector3.new(0.9223, 0, 0.3865), Struck = false,
			Pieces = {
				{ Name = "ET_H33_1", Rel = CFrame.new(1.3163, 4.3368, 0.4743), Local = CFrame.new(0.0964, -0.2375, -0.0911), Phase = 7.2851, Vol = 0.1948 },
				{ Name = "ET_H33_2", Rel = CFrame.new(1.251, 4.5057, 0.752), Local = CFrame.new(0.0311, -0.0686, 0.1866), Phase = 7.0851, Vol = 0.2194 },
				{ Name = "ET_H33_3", Rel = CFrame.new(1.0926, 4.8804, 0.4699), Local = CFrame.new(-0.1274, 0.3061, -0.0955), Phase = 6.2821, Vol = 0.1449 },
			} },
		{ Ring = 4, Rel = CFrame.new(1.1827, 4.5943, -0.5916), EruptAt = 0.192, Travel = 5.473, Pull = Vector3.new(0, 0, 0), Axis = Vector3.new(-0.8165, -0.0972, -0.5691), Dir = Vector3.new(0.9254, 0, -0.3789), Struck = false,
			Pieces = {
				{ Name = "ET_H34_1", Rel = CFrame.new(1.2885, 4.377, -0.5174), Local = CFrame.new(0.1059, -0.2172, 0.0741), Phase = 4.0576, Vol = 0.3108 },
				{ Name = "ET_H34_2", Rel = CFrame.new(1.1613, 4.5338, -0.8177), Local = CFrame.new(-0.0213, -0.0604, -0.2261), Phase = 4.5421, Vol = 0.1693 },
				{ Name = "ET_H34_3", Rel = CFrame.new(1.0981, 4.872, -0.4396), Local = CFrame.new(-0.0845, 0.2777, 0.152), Phase = 3.7626, Vol = 0.1399 },
			} },
		{ Ring = 4, Rel = CFrame.new(0.5605, 4.6011, -1.1793), EruptAt = 0.1751, Travel = 5.518, Pull = Vector3.new(0, 0, 0), Axis = Vector3.new(-0.3347, 0.9235, 0.1873), Dir = Vector3.new(0.4074, 0, -0.9132), Struck = true,
			Pieces = {
				{ Name = "ET_H35_1", Rel = CFrame.new(0.6397, 4.8604, -1.1519), Local = CFrame.new(0.0792, 0.2593, 0.0275), Phase = 4.4327, Vol = 0.154 },
				{ Name = "ET_H35_2", Rel = CFrame.new(0.6994, 4.4156, -1.2763), Local = CFrame.new(0.139, -0.1855, -0.0969), Phase = 3.5933, Vol = 0.2351 },
				{ Name = "ET_H35_3", Rel = CFrame.new(0.3424, 4.5273, -1.1099), Local = CFrame.new(-0.2181, -0.0738, 0.0695), Phase = 3.9129, Vol = 0.174 },
			} },
		{ Ring = 4, Rel = CFrame.new(-0.4302, 4.4851, -1.2194), EruptAt = 0.1943, Travel = 5.4882, Pull = Vector3.new(0, 0, 0), Axis = Vector3.new(0.1145, 0.1292, -0.985), Dir = Vector3.new(-0.3576, 0, -0.9339), Struck = false,
			Pieces = {
				{ Name = "ET_H36_1", Rel = CFrame.new(-0.4965, 4.7305, -1.165), Local = CFrame.new(-0.0662, 0.2454, 0.0544), Phase = 8.3175, Vol = 0.2698 },
				{ Name = "ET_H36_2", Rel = CFrame.new(-0.1725, 4.401, -1.2131), Local = CFrame.new(0.2577, -0.0841, 0.0063), Phase = 8.3208, Vol = 0.1228 },
				{ Name = "ET_H36_3", Rel = CFrame.new(-0.6217, 4.3239, -1.28), Local = CFrame.new(-0.1915, -0.1613, -0.0606), Phase = 7.4509, Vol = 0.1691 },
			} },
		{ Ring = 5, Rel = CFrame.new(0.4163, 5.681, 0.2459), EruptAt = 0.2335, Travel = 6.4948, Pull = Vector3.new(0, 0, 0), Axis = Vector3.new(-0.3186, 0.5439, -0.7763), Dir = Vector3.new(0.8751, 0, 0.484), Struck = false,
			Pieces = {
				{ Name = "ET_H37_1", Rel = CFrame.new(0.4724, 5.6049, 0.5542), Local = CFrame.new(0.0561, -0.0761, 0.3082), Phase = 10.5855, Vol = 0.124 },
				{ Name = "ET_H37_2", Rel = CFrame.new(0.3943, 5.7695, -0.0069), Local = CFrame.new(-0.022, 0.0885, -0.2528), Phase = 9.9894, Vol = 0.1023 },
				{ Name = "ET_H37_3", Rel = CFrame.new(0.3822, 5.6686, 0.1905), Local = CFrame.new(-0.0341, -0.0124, -0.0554), Phase = 10.299, Vol = 0.1376 },
			} },
		{ Ring = 5, Rel = CFrame.new(-0.0891, 5.6621, -0.4295), EruptAt = 0.2269, Travel = 6.4367, Pull = Vector3.new(0, 0, 0), Axis = Vector3.new(-0.206, 0.9133, -0.3515), Dir = Vector3.new(-0.0184, 0, -0.9998), Struck = false,
			Pieces = {
				{ Name = "ET_H38_1", Rel = CFrame.new(-0.021, 5.6221, -0.4272), Local = CFrame.new(0.0682, -0.04, 0.0023), Phase = 9.4769, Vol = 0.1466 },
				{ Name = "ET_H38_2", Rel = CFrame.new(0.1866, 5.7948, -0.3327), Local = CFrame.new(0.2757, 0.1326, 0.0968), Phase = 9.9801, Vol = 0.1347 },
				{ Name = "ET_H38_3", Rel = CFrame.new(-0.433, 5.5695, -0.5286), Local = CFrame.new(-0.3439, -0.0926, -0.0991), Phase = 9.5492, Vol = 0.1129 },
			} },
		{ Ring = 5, Rel = CFrame.new(-0.2828, 5.6365, 0.3218), EruptAt = 0.2451, Travel = 6.4958, Pull = Vector3.new(0, 0, 0), Axis = Vector3.new(-0.9951, 0.0976, 0.0167), Dir = Vector3.new(-0.8567, 0, 0.5158), Struck = false,
			Pieces = {
				{ Name = "ET_H39_1", Rel = CFrame.new(-0.3472, 5.7039, 0.1018), Local = CFrame.new(-0.0644, 0.0673, -0.22), Phase = 5.0273, Vol = 0.2061 },
				{ Name = "ET_H39_2", Rel = CFrame.new(-0.4095, 5.6034, 0.6009), Local = CFrame.new(-0.1267, -0.0332, 0.2791), Phase = 5.7317, Vol = 0.0772 },
				{ Name = "ET_H39_3", Rel = CFrame.new(-0.0917, 5.6024, 0.2628), Local = CFrame.new(0.1911, -0.0342, -0.059), Phase = 5.4795, Vol = 0.067 },
			} },
	},
	Boulders = {
		{ TearAt = 0.4889, From = Vector3.new(-12.9985, -1.5156, 0.6924), Control = Vector3.new(-12.9985, 21.6777, 0.6924), Gather = Vector3.new(-11.2159, 20.4243, 0.6047), GatherSlabY = 10.6131,
			StopAt = Vector3.new(-3.2936, 1.948, 0.162), Dir = Vector3.new(-0.86, 0.5086, 0.0423), REnd = 3.83, Spin = 3.211, Axis = Vector3.new(-0.2012, -0.5103, 0.8361), Size = 2.8244, Radius = 1.5156,
			Q0 = CFrame.new(0, 0, 0, -0.1939, 0.9809, 0.012, 0.6827, 0.1261, 0.7197, 0.7045, 0.1477, -0.6941),
			Pieces = {
				{ Name = "ET_B01_1", Rel = CFrame.new(-0.0456, 0.1611, 0.5924), Phase = 4.3721, Vol = 1.2031 },
				{ Name = "ET_B01_2", Rel = CFrame.new(-0.3898, -0.0854, 0.0404), Phase = 3.0427, Vol = 1.132 },
				{ Name = "ET_B01_3", Rel = CFrame.new(0.4448, -0.3689, 0.3462), Phase = 3.9948, Vol = 1.1399 },
				{ Name = "ET_B01_4", Rel = CFrame.new(0.6254, 0.2651, -0.1979), Phase = 5.5896, Vol = 0.5579 },
			} },
		{ TearAt = 0.4456, From = Vector3.new(-11.1829, -1.5283, 8.4332), Control = Vector3.new(-11.1829, 22.2443, 8.4332), Gather = Vector3.new(-9.343, 19.596, 7.0502), GatherSlabY = 10.6131,
			StopAt = Vector3.new(-3.9231, 2.438, 2.9489), Dir = Vector3.new(-0.7159, 0.4449, 0.5381), REnd = 5.48, Spin = 4.5949, Axis = Vector3.new(0.3468, 0.7124, -0.6101), Size = 2.9797, Radius = 1.5283,
			Q0 = CFrame.new(0, 0, 0, -0.6314, 0.2018, 0.7487, -0.3813, 0.7599, -0.5264, -0.6752, -0.6179, -0.4029),
			Pieces = {
				{ Name = "ET_B02_1", Rel = CFrame.new(-0.5812, -0.3386, -0.2351), Phase = 5.0788, Vol = 0.5911 },
				{ Name = "ET_B02_2", Rel = CFrame.new(0.4289, 0.202, 0.1021), Phase = 3.8448, Vol = 1.6066 },
				{ Name = "ET_B02_3", Rel = CFrame.new(-0.5207, -0.0139, -0.7532), Phase = 2.7218, Vol = 0.5415 },
				{ Name = "ET_B02_4", Rel = CFrame.new(0.182, -0.3981, -0.119), Phase = 4.2363, Vol = 1.2017 },
			} },
		{ TearAt = 0.4357, From = Vector3.new(-2.7729, -1.5456, 13.3979), Control = Vector3.new(-2.7729, 23.6071, 13.3979), Gather = Vector3.new(-2.2533, 20.6858, 10.864), GatherSlabY = 10.6131,
			StopAt = Vector3.new(-0.7384, 2.2894, 3.6003), Dir = Vector3.new(-0.1705, 0.5287, 0.8315), REnd = 4.33, Spin = 3.8294, Axis = Vector3.new(-0.6558, 0.3566, -0.6654), Size = 2.9095, Radius = 1.5456,
			Q0 = CFrame.new(0, 0, 0, 0.9514, -0.2793, -0.1299, 0.2935, 0.9499, 0.1073, 0.0934, -0.1402, 0.9857),
			Pieces = {
				{ Name = "ET_B03_1", Rel = CFrame.new(0.3459, -0.1668, 0.0592), Phase = 9.0194, Vol = 1.3478 },
				{ Name = "ET_B03_2", Rel = CFrame.new(0.3558, -0.0494, 0.7746), Phase = 8.6925, Vol = 0.6573 },
				{ Name = "ET_B03_3", Rel = CFrame.new(0.5133, 0.4984, 0.1769), Phase = 10.0231, Vol = 0.8486 },
				{ Name = "ET_B03_4", Rel = CFrame.new(-0.5582, 0.0292, 0.1676), Phase = 10.5522, Vol = 1.2342 },
			} },
		{ TearAt = 0.4213, From = Vector3.new(7.7094, -1.4778, 11.6014), Control = Vector3.new(7.7094, 21.5152, 11.6014), Gather = Vector3.new(6.5321, 19.2874, 9.8464), GatherSlabY = 10.6131,
			StopAt = Vector3.new(2.011, 1.6762, 2.9978), Dir = Vector3.new(0.5053, 0.4212, 0.7532), REnd = 3.98, Spin = 6.6434, Axis = Vector3.new(-0.5932, 0.5705, 0.568), Size = 3.0549, Radius = 1.4778,
			Q0 = CFrame.new(0, 0, 0, -0.682, -0.6747, -0.2822, -0.3395, 0.6339, -0.6949, 0.6478, -0.3781, -0.6614),
			Pieces = {
				{ Name = "ET_B04_1", Rel = CFrame.new(-0.3528, -0.3158, 0.3258), Phase = 10.5436, Vol = 1.3313 },
				{ Name = "ET_B04_2", Rel = CFrame.new(0.3648, -0.3648, 0.1193), Phase = 8.7222, Vol = 1.8788 },
				{ Name = "ET_B04_3", Rel = CFrame.new(-0.1718, 0.4976, 0.2983), Phase = 11.4001, Vol = 1.1467 },
				{ Name = "ET_B04_4", Rel = CFrame.new(0.2838, 0.4279, -0.2415), Phase = 11.1314, Vol = 0.7795 },
			} },
		{ TearAt = 0.4823, From = Vector3.new(15.5391, -1.2936, 0.3288), Control = Vector3.new(15.5391, 14.9156, 0.3288), Gather = Vector3.new(12.9299, 12.9063, 0.2829), GatherSlabY = 10.6131,
			StopAt = Vector3.new(4.4684, -0.3123, 0.0786), Dir = Vector3.new(0.9974, -0.0697, 0.0176), REnd = 4.48, Spin = 4.377, Axis = Vector3.new(0.2692, -0.1981, 0.9425), Size = 2.6284, Radius = 1.2936,
			Q0 = CFrame.new(0, 0, 0, -0.9971, 0.0022, -0.0762, 0.0485, 0.7895, -0.6118, 0.0589, -0.6138, -0.7873),
			Pieces = {
				{ Name = "ET_B05_1", Rel = CFrame.new(0.3849, 0.0042, -0.2659), Phase = 2.4152, Vol = 1.2529 },
				{ Name = "ET_B05_2", Rel = CFrame.new(-0.0737, 0.3719, -0.4902), Phase = 3.4386, Vol = 0.8452 },
				{ Name = "ET_B05_3", Rel = CFrame.new(-0.5494, 0.0063, -0.0192), Phase = 1.605, Vol = 0.6268 },
				{ Name = "ET_B05_4", Rel = CFrame.new(0.7411, 0.2476, -0.3256), Phase = 3.2789, Vol = 0.3624 },
			} },
		{ TearAt = 0.4146, From = Vector3.new(6.4519, -1.6894, -10.0283), Control = Vector3.new(6.4519, 23.7805, -10.0283), Gather = Vector3.new(5.7464, 21.215, -8.932), GatherSlabY = 10.6131,
			StopAt = Vector3.new(1.726, 2.2094, -2.6822), Dir = Vector3.new(0.4448, 0.5694, -0.6913), REnd = 3.88, Spin = 4.8643, Axis = Vector3.new(0.6473, 0.6832, 0.338), Size = 3.1601, Radius = 1.6894,
			Q0 = CFrame.new(0, 0, 0, -0.5306, 0.8104, -0.2483, -0.567, -0.1217, 0.8147, 0.63, 0.5731, 0.5241),
			Pieces = {
				{ Name = "ET_B06_1", Rel = CFrame.new(-0.4739, 0.324, 0.0138), Phase = 2.1094, Vol = 1.7522 },
				{ Name = "ET_B06_2", Rel = CFrame.new(-0.0265, 0.4088, -0.6189), Phase = 2.5716, Vol = 1.477 },
				{ Name = "ET_B06_3", Rel = CFrame.new(0.6525, -0.4064, -0.1684), Phase = 4.3005, Vol = 1.4106 },
				{ Name = "ET_B06_4", Rel = CFrame.new(0.7411, 0.3907, -0.1299), Phase = 2.4166, Vol = 0.7315 },
			} },
		{ TearAt = 0.493, From = Vector3.new(-1.6094, -1.6333, -12.5832), Control = Vector3.new(-1.6094, 23.3468, -12.5832), Gather = Vector3.new(-1.3371, 21.4348, -10.3955), GatherSlabY = 10.6131,
			StopAt = Vector3.new(-0.5683, 3.3304, -4.5659), Dir = Vector3.new(-0.1001, 0.5863, -0.8039), REnd = 5.68, Spin = 3.8341, Axis = Vector3.new(0.4075, -0.3772, 0.8317), Size = 3.1298, Radius = 1.6333,
			Q0 = CFrame.new(0, 0, 0, 0.9867, 0.1601, 0.0281, -0.1623, 0.9796, 0.1183, -0.0086, -0.1213, 0.9926),
			Pieces = {
				{ Name = "ET_B07_1", Rel = CFrame.new(-0.1678, 0.005, -0.6812), Phase = 8.1639, Vol = 2.0677 },
				{ Name = "ET_B07_2", Rel = CFrame.new(0.0345, -0.0634, 0.5245), Phase = 5.8642, Vol = 1.0009 },
				{ Name = "ET_B07_3", Rel = CFrame.new(-0.754, 0.2045, -0.0263), Phase = 8.9981, Vol = 1.2259 },
				{ Name = "ET_B07_4", Rel = CFrame.new(0.5333, 0.2172, -0.2734), Phase = 7.2142, Vol = 1.0466 },
			} },
		{ TearAt = 0.4029, From = Vector3.new(-12.0327, -1.4448, -7.5291), Control = Vector3.new(-12.0327, 17.7646, -7.5291), Gather = Vector3.new(-10.9149, 15.6468, -6.8224), GatherSlabY = 10.6131,
			StopAt = Vector3.new(-3.6234, 0.611, -2.2906), Dir = Vector3.new(-0.8368, 0.1411, -0.529), REnd = 4.33, Spin = 3.3619, Axis = Vector3.new(-0.6314, -0.704, -0.3251), Size = 2.7727, Radius = 1.4448,
			Q0 = CFrame.new(0, 0, 0, -0.2378, -0.1525, 0.9593, 0.0533, 0.9841, 0.1697, -0.9699, 0.0915, -0.2258),
			Pieces = {
				{ Name = "ET_B08_1", Rel = CFrame.new(0.0275, -0.1201, -0.2428), Phase = 6.9401, Vol = 1.3187 },
				{ Name = "ET_B08_2", Rel = CFrame.new(0.5239, 0.0832, -0.1269), Phase = 5.5832, Vol = 0.6498 },
				{ Name = "ET_B08_3", Rel = CFrame.new(-0.0223, -0.4897, 0.2619), Phase = 7.9216, Vol = 0.5097 },
				{ Name = "ET_B08_4", Rel = CFrame.new(-0.4939, -0.5867, -0.349), Phase = 9.9043, Vol = 0.5619 },
			} },
	},
	Slab = {
		Outline = { Vector2.new(-0.0262, 2.5385), Vector2.new(0.0391, 2.4468), Vector2.new(1.3371, 2.5834), Vector2.new(1.3958, 2.6544), Vector2.new(2.467, 2.2598), Vector2.new(2.3611, 1.6856), Vector2.new(3.2367, 1.0266), Vector2.new(2.8752, 0.0559), Vector2.new(3.0164, -0.1068), Vector2.new(3.0561, -1.4766), Vector2.new(3.1002, -1.537), Vector2.new(2.1922, -2.3548), Vector2.new(1.9214, -2.3278), Vector2.new(1.2171, -3.3178), Vector2.new(0.7008, -2.9445), Vector2.new(-0.2071, -3.2604), Vector2.new(-0.976, -2.4472), Vector2.new(-1.1415, -2.4546), Vector2.new(-1.3601, -2.6269), Vector2.new(-2.3464, -2.4413), Vector2.new(-2.5361, -1.6196), Vector2.new(-3.4705, -1.4162), Vector2.new(-3.4809, -1.1556), Vector2.new(-2.9338, -0.3057), Vector2.new(-3.2327, 0.2829), Vector2.new(-2.7929, 0.9598), Vector2.new(-2.9048, 1.4917), Vector2.new(-1.9268, 2.089), Vector2.new(-1.6307, 2.0607), Vector2.new(-1.2229, 2.6868), Vector2.new(-1.1437, 2.7122) },
		Depth = 3.95, Clod = "ET_SlabClod", Top = "ET_SlabTop", Mouth = "ET_Mouth", Centre = Vector3.new(-0.1425, 0, -0.1374), PitR = 3.1,
		-- in flight it rocks 2.2 deg sin(2.3a + 0.4) about X and 1.6 deg sin(1.7a + 1.9) about Z (kit), eased in over In s
		-- from the tear and out over the descent's first Out s; trembles Tremble studs (freq 7) at the tear and the landing
		Wobble = { X = 0.0384, Z = 0.0279, In = 0.35, Out = 0.42 }, Tremble = 0.03,
		Ring = { A = 0.24, Tau = 0.12, W = 28 },      -- at the burst: y -= A exp(-a/Tau) sin(W a)
		Thud = { A = 0.10, Tau = 0.06, Rise = 0.04 },  -- seated: y = -A exp(-b/Tau) sin(min(b/Rise, 1) pi)
	},
	Ground = {
		Plates = {
			{ Name = "ET_Plate_001", Rel = CFrame.new(-0.3178, 0, 3.5072), Kind = "shove", Dly = 0.0051, H = 0.0983, Tilt = 0.0736, Sh = 0.1663 },
			{ Name = "ET_Plate_002", Rel = CFrame.new(-2.0103, 0, 3.0019), Kind = "shove", Dly = 0.0062, H = 0.4689, Tilt = 0.555, Sh = 0.1975 },
			{ Name = "ET_Plate_003", Rel = CFrame.new(-0.9851, 0, -3.5326), Kind = "shove", Dly = 0.0068, H = 0, Tilt = 0, Sh = 0.0571 },
			{ Name = "ET_Plate_004", Rel = CFrame.new(0.8868, 0, 3.5601), Kind = "shove", Dly = 0.0068, H = 0, Tilt = 0, Sh = 0.0819 },
			{ Name = "ET_Plate_005", Rel = CFrame.new(-3.6933, 0, 0.3607), Kind = "shove", Dly = 0.0073, H = 0.1222, Tilt = 0.1597, Sh = 0.157 },
			{ Name = "ET_Plate_006", Rel = CFrame.new(2.0786, 0, 3.0821), Kind = "shove", Dly = 0.0074, H = 0.0723, Tilt = 0.1574, Sh = 0.1908 },
			{ Name = "ET_Plate_007", Rel = CFrame.new(3.3379, 0, -1.6548), Kind = "shove", Dly = 0.0075, H = 0, Tilt = 0, Sh = 0.0609 },
			{ Name = "ET_Plate_008", Rel = CFrame.new(0.4066, 0, -3.7286), Kind = "shove", Dly = 0.0078, H = 0.0824, Tilt = 0.2077, Sh = 0.1849 },
			{ Name = "ET_Plate_009", Rel = CFrame.new(-2.9687, 0, 2.2965), Kind = "shove", Dly = 0.0078, H = 0.4904, Tilt = 0.6009, Sh = 0.2043 },
			{ Name = "ET_Plate_010", Rel = CFrame.new(-3.0368, 0, -2.2098), Kind = "shove", Dly = 0.0079, H = 0.3741, Tilt = 0.4844, Sh = 0.2645 },
			{ Name = "ET_Plate_011", Rel = CFrame.new(-2.143, 0, -3.1258), Kind = "shove", Dly = 0.0083, H = 0, Tilt = 0, Sh = 0.0476 },
			{ Name = "ET_Plate_012", Rel = CFrame.new(-1.1846, 0, 3.603), Kind = "shove", Dly = 0.0083, H = 0, Tilt = 0, Sh = 0.0613 },
			{ Name = "ET_Plate_013", Rel = CFrame.new(3.7727, 0, 0.4737), Kind = "shove", Dly = 0.0084, H = 0, Tilt = 0, Sh = 0.0569 },
			{ Name = "ET_Plate_014", Rel = CFrame.new(2.0494, 0, -3.2061), Kind = "shove", Dly = 0.0085, H = 0, Tilt = 0, Sh = 0.0726 },
			{ Name = "ET_Plate_015", Rel = CFrame.new(3.2941, 0, 1.9259), Kind = "shove", Dly = 0.0086, H = 0, Tilt = 0, Sh = 0.0501 },
			{ Name = "ET_Plate_016", Rel = CFrame.new(-4.2847, 0, -1.6802), Kind = "shove", Dly = 0.018, H = 0, Tilt = 0, Sh = 0.0234 },
			{ Name = "ET_Plate_017", Rel = CFrame.new(-4.2875, 0, 1.8613), Kind = "shove", Dly = 0.0189, H = 0.1389, Tilt = 0.1714, Sh = 0.073 },
			{ Name = "ET_Plate_018", Rel = CFrame.new(2.7944, 0, 3.804), Kind = "shove", Dly = 0.0194, H = 0.148, Tilt = 0.1729, Sh = 0.0767 },
			{ Name = "ET_Plate_019", Rel = CFrame.new(1.9585, 0, -4.3229), Kind = "shove", Dly = 0.0197, H = 0.0544, Tilt = 0.1473, Sh = 0.1044 },
			{ Name = "ET_Plate_020", Rel = CFrame.new(4.7736, 0, -0.0556), Kind = "shove", Dly = 0.0201, H = 0.3707, Tilt = 0.6452, Sh = 0.1134 },
			{ Name = "ET_Plate_021", Rel = CFrame.new(-2.4343, 0, -4.1245), Kind = "shove", Dly = 0.0203, H = 0.0611, Tilt = 0.1209, Sh = 0.0575 },
			{ Name = "ET_Plate_022", Rel = CFrame.new(-3.5372, 0, -3.2356), Kind = "shove", Dly = 0.0203, H = 0, Tilt = 0, Sh = 0.0308 },
			{ Name = "ET_Plate_023", Rel = CFrame.new(4.5519, 0, 1.5134), Kind = "shove", Dly = 0.0204, H = 0, Tilt = 0, Sh = 0.0302 },
			{ Name = "ET_Plate_024", Rel = CFrame.new(-4.7868, 0, 0.5163), Kind = "shove", Dly = 0.0206, H = 0.3313, Tilt = -0.4035, Sh = 0.107 },
			{ Name = "ET_Plate_025", Rel = CFrame.new(3.7513, 0, 3.0445), Kind = "shove", Dly = 0.0208, H = 0.2945, Tilt = -0.3981, Sh = 0.1046 },
			{ Name = "ET_Plate_026", Rel = CFrame.new(-3.5947, 0, 3.3675), Kind = "shove", Dly = 0.0219, H = 0.0449, Tilt = 0.1172, Sh = 0.0575 },
			{ Name = "ET_Plate_027", Rel = CFrame.new(0.8254, 0, 5.0741), Kind = "rim", T = 0.0706, H = 0.1371, Tr = 0.0922 },
			{ Name = "ET_Plate_028", Rel = CFrame.new(-0.3754, 0, 5.1608), Kind = "rim", T = 0.0711, H = 0.1277, Tr = 0.1219 },
			{ Name = "ET_Plate_029", Rel = CFrame.new(0.4755, 0, -5.1667), Kind = "rim", T = 0.0713, H = 0.0939, Tr = 0.1047 },
			{ Name = "ET_Plate_030", Rel = CFrame.new(-0.9461, 0, -5.1653), Kind = "rim", T = 0.0723, H = 0.1679, Tr = 0.0828 },
			{ Name = "ET_Plate_031", Rel = CFrame.new(5.2112, 0, -0.8043), Kind = "rim", T = 0.0726, H = 0.1818, Tr = 0.097 },
			{ Name = "ET_Plate_032", Rel = CFrame.new(4.5748, 0, -2.7171), Kind = "rim", T = 0.0733, H = 0.173, Tr = 0.0745 },
			{ Name = "ET_Plate_033", Rel = CFrame.new(-1.3657, 0, 5.1794), Kind = "rim", T = 0.0738, H = 0.1432, Tr = 0.1162 },
			{ Name = "ET_Plate_034", Rel = CFrame.new(-2.4761, 0, 4.7963), Kind = "rim", T = 0.0745, H = 0.099, Tr = 0.0875 },
			{ Name = "ET_Plate_035", Rel = CFrame.new(3.238, 0, -4.3405), Kind = "rim", T = 0.0747, H = 0.1812, Tr = 0.052 },
			{ Name = "ET_Plate_036", Rel = CFrame.new(2.9601, 0, 4.8622), Kind = "rim", T = 0.0789, H = 0.1641, Tr = 0.0874 },
			{ Name = "ET_Plate_037", Rel = CFrame.new(5.4423, 0, -1.7176), Kind = "rim", T = 0.0791, H = 0.0853, Tr = 0.0461 },
			{ Name = "ET_Plate_038", Rel = CFrame.new(2.0354, 0, 5.3534), Kind = "rim", T = 0.0794, H = 0.1237, Tr = 0.1164 },
			{ Name = "ET_Plate_039", Rel = CFrame.new(-5.7437, 0, -0.0917), Kind = "rim", T = 0.0797, H = 0.124, Tr = 0.0791 },
			{ Name = "ET_Plate_040", Rel = CFrame.new(-4.701, 0, 3.3116), Kind = "rim", T = 0.0798, H = 0.1411, Tr = 0.0598 },
			{ Name = "ET_Plate_041", Rel = CFrame.new(1.7806, 0, -5.469), Kind = "rim", T = 0.0798, H = 0.1917, Tr = 0.0881 },
			{ Name = "ET_Plate_042", Rel = CFrame.new(-5.3398, 0, 2.1628), Kind = "rim", T = 0.0799, H = 0.1085, Tr = 0.0963 },
			{ Name = "ET_Plate_043", Rel = CFrame.new(5.0592, 0, 2.7633), Kind = "rim", T = 0.08, H = 0.1217, Tr = 0.1182 },
			{ Name = "ET_Plate_044", Rel = CFrame.new(-5.4152, 0, -1.9925), Kind = "rim", T = 0.0801, H = 0.1195, Tr = 0.1065 },
			{ Name = "ET_Plate_045", Rel = CFrame.new(4.2897, 0, -3.8824), Kind = "rim", T = 0.0803, H = 0.1253, Tr = 0.0462 },
			{ Name = "ET_Plate_046", Rel = CFrame.new(-2.4894, 0, -5.231), Kind = "rim", T = 0.0804, H = 0.0875, Tr = 0.1217 },
			{ Name = "ET_Plate_047", Rel = CFrame.new(5.7049, 0, 1.1496), Kind = "rim", T = 0.0808, H = 0.1573, Tr = 0.0936 },
			{ Name = "ET_Plate_048", Rel = CFrame.new(-3.844, 0, -4.3889), Kind = "rim", T = 0.081, H = 0.1631, Tr = 0.0664 },
			{ Name = "ET_Plate_049", Rel = CFrame.new(-3.6294, 0, 4.5968), Kind = "rim", T = 0.0814, H = 0.1001, Tr = 0.1095 },
			{ Name = "ET_Plate_050", Rel = CFrame.new(-4.9322, 0, -3.2396), Kind = "rim", T = 0.082, H = 0.1172, Tr = 0.0477 },
		},
	},
	-- THE BURST (TombBurst): every heap piece flies Dir * U(HeapOut) * (TowardCaster if Dir points within acos(0.8) of
	-- the caster) + up U(HeapUp) + HeapUpPerRing * (Ring - 1) + a random HeapRand; a boulder piece Dir * U(BoulderOut)
	-- + up U(BoulderUp) + BoulderRand; spin U(Spin) rad/s; then G, bouncing Bounce, sliding Friction, at rest by RestAfter
	Burst = { HeapOut = { 10, 16 }, HeapUp = { 4, 12 }, HeapUpPerRing = 1.5, TowardCaster = 0.55, TowardCasterCos = 0.8,
		HeapRand = 1.0, BoulderOut = { 12, 20 }, BoulderUp = { 4, 10 }, BoulderRand = 2.0, Spin = { 4, 10 }, G = 35,
		Bounce = 0.22, Friction = 0.75, RestAfter = 1.2, Scuffs = 12, ScuffSize = { 2.1, 2.7 } },
	Timing = {
		RiseTime = 1.6, RiseHeight = 12, Converge = 0.6, BurstHold = 0.45, DescendTime = 0.8, -- live (TerraFX.Tuning.EarthenTomb)
		EruptAt = 0.02, RingLag = 0.05, Jitter = 0.03, EruptTime = 0.18, Tumble = 0.7, PunchOver = 0.07,
		Sealed = 0.4251, Arrive = -0.1, ConvergeAt = 1, Top = 1.6, Burst = 1.6, BurstDelay = 0.06, BoulderFrom = 13, ChestUp = 3.2,
		HitFlare = 0.6, HitTau = 0.08, -- the slam at Top: boulders and the Struck heap rocks (ChargedRock.AfterHit)
		-- (Burst = the live burst at the top; the showcase's BurstDelay 0.06 and its 4-frame hitpause are out of scope)
	},
	Dust = {
		Grit = "rbxassetid://82803520621527", Scuff = "rbxassetid://102375587925629",
		Colour = Color3.fromRGB(173, 158, 135), Dark = Color3.fromRGB(120, 102, 79), Pale = Color3.fromRGB(194, 173, 140),
		Tear = { Puffs = 16, Grit = 28, Out = { 9, 16 }, Up = { 0.4, 2 }, Life = { 0.7, 1.3 } },
		BoulderTear = { Puffs = 3, Grit = 7 }, Sealed = { Puffs = 3, Grit = 8 },
		Burst = { Dome = 6, Ring = 8, Grit = 50, Splinters = 18, Life = { 0.45, 0.8 } },
		Seat = { Puffs = 12, Grit = 10, Out = { 7, 13 } },
	},
	Pebbles = { "ET_Pebble_01", "ET_Pebble_02", "ET_Pebble_03", "ET_Pebble_04", "ET_Pebble_05", "ET_Pebble_06", "ET_Pebble_07", "ET_Pebble_08" },
	Parts = { Heap = 348, Boulders = 120, Plates = 50, HeapStones = 117, BoulderStones = 32, Slab = 3, Pebble = 8 },
}

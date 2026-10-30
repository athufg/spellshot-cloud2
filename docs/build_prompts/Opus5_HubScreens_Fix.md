<role>
You work for SPELLSHOT's solo owner-developer, building in Roblox Studio. Most of the hub's info screens are dead black panels with just a title — only "Top Duelists" is actually built right (clear header, season tag, and a real explanatory empty state: "No duel results yet / Duel wins show here once they are saved / Leaderboard backend not built yet"). Bring every other screen up to that same bar. Done means no screen in the hub is a blank black panel — each either shows real live data or a properly designed empty state matching Top Duelists' style, and the two wayfinding placards actually function.
</role>

<context>
Two different kinds of screens here, treat them differently:

**Data/leaderboard screens** (Longest Streak, Live Duels, Daily Deals): show real data if the backend for it already exists; if it doesn't (same situation as Top Duelists, which already says its backend isn't built), give it the exact same quality of empty state as Top Duelists — a clear headline message plus one line explaining what will show there and why it's empty now. Don't fake data. Daily Deals is the one exception worth checking first: the Shop already has a real "Today's Drop" / daily featured item system, so pull that in as actual live data rather than defaulting to an empty state.

**Wayfinding placards** (the small "Duels" and "Loadout" signs mounted near doorways/altars, distinct from the big data boards): these aren't data displays, they're in-world buttons. Wire each one so interacting with it opens the same flow as pressing the corresponding Duels/Loadout button in the top-right menu.

All screens must visually match Top Duelists' existing panel style exactly — same frame shape, border, typography, and empty-state tone — so the hub reads as one consistent system instead of some screens being finished and others not.
</context>

<instructions>
1. Build "Longest Streak" using Top Duelists' exact panel component: real data if a streak-tracking system exists, otherwise a matching empty state explaining streaks will appear once tracked.
2. Build "Live Duels" the same way: a real list of currently active duels if that data is reachable, otherwise a matching empty state.
3. Build "Daily Deals" pulling from the Shop's existing daily/featured item data so it shows the actual current deal, not a placeholder.
4. Wire the "Duels" and "Loadout" wayfinding placards as functional interactables that open the same flow as the top-right menu's Duels/Loadout buttons.
5. Match every screen's visual style (frame, border, text treatment) to Top Duelists exactly.
</instructions>

<output_format>
One line before starting. Screenshots of each fixed screen, noting for each one whether it's showing real data or a designed empty state. Confirm both placards are now interactive.
</output_format>

<edge_cases>
If a data source genuinely doesn't exist for Longest Streak or Live Duels, don't build a new backend system for it in this pass — use the matching empty state instead and note it the same way Top Duelists already does.
</edge_cases>

<tone_preference>
Be efficient — minimize exploration, keep the report brief.
</tone_preference>

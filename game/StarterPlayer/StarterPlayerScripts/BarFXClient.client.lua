--[[ BarFXClient (LocalScript) -> StarterPlayer.StarterPlayerScripts.BarFXClient
     Starts the full-bar status looks (ReplicatedStorage.Spellshot.BarFX) for the local player. ]]
local BarFX = require(game:GetService("ReplicatedStorage"):WaitForChild("Spellshot"):WaitForChild("BarFX"))
BarFX.Start()

local classIndices_Internal = {
    [1] = "Scout",
    [3] = "Soldier",
    [7] = "Pyro",
    [4] = "Demoman",
    [6] = "Heavy",
    [9] = "Engineer",
    [5] = "Medic",
    [2] = "Sniper",
    [8] = "Spy",
}

function Set(list)
	local set = {}
	for _, l in ipairs(list) do
		set[l] = true
	end
	return set
end

function OnWaveSpawnBot(bot, wave, tags)
	local tagsList = Set(tags)

	if tagsList["no_zombie"] then
		return
	end

	local props = bot:DumpProperties()

	local className = classIndices_Internal[props.m_iClass]
	local vodooName = "Zombie "..className
	local skin = props.m_iTeamNum == 2 and 4 or 5 -- zombie skin for each team

	bot:AcceptInput("$SetProp$m_bForcedSkin", "1")
	bot:AcceptInput("$SetProp$m_nForcedSkin", tostring(skin))

	bot:GiveItem(vodooName, nil, true, true)
end

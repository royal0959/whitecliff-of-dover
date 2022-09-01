--I am in your walls

local SPAWN_QUOTES = {
	[2] = "Have you blokes watched Groundhog Day (1993)?",
}

local function chatMessage(string)
	local recallText = "{blue}"
	.. "Time-Cosnstraint: "
	.. string
end

local function hasTag(tags, tagToFind)
	for _, tag in pairs(tags) do
		if tag == tagToFind then
			return true
		end
	end
end

local function removeCallbacks(bot, callbacks)
	for _, callbackId in pairs(callbacks) do
		bot:RemoveCallback(callbackId)
	end
end

local rollbacks = {}

local function storeRollback()
	local classes = {"player", "obj_*"}

	for _, class in pairs(classes) do
		for _, ent in pairs(ents.FindAllByClass(class)) do
			if not ent:IsCombatCharacter() then
				goto continue
			end

			rollbacks[ent] = {
				Origin = ent:GetAbsOrigin(),
				Angles = ent:GetAbsAngles()
			}

			::continue::
		end
	end
end

local function revertRollback()
	for ent, data in pairs(rollbacks) do
		if not IsValid(ent) or not ent:IsAlive() then
			goto continue
		end

		ent:SetAbsOrigin(data.Origin)
		ent:SetAbsAngles(data.Angles)

		::continue::
	end
end

local function Handle1(bot)
	local callbacks = {}

	timer.Simple(7, function ()
		storeRollback()
	end)

	callbacks.died = bot:AddCallback(ON_DEATH, function()
		timer.Simple(0.5, function ()
			chatMessage("That's not supposed to happen")
		end)

		timer.Simple(1.3, function ()
			chatMessage("Let's do that again")
		end)

		timer.Simple(1.7, function ()
			revertRollback()
		end)

		removeCallbacks(bot, callbacks)
	end)
end

function OnWaveSpawnBot(bot, _, tags)
	if hasTag(tags, "T_TFBot_Timeconstraint_1") then
		Handle1(bot)
		return
	end
end
local CRIT_CONDS  = {11, 34, 40, 44, 56, 105}
local MINI_CRIT_CONDS  = {11, 34, 40, 44, 56, 105}

local callbacks = {}
local botTypesData = {}

local CUSTOM_BOTTYPES_INDICES = { "Undying" }
for _, botTypeIndex in pairs(CUSTOM_BOTTYPES_INDICES) do
	callbacks[botTypeIndex] = {}
	botTypesData[botTypeIndex] = {}
end

function ClearCallbacks(index, activator)
	local handle = activator:GetHandleIndex()

	local botTypeCallbacks = callbacks[index][handle]

	if not botTypeCallbacks then
		return
	end

	for _, callbackData in pairs(botTypeCallbacks) do
		activator:RemoveCallback(callbackData.Type, callbackData.ID)
	end

	callbacks[index][handle] = nil
end

function ClearData(index, activator)
	local handle = activator:GetHandleIndex()

	local botTypeData = botTypesData[index][handle]

	if not botTypeData then
		return
	end

	botTypesData[index][handle] = nil
end

-- teleport back to spawn instead of dying
function UndyingActivate(rechargeTime, activator)
	activator:AcceptInput("$TeleportToEntity", "spawnbot")

	local handle = activator:GetHandleIndex()

	botTypesData.Undying[handle].Recharging = true

	activator:ChangeAttributes("Recharging")
	activator:SetAttributeValue("health regen", botTypesData.Undying[handle].MaxHealth / rechargeTime)

	local allPlayers = ents.GetAllPlayers()

	for _, player in pairs(allPlayers) do
		player:AcceptInput(
			"$DisplayTextChat",
			"{blue}Undying Runner{reset} has used their {9BBF4D}RECALL{reset} Power Up Canteen!"
		)
		player:AcceptInput("$PlaySoundToSelf", "=35|mvm/mvm_used_powerup.wav")
	end

	local undyingFirstDeathSpawn = ents.FindByName("undying_first_death")
	undyingFirstDeathSpawn:AcceptInput("Enable")

	timer.Simple(rechargeTime + 1.1, function()
		activator:SetAttributeValue("health regen", 0)
		activator:ChangeAttributes("Default")
		botTypesData.Undying[handle].Recharging = false
	end)
end

function UndyingSpawn(rechargeTime, activator)
	rechargeTime = tonumber(rechargeTime)

	local handle = activator:GetHandleIndex()

	if callbacks.Undying[handle] then
		ParryAddictionUnequip(_, activator)
	end

	botTypesData.Undying[handle] = { MaxHealth = activator.m_iHealth, Recharging = false }

	callbacks.Undying[handle] = {}

	local undyingCallbacks = callbacks.Undying[handle]

	-- on damage
	undyingCallbacks.onDamagePre = {
		Type = 3,
		ID = activator:AddCallback(3, function(_, damageInfo)
			if botTypesData.Undying[handle].Recharging then
				return
			end

			local curHealth = activator.m_iHealth

			-- can't detect crit damage, assume all damage are crit instead for fatal check
			local damage = damageInfo.Damage * 3

			if curHealth - (damage + 1) <= 0 then
				damageInfo.Damage = 0
				damageInfo.DamageType = DMG_GENERIC
				damageInfo.CritType = 0

				UndyingActivate(rechargeTime, activator)

				-- set health to 1
				local setHealthDmgInfo = {
					Attacker = damageInfo.Attacker,
					Inflictor = damageInfo.Inflictor,
					Weapon = damageInfo.Weapon,
					Damage = curHealth - 1,
					CritType = 0,
					DamageType = damageInfo.DamageType,
					DamageCustom = damageInfo.DamageCustom,
					DamagePosition = damageInfo.DamagePosition,
					DamageForce = damageInfo.DamageForce,
					ReportedPosition = damageInfo.ReportedPosition,
				}

				activator:TakeDamage(setHealthDmgInfo)

				return true
			end

			return true
		end),
	}

	undyingCallbacks.onDeath = {
		Type = 9,
		ID = activator:AddCallback(9, function()
			UndyingEnd(activator)
		end),
	}

	undyingCallbacks.onSpawn = {
		Type = 1,
		ID = activator:AddCallback(1, function()
			UndyingEnd(activator)
		end),
	}
end

function UndyingEnd(activator)
	ClearCallbacks("Undying", activator)
	ClearData("Undying", activator)
end

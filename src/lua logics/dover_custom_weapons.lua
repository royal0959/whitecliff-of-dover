local REDEEMER_HIT_DEBOUNCE = 10
local REDEEMER_HIT_DAMAGE = 40
local REDEEMER_HIT_DAMAGE_ADDITION = 10 -- increased each hit
local REDEEMER_HIT_DAMAGE_ADDITION_CAP = 50

local PARRY_TIME = 0.8

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

local callbacks = {}
local weaponsData = {}

local CUSTOM_WEAPONS_INDICES = { "Parry" }
for _, weaponIndex in pairs(CUSTOM_WEAPONS_INDICES) do
	callbacks[weaponIndex] = {}
	weaponsData[weaponIndex] = {}
end

function ClearCallbacks(index, activator, handle)
	handle = handle or activator:GetHandleIndex()

	local weaponCallbacks = callbacks[index][handle]

	if not weaponCallbacks then
		return
	end

	if activator then
		for _, callbackData in pairs(weaponCallbacks) do
			activator:RemoveCallback(callbackData.Type, callbackData.ID)
		end
	end

	callbacks[index][handle] = nil
end

function ClearData(index, activator)
	local handle = activator:GetHandleIndex()

	local weaponData = weaponsData[index][handle]

	if not weaponData then
		return
	end

	weaponsData[index][handle] = nil
end

local redeemerDebounces = {} --value is debounce players

ents.AddCreateCallback("tf_projectile_rocket", function(entity)
	timer.Simple(0.01, function()
		local owner = entity.m_hOwnerEntity

		if not owner then
			return
		end

		--TODO: check if switching class from scout with redeemer to soldier still pass the check
		local props = owner:DumpProperties()

		if not props.hasRedeemer or props.hasRedeemer ~= 1 then
			return
		end

		-- not scout, just in case
		if owner.m_iClass ~= 1 then
			return
		end

		local extraDamage = 0

		local handle = entity:GetHandleIndex()

		redeemerDebounces[handle] = {}

		entity:AddCallback(0, function()
			redeemerDebounces[handle] = nil
		end)

		entity:AddCallback(16, function(_, target)
			if not target or not target:IsPlayer() then
				return true
			end

			local targetHandle = target:GetHandleIndex()

			local nextAllowedDamageTickOnTarget = redeemerDebounces[handle][targetHandle] or -1

			if CurTime() < nextAllowedDamageTickOnTarget then
				return false
			end

			local targetTeamnum = target._iTeamNum

			if targetTeamnum == owner.m_iTeamNum then
				return false
			end

			redeemerDebounces[handle][targetHandle] = CurTime() + REDEEMER_HIT_DEBOUNCE

			local secondary = owner:GetPlayerItemBySlot(1)

			local baseDamage = REDEEMER_HIT_DAMAGE
			local damageMult = secondary:GetAttributeValue("damage bonus") or 1

			local visualHitPost = target:GetAbsOrigin() + Vector(0, 0, 50)

			local damageInfo = {
				Attacker = owner,
				Inflictor = nil,
				Weapon = nil,
				Damage = baseDamage * damageMult + extraDamage,
				DamageType = DMG_SHOCK,
				DamageCustom = 0,
				DamagePosition = visualHitPost,
				DamageForce = Vector(0, 0, 0),
				ReportedPosition = visualHitPost
			}

			local dmg = target:TakeDamage(damageInfo)

			extraDamage = extraDamage + REDEEMER_HIT_DAMAGE_ADDITION

			if extraDamage > REDEEMER_HIT_DAMAGE_ADDITION_CAP then
				extraDamage = REDEEMER_HIT_DAMAGE_ADDITION_CAP
			end

			return false
		end)
	end)
end)

local function _parry(activator)
	local handle = activator:GetHandleIndex()

	weaponsData.Parry[handle] = true

	timer.Simple(PARRY_TIME, function()
		weaponsData.Parry[handle] = nil
	end)
end

function ParryAddictionEquip(_, activator)
	-- fix weird quirk with template being spawned after you switch to a different class
	if classIndices_Internal[activator:DumpProperties().m_iClass] ~= "Demoman" then
		return
	end

	print("parry addiction equipped")
	local handle = activator:GetHandleIndex()

	if callbacks.Parry[handle] then
		ParryAddictionUnequip(_, activator)
	end

	callbacks.Parry[handle] = {}

	local parryCallbacks = callbacks.Parry[handle]

	-- on key press
	parryCallbacks.keyPress = {
		Type = 7,
		ID = activator:AddCallback(7, function(_, key)
			if key ~= IN_ATTACK2 then
				return
			end

			local props = activator:DumpProperties()

			if props.m_flChargeMeter < 100 then
				return
			end

			if weaponsData.Parry[handle] then
				activator:AcceptInput("$SetProp$m_flChargeMeter", "0")
				return
			end

			activator:AddCond(46, PARRY_TIME)

			activator:AcceptInput("$SetProp$m_flChargeMeter", "0")

			_parry(activator)
		end),
	}

	-- on damage
	parryCallbacks.onDamagePre = {
		Type = 3,
		ID = activator:AddCallback(3, function(_, damageInfo)
			if not weaponsData.Parry[handle] then
				return
			end

			if damageInfo.Attacker == activator then
				return
			end

			local deflectDmg = damageInfo.Damage * 2

			local deflectDmgInfo = {
				Attacker = activator,
				Inflictor = nil,
				Weapon = nil,
				Damage = deflectDmg,
				DamageType = 0,
				DamageCustom = 0,
				DamagePosition = Vector(0, 0, 0),
				DamageForce = Vector(0, 0, 0),
				ReportedPosition = Vector(0, 0, 0),
			}

			-- negate damage
			damageInfo.Damage = 0

			-- deflect
			damageInfo.Attacker:TakeDamage(deflectDmgInfo)

			return true
		end),
	}

	parryCallbacks.onDeath = {
		Type = 9,
		ID = activator:AddCallback(9, function()
			ParryAddictionUnequip(_, activator)
		end),
	}

	parryCallbacks.onSpawn = {
		Type = 1,
		ID = activator:AddCallback(1, function()
			ParryAddictionUnequip(_, activator)
		end),
	}
end

function ParryAddictionUnequip(_, activator)
	ClearCallbacks("Parry", activator)
	ClearData("Parry", activator)
end

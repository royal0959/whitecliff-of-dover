local REDEEMER_HIT_DEBOUNCE = 10
local REDEEMER_HIT_DAMAGE = 50
-- local REDEEMER_HIT_DAMAGE_ADDITION = 10 -- increased each hit
-- local REDEEMER_HIT_DAMAGE_ADDITION_CAP = 50

local REDEEMER_HIT_DAMAGE_ADDITION_MULT_ADDITIVE = 1 -- increased each hit
local REDEEMER_HIT_DAMAGE_ADDITION_CAP_ADDITIVE = 10

local DRONES_CAP = 2

local PHD_THRESHOLD = {
	["Small"] = -100,
	["Medium"] = 1,
	["Medium2"] = 1.7,
	["Large"] = 2.3,
	["Nuke"] = 4,
}

local PHD_EXPLOSIONS = {
	["Small"] = { Particle = "hammer_impact_button", Radius = 144, Damage = 25 },
	["Medium"] = { Particle = "ExplosionCore_buildings", Radius = 144, Damage = 50 },
	["Medium2"] = { Particle = "ExplosionCore_Wall", Radius = 144, Damage = 100 },
	["Large"] = { Particle = "asplode_hoodoo", Radius = 200, Damage = 150 },
	["Nuke"] = { Particle = "skull_island_explosion", Radius = 600, Damage = 350 },
}

local PARRY_TIME = 0.8

local SCAVENGER_EXPLOSION_BASE_DAMAGE = 175

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

local function findInTable(table, value)
	for i, v in pairs(table) do
		if v == value then
			return i
		end
	end
end

local function dictionaryLength(dictionary)
	local length = 0

	for i, _ in pairs(dictionary) do
		length = length + 1
	end

	return length
end

local callbacks = {}
local weaponsData = {}
local weaponTimers = {}

local CUSTOM_WEAPONS_INDICES = { "Parry", "Drone", "PHD" }
for _, weaponIndex in pairs(CUSTOM_WEAPONS_INDICES) do
	callbacks[weaponIndex] = {}
	weaponsData[weaponIndex] = {}
	weaponTimers[weaponIndex] = {}
end

function ClearCallbacks(index, activator, handle)
	handle = handle or activator:GetHandleIndex()

	local weaponCallbacks = callbacks[index][handle]

	if not weaponCallbacks then
		return
	end

	if activator and IsValid(activator) then
		for _, callbackId in pairs(weaponCallbacks) do
			activator:RemoveCallback(callbackId)
		end
	end

	callbacks[index][handle] = nil
end

function ClearData(index, activator, handle)
	handle = handle or activator:GetHandleIndex()

	local weaponData = weaponsData[index][handle]

	if not weaponData then
		return
	end

	weaponsData[index][handle] = nil
end

function ClearTimers(index, activator, handle)
	handle = handle or activator:GetHandleIndex()

	local weaponTimer = weaponTimers[index][handle]

	if not weaponTimer then
		return
	end

	for _, timerId in pairs(weaponTimer) do
		timer.Stop(timerId)
	end

	weaponTimers[index][handle] = nil
end

local noReprogram = {}
function OnWaveSpawnBot(bot, _, tags)
	noReprogram[bot] = nil

	if not findInTable(tags, "no_reprogram") then
		return
	end

	noReprogram[bot] = true
end

local controlled = {}
function SeducerHit(_, activator, caller)
	if noReprogram[caller] then
		return
	end

	if not caller:IsPlayer() then
		return
	end

	if caller.m_bIsMiniBoss ~= 0 then
		return
	end

	if caller:InCond(TF_COND_INVULNERABLE_HIDE_UNLESS_DAMAGED) ~= 0 then
		return
	end

	if caller.m_iTeamNum == activator.m_iTeamNum then
		return
	end

	local handle = activator:GetHandleIndex()

	if controlled[handle] then
		return
	end

	controlled[handle] = caller

	caller:AddCond(TF_COND_REPROGRAMMED)
	caller:AddCond(TF_COND_CRITBOOSTED_CARD_EFFECT)

	timer.Simple(8, function ()
		controlled[handle] = nil
		caller:Suicide()
	end)
end

local redeemerDebounces = {} --value is debounce players

-- redeemer
ents.AddCreateCallback("tf_projectile_rocket", function(entity)
	timer.Simple(0.01, function()
		if not IsValid(entity) then
			return
		end

		local owner = entity.m_hOwnerEntity

		if not owner then
			return
		end

		if not owner.hasRedeemer or owner.hasRedeemer ~= 1 then
			return
		end

		-- not scout, just in case
		if owner.m_iClass ~= 1 then
			return
		end

		local extraDamageMult = 1

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
				Damage = baseDamage * damageMult * extraDamageMult,
				DamageType = DMG_SHOCK,
				DamageCustom = 0,
				DamagePosition = visualHitPost,
				DamageForce = Vector(0, 0, 0),
				ReportedPosition = visualHitPost,
			}

			local dmg = target:TakeDamage(damageInfo)

			extraDamageMult = extraDamageMult + REDEEMER_HIT_DAMAGE_ADDITION_MULT_ADDITIVE

			if extraDamageMult > REDEEMER_HIT_DAMAGE_ADDITION_CAP_ADDITIVE then
				extraDamageMult = REDEEMER_HIT_DAMAGE_ADDITION_CAP_ADDITIVE
			end

			return false
		end)
	end)
end)

function SetScavengerMimicDamage(mimicName, projectile)
	if not IsValid(projectile) then
		return
	end

	local mimic = ents.FindByName(mimicName)

	local owner = mimic.m_hOwnerEntity
	local primary = owner:GetPlayerItemBySlot(0)

	local damageMult = primary:GetAttributeValue("damage bonus") or 1

	print(damageMult)

	mimic.Damage = SCAVENGER_EXPLOSION_BASE_DAMAGE * damageMult
end

-- drone
function DroneFired(sentryName, projectile)
	local owner = projectile.m_hOwnerEntity

	local sentryEnt = ents.FindByName(sentryName)

	sentryEnt.m_hBuilder = owner

	local ownerHandle = owner:GetHandleIndex()

	local dronesData = weaponsData.Drone[ownerHandle]

	local dronesList = dronesData.DronesList

	if dictionaryLength(dronesList) >= dronesData.DronesCap then
		-- remove first drone
		-- automatically cleared from array
		dronesList[1]:Remove()
	end

	table.insert(dronesList, projectile)

	projectile:AddCallback(ON_REMOVE, function()
		if IsValid(sentryEnt) then
			util.ParticleEffect("ExplosionCore_buildings", sentryEnt:GetAbsOrigin(), Vector(0, 0, 0))
			sentryEnt:Remove()
		end

		table.remove(dronesList, findInTable(dronesList, projectile))

		local stationaryId = dronesData.DronesStationaryIds[projectile]

		if stationaryId then
			timer.Stop(stationaryId)
			dronesData.DronesStationaryIds[projectile] = nil
		end
	end)
end

function DroneWalkerEquip(_, activator)
	-- fix weird quirk with template being spawned after you switch to a different class
	if classIndices_Internal[activator.m_iClass] ~= "Engineer" then
		return
	end

	print("drone walker equipped")
	local handle = activator:GetHandleIndex()

	if callbacks.Drone[handle] then
		DroneWalkerUnequip(activator, handle)
	end

	local meleeWeapon = activator:GetPlayerItemBySlot(2)
	local gunslingerEquipped = meleeWeapon.m_iClassname == "tf_weapon_robot_arm"

	local primary = activator:GetPlayerItemBySlot(0)

	if gunslingerEquipped then
		primary:SetAttributeValue("always crit", 1)
		-- primary:SetAttributeValue("engy sentry damage bonus", 1.25)
	else
		primary:SetAttributeValue("always crit", nil)
		-- primary:SetAttributeValue("engy sentry damage bonus", nil)
	end

	callbacks.Drone[handle] = {}
	weaponsData.Drone[handle] = {
		DronesList = {},

		DronesStationaryIds = {},

		DronesCap = not gunslingerEquipped and DRONES_CAP or DRONES_CAP + 1,

		Buffed = gunslingerEquipped,
	}

	local droneCallbacks = callbacks.Drone[handle]
	local dronesData = weaponsData.Drone[handle]

	-- on key press
	droneCallbacks.keyPress = activator:AddCallback(ON_KEY_PRESSED, function(_, key)
		if key ~= IN_ATTACK2 then
			return
		end

		if activator.m_hActiveWeapon.m_iClassname ~= "tf_weapon_shotgun_building_rescue" then
			return
		end

		if dictionaryLength(dronesData.DronesStationaryIds) > 0 then
			for projectile, id in pairs(dronesData.DronesStationaryIds) do
				timer.Stop(id)
				dronesData.DronesStationaryIds[projectile] = nil
			end

			return
		end

		for _, projectile in pairs(dronesData.DronesList) do
			local origin = projectile:GetAbsOrigin()

			projectile:SetLocalVelocity(Vector(0, 0, 0))

			dronesData.DronesStationaryIds[projectile] = timer.Create(0, function()
				projectile:SetAbsOrigin(origin)
			end, 0)
		end
	end)

	droneCallbacks.onRemoved = activator:AddCallback(ON_REMOVE, function()
		DroneWalkerUnequip(activator, handle)
	end)

	droneCallbacks.onDeath = activator:AddCallback(ON_DEATH, function()
		DroneWalkerUnequip(activator, handle)
	end)

	droneCallbacks.onSpawn = activator:AddCallback(ON_SPAWN, function()
		DroneWalkerUnequip(activator, handle)
	end)
end

function DroneWalkerUnequip(activator, handle)
	if not IsValid(activator) then
		activator = nil
	end

	ClearCallbacks("Drone", activator, handle)
	ClearData("Drone", activator, handle)
end

local function _parry(activator)
	local handle = activator:GetHandleIndex()

	weaponsData.Parry[handle] = true

	timer.Simple(PARRY_TIME, function()
		weaponsData.Parry[handle] = nil
	end)
end

function PHDEquip(_, activator)
	-- fix weird quirk with template being spawned after you switch to a different class
	if classIndices_Internal[activator.m_iClass] ~= "Soldier" then
		return
	end

	print("phd jumper equipped")
	local handle = activator:GetHandleIndex()

	if callbacks.PHD[handle] then
		PHDUnequip(activator, handle)
	end

	callbacks.PHD[handle] = {}
	weaponTimers.PHD[handle] = {}
	weaponsData.PHD[handle] = {
		JumpStartTime = false,
	}

	local phdCallbacks = callbacks.PHD[handle]
	local phdTimers = weaponTimers.PHD[handle]
	local phdData = weaponsData.PHD[handle]

	phdCallbacks.removed = activator:AddCallback(ON_REMOVE, function()
		PHDUnequip(activator, handle)
	end)

	phdCallbacks.died = activator:AddCallback(ON_DEATH, function()
		PHDUnequip(activator, handle)
	end)

	phdCallbacks.spawned = activator:AddCallback(ON_SPAWN, function()
		PHDUnequip(activator, handle)
	end)

	local timeSpentParachuting = 0

	phdTimers.rocketJumpCheck = timer.Create(0.1, function()

		local jumping = activator:InCond(TF_COND_BLASTJUMPING)

		if jumping == 0 then
			if phdData.JumpStartTime then
				local timeDiff = CurTime() - phdData.JumpStartTime - timeSpentParachuting
				print(timeDiff, timeSpentParachuting)

				timeSpentParachuting = 0

				local currentThreshold = { nil, -10000 }

				for thresHoldName, timeRequired in pairs(PHD_THRESHOLD) do
					if timeRequired > currentThreshold[2] and timeDiff > timeRequired then
						currentThreshold = { thresHoldName, timeRequired }
					end
				end

				local chosenThreshold = currentThreshold[1]
				print(chosenThreshold)

				local activatorOrigin = activator:GetAbsOrigin()

				local explosionData = PHD_EXPLOSIONS[chosenThreshold]

				util.ParticleEffect(explosionData.Particle, activatorOrigin, Vector(0, 0, 0))
				local radius = explosionData.Radius
				local damage = explosionData.Damage

				local enemiesInRange = ents.FindInSphere(activatorOrigin, radius) --ents.GetAllPlayers()

				local primary = activator:GetPlayerItemBySlot(0)

				local damageMult = primary:GetAttributeValue("damage bonus") or 1

				for _, enemy in pairs(enemiesInRange) do
					if not enemy:IsPlayer() then
						goto continue
					end

					if enemy.m_iTeamNum == activator.m_iTeamNum then
						goto continue
					end

					local damageInfo = {
						Attacker = activator,
						Inflictor = nil,
						Weapon = primary,
						Damage = damage * damageMult,
						DamageType = DMG_BLAST,
						DamageCustom = TF_DMG_CUSTOM_NONE,
						DamagePosition = enemy:GetAbsOrigin(), -- Where the target was hit at
						DamageForce = Vector(0, 0, 0), -- Knockback force of the attack
						ReportedPosition = activatorOrigin, -- Where the attacker attacked from
					}

					enemy:TakeDamage(damageInfo)

					::continue::
				end

				print("kaboom")

				phdData.JumpStartTime = false
			end

			return
		end

		local parachuting = activator:InCond(TF_COND_PARACHUTE_ACTIVE)

		if parachuting ~= 0 then
			timeSpentParachuting = timeSpentParachuting + 0.1
		end

		if phdData.JumpStartTime then
			return
		end

		phdData.JumpStartTime = CurTime()
	end, 0)
end

function PHDUnequip(activator, handle)
	if not IsValid(activator) then
		activator = nil
	end

	ClearCallbacks("PHD", activator, handle)
	ClearData("PHD", activator, handle)
	ClearTimers("PHD", activator, handle)
end

function ParryAddictionEquip(_, activator)
	-- fix weird quirk with template being spawned after you switch to a different class
	if classIndices_Internal[activator:DumpProperties().m_iClass] ~= "Demoman" then
		return
	end

	print("parry addiction equipped")
	local handle = activator:GetHandleIndex()

	if callbacks.Parry[handle] then
		ParryAddictionUnequip(activator, handle)
	end

	callbacks.Parry[handle] = {}

	local parryCallbacks = callbacks.Parry[handle]

	-- on key press
	parryCallbacks.keyPress = activator:AddCallback(7, function(_, key)
		if key ~= IN_ATTACK2 then
			return
		end

		if activator.m_flChargeMeter < 100 then
			return
		end

		if weaponsData.Parry[handle] then
			activator.m_flChargeMeter = 0
			-- activator:AcceptInput("$SetProp$m_flChargeMeter", "0")
			return
		end

		activator:AddCond(46, PARRY_TIME)

		activator.m_flChargeMeter = 0
		-- activator:AcceptInput("$SetProp$m_flChargeMeter", "0")

		_parry(activator)
	end)

	-- on damage
	parryCallbacks.onDamagePre = activator:AddCallback(3, function(_, damageInfo)
		if not weaponsData.Parry[handle] then
			return
		end

		if not damageInfo.Attacker then
			-- negate damage, don't try deflecting
			damageInfo.Damage = 0
			return true
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
	end)

	parryCallbacks.onRemoved = activator:AddCallback(ON_REMOVE, function()
		ParryAddictionUnequip(activator, handle)
	end)

	parryCallbacks.onDeath = activator:AddCallback(9, function()
		ParryAddictionUnequip(activator, handle)
	end)

	parryCallbacks.onSpawn = activator:AddCallback(1, function()
		ParryAddictionUnequip(activator, handle)
	end)
end

function ParryAddictionUnequip(activator, handle)
	if not IsValid(activator) then
		activator = nil
	end

	ClearCallbacks("Parry", activator, handle)
	ClearData("Parry", activator, handle)
end

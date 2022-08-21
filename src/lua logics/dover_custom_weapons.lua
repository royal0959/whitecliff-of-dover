local REDEEMER_HIT_DEBOUNCE = 10
local REDEEMER_HIT_DAMAGE = 40
local REDEEMER_HIT_DAMAGE_ADDITION = 10 -- increased each hit
local REDEEMER_HIT_DAMAGE_ADDITION_CAP = 50

local DRONES_CAP = 2

local PHD_THRESHOLD = {
	["Small"] = -1,
	["Medium"] = 1,
	["Medium2"] = 1.4,
	["Large"] = 2.2,
	["Nuke"] = 3.5,
}

local PHD_EXPLOSIONS = {
	["Small"] = {Particle = "hammer_impact_button", Radius = 300, Damage = 75},
	["Medium"] = {Particle = "ExplosionCore_buildings", Radius = 300, Damage = 125},
	["Medium2"] = {Particle = "ExplosionCore_Wall", Radius = 300, Damage = 175},
	["Large"] = {Particle = "asplode_hoodoo", Radius = 400, Damage = 250},
	["Nuke"] = {Particle = "skull_island_explosion", Radius = 800, Damage = 700}
}

local PARRY_TIME = 0.8

local SCAVENGER_EXPLOSION_BASE_DAMAGE = 300 -- actual damage is half of this

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

	if activator then
		for _, callbackData in pairs(weaponCallbacks) do
			activator:RemoveCallback(callbackData.ID)
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

function ClearTimers(index, activator, handle)
	handle = handle or activator:GetHandleIndex()

	local weaponTimer = weaponTimers[index][handle]

	if not weaponTimer then
		return
	end

	if activator then
		for _, timerId in pairs(weaponTimer) do
			timer.Stop(timerId)
		end
	end

	weaponTimers[index][handle] = nil
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
				ReportedPosition = visualHitPost,
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
	if classIndices_Internal[activator:DumpProperties().m_iClass] ~= "Engineer" then
		return
	end

	print("drone walker equipped")
	local handle = activator:GetHandleIndex()

	if callbacks.Drone[handle] then
		DroneWalkerUnequip(_, activator)
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
	droneCallbacks.keyPress = {
		Type = 7,
		ID = activator:AddCallback(7, function(_, key)
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
		end),
	}
end

function DroneWalkerUnequip(_, activator)
	ClearCallbacks("Drone", activator)
	ClearData("Drone", activator)
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
	if classIndices_Internal[activator:DumpProperties().m_iClass] ~= "Soldier" then
		return
	end

	print("phd jumper equipped")
	local handle = activator:GetHandleIndex()

	if callbacks.PHD[handle] then
		PHDUnequip(_, activator)
	end

	callbacks.PHD[handle] = {}
	weaponTimers.PHD[handle] = {}
	weaponsData.PHD[handle] = {
		JumpStartTime = false,
	}

	local phdCallbacks = callbacks.PHD[handle]
	local phdTimers = callbacks.PHD[handle]
	local phdData = weaponsData.PHD[handle]

	phdTimers.rocketJumpCheck = timer.Create(0.1, function()
		local jumping = activator:InCond(TF_COND_BLASTJUMPING)

		if jumping == 0 then
			if phdData.JumpStartTime then
				print("here")
				local timeDiff = CurTime() - phdData.JumpStartTime

				print(timeDiff)
				local currentThreshold = {nil, -1}
				
				for thresHoldName, timeRequired in pairs(PHD_THRESHOLD) do
					if timeRequired < currentThreshold[2] then
						goto continue
					end

					if timeDiff < timeRequired then
						goto continue
					end

					currentThreshold = {thresHoldName, timeRequired}
					
					::continue::
				end

				local chosenThreshold = currentThreshold[1]
				print(chosenThreshold)

				local activatorOrigin = activator:GetAbsOrigin()

				-- if chosenThreshold == "Small" then
				-- 	util.ParticleEffect("hammer_impact_button", activatorOrigin, Vector(0, 0, 0))
				-- 	radius = 300
				-- 	damage = 75
				-- elseif chosenThreshold == "Medium" then
				-- 	util.ParticleEffect("ExplosionCore_buildings", activatorOrigin, Vector(0, 0, 0))
				-- 	radius = 300
				-- 	damage = 125
				-- elseif chosenThreshold == "Medium2" then
				-- 	util.ParticleEffect("ExplosionCore_Wall", activatorOrigin, Vector(0, 0, 0))
				-- 	radius = 300
				-- 	damage = 175
				-- elseif chosenThreshold == "Large" then
				-- 	util.ParticleEffect("asplode_hoodoo", activatorOrigin, Vector(0, 0, 0))
				-- 	radius = 400
				-- 	damage = 250
				-- elseif chosenThreshold == "Nuke" then
				-- 	util.ParticleEffect("skull_island_explosion", activatorOrigin, Vector(0, 0, 0))
				-- 	radius = 800
				-- 	damage = 700
				-- end

				local explosionData = PHD_EXPLOSIONS[chosenThreshold]
				
				util.ParticleEffect(explosionData.Particle, activatorOrigin, Vector(0, 0, 0))
				local radius = explosionData.Radius
				local damage = explosionData.Damage

				local enemiesInRange = ents.GetAllPlayers() --ents.FindAllInSphere(activatorOrigin, radius)

				local primary = activator:GetPlayerItemBySlot(0)

				local damageMult = primary:GetAttributeValue("damage bonus") or 1

				for _, enemy in pairs(enemiesInRange) do
					-- if not enemy:IsPlayer() then
					-- 	goto continue
					-- end

					if enemy.m_iTeamNum == activator.m_iTeamNum then
						goto continue
					end

					local distance = activatorOrigin:Distance(enemy:GetAbsOrigin())

					if tonumber(distance) < radius then
						local damageInfo = {
							Attacker = activator,
							Inflictor = nil,
							Weapon = primary,
							Damage = damage * damageMult,
							DamageType = DMG_BLAST,
							DamageCustom = TF_DMG_CUSTOM_NONE,
							DamagePosition = enemy:GetAbsOrigin(), -- Where the target was hit at
							DamageForce = Vector(0,0,0), -- Knockback force of the attack
							ReportedPosition = activatorOrigin -- Where the attacker attacked from
						}
					
						enemy:TakeDamage(damageInfo)
	
					end
					::continue::
				end

				print("kaboom")


				phdData.JumpStartTime = false
			end

			return
		end

		if phdData.JumpStartTime then
			return
		end

		phdData.JumpStartTime = CurTime()
	end, 0)
end

function PHDUnequip(_, activator)
	ClearCallbacks("PHD", activator)
	ClearData("PHD", activator)
	ClearTimers("PHD", activator)
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

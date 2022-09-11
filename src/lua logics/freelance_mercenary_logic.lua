local SWITCH_COOLDOWN = 5

local classIndices = {
	[1] = "Scout",
	[2] = "Soldier",
	[3] = "Pyro",
	[4] = "Demoman",
	[5] = "Heavyweapons",
	[6] = "Engineer",
	[7] = "Medic",
	[8] = "Sniper",
	[9] = "Spy",
}

local classIndices_Internal = {
	[1] = "Scout",
	[3] = "Soldier",
	[7] = "Pyro",
	[4] = "Demoman",
	[6] = "Heavyweapons",
	[9] = "Engineer",
	[5] = "Medic",
	[2] = "Sniper",
	[8] = "Spy",
}

local cooldowns = {}

function FreelanceMerc_PromptMenu(currentClass, activator, caller)
	local menu = {
		timeout = 0,
		title = "Classes",
		itemsPerPage = 10,
		---@diagnostic disable-next-line: undefined-global
		flags = MENUFLAG_BUTTON_EXIT,
		onSelect = function(player, index)
			if not player:IsAlive() then
				return
			end
			
			local handleIndex = player:GetHandleIndex()

			if cooldowns[handleIndex] then
				--display text center
				player:Print(2, "Freelance Mercenary switch on cooldown")
				return
			end

			player:SwitchClassInPlace(classIndices[index])
			player:HideMenu()

			cooldowns[handleIndex] = true

			---@diagnostic disable-next-line: undefined-global
			timer.Simple(SWITCH_COOLDOWN, function()
				cooldowns[handleIndex] = nil
			end)
		end,
		onCancel = nil,
	}

	for index, className in pairs(classIndices) do
		menu[index] = { text = className, value = index, disabled = classIndices_Internal[currentClass] == className }
	end

	activator:DisplayMenu(menu)
end

run(function()
	TrapDisabler = vape.Categories.Utility:CreateModule({
		Name = 'AntiTrap',
		Tooltip = 'stops traps that rely on ur client reporting them'
	})

	TrapSnap = TrapDisabler:CreateToggle({
		Name = 'Snap traps',
		Default = true,
		Tooltip = 'stops snap traps from freezing u'
	})

	TrapMine = TrapDisabler:CreateToggle({
		Name = 'Landmines',
		Default = true,
		Tooltip = 'stops invisible landmines from going off on u'
	})

	TrapTeleport = TrapDisabler:CreateToggle({
		Name = 'Teleport blocks',
		Default = true,
		Tooltip = 'stops teleport blocks from moving u'
	})

	TrapPortal = TrapDisabler:CreateToggle({
		Name = 'Void portals',
		Default = true,
		Tooltip = 'stops void portals from moving u, also blocks ur own'
	})
end)
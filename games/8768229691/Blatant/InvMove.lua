run(function()
	local InvMove
	local restore

	InvMove = vape.Categories.Blatant:CreateModule({
		Name = 'InvMove',
		Function = function(callback)
			if callback then
				if restore then return end
				local controller = skywars.ScreenController
				local original = controller and controller.enableFocus
				if type(original) ~= 'function' then
					notif('InvMove', 'Screen focus controller is unavailable.', 5, 'alert')
					if InvMove.Enabled then InvMove:Toggle() end
					return
				end

				local changed = {}
				local active = true
				local hook
				hook = function(self, screen, ...)
					if active and type(screen) == 'table' then
						local handler = screen.Handler
						local options = type(handler) == 'table' and handler.Options
						if type(options) == 'table' then
							if not changed[options] then
								-- Store a wrapper so an original nil value is preserved too.
								changed[options] = {value = options.focusedAllowMovement}
							end
							options.focusedAllowMovement = true
						end
					end
					return original(self, screen, ...)
				end
				controller.enableFocus = hook
				restore = function()
					if not active then return end
					active = false
					-- Do not overwrite a hook installed by another module after ours.
					if controller.enableFocus == hook then controller.enableFocus = original end
					for options, saved in changed do
						if options.focusedAllowMovement == true then options.focusedAllowMovement = saved.value end
					end
					table.clear(changed)
					restore = nil
				end
				InvMove:Clean(restore)
			elseif restore then
				restore()
			end
		end,
		Tooltip = 'Allows movement in menus opened while enabled. Reopen an already-open menu to apply.'
	})
end)
run(function()
    local LARPBedCoins
    local customAmount = 0
    local cachedLabel = nil
    local hookedLabel = nil
    local realText = nil
    local textConn = nil
    local applying = false

    local function findLabel()
        if cachedLabel and cachedLabel.Parent then
            return cachedLabel
        end
        local pg = lplr:FindFirstChild("PlayerGui")
        if not pg then return nil end
        local sideGui = pg:FindFirstChild("LobbyHudSideGui")
        if not sideGui then return nil end
        local side = sideGui:FindFirstChild("LobbyHudSide")
        if not side then return nil end
        local currency = side:FindFirstChild("LobbyHudCurrency")
        if not currency then return nil end
        local inner = currency:FindFirstChild("LobbyHudCurrency")
        if not inner then return nil end
        local container = inner:FindFirstChild("Container")
        if not container then return nil end
        local amount = container:FindFirstChild("CurrencyAmount")
        if not amount then return nil end
        if not amount:IsA("TextLabel") then return nil end
        cachedLabel = amount
        return amount
    end

    local function formatNumber(n)
        local s = tostring(math.floor(n))
        local res = ""
        for i = 1, #s do
            res = res .. s:sub(i, i)
            if (#s - i) % 3 == 0 and i ~= #s then
                res = res .. ","
            end
        end
        return res
    end

    local function updateCoins()
        if not LARPBedCoins or not LARPBedCoins.Enabled then return end
        local label = findLabel()
        if not label then return end
        if label ~= hookedLabel then
            if textConn then textConn:Disconnect() end
            hookedLabel = label
            realText = label.Text
            textConn = label:GetPropertyChangedSignal("Text"):Connect(function()
                if applying then return end
                realText = label.Text
                updateCoins()
            end)
        end
        local want = formatNumber(customAmount)
        if label.Text ~= want then
            applying = true
            label.Text = want
            applying = false
        end
    end

    LARPBedCoins = vape.Categories.Minigames:CreateModule({
        Name = "LARPBedCoins",
        Tooltip = "larp ur bed coins",
        Function = function(callback)
            if callback then
                LARPBedCoins:Clean(runService.RenderStepped:Connect(function()
                    updateCoins()
                end))
                updateCoins()
            else
                if textConn then
                    textConn:Disconnect()
                    textConn = nil
                end
                if hookedLabel and hookedLabel.Parent and realText then
                    applying = true
                    hookedLabel.Text = realText
                    applying = false
                end
                hookedLabel = nil
                realText = nil
                cachedLabel = nil
            end
        end
    })

    LARPBedCoins:CreateSlider({
        Name = "Coin Amount",
        Min = 0,
        Max = 1000000,
        Default = 0,
        Decimal = 1,
        Function = function(val)
            customAmount = math.floor(val)
            if LARPBedCoins.Enabled then updateCoins() end
        end
    })
end)
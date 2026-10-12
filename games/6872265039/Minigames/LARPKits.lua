run(function()
    local LARPKits
    local KITS_TO_OWN = {}
    local active = false
    local connection = nil

    local function getKitName(btn)
        local tag = btn:FindFirstChild("KitNameTag")
        if not tag then return nil end
        local lbl = tag:FindFirstChild("5") or tag:FindFirstChild("4")
        if lbl and lbl:IsA("TextLabel") then
            return lbl.Text
        end
        return nil
    end

    local function moveOwnedKits(notOwned, owned)
        if not notOwned or not owned then return 0 end
        local moved = 0
        for _, btn in ipairs(notOwned:GetChildren()) do
            if btn:IsA("ImageButton") then
                local name = getKitName(btn)
                if name then
                    for _, wantedKit in ipairs(KITS_TO_OWN) do
                        if string.lower(name) == string.lower(wantedKit) then
                            btn.Parent = owned
                            moved = moved + 1
                            break
                        end
                    end
                end
            end
        end
        return moved
    end

    local function applyKits()
        local pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui")
        if not pg then return end
        local app = pg:FindFirstChild("KitShopApp")
        if not app then return end
        local list = app:FindFirstChild("LobbyKitShopItemList", true)
        if not list then return end
        local notOwned = list:FindFirstChild("NotUnlockedKits")
        local owned = list:FindFirstChild("UnlockedKits")
        if notOwned and owned then
            moveOwnedKits(notOwned, owned)
        end
    end

    local addedConn = nil

    local function isWanted(name)
        if not name then return false end
        local lower = string.lower(name)
        for _, wantedKit in ipairs(KITS_TO_OWN) do
            if lower == string.lower(wantedKit) then return true end
        end
        return false
    end

    local function tryMove(obj)
        if not active or not obj then return end
        local btn = obj:IsA("ImageButton") and obj or obj:FindFirstAncestorWhichIsA("ImageButton")
        if not btn then return end
        local parent = btn.Parent
        if not parent or parent.Name ~= "NotUnlockedKits" then return end
        local owned = parent.Parent and parent.Parent:FindFirstChild("UnlockedKits")
        if owned and isWanted(getKitName(btn)) then
            btn.Parent = owned
        end
    end

    local function startAutoMove()
        if connection then return end
        local pg = game.Players.LocalPlayer:FindFirstChild("PlayerGui") or game.Players.LocalPlayer:WaitForChild("PlayerGui")
        addedConn = pg.DescendantAdded:Connect(function(obj)
            if not active then return end
            if obj:IsA("ImageButton") or (obj:IsA("TextLabel") and (obj.Name == "5" or obj.Name == "4")) then
                tryMove(obj)
            end
        end)
        local last = 0
        connection = game:GetService("RunService").RenderStepped:Connect(function()
            if not active then return end
            local now = os.clock()
            if now - last < 0.25 then return end
            last = now
            applyKits()
        end)
    end

    local function stopAutoMove()
        if connection then
            connection:Disconnect()
            connection = nil
        end
        if addedConn then
            addedConn:Disconnect()
            addedConn = nil
        end
    end

    LARPKits = vape.Categories.Minigames:CreateModule({
        Name = "LARPKits",
        Tooltip = "do u own it or not !!! (client-sided)",
        Function = function(callback)
            active = callback
            if callback then
                startAutoMove()
                applyKits() 
            else
                stopAutoMove()
            end
        end
    })

    LARPKits:CreateTextList({
        Name = "Kits To Own",
        Placeholder = "Type kit names here e.g. Ragnar",
        Function = function(list)
            KITS_TO_OWN = {}
            for _, name in ipairs(list) do
                if name and name ~= "" then
                    table.insert(KITS_TO_OWN, name)
                end
            end
            if active then
                applyKits()
            end
        end
    })
end)
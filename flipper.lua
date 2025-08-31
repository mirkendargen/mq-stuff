local mq = require('mq')
local imgui = require('ImGui')

local npcName = ''
local requestPhrase = ''
local enterPhrase = ''
local kickTime = ''
local showUI = true
local running = false
local kickTimeLeft = ''
local startCMD = ''
local stopCMD = ''
local startZone = ''
local missions = {"Custom", "Pups of War", "Time and Tides", "Assault the Tower", "Breaking the Seal"}
local mission = 1

local function kickTask()
    mq.delay(100)
    mq.cmdf('/kickp task')
    mq.delay(100)
    mq.cmdf('/notify ConfirmationDialogBox CD_Yes_Button leftmouseup')
    while mq.TLO.Zone.ShortName() ~= startZone do
            mq.delay(1000)
        end
    while mq.TLO.Group.AnyoneMissing() do
        mq.delay(1000)
    end
    
end

local function interactWithNPC()

    while true do 
        if npcName == '' or requestPhrase == '' or enterPhrase == '' then
            print("All fields must be filled out!")
            running = false
            return
        end

        mq.cmdf('/dgga /target ' .. npcName)
        mq.delay(300)  -- wait for target to register
        mq.cmdf('/dgga /nav target')
        mq.delay(300)

        while mq.TLO.Navigation.Active() do
            mq.delay(100)
        end
        startZone = mq.TLO.Zone.ShortName()
        mq.cmdf("/hail")
        mq.delay(1000)

        mq.cmdf("/makemevisible")
        mq.delay(200)

        mq.cmdf("/say %s", requestPhrase)
        mq.delay(40000)

        mq.cmdf('/dgga /target ' .. npcName)
        mq.delay(200)
        mq.cmdf('/dgga /makemevisible')
        mq.delay(300) 
        mq.cmdf("/dgga /say %s", enterPhrase)
        mq.delay(1000)
        while mq.TLO.Zone.ShortName() == startZone do
            mq.delay(1000)
        end
        while mq.TLO.Group.AnyoneMissing() do
            mq.delay(5000)
            mq.cmdf('/dgga /target ' .. npcName)
            mq.delay(300)
            mq.cmdf('/dgga /makemevisible')
            mq.delay(300) 
            mq.cmdf('/dgga /nav target')
            mq.delay(300)
            mq.cmdf("/dgga /say %s", enterPhrase)
            mq.delay(1000)
        end
        mq.delay(3000)
        mq.cmdf(startCMD)

        kickTimeLeft = kickTime

        while kickTimeLeft > 0 do
            mq.cmdf('/echo Minutes till kick: ' .. kickTimeLeft)
            mq.delay(60000)
            kickTimeLeft = kickTimeLeft -1
        end

        kickTask()
        mq.delay(3000)
        mq.cmdf(stopCMD)


    end
    running = false
end

local function missionLibrary(mission)
    
    if mission == 'Custom' then
        npcName = ''
        requestPhrase = ''
        enterPhrase = ''
    end

    if mission == 'Pups of War' then
        npcName = "Captain Portencia"
        requestPhrase = "get"
        enterPhrase = "ready"
    end

    if mission == 'Time and Tides' then
        npcName = 'General Serobi'
        requestPhrase = 'we\'ll travel there'
        enterPhrase = 'begin'
    end

    if mission == "Assault the Tower" then
        npcName = "General Serobi"
        requestPhrase = "move"
        enterPhrase = "ready"
    end

    if mission == "Breaking the Seal" then
        npcName = "Kela Lor Telaris"
        requestPhrase = "accompany"
        enterPhrase = "depart"
    end
end

local co = nil
local function startInteraction()
    if running then return end
    running = true
    
    co = coroutine.create(interactWithNPC)
end



local function update()
    if running and co and coroutine.status(co) ~= "dead" then
        local ok, err = coroutine.resume(co)
        if not ok then
            print("Error in interaction coroutine: ", err)
            running = false
        end
    end
end


local function renderUI()
    if showUI then
        ImGui.Begin("Mirk\'s Mission Flipper", true)
        local main_viewport = imgui.GetMainViewport()
        imgui.SetNextWindowPos(main_viewport.WorkPos.x + 650, main_viewport.WorkPos.y + 20, ImGuiCond.FirstUseEver)
        imgui.SetNextWindowSize(800, 600, ImGuiCond.FirstUseEver)
        imgui.PushItemWidth(450)

        local currentSelection = missions[mission]
        if ImGui.BeginCombo("Mission Library", currentSelection) then
            for i = 1, #missions do
                local isSelected = (i == mission)
                if ImGui.Selectable(missions[i], isSelected) then
            
                    if not isSelected then
                        mission = i -- Set new selection
                    end
                end
                if isSelected then
                    ImGui.SetItemDefaultFocus()
                end
        end
            ImGui.EndCombo()
        end
        npcName = ImGui.InputText("NPC Name", npcName, 128)
        requestPhrase = ImGui.InputText("Request Phrase", requestPhrase, 128)
        enterPhrase = ImGui.InputText("Enter Phrase", enterPhrase, 128)
        kickTime = ImGui.InputInt("Task kick timer (minutes)", kickTime)
        startCMD = ImGui.InputText("/command to get going", startCMD)
        stopCMD = ImGui.InputText("/command to chill out", stopCMD)
        if ImGui.Button("Request and Enter Mission") then
            startInteraction()
        end
        if imgui.Button("Stop Script") then
            mq.exit()
        end
        missionLibrary(missions[mission])
        ImGui.End()
    end
end

mq.imgui.init("MissionRequesterUI", renderUI)

while mq.TLO.MacroQuest.GameState() ~= "INGAME" do mq.delay(1000) end
print("Mirk\'s Mission Flipper script loaded. Use the UI to set values.")
while true do
    mq.delay(100)
    update()
end

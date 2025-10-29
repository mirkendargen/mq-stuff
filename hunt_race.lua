-- hunt_race_multifield_remove.lua
local mq = require('mq')
local imgui = require('ImGui')

-- === State ===
local State = {
    raceFilters = { "" },    -- list of race text fields
    isHunting = false,
    status = "Idle"
}

-- === Helper Function: Check XTarget ===
local function AnyXtarTargets()
    if mq.TLO.Me.XTHaterCount() > 0 then return true end
    return false
end

-- === Core Execution Function ===
local function ExecuteHuntingChain(race)
    if not race or race == "" then
        mq.cmd("/echo [HUNT] Race filter empty. Skipping.")
        return
    end

    mq.cmdf('/echo [HUNT] Attempting to target and engage nearest "%s"...', race)
    mq.cmdf('/target npc race %s', race)
    mq.delay(500)

    if mq.TLO.Target.ID() > 0 and mq.TLO.Target.Dead() == false then
        mq.cmd("/echo [HUNT] Target acquired. Navigating and attacking.")
        mq.cmd('/nav target')
        mq.delay(200)
        mq.cmd('/attack on')
    else
        mq.cmd("/echo [HUNT] No live target found for race: " .. race)
    end
end

-- === GUI Function ===
local function DrawGUI()
    ImGui.Begin("Multi-Race Hunter")

    ImGui.PushItemWidth(150)

    local i = 1
    while i <= #State.raceFilters do
        local race = State.raceFilters[i]
        local newText, changed = ImGui.InputText("Race " .. i, race, 64)
        if changed then
            State.raceFilters[i] = newText
        end

        ImGui.SameLine()
        if ImGui.SmallButton("+##" .. i) then
            table.insert(State.raceFilters, i + 1, "")
        end
        ImGui.SameLine()
        if #State.raceFilters > 1 and ImGui.SmallButton("-##" .. i) then
            table.remove(State.raceFilters, i)
            i = i - 1 -- stay on the same index after removal
        end

        i = i + 1
    end

    ImGui.PopItemWidth()
    ImGui.Separator()

    if not State.isHunting then
        if ImGui.Button("Start Hunting") then
            local anyFilled = false
            for _, r in ipairs(State.raceFilters) do
                if r ~= "" then anyFilled = true break end
            end
            if anyFilled then
                State.isHunting = true
                State.status = "Hunting..."
                mq.cmd("/echo [HUNT] Hunting started for specified races.")
            else
                State.status = "Enter at least one race!"
            end
        end
    else
        if ImGui.Button("Stop Hunting") then
            State.isHunting = false
            State.status = "Idle"
            mq.cmd("/attack off")
            mq.cmd("/nav stop")
            mq.cmd("/echo [HUNT] Hunting stopped.")
        end
    end

    ImGui.Separator()
    ImGui.Text("Status: " .. State.status)
    ImGui.Text("Target: " .. (mq.TLO.Target.ID() and mq.TLO.Target.Name() or "None"))

    ImGui.End()
end

-- === Core Hunting Loop ===
local function HuntLoop()
    while true do
        mq.doevents()
        if not State.isHunting then
            mq.delay(500)
        else
            if AnyXtarTargets() then
                State.status = "Waiting for XTarget to clear..."
                local id = mq.TLO.Me.XTarget(1).ID()
                mq.cmdf('/target id %d', id)
                mq.cmd("/attack on")
                mq.cmd("/nav target")
                mq.delay(1000)
            else
                local foundTarget = false
                for _, race in ipairs(State.raceFilters) do
                    if race ~= "" then
                        ExecuteHuntingChain(race)
                        if mq.TLO.Target.ID() > 0 and mq.TLO.Target.Dead() == false then
                            foundTarget = true
                            State.status = "Target acquired: " .. mq.TLO.Target.Name()
                            mq.delay(500)
                            break
                        end
                    end
                end
                if not foundTarget then
                    State.status = "No targets found. Waiting..."
                    mq.delay(5000)
                end
            end
        end
    end
end

-- === Initialization ===
mq.imgui.init('MultiRaceHunter', DrawGUI)
HuntLoop()

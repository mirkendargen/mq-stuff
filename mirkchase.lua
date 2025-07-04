
--[[
chase.lua 1.1.1 -- aquietone

Commands:
- /luachase pause on|1|true -- pause chasing
- /luachase pause off|0|false -- resume chasing
- /luachase target -- sets the chase to your current target, if it is a valid PC target
- /luachase name somedude -- sets the chase target to somedude
- /luachase name -- prints the current chase target
- /luachase role [ma|mt|leader|raid1|raid2|raid3] -- chase the PC with the specified role
- /luachase role -- displays the role to chase
- /luachase distance 30 -- sets the chase distance to 30
- /luachase distance -- prints the current chase distance
- /luachase stopdistance 10 -- sets the stop distance to 10 (nav dist=# parameter)
- /luachase stopdistance -- prints the current stop distance
- /luachase show -- displays the UI window
- /luachase hide -- hides the UI window
- /luachase [help] -- displays the help output

TLO:
${Chase}
${Chase.Role}
${Chase.Paused}
${Chase.ChaseDistance}
${Chase.StopDistance}
${Chase.Target}
]]--

local mq = require('mq')
require('ImGui')

local PREFIX = '\aw[\agCHASE\aw] \ay'
local PAUSED = false
local CHASE = ''
local CHASE_ID = nil -- New variable to track unique NPC ID
local DISTANCE = 30
local STOP_DISTANCE = 10
local TARGET_TYPE = 'PC' -- New variable to track target type (PC/NPC)

local open_gui = true
local should_draw_gui = true

local ROLES = {[1]='none',none=1,[2]='ma',ma=1,[3]='mt',mt=1,[4]='leader',leader=1,[5]='raid1',raid1=1,[6]='raid2',raid2=1,[7]='raid3',raid3=1}
local ROLE = 'none'

local function init_tlo()
    local ChaseType

    local function ChaseTLO(index)
        return ChaseType, {}
    end

    local tlomembers = {
        Paused = function() return 'bool', PAUSED end,
        Role = function(val, index) return 'string', ROLE end,
        Target = function(val, index) return 'string', CHASE end,
        ChaseDistance = function(val, index) return 'int', DISTANCE end,
        StopDistance = function(val, index) return 'int', STOP_DISTANCE end,
    }

    ChaseType = mq.DataType.new('ChaseType', {
        Members = tlomembers
    })
    function ChaseType.ToString()
        return ('Chase Running = %s'):format(not PAUSED)
    end

    mq.AddTopLevelObject('Chase', ChaseTLO)
end

local function validate_distance(distance)
    return distance >= 15 and distance <= 300
end

local function validate_stop_distance(distance)
    return distance >= 0 and distance < DISTANCE
end

local function check_distance(x1, y1, x2, y2)
    return (x2 - x1) ^ 2 + (y2 - y1) ^ 2
end

local function validate_chase_role(role)
    return ROLES[role] ~= nil
end

local function get_spawn_for_role()
    local spawn = nil
    if ROLE == 'none' then
        if CHASE_ID then
            spawn = mq.TLO.Spawn(string.format('id %s', CHASE_ID))
        else
            spawn = mq.TLO.Spawn(string.format('%s =%s', TARGET_TYPE:lower(), CHASE))
        end
    elseif ROLE == 'ma' then
        spawn = mq.TLO.Group.MainAssist
    elseif ROLE == 'mt' then
        spawn = mq.TLO.Group.MainTank
    elseif ROLE == 'leader' then
        spawn = mq.TLO.Group.Leader
    elseif ROLE == 'raid1' then
        spawn = mq.TLO.Raid.MainAssist(1)
    elseif ROLE == 'raid2' then
        spawn = mq.TLO.Raid.MainAssist(2)
    elseif ROLE == 'raid3' then
        spawn = mq.TLO.Raid.MainAssist(3)
    end
	
	if spawn and spawn.Type() == 'Corpse' then
        return nil
    end
	
    return spawn
end

local function do_chase()
    if PAUSED then return end
    if mq.TLO.Me.Hovering() or mq.TLO.Me.AutoFire() or mq.TLO.Me.Combat() or (mq.TLO.Me.Casting() and mq.TLO.Me.Class.ShortName() ~= 'BRD') or mq.TLO.Stick.Active() then return end
    local chase_spawn = get_spawn_for_role()
	if not chase_spawn then return end -- Skip if target is a corpse
    local me_x = mq.TLO.Me.X()
    local me_y = mq.TLO.Me.Y()
    local chase_x = chase_spawn.X()
    local chase_y = chase_spawn.Y()
    if not chase_x or not chase_y then return end
    if check_distance(me_x, me_y, chase_x, chase_y) > DISTANCE^2 then
        if not mq.TLO.Nav.Active() and mq.TLO.Navigation.PathExists(string.format('spawn id %s', CHASE_ID or chase_spawn.ID())) then
            mq.cmdf('/nav spawn id %s | dist=%s log=off', CHASE_ID or chase_spawn.ID(), STOP_DISTANCE)
        end
    end
end

local function helpMarker(desc)
    if ImGui.IsItemHovered() then
        ImGui.BeginTooltip()
        ImGui.PushTextWrapPos(ImGui.GetFontSize() * 35.0)
        ImGui.Text(desc)
        ImGui.PopTextWrapPos()
        ImGui.EndTooltip()
    end
end

local function draw_combo_box(resultvar, options)
    if ImGui.BeginCombo('Chase Role', resultvar) then
        for _,j in ipairs(options) do
            if ImGui.Selectable(j, j == resultvar) then
                resultvar = j
            end
        end
        ImGui.EndCombo()
    end
    helpMarker('Assign the group or raid role to chase')
    return resultvar
end

local function chase_ui()
    if not open_gui or mq.TLO.MacroQuest.GameState() ~= 'INGAME' then return end
    open_gui, should_draw_gui = ImGui.Begin(mq.TLO.Me.Name(), open_gui)
    if should_draw_gui then
        if PAUSED then
            if ImGui.Button('Resume') then
                PAUSED = false
            end
        else
            if ImGui.Button('Pause') then
                PAUSED = true
                mq.cmd('/squelch /nav stop')
            end
        end
        helpMarker('Pause or resume chasing')
        ImGui.PushItemWidth(200)
        ROLE = draw_combo_box(ROLE, ROLES)
        if ROLE == 'none' then
            CHASE = ImGui.InputText('Chase Target', CHASE)
        helpMarker('Assign the PC spawn name to chase')
        end
        local tmp_distance = ImGui.InputInt('Chase Distance', DISTANCE)
        helpMarker('Set the distance to begin chasing at. Min=15, Max=300')
        if validate_distance(tmp_distance) then
            DISTANCE = tmp_distance
        end
        tmp_distance = ImGui.InputInt('Stop Distance', STOP_DISTANCE)
        helpMarker('Set the distance to stop chasing at. Min=0, Max='..(DISTANCE-1))
        ImGui.PopItemWidth()
        if validate_stop_distance(tmp_distance) then
            STOP_DISTANCE = tmp_distance
        end
    end
    ImGui.End()
end
mq.imgui.init('Chase', chase_ui)

local function print_help()
    print('\ayLua Chase 1.0 -- \awAvailable Commands:')
    print('\ay\t/luachase role ma|mt|leader|raid1|raid2|raid3\n\t/luachase target\n\t/luachase name [pc_name_to_chase]\n\t/luachase distance [10,300]\n\t/luachase stopdistance [0,chase_distance-1]\n\t/luachase pause on|1|true\n\t/luachase pause off|0|false\n\t/luachase show\n\t/luachase hide')
end

local function bind_chase(...)
    local args = {...}
    local key = args[1]
    local value = args[2]
    if not key or key == 'help' then
        print_help()
    elseif key == 'target' then
        if mq.TLO.Target() and (mq.TLO.Target.Type() == 'PC' or mq.TLO.Target.Type() == 'NPC') then
            CHASE = mq.TLO.Target.CleanName()
			CHASE_ID = mq.TLO.Target.ID()
			TARGET_TYPE = mq.TLO.Target.Type()
		else
			return
        end
    elseif key == 'name' then
        if value then
            CHASE = value
        else
            printf('%sChase Target: \aw%s', PREFIX, CHASE)
        end
    elseif key == 'role' then
        if value and validate_chase_role(value) then
            ROLE = value
        else
            printf('%sChase Role: \aw%s', PREFIX, ROLE)
        end
    elseif key == 'distance' then
        if tonumber(value) then
            local tmp_distance = tonumber(value)
            if validate_distance(tmp_distance) then
                DISTANCE = tmp_distance
            end
        else
            printf('%sChase Distance: \aw%s', PREFIX, DISTANCE)
        end
    elseif key == 'stopdistance' then
        if tonumber(value) then
            local tmp_distance = tonumber(value)
            if validate_stop_distance(tmp_distance) then
                STOP_DISTANCE = tmp_distance
            end
        else
            printf('%sStop Distance: \aw%s', PREFIX, STOP_DISTANCE)
        end
    elseif key == 'pause' then
        if value == 'on' or value == '1' or value == 'true' then
            PAUSED = true
            mq.cmd('/squelch /nav stop')
        elseif value == 'off' or value == '0' or value == 'false' then
            PAUSED = false
        else
            printf('%sPaused: \aw%s', PREFIX, PAUSED)
        end
    elseif key == 'show' then
        open_gui = true
    elseif key == 'hide' then
        open_gui = false
    end
end
mq.bind('/luachase', bind_chase)
init_tlo()

local args = {...}
if args[1] then
    if validate_chase_role(args[1]) then
        ROLE = args[1]
    else
        CHASE=args[1]
    end
end

while true do
    if mq.TLO.MacroQuest.GameState() == 'INGAME' then
        do_chase()
    end
    mq.delay(50)
end

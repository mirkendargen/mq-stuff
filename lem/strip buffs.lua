local mq = require('mq')

-- Do not edit this if condition
if not package.loaded['events'] then
    print('This script is intended to be imported to Lua Event Manager (LEM). Try "\a-t/lua run lem\a-x"')
end

local function on_load()
    -- Perform any initial setup here when the event is loaded.
end

---@return boolean @Returns true if the action should fire, otherwise false.
local function condition()
    if mq.TLO.Me.CountBuffs() ~= NULL then
        return true
    end
end

local function action()
    mq.cmdf("/removebuff %s", mq.TLO.Me.Beneficial())
end

return {onload=on_load, condfunc=condition, actionfunc=action}
-- File: group_command.lua
-- Usage in MQ: /lua run group_command "/cast 1"

local mq = require('mq')

-- Get the command parameter from the script arguments
local args = {...}
if #args == 0 then
    print("Usage: /lua run group_command \"<command to send>\"")
    return
end
local commandToSend = table.concat(args, " ")

-- Get list of group members (excluding self)
local function getGroupMembers()
    local members = {}
    for i = 0, mq.TLO.Group.Members() - 1 do
        local name = mq.TLO.Group.Member(i).Name()
        if name and name ~= mq.TLO.Me.Name() then
            table.insert(members, name)
        end
    end
    return members
end

-- Send the command to each group member via DanNet with a random delay
local function sendCommandToGroup(cmd)
    local members = getGroupMembers()
    for _, member in ipairs(members) do
        -- Random delay between 0.5 and 2.0 seconds
        local delayMs = math.random(100, 1000)
        mq.delay(delayMs)
        mq.cmdf('/dex %s %s', member, cmd)
        print(string.format("Sent command to %s after %d ms delay", member, delayMs))
    end
    mq.cmdf(cmd)
end

math.randomseed(os.time() + mq.TLO.Me.ID())
sendCommandToGroup(commandToSend)

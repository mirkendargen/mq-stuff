mq = require('mq')

-- Have target and meleeing and have enough endurance and ability is up
local function condition()
    local abilityName = "Boastful Bellow"
    local bellowCost = mq.TLO.AltAbility(199).Spell.EnduranceCost()
    if not mq.TLO.Target() or not mq.TLO.Me.Combat() or mq.TLO.Me.Endurance() < bellowCost then
        return false
    end
    
    if mq.TLO.Target.Buff("Boastful Bellow").Caster() ~= mq.TLO.Me.Name() and mq.TLO.Me.AltAbilityReady("Boastful Bellow")() then
        return true
    end
  
end

-- Function to cast Boastful Bellow if the condition is met
local function action()
    mq.cmdf("/alt act 199")
end

return {condfunc=condition, actionfunc=action}
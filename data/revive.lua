-- revive.lua
local revive = {}

local revive_start_time = nil


function revive.check_and_revive()
    local local_player = get_local_player()
    if local_player and local_player:is_dead() then
        if not revive_start_time then
            revive_start_time = os.clock()
            console.print("Player will be revived in 6 seconds.")
        elseif os.clock() - revive_start_time >= 6 then
            revive_at_checkpoint()
            console.print("Player revived at checkpoint.")
            revive_start_time = nil -- reset timer
        end
    else
        revive_start_time = nil -- not dead reset
    end
end

return revive
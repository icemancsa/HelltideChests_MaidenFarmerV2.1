-- game_state_checker.lua

local GameStateChecker = {}

-- Function to check if in loading screen or Limbo
function GameStateChecker.is_loading_screen()
    local world_instance = world.get_current_world()
    if world_instance then
        local zone_name = world_instance:get_current_zone_name()
        local world_name = ""
        
        -- Safely try to get the world name
        pcall(function()
            world_name = world_instance:get_world_name() or ""
        end)
        
        -- Check for loading screen (empty zone name) or Limbo
        return zone_name == nil or zone_name == "" or world_name:find("Limbo")
    end
    return true
end

-- Function to check if in Helltide
function GameStateChecker.is_in_helltide(local_player)
    if not local_player then return false end

    local buffs = local_player:get_buffs()
    if not buffs then return false end

    for _, buff in ipairs(buffs) do
        if buff and buff.name_hash == 1066539 then
            return true
        end
    end
    return false
end

-- Function to check overall game state
function GameStateChecker.check_game_state()
    if GameStateChecker.is_loading_screen() then
        return "loading_or_limbo"
    end

    local local_player = get_local_player()
    if not local_player then
        return "no_player"
    end

    if GameStateChecker.is_in_helltide(local_player) then
        return "helltide"
    end

    return "normal"
end

return GameStateChecker
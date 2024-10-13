local actors = {}

local permanent_blacklist = {}
local expiration_time = 10 -- Expiration time in seconds for temporarily ignored objects

-- Table for storing object movement timers
local movement_timers = {}
local max_movement_time = 15 -- Maximum time in seconds to attempt to move to an object

local ignored_objects = {
    "Lilith",
    "QST_Class_Necro_Shrine",
    "LE_Shrine_Goatman_Props_Arrangement_SP",
    "fxKit_seamlessSphere_twoSided2_lilithShrine_idle",
    "LE_Shrine_Zombie_Props_Arrangement_SP",
    "_Shrine_Moss_",
    "g_gold"
}

local function should_ignore_object(skin_name)
    for _, ignored_pattern in ipairs(ignored_objects) do
        if skin_name:match(ignored_pattern) then
            return true
        end
    end
    return false
end

local actor_types = {
    shrine = {
        pattern = "Shrine_",
        move_threshold = 12,
        interact_threshold = 2.5,
        interact_function = function(obj) 
            interact_object(obj)
        end
    },
    goblin = {
        pattern = "treasure_goblin",
        move_threshold = 20,
        interact_threshold = 2,
        interact_function = function(actor)
            console.print("Interacting with the Goblin")
        end
    },
    harvest_node = {
        pattern = "HarvestNode_Ore",
        move_threshold = 12,
        interact_threshold = 1.0,
        interact_function = function(obj)
            interact_object(obj)
        end
    },
    Misterious_Chest = {
        pattern = "Hell_Prop_Chest_Rare_Locked",
        move_threshold = 12,
        interact_threshold = 1.0,
        interact_function = function(obj)
            interact_object(obj)
        end
    },
    Herbs = {
        pattern = "HarvestNode_Herb",
        move_threshold = 8,
        interact_threshold = 1.0,
        interact_function = function(obj)
            interact_object(obj)
        end
    }
}

local actor_display_names = {
    shrine = "Total Shrines Interacted",
    goblin = "Total Goblins Killed",
    harvest_node = "Total Iron Nodes Interacted",
    Misterious_Chest = "Total Silent Chests Opened",
    Herbs = "Total Herbs Interacted"
}

local interacted_actor_counts = {}
for actor_type in pairs(actor_types) do
    interacted_actor_counts[actor_type] = 0
end

local function is_actor_of_type(skin_name, actor_type)
    return skin_name:match(actor_types[actor_type].pattern) and not should_ignore_object(skin_name)
end

local function should_interact_with_actor(actor_position, player_position, actor_type)
    local distance_threshold = actor_types[actor_type].interact_threshold
    return actor_position:dist_to(player_position) < distance_threshold
end

local function move_to_actor(actor_position, player_position, actor_type)
    local move_threshold = actor_types[actor_type].move_threshold
    local distance = actor_position:dist_to(player_position)
    
    if distance <= move_threshold then
        pathfinder.request_move(actor_position)
        return true
    end
    
    return false
end

-- Function to perm blacklist
local function add_to_permanent_blacklist(obj)
    local obj_name = obj:get_skin_name()
    local obj_pos = obj:get_position()
    
    local pos_string = "unknown position"
    if obj_pos then
        
        pos_string = string.format("(%.2f, %.2f, %.2f)", obj_pos:x(), obj_pos:y(), obj_pos:z())
    end
    
    table.insert(permanent_blacklist, {name = obj_name, position = obj_pos})
    --console.print("Adicionado " .. obj_name .. " à blacklist permanente na posição: " .. pos_string)
end

-- Function to check if you are on the permanent blacklist
local function is_permanently_blacklisted(obj)
    local obj_name = obj:get_skin_name()
    local obj_pos = obj:get_position()
    
    for _, blacklisted_obj in ipairs(permanent_blacklist) do
        if blacklisted_obj.name == obj_name and blacklisted_obj.position:dist_to(obj_pos) < 0.1 then
            return true
        end
    end
    
    return false
end

function actors.update()
    local local_player = get_local_player()
    if not local_player then
        return
    end

    local player_pos = local_player:get_position()
    local all_actors = actors_manager.get_ally_actors()
    local current_time = os.clock()

    -- sort actors by distance
    table.sort(all_actors, function(a, b)
        return a:get_position():squared_dist_to_ignore_z(player_pos) <
               b:get_position():squared_dist_to_ignore_z(player_pos)
    end)

    for _, obj in ipairs(all_actors) do
        if obj and not is_permanently_blacklisted(obj) then
            local position = obj:get_position()
            local skin_name = obj:get_skin_name()

            for actor_type, config in pairs(actor_types) do
                if skin_name and is_actor_of_type(skin_name, actor_type) then
                    local distance = position:dist_to(player_pos)
                    if distance <= config.move_threshold then
                        -- Iniciar o temporizador de movimento se ainda não existir
                        if not movement_timers[obj:get_id()] then
                            movement_timers[obj:get_id()] = current_time
                        end

                        -- verify timelimit reach ?
                        if current_time - movement_timers[obj:get_id()] > max_movement_time then
                            add_to_permanent_blacklist(obj)
                            movement_timers[obj:get_id()] = nil
                            --console.print("Tempo limite de movimento atingido para " .. actor_type .. ": " .. skin_name .. ". Adicionado à blacklist permanente.")
                        else
                            if move_to_actor(position, player_pos, actor_type) then
                                if should_interact_with_actor(position, player_pos, actor_type) then
                                    config.interact_function(obj)
                                    add_to_permanent_blacklist(obj)
                                    movement_timers[obj:get_id()] = nil
                                    interacted_actor_counts[actor_type] = interacted_actor_counts[actor_type] + 1
                                    --console.print("Interagiu com " .. actor_type .. ": " .. skin_name .. ". Adicionado à blacklist permanente.")
                                end
                            end
                        end
                    else
                        -- If the object is out of range, we reset the timer
                        movement_timers[obj:get_id()] = nil
                    end
                end
            end
        end
    end
end

-- Function to clear the permanent blacklist
function actors.clear_permanent_blacklist()
    permanent_blacklist = {}
    movement_timers = {}
    console.print("Permanent blacklist and movement timers have been cleared")
end

function actors.draw_actor_info()
    local positions = {
        shrine = {x = 10, y = 90},
        goblin = {x = 10, y = 110},
        harvest_node = {x = 10, y = 130},
        Misterious_Chest = {x = 10, y = 150},
        Herbs = {x = 10, y = 170}
    }

    for actor_type, count in pairs(interacted_actor_counts) do
        local pos = positions[actor_type]
        if pos then
            local display_name = actor_display_names[actor_type] or actor_type
            local info_text = string.format("%s: %d", display_name, count)
            graphics.text_2d(info_text, vec2:new(pos.x, pos.y), 20, color_white(255))
        end
    end
end

function actors.reset_interacted_counts()
    for actor_type in pairs(actor_types) do
        interacted_actor_counts[actor_type] = 0
    end
end

return actors
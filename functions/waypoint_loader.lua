local waypoint_loader = {}
local cached_waypoints = {}


waypoint_loader.zone_mappings = {
    ["Frac_Tundra_S"] = {id = 0xACE9B, regular = "menestad", maiden = "menestad_to_maiden"},
    ["Scos_Coast"] = {id = 0x27E01, regular = "marowen", maiden = "marowen_to_maiden"},
    ["Kehj_Oasis"] = {id = 0xDEAFC, regular = "ironwolfs", maiden = "ironwolfs_to_maiden"},
    ["Hawe_Verge"] = {id = 0x9346B, regular = "wejinhani", maiden = "wejinhani_to_maiden"},
    ["Step_South"] = {id = 0x462E2, regular = "jirandai", maiden = "jirandai_to_maiden"}
}


function waypoint_loader.load_waypoints(file)
    if cached_waypoints[file] then
        return cached_waypoints[file]
    end
    local waypoints = require("waypoints." .. file)
    cached_waypoints[file] = waypoints
    return waypoints
end


function waypoint_loader.clear_cached_waypoints()
    cached_waypoints = {}
    collectgarbage("collect")
end


function waypoint_loader.randomize_waypoint(waypoint, max_offset)
    max_offset = max_offset or 1.5
    local attempts = 0
    local max_attempts = 30
    
    while attempts < max_attempts do
        local random_x = math.random() * max_offset * 2 - max_offset
        local random_y = math.random() * max_offset * 2 - max_offset
        
        local new_waypoint = vec3:new(
            waypoint:x() + random_x,
            waypoint:y() + random_y,
            waypoint:z()
        )
        
        if utility.is_point_walkeable(new_waypoint) then
            return new_waypoint
        end
        
        attempts = attempts + 1
    end
    
    
    return waypoint
end


function waypoint_loader.load_route(zone_name, is_maiden_route)
    local world_instance = world.get_current_world()
    if not world_instance then
        console.print("Error: Unable to get world instance")
        return nil, nil
    end

    local zone_name = zone_name or world_instance:get_current_zone_name()
    if not zone_name then
        console.print("Error: Unable to get zone name")
        return nil, nil
    end

    local zone_info = waypoint_loader.zone_mappings[zone_name]
    if not zone_info then
        console.print("No matching zones found for waypoints: " .. zone_name)
        return nil, nil
    end

    local file = is_maiden_route and zone_info.maiden or zone_info.regular
    local route_type = is_maiden_route and "Maiden" or "regular"
    
    console.print("Trying to load waypoints " .. route_type .. " to the zone: " .. zone_name .. " do arquivo: " .. file)
    
    if cached_waypoints[file] then
        console.print("Using cached waypoints to " .. file)
        return cached_waypoints[file], zone_info.id
    end

    local full_path = "waypoints." .. file
    

    local success, waypoints_or_error = pcall(require, full_path)
    if not success then
        console.print("Error loading waypoints from file " .. file .. ": " .. tostring(waypoints_or_error))
        return nil, nil
    end
    
    if type(waypoints_or_error) ~= "table" or #waypoints_or_error == 0 then
        console.print("Error: Waypoints are empty or not a valid table")
        return nil, nil
    end
    
    
    for i, wp in ipairs(waypoints_or_error) do
        if type(wp) ~= "userdata" or not wp.x or not wp.y or not wp.z then
            console.print("Erro: Waypoint " .. i .. " not a valid vec3")
            return nil, nil
        end
    end
    
    cached_waypoints[file] = waypoints_or_error
    console.print("Loaded " .. #waypoints_or_error .. " waypoints")
    
    return waypoints_or_error, zone_info.id
end


function waypoint_loader.check_and_load_waypoints()
    local world_instance = world.get_current_world()
    if not world_instance then
        console.print("Error: Unable to get world instance")
        return nil, nil
    end

    local zone_name = world_instance:get_current_zone_name()
    if not zone_name then
        console.print("Error: Unable to get zone name")
        return nil, nil
    end

    return waypoint_loader.load_route(zone_name, false)
end


function waypoint_loader.load_maiden_route(file)
    for zone_name, info in pairs(waypoint_loader.zone_mappings) do
        if info.regular == file then
            return waypoint_loader.load_route(zone_name, true)
        end
    end
    console.print("Error: Unable to find matching zone for file: " .. file)
    return nil, nil
end

return waypoint_loader
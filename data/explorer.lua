local MinHeap = {}
MinHeap.__index = MinHeap

function MinHeap.new(compare)
    return setmetatable({heap = {}, compare = compare or function(a, b) return a < b end}, MinHeap)
end

function MinHeap:push(value)
    table.insert(self.heap, value)
    self:siftUp(#self.heap)
end

function MinHeap:pop()
    if self:empty() then return nil end
    local root = self.heap[1]
    self.heap[1] = self.heap[#self.heap]
    table.remove(self.heap)
    if #self.heap > 1 then
        self:siftDown(1)
    end
    return root
end

function MinHeap:peek()
    return self.heap[1]
end

function MinHeap:empty()
    return #self.heap == 0
end

function MinHeap:siftUp(index)
    local parent = math.floor(index / 2)
    while index > 1 and self.compare(self.heap[index], self.heap[parent]) do
        self.heap[index], self.heap[parent] = self.heap[parent], self.heap[index]
        index = parent
        parent = math.floor(index / 2)
    end
end

function MinHeap:siftDown(index)
    local size = #self.heap
    local smallest = index
    while true do
        local left = 2 * index
        local right = 2 * index + 1
        if left <= size and self.compare(self.heap[left], self.heap[smallest]) then
            smallest = left
        end
        if right <= size and self.compare(self.heap[right], self.heap[smallest]) then
            smallest = right
        end
        if smallest == index then break end
        self.heap[index], self.heap[smallest] = self.heap[smallest], self.heap[index]
        index = smallest
    end
end

function MinHeap:contains(value)
    for _, v in ipairs(self.heap) do
        if v == value then return true end
    end
    return false
end

local enabled = false
local explored_areas = {}
local target_position = nil
local grid_size = 1.5            -- Size of grid cells in meters
local exploration_radius = 7   -- Radius in which areas are considered explored
local explored_buffer = 0      -- Buffer around explored areas in meters
local max_target_distance = 80 -- Maximum distance for a new target -- 120
local target_distance_states = {80, 40, 20, 5}
local target_distance_index = 1
local unstuck_target_distance = 5 -- Maximum distance for an unstuck target
local stuck_threshold = 4      -- Seconds before the character is considered "stuck"
local last_position = nil
local last_move_time = 0
local last_explored_targets = {}
local max_last_targets = 50
local start_time = 0
local min_duration = 30 -- Minimum 5 seconds -- Tempo minimo duracao explorer

-- A* pathfinding variables
local current_path = {}
local path_index = 1

-- Explorationsmodus
local exploration_mode = "unexplored"

local exploration_direction = { x = 10, y = 0 } -- Initiale Richtung (kann angepasst werden)

local last_movement_direction = nil

local function calculate_distance(point1, point2)
    if not point2.x and point2 then
        return point1:dist_to_ignore_z(point2:get_position())
    end
    return point1:dist_to_ignore_z(point2)
end

local function enable()
    enabled = true
    start_time = os.clock()
    console.print("Explorer module enabled.")
end

-- Função para desabilitar o módulo de exploração
local function disable()
    enabled = false
    target_position = nil
    current_path = {}
    path_index = 1
    --console.print("Explorer module disabled.")
end

local function is_enabled()
    return enabled
end

local function set_target(new_target)
    target_position = new_target
    current_path = {}
    path_index = 1
end

-- New function to check if explorer has reached its target
local function is_target_reached()
    if not target_position then
        return true
    end
    local player_pos = get_player_position()
    return calculate_distance(player_pos, target_position) < 2
end

--ai fix for stairs
local function set_height_of_valid_position(point)
    --console.print("Setting height of valid position.")
    return utility.set_height_of_valid_position(point)
end

local function get_grid_key(point)
    --console.print("Getting grid key.")
    return math.floor(point:x() / grid_size) .. "," ..
        math.floor(point:y() / grid_size) .. "," ..
        math.floor(point:z() / grid_size)
end

local function calculate_distance(point1, point2)
    --console.print("Calculating distance between points.")
    if not point2.x and point2 then
        return point1:dist_to_ignore_z(point2:get_position())
    end
    return point1:dist_to_ignore_z(point2)
end

local explored_area_bounds = {
    min_x = math.huge,
    max_x = -math.huge,
    min_y = math.huge,
    max_y = -math.huge,
}

local function update_explored_area_bounds(point, radius)
    --console.print("Updating explored area bounds.")
    explored_area_bounds.min_x = math.min(explored_area_bounds.min_x, point:x() - radius)
    explored_area_bounds.max_x = math.max(explored_area_bounds.max_x, point:x() + radius)
    explored_area_bounds.min_y = math.min(explored_area_bounds.min_y, point:y() - radius)
    explored_area_bounds.max_y = math.max(explored_area_bounds.max_y, point:y() + radius)
    explored_area_bounds.min_z = math.min(explored_area_bounds.min_z or math.huge, point:z() - radius)
    explored_area_bounds.max_z = math.max(explored_area_bounds.max_z or -math.huge, point:z() + radius)
end

local function is_point_in_explored_area(point)
    --console.print("Checking if point is in explored area.")
    return point:x() >= explored_area_bounds.min_x and point:x() <= explored_area_bounds.max_x and
        point:y() >= explored_area_bounds.min_y and point:y() <= explored_area_bounds.max_y and
        point:z() >= explored_area_bounds.min_z and point:z() <= explored_area_bounds.max_z
end

local function mark_area_as_explored(center, radius)
    --console.print("Marking area as explored.")
    update_explored_area_bounds(center, radius)
    -- Hier können Sie zusätzliche Logik hinzufügen, um die erkundeten Bereiche zu markieren
    -- z.B. durch Hinzufügen zu einer Datenstruktur oder durch Setzen von Flags
end

local function check_walkable_area()
    --console.print("Checking walkable area.")
    if os.time() % 5 ~= 0 then return end  -- Only run every 5 seconds

    local player_pos = get_player_position()
    local check_radius = 10 -- Überprüfungsradius in Metern

    mark_area_as_explored(player_pos, exploration_radius)

    for x = -check_radius, check_radius, grid_size do
        for y = -check_radius, check_radius, grid_size do
            for z = -check_radius, check_radius, grid_size do -- Inclui z no loop

                local point = vec3:new(
                    player_pos:x() + x,
                    player_pos:y() + y,
                    player_pos:z() + z
                )
                print("Checking point:", point:x(), point:y(), point:z()) -- Debug print
                point = set_height_of_valid_position(point)

                if utility.is_point_walkeable(point) then
                    if is_point_in_explored_area(point) then
                        --graphics.text_3d("Explored", point, 15, color_white(128))
                    else
                        --graphics.text_3d("unexplored", point, 15, color_green(255))
                    end
                end
            end
        end
    end
end

local function reset_exploration()
    --console.print("Resetting exploration.")
    explored_area_bounds = {
        min_x = math.huge,
        max_x = -math.huge,
        min_y = math.huge,
        max_y = -math.huge,
    }
    target_position = nil
    last_position = nil
    last_move_time = 0
    current_path = {}
    path_index = 1
    exploration_mode = "unexplored"
    last_movement_direction = nil

    console.print("Exploration reset. All areas marked as unexplored.")
end

local function is_near_wall(point)
    --console.print("Checking if point is near wall.")
    local wall_check_distance = 1 -- Abstand zur Überprüfung von Wänden
    local directions = {
        { x = 1, y = 0 }, { x = -1, y = 0 }, { x = 0, y = 1 }, { x = 0, y = -1 },
        { x = 1, y = 1 }, { x = 1, y = -1 }, { x = -1, y = 1 }, { x = -1, y = -1 }
    }
    
    for _, dir in ipairs(directions) do
        local check_point = vec3:new(
            point:x() + dir.x * wall_check_distance,
            point:y() + dir.y * wall_check_distance,
            point:z()
        )
        check_point = set_height_of_valid_position(check_point)
        if not utility.is_point_walkeable(check_point) then
            return true
        end
    end
    return false
end

local function find_central_unexplored_target()
    console.print("Finding central unexplored target.")
    local player_pos = get_player_position()
    local check_radius = max_target_distance
    local unexplored_points = {}
    local min_x, max_x, min_y, max_y = math.huge, -math.huge, math.huge, -math.huge

    for x = -check_radius, check_radius, grid_size do
        for y = -check_radius, check_radius, grid_size do
            local point = vec3:new(
                player_pos:x() + x,
                player_pos:y() + y,
                player_pos:z()
            )

            point = set_height_of_valid_position(point)

            if utility.is_point_walkeable(point) and not is_point_in_explored_area(point) then
                table.insert(unexplored_points, point)
                min_x = math.min(min_x, point:x())
                max_x = math.max(max_x, point:x())
                min_y = math.min(min_y, point:y())
                max_y = math.max(max_y, point:y())
            end
        end
    end

    if #unexplored_points == 0 then
        return nil
    end

    local center_x = (min_x + max_x) / 2
    local center_y = (min_y + max_y) / 2
    local center = vec3:new(center_x, center_y, player_pos:z())
    center = set_height_of_valid_position(center)

    table.sort(unexplored_points, function(a, b)
        return calculate_distance(a, center) < calculate_distance(b, center)
    end)

    return unexplored_points[1]
end

local function find_random_explored_target()
    console.print("Finding random explored target.")
    local player_pos = get_player_position()
    local check_radius = max_target_distance
    local explored_points = {}

    for x = -check_radius, check_radius, grid_size do
        for y = -check_radius, check_radius, grid_size do
            local point = vec3:new(
                player_pos:x() + x,
                player_pos:y() + y,
                player_pos:z()
            )
            point = set_height_of_valid_position(point)
            local grid_key = get_grid_key(point)
            if utility.is_point_walkeable(point) and explored_areas[grid_key] and not is_near_wall(point) then
                table.insert(explored_points, point)
            end
        end
    end

    if #explored_points == 0 then
        return nil
    end

    return explored_points[math.random(#explored_points)]
end

function vec3.__add(v1, v2)
    --console.print("Adding two vectors.")
    return vec3:new(v1:x() + v2:x(), v1:y() + v2:y(), v1:z() + v2:z())
end

local function is_in_last_targets(point)
    --console.print("Checking if point is in last targets.")
    for _, target in ipairs(last_explored_targets) do
        if calculate_distance(point, target) < grid_size * 2 then
            return true
        end
    end
    return false
end

local function add_to_last_targets(point)
   --console.print("Adding point to last targets.")
    table.insert(last_explored_targets, 1, point)
    if #last_explored_targets > max_last_targets then
        table.remove(last_explored_targets)
    end
end

local function find_explored_direction_target()
    console.print("Finding explored direction target.")
    local player_pos = get_player_position()
    local max_attempts = 200
    local attempts = 0
    local best_target = nil
    local best_distance = 0

    while attempts < max_attempts do
        local direction_vector = vec3:new(
            exploration_direction.x * max_target_distance * 0.5 ,
            exploration_direction.y * max_target_distance * 0.5,
            0
        )
        local target_point = player_pos + direction_vector
        target_point = set_height_of_valid_position(target_point)

        if utility.is_point_walkeable(target_point) and is_point_in_explored_area(target_point) then
            local distance = calculate_distance(player_pos, target_point)
            if distance > best_distance and not is_in_last_targets(target_point) then
                best_target = target_point
                best_distance = distance
            end
        end

        -- Ändere die Richtung leicht
        local angle = math.atan2(exploration_direction.y, exploration_direction.x) + math.random() * math.pi / 2 - math.pi / 4
        exploration_direction.x = math.cos(angle)
        exploration_direction.y = math.sin(angle)
        attempts = attempts + 1
    end

    if best_target then
        add_to_last_targets(best_target)
        return best_target
    end

    console.print("Could not find a valid explored target after " .. max_attempts .. " attempts.")
    return nil
end

local function find_unstuck_target()
    console.print("Finding unstuck target.")
    local player_pos = get_player_position()
    local valid_targets = {}

    for x = -unstuck_target_distance, unstuck_target_distance, grid_size do
        for y = -unstuck_target_distance, unstuck_target_distance, grid_size do
            local point = vec3:new(
                player_pos:x() + x,
                player_pos:y() + y,
                player_pos:z()
            )
            point = set_height_of_valid_position(point)

            local distance = calculate_distance(player_pos, point)
            if utility.is_point_walkeable(point) and distance >= 2 and distance <= unstuck_target_distance then
                table.insert(valid_targets, point)
            end
        end
    end

    if #valid_targets > 0 then
        return valid_targets[math.random(#valid_targets)]
    end

    return nil
end

local function find_target(include_explored)
    console.print("Finding target.")
    last_movement_direction = nil -- Reset the last movement direction

    if include_explored then
        return find_unstuck_target()
    else
        if exploration_mode == "unexplored" then
            local unexplored_target = find_central_unexplored_target()
            if unexplored_target then
                return unexplored_target
            else
                exploration_mode = "explored"
                console.print("No unexplored areas found. Switching to explored mode.")
                last_explored_targets = {} -- Reset last targets when switching modes
            end
        end
        
        if exploration_mode == "explored" then
            local explored_target = find_explored_direction_target()
            if explored_target then
                return explored_target
            else
                console.print("No valid explored targets found. Resetting exploration.")
                reset_exploration()
                exploration_mode = "unexplored"
                return find_central_unexplored_target()
            end
        end
    end
    
    return nil
end

-- A* pathfinding functions
local function heuristic(a, b)
    --console.print("Calculating heuristic.")
    return calculate_distance(a, b)
end

local function get_neighbors(point)
    local neighbors = {}
    local directions = {
        { x = 1.2, y = 0 }, { x = -1.2, y = 0 }, { x = 0, y = 1.2 }, { x = 0, y = -1.2 },
        { x = 1.2, y = 1.2 }, { x = 1.2, y = -1.2 }, { x = -1.2, y = 1.2 }, { x = -1.2, y = -1.2 }
    }
    
    for _, dir in ipairs(directions) do
        local neighbor = vec3:new(
            point:x() + dir.x * grid_size,
            point:y() + dir.y * grid_size,
            point:z()
        )
        neighbor = set_height_of_valid_position(neighbor)
        if utility.is_point_walkeable(neighbor) then
            if not last_movement_direction or
                (dir.x ~= -last_movement_direction.x or dir.y ~= -last_movement_direction.y) then

                table.insert(neighbors, neighbor)
            end
        end
    end
    
    -- Wenn keine anderen Optionen verfügbar sind, fügen Sie die entgegengesetzte Richtung hinzu
    if #neighbors == 0 and last_movement_direction then
        local back_direction = vec3:new(
            point:x() - last_movement_direction.x * grid_size,
            point:y() - last_movement_direction.y * grid_size,
            point:z()
        )
        back_direction = set_height_of_valid_position(back_direction)
        if utility.is_point_walkeable(back_direction) then
            table.insert(neighbors, back_direction)
        end
    end
    
    return neighbors
end

local function reconstruct_path(came_from, current)
    local path = { current }
    while came_from[get_grid_key(current)] do
        current = came_from[get_grid_key(current)]
        table.insert(path, 1, current)
    end

    -- Filter points with a less aggressive approach
    local filtered_path = { path[1] }
    for i = 2, #path - 1 do
        local prev = path[i - 1]
        local curr = path[i]
        local next = path[i + 1]

        local dir1 = { x = curr:x() - prev:x(), y = curr:y() - prev:y() }
        local dir2 = { x = next:x() - curr:x(), y = next:y() - curr:y() }

        -- Calculate the angle between directions
        local dot_product = dir1.x * dir2.x + dir1.y * dir2.y
        local magnitude1 = math.sqrt(dir1.x^2 + dir1.y^2)
        local magnitude2 = math.sqrt(dir2.x^2 + dir2.y^2)
        local angle = math.acos(dot_product / (magnitude1 * magnitude2))

        -- Keep points if the angle is greater than a threshold (e.g., 15 degrees)
        if angle > math.rad(40) then
            table.insert(filtered_path, curr)
        end
    end
    table.insert(filtered_path, path[#path])

    return filtered_path
end

local function a_star(start, goal)
    --console.print("Starting A* pathfinding.")
    local closed_set = {}
    local came_from = {}
    local g_score = { [get_grid_key(start)] = 0 }
    local f_score = { [get_grid_key(start)] = heuristic(start, goal) }
    local iterations = 0

    local open_set = MinHeap.new(function(a, b)
        return f_score[get_grid_key(a)] < f_score[get_grid_key(b)] -- Does that work?
    end)
    open_set:push(start)

    while not open_set:empty() do
        iterations = iterations + 1
        if iterations > 6666 then
            console.print("Max iterations reached, aborting!")
            break
        end

        local current = open_set:pop()
        if calculate_distance(current, goal) < grid_size then
            max_target_distance = target_distance_states[1]
            target_distance_index = 1
            return reconstruct_path(came_from, current)
        end

        closed_set[get_grid_key(current)] = true

        for _, neighbor in ipairs(get_neighbors(current)) do
            if not closed_set[get_grid_key(neighbor)] then
                local tentative_g_score = g_score[get_grid_key(current)] + calculate_distance(current, neighbor)

                if not g_score[get_grid_key(neighbor)] or tentative_g_score < g_score[get_grid_key(neighbor)] then
                    came_from[get_grid_key(neighbor)] = current
                    g_score[get_grid_key(neighbor)] = tentative_g_score
                    f_score[get_grid_key(neighbor)] = g_score[get_grid_key(neighbor)] + heuristic(neighbor, goal)

                    if not open_set:contains(neighbor) then
                        open_set:push(neighbor)
                    end
                end
            end
        end
    end

    if target_distance_index < #target_distance_states then
        target_distance_index = target_distance_index + 1
        max_target_distance = target_distance_states[target_distance_index]
        console.print("No path found. Reducing max target distance to " .. max_target_distance)
    else
        console.print("No path found even after reducing max target distance.")
    end

    return nil
end

local last_a_star_call = 0.0
local function smooth_path(path, smoothness)
    if #path < 3 then return path end
    
    local smoothed_path = {path[1]}
    for i = 2, #path - 1 do
        local prev = smoothed_path[#smoothed_path]
        local curr = path[i]
        local next = path[i + 1]
        
        local smooth_x = prev:x() * (1 - smoothness) + curr:x() * smoothness
        local smooth_y = prev:y() * (1 - smoothness) + curr:y() * smoothness
        local smooth_z = prev:z() * (1 - smoothness) + curr:z() * smoothness
        
        table.insert(smoothed_path, vec3:new(smooth_x, smooth_y, smooth_z))
    end
    table.insert(smoothed_path, path[#path])
    
    return smoothed_path
end

local path_recalculation_interval = 5.0  -- Recalculate path every 1 second
local last_path_calculation_time = 0

local function move_to_target()
    if target_position then
        local player_pos = get_player_position()
        local current_time = os.clock()

        if calculate_distance(player_pos, target_position) > 500 then
            target_position = nil
            current_path = {}
            path_index = 1
            return
        end

        if not current_path or #current_path == 0 or path_index > #current_path or 
           (current_time - last_path_calculation_time > path_recalculation_interval) then
            path_index = 1
            local raw_path = a_star(player_pos, target_position)
            if raw_path then
                current_path = smooth_path(raw_path, 0.5)
            else
                console.print("No path found to target. Disabling explorer.")
                disable()
                return
            end
            last_path_calculation_time = current_time
        end

        local next_point = current_path[path_index+1]
        if next_point and not next_point:is_zero() then
            pathfinder.request_move(next_point)
        end

        if next_point and next_point.x and not next_point:is_zero() and calculate_distance(player_pos, next_point) < grid_size then
            local direction = {
                x = next_point:x() - player_pos:x(),
                y = next_point:y() - player_pos:y()
            }
            last_movement_direction = direction
            path_index = path_index + 1
        end

        if calculate_distance(player_pos, target_position) < 2 then
            mark_area_as_explored(player_pos, exploration_radius)
            disable()
        end
    end
end

local function check_if_stuck()
    --console.print("Checking if character is stuck.")
    local current_pos = get_player_position()
    local current_time = os.time()
    
    if last_position and calculate_distance(current_pos, last_position) < 2 then -- estava 0.1 aumentei para 2
        if current_time - last_move_time > stuck_threshold then
            return true
        end
    else
        last_move_time = current_time
    end
    
    last_position = current_pos
    
    return false
end

on_update(function()
    if enabled then
        if os.clock() - start_time < min_duration then
            check_walkable_area()
            local is_stuck = check_if_stuck()
            
            if is_stuck then
                console.print("Character was stuck. Finding new target.")
                target_position = find_target(true)
                target_position = set_height_of_valid_position(target_position)
                last_move_time = os.time()
                current_path = {}
                path_index = 1
            end
            
            move_to_target()
        else
            if is_target_reached() then
                disable()
            else
                check_walkable_area()
                local is_stuck = check_if_stuck()
                
                if is_stuck then
                    console.print("Character was stuck. Finding new target.")
                    target_position = find_target(true)
                    target_position = set_height_of_valid_position(target_position)
                    last_move_time = os.time()
                    current_path = {}
                    path_index = 1
                end
                
                move_to_target()
            end
        end
    end
end)
       
local render_buffer = {}
local last_render_time = 0
local render_interval = 1/1  -- 1 FPS

on_render(function()
    local current_time = os.clock()
    if current_time - last_render_time < render_interval then
        -- Render from buffer
        for _, item in ipairs(render_buffer) do
            if item.position.z then  -- Check if it's a vec3
                graphics.text_3d(item.text, item.position, item.size, item.color)
            else  -- If it's a vec2, convert to vec3
                local player_pos = get_player_position()
                local vec3_pos = vec3:new(item.position.x, item.position.y, player_pos.z)
                graphics.text_3d(item.text, vec3_pos, item.size, item.color)
            end
        end
        return
    end
    last_render_time = current_time

    -- Clear buffer
    render_buffer = {}

    if enabled then
        if target_position then
            table.insert(render_buffer, {text = "TARGET", position = target_position, size = 20, color = color_red(255)})
        end

        if current_path then
            for i, point in ipairs(current_path) do
                local color = (i == path_index) and color_green(255) or color_yellow(255)
                table.insert(render_buffer, {text = "PATH", position = point, size = 15, color = color})
            end
        end

        -- Use vec3 for the mode text position
        --local player_pos = get_player_position()
        --local mode_text_pos = vec3:new(player_pos.x, player_pos.y, player_pos.z + 2)  -- Offset the text above the player
        --table.insert(render_buffer, {text = "Mode: " .. exploration_mode, position = mode_text_pos, size = 20, color = color_white(255)})
    end
end)

return {
    enable = enable,
    disable = disable,
    set_target = set_target,
    is_target_reached = is_target_reached,
    calculate_distance = calculate_distance,
    is_enabled = is_enabled
}
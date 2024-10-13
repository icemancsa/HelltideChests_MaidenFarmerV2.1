local menu = require("menu")
local automindcage = {}

local last_use_time = 0
local cooldown = 0.2 -- 0.2 seconds of cooldown between uses
local buff_duration = 60 * 60 -- 60 minutes in seconds
local check_interval = 59 * 1 -- verify each 59min

local function check_for_player_buff(buffs, option)
  for _, buff in ipairs(buffs) do
    if buff:name() == option then
      return true
    end
  end
  return false
end

local function use_profane_mindcage(consumable_items)
  local count = menu.profane_mindcage_slider:get()
  for _, item in ipairs(consumable_items) do
    if item:get_name() == "Helltide_ProfaneMindcage" then
      for i = 1, count do
        use_item(item)
      end
      last_use_time = os.clock()
      break
    end
  end
end

local function is_in_helltide(local_player)
  local buffs = local_player:get_buffs()
  for _, buff in ipairs(buffs) do
    if buff.name_hash == 1066539 then -- ID buff Helltide
      return true
    end
  end
  return false
end

function automindcage.update()
  local current_time = os.clock()
  
  -- seconds of cooldown between uses
  if current_time - last_use_time < check_interval then
    return
  end

  local local_player = get_local_player()

  if menu.profane_mindcage_toggle:get() then
    local player_position = get_player_position()
    local buffs = local_player:get_buffs()
    local consumable_items = local_player:get_consumable_items()

    local closest_target = target_selector.get_target_closer(player_position, 10)

    if closest_target and is_in_helltide(local_player) then
      -- checks if Profane Mindcage's buff is no active
      if not check_for_player_buff(buffs, "Helltide_ProfaneMindcageConsumable") then
        use_profane_mindcage(consumable_items)
      end
    end
  end
end

return automindcage
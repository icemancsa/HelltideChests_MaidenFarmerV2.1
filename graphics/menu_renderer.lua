local menu = require("menu")
local maidenmain = require("data.maidenmain")

local menu_renderer = {}

local function safe_render(menu_item, label, description, value)
    if type(value) == "boolean" then
        value = value and 1 or 0
    elseif type(value) ~= "number" then
        value = 0
    end
    menu_item:render(label, description, value)
end

function menu_renderer.render_menu(plugin_enabled, doorsEnabled, loopEnabled, revive_enabled, profane_mindcage_enabled, profane_mindcage_count, moveThreshold)
    if menu.main_tree:push("HellChest Farmer (EletroLuz)-V2.0") then
        safe_render(menu.plugin_enabled, "Enable Plugin Chests Farm", "Enable or disable the chest farm plugin", plugin_enabled)
        safe_render(menu.main_openDoors_enabled, "Open Chests", "Enable or disable the chest plugin", doorsEnabled)
        safe_render(menu.loop_enabled, "Enable Loop", "Enable or disable looping waypoints", loopEnabled)
        safe_render(menu.revive_enabled, "Enable Revive Module", "Enable or disable the revive module", revive_enabled)

        if menu.profane_mindcage_tree:push("Profane Mindcage Settings") then
            safe_render(menu.profane_mindcage_toggle, "Enable Profane Mindcage Auto Use", "Enable or disable automatic use of Profane Mindcage", profane_mindcage_enabled)
            safe_render(menu.profane_mindcage_slider, "Profane Mindcage Count", "Number of Profane Mindcages to use", profane_mindcage_count)
            menu.profane_mindcage_tree:pop()
        end

        if menu.move_threshold_tree:push("Chest Move Range Settings") then
            safe_render(menu.move_threshold_slider, "Move Range", "maximum distance the player can detect and move towards a chest in the game", moveThreshold)
            menu.move_threshold_tree:pop()
        end

        -- Renderize o menu do maidenmain como uma subseção
        if menu.main_tree:push("Helltide Maiden") then
            maidenmain.render_menu()
            menu.main_tree:pop()
        end

        menu.main_tree:pop()
    end
end

return menu_renderer
-- Define a etiqueta do plugin
local plugin_label = "CAMINHADOR_PLUGIN_"

-- Cria os elementos do menu
local menu_elements = 
{
    main_tree = tree_node:new(0),
    plugin_enabled = checkbox:new(false, get_hash(plugin_label .. "plugin_enabled")),
    main_openDoors_enabled = checkbox:new(false, get_hash(plugin_label .. "main_openDoors_enabled")),
    loop_enabled = checkbox:new(false, get_hash(plugin_label .. "loop_enabled")),
    --graphics_enabled = checkbox:new(false, get_hash(plugin_label .. "graphics_enabled")),
    revive_enabled = checkbox:new(false, get_hash(plugin_label .. "revive_enabled")),
        
    -- Nova subseção para Profane Mindcage
    profane_mindcage_tree = tree_node:new(1),
    profane_mindcage_toggle = checkbox:new(false, get_hash(plugin_label .. "profane_mindcage_toggle")),
    profane_mindcage_slider = slider_int:new(1, 3, 1, get_hash(plugin_label .. "_profane_mindcage_slider")),

    -- Nova subseção para Move Threshold
    move_threshold_tree = tree_node:new(2),
    move_threshold_slider = slider_int:new(12, 20, 12, get_hash(plugin_label .. "move_threshold_slider")),
}

-- Função para renderizar o menu
function render_menu()
    menu_elements.main_tree:push("Helltide Farmer (EletroLuz)-V2.0")

    -- Renderiza o checkbox para habilitar o plugin de movimento
    menu_elements.plugin_enabled:render("Enable Plugin Chests Farm", "Enable or disable the chest farm plugin")

    -- Renderiza o checkbox para habilitar o plugin de abertura de baus
    menu_elements.main_openDoors_enabled:render("Open Chests", "Enable or disable the chest plugin")

    -- Renderiza o checkbox para habilitar o loop dos waypoints
    menu_elements.loop_enabled:render("Enable Loop", "Enable or disable looping waypoints")

    -- Renderiza o checkbox para habilitar/desabilitar o módulo de revive
    menu_elements.revive_enabled:render("Enable Revive Module", "Enable or disable the revive module")

    -- Nova subseção para Profane Mindcage
    if menu_elements.profane_mindcage_tree:push("Profane Mindcage Settings") then
        menu_elements.profane_mindcage_toggle:render("Enable Profane Auto Use Mindcage", "Enable or disable automatic use of Profane Mindcage")
        menu_elements.profane_mindcage_slider:render("Profane Mindcage Count", "Number of Profane Mindcages to use")
        menu_elements.profane_mindcage_tree:pop()
    end

    -- Nova subseção para Move Threshold
    if menu_elements.move_threshold_tree:push("Chest Move Range Settings") then
        menu_elements.move_threshold_slider:render("Move Threshold", "Set Chest Max Move distance")
        menu_elements.move_threshold_tree:pop()
    end

    menu_elements.main_tree:pop()
end

-- Retorna os elementos do menu
return menu_elements
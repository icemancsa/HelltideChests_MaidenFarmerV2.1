local countdown_display = {}

local start_time = nil
local duration = nil
local countdown_active = false

-- Cores
local color_red = color.new(255, 0, 0, 255)
local color_white = color.new(255, 255, 255, 255)

function countdown_display.start_countdown(timeout_duration)
    start_time = os.clock()
    duration = timeout_duration
    countdown_active = true
end

function countdown_display.is_active()
    return countdown_active
end

function countdown_display.update_and_draw()
    if not countdown_active then return end

    local current_time = os.clock()
    local elapsed_time = current_time - start_time
    local remaining_time = duration - elapsed_time

    if remaining_time <= 0 then
        countdown_active = false
        start_time = nil
        return true -- Indica que a contagem regressiva terminou
    end

    local local_player = get_local_player()
    if not local_player then return false end

    local player_pos = local_player:get_position()
    local screen_pos = graphics.w2s(player_pos)

    if screen_pos then
        local text_pos = vec2.new(screen_pos.x - 80, screen_pos.y - 240)  -- 100 pixels acima do jogador
        
        graphics.text_2d("Teleport in:", text_pos, 30, color_white)
        
        text_pos.y = text_pos.y + 40 -- era 40
        graphics.text_2d(string.format("%.1f seconds", remaining_time), text_pos, 40, color_red)
    end

    return false -- Indica que a contagem regressiva ainda está em andamento
end

-- Função on_render para renderização gráfica
on_render(function()
    if countdown_active then
        countdown_display.update_and_draw()
    end
end)

return countdown_display
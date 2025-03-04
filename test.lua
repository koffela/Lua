-- My Monster Hunter Wilds overlay mod with red health effect
local enemy_manager = nil
local current_monster = nil
local hp = 0
local max_hp = 1000
local previous_hp = 0 -- Track HP from last frame
local red_hp = 0 -- HP to show in red
local red_timer = 0 -- Animation timer
local red_duration = 1.5 -- How long the red bar lingers (seconds)

-- Initialize
local function initialize()
    enemy_manager = sdk.get_managed_singleton("snow.enemy.EnemyManager")
    if not enemy_manager then
        log.error("Failed to initialize EnemyManager!")
    end
end

-- Update and draw every frame
local function on_frame()
    -- Fetch monster data
    if enemy_manager then
        current_monster = enemy_manager:call("getBossEnemy")
        if current_monster then
            hp = current_monster:call("getHP") or 0
            max_hp = current_monster:call("getMaxHP") or 1000
            
            -- Detect HP drop
            if hp < previous_hp then
                red_hp = previous_hp -- Set red bar to old HP
                red_timer = red_duration -- Start the timer
            end
            previous_hp = hp -- Update previous HP
        else
            hp, max_hp = 0, 1000
            previous_hp = 0
            red_hp = 0
            red_timer = 0
        end
    end

    -- Update red bar animation
    if red_timer > 0 then
        red_timer = red_timer - 0.016 -- Approx 1/60th sec per frame
        red_hp = hp + (red_hp - hp) * (red_timer / red_duration) -- Lerp to current HP
        if red_timer <= 0 then
            red_hp = hp -- Snap to current HP when done
        end
    end

    -- Draw the overlay
    imgui.begin_window("Monster Stats", true, 
        bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoBackground)
    )
    imgui.set_window_pos(50, 50)
    imgui.set_window_size(250, 150)

    -- HP Bar with red effect
    imgui.text("HP")
    -- Red bar (lost HP)
    if red_hp > hp then
        imgui.push_style_color(ImGuiCol_PlotProgressBar, 0xFFFF0000) -- Red
        imgui.progress_bar(red_hp / max_hp, 200, 20)
        imgui.pop_style_color()
    end
    -- Green bar (current HP)
    imgui.push_style_color(ImGuiCol_PlotProgressBar, 0xFF00FF00) -- Green
    imgui.progress_bar(hp / max_hp, 200, 20, string.format("%.0f/%.0f", hp, max_hp))
    imgui.pop_style_color()

    imgui.end_window()
end

-- Start the mod
initialize()
re.on_frame(on_frame)
-- My Monster Hunter Wilds overlay mod with stacking red health effect
local enemy_manager = nil
local current_monster = nil
local hp = 0
local max_hp = 1000
local previous_hp = 0
local red_hp = 0
local red_timer = 0
local red_duration = 1.5
local shrink_timer = 0 -- Separate timer for shrinking
local shrink_duration = 0.5 -- How fast red shrinks once it starts

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
            
            -- Detect damage and stack red HP
            if hp < previous_hp then
                local damage = previous_hp - hp
                red_hp = red_hp + damage
                if red_hp > max_hp then red_hp = max_hp end
                red_timer = red_duration -- Reset delay timer
                shrink_timer = 0 -- Reset shrink timer
            end
            previous_hp = hp
        else
            hp, max_hp = 0, 1000
            previous_hp = 0
            red_hp = 0
            red_timer = 0
            shrink_timer = 0
        end
    end

    -- Update timers
    if red_timer > 0 then
        red_timer = red_timer - 0.016 -- Count down delay
        if red_timer <= 0 and red_hp > hp then
            shrink_timer = shrink_duration -- Start shrinking
        end
    end
    if shrink_timer > 0 then
        shrink_timer = shrink_timer - 0.016
        red_hp = hp + (red_hp - hp) * (shrink_timer / shrink_duration)
        if shrink_timer <= 0 then
            red_hp = hp -- Snap to current HP
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
    if red_hp > hp then
        imgui.push_style_color(ImGuiCol_PlotProgressBar, 0xFFFF0000)
        imgui.progress_bar(red_hp / max_hp, 200, 20)
        imgui.pop_style_color()
    end
    imgui.push_style_color(ImGuiCol_PlotProgressBar, 0xFF00FF00)
    imgui.progress_bar(hp / max_hp, 200, 20, string.format("%.0f/%.0f", hp, max_hp))
    imgui.pop_style_color()

    imgui.end_window()
end

-- Start the mod
initialize()
re.on_frame(on_frame)
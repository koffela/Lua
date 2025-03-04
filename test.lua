-- My Monster Hunter Wilds overlay mod with layered HP bars
local enemy_manager = nil
local current_monster = nil
local hp = 0
local max_hp = 1000
local previous_hp = 0
local red_hp = 0 -- Red bar locks to HP when damage starts
local no_hit_timer = 0 -- Time since last hit
local no_hit_duration = 2.0 -- Delay before red shrinks
local shrink_timer = 0 -- Shrink animation timer
local shrink_duration = 0.5 -- How fast red shrinks
local taking_damage = false -- Flag to track damage state

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
            
            -- Detect damage
            if hp < previous_hp then
                if not taking_damage then
                    red_hp = previous_hp -- Lock red to HP when damage starts
                    taking_damage = true
                end
                no_hit_timer = no_hit_duration -- Reset delay on each hit
                shrink_timer = 0 -- Reset shrink
            end
            previous_hp = hp
        else
            hp, max_hp = 0, 1000
            previous_hp = 0
            red_hp = 0
            no_hit_timer = 0
            shrink_timer = 0
            taking_damage = false
        end
    end

    -- Update timers
    if no_hit_timer > 0 then
        no_hit_timer = no_hit_timer - 0.016 -- Count down since last hit
        if no_hit_timer <= 0 and red_hp > hp then
            shrink_timer = shrink_duration -- Start shrinking after 2s
        end
    end
    if shrink_timer > 0 then
        shrink_timer = shrink_timer - 0.016
        red_hp = hp + (red_hp - hp) * (shrink_timer / shrink_duration)
        if shrink_timer <= 0 then
            red_hp = hp -- Snap to current HP
            taking_damage = false -- Reset damage state
        end
    end

    -- Draw the overlay
    imgui.begin_window("Monster Stats", true, 
        bit.bor(ImGuiWindowFlags_NoTitleBar, ImGuiWindowFlags_NoResize, ImGuiWindowFlags_NoMove, ImGuiWindowFlags_NoBackground)
    )
    imgui.set_window_pos(50, 50)
    imgui.set_window_size(250, 100)

    -- HP Bars (layered)
    imgui.text("HP")
    -- Bottom layer: Dark grey (total missing HP)
    imgui.push_style_color(ImGuiCol_PlotProgressBar, 0xFF404040) -- Dark grey
    imgui.progress_bar(1.0, 200, 20) -- Full bar as background
    imgui.pop_style_color()
    
    -- Middle layer: Red (damage ghost)
    if red_hp > hp then
        imgui.push_style_color(ImGuiCol_PlotProgressBar, 0xFFFF0000) -- Red
        imgui.progress_bar(red_hp / max_hp, 200, 20)
        imgui.pop_style_color()
    end
    
    -- Top layer: Green (current HP)
    imgui.push_style_color(ImGuiCol_PlotProgressBar, 0xFF00FF00) -- Green
    imgui.progress_bar(hp / max_hp, 200, 20, string.format("%.0f/%.0f", hp, max_hp))
    imgui.pop_style_color()

    imgui.end_window()
end

-- Start the mod
initialize()
re.on_frame(on_frame)
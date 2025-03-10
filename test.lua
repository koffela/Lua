-- My Monster Hunter Wilds overlay mod with layered HP bars and adapted enemy detection
--[[
local enemy_manager = nil
local current_monster = nil
local hp = 0
local max_hp = 1000
local previous_hp = 0
local red_hp = 0
local no_hit_timer = 0
local no_hit_duration = 1.5 -- Reduced to 1.5 seconds to test shorter duration
local shrink_timer = 0
local shrink_duration = 0.5 -- Duration to shrink damage bar (seconds)
local taking_damage = false
local damage_cooldown = 0 -- Cooldown to prevent rapid retriggering
local cooldown_duration = 0.5 -- 0.5 seconds cooldown
local debug_logged = false
local enemy_contexts = {}

-- Utility function adapted from CatLib
local function ForEach(list, func)
    if list == nil then return end
    local get_Count = list.get_Count
    local get_Item = list.get_Item
    if not get_Count or not get_Item then return end
    local len = get_Count:call(list)
    for i = 0, len - 1, 1 do
        local item = get_Item:call(list, i)
        local ret = func(item, i, len)
        if ret == -1 then break end
    end
end

-- Initialize with retry and debug
local function initialize()
    enemy_manager = sdk.get_managed_singleton("app.EnemyManager")
    if not enemy_manager and not debug_logged then
        log.info("Trying to initialize app.EnemyManager...")
        debug_logged = true
    elseif enemy_manager then
        log.info("Successfully initialized app.EnemyManager")
    end
end

-- Update enemy contexts (adapted from _M.OnQuestPlaying)
local function update_enemy_contexts()
    local mission_manager = sdk.get_managed_singleton("app.MissionManager")
    if mission_manager then
        local browsers = mission_manager:call("getAcceptQuestTargetBrowsers")
        if browsers then
            enemy_contexts = {}
            ForEach(browsers, function(browser)
                local ctx = browser:call("get_EmContext")
                if ctx then
                    table.insert(enemy_contexts, ctx)
                end
            end)
        else
            enemy_contexts = {}
        end
    else
        enemy_contexts = {}
    end
end

-- Get HP from an enemy context (adapted from _M.doUpdateEnemyCtx)
local function get_enemy_hp(ctx)
    if not ctx then return 0, 1000 end
    local parts = sdk.find_type_definition("app.cEnemyContext"):get_field("Parts"):get_data(ctx)
    if parts then
        local damage_parts = sdk.find_type_definition("app.cEmModuleParts"):get_field("_DmgParts"):get_data(parts)
        if damage_parts then
            local get_Value = sdk.find_type_definition("app.cValueHolderF_R"):get_method("get_Value()")
            local get_DefaultValue = sdk.find_type_definition("app.cValueHolderF_R"):get_method("get_DefaultValue()")
            ForEach(damage_parts, function(part)
                if part then
                    local hp_value = get_Value:call(part) or 0
                    local max_hp_value = get_DefaultValue:call(part) or 1000
                    if hp_value > 0 then
                        hp = hp_value
                        max_hp = max_hp_value
                        return -1 -- Break on first valid part
                    end
                end
            end)
        end
    end
    return hp, max_hp
end

-- Update and draw every frame
local function on_frame()
    if not enemy_manager then
        initialize()
        if not enemy_manager then
            enemy_manager = sdk.get_managed_singleton("app.EnemyManager")
            if not enemy_manager then
                imgui.begin_window("Monster Stats", true, 1025) -- NoTitleBar + NoBackground
                imgui.text("Waiting for app.EnemyManager...")
                imgui.end_window()
                return
            end
        end
    end

    update_enemy_contexts()
    current_monster = nil
    if #enemy_contexts > 0 then
        for _, ctx in ipairs(enemy_contexts) do
            hp, max_hp = get_enemy_hp(ctx)
            if hp > 0 then
                current_monster = ctx
                break
            end
        end
    end

    if current_monster then
        local hp_floor = math.floor(hp)
        local prev_hp_floor = math.floor(previous_hp)
        if hp_floor < prev_hp_floor and math.abs(hp_floor - prev_hp_floor) > 5 and damage_cooldown <= 0 then -- Increased threshold to 5
            if not taking_damage then
                red_hp = previous_hp
                taking_damage = true
                log.info(string.format("Damage detected: previous_hp=%d, hp=%d, red_hp=%d", prev_hp_floor, hp_floor, math.floor(red_hp)))
            end
            no_hit_timer = no_hit_duration
            shrink_timer = 0
            damage_cooldown = cooldown_duration
        end
        previous_hp = hp
        if damage_cooldown > 0 then
            damage_cooldown = damage_cooldown - 0.016
        end
        log.info(string.format("Monster HP: %d/%d", hp_floor, math.floor(max_hp)))
    else
        hp = 0
        max_hp = 1000
        previous_hp = 0
        red_hp = 0
        no_hit_timer = 0
        shrink_timer = 0
        taking_damage = false
        damage_cooldown = 0
        log.info("No boss or enemy detected")
    end

    if no_hit_timer > 0 then
        no_hit_timer = no_hit_timer - 0.016
        if no_hit_timer <= 0 and red_hp > hp then
            shrink_timer = shrink_duration
            log.info(string.format("Starting shrink: red_hp=%d, hp=%d", math.floor(red_hp), math.floor(hp)))
        end
    end
    if shrink_timer > 0 then
        shrink_timer = shrink_timer - 0.016
        red_hp = hp + (red_hp - hp) * (shrink_timer / shrink_duration)
        if shrink_timer <= 0 then
            red_hp = hp
            taking_damage = false
            log.info(string.format("Shrink complete: red_hp=%d, hp=%d", math.floor(red_hp), math.floor(hp)))
        end
    end

    -- Set size before beginning window
    imgui.set_next_window_size(400, 200)
    imgui.begin_window("Monster Stats", true, 1025) -- NoTitleBar + NoBackground

    -- Draw HP bars with layered damage
    imgui.text("HP")
    local base_y = imgui.get_cursor_pos_y()
    imgui.push_style_color(1, 0xFF404040) -- Background bar
    imgui.progress_bar(1.0, 350, 40, "", base_y) -- Full background bar
    imgui.pop_style_color()
    
    if red_hp > hp and taking_damage then
        imgui.push_style_color(1, 0xFFFF0000) -- Red damage bar
        imgui.progress_bar(math.min(red_hp / max_hp, 1.0), 350, 40, "", base_y)
        imgui.pop_style_color()
    end
    
    imgui.push_style_color(1, 0xFF00FF00) -- Green current HP bar
    imgui.progress_bar(math.min(hp / max_hp, 1.0), 350, 40, string.format("%d/%d", math.floor(hp), math.floor(max_hp)), base_y)
    imgui.pop_style_color()

    imgui.end_window()
end

-- Start the mod
initialize()
re.on_frame(on_frame)
--]]





-- Monster Hunter Wilds HP Display Mod (Minimal Text Only - Total HP Focus)
local sdk = sdk
local re = re
local imgui = imgui
local log = log

local enemy_manager = nil
local current_monster = nil
local hp = 0
local max_hp = 1000
local debug_logged = false
local enemy_contexts = {}

-- Utility function from your original
local function ForEach(list, func)
    if list == nil then return end
    local get_Count = list.get_Count
    local get_Item = list.get_Item
    if not get_Count or not get_Item then return end
    local len = get_Count:call(list)
    for i = 0, len - 1 do
        local item = get_Item:call(list, i)
        local ret = func(item, i, len)
        if ret == -1 then break end
    end
end

-- Initialize with retry
local function initialize()
    enemy_manager = sdk.get_managed_singleton("app.EnemyManager")
    if not enemy_manager and not debug_logged then
        log.info("Trying to initialize app.EnemyManager...")
        debug_logged = true
    elseif enemy_manager then
        log.info("Successfully initialized app.EnemyManager")
    end
end

-- Update enemy contexts (your working method)
local function update_enemy_contexts()
    local mission_manager = sdk.get_managed_singleton("app.MissionManager")
    if mission_manager then
        local browsers = mission_manager:call("getAcceptQuestTargetBrowsers")
        if browsers then
            enemy_contexts = {}
            ForEach(browsers, function(browser)
                local ctx = browser:call("get_EmContext")
                if ctx then
                    table.insert(enemy_contexts, ctx)
                    log.info("Found enemy context: " .. tostring(ctx))
                end
            end)
        else
            enemy_contexts = {}
            log.info("No browsers found in MissionManager")
        end
    else
        enemy_contexts = {}
        log.info("MissionManager not found")
    end
    log.info("Enemy contexts count: " .. #enemy_contexts)
end

-- Get total HP from enemy context
local function get_enemy_hp(ctx)
    if not ctx then
        log.info("No context provided to get_enemy_hp")
        return 0, 1000
    end

    -- Try Life field (from previous log)
    local life = ctx:get_field("Life")
    if life then
        local vital = life:get_field("_Vital") -- Check for nested Vital
        if not vital then
            vital = life -- Fallback to Life itself
        end

        local get_Value = sdk.find_type_definition("app.cValueHolderF_R"):get_method("get_Value()")
        local get_DefaultValue = sdk.find_type_definition("app.cValueHolderF_R"):get_method("get_DefaultValue()")
        local current_hp = get_Value:call(vital)
        local maximum_hp = get_DefaultValue:call(vital)

        if current_hp and maximum_hp then
            log.info(string.format("HP from Life: %f/%f", current_hp, maximum_hp))
            return current_hp, maximum_hp
        else
            log.info("Failed to read HP from Life/_Vital")
        end
    else
        log.info("No Life field in cEnemyContext")
    end

    -- Debug: Dump all fields to find total HP
    local type_def = ctx:get_type_definition()
    local fields = type_def:get_fields()
    log.info("Dumping cEnemyContext fields for HP search:")
    for i, field in ipairs(fields) do
        local name = field:get_name()
        local data = field:get_data(ctx)
        log.info(string.format("Field %d: %s = %s", i, name, tostring(data)))
    end

    return 0, 1000 -- Fallback until we find the right field
end

-- Update and draw every frame
local function on_frame()
    if not enemy_manager then
        initialize()
        if not enemy_manager then
            imgui.begin_window("Monster HP", true, 1025)
            imgui.text("Waiting for app.EnemyManager...")
            imgui.end_window()
            return
        end
    end

    update_enemy_contexts()
    current_monster = nil
    if #enemy_contexts > 0 then
        for _, ctx in ipairs(enemy_contexts) do
            hp, max_hp = get_enemy_hp(ctx)
            if hp > 0 then
                current_monster = ctx
                break
            end
        end
    end

    if not current_monster then
        hp = 0
        max_hp = 1000
        log.info("No valid monster detected")
    else
        log.info(string.format("Monster HP: %d/%d", math.floor(hp), math.floor(max_hp)))
    end

    -- Display HP as text only
    imgui.set_next_window_size(200, 50)
    imgui.begin_window("Monster HP", true, 1025)
    if current_monster then
        imgui.text(string.format("HP: %d/%d", math.floor(hp), math.floor(max_hp)))
    else
        imgui.text("HP: 0/1000")
    end
    imgui.end_window()
end

-- Start the mod
initialize()
re.on_frame(on_frame)




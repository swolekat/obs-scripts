-- todo make this generic so it's not reliant on coming up from the bottom

local obs = obslua

local AUDIO_NAME = 'cable a'
local AUDIO_THRESHOLD = -60
local SCENE_ITEM_NAME = 'swolebae'
local SCENE_ITEM_QUIET_POSITION = obs.vec2()
SCENE_ITEM_QUIET_POSITION.x = 0
SCENE_ITEM_QUIET_POSITION.y = 1456
local SCENE_ITEM_LOUD_POSITION = obs.vec2()
SCENE_ITEM_LOUD_POSITION.x = 0
SCENE_ITEM_LOUD_POSITION.y = 950
local FADE_TIME_IN_MILISECONDS = 2000
local ANIMATION_TIME_IN_SECONDS = 1
local VELOCITY_PER_SECOND = obs.vec2()
VELOCITY_PER_SECOND.x = (SCENE_ITEM_LOUD_POSITION.x - SCENE_ITEM_QUIET_POSITION.x)/ANIMATION_TIME_IN_SECONDS
VELOCITY_PER_SECOND.y = (SCENE_ITEM_LOUD_POSITION.y - SCENE_ITEM_QUIET_POSITION.y)/ANIMATION_TIME_IN_SECONDS

-- todo switch this on/off based on audio source
local audio_is_playing = false
local scene_item = nil
local audio_scene_item = nil
local fade_time_balance = 0

function find_scene_item()
    print('calling find_scene_item')
    local source = obs.obs_frontend_get_current_scene()
    if not source then
        print('there is no current scene')
        return
    end
    local scene = obs.obs_scene_from_source(source)
    obs.obs_source_release(source)
    scene_item = obs.obs_scene_find_source(scene, SCENE_ITEM_NAME)
    --audio_scene_item = obs.obs_scene_find_source(scene, AUDIO_NAME)
    if scene_item then
        return true
    end
    print(source_name..' not found')
    return false
end

function calculate_audio_level(param, source, data, muted)
    if (muted) then
        return nil
    end
    local numberOfSamples = data.frames
    local samples = data.data[0]
    if not samples then
        return nil
    end
    local sum = 0
    for i=0,samples,1
    do
        local sample = samples[i]
        sum = sum + (sample * sample)
    end
    local audioLevel = obs.obs_mul_to_db(math.sqrt(sum / numberOfSamples))
    audio_is_playing = audioLevel > AUDIO_THRESHOLD
    return source
end

function set_up_audio_listener()
    local audio_source = obs.obs_get_source_by_name(AUDIO_NAME)
    obs.obs_source_release(audio_source);
    -- todo this doesn't work
    obs.obs_source_add_audio_capture_callback(audio_source, calculate_audio_level, nil);
end

function get_source_position(source)
    local pos = obs.vec2()
    obs.obs_sceneitem_get_pos(source, pos)
    return pos
end

function source_item_is_at_top(source_position)
    return source_position.x == SCENE_ITEM_LOUD_POSITION.x and source_position.y == SCENE_ITEM_LOUD_POSITION.y
end

function source_item_is_at_bottom(source_position)
    return source_position.x == SCENE_ITEM_QUIET_POSITION.x and source_position.y == SCENE_ITEM_QUIET_POSITION.y
end

function get_amount_to_move(seconds)
    local amount_to_move = obs.vec2()
    amount_to_move.x = VELOCITY_PER_SECOND.x * seconds
    amount_to_move.y = VELOCITY_PER_SECOND.y * seconds
    return amount_to_move
end

function move_up(source_position, amount_to_move)
    local new_position = obs.vec2();
    new_position.x = math.floor(source_position.x + amount_to_move.x)
    new_position.y = math.floor(source_position.y + amount_to_move.y)
    -- todo generic here
    if(new_position.x < SCENE_ITEM_LOUD_POSITION.x)then
        new_position.x = SCENE_ITEM_LOUD_POSITION.x
    end
    -- todo generic here
    if(new_position.y < SCENE_ITEM_LOUD_POSITION.y) then
        new_position.y = SCENE_ITEM_LOUD_POSITION.y
    end
    obs.obs_sceneitem_set_pos(scene_item, new_position)
    end

function move_down(source_position, amount_to_move)
    local new_position = obs.vec2();
    new_position.x = math.floor(source_position.x - amount_to_move.x)
    new_position.y = math.floor(source_position.y - amount_to_move.y)
    -- todo generic here
    if(new_position.x > SCENE_ITEM_QUIET_POSITION.x)then
        new_position.x = SCENE_ITEM_QUIET_POSITION.x
    end
    -- todo generic here
    if(new_position.y > SCENE_ITEM_QUIET_POSITION.y) then
        new_position.y = SCENE_ITEM_QUIET_POSITION.y
    end
    obs.obs_sceneitem_set_pos(scene_item, new_position)
end

function script_tick(seconds)
    if (scene_item == nil) then
        print("could not find scene " .. SCENE_ITEM_NAME)
        return nil
    end
    local source_position = get_source_position(scene_item)
    local at_top = source_item_is_at_top(source_position)
    local at_bottom = source_item_is_at_bottom(source_position)
    local amount_to_move = get_amount_to_move(seconds)
    if audio_is_playing and not at_top then
        move_up(source_position, amount_to_move)
    end
    if not audio_is_playing and not at_bottom then
        move_down(source_position, amount_to_move)
    end
end

function script_load()
    print('script load called')
    find_scene_item()
    set_up_audio_listener()
end

-- todo unload and drop off memory handler
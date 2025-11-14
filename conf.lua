-- Configuration file for LÖVE Potion
-- This file is loaded before main.lua

function love.conf(t)
    -- Game identity
    t.identity = "3ds-project"
    t.version = "11.4"  -- LÖVE Potion version compatibility
    
    -- Window settings (for 3DS screens)
    t.window.title = "3DS Game Project"
    
    -- Console settings for 3DS
    t.console = false  -- Set to true for debugging
    
    -- Modules to enable/disable
    t.modules.audio = true
    t.modules.data = true
    t.modules.event = true
    t.modules.font = true
    t.modules.graphics = true
    t.modules.image = true
    t.modules.joystick = true
    t.modules.keyboard = false  -- Not used on 3DS
    t.modules.math = true
    t.modules.mouse = false     -- Not used on 3DS
    t.modules.physics = true
    t.modules.sound = true
    t.modules.system = true
    t.modules.thread = true
    t.modules.timer = true
    t.modules.touch = true      -- For touchscreen support
    t.modules.video = false
    t.modules.window = true
end

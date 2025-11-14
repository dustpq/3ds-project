-- Main entry point for the 3DS game
-- This file is called by LÖVE Potion

function love.load()
    -- Initialize game state
    love.graphics.setDefaultFilter("nearest", "nearest")
    
    -- Game variables
    gameTitle = "3DS Game Project"
    x, y = 200, 120
end

function love.update(dt)
    -- Update game logic here
    -- dt is the time since last update in seconds
end

function love.draw()
    -- Clear screen
    love.graphics.clear()
    
    -- Draw to top screen (3DS has dual screens)
    love.graphics.setScreen("top")
    love.graphics.print(gameTitle, 10, 10)
    love.graphics.print("Top Screen (400x240)", 10, 30)
    love.graphics.circle("fill", x, y, 20)
    
    -- Draw to bottom screen
    love.graphics.setScreen("bottom")
    love.graphics.print("Bottom Screen (320x240)", 10, 10)
    love.graphics.print("Press START to exit", 10, 30)
end

function love.gamepadpressed(joystick, button)
    -- Handle button input
    if button == "start" then
        love.event.quit()
    end
end

# 3DS Game Project

A Nintendo 3DS game project using LÖVE Potion and Lovebrew.

## Project Structure

```
3ds-project/
├── main.lua          # Main entry point for your game
├── conf.lua          # LÖVE Potion configuration
├── graphics/         # Image assets (PNG, JPG, etc.)
├── audio/            # Sound and music files (OGG, WAV, MP3)
├── fonts/            # Custom font files (TTF, OTF)
├── libs/             # Third-party Lua libraries
└── .gitignore        # Git ignore file for build artifacts
```

## Prerequisites

1. **Install Lovebrew**: Follow the installation instructions at [lovebrew.org](https://lovebrew.org)
2. **devkitPro**: Lovebrew requires devkitARM for 3DS development
3. **Citra Emulator** (optional): For testing without physical hardware

## Getting Started

### Installation

Install Lovebrew following the official guide:
```bash
# On Linux/macOS
curl -s https://raw.githubusercontent.com/lovebrew/lovebrew/main/install | sh

# On Windows (PowerShell)
iwr https://raw.githubusercontent.com/lovebrew/lovebrew/main/install.ps1 -useb | iex
```

### Building Your Game

Build the project for 3DS:
```bash
lovebrew build 3ds
```

This will create a `.3dsx` file in the build directory that can be run on your 3DS.

### Running on Hardware

1. Copy the generated `.3dsx` file to your SD card's `/3ds/` folder
2. Launch the Homebrew Launcher on your 3DS
3. Select and run your game

### Running on Emulator (Citra)

```bash
citra-qt build/your-game.3dsx
```

## Development

### Main Files

- **main.lua**: Contains the main game loop with `love.load()`, `love.update()`, and `love.draw()`
- **conf.lua**: Configuration for your game (title, modules, settings)

### 3DS-Specific Features

The 3DS has unique features you can use:
- **Dual Screens**: Top screen (400x240) and bottom screen (320x240)
- **Touch Input**: Bottom screen supports touch
- **Physical Buttons**: A, B, X, Y, L, R, Start, Select, D-pad
- **Circle Pad**: Analog stick input

### Example: Drawing to Both Screens

```lua
function love.draw()
    -- Draw to top screen
    love.graphics.setScreen("top")
    love.graphics.print("Top Screen", 10, 10)
    
    -- Draw to bottom screen
    love.graphics.setScreen("bottom")
    love.graphics.print("Bottom Screen (Touch)", 10, 10)
end
```

### Example: Handling Input

```lua
function love.gamepadpressed(joystick, button)
    if button == "a" then
        -- Handle A button press
    end
    if button == "start" then
        love.event.quit()
    end
end
```

## Resources

- [LÖVE Potion Documentation](https://github.com/lovebrew/lovepotion)
- [Lovebrew Official Site](https://lovebrew.org)
- [LÖVE Wiki](https://love2d.org/wiki/Main_Page) - Most APIs are compatible
- [3DS Homebrew Guide](https://3ds.hacks.guide/)

## License

This project template is provided as-is for game development on Nintendo 3DS.
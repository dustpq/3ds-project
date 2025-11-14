# Audio

Place your audio assets here (.ogg, .wav, .mp3)

Example usage in your game:
```lua
local music = love.audio.newSource("audio/bgm.ogg", "stream")
music:play()

local sfx = love.audio.newSource("audio/jump.wav", "static")
sfx:play()
```

-- Slowfo
-- 1.0.0 @markeats
--
-- Generate slow sine waves
-- over MIDI.
--

local UI = require "ui"

local SCREEN_FRAMERATE = 15
local screen_refresh_clock
local screen_dirty = true

local lfo_clocks = {}
local lfo_sliders = {}
local lfo_resolution = 128 -- MIDI CC resolution

local midi_out_device
local midi_out_channel


-- Clock
local function tick(id, time)
  while true do
    clock.sync(time)
    screen_dirty = true
    print(id, "Tick")
  end
end

local function start_clocks()
  local freq = 2
  for i = 1, 8 do
    lfo_clocks[i] = clock.run(i, tick, 1 / freq / lfo_resolution)
  end
end

-- Encoder input
function enc(n, delta)

end

-- Key input
function key(n, z)

end


function init()
  midi_out_device = midi.connect(1)

  -- TODO update to clock
  local screen_refresh_metro = metro.init()
  screen_refresh_metro.event = function()
    if screen_dirty then
      screen_dirty = false
      redraw()
    end
  end

  -- Add params

  params:add {
    type = "number",
    id = "midi_out_device",
    name = "MIDI Out Device",
    min = 1,
    max = 4,
    default = 1,
    action = function(value)
      midi_out_device = midi.connect(value)
    end
  }

  params:add {
    type = "number",
    id = "midi_out_channel",
    name = "MIDI Out Channel",
    min = 1,
    max = 16,
    default = 1,
    action = function(value)
      all_notes_kill()
      midi_out_channel = value
    end
  }

  midi_out_channel = params:get("midi_out_channel")

  start_clocks()

end


function redraw()
  screen.clear()

  screen.move(10, 10)
  screen.text("Slowfo")
  screen.level(15)
  screen.fill()

  screen.update()
end

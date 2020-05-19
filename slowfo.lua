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

local NUM_LFOS = 8
local LFO_RESOLUTION = 128 -- MIDI CC resolution
local lfo_freqs = {}
local lfo_progress = {}
local lfo_values = {}

local midi_out_device
local midi_out_channel


-- Clock
local function tick(time)
  while true do
    for i = 1, NUM_LFOS do
      lfo_progress[i] = lfo_progress[i] + 2 * math.pi * (1 / lfo_freqs[i]) --TODO?
      local value = math.sin(lfo_progress[i])
      if value ~= lfo_values[i] then
        lfo_values[i] = value
        print(i, "Tick", value) --TODO only fire if value has changed
      end
    end
    screen_dirty = true
    clock.sleep(time)
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

  for i = 1, NUM_LFOS do
    lfo_freqs[i] = 0.5
    lfo_progress[i] = 0
  end

  local lfo_max_freq = 0.5 --TODO controlspec
  clock.run(i, tick, 1 / lfo_max_freq / LFO_RESOLUTION)

end


function redraw()
  screen.clear()

  screen.move(10, 10)
  screen.text("Slowfo 1" .. lfo_values[1])
  screen.level(15)
  screen.fill()

  -- TODO draw some sliders/rects

  screen.update()
end

-- Changes
-- 1.0.0 @markeats
--
-- Eight connected sine waves
-- over MIDI.
--
-- E2 : Left time
-- E3 : Right time
-- K2 : Reset phase
--

local ControlSpec = require "controlspec"
local Formatters = require "formatters"

local SCREEN_FRAMERATE = 15
local screen_dirty = true

local NUM_LFOS = 8
local LFO_MIN_TIME = 1 -- Secs
local LFO_MAX_TIME = 60 * 60 * 24
local LFO_UPDATE_FREQ = 256
local LFO_RESOLUTION = 128 -- MIDI CC resolution

local lfo_freqs = {}
local lfo_progress = {}
local lfo_values = {}

local midi_out_device
local midi_out_channel


local specs = {}
specs.TIME_L = ControlSpec.new(LFO_MIN_TIME, LFO_MAX_TIME, "exp", 0, 4, "s")
specs.TIME_R = ControlSpec.new(LFO_MIN_TIME, LFO_MAX_TIME, "exp", 0, 300, "s")

local function reset_phase()
  for i = 1, NUM_LFOS do
    lfo_progress[i] = math.pi * 1.5
  end
end

local function update_freqs()
  for i = 1, NUM_LFOS do
    lfo_freqs[i] = util.linlin(1, NUM_LFOS, 1 / params:get("time_l"), 1 / params:get("time_r"), i)
  end
end


-- Metro callbacks

local function lfo_update()
  local delta = (1 / LFO_UPDATE_FREQ) * 2 * math.pi
  for i = 1, NUM_LFOS do
    lfo_progress[i] = lfo_progress[i] + delta * lfo_freqs[i]
    local value = util.round(util.linlin(-1, 1, 0, LFO_RESOLUTION - 1, math.sin(lfo_progress[i])))
    if value ~= lfo_values[i] then
      lfo_values[i] = value
      midi_out_device:cc(i - 1 + params:get("midi_cc_start"), value, midi_out_channel)
      screen_dirty = true
    end
  end
end

local function screen_update()
  if screen_dirty then
    screen_dirty = false
    redraw()
  end
end


-- Encoder input
function enc(n, delta)
  if n == 2 then
    params:delta("time_l", delta * 0.1)
  elseif n == 3 then
    params:delta("time_r", delta * 0.1)
  end
end

-- Key input
function key(n, z)
  if z == 1 then
    if n == 2 then
      reset_phase()
    end
  end
end


function init()
  midi_out_device = midi.connect(1)

  -- Add params
  
  params:add_separator()

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
      midi_out_channel = value
    end
  }

  params:add {
    type = "number",
    id = "midi_cc_start",
    name = "MIDI CC Range",
    min = 0,
    max = 128 - NUM_LFOS,
    default = 1,
    formatter = function(param)
      return param:get() .. "-" .. param:get() + NUM_LFOS - 1
    end
  }

  params:add_separator("LFOs")

  params:add {
    type = "control",
    id = "time_l",
    name = "Left Time",
    controlspec = specs.TIME_L,
    formatter = Formatters.format_secs,
    action = function(value)
      update_freqs()
      screen_dirty = true
    end
  }

  params:add {
    type = "control",
    id = "time_r",
    name = "Right Time",
    controlspec = specs.TIME_R,
    formatter = Formatters.format_secs,
    action = function(value)
      update_freqs()
      screen_dirty = true
    end
  }

  midi_out_channel = params:get("midi_out_channel")

  reset_phase()
  update_freqs()
  lfo_update()
  
  metro.init(lfo_update, 1 / LFO_UPDATE_FREQ):start()
  metro.init(screen_update, 1 / SCREEN_FRAMERATE):start()

end


function redraw()
  screen.clear()

  local BAR_W, BAR_H = 1, 41
  local MARGIN_H, MARGIN_V = 6, 6
  local gutter = (128 - MARGIN_H * 2 - BAR_W * NUM_LFOS) / (NUM_LFOS - 1)

  -- Draw bars
  for i = 1, NUM_LFOS do
    local row_x = MARGIN_H + (gutter + BAR_W) * (i - 1)

    -- Dotted
    for y = 0, BAR_H - 1, 2 do
      screen.rect(row_x, MARGIN_V + y, BAR_W, 1)
      screen.level(1)
      screen.fill()
    end

    -- Fills
    local filled_height = util.linlin(0, LFO_RESOLUTION - 1, 0, BAR_H, lfo_values[i])
    screen.rect(row_x, MARGIN_V + BAR_H - filled_height, BAR_W, filled_height)
    screen.level(15)
    screen.fill()
  end

  -- Draw text
  screen.level(3)
  screen.move(MARGIN_H, 64 - 5)
  screen.text("\u{25C0} " .. params:string("time_l"))
  screen.move(128 - MARGIN_H, 64 - 5)
  screen.text_right(params:string("time_r") .. " \u{25B6}")
  screen.fill()

  screen.update()
end

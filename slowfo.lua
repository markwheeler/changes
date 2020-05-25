-- Slowfo
-- 1.0.0 @markeats
--
-- Generate slow sine waves
-- over MIDI.
--
-- E2 : Low freq
-- E3 : High freq
-- K2 : Reset phase
--

local ControlSpec = require "controlspec"

local SCREEN_FRAMERATE = 15
local screen_dirty = true

local NUM_LFOS = 8
local LFO_RESOLUTION = 128 -- MIDI CC resolution
local LFO_MIN_FREQ = 1 / 60 / 60 / 24 -- 24hrs
local LFO_MAX_FREQ = 0.5 -- 2 secs
local lfo_freqs = {}
local lfo_progress = {}
local lfo_values = {}

local midi_out_device
local midi_out_channel


local specs = {}
specs.FREQ_L = ControlSpec.new(LFO_MIN_FREQ, LFO_MAX_FREQ, "exp", 0, 0.001, "Hz")
specs.FREQ_R = ControlSpec.new(LFO_MIN_FREQ, LFO_MAX_FREQ, "exp", 0, 0.1, "Hz")


local function format_freq_to_time(param)
  local secs = 1 / param:get()
  local out_string
  if secs > 3600 then
    out_string = util.round(secs / 60 / 60, 0.1) .. " hrs"
  elseif secs > 120 then
    out_string = util.round(secs / 60, 0.1) .. " mins"
  elseif secs > 60 then
    out_string = util.round(secs) .. " secs"
  else
    out_string = util.round(secs, 0.1) .. " secs"
  end
  return out_string
end

local function reset_phase()
  for i = 1, NUM_LFOS do
    lfo_progress[i] = 0
  end
end

local function update_freqs()
  for i = 1, NUM_LFOS do
    lfo_freqs[i] = util.linlin(1, NUM_LFOS, params:get("freq_l"), params:get("freq_r"), i)
  end
end


-- Clock callbacks

local function lfo_tick()
  while true do
    local time = util.time()
    for i = 1, NUM_LFOS do
      -- TODO switch method here to use progress properly
      lfo_progress[i] = time * 2 * math.pi * lfo_freqs[i]
      local value = util.linlin(-1, 1, 0, LFO_RESOLUTION - 1, math.sin(lfo_progress[i]))
      if value ~= lfo_values[i] then
        lfo_values[i] = value
        midi_out_device:cc(i, value, midi_out_channel)
        -- print(i, "Tick", value) --TODO
      end
    end
    screen_dirty = true

    clock.sleep(1 / LFO_MAX_FREQ / LFO_RESOLUTION)
  end
end

local function screen_tick()
  while true do
    -- print("screen tick", util.time())
    if screen_dirty then
      screen_dirty = false
      redraw()
    end
    clock.sleep(1 / SCREEN_FRAMERATE)
  end
end


-- Encoder input
function enc(n, delta)
  if n == 2 then
    params:delta("freq_l", delta * -0.1)
  elseif n == 3 then
    params:delta("freq_r", delta * -0.1)
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
      all_notes_kill()
      midi_out_channel = value
    end
  }

  params:add_separator("LFOs")

  params:add {
    type = "control",
    id = "freq_l",
    name = "Left Freq",
    controlspec = specs.FREQ_L,
    formatter = format_freq_to_time,
    action = function(value)
      update_freqs()
    end
  }

  params:add {
    type = "control",
    id = "freq_r",
    name = "Right Freq",
    controlspec = specs.FREQ_R,
    formatter = format_freq_to_time,
    action = function(value)
      update_freqs()
    end
  }

  midi_out_channel = params:get("midi_out_channel")

  reset_phase()
  update_freqs()
  
  clock.run(lfo_tick)
  clock.run(screen_tick)
end


function redraw()
  screen.clear()

  local BAR_W, BAR_H = 1, 40
  local MARGIN_H, MARGIN_V = 6, 6
  local gutter = (128 - MARGIN_H * 2 - BAR_W * NUM_LFOS) / (NUM_LFOS - 1)

  -- Draw bars
  for i = 1, NUM_LFOS do
    local row_x = MARGIN_H + (gutter + BAR_W) * (i - 1)
    screen.rect(row_x, MARGIN_V, BAR_W, BAR_H)
    screen.level(1)
    screen.fill()
    local filled_height = util.linlin(0, LFO_RESOLUTION - 1, 0, BAR_H, lfo_values[i])
    screen.rect(row_x, MARGIN_V + BAR_H - filled_height, BAR_W, filled_height)
    screen.level(15)
    screen.fill()
  end

  -- Draw text
  screen.level(3)
  screen.move(MARGIN_H, 64 - 5)
  screen.text("\u{25C0} " .. params:string("freq_l"))
  screen.move(128 - MARGIN_H, 64 - 5)
  screen.text_right(params:string("freq_r") .. " \u{25B6}")
  screen.fill()

  screen.update()
end

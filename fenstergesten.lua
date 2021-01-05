--[[
Author:    Mat/FreeER
Version:   1.13
Date:      Jan. 5th 2021
This script lets you use simple mouse gestures while holding a specific mouse button:
Mouse buttons: 1=M1,2=M2,3=MMB,4=X1,5=X2. For G-buttons use their respective numbers eg. G9 is 9
--]]

button_number = 3    -- Change to your mouse button number
GSHIFT        = 6    -- used for alternate functions
threshold_x   = 5000 -- Change thresholds for x and y to set
threshold_y   = 8000 -- the min distance needed for a gesture

-- event handlers for more generic/complex gesture commands
handlers         = {}
handlers["up"]   = function() PressAndReleaseKey("home") end
handlers["down"] = function() PressAndReleaseKey("end") end
-- PressAndReleaseKeyModified presses the first key last, assuming any other keys are modifiers that should be held first and released after
handlers["left"]   = function() PressAndReleaseKeyModified('w','lctrl') end           -- browser close tab
handlers["right"]  = function() PressAndReleaseKeyModified('t','lctrl','lshift') end  -- browser reopen tab
handlers["center"] = function() PressAndReleaseKeyModified('tab','lalt') end          -- alt+tab
-- note: for whatever reason Press...Key doesn't seem to like 'ctrl', it wants 'lctrl' or presumably 'rctrl'

handlers["alt_left"] = function() PressAndReleaseKeyModified('F4','lalt') end         -- alt-F4 close window
--[[
-- undefined alternates call the same as the non-gshifted versions
handlers["alt_up"]     = function() PressAndReleaseKey("home") end
handlers["alt_down"]   = function() PressAndReleaseKey("end") end
handlers["alt_right"]  = function() PressAndReleaseKeyModified('t','lctrl','lshift') end
handlers["alt_center"] = function() PressAndReleaseKeyModified('tab','lalt') end
--]]

-- is pressed functions don't seem to support G-keys on mouse for some reason.... :(
-- so I'll have to implement my own to check for the gshift/alternate key
pressed_buttons = {}

-- makes working with mouse coords a bit easier, particularly if more complex math was used
local vector = {}
vector.__index = vector
function vector.new(x, y) return setmetatable({ x = x or 0, y = y or 0 }, vector) end
function vector.__sub(lhs, rhs) return vector.new(lhs.x - rhs.x, lhs.y - rhs.y) end
function vector:__tostring() return "("..self.x..", "..self.y..")" end

function OnEvent(event, arg, family)
  if event == "MOUSE_BUTTON_PRESSED" then
    pressed_buttons[arg] = true
    if arg == button_number then start = vector.new(GetMousePosition()) end
  end

  if event == "MOUSE_BUTTON_RELEASED" then
    pressed_buttons[arg] = nil
    if arg == button_number then
      stop = vector.new(GetMousePosition())
      local diff = stop-start
--[[
      -- attempt at figuring out 8 directions instead of just 4 using 360 degrees
      -- this is too strict to support eg straight left, a little below == 0, a little above 7
      -- and if you happen to get a perfect straight line, a completely separate 8
      -- test image https://etc.usf.edu/clipart/43200/43202/unit-circle10_43202_lg.gif
      -- I wish there was a way to draw an overlay when the button was held, particularly if it could be highlighted
      -- like those circular weapon selections in games... I don't really see anything in the logitech api for that though lol

      dir = math.deg(math.atan2(diff.y,diff.x)) + 180 -- original 0=right, 90=down, 179=left, -90=up!
      --                                                  +180 shifts to left is 0/360, up 90 etc.
      if math.abs(diff.y) < threshold_y and math.abs(diff.x) < threshold_x  then dir = 720 end -- too short / center
      OutputLogMessage("\nAngle: %d     %d\n", dir, tostring(dir/45))
      if true then return end
--]]

      local function call(dir)
        if pressed_buttons[GSHIFT] and handlers['alt_' .. dir] then handlers['alt_' .. dir]()
        elseif handlers[dir] then handlers[dir]() end
      end

      if math.abs(diff.y) < threshold_y and math.abs(diff.x) < threshold_x  then call("center")
      elseif diff.y < -threshold_y then call("up")
      elseif diff.y >  threshold_y then call("down")
      elseif diff.x < -threshold_x then call("left")
      elseif diff.x >  threshold_x then call("right") end
    end
  end
end

-- Helper functions
function PressAndReleaseKeyModified(key, ...)
  PressKey(...)
  Sleep(40)
  PressAndReleaseKey(key)
  Sleep(40)
  ReleaseKey(...)
  Sleep(40)
end

function control_menu(key)
  PressAndReleaseKeyModified('spacebar', 'lalt')
  Sleep(250)
  PressAndReleaseKey(key)
  sleep(40)
end

-- window movements
function gestureMoveleft() PressAndReleaseKeyModified("left","lgui") end
function gestureMoveright() PressAndReleaseKeyModified("right","lgui") end
function gestureMaximise() control_menu("x") end
function gestureReset() control_menu("w") end
function gestureMinimise() control_menu("n"); PressAndReleaseKey("enter") --[[ workaround for Chrome ]] end

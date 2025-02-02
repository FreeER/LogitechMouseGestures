--[[
Author:    Mat/FreeER
Version:   1.15.1
Date:      Jan. 15th 2021
This script lets you use simple mouse gestures while holding a specific mouse button:
Mouse buttons: 1=M1,2=M2,3=MMB,4=X1,5=X2. For G-buttons use their respective numbers eg. G9 is 9
note, most main mouse buttons do not seem to be passed with EnablePrimaryMouseEvents(true) even if mapped to G keys
eg. I have front/back mapped to G11 and G14 but OnEvent is never called for those two keys if they are assigned, but will if not.
It is impossible to unassign l/r mouse buttons so...3/middle mouse button is called even if mapped/generic to MMB... /shrug
your experience may vary
--]]

handlers = {} -- table to store all the functions that can be called upon a gesture being completed
-- this __index method makes it simpler to add new handler keys by simplying doing handlers[new_key]...
-- instead of requiring users to first create a table with handlers[new_key] = {} then handlers[new_key]....
setmetatable(handlers,{__index = function(t,k)
  if type(k)=="number" then -- if not a number just allow normal nil index error otherwise
    local new = {button=k} -- remember the button being assigned for later warning information
    -- this __newindex method checks on direction assignment that it's valid and warns if it is not
    setmetatable(new, {__newindex = function(t,k,v)
      rawset(t,k,v) -- set the direction regardless, bypassing the this metamethod
      if ({left=1,right=1,up=1,down=1,center=1,fake=1})[k] ~= 1 then -- allow fake to add button without warning
        OutputLogMessage("'%s' is an invalid direction for button %d at line %d!\n", k, t.button, debug.getinfo(2,'l').currentline)
        OutputLogMessage("If generating buttons %d will still be added to the list for base usage.\n", t.button)
      end    
    end})
    t[k] = new
    return t[k]
  end
end})

-- //////////////////////////////// START OF CONFIG //////////////////////////////// 

-- list of buttons that can be used to gesture with, only the index matters, not the value
-- note if assigned these will still result in the assigned function running.
-- Eg. if something is mapped to press E holding that key to gesture _will_ type E
-- if not provided then will be generated based on the declared handlers below
--buttons = {3, 7, 11, 14} -- if commented out then generates buttons based on specified handlers
gshift_buttons = {6} -- ignore buttons if one of these is being held, so that you can still use gshifted keys as separately
-- TODO enable buttons only _if_ gshifted?
-- would require buttons value be {key,{accepted gshift keys list},...} or something? or maybe negative if there's only one gshift?

escapeModifier = "lctrl" -- hold this key when releasing gesture and nothing will happen
-- TODO allow alternate gestures with different modifiers?

-- also, mini-rant: Why TF does logitech not allow me to be notified, or even _check_, regular keyboard keys?
-- originally wanted to get an event for pressing Escape and have that cancel the gesture.

thresholds = {
  ["x"]    = 5000, -- Change thresholds for x and y to set
  ["y"]    = 8000, -- the min distance needed for a gesture
  ["time"] = 150   -- the minimum time in ms for a gesture
  -- TOODO separate times for each button? eg. unassigned can be short
  -- but gshift you may hold for longer periods during normal use
}

handlers.do_base  = true -- if specific handler is not set try to call base direction handler

-- event handlers for gesture commands are just functions assigned to indexes on the handlers table
-- The "base" handlers are handlers.direction, key specific handlers are created on handlers[key].direction
handlers.up         = function() PressAndReleaseKey("home") end
handlers.down       = function() PressAndReleaseKey("end")  end
-- PressAndReleaseKeyModified presses the first key last, assuming any other keys are modifiers that should be held first and released after
-- note: for whatever reason Press...Key doesn't seem to like "ctrl", it wants "lctrl" or presumably "rctrl"
handlers.left       = function() PressAndReleaseKeyModified("w","lctrl") end             -- browser close tab
handlers.right      = function() PressAndReleaseKeyModified("t","lctrl","lshift") end    -- browser reopen tab

handlers[3].center  = function() PressAndReleaseKeyModified("tab","lalt") end            -- alt+tab

handlers[11].up     = function() PressAndReleaseKey("f5") end                            -- browser refresh page
handlers[11].down   = function() gestureReset() end                                      -- restore maximized window size/ps
--handlers[11].left   = function() PressAndReleaseKeyModified("F4","lalt") end           -- placeholder
--handlers[11].right  = function() PressAndReleaseKeyModified("delete","lctrl") end      -- placeholder

handlers[14].up     = function() gestureMaximise() end
handlers[14].down   = function() gestureMinimise() end
handlers[14].left   = function() PressAndReleaseKeyModified("F4","lalt") end             -- duplicate alt-f4
handlers[14].right  = function() PressAndReleaseKeyModified("delete","lctrl") end        -- QuiteRSS delete all

handlers[7].left    = function() PressAndReleaseKeyModified("3", "lshift") end           -- email client, delete email
handlers[7].right   = function() PressAndReleaseKeyModified("1", "lshift") end           -- email client, junk   email
handlers[7].center  = function() PressAndReleaseKeyModified("tab", "lctrl", "lalt")  end -- alt+tab, stays open
handlers[7].down    = function() PressAndReleaseKey("f5") end                            -- browser refresh page

--handlers[99].fake = 1 -- allows a button to be generated without any specific directions and only works for base directions

-- //////////////////////////////// END OF CONFIG //////////////////////////////// 

-- invalid handler testing
--handlers[-93].down  = 1
--handlers[42].down  = 2
--handlers.bad = {}
--handlers[{}] = {}
--handlers[{}].up = function() end
--handlers[53].anythingelse = 42

-- check/generate buttons list
local old_buttons = buttons
buttons = {}
if old_buttons then
  -- quick loop to transform readable {1,2,3} to {[1]=1, [2]=1, [3]=1} where 1 is not nil
  -- so that users can easily create list of special keys and lookup can be just buttons[arg]
  for _,key in ipairs(old_buttons) do buttons[key] = 1 end
end

local num_buttons = 0
for button,_ in pairs(handlers) do
  if type(button) == "number" then
    num_buttons = num_buttons + 1
    if button < 1 or button > 32 then OutputLogMessage("UM... did you mean to declare a handler for button %d??\n", button)end
    if not old_buttons then buttons[button] = {}
    elseif not buttons[button] then OutputLogMessage("Handler declared for undeclared button %d!\n", button); num_buttons = num_buttons - 1 end
    elseif type(button) == "string" then 
  if ({left=1,right=1,up=1,down=1,center=1,do_base=1})[button] ~= 1 then OutputLogMessage("%s is an invalid direction!\n", button) end
  else OutputLogMessage("Wtf kind of handler is a %s\n", type(button)) end -- should be caught by __index metamethod
end

if num_buttons < 1 then error("No buttons were declared!", 2) end

-- makes working with mouse coords a bit easier, particularly if more complex math was used
local vector = {}
vector.__index = vector
function vector.new(x, y) return setmetatable({ x = x or 0, y = y or 0 }, vector) end
function vector.__sub(lhs, rhs) return vector.new(lhs.x - rhs.x, lhs.y - rhs.y) end
function vector:__tostring() return "("..self.x..", "..self.y..")" end

EnablePrimaryMouseButtonEvents(true)

local function call(dir,arg)
  -- call specific handler if one is set, otherwise try to call base dir handler
  if handlers[arg][dir] then handled = true; handlers[arg][dir]()
  elseif handlers.do_base and handlers[dir] then handlers[dir]() end
end

pressed = {} -- IsMouseButtonPressed doesn't seem to support Gkeys so... make my own 

function OnEvent(event, arg, family)
  if event == "MOUSE_BUTTON_PRESSED" then
    pressed[arg] = true -- IsMouseButtonPressed doesn't seem to support Gkeys so... make my own 
    -- work around for X1/X2 aka foward/back not working if assigned
    if arg == 11 then PressMouseButton(5) end
    if arg == 14 then PressMouseButton(4) end
    -- remember starting position if one of the meaningful keys
    local gshifted = false
    for _,gshift in ipairs(gshift_buttons) do if pressed[gshift] then gshifted = true break end end
    if not gshifted and buttons[arg] then buttons[arg] = {["start"]=vector.new(GetMousePosition()),["time"]=GetRunningTime()} end
  end

  if event == "MOUSE_BUTTON_RELEASED" then
    pressed[arg] = nil -- IsMouseButtonPressed doesn't seem to support Gkeys so... make my own 
    -- work around for X1/X2 aka foward/back not working if assigned
    if arg == 11 then ReleaseMouseButton(5) end
    if arg == 14 then ReleaseMouseButton(4) end

    -- time to work :)
    if buttons[arg] and buttons[arg].start and not IsModifierPressed(escapeModifier) then
      local stop = vector.new(GetMousePosition())
      local diff = stop-buttons[arg].start
      buttons[arg].start = nil -- disable until next valid press 
      local time_diff = GetRunningTime() - buttons[arg].time
      if time_diff < thresholds.time and arg == 3 then
        PressAndReleaseMouseButton(2) -- press my middle mouse button if it's under the threshold
        -- for some reason it has never worked properly in software mode when assigned
        -- though it does in the onboard profile and other Gkeys /shrug. LGS is a kludge of semi-useful code apparently
        return
      end

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

      if math.abs(diff.y) < thresholds.y and math.abs(diff.x) < thresholds.x  then call("center",arg)
      elseif diff.y < -thresholds.y then call("up",arg)
      elseif diff.y >  thresholds.y then call("down",arg)
      elseif diff.x < -thresholds.x then call("left",arg)
      elseif diff.x >  thresholds.x then call("right",arg) end
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
  PressAndReleaseKeyModified("spacebar", "lalt")
  Sleep(250)
  PressAndReleaseKey(key)
  Sleep(40)
end

-- window movements
function gestureMoveleft() PressAndReleaseKeyModified("left","lgui") end
function gestureMoveright() PressAndReleaseKeyModified("right","lgui") end
function gestureMaximise() control_menu("x") end
function gestureReset() control_menu("r") end
function gestureMinimise() control_menu("n"); PressAndReleaseKey("enter") --[[ workaround for Chrome ]] end

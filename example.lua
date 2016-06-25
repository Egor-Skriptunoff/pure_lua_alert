-- Example script for module "alert.lua".

-------------------------------------------------------
-- Introductory examples:

--The module does not create global variables, user should catch a function returned by require().
local alert = require("alert")

-- Create a window with some text inside and wait until user closed this window
-- (user may close it by pressing any key or close it with mouse or somehow kill window process):
alert("This is alert box")

-- Display a text and set window title:
alert("Hello from pure Lua alert() function!\nPress any key to continue...", "Greeting")

-- Add the colors in the form "foreground/background" to indicate severity of the warning:
alert("The meaning of life was not found.", "Critical error", "yellow/maroon")

-- Create a window and return immediately, without waiting for user reaction:
alert("This alert box doesn't block Lua script execution", nil, nil, false)

-- The same using named arguments:
alert{text = "This window doesn't block Lua script execution",
      wait = false}

-- Create empty blue window:
alert{colors = "/magenta"}  -- this means "I want magenta background and I don't care about foreground color"

-- Any printable characters are allowed in the text, shell metacharacters don't have magic:
alert("\tLook ma, environment variables are not expanded:\n\t$PATH %PATH%\n\n"..[[
 !"#$%&'()*+,-./0123456789:;<=>?
@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\]^_`abcdefghijklmnopqrstuvwxyz{|}~

UTF-8: Русский Ελληνικά 中文 ½°©§№
]], [[$PATH %PATH% Рус Ελλ 中文 ½°©§№ !"#$%&'()*+,-./:;<=>?@[\]^_`{|}~]], "white/navy")

-------------------------------------------------------
-- Working with configurations. Example #1:

-- Get initial function instance (it will use initial configuration)
local alert_1 = require("alert")

-- Create alert box using alert_1()
alert_1(("Test,"):rep(20))
-- Window created: title = "Press any key", colors = "black/silver", geometry up to 80x25

-- Override some parameters and create another function instance:
local alert_2 = alert_1(nil, {
   -- default values for arguments:
   default_arg_title = "My default title",
   default_arg_colors = "white/olive",
   -- other configurable parameters:
   max_width = 128,
   terminal = "urxvt"
}) -- no alert box is created by this call, instead, a new function is created

-- Create alert box using alert_2()
alert_2(("Test,"):rep(20))
-- Window created: title = "My default title", colors = "white/olive", using urxvt, geometry up to 128x25

-- Override some more configurable parameters and create yet another function instance:
local msg_ctr = 0
local alert_3 = alert_2(nil, {
   -- default values for text, title and colors could be constant strings or functions returning a string:
   default_arg_colors = "black/aqua",
   default_arg_title = function()
                          msg_ctr = msg_ctr + 1
                          return "Message #"..msg_ctr
                       end,
   -- other configurable parameters:
   terminal = "xterm"
})

-- Create alert box using alert_3()
alert_3(("Test,"):rep(20))
-- Window created: title = "Message #1", colors = "black/aqua", using xterm, geometry up to 128x25

-------------------------------------------------------
-- Working with configurations. Example #2:
-- How to create 2 functions to use different terminal emulators in Linux:
-- (of course, both terminal emulators should be installed on your system)
local alert_xterm = require("alert")(nil, {terminal = "xterm"})
local alert_urxvt = alert_xterm     (nil, {terminal = "urxvt"})
alert_xterm("This is xterm window")
alert_urxvt("This is urxvt window")

-------------------------------------------------------
-- Working with configurations. Example #3:
-- How to create 3 functions to use different default colors:
local alert_red   = require("alert")(nil, {default_arg_colors = "/dark red"}  )
local alert_green = alert_red       (nil, {default_arg_colors = "/dark green"})
local alert_blue  = alert_red       (nil, {default_arg_colors = "/dark blue"} )
alert_red  ("This window is red")
alert_green("This window is green")
alert_blue ("This window is blue")
alert_blue ("This window is yellow", nil, "/yellow")

-------------------------------------------------------
-- Working with configurations. Example #4:
-- How to create function that accepts Windows ANSI strings instead of UTF-8 strings (only for Windows):
local alert = require("alert")(nil, {use_windows_native_encoding = true})
alert('This is win1252 string.\n"One half" symbol: \189', "\189 in the title")


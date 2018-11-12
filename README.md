# pure_lua_alert

### Description
The functionality is similar to JavaScript `alert()` function.  
`alert()` creates a window with specified text and waits until user closed the window (by pressing any key).  
It is pure Lua module, compatible with Lua 5.1, 5.2, 5.3, 5.4 and LuaJIT.  
It does not depend on any C library, all it needs is `os.execute()` and `io.popen()`.  
It works on Linux, Mac OS X, Windows, Cygwin and Wine.  

`alert()` performs its task by invoking terminal emulator and executing shell command `echo YourMessage` inside it:
* "CMD.EXE" (Windows Command Prompt) is used on Windows, Cygwin and Wine;
* "Terminal.app" is used on Mac OS X;
* any of 17 supported terminal emulators (if found to be installed on your system) is used on Linux.

The alert dialog box is created as frontmost window; but, unlike standard dialog boxes, it is NOT modal to other windows of host application.

---
### Usage examples
```lua
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
```
---
### List of supported terminal emulators
`alert()` on Linux works only with terminal emulators it is aware of (see table `terminals`).  
Currently 17 terminal emulators are supported:
* aterm
* Eterm
* evilvte
* gnome-terminal
* konsole
* lxterminal
* mate-terminal
* mlterm
* mrxvt
* roxterm
* rxvt
* sakura
* urxvt     (aka "rxvt-unicode")
* uxterm    (UTF-8 wrapper around xterm)
* xfce4-terminal
* xterm
* xvt

and "zenity" (it is not a terminal emulator, nevertheless it can display a message and wait until user pressed OK button).

I hope that all default terminal emulators from all Linux desktop environments are listed here,  
so `alert()` should work on any desktop Linux.

---
### OS-specific behavior
* **Windows, Wine:**  
   Windows Command Prompt (CMD.EXE) is used to create a console window and display a message inside it.

* **Linux:**  
   All terminal emulators listed in the table `terminals` are checked for being installed in order of their priority.  
   The first one which was successfully detected is used as alert box.  
   Otherwise (if auto-detection failed) an error is raised.

* **CYGWIN:**  
   **if** Cygwin/X is running and auto-detection was successful  
   **then** the terminal emulator which has been detected is used, usually it is "rxvt-unicode"  
   **else** CMD.EXE is used

* **Mac OS X:**  
   **if** XQuartz is running and auto-detection was successful  
   **then** the terminal emulator which has been detected is used  
   **else** Terminal.app is used

* **other OS:**  
   all other systems use Linux scenario

---
### Text Encoding
Arguments `text` and `title` are expected to be UTF-8 strings on all platforms, including Windows and Wine.  
The following variants of newlines are valid on all platforms: `"\n"`, `"\r\n"`, `"\r"`, `"\0"`.

##### A note for CYGWIN users:
* When Cygwin/X-based terminal emulator is used as alert box:
  * UTF-8 is fully supported
  * Sometimes alert box is created as NOT frontmost window and NOT focused.
* When CMD.EXE is used as alert box:
  * UTF-8 support is limited to symbols from current Windows locale:
    * characters from Windows OEM codepage (OEM=cp850 for Latin-1 locale) are displayed correctly,
    * all other characters are replaced with `?`

##### A note for WINDOWS users:
* Limited UTF-8 support:
  * characters which are present in both Windows ANSI and OEM codepages simultaneously are displayed correctly,
  * all other characters are replaced with `?`
    * Example #1: Windows locale is "Latin-1" (ANSI=win1252, OEM=cp850)  
      characters from intersection of win1252 and cp850 are displayed correctly.
    * Example #2: Windows locale is "Chinese traditional" (ANSI=OEM=cp950)  
      Chinese and Greek letters are displayed correctly, Russian letters are replaced with `?`.
* To work with Windows ANSI strings instead of UTF-8 strings,  
  set `use_windows_native_encoding` configurable parameter to `true`  
  (see "Working with configurations. Example #4" below)

##### A note for Wine users:
* "A note for WINDOWS users" is applicable to Wine users too.
* Sometimes alert box is created as NOT frontmost window and NOT focused.
* Alert box is always constantly big (80x25) because Wine lacks `C:\WINDOWS\system32\mode.com`.

---
### Function signature
```lua
   function alert (text, title, colors, wait, admit_linebreak_inside_of_a_word)
```
or
```lua
   function alert (arg_table)
```
where `arg_table` is a table containing arguments in fields with corresponding names.

---
### Arguments
All arguments are optional.  
If some argument is omitted or set to nil, then its default value is used  
(see "Configurations" section on how to set default values).
* **text:**  
   Text to be displayed (empty string by default)
* **title:**  
   Window title ("Press any key" by default)
* **colors:**  
   Forground and background color names, separated by a slash, `"black/silver"` by default.  
   Omitting one of the components (`"cyan/"`, `"/green"`,...) means "I don't care omitted color", white or black color will be used in place of omitted component to maximize the contrast.  
   Omitting both components `"/"` means "use your terminal's default colors".  
   Color names are actually the keys in table `all_colors`, examples: `"dk-blue", "lime"`, `"magenta", "white"`,...  
   Color names are case-insensitive, light=lt, dark=dk, gray=grey, non-alphanumeric chars are ignored:  
   `"Light Red"` = `"lightred"` = `"LtRed"` = `"light-red"` = `"Lt.Red"`  = `"light red"`  = `"red"`
* **wait:**  
   **true:** Lua script execution is blocked until user closed terminal window  
   **false:** alert() returns immediately without waiting for user to press a key
* **admit_linebreak_inside_of_a_word:**  
   This option affects only long text lines which are longer than maximal terminal window width (more than 80 characters)  
   **false:** insert additional newlines in safe places to avoid words get splitted by linebreaks  
   **true:** display long text lines as-is, without inserting additional newlines

---
### Configurations
Configuration is a set of parameters which can be modified in order to control the behavior of `alert()`.  
Configurable parameters are:
* default values for omitted `alert()` arguments,
* parameters concerning to window geometry and text padding,
* OS-specific behavior parameters.

See `initial_config` table to view full list of configurable parameters.

To use a configuration which differs from `initial_config`, one should create new instance of function `alert()` by using special form of invocation with table as second argument:
```lua
   alert = alert(nil, config_override_table)
```
Table `config_override_table` should contain new values for overridden parameters.  
Configurable parameters that had not been overridden are inherited from the current instance of function.

##### Working with configurations. Example #1:
```lua
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
```
##### Working with configurations. Example #2:
How to create two functions to use different terminal emulators in Linux:  
(of course, both terminal emulators should be installed on your system)
```lua
local alert_xterm = require("alert")(nil, {terminal = "xterm"})
local alert_urxvt = alert_xterm     (nil, {terminal = "urxvt"})
alert_xterm("This is xterm window")
alert_urxvt("This is urxvt window")
```
##### Working with configurations. Example #3:
How to create three functions to use different default colors:
```lua
local alert_red   = require("alert")(nil, {default_arg_colors = "/dark red"}  )
local alert_green = alert_red       (nil, {default_arg_colors = "/dark green"})
local alert_blue  = alert_red       (nil, {default_arg_colors = "/dark blue"} )
alert_red  ("This window is red")
alert_green("This window is green")
alert_blue ("This window is blue")
alert_blue ("This window is yellow", nil, "/yellow")
```
##### Working with configurations. Example #4:
How to create function that accepts Windows ANSI strings instead of UTF-8 strings (only for Windows and Wine):
```lua
local alert = require("alert")(nil, {use_windows_native_encoding = true})
alert('This is win1252 string.\n"One half" symbol: \189', "\189 in the title")
```
---
### OS versions
* **Windows:**  
 XP and higher versions are supported
* **MacOSX:**  
 tested on Mountain Lion and El Capitan
* **Cygwin:**  
 tested on 2.5.1
* **Wine**  
 tested on 1.6.2
* **Linux:**  
 should work on all desktop Linux distributions
* **Other *nices:**  
 not tested, but I hope it should work (bugreports are welcome)

---
### Installation
   Just copy `alert.lua` to folder where Lua modules are stored on your machine.

---
### Known problems:
1. Problem with symbol width on Windows with Multi-Byte-Character-Set locales (such as CJK).  
   Currently, `alert()` is unable to distinguish between full-width and half-width characters in CMD.EXE console output.  
   So, "geometry beautifier" may give wrong text layout and/or incorrect window dimensions.  
   Bugreports with screenshots are welcome.  
   Is there exist a rule (applicable to all existing MBCS Windows encodings) to determine width of symbol on CMD.EXE screen?  
   Can someone suggest a way to solve this problem?

---
### Feedback
Please send any ideas, improvements and constructive criticism to egor.skriptunoff(at)gmail.com

Feedback is especially desirable from:
* People that are using *nix distributions which are not in widespread use;
* CJK Windows users.

---
### FAQ
* **Q:** Why module version numbers are so plain: version 1, version 2,... instead of traditional **x.y.z** version notation?  
* **A:** I want to keep things simple.  
 This module is intended to ALWAYS keep backward compatibility: if your program works with `alert` version **N**, it will also work with `alert` version **N+1**.  
 So, one level of numbers is enough to describe dependency.

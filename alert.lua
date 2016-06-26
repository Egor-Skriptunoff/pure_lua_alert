--------------------------------------------------------------------------------
-- Functionality similar to JavaScript "alert()" implemented in pure Lua.
--------------------------------------------------------------------------------
-- MODULE: alert

-- VERSION: 2 (2016-06-25)

-- AUTHOR: Egor (egor.skriptunoff(at)gmail.com)
-- This module is released under the MIT License (the same license as Lua itself).
--
-- DESCRIPTION:
--   This module returns the following function:
--     alert(text, title, colors, wait, admit_linebreak_inside_of_a_word)
--   It creates a window with specified text and waits until user closed the window by pressing any key.
--
-- USAGE:
--   Simplest example:
--     local alert = require("alert")
--     alert("Hello")
--   See "example.lua" for more examples.
--
-- REQUIREMENTS:
--   Lua 5.1, Lua 5.2, Lua 5.3 or LuaJIT.
--   Lua standard library functions "os.execute()" and "io.popen()" must be non-sandboxed.
--   Supported OS: probably all X11-based *nices, Windows (XP and higher), MacOSX, Cygwin, Wine.
--
-- CHANGELOG:
--  version     date      description
--     2     2016-06-25   Wine support added
--     1     2016-06-21   First release
-----------------------------------------------------------------------------

local NIL = {} -- this value represents "nil" values inside "initial_config" table

-- Initial values of configurable parameters.
local initial_config = {
   -- To preserve module compatibility, don't modify anything in this table.
   -- In order to use modified configuration, create specific instance of "alert()" function:
   --   local alert = require("alert")(nil, {param_name_1=param_value_1, param_name_2=param_value_2, ...})

   -------------------------------------------------------
   -- Default values for omitted alert() arguments
   -------------------------------------------------------
   default_arg_text   = NIL,               -- [string] or [function returning a string]
   default_arg_title  = NIL,               -- [string] or [function returning a string]
   default_arg_colors = NIL,               -- [string] or [function returning a string]
   default_arg_wait                             = true,   -- [boolean]
   default_arg_admit_linebreak_inside_of_a_word = false,  -- [boolean]

   ------------------------------------------------------
   -- Parameters concerning to terminal window geometry
   ------------------------------------------------------
   enable_geometry_beautifier = true,                     -- [boolean]
   -- true:  set terminal window width and height, center the text in the window, break lines only at word boundaries
   -- false: never change size of terminal window, don't center text, don't move linebreaks in the text

   -- Terminal window size constraints:
   max_width  = 80,    -- [positive integers]
   max_height = 25,
   min_width  = 44,
   min_height = 15,

   always_use_maximum_size_of_terminal_window = false,    -- [boolean]
   -- false: geometry beautifier chooses nice-looking size from range (min_width..max_width)x(min_height..max_height)
   -- true:  geometry beautifier always sets terminal window size to constant dimensions (max_width)x(max_height)

   -- Desired number of unused rows and columns near window borders:
   horiz_padding = 4,    -- [non-negative integers]
   vert_padding = 2,

   ------------------------------------
   -- OS-specific behavior parameters
   ------------------------------------
   -- This parameter is applicable only for CYGWIN.
   always_use_cmd_exe_under_cygwin = false,               -- [boolean]
   -- false: when Cygwin/X is running, terminal emulators are being tried first, failed that CMD.EXE is used.
   -- true:  when Cygwin/X is running, CMD.EXE is always used (it opens faster, but has limited UTF-8 support).

   -- This parameter is applicable only for MacOSX.
   always_use_terminal_app_under_macosx = false,          -- [boolean]
   -- false: when XQuartz is running, *nix terminal emulators are being tried first, failed that Terminal.app is used.
   -- true:  when XQuartz is running, Terminal.app is always used.

   -- This parameter is applicable only for Windows and Wine.
   use_windows_native_encoding = false,                   -- [boolean]
   -- false: "text" and "title" arguments are handled as UTF-8 strings whenever possible
   --        (if they both are correct UTF-8 strings), otherwise native Windows ANSI codepage is assumed for both of them
   -- true:  "text" and "title" arguments are always interpreted as strings in native Windows ANSI codepage
   -- Please note that Windows ANSI codepage depends on current locale settings, it can be modified by user in
   -- "Windows Control Panel" -> "Regional and Language" -> "Language for non-Unicode Programs"

   -- This parameter is applicable for all systems except Windows and Wine.
   terminal = NIL,                                     -- [any key from "terminals" table]
   -- This parameter selects preferred terminal emulator, which will be given highest priority during auto-detection

}  -- end of table "initial_config"


-- This is the list of supported terminal emulators.
-- Feel free to add additional terminal emulators that must be here (and send your patch to the module's author).

local terminals = {
   -- Description of fields:
   --    priority                   optional  number    terminal emulators will be checked for being installed in order
   --                                                   from highest priority to lowest
   --    option_title               required  string    a command line option to set window title (for example, "--title")
   --    option_geometry            optional  string    a command line option to set width in columns and height in rows
   --    options_misc               optional  string    miscellaneous command line options for this terminal emulator
   --    only_8_colors              optional  boolean   if this terminal emulator can display only 8 colors instead of 16
   --    option_colors              optional  string    a command line option to set foreground and background colors
   --                                                   (if omitted, Esc-sequence will be used to set terminal colors)
   -- Next two fields are for terminal emulators:
   --    option_command             required  string    an option to provide a shell command to execute (for example, "-e")
   --    command_requires_quoting   required  boolean   should shell command be quoted in the command line?
   -- Next two fields are for native dialogs, such as "zenity":
   --    option_text                required  string    a command line option to pass user text to be displayed
   --    text_preprocessor          optional  function  text preprocessing function to implement escaping, etc.

   ["xfce4-terminal"] = {
      priority = -0,
      option_geometry = "--geometry=%dx%d", -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_command = "-x",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
      options_misc = "--disable-server --hide-menubar", -- other useful options
   },
   ["mlterm"] = {
      priority = -1,
      option_geometry = "-g %dx%d",         -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_colors = "-f '%s' -b '%s'",    -- actual usage == string.format(option_colors, fg#RRGGBB, bg#RRGGBB)
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
      options_misc = "-O none",             -- other useful options
   },
   ["urxvt"] = {  -- rxvt-unicode
      priority = -2,
      option_geometry = "-g %dx%d",         -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_colors = "-fg '%s' -bg '%s'",  -- actual usage == string.format(option_colors, fg#RRGGBB, bg#RRGGBB)
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
      options_misc = "-sr +sb",             -- other useful options
   },
   ["uxterm"] = {
      priority = -3,
      option_geometry = "-geometry %dx%d",  -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_colors = "-fg '%s' -bg '%s'",  -- actual usage == string.format(option_colors, fg#RRGGBB, bg#RRGGBB)
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
   },
   ["xterm"] = {
      priority = -4,
      option_geometry = "-geometry %dx%d",  -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_colors = "-fg '%s' -bg '%s'",  -- actual usage == string.format(option_colors, fg#RRGGBB, bg#RRGGBB)
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
   },
   ["lxterminal"] = {
      priority = -5,
      option_geometry = "--geometry=%dx%d", -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-t",                  -- actual usage == option_title..[[ 'My Title']]
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = true,      -- if true then == option_command..[[ "command arguments"]]
   },
   ["gnome-terminal"] = {
      priority = -6,
      option_geometry = "--geometry=%dx%d", -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-t",                  -- actual usage == option_title..[[ 'My Title']]
      option_command = "-x",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
      options_misc = "--disable-factory",   -- other useful options
   },
   ["mate-terminal"] = {
      priority = -7,
      option_geometry = "--geometry=%dx%d", -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-t",                  -- actual usage == option_title..[[ 'My Title']]
      option_command = "-x",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
      options_misc = "--disable-factory",   -- other useful options
   },
   ["sakura"] = {
      priority = -8,
      option_geometry = "-c %d -r %d",      -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-t",                  -- actual usage == option_title..[[ 'My Title']]
      only_8_colors = true,                 -- this terminal emulator can display only 8 colors instead of 16
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = true,      -- if true then == option_command..[[ "command arguments"]]
   },
   ["roxterm"] = {
      priority = -9,
      option_geometry = "--geometry=%dx%d", -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
      options_misc = "--hide-menubar --separate -n ' '", -- other useful options (how to hide tabbar?)
   },

   -- The following terminal emulators don't support UTF-8
   ["mrxvt"] = {
      priority = -100,
      option_geometry = "-g %dx%d",         -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_colors = "-fg '%s' -bg '%s'",  -- actual usage == string.format(option_colors, fg#RRGGBB, bg#RRGGBB)
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
      options_misc = "+sb -aht +showmenu",  -- other useful options
   },
   ["rxvt"] = {
      priority = -101,
      option_geometry = "-g %dx%d",         -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_colors = "-fg '%s' -bg '%s'",  -- actual usage == string.format(option_colors, fg#RRGGBB, bg#RRGGBB)
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
      options_misc = "-sr +sb",             -- other useful options
   },
   ["Eterm"] = {
      priority = -102,
      option_geometry = "-g %dx%d",         -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_colors = "-f '%s' -b '%s'",    -- actual usage == string.format(option_colors, fg#RRGGBB, bg#RRGGBB)
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
      options_misc = "--scrollbar 0 -P ''", -- other useful options
   },
   ["aterm"] = {
      priority = -103,
      option_geometry = "-g %dx%d",         -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_colors = "-fg '%s' -bg '%s'",  -- actual usage == string.format(option_colors, fg#RRGGBB, bg#RRGGBB)
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
      options_misc = "-sr +sb",             -- other useful options
   },
   ["xvt"] = {
      priority = -104,
      option_geometry = "-geometry %dx%d",  -- actual usage == string.format(option_geometry, my_columns, my_rows)
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_colors = "-fg '%s' -bg '%s'",  -- actual usage == string.format(option_colors, fg#RRGGBB, bg#RRGGBB)
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
   },

   -- the following terminal emulators do support UTF-8, but don't have an option to set its width and height in characters
   ["evilvte"] = {
      priority = -200,
      -- option_geometry =                  -- there is no way to set number of rows and columns for this terminal emulator
      option_title = "-T",                  -- actual usage == option_title..[[ 'My Title']]
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
   },
   ["konsole"] = {
      priority = -201,
      -- the following "option_geometry" should work but it doesn't
      -- (bugs.kde.org/show_bug.cgi?id=345403)
      -- option_geometry = "-p TerminalColumns=%d -p TerminalRows=%d",
      option_title = "--caption",           -- actual usage == option_title..[[ 'My Title']]
      -- konsole <-e> option has a problem: it expands all environment variables inside <-e command arguments>
      -- despite of protecting them with single quotes, so all $VARs in your text will be forcibly expanded
      -- (bugs.kde.org/show_bug.cgi?id=361835)
      option_command = "-e",                -- actual usage == option_command..[[ command arguments]]
      command_requires_quoting = false,     -- if true then == option_command..[[ "command arguments"]]
      options_misc = "--nofork --hide-tabbar --hide-menubar -p ScrollBarPosition=2",  -- other useful options
   },

   -- native dialogs (they don't have ability to set background color, so colors are not used)
   ["zenity"] = { -- user should press Enter or Spacebar, or "OK" button with mouse (instead of pressing any key)
      priority = -1000,
      -- option_geometry =                  -- zenity does not allow setting number of rows and columns for monospaced font
      option_title = "--title",             -- actual usage == option_title..[[ 'My Title']]
      option_colors = "",                   -- zenity can't set its window color, so we don't use colors at all
      -- option_command =                   -- "zenity" uses "option_text" instead of "option_command"
      option_text = "--text",               -- actual usage == option_text..[[ 'My Text']]
      text_preprocessor =                   -- Pango Markup Language requires some escaping
         function(text)
            return "<tt>"..text:match"^\n*(.-)\n*$":gsub(".", {
               ["\\"]="\\\\", ["&"]="&amp;", ["<"]="&lt;", [">"]="&gt;", ["\n"]="\\n"
            }).."</tt>"
         end,
      options_misc = "--info --icon-name=", -- other useful options
   },

}  -- end of table "terminals"

-- all 16 colors available for foreground and background in terminal emulators
local all_colors = {--ANSI_FG  ANSI_BG   EGA     #RRGGBB            SYNONYMS
   ["dark red"]      = {"31",    "41",   "4",   "#800000", "          maroon"},
   ["light red"]     = {"91",   "101",   "C",   "#FF0000", "             red"},
   ["dark green"]    = {"32",    "42",   "2",   "#008000", "           green"},
   ["light green"]   = {"92",   "102",   "A",   "#00FF00", "            lime"},
   ["dark yellow"]   = {"33",    "43",   "6",   "#808000", "           olive"},
   ["light yellow"]  = {"93",   "103",   "E",   "#FFFF00", "          yellow"},
   ["dark blue"]     = {"34",    "44",   "1",   "#000080", "            navy"},
   ["light blue"]    = {"94",   "104",   "9",   "#0000FF", "            blue"},
   ["dark magenta"]  = {"35",    "45",   "5",   "#800080", "          purple"},
   ["light magenta"] = {"95",   "105",   "D",   "#FF00FF", "magenta, fuchsia"},
   ["dark cyan"]     = {"36",    "46",   "3",   "#008080", "            teal"},
   ["light cyan"]    = {"96",   "106",   "B",   "#00FFFF", "      aqua; cyan"},
   ["black"]         = {"30",    "40",   "0",   "#000000", "    afroamerican"},
   ["dark gray"]     = {"90",   "100",   "8",   "#808080", "            gray"},
   ["light gray"]    = {"37",    "47",   "7",   "#C0C0C0", "          silver"},
   ["white"]         = {"97",   "107",   "F",   "#FFFFFF", "                "},
}                         -- all_colors[color_name] = color_value

-- create "all_colors" table entries for color synonyms
local color_synonyms = {}
local ega_colors = {}     -- ega_colors[0..15] = color_value
for name, value in pairs(all_colors) do
   ega_colors[tonumber(value[3], 16)] = value
   color_synonyms[name:lower():gsub("%W", "")] = value
   for syn in value[5]:gmatch"[^,;/]+" do
      syn = syn:lower():gsub("%W", "")
      if syn ~= "" then
         color_synonyms[syn] = value
      end
   end
end
for name, value in pairs(color_synonyms) do
   all_colors[name] = value
   all_colors[name:gsub("gray", "grey")] = value
   name = name:gsub("^light", "lt"):gsub("^dark", "dk")
   all_colors[name] = value
   all_colors[name:gsub("gray", "grey")] = value
end

-- calculate best contrast counterparts for all colors
local best_contrast = {}  -- best_contrast[color_value] = color_value
for ega_color_id = 0, 15 do
   best_contrast[ega_colors[ega_color_id]] =
      ega_color_id <= 9 and ega_color_id ~= 7 and all_colors.white or all_colors.black
end

-- function to convert a string "fg/bg" to pair of color values
local function get_color_values(color_names, terminal_is_able_to_display_only_8_colors, avoid_using_default_terminal_colors)
   local fg_color_name, bg_color_name = (color_names or "black/silver"):match"^%s*([^/]-)%s*/%s*([^/]-)%s*$"
   if not fg_color_name then
      error('Wrong "colors" argument for "alert": expected format is "fg_color_name/bg_color_name"', 3)
   end
   local fg_color_value = all_colors[fg_color_name:gsub("%W", ""):lower()]
   local bg_color_value = all_colors[bg_color_name:gsub("%W", ""):lower()]
   if fg_color_name ~= "" or bg_color_name ~= "" then
      if not (fg_color_value or fg_color_name == "") then
         error('"alert" doesn\'t know this color: "'..fg_color_name..'"', 3)
      end
      if not (bg_color_value or bg_color_name == "") then
         error('"alert" doesn\'t know this color: "'..bg_color_name..'"', 3)
      end
      fg_color_value = fg_color_value or best_contrast[bg_color_value]
      bg_color_value = bg_color_value or best_contrast[fg_color_value]
      if terminal_is_able_to_display_only_8_colors then
         local colors_were_different = fg_color_value ~= bg_color_value
         fg_color_value = ega_colors[tonumber(fg_color_value[3], 16) % 8]
         bg_color_value = ega_colors[tonumber(bg_color_value[3], 16) % 8]
         if colors_were_different and fg_color_value == bg_color_value then
            -- pair of fg/bg colors is beyond terminal abilities, default terminal colors will be used
            fg_color_value, bg_color_value = nil
         end
      end
   end
   if avoid_using_default_terminal_colors then
      fg_color_value, bg_color_value = fg_color_value or all_colors.black, bg_color_value or all_colors.white
   end
   return fg_color_value, bg_color_value
end  -- end of function "get_color_values()"

local one_byte_char_pattern = "."                    -- Lua pattern for characters in Windows ANSI strings
local utf8_char_pattern = "[^\128-\191][\128-\191]*" -- Lua pattern for characters in UTF-8 strings

local function geometry_beautifier(
   cfg,                      --  configuration of current alert() instance
   text,                     --  text which layout should be beautified (text centering and padding, nice line splitting)
   char_pattern,             --  Lua pattern for matching one symbol in the text
   early_line_overflow,      --  true: cursor jumps to next line when previous line has been filled but not yet overflowed
   admit_linebreak_inside_of_a_word,  --  true: disable inserting additional LF in the safe locations of the text
   exact_geometry_is_unknown --  true (or number): we have no control over width and height of the terminal window
)  -- Three values returned:
   --    text (all newlines CR/CRLF/LF are converted to LF, last line is not terminated by LF)
   --    chosen terminal width  (nil if geometry beautifier is disabled)
   --    chosen terminal height (nil if geometry beautifier is disabled)
   text = (text or ""):gsub("\r\n?", "\n"):gsub("%z","\n"):gsub("[^\n]$", "%0\n")
   local width, height
   if cfg.enable_geometry_beautifier then
      local min_width  = math.max(12, cfg.min_width )
      local min_height = math.max( 3, cfg.min_height)
      local max_width  = math.max(12, cfg.max_width )
      local max_height = math.max( 3, cfg.max_height)
      if exact_geometry_is_unknown then
         -- we have no control over width and height of the terminal window, but we assume
         -- that terminal window has exactly 80 columns and at least 23 rows (this is very probable)
         max_width  = 80
         max_height = type(exact_geometry_is_unknown) == "number" and exact_geometry_is_unknown or 23
      end
      local pos, left_cut, right_cut = 0, math.huge, 0
      local line_no, top_cut, bottom_cut = 0, math.huge, 0
      local line_is_not_empty
      text = text:gsub(char_pattern,
         function(c)
            if c == "\n" then
               pos = 0
               if line_is_not_empty then
                  line_is_not_empty = false
                  top_cut = math.min(top_cut, line_no)
                  bottom_cut = math.max(bottom_cut, line_no + 1)
               end
               line_no = line_no + 1
            elseif c == "\t" then
               local delta = 8 - pos % 8
               pos = pos + delta
               return (' '):rep(delta)
            else
               if c:find"%S" then
                  left_cut = math.min(left_cut, pos)
                  right_cut = math.max(right_cut, pos + 1)
                  line_is_not_empty = true
               end
               pos = pos + 1
            end
         end
      )
      left_cut = math.min(left_cut, right_cut)
      width = math.min(max_width, math.max(right_cut - left_cut + 2*cfg.horiz_padding,
         (cfg.always_use_maximum_size_of_terminal_window or exact_geometry_is_unknown) and max_width or min_width))
      local line_length_limit =
         not admit_linebreak_inside_of_a_word and right_cut - left_cut > max_width and max_width - 2*cfg.horiz_padding
      local left_indent =
         (" "):rep(line_length_limit and cfg.horiz_padding or math.max(math.floor((width - right_cut + left_cut)/2), 0))
      top_cut = math.min(top_cut, bottom_cut)
      local actual_height, new_text, line_no = 0, "", 0
      for line in text:gmatch"(.-)\n" do
         if line_no >= top_cut and line_no < bottom_cut then
            local prefix, prefix_len, new_line, new_line_len, pos, tail_of_spaces = "", 0, "", 0, 0, ""
            local punctuation, remove_leading_spaces
            for c in (line.." "):gmatch(char_pattern) do
               if pos >= left_cut then
                  if line_length_limit and (                  -- There are two kinds of locations to split a line nicely:
                     punctuation and (c:find"%w" or c:byte() > 127)                 -- 1) alphanumeric after punctuation
                     or tail_of_spaces == "" and pos > left_cut and not c:find"%S"  -- 2) space after non-space
                  ) then
                     if prefix_len + new_line_len > line_length_limit and prefix ~= ""
                           and #new_line:match"%S.*" < line_length_limit/3 then
                        new_text = new_text..left_indent..prefix.."\n"
                        actual_height = actual_height + 1
                        prefix, prefix_len, remove_leading_spaces = "", 0, true
                     end
                     repeat
                        if new_line == "" then
                           local length_in_bytes = 0
                           for _ = 1, line_length_limit do
                              length_in_bytes = select(2, prefix:find(char_pattern, length_in_bytes + 1))
                           end
                           local next_line = (left_indent..prefix:sub(1, length_in_bytes)):match".*%S"
                           remove_leading_spaces = next_line ~= nil
                           new_text = new_text..(next_line or "").."\n"
                           actual_height = actual_height + 1
                           prefix, prefix_len = prefix:sub(1 + length_in_bytes), prefix_len - line_length_limit
                        end
                        prefix, new_line, prefix_len, new_line_len = prefix..new_line, "", prefix_len + new_line_len, 0
                        local spaces_at_the_beginning = #prefix:match"%s*"
                        if remove_leading_spaces and spaces_at_the_beginning > 0 then
                           prefix, prefix_len = prefix:sub(1 + spaces_at_the_beginning), prefix_len - spaces_at_the_beginning
                        end
                     until prefix_len <= line_length_limit
                  end
                  if c:find"%S" then
                     new_line = new_line..tail_of_spaces..c
                     new_line_len = new_line_len + #tail_of_spaces + 1
                     tail_of_spaces = ""
                  else
                     tail_of_spaces = tail_of_spaces..c
                  end
                  punctuation = (",;"):find(c, 1, true)  -- dot was excluded to avoid splitting of numeric literals
               end
               pos = pos + 1
            end
            if line_length_limit then
               new_line, new_line_len = prefix, prefix_len
            end
            new_text = new_text..(new_line == "" and "" or left_indent)..new_line.."\n"
            actual_height = actual_height + math.max(math.ceil(new_line_len/width), 1)
         end
         line_no = line_no + 1
      end
      height = math.min(max_height, math.max(actual_height + 2*cfg.vert_padding,
         (cfg.always_use_maximum_size_of_terminal_window or exact_geometry_is_unknown) and max_height or min_height))
      local top_indent_size = math.floor((height - actual_height)/2)
      text = ("\n"):rep(math.max(top_indent_size, exact_geometry_is_unknown and cfg.vert_padding or 0))
         ..new_text..("\n"):rep(height - actual_height - top_indent_size - 1)
      if early_line_overflow then
         text = text:gsub("(.-)\n",
            function(line)
               return line ~= "" and select(2, line:gsub(char_pattern, "")) % width == 0 and line
            end
         )
      end
   end
   return text:gsub("\n$", ""), width, height
end  -- end of function "geometry_beautifier()"

-- the must-have system functions for this module:
local os_execute, io_popen, os_getenv = os.execute, io.popen, os.getenv

-- the following functions are required only under Wine and CJK Windows
local io_open, os_remove = io.open, os.remove -- they are needed to create and delete temporary file

local test_echo, env_var_os, windows_ver, system_name, xinit_proc_cnt, wait_key_method_code
local tempfolder, tempfileid, sbcs, mbcs, ansi_to_utf16, utf16_to_ansi, utf16_to_oem, utf8_to_sbcs, tempfilespec
local locale_dependent_chars

local function create_function_alert(cfg)   -- function constructor

   if not (os_execute and io_popen) then
      error('"alert" requires "os.execute" and "io.popen"', 3)
   end
   if not test_echo then
      local pipe = io_popen"echo Test"  -- command "echo Test" should work on any OS
      test_echo = pipe:read"*a"
      pipe:close()
   end
   if not test_echo:match"^Test" then
      error('"alert" requires non-sandboxed "os.execute" and "io.popen"', 3)
   end

   env_var_os = env_var_os or os_getenv"oS" or ""
   -- "oS" is not a typo.  It prevents Cygwin from being incorrectly identified as Windows.
   -- Cygwin inherits Windows environment variables, but treats them as if they were case-sensitive.

   if env_var_os:find"^Windows" then

      ----------------------------------------------------------------------------------------------------
      -- Windows or Wine
      ----------------------------------------------------------------------------------------------------

      local function getwindowstempfilespec()
         if not tempfolder then
            tempfolder = assert(os_getenv"TMP" or os_getenv"TEMP", "%TMP% environment variable is not set")
            tempfileid = os.time() * 3456793  -- tempfileid is an integer number in the range 0..(2^53)-1
            local pipe = io_popen"echo %random%%time%%date%"
            -- We want to make temporary file name different for every run of the program
            -- %random% is 15-bit random integer generated by OS
            -- %time% is current time with 0.01 seconds precision on Windows (one-minute precision on Wine)
            -- tostring{} contains table's address inside the heap, heap location is changed on every run due to ASLR
            ;(tostring{}..pipe:read"*a"):gsub("..",
               function(s)
                  tempfileid = tempfileid % 68719476736 * 126611
                     + math.floor(tempfileid/68719476736) * 505231
                     + s:byte() * 3083 + s:byte(2)
               end)
            pipe:close()
         end
         tempfileid = tempfileid + 1
         return tempfolder..("\\alert_%.f.tmp"):format(tempfileid)
      end

      if not locale_dependent_chars then
         locale_dependent_chars = {}
         for code = 128, 255 do
            locale_dependent_chars[code - 127] = string.char(code)
         end
         locale_dependent_chars = table.concat(locale_dependent_chars)
      end

      local function is_utf8(str)
         local is_ascii7 = true
         for c in str:gmatch"[^\128-\191]?[\128-\191]*" do
            local len, first = #c, c:byte()
            if len > 4 or len == 4 and not (first >= 0xF0 and first < 0xF5)
                       or len == 3 and not (first >= 0xE0 and first < 0xF0)
                       or len == 2 and not (first >= 0xC2 and first < 0xE0)
                       or len == 1 and not (first < 0x80) then
               return false
            end
            is_ascii7 = is_ascii7 and len < 2
         end
         return true, is_ascii7
      end

      local function convert_char_utf8_to_utf16(c)
         local c1, c2, c3, c4 = c:byte(1, 4)
         local unicode
         if c4 then      -- [1111 0xxx] [10xx xxxx] [10xx xxxx] [10xx xxxx]
            unicode = ((c1 % 8 * 64 + c2 % 64) * 64 + c3 % 64) * 64 + c4 % 64
         elseif c3 then  -- [1110 xxxx] [10xx xxxx] [10xx xxxx]
            unicode = (c1 % 16 * 64 + c2 % 64) * 64 + c3 % 64
         elseif c2 then  -- [110x xxxx] [10xx xxxx]
            unicode = c1 % 32 * 64 + c2 % 64
         else            -- [0xxx xxxx]
            unicode = c1
         end
         if unicode < 0x10000 then
            return string.char(unicode % 256, math.floor(unicode/256))
         else   -- make surrogate pair for unicode code points above 0xFFFF
            local unicode1 = 0xD800 + math.floor((unicode - 0x10000)/0x400) % 0x400
            local unicode2 = 0xDC00 + (unicode - 0x10000) % 0x400
            return string.char(unicode1 % 256, math.floor(unicode1/256),
                               unicode2 % 256, math.floor(unicode2/256))
         end
      end

      local function convert_string_utf8_to_utf16(str, with_bom)
         return (with_bom and "\255\254" or "")..str:gsub(utf8_char_pattern, convert_char_utf8_to_utf16)
      end

      if not windows_ver then
         local pipe = io_popen"ver"
         windows_ver = pipe:read"*a"
         pipe:close()
      end

      if windows_ver:match"%w+" ~= "Wine" then

         ----------------------------------------------------------------------------------------------------
         -- Invocation of CMD.EXE on WINDOWS
         ----------------------------------------------------------------------------------------------------

         local function convert_string_utf8_to_oem(str, filename)
            local file = assert(io_open(filename, "wb"))    -- create temporary file
            -- convert UTF-8 to UTF-16LE with BOM
            file:write(convert_string_utf8_to_utf16(str.."#", true))
            file:close()
            -- convert UTF-16LE to OEM
            local pipe = io_popen('type "'..filename..'"', "rb")
            local converted = assert(pipe:read"*a":match"^(.*)#")
            pipe:close()
            assert(os_remove(filename))                     -- delete temporary file
            return converted
         end

         local function to_native(str)
            if not (sbcs or mbcs) then
               local pipe = io_popen("cmd /u/d/c echo("..locale_dependent_chars.."$", "rb")
               local converted = pipe:read"*a"
               pipe:close()
               if converted:sub(257, 258) == "$\0" then
                  -- Windows native codepage is Single-Byte Character Set
                  sbcs = true
                  -- create table for fast conversion of UTF-8 characters to Single-Byte Character Set
                  utf8_to_sbcs = {}
                  for code = 128, 255 do
                     local low, high = converted:byte(2*code - 255, 2*code - 254)
                     local unicode = high * 256 + low
                     if unicode > 0x7FF then    -- [1110 xxxx] [10xx xxxx] [10xx xxxx]
                        utf8_to_sbcs[string.char(
                           0xE0 + math.floor(unicode/4096),
                           0x80 + math.floor(unicode/64) % 64,
                           0x80 + unicode % 64)] = string.char(code)
                     elseif unicode > 0x7F then -- [110x xxxx] [10xx xxxx]
                        utf8_to_sbcs[string.char(
                           0xC0 + math.floor(unicode/64),
                           0x80 + unicode % 64)] = string.char(code)
                     end
                  end
               else
                  -- Windows native codepage is Multi-Byte Character Set
                  mbcs = true
                  tempfilespec = getwindowstempfilespec()  -- temporary file for converting unicode strings to MBCS
               end
            end
            if sbcs then
               -- UTF-8 to SBCS
               return (str:gsub(utf8_char_pattern, function(c) return #c > 1 and (utf8_to_sbcs[c] or "?") end))
            else
               -- UTF-8 to MBCS
               -- on multibyte Windows encodings ANSI codepage is the same as OEM codepage
               return convert_string_utf8_to_oem(str, tempfilespec)
            end
         end

         return function (text, title, colors, wait, admit_linebreak_inside_of_a_word)
            text, title = text or "", title or "Press any key"
            if not cfg.use_windows_native_encoding then
               local text_is_utf8,  text_is_ascii7  = is_utf8(text)
               local title_is_utf8, title_is_ascii7 = is_utf8(title)
               if text_is_utf8 and title_is_utf8 then
                  text  = text_is_ascii7  and text  or to_native(text)
                  title = title_is_ascii7 and title or to_native(title)
               end
            end
            local text, width, height =
               geometry_beautifier(cfg, text, one_byte_char_pattern, true, admit_linebreak_inside_of_a_word)
            local fg, bg = get_color_values(colors)
            local lines = {}
            local function add_line(prefix, line)
               table.insert(lines, prefix..line:gsub(".", {
                  ["("]="^(", [")"]="^)", ["&"]="^&",  ["|"]="^|", ["^"]="^^",
                  [">"]="^>", ["<"]="^<", ["%"]="%^<", ['"']="%^>"
               }))
            end
            title = title:sub(1,200):match"%C+" or ""
            -- the following check is needed to avoid invocation of "title /?"
            if title:find'["%%]' and not title:find"/[%s,;=]*%?" then
               add_line("title ", title)
               title = ""
            end
            for line in (text.."\n"):gmatch"(.-)\n" do
               add_line("echo(", line)
            end
            os_execute(
               '"start "'..title:gsub(".", {['"']="'", ["%"]=" % "})..'" '
               ..(wait and "/wait " or "")
               ..'cmd /d/c"'
               ..(width and "mode "..width..","..height.."&" or "")
               ..(fg and "color "..bg[3]..fg[3].."&" or "")
               ..'for /f "tokens=1-3delims=_" %^< in ("%_"_"")do @('..table.concat(lines, "&")..")&"
               ..'pause>nul:""'
            )
         end

      end

      ----------------------------------------------------------------------------------------------------
      -- Invocation of CMD.EXE on Wine
      ----------------------------------------------------------------------------------------------------

      local function initialize_convertor(filename)
         local pipe = io_popen("cmd /u/d/c echo "..locale_dependent_chars.."$", "rb")
         local converted_ansi = pipe:read"*a"
         pipe:close()
         if converted_ansi:sub(257, 258) == "$\0" then
            -- Wine codepage is Single-Byte Character Set
            sbcs = true
            -- create tables for fast conversion UTF-16 to/from Single-Byte Character Set
            ansi_to_utf16 = {}          --  ansi_to_utf16[ansi char] = utf-16 char
            utf16_to_ansi = {}          --  utf16_to_ansi[utf-16 char] = ansi char
            utf16_to_oem = {}           --  utf16_to_oem[utf-16 char] = oem char
            local file = assert(io_open(filename, "wb"))
            file:write(locale_dependent_chars)
            file:close()
            pipe = io_popen("cmd /u/d/c type "..filename, "rb")
            local converted_oem = pipe:read"*a"
            pipe:close()
            for code = 0, 255 do
               local c = string.char(code)
               local w_ansi = code < 128 and c.."\0" or converted_ansi:sub(2*code - 255, 2*code - 254)
               if code < 128 or w_ansi:byte(2) * 256 + w_ansi:byte() > 0x7F then
                  ansi_to_utf16[c] = w_ansi
                  utf16_to_ansi[w_ansi] = c
               end
               local w_oem = code < 128 and w_ansi or converted_oem:sub(2*code - 255, 2*code - 254)
               if code < 128 or w_oem:byte(2) * 256 + w_oem:byte() > 0x7F then
                  utf16_to_oem[w_oem] = c
               end
            end
         else
            -- Wine codepage is Multi-Byte Character Set
            mbcs = true
         end
      end

      return function (text, title, colors, wait, admit_linebreak_inside_of_a_word)
         text, title = text or "", (title or "Press any key"):sub(1,200):match"%C+" or ""
         local text_is_utf8,  text_is_ascii7  = is_utf8(text)
         local title_is_utf8, title_is_ascii7 = is_utf8(title)
         local char_pattern =
            (not cfg.use_windows_native_encoding and text_is_utf8 and title_is_utf8)
            and utf8_char_pattern
            or one_byte_char_pattern
         local text = geometry_beautifier(cfg, text, char_pattern, true, admit_linebreak_inside_of_a_word, 25)
         local fg, bg = get_color_values(colors)
         local tempfilename = getwindowstempfilespec()       -- temporary file for saving text
         -- convert title to ANSI codepage
         if not title_is_ascii7 and char_pattern == utf8_char_pattern then
            if not (sbcs or mbcs) then
               initialize_convertor(tempfilename)
            end
            if sbcs then
               title = convert_string_utf8_to_utf16(title)
                  :gsub("..", function(w) return utf16_to_ansi[w] or "?" end)
            end
         end
         -- convert text to OEM codepage and save to temporary file
         text = (text.."\n"):gsub("\n", "\r\n")
         if not text_is_ascii7 then
            if not (sbcs or mbcs) then
               initialize_convertor(tempfilename)
            end
            if sbcs then
               if char_pattern == utf8_char_pattern then
                  text = convert_string_utf8_to_utf16(text)
               else
                  text = text:gsub(".", ansi_to_utf16)
               end
               text = text:gsub("..", function(w) return utf16_to_oem[w] or "?" end)
            end
         end
         local file = assert(io_open(tempfilename, "wb"))
         file:write(text)
         file:close()
         os_execute(
            "start "
            ..(wait and "/wait " or "")
            ..'cmd /d/c "'
            ..(fg and "color "..bg[3]..fg[3].."&" or "")
            .."title "..title:gsub("/%?", "/ ?")  -- to avoid invocation of "title /?"
               :gsub(".", {["&"]="^&", ["|"]="^|", ["^"]="^^", [">"]="^>", ["<"]="^<", ["%"]=" % ", ['"']="'"})
            .."&type "..tempfilename
            .."&del "..tempfilename.." 2>nul:"
            ..'&pause>nul:"'
         )
      end

   end

   ----------------------------------------------------------------------------------------------------
   -- *NIX
   ----------------------------------------------------------------------------------------------------

   local function q(text)   -- quoting under *nix shells
      return "'"..text:gsub("'","'\\''").."'"
   end

   if not system_name then
      local pipe = io_popen"uname"
      system_name = pipe:read"*a":match"%C+"
      pipe:close()
   end
   local is_macosx = system_name == "Darwin"
   local is_cygwin = system_name:find"^CYGWIN" or system_name:find"^MINGW" or system_name:find"^MSYS"
   local xless_system =
      is_macosx and cfg.always_use_terminal_app_under_macosx
      or is_cygwin and cfg.always_use_cmd_exe_under_cygwin
   if not xless_system and (is_macosx or is_cygwin) then
      if not xinit_proc_cnt then
         local pipe = io_popen"(ps ax|grep /bin/xinit|grep -c -v grep)2>/dev/null"
         xinit_proc_cnt = pipe:read"*n" or 0
         pipe:close()
      end
      xless_system = xinit_proc_cnt == 0
   end

   if not xless_system then

      ----------------------------------------------------------------------------------------------------
      -- Auto-detection of terminal emulator on *nix
      ----------------------------------------------------------------------------------------------------

      local function get_terminal_priority(terminal)
         return terminal == cfg.terminal and math.huge or terminals[terminal].priority or -math.huge
      end
      local terminal_names = {}
      for terminal in pairs(terminals) do
         table.insert(terminal_names, terminal)
      end
      table.sort(terminal_names,
         function(a, b)
            local pr_a, pr_b = get_terminal_priority(a), get_terminal_priority(b)
            return pr_a < pr_b or pr_a == pr_b and a < b
         end
      )
      local command, delta = "exit 0", 70
      for k, terminal in ipairs(terminal_names) do
         command = "command -v "..terminal.."&&exit "..k+delta.."||"..command
      end
      local function run_quietly_and_get_exit_code(shell_command)
         local pipe = io_popen("("..shell_command..")>/dev/null 2>&1;echo $?")
         local exit_code = pipe:read"*n" or -1
         pipe:close()
         return exit_code
      end
      local terminal = terminal_names[run_quietly_and_get_exit_code(command) - delta]

      if terminal then

         ----------------------------------------------------------------------------------------------------
         -- Invocation of terminal emulator on *nix
         ----------------------------------------------------------------------------------------------------

         -- choosing a method of waiting for user pressed a key
         local mc
         if terminals[terminal].option_command then
            wait_key_method_code = wait_key_method_code or
               run_quietly_and_get_exit_code"command -v dd&&command -v stty&&exit 69||command -v bash&&exit 68||exit 0"
            mc = wait_key_method_code
         end
         local method = ({
            [68] = {default_title = "Press any key",
                    shell = "bash",
                    wait_a_key = "read -rsn 1"},
            [69] = {default_title = "Press any key",
                    shell = "sh",
                    wait_a_key = "stty -echo raw;dd bs=1 count=1 >/dev/null 2>&1;stty sane"}
         })[mc] or {default_title = "Press Enter",
                    shell = "sh",
                    wait_a_key = "read a"}

         local function nop(...) return ... end
         local exact_geometry_is_unknown = not terminals[terminal].option_geometry

         return function (text, title, colors, wait, admit_linebreak_inside_of_a_word)
            title = title or method.default_title
            local text, width, height = geometry_beautifier(
               cfg, text, utf8_char_pattern, false, admit_linebreak_inside_of_a_word, exact_geometry_is_unknown)
            local fg, bg = get_color_values(colors, terminals[terminal].only_8_colors)
            if fg and not terminals[terminal].option_colors then
               text = "\27["..fg[1]..";"..bg[2].."m\27[J"..text
            end
            os_execute(
               ((is_cygwin or is_macosx) and "DISPLAY=:0 " or "")
               ..terminal.." "
               ..(terminals[terminal].options_misc or "").." "
               ..(fg
                  and terminals[terminal].option_colors and terminals[terminal].option_colors:format(fg[4], bg[4]).." "
                  or "")
               ..(width
                  and (terminals[terminal].option_geometry or ""):format(width, height).." "
                  or "")
               ..terminals[terminal].option_title.." "..q(title).." "
               ..(terminals[terminal].option_command
                  and
                     terminals[terminal].option_command.." "..
                     (terminals[terminal].command_requires_quoting and q or nop)(
                        method.shell.." -c "..q("echo "..q(text)..";"..method.wait_a_key)
                     )..">/dev/null 2>&1"
                  or
                     terminals[terminal].option_text.." "..q((terminals[terminal].text_preprocessor or nop)(text))
               )
               ..(wait and "" or " &")
            )
         end

      end

   end

   if is_macosx then

      ----------------------------------------------------------------------------------------------------
      -- Invocation of Terminal.app on MacOSX
      ----------------------------------------------------------------------------------------------------

      local function q_as(text)  -- quoting under AppleScript
         return '"'..text:gsub('[\\"]', "\\%0")..'"'
      end

      local display_CLOSE_THIS_WINDOW_message = true

      return function (text, title, colors, wait, admit_linebreak_inside_of_a_word)
         title = title or "Press any key"
         local text, width, height =
            geometry_beautifier(cfg, text, utf8_char_pattern, false, admit_linebreak_inside_of_a_word)
         local fg, bg = get_color_values(colors, nil, true)
         local r, g, b = bg[4]:match"(%x%x)(%x%x)(%x%x)"
         local rgb = "{"..tonumber(r..r, 16)..","..tonumber(g..g, 16)..","..tonumber(b..b, 16).."}"
         os_execute(  -- "shell command" nested into 'AppleScript' nested into "shell command"
            "osascript -e "..q(
               'set w to 1\n'                                   -- 1 second (increase it when running Mac OS X as VM guest)
            .. 'if app "Terminal" is running then set w to 0\n' -- 0 seconds
            .. 'do shell script "open -a Terminal ."\n'
            .. 'delay w\n' -- Terminal.app may take about a second to start, this delay happens only once
            .. 'tell app "Terminal"\n'
            ..    'tell window 1\n'
            ..       (width and string.format(
                     'set number of columns to %d\n'
            ..       'set number of rows to %d\n', width, height) or '')
            ..       'set normal text color to '..rgb..'\n'
            ..       'set background color to '..rgb..'\n'
            ..       'set custom title to '..q_as(title)..'\n'
            ..       'do script '..q_as(
                        "echo $'\\ec\\e['"..q(fg[1].."m"..text)..";read -rsn 1;echo $'\\e[H\\e[J"
            ..          (wait and display_CLOSE_THIS_WINDOW_message and "\n"
            ..          "  PLEASE CLOSE THIS WINDOW TO CONTINUE\n\n" -- this will be displayed only once
            ..          "The following profile setting may be useful:\n"
            ..          "Terminal -> Preferences -> Settings -> Shell\n"
            ..          "When the shell exits: Close the window" or "").."\\e[0m';exit"
                     )..' in it\n'
            ..       (wait and
                     'set w to its id\n'
            ..     'end\n'
            ..     'repeat while id of every window contains w\n'
            ..        'delay 0.1\n' or '')
            ..     'end\n'
            .. 'end\n'
            )..">/dev/null 2>&1"
         )
         display_CLOSE_THIS_WINDOW_message = not wait and display_CLOSE_THIS_WINDOW_message
      end

   end

   if is_cygwin then

      ----------------------------------------------------------------------------------------------------
      -- Invocation of CMD.EXE on CYGWIN
      ----------------------------------------------------------------------------------------------------

      return function (text, title, colors, wait, admit_linebreak_inside_of_a_word)
         local text, width, height =
            geometry_beautifier(cfg, text, utf8_char_pattern, true, admit_linebreak_inside_of_a_word)
         local fg, bg = get_color_values(colors)
         local lines = {}
         local function add_line(prefix, line)
            table.insert(lines, prefix..line:gsub(".", {
               ["("]="^(", [")"]="^)", ["&"]="^&",  ["|"]="^|", ["^"]="^^",
               [">"]="^>", ["<"]="^<", ["%"]="%^<", ['"']="%^>", ["'"]="'\\''"
            }))
         end
         title = (title or "Press any key"):sub(1,200):match"%C+" or ""
         if title:find'["%%]' and not title:find"/[%s,;=]*%?" then
            add_line("title ", title)
            title = ""
         end
         for line in (text.."\n"):gmatch"(.-)\n" do
            add_line("echo(", line)
         end
         os_execute(
            'cmd /d/c \'for %\\ in (_)do @'
            ..'start %~x"'..title:gsub("[\"']", "'\\''"):gsub("%%", " %% ")..'%~x" '
            ..(wait and "/wait " or "")
            ..'cmd /d/c%~x"'
            ..(width and "mode "..width..","..height.."&" or "")
            ..(fg and "color "..bg[3]..fg[3].."&" or "")
            ..'for /f %~x"tokens=1-3delims=_" %^< in (%~x"%_""")do @('..table.concat(lines, "&")..')&pause>nul:%~x"\''
         )
      end

   end

   error(
      "Terminal emulator auto-detection failed.\n"..
      '"alert" is not aware of the terminal emulator your are using.\n'..
      'Please add your terminal emulator to the "terminals" table.', 3)

end  -- end of function "create_function_alert()"

local function result(x)
   -- argument may be nil, a string or a function returning a string
   -- retuned value is nil or a string
   if type(x) == "function" then return x() else return x end
end

local function create_new_instance_of_function_alert(old_config, config_update)  -- factory of lazy wrapper for alert()
   local cfg = {}
   for key in pairs(initial_config) do
      if config_update[key] ~= nil then
         cfg[key] = config_update[key]
      elseif old_config[key] ~= NIL then
         cfg[key] = old_config[key]
      end
   end
   local alert
   return
      function(...)
         local arg1, cfg_update = ...
         if arg1 == nil and type(cfg_update) == "table" then  -- special form of invocation (user wants to create a function)
            -- create new instance of function with modified configuration
            return create_new_instance_of_function_alert(cfg, cfg_update)
         else                                           -- usual form of invocation (user wants to create a window with text)
            -- create alert window
            alert = alert or create_function_alert(cfg)   -- here alert() is actually gets created (deferred/"lazy" creation)
            local text, title, colors, wait, admit_linebreak_inside_of_a_word = ...
            if type(text) == "table" then  -- handle invocation with named arguments
               text, title, colors, wait, admit_linebreak_inside_of_a_word =
                  text.text, text.title, text.colors, text.wait, text.admit_linebreak_inside_of_a_word
            end
            -- applying default argument values if needed
            if wait == nil then
               wait = cfg.default_arg_wait
            end
            if admit_linebreak_inside_of_a_word == nil then
               admit_linebreak_inside_of_a_word = cfg.default_arg_admit_linebreak_inside_of_a_word
            end
            -- default arguments for text/title/colors are allowed to be nils, strings or functions returning a string
            text   = text   or result(cfg.default_arg_text)
            title  = title  or result(cfg.default_arg_title)
            colors = colors or result(cfg.default_arg_colors)
            -- nothing will be returned, the keyword "return" is here just for tail call
            return alert(text, title, colors, wait, admit_linebreak_inside_of_a_word)
         end
      end
end

return create_new_instance_of_function_alert(initial_config, {})

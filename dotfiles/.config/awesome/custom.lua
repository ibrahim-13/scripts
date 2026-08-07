-- custom.lua
-- A custom module for awesome WM.
--
-- It builds the "applications" menu and, right below it, a submenu
-- (labelled "custom") in the main menu. The custom submenu contains:
--   * every user-defined command (persisted on disk),
--   * a "Natural Scroll: <state>" toggle for the Xorg pointer devices
--     (the chosen state is persisted and re-applied on startup),
--   * a "Display Always On: <state>" toggle that disables/re-enables X11
--     screen blanking and DPMS (not persisted; always starts false), and
--   * an "Edit cmd" entry that opens the commands file in the editor
--     (creating a sample file first if none exists).
--
-- It also persists the last selected tag layout (see get_default_layout /
-- save_layout), so the layout chosen from the wibar survives restarts.
--
-- Wire it up from rc.lua after the main menu has been created:
--
--     local custom = require("custom")
--     ...
--     custom.init(mymainmenu, 2)   -- applications at 2, custom at 3

local awful     = require("awful")
local naughty   = require("naughty")
local gears     = require("gears")
local wibox     = require("wibox")
local menubar   = require("menubar")
local beautiful = require("beautiful")
local xresources = require("beautiful.xresources")
local dpi        = xresources.apply_dpi

local custom = {}

-- Where user-defined commands are persisted. Same directory as the rest of
-- the awesome configuration files (get_configuration_dir has a trailing "/").
local cmds_file = gears.filesystem.get_configuration_dir() .. "custom_cmds.txt"

-- Where option state (natural scroll, selected layout, ...) is persisted.
-- File format: one option per line, "key\tvalue".
local state_file = gears.filesystem.get_configuration_dir() .. "custom_state.txt"

-- Runtime state -------------------------------------------------------------
custom.mainmenu      = nil    -- reference to the main menu we live in
custom.index         = nil    -- our position inside that main menu
custom.natural_scroll = false -- current natural-scrolling state (bool)
custom.display_always_on = false -- current "keep display on" state (bool, not persisted)

-- Persistence ---------------------------------------------------------------
-- File format: one command per line, "NAME=COMMAND". Lines starting with "#"
-- are comments. The name may contain spaces; the split happens at the first
-- "=", and both sides are trimmed of surrounding whitespace.

local function trim(s)
    return s:match("^%s*(.-)%s*$")
end

local function load_cmds()
    local cmds = {}
    local f = io.open(cmds_file, "r")
    if f then
        for line in f:lines() do
            if not line:match("^%s*#") then
                local name, cmd = line:match("^([^=]-)=(.*)$")
                if name then
                    name = trim(name)
                    cmd  = trim(cmd)
                    if name ~= "" and cmd ~= "" then
                        table.insert(cmds, { name = name, cmd = cmd })
                    end
                end
            end
        end
        f:close()
    end
    return cmds
end

-- Option-state persistence ---------------------------------------------------

local function load_state()
    local state = {}
    local f = io.open(state_file, "r")
    if f then
        for line in f:lines() do
            local key, value = line:match("^(.-)\t(.*)$")
            if key and key ~= "" then state[key] = value end
        end
        f:close()
    end
    return state
end

local function save_state(key, value)
    local state = load_state()
    state[key] = tostring(value)
    local f = io.open(state_file, "w")
    if f then
        for k, v in pairs(state) do
            f:write(k .. "\t" .. v .. "\n")
        end
        f:close()
        return true
    end
    naughty.notify({
        preset = naughty.config.presets.critical,
        title  = "custom menu",
        text   = "Could not write to " .. state_file,
    })
    return false
end

-- Natural scrolling (Xorg / libinput) --------------------------------------
-- Reads the current state synchronously (used once at init). Returns a bool.
-- Looks at the first pointer device exposing the libinput property.

-- Whether the `xinput` binary is on $PATH. Checked once at load time.
local xinput_available = os.execute("command -v xinput >/dev/null 2>&1")
-- os.execute returns differ between Lua 5.1 (0) and 5.2+ (true) on success.
xinput_available = (xinput_available == true or xinput_available == 0)

local function notify_no_xinput()
    naughty.notify({
        preset = naughty.config.presets.critical,
        title  = "custom menu",
        text   = "'xinput' is not installed — cannot control natural scrolling.",
    })
end

local function detect_natural_scroll()
    if not xinput_available then return false end
    local shell = [[
        for id in $(xinput list --id-only 2>/dev/null); do
            val=$(xinput list-props "$id" 2>/dev/null \
                  | grep 'Natural Scrolling Enabled (' \
                  | grep -o '[01]$' | head -n1)
            if [ -n "$val" ]; then echo "$val"; break; fi
        done
    ]]
    local f = io.popen(shell)
    if not f then return false end
    local out = f:read("*a") or ""
    f:close()
    out = out:gsub("%s+", "")
    return out == "1"
end

-- Applies the given state to every device that exposes the libinput
-- natural-scroll property. Used on toggle and to restore the saved state
-- at startup.
local function apply_natural_scroll(enabled)
    local shell = string.format([[
        for id in $(xinput list --id-only 2>/dev/null); do
            if xinput list-props "$id" 2>/dev/null \
               | grep -q 'Natural Scrolling Enabled ('; then
                xinput set-prop "$id" 'libinput Natural Scrolling Enabled' %d 2>/dev/null
            fi
        done
    ]], enabled and 1 or 0)
    -- Fire-and-forget: we don't consume the command's output, and using a
    -- callback-based spawn (easy_async_with_shell / with_line_callback) breaks
    -- on GLib >= 2.80 where Gio.UnixInputStream was moved to the GioUnix
    -- namespace (spawn.lua: "attempt to index a nil value (field
    -- 'UnixInputStream')"). with_shell needs no stdout stream, so it is safe.
    awful.spawn.with_shell(shell)
end

function custom.toggle_natural_scroll()
    if not xinput_available then
        notify_no_xinput()
        return
    end
    -- The new state is deterministic, so update it without awaiting the run.
    custom.natural_scroll = not custom.natural_scroll
    apply_natural_scroll(custom.natural_scroll)
    save_state("natural_scroll", custom.natural_scroll)
    custom.rebuild_menu()
end

-- Display Always On -----------------------------------------------------------
-- Toggles whether the screen is allowed to blank/sleep. Unlike natural
-- scroll, this state is NOT persisted: it always starts as `false` (normal
-- blanking behaviour) on every awesome restart/login, so a machine never
-- boots up with blanking accidentally left disabled.

local xset_available = os.execute("command -v xset >/dev/null 2>&1")
xset_available = (xset_available == true or xset_available == 0)

local function notify_no_xset()
    naughty.notify({
        preset = naughty.config.presets.critical,
        title  = "custom menu",
        text   = "'xset' is not installed — cannot control display blanking.",
    })
end

-- Disable/re-enable the X11 screensaver and DPMS via xset.
-- This is stateless (two shell commands, no background process to track)
-- and is sufficient when the screen is blanked by X itself rather than by
-- systemd/logind-triggered suspend.
local function apply_display_always_on(enabled)
    local shell
    if enabled then
        shell = "xset s off; xset -dpms"
    else
        shell = "xset s on; xset +dpms"
    end
    awful.spawn.with_shell(shell)
end

-- "noblank"/"blank" instead of "off"/"on".
-- Changes *how* the screensaver blanks the video signal rather than turning the screensaver
-- mechanism off/on outright. Still stateless (no background process), just
-- a different xset sub-command; some drivers reportedly respect `noblank`
-- more reliably than `s off`. Swap this in for apply_display_always_on
-- above if `s off` ever turns out not to be enough on a given machine.
--
-- local function apply_display_always_on(enabled)
--     if enabled then
--         awful.spawn.with_shell("xset s noblank; xset -dpms")
--     else
--         awful.spawn.with_shell("xset s blank; xset +dpms")
--     end
-- end

-- Hold a systemd-logind idle/sleep
-- inhibitor instead of touching xset at all. This operates at the
-- systemd/logind level rather than X11, so it stops logind-triggered
-- idle/suspend actions but does NOT by itself stop the X11 screensaver or
-- DPMS blanking — only useful if something other than X is putting the
-- screen/system to sleep. Requires tracking the spawned process's PID so it
-- can be killed again when toggled off — more state to manage than the
-- stateless xset approach.
--
-- custom.display_always_on_pid = nil
--
-- local function apply_display_always_on(enabled)
--     if enabled then
--         awful.spawn(
--             "systemd-inhibit --what=idle:sleep:handle-lid-switch " ..
--             "--who=awesome --why='Display Always On' sleep infinity",
--             function(c) custom.display_always_on_pid = c.pid end
--         )
--     else
--         if custom.display_always_on_pid then
--             awful.spawn.with_shell("kill " .. custom.display_always_on_pid)
--             custom.display_always_on_pid = nil
--         end
--     end
-- end

-- belt-and-suspenders combination of the
-- Covering both the X11 blanking source and systemd/logind-triggered suspend at the
-- same time. Most complete, but also the most complex: it needs both the
-- xset calls and PID tracking for the inhibitor process.
--
-- custom.display_always_on_pid = nil
--
-- local function apply_display_always_on(enabled)
--     if enabled then
--         awful.spawn.with_shell("xset s off; xset -dpms")
--         awful.spawn(
--             "systemd-inhibit --what=idle:sleep:handle-lid-switch " ..
--             "--who=awesome --why='Display Always On' sleep infinity",
--             function(c) custom.display_always_on_pid = c.pid end
--         )
--     else
--         awful.spawn.with_shell("xset s on; xset +dpms")
--         if custom.display_always_on_pid then
--             awful.spawn.with_shell("kill " .. custom.display_always_on_pid)
--             custom.display_always_on_pid = nil
--         end
--     end
-- end

function custom.toggle_display_always_on()
    if not xset_available then
        notify_no_xset()
        return
    end
    custom.display_always_on = not custom.display_always_on
    apply_display_always_on(custom.display_always_on)
    custom.rebuild_menu()
end

-- Layout persistence ---------------------------------------------------------
-- The last layout selected (layoutbox clicks, Mod+space, ...) is saved by
-- name and used as the default layout for all tags on the next startup.

function custom.save_layout(t)
    save_state("layout", awful.layout.getname(t.layout))
end

function custom.get_default_layout()
    local name = load_state().layout
    if name then
        for _, l in ipairs(awful.layout.layouts) do
            if awful.layout.getname(l) == name then return l end
        end
    end
    return awful.layout.layouts[1]
end

-- Edit-commands entry ---------------------------------------------------------
-- Opens the commands file in the configured editor (same way rc.lua opens
-- the awesome config file via the global `editor_cmd`). If the file does
-- not exist yet, a sample file is created first.

function custom.edit_cmds()
    if not gears.filesystem.file_readable(cmds_file) then
        local f = io.open(cmds_file, "w")
        if f then
            f:write("# Custom menu commands: one per line, \"NAME=COMMAND\".\n")
            f:write("# Lines starting with '#' are comments and are ignored.\n")
            f:write("# The name may contain spaces; the first '=' separates\n")
            f:write("# name from command, and both sides are trimmed, e.g.:\n")
            f:write("#   SOME NAME = COMMAND PARAM1 PARAM2\n")
            f:write("Sample cmd = echo hello\n")
            f:close()
        else
            naughty.notify({
                preset = naughty.config.presets.critical,
                title  = "custom menu",
                text   = "Could not create " .. cmds_file,
            })
            return
        end
    end
    awful.spawn(editor_cmd .. " " .. cmds_file)
end

-- CPU / memory usage widget ---------------------------------------------------
-- A textbox for the wibar showing current CPU and memory usage percentages,
-- refreshed on a timer. Both values are read from /proc (no external
-- processes spawned):
--   * CPU: the aggregate "cpu" line of /proc/stat. Usage is computed from
--     the delta between two consecutive reads (the very first reading is
--     therefore the average since boot).
--   * Memory: MemTotal/MemAvailable from /proc/meminfo.
--
-- Usage from rc.lua:
--     mycpumem = custom.cpu_mem_widget()                -- 15 s refresh
--     mycpumem = custom.cpu_mem_widget({ timeout = 5 }) -- custom refresh

function custom.cpu_mem_widget(args)
    args = args or {}
    local timeout = args.timeout or 15

    local widget = wibox.widget {
        widget = wibox.widget.textbox,
        text   = " cpu --% mem --% ",
    }

    -- Previous /proc/stat totals, for delta-based CPU usage.
    local prev_total, prev_idle = 0, 0

    local function cpu_percent()
        local f = io.open("/proc/stat", "r")
        if not f then return nil end
        local line = f:read("*l") or ""
        f:close()

        -- "cpu  user nice system idle iowait irq softirq steal ..."
        local fields = {}
        for n in line:gmatch("%d+") do table.insert(fields, tonumber(n)) end
        if #fields < 4 then return nil end

        local total = 0
        for _, n in ipairs(fields) do total = total + n end
        local idle = fields[4] + (fields[5] or 0) -- idle + iowait

        local dtotal = total - prev_total
        local didle  = idle - prev_idle
        prev_total, prev_idle = total, idle

        if dtotal <= 0 then return nil end
        return (dtotal - didle) / dtotal * 100
    end

    local function mem_percent()
        local f = io.open("/proc/meminfo", "r")
        if not f then return nil end
        local total, available
        for line in f:lines() do
            local k, v = line:match("^(%w+):%s+(%d+)")
            if k == "MemTotal" then total = tonumber(v)
            elseif k == "MemAvailable" then available = tonumber(v) end
            if total and available then break end
        end
        f:close()
        if not (total and available) or total == 0 then return nil end
        return (total - available) / total * 100
    end

    local function fmt(v)
        return v and string.format("%.0f%%", v) or "--%"
    end

    gears.timer {
        timeout   = timeout,
        call_now  = true,
        autostart = true,
        callback  = function()
            widget.text = string.format(
                " cpu %s mem %s ", fmt(cpu_percent()), fmt(mem_percent()))
        end,
    }

    return widget
end

-- Menu building -------------------------------------------------------------

-- Measure a label the way awesome will actually draw it: same Pango stack as
-- wibox.widget.textbox, same font and screen DPI. A per-character estimate is
-- not good enough for a proportional font -- in "sans 10" a character is
-- anywhere from 3px ("l") to 12px ("W") wide. Set up lazily; if Pango is not
-- reachable for any reason we degrade to a rough estimate rather than break
-- the menus.
local pango_layout = nil   -- nil = not tried yet, false = unavailable

local function text_width(text)
    if pango_layout == nil then
        local ok, layout = pcall(function()
            local lgi = require("lgi")
            local ctx = lgi.PangoCairo.font_map_get_default():create_context()
            ctx:set_resolution(xresources.get_dpi())
            -- Measure the way the text is drawn, not the way textbox:fit
            -- measures it. Drawing goes through a cairo context whose font
            -- options hint glyph advances, so hinted text can come out a few
            -- pixels wider than an unhinted measurement -- and a label that
            -- does not fit gets wrapped by Pango, which in a one-line-tall
            -- menu entry simply hides the tail of the name. Best-effort: plain
            -- unhinted measurement if this cairo API is not reachable.
            pcall(function()
                local fo = lgi.cairo.FontOptions.create()
                fo:set_hint_metrics(lgi.cairo.HintMetrics.ON)
                ctx:set_font_options(fo)
            end)
            return lgi.Pango.Layout.new(ctx)
        end)
        pango_layout = ok and layout or false
    end
    if not pango_layout then
        return #text * 7
    end
    pango_layout:set_font_description(
        beautiful.get_font(beautiful.menu_font or beautiful.font))
    pango_layout:set_text(text, -1)
    local _, logical = pango_layout:get_pixel_extents()
    return logical.width
end

-- awful.menu does not auto-size a menu to its content, so long labels get
-- cropped at the default width (beautiful.menu_width). Attach a `theme.width`
-- to the items table (menu.new reads it) that fits the widest label plus:
--   * the icon gutter awful.menu.entry reserves on the left of every entry --
--     theme.height + dpi(2), whether or not the entry has an icon,
--   * the same gutter again on the right, so the label sits between matching
--     margins instead of running to the edge, and
--   * a submenu indicator, scaled to the entry height -- only when some entry
--     opens a submenu.
-- The right-hand gutter doubles as slack: text_width measures a label to the
-- pixel, so without it a label that exactly fits has nothing to give if the
-- drawn glyphs land a pixel or two wider.
local function set_menu_width(items)
    local height = beautiful.menu_height or dpi(16)
    local gutter = height + dpi(2)
    local widest, has_submenu = 0, false
    for _, it in ipairs(items) do
        local w = text_width(tostring(it[1] or ""))
        if w > widest then widest = w end
        if type(it[2]) == "table" then has_submenu = true end
    end
    local width = gutter + widest + gutter
    if has_submenu then width = width + height end
    items.theme = { width = math.ceil(width) }
    return items
end
custom.set_menu_width = set_menu_width

function custom.build_items()
    local items = {}

    -- User-defined commands.
    for _, c in ipairs(load_cmds()) do
        table.insert(items, { c.name, function() awful.spawn(c.cmd) end })
    end

    -- Natural-scroll toggle.
    local ns_label = xinput_available
        and ("Natural Scroll: " .. tostring(custom.natural_scroll))
        or  "Natural Scroll: unavailable"
    table.insert(items, {
        ns_label,
        function() custom.toggle_natural_scroll() end,
    })

    -- Display-always-on toggle.
    local dao_label = xset_available
        and ("Display Always On: " .. tostring(custom.display_always_on))
        or  "Display Always On: unavailable"
    table.insert(items, {
        dao_label,
        function() custom.toggle_display_always_on() end,
    })

    -- Edit-commands entry (kept last).
    table.insert(items, { "Edit cmd", function() custom.edit_cmds() end })

    return set_menu_width(items)
end

-- Replace our submenu in-place so label/state changes take effect.
function custom.rebuild_menu()
    if not (custom.mainmenu and custom.index) then return end
    custom.mainmenu:delete(custom.index)
    custom.mainmenu:add({ "custom", custom.build_items() }, custom.index)
end

-- Entry point: register the submenu into `mainmenu` at position `index`.
-- Generate the "applications" menu asynchronously and add it at
-- `app_index`; the "custom" submenu is then added right below it.
function custom.init(mainmenu, app_index)
    custom.mainmenu = mainmenu
    custom.index    = app_index + 1

    -- Restore the persisted natural-scroll state; fall back to whatever the
    -- devices currently report when nothing has been saved yet.
    local saved_ns = load_state().natural_scroll
    if saved_ns ~= nil and xinput_available then
        custom.natural_scroll = (saved_ns == "true")
        apply_natural_scroll(custom.natural_scroll)
    else
        custom.natural_scroll = detect_natural_scroll()
    end

    menubar.utils.terminal = terminal -- for apps that require a terminal

    menubar.menu_gen.generate(function(entries)
        local items = {}
        for _, v in ipairs(entries) do
            table.insert(items, { v.name, v.cmdline, v.icon })
        end
        mainmenu:add({ "applications", set_menu_width(items) }, app_index)
        -- Add the custom submenu right below "applications".
        mainmenu:add({ "custom", custom.build_items() }, custom.index)
    end)
end

return custom

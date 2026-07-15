-- custom.lua
-- A custom module for awesome WM.
--
-- It builds the "applications" menu and, right below it, a submenu
-- (labelled "custom") in the main menu. The custom submenu contains:
--   * every user-defined command (persisted on disk),
--   * a "Natural Scroll: <state>" toggle for the Xorg pointer devices
--     (the chosen state is persisted and re-applied on startup), and
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

local awful   = require("awful")
local naughty = require("naughty")
local gears   = require("gears")
local menubar = require("menubar")

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

-- Menu building -------------------------------------------------------------

-- awful.menu does not auto-size a menu to its content, so long labels get
-- cropped at the default width. Attach a `theme.width` to the items table
-- (menu.new reads it) large enough to fit the longest label.
local function set_menu_width(items)
    local longest = 0
    for _, it in ipairs(items) do
        local label = tostring(it[1] or "")
        if #label > longest then longest = #label end
    end
    -- ~7px per char, plus room for icon, submenu arrow and margins.
    items.theme = { width = math.max(200, longest * 7 + 60) }
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

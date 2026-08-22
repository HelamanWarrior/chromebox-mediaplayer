-- mpv Lua script
--
-- Automatically select the best available Hyprland refresh rate
-- for the video's FPS.
--
-- Designed for Hyprland 0.55+ using the Lua config provider.
--
-- Only modes matching the monitor's CURRENT resolution are considered.
--
-- The exact original mode is restored when playback ends.

local utils = require 'mp.utils'


------------------------------------------------------------
-- State
------------------------------------------------------------

local changed_monitor = nil
local original_mode = nil


------------------------------------------------------------
-- Get active/focused monitor
------------------------------------------------------------

local function get_active_monitor()
    local handle = io.popen("hyprctl -j monitors")

    if not handle then
        mp.msg.error("Failed to run hyprctl")
        return nil
    end

    local result = handle:read("*a")
    handle:close()

    local ok, monitors = pcall(utils.parse_json, result)

    if not ok or not monitors or #monitors == 0 then
        mp.msg.error("Failed to parse hyprctl monitor JSON")
        return nil
    end

    -- Prefer the focused monitor.
    for _, mon in ipairs(monitors) do
        if mon.focused then
            return mon
        end
    end

    -- Fallback.
    return monitors[1]
end


------------------------------------------------------------
-- Save original monitor configuration
------------------------------------------------------------

local function save_original_mode(mon)
    if not mon or original_mode then
        return
    end

    changed_monitor = mon.name

    original_mode = {
        width = mon.width,
        height = mon.height,
        refresh = mon.refreshRate,
        x = mon.x,
        y = mon.y,
        scale = mon.scale,
        transform = mon.transform,
    }

    mp.msg.info(string.format(
        "Saved original mode for %s: %dx%d@%.3fHz",
        mon.name,
        mon.width,
        mon.height,
        mon.refreshRate
    ))
end


------------------------------------------------------------
-- Get available refresh rates for CURRENT resolution
------------------------------------------------------------

local function get_available_refresh_rates(mon)
    local rates = {}

    if not mon or not mon.availableModes then
        return rates
    end

    local wanted_width = mon.width
    local wanted_height = mon.height

    for _, mode in ipairs(mon.availableModes) do

        -- Example:
        -- 2560x1080@59.98Hz
        local width, height, refresh = mode:match(
            "^(%d+)x(%d+)@([%d%.]+)Hz$"
        )

        width = tonumber(width)
        height = tonumber(height)
        refresh = tonumber(refresh)

        if width and height and refresh then

            -- Only consider modes at the CURRENT resolution.
            if width == wanted_width and height == wanted_height then

                -- Avoid duplicate refresh rates.
                local duplicate = false

                for _, existing in ipairs(rates) do
                    if math.abs(existing - refresh) < 0.01 then
                        duplicate = true
                        break
                    end
                end

                if not duplicate then
                    table.insert(rates, refresh)
                end
            end
        end
    end

    table.sort(rates)

    return rates
end


------------------------------------------------------------
-- Find the best refresh rate for the video FPS
------------------------------------------------------------

local function find_best_refresh(fps, rates, original_refresh)
    if not fps or fps <= 0 then
        return original_refresh
    end

    local best = nil
    local best_error = math.huge

    -- Maximum acceptable relative cadence error.
    -- 0.5% is deliberately conservative.
    local tolerance = 0.005

    for _, hz in ipairs(rates) do
        local multiple = hz / fps
        local nearest = math.floor(multiple + 0.5)

        if nearest >= 1 then
            local error = math.abs(
                multiple - nearest
            ) / nearest

            if error <= tolerance then
                if error < best_error then
                    best_error = error
                    best = hz
                elseif math.abs(error - best_error) < 0.00001 then
                    -- If cadence is equally good, prefer lower Hz.
                    if not best or hz < best then
                        best = hz
                    end
                end
            end
        end
    end

    -- No genuinely good cadence match:
    -- preserve the monitor's original refresh.
    return best or original_refresh
end

------------------------------------------------------------
-- Execute Hyprland Lua monitor configuration
------------------------------------------------------------

local function set_hyprland_monitor(args)
    local parts = {}

    for key, value in pairs(args) do

        local formatted

        if type(value) == "string" then

            -- Escape characters that could break the Lua string.
            value = value
                :gsub("\\", "\\\\")
                :gsub('"', '\\"')

            formatted = string.format(
                '%s = "%s"',
                key,
                value
            )

        elseif type(value) == "number" then

            formatted = string.format(
                "%s = %s",
                key,
                tostring(value)
            )

        elseif type(value) == "boolean" then

            formatted = string.format(
                "%s = %s",
                key,
                tostring(value)
            )
        end

        if formatted then
            table.insert(parts, formatted)
        end
    end

    local lua_table = table.concat(parts, ", ")

    local cmd = string.format(
        "hyprctl eval 'hl.monitor({ %s })'",
        lua_table
    )

    mp.msg.info("Hyprland command: " .. cmd)

    local result = os.execute(cmd)

    if result ~= 0 then
        mp.msg.error(
            "Hyprland failed to change monitor mode"
        )
    end
end


------------------------------------------------------------
-- Set refresh rate based on video FPS
------------------------------------------------------------

local function set_refresh_rate()
    local fps = mp.get_property_native("container-fps")

    if not fps or fps <= 0 then
        mp.msg.warn("No valid video FPS detected")
        return
    end

    local mon = get_active_monitor()

    if not mon then
        return
    end

    -- Save the ORIGINAL mode before doing anything.
    save_original_mode(mon)

    --------------------------------------------------------
    -- Get modes available at the monitor's CURRENT
    -- resolution.
    --------------------------------------------------------

    local rates = get_available_refresh_rates(mon)

    if #rates == 0 then
        mp.msg.warn(
            "No available refresh rates found for " ..
            mon.width .. "x" .. mon.height
        )

        return
    end

    local hz = find_best_refresh(
       fps,
        rates,
        original_mode.refresh
    )


    if not hz then
        mp.msg.warn("Could not find suitable refresh rate")
        return
    end

    local resolution = string.format(
        "%dx%d",
        mon.width,
        mon.height
    )

    --------------------------------------------------------
    -- Logging
    --------------------------------------------------------

    local rate_strings = {}

    for _, rate in ipairs(rates) do
        table.insert(
            rate_strings,
            string.format("%.2f", rate)
        )
    end

    local multiple = hz / fps

    mp.msg.info(string.format(
        "Video FPS: %.3f",
        fps
    ))

    mp.msg.info(string.format(
        "Current resolution: %s",
        resolution
    ))

    mp.msg.info(
        "Available refresh rates: " ..
        table.concat(rate_strings, ", ")
    )

    mp.msg.info(string.format(
        "Selected %.3f Hz (%.4fx video FPS)",
        hz,
        multiple
    ))



    --------------------------------------------------------
    -- Already using the correct refresh rate.
    --------------------------------------------------------

    if math.abs(mon.refreshRate - hz) < 0.05 then

        mp.msg.info(
            "Monitor is already at the optimal refresh rate"
        )

        return
    end


    --------------------------------------------------------
    -- Change only the refresh rate.
    --
    -- Resolution stays the same.
    -- Position stays the same.
    -- Scale stays the same.
    -- Transform stays the same.
    --------------------------------------------------------

    set_hyprland_monitor({

        output = mon.name,

        mode = string.format(
            "%s@%.3f",
            resolution,
            hz
        ),

        position = string.format(
            "%dx%d",
            mon.x,
            mon.y
        ),

        scale = mon.scale,

        transform = mon.transform,
    })
end


------------------------------------------------------------
-- Restore original monitor mode
------------------------------------------------------------

local function reset_refresh_rate()
    if not changed_monitor or not original_mode then
        return
    end

    mp.msg.info(string.format(
        "Restoring %s to %dx%d@%.3fHz",
        changed_monitor,
        original_mode.width,
        original_mode.height,
        original_mode.refresh
    ))

    set_hyprland_monitor({

        output = changed_monitor,

        mode = string.format(
            "%dx%d@%.3f",
            original_mode.width,
            original_mode.height,
            original_mode.refresh
        ),

        position = string.format(
            "%dx%d",
            original_mode.x,
            original_mode.y
        ),

        scale = original_mode.scale,

        transform = original_mode.transform,
    })

    changed_monitor = nil
    original_mode = nil
end


------------------------------------------------------------
-- mpv events
------------------------------------------------------------

mp.register_event(
    "file-loaded",
    set_refresh_rate
)

mp.register_event(
    "end-file",
    reset_refresh_rate
)


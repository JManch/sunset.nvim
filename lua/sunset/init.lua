local M = {}

local util = require("sunset.util")
local notify = util.notify

local is_day = nil -- the actual day/night state
local is_day_forced = nil -- user's manually set day/night state
local next_sunrise = nil
local next_sunset = nil
local timer = nil
local opts = {}

local default_opts = {
    latitude = 51.5072, -- north is positive, south is negative
    longitude = -0.1276, -- east is positive, west is negative
    sunrise_offset = 0, -- offset the sunrise by this many seconds
    sunset_offset = 0, -- offset the sunset by this many seconds
    sunrise_override = nil, -- accepts a time in the form "HH:MM" which will override the sunrise time
    sunset_override = nil, -- accepts a time in the form "HH:MM" which will override the sunrise time
    day_callback = nil, -- function that is called when day begins
    night_callback = nil, -- function that is called when night begins
    update_interval = 60000, -- how frequently to check for sunrise/sunset changes in milliseconds
    time_format = "%H:%M", -- sun time formatting using os.date https://www.lua.org/pil/22.1.html
}

local trigger_night = function()
    is_day_forced = false
    if opts.night_callback then
        opts.night_callback()
    else
        util.set_background("dark")
    end
end

local trigger_day = function()
    is_day_forced = true
    if opts.day_callback then
        opts.day_callback()
    else
        util.set_background("light")
    end
end

--- Updates the next_sunrise and next_sunset values
local update_sun_times = function()
    -- if both are overriden no need to calculate next sun times
    if opts.sunrise_override and opts.sunset_override then
        next_sunrise = util.str_to_next_time(opts.sunrise_override)
        next_sunset = util.str_to_next_time(opts.sunset_override)
        return
    end

    local sun_times = util.next_sun_times(opts.latitude, opts.longitude, opts.sunrise_offset, opts.sunset_offset)
    next_sunrise = util.str_to_next_time(opts.sunrise_override) or sun_times.sunrise
    next_sunset = util.str_to_next_time(opts.sunset_override) or sun_times.sunset

    vim.g.sunrise = os.date(opts.time_format, next_sunrise)
    vim.g.sunset = os.date(opts.time_format, next_sunset)
end

--- Checks if sunrise/sunset is outdated and triggers day/night transition if
--- the sun's state has changed.
local update = function()
    if next_sunrise == nil or next_sunset == nil then
        notify.error("Plugin stopping due to sunrise/sunset error.")
        if timer ~= nil then
            timer:stop()
        end
        return
    end

    local time = os.time()
    -- update sunrise/sunset time if either is outdated
    if time > next_sunrise or time > next_sunset then
        update_sun_times()
    end

    -- use the next sunset and sunrise times to determine if the sun is up
    if is_day and next_sunrise < next_sunset then
        vim.g.is_day = false
        is_day = false
        trigger_night()
    elseif not is_day and next_sunset < next_sunrise then
        vim.g.is_day = true
        is_day = true
        trigger_day()
    end
end

--- Validates and loads options. Resorts to default values if there's an error
--- with the user's options.
---@param new_opts table
local load_opts = function(new_opts)
    if not new_opts then
        new_opts = {}
    end

    if new_opts.latitude and (new_opts.latitude < -90 or new_opts.latitude > 90) then
        notify.warn("Invalid latitude value. Must be between -90 and 90 inclusive.")
        new_opts.latitude = default_opts.latitude
    end

    if new_opts.longitude and (new_opts.longitude < -180 or new_opts.longitude > 180) then
        notify.warn("Invalid longitude value. Must be between -180 and 180 inclusive.")
        new_opts.longitude = default_opts.longitude
    end

    if new_opts.update_interval and (new_opts.update_interval <= 0) then
        notify.warn("Invalid update interval milliseconds. Must be greater than 0.")
        new_opts.update_interval = default_opts.update_interval
    end

    if new_opts.sunrise_offset then
        new_opts.sunrise_offset = new_opts.sunrise_offset % (86400 * util.sign(new_opts.sunrise_offset))
    end

    if new_opts.sunset_offset then
        new_opts.sunset_offset = new_opts.sunset_offset % (86400 * util.sign(new_opts.sunset_offset))
    end

    opts = vim.tbl_extend("force", default_opts, new_opts)
end

--- Prints the next sunrise and sunset times
local print_sun_times = function()
    if next_sunrise == nil or next_sunset == nil then
        notify.error("Cannot print sun times due to error.")
    end

    local sunrise_message = ""
    if opts.sunrise_override then
        sunrise_message = " overriden to"
    elseif opts.sunrise_offset ~= 0 then
        sunrise_message = " offset to"
    end

    local sunset_message = ""
    if opts.sunset_override then
        sunset_message = " overriden to"
    elseif opts.sunset_offset ~= 0 then
        sunset_message = " offset to"
    end

    local message = "Next sunrise is%s: %s\nNext sunset is%s: %s"
    message = message:format(sunrise_message, os.date("%c", next_sunrise), sunset_message, os.date("%c", next_sunset))
    notify.info(message)
end

local commands = {
    SunsetToggle = function()
        if is_day_forced then
            trigger_night()
        else
            trigger_day()
        end
    end,
    SunsetTimes = print_sun_times,
}

--- Loads the plugin
---@param new_opts table
M.setup = function(new_opts)
    if vim.g.loaded_sunrise == 1 then
        -- update the background as neovim resets it if config is sourced
        if is_day_forced then
            if opts.day_callback then
                opts.day_callback()
            else
                util.set_background("light")
            end
        else
            if opts.night_callback then
                opts.night_callback()
            else
                util.set_background("dark")
            end
        end
        return
    end

    load_opts(new_opts)
    update_sun_times()
    if next_sunrise == nil or next_sunset == nil then
        return
    end

    vim.g.loaded_sunrise = 1

    -- create commands
    for command, func in pairs(commands) do
        vim.api.nvim_create_user_command(command, func, {})
    end

    -- set initial is_day value as opposite to trigger the first day/night switch
    is_day = not (next_sunset < next_sunrise)
    is_day_forced = is_day

    -- start the update_theme timer
    timer = vim.loop.new_timer()
    timer:start(0, opts.update_interval, vim.schedule_wrap(update))
end

return M

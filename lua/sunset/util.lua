local M = {}

local api = vim.api

--- Trig functions in degrees
local sin = function(x)
    return math.sin(math.rad(x))
end
local cos = function(x)
    return math.cos(math.rad(x))
end
local asin = function(x)
    return math.deg(math.asin(x))
end
local acos = function(x)
    return math.deg(math.acos(x))
end

M.sign = function(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

local round_to_zero = function(x)
    if x >= 0 then
        return math.floor(x)
    else
        return math.ceil(x)
    end
end

M.set_background = function(background)
    if api.nvim_get_option("background") ~= background then
        api.nvim_set_option("background", background)
    end
end

--- Notify with plugin title
---@param message string
---@param level number
local notify_func = function(message, level)
    local exists, notify = pcall(require, "notify")
    if exists then
        notify(message, level, { title = "Sunset.nvim", timeout = 20000 })
    else
        message = "Sunset.nvim\n" .. message
        vim.notify(message, level)
    end
end

M.notify = {
    debug = function(message)
        notify_func(message, vim.log.levels.DEBUG)
    end,
    error = function(message)
        notify_func(message, vim.log.levels.ERROR)
    end,
    info = function(message)
        notify_func(message, vim.log.levels.INFO)
    end,
    warn = function(message)
        notify_func(message, vim.log.levels.WARN)
    end,
}

--- Converts a string representing a 24 hour time in the form HH:MM to the next
--- occurence of this time as a system datetime value. Returns nil if the
--- provided string is not a valid time.
---@param time_str string
---@return number|nil
M.str_to_next_time = function(time_str)
    if not time_str or time_str == "" then
        return nil
    end

    -- parse string
    local hour, min = string.match(time_str, "(%d?%d):(%d%d)")
    if not hour or not min then
        M.notify.error("Invalid time format provided. Supported format is HH:MM.")
        return nil
    elseif tonumber(hour) > 23 or tonumber(min) > 59 then
        M.notify.error("Invalid time provided. Must be a 24-hour time.")
        return nil
    end

    local date = os.date("*t")
    local current_time = os.time(date)
    date.hour = tonumber(hour)
    date.min = tonumber(min)
    date.sec = 0

    local next_time = os.time(date)
    if next_time < current_time then
        date.day = date.day + 1
        next_time = os.time(date)
    end
    return next_time
end

--- Converts an osdate to a Julian date
---
--- Implements algorithm from wikipedia:
--- https://en.wikipedia.org/wiki/Julian_day#Julian_day_number_calculation
---
---@param date osdate
---@return number
local date_to_julian = function(date)
    return round_to_zero((1461 * (date.year + 4800 + round_to_zero((date.month - 14) / 12))) / 4)
        + round_to_zero((367 * (date.month - 2 - 12 * round_to_zero((date.month - 14) / 12))) / 12)
        - round_to_zero((3 * round_to_zero((date.year + 4900 + round_to_zero((date.month - 14) / 12)) / 100)) / 4)
        + (date.day - 32075)
        + ((date.hour - 12) / 24)
        + (date.min / 1440)
        + (date.sec / 86400)
end

--- Converts a Julian date to an osdate
---
--- Implements algorithm from wikipedia:
--- https://en.wikipedia.org/wiki/Julian_day#Julian_day_number_calculation
---
---@param julian_date number
---@return osdate
local julian_to_greg = function(julian_date)
    local date = {}
    -- date component
    local julian_day = math.floor(julian_date)
    local f = julian_day + 1401 + math.floor((math.floor(((4 * julian_day) + 274277) / 146097) * 3) / 4) - 38
    local e = (4 * f) + 3
    local g = math.floor((e % 1461) / 4)
    local h = (5 * g) + 2
    date.day = math.floor((h % 153) / 5) + 1
    date.month = ((math.floor(h / 152) + 2) % 12) + 1
    date.year = math.floor(e / 1461) - 4716 + math.floor((14 - date.month) / 12)

    -- time component
    local julian_time = julian_date - julian_day
    f = 86400 * julian_time
    e = f % 3600
    g = math.floor(f / 3600) + 12
    date.day = date.day + math.floor(g / 24)
    date.hour = g % 24
    date.min = math.floor(e / 60)
    date.sec = math.floor(e % 60)
    date.isdst = false
    return date
end

--- Returns a table containing the sunet and runrise time for the given
--- latitude, longitude and date. The returned times will be for day n if the
--- osdate provided is between 12 noon on day n-1 and 12 noon on day n.
---
--- Implements algorithm from wikipedia:
--- https://en.wikipedia.org/wiki/Sunrise_equation#Complete_calculation_on_Earth
---
---@param latitude number
---@param longitude number
---@param date osdate
---@return table
local calc_sun_times = function(latitude, longitude, date)
    local j = date_to_julian(date)
    local mst = math.ceil(j - 2451545.0008) - (longitude / 360)
    local msa = (357.5291 + (0.98560028 * mst)) % 360
    local c = (1.9148 * sin(msa)) + (0.02 * sin(2 * msa)) + (0.0003 * sin(3 * msa))
    local e = (msa + c + 282.9372) % 360
    local st = 2451545 + mst + (0.0053 * sin(msa)) - (0.0069 * sin(2 * e))
    local sd = asin(sin(e) * sin(23.44))
    local h_cos = (sin(-0.83) - (sin(latitude) * sin(sd))) / (cos(latitude) * cos(sd))

    -- sun never rises or sets
    if h_cos > 1 or h_cos < -1 then
        return { sunrise = -1, sunset = -1 }
    end

    local h = acos((sin(-0.83) - (sin(latitude) * sin(sd))) / (cos(latitude) * cos(sd))) / 360

    return {
        sunrise = os.time(julian_to_greg(st - h)),
        sunset = os.time(julian_to_greg(st + h)),
    }
end

--- Returns a table containing the next sunrise and sunset times. Offsets are
--- in seconds and can be positive or negative.
---@param latitude number
---@param longitude number
---@param sunrise_offset number
---@param sunset_offset number
---@return table
M.next_sun_times = function(latitude, longitude, sunrise_offset, sunset_offset)
    local date = os.date("!*t")
    local time = os.time(date)
    date.hour = 0

    -- first get sunset and sunrise for the current date
    local sun_times = calc_sun_times(latitude, longitude, date)
    local sunrise = sun_times.sunrise + sunrise_offset
    local sunset = sun_times.sunset + sunset_offset

    local i = 0
    while sunrise < time or sunset < time do
        i = i + 1
        if i > 365 then
            M.notify.error("Unsupported latitude, longitude coordinates.")
            return { sunrise = nil, sunset = nil }
        end
        date.day = date.day + 1
        sun_times = calc_sun_times(latitude, longitude, date)
        if sunrise < time then
            sunrise = sun_times.sunrise + sunrise_offset
        end

        if sunset < time then
            sunset = sun_times.sunset + sunset_offset
        end
    end
    return { sunrise = sunrise, sunset = sunset }
end

return M

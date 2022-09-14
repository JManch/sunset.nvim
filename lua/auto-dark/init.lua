local M = {}

local utils = require("auto-dark.utils")
local api = vim.api

local default_opts = {
	sunrise_offset = 0,
	sunset_offset = 0,
	sunrise_override = nil,
	sunset_override = nil,
	day_callback = nil,
	night_callback = nil,
	update_interval = 60000,
	latitude = 51.5072,
	longitude = -0.1276,
}

local opts = {}
local next_sunrise = nil
local next_sunset = nil
local is_day = nil
local fake_is_day = nil

local function update_sun_times()
	-- if both are overriden no need to compute sun times
	if opts.sunrise_override and opts.sunset_override then
		next_sunrise = utils.str_to_next_time(opts.sunrise_override)
		next_sunset = utils.str_to_next_time(opts.sunset_override)
		return
	end

	local sun_times = utils.next_sun_times(opts.latitude, opts.longitude, opts.sunrise_offset, opts.sunset_offset)
	next_sunrise = utils.str_to_next_time(opts.sunrise_override) or sun_times.sunrise
	next_sunset = utils.str_to_next_time(opts.sunset_override) or sun_times.sunset
	-- print("Next sunrise is", os.date("!*t", next_sunrise), "Next sunset is", os.date("!*t", next_sunset))
	-- set initial is_day value as opposite to trigger the first day/night switch
	is_day = is_day or not (next_sunset < next_sunrise)
	fake_is_day = fake_is_day or is_day
end

local function trigger_night()
	fake_is_day = false
	if opts.night_callback then
		opts.night_callback()
	else
		utils.set_background("dark")
	end
end

local function trigger_day()
	fake_is_day = true
	if opts.day_callback then
		opts.day_callback()
	else
		utils.set_background("light")
	end
end

local function toggle_theme()
	if fake_is_day then
		trigger_night()
	else
		trigger_day()
	end
end

local function update_theme()
	-- local start = vim.loop.hrtime()
	local time = os.time()

	-- update next sunrise/sunset times if necessary
	if time > next_sunrise or time > next_sunset then
		update_sun_times()
	end

	-- use the next sunset and sunrise times to determine if the sun is up
	if is_day and next_sunrise < next_sunset then
		is_day = false
		trigger_night()
	elseif not is_day and next_sunset < next_sunrise then
		is_day = true
		trigger_day()
	end

	-- local stop = vim.loop.hrtime()
	-- print("Theme update ran at " .. os.date("%c", time) .. " took " .. (stop - start) / 1000000 .. " milliseconds")
end

-- Load and validate options
local function load_opts(new_opts)
	if not new_opts then
		new_opts = {}
	end

	if new_opts.latitude and (new_opts.latitude < -90 or new_opts.latitude > 90) then
		utils.error("Invalid latitude value. Must be between -90 and 90 inclusive.")
		new_opts.latitude = default_opts.latitude
	end

	if new_opts.longitude and (new_opts.longitude < -180 or new_opts.longitude > 180) then
		utils.error("Invalid longitude value. Must be between -180 and 180 inclusive.")
		new_opts.longitude = default_opts.longitude
	end

	if new_opts.update_interval and (new_opts.update_interval <= 0) then
		utils.error("Invalid update interval milliseconds. Must be greater than 0.")
		new_opts.update_interval = default_opts.update_interval
	end

	if new_opts.sunrise_offset then
		new_opts.sunrise_offset = new_opts.sunrise_offset % (86400 * utils.sign(new_opts.sunrise_offset))
	end

	if new_opts.sunset_offset then
		new_opts.sunset_offset = new_opts.sunset_offset % (86400 * utils.sign(new_opts.sunrise_offset))
	end

	opts = vim.tbl_extend("force", default_opts, new_opts)
end

M.print_sun_times = function()
	local message = ""
	if vim.next_sunrise == math.huge or vim.next_sunset == math.huge then
		message = "Sun times are invalid due to unsupported coordinates."
	else
		if opts.sunrise_override then
			message = string.format("Sunrise is overriden to %s.", os.date("%c", next_sunrise))
		else
			message = string.format("Sunrise is at %s.", os.date("%c", next_sunrise))
		end
		message = string.format("Next ")
	end

	vim.notify(message, vim.log.levels.INFO)
end

local commands = {
	SunsetTriggerNight = trigger_night,
	SunsetTriggerDay = trigger_day,
	SunsetToggle = toggle_theme,
}

M.setup = function(new_opts)
	load_opts(new_opts)
	update_sun_times()
	local timer = vim.loop.new_timer()
	timer:start(0, opts.update_interval, vim.schedule_wrap(update_theme))

	for command, func in pairs(commands) do
		api.nvim_create_user_command(command, func, {})
	end
end

return M

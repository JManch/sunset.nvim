local M = {}

local util = require("auto-dark.util")

local is_day = nil -- the actual day/night state
local is_day_forced = nil -- user's manually set day/night state
local next_sunrise = nil
local next_sunset = nil

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

local function trigger_night()
	is_day_forced = false
	if opts.night_callback then
		opts.night_callback()
	else
		util.set_background("dark")
	end
end

local function trigger_day()
	is_day_forced = true
	if opts.day_callback then
		opts.day_callback()
	else
		util.set_background("light")
	end
end

--- updates the next_sunrise and next_sunset variables
local update_sun_times = function()
	-- if both are overriden no need to compute sun times
	if opts.sunrise_override and opts.sunset_override then
		next_sunrise = util.str_to_next_time(opts.sunrise_override)
		next_sunset = util.str_to_next_time(opts.sunset_override)
		return
	end

	local sun_times = util.next_sun_times(opts.latitude, opts.longitude, opts.sunrise_offset, opts.sunset_offset)
	next_sunrise = util.str_to_next_time(opts.sunrise_override) or sun_times.sunrise
	next_sunset = util.str_to_next_time(opts.sunset_override) or sun_times.sunset
end

--- checks if sunrise/sunset is outdated and if the sun's state has changed
local update_theme = function()
	local time = os.time()

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
end

-- validate and load options
local load_opts = function(new_opts)
	if not new_opts then
		new_opts = {}
	end

	if new_opts.latitude and (new_opts.latitude < -90 or new_opts.latitude > 90) then
		util.error("Invalid latitude value. Must be between -90 and 90 inclusive.")
		new_opts.latitude = default_opts.latitude
	end

	if new_opts.longitude and (new_opts.longitude < -180 or new_opts.longitude > 180) then
		util.error("Invalid longitude value. Must be between -180 and 180 inclusive.")
		new_opts.longitude = default_opts.longitude
	end

	if new_opts.update_interval and (new_opts.update_interval <= 0) then
		util.error("Invalid update interval milliseconds. Must be greater than 0.")
		new_opts.update_interval = default_opts.update_interval
	end

	if new_opts.sunrise_offset then
		new_opts.sunrise_offset = new_opts.sunrise_offset % (86400 * util.sign(new_opts.sunrise_offset))
	end

	if new_opts.sunset_offset then
		new_opts.sunset_offset = new_opts.sunset_offset % (86400 * util.sign(new_opts.sunrise_offset))
	end

	opts = vim.tbl_extend("force", default_opts, new_opts)
end

local print_sun_times = function()
	local message = ""
	if vim.next_sunrise == math.huge or vim.next_sunset == math.huge then
		message = "Sun times are invalid due to unsupported coordinates."
	else
		if opts.sunrise_override then
			message = string.format("Next sunrise is overriden to %s.", os.date("%c", next_sunrise))
		else
			message = string.format("Next sunrise is at %s.", os.date("%c", next_sunrise))
		end

		if opts.sunset_override then
			message = string.format("%s Next sunset is overriden to %s.", message, os.date("%c", next_sunset))
		else
			message = string.format("%s Next sunset is at %s.", message, os.date("%c", next_sunset))
		end
	end

	vim.notify(message, vim.log.levels.INFO)
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

M.setup = function(new_opts)
	if vim.g.loaded_sunrise == 1 then
		return
	end
	vim.g.loaded_sunrise = 1

	load_opts(new_opts)
	update_sun_times()

	-- set initial is_day value as opposite to trigger the first day/night switch
	is_day = not (next_sunset < next_sunrise)
	is_day_forced = is_day

	-- start the update_theme timer
	local timer = vim.loop.new_timer()
	timer:start(0, opts.update_interval, vim.schedule_wrap(update_theme))

	for command, func in pairs(commands) do
		vim.api.nvim_create_user_command(command, func, {})
	end
end

return M

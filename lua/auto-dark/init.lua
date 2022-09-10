local M = {}

local sun = require("auto-dark.sun")
local api = vim.api

local default_opts = {
	use_sunset_sunrise = true,
	latitude = 51.5072,
	longitude = 0.1276,
	dark_on = "07:00",
	dark_off = "21:00",
}

local opts = {}

local function update_theme()
	local time = sun.date_to_seconds(os.date("!*t"))
	-- local time = sun.date_to_seconds({ hour = 8, min = 0, sec = 0 })
	local current_theme = api.nvim_get_option("background")
	if opts.use_sunset_sunrise then
		if current_theme == "light" and (time > sun.sunset or time < sun.sunrise) then
			api.nvim_set_option("background", "dark")
		elseif current_theme == "dark" and (time > sun.sunrise and time < sun.sunset) then
			api.nvim_set_option("background", "light")
		end
	end
end

M.setup = function(options)
	if not options then
		options = {}
	end
	opts = vim.tbl_extend("force", default_opts, options)
	sun.update_sunrise_sunset(opts.latitude, opts.longitude)
	update_theme()
end

return M

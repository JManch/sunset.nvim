local M = {}

local api = vim.api
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

local function round_to_zero(num)
	if num >= 0 then
		return math.floor(num)
	else
		return math.ceil(num)
	end
end

local greg_to_julian = function(date)
	return round_to_zero((1461 * (date.year + 4800 + round_to_zero((date.month - 14) / 12))) / 4)
		+ round_to_zero((367 * (date.month - 2 - 12 * round_to_zero((date.month - 14) / 12))) / 12)
		- round_to_zero((3 * round_to_zero((date.year + 4900 + round_to_zero((date.month - 14) / 12)) / 100)) / 4)
		+ (date.day - 32075)
		+ ((date.hour - 12) / 24)
		+ (date.min / 1440)
		+ (date.sec / 86400)
end

local julian_to_greg = function(julian_date)
	local date = {}
	local julian_day = math.floor(julian_date)
	local f = julian_day + 1401 + math.floor((math.floor(((4 * julian_day) + 274277) / 146097) * 3) / 4) - 38
	local e = (4 * f) + 3
	local g = math.floor((e % 1461) / 4)
	local h = (5 * g) + 2
	date.day = math.floor((h % 153) / 5) + 1
	date.month = ((math.floor(h / 152) + 2) % 12) + 1
	date.year = math.floor(e / 1461) - 4716 + math.floor((14 - date.month) / 12)

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
	-- return { hour = hour, min = min, sec = sec, isdst = false }
end

-- Returns the sunset/sunrise times for day n if the datetime object is between 12 noon on day n-1 and 12 noon on day n
local calc_sun_times = function(latitude, longitude, date)
	local time = os.time(date)
	date = os.date("!*t", time)
	local j = greg_to_julian(date)
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
			vim.notify("Unsupported latitude and longitude.", vim.log.levels.WARN)
			return { sunrise = math.huge, sunset = math.huge }
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

-- M.error = function(string)
-- 	vim.notify(string, vim.log.levels.ERROR)
-- end

M.str_to_next_time = function(time_str)
	if not time_str or time_str == "" then
		return nil
	end
	-- convert time string into date object
	local date = os.date("!*t")
	local current_time = os.time(date)
	local hour, min = string.match(time_str, "(%d?%d):(%d%d)")
	if not hour or not min then
		error("Invalid time format provided. Supported format is HH:MM.")
		return nil
	elseif tonumber(hour) > 24 or tonumber(min) > 59 then
		error("Invalid time provided. Must be a 24-hour time.")
		return nil
	end
	date.hour = tonumber(hour)
	date.min = tonumber(min)
	date.sec = 0
	local time = os.time(date)
	if time < current_time then
		date.day = date.day + 1
		time = os.time(date)
	end
	return time
end

M.set_background = function(background)
	if api.nvim_get_option("background") ~= background then
		api.nvim_set_option("background", background)
	end
end

-- local function test()
-- 	local date = os.date("!*t")
-- 	date.hour = 0
-- 	for i = 1, 1000000, 1 do
-- 		if i % 10000 == 0 then
-- 			print("Test " .. i)
-- 		end
-- 		-- generate random lat and long
-- 		local lat = math.random() + math.random(-90, 89)
-- 		local long = math.random() + math.random(-180, 179)
--
-- 		M.next_sun_times(lat, long, 0, 0)
-- 	end
-- end

-- test()

-- for i, coord in pairs(lats) do
-- 	print(i)
-- 	local next_sun_times = M.next_sun_times(coord[1], coord[2], 0, 0)
-- 	print(
-- 		"Next sunrise is at",
-- 		os.date("!%c", next_sun_times.sunrise),
-- 		"sunset is at",
-- 		os.date("!%c", next_sun_times.sunset)
-- 	)
-- end

-- local next_sun_times = M.next_sun_times(90, -135, 0, 0)
-- print(
-- 	"Next sunrise is at",
-- 	os.date("!%c", next_sun_times.sunrise),
-- 	"sunset is at",
-- 	os.date("!%c", next_sun_times.sunset)
-- )
return M

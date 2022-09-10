local M = {}

local sin, cos, asin, acos = math.sin, math.cos, math.asin, math.acos
local deg, rad = math.deg, math.rad
math.sin = function(x)
	return sin(rad(x))
end
math.cos = function(x)
	return cos(rad(x))
end
math.asin = function(x)
	return deg(asin(x))
end
math.acos = function(x)
	return deg(acos(x))
end

local function round_to_zero(num)
	if num >= 0 then
		return math.floor(num)
	else
		return math.ceil(num)
	end
end

local greg_to_julian = function(date)
	local year = date.year
	local month = date.month
	local day = date.day
	local hour = date.hour
	local min = date.min
	local sec = date.sec

	return round_to_zero((1461 * (year + 4800 + round_to_zero((month - 14) / 12))) / 4)
		+ round_to_zero((367 * (month - 2 - 12 * round_to_zero((month - 14) / 12))) / 12)
		- round_to_zero((3 * round_to_zero((year + 4900 + round_to_zero((month - 14) / 12)) / 100)) / 4)
		+ (day - 32075)
		+ ((hour - 12) / 24)
		+ (min / 1440)
		+ (sec / 86400)
end

local julian_to_greg = function(julian_date)
	local julian_day = math.floor(julian_date)
	local f = julian_day + 1401 + math.floor((math.floor(((4 * julian_day) + 274277) / 146097) * 3) / 4) - 38
	local e = (4 * f) + 3
	local g = math.floor((e % 1461) / 4)
	local h = (5 * g) + 2
	local day = math.floor((h % 153) / 5) + 1
	local month = ((math.floor(h / 152) + 2) % 12) + 1
	local year = math.floor(e / 1461) - 4716 + math.floor((14 - month) / 12)

	local julian_time = julian_date - julian_day
	f = 86400 * julian_time
	e = f % 3600
	g = math.floor(f / 3600) + 12
	day = day + math.floor(g / 24)
	local hour = g % 24
	local min = math.floor(e / 60)
	local sec = math.floor(e % 60)
	-- return os.time({ day = day, month = month, year = year, hour = hour, min = min, sec = sec, isdst = false })
	return { hour = hour, min = min, sec = sec, isdst = false }
end

M.date_to_seconds = function(date)
	return date.hour * 3600 + date.min * 60 + date.sec
end

M.update_sunrise_sunset = function(latitude, longitude)
	local ust_date = os.date("!*t")
	-- local julian_date = greg_to_julian({ day = 9, month = 12, year = 2022, hour = 12, min = 0, sec = 0 })
	local julian_date = greg_to_julian(ust_date)

	local mean_solar_time = math.ceil(julian_date - 2451545 + 0.0008) - (longitude / 360)
	local mean_solar_anomaly = (357.5291 + (0.98560028 * mean_solar_time)) % 360
	local center = (1.9148 * math.sin(mean_solar_anomaly))
		+ (0.02 * math.sin(2 * mean_solar_anomaly))
		+ (0.0003 * math.sin(3 * mean_solar_anomaly))
	local ecliptic_longitude = (mean_solar_anomaly + center + 282.9372) % 360
	local solar_transit = 2451545
		+ mean_solar_time
		+ (0.0053 * math.sin(mean_solar_anomaly))
		- (0.0069 * math.sin(2 * ecliptic_longitude))

	local sun_dec_asin = math.sin(ecliptic_longitude) * math.sin(23.44)
	if sun_dec_asin < -1 or sun_dec_asin > 1 then
		return nil
	end
	local sun_dec = math.asin(sun_dec_asin)

	local hour_angle_acos = (math.sin(-0.83) - (math.sin(latitude) * math.sin(sun_dec)))
		/ (math.cos(latitude) * math.cos(sun_dec))
	if hour_angle_acos < -1 or hour_angle_acos > 1 then
		return nil
	end
	local hour_angle = math.acos(
		(math.sin(-0.83) - (math.sin(latitude) * math.sin(sun_dec))) / (math.cos(latitude) * math.cos(sun_dec))
	) / 360

	M.sunrise = M.date_to_seconds(julian_to_greg(solar_transit - hour_angle))
	M.sunset = M.date_to_seconds(julian_to_greg(solar_transit + hour_angle))

	-- return {
	-- 	sunrise = julian_to_greg(solar_transit - hour_angle),
	-- 	sunset = julian_to_greg(solar_transit + hour_angle),
	-- }
end

-- M.update_sunrise_sunset(51.5072, -0.1276)
-- print(os.date("%c", M.sunrise), os.date("%c", M.sunset))

return M

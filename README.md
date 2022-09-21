# Sunset.nvim :sunrise:

An automatic theme switcher for Neovim that uses precise sunrise/sunset times based on your latitude and longitude.

Sun times are calculated locally so the plugin does not require an internet connection to function. The plugin uses a libuv timer to ensure that the theme is updated whilst Neovim is open without the need for a restart.

## Installation

Install using your prefered method and call the setup function to load the plugin.
The function accepts a table for overriding the default configuration:

```lua
require("sunset").setup({
    latitude = 51.5072, -- north is positive, south is negative
    longitude = -0.1276, -- east is positive, west is negative
    sunrise_offset = 0, -- offset the sunrise by this many seconds
    sunset_offset = 0, -- offset the sunset by this many seconds
    sunrise_override = nil, -- accepts a time in the form "HH:MM" which will override the sunrise time
    sunset_override = nil, -- accepts a time in the form "HH:MM" which will override the sunset time
    day_callback = nil, -- function that is called when day begins
    night_callback = nil, -- function that is called when night begins
    update_interval = 60000, -- how frequently to check for sunrise/sunset changes in milliseconds
})
```

I recommend ensuring that Sunset.nvim loads after any colorscheme plugins to reduce the likelihood of issues.

## Usage

By default, the plugin changes the [background](https://neovim.io/doc/user/options.html#'background') option between light and dark. If you would like the change this behaviour (instead change the colorscheme for example), you can set the `day_callback` or `night_callback` which will disable the background switching. For example:

```lua
day_callback = function()
    vim.cmd("colorscheme foo")
end
```

The plugin has the following commands:
- `SunsetTimes` - view the next sunrise/sunset times
- `SunsetToggle` - switch between day and night theme
- `SunsetDay` - switch to day theme
- `SunsetNight` - switch to night theme

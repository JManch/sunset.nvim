# Sunset.nvim :sunrise:

An automatic theme switcher for Neovim that uses precise sunrise/sunset times
based on your latitude and longitude.

Sun times are calculated locally so the plugin does not require an internet
connection to function. The plugin uses a libuv timer to ensure that the theme
is updated whilst Neovim is open without the need for a restart.

## Installation

Install using your preferred method and call the setup function to load the plugin.
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
    time_format = "%H:%M", -- sun time formatting using os.date https://www.lua.org/pil/22.1.html
})
```

I recommend ensuring that Sunset.nvim loads after any colorscheme plugins to
reduce the likelihood of issues. 

Here's how I load my colorscheme plugin and sunset.nvim with [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "JManch/sunset.nvim",
    dependencies = {
        {
            "colorscheme plugin",
            config = function
                -- Colorscheme plugin config
            end,
        },
    },
    lazy = false,
    priority = 1000,
    opts = {
        latitude = 51.5072,
        longitude = -0.1276,
    },
}
```

## Usage

By default, the plugin changes the
[background](https://neovim.io/doc/user/options.html#'background') option
between light and dark. If you would like the change this behaviour, you can
set the `day_callback` or `night_callback` which will disable the background
switching. For example:

```lua
day_callback = function()
    vim.cmd("colorscheme foo")
end
```

If you would like to show the sun status in your statusline, sunset.nvim
sets the following global variables:

```lua
vim.g.is_day -- boolean
vim.g.sunrise -- next sunrise time string formatted using time_format option
vim.g.sunset -- next sunset time string formatted using time_format option
```
The plugin has the following commands:
- `SunsetTimes` - view the next sunrise/sunset times
- `SunsetToggle` - toggle between day and night theme

## Note on highlight groups

If you find that sunset.nvim is clearing your custom highlight groups every
time you switch themes, you need to set highlight groups in a ColorScheme
autocommand. More info
[here](https://gist.github.com/romainl/379904f91fa40533175dfaec4c833f2f).

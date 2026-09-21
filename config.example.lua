--- Installation template: copy outside the repository before adding personal values.
-- @script config.example

-- Copy to ~/.config/hammerspoon/personal.lua. Never put credentials here.
return {
  -- UI preferences are independent of the language used by AI actions.
  language = 'es', -- 'es' or 'en'; reload Hammerspoon after changing.
  notifications = {
    backend = 'notify', -- 'notify', 'alert', or 'both'.
    finalBackend = 'both', -- Final task outcomes; omit to inherit backend.
    title = 'VSDeck',
    -- duration = 4, -- Alert seconds; native banners are controlled by macOS.
    -- style = { textSize = 18 }, -- hs.alert style table.
    levels = {
      info = { enabled = true },
      success = { enabled = true },
      warning = { enabled = true },
      error = { enabled = true },
    },
  },
  -- Optional integrations: fill only the services used on this installation.
  ai = { lmStudioUrl = 'http://localhost:1234/v1/chat/completions', model = 'your-loaded-model' },
  awsBinary = '/opt/homebrew/bin/aws', -- Intel/Homebrew may use /usr/local/bin/aws.
}

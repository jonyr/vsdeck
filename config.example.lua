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
  webShortcuts = {},
  webviewDeck = { menuBarGap = 6 }, -- Points below the menu bar; 0 places it flush.
  canvasDeck = { maxColumns = 5 }, -- Maximum two rows per page.
  soundboard = {
    enabled = true,
    volume = 0.5, -- Relative to system volume, from 0 to 1.
    -- directory = '~/Music/Soundboard', -- Default: hs.configdir .. '/sounds'.
    -- sounds = { -- Optional explicit list replaces directory discovery.
    --   { id = 'applause', title = 'Aplausos', path = '~/Music/applause.mp3', volume = 0.4 },
    -- },
  },
  awsBinary = '/opt/homebrew/bin/aws', -- Intel/Homebrew may use /usr/local/bin/aws.
  snapshots = {
    -- { id = 'rds.work', title = 'Snapshot trabajo', profile = 'work',
    --   region = 'us-east-1', instance = 'example-db' },
  },
  hue = {
    -- bridge = '192.168.1.100',
    controls = true, -- Add six presets and +/- brightness to each toggle light.
    transitionSeconds = 0.4, -- 0 to 10; presets may override this.
    -- presets = { -- Omit to use Work, Relax, Cinema, Gaming, Red and Green.
    --   { id='work', title='Trabajo', badge='🤍', kelvin=5000, brightness=100 },
    --   { id='relax', title='Relax', badge='🟠', kelvin=2700, brightness=40 },
    --   { id='cinema', title='Cine', badge='🎬', hue=240, saturation=100, brightness=15 },
    --   { id='gaming', title='Gaming', badge='🎮', hue=280, saturation=100, brightness=70 },
    --   { id='red', title='Rojo', badge='🔴', hue=0, saturation=100, brightness=40 },
    --   { id='green', title='Verde', badge='🟢', hue=120, saturation=100, brightness=40 },
    -- },
    lights = {
      -- { id='hue.desk', title='Escritorio', lightId='1', action='toggle' },
    },
  },
  scripts = {
    -- { id = 'script.example', title = 'Mi tarea', script = '/absolute/path/task.sh',
    --   args = { 'argument' }, confirm = true },
  },
}

-- Copy to ~/.config/hammerspoon/personal.lua. Never put credentials here.
return {
  ai = { lmStudioUrl = 'http://localhost:1234/v1/chat/completions', model = 'your-loaded-model' },
  webShortcuts = {},
  deckUi = 'html', -- 'react' loads modules/deck/panel.react.html (built from ui/).
  canvasDeck = { maxColumns = 5 }, -- Maximum two rows per page.
  awsBinary = '/opt/homebrew/bin/aws', -- Intel/Homebrew may use /usr/local/bin/aws.
  snapshots = {
    -- { id = 'rds.work', title = 'Snapshot trabajo', profile = 'work',
    --   region = 'us-east-1', instance = 'example-db' },
  },
  hue = {
    -- bridge = '192.168.1.100',
    lights = {
      -- { id='hue.desk', title='Escritorio', lightId='1', action='toggle' },
    },
  },
  scripts = {
    -- { id = 'script.example', title = 'Mi tarea', script = '/absolute/path/task.sh',
    --   args = { 'argument' }, confirm = true },
  },
}

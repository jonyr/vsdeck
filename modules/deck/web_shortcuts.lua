--- Expose installation-specific web shortcuts without embedding private URLs.
-- @module modules.deck.web_shortcuts

-- Personal URLs and profiles live outside this repository.
return require('modules.config.personal').data.webShortcuts or {}

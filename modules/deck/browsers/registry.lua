-- Browser metadata only. Add Chromium-based browsers without duplicating adapters.
return {
  safari = { label = 'Safari', adapter = 'modules.deck.browsers.safari',
    bundle = 'com.apple.Safari', profileField = 'profile' },
  chrome = { label = 'Google Chrome', adapter = 'modules.deck.browsers.chromium',
    bundle = 'com.google.Chrome', profileField = 'profileDirectory',
    executable = 'Google Chrome', data = 'Google/Chrome' },
  brave = { label = 'Brave', adapter = 'modules.deck.browsers.chromium',
    bundle = 'com.brave.Browser', profileField = 'profileDirectory',
    executable = 'Brave Browser', data = 'BraveSoftware/Brave-Browser' },
}

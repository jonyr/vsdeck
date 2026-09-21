// Multi-action children own settings but do not own the enclosing key's image.
export function handlePresenceEvent(controller, message, newId) {
  if (!['com.vsdeck.jonyr.discord-lunch','com.vsdeck.jonyr.discord-presence'].includes(message.action)) return false;
  const mode = message.action.endsWith('discord-presence') ? 'presence' : 'lunch';
  const payload = message.payload || {};
  if (message.event === 'willAppear' && !payload.isInMultiAction) controller.appear(message.context, payload.settings, mode);
  if (message.event === 'willDisappear') controller.disappear(message.context);
  if (message.event === 'didReceiveSettings' && !payload.isInMultiAction) controller.updateSettings(message.context, payload.settings);
  if (message.event === 'keyDown') {
    void controller.press(newId(), message.context, {mode, settings:payload.settings});
  }
  return true;
}

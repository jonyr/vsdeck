local M = {}
-- Progress is transient. Final outcomes stay in Notification Center and also
-- appear through Hammerspoon, independently of macOS notification banners.
function M.send(title, message, final)
  local notification = hs.notify.new({
    title = title,
    informativeText = message,
    withdrawAfter = final and 0 or 5,
  }):send()
  if final then hs.alert.show(title .. '\n' .. message, 10) end
  return notification
end
return M

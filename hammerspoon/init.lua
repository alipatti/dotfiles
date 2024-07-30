-----------------------
-- FLOATING TERMINAL --
-----------------------

local getKitty = function()
  local floatingKittyPid = hs.execute("pgrep -f FloatingKittyWindow")
  local kittyApp = hs.application(tonumber(floatingKittyPid))

  return kittyApp
end

hs.hotkey.bind("ctrl", "`", function()
  -- get the  kitty application object
  if kitty == nil then
    kitty = getKitty()
  end

  if kitty == nil then
    -- open background process
    io.popen("~/.hammerspoon/floating_kitty")

    -- wait for it to open
    -- while kitty == nil do
    --   kitty = getKitty()
    --   print("waiting for app")
    -- end
  end

  -- hide app if it's showing
  if not kitty:isHidden() then
    kitty:hide()
    print("Hiding floating terminal")
    return
  end

  -- create a window if one doesn't exist
  if not kitty:mainWindow() then
    hs.eventtap.keyStroke("cmd", "n", nil, kitty)

    print("Creating floating terminal")
  end

  print("Showing floating terminal")

  hs.spaces.moveWindowToSpace(kitty:mainWindow(), hs.spaces.focusedSpace())
  kitty:mainWindow():moveToUnit '[80,30,20,10]'
  kitty:mainWindow():moveToScreen(hs.screen.mainScreen())

  kitty:mainWindow():focus()
end)

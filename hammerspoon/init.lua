-----------------------
-- FLOATING TERMINAL --
-----------------------

-- get hammerspoon application object for the kitty background
-- process if it exists, nil otherwise
getKitty = function()
  local pid = hs.execute("pgrep -f 'kitty --instance-group floating'")
  print(pid)
  pid = tonumber(pid)
  print(pid)
  return hs.application(pid)
end

-- launch the kitty background process
startKitty = function()
  io.popen("/Applications/kitty.app/Contents/MacOS/kitty " ..
    "--instance-group floating " ..
    "--directory ~ " ..
    "-o hide_window_decorations=titlebar-only " ..
    "-o macos_window_resizable=no " ..
    "-o macos_hide_from_tasks=yes " ..
    "-o background_opacity=0.95 " ..
    "-o background_blur=5 " ..
    "-o tab_bar_style=hidden"
  )
end

local createWindow = function(app)
  hs.eventtap.keyStroke("cmd", "n", nil, app)
end

hs.hotkey.bind("ctrl", "`", function()
  -- get the kitty application object
  local kitty = getKitty()
  if not kitty then
    startKitty()

    -- wait until it activates
    -- while kitty == nil do
    --   kitty = getKitty()
    -- end
  end

  -- if is showing, hide it
  if kitty:isFrontmost() then
    kitty:hide()
    return
  end

  -- if it's not showing, activate it
  if not kitty:mainWindow() then createWindow(kitty) end
  local w = kitty:mainWindow()
  w:moveToUnit '[80,40,20,10]'
  getKitty():mainWindow():moveToScreen(hs.screen.mainScreen())
  hs.spaces.moveWindowToSpace(w, hs.spaces.focusedSpace())
  w:focus()
end)

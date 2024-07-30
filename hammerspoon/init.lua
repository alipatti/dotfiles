-----------------------
-- FLOATING TERMINAL --
-----------------------

local getFloatingKittyApplication = function()
  local floatingKittyPid = hs.execute("pgrep -f FloatingKittyWindow")
  local kittyApp = hs.application(tonumber(floatingKittyPid))

  return kittyApp
end

local kittyWindowExists = function()
  -- check if app exists
  local kitty = getFloatingKittyApplication()
  if kitty == nil then return false end

  -- check if window exists
  return kitty:mainWindow() ~= nil
end

local positionWindow = function(window)
  hs.spaces.moveWindowToSpace(window, hs.spaces.focusedSpace())
  window:moveToUnit '[80,30,20,10]'
  window:moveToScreen(hs.screen.mainScreen())

  window:focus()
end

function setupWatcher()
  if watcher == nil then
    print("Starting watcher to close floating terminal when focus is lost")
    watcher = hs.application.watcher.new(
      function(_name, event, app)
        if (event == hs.application.watcher.deactivated)
            and (app:mainWindow():title() == "FloatingKittyWindow")
        then
          print("Hiding floating terminal (focus lost)")
          kitty:hide()
        end
      end
    )
    watcher:start()
  end
end

toggleKitty = function()
  setupWatcher()

  -- -- get the kitty application object
  kitty = getFloatingKittyApplication()

  if kitty == nil then
    -- open background process
    print("No floating terminal process found. Creating one.")
    hs.execute("pkill -f FloatingKittyWindow")           -- kill all previous instances
    io.popen("open -a ~/.hammerspoon/FloatingKitty.app") -- open a new instance

    hs.timer.waitUntil(
      kittyWindowExists,
      function()
        local kitty = getFloatingKittyApplication()

        -- center kity window
        positionWindow(kitty:mainWindow())
      end,
      .1
    )
    return
  end

  -- hide app if it's showing
  if kitty:mainWindow() == hs.window.focusedWindow() then
    print("Hiding floating terminal (hotkey pressed)")
    kitty:hide()
    return
  end

  -- show window if it exists
  if kitty:mainWindow() then
    print("Showing floating terminal")
    positionWindow(kitty:mainWindow())

    return
  end

  -- create a window if one doesn't exist
  print("Creating floating terminal")
  hs.eventtap.keyStroke("cmd", "n", nil, kitty)

  -- wait until it is created, then center it
  hs.timer.waitUntil(
    kittyWindowExists,
    function() positionWindow(kitty:mainWindow()) end,
    .1
  )
end

hs.hotkey.bind("ctrl", "`", toggleKitty)

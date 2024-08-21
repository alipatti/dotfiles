-- factory that returns a function that toggles app when called
toggleApp = function(appName, getApp, openApp)
  -- function to check if app has a window
  local windowExists = function()
    local app = getApp()

    if (app ~= nil) and (app:mainWindow() ~= nil) then
      return true
    else
      return false
    end
  end

  -- function to center and focus the app window
  local focusAndCenter = function()
    local window = getApp():mainWindow()
    hs.spaces.moveWindowToSpace(window, hs.spaces.focusedSpace())
    -- TODO: make this a parameter
    window:moveToUnit '[80,70,20,10]'
    window:moveToScreen(hs.screen.mainScreen())

    window:focus()
  end

  local setupApp = function()
    focusAndCenter()

    -- application watcher that hides the app when focus is lost
    local app = getApp()
    local watcher = hs.application.watcher.new(
      function(_name, eventType, eventApp)
        if eventType ~= hs.application.watcher.deactivated then return end

        if eventApp ~= app then return end

        print("Hiding " .. appName .. " (focus lost)")
        app:hide()
      end
    )
    watcher:start()
  end

  -- toggling function
  local toggle = function()
    -- -- get the hammerspoon application object
    local app = getApp()

    -- if app isn't running, open it
    if app == nil then
      print("No runninng application found for " .. appName .. ". Creating one.")
      openApp()

      -- once the window appears, do necessary setup
      hs.timer.waitUntil(windowExists, setupApp, .1)
      return
    end

    -- hide app if it's in focus
    if app:mainWindow() == hs.window.focusedWindow() then
      print("Hiding " .. appName .. " (hotkey pressed)")
      app:hide()
      return
    end

    -- focus main window if it exists
    if app:mainWindow() then
      print("Showing " .. appName)
      focusAndCenter()
      return
    end

    -- create a window if one doesn't exist
    print("Creating window for " .. appName)
    hs.eventtap.keyStroke("cmd", "n", nil, app)
    hs.timer.waitUntil(windowExists, focusAndCenter, .1)
  end

  return toggle
end

-- floating kitty terminal
hs.hotkey.bind("ctrl", "`",
  toggleApp("FloatingKitty",
    function()
      local floatingKittyPid = hs.execute("pgrep -f FloatingKittyWindow")
      local kittyApp = hs.application(tonumber(floatingKittyPid))

      return kittyApp
    end,
    function()
      hs.execute("pkill -f FloatingKittyWindow")           -- kill all previous instances
      io.popen("open -a ~/.hammerspoon/FloatingKitty.app") -- open a new instance
    end
  )
)

-- TODO: fix this
-- floating chatgpt window
-- hs.hotkey.bind("ctrl", "tab",
--   toggleApp("ChatGPT",
--     function()
--       local window = hs.application.get("chatgpt")
--       if not window then return nil end
--       return window:application()
--     end,
--     function()
--       hs.application.open("/Applications/ChatGPT.app")
--     end
--   )
-- )

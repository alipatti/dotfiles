local hammerMode = hs.hotkey.modal.new(nil, nil)
hs.hotkey.bind("ctrl", "space",
  function() -- on press
    hammerMode:enter()
  end,
  function() -- on release
    hammerMode:exit()
  end
)

-------------------
-- WINDOW TILING --
-------------------

-- regions of the screen to tile windows to
local regions = {
  f = hs.geometry(0, 0, 1, 1),

  l = hs.geometry(0, 0, .5, 1),
  r = hs.geometry(.5, 0, .5, 1),
  t = hs.geometry(0, 0, 1, .5),
  b = hs.geometry(0, .5, 1, .5),

  tl = hs.geometry(0, 0, .5, .5),
  tr = hs.geometry(.5, 0, .5, .5),
  bl = hs.geometry(0, .5, .5, .5),
  br = hs.geometry(.5, .5, .5, .5),
}

local windowBindings = {
  -- full
  [";"] = "f",

  -- halves
  h = "l",
  l = "r",
  j = "b",
  k = "t",

  -- quarters
  u = "tl",
  i = "tr",
  n = "bl",
  m = "br",
}

for key, region in pairs(windowBindings) do
  hammerMode:bind("ctrl", key, function()
    local w = hs.window.focusedWindow()
    local r = regions[region]

    if not w:isFullScreen() then w:move(r) end

    hammerMode:exit()
  end)
end

hammerMode:bind("ctrl", "c", function()
  hs.window.focusedWindow():centerOnScreen()
end)

-----------------------
-- FLOATING TERMINAL --
-----------------------

-- get hammerspoon application object for the kitty background
-- process if it exists, nil otherwise
local getKitty = function()
  local pid = hs.execute("pgrep -f 'kitty --instance-group floating'")
  pid = tonumber(pid)
  return hs.application(pid)
end

-- launch the kitty background process
local startKitty = function()
  io.popen("/Applications/kitty.app/Contents/MacOS/kitty " ..
    "--instance-group floating " ..
    "--directory ~ " ..
    "-o hide_window_decorations=titlebar-only " ..
    -- "-o macos_window_resizable=no " ..
    "-o macos_hide_from_tasks=yes"
  )
end

local createWindow = function(app)
  hs.eventtap.keyStroke("cmd", "n", nil, app)
end

hammerMode:bind("ctrl", "t", function()
  -- get the kitty application object
  local kitty = getKitty()
  if not kitty then
    startKitty()
    kitty = getKitty()
  end

  -- if is showing, hide it
  if kitty:isFrontmost() then
    kitty:hide()
    return
  end

  -- if it's not showing, activate it
  if not kitty:mainWindow() then createWindow(kitty) end
  local w = kitty:mainWindow()
  w:centerOnScreen(nil, 0)
  hs.spaces.moveWindowToSpace(w, hs.spaces.focusedSpace())
  w:focus()
end)

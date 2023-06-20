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

-----------------------
-- FLOATING TERMINAL --
-----------------------

hammerMode:bind("ctrl", "t", function()
  -- if kitty is showing, hide it
  if not kitty:isHidden() then
    kitty:hide()
    return
  end

  kitty:activate()

  if not kitty:mainWindow() then
    hs.eventtap.keystroke({ "cmd" }, "n", kitty)
  end

  kitty:mainWindow():centerOnScreen()
end)

-- hs.hotkey.new("ctrl", "space", function() hs.alert("hello world") end)

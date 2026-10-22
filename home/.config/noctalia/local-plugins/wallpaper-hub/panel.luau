--!nonstrict
-- Wallpaper Hub: one carousel for images AND videos.
-- Carousel UI adapted from ashur-d/wallpaper-widget (MIT); video playback is
-- delegated to this plugin's own mpvpaper service through the shared "command" state.

local selectedIndex = 1
local displayedIndex = 1
local fullList = {}
local allWallpapers = {}
local filterMode = "all" -- all | images | videos
local currentWallpaper = ""
local isScanning = false
local navToken = 0
local generatingPending = {}
local batchRunning = false
local batchDone = false
local isOpen = false
local cmdNonce = 0

math.randomseed(math.floor((os.clock() * 1000000) % 2147483647) + os.time())

local function shellQuote(s)
  return "'" .. s:gsub("'", "'\\''") .. "'"
end

local function makeSortKey(s)
  local lower = s:lower()
  return lower:gsub("%d+", function(n)
    return string.format("%08d", tonumber(n) or 0)
  end)
end

local home = noctalia.getenv("HOME") or "~"
local xdgCache = noctalia.getenv("XDG_CACHE_HOME")
local cacheDir = (xdgCache and xdgCache ~= "" and xdgCache or (home .. "/.cache")) .. "/noctalia/wallpaper-hub/thumbs3"

local cacheDirPrepared = false
local function ensureCacheDir()
  if cacheDirPrepared then return end
  cacheDirPrepared = true
  if not noctalia.fileExists(cacheDir) then
    noctalia.runAsync("mkdir -p " .. shellQuote(cacheDir))
  end
end

local function getThumbPath(wallpaperPath)
  local safe = wallpaperPath:gsub("[^%w]", "_")
  if #safe > 150 then safe = safe:sub(-150) end
  return cacheDir .. "/" .. safe .. ".jpg"
end

-- Shell snippet that writes a 512x288 cover-cropped thumbnail for src into dst.
local VIDEO_FILTER = "scale=960:-2"
local function thumbCmd(kind, src, dst)
  if kind == "video" then
    return string.format(
      "nice -n 19 ffmpeg -y -loglevel error -ss 1 -i %s -frames:v 1 -vf %s %s >/dev/null 2>&1 || nice -n 19 ffmpeg -y -loglevel error -i %s -frames:v 1 -vf %s %s >/dev/null 2>&1",
      shellQuote(src), shellQuote(VIDEO_FILTER), shellQuote(dst),
      shellQuote(src), shellQuote(VIDEO_FILTER), shellQuote(dst))
  end
  return string.format(
    "if command -v magick >/dev/null 2>&1; then nice -n 19 magick %s[0] -thumbnail 960x960\\> %s >/dev/null 2>&1; else nice -n 19 ffmpeg -y -loglevel error -i %s -vf %s %s >/dev/null 2>&1; fi",
    shellQuote(src), shellQuote(dst), shellQuote(src), shellQuote(VIDEO_FILTER), shellQuote(dst))
end

local render

local function resolveDisplayPath(item)
  if not item or not item.path or item.path == "" then return "" end
  ensureCacheDir()
  local thumb = getThumbPath(item.path)
  if noctalia.fileExists(thumb) then
    return thumb
  end

  if not generatingPending[item.path] then
    generatingPending[item.path] = true
    local cmd = "[ -d " .. shellQuote(cacheDir) .. " ] || mkdir -p " .. shellQuote(cacheDir) .. "; " .. thumbCmd(item.kind, item.path, thumb)
    noctalia.runAsync(cmd, function()
      generatingPending[item.path] = nil
      if isOpen and noctalia.fileExists(thumb) and render then
        render()
      end
    end)
  end

  -- Videos have no usable placeholder; images can show themselves meanwhile.
  if item.kind == "image" then return item.path end
  return ""
end

local function triggerBatchThumbnails()
  if batchRunning or batchDone or #fullList == 0 then return end
  batchDone = true
  ensureCacheDir()

  local missing = {}
  for _, wp in ipairs(fullList) do
    table.insert(missing, { kind = wp.kind, src = wp.path, dst = getThumbPath(wp.path) })
  end

  if #missing == 0 then return end
  batchRunning = true

  local chunkSize = 12
  local chunkIndex = 1

  local function processNextChunk()
    if chunkIndex > #missing then
      batchRunning = false
      return
    end

    local parts = { "[ -d " .. shellQuote(cacheDir) .. " ] || mkdir -p " .. shellQuote(cacheDir) .. "; " }
    local chunkEnd = math.min(chunkIndex + chunkSize - 1, #missing)
    for i = chunkIndex, chunkEnd do
      local item = missing[i]
      table.insert(parts, string.format("[ -f %s ] || { %s; }; ", shellQuote(item.dst), thumbCmd(item.kind, item.src, item.dst)))
    end

    chunkIndex = chunkEnd + 1
    noctalia.runAsync(table.concat(parts), function()
      if isOpen and render then
        render()
      end
      processNextChunk()
    end)
  end

  processNextChunk()
end

local function getWallpaperDir()
  if noctalia.wallpaperDirectory then
    local ok, d = pcall(function() return noctalia.wallpaperDirectory() end)
    if ok and type(d) == "string" and d ~= "" then
      return d
    end
  end
  return home .. "/Pictures/Walpappers"
end

local function kindOf(name)
  local lower = name:lower()
  if lower:match("%.png$") or lower:match("%.jpg$") or lower:match("%.jpeg$") or lower:match("%.webp$") or lower:match("%.avif$") then
    return "image"
  end
  if lower:match("%.mp4$") or lower:match("%.mkv$") or lower:match("%.webm$") or lower:match("%.mov$") or lower:match("%.gif$") then
    return "video"
  end
  return nil
end

local function getCurrentWallpaper()
  if noctalia.wallpaperPath then
    local out = noctalia.focusedOutputName and noctalia.focusedOutputName()
    if out then
      local path = noctalia.wallpaperPath(out)
      if path and path ~= "" then return path end
    end
    if noctalia.outputs then
      for _, o in ipairs(noctalia.outputs()) do
        if o.name then
          local path = noctalia.wallpaperPath(o.name)
          if path and path ~= "" then return path end
        end
      end
    end
  end
  return nil
end

-- Path of the video currently playing on all outputs (or any output), if any.
local function activeVideo()
  local assignments = noctalia.state.get("assignments")
  if type(assignments) ~= "table" then return nil end
  if assignments["*"] then return assignments["*"] end
  for _, v in pairs(assignments) do
    return v
  end
  return nil
end

local function isActive(item)
  if item.kind == "video" then
    return activeVideo() == item.path
  end
  return activeVideo() == nil and currentWallpaper == item.path
end

local function scanDir(dir, list, depth)
  if depth > 2 then return end
  local entries = noctalia.listDir(dir)
  if not entries then return end

  for _, name in ipairs(entries) do
    if name ~= "." and name ~= ".." and not name:match("^%.") then
      local fullPath = dir .. "/" .. name
      local kind = kindOf(name)
      if kind then
        local cleanName = name:gsub("%.%w+$", "")
        table.insert(list, {
          path = fullPath,
          name = cleanName,
          filename = name,
          kind = kind,
          sortKey = makeSortKey(cleanName),
        })
      else
        local info = noctalia.fileInfo(fullPath)
        if info and info.isDir then
          scanDir(fullPath, list, depth + 1)
        end
      end
    end
  end
end

local function rebuildFiltered(keepPath)
  local list = {}
  for _, wp in ipairs(fullList) do
    if filterMode == "all" or (filterMode == "images" and wp.kind == "image") or (filterMode == "videos" and wp.kind == "video") then
      table.insert(list, wp)
    end
  end
  allWallpapers = list
  selectedIndex = 1
  displayedIndex = 1
  if keepPath then
    for i, wp in ipairs(list) do
      if wp.path == keepPath then
        selectedIndex = i
        displayedIndex = i
        break
      end
    end
  end
end

local function getDisplayedWallpaperAt(offset)
  local total = #allWallpapers
  if total == 0 then return nil, 1 end
  local idx = ((displayedIndex - 1 + offset) % total) + 1
  return allWallpapers[idx], idx
end

local function syncSelectedIndexToActive()
  if #allWallpapers == 0 then return end
  for i, wp in ipairs(allWallpapers) do
    if isActive(wp) then
      selectedIndex = i
      displayedIndex = i
      return
    end
  end
end

local function refreshActiveWallpaper(callback)
  local active = getCurrentWallpaper()
  if active and active ~= "" then
    currentWallpaper = active
    if callback then callback() end
    return
  end

  noctalia.runAsync("noctalia msg wallpaper-get", function(result)
    if result and result.exitCode == 0 and result.stdout then
      currentWallpaper = result.stdout:gsub("%s+$", "")
    end
    if callback then callback() end
  end, 1500)
end

local function loadWallpapers()
  isScanning = true
  local list = {}
  scanDir(getWallpaperDir(), list, 0)
  table.sort(list, function(a, b)
    return a.sortKey < b.sortKey
  end)
  fullList = list
  isScanning = false
  rebuildFiltered(nil)
  triggerBatchThumbnails()
  refreshActiveWallpaper(function()
    syncSelectedIndexToActive()
    if isOpen and render then
      render()
    end
  end)
end

local function sendCommand(action, connector, path)
  cmdNonce = cmdNonce + 1
  noctalia.state.set("command", { action = action, connector = connector, path = path, nonce = cmdNonce })
end

local function applyItem(item)
  if not item then return end

  if item.kind == "video" then
    sendCommand("set", "*", item.path)
  else
    local hadVideo = activeVideo() ~= nil
    if hadVideo then
      -- Stops mpvpaper and gives the surface back to Noctalia.
      sendCommand("clear-all", nil, nil)
      noctalia.runAsync({ "sleep", "0.6" }, function()
        if noctalia.setWallpaper then
          noctalia.setWallpaper(item.path)
        else
          noctalia.runAsync("noctalia msg wallpaper-set " .. shellQuote(item.path))
        end
        currentWallpaper = item.path
        if isOpen and render then render() end
      end)
    else
      if noctalia.setWallpaper then
        noctalia.setWallpaper(item.path)
      else
        noctalia.runAsync("noctalia msg wallpaper-set " .. shellQuote(item.path))
      end
    end
    currentWallpaper = item.path
  end

  panel.close()
end

local function applyRandom()
  local total = #allWallpapers
  if total == 0 then return end
  local idx = math.random(1, total)
  if total > 1 and idx == selectedIndex then
    idx = (idx % total) + 1
  end
  selectedIndex = idx
  displayedIndex = idx
  applyItem(allWallpapers[idx])
end

local function cardsCached(centerIdx)
  local total = #allWallpapers
  if total == 0 then return true end
  for off = -3, 3 do
    local idx = ((centerIdx - 1 + off) % total) + 1
    if not noctalia.fileExists(getThumbPath(allWallpapers[idx].path)) then return false end
  end
  return true
end

local function scheduleDisplay()
  navToken = navToken + 1
  local currentToken = navToken

  render()

  noctalia.runAsync({"sleep", "0.040"}, function()
    if isOpen and navToken == currentToken then
      displayedIndex = selectedIndex
      render()
    end
  end)
end

local function stepSelection(delta)
  local total = #allWallpapers
  if total == 0 then return end
  selectedIndex = ((selectedIndex - 1 + delta) % total) + 1

  if cardsCached(selectedIndex) then
    displayedIndex = selectedIndex
    render()
  else
    scheduleDisplay()
  end
end

local function cycleFilter()
  local keep = allWallpapers[selectedIndex] and allWallpapers[selectedIndex].path or nil
  if filterMode == "all" then filterMode = "images"
  elseif filterMode == "images" then filterMode = "videos"
  else filterMode = "all" end
  rebuildFiltered(keep)
  render()
end

local function card(key, item, idx, width, height, radius, opacity, onClick, borderW, border)
  local children = {
    ui.image({
      key = "img-" .. key,
      path = resolveDisplayPath(item),
      width = width,
      height = height,
      fit = "cover",
      radius = radius,
      borderWidth = borderW,
      border = border,
    }),
  }
  return ui.column({
    key = "card-" .. key,
    align = "center",
    width = width,
    opacity = opacity,
    onClick = onClick,
  }, children)
end

local FILTER_LABEL = { all = "All", images = "Images", videos = "Videos" }

render = function()
  if isScanning then
    panel.render(ui.column({
      align = "center", justify = "center", flexGrow = 1, gap = 12, padding = 40,
    }, {
      ui.glyph({ name = "loader-2", size = 36, color = "primary" }),
      ui.label({ text = "Loading wallpapers...", fontSize = 14, color = "on_surface_variant" }),
    }))
    return
  end

  if #allWallpapers == 0 then
    panel.render(ui.column({
      align = "center", justify = "center", flexGrow = 1, gap = 12, padding = 40,
    }, {
      ui.glyph({ name = "photo-off", size = 48, color = "on_surface_variant" }),
      ui.label({ text = "No wallpapers found", fontSize = 15, fontWeight = "bold", color = "on_surface" }),
      ui.label({ text = "Filter: " .. FILTER_LABEL[filterMode] .. "  (Tab to change)", fontSize = 13, color = "on_surface_variant" }),
      ui.label({ text = getWallpaperDir(), fontSize = 11, color = "outline" }),
    }))
    return
  end

  local wpCenter = getDisplayedWallpaperAt(0)
  local centerActive = isActive(wpCenter)

  -- 7 cards, tallest in the middle, fading and shrinking outwards.
  local SIZES = {
    [0] = { 400, 430, 1.0 },
    [1] = { 230, 350, 0.85 },
    [2] = { 170, 280, 0.65 },
    [3] = { 120, 220, 0.45 },
  }
  local cards = {}
  for off = -3, 3 do
    local item, idx = getDisplayedWallpaperAt(off)
    local sz = SIZES[math.abs(off)]
    local active = isActive(item)
    local isCenter = off == 0
    table.insert(cards, card("o" .. tostring(off), item, idx, sz[1], sz[2], isCenter and 18 or 14, sz[3],
      function()
        if isCenter then
          applyItem(item)
        else
          selectedIndex = idx
          displayedIndex = idx
          render()
        end
      end,
      (isCenter and (centerActive and 3 or 1)) or (active and 2 or 0),
      (isCenter and (centerActive and "primary" or "outline")) or (active and "primary" or nil)))
  end

  local carouselRow = ui.row({
    align = "center", justify = "center", gap = 10, flexGrow = 1,
  }, cards)

  local isVideo = wpCenter.kind == "video"

  local badges = {
    ui.row({
      align = "center", gap = 4, paddingH = 8, paddingV = 2, radius = 10,
      fill = isVideo and "tertiary/0.25" or "secondary/0.25",
    }, {
      ui.glyph({ name = isVideo and "movie" or "photo", size = 13, color = isVideo and "tertiary" or "secondary" }),
      ui.label({ text = isVideo and "Live" or "Image", fontSize = 10, fontWeight = "bold", color = isVideo and "tertiary" or "secondary" }),
    }),
  }
  if centerActive then
    table.insert(badges, ui.row({
      align = "center", gap = 4, paddingH = 8, paddingV = 2, radius = 10, fill = "primary/0.2",
    }, {
      ui.glyph({ name = "check", size = 13, color = "primary" }),
      ui.label({ text = "Active", fontSize = 10, fontWeight = "bold", color = "primary" }),
    }))
  end

  local infoSection = ui.column({ align = "center", gap = 4 }, {
    ui.row({ align = "center", justify = "center", gap = 8, height = 22 }, badges),
    ui.label({ text = wpCenter.name, fontSize = 13, fontWeight = "bold", color = "on_surface" }),
    ui.label({
      text = tostring(selectedIndex) .. " / " .. tostring(#allWallpapers) .. "   -   " .. FILTER_LABEL[filterMode],
      fontSize = 12, color = "on_surface_variant",
    }),
    ui.label({
      text = "Enter apply   Space random   Tab filter   Esc close",
      fontSize = 11, color = "on_surface_variant",
    }),
  })

  panel.render(ui.column({ padding = 24, gap = 14, align = "stretch", flexGrow = 1 }, {
    carouselRow,
    infoSection,
  }))
end

function onKey(chord, pressed)
  if not pressed then return end

  if chord == "Left" or chord == "Up" then
    stepSelection(-1)
  elseif chord == "Right" or chord == "Down" then
    stepSelection(1)
  elseif chord == "Return" then
    if #allWallpapers > 0 and selectedIndex >= 1 and selectedIndex <= #allWallpapers then
      displayedIndex = selectedIndex
      applyItem(allWallpapers[selectedIndex])
    end
  elseif chord == "Space" then
    applyRandom()
  elseif chord == "Tab" then
    cycleFilter()
  elseif chord == "Escape" then
    panel.close()
  end
end

local lastScrollTime = 0

function onScroll(axis, steps, _startsGesture)
  if axis ~= "vertical" then return end
  if #allWallpapers == 0 then return end
  local now = os.clock()
  if now - lastScrollTime < 0.12 then return end
  lastScrollTime = now

  if (steps or 0) > 0 then
    stepSelection(1)
  else
    stepSelection(-1)
  end
end

function onOpen(_context)
  isOpen = true
  refreshActiveWallpaper(function()
    if #fullList > 0 then
      syncSelectedIndexToActive()
      displayedIndex = selectedIndex
      render()
    end
  end)
  if #fullList == 0 then
    loadWallpapers()
  else
    render()
  end
end

function onClose()
  isOpen = false
end

noctalia.state.watch("assignments", function(_)
  if isOpen and render then render() end
end)

loadWallpapers()

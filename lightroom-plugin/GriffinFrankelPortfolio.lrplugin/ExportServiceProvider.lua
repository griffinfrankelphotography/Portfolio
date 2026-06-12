-- Export service: publishes selected photos straight to the portfolio.
-- Uploads each rendered JPEG to images/ via the GitHub Contents API, then
-- updates photos.json — the same flow as the admin page, so the site picks
-- the photos up as soon as GitHub Pages redeploys (~1 minute).

local LrDialogs     = import 'LrDialogs'
local LrFileUtils   = import 'LrFileUtils'
local LrHttp        = import 'LrHttp'
local LrPasswords   = import 'LrPasswords'
local LrPathUtils   = import 'LrPathUtils'
local LrStringUtils = import 'LrStringUtils'
local LrTasks       = import 'LrTasks'
local LrView        = import 'LrView'

local JSON = require 'JSON'

local REPO      = 'griffinfrankelphotography/Portfolio'
local BRANCH    = 'main'
local API       = 'https://api.github.com'
local TOKEN_KEY = 'com.griffinfrankel.portfolio.token'

local GALLERIES = {
  { title = 'People',        value = 'portrait' },
  { title = 'City & Nature', value = 'city-nature' },
  { title = 'Events',        value = 'events' },
}

local function galleryTitle(tag)
  for _, g in ipairs(GALLERIES) do
    if g.value == tag then return g.title end
  end
  return tag
end

-- ── GitHub API ──────────────────────────────────────────────────────────────

local function ghRequest(method, path, token, bodyTable)
  local headers = {
    { field = 'Authorization', value = 'token ' .. token },
    { field = 'Accept',        value = 'application/vnd.github.v3+json' },
    { field = 'User-Agent',    value = 'GFP-Lightroom-Plugin' },
  }
  local body, respHeaders
  if method == 'GET' then
    body, respHeaders = LrHttp.get(API .. path, headers)
  else
    headers[#headers + 1] = { field = 'Content-Type', value = 'application/json' }
    body, respHeaders = LrHttp.post(API .. path, JSON.encode(bodyTable), headers, method)
  end
  local status = (respHeaders and respHeaders.status) or 0
  return status, body and JSON.decode(body) or nil
end

local function ghErrorMessage(status, data)
  if data and data.message then return data.message .. ' (HTTP ' .. status .. ')' end
  if status == 0 then return 'no response — check your internet connection' end
  return 'GitHub returned HTTP ' .. status
end

local function fetchPhotosJson(token)
  local status, data = ghRequest('GET', '/repos/' .. REPO .. '/contents/photos.json?ref=' .. BRANCH, token)
  if status == 200 and data and data.content then
    local raw = LrStringUtils.decodeBase64(data.content:gsub('%s', ''))
    local photos, err = JSON.decode(raw)
    if not photos then error('photos.json is not valid JSON: ' .. tostring(err)) end
    return photos, data.sha
  elseif status == 404 then
    return {}, nil
  end
  error(ghErrorMessage(status, data))
end

local function putPhotosJson(token, photos, sha)
  local body = {
    message = 'Update gallery (Lightroom export)',
    content = LrStringUtils.encodeBase64(JSON.encodePretty(photos)),
    branch  = BRANCH,
  }
  if sha then body.sha = sha end
  local status, data = ghRequest('PUT', '/repos/' .. REPO .. '/contents/photos.json', token, body)
  if status ~= 200 and status ~= 201 then error(ghErrorMessage(status, data)) end
end

local function uploadImage(token, path, base64Content, fileName)
  -- If the file already exists, GitHub requires its sha to overwrite
  local status, existing = ghRequest('GET', '/repos/' .. REPO .. '/contents/' .. path .. '?ref=' .. BRANCH, token)
  local body = {
    message = 'Upload photo: ' .. fileName,
    content = base64Content,
    branch  = BRANCH,
  }
  if status == 200 and existing and existing.sha then body.sha = existing.sha end
  local putStatus, data = ghRequest('PUT', '/repos/' .. REPO .. '/contents/' .. path, token, body)
  if putStatus ~= 200 and putStatus ~= 201 then error(ghErrorMessage(putStatus, data)) end
end

-- ── Helpers ─────────────────────────────────────────────────────────────────

-- Match the admin page's naming: spaces become dashes, extension becomes .jpg
local function sanitizeFileName(name)
  name = name:gsub('%.[^.]+$', '')
  name = name:gsub('%s+', '-'):gsub('[^%w%-%._]', ''):gsub('%-%-+', '-')
  if name == '' then name = 'photo-' .. os.time() end
  return name .. '.jpg'
end

local function round3(x)
  return math.floor(x * 1000 + 0.5) / 1000
end

-- ── Export service definition ───────────────────────────────────────────────

local exportServiceProvider = {}

exportServiceProvider.allowFileFormats = { 'JPEG' }
exportServiceProvider.allowColorSpaces = { 'sRGB' }
exportServiceProvider.canExportVideo = false
exportServiceProvider.hideSections = {
  'exportLocation', 'fileNaming', 'fileSettings', 'imageSettings',
  'outputSharpening', 'video', 'watermarking',
}

-- The token is intentionally NOT a preset field: presets are stored as
-- plain text, so the token lives in Lightroom's password store instead.
exportServiceProvider.exportPresetFields = {
  { key = 'gallery', default = 'portrait' },
}

-- Force the site's image standard (same as the admin upload pipeline)
function exportServiceProvider.updateExportSettings(exportSettings)
  exportSettings.LR_format = 'JPEG'
  exportSettings.LR_jpeg_quality = 0.82
  exportSettings.LR_export_colorSpace = 'sRGB'
  exportSettings.LR_size_doConstrain = true
  exportSettings.LR_size_resizeType = 'longEdge'
  exportSettings.LR_size_maxWidth = 2400
  exportSettings.LR_size_maxHeight = 2400
  exportSettings.LR_size_units = 'pixels'
  exportSettings.LR_size_doNotEnlarge = true
  exportSettings.LR_embeddedMetadataOption = 'copyrightOnly'
  exportSettings.LR_removeLocationMetadata = true
  exportSettings.LR_export_destinationType = 'tempFolder'
  exportSettings.LR_reimportExportedPhoto = false
end

function exportServiceProvider.startDialog(propertyTable)
  if not propertyTable.token or propertyTable.token == '' then
    propertyTable.token = LrPasswords.retrieve(TOKEN_KEY) or ''
  end
  if not propertyTable.gallery then
    propertyTable.gallery = 'portrait'
  end
end

function exportServiceProvider.endDialog(propertyTable)
  if propertyTable.token and propertyTable.token ~= '' then
    LrPasswords.store(TOKEN_KEY, propertyTable.token)
  end
end

function exportServiceProvider.sectionsForTopOfDialog(f, propertyTable)
  local bind = LrView.bind

  return {
    {
      title = 'Griffin Frankel Portfolio',

      f:row {
        f:static_text {
          title = 'Photos are resized to 2400px / quality 82 (the site standard),\n'
            .. 'uploaded to the portfolio repo, and added to the chosen gallery.\n'
            .. 'The live site updates about a minute after the export finishes.',
          fill_horizontal = 1,
        },
      },

      f:spacer { height = 8 },

      f:row {
        spacing = f:control_spacing(),
        f:static_text { title = 'Gallery:', width = LrView.share 'label_width' },
        f:popup_menu {
          value = bind 'gallery',
          items = GALLERIES,
          width_in_chars = 18,
        },
      },

      f:spacer { height = 8 },

      f:row {
        spacing = f:control_spacing(),
        f:static_text { title = 'GitHub token:', width = LrView.share 'label_width' },
        f:password_field {
          value = bind 'token',
          width_in_chars = 30,
          immediate = true,
        },
        f:push_button {
          title = 'Test connection',
          action = function()
            LrTasks.startAsyncTask(function()
              local token = propertyTable.token
              if not token or token == '' then
                LrDialogs.message('Griffin Frankel Portfolio',
                  'Paste a GitHub personal access token first.', 'warning')
                return
              end
              local status, data = ghRequest('GET', '/repos/' .. REPO, token)
              if status == 200 then
                LrPasswords.store(TOKEN_KEY, token)
                LrDialogs.message('Connected',
                  'Token works — connected to ' .. (data and data.full_name or REPO) .. '.')
              else
                LrDialogs.message('Connection failed',
                  ghErrorMessage(status, data) .. '\n\nCheck that the token has the "repo" scope.',
                  'critical')
              end
            end)
          end,
        },
      },

      f:row {
        f:static_text {
          title = 'Same token as the admin page — create one at\n'
            .. 'github.com/settings/tokens/new with the "repo" scope.',
          text_color = import('LrColor')(0.5, 0.5, 0.5),
          fill_horizontal = 1,
        },
      },
    },
  }
end

function exportServiceProvider.processRenderedPhotos(functionContext, exportContext)
  local props = exportContext.propertyTable
  local token = (props.token and props.token ~= '' and props.token)
    or LrPasswords.retrieve(TOKEN_KEY) or ''
  local tag = props.gallery or 'portrait'

  local nPhotos = exportContext.exportSession:countRenditions()
  local progressScope = exportContext:configureProgress {
    title = nPhotos > 1
      and ('Publishing ' .. nPhotos .. ' photos to portfolio')
      or 'Publishing photo to portfolio',
  }

  if token == '' then
    LrDialogs.message('Griffin Frankel Portfolio',
      'No GitHub token configured. Open the export dialog and connect first.', 'critical')
    return
  end

  -- Load the current gallery index up front so we fail fast on a bad token
  local okFetch, photosOrErr, photosSha = pcall(fetchPhotosJson, token)
  if not okFetch then
    LrDialogs.message('Griffin Frankel Portfolio',
      'Could not load photos.json: ' .. tostring(photosOrErr), 'critical')
    return
  end
  local photosData = photosOrErr

  local uploaded, failed = {}, {}

  for i, rendition in exportContext:renditions { stopIfCanceled = true } do
    progressScope:setPortionComplete((i - 1) / nPhotos)
    local success, pathOrMessage = rendition:waitForRender()
    if success then
      local fileName = sanitizeFileName(LrPathUtils.leafName(pathOrMessage))
      progressScope:setCaption('Uploading ' .. fileName .. ' (' .. i .. ' of ' .. nPhotos .. ')')

      local fileData = LrFileUtils.readFile(pathOrMessage)
      local okUpload, err = pcall(uploadImage, token,
        'images/' .. fileName, LrStringUtils.encodeBase64(fileData), fileName)

      if okUpload then
        local entry = { src = 'images/' .. fileName, tag = tag }
        local dims = rendition.photo:getRawMetadata('croppedDimensions')
        if dims and dims.width and dims.height and dims.height > 0 then
          entry.aspect = round3(dims.width / dims.height)
        end
        uploaded[#uploaded + 1] = entry
      else
        failed[#failed + 1] = fileName .. ' — ' .. tostring(err)
      end
      LrFileUtils.delete(pathOrMessage)
    elseif pathOrMessage then
      failed[#failed + 1] = tostring(pathOrMessage)
    end
  end

  if #uploaded > 0 then
    progressScope:setCaption('Updating gallery index…')
    -- Re-exported photos replace their existing entry instead of duplicating
    local indexBySrc = {}
    for idx, p in ipairs(photosData) do indexBySrc[p.src] = idx end
    for _, p in ipairs(uploaded) do
      if indexBySrc[p.src] then
        photosData[indexBySrc[p.src]] = p
      else
        photosData[#photosData + 1] = p
      end
    end
    local okPut, err = pcall(putPhotosJson, token, photosData, photosSha)
    if not okPut then
      failed[#failed + 1] = 'photos.json update — ' .. tostring(err)
    end
  end

  progressScope:done()

  if #failed > 0 then
    LrDialogs.message('Portfolio publish finished with errors',
      table.concat(failed, '\n'), 'warning')
  elseif #uploaded > 0 then
    LrDialogs.message('Published to portfolio',
      #uploaded .. ' photo' .. (#uploaded == 1 and '' or 's')
      .. ' added to the ' .. galleryTitle(tag)
      .. ' gallery.\nThe live site updates in about a minute.')
  end
end

return exportServiceProvider

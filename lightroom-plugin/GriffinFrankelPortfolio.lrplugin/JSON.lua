-- Minimal JSON encoder/decoder.
-- Covers everything the GitHub API and photos.json need; not a general-
-- purpose library (no surrogate pairs, no huge numbers).

local JSON = {}

-- ── Encode ──────────────────────────────────────────────────────────────────

local ESCAPES = {
  ['"'] = '\\"', ['\\'] = '\\\\', ['\b'] = '\\b', ['\f'] = '\\f',
  ['\n'] = '\\n', ['\r'] = '\\r', ['\t'] = '\\t',
}

local function encodeString(s)
  return '"' .. s:gsub('[%z\1-\31"\\]', function(c)
    return ESCAPES[c] or string.format('\\u%04x', c:byte())
  end) .. '"'
end

-- photos.json entries read nicest as src, tag, aspect — keep that order
local KEY_ORDER = { src = 1, tag = 2, aspect = 3 }

local function sortedKeys(t)
  local keys = {}
  for k in pairs(t) do keys[#keys + 1] = k end
  table.sort(keys, function(a, b)
    local oa, ob = KEY_ORDER[a] or 99, KEY_ORDER[b] or 99
    if oa ~= ob then return oa < ob end
    return tostring(a) < tostring(b)
  end)
  return keys
end

local function isArray(t)
  local n = 0
  for _ in pairs(t) do n = n + 1 end
  return n == #t
end

local function encodeValue(v, indent, pretty)
  if v == nil then return 'null' end
  local t = type(v)
  if t == 'boolean' then return tostring(v) end
  if t == 'number' then return tostring(v) end
  if t == 'string' then return encodeString(v) end
  if t == 'table' then
    local nl, pad, padEnd = '', '', ''
    if pretty then
      nl = '\n'
      pad = string.rep('  ', indent + 1)
      padEnd = string.rep('  ', indent)
    end
    local parts = {}
    if isArray(v) then
      if #v == 0 then return '[]' end
      for i = 1, #v do
        parts[#parts + 1] = pad .. encodeValue(v[i], indent + 1, pretty)
      end
      return '[' .. nl .. table.concat(parts, ',' .. nl) .. nl .. padEnd .. ']'
    end
    for _, k in ipairs(sortedKeys(v)) do
      parts[#parts + 1] = pad .. encodeString(tostring(k))
        .. (pretty and ': ' or ':') .. encodeValue(v[k], indent + 1, pretty)
    end
    if #parts == 0 then return '{}' end
    return '{' .. nl .. table.concat(parts, ',' .. nl) .. nl .. padEnd .. '}'
  end
  error('cannot encode value of type ' .. t)
end

function JSON.encode(v) return encodeValue(v, 0, false) end
function JSON.encodePretty(v) return encodeValue(v, 0, true) end

-- ── Decode ──────────────────────────────────────────────────────────────────

local function decodeError(pos, msg)
  error(string.format('JSON parse error at position %d: %s', pos, msg), 0)
end

local function skipWhitespace(str, pos)
  return str:find('[^ \t\r\n]', pos) or (#str + 1)
end

local decodeValue

local UNESCAPES = {
  ['"'] = '"', ['\\'] = '\\', ['/'] = '/', b = '\b', f = '\f',
  n = '\n', r = '\r', t = '\t',
}

local function decodeString(str, pos)
  local out = {}
  local i = pos + 1
  while i <= #str do
    local c = str:sub(i, i)
    if c == '"' then
      return table.concat(out), i + 1
    elseif c == '\\' then
      local esc = str:sub(i + 1, i + 1)
      if UNESCAPES[esc] then
        out[#out + 1] = UNESCAPES[esc]
        i = i + 2
      elseif esc == 'u' then
        local cp = tonumber(str:sub(i + 2, i + 5), 16)
        if not cp then decodeError(i, 'bad \\u escape') end
        if cp < 0x80 then
          out[#out + 1] = string.char(cp)
        elseif cp < 0x800 then
          out[#out + 1] = string.char(0xC0 + math.floor(cp / 0x40), 0x80 + cp % 0x40)
        else
          out[#out + 1] = string.char(
            0xE0 + math.floor(cp / 0x1000),
            0x80 + math.floor(cp / 0x40) % 0x40,
            0x80 + cp % 0x40)
        end
        i = i + 6
      else
        decodeError(i, 'bad escape \\' .. esc)
      end
    else
      out[#out + 1] = c
      i = i + 1
    end
  end
  decodeError(pos, 'unterminated string')
end

decodeValue = function(str, pos)
  pos = skipWhitespace(str, pos)
  local c = str:sub(pos, pos)
  if c == '{' then
    local obj = {}
    pos = skipWhitespace(str, pos + 1)
    if str:sub(pos, pos) == '}' then return obj, pos + 1 end
    while true do
      if str:sub(pos, pos) ~= '"' then decodeError(pos, 'expected object key') end
      local key
      key, pos = decodeString(str, pos)
      pos = skipWhitespace(str, pos)
      if str:sub(pos, pos) ~= ':' then decodeError(pos, "expected ':'") end
      local val
      val, pos = decodeValue(str, pos + 1)
      obj[key] = val
      pos = skipWhitespace(str, pos)
      local d = str:sub(pos, pos)
      if d == ',' then
        pos = skipWhitespace(str, pos + 1)
      elseif d == '}' then
        return obj, pos + 1
      else
        decodeError(pos, "expected ',' or '}'")
      end
    end
  elseif c == '[' then
    local arr = {}
    pos = skipWhitespace(str, pos + 1)
    if str:sub(pos, pos) == ']' then return arr, pos + 1 end
    while true do
      local val
      val, pos = decodeValue(str, pos)
      arr[#arr + 1] = val
      pos = skipWhitespace(str, pos)
      local d = str:sub(pos, pos)
      if d == ',' then
        pos = pos + 1
      elseif d == ']' then
        return arr, pos + 1
      else
        decodeError(pos, "expected ',' or ']'")
      end
    end
  elseif c == '"' then
    return decodeString(str, pos)
  elseif str:sub(pos, pos + 3) == 'true' then
    return true, pos + 4
  elseif str:sub(pos, pos + 4) == 'false' then
    return false, pos + 5
  elseif str:sub(pos, pos + 3) == 'null' then
    return nil, pos + 4
  else
    local numStr = str:match('^-?%d+%.?%d*[eE]?[%+%-]?%d*', pos)
    local n = numStr and tonumber(numStr)
    if not n then decodeError(pos, "unexpected character '" .. c .. "'") end
    return n, pos + #numStr
  end
end

-- Returns the decoded value, or nil plus an error message
function JSON.decode(str)
  if type(str) ~= 'string' then return nil, 'not a string' end
  local ok, valueOrErr, endPos = pcall(decodeValue, str, 1)
  if not ok then return nil, valueOrErr end
  return valueOrErr, nil, endPos
end

return JSON

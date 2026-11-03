-- Pandoc filter used when building 实验报告.tex.
--  * a screenshot that is not in images/ yet becomes a red box naming the file
--  * "2^1024" becomes a real superscript; math-like symbols use LaTeX math
--  * 【待补…】 text is shown in red
--  * ```asm code blocks are highlighted as GNU assembler
--  * table column widths follow the length of their contents

local function exists(path)
  local f = io.open(path, "rb")
  if f then f:close() return true end
  return false
end

function Image(el)
  if exists(el.src) then return nil end
  return pandoc.RawInline("latex", "\\missingshot{" .. el.src .. "}")
end

local sym = {
  ["×"] = "\\ensuremath{\\times}", ["÷"] = "\\ensuremath{\\div}",
  ["Σ"] = "\\ensuremath{\\Sigma}", ["−"] = "\\ensuremath{-}",
  ["≤"] = "\\ensuremath{\\leq}",   ["≥"] = "\\ensuremath{\\geq}",
  ["⌊"] = "\\ensuremath{\\lfloor}", ["⌋"] = "\\ensuremath{\\rfloor}",
  ["→"] = "\\ensuremath{\\rightarrow}", ["²"] = "\\textsuperscript{2}",
  ["～"] = "--",
}

-- Split plain text into Str and RawInline pieces for the symbols above.
local function symbols(text, out)
  local buf = {}
  for _, cp in utf8.codes(text) do
    local ch = utf8.char(cp)
    if sym[ch] then
      if #buf > 0 then table.insert(out, pandoc.Str(table.concat(buf))); buf = {} end
      table.insert(out, pandoc.RawInline("latex", sym[ch]))
    else
      table.insert(buf, ch)
    end
  end
  if #buf > 0 then table.insert(out, pandoc.Str(table.concat(buf))) end
end

function Str(el)
  local s = el.text
  if s:find("【待补", 1, true) then
    return pandoc.Span({el}, {style = "color:red"}) and
      pandoc.RawInline("latex", "\\textcolor{red}{\\textbf{" .. s .. "}}")
  end
  local out, i = {}, 1
  while true do
    local a, b, exp = s:find("%^(%d+)", i)
    if not a then break end
    if a > i then symbols(s:sub(i, a - 1), out) end
    table.insert(out, pandoc.Superscript({pandoc.Str(exp)}))
    i = b + 1
  end
  if i <= #s then symbols(s:sub(i), out) end
  return out
end

function Code(el)
  el.text = el.text:gsub("−", "-")
  return el
end

function CodeBlock(el)
  for i, c in ipairs(el.classes) do
    if c == "asm" then el.classes[i] = "gnuassembler" end
  end
  return el
end

-- Display width of a string: CJK characters count as two.
local function width(s)
  local n = 0
  for _, cp in utf8.codes(s) do n = n + ((cp >= 0x2E80) and 2 or 1) end
  return n
end

function Table(tbl)
  local ncol = #tbl.colspecs
  local maxw, tok = {}, {}
  for c = 1, ncol do maxw[c] = 7; tok[c] = 4 end
  local function scan(rows)
    for _, row in ipairs(rows) do
      for c, cell in ipairs(row.cells) do
        if c <= ncol then
          local text = pandoc.utils.stringify(cell.contents)
          maxw[c] = math.max(maxw[c], width(text))
          -- longest piece that cannot be broken across lines
          local spaced = text:gsub("，", " "):gsub("、", " "):gsub("；", " ")
          for word in spaced:gmatch("%S+") do
            local w = 0
            for _, cp in utf8.codes(word) do
              if cp >= 0x2E80 then w = 0 else w = w + 1; tok[c] = math.max(tok[c], w) end
            end
          end
        end
      end
    end
  end
  scan(tbl.head.rows)
  for _, body in ipairs(tbl.bodies) do scan(body.body) end
  -- start from a damped share of the content length ...
  local f, total = {}, 0
  for c = 1, ncol do f[c] = math.min(maxw[c], 60) ^ 0.75; total = total + f[c] end
  for c = 1, ncol do f[c] = f[c] / total end
  -- ... then make every column wide enough for its longest unbreakable piece
  local line = 82  -- about how many characters fit across the text width
  for _ = 1, 5 do
    local fixed, free = 0, 0
    for c = 1, ncol do
      local need = (tok[c] + 1) / line
      if f[c] <= need then f[c] = need; fixed = fixed + need else free = free + f[c] end
    end
    if free <= 0 then break end
    for c = 1, ncol do
      if f[c] > (tok[c] + 1) / line then f[c] = f[c] * (1 - fixed) / free end
    end
  end
  for c = 1, ncol do tbl.colspecs[c] = {tbl.colspecs[c][1], f[c]} end
  return tbl
end

-- Keep a "流程：" / "C 代码：" label on the same page as what follows it.
function Para(el)
  local t = pandoc.utils.stringify(el)
  if t == "流程：" or t == "C 代码：" then
    return {pandoc.RawBlock("latex", "\\needspace{10\\baselineskip}"), el}
  end
end

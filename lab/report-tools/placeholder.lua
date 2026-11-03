-- Missing screenshots become a dashed box naming the expected file;
-- 【待补…】 text is shown in red so unfinished spots stand out.
function Image(el)
  local f = io.open(el.src, "rb")
  if f then f:close(); return nil end
  return pandoc.Span({pandoc.Str("待补截图：" .. el.src)}, {class = "missing"})
end

function Str(el)
  if el.text:find("【待补", 1, true) then
    return pandoc.Span({el}, {class = "todo"})
  end
end

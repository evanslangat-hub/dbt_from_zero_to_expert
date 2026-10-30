function Header(el)
  if el.level == 1 then
    local text = pandoc.utils.stringify(el)
    if text:match("^PART ") then
      el.classes:insert("part")
    elseif text:match("^%d+%.") then
      el.classes:insert("chapter")
    elseif text:match("^How to Use") then
      el.classes:insert("frontmatter")
    end
  end
  return el
end

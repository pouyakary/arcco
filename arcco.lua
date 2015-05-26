#!/usr/bin/env lua

--
-- ┌───────────────────────────────────────────────────────────────────────┐
-- │      ___           ___           ___           ___           ___      │
-- │     /\  \         /\  \         /\  \         /\  \         /\  \     │
-- │    /::\  \       /::\  \       /::\  \       /::\  \       /::\  \    │
-- │   /:/\:\  \     /:/\:\  \     /:/\:\  \     /:/\:\  \     /:/\:\  \   │
-- │  /::\~\:\  \   /::\~\:\  \   /:/  \:\  \   /:/  \:\  \   /:/  \:\  \  │
-- │ /:/\:\ \:\__\ /:/\:\ \:\__\ /:/__/ \:\__\ /:/__/ \:\__\ /:/__/ \:\__\ │
-- │ \/__\:\/:/  / \/_|::\/:/  / \:\  \  \/__/ \:\  \  \/__/ \:\  \ /:/  / │
-- │      \::/  /     |:|::/  /   \:\  \        \:\  \        \:\  /:/  /  │
-- │      /:/  /      |:|\/__/     \:\  \        \:\  \        \:\/:/  /   │
-- │     /:/  /       |:|  |        \:\__\        \:\__\        \::/  /    │
-- │     \/__/         \|__|         \/__/         \/__/         \/__/     │
-- │                                                                       │
-- │                                                                       │
-- │ Arrco: The son of Locco and grandson of Docco.                        │
-- │ Copyright 2015 Pouya Kary <k@arendelle.org>, All rights reserved.     │
-- │                                                                       │
-- └───────────────────────────────────────────────────────────────────────┘
--


-- ### Setup & Helpers

-- Add script path to package path to find submodules.
local script_path = arg[0]:match('(.+)/.+')
package.path = table.concat({
  script_path..'/?.arendelle',
  package.path
}, ';')

-- Load markdown.lua.
local md = require 'markdown'
-- Load HTML templates.
local template = require 'template'

-- Ensure the `docs` directory exists and return the _path_ of the source file.<br>
-- Parameter:<br>
-- _source_: The source file for which documentation is generated.<br>
local function ensure_directory(source)
  local path = source:match('(.+)/.+$')
  if not path then path = '.' end
  os.execute('mkdir -p '..path..'/docs')
  return path
end

-- Insert HTML entities in a string.<br>
-- Parameter:<br>
-- _s_: String to escape.<br>
local function escape(s)
  s = s:gsub('&', '&amp;')
  s = s:gsub('<', '&lt;')
  s = s:gsub('>', '&gt;')
  s = s:gsub('%%','&#37;')
  return s
end


-- Wrap an item from a list of Lua keywords in a span template or return the
-- unchanged item.<br>
-- Parameters:<br>
-- _item_: An item of a code snippet.<br>
-- _item\_list_: List of keywords or functions.<br>
-- _span\_class_: Style sheet class.<br>
local function wrap_in_span(item, item_list, span_class)
  for i=1, #item_list do
    if item_list[i] == item then
      item = '<span class="'..span_class..'">'..item..'</span>'
      break
    end
  end
  return item
end


-- ### Main Documentation Generation Functions

-- Given a string of source code, parse out each comment and the code that
-- follows it, and create an individual section for it. Sections take the form:
--
--     {
--       docs_text = ...,
--       docs_html = ...,
--       code_text = ...,
--       code_html = ...,
--     }
--
-- Parameter:<br>
-- _source_: The source file to process.<br>
local function parse(source)
  local sections = {}
  local has_code = false
  local docs_text, code_text = '', ''
  for line in io.lines(source) do
    if line:match('^%s*//') then
      if has_code then
        code_text = code_text:gsub('\n\n$', '\n') -- remove empty trailing line
        sections[#sections + 1] = { ['docs_text'] = docs_text,
                                    ['code_text'] = code_text }
        has_code = false
        docs_text, code_text = '', ''
      end
      docs_text = docs_text..line:gsub('%s*(//%s?)', '', 1)..'\n'
    else
      if not line:match('^#!') then -- ignore #!/usr/bin/lua
        has_code = true
        code_text = code_text..line..'\n'
      end
    end
  end
  sections[#sections + 1] = { ['docs_text'] = docs_text,
                              ['code_text'] = code_text }
  return sections
end

-- Loop through a table of split sections and convert the documentation
-- from Markdown to HTML and pass the code through Locco's syntax
-- highlighting. Add  _docs\_html_ and _code\_html_ elements to the sections
-- table.<br>
-- Parameter:<br>
-- _sections_: A table with split sections.<br>
local function highlight(sections)
  for i=1, #sections do
    sections[i]['docs_html'] = md.markdown(escape(sections[i]['docs_text']))
    sections[i]['code_html'] = '<div class="highlight"><pre class="arendelle">'..escape(sections[i]['code_text'])..'</pre></div>'
  end
  return sections
end

-- After the highlighting is done, the template is filled with the documentation
-- and code snippets and an HTML file is written.<br>
-- Parameters:<br>
-- _source_: The source file.<br>
-- _path_: Path of the source file.<br>
-- _filename_: The filename of the source file.<br>
-- _sections_: A table with the original sections and rendered as HTML.<br>
-- _jump\_to_: A HTML chunk with links to other documentation files.
local function generate_html(source, path, filename, sections, jump_to)
  local f, err = io.open(path..'/'..'docs/'..filename:gsub('arendelle$', 'html'), 'wb')
  if err then print(err) end
  local h = template.header:gsub('%%title%%', source)
  h = h:gsub('%%jump%%', jump_to)
  f:write(h)
  for i=1, #sections do
    local t = template.table_entry:gsub('%%index%%', i..'')
    t = t:gsub('%%docs_html%%', sections[i]['docs_html'])
    t = t:gsub('%%code_html%%', sections[i]['code_html'])
    f:write(t)
  end
  f:write(template.footer)
  f:close()
end

-- Generate the documentation for a source file by reading it in,
-- splitting it up into comment/code sections, highlighting and merging
-- them into an HTML template.<br>
-- Parameters:<br>
-- _source_: The source file to process.<br>
-- _path_: Path of the source file.<br>
-- _filename_: The filename of the source file.<br>
-- _jump\_to_: A HTML chunk with links to other documentation files.
local function generate_documentation(source, path, filename, jump_to)
  local sections = parse(source)
  local sections = highlight(sections)
  generate_html(source, path, filename, sections, jump_to)
end


-- Run the script.

-- Generate HTML links to other files in the documentation.
local jump_to = ''
if #arg > 1 then
  jump_to = template.jump_start
  for i=1, #arg do
    local link = arg[i]:gsub('arendelle$', 'html')
    link = link:match('.+/(.+)$') or link
    local t = template.jump:gsub('%%jump_html%%', link)
    t = t:gsub('%%jump_arendelle%%', arg[i])
    jump_to = jump_to..t
  end
  jump_to = jump_to..template.jump_end
end

-- Make sure the output directory exists, generate the HTML files for each
-- source file, print what's happening and write the style sheet.
local path = ensure_directory(arg[1])
for i=1, #arg do
  local filename = arg[i]:match('.+/(.+)$') or arg[i]
  generate_documentation(arg[i], path, filename, jump_to)
  print(arg[i]..' --> '..path..'/docs/'..filename:gsub('arendelle$', 'html'))
end
local f, err = io.open(path..'/'..'docs/locco.css', 'wb')
if err then print(err) end
f:write(template.css)
f:close()

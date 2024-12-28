local M = {}

M._create_float_win = function(config, enter)
  if enter == nil then
    enter = false
  end
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, enter, config)
  return { buf = buf, win = win }
end

--- Default executor for lua code
---@param lua_code string[]: lines of lua code
local execute_lua_code = function(lua_code)
  -- Override the original print function to caputre output and place it in
  -- a pop-up window
  local original_print = print

  local output = {}

  -- the new print function
  print = function(...)
    local args = { ... }
    local messages = table.concat(vim.tbl_map(tostring, args), "\t")
    table.insert(output, messages)
  end

  -- call the provider function
  local chunk = loadstring(lua_code)
  pcall(function()
    if not chunk then
      table.insert(output, "Broken code")
    else
      chunk()
    end

    return output
  end)

  print = original_print
  return output
end

M.create_system_executor = function(program)
  return function(program_code)
    local tempfile = vim.fn.tempname()
    vim.fn.writefile(vim.split(program_code, '\n'), tempfile)
    local result = vim.system({ program, tempfile }, { text = true }):wait()
    return vim.split(result.stdout, "\n")
  end
end

local state = {
  parsed = {},
  current_slide = 1,
  floats = {},
}

local present_keymap = function(mode, key, callback)
  vim.keymap.set(mode, key, callback, {
    buffer = state.floats.body.buf,
  })
end

local options = {
  executors = {
    lua = execute_lua_code,
    javascript = M.create_system_executor('node'),
    python = M.create_system_executor('python'),
  }
}

M.setup = function(opts)
  opts = opts or {}
  opts.executors = opts.executors or {}

  opts.executors.lua = opts.executors.lua or execute_lua_code
  opts.executors.python = opts.executors.python or M.create_system_executor("python")
end

--- @class present.Slides
--- @fields slides present.Slide[]: slides of the file
---
--- @class present.Slide
--- @field title string: The title of the slide
--- @field body string[]: The body of the slide
--- @field blocks present.Block[]: A codeblock inside of a slide

--- @class present.Block
--- @field languale string: The language of the codeblock
--- @field body string: The body of the codeblock

--- Parse markdown
--- @param lines string[]: The lines in the buffer
--- @return present.Slides
local parse_slides = function(lines)
  local slides = { slides = {} }
  local separator = "^#"
  local current_slide = {
    title = "",
    body = {},
    blocks = {},
  }
  for _, line in ipairs(lines) do
    if line:find(separator) then
      if #current_slide.title > 0 then
        table.insert(slides.slides, current_slide)
      end
      current_slide = {
        title = line,
        body = {},
        blocks = {},
      }
    else
      table.insert(current_slide.body, line)
    end
  end
  table.insert(slides.slides, current_slide)

  for _, slide in ipairs(slides.slides) do
    local block = {
      language = nil,
      body = "",
    }
    local inside_block = false
    for _, line in ipairs(slide.body) do
      if vim.startswith(line, '```') then
        if not inside_block then
          inside_block = true
          block.language = string.sub(line, 4)
        else
          inside_block = false
          block.body = vim.trim(block.body)
          table.insert(slide.blocks, block)
          block = {
            language = nil,
            body = "",
          }
        end
        -- we are inside the markdown block just not at its fences
      else
        if inside_block then
          block.body = block.body .. line .. "\n"
        end
      end
    end
  end

  return slides
end

local foreach_float = function(cb)
  for name, float in pairs(state.floats) do
    cb(name, float)
  end
end

---@type vim.api.keyset.win_config[]
local create_windown_configuration = function()
  local width = vim.o.columns
  local height = vim.o.lines
  local header_height = 3
  local footer_height = 1
  local body_height = height - header_height - footer_height - 3

  return {
    background = {
      relative = "editor",
      width = width,
      height = height,
      style = 'minimal',
      border = 'none',
      row = 0,
      col = 0,
      zindex = 1,
    },
    header = {
      relative = "editor",
      width = width,
      height = 1,
      style = 'minimal',
      border = 'rounded',
      row = 0,
      col = 0,
      zindex = 2,
    },
    body = {
      relative = 'editor',
      height = body_height,
      width = width - 8,
      border = 'none',
      style = 'minimal',
      row = 6,
      col = 4,
      zindex = 2,
    },
    footer = {
      relative = 'editor',
      height = 1,
      width = width,
      style = 'minimal',
      row = height - 1,
      col = 0,
      zindex = 2,
    },
  }
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  state.parsed = parse_slides(lines)
  state.current_slide = 1
  state.filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.bufnr), ":t:r")

  local window = create_windown_configuration()

  -- foreach_float(function(name, _)
  --   state.floats[name] = CreateFloatingWindow(window[name])
  -- end)
  state.floats.background = M._create_float_win(window.background, false)
  state.floats.header = M._create_float_win(window.header, false)
  state.floats.footer = M._create_float_win(window.footer, false)
  state.floats.body = M._create_float_win(window.body, true)

  foreach_float(function(_, float)
    vim.bo[float.buf].filetype = "markdown"
  end)

  local set_slide_content = function(idx)
    local width = vim.o.columns
    local slide = state.parsed.slides[idx]
    local padding = string.rep(" ", (width - #slide.title) / 2)
    vim.api.nvim_buf_set_lines(state.floats.header.buf, 0, -1, false,
      { padding .. slide.title })
    vim.api.nvim_buf_set_lines(state.floats.body.buf, 0, -1, false, slide.body)
    local footer = string.format(
      " %d / %d | %s",
      state.current_slide,
      #state.parsed.slides,
      state.filename
    )
    vim.api.nvim_buf_set_lines(state.floats.footer.buf, 0, -1, false, { footer })
  end

  present_keymap("n", "n", function()
    state.current_slide = math.min(state.current_slide + 1, #state.parsed.slides)
    set_slide_content(state.current_slide)
  end)

  present_keymap("n", "N", function()
    state.current_slide = math.max(state.current_slide - 1, 1)
    set_slide_content(state.current_slide)
  end)

  present_keymap("n", "q", function()
    vim.api.nvim_win_close(state.floats.body.win, true)
  end)

  present_keymap("n", "<space>e", function()
    local slide = state.parsed.slides[state.current_slide]
    local block = slide.blocks[1]
    if not block then
      print("No code blocks on this page")
      return
    end

    local executor = options.executors[block.language]
    if not executor then
      print("No valid executor for this language")
      return
    end

    local output = { "# Code", "", '```' .. block.language }
    vim.list_extend(output, vim.split(block.body, '\n'))
    vim.list_extend(output, { '```' })

    table.insert(output, "")
    table.insert(output, "# Output")
    table.insert(output, "```")
    vim.list_extend(output, executor(block.body))
    table.insert(output, "```")

    local buf = vim.api.nvim_create_buf(false, true)
    local width_tmp = math.floor(vim.o.columns * 0.8)
    local height_tmp = math.floor(vim.o.lines * 0.8)
    vim.api.nvim_open_win(buf, true, {
      relative = "editor",
      style = "minimal",
      border = 'rounded',
      height = height_tmp,
      width = width_tmp,
      row = math.floor((vim.o.lines - height_tmp) / 2),
      col = math.floor((vim.o.columns - width_tmp) / 2),
      noautocmd = true,
    })

    vim.bo[buf].filetype = 'markdown'

    vim.api.nvim_buf_set_lines(buf, 0, -1, false, output)
  end)

  local restore = {
    cmdheight = {
      original = vim.o.cmdheight,
      present = 0,
    }
  }

  for option, config in pairs(restore) do
    vim.api.nvim_set_option_value(option, config.present, {})
  end

  vim.api.nvim_create_autocmd("BufLeave", {
    buffer = state.floats.body.buf,
    callback = function()
      for option, config in pairs(restore) do
        vim.api.nvim_set_option_value(option, config.original, {})
      end

      foreach_float(function(_, float)
        pcall(vim.api.nvim_win_close, float.win, true)
      end)
    end
  })

  vim.api.nvim_create_autocmd("VimResized", {
    group = vim.api.nvim_create_augroup("present-resize", {}),
    callback = function()
      if not vim.api.nvim_win_is_valid(state.floats.body.win)
          or state.floats.body.win == nil then
        return
      end
      local updated = create_windown_configuration()
      foreach_float(function(name, float)
        vim.api.nvim_win_set_config(float.win, updated[name])
      end)
      set_slide_content(state.current_slide)
    end
  })

  set_slide_content(state.current_slide)
end

-- M.start_presentation({ bufnr = 66 })

M._parse_slides = parse_slides

return M

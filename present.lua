local M = {}

function CreateFloatingWindow(config, enter)
  if enter == nil then
    enter = false
  end
  local buf = vim.api.nvim_create_buf(false, true)
  local win = vim.api.nvim_open_win(buf, enter, config)
  return { buf = buf, win = win }
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

M.setup = function()
  -- nothing
end

--- @class present.Slides
--- @fields slides present.Slide[]: slides of the file
---
--- @class present.Slide
--- @field title string: The title of the slide
--- @field body string[]: The body of the slide

--- Parse markdown
--- @param lines string[]: The lines in the buffer
--- @return present.Slides
local parse_slides = function(lines)
  local slides = { slides = {} }
  local separator = "^#"
  local current_slide = {
    title = "",
    body = {},
  }
  for _, line in ipairs(lines) do
    if line:find(separator) then
      if #current_slide.title > 0 then
        table.insert(slides.slides, current_slide)
      end
      current_slide = {
        title = line,
        body = {},
      }
    else
      table.insert(current_slide.body, line)
    end
  end
  table.insert(slides.slides, current_slide)

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
  local body_height = height - header_height - footer_height - 2

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
      width = width,
      border = { "#", "#", "#", "#", "#", "#", "#", "#" },
      style = 'minimal',
      row = 3,
      col = 0,
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
  state.filename = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(opts.bufnr), ":t")

  local window = create_windown_configuration()

  -- foreach_float(function(name, _)
  --   state.floats[name] = CreateFloatingWindow(window[name])
  -- end)
  state.floats.background = CreateFloatingWindow(window.background, false)
  state.floats.header = CreateFloatingWindow(window.header, false)
  state.floats.footer = CreateFloatingWindow(window.footer, false)
  state.floats.body = CreateFloatingWindow(window.body, true)

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

-- M.start_presentation({ bufnr = 4 })

return M

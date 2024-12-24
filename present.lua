local M = {}

function CreateFloatingWindow(opts)
  local buf = vim.api.nvim_create_buf(false, true)

  opts = opts or {}

  local width = opts.width or
      math.floor(vim.api.nvim_get_option_value("columns", {}) * 0.8)
  local height = opts.height or
      math.floor(vim.api.nvim_get_option_value("lines", {}) * 0.8)
  local x = math.floor((vim.api.nvim_get_option_value("columns", {}) - width) / 2)
  local y = math.floor((vim.api.nvim_get_option_value("lines", {}) - height) / 2)


  local win_config = {
    relative = "editor",
    width = width,
    height = height,
    col = x,
    row = y,
    style = "minimal",
    border = "rounded",
  }

  -- vim.cmd("below " .. y .. "left " .. x .. " resize " .. width .. " " .. height)
  -- vim.cmd("wincmd o")
  local win = vim.api.nvim_open_win(buf, true, win_config)

  return { buf = buf, win = win }
end

M.setup = function()
  -- nothing
end

--- @class present.Slides
--- @fields slides string[]: slides of the file

--- Parse markdown
--- @param lines string[]: The lines in the buffer
--- @return present.Slides
local parse_slides = function(lines)
  local slides = { slides = {} }
  local separator = "^#"
  local current_slide = {}
  for _, line in ipairs(lines) do
    print(line, "find: ", line:find(separator), "|")
    if line:find(separator) then
      if #current_slide > 0 then
        table.insert(slides.slides, current_slide)
      end
      current_slide = {}
    end
    table.insert(current_slide, line)
  end
  table.insert(slides.slides, current_slide)

  return slides
end

M.start_presentation = function(opts)
  opts = opts or {}
  opts.bufnr = opts.bufnr or 0
  local lines = vim.api.nvim_buf_get_lines(opts.bufnr, 0, -1, false)
  local parsed = parse_slides(lines)
  local float = CreateFloatingWindow()

  local current_slide = 1
  vim.keymap.set("n", "n", function()
    current_slide = math.min(current_slide + 1, #parsed.slides)
    vim.api.nvim_buf_set_lines(float.buf, 0, -1, false,
      parsed.slides[current_slide])
  end, {
    buffer = float.buf
  })

  vim.keymap.set("n", "p", function()
    current_slide = math.max(current_slide - 1, 1)
    vim.api.nvim_buf_set_lines(float.buf, 0, -1, false,
      parsed.slides[current_slide])
  end, {
    buffer = float.buf
  })

  vim.keymap.set("n", "q", function()
      vim.api.nvim_win_close(float.win, true)
    end,
    { buffer = float.buf })

  vim.api.nvim_buf_set_lines(float.buf, 0, -1, false, parsed.slides[1])
end

M.start_presentation({ bufnr = 13 })

return M

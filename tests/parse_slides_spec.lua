local parse = require("present")._parse_slides
local eq = assert.are.same
describe("present.parse_slides", function()
  it("should parse an empty file", function()
    assert.are.same({
      slides = {
        {
          title = '',
          body = {},
          blocks = {},
        },
      },
    }, parse {})
  end)

  it("should parse a file with one slide", function()
    assert.are.same({
      slides = {
        {
          title = '# Slide title',
          body = { " slide content" },
          blocks = {},
        },
      },
    }, parse { "# Slide title", " slide content" })
  end)

  it("should parse a file with one slide, and one block", function()
    local results = parse {
      "# Slide title",
      " slide content",
      "```lua",
      "print(hi)",
      "```",
    }
    eq(1, #results.slides)
    local slide = results.slides[1]
    eq('# Slide title', slide.title)
    eq({
      " slide content",
      "```lua",
      "print(hi)",
      "```", }, slide.body)

    local block = {
      language = "lua",
      body = "print(hi)"
    }
    eq(block, slide.blocks[1])
  end)
end)

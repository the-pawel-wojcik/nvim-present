local parse = require("present")._parse_slides
describe("present.parse_slides", function()
  it("should parse an empty file", function()
    assert.are.same({
      slides = {
        {
          title = '',
          body = {},
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
        },
      },
    }, parse { "# Slide title", " slide content" })
  end)
end)

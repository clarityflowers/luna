local result = {}

result.BAR_HEIGHT = 3
result.NOTE_FONT_SIZE = 20
result.SMALL_NOTE_FONT_SIZE = 15
result.FONT_SIZE = 10

local function calculateOffset(size)
  return -size * 2 - 0.5
end

result.NOTE_OFFSET = calculateOffset(result.NOTE_FONT_SIZE)
result.SMALL_NOTE_OFFSET = calculateOffset(result.SMALL_NOTE_FONT_SIZE)

result.NOTE_HEAD_BLACK = "";
result.NOTE_HEAD_HALF = "";
result.NOTE_QUARTER_UP = "";
result.NOTE_QUARTER_DOWN = "";
result.NOTE_HALF_UP = ""
result.STAFF = ""
result.G_CLEFF = ""
result.F_CLEFF = ""
result.ACCIDENTAL_DOUBLE_FLAT = ""
result.ACCIDENTAL_FLAT = ""
result.ACCIDENTAL_NATURAL = ""
result.ACCIDENTAL_SHARP = ""
result.ACCIDENTAL_DOUBLE_SHARP = ""
result.QUARTER_REST = ""

result.ACCIDENTALS = {
  [-2] = "accidental double flat",
  [-1] = "accidental flat",
  [0] = "accidental natural",
  [1] = "accidental sharp",
  [2] = "accidental double sharp",
}

result.SYMBOLS = {
  ["note head black"] = result.NOTE_HEAD_BLACK,
  ["note head half"] = result.NOTE_HEAD_HALF,
  ["note quarter up"] = result.NOTE_QUARTER_UP,
  ["note quarter down"] = result.NOTE_QUARTER_DOWN,
  ["note half up"] = result.NOTE_HALF_UP,
  ["staff"] = result.STAFF,
  ["g cleff"] = result.G_CLEFF,
  ["f cleff"] = result.F_CLEFF,
  ["accidental double flat"] = result.ACCIDENTAL_DOUBLE_FLAT,
  ["accidental flat"] = result.ACCIDENTAL_FLAT,
  ["accidental natural"] = result.ACCIDENTAL_NATURAL,
  ["accidental sharp"] = result.ACCIDENTAL_SHARP,
  ["accidental double sharp"] = result.ACCIDENTAL_DOUBLE_SHARP,
  ["quarter rest"] = result.QUARTER_REST,
}

result.note_font = love.graphics.newFont("Bravura.otf", result.NOTE_FONT_SIZE)
result.small_note_font = love.graphics.newFont("Bravura.otf", result.SMALL_NOTE_FONT_SIZE)
result.text_font = love.graphics.newFont("leaguespartan-bold.ttf", result.FONT_SIZE)
result.mono_font = love.graphics.newFont("Courier.dfont", result.FONT_SIZE)

return result
do ->
  assert = (val, msg) ->
    unless val
      throw new Error msg ? val
    return val

  class Point
    constructor: (@x, @y) ->
  class BlockType
    constructor: (@n) ->
  class BlockTypes
    constructor: (n) ->
      @types = (new BlockType(i) for i in [0...n])
    rand: ->
      index = Math.floor @types.length * Math.random()
      ret = @types[index]
      assert ret?, 'rand is broken: '+index
      return ret
  class Grid
    constructor: (@width, @height) ->
      @blocks = {}
      @broker = $({})
    add: (pt, block) ->
      @blocks[pt] = block
      @broker.trigger 'add',
        pt: pt
        block: block
    remove: (pt) ->
      delete @blocks[pt]
      @broker.trigger 'remove',
        pt: pt
  class Field
    constructor: (@grid, @types, @cursor) ->
    init: ->
      h = Math.floor @grid.height/2
      w = @grid.width
      for y in [0...h] then do (y) =>
        for x in [0...w] then do (x) =>
          pt = new Point x, y
          @grid.add pt, @types.rand()
      console.log 'hello'

  class View
    constructor: (@field) ->
      grid = $('<div class="grid">')
      grid.css
        width:@field.grid.width*32
        height:@field.grid.height*32
      grid.appendTo('#game')

      @field.grid.broker.bind
        add: (e, args) =>
          block = $('<div class="block block-'+args.block.n+'">')
          # y=0 is the top in html, but we want it to be the bottom
          y = (@field.grid.height - args.pt.y - 1) * 32
          block.css
            left:args.pt.x*32
            top:y
            width:30
            height:30
          block.appendTo('.grid')

  tryCatch = (fn) ->
    try
      fn()
    catch e
      console.error e
      throw e

  onStart = ->
    $('#intro').fadeOut()
    $('#game').fadeIn()
    types = new BlockTypes 5
    grid = new Grid 6, 15
    field = new Field grid, types
    view = new View field

    field.init()

  onLoad = ->
    $('#loading').fadeOut()
    $('#intro').fadeIn()
    setTimeout tryCatch(onStart), 1
    #setTimeout onStart, 1
    #onStart()
    #$(document).click onStart

  jQuery onLoad

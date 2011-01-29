do ->
  assert = (val, msg) ->
    unless val
      throw new Error msg ? val
    return val

  class Point
    constructor: (@x, @y) ->
    clone: -> new Point @x, @y
    add: (dx, dy) ->
      @x += dx
      @y += dy
      return this
    # TODO why isn't this working
    toString: -> JSON.stringify {x:@x,y:@y}
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
      @blocks[pt.toString()] = block
      @broker.trigger 'add',
        pt: pt
        block: block
    remove: (pt) ->
      delete @blocks[pt.toString()]
      @broker.trigger 'remove',
        pt: pt
    swap: (pt1, pt2) ->
      tmp = @blocks[pt1.toString()]
      @blocks[pt1.toString()] = @blocks[pt2.toString()]
      @blocks[pt2.toString()] = tmp
      @broker.trigger 'swap',
        pt1:pt1
        pt2:pt2
  class Cursor
    constructor: (@grid, @pt) ->
      @broker = $({})
    move: (dx, dy) ->
      @pt.x += dx
      @pt.y += dy
      @broker.trigger 'move', {dx:dx, dy:dy}
    bind: (input) ->
      input.bind
        left: => @move -1, 0
        right: => @move 1, 0
        up: => @move 0, 1
        down: => @move 0, -1
        swap: => @grid.swap @pt, @pt.clone().add(1,0)
  class Field
    constructor: (@grid, @types, @cursor) ->
    init: ->
      h = Math.floor @grid.height/2
      w = @grid.width
      for y in [0...h] then do (y) =>
        for x in [0...w] then do (x) =>
          pt = new Point x, y
          @grid.add pt, @types.rand()

  class View
    x: (x) -> 32 * x
    # y=0 is the top in html, but we want it to be the bottom
    y: (y) -> 32 * (@field.grid.height - 1 - y)
    sq: (v=1) -> 32 * v
    constructor: (@field) ->
      grid = $('<div class="grid">')
      grid.css
        width:@sq @field.grid.width
        height:@sq @field.grid.height
      grid.appendTo('#game')

      cursor = $('<div class="cursor">')
      cursor.css
        left:@x @field.cursor.pt.x
        top:@y @field.cursor.pt.y
        width:@sq()-1
        height:@sq()-1
      cursor.appendTo('.grid')

      @field.cursor.broker.bind
        move: (e, args) =>
          props =
            left:@x @field.cursor.pt.x
            top:@y @field.cursor.pt.y
          cursor.animate props, 50
      blocks = {}
      updateBlock = (b, pt) =>
        props =
          left:@x pt.x
          top:@y pt.y
        b.animate props, 50
      @field.grid.broker.bind
        add: (e, args) =>
          block = $('<div class="block block-'+args.block.n+'">')
          block.css
            width:@sq()-2
            height:@sq()-2
          updateBlock block, args.pt
          # TODO use ids instead? this is error-prone
          blocks[args.pt.toString()] = block
          block.appendTo('.grid')
        swap: (e, args) =>
          b1 = blocks[args.pt1.toString()]
          b2 = blocks[args.pt2.toString()]
          blocks[args.pt1.toString()] = b2
          blocks[args.pt2.toString()] = b1
          if b2?
            updateBlock b2, args.pt1
          if b1?
            updateBlock b1, args.pt2

  tryCatch = (fn) ->
    try
      fn()
    catch e
      console.error e
      throw e

  class Input
    constructor: ->
      @broker = $({})
      @inputBindings =
        32: 'swap' #spacebar
        37: 'left' #arrows
        38: 'up'
        39: 'right'
        40: 'down'
    bind: (win) ->
      win.keydown (e) =>
        event = @inputBindings[e.which]
        if event?
          @broker.trigger event

  onStart = ->
    $('#intro').fadeOut()
    $('#game').fadeIn()
    types = new BlockTypes 5
    grid = new Grid 6, 15
    cursor = new Cursor grid, new Point 2,3
    field = new Field grid, types, cursor
    view = new View field

    input = new Input()
    input.bind $(window)
    cursor.bind input.broker
    field.init()

  onLoad = ->
    $('#loading').fadeOut()
    $('#intro').fadeIn()
    setTimeout (=>tryCatch onStart), 1
    #setTimeout onStart, 1
    #onStart()
    #$(document).click onStart

  jQuery onLoad

do ->
  assert = (val, msg) ->
    unless val
      throw new Error msg ? val
    return val

  bound = (val, min, max) ->
    return Math.min max, Math.max min, val

  class Schedule
    constructor: ->
      @t = 0
      @schedule = {}
      @broker = $({})
    at: (t, fn) ->
      @schedule[t] ?= []
      @schedule[t].push fn
    delay: (t, fn) ->
      @at(t + @t, fn)
    interval: (t, fn) ->
      recurse = =>
        fn @t
        @delay t, recurse
      @delay t, recurse
    tick: ->
      @t += 1
      for fn in @schedule[@t] ? []
        fn @t
      @broker.trigger 'tick', @t

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
      cleared = @calcMatches [pt]
      @broker.trigger 'add',
        pt: pt
        block: block
      @clearMatches [pt], cleared
    remove: (pt) ->
      delete @blocks[pt.toString()]
      @broker.trigger 'remove',
        pt: pt
    findMatchingLine: (start, dx, dy, min=0, max=15) ->
      expected = @blocks[start.toString()]

      pt = start.clone()
      actual = expected
      matchesUp = []
      while actual == expected and min <= pt.x <= max and min <= pt.y <= max
        matchesUp.push pt.clone()
        pt.add dx, dy
        actual = @blocks[pt.toString()]

      pt = start.clone()
      actual = expected
      matchesDown = []
      while actual == expected and min <= pt.x <= max and min <= pt.y <= max
        matchesDown.push pt.clone()
        pt.add -dx, -dy
        actual = @blocks[pt.toString()]

      matchesDown.shift()
      matches = matchesUp.concat(matchesDown)
      return matches
    findMatches: (pt) ->
      horiz = unless @blocks[pt.toString()] then [] else @findMatchingLine pt, 1, 0
      vert = unless @blocks[pt.toString()] then [] else @findMatchingLine pt, 0, 1
      clear = []
      if horiz.length >= 3
        clear = clear.concat horiz
      if vert.length >= 3
        clear.shift() #hack to remove the duplicate at the beginning
        clear = clear.concat vert
      return clear

    fall: (pt) ->
      # any space to fall?
      if @blocks[pt.toString()]
        return
      empties = @findMatchingLine(pt, 0, 1)
      #assert empties.length > 0, 'no empties?'
      # TODO debug the above
      if empties.length == 0
        return
      empties.sort (a,b) -> a.y - b.y
      fallTo = empties[0]
      fallFrom = empties[empties.length-1].clone().add(0,1)
      #while @blocks[fallFrom.toString()]
      while @blocks[fallFrom.toString()] and not @blocks[fallTo.toString()]
        #assert not @blocks[fallTo.toString()], 'fallTo is full'
        # TODO debug that
        @swap fallTo, fallFrom, false
        fallTo.add(0,1)
        fallFrom.add(0,1)

    calcMatches: (pts) ->
      cleared = []
      for pt in pts
        cleared = cleared.concat @findMatches pt
      return cleared
    clearMatches: (pts, cleared) ->
      for pt in cleared
        @remove pt
      for pt in pts.concat(cleared)
        @fall pt
        # TODO overkill
        @fall pt.clone().add(0,-1)

    swap: (pt1, pt2, cursor=true) ->
      tmp = @blocks[pt1.toString()]
      @blocks[pt1.toString()] = @blocks[pt2.toString()]
      @blocks[pt2.toString()] = tmp
      cleared = @calcMatches [pt1, pt2]
      @broker.trigger 'swap',
        pt1:pt1
        pt2:pt2
        cleared:cleared
      @clearMatches [pt1, pt2], cleared

  class Cursor
    constructor: (@grid, @pt) ->
      @broker = $({})
    move: (dx, dy) ->
      @pt.x = bound @pt.x + dx, 0, @grid.width-2
      @pt.y = bound @pt.y + dy, 0, @grid.height-1
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
      @schedule = new Schedule()
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

      # TODO combine these
      cursor1 = $('<div class="cursor">')
      cursor1.css
        left:@x @field.cursor.pt.x
        top:@y @field.cursor.pt.y
        width:@sq()-1
        height:@sq()-1
      cursor1.appendTo('.grid')
      cursor2 = $('<div class="cursor">')
      cursor2.css
        left:@x @field.cursor.pt.x+1
        top:@y @field.cursor.pt.y
        width:@sq()-1
        height:@sq()-1
      cursor2.appendTo('.grid')

      @field.cursor.broker.bind
        move: (e, args) =>
          props =
            left:@x @field.cursor.pt.x
            top:@y @field.cursor.pt.y
          cursor1.animate props, 50
          props =
            left: @x @field.cursor.pt.x+1
            top:@y @field.cursor.pt.y
          cursor2.animate props, 50
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
        remove: (e, args) =>
          block = blocks[args.pt.toString()]
          block.fadeOut null, ->
            $(block).remove()
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
      @inputBindings['Z'.charCodeAt(0)] = 'swap'
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
    setInterval (=>tryCatch =>field.schedule.tick()), 33
    field.schedule.broker.bind
      tick: ->

  onLoad = ->
    $('#loading').fadeOut()
    $('#intro').fadeIn()
    setTimeout (=>tryCatch onStart), 1
    #setTimeout onStart, 1
    #onStart()
    #$(document).click onStart

  jQuery onLoad

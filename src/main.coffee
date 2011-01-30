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
    constructor: (@width, @height, @types) ->
      @blocks = {}
      @broker = $({})
      @started = false
    add: (pt, block,clear=true) ->
      @blocks[pt.toString()] = block
      if clear
        cleared = @calcMatches [pt]
      @broker.trigger 'add',
        pt: pt
        block: block
      if clear
        @clearMatches [pt], cleared
    countTypes: ->
      counts = {}
      for t in @types.types
        counts[t.n] =
          count: 0
          type: t
      for p,b of @blocks
        if b? #TODO this shouldn't be possible!
          assert counts[b.n]?, b.n
          counts[b.n].count += 1
      return (v for k,v of counts)
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

    causeExtinction: ->
      # Don't trigger extinction during the intial scrolling/setup, or
      # after we've already won
      if (not @started) or @clear
        return
      # which types are extinct?
      counts = @countTypes()
      zeros = _.filter counts, (c) -> c.count == 0
      zeros = _.pluck zeros, 'type'
      @types.types = _.without @types.types, zeros...
      for type in zeros
        console.log 'extinct',type
        @broker.trigger 'extinct', type
      if @types.types.length == 1
        console.log 'stageclear'
        @clear = true
        @broker.trigger 'stage'

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
      @causeExtinction()

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

    scroll: ->
      console.log 'scroll-fn'
      xs = [0...@width]
      ys = [0...@height-1]
      ys.reverse()
      # any blocks in the top row? gameover
      pts = (new Point(x, @height-1) for x in xs)
      bs = _.filter (@blocks[p.toString()] for p in pts),
        (b) -> b?
      if bs.length > 0
        @broker.trigger 'gameover'
        return
      # Move existing blocks
      for y in ys
        for x in xs
          pt = new Point(x,y)
          up = new Point(x,y+1)
          b = @blocks[pt.toString()]
          if b?
            @remove pt
            @add up, b, false
          #  moved.push pt
          #  newblocks[up.toString()] = b
      # insert new blocks. TODO use next-row
      for x in xs
        @add new Point(x, 0), @types.rand()
      # TODO next-row

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
        scroll: => @grid.scroll()

  class Field
    constructor: (@grid, @cursor) ->
      @schedule = new Schedule()
    init: ->
      h = Math.floor @grid.height/2
      for y in [0...h] then do (y) =>
        @grid.scroll()
      @grid.started = true

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
            left:@x args.pt.x
            top:@y args.pt.y
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
        13: 'scroll' #enter
        32: 'swap' #spacebar
        37: 'left' #arrows
        38: 'up'
        39: 'right'
        40: 'down'
      @inputBindings['Z'.charCodeAt(0)] = 'swap'
    bind: (win) ->
      win.bind 'keydown.input', (e) =>
        event = @inputBindings[e.which]
        if event?
          @broker.trigger event
    unbind: (win) ->
      win.unbind 'keydown.input'

  class SFX
    constructor: ->
      @played = {}
      @playingTotal = 0
    load: (id) ->
      assert $('audio.'+id)[0], 'audio.'+id
    now: -> new Date().getTime()
    play: (id) ->
      console.log 'sfx.'+id
      now = @now()
      src = @load id
      # don't spam the same sound
      diff = now - (@played[src.src] ? 0)
      if diff < 250
        return
      @played[src.src] = now
      console.log src.src
      # TODO re-enable sfx when it stops crashing
      #a = new Audio src.src
      #a.play()

    bind: (input) ->
      assert input?
      input.bind
        gameover: =>@play 'gameover'
        move: =>@play 'move'
        clear: =>@play 'clear'
        swap: =>@play 'swap'
        stage: =>@play 'stage'
        drop: =>@play 'drop'
        scroll: =>@play 'scroll'
      return this

  gameover = ->
    console.log 'gameover-fn'
    $('#gameover').fadeIn(500)

  stage = ->
    console.log 'STAGE CLEAR'
    $('#stageclear').fadeIn().delay(500).fadeOut()
    $('#game').fadeOut null, -> $(this).empty()
    setTimeout (->onStart()), 1000

  onStart = ->
    $('#intro').fadeOut()
    $('#game').fadeIn()
    types = new BlockTypes 5
    grid = new Grid 6, 15, types
    cursor = new Cursor grid, new Point 2,3
    field = new Field grid, cursor
    view = new View field
    sfx = new SFX()

    input = new Input()
    input.bind $(window)
    cursor.bind input.broker
    field.init()
    sfx.bind(grid.broker).bind(cursor.broker)
    #sfx.play 'scroll'
    timer = setInterval (=>tryCatch =>field.schedule.tick()), 33
    #field.schedule.broker.bind
    #  tick: ->
    grid.broker.bind
      gameover: ->
        clearInterval timer
        input.unbind $(window)
        gameover()
      stage: ->
        clearInterval timer
        input.unbind $(window)
        stage()
      extinct: (e, type) ->
        console.log 'extinct',JSON.stringify type
        cls = 'extinct-'+type.n
        $('#extinct').addClass(cls).fadeIn().delay(500).fadeOut null, -> $(this).removeClass cls
        console.log 'done',JSON.stringify type

  onLoad = ->
    $('#loading').fadeOut()
    $('#intro').fadeIn()
    setTimeout (=>tryCatch onStart), 1
    #setTimeout onStart, 1
    #onStart()
    #$(document).click onStart

  jQuery onLoad

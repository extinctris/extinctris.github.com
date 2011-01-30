(function() {
  var __bind = function(fn, me){ return function(){ return fn.apply(me, arguments); }; }, __slice = Array.prototype.slice;
  (function() {
    var BlockType, BlockTypes, Cursor, Field, Grid, Input, Point, SFX, Schedule, View, assert, bound, gameover, onLoad, onStart, stage, tryCatch, updateExtinctions, updateStats;
    assert = function(val, msg) {
      if (!val) {
        throw new Error(msg != null ? msg : val);
      }
      return val;
    };
    bound = function(val, min, max) {
      return Math.min(max, Math.max(min, val));
    };
    Schedule = (function() {
      function Schedule() {
        this.t = 0;
        this.schedule = {};
        this.broker = $({});
      }
      Schedule.prototype.at = function(t, fn) {
        var _base, _ref;
        (_ref = (_base = this.schedule)[t]) != null ? _ref : _base[t] = [];
        return this.schedule[t].push(fn);
      };
      Schedule.prototype.delay = function(t, fn) {
        return this.at(t + this.t, fn);
      };
      Schedule.prototype.interval = function(t, fn) {
        var recurse;
        recurse = __bind(function() {
          fn(this.t);
          return this.delay(t, recurse);
        }, this);
        return this.delay(t, recurse);
      };
      Schedule.prototype.tick = function() {
        var fn, _i, _len, _ref, _ref2;
        this.t += 1;
        _ref2 = (_ref = this.schedule[this.t]) != null ? _ref : [];
        for (_i = 0, _len = _ref2.length; _i < _len; _i++) {
          fn = _ref2[_i];
          fn(this.t);
        }
        return this.broker.trigger('tick', this.t);
      };
      return Schedule;
    })();
    Point = (function() {
      function Point(x, y) {
        this.x = x;
        this.y = y;
      }
      Point.prototype.clone = function() {
        return new Point(this.x, this.y);
      };
      Point.prototype.add = function(dx, dy) {
        this.x += dx;
        this.y += dy;
        return this;
      };
      Point.prototype.toString = function() {
        return JSON.stringify({
          x: this.x,
          y: this.y
        });
      };
      return Point;
    })();
    BlockType = (function() {
      function BlockType(n) {
        this.n = n;
      }
      return BlockType;
    })();
    BlockTypes = (function() {
      function BlockTypes(n, stageClearAt) {
        var i;
        this.stageClearAt = stageClearAt;
        this.types = (function() {
          var _results;
          _results = [];
          for (i = 0; (0 <= n ? i < n : i > n); (0 <= n ? i += 1 : i -= 1)) {
            _results.push(new BlockType(i));
          }
          return _results;
        })();
      }
      BlockTypes.prototype.rand = function() {
        var index, ret;
        index = Math.floor(this.types.length * Math.random());
        ret = this.types[index];
        assert(ret != null, 'rand is broken: ' + index);
        return ret;
      };
      return BlockTypes;
    })();
    Grid = (function() {
      function Grid(width, height, types) {
        this.width = width;
        this.height = height;
        this.types = types;
        this.blocks = {};
        this.broker = $({});
        this.started = false;
      }
      Grid.prototype.add = function(pt, block, clear) {
        var cleared;
        if (clear == null) {
          clear = true;
        }
        this.blocks[pt.toString()] = block;
        if (clear) {
          cleared = this.calcMatches([pt]);
        }
        this.broker.trigger('add', {
          pt: pt,
          block: block
        });
        if (clear) {
          return this.clearMatches([pt], cleared);
        }
      };
      Grid.prototype.countTypes = function() {
        var b, counts, k, p, t, v, _i, _len, _ref, _ref2, _results;
        counts = {};
        _ref = this.types.types;
        for (_i = 0, _len = _ref.length; _i < _len; _i++) {
          t = _ref[_i];
          counts[t.n] = {
            count: 0,
            type: t
          };
        }
        _ref2 = this.blocks;
        for (p in _ref2) {
          b = _ref2[p];
          if (b != null) {
            assert(counts[b.n] != null, b.n);
            counts[b.n].count += 1;
          }
        }
        _results = [];
        for (k in counts) {
          v = counts[k];
          _results.push(v);
        }
        return _results;
      };
      Grid.prototype.remove = function(pt) {
        delete this.blocks[pt.toString()];
        return this.broker.trigger('remove', {
          pt: pt
        });
      };
      Grid.prototype.findMatchingLine = function(start, dx, dy, min, max) {
        var actual, expected, matches, matchesDown, matchesUp, pt, _ref, _ref2, _ref3, _ref4;
        if (min == null) {
          min = 0;
        }
        if (max == null) {
          max = 15;
        }
        expected = this.blocks[start.toString()];
        pt = start.clone();
        actual = expected;
        matchesUp = [];
        while (actual === expected && (min <= (_ref = pt.x) && _ref <= max) && (min <= (_ref2 = pt.y) && _ref2 <= max)) {
          matchesUp.push(pt.clone());
          pt.add(dx, dy);
          actual = this.blocks[pt.toString()];
        }
        pt = start.clone();
        actual = expected;
        matchesDown = [];
        while (actual === expected && (min <= (_ref3 = pt.x) && _ref3 <= max) && (min <= (_ref4 = pt.y) && _ref4 <= max)) {
          matchesDown.push(pt.clone());
          pt.add(-dx, -dy);
          actual = this.blocks[pt.toString()];
        }
        matchesDown.shift();
        matches = matchesUp.concat(matchesDown);
        return matches;
      };
      Grid.prototype.findMatches = function(pt) {
        var clear, horiz, vert;
        horiz = !this.blocks[pt.toString()] ? [] : this.findMatchingLine(pt, 1, 0);
        vert = !this.blocks[pt.toString()] ? [] : this.findMatchingLine(pt, 0, 1);
        clear = [];
        if (horiz.length >= 3) {
          clear = clear.concat(horiz);
        }
        if (vert.length >= 3) {
          clear.shift();
          clear = clear.concat(vert);
        }
        return clear;
      };
      Grid.prototype.fall = function(pt) {
        var empties, fallFrom, fallTo, _results;
        if (this.blocks[pt.toString()]) {
          return;
        }
        empties = this.findMatchingLine(pt, 0, 1);
        if (empties.length === 0) {
          return;
        }
        empties.sort(function(a, b) {
          return a.y - b.y;
        });
        fallTo = empties[0];
        fallFrom = empties[empties.length - 1].clone().add(0, 1);
        _results = [];
        while (this.blocks[fallFrom.toString()] && !this.blocks[fallTo.toString()]) {
          this.swap(fallTo, fallFrom, false);
          fallTo.add(0, 1);
          _results.push(fallFrom.add(0, 1));
        }
        return _results;
      };
      Grid.prototype.causeExtinction = function() {
        var counts, type, zeros, _i, _len;
        if ((!this.started) || this.clear) {
          return;
        }
        counts = this.countTypes();
        zeros = _.filter(counts, function(c) {
          return c.count === 0;
        });
        zeros = _.pluck(zeros, 'type');
        this.types.types = _.without.apply(_, [this.types.types].concat(__slice.call(zeros)));
        for (_i = 0, _len = zeros.length; _i < _len; _i++) {
          type = zeros[_i];
          this.broker.trigger('extinct', type);
        }
        if (this.types.types.length <= this.types.stageClearAt) {
          this.clear = true;
          return this.broker.trigger('stage');
        }
      };
      Grid.prototype.calcMatches = function(pts) {
        var cleared, pt, _i, _len;
        cleared = [];
        for (_i = 0, _len = pts.length; _i < _len; _i++) {
          pt = pts[_i];
          cleared = cleared.concat(this.findMatches(pt));
        }
        return cleared;
      };
      Grid.prototype.clearMatches = function(pts, cleared) {
        var pt, _i, _j, _len, _len2, _ref;
        for (_i = 0, _len = cleared.length; _i < _len; _i++) {
          pt = cleared[_i];
          this.remove(pt);
        }
        _ref = pts.concat(cleared);
        for (_j = 0, _len2 = _ref.length; _j < _len2; _j++) {
          pt = _ref[_j];
          this.fall(pt);
          this.fall(pt.clone().add(0, -1));
        }
        if (cleared.length > 0) {
          this.broker.trigger('clear');
          return this.causeExtinction();
        }
      };
      Grid.prototype.swap = function(pt1, pt2, cursor) {
        var cleared, tmp;
        if (cursor == null) {
          cursor = true;
        }
        tmp = this.blocks[pt1.toString()];
        this.blocks[pt1.toString()] = this.blocks[pt2.toString()];
        this.blocks[pt2.toString()] = tmp;
        cleared = this.calcMatches([pt1, pt2]);
        this.broker.trigger('swap', {
          pt1: pt1,
          pt2: pt2,
          cleared: cleared
        });
        return this.clearMatches([pt1, pt2], cleared);
      };
      Grid.prototype.scroll = function() {
        var b, bs, p, pt, pts, up, x, xs, y, ys, _i, _j, _k, _l, _len, _len2, _len3, _m, _ref, _ref2, _results, _results2, _results3;
        xs = (function() {
          _results = [];
          for (var _i = 0, _ref = this.width; 0 <= _ref ? _i < _ref : _i > _ref; 0 <= _ref ? _i += 1 : _i -= 1){ _results.push(_i); }
          return _results;
        }).call(this);
        ys = (function() {
          _results2 = [];
          for (var _j = 0, _ref2 = this.height - 1; 0 <= _ref2 ? _j < _ref2 : _j > _ref2; 0 <= _ref2 ? _j += 1 : _j -= 1){ _results2.push(_j); }
          return _results2;
        }).call(this);
        ys.reverse();
        pts = (function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = xs.length; _i < _len; _i++) {
            x = xs[_i];
            _results.push(new Point(x, this.height - 1));
          }
          return _results;
        }).call(this);
        bs = _.filter((function() {
          var _i, _len, _results;
          _results = [];
          for (_i = 0, _len = pts.length; _i < _len; _i++) {
            p = pts[_i];
            _results.push(this.blocks[p.toString()]);
          }
          return _results;
        }).call(this), function(b) {
          return b != null;
        });
        this.broker.trigger('scroll');
        if (bs.length > 0) {
          this.broker.trigger('gameover');
          return;
        }
        for (_k = 0, _len = ys.length; _k < _len; _k++) {
          y = ys[_k];
          for (_l = 0, _len2 = xs.length; _l < _len2; _l++) {
            x = xs[_l];
            pt = new Point(x, y);
            up = new Point(x, y + 1);
            b = this.blocks[pt.toString()];
            if (b != null) {
              this.remove(pt);
              this.add(up, b, false);
            }
          }
        }
        _results3 = [];
        for (_m = 0, _len3 = xs.length; _m < _len3; _m++) {
          x = xs[_m];
          _results3.push(this.add(new Point(x, 0), this.types.rand()));
        }
        return _results3;
      };
      return Grid;
    })();
    Cursor = (function() {
      function Cursor(grid, pt) {
        this.grid = grid;
        this.pt = pt;
        this.broker = $({});
        this.grid.broker.bind({
          scroll: __bind(function() {
            return this.move(0, 1, false);
          }, this)
        });
      }
      Cursor.prototype.move = function(dx, dy, input) {
        if (input == null) {
          input = true;
        }
        this.pt.x = bound(this.pt.x + dx, 0, this.grid.width - 2);
        this.pt.y = bound(this.pt.y + dy, 0, this.grid.height - 1);
        return this.broker.trigger('move', {
          dx: dx,
          dy: dy,
          input: input
        });
      };
      Cursor.prototype.bind = function(input) {
        return input.bind({
          left: __bind(function() {
            return this.move(-1, 0);
          }, this),
          right: __bind(function() {
            return this.move(1, 0);
          }, this),
          up: __bind(function() {
            return this.move(0, 1);
          }, this),
          down: __bind(function() {
            return this.move(0, -1);
          }, this),
          swap: __bind(function() {
            return this.grid.swap(this.pt, this.pt.clone().add(1, 0));
          }, this),
          scroll: __bind(function() {
            return this.grid.scroll();
          }, this)
        });
      };
      return Cursor;
    })();
    Field = (function() {
      function Field(grid, cursor, config) {
        this.grid = grid;
        this.cursor = cursor;
        this.config = config;
        this.schedule = new Schedule();
      }
      Field.prototype.init = function() {
        var h, y, _fn;
        h = Math.floor(this.grid.height / 2);
        _fn = __bind(function(y) {
          return this.grid.scroll();
        }, this);
        for (y = 0; (0 <= h ? y < h : y > h); (0 <= h ? y += 1 : y -= 1)) {
          _fn(y);
        }
        this.grid.started = true;
        this.scroll = 0;
        this.maxscroll = this.config.maxscroll;
        return this.schedule.broker.bind('tick', __bind(function() {
          var _results;
          this.scroll += this.config.scroll;
          _results = [];
          while (this.scroll >= this.maxscroll) {
            this.scroll -= this.maxscroll;
            _results.push(this.grid.scroll());
          }
          return _results;
        }, this));
      };
      Field.prototype.bind = function(input) {
        return input.bind({
          scroll: __bind(function() {
            return this.scroll = 0;
          }, this)
        });
      };
      return Field;
    })();
    View = (function() {
      View.prototype.x = function(x) {
        return 32 * x;
      };
      View.prototype.y = function(y) {
        return 32 * (this.field.grid.height - 1 - y);
      };
      View.prototype.sq = function(v) {
        if (v == null) {
          v = 1;
        }
        return 32 * v;
      };
      function View(field) {
        var bg, blocks, cursor, grid, updateBlock;
        this.field = field;
        bg = $('<div class="grid-background">');
        bg.css({
          width: this.sq(this.field.grid.width),
          height: this.sq(this.field.grid.height),
          left: 0,
          top: 0
        });
        bg.appendTo('#game');
        grid = $('<div class="grid">');
        grid.css({
          width: this.sq(this.field.grid.width),
          height: this.sq(this.field.grid.height),
          left: 0,
          top: 0
        });
        grid.appendTo('#game');
        cursor = $('.cursor').clone();
        cursor.css({
          left: this.x(this.field.cursor.pt.x),
          top: this.y(this.field.cursor.pt.y)
        });
        cursor.appendTo('.grid');
        this.field.schedule.broker.bind({
          tick: __bind(function(e, args) {
            var fr, min, offset, pct, sec, t;
            pct = field.scroll / field.maxscroll;
            offset = Math.floor(32 * pct);
            grid.css({
              top: -offset
            });
            t = this.field.schedule.t;
            sec = Math.floor(t / 30);
            min = (Math.floor(sec / 60)).toString();
            sec = (sec % 60).toString();
            fr = (t % 30).toString();
            while (sec.length < 2) {
              sec = '0' + sec;
            }
            while (fr.length < 2) {
              fr = '0' + fr;
            }
            while (min.length < 2) {
              min = '0' + min;
            }
            return $('#stats .time').text([min, sec, fr].join(':'));
          }, this)
        });
        this.field.cursor.broker.bind({
          move: __bind(function(e, args) {
            var dur, props;
            dur = args.input ? 50 : 0;
            props = {
              left: this.x(this.field.cursor.pt.x),
              top: this.y(this.field.cursor.pt.y)
            };
            return cursor.animate(props, dur);
          }, this)
        }, blocks = {});
        updateBlock = __bind(function(b, pt) {
          var props;
          props = {
            left: this.x(pt.x),
            top: this.y(pt.y)
          };
          return b.animate(props, 50);
        }, this);
        this.field.grid.broker.bind({
          add: __bind(function(e, args) {
            var block;
            block = $('<div class="block block-' + args.block.n + '">');
            block.css({
              width: this.sq() - 2,
              height: this.sq() - 2,
              left: this.x(args.pt.x),
              top: this.y(args.pt.y)
            });
            updateBlock(block, args.pt);
            blocks[args.pt.toString()] = block;
            return block.appendTo('.grid');
          }, this),
          remove: __bind(function(e, args) {
            var block;
            block = blocks[args.pt.toString()];
            return block.fadeOut(null, function() {
              return $(block).remove();
            });
          }, this),
          swap: __bind(function(e, args) {
            var b1, b2;
            b1 = blocks[args.pt1.toString()];
            b2 = blocks[args.pt2.toString()];
            blocks[args.pt1.toString()] = b2;
            blocks[args.pt2.toString()] = b1;
            if (b2 != null) {
              updateBlock(b2, args.pt1);
            }
            if (b1 != null) {
              return updateBlock(b1, args.pt2);
            }
          }, this),
          scroll: function(e, args) {
            return grid.css({
              top: 0
            });
          }
        });
      }
      return View;
    })();
    tryCatch = function(fn) {
      try {
        return fn();
      } catch (e) {
        console.error(e);
        throw e;
      }
    };
    Input = (function() {
      function Input(config) {
        this.config = config;
        this.broker = $({});
        this.inputBindings = {
          13: 'scroll',
          32: 'swap',
          37: 'left',
          38: 'up',
          39: 'right',
          40: 'down'
        };
        this.inputBindings['Z'.charCodeAt(0)] = 'swap';
      }
      Input.prototype.bind = function(win) {
        var input;
        win.bind('keydown.input', __bind(function(e) {
          var event;
          event = this.inputBindings[e.which];
          if (event != null) {
            return this.broker.trigger(event);
          }
        }, this));
        input = this;
        return $('#sfx-enable-checkbox').bind('change.input', function() {
          var val;
          val = $(this).attr('checked');
          return input.config.sfx = val;
        });
      };
      Input.prototype.unbind = function(win) {
        win.unbind('keydown.input');
        return $('#sfx-enable-checkbox').unbind('change.input');
      };
      return Input;
    })();
    SFX = (function() {
      function SFX(config) {
        this.config = config;
        this.played = {};
        this.playingTotal = 0;
      }
      SFX.prototype.load = function(id) {
        return assert($('audio.' + id)[0], 'audio.' + id);
      };
      SFX.prototype.now = function() {
        return new Date().getTime();
      };
      SFX.prototype.play = function(id) {
        var a, diff, now, src, _ref;
        if (!this.config.sfx) {
          return;
        }
        now = this.now();
        src = this.load(id);
        diff = now - ((_ref = this.played[src.src]) != null ? _ref : 0);
        if (diff < 333) {
          return;
        }
        this.played[src.src] = now;
        a = new Audio(src.src);
        console.log(src.src);
        return a.play();
      };
      SFX.prototype.bind = function(input) {
        assert(input != null);
        input.bind({
          gameover: __bind(function() {
            return this.play('gameover');
          }, this),
          move: __bind(function() {
            return this.play('move');
          }, this),
          clear: __bind(function() {
            return this.play('clear');
          }, this),
          swap: __bind(function() {
            return this.play('swap');
          }, this),
          stage: __bind(function() {
            return this.play('stage');
          }, this),
          drop: __bind(function() {
            return this.play('drop');
          }, this),
          scroll: __bind(function() {
            return this.play('scroll');
          }, this),
          extinct: __bind(function() {
            return this.play('extinct');
          }, this)
        });
        return this;
      };
      return SFX;
    })();
    gameover = function() {
      return $('#gameover').fadeIn(500);
    };
    stage = function(config) {
      var fn;
      $('#stageclear').fadeIn().delay(500).fadeOut();
      $('#game').fadeOut(null, function() {
        return $(this).empty();
      });
      $('#stats').fadeOut();
      fn = function() {
        config.stage += 1;
        config.scroll *= 1.3;
        return onStart(config);
      };
      return setTimeout(fn, 1000);
    };
    updateStats = function(config) {
      var speed, text;
      $('#stats .stage').text(config.stage);
      speed = $('#stats .speed');
      text = Math.floor(config.scroll * 10);
      if (speed.text() !== text) {
        return speed.fadeOut(null, function() {
          speed.text(text);
          return speed.fadeIn();
        });
      }
    };
    updateExtinctions = function(types) {
      var n, text;
      n = types.types.length - types.stageClearAt;
      text = n + ' extinction';
      if (n !== 1) {
        text += 's';
      }
      return $('#stats .extinctionsLeft').text(text);
    };
    onStart = function(config) {
      var cursor, field, grid, input, scrollIncr, sfx, timer, types, view;
      config != null ? config : config = {
        stage: 1,
        maxscroll: 500,
        scroll: 1,
        blockTypes: 6,
        stageClearAt: 3,
        sfx: $('#sfx-enable-checkbox').attr('checked')
      };
      console.log(config.sfx);
      updateStats(config);
      $('#intro').fadeOut();
      $('#game').fadeIn();
      $('#stats').fadeIn();
      types = new BlockTypes(config.blockTypes, config.stageClearAt);
      grid = new Grid(6, 15, types);
      cursor = new Cursor(grid, new Point(2, 3));
      field = new Field(grid, cursor, config);
      view = new View(field);
      sfx = new SFX(config);
      input = new Input(config);
      input.bind($(window));
      cursor.bind(input.broker);
      field.init();
      field.bind(input.broker);
      sfx.bind(grid.broker).bind(cursor.broker);
      updateExtinctions(types);
      timer = setInterval((__bind(function() {
        return tryCatch(__bind(function() {
          return field.schedule.tick();
        }, this));
      }, this)), 33);
      scrollIncr = 0.1 * config.scroll;
      field.schedule.interval(30 * 30, function() {
        config.scroll += scrollIncr;
        return updateStats(config);
      });
      return grid.broker.bind({
        gameover: function() {
          clearInterval(timer);
          input.unbind($(window));
          return gameover();
        },
        stage: function() {
          clearInterval(timer);
          input.unbind($(window));
          return stage(config);
        },
        extinct: function(e, type) {
          var cls;
          updateExtinctions(types);
          cls = 'extinct-' + type.n;
          return $('#extinct').addClass(cls).fadeIn().delay(500).fadeOut(null, function() {
            return $(this).removeClass(cls);
          });
        }
      });
    };
    onLoad = function() {
      $('#sfx-enable-checkbox').bind('change', function() {
        var val;
        val = $(this).attr('checked');
        return $('.sfx-enable .enabled').text(val ? 'ON' : 'OFF');
      });
      $('#sfx-enable-checkbox').change();
      $('#loading').hide();
      $('#intro').fadeIn();
      return $(document).bind('keypress.start', __bind(function() {
        $(document).unbind('keypress.start');
        return tryCatch(onStart);
      }, this));
    };
    return jQuery(onLoad);
  })();
}).call(this);

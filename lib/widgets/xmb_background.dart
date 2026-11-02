import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../debug/dev_values.dart';
import '../debug/xmb_tuning.dart';
import '../ui/skin.dart';

/// Touch and scroll input for the Wave background. Screens forward their
/// pointer events here (see [XmbTouch]) and the carousel reports each song
/// it passes; every live [XmbBackground] reacts.
class XmbInput {
  XmbInput._();
  static final XmbInput instance = XmbInput._();

  final Set<_XmbBackgroundState> _targets = {};

  void down(int pointer, Offset global) {
    for (final t in _targets) {
      t._down(pointer, global);
    }
  }

  void move(int pointer, Offset global, Offset delta) {
    for (final t in _targets) {
      t._move(pointer, global, delta);
    }
  }

  void up(int pointer) {
    for (final t in _targets) {
      t._up(pointer);
    }
  }

  /// The carousel scrolled by [delta] px (positive = content moves up).
  void scrolled(double delta) {
    for (final t in _targets) {
      t._sim.scroll(delta);
    }
  }

  /// A song passed in the carousel (also during flings).
  void songPassed() {
    for (final t in _targets) {
      t._kick();
    }
  }
}

/// Forwards every pointer event under [child] to [XmbInput] without taking
/// part in gestures, so taps and scrolls work exactly as before.
class XmbTouch extends StatelessWidget {
  const XmbTouch({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final input = XmbInput.instance;
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) => input.down(e.pointer, e.position),
      onPointerMove: (e) => input.move(e.pointer, e.position, e.delta),
      onPointerUp: (e) => input.up(e.pointer),
      onPointerCancel: (e) => input.up(e.pointer),
      child: child,
    );
  }
}

/// The Wave theme's background: gradient, the folding light wave and the
/// sparkles, reacting to touch and scrolling. Tuning: [XmbTuning] in
/// lib/debug/xmb_tuning.dart.
///
/// Performance: everything is drawn in three calls per frame (one gradient
/// rect, one vertex mesh for the wave, one sprite atlas for the sparkles),
/// all computed on the CPU in well under a millisecond. It sits in its own
/// repaint layer so the rest of the screen is not repainted with it, and
/// its ticker stops whenever the screen is covered (TickerMode).
class XmbBackground extends StatefulWidget {
  const XmbBackground({super.key, this.opacity = 1});

  /// Fade of the whole background (the Classic/Wave cross-fade).
  final double opacity;

  /// Off in widget tests that need a still frame.
  static bool animate = true;

  @override
  State<XmbBackground> createState() => _XmbBackgroundState();
}

class _XmbBackgroundState extends State<XmbBackground>
    with SingleTickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_tick);
  final _repaint = ValueNotifier<int>(0);
  final _sim = _XmbSim();
  Duration? _last;

  @override
  void initState() {
    super.initState();
    XmbInput.instance._targets.add(this);
    if (XmbBackground.animate) {
      _ticker.start();
    } else {
      _sim.time = 3.0; // a still frame with some folds in view
    }
  }

  @override
  void dispose() {
    XmbInput.instance._targets.remove(this);
    _ticker.dispose();
    _repaint.dispose();
    super.dispose();
  }

  void _tick(Duration elapsed) {
    final dt = _last == null
        ? 0.0
        : ((elapsed - _last!).inMicroseconds / 1e6).clamp(0.0, 0.05);
    _last = elapsed;
    _sim.step(dt);
    _repaint.value++;
  }

  Offset? _local(Offset global) {
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return box.globalToLocal(global);
  }

  void _down(int pointer, Offset global) {
    final p = _local(global);
    if (p != null) _sim.touchDown(pointer, p);
  }

  void _move(int pointer, Offset global, Offset delta) {
    final p = _local(global);
    if (p != null) _sim.touchMove(pointer, p, delta);
  }

  void _up(int pointer) => _sim.touchUp(pointer);

  void _kick() => _sim.kick();

  @override
  Widget build(BuildContext context) {
    final night = Skin.of(context).night;
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          isComplex: true,
          willChange: true,
          painter: _XmbPainter(
            sim: _sim,
            repaint: _repaint,
            night: night,
            opacity: widget.opacity,
          ),
        ),
      ),
    );
  }
}

/// The moving parts: wave time, energy, scroll offset and sparkles.
/// The wave reacts only to scrolling; a finger only nudges the sparkles.
class _XmbSim {
  _XmbSim() {
    final rnd = math.Random(7);
    for (var i = 0; i < _n; i++) {
      _seed[i] = rnd.nextDouble();
      _sizeR[i] = rnd.nextDouble();
      _periodR[i] = rnd.nextDouble();
      _phase[i] = rnd.nextDouble();
      _near[i] = rnd.nextDouble() < XmbTuning.nearWave ? 1 : 0;
      _fx[i] = rnd.nextDouble(); // placed on first layout
      _fy[i] = rnd.nextDouble();
      _lane[i] = _gauss(rnd);
    }
    _rnd = rnd;
    _refresh();
  }

  int _version = -1;
  final Float32List _sizeR = Float32List(_n);
  final Float32List _periodR = Float32List(_n);

  /// Recomputes sizes and twinkle times from [XmbTuning] (after a change
  /// in the developer settings).
  void _refresh() {
    _version = DevValues.version;
    final minT = XmbTuning.minTwinkle.inMilliseconds / 1000;
    final maxT = XmbTuning.maxTwinkle.inMilliseconds / 1000;
    for (var i = 0; i < _n; i++) {
      final sz = math.pow(_sizeR[i], XmbTuning.sizeBias).toDouble();
      _size[i] = XmbTuning.minSize + (XmbTuning.maxSize - XmbTuning.minSize) * sz;
      _period[i] = minT + (maxT - minT) * _periodR[i];
    }
  }

  static const int _n = XmbTuning.particles;
  late math.Random _rnd;

  double time = 0; // wave time (speeds up with energy)
  double clock = 0; // real time, for twinkling
  double energy = 0;

  // Sparkles: position in px once [size] is known; before that, fractions.
  final Float32List _x = Float32List(_n);
  final Float32List _y = Float32List(_n);
  final Float32List _vx = Float32List(_n);
  final Float32List _vy = Float32List(_n);
  final Float32List _size = Float32List(_n);
  final Float32List _seed = Float32List(_n);
  final Float32List _period = Float32List(_n);
  final Float32List _phase = Float32List(_n);
  final Float32List _near = Float32List(_n);
  final Float32List _lane = Float32List(_n);
  final Float32List _fx = Float32List(_n);
  final Float32List _fy = Float32List(_n);
  Size size = Size.zero;
  bool _placed = false;

  final Map<int, Offset> _fingers = {};
  double _windX = 0, _windY = 0;

  static double _gauss(math.Random r) {
    final u = math.max(1e-6, r.nextDouble());
    return math.sqrt(-2 * math.log(u)) * math.cos(2 * math.pi * r.nextDouble());
  }

  /// Centre line of the wave at height y, in px.
  double waveCentre(double y) {
    final s = size.height <= 0 ? 0.0 : y / size.height * 2 - 1;
    return size.width * (XmbTuning.centre + XmbTuning.lean * s);
  }

  void layout(Size s) {
    if (s == size) return;
    final old = size;
    size = s;
    if (!_placed) {
      for (var i = 0; i < _n; i++) {
        _y[i] = _fy[i] * s.height;
        _x[i] = _spawnX(i, _y[i]);
      }
      _placed = true;
    } else if (old.width > 0 && old.height > 0) {
      for (var i = 0; i < _n; i++) {
        _x[i] = _x[i] / old.width * s.width;
        _y[i] = _y[i] / old.height * s.height;
      }
    }
  }

  double _spawnX(int i, double y) => _near[i] > 0
      ? waveCentre(y) + _lane[i] * size.width * 0.11
      : _fx[i] * size.width;

  void touchDown(int pointer, Offset p) => _fingers[pointer] = p;

  void touchMove(int pointer, Offset p, Offset delta) {
    _fingers[pointer] = p;
    _windX = _windX * 0.6 + delta.dx * 0.4;
    _windY = _windY * 0.6 + delta.dy * 0.4;
  }

  void touchUp(int pointer) => _fingers.remove(pointer);

  /// Wave offset from scrolling, in px.
  double scrollShift = 0;

  void scroll(double delta) {
    scrollShift += delta * XmbTuning.waveScroll;
    energy = math.min(XmbTuning.energyMax,
        energy + delta.abs() * XmbTuning.energyPerPx);
    final span = XmbTuning.maxSize - XmbTuning.minSize;
    for (var i = 0; i < _n; i++) {
      final depth = span <= 0 ? 0.5 : (_size[i] - XmbTuning.minSize) / span;
      _y[i] -= delta *
          (XmbTuning.particleScrollMin +
              (XmbTuning.particleScrollMax - XmbTuning.particleScrollMin) *
                  depth);
    }
  }

  void kick() {
    energy = math.min(XmbTuning.energyMax, energy + XmbTuning.energyPerSong);
  }

  void step(double dt) {
    clock += dt;
    final decay = math.exp(-dt / (XmbTuning.energyDecay.inMilliseconds / 1000));
    energy *= decay;
    time += dt *
        XmbTuning.flowSpeed *
        (1 + XmbTuning.energySpeedBoost * energy);
    if (DevValues.version != _version) _refresh();
    _stepParticles(dt);
    _windX *= decay;
    _windY *= decay;
  }

  void _stepParticles(double dt) {
    if (size.isEmpty || dt <= 0) return;
    final w = size.width, h = size.height;
    final damp = 1 - math.exp(-dt * XmbTuning.particleDamping);
    final r = XmbTuning.repelRadius * w;
    final boost = 1 + 1.5 * energy;
    for (var i = 0; i < _n; i++) {
      // Drift: upwards along the wave, swaying gently sideways.
      final sway = math.sin(clock * (0.3 + _seed[i] * 0.5) + _seed[i] * 40) * 6;
      final tx = sway;
      final ty = -XmbTuning.drift * (0.5 + _seed[i]) * boost;
      var ax = (tx - _vx[i]) * damp / dt;
      var ay = (ty - _vy[i]) * damp / dt;
      for (final f in _fingers.values) {
        final dx = _x[i] - f.dx, dy = _y[i] - f.dy;
        final d = math.sqrt(dx * dx + dy * dy);
        if (d < r && d > 0.5) {
          final k = (1 - d / r);
          final a = XmbTuning.repelForce * k * k / d;
          ax += dx * a;
          ay += dy * a;
          // Scrolling drags nearby sparkles along.
          _vx[i] += _windX * XmbTuning.wind * k;
          _vy[i] += _windY * XmbTuning.wind * k;
        }
      }
      _vx[i] += ax * dt;
      _vy[i] += ay * dt;
      _x[i] += _vx[i] * dt;
      _y[i] += _vy[i] * dt;
      // Leave one edge, come back on the other.
      if (_y[i] < -10) {
        _y[i] = h + 10;
        _x[i] = _spawnX(i, _y[i]);
        _lane[i] = _gauss(_rnd);
      } else if (_y[i] > h + 10) {
        _y[i] = -10;
        _x[i] = _spawnX(i, _y[i]);
      }
      if (_x[i] < -20) _x[i] = w + 20;
      if (_x[i] > w + 20) _x[i] = -20;
    }
  }
}

class _XmbPainter extends CustomPainter {
  _XmbPainter({
    required this.sim,
    required Listenable repaint,
    required this.night,
    required this.opacity,
  }) : super(repaint: repaint);

  final _XmbSim sim;
  final double night;
  final double opacity;

  static Uint16List? _indices;
  static int _indexRows = 0, _indexCols = 0;
  static ui.Image? _sprite;
  static Float32List? _rects;

  static Uint16List _gridIndices(int rows, int cols) {
    if (_indices != null && _indexRows == rows && _indexCols == cols) {
      return _indices!;
    }
    final out = Uint16List((rows - 1) * (cols - 1) * 6);
    var k = 0;
    for (var r = 0; r < rows - 1; r++) {
      for (var c = 0; c < cols - 1; c++) {
        final a = r * cols + c, b = a + 1, d = a + cols, e = d + 1;
        out[k++] = a;
        out[k++] = b;
        out[k++] = d;
        out[k++] = b;
        out[k++] = e;
        out[k++] = d;
      }
    }
    _indexRows = rows;
    _indexCols = cols;
    return _indices = out;
  }

  /// A soft white dot, made once.
  static ui.Image _dot() {
    final cached = _sprite;
    if (cached != null) return cached;
    final rec = ui.PictureRecorder();
    final c = Canvas(rec);
    c.drawCircle(
      const Offset(32, 32),
      32,
      Paint()
        ..shader = ui.Gradient.radial(const Offset(32, 32), 32, const [
          Color(0xFFFFFFFF),
          Color(0xFFFFFFFF),
          Color(0x66FFFFFF),
          Color(0x00FFFFFF),
        ], const [
          0.0,
          0.18,
          0.4,
          1.0,
        ]),
    );
    return _sprite = rec.endRecording().toImageSync(64, 64);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || opacity <= 0) return;
    sim.layout(size);
    final o = opacity.clamp(0.0, 1.0);

    // 1. Gradient.
    final colors = [
      for (var i = 0; i < 3; i++)
        Color.lerp(XmbTuning.lightGradient[i], XmbTuning.darkGradient[i], night)!
            .withValues(alpha: o),
    ];
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.linear(
          Offset.zero,
          Offset(size.width, size.height * 0.8),
          colors,
          [0.0, XmbTuning.gradientMid, 1.0],
        ),
    );

    // 2. Wave.
    _paintWave(canvas, size, o);

    // 3. Sparkles.
    _paintSparkles(canvas, o);
  }

  void _paintWave(Canvas canvas, Size size, double o) {
    const rows = XmbTuning.rows, cols = XmbTuning.columns;
    final w = size.width, h = size.height;
    final pos = Float32List(rows * cols * 2);
    final col = Int32List(rows * cols);
    final t = sim.time;
    final grow = 1 + XmbTuning.energyAmpBoost * sim.energy;
    final alphaScale = o *
        (XmbTuning.opacityLight +
            (XmbTuning.opacityDark - XmbTuning.opacityLight) * night);
    final ys = h * 0.5; // dy/ds in px
    // Scrolling slides the wave's folds along it (in s units).
    final scroll = h <= 0 ? 0.0 : sim.scrollShift / ys;
    final depth = w * XmbTuning.depth;
    final waves = XmbTuning.waves;

    var vi = 0;
    for (var r = 0; r < rows; r++) {
      // s runs a little past the screen edges so the ends stay hidden.
      final s = (r / (rows - 1)) * 2.6 - 1.3; // -1.3..1.3
      final y = h * (s * 0.5 + 0.5);
      final sEdge = 1 - _smooth(1.0, 1.3, s.abs());
      for (var c = 0; c < cols; c++) {
        final z = (c / (cols - 1)) * 2 - 1;
        var x = XmbTuning.centre +
            XmbTuning.lean * s +
            z * (XmbTuning.spread + XmbTuning.spreadLean * s);
        var xs = XmbTuning.lean + z * XmbTuning.spreadLean;
        var xz = XmbTuning.spread + XmbTuning.spreadLean * s;
        for (final k in waves) {
          final a = k.amp * grow;
          final arg = k.along * (s + scroll) + k.twist * z + k.speed * t + k.phase;
          x += a * math.sin(arg);
          final cs = math.cos(arg);
          xs += a * k.along * cs;
          xz += a * k.twist * cs;
        }
        final px = x * w;
        final xzPx = xz * w;
        final xsPx = xs * w;

        // Fresnel: bright where the sheet is edge-on to the viewer.
        // N = (ys*depth, -xs*depth, -ys*xz); |N.z| = 1 means facing us.
        final nx = ys * depth, ny = -xsPx * depth, nz = -ys * xzPx;
        final len = math.sqrt(nx * nx + ny * ny + nz * nz);
        final facing = len == 0 ? 0.0 : (nz.abs() / len);
        final edgeOn = 1 - facing;
        var a = XmbTuning.baseAlpha +
            XmbTuning.fresnel * math.pow(edgeOn, XmbTuning.fresnelPower) +
            (xzPx < 0 ? XmbTuning.backBoost : 0.0);
        final zEdge = 1 - _smooth(0.7, 1.0, z.abs());
        a = (a * zEdge * sEdge * alphaScale).clamp(0.0, 1.0);

        pos[vi * 2] = px;
        pos[vi * 2 + 1] = y;
        col[vi] = ((a * 255).round() << 24) | 0x00FFFFFF;
        vi++;
      }
    }
    final verts = ui.Vertices.raw(
      VertexMode.triangles,
      pos,
      colors: col,
      indices: _gridIndices(rows, cols),
    );
    canvas.drawVertices(verts, BlendMode.dst, Paint());
    verts.dispose();
  }

  void _paintSparkles(Canvas canvas, double o) {
    final n = _XmbSim._n;
    final sprite = _dot();
    final rects = _rects ??= () {
      final r = Float32List(n * 4);
      for (var i = 0; i < n; i++) {
        r[i * 4 + 2] = 64;
        r[i * 4 + 3] = 64;
      }
      return r;
    }();
    final xf = Float32List(n * 4);
    final colors = Int32List(n);
    final peak = o *
        (XmbTuning.particleOpacityLight +
            (XmbTuning.particleOpacityDark - XmbTuning.particleOpacityLight) *
                night);
    for (var i = 0; i < n; i++) {
      final wave = 0.5 -
          0.5 * math.cos(2 * math.pi * (sim.clock / sim._period[i] + sim._phase[i]));
      final a = (peak * math.pow(wave, 1.5) * (0.5 + 0.5 * sim._seed[i]))
          .clamp(0.0, 1.0);
      final scale = sim._size[i] * 2 / 64 * 2; // sprite fades, so draw 2x
      xf[i * 4] = scale;
      xf[i * 4 + 1] = 0;
      xf[i * 4 + 2] = sim._x[i] - 32 * scale;
      xf[i * 4 + 3] = sim._y[i] - 32 * scale;
      colors[i] = ((a * 255).round() << 24) | 0x00FFFFFF;
    }
    canvas.drawRawAtlas(sprite, xf, rects, colors, BlendMode.modulate, null,
        Paint()..blendMode = BlendMode.plus);
  }

  static double _smooth(double e0, double e1, double x) {
    final t = ((x - e0) / (e1 - e0)).clamp(0.0, 1.0);
    return t * t * (3 - 2 * t);
  }

  @override
  bool shouldRepaint(_XmbPainter old) =>
      old.night != night || old.opacity != opacity || old.sim != sim;
}

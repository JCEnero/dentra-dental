import 'dart:math' as math;
import 'dart:typed_data';

/// Minimal 3D vector for building geometry.
class Vec3 {
  const Vec3(this.x, this.y, this.z);

  final double x, y, z;

  static const zero = Vec3(0, 0, 0);

  Vec3 operator +(Vec3 o) => Vec3(x + o.x, y + o.y, z + o.z);
  Vec3 operator -(Vec3 o) => Vec3(x - o.x, y - o.y, z - o.z);
  Vec3 operator *(double s) => Vec3(x * s, y * s, z * s);
  Vec3 operator -() => Vec3(-x, -y, -z);

  double dot(Vec3 o) => x * o.x + y * o.y + z * o.z;

  Vec3 cross(Vec3 o) =>
      Vec3(y * o.z - z * o.y, z * o.x - x * o.z, x * o.y - y * o.x);

  double get length => math.sqrt(x * x + y * y + z * z);

  Vec3 normalized() {
    final l = length;
    return l == 0 ? this : this * (1 / l);
  }

  static Vec3 lerp(Vec3 a, Vec3 b, double t) => a + (b - a) * t;

  @override
  String toString() =>
      'Vec3(${x.toStringAsFixed(2)}, ${y.toStringAsFixed(2)}, ${z.toStringAsFixed(2)})';
}

/// Linear RGB albedo in 0–1.
class Rgb {
  const Rgb(this.r, this.g, this.b);
  final double r, g, b;

  Rgb operator *(double s) => Rgb(r * s, g * s, b * s);
  static Rgb lerp(Rgb a, Rgb b, double t) =>
      Rgb(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t, a.b + (b.b - a.b) * t);
}

/// One vertex of a ring surface.
class SurfaceVertex {
  const SurfaceVertex(this.p, this.color, [this.flags = 0, this.rootDepth = 0]);
  final Vec3 p;
  final Rgb color;
  final int flags;

  /// Distance below the cementoenamel junction in mm (0 on the crown).
  final double rootDepth;
}

/// Vertex flag: root surface, hidden while the gums are shown.
const int kFlagRoot = 1;

/// Vertex flag: a separate root that grows out of a root trunk. Sorted
/// slightly behind so the trunk wins where the two meet.
const int kFlagSubRoot = 2;

/// Accumulates owner-tagged vertices and triangles, then bakes them into
/// flat typed arrays for the renderer.
class MeshBuilder {
  final _pos = <double>[];
  final _albedo = <double>[];
  final _owner = <int>[];
  final _flags = <int>[];
  final _rootDepth = <double>[];
  final _tris = <int>[];

  int get vertexCount => _owner.length;

  int addVertex(Vec3 p, Rgb color, int owner,
      {int flags = 0, double rootDepth = 0}) {
    _pos
      ..add(p.x)
      ..add(p.y)
      ..add(p.z);
    _albedo
      ..add(color.r)
      ..add(color.g)
      ..add(color.b);
    _owner.add(owner);
    _flags.add(flags);
    _rootDepth.add(rootDepth);
    return _owner.length - 1;
  }

  Vec3 position(int i) => Vec3(_pos[i * 3], _pos[i * 3 + 1], _pos[i * 3 + 2]);

  /// Joins closed rings of vertices into a tube. Optional poles close
  /// either end.
  ///
  /// When [closed] is true the winding is fixed from the enclosed volume
  /// so every face points outward. Otherwise [outwardHint] picks it.
  void addRingSurface(
    List<List<SurfaceVertex>> rings, {
    required int owner,
    SurfaceVertex? startPole,
    SurfaceVertex? endPole,
    bool closed = true,
    Vec3? outwardHint,
  }) {
    final firstTri = _tris.length;
    final n = rings.first.length;
    final ringStart = <int>[];
    for (final ring in rings) {
      ringStart.add(vertexCount);
      for (final v in ring) {
        addVertex(v.p, v.color, owner, flags: v.flags, rootDepth: v.rootDepth);
      }
    }
    for (var r = 0; r + 1 < rings.length; r++) {
      final a = ringStart[r], b = ringStart[r + 1];
      for (var s = 0; s < n; s++) {
        final s1 = (s + 1) % n;
        _tri(a + s, b + s, a + s1);
        _tri(a + s1, b + s, b + s1);
      }
    }
    if (startPole != null) {
      final p = addVertex(startPole.p, startPole.color, owner,
          flags: startPole.flags, rootDepth: startPole.rootDepth);
      final a = ringStart.first;
      for (var s = 0; s < n; s++) {
        _tri(p, a + s, a + (s + 1) % n);
      }
    }
    if (endPole != null) {
      final p = addVertex(endPole.p, endPole.color, owner,
          flags: endPole.flags, rootDepth: endPole.rootDepth);
      final a = ringStart.last;
      for (var s = 0; s < n; s++) {
        _tri(p, a + (s + 1) % n, a + s);
      }
    }
    _orient(firstTri, closed: closed, hint: outwardHint);
  }

  void _tri(int a, int b, int c) => _tris
    ..add(a)
    ..add(b)
    ..add(c);

  /// Flips triangles from [firstTri] on if they face inward.
  void _orient(int firstTri, {required bool closed, Vec3? hint}) {
    var score = 0.0;
    for (var t = firstTri; t < _tris.length; t += 3) {
      final a = position(_tris[t]);
      final b = position(_tris[t + 1]);
      final c = position(_tris[t + 2]);
      final n = (b - a).cross(c - a);
      score += closed ? a.dot(n) : n.dot(hint ?? const Vec3(0, 1, 0));
    }
    if (score >= 0) return;
    for (var t = firstTri; t < _tris.length; t += 3) {
      final tmp = _tris[t + 1];
      _tris[t + 1] = _tris[t + 2];
      _tris[t + 2] = tmp;
    }
  }

  DentitionMesh build() {
    final vCount = vertexCount;
    final positions = Float32List.fromList(_pos);
    final normals = Float32List(vCount * 3);
    final triangles = Uint32List.fromList(_tris);
    final triCount = triangles.length ~/ 3;
    final triOwner = Uint8List(triCount);
    final triFlags = Uint8List(triCount);

    // Area-weighted smooth normals.
    for (var t = 0; t < triCount; t++) {
      final i0 = triangles[t * 3],
          i1 = triangles[t * 3 + 1],
          i2 = triangles[t * 3 + 2];
      final ax = _pos[i0 * 3], ay = _pos[i0 * 3 + 1], az = _pos[i0 * 3 + 2];
      final ux = _pos[i1 * 3] - ax,
          uy = _pos[i1 * 3 + 1] - ay,
          uz = _pos[i1 * 3 + 2] - az;
      final vx = _pos[i2 * 3] - ax,
          vy = _pos[i2 * 3 + 1] - ay,
          vz = _pos[i2 * 3 + 2] - az;
      final nx = uy * vz - uz * vy,
          ny = uz * vx - ux * vz,
          nz = ux * vy - uy * vx;
      for (final i in [i0, i1, i2]) {
        normals[i * 3] += nx;
        normals[i * 3 + 1] += ny;
        normals[i * 3 + 2] += nz;
      }
      triOwner[t] = _owner[i0];
      // A triangle counts as root only when it lies fully on the root.
      triFlags[t] = _flags[i0] & _flags[i1] & _flags[i2];
    }
    for (var i = 0; i < vCount; i++) {
      final x = normals[i * 3], y = normals[i * 3 + 1], z = normals[i * 3 + 2];
      final l = math.sqrt(x * x + y * y + z * z);
      if (l > 0) {
        normals[i * 3] = x / l;
        normals[i * 3 + 1] = y / l;
        normals[i * 3 + 2] = z / l;
      }
    }

    return DentitionMesh(
      positions: positions,
      normals: normals,
      albedo: Float32List.fromList(_albedo),
      owner: Uint8List.fromList(_owner),
      flags: Uint8List.fromList(_flags),
      rootDepth: Float32List.fromList(_rootDepth),
      triangles: triangles,
      triOwner: triOwner,
      triFlags: triFlags,
    );
  }
}

/// Baked geometry: one shared vertex pool for every tooth and the gums.
class DentitionMesh {
  const DentitionMesh({
    required this.positions,
    required this.normals,
    required this.albedo,
    required this.owner,
    required this.flags,
    required this.rootDepth,
    required this.triangles,
    required this.triOwner,
    required this.triFlags,
  });

  final Float32List positions;
  final Float32List normals;
  final Float32List albedo;
  final Uint8List owner;
  final Uint8List flags;

  /// Per vertex: mm below the cementoenamel junction (0 on crowns, gums).
  final Float32List rootDepth;
  final Uint32List triangles;
  final Uint8List triOwner;
  final Uint8List triFlags;

  int get vertexCount => owner.length;
  int get triangleCount => triOwner.length;
}

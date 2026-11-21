# -*- coding: utf-8 -*-
"""
glblib.py — 纯 Python glTF 2.0 (.glb) 生成器（无外部依赖）
《沈家老宅》资产管线核心：几何图元 / PBR 材质 / 节点层级 / 关键帧动画 / 内嵌 PNG 贴图
碰撞约定：节点名以 -colonly 结尾 → Godot 导入为纯碰撞体（不渲染）
"""
import json, struct, math, os

# ---------------------------------------------------------------- 数学工具
def quat_from_euler(rx, ry, rz):
    """欧拉角(度, XYZ 顺序) -> 四元数 [x,y,z,w]"""
    rx, ry, rz = math.radians(rx), math.radians(ry), math.radians(rz)
    cx, sx = math.cos(rx / 2), math.sin(rx / 2)
    cy, sy = math.cos(ry / 2), math.sin(ry / 2)
    cz, sz = math.cos(rz / 2), math.sin(rz / 2)
    return [
        sx * cy * cz - cx * sy * sz,
        cx * sy * cz + sx * cy * sz,
        cx * cy * sz + sx * sy * cz,
        cx * cy * cz - sx * sy * sz,
    ]

def trs_matrix(t=(0, 0, 0), r=(0, 0, 0), s=(1, 1, 1)):
    q = quat_from_euler(*r)
    x, y, z, w = q
    R = [
        [1 - 2 * (y * y + z * z), 2 * (x * y - w * z), 2 * (x * z + w * y)],
        [2 * (x * y + w * z), 1 - 2 * (x * x + z * z), 2 * (y * z - w * x)],
        [2 * (x * z - w * y), 2 * (y * z + w * x), 1 - 2 * (x * x + y * y)],
    ]
    M = [[R[i][j] * s[j] for j in range(3)] + [t[i]] for i in range(3)]
    M.append([0, 0, 0, 1])
    return M

def xform_points(pos, M):
    out = []
    for p in pos:
        x, y, z = p
        out.append((M[0][0] * x + M[0][1] * y + M[0][2] * z + M[0][3],
                    M[1][0] * x + M[1][1] * y + M[1][2] * z + M[1][3],
                    M[2][0] * x + M[2][1] * y + M[2][2] * z + M[2][3]))
    return out

def xform_dirs(nor, M):
    R = [[M[0][0], M[0][1], M[0][2]], [M[1][0], M[1][1], M[1][2]], [M[2][0], M[2][1], M[2][2]]]
    out = []
    for n in nor:
        x, y, z = n
        out.append((R[0][0] * x + R[0][1] * y + R[0][2] * z,
                    R[1][0] * x + R[1][1] * y + R[1][2] * z,
                    R[2][0] * x + R[2][1] * y + R[2][2] * z))
    return out

def normalize(v):
    l = math.sqrt(v[0] ** 2 + v[1] ** 2 + v[2] ** 2) or 1.0
    return (v[0] / l, v[1] / l, v[2] / l)

# ---------------------------------------------------------------- 图元
class Mesh:
    def __init__(self):
        self.pos, self.nor, self.uv, self.idx = [], [], [], []

    def merge(self, other, mat4=None):
        base = len(self.pos)
        if mat4 is None:
            self.pos += other.pos
            self.nor += other.nor
        else:
            self.pos += xform_points(other.pos, mat4)
            self.nor += [normalize(n) for n in xform_dirs(other.nor, mat4)]
        self.uv += other.uv
        self.idx += [i + base for i in other.idx]
        return self

def _face(mesh, quad_pos, quad_nor, quad_uv):
    i0 = len(mesh.pos)
    for k in range(4):
        mesh.pos.append(quad_pos[k])
        mesh.nor.append(quad_nor)
        mesh.uv.append(quad_uv[k])
    mesh.idx += [i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3]

def box(w, h, d, uv=1.0):
    m = Mesh()
    x, y, z = w / 2, h / 2, d / 2
    faces = [
        ((-x, -y, z), (x, -y, z), (x, y, z), (-x, y, z), (0, 0, 1)),
        ((x, -y, -z), (-x, -y, -z), (-x, y, -z), (x, y, -z), (0, 0, -1)),
        ((x, -y, z), (x, -y, -z), (x, y, -z), (x, y, z), (1, 0, 0)),
        ((-x, -y, -z), (-x, -y, z), (-x, y, z), (-x, y, -z), (-1, 0, 0)),
        ((-x, y, z), (x, y, z), (x, y, -z), (-x, y, -z), (0, 1, 0)),
        ((-x, -y, -z), (x, -y, -z), (x, -y, z), (-x, -y, z), (0, -1, 0)),
    ]
    for a, b, c, dd, n in faces:
        _face(m, [a, b, c, dd], n, [(0, 0), (uv, 0), (uv, uv), (0, uv)])
    return m

def plane(w, d, uv=1.0):
    m = Mesh()
    x, z = w / 2, d / 2
    _face(m, [(-x, 0, -z), (-x, 0, z), (x, 0, z), (x, 0, -z)], (0, 1, 0),
          [(0, 0), (0, uv), (uv, uv), (uv, 0)])
    return m

def quad(w, h, uv=1.0):
    m = Mesh()
    x, y = w / 2, h / 2
    _face(m, [(-x, -y, 0), (x, -y, 0), (x, y, 0), (-x, y, 0)], (0, 0, 1),
          [(0, 0), (uv, 0), (uv, uv), (0, uv)])
    return m

def cylinder(r0, r1, h, seg=16, cap=True, uv=1.0):
    """底面 y=0，顶面 y=h；r0=底半径，r1=顶半径（0 则为圆锥）"""
    m = Mesh()
    for i in range(seg):
        a0 = 2 * math.pi * i / seg
        a1 = 2 * math.pi * (i + 1) / seg
        c0, s0 = math.cos(a0), math.sin(a0)
        c1, s1 = math.cos(a1), math.sin(a1)
        slope = (r0 - r1) / h if h > 0 else 0.0
        n = normalize((c0 + c1, slope, s0 + s1))
        i0 = len(m.pos)
        m.pos += [(r0 * c0, 0, r0 * s0), (r0 * c1, 0, r0 * s1),
                  (r1 * c1, h, r1 * s1), (r1 * c0, h, r1 * s0)]
        m.nor += [n] * 4
        u0, u1 = uv * i / seg, uv * (i + 1) / seg
        m.uv += [(u0, 0), (u1, 0), (u1, uv), (u0, uv)]
        m.idx += [i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3]
        if cap and r0 > 0.0001:
            ci = len(m.pos)
            m.pos += [(0, 0, 0), (r0 * c0, 0, r0 * s0), (r0 * c1, 0, r0 * s1)]
            m.nor += [(0, -1, 0)] * 3
            m.uv += [(0.5, 0.5), (0.5 + 0.5 * c0, 0.5 + 0.5 * s0), (0.5 + 0.5 * c1, 0.5 + 0.5 * s1)]
            m.idx += [ci, ci + 2, ci + 1]
        if cap and r1 > 0.0001:
            ci = len(m.pos)
            m.pos += [(0, h, 0), (r1 * c1, h, r1 * s1), (r1 * c0, h, r1 * s0)]
            m.nor += [(0, 1, 0)] * 3
            m.uv += [(0.5, 0.5), (0.5 + 0.5 * c1, 0.5 + 0.5 * s1), (0.5 + 0.5 * c0, 0.5 + 0.5 * s0)]
            m.idx += [ci, ci + 1, ci + 2]
    return m

def lathe(profile, seg=24, uv_u=1.0, uv_v=1.0):
    """旋转成型：profile=[(半径r, 高度y), ...] 自底向上绕 Y 轴旋转"""
    m = Mesh()
    n_pts = len(profile)
    for j, (r, y) in enumerate(profile):
        for i in range(seg + 1):
            a = 2 * math.pi * i / seg
            m.pos.append((r * math.cos(a), y, r * math.sin(a)))
            m.uv.append((uv_u * i / seg, uv_v * j / (n_pts - 1)))
    normals = []
    for j in range(n_pts):
        r, y = profile[j]
        if j == 0:
            dr = profile[1][0] - r; dy = profile[1][1] - y
        elif j == n_pts - 1:
            dr = r - profile[j - 1][0]; dy = y - profile[j - 1][1]
        else:
            dr = profile[j + 1][0] - profile[j - 1][0]
            dy = profile[j + 1][1] - profile[j - 1][1]
        nr, ny = dy, -dr
        l = math.sqrt(nr * nr + ny * ny) or 1.0
        nr, ny = nr / l, ny / l
        for i in range(seg + 1):
            a = 2 * math.pi * i / seg
            normals.append((nr * math.cos(a), ny, nr * math.sin(a)))
    m.nor = normals
    for j in range(n_pts - 1):
        for i in range(seg):
            a = j * (seg + 1) + i
            b = a + 1
            c = a + (seg + 1)
            d = c + 1
            m.idx += [a, b, d, a, d, c]
    if profile[0][0] > 0.0001:  # 底盖（朝下）
        ci = len(m.pos)
        r0, y0 = profile[0]
        for i in range(seg + 1):
            a = 2 * math.pi * i / seg
            m.pos.append((r0 * math.cos(a), y0, r0 * math.sin(a)))
            m.nor.append((0, -1, 0))
            m.uv.append((0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a)))
        for i in range(1, seg - 1):
            m.idx += [ci, ci + i + 1, ci + i]
    if profile[-1][0] > 0.0001:  # 顶盖（朝上）
        ci = len(m.pos)
        r1, y1 = profile[-1]
        for i in range(seg + 1):
            a = 2 * math.pi * i / seg
            m.pos.append((r1 * math.cos(a), y1, r1 * math.sin(a)))
            m.nor.append((0, 1, 0))
            m.uv.append((0.5 + 0.5 * math.cos(a), 0.5 + 0.5 * math.sin(a)))
        for i in range(0, seg - 1):
            m.idx += [ci, ci + i, ci + i + 1]
    return m

def sphere(r, seg=16, rings=8):
    prof = []
    for j in range(rings + 1):
        a = math.pi * j / rings
        prof.append((max(r * math.sin(a), 1e-4), r * math.cos(a) + r))
    return lathe(prof, seg)

def annulus(r_out, r_in, seg=24, uv=1.0):
    """水平圆环，法线 +Y"""
    m = Mesh()
    for i in range(seg):
        a0, a1 = 2 * math.pi * i / seg, 2 * math.pi * (i + 1) / seg
        p = [(r_out * math.cos(a0), 0, r_out * math.sin(a0)), (r_out * math.cos(a1), 0, r_out * math.sin(a1)),
             (r_in * math.cos(a1), 0, r_in * math.sin(a1)), (r_in * math.cos(a0), 0, r_in * math.sin(a0))]
        _face(m, p, (0, 1, 0), [(0, 0), (uv, 0), (uv, uv), (0, uv)])
    return m

def _tri_poly(poly):
    """耳切法三角化 XY 多边形"""
    n = len(poly)
    if n < 3:
        return []
    idx = list(range(n))
    tris = []
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    guard = 0
    while len(idx) > 3 and guard < 1000:
        guard += 1
        ni = len(idx)
        ear = False
        for i in range(ni):
            i0, i1, i2 = idx[(i - 1) % ni], idx[i], idx[(i + 1) % ni]
            a, b, c = poly[i0], poly[i1], poly[i2]
            if cross(a, b, c) <= 1e-9:
                continue
            bad = False
            for j in idx:
                if j in (i0, i1, i2):
                    continue
                p = poly[j]
                if cross(a, b, p) >= 0 and cross(b, c, p) >= 0 and cross(c, a, p) >= 0:
                    bad = True
                    break
            if not bad:
                tris += [i0, i1, i2]
                idx.pop(i)
                ear = True
                break
        if not ear:
            break
    if len(idx) == 3:
        tris += list(idx)
    return tris

def prism(poly_xy, depth, uv=1.0):
    """XY 多边形沿 Z 挤出 -depth/2..+depth/2"""
    m = Mesh()
    d = depth / 2
    n = len(poly_xy)
    for i in range(n):
        x0, y0 = poly_xy[i]
        x1, y1 = poly_xy[(i + 1) % n]
        nx, ny = y1 - y0, -(x1 - x0)
        l = math.sqrt(nx * nx + ny * ny) or 1.0
        nx, ny = nx / l, ny / l
        i0 = len(m.pos)
        m.pos += [(x0, y0, -d), (x1, y1, -d), (x1, y1, d), (x0, y0, d)]
        m.nor += [(nx, ny, 0)] * 4
        seg = uv * math.sqrt((x1 - x0) ** 2 + (y1 - y0) ** 2)
        m.uv += [(0, 0), (seg, 0), (seg, uv), (0, uv)]
        m.idx += [i0, i0 + 1, i0 + 2, i0, i0 + 2, i0 + 3]
    tris = _tri_poly(poly_xy)
    for sign, z in ((1, d), (-1, -d)):
        ci = len(m.pos)
        for (x, y) in poly_xy:
            m.pos.append((x, y, z))
            m.nor.append((0, 0, sign))
            m.uv.append((x * uv, y * uv))
        for k in range(0, len(tris), 3):
            a, b, c = tris[k], tris[k + 1], tris[k + 2]
            if sign > 0:
                m.idx += [ci + a, ci + c, ci + b]
            else:
                m.idx += [ci + a, ci + b, ci + c]
    return m

# ---------------------------------------------------------------- 材质库
class MaterialLib:
    def __init__(self):
        self.mats = {}
        self.textures = {}  # tex_name -> png bytes

    def reg_tex(self, name, png_bytes):
        self.textures[name] = png_bytes

    def mat(self, name, tex=None, color=(1, 1, 1, 1), metal=0.0, rough=0.8,
            emissive=None, alpha=None, cutoff=0.5, double=False):
        self.mats[name] = dict(tex=tex, color=list(color), metal=metal, rough=rough,
                               emissive=list(emissive) if emissive else None,
                               alpha=alpha, cutoff=cutoff, double=double)
        return name

MATLIB = MaterialLib()

# ---------------------------------------------------------------- Prop
class Prop:
    """一个 .glb 资产：根节点 + 命名子节点（每个 part 一个节点）+ 可选动画"""
    def __init__(self, name):
        self.name = name
        self.parts = []       # dict(node, mesh, mat, trs)
        self.animations = []  # dict(name, node, path, keys)

    def part(self, node_name, mesh, mat_name, t=(0, 0, 0), r=(0, 0, 0), s=(1, 1, 1), parent=None):
        """添加部件；parent 为另一部件节点名（该节点成为其父级，t/r/s 为相对父级）"""
        self.parts.append(dict(node=node_name, mesh=mesh, mat=mat_name, trs=(t, r, s),
                               parent=parent))
        return self

    def anim(self, name, node_name, path, keys):
        """keys=[(time, value)]；path: 'rotation'(欧拉角度数) / 'translation'(米)"""
        self.animations.append(dict(name=name, node=node_name, path=path, keys=keys))
        return self

    def col(self, t, size, r=(0, 0, 0)):
        """添加 -colonly 碰撞代理盒（Godot 导入为纯碰撞）"""
        self.parts.append(dict(node=self.name + "-colonly", mesh=box(*size),
                               mat="__col", trs=(t, r, (1, 1, 1))))
        return self

    def save(self, path):
        W = _GlbWriter(self)
        W.save(path)
        return path


class _GlbWriter:
    def __init__(self, prop):
        self.prop = prop
        self.bin = bytearray()
        self.accessors = []
        self.bufferViews = []
        self.images = []
        self.textures = []
        self.samplers = [dict(magFilter=9729, minFilter=9987, wrapS=10497, wrapT=10497)]
        self._tex_map = {}
        self._mat_map = {}

    def _view(self, data):
        while len(self.bin) % 4:
            self.bin.append(0)
        off = len(self.bin)
        self.bin += data
        self.bufferViews.append(dict(buffer=0, byteOffset=off, byteLength=len(data)))
        return len(self.bufferViews) - 1

    def _acc_f(self, vals, typ):
        """float 数组 accessor（vals: [ [..],[..] ] 或 flat 数值列表）"""
        flat = []
        for v in vals:
            if isinstance(v, (list, tuple)):
                flat += list(v)
            else:
                flat.append(v)
        bv = self._view(struct.pack("<%df" % len(flat), *flat))
        acc = dict(bufferView=bv, componentType=5126, count=len(vals), type=typ)
        if typ != "SCALAR":
            dim = {"VEC2": 2, "VEC3": 3, "VEC4": 4}[typ]
            acc["min"] = [min(v[i] for v in vals) for i in range(dim)]
            acc["max"] = [max(v[i] for v in vals) for i in range(dim)]
        else:
            acc["min"] = [min(vals)]
            acc["max"] = [max(vals)]
        self.accessors.append(acc)
        return len(self.accessors) - 1

    def _acc_u(self, vals):
        bv = self._view(b"".join(struct.pack("<I", v) for v in vals))
        self.accessors.append(dict(bufferView=bv, componentType=5125,
                                   count=len(vals), type="SCALAR"))
        return len(self.accessors) - 1

    def _tex_id(self, tex_name):
        if tex_name in self._tex_map:
            return self._tex_map[tex_name]
        png = MATLIB.textures.get(tex_name)
        if png is None:
            raise RuntimeError("贴图未注册: " + tex_name)
        bv = self._view(png)
        self.images.append(dict(bufferView=bv, mimeType="image/png", name=tex_name))
        tid = len(self.textures)
        self.textures.append(dict(source=len(self.images) - 1, sampler=0))
        self._tex_map[tex_name] = tid
        return tid

    def _mat_id(self, mat_name):
        if mat_name in self._mat_map:
            return self._mat_map[mat_name]
        if mat_name in ("__col", "M_Col"):
            mj = dict(name="M_Col", pbrMetallicRoughness=dict(
                baseColorFactor=[0, 0, 0, 1], metallicFactor=0, roughnessFactor=1))
        else:
            m = MATLIB.mats[mat_name]
            mr = dict(baseColorFactor=m["color"], metallicFactor=m["metal"],
                      roughnessFactor=m["rough"])
            mj = dict(name=mat_name, pbrMetallicRoughness=mr, doubleSided=bool(m["double"]))
            if m["emissive"]:
                mj["emissiveFactor"] = m["emissive"]
            if m["alpha"] == "MASK":
                mj["alphaMode"] = "MASK"
                mj["alphaCutoff"] = m["cutoff"]
            elif m["alpha"] == "BLEND":
                mj["alphaMode"] = "BLEND"
            if m["tex"]:
                mr["baseColorTexture"] = dict(index=self._tex_id(m["tex"]))
        self._mat_map[mat_name] = len(self._mat_map)
        self.materials.append(mj)
        return self._mat_map[mat_name]

    def save(self, path):
        self.materials = []
        meshes_json, nodes_json = [], []
        node_index = {}
        root_children = []
        children_map = {}  # parent_name -> [child_name]

        # 1) 收集节点（避免同名 part 冲突——自动加后缀）
        used = {}
        for p in self.prop.parts:
            n = p["node"]
            used[n] = used.get(n, 0) + 1
            if used[n] > 1:
                p["node"] = "%s_%d" % (n, used[n])
            if p.get("parent"):
                children_map.setdefault(p["parent"], []).append(p["node"])

        def ensure_node(nname, trs=None):
            """确保节点存在（可为空节点）；返回索引"""
            if nname not in node_index:
                node_index[nname] = len(nodes_json)
                nodes_json.append(self._node_json(nname, trs or ((0, 0, 0), (0, 0, 0), (1, 1, 1))))
                root_children.append(nname)
            return node_index[nname]

        for p in self.prop.parts:
            ensure_node(p["node"], p["trs"])
        # 父节点可能只是纯枢轴（无网格）
        for pname in list(children_map.keys()):
            ensure_node(pname)

        # 2) 每个 part 一个 mesh
        for p in self.prop.parts:
            mesh = p["mesh"]
            prim = dict(
                attributes=dict(
                    POSITION=self._acc_f(mesh.pos, "VEC3"),
                    NORMAL=self._acc_f(mesh.nor, "VEC3"),
                    TEXCOORD_0=self._acc_f(mesh.uv, "VEC2"),
                ),
                indices=self._acc_u(mesh.idx),
                material=self._mat_id(p["mat"]),
                mode=4,
            )
            nodes_json[node_index[p["node"]]]["mesh"] = len(meshes_json)
            meshes_json.append(dict(name=p["node"], primitives=[prim]))

        # 2.5) 父子关系
        for pname, kids in children_map.items():
            pi = node_index[pname]
            nodes_json[pi].setdefault("children", [])
            for k in kids:
                ki = node_index[k]
                nodes_json[pi]["children"].append(ki)
                if k in root_children:
                    root_children.remove(k)

        # 3) 动画
        anims_json = []
        for a in self.prop.animations:
            nname = a["node"]
            ensure_node(nname)
            ni = node_index[nname]
            times = [k[0] for k in a["keys"]]
            ti = self._acc_f(times, "SCALAR")
            if a["path"] == "rotation":
                vals = [quat_from_euler(*k[1]) for k in a["keys"]]
                vi = self._acc_f(vals, "VEC4")
                nodes_json[ni].setdefault("rotation", quat_from_euler(*a["keys"][0][1]))
            else:
                vals = [list(k[1]) for k in a["keys"]]
                vi = self._acc_f(vals, "VEC3")
                nodes_json[ni].setdefault("translation", list(a["keys"][0][1]))
            samplers = [dict(input=ti, output=vi, interpolation="LINEAR")]
            channels = [dict(sampler=0, target=dict(node=ni, path=a["path"]))]
            anims_json.append(dict(name=a["name"], channels=channels, samplers=samplers))

        # 4) 根节点
        root = dict(name=self.prop.name, children=[node_index[c] for c in root_children])
        gltf = dict(
            asset=dict(version="2.0", generator="shen-jia-glblib 1.0"),
            scene=0,
            scenes=[dict(name=self.prop.name, nodes=[len(nodes_json)])],
            nodes=nodes_json + [root],
            meshes=meshes_json,
            materials=self.materials,
            accessors=self.accessors,
            bufferViews=self.bufferViews,
            buffers=[dict(byteLength=len(self.bin))],
        )
        if self.images:
            gltf["images"] = self.images
            gltf["textures"] = self.textures
            gltf["samplers"] = self.samplers
        if anims_json:
            gltf["animations"] = anims_json

        # 5) 打包 GLB
        bj = json.dumps(gltf, separators=(",", ":"), ensure_ascii=False).encode("utf-8")
        while len(bj) % 4:
            bj += b" "
        while len(self.bin) % 4:
            self.bin.append(0)
        total = 12 + 8 + len(bj) + 8 + len(self.bin)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", 0x46546C67, 2, total))
            f.write(struct.pack("<II", len(bj), 0x4E4F534A))
            f.write(bj)
            f.write(struct.pack("<II", len(self.bin), 0x004E4942))
            f.write(self.bin)

    def _node_json(self, name, trs):
        t, r, s = trs
        nd = dict(name=name)
        if any(abs(v) > 1e-9 for v in t):
            nd["translation"] = list(t)
        if any(abs(v) > 1e-9 for v in r):
            nd["rotation"] = quat_from_euler(*r)
        if any(abs(v - 1) > 1e-9 for v in s):
            nd["scale"] = list(s)
        return nd

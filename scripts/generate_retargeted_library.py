"""Retarget Tripo preset clips between characters that share the 41-bone Tripo legacy
biped skeleton but have different bind poses (e.g. Nadiya A-pose -> Mara T-pose).

No Tripo credits are used. Rotation retarget in world space:
    W_tgt(t) = W_src(t) * W_src_rest^-1 * W_tgt_rest
Hip translation delta is rotated into the target parent frame and scaled by hip height.

Usage:
    python scripts/generate_retargeted_library.py TARGET.glb OUT.glb CLIP.glb [CLIP.glb ...]
The target's own clips are kept; retargeted clips are appended (in place, 30 fps, linear).
"""
import struct
import sys

import numpy as np
import pygltflib
from scipy.spatial.transform import Rotation as R
from scipy.spatial.transform import Slerp

FPS = 30.0


def _read(g, blob, idx):
    acc = g.accessors[idx]
    bv = g.bufferViews[acc.bufferView]
    ncomp = {"SCALAR": 1, "VEC3": 3, "VEC4": 4, "MAT4": 16}[acc.type]
    dt = {5126: np.float32}[acc.componentType]
    start = (bv.byteOffset or 0) + (acc.byteOffset or 0)
    stride = bv.byteStride or ncomp * 4
    raw = np.frombuffer(blob, dtype=np.uint8, count=stride * (acc.count - 1) + ncomp * 4, offset=start)
    out = np.lib.stride_tricks.as_strided(raw.view(np.uint8), shape=(acc.count, ncomp * 4), strides=(stride, 1))
    return np.ascontiguousarray(out).view(dt).reshape(acc.count, ncomp)


class Rig:
    def __init__(self, path):
        self.g = pygltflib.GLTF2().load(path)
        self.blob = self.g.binary_blob()
        g = self.g
        self.joints = g.skins[0].joints
        self.name = {j: g.nodes[j].name for j in self.joints}
        self.by_name = {v: k for k, v in self.name.items()}
        self.parent = {}
        for i, n in enumerate(g.nodes):
            for c in n.children or []:
                self.parent[c] = i
        self.rest_q = {i: np.array(n.rotation or [0, 0, 0, 1.0]) for i, n in enumerate(g.nodes)}
        self.rest_t = {i: np.array(n.translation or [0, 0, 0.0]) for i, n in enumerate(g.nodes)}
        self.rest_world = {}
        for j in self.joints:
            self.rest_world[j] = self.world_rest(j)

    def world_rest(self, node):
        q = R.from_quat(self.rest_q[node])
        p = self.parent.get(node)
        while p is not None:
            q = R.from_quat(self.rest_q[p]) * q
            p = self.parent.get(p)
        return q

    def world_rest_pos(self, node):
        pos = np.zeros(3)
        chain = []
        n = node
        while n is not None:
            chain.append(n)
            n = self.parent.get(n)
        rot = R.identity()
        for n in reversed(chain):
            pos = pos + rot.apply(self.rest_t[n])
            rot = rot * R.from_quat(self.rest_q[n])
        return pos

    def clip(self, anim_index=0):
        g = self.g
        a = g.animations[anim_index]
        dur = max(g.accessors[s.input].max[0] for s in a.samplers)
        times = np.arange(0, dur + 1e-6, 1.0 / FPS)
        rot, trans = {}, {}
        for ch in a.channels:
            s = a.samplers[ch.sampler]
            t = _read(g, self.blob, s.input)[:, 0]
            v = _read(g, self.blob, s.output)
            tt = np.clip(times, t[0], t[-1])
            if ch.target.path == "rotation":
                rot[ch.target.node] = Slerp(t, R.from_quat(v))(tt) if len(t) > 1 else R.from_quat(np.repeat(v, len(times), 0))
            elif ch.target.path == "translation":
                trans[ch.target.node] = np.stack([np.interp(tt, t, v[:, k]) for k in range(3)], 1)
        return a.name, times, rot, trans


def retarget(src, tgt, clip_index=0):
    name, times, rot, trans = src.clip(clip_index)
    n = len(times)
    out_rot, out_trans = {}, {}
    # world rotations of source per joint (joints are listed parent-first in Tripo exports; resolve recursively)
    src_world = {}

    def sw(j):
        if j in src_world:
            return src_world[j]
        local = rot.get(j, R.from_quat(np.repeat(src.rest_q[j][None], n, 0)))
        p = src.parent.get(j)
        if p in src.name:
            w = sw(p) * local
        else:
            w = (src.world_rest(p) if p is not None else R.identity()) * local
        src_world[j] = w
        return w

    tgt_world = {}
    for tj in sorted(tgt.joints, key=lambda j: _depth(tgt, j)):
        bname = tgt.name[tj]
        sj = src.by_name.get(bname)
        if sj is None:
            continue
        w_t = sw(sj) * src.rest_world[sj].inv() * tgt.rest_world[tj]
        tgt_world[tj] = w_t
        p = tgt.parent.get(tj)
        pw = tgt_world[p] if p in tgt_world else (tgt.world_rest(p) if p is not None else R.identity())
        out_rot[tj] = (pw.inv() * w_t).as_quat()
    # hip translation
    s_hip, t_hip = src.by_name.get("Hip"), tgt.by_name.get("Hip")
    if s_hip in trans and t_hip is not None:
        ratio = tgt.world_rest_pos(t_hip)[1] / max(src.world_rest_pos(s_hip)[1], 1e-4)
        sp = src.parent.get(s_hip)
        tp = tgt.parent.get(t_hip)
        delta = trans[s_hip] - src.rest_t[s_hip]
        delta_world = src.world_rest(sp).apply(delta) if sp is not None else delta
        delta_tgt = tgt.world_rest(tp).inv().apply(delta_world * ratio) if tp is not None else delta_world * ratio
        out_trans[t_hip] = tgt.rest_t[t_hip] + delta_tgt
    return name, times, out_rot, out_trans


def _depth(rig, j):
    d = 0
    while j in rig.parent:
        j = rig.parent[j]
        d += 1
    return d


def append_clips(tgt, clips, out_path):
    g = tgt.g
    blob = bytearray(tgt.blob)

    def add(arr, typ, minmax=False):
        nonlocal blob
        while len(blob) % 4:
            blob.append(0)
        data = np.ascontiguousarray(arr, dtype=np.float32).tobytes()
        g.bufferViews.append(pygltflib.BufferView(buffer=0, byteOffset=len(blob), byteLength=len(data)))
        blob.extend(data)
        acc = pygltflib.Accessor(bufferView=len(g.bufferViews) - 1, componentType=5126, count=len(arr), type=typ)
        if minmax:
            acc.min = [float(arr.min())]
            acc.max = [float(arr.max())]
        g.accessors.append(acc)
        return len(g.accessors) - 1

    for name, times, rots, transs in clips:
        ti = add(times.astype(np.float32), "SCALAR", True)
        samplers, channels = [], []
        for node, q in rots.items():
            q = np.asarray(q, np.float32)
            # keep quaternion hemisphere continuous
            for k in range(1, len(q)):
                if np.dot(q[k], q[k - 1]) < 0:
                    q[k] = -q[k]
            samplers.append(pygltflib.AnimationSampler(input=ti, output=add(q, "VEC4"), interpolation="LINEAR"))
            channels.append(pygltflib.AnimationChannel(sampler=len(samplers) - 1, target=pygltflib.AnimationChannelTarget(node=node, path="rotation")))
        for node, t in transs.items():
            samplers.append(pygltflib.AnimationSampler(input=ti, output=add(np.asarray(t, np.float32), "VEC3"), interpolation="LINEAR"))
            channels.append(pygltflib.AnimationChannel(sampler=len(samplers) - 1, target=pygltflib.AnimationChannelTarget(node=node, path="translation")))
        g.animations.append(pygltflib.Animation(name=name, samplers=samplers, channels=channels))
    g.buffers[0].byteLength = len(blob)
    g.set_binary_blob(bytes(blob))
    g.save_binary(out_path)


def main():
    target, out, *clip_files = sys.argv[1:]
    tgt = Rig(target)
    existing = {a.name for a in tgt.g.animations}
    clips = []
    for f in clip_files:
        src = Rig(f)
        for i, a in enumerate(src.g.animations):
            if a.name in existing:
                print(f"[SKIP] {a.name} already in target")
                continue
            clips.append(retarget(src, tgt, i))
            print(f"[RETARGET] {a.name} from {f} ({len(clips[-1][1])} frames)")
    append_clips(tgt, clips, out)
    print(f"[SAVED] {out}")


if __name__ == "__main__":
    main()

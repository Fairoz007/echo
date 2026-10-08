"""Read-only GLB inventory. Does not import, generate, or approve assets."""
import argparse
import hashlib
import json
from pathlib import Path
import struct


def inspect(path):
    data = path.read_bytes()
    magic, version, length = struct.unpack_from('<III', data)
    if magic != 0x46546C67 or version != 2 or length != len(data):
        raise ValueError(f'Invalid GLB header: {path}')
    size, kind = struct.unpack_from('<II', data, 12)
    if kind != 0x4E4F534A:
        raise ValueError(f'First chunk is not JSON: {path}')
    gltf = json.loads(data[20:20 + size])
    accessors = gltf.get('accessors', [])
    triangles = 0
    bounds = []
    for mesh in gltf.get('meshes', []):
        for primitive in mesh['primitives']:
            if primitive.get('mode', 4) == 4:
                count = accessors[primitive['indices']]['count'] if 'indices' in primitive else accessors[primitive['attributes']['POSITION']]['count']
                triangles += count // 3
            position = accessors[primitive['attributes']['POSITION']]
            bounds.append({'min': position.get('min'), 'max': position.get('max')})
    return {
        'path': path.as_posix(), 'sha256': hashlib.sha256(data).hexdigest(),
        'bytes': len(data), 'source_triangles': triangles,
        'mesh_local_bounds': bounds,
        'animations': [item.get('name', '') for item in gltf.get('animations', [])],
        'skins': len(gltf.get('skins', [])),
        'materials': len(gltf.get('materials', [])),
        'images': [item.get('uri', 'embedded') for item in gltf.get('images', [])],
        'mesh_node_transforms': [{key: value for key, value in item.items() if key in ('name', 'mesh', 'matrix', 'translation', 'rotation', 'scale')} for item in gltf.get('nodes', []) if 'mesh' in item],
        'approval_status': 'QA',
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--root', default='assets')
    parser.add_argument('--output')
    args = parser.parse_args()
    records = [inspect(path) for path in sorted(Path(args.root).rglob('*.glb'))]
    result = json.dumps({'scope': 'source metadata only; no rendered or gameplay validation', 'assets': records}, indent=2)
    if args.output:
        Path(args.output).write_text(result + '\n', encoding='utf-8')
    else:
        print(result)

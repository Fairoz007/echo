# Blender CLI LOD builder: blender -b --python scripts/generate_lods_blender.py -- SRC.glb OUT_BASE MAX_TEX TRI1,TRI2,...
# Decimate modifier (collapse) preserves UVs, skin weights and animations; textures capped at MAX_TEX.
import bpy,sys
a=sys.argv[sys.argv.index('--')+1:]; src,outbase,maxtex=a[0],a[1],int(a[2]); targets=[int(x) for x in a[3].split(',')]
for i,tgt in enumerate(targets):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    for im in bpy.data.images:
        if im.size[0]>maxtex: im.scale(maxtex,maxtex)
    for o in [o for o in bpy.data.objects if o.type=='MESH']:
        tris=sum(len(p.vertices)-2 for p in o.data.polygons)
        if tris>tgt:
            m=o.modifiers.new('dec','DECIMATE'); m.ratio=tgt/tris
            bpy.context.view_layer.objects.active=o; bpy.ops.object.modifier_apply(modifier='dec')
        print('LOD',i,o.name,sum(len(p.vertices)-2 for p in o.data.polygons))
    bpy.ops.export_scene.gltf(filepath=f"{outbase}_LOD{i}.glb",export_format='GLB',export_image_format='JPEG',export_animations=True)

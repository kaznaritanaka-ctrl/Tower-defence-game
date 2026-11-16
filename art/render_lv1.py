"""Render the Lv1 preview from imported KayKit meshes and project-specific parts.

Run: blender -b -t 2 --python art/render_lv1.py -- --sprites --scene
The download manifest records the upstream meshes and their licenses.
No generative-image model is involved in this reproducible render pipeline.
"""
import argparse
import json
import math
import random
import sys
from pathlib import Path

import bpy
from mathutils import Vector, Matrix
from bpy_extras.object_utils import world_to_camera_view

ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'art' / 'source-assets'
OUTPUT = ROOT / 'prototypes' / 'assets' / 'lv1'
GENERATED = ROOT / 'art' / 'generated'
ELEVATION = math.asin(.47)
TEMPLATES = {}
MATERIALS = {}


def material(name, color, roughness=.8, metallic=0, emission=0):
    if name in MATERIALS:
        return MATERIALS[name]
    mat = bpy.data.materials.new(name)
    mat.diffuse_color = (*color, 1)
    mat.use_nodes = True
    bsdf = mat.node_tree.nodes.get('Principled BSDF')
    bsdf.inputs['Base Color'].default_value = (*color, 1)
    bsdf.inputs['Roughness'].default_value = roughness
    bsdf.inputs['Metallic'].default_value = metallic
    if emission:
        bsdf.inputs['Emission Color'].default_value = (*color, 1)
        bsdf.inputs['Emission Strength'].default_value = emission
    MATERIALS[name] = mat
    return mat


def palette():
    return {
        'stone': material('blue-grey stone', (.19, .235, .285)),
        'light_stone': material('worn stone edges', (.29, .34, .38)),
        'dark_stone': material('cavern slate', (.075, .105, .14)),
        'floor': material('stone paving', (.19, .225, .26)),
        'wood': material('aged brown wood', (.20, .115, .065)),
        'iron': material('dark iron', (.075, .105, .13), .45, .65),
        'bronze': material('antique bronze', (.32, .18, .065), .45, .65),
        'amber': material('amber magic', (1, .39, .055), .3, .15, 2.3),
        'gold': material('amber reflection', (.95, .52, .12), .35, .6),
        'skin': material('kobold warm fur', (.28, .20, .115)),
        'snout': material('kobold muzzle', (.42, .33, .20)),
        'leather': material('miners leather', (.15, .105, .065)),
        'eye': material('deep eyes', (.012, .018, .022), .3),
        'steel': material('pickaxe steel', (.31, .39, .44), .45, .7),
        'green': material('elf cloak', (.085, .22, .16)),
        'elf_skin': material('elf ears', (.58, .38, .23)),
        'blue': material('mage robes', (.12, .15, .29)),
    }


def all_children(root):
    return [root, *root.children_recursive]


def bounds(objects):
    points = [obj.matrix_world @ Vector(corner) for obj in objects if obj.type == 'MESH' for corner in obj.bound_box]
    if not points:
        return Vector((0, 0, 0)), Vector((1, 1, 1))
    return Vector(tuple(min(p[i] for p in points) for i in range(3))), Vector(tuple(max(p[i] for p in points) for i in range(3)))


def find_asset(name):
    paths = list(SOURCE.rglob(name))
    if not paths:
        return None
    return paths[0]


def load_template(filename):
    if filename in TEMPLATES:
        return TEMPLATES[filename]
    path = find_asset(filename)
    if path is None:
        raise FileNotFoundError(f'Asset missing: {filename}')
    before = set(bpy.data.objects)
    bpy.ops.import_scene.gltf(filepath=str(path))
    objects = list(set(bpy.data.objects) - before)
    # Blender's importer creates a mesh for custom bone controls. It is not part
    # of the supplied character and must never be instantiated as visible art.
    control_shapes = {bone.custom_shape for obj in objects if obj.type == 'ARMATURE'
                      for bone in obj.pose.bones if bone.custom_shape}
    for obj in control_shapes:
        obj.hide_render = True
    objects = [obj for obj in objects if obj not in control_shapes]
    group = bpy.data.objects.new('SOURCE ' + filename, None)
    bpy.context.scene.collection.objects.link(group)
    for obj in objects:
        if obj.parent not in objects:
            obj.parent = group
    bpy.context.view_layer.update()
    lower, upper = bounds(objects)
    group.location = (-(lower.x + upper.x) / 2, -(lower.y + upper.y) / 2, -lower.z)
    bpy.context.view_layer.update()
    for obj in [group, *objects]:
        obj.hide_render = True
    TEMPLATES[filename] = (group, [group, *objects], upper - lower)
    return TEMPLATES[filename]


def asset(filename, pos=(0, 0, 0), size=None, height=None, rotation=0, mat=None):
    original, objects, dimensions = load_template(filename)
    clones = {}
    for obj in objects:
        clone = obj.copy()
        bpy.context.scene.collection.objects.link(clone)
        clone.hide_render = False
        clone.hide_viewport = False
        clones[obj] = clone
    for obj, clone in clones.items():
        clone.parent = clones.get(obj.parent)
        for modifier in clone.modifiers:
            if modifier.type == 'ARMATURE' and modifier.object in clones:
                modifier.object = clones[modifier.object]
        if mat and clone.type == 'MESH':
            clone.data = clone.data.copy()
            clone.data.materials.clear()
            clone.data.materials.append(mat)
    wrapper = bpy.data.objects.new('Placed ' + filename, None)
    bpy.context.scene.collection.objects.link(wrapper)
    clones[original].parent = wrapper
    if size:
        wrapper.scale = tuple(size[i] / max(dimensions[i], .0001) for i in range(3))
    elif height:
        wrapper.scale = (height / max(dimensions.z, .0001),) * 3
    wrapper.rotation_euler.z = rotation
    wrapper.location = pos
    return wrapper


def cube(name, pos, size, mat, bevel=.03):
    bpy.ops.mesh.primitive_cube_add(size=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.dimensions = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        mod = obj.modifiers.new('worn edges', 'BEVEL')
        mod.width = bevel
        mod.segments = 1
        obj.modifiers.new('weighted normals', 'WEIGHTED_NORMAL')
    obj.data.materials.append(mat)
    return obj


def cylinder(name, pos, radius, depth, mat, vertices=10):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.data.materials.append(mat)
    return obj


def ico(name, pos, scale, mat, subdivisions=1):
    bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=subdivisions, radius=1, location=pos)
    obj = bpy.context.object
    obj.name = name
    obj.scale = scale
    obj.data.materials.append(mat)
    return obj


def rod(name, a, b, radius, mat, vertices=8):
    direction = Vector(b) - Vector(a)
    obj = cylinder(name, (Vector(a) + Vector(b)) / 2, radius, direction.length, mat, vertices)
    obj.rotation_euler = direction.to_track_quat('Z', 'Y').to_euler()
    return obj


def mesh(name, vertices, faces, mat):
    data = bpy.data.meshes.new(name)
    data.from_pydata(vertices, [], faces)
    data.materials.append(mat)
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    return obj


def crystal(name, pos, radius=.15, height=.75, mat=None):
    x, y, z = pos
    vertices = [(x, y, z + height), (x, y, z)]
    vertices += [(x + radius * math.cos(i * math.tau / 5), y + radius * math.sin(i * math.tau / 5), z + height * .32) for i in range(5)]
    faces = [(0, i + 2, (i + 1) % 5 + 2) for i in range(5)] + [(1, (i + 1) % 5 + 2, i + 2) for i in range(5)]
    return mesh(name, vertices, faces, mat or palette()['amber'])


def add_light(name, pos, energy, color, size=1, kind='AREA'):
    data = bpy.data.lights.new(name, kind)
    data.energy = energy
    data.color = color
    if kind == 'AREA':
        data.shape = 'DISK'
        data.size = size
    else:
        data.shadow_soft_size = size
    obj = bpy.data.objects.new(name, data)
    bpy.context.scene.collection.objects.link(obj)
    obj.location = pos
    obj.rotation_euler = (Vector((0, 0, .4)) - obj.location).to_track_quat('-Z', 'Y').to_euler()
    return obj


def setup_scene(width=384, height=384, full=False):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    TEMPLATES.clear()
    MATERIALS.clear()
    scene = bpy.context.scene
    scene.render.engine = 'CYCLES'
    scene.cycles.device = 'CPU'
    scene.cycles.samples = 96 if full else 64
    # The execution image's Blender build has no OpenImageDenoise support.
    scene.cycles.use_denoising = False
    scene.cycles.use_adaptive_sampling = True
    scene.cycles.adaptive_threshold = .05
    scene.cycles.max_bounces = 4
    scene.render.threads_mode = 'FIXED'
    scene.render.threads = 2
    scene.render.resolution_x = width
    scene.render.resolution_y = height
    scene.render.resolution_percentage = 100
    scene.render.film_transparent = not full
    scene.render.image_settings.file_format = 'PNG'
    scene.render.image_settings.color_mode = 'RGBA'
    scene.render.image_settings.color_depth = '8'
    scene.render.image_settings.compression = 90
    scene.view_settings.view_transform = 'AgX'
    scene.view_settings.look = 'AgX - Medium High Contrast'
    scene.view_settings.exposure = -.65 if full else .35
    world = bpy.data.worlds.new('Deep cavern')
    world.use_nodes = True
    world.node_tree.nodes['Background'].inputs['Color'].default_value = (.028, .045, .075, 1) if full else (.11, .16, .24, 1)
    world.node_tree.nodes['Background'].inputs['Strength'].default_value = .16 if full else .35
    scene.world = world
    camera_data = bpy.data.cameras.new('Orthographic game camera')
    camera_data.type = 'ORTHO'
    camera_data.ortho_scale = 16 if full else 3.4
    camera = bpy.data.objects.new('Orthographic game camera', camera_data)
    scene.collection.objects.link(camera)
    target = Vector((4.5, -3.5, .35) if full else (0, 0, .9))
    camera.location = target + Vector((12, -12, 12 * math.sqrt(2) * math.tan(ELEVATION)))
    camera.rotation_euler = (target - camera.location).to_track_quat('-Z', 'Y').to_euler()
    scene.camera = camera
    if full:
        add_light('cool overhead cavern bounce', (2, -2, 9), 650, (.58, .71, 1), 8)
        add_light('soft front bounce', (10, -11, 8), 280, (.64, .74, 1), 9)
        add_light('warm side bounce', (-3, -7, 6), 250, (1, .58, .28), 7)
        add_light('archer watchlight', (2, -5, 4), 90, (1, .68, .40), 3)
    else:
        add_light('cool overhead', (-3, -2, 7), 360, (.65, .77, 1), 5)
        add_light('warm front bounce', (4, -5, 4), 200, (1, .72, .43), 5)
        add_light('blue edge light', (1, 4, 4), 180, (.35, .52, 1), 4)
    return scene


def floor(pos=(0, 0, 0)):
    p = palette()
    return asset('floor_tile_small.glb', (pos[0], pos[1], pos[2] - .10), size=(.995, .995, .10), mat=p['floor'])


def wall(pos=(0, 0, 0), level=1):
    p = palette()
    return asset('wall_half.glb', pos, size=(.34, .95, .62 if level == 1 else .82), mat=p['stone'])


def well(pos=(0, 0, 0)):
    x, y, z = pos
    p = palette()
    asset('floor_foundation_allsides.glb', (x, y, z), size=(.95, .95, .20), mat=p['stone'])
    cylinder('sunken shaft', (x, y, z + .21), .31, .045, p['iron'], 12)
    for i in range(8):
        a = i * math.tau / 8
        obj = cube('bronze conduit rim', (x + math.cos(a) * .36, y + math.sin(a) * .36, z + .24), (.23, .12, .10), p['bronze'], .015)
        obj.rotation_euler.z = a + math.pi / 2
    crystal('amber mana crystal', (x, y, z + .23), .145, .77)
    for a in (0, 2.1, 4.2):
        crystal('small mana shard', (x + .26 * math.cos(a), y + .26 * math.sin(a), z + .21), .045, .20)
    add_light('amber well glow', (x, y, z + .58), 32, (1, .30, .045), .32, 'POINT')


def tower_base(pos=(0, 0, 0), level=1):
    x, y, z = pos
    p = palette()
    height = 1.0 if level == 1 else 1.17
    asset('floor_foundation_allsides.glb', (x, y, z), size=(.91, .91, height), mat=p['stone'])
    asset('floor_wood_large_dark.glb', (x, y, z + height), size=(.96, .96, .10), mat=p['wood'])
    for dx, dy in [(-.4, .37), (.4, .37)]:
        cube('tower corner cap', (x + dx, y + dy, z + height + .19), (.18, .2, .20), p['light_stone'])
    rod('tower front cross brace', (x - .38, y - .46, z + .15), (x + .38, y - .46, z + height - .12), .035, p['wood'])
    rod('ladder left stile', (x + .50, y - .20, z + .04), (x + .50, y - .20, z + height), .025, p['wood'])
    rod('ladder right stile', (x + .50, y + .18, z + .04), (x + .50, y + .18, z + height), .025, p['wood'])
    for i in range(5):
        zz = z + .13 + i * height / 5
        rod('ladder rung', (x + .50, y - .20, zz), (x + .50, y + .18, zz), .022, p['wood'])
    return z + height + .10


def choose_character(kind):
    names = ['Ranger.glb', 'ranger.glb', 'Ranger.gltf'] if kind == 'archer' else ['Mage.glb', 'mage.glb', 'Mage.gltf']
    for name in names:
        if find_asset(name):
            return name
    return None


def character(kind, pos, height=.90):
    filename = choose_character(kind)
    if filename is None:
        raise FileNotFoundError('Actual character asset is required for ' + kind)
    root = asset(filename, pos, height=height, rotation=0)
    if find_asset('Rig_Medium_CombatRanged.glb'):
        load_template('Rig_Medium_CombatRanged.glb')
    armatures = [obj for obj in root.children_recursive if obj.type == 'ARMATURE']
    for rig in armatures:
        if rig.animation_data:
            rig.animation_data_clear()
        desired = 'Ranged_Bow_Aiming_Idle' if kind == 'archer' else 'Ranged_Magic_Spellcasting'
        actions = [action for action in bpy.data.actions if desired.lower() in action.name.lower()]
        if not actions:
            actions = [action for action in bpy.data.actions if 'idle' in action.name.lower() and not any(word in action.name.lower() for word in ['combat', 'sitting', 'crouch'])]
        if actions:
            rig.animation_data_create()
            rig.animation_data.action = actions[0]
            bpy.context.scene.frame_set(int(actions[0].frame_range[0]) + 6)
        else:
            # Static, relaxed ready pose; no shooting animation is claimed.
            for bone_name, angle in [('upperarm.l', 38), ('upperarm.r', -62)]:
                bone = rig.pose.bones.get(bone_name)
                if bone:
                    old = bone.matrix.copy()
                    changed = (Matrix.Rotation(math.radians(angle), 4, 'Y') @ old.to_3x3().to_4x4())
                    changed.translation = old.translation
                    bone.matrix = changed
                    bpy.context.view_layer.update()
    return root


def equip_bow(character_root, filename, hand_name='handslot.l', upright=True):
    rig = next(obj for obj in character_root.children_recursive if obj.type == 'ARMATURE')
    hand = rig.pose.bones.get(hand_name)
    bow = asset(filename)
    # Equipment origins are authored at the grip, so undo the bounding-box
    # normalization used for freestanding props and keep the supplied origin.
    template_clone = bow.children[0]
    template_clone.location = (0, 0, 0)
    bpy.context.view_layer.update()
    # glTF's weapon long axis becomes local Y in Blender; rotate it into the
    # upright bow plane at the left-hand socket.
    bow.matrix_world = rig.matrix_world @ hand.matrix @ Matrix.Rotation(math.pi / 2 if upright else 0, 4, 'X')
    return bow


def archer(pos=(0, 0, 0), level=1):
    x, y, z = pos
    top = tower_base(pos, level)
    ranger = character('archer', (x, y, top), 1.02)
    # The ear silhouettes and bow placement are project-specific additions.
    p = palette()
    for sign in [-1, 1]:
        mesh('elf pointed ear', [(x + sign * .12, y, top + .68), (x + sign * .28, y + .015, top + .76), (x + sign * .13, y - .04, top + .63)], [(0, 1, 2)], p['elf_skin'])
    bowfile = next((name for name in ['bow_withString.gltf', 'bow.glb', 'bow.gltf', 'Bow.glb'] if find_asset(name)), None)
    if bowfile:
        equip_bow(ranger, bowfile)
        if find_asset('arrow_bow.gltf'):
            equip_bow(ranger, 'arrow_bow.gltf', 'handslot.r', False)
    else:
        pts = [(x + .31, y - .13, top + .24), (x + .42, y - .13, top + .39), (x + .43, y - .13, top + .55), (x + .31, y - .13, top + .70)]
        for a, b in zip(pts, pts[1:]):
            rod('original curved bow limb', a, b, .018, p['wood'])
        rod('bow string', pts[0], pts[-1], .004, p['light_stone'], 4)
    return ranger


def mage(pos=(0, 0, 0), level=1):
    x, y, z = pos
    top = tower_base(pos, level)
    if choose_character('mage'):
        character('mage', (x, y, top), .95)
    else:
        p = palette()
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=.20, radius2=.105, depth=.48, location=(x, y, top + .30))
        bpy.context.object.data.materials.append(p['blue'])
        ico('original mage head', (x, y, top + .65), (.13, .12, .15), p['elf_skin'], 2)
        bpy.ops.mesh.primitive_cone_add(vertices=8, radius1=.21, radius2=0, depth=.34, location=(x, y, top + .87))
        bpy.context.object.data.materials.append(p['blue'])
    rod('mage staff', (x + .29, y, top), (x + .29, y, top + .93), .022, palette()['wood'])
    crystal('mage amber focus', (x + .29, y, top + .89), .07, .21)


def deposit(pos=(0, 0, 0), large=False):
    x, y, z = pos
    p = palette()
    asset('rubble_large.glb', pos, size=(1.05, .96, .72 if not large else 1.4), mat=p['dark_stone'])
    if not large:
        for dx, dy, zz in [(-.23, -.23, .48), (.15, -.18, .42), (.33, .12, .32)]:
            ico('copper-rich ore', (x + dx, y + dy, z + zz), (.105, .07, .09), p['bronze'])


def kobold(pos=(0, 0, 0)):
    x, y, z = pos
    p = palette()
    # Original low-poly worker, identifiable by muzzle, ears, tail and pickaxe.
    ico('kobold torso', (x, y, z + .28), (.12, .10, .18), p['leather'], 2)
    ico('kobold head', (x, y - .02, z + .55), (.15, .13, .16), p['skin'], 2)
    ico('kobold projecting muzzle', (x, y - .13, z + .51), (.11, .13, .075), p['snout'])
    ico('kobold nose', (x, y - .23, z + .53), (.045, .03, .03), p['eye'])
    for sign in [-1, 1]:
        mesh('kobold triangular ear', [(x + sign * .08, y + .005, z + .60), (x + sign * .21, y + .03, z + .79), (x + sign * .15, y - .06, z + .55)], [(0, 1, 2)], p['skin'])
        ico('kobold bright eye', (x + sign * .09, y - .119, z + .59), (.027, .018, .032), p['eye'], 2)
        ico('kobold eye glint', (x + sign * .09 + .007, y - .137, z + .603), (.008, .004, .008), p['gold'])
        rod('kobold leg', (x + sign * .07, y, z + .21), (x + sign * .08, y - .025, z + .06), .045, p['skin'])
        ico('kobold foot', (x + sign * .08, y - .055, z + .045), (.055, .085, .045), p['leather'])
    rod('kobold left arm', (x - .12, y, z + .38), (x - .21, y - .08, z + .26), .035, p['skin'])
    rod('kobold right arm', (x + .12, y, z + .38), (x + .25, y - .10, z + .39), .035, p['skin'])
    tail = [(x, y + .08, z + .22), (x - .08, y + .25, z + .12), (x - .23, y + .30, z + .18), (x - .28, y + .28, z + .26)]
    for i, (a, b) in enumerate(zip(tail, tail[1:])):
        rod('kobold tail', a, b, .035 - i * .009, p['skin'])
    rod('pickaxe handle', (x + .16, y - .13, z + .12), (x + .36, y - .13, z + .72), .022, p['wood'])
    rod('pickaxe head left', (x + .16, y - .13, z + .76), (x + .36, y - .13, z + .72), .027, p['steel'])
    rod('pickaxe head right', (x + .36, y - .13, z + .72), (x + .52, y - .13, z + .62), .023, p['steel'])
    ico('miner satchel', (x - .11, y + .11, z + .30), (.075, .065, .10), p['wood'])


def trap(pos=(0, 0, 0)):
    x, y, z = pos
    p = palette()
    cube('trap plate', (x, y, z + .035), (.68, .68, .07), p['iron'])
    for dx in [-.2, 0, .2]:
        for dy in [-.2, 0, .2]:
            bpy.ops.mesh.primitive_cone_add(vertices=5, radius1=.035, radius2=0, depth=.18, location=(x + dx, y + dy, z + .15))
            bpy.context.object.data.materials.append(p['steel'])


def torch(pos=(0, 0, 0)):
    x, y, z = pos
    obj = asset('torch_lit.glb', pos, height=.70)
    add_light('torch amber light', (x, y, z + .58), 16, (1, .28, .04), .16, 'POINT')
    return obj


def sprite_metadata(scene, path):
    bpy.context.view_layer.update()
    anchor = world_to_camera_view(scene, scene.camera, Vector((0, 0, 0)))
    unit = world_to_camera_view(scene, scene.camera, Vector((1, 0, 0)))
    w, h = scene.render.resolution_x, scene.render.resolution_y
    return {'file': path.name, 'width': w, 'height': h,
            'anchor': [round(anchor.x * w, 4), round((1 - anchor.y) * h, 4)],
            'referenceTw': round(abs(unit.x - anchor.x) * w, 4), 'footprint': [1, 1]}


def render_sprites(only=None):
    OUTPUT.mkdir(parents=True, exist_ok=True)
    makers = {'floor': floor, 'wall': wall, 'archer': archer, 'well': well,
              'deposit': deposit, 'kobold': kobold, 'mage': mage, 'trap': trap,
              'rock': lambda: deposit(large=True), 'torch': torch}
    metadata = {'camera': {'elevationDegrees': math.degrees(ELEVATION), 'thOverTw': .47},
                'sprites': {}, 'notes': 'Actual KayKit meshes rendered with Blender; original kobold, elf ears, mana crystal and structural additions.'}
    if only and (OUTPUT / 'sprites.json').exists():
        metadata = json.loads((OUTPUT / 'sprites.json').read_text())
    for key, maker in makers.items():
        if only and key not in only:
            continue
        scene = setup_scene()
        maker()
        path = OUTPUT / (key + '.png')
        scene.render.filepath = str(path)
        bpy.ops.render.render(write_still=True)
        metadata['sprites'][key] = sprite_metadata(scene, path)
        (OUTPUT / 'sprites.json').write_text(json.dumps(metadata, indent=2))
        print('SPRITE_READY', key, path.stat().st_size, flush=True)
    return metadata


def render_full_scene():
    GENERATED.mkdir(parents=True, exist_ok=True)
    scene = setup_scene(1280, 720, True)
    p = palette()
    cube('cavern ground bed', (4.5, -3.5, -.32), (17, 15, .45), p['dark_stone'], .25)
    for x in range(10):
        for y in range(8):
            floor((x, -y, 0))
    random.seed(17)
    for x in range(-2, 12):
        for y in [-1.5, 9]:
            zheight = random.uniform(.65, 1.6) if y < 0 else random.uniform(.25, .65)
            asset('rubble_large.glb', (x + random.uniform(-.3, .3), -y, -.08), size=(random.uniform(1.1, 1.7), 1.5, zheight), rotation=random.random() * math.tau, mat=p['dark_stone'])
    for y in range(8):
        for x in [-1.5, 11]:
            asset('rubble_large.glb', (x, -y, -.05), size=(1.3, random.uniform(1.0, 1.7), random.uniform(.4, 1.1)), rotation=random.random() * math.tau, mat=p['dark_stone'])
    well((6, -2, 0))
    archer((3, -3, 0))
    wall((5, -4, 0))
    wall((5, -5, 0))
    for x, y in [(0, 1), (0, 4), (2, 0)]:
        deposit((x, -y, 0))
    kobold((.8, -2.7, 0))
    for x, y in [(-.7, -1.4), (9.7, -6.5), (6.5, .7)]:
        torch((x, y, 0))
    for light in bpy.data.lights:
        if light.name.startswith('amber well glow'):
            light.energy = 100
        elif light.name.startswith('torch amber light'):
            light.energy = 60
    scene.render.filepath = str(GENERATED / 'lv1-dark-assets.png')
    bpy.ops.render.render(write_still=True)
    print('SCENE_READY', scene.render.filepath, flush=True)


def main():
    argv = sys.argv[sys.argv.index('--') + 1:] if '--' in sys.argv else []
    parser = argparse.ArgumentParser()
    parser.add_argument('--sprites', action='store_true')
    parser.add_argument('--scene', action='store_true')
    parser.add_argument('--only', help='Comma-separated sprite keys for an incremental render')
    args = parser.parse_args(argv)
    if args.sprites or not args.scene:
        render_sprites(args.only.split(',') if args.only else None)
    if args.scene:
        render_full_scene()


if __name__ == '__main__':
    main()

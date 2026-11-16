"""Losslessly remove irrelevant RGB values from fully transparent render pixels.

This does not alter any visible pixel or alpha value. It reduces sprite file
size for a self-contained HTML preview. Requires Pillow (pip install Pillow).
Run after rendering: python3 art/optimize_png.py
"""
from pathlib import Path
import json
import sys
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]
total_before = total_after = 0
manifest_path = ROOT / 'prototypes' / 'assets' / 'lv1' / 'sprites.json'
manifest = json.loads(manifest_path.read_text())
paths = [] if '--scene-only' in sys.argv else sorted((ROOT / 'prototypes' / 'assets' / 'lv1').glob('*.png'))
def pixels_of(image):
    return list(image.get_flattened_data() if hasattr(image, 'get_flattened_data') else image.getdata())

for path in paths:
    total_before += path.stat().st_size
    image = Image.open(path).convert('RGBA')
    pixels = pixels_of(image)
    clean = [(0, 0, 0, 0) if pixel[3] == 0 else pixel for pixel in pixels]
    image.putdata(clean)
    image.save(path, format='PNG', optimize=True, compress_level=9)
    decoded = pixels_of(Image.open(path).convert('RGBA'))
    assert all(original == packed for original, packed in zip(pixels, decoded) if original[3] != 0)
    assert [p[3] for p in pixels] == [p[3] for p in decoded]
    if path.stem in manifest['sprites']:
        manifest['sprites'][path.stem]['hitBounds'] = list(image.getchannel('A').point(lambda value: 255 if value >= 48 else 0).getbbox())
    total_after += path.stat().st_size
    print(path.name, path.stat().st_size)
print('TOTAL', total_before, '->', total_after)
if paths:
    manifest_path.write_text(json.dumps(manifest, indent=2))
scene_path = ROOT / 'art' / 'generated' / 'lv1-dark-assets.png'
if scene_path.exists():
    scene = Image.open(scene_path).convert('RGB')
    compact = scene_path.with_suffix('.webp')
    scene.save(compact, format='WEBP', quality=88, method=6)
    print('SCENE', compact.name, compact.stat().st_size)

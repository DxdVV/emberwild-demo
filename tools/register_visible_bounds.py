"""Read opaque frame bounds into Resources; never modify source PNG pixels."""
import json
import re
from pathlib import Path
from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def register():
    images = {}
    pending = []
    count = 0
    for path in sorted((ROOT / 'resources/animations').glob('*.tres')):
        text = path.read_text(encoding='utf-8')
        refs = dict((key, uri) for uri, key in re.findall(
            r'\[ext_resource type="Texture2D" path="([^"]+)" id="([^"]+)"\]', text))
        sources = {}
        for field, source in [('texture', 'walk'), ('action_texture', 'action'),
                              ('directional_texture', 'directional')]:
            match = re.search(r'^' + field + r' = ExtResource\("([^"]+)"\)', text, re.M)
            if match:
                sources[source] = refs[match[1]]
        extra = re.search(r'^supplemental_textures = (.+)$', text, re.M)
        if extra:
            for source, key in re.findall(r'"([^"]+)": ExtResource\("([^"]+)"\)', extra[1]):
                sources[source] = refs[key]
        for field, default in [('frames', 'walk'), ('action_frames', 'action')]:
            match = re.search(r'^' + field + r' = Array\[Dictionary\]\((.+)\)$', text, re.M)
            if not match:
                continue
            frames = json.loads(match[1])
            for frame in frames:
                source = frame.get('source', default)
                if source == 'default':
                    source = default
                uri = sources[source]
                if uri not in images:
                    images[uri] = Image.open(ROOT / uri.removeprefix('res://')).convert('RGBA')
                x, y, width, height = frame['region']
                alpha = images[uri].getchannel('A').crop((x, y, x + width, y + height))
                bounds = alpha.point(lambda value: 255 if value >= 128 else 0).getbbox()
                if not bounds:
                    raise ValueError(f'Empty rendered frame: {path.name} {frame["region"]}')
                left, top, right, bottom = bounds
                frame['visible_bounds'] = [left, top, right - left, bottom - top]
                count += 1
            text = text[:match.start(1)] + json.dumps(frames) + text[match.end(1):]
        pending.append((path, text))
    for path, text in pending:
        path.write_text(text, encoding='utf-8')
    print(f'Registered opaque bounds for {count} frames in {len(pending)} animations; PNGs unchanged')


if __name__ == '__main__':
    register()

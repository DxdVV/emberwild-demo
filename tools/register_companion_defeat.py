"""Register authored collapse sequences; inspect alpha, never change source PNGs."""
from pathlib import Path
import json
import re
import statistics
import numpy as np
from PIL import Image
from register_combat_animation import frames_in_row
from register_directional_animation import read_array, height

ROOT = Path(__file__).resolve().parents[1]
DEFEATS = {'cinder': .65, 'rill': .65, 'briar': .8, 'volt': .6, 'solstice': .75}


def measure(filename):
    image = Image.open(ROOT / 'assets/characters' / filename).convert('RGBA')
    mask = np.asarray(image.getchannel('A')) > 128
    if not mask.any() or mask.mean() > .65:
        raise ValueError(f'{filename}: missing transparent background')
    occupied = np.flatnonzero(mask.any(axis=1))
    # Generated atlases may have extra top margin, so actual empty row gutters
    # define the bands instead of cutting through limbs at nominal thirds.
    breaks = np.flatnonzero(np.diff(occupied) > 10)
    if len(breaks) != 2:
        raise ValueError(f'{filename}: expected three separated sprite rows')
    cuts = [0] + [int((occupied[i] + occupied[i+1]) // 2) for i in breaks] + [image.height]
    frames = []
    for top, bottom in zip(cuts, cuts[1:]):
        row = frames_in_row(image, top, bottom)
        for column, frame in enumerate(row):
            x, y, w, h = frame['region']
            crop = mask[y:y+h, x:x+w]
            if crop[0].any() or crop[-1].any() or crop[:,0].any() or crop[:,-1].any():
                raise ValueError(f'{filename}: clipped sprite {frame}')
            # One stance pivot for the whole sequence, retaining authored lean.
            frame['anchor'][0] = round(image.width*(column+.5)/6) - x
            frame['source'] = 'defeat'
        frames.extend(row)
    return image, frames, cuts, float(mask.mean())


def register():
    report = {}
    pending = {}
    for name, duration in DEFEATS.items():
        filename = f'{name}-defeat.png'
        image, frames, cuts, coverage = measure(filename)
        path = ROOT / 'resources/animations' / f'{name}.tres'
        text = path.read_text(encoding='utf-8')
        actions = [frame for frame in read_array(text, 'action_frames') if frame.get('source') != 'defeat']
        clips = json.loads(next(line.split(' = ',1)[1] for line in text.splitlines() if line.startswith('clips = ')))
        walking = read_array(text, 'frames')
        texture_id = re.search(r'^texture = ExtResource\("([^"]+)"\)',text,re.M)[1]
        texture_path = re.search(r'\[ext_resource type="Texture2D" path="res://([^"]+)" id="'+texture_id+r'"\]',text)[1]
        source = Image.open(ROOT / texture_path)
        walk_scale = float(re.search(r'^render_scale = (.+)$',text,re.M)[1])
        old_height = statistics.median(height(source,frame) for frame in walking[:6])
        scale = round(old_height * walk_scale / height(image,frames[0]),5)
        for row, direction in enumerate(['east','south','north']):
            key = 'death' + ('.'+direction if direction!='east' else '')
            clips[key] = list(range(len(actions)+row*6,len(actions)+row*6+6))
        keys = ('action_frames =','clips =','supplemental_textures =','supplemental_scales =','death_duration =','death_ground_phase =')
        text = '\n'.join(line for line in text.splitlines() if not line.startswith(keys) and 'id="5"' not in line)+'\n'
        text = text.replace('[resource]',f'[ext_resource type="Texture2D" path="res://assets/characters/{filename}" id="5"]\n[resource]')
        text = re.sub(r'load_steps=\d+','load_steps='+str(text.count('[ext_resource')+1),text,count=1)
        text += 'supplemental_textures = {"defeat": ExtResource("5")}\n'
        text += 'supplemental_scales = '+json.dumps({'defeat':scale})+'\n'
        text += f'death_duration = {duration}\n'
        if name=='volt': text += 'death_ground_phase = 0.3333333333333333\n'
        text += 'action_frames = Array[Dictionary]('+json.dumps(actions+frames)+')\n'
        text += 'clips = '+json.dumps(clips)+'\n'
        pending[path] = text
        report[name] = {'size':image.size,'cuts':cuts,'alpha_coverage':coverage,'scale':scale,'frame_heights':[height(image,frame) for frame in frames]}
    # A rejected later atlas must not leave earlier Resources half-updated.
    for path, text in pending.items():
        path.write_text(text,encoding='utf-8')
    (ROOT/'build/companion-defeat-atlas-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__ == '__main__': register()

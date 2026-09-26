"""Measure the six-pose side collapse atlas without editing source pixels."""
from pathlib import Path
import json
import re
import statistics
import numpy as np
from PIL import Image
from register_combat_animation import frames_in_row
from register_directional_animation import read_array, height

ROOT = Path(__file__).resolve().parents[1]


def register():
    image = Image.open(ROOT/'assets/characters/guardian-side-defeat.png').convert('RGBA')
    mask = np.asarray(image.getchannel('A')) > 128
    if not mask.any() or mask.mean()>.65:
        raise ValueError('Missing transparent guardian collapse alpha')
    occupied = np.flatnonzero(mask.any(axis=1))
    breaks = np.flatnonzero(np.diff(occupied)>10)
    if len(breaks)!=1:
        raise ValueError('Expected two separated guardian collapse rows')
    split = int((occupied[breaks[0]]+occupied[breaks[0]+1])//2)
    actions = []
    for top,bottom in [(0,split),(split,image.height)]:
        for column,frame in enumerate(frames_in_row(image,top,bottom,3)):
            x,y,w,h = frame['region']
            crop = mask[y:y+h,x:x+w]
            if crop[0].any() or crop[-1].any() or crop[:,0].any() or crop[:,-1].any():
                raise ValueError(f'Clipped guardian collapse: {frame}')
            frame['source'] = 'side_defeat'
            frame['anchor'][0] = round(image.width*(column+.5)/3)-x
            actions.append(frame)
    path = ROOT/'resources/animations/guardian.tres'
    text = path.read_text(encoding='utf-8')
    old_actions = [frame for frame in read_array(text,'action_frames') if frame.get('source')!='side_defeat']
    walk = read_array(text,'frames')
    source = Image.open(ROOT/'assets/characters/guardian-motion.png')
    walk_scale = float(re.search(r'^render_scale = (.+)$',text,re.M)[1])
    scale = round(walk_scale*statistics.median(height(source,frame) for frame in walk[:6])/height(image,actions[0]),5)
    clips = json.loads(next(line.split(' = ',1)[1] for line in text.splitlines() if line.startswith('clips = ')))
    clips['death'] = list(range(len(old_actions),len(old_actions)+6))
    keys = ('action_frames =','clips =','supplemental_textures =','supplemental_scales =','death_duration =')
    text = '\n'.join(line for line in text.splitlines() if not line.startswith(keys) and 'id="5"' not in line)+'\n'
    text = text.replace('[resource]','[ext_resource type="Texture2D" path="res://assets/characters/guardian-side-defeat.png" id="5"]\n[resource]')
    text = re.sub(r'load_steps=\d+','load_steps='+str(text.count('[ext_resource')+1),text,count=1)
    text += 'supplemental_textures = {"side_defeat": ExtResource("5")}\n'
    text += 'supplemental_scales = '+json.dumps({'side_defeat':scale})+'\n'
    text += 'death_duration = 0.8\n'
    text += 'action_frames = Array[Dictionary]('+json.dumps(old_actions+actions)+')\n'
    text += 'clips = '+json.dumps(clips)+'\n'
    path.write_text(text,encoding='utf-8')
    report = {'size':image.size,'row_split':split,'alpha_coverage':float(mask.mean()),'scale':scale,'heights':[height(image,frame) for frame in actions]}
    (ROOT/'build/guardian-side-defeat-atlas-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))


if __name__=='__main__': register()

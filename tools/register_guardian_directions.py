"""Validate and register untouched directional guardian attack/defeat artwork."""
from pathlib import Path
import json, re, statistics
from PIL import Image
import numpy as np
from register_combat_animation import frames_in_row

ROOT = Path(__file__).resolve().parents[1]

def measure(path):
    image = Image.open(path).convert('RGBA')
    mask = np.asarray(image.getchannel('A')) > 128
    if not mask.any() or mask.mean()>.6: raise ValueError('Missing transparent guardian alpha')
    occupancy = mask.sum(axis=1)
    cuts = [0]
    for row in range(1,4):
        nominal = image.height*row//4
        cuts.append(min(range(nominal-70,nominal+71),key=lambda y:(sum(occupancy[y-2:y+3]),abs(y-nominal))))
    cuts.append(image.height)
    rows = []
    for top,bottom in zip(cuts,cuts[1:]):
        frames = frames_in_row(image,top,bottom)
        for column,frame in enumerate(frames):
            x,y,w,h = frame['region']
            if mask[y:y+h,x].any() or mask[y:y+h,x+w-1].any() or mask[y,x:x+w].any() or mask[y+h-1,x:x+w].any():
                raise ValueError(f'Guardian crop contacts opaque pixels: {frame}')
            frame['source'] = 'directional'
            frame['anchor'][0] = column*image.width//6+image.width//12-x
        rows.append(frames)
    print('Guardian row cuts:',cuts,'; alpha coverage:',float(mask.mean()))
    return image, rows

def height(image,frame):
    x,y,w,h = frame['region']
    alpha = np.asarray(image.getchannel('A'))[y:y+h,x:x+w]>128
    rows = np.flatnonzero(alpha.any(axis=1))
    return int(rows[-1]-rows[0]+1)

def register():
    image,rows = measure(ROOT/'assets/characters/guardian-directions.png')
    path = ROOT/'resources/animations/guardian.tres'
    text = path.read_text(encoding='utf-8')
    def array(name):
        line = next(line for line in text.splitlines() if line.startswith(name+' = '))
        return json.loads(line.split('Array[Dictionary](',1)[1][:-1])
    walk,actions = array('frames'),array('action_frames')[:6]
    old_image = Image.open(ROOT/'assets/characters/guardian-motion.png').convert('RGBA')
    old_height = statistics.median(height(old_image,frame) for frame in walk)
    # Neutral poses in column six retain the same scale as existing locomotion.
    new_height = statistics.median(height(image,rows[row][5]) for row in [0,1])
    scale = round(.74*old_height/new_height,5)
    clips = {'windup':[0,1],'release':[2,3],'hurt':[4],'death':[4,0,5,5]}
    for row,direction in enumerate(['south','north']):
        offset = 6+row*6
        for name,sequence in {'windup':[0,1],'release':[2,3],'hurt':[4]}.items():
            clips[name+'.'+direction] = [offset+index for index in sequence]
        clips['death.'+direction] = list(range(18+row*6,24+row*6))
    keys=('action_frames =','clips =','directional_texture =','directional_scale =')
    text='\n'.join(line for line in text.splitlines() if not line.startswith(keys) and 'id="4"' not in line)+'\n'
    text=re.sub(r'load_steps=\d+','load_steps=4',text,count=1)
    text=text.replace('[resource]','[ext_resource type="Texture2D" path="res://assets/characters/guardian-directions.png" id="4"]\n[resource]')
    text+='directional_texture = ExtResource("4")\n'
    text+=f'directional_scale = {scale}\n'
    text+='action_frames = Array[Dictionary]('+json.dumps(actions+[frame for row in rows for frame in row])+')\n'
    text+='clips = '+json.dumps(clips)+'\n'
    path.write_text(text,encoding='utf-8')
    print('Guardian directional scale:',scale,'; original/neutral height:',old_height,new_height)
    from register_guardian_side_defeat import register as register_side_defeat
    register_side_defeat()

if __name__=='__main__':
    import sys
    if len(sys.argv)>1: measure(sys.argv[1])
    else: register()

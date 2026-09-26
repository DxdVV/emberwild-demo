"""Register untouched hero atlases as validated, viewer-compatible animation data."""
from pathlib import Path
from PIL import Image
import json
import numpy as np
from register_combat_animation import frames_in_row

ROOT = Path(__file__).resolve().parents[1]

def combat_frames(filename='ranger-combat-directions.png', source='directional'):
    image = Image.open(ROOT/'assets/characters'/filename).convert('RGBA')
    mask = np.asarray(image.getchannel('A')) > 128
    if mask.mean() > .6: raise ValueError('Hero combat atlas lacks a transparent background')
    occupancy = mask.sum(axis=1)
    cuts = [0]
    for nominal in [image.height//3,image.height*2//3]:
        cuts.append(min(range(nominal-85,nominal+86),key=lambda y:(sum(occupancy[y-2:y+3]),abs(y-nominal))))
    cuts.append(image.height)
    frames = []
    for top,bottom in zip(cuts,cuts[1:]):
        for column,frame in enumerate(frames_in_row(image,top,bottom)):
            x,y,w,h = frame['region']
            if mask[y:y+h,x].any() or mask[y:y+h,x+w-1].any() or mask[y,x:x+w].any() or mask[y+h-1,x:x+w].any():
                raise ValueError(f'Clipped hero combat frame {frame}')
            # Shared cell pivot preserves authored torso lean instead of recentering it.
            frame['anchor'][0] = column*image.width//6+image.width//12-x
            frame['source'] = source
            frames.append(frame)
    print(filename,'row boundaries:',cuts,'; alpha coverage:',float(mask.mean()))
    return frames

def register():
    image = Image.open(ROOT/'assets/characters/ranger-defeat.png').convert('RGBA')
    mask = np.asarray(image.getchannel('A')) > 128
    occupancy = mask.sum(axis=1)
    cuts = [0]
    # The generated first row sits below its nominal baseline; find the real gutters.
    for nominal in [image.height//3, image.height*2//3]:
        cuts.append(min(range(nominal-85,nominal+86),key=lambda y:(sum(occupancy[y-2:y+3]),abs(y-nominal))))
    cuts.append(image.height)
    actions = []
    for top,bottom in zip(cuts,cuts[1:]):
        row = frames_in_row(image,top,bottom)
        for column, frame in enumerate(row):
            x,y,w,h = frame['region']
            if mask[y:y+h,x].any() or mask[y:y+h,x+w-1].any():
                raise ValueError(f'Clipped hero frame {frame}')
            # Fixed world pivot across the authored falling arc; keep pose displacement.
            frame['anchor'][0] = column*image.width//6+image.width//12-x
        actions.extend(row)
    frames = json.loads((ROOT/'resources/ranger_frames.json').read_text())
    for frame,x in zip(frames[18:],[143,143,136,128,128,128]): frame['anchor'][0]=x
    actions.extend(combat_frames())
    actions.extend(combat_frames('ranger-reactions.png','reactions'))
    text = '[gd_resource type="Resource" script_class="SpriteAnimationData" load_steps=6 format=3]\n'
    text += '[ext_resource type="Script" path="res://scripts/data/sprite_animation_data.gd" id="1"]\n'
    text += '[ext_resource type="Texture2D" path="res://assets/characters/ranger-motion.png" id="2"]\n'
    text += '[ext_resource type="Texture2D" path="res://assets/characters/ranger-defeat.png" id="3"]\n'
    text += '[ext_resource type="Texture2D" path="res://assets/characters/ranger-combat-directions.png" id="4"]\n'
    text += '[ext_resource type="Texture2D" path="res://assets/characters/ranger-reactions.png" id="5"]\n'
    text += '[resource]\nscript = ExtResource("1")\nid = "animation.ranger"\ntexture = ExtResource("2")\naction_texture = ExtResource("3")\n'
    text += 'render_scale = 0.44\naction_scale = 0.44\ndeath_duration = 0.9\n'
    text += 'directional_texture = ExtResource("4")\ndirectional_scale = 0.4\n'
    text += 'supplemental_textures = {"reactions": ExtResource("5")}\nsupplemental_scales = {"reactions": 0.45}\nhurt_duration = 0.24\n'
    text += 'frames = Array[Dictionary]('+json.dumps(frames)+')\n'
    text += 'action_frames = Array[Dictionary]('+json.dumps(actions)+')\n'
    text += 'directions = '+json.dumps({'south':list(range(6)),'east':list(range(6,12)),'north':list(range(12,18))})+'\n'
    clips = {'death':list(range(6,12)),'death.south':list(range(6)),'death.north':list(range(12,18))}
    for row,direction in enumerate(['south','east','north']):
        for name,sequence in {'windup':[0,1],'release':[2,3]}.items():
            clips[name+('.'+direction if direction!='east' else '')] = [18+row*6+index for index in sequence]
        for name,sequence in {'hurt':[0,1,2],'dodge':[3,4,5]}.items():
            clips[name+('.'+direction if direction!='east' else '')] = [36+row*6+index for index in sequence]
    text += 'clips = '+json.dumps(clips)+'\n'
    (ROOT/'resources/animations/ranger.tres').write_text(text,encoding='utf-8')
    print('Hero defeat row boundaries:',cuts,'; alpha coverage:',float(mask.mean()))

if __name__=='__main__': register()

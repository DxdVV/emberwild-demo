"""Register untouched Solstice PNGs using transparent gutters and foot anchors."""
from pathlib import Path
import json, statistics
import numpy as np
from PIL import Image
from register_combat_animation import frames_in_row

ROOT = Path(__file__).resolve().parents[1]

def measure(name):
    image = Image.open(ROOT/'assets/characters'/name).convert('RGBA')
    mask = np.asarray(image.getchannel('A')) > 128
    if not mask.any() or mask.mean() > .65:
        raise ValueError(f'{name}: missing transparent background')
    occupancy = mask.sum(axis=1)
    cuts = [0]
    for row in [1,2]:
        nominal = image.height*row//3
        cuts.append(min(range(nominal-70,nominal+71),key=lambda y:(sum(occupancy[y-2:y+3]),abs(y-nominal))))
    cuts.append(image.height)
    frames, heights = [], []
    for top,bottom in zip(cuts,cuts[1:]):
        row = frames_in_row(image,top,bottom)
        for frame in row:
            x,y,w,h = frame['region']
            crop = mask[y:y+h,x:x+w]
            if crop[0].any() or crop[-1].any() or crop[:,0].any() or crop[:,-1].any():
                raise ValueError(f'{name}: clipped frame {frame}')
            occupied = np.flatnonzero(crop.any(axis=1))
            heights.append(int(occupied[-1]-occupied[0]+1))
        frames.extend(row)
    print(name,image.size,'row cuts',cuts,'heights',heights,'alpha',mask.mean())
    return image,frames,heights

def register():
    walk,frames,heights = measure('solstice-walk.png')
    _,actions,action_heights = measure('solstice-combat.png')
    scale = round(104/statistics.median(heights),5)
    # Match upright poses, excluding crouched/hit/defeat silhouettes.
    action_scale = round(scale*statistics.median(heights)/statistics.median(action_heights[i] for i in [0,6,12]),5)
    directions = {name:list(range(row*6,row*6+6)) for row,name in enumerate(['east','south','north'])}
    clips = {}
    for row,direction in enumerate(['east','south','north']):
        for name,sequence in {'windup':[0,1],'release':[2,3],'hurt':[4],'death':[4,1,5,5]}.items():
            clips[name+('' if direction=='east' else '.'+direction)] = [row*6+i for i in sequence]
    text = '[gd_resource type="Resource" script_class="SpriteAnimationData" load_steps=4 format=3]\n'
    text += '[ext_resource type="Script" path="res://scripts/data/sprite_animation_data.gd" id="1"]\n'
    text += '[ext_resource type="Texture2D" path="res://assets/characters/solstice-walk.png" id="2"]\n'
    text += '[ext_resource type="Texture2D" path="res://assets/characters/solstice-combat.png" id="3"]\n'
    text += '[resource]\nscript = ExtResource("1")\nid = "animation.solstice"\ntexture = ExtResource("2")\naction_texture = ExtResource("3")\n'
    text += f'render_scale = {scale}\naction_scale = {action_scale}\nstride_per_frame = 18.0\n'
    text += 'frames = Array[Dictionary]('+json.dumps(frames)+')\n'
    text += 'action_frames = Array[Dictionary]('+json.dumps(actions)+')\n'
    text += 'directions = '+json.dumps(directions)+'\nclips = '+json.dumps(clips)+'\n'
    (ROOT/'resources/animations/solstice.tres').write_text(text,encoding='utf-8')
    x,y,w,h = frames[7]['region']
    box = walk.getchannel('A').crop((x,y,x+w,y+h)).point(lambda a:255 if a>128 else 0).getbbox()
    folder = ROOT/'resources/portraits'
    folder.mkdir(exist_ok=True)
    portrait = '[gd_resource type="AtlasTexture" load_steps=2 format=3]\n[ext_resource type="Texture2D" path="res://assets/characters/solstice-walk.png" id="1"]\n[resource]\natlas = ExtResource("1")\n'
    portrait += f'region = Rect2({x+box[0]}, {y+box[1]}, {box[2]-box[0]}, {box[3]-box[1]})\n'
    (folder/'solstice.tres').write_text(portrait,encoding='utf-8')

if __name__ == '__main__': register()

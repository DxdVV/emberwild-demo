"""Read the untouched directional sheets into Godot atlas/anchor metadata."""
from pathlib import Path
from PIL import Image
import json, re, statistics
import numpy as np
from register_combat_animation import frames_in_row

ROOT = Path(__file__).resolve().parents[1]

def read_array(text, name):
    line = next(line for line in text.splitlines() if line.startswith(name+' = '))
    return json.loads(line.split('Array[Dictionary](',1)[1][:-1])

def height(image, frame):
    x,y,w,h=frame['region']
    alpha=np.asarray(image.getchannel('A'))[y:y+h,x:x+w]>128
    rows=np.flatnonzero(alpha.any(axis=1))
    return int(rows[-1]-rows[0]+1)

def register():
    report={}
    for name in ['cinder','rill','briar','volt']:
        filename=f'{name}-directions'+('-v2' if name=='volt' else '')+'.png'
        image=Image.open(ROOT/'assets/characters'/filename).convert('RGBA')
        mask=np.asarray(image.getchannel('A'))>128
        if mask.all() or not mask.any(): raise ValueError('Missing transparent sprite alpha: '+name)
        occupancy=mask.sum(axis=1)
        cuts=[0]
        for row in range(1,4):
            nominal=image.height*row//4
            candidates=range(nominal-36,nominal+37)
            cuts.append(min(candidates,key=lambda y:(sum(occupancy[max(0,y-1):y+2]),abs(y-nominal))))
        cuts.append(image.height)
        rows=[frames_in_row(image,top,bottom) for top,bottom in zip(cuts,cuts[1:])]
        for row in rows:
            for frame in row:
                frame['source']='directional'
                x,y,w,h=frame['region']
                if mask[y:y+h,x].any() or mask[y:y+h,x+w-1].any():
                    raise ValueError(f'{name}: opaque pixels reach a frame crop boundary at {frame["region"]}')
        path=ROOT/'resources/animations'/f'{name}.tres'
        text=path.read_text(encoding='utf-8')
        walk=read_array(text,'frames')[:6]
        actions=read_array(text,'action_frames')[:6]
        source=Image.open(ROOT/'assets/characters/creatures-motion.png')
        scale=float(re.search(r'^render_scale = (.+)$',text,re.M)[1])
        # Match overall standing height across sheets; pose geometry remains authored.
        new_height=statistics.median(height(image,frame) for row in rows[:2] for frame in row)
        old_height=statistics.median(height(source,frame) for frame in walk)
        directional_scale=round(scale*old_height/new_height,5)
        clips={'windup':[0,1],'release':[2,3],'hurt':[4],'death':[4,0,5,5]}
        for direction,offset in [('south',6),('north',12)]:
            for clip,sequence in list(clips.items()):
                if '.' not in clip: clips[clip+'.'+direction]=[index+offset for index in sequence]
        keys=('frames =','action_frames =','clips =','directions =','directional_texture =','directional_scale =')
        text='\n'.join(line for line in text.splitlines() if not line.startswith(keys) and 'id="4"' not in line)+'\n'
        text=re.sub(r'load_steps=\d+','load_steps=5',text,count=1)
        text=text.replace('[resource]',f'[ext_resource type="Texture2D" path="res://assets/characters/{filename}" id="4"]\n[resource]')
        text+='directional_texture = ExtResource("4")\n'
        text+=f'directional_scale = {directional_scale}\n'
        text+='frames = Array[Dictionary]('+json.dumps(walk+rows[0]+rows[1])+')\n'
        text+='action_frames = Array[Dictionary]('+json.dumps(actions+rows[2]+rows[3])+')\n'
        text+='directions = '+json.dumps({'east':list(range(6)),'south':list(range(6,12)),'north':list(range(12,18))})+'\n'
        text+='clips = '+json.dumps(clips)+'\n'
        path.write_text(text,encoding='utf-8')
        report[name]={'row_cuts':cuts,'directional_scale':directional_scale,'old_height':old_height,'new_height':new_height,'alpha_coverage':float(mask.mean())}
    (ROOT/'build/directional-atlas-report.json').write_text(json.dumps(report,indent=2),encoding='utf-8')
    print(json.dumps(report,indent=2))

if __name__=='__main__': register()

"""Measure authored PNG alpha into atlas metadata; never alter source artwork."""
from pathlib import Path
from PIL import Image
import json
import statistics

ROOT = Path(__file__).resolve().parents[1]

def frames_in_row(image, top, bottom, columns=6):
    alpha = image.getchannel('A')
    width, _ = image.size
    counts = [sum(alpha.getpixel((x,y))>128 for y in range(top,bottom)) for x in range(width)]
    cuts = [0]
    for column in range(1,columns):
        nominal = width*column//columns
        candidates = range(nominal-38,nominal+39)
        # Find transparent gaps near the nominal grid; some authored limbs
        # extend beyond an exact cell but remain separated from neighbours.
        cuts.append(min(candidates,key=lambda x:(sum(counts[max(0,x-2):x+3]),abs(x-nominal))))
    cuts.append(width)
    result = []
    for left,right in zip(cuts,cuts[1:]):
        box = alpha.crop((left,top,right,bottom)).point(lambda a:255 if a>128 else 0).getbbox()
        if not box: raise ValueError('Empty animation frame')
        body=[]
        for y in range(top+box[1]+int((box[3]-box[1])*.42),top+box[1]+int((box[3]-box[1])*.72)):
            body.extend(x-left for x in range(left,right) if alpha.getpixel((x,y))>180)
        anchor = int(statistics.median(body)) if body else (box[0]+box[2])//2
        result.append({'region':[left,top,right-left,bottom-top],'anchor':[anchor,box[3]-1]})
    return result

def register():
    combat=Image.open(ROOT/'assets/characters/creatures-combat.png').convert('RGBA')
    rows=[('cinder',0,264,.38),('rill',264,485,.38),('briar',485,762,.44),('volt',762,1024,.39)]
    clips={'windup':[0,1],'release':[2,3],'hurt':[4],'death':[4,0,5,5]}
    for name,top,bottom,scale in rows:
        path=ROOT/'resources/animations'/f'{name}.tres'
        text=path.read_text(encoding='utf-8')
        text=text.replace('load_steps=3','load_steps=4')
        if 'id="3"' not in text:
            text=text.replace('[resource]','[ext_resource type="Texture2D" path="res://assets/characters/creatures-combat.png" id="3"]\n[resource]')
        # Allow deterministic reruns without duplicated properties.
        text='\n'.join(line for line in text.splitlines() if not line.startswith(('action_texture =','action_frames =','action_scale =','clips =')))+'\n'
        text+='action_texture = ExtResource("3")\n'
        text+=f'action_scale = {scale}\n'
        text+='action_frames = Array[Dictionary]('+json.dumps(frames_in_row(combat,top,bottom))+')\n'
        text+='clips = '+json.dumps(clips)+'\n'
        path.write_text(text,encoding='utf-8')
    guardian=Image.open(ROOT/'assets/characters/guardian-motion.png').convert('RGBA')
    frames=[]
    for top,bottom in [(0,255),(255,501),(501,749)]: frames.extend(frames_in_row(guardian,top,bottom))
    text='[gd_resource type="Resource" script_class="SpriteAnimationData" load_steps=3 format=3]\n'
    text+='[ext_resource type="Script" path="res://scripts/data/sprite_animation_data.gd" id="1"]\n'
    text+='[ext_resource type="Texture2D" path="res://assets/characters/guardian-motion.png" id="2"]\n'
    text+='[resource]\nscript = ExtResource("1")\ntexture = ExtResource("2")\naction_texture = ExtResource("2")\n'
    text+='id = "animation.guardian"\nrender_scale = 0.74\naction_scale = 0.74\nstride_per_frame = 18.0\n'
    text+='frames = Array[Dictionary]('+json.dumps(frames)+')\n'
    text+='directions = '+json.dumps({'east':list(range(6)),'south':list(range(6,12)),'north':list(range(12,18))})+'\n'
    text+='action_frames = Array[Dictionary]('+json.dumps(frames_in_row(guardian,749,1024))+')\n'
    text+='clips = '+json.dumps(clips)+'\n'
    (ROOT/'resources/animations/guardian.tres').write_text(text,encoding='utf-8')
    for species,animation in [('guardian','guardian'),('solstice','solstice')]:
        path=ROOT/'resources/species'/f'{species}.tres'
        text=path.read_text(encoding='utf-8')
        if 'animation_id =' not in text: text+=f'animation_id = "animation.{animation}"\n'
        path.write_text(text,encoding='utf-8')
    from register_guardian_directions import register as register_guardian
    register_guardian()
    print('Registered combat/death clips for four creatures and directional guardian frames.')

if __name__=='__main__': register()

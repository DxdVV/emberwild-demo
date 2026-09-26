"""Measure sprite frame anchors; write native Godot animation Resources."""
from pathlib import Path
from PIL import Image
import statistics,json

root=Path(__file__).resolve().parents[1]
sheet=Image.open(root/'assets/characters/creatures-motion.png').convert('RGBA')
folder=root/'resources/animations'; folder.mkdir(exist_ok=True)
rows=[('cinder',0,258,.38),('rill',263,209,.38),('briar',474,270,.44),('volt',744,280,.39)]
for name,base_y,height,scale in rows:
    frames=[]
    for column in range(6):
        frame=sheet.crop((column*256,base_y,column*256+256,base_y+height))
        box=frame.getchannel('A').point(lambda a:255 if a>128 else 0).getbbox()
        body=[]
        for y in range(int(height*.42),int(height*.7)):
            for x in range(256):
                if frame.getpixel((x,y))[3]>180: body.append(x)
        anchor=int(statistics.median(body)) if body else 128
        frames.append({'region':[column*256,base_y,256,height],'anchor':[anchor,box[3]-1]})
    text='[gd_resource type="Resource" script_class="SpriteAnimationData" load_steps=3 format=3]\n'
    text+='[ext_resource type="Script" path="res://scripts/data/sprite_animation_data.gd" id="1"]\n'
    text+='[ext_resource type="Texture2D" path="res://assets/characters/creatures-motion.png" id="2"]\n'
    text+='[resource]\nscript = ExtResource("1")\ntexture = ExtResource("2")\n'
    text+=f'id = "animation.{name}"\nrender_scale = {scale}\nautoplay = {str(name=="volt").lower()}\n'
    text+='frames = Array[Dictionary]('+json.dumps(frames)+')\n'
    (folder/(name+'.tres')).write_text(text,encoding='utf-8')
    species_path=root/'resources/species'/f'{name}.tres'
    content=species_path.read_text(encoding='utf-8')
    if 'animation_id' not in content: content+=f'animation_id = "animation.{name}"\n'
    species_path.write_text(content,encoding='utf-8')

from register_combat_animation import register
register()
from register_directional_animation import register as register_directions
register_directions()
from register_solstice_animation import register as register_solstice
register_solstice()
from register_companion_defeat import register as register_defeat
register_defeat()
from register_visible_bounds import register as register_bounds
register_bounds()

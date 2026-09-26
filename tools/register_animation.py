"""Read alpha/head landmarks into frame metadata; never resample or edit source artwork."""
from PIL import Image
from pathlib import Path
import json, statistics

root = Path(__file__).resolve().parents[1]
image = Image.open(root/'assets/characters/ranger-motion.png').convert('RGBA')
frames=[]
for row in range(4):
    base_y = [0,256,512,752][row]
    height = 240 if row==2 else 256
    for column in range(6):
        region=(column*256,base_y,column*256+256,base_y+height)
        frame=image.crop(region)
        alpha=frame.getchannel('A').point(lambda a:255 if a>128 else 0)
        box=alpha.getbbox()
        head=[]
        for y in range(8,84):
            for x in range(256):
                r,g,b,a=frame.getpixel((x,y))
                if a>128 and r>120 and r>g*1.6 and r>b*1.9:
                    head.append(x)
        anchor_x=int(statistics.median(head)) if head else 128
        frames.append({'region':[column*256,base_y,256,height], 'anchor':[anchor_x,box[3]-1]})
(root/'resources/ranger_frames.json').write_text(json.dumps(frames,indent=2),encoding='utf-8')
print([(f['anchor']) for f in frames])
from register_hero_animation import register
register()
from register_visible_bounds import register as register_bounds
register_bounds()

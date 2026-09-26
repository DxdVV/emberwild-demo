"""Original deterministic combat cues and data profiles, without external samples."""
from pathlib import Path
import math
import random
import re
import struct
import wave

ROOT = Path(__file__).resolve().parents[1]
PROFILES = {
    'fire': ['spark', 'flare', 'breath'],
    'water': ['splash', 'tide', 'frost'],
    'wood': ['thorn', 'roots', 'sweep'],
    'electric': ['arc', 'storm', 'discharge'],
    'lantern': ['pulse'],
    'heavy': ['slam'],
}


def synth(family, phase, variant, seed):
    rate = 22050
    duration = (.38 if family == 'heavy' else .24) + variant * .012
    rng = random.Random(seed)
    low = 0
    values = []
    for frame in range(int(rate * duration)):
        t = frame / rate
        p = t / duration
        noise = rng.uniform(-1, 1)
        low += .12 * (noise - low)
        onset = min(1, t / .003)
        tail = (1 - p) ** (1.8 if phase == 'cast' else 2.6)
        pitch = 1 + (variant - 1) * .07
        if family == 'fire':
            value = .3 * low + .07 * noise + .13 * math.sin(math.tau * pitch * (180*t - 110*t*t))
        elif family == 'water':
            value = .25 * low + .12 * math.sin(math.tau * pitch * (680*t - 950*t*t)) * math.exp(-t*8)
        elif family == 'wood':
            value = .19 * math.sin(math.tau*155*pitch*t)*math.exp(-t*20) + .23*low + .07*noise*math.exp(-t*38)
        elif family == 'electric':
            value = .08*noise + .15*math.sin(math.tau*740*pitch*t + 2*math.sin(math.tau*75*t))*(.6+.4*math.sin(math.tau*95*t))
        elif family == 'lantern':
            value = (.14*math.sin(math.tau*523*pitch*t)+.08*math.sin(math.tau*784*pitch*t))*math.exp(-t*5)
        else:
            value = .26*math.sin(math.tau*pitch*(68*t-28*t*t)) + .45*low + .08*noise*math.exp(-t*25)
        if phase == 'impact':
            value = value*.7 + .16*math.sin(math.tau*(92 if family!='heavy' else 43)*t)*math.exp(-t*24)
        values.append(int(32767*max(-.9,min(.9,value*onset*tail))))
    path = ROOT / 'assets/audio' / f'{family}-{phase}-{variant+1}.wav'
    with wave.open(str(path), 'wb') as output:
        output.setparams((1,2,rate,0,'NONE','not compressed'))
        output.writeframes(struct.pack(f'<{len(values)}h', *values))
    return path


def build():
    folder = ROOT / 'resources/audio'
    folder.mkdir(parents=True, exist_ok=True)
    for family_index, (family, abilities) in enumerate(PROFILES.items()):
        lines = ['[gd_resource type="Resource" script_class="AbilityAudioData" load_steps=8 format=3]',
                 '[ext_resource type="Script" path="res://scripts/data/ability_audio_data.gd" id="1"]']
        for phase_index, phase in enumerate(('cast','impact')):
            for variant in range(3):
                path = synth(family, phase, variant, 8220+family_index*100+phase_index*10+variant)
                lines.append(f'[ext_resource type="AudioStream" path="res://assets/audio/{path.name}" id="{phase}{variant}"]')
        lines += ['[resource]', 'script = ExtResource("1")', f'id = "{family}"', 'cast_gain_db = -4.0', 'impact_gain_db = -4.0']
        for phase in ('cast','impact'):
            refs = ', '.join(f'ExtResource("{phase}{v}")' for v in range(3))
            lines.append(f'{phase}_samples = Array[AudioStream]([{refs}])')
        (folder/f'{family}.tres').write_text('\n'.join(lines)+'\n', encoding='utf-8')
        for name in abilities:
            path = ROOT/'resources/abilities'/f'{name}.tres'
            text = path.read_text(encoding='utf-8')
            if 'id="audio_profile"' not in text:
                text = re.sub(r'load_steps=(\d+)', lambda match:f'load_steps={int(match[1])+1}', text, count=1)
                text = text.replace('[resource]',f'[ext_resource type="Resource" path="res://resources/audio/{family}.tres" id="audio_profile"]\n[resource]')
                text += 'audio_profile = ExtResource("audio_profile")\n'
            else:
                text = re.sub(r'\[ext_resource[^\n]+id="audio_profile"\]',
                              f'[ext_resource type="Resource" path="res://resources/audio/{family}.tres" id="audio_profile"]', text)
            path.write_text(text, encoding='utf-8')
    print('Combat audio: 6 profiles, 36 samples, 14 ability assignments.')


if __name__ == '__main__':
    build()

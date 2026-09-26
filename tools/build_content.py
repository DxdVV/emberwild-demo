"""Rebuild authored Godot Resources and original synthesized audio. No external packages."""
from pathlib import Path
import json, math, random, re, struct, wave

ROOT = Path(__file__).resolve().parents[1]
def gd(v):
    if isinstance(v, bool): return 'true' if v else 'false'
    if isinstance(v, str): return json.dumps(v, ensure_ascii=False)
    if isinstance(v, dict): return '{'+', '.join(gd(k)+': '+gd(x) for k,x in v.items())+'}'
    if isinstance(v, list): return '['+', '.join(gd(x) for x in v)+']'
    return str(v)

strings = {'key':['ru','en']}
def resource(kind, script, name, fields):
    folder=ROOT/'resources'/kind; folder.mkdir(parents=True,exist_ok=True)
    external = {key:type_name for key,type_name in [('portrait','Texture2D'),('layout','Resource')] if key in fields}
    lines=['[gd_resource type="Resource" script_class="'+script[1]+'" load_steps='+str(2+len(external))+' format=3]',
           '[ext_resource type="Script" path="res://scripts/data/'+script[0]+'.gd" id="1"]','[resource]','script = ExtResource("1")']
    for key,type_name in external.items(): lines.insert(2,'[ext_resource type="'+type_name+'" path="'+fields[key]+'" id="'+key+'"]')
    for key,value in fields.items():
        if key in external: text='ExtResource("'+key+'")'
        elif key in ('color','tint','ground'): text='Color('+','.join(str(x) for x in value)+')'
        elif key == 'size': text='Vector2('+','.join(str(x) for x in value)+')'
        elif isinstance(value,list):
            kind_type='Dictionary' if key in ('effects','modifiers','triggers','spawns','reactions','elite_affixes','item_affixes','boss_phases','ability_unlocks') else 'String'
            text='Array['+kind_type+']('+gd(value)+')'
        else: text=gd(value)
        lines.append(key+' = '+text)
    (folder/(name+'.tres')).write_text('\n'.join(lines)+'\n',encoding='utf-8')

colors={'fire':[1,.43,.13,1],'water':[.25,.82,1,1],'nature':[.55,.85,.32,1],'electric':[.72,.5,1,1],'neutral':[.95,.83,.53,1]}
def label(key,ru,en):
    if key in strings: raise ValueError('Duplicate translation key: '+key)
    formats = lambda text: re.findall(r'%(?:[-+0 #]*\d*(?:\.\d+)?[dfs]|%)', text)
    if not ru or not en or formats(ru) != formats(en):
        raise ValueError('Missing translation or mismatched format placeholders: '+key)
    strings[key]=[ru,en]
    return key
for name,ru,en,element,power,cd,reach,radius,status,cost in [
 ('spark','Искра','Ember bolt','fire',1.1,1.15,250,0,'burn',0),
 ('flare','Огненный веер','Flame fan','fire',2.7,7,280,72,'burn',25),
 ('splash','Водяной осколок','Water shard','water',1,1.3,260,0,'wet',0),
 ('tide','Прилив','Tidal surge','water',2.0,8,260,100,'slow',25),
 ('thorn','Шип','Thorn','nature',1.0,1.1,150,0,'poison',0),
 ('roots','Живые корни','Living roots','nature',1.8,8,240,100,'root',25),
 ('arc','Разряд','Arc','electric',1.15,1.25,275,0,'shock',0),
 ('storm','Грозовая цепь','Chain storm','electric',2.2,8,300,65,'shock',25),
 ('pulse','Импульс фонаря','Lantern pulse','neutral',.65,.6,230,0,'marked',0),
 ('slam','Гнев рощи','Grove wrath','nature',2.5,3.8,310,115,'slow',0)]:
    effects=[{'kind':'status','id':'status.'+status}]
    resource('abilities',('ability_data','AbilityData'),name,{'id':'ability.'+name,'name_key':label('ability.'+name,ru,en),'element':element,'power':power,'cooldown':cd,'windup':1.1 if name=='slam' else .25,'recovery':.28,'reach':reach,'radius':radius,'projectile_speed':320,'cost':cost,'effects':effects,'color':colors[element],'tags':['heavy'] if name=='slam' else ['projectile']})

for name,ru,en,element,delivery,power,reach,angle,status,force in [
 ('breath','Пламенное дыхание','Flame breath','fire','cone',3.2,165,75,'burn',0),
 ('frost','Ледяной круг','Frost ring','water','nova',1.5,150,360,'slow',0),
 ('sweep','Удар ветвей','Branch sweep','nature','cone',2.3,155,120,'root',220),
 ('discharge','Грозовой круг','Thunder ring','electric','nova',1.8,180,360,'shock',0)]:
    effects=[{'kind':'status','id':'status.'+status}]
    if force: effects.append({'kind':'knockback','force':force})
    resource('abilities',('ability_data','AbilityData'),name,{'id':'ability.'+name,'name_key':label('ability.'+name,ru,en),'element':element,'delivery':delivery,'cone_angle':float(angle),'power':power,'cooldown':9.0,'windup':.38,'recovery':.3,'reach':float(reach),'radius':float(reach) if delivery=='nova' else 0.0,'cost':30.0,'effects':effects,'color':colors[element],'tags':[delivery]})

for name,ru,en,category,mods,ability_mods,triggers in [
 ('enduring','Затяжные чары','Lingering magic','individual',[{'stat':'status_duration','op':'flat','value':1.0}],{},[]),
 ('resonant','Резонанс','Resonance','individual',[{'stat':'attack','op':'add','value':-.1}],{'chains':1},[]),
 ('steadfast','Несокрушимость','Steadfast','individual',[],{},[{'event':'swap','effect':'shield','amount':14,'cooldown':8}]),
 ('swift','Проворство','Agility','individual',[{'stat':'speed','op':'add','value':.1},{'stat':'cooldown_reduction','op':'flat','value':.08}],{},[]),
 ('passive.ember','Питание огнём','Fire sustenance','species',[],{},[{'event':'hit','effect':'energy','amount':6,'cooldown':1.5,'conditions':{'target_status':'status.burn'}}]),
 ('passive.flow','Живая вода','Living water','species',[],{},[{'event':'ability_cast','effect':'heal','amount':.04,'cooldown':3}]),
 ('passive.bark','Крепкая кора','Iron bark','species',[],{},[{'event':'damage_taken','effect':'shield','amount':18,'cooldown':6,'conditions':{'health_below':.5}}]),
 ('passive.surge','Перезарядка','Recharge','species',[],{},[{'event':'critical','effect':'energy','amount':8,'cooldown':1}]),
 ('passive.sun','Двойное пламя','Twin flame','species',[],{'projectiles':2},[])]:
    resource('traits',('trait_data','TraitData'),name,{'id':name,'name_key':label('trait.'+name,ru,en),'category':category,'modifiers':mods,'ability_mods':ability_mods,'triggers':triggers})

status_icons = {
 'burn':['0001000','0011000','0011010','0111110','1111111','1110111','0111110'],
 'wet':['0001000','0011100','0011100','0111110','1111011','1111111','0111110'],
 'poison':['0111110','1111111','1010101','1111111','0011100','0010100','0011100'],
 'shock':['0000110','0001100','0011000','0111110','0001100','0011000','0110000'],
 'slow':['1111111','0100010','0010100','0001000','0011100','0111110','1111111'],
 'root':['0001000','0101010','0011100','0001000','0011100','0110110','1100011'],
 'marked':['0011100','0101010','1011101','1111111','1011101','0101010','0011100'],
}
for name,ru,en,element,duration,power,stacks,mods in [
 ('burn','Горение','Burn','fire',4,.22,3,[]),('wet','Промокание','Wet','water',5,0,1,[]),
 ('poison','Яд','Poison','nature',6,.16,4,[]),('shock','Шок','Shock','electric',3,0,1,[{'stat':'defense','op':'add','value':-.25}]),
 ('slow','Замедление','Slow','water',3,0,1,[{'stat':'speed','op':'multiply','value':.55}]),
 ('root','Корни','Root','nature',1.5,0,1,[{'stat':'speed','op':'override','value':0}]),
 ('marked','Метка','Marked','neutral',4,0,1,[{'stat':'defense','op':'add','value':-.3}])]:
    resource('statuses',('status_data','StatusData'),name,{'id':'status.'+name,'name_key':label('status.'+name,ru,en),'duration':duration,'tick_power':power,'max_stacks':stacks,'element':element,'modifiers':mods,'color':colors[element],'icon_rows':status_icons[name]})

for name,ru,en,element,hp,attack,defense,speed,cell,height,abilities,ai in [
 ('cinder','Уголёк','Cinder','fire',120,19,5,135,1,83,['spark','flare'],'ranged'),
 ('rill','Ручеёк','Rill','water',150,16,8,115,2,78,['splash','tide'],'support'),
 ('briar','Вереск','Briar','nature',210,19,16,95,3,115,['thorn','roots'],'tank'),
 ('volt','Грозокрыл','Voltwing','electric',100,24,4,150,4,94,['arc','storm'],'ranged'),
 ('guardian','Страж древней рощи','Ancient Warden','nature',1500,32,14,75,5,175,['thorn','slam'],'boss'),
 ('solstice','Солнцехвост','Solstice','fire',175,29,9,145,1,104,['spark','flare'],'ranged')]:
    fields={'id':'species.'+name,'name_key':label('species.'+name,ru,en),'element':element,'base_stats':{'health':float(hp),'attack':float(attack),'defense':float(defense),'speed':float(speed)},'abilities':['ability.'+a for a in abilities],'sprite_cell':cell,'visual_height':float(height),'color':colors[element],'ai_profile':ai,'tags':[element,ai]}
    if name=='cinder': fields.update(evolution_target='species.solstice',evolution_level=5)
    fields['animation_id']='animation.'+name
    if name=='solstice': fields['portrait']='res://resources/portraits/solstice.tres'
    fields['passives']={'cinder':['passive.ember'],'rill':['passive.flow'],'briar':['passive.bark'],'volt':['passive.surge'],'guardian':['passive.bark'],'solstice':['passive.ember','passive.sun']}[name]
    if name!='guardian': fields['ability_unlocks']=[{'level':3,'ability':'ability.'+{'cinder':'breath','rill':'frost','briar':'sweep','volt':'discharge','solstice':'breath'}[name]}]
    resource('species',('species_data','SpeciesData'),name,fields)

for name,ru,en,desc,cat,slot,rarity,mods,ability_mods,triggers in [
 ('prism','Призма эха','Echo prism','Дополнительные снаряды. Каждая атака поражает до трёх целей.','held','held',2,[],{'projectiles':3},[]),
 ('conductor','Сердце грозы','Storm heart','Атаки перескакивают на соседнюю цель.','held','held',3,[],{'chains':2},[]),
 ('seed','Семя жизни','Life seed','Попадания восстанавливают 4% здоровья владельца.','held','held',1,[],{},[{'event':'hit','effect':'heal','amount':.04,'cooldown':1.5}]),
 ('boots','Сапоги следопыта','Trail boots','Быстрее движение; после уклонения появляется щит.','trainer','boots',1,[{'stat':'speed','op':'add','value':.18}],{},[{'event':'dodge','effect':'shield','amount':18,'cooldown':3}]),
 ('charm','Знак хранителя','Warden sign','Увеличивает здоровье тренера.','trainer','charm',1,[{'stat':'health','op':'flat','value':45}],{},[]),
 ('ember','Угольный фокус','Ember focus','Усиливает атаки владельца.','held','held',0,[{'stat':'attack','op':'add','value':.15}],{},[]),
 ('relic','Корень первозданных','Primordial root','Критическое попадание вызывает грозовой разряд. Награда стража.','held','held',3,[],{'chains':1},[{'event':'critical','effect':'ability','ability':'ability.arc','cooldown':1.5}])]:
    resource('items',('item_data','ItemData'),name,{'id':'item.'+name,'name_key':label('item.'+name,ru,en),'description_key':label('item.'+name+'.desc',desc,desc),'category':cat,'slot':slot,'rarity':rarity,'modifiers':mods,'ability_mods':ability_mods,'triggers':triggers})

resource('areas',('area_data','AreaData'),'haven',{'id':'area.haven','name_key':label('area.haven','Тихая гавань','Stillwater Haven'),'subtitle_key':label('area.haven.sub','Свет фонаря всегда укажет путь домой','A lantern always guides you home'),'size':[1200,850],'safe':True,'ground':[.13,.22,.19,1],'tint':[.87,.96,.91,1],'layout':'res://resources/layouts/haven.tres','exits':['area.grove']})
resource('areas',('area_data','AreaData'),'grove',{'id':'area.grove','name_key':label('area.grove','Янтарная роща','The Amber Grove'),'subtitle_key':label('area.grove.sub','Там, где древние корни хранят память','Where ancient roots remember'),'size':[2400,1600],'level_min':1,'level_max':3,'ground':[.15,.22,.16,1],'tint':[.82,.9,.83,1],'layout':'res://resources/layouts/grove.tres','exits':['area.haven']})
resource('',('rules_data','RulesData'),'rules',{
 'loot_tables':{
  'common':{'chance':.4,'entries':[{'item':'item.'+id,'weight':1.0} for id in ['boots','charm','conductor','ember','prism','seed']]},
  'elite':{'chance':1.0,'entries':[{'item':'item.'+id,'weight':1.0} for id in ['boots','charm','conductor','ember','prism','seed']]},
  'boss':{'chance':1.0,'entries':[{'item':'item.relic','weight':1.0,'level':5,'rarity':3}]}},
 'type_chart':{'fire':{'nature':1.5,'water':.65},'water':{'fire':1.5,'electric':.8},'nature':{'water':1.5,'fire':.65},'electric':{'water':1.5,'nature':.75}},
 'reactions':[{'status':'status.wet','element':'electric','effect':'chain','count':2},{'status':'status.burn','element':'nature','effect':'bonus','multiplier':1.4}],
 'elite_affixes':[{'id':'vampiric','name':'Кровопийца','modifiers':[{'stat':'health','op':'multiply','value':2.0}],'triggers':[{'event':'hit','effect':'heal','amount':.08,'cooldown':1}]},{'id':'swift','name':'Стремительный','modifiers':[{'stat':'speed','op':'multiply','value':1.4}],'triggers':[{'event':'damage_taken','effect':'shield','amount':12,'cooldown':4}]}],
 'item_affixes':[{'id':'stout','name':'Стойкость','modifiers':[{'stat':'health','op':'flat','value':20}]},{'id':'keen','name':'Сила','modifiers':[{'stat':'attack','op':'add','value':.12}]},{'id':'swift','name':'Лёгкость','modifiers':[{'stat':'speed','op':'add','value':.08}]}],
 'boss_phases':[{'threshold':1.0,'interval':3.8,'radius':95.0,'waves':1},{'threshold':.6,'interval':3.0,'radius':110.0,'waves':2},{'threshold':.3,'interval':2.2,'radius':125.0,'waves':3}]})

for key,ru,en in [
 ('world.camp','Лагерь','Camp'),('world.spring','Источник','Spring'),('world.to_grove','В рощу','To the grove'),('world.return','Вернуться','Return'),
 ('combat.reaction','РЕАКЦИЯ','REACTION'),
 ('ui.trait','Особенность','Trait'),('ui.passive','Пассивное умение','Passive'),('ui.command','Командный навык','Command skill'),
 ('ui.unlock','Уровень %d: %s','Level %d: %s'),('ui.no_item','Нет предмета','No held item'),
 ('ui.skill_details','Навык и эффекты: %s','Skill and effects: %s'),
 ('tip.damage','%.1f урона до защиты и сопротивлений','%.1f damage before defense and resistance'),
 ('tip.cost','Энергия: %.0f · перезарядка: %.2f с','Energy: %.0f · cooldown: %.2f s'),
 ('tip.projectile','Снаряд · дальность %.0f · радиус взрыва %.0f','Projectile · range %.0f · blast radius %.0f'),
 ('tip.cone','Сектор перед владельцем · дальность %.0f · угол %.0f°','Cone in front of owner · range %.0f · angle %.0f°'),
 ('tip.nova','Круг вокруг владельца · радиус %.0f','Circle around owner · radius %.0f'),
 ('tip.status','%s: %.1f с · до %d ст.','%s: %.1f s · up to %d stacks'),
 ('tip.dot','%.1f урона/с за каждый заряд до защиты','%.1f damage/s per stack before defense'),
 ('tip.knockback','Отбрасывание: %.0f','Knockback: %.0f'),
 ('tip.projectiles','Дополнительных целей для снарядов: +%d','Additional projectile targets: +%d'),
 ('tip.chains','Дополнительных скачков: +%d','Additional chain jumps: +%d'),
 ('tip.interval','не чаще раза в %.1f с','at most once every %.1f s'),
 ('tip.heal','восстановить %.0f%% максимального здоровья','restore %.0f%% of maximum health'),
 ('tip.shield','получить %.0f щита','gain %.0f shield'),('tip.energy','получить %.0f энергии','gain %.0f energy'),
 ('tip.ability','применить %s к цели','cast %s at target'),('tip.self_status','наложить на себя %s','apply %s to self'),
 ('tip.target_status','если на цели %s','if target has %s'),('tip.owner_status','если на владельце %s','if owner has %s'),
 ('tip.health_below','если здоровье ниже %.0f%%','if health is below %.0f%%'),
 ('event.hit','При попадании','On hit'),('event.critical','При критическом попадании','On critical hit'),
 ('event.kill','При убийстве','On kill'),('event.damage_taken','При получении урона','On taking damage'),
 ('event.swap','При смене с резерва','On swapping in from reserve'),('event.dodge','При уклонении','On dodge'),('event.ability_cast','При применении навыка','On ability cast'),
 ('stat.health','Здоровье','Health'),('stat.attack','Атака','Attack'),('stat.defense','Защита','Defense'),('stat.speed','Скорость','Speed'),
 ('stat.critical_chance','Шанс критического удара','Critical chance'),('stat.cooldown_reduction','Сокращение перезарядки','Cooldown reduction'),
 ('stat.energy_regeneration','Восстановление энергии/с','Energy regeneration/s'),('stat.status_duration','Длительность наложенных эффектов, с','Applied effect duration, s'),
 ('tip.active_mods','В сумме: до %d целей снарядами, до %d скачков','Combined: up to %d projectile targets, up to %d chain jumps')]: label(key,ru,en)

for key,ru,en in [
 ('input.title','Управление','Controls'),('loot.title','Фильтр добычи','Loot filter'),('settings.back','← Настройки','← Settings'),
 ('input.help','Выберите ячейку и нажмите клавишу, сочетание или кнопку мыши. Esc — отмена. Последнюю привязку удалить нельзя.','Choose a cell, then press a key, chord or mouse button. Esc cancels. Each action must retain a binding.'),
 ('input.capture_prompt','Назначение: %s. Нажмите клавишу или кнопку мыши; Esc — отмена.','Binding: %s. Press a key or mouse button; Esc cancels.'),
 ('input.conflict','Уже занято: %s. Выберите другую клавишу или сначала измените занятую привязку. Esc — отмена.','Already used by: %s. Choose another key or change that binding first. Esc cancels.'),
 ('input.reset','Восстановить стандартное управление','Restore default controls'),('input.remove','Удалить дополнительную привязку','Remove binding'),
 ('settings.save_failed','Не удалось записать настройки. Изменения действуют до выхода.','Could not save settings. Changes remain active until exit.'),
 ('input.footer','%s движение   %s атака   %s рывок   %s рюкзак   %s команда   %s действие   %s вся добыча','%s move   %s attack   %s dodge   %s inventory   %s party   %s interact   %s all loot'),
 ('input.camp_hint','%s у лагеря — припасы, у источника — лечение. Арка справа ведёт в рощу.','%s at camp: supplies; at the spring: healing. The arch to the right leads to the grove.'),
 ('input.party_hint','Два существа активны. Командные навыки: %s / %s. Смена — кнопками на карточке.','Two active creatures. Command skills: %s / %s. Swap using the card buttons.'),
 ('input.mouse.1','ЛКМ','LMB'),('input.mouse.2','ПКМ','RMB'),('input.mouse.3','СКМ','MMB'),('input.mouse.8','Мышь 4','Mouse 4'),('input.mouse.9','Мышь 5','Mouse 5'),
 ('loot.help','Фильтр скрывает метки и исключает предметы из подбора. Предметы остаются в мире. Удерживайте %s, чтобы увидеть и подобрать всё.','The filter hides labels and excludes items from pickup. Items remain in the world. Hold %s to reveal and pick up everything.'),
 ('loot.minimum','Минимальная редкость','Minimum rarity'),('loot.category.held','Предметы для существ','Creature held items'),('loot.category.trainer','Экипировка хранительницы','Trainer equipment'),
 ('loot.unique','Всегда показывать уникальные предметы','Always show unique items'),('loot.reset','Показывать всю добычу','Show all loot'),
 ('rarity.0','Обычный и выше','Common and above'),('rarity.1','Магический и выше','Magic and above'),('rarity.2','Редкий и выше','Rare and above'),('rarity.3','Только уникальный','Unique only')]: label(key,ru,en)

for key,ru,en in [
 ('move_left','Движение влево','Move left'),('move_right','Движение вправо','Move right'),('move_up','Движение вверх','Move up'),('move_down','Движение вниз','Move down'),
 ('dodge','Рывок','Dodge'),('attack','Атака хранительницы','Trainer attack'),('focus','Выбрать цель','Focus target'),('ability_one','Навык первого спутника','First companion skill'),('ability_two','Навык второго спутника','Second companion skill'),
 ('capture','Захват существа','Capture creature'),('interact','Взаимодействие / подбор','Interact / pick up'),('inventory','Рюкзак','Inventory'),('party','Команда','Party'),('potion','Лечение','Healing'),
 ('pause','Пауза (Esc доступен всегда)','Pause (Esc always available)'),('debug_menu','Инструменты разработчика','Developer tools'),('companion_mode','Режим команды','Party mode'),
 ('save_game','Быстрое сохранение','Quick save'),('load_game','Быстрая загрузка','Quick load'),('show_all_loot','Показать всю добычу (удерживать)','Reveal all loot (hold)')]: label('input.'+key,ru,en)
for index,name in enumerate(['one','two','three','four']):
    label('input.swap_'+name,f'Существо {index+1} → слот 1',f'Creature {index+1} → slot 1')
    label('input.swap_second_'+str(index+1),f'Существо {index+1} → слот 2',f'Creature {index+1} → slot 2')

import csv
from inspection_strings import register as register_inspection_strings
register_inspection_strings(label)
from ui_strings import register as register_ui_strings
register_ui_strings(label)
with (ROOT/'resources/strings.csv').open('w',newline='',encoding='utf-8') as f:
    writer=csv.writer(f); writer.writerow(['keys','ru','en'])
    for key,langs in strings.items():
        if key!='key': writer.writerow([key]+langs)

def write_sound(name,seconds,sample):
    rate=22050
    path=ROOT/'assets/audio'/f'{name}.wav'; path.parent.mkdir(parents=True,exist_ok=True)
    with wave.open(str(path),'wb') as f:
        f.setparams((1,2,rate,0,'NONE','not compressed'))
        values=(max(-.95,min(.95,sample(i/rate,seconds))) for i in range(int(seconds*rate)))
        f.writeframes(b''.join(struct.pack('<h',int(x*32767)) for x in values))

rng=random.Random(188)
write_sound('cast',.3,lambda t,d: .23*math.sin(2*math.pi*(520*t-420*t*t))*math.exp(-t*13)+rng.uniform(-.05,.05)*math.exp(-t*20))
write_sound('hit',.2,lambda t,d: (.25*math.sin(2*math.pi*90*t)+rng.uniform(-.17,.17))*math.exp(-t*24))
write_sound('capture',1,lambda t,d: sum(math.sin(2*math.pi*f*t) for f in [440,554.37,659.25])*.1*math.sin(math.pi*t/d)**2)
write_sound('ui',.12,lambda t,d: .12*math.sin(2*math.pi*880*t)*math.exp(-t*35))
write_sound('dodge',.25,lambda t,d: rng.uniform(-.15,.15)*math.sin(math.pi*t/d)**2)
write_sound('loot',.6,lambda t,d: .12*(math.sin(2*math.pi*1046*t)+math.sin(2*math.pi*1318*t))*math.exp(-t*8))
write_sound('ambience',12,lambda t,d: (.013*math.sin(2*math.pi*117*t)+rng.uniform(-.025,.025))*(.7+.3*math.sin(2*math.pi*t/d)))
notes=[146.83,220,293.66,329.63,440,392,329.63,220]
def music(t,d):
    beat=t%2; note=notes[int(t/2)%len(notes)]
    chime=.055*(math.sin(2*math.pi*note*t)+.4*math.sin(2*math.pi*note*2*t))*math.exp(-beat*2.5)
    pad=sum(math.sin(2*math.pi*f*t) for f in [73.416,110,146.832])*.018
    return (chime+pad)*min(1,t/2,(d-t)/2)
write_sound('music',32,music)
from build_footsteps import build as build_footsteps
build_footsteps()
from build_combat_audio import build as build_combat_audio
build_combat_audio()
print('Content and audio built.')

# Техническое задание №2
# Action-RPG в духе Diablo II с системой существ в духе Pokémon

## 0. Назначение документа

Этот документ дополняет основное техническое ТЗ проекта.

Первый документ определяет:

- инженерный quality bar;
- архитектурные принципы;
- визуальные стандарты;
- правила работы с Godot;
- требования к качеству реализации.

Этот документ определяет:

- игровую архитектуру;
- структуру мира;
- систему существ;
- боевую систему;
- систему билдов;
- лут;
- прогрессию;
- требования к data-driven архитектуре.

Жанр и конкретные игровые механики могут уточняться позднее.

Не воспринимать отдельные числовые значения этого документа как окончательный баланс.

Главная задача — заложить архитектуру, которая позволит развивать эту концепцию без переписывания фундаментальных систем.

---

# 1. Общая концепция

Игра — изометрическая / псевдоизометрическая Action RPG.

Основные источники вдохновения по структуре:

- Diablo II;
- современные loot-based ARPG;
- Pokémon как идея коллекционирования, типов, видов, эволюций и формирования команды.

Это НЕ пошаговая Pokémon-игра.

Это НЕ Diablo с косметически заменёнными монстрами.

Существа должны быть центральной частью:

- боя;
- билдостроения;
- прогрессии;
- исследования мира;
- коллекционирования;
- экономики предметов;
- тактических решений.

Главная формула:

ARPG combat
+
party building
+
creature collection
+
loot hunt
+
elemental synergies
+
character progression.

---

# 2. Главный принцип дизайна

Основной билд игрока состоит не из одного персонажа.

Билд — это комбинация:

- тренера;
- активных существ;
- резервных существ;
- их способностей;
- пассивных свойств;
- held items;
- экипировки тренера;
- модификаторов навыков;
- синергий команды.

Команда должна рассматриваться как единая build system.

Замена одного существа потенциально должна менять игровой стиль всего билда.

---

# 3. Управляемый персонаж

По умолчанию игрок непосредственно управляет тренером.

Тренер:

- перемещается по миру;
- уклоняется;
- взаимодействует;
- использует предметы;
- отдаёт команды;
- активирует некоторые собственные способности;
- управляет вызовом и сменой существ.

Тренер не должен быть главным источником чистого урона, если дизайн конкретного билда не предусматривает обратного.

Главная сила игрока — команда.

При этом тренер не должен ощущаться беспомощным курсором для вызова питомцев.

У него должны быть собственные:

- defensive tools;
- mobility;
- utility;
- tactical abilities;
- equipment;
- progression.

---

# 4. Активная команда

Архитектурно предусмотреть:

- активных существ;
- резерв команды;
- быстрое переключение;
- вызов;
- отзыв;
- смерть / потерю боеспособности;
- cooldown смены;
- эффекты смены.

Конкретное количество активных существ определяется позже.

Архитектура не должна жёстко предполагать ровно одного активного питомца.

Желательно проектировать систему так, чтобы поддерживалось:

1 active creature;
2 active creatures;
возможные временные дополнительные summons.

---

# 5. Управление существами

Существа могут сочетать:

- автономный AI;
- прямые команды;
- способности на hotkeys.

Базовая модель:

существо самостоятельно:

- следует за игроком;
- выбирает позицию;
- использует базовое поведение;
- атакует подходящие цели;

а игрок управляет:

- ключевыми способностями;
- целью;
- сменой существа;
- режимом поведения.

Архитектура AI должна позволять иметь режимы вроде:

Aggressive
Defensive
Follow
Hold Position
Focus Target

без переписывания AI каждого вида.

---

# 6. Существа как data-driven сущности

Каждый вид существа должен описываться ресурсом данных.

Пример:

CreatureSpeciesResource

Потенциальные поля:

- species_id;
- display_name;
- base_stats;
- primary_type;
- secondary_type;
- movement_profile;
- available_abilities;
- passive_abilities;
- evolution_data;
- animation_set;
- visual_scene;
- audio_profile;
- AI profile;
- capture properties;
- tags.

Не привязывать основные характеристики вида непосредственно к конкретной scene.

Scene отвечает за представление и runtime components.

Resource отвечает за данные.

---

# 7. Отдельно Species и Individual

Не смешивать понятие вида существа и конкретной особи.

Нужно разделить:

SpeciesData

и

CreatureInstanceData.

SpeciesData описывает:

- что это за вид;
- базовые характеристики;
- возможные способности;
- типы;
- эволюции.

CreatureInstanceData описывает конкретное существо игрока:

- уникальный ID;
- уровень;
- опыт;
- выбранные способности;
- индивидуальные traits;
- возможную nature;
- индивидуальные параметры;
- equipped held item;
- cosmetic variant;
- progression.

Это необходимо для save system.

---

# 8. Система характеристик

Статы должны рассчитываться через централизованную систему.

Не хранить итоговые значения в десятках объектов.

Условная модель:

Base stat
+
level scaling
+
individual modifiers
+
equipment
+
passives
+
buffs
+
debuffs
+
environment effects
=
final stat.

Должна существовать одна понятная точка расчёта итогового значения.

Поддерживать modifiers:

flat;
additive percentage;
multiplicative;
override при необходимости.

Избегать хаотичного:

damage *= 1.2

в разных скриптах.

---

# 9. Типы

Типы являются отдельной системой.

Не писать:

if fire:
if water:
if grass:

в gameplay scripts.

Использовать TypeResource / TypeRegistry или аналогичную data-driven систему.

Каждый тип должен иметь стабильный ID.

Система взаимодействий типов должна храниться централизованно.

Пример:

Fire -> Grass = 2.0
Fire -> Water = 0.5

Но конкретные коэффициенты и правила могут отличаться от оригинального Pokémon.

Архитектура должна позволять менять таблицу типов без изменения DamageSystem.

---

# 10. Damage System

Вся боевая математика должна проходить через единый DamageSystem.

Damage event должен содержать контекст.

Например:

DamageRequest

- source;
- target;
- base_damage;
- damage_types;
- ability;
- critical info;
- modifiers;
- tags.

DamageResult:

- final_damage;
- blocked;
- critical;
- effectiveness;
- applied_statuses;
- killed;
- absorbed;
- resisted.

Не рассчитывать урон отдельно внутри каждой способности.

---

# 11. Способности

Способность должна быть data-driven объектом.

AbilityResource может содержать:

- ability_id;
- name;
- tags;
- damage profile;
- elemental type;
- cooldown;
- cast time;
- animation;
- targeting type;
- projectile;
- area;
- cost;
- effects;
- status applications;
- visual effect;
- sound;
- AI usage rules.

Код способности должен быть модульным.

Не создавать отдельный уникальный скрипт на каждый простой удар.

---

# 12. Ability Effects

Способность желательно собирать из эффектов.

Например:

Flamethrower

может состоять из:

DamageEffect
+
BurnEffect
+
KnockbackEffect
+
VisualEffect.

Другой ability может использовать те же компоненты.

Это позволит создавать большое количество навыков без огромного числа почти одинаковых скриптов.

Не доводить систему до абстрактного универсального scripting engine без необходимости.

---

# 13. Модификация способностей

Один из главных элементов ARPG — возможность менять поведение навыка.

Модификаторы должны уметь изменять не только цифры.

Примеры:

- projectile count;
- projectile speed;
- chain count;
- area;
- penetration;
- conversion of damage type;
- additional status;
- behavior on kill;
- behavior on critical;
- cooldown;
- duration;
- triggered secondary ability.

Хороший modifier:

"Fireball после попадания разделяется на три меньших огненных снаряда."

Плохой основной дизайн:

"+4% Fireball damage."

Числовые бонусы допустимы, но не должны быть единственной формой развития.

---

# 14. Триггерная система

Нужно предусмотреть event / trigger architecture.

Примеры триггеров:

OnHit
OnCriticalHit
OnKill
OnDamageTaken
OnStatusApplied
OnAbilityCast
OnCreatureSwap
OnSummon
OnLowHealth
OnDodge.

Они могут использоваться:

- пассивами;
- предметами;
- способностями;
- синергиями;
- traits.

Следить, чтобы trigger system не превращалась в бесконечную рекурсию.

Нужны safeguards против:

OnHit -> ability -> OnHit -> ability -> ...

---

# 15. Статусные эффекты

StatusEffect является отдельной фундаментальной системой.

Поддерживать:

- duration;
- stacks;
- max stacks;
- refresh behavior;
- source;
- periodic effects;
- stat modifiers;
- visual representation;
- removal conditions.

Примеры:

Burn
Poison
Freeze
Shock
Bleed
Slow
Blind
Marked.

Правила stack/refresh должны задаваться данными конкретного эффекта.

---

# 16. Элементальные взаимодействия

Не ограничиваться исключительно таблицей "эффективно / неэффективно".

Позже система должна позволять создавать взаимодействия между состояниями.

Пример:

Burning + Electric
=> дополнительный эффект.

Wet + Electric
=> chain shock.

Frozen + Heavy Hit
=> shatter.

Oil + Fire
=> ignition.

Это не обязательные конкретные механики.

Но архитектура StatusEffect/Ability должна позволять подобные комбинации без переписывания боевой системы.

---

# 17. Party Synergy

Команда должна создавать дополнительные комбинации.

Возможные источники synergy:

- типы;
- теги;
- способности;
- пассивы;
- weather;
- status effects;
- последовательность действий.

Пример:

существо A поджигает врагов;
существо B получает бонус против burning targets;
существо C распространяет status при убийстве.

Это должно образовывать единый build loop.

---

# 18. Смена активного существа

Swap должен быть полноценной механикой, а не меню.

Смена может потенциально:

- иметь cooldown;
- давать invulnerability window;
- запускать способность;
- давать buff;
- создавать эффект входа/выхода;
- активировать пассивы.

Архитектурно предусмотреть события:

creature_about_to_swap_out
creature_swapped_out
creature_swapped_in.

---

# 19. Progression существа

У существа должна быть собственная прогрессия.

Минимально архитектура должна поддерживать:

- level;
- XP;
- unlock abilities;
- passive progression;
- evolution.

Не копировать систему Pokémon буквально, если она плохо работает в real-time ARPG.

Система должна быть адаптирована под быстрый action gameplay.

---

# 20. Эволюции

Evolution является данными, а не hardcoded logic.

EvolutionRule может потенциально проверять:

- level;
- item;
- quest state;
- environment;
- relationship;
- special trigger.

После эволюции должна быть возможность:

- изменить SpeciesResource;
- сохранить identity конкретной особи;
- сохранить relevant progression;
- обновить доступные способности;
- обновить visuals.

---

# 21. Индивидуальные особенности существ

Возможна система Traits.

Traits должны давать интересные различия между особями.

Предпочтительно:

"Burn длится на 1 сек дольше"

или

"после уклонения следующая Electric attack chain'ится"

вместо исключительно:

"+2 Strength."

Особь должна иногда создавать новую идею для билда.

---

# 22. Shiny / cosmetic variants

Редкие цветовые варианты не должны автоматически означать лучшие боевые характеристики.

Разделять:

cosmetic rarity

и

gameplay power.

Редкость визуального варианта может быть чисто коллекционной.

---

# 23. Capture System

Система захвата должна быть независимой gameplay system.

Не связывать захват напрямую со смертью врага.

Она потенциально может учитывать:

- HP;
- status effects;
- rarity;
- creature state;
- capture device;
- trainer modifiers;
- environmental conditions.

Конкретная формула определяется позже.

CaptureResult должен быть воспроизводимым и понятным для gameplay logic.

---

# 24. Дикие существа

Дикие существа используют ту же фундаментальную Creature system, что и существа игрока.

Не создавать отдельную параллельную архитектуру "enemy Pokémon".

Различаться должны controller/AI/faction/runtime configuration.

Это позволяет потенциально:

встретить существо как врага;
поймать его;
затем использовать то же поведение и способности как союзника.

---

# 25. Factions

Actors должны иметь систему faction/team relationship.

Например:

Player
PlayerCreatures
WildNeutral
WildHostile
EnemyTrainers
Boss
Environment.

Не проверять:

if body.name == "Player"

или

if body is Enemy.

Использовать единый faction system.

---

# 26. AI

AI должен строиться из общих систем.

Разделить:

- perception;
- target selection;
- movement;
- ability selection;
- state;
- tactical preferences.

Не писать полностью отдельный AI для каждого вида.

Вид может задавать:

AIProfile.

Например:

MeleeAggressive
RangedKiter
Support
Ambusher
Tank
PackHunter.

А конкретные параметры задаются Resource.

---

# 27. Elite enemies

В духе ARPG должны существовать элитные варианты врагов.

Elite modifiers должны быть data-driven.

Примеры:

Fast
Armored
Burning
Teleporting
Vampiric
Explosive.

Конкретные названия и механики определяются позже.

Важно:

elite modifier должен изменять поведение или боевой сценарий, а не только увеличивать HP.

---

# 28. Affix system

Создать общую систему affix/modifiers.

Она должна потенциально использоваться для:

- предметов;
- elite enemies;
- rare creatures;
- dungeon modifiers.

Не обязательно одна и та же конкретная реализация для всего.

Но логика modifiers должна быть переиспользуемой.

---

# 29. Boss architecture

Боссы должны иметь отдельную фазовую архитектуру.

Boss может иметь:

- phases;
- phase transitions;
- scripted mechanics;
- arena events;
- adds;
- environmental hazards.

Не строить boss fight одним огромным script с сотней if.

Использовать state / phase system.

---

# 30. Лут

Игра должна поддерживать полноценный loot hunt.

Лут делится как минимум на:

1. Trainer Equipment
2. Creature Held Items
3. Ability Modifiers
4. Consumables
5. Crafting / upgrade resources
6. Quest / key items.

Не заставлять существ носить человеческие доспехи только ради копирования Diablo.

---

# 31. Trainer Equipment

Тренер может иметь экипировку.

Например:

Head
Body
Gloves
Boots
Backpack
Device
Charm.

Финальные slots определяются дизайном.

Экипировка может влиять на:

- trainer stats;
- movement;
- capture;
- summon behavior;
- team bonuses;
- cooldown;
- support abilities.

---

# 32. Held Items

Существо может иметь ограниченное число собственных предметов.

Held Item должен иметь серьёзный эффект на билд.

Пример:

"Electric attacks have a chance to chain."

лучше, чем:

"+7% electric damage."

---

# 33. Item rarity

Архитектура должна поддерживать rarity tiers.

Например:

Normal
Magic
Rare
Unique.

Названия могут измениться.

Rare item:

base item
+
random affixes.

Unique item:

имеет предопределённую identity;
может содержать уникальный mechanic-changing effect.

Unique предметы должны быть инструментом билдостроения.

---

# 34. Не превращать игру в loot spam

Количество выпадающих предметов должно контролироваться.

Не проектировать экономику вокруг тысячи бесполезных предметов в минуту.

Хороший loot system должен создавать:

- anticipation;
- recognition;
- meaningful decisions.

Нужно предусмотреть:

loot filter;
item labels;
rarity feedback;
auto-pickup для валюты/ресурсов.

---

# 35. Item generation

Предмет должен генерироваться централизованной системой.

ItemGenerator:

BaseItem
+
Rarity
+
AffixPool
+
ItemLevel
+
GenerationRules.

Использовать deterministic/random seed там, где это полезно для отладки.

---

# 36. Inventory

Inventory является отдельной системой данных.

Не хранить сами runtime Nodes предметов внутри inventory.

Inventory хранит ItemInstanceData.

World drop является представлением этих данных в мире.

Это важно для:

- save/load;
- transfer;
- stash;
- vendors;
- multiplayer compatibility в будущем, даже если multiplayer не планируется сейчас.

---

# 37. Stash

С самого начала учитывать существование:

- personal inventory;
- stash;
- возможно shared stash.

Не добавлять stash как костыль после создания inventory.

---

# 38. World structure

Не делать обязательный огромный бесшовный open world.

Предпочтительная структура:

ACT / REGION
    HUB
    CONNECTED AREAS
    DUNGEONS
    OPTIONAL AREAS
    BOSS AREA.

Например:

Region 1
├── Town
├── Route
├── Forest
├── Cave
├── Ruins
├── Optional Dungeon
└── Boss Location.

Такая структура позволяет:

- лучше контролировать темп;
- создавать плотные локации;
- оптимизировать загрузку;
- делать procedural variation;
- повторно посещать зоны.

---

# 39. World Areas

Каждая Area должна иметь WorldAreaResource.

Потенциальные данные:

- area_id;
- biome;
- level range;
- creature spawn tables;
- elite rules;
- loot tables;
- weather;
- lighting profile;
- music;
- ambience;
- procedural rules;
- exits;
- encounter definitions.

---

# 40. Генерация уровней

Не использовать чистый хаотичный procedural generation для визуально богатых локаций.

Предпочтительно:

hand-authored chunks
+
procedural arrangement
+
procedural population.

То есть художник/дизайнер создаёт качественные куски среды.

Генератор собирает из них вариации.

Это позволяет одновременно получить:

- высокий visual quality;
- replayability.

---

# 41. Seed

Procedural systems должны иметь seed.

При одинаковом:

seed
+
world state
+
generator version

генерация должна быть максимально воспроизводимой.

Это критично для отладки.

Debug menu должен позволять видеть и копировать текущий seed.

---

# 42. Spawn System

Spawn logic не должна быть разбросана по уровню.

Нужен SpawnDirector / EncounterSystem или аналог.

Он управляет:

- spawn tables;
- density;
- pack composition;
- elites;
- rarity;
- encounter budget;
- area rules.

---

# 43. Packs

Враги должны появляться осмысленными группами.

Не просто случайное распределение отдельных существ.

Поддерживать pack definitions.

Например:

Leader
+
Melee units
+
Support unit.

Это создаёт более интересные encounter'ы.

---

# 44. Encounter Director

В перспективе система должна уметь контролировать интенсивность боя.

Она может учитывать:

- количество живых врагов;
- силу игрока;
- геометрию зоны;
- текущий encounter;
- время после последней схватки.

Но не использовать агрессивный dynamic scaling, который делает прогрессию бессмысленной.

---

# 45. Level scaling

Не масштабировать автоматически каждого врага точно под уровень игрока.

Игрок должен ощущать:

- слабые зоны;
- опасные зоны;
- рост собственной силы.

Допускается ограниченное scaling внутри диапазона зоны.

Например:

AreaLevel 20-24.

---

# 46. Difficulty

Система сложности может изменять:

- enemy composition;
- elite frequency;
- AI behavior;
- affix complexity;
- boss mechanics;
- rewards.

Не делать основной эффект сложности:

Enemy HP x 5.

---

# 47. Endgame readiness

Не обязательно реализовывать endgame сразу.

Но фундамент не должен ему мешать.

В будущем должны быть возможны:

- procedural dungeons;
- modifiers;
- higher difficulty;
- rare encounters;
- special bosses;
- targeted farming.

---

# 48. Weather

Погода потенциально может быть gameplay system.

Например:

Rain
Sun
Sandstorm
Fog.

Она может влиять:

- визуально;
- на типы;
- на abilities;
- на spawn tables.

Не смешивать weather visuals и gameplay effects в одном скрипте.

EnvironmentState сообщает состояние.

Presentation отображает его.

Gameplay systems реагируют на него.

---

# 49. Day/Night

Если будет реализована смена времени суток, архитектурно отделить:

World Time
от
Lighting Presentation.

Время суток потенциально может менять:

- spawn creatures;
- quests;
- environment;
- weather probabilities;
- encounters.

Но система не обязательна для первого vertical slice.

---

# 50. Навигация существ

Companion AI должен особенно хорошо решать:

- следование;
- обход препятствий;
- телепортацию к игроку при потере;
- узкие проходы;
- crowded combat;
- смену цели.

Нельзя допускать ситуацию, когда питомцы постоянно застревают в геометрии.

Предусмотреть fallback recovery.

---

# 51. Off-screen companions

Если companion слишком далеко от игрока из-за navigation failure:

не заставлять его идти через половину карты.

Использовать корректный recovery mechanism:

- reposition;
- teleport outside viewport;
- respawn near player.

С визуальным скрытием, если это необходимо.

---

# 52. Targeting

Нужна централизованная TargetingSystem.

Она должна поддерживать:

- nearest target;
- target under cursor;
- priority target;
- locked target;
- cone;
- area;
- chain;
- random valid target.

AI и player abilities желательно должны использовать общие правила определения valid targets.

---

# 53. Telegraphs

Сильные вражеские способности должны иметь читаемые telegraphs.

Использовать:

- animation;
- ground indicators;
- sound;
- particle;
- pose.

Игрок должен понимать опасность до попадания.

Высокая сложность должна происходить из необходимости правильно реагировать, а не из невидимых атак.

---

# 54. Combat readability

Несмотря на богатый pixel-art, бой должен оставаться читаемым.

Приоритет:

gameplay information
>
декоративные эффекты.

Особенно различимы должны быть:

- player;
- active creatures;
- enemy attacks;
- AoE;
- projectiles;
- dangerous statuses;
- interactable objects;
- loot.

Effects должны иметь лимиты визуального шума.

---

# 55. Слои визуальных эффектов

Разделять эффекты по важности.

Например:

GameplayCritical
GameplayFeedback
Ambient
Decorative.

При снижении графических настроек сначала уменьшать Decorative.

Нельзя отключать telegraph босса ради производительности.

---

# 56. Camera для ARPG

Камера должна показывать достаточно пространства вокруг персонажа.

Нельзя чрезмерно приближать её ради демонстрации детализации pixel-art.

Приоритет:

понимание поля боя.

Камера потенциально может иметь небольшой look-ahead по направлению движения / курсора.

---

# 57. Базовое разрешение

Для данного конкретного проекта рассматривать:

960x540

как сильный кандидат на внутреннее разрешение.

Причины:

- высокая детализация pixel-art;
- большое поле боя;
- несколько существ;
- группы врагов;
- projectiles;
- effects;
- loot;
- environment.

Не фиксировать окончательно без visual prototype.

Сделать ранний rendering test:

640x360
против
960x540.

Выбрать минимальное разрешение, которое обеспечивает необходимую читаемость и детализацию.

---

# 58. Character scale

В 960x540 основные существа могут иметь ориентировочный visual height:

80-140 px

в зависимости от размера вида.

Большие виды могут быть значительно крупнее.

Не делать всех существ визуально одного размера ради удобства коллизий.

Visual size
и
gameplay collision size

могут различаться.

---

# 59. Animation architecture

AnimationController не должен определять gameplay самостоятельно.

Gameplay сообщает:

started attack
cast complete
was hit
died.

Presentation воспроизводит соответствующую анимацию.

Для gameplay-critical timing использовать explicit gameplay events.

Не полагаться исключительно на случайную длину sprite animation.

---

# 60. Ability timing

Способность должна иметь понятные фазы:

Windup
Activation
Recovery.

Это позволяет:

- animation cancel rules;
- interruption;
- telegraph;
- attack speed scaling.

Не считать ability просто cooldown timer + damage.

---

# 61. Cooldown System

Нужна единая cooldown architecture.

Поддерживать:

- base cooldown;
- cooldown modifiers;
- global cooldown при необходимости;
- charge-based abilities;
- cooldown reset;
- cooldown reduction.

Не реализовывать cooldown каждым ability script самостоятельно.

---

# 62. Resource / Energy Systems

Если существа или тренер используют ресурсы:

Mana
Energy
Stamina
Charges

система должна быть компонентной.

Не предполагать, что все Actors используют один и тот же ресурс.

---

# 63. Death / Defeat

Разделять:

Trainer defeated
Creature defeated.

Существо может быть:

active;
downed;
unavailable;
revived.

Правила определяются дизайном.

Но runtime architecture должна различать смерть игрового Actor и уничтожение Node.

Не queue_free() важное существо игрока как единственную форму смерти.

---

# 64. Persistence

Сохранять идентичность пойманных существ.

У каждой особи должен быть persistent unique ID.

Save game должен хранить:

- species;
- individual progression;
- traits;
- abilities;
- held items;
- cosmetic variant;
- relevant history.

Не хранить NodePath в save data.

---

# 65. Stable IDs

Все игровые данные должны использовать стабильные ID.

Например:

species.pikachu
ability.thunderbolt
item.magnet
status.burn
area.forest_01.

Save не должен зависеть от:

- resource path;
- Node name;
- display name.

Переименование файлов не должно ломать сохранения.

---

# 66. Content Registry

Для data-driven контента желательно иметь централизованный registry / database layer.

Он должен позволять получить Resource по ID.

Например:

GameDatabase.get_species(id)
GameDatabase.get_ability(id)
GameDatabase.get_item(id).

Не загружать Resources хаотично по строковым путям из gameplay-кода.

---

# 67. Validation

При запуске development build желательно валидировать content data.

Например:

- duplicate IDs;
- missing ability;
- invalid evolution target;
- missing sprite;
- invalid affix;
- circular references.

Ошибка в данных должна обнаруживаться заранее, а не после 20 часов игры.

---

# 68. Localization readiness

Display names и descriptions не должны использоваться как внутренние ID.

Сразу предусмотреть локализацию.

Контент должен ссылаться на localization keys.

Например:

creature.pikachu.name

а не использовать строку "Pikachu" как системное значение.

---

# 69. Tooltips

Предметы, способности, status effects и существа должны использовать общую систему описания.

Tooltip должен уметь получать данные из gameplay systems.

Не хранить вручную текст:

"наносит 42 урона"

если значение реально вычисляется системой и может стать 57.

Числовые значения tooltips должны строиться из актуальных данных.

---

# 70. Codex и новая механика

При добавлении новой системы Codex сначала должен определить:

- это новая фундаментальная система;
- новый компонент;
- новый Resource;
- новый modifier;
- или просто новый контент существующей системы.

Не создавать новый subsystem, если задача решается добавлением данных.

Пример:

новая Fire ability

обычно должна означать новый AbilityResource,

а не новый глобальный FireAbilityManager.

---

# 71. Правило масштабирования контента

Проект должен быть способен масштабироваться до большого количества:

- creatures;
- abilities;
- items;
- affixes;
- areas.

Если добавление 100-го существа требует изменить 20 switch/case в коде — архитектура неправильная.

Если добавление нового вида требует преимущественно:

Resource
+
sprites
+
animations
+
audio
+
configuration,

архитектура движется в правильном направлении.

---

# 72. Первый vertical slice

Не начинать с создания огромного Pokédex или сотен предметов.

Первый vertical slice должен содержать примерно:

- 1 небольшую качественную локацию;
- 1 хаб или тестовую безопасную область;
- тренера;
- 3-5 полноценных видов существ;
- несколько диких противников;
- минимум 1 elite enemy;
- 1 небольшой boss encounter;
- capture;
- смену существ;
- несколько abilities;
- types;
- status effects;
- loot;
- held items;
- inventory;
- basic progression;
- полноценный visual presentation.

Цель vertical slice:

доказать, что фундаментальный gameplay loop интересен.

---

# 73. Vertical slice quality

Vertical slice не должен быть просто технической демкой.

Он должен показать целевой уровень:

- pixel-art;
- animation;
- particles;
- sound;
- lighting;
- combat feel;
- UI;
- responsiveness;
- loot feedback.

Допустим placeholder только там, где он не мешает оценить систему.

---

# 74. Второй этап

После успешного vertical slice:

расширять количество:

- существ;
- навыков;
- enemy archetypes;
- предметов;
- affixes.

Не начинать производство большой карты до подтверждения core gameplay.

---

# 75. Третий этап

Только после стабилизации основных systems:

- procedural world;
- несколько биомов;
- полноценная progression curve;
- economy;
- extended bosses;
- endgame prototypes.

---

# 76. Порядок разработки фундаментальных систем

Предпочтительный порядок:

1. Actor architecture
2. Stats
3. Factions
4. Damage
5. Health
6. Ability system
7. Status effects
8. Type system
9. Creature data
10. Companion controller
11. AI
12. Party
13. Creature switching
14. Capture
15. Items
16. Inventory
17. Loot generation
18. Affixes
19. Progression
20. Save system
21. World areas
22. Spawn system
23. Procedural generation.

Порядок может изменяться при наличии технической причины.

---

# 77. Не делать заранее

До рабочего vertical slice НЕ тратить значительное время на:

- сотни существ;
- огромный мир;
- сложную экономику;
- crafting tree;
- endgame;
- multiplayer;
- десятки биомов;
- exhaustive Pokédex UI;
- процедурную генерацию всего мира.

Сначала доказать качество core loop.

---

# 78. Core gameplay loop

Базовый loop:

Explore
↓
Encounter enemies
↓
Fight
↓
Gain loot / XP
↓
Encounter creatures
↓
Capture / evaluate
↓
Improve team
↓
Create stronger synergies
↓
Enter harder area
↓
Fight elites / boss
↓
Receive build-defining rewards
↓
Repeat.

Каждая большая система должна усиливать этот loop.

Если система никак с ним не взаимодействует, необходимо отдельно обосновать её необходимость.

---

# 79. Philosophy of progression

Прогрессия должна давать не только:

"старые действия, но цифры больше."

По мере развития игрок должен получать:

- новые взаимодействия;
- новые build options;
- новые ability behaviors;
- новые team compositions;
- новые tactical choices.

Хорошая прогрессия увеличивает пространство решений.

---

# 80. Build diversity

Различные команды должны играться заметно по-разному.

Например один билд может строиться вокруг:

- burning;
- ranged attacks;
- summons;
- poison;
- crowd control;
- burst;
- status spreading;
- defensive companions;
- frequent switching.

Не делать ситуацию, где все билды в итоге отличаются только цветом damage number.

---

# 81. Метагейм и обязательные существа

Не проектировать намеренно одного "обязательного" универсального существа для всех билдов.

Сильные существа допустимы.

Но сила должна иметь:

- контекст;
- tradeoffs;
- build dependency.

---

# 82. Legendary creatures

Редкие и легендарные существа могут быть исключительными.

Но они не должны автоматически делать обычных существ бессмысленными.

Обычный хорошо собранный билд должен оставаться жизнеспособным.

---

# 83. Balance architecture

Балансные значения должны находиться в Resources / data tables.

Не разбросывать:

1.15
0.72
150
30

по игровым скриптам.

Баланс должен иметь центрально редактируемые параметры.

---

# 84. Developer cheats

Для быстрой разработки создать dev commands / debug menu.

Минимально полезные команды:

- give creature;
- set level;
- give item;
- spawn enemy;
- spawn elite;
- teleport;
- kill enemies;
- god mode;
- change area;
- set seed;
- apply status;
- reset save.

Это важный production tool.

---

# 85. Combat test room

Создать отдельную development scene.

CombatTestRoom.

Она должна позволять быстро:

- выбрать creature;
- выбрать enemy;
- добавить item;
- изменить stats;
- применить status;
- проверить ability;
- посмотреть DPS / events.

Не тестировать каждую механику через прохождение игрового уровня.

---

# 86. Content test room

Также полезен отдельный visual/content viewer.

Он должен позволять:

- просматривать существ;
- анимации;
- VFX;
- items;
- lighting profiles;
- environments.

Это ускорит проверку большого количества контента.

---

# 87. Performance target

Несмотря на pixel-art, игра может иметь много runtime entities.

Профилировать сценарии:

- 20 enemies;
- 30 enemies;
- несколько companions;
- projectiles;
- particles;
- status effects;
- loot.

Не ждать конца разработки для stress testing.

---

# 88. Combat simulation budget

При проектировании систем помнить:

одновременно могут существовать десятки Actors.

Не создавать на каждого Actor десятки постоянно работающих _process callbacks без необходимости.

Использовать:

events;
timers;
shared systems;
conditional processing

там, где это разумно.

---

# 89. Object identity

Каждый runtime actor должен иметь понятную identity.

Для persistent creature:

persistent_id.

Для временного runtime объекта:

runtime ID при необходимости.

Не использовать Node.name как игровую identity.

---

# 90. Replay/debug determinism

Для систем с RNG использовать контролируемые RandomNumberGenerator instances.

Особенно:

- loot;
- procedural generation;
- encounter generation;
- capture;
- affixes.

Не использовать случайность хаотично из глобального random state, если результат нужно воспроизводить.

---

# 91. Analytics readiness

Не обязательно подключать analytics.

Но gameplay events должны иметь достаточно чистую архитектуру, чтобы позже можно было измерить:

- deaths;
- ability usage;
- captures;
- item drops;
- boss attempts;
- build choices.

Не вплетать analytics непосредственно в боевую логику.

---

# 92. Главный архитектурный критерий

Система считается хорошо спроектированной, если новый контент создаётся преимущественно через данные и композицию уже существующих механизмов.

Пример:

Добавить новое существо:

GOOD:

create SpeciesResource
add sprites
add animations
select abilities
select AI profile
configure stats
configure evolution

BAD:

modify DamageSystem
modify PartyManager
modify AIManager
modify SaveManager
add 12 species-specific if statements.

---

# 93. Главный критерий боевой системы

Бой должен создавать интересные решения каждую секунду.

Игрок должен думать:

- кого вызвать;
- когда заменить;
- где находиться;
- какую способность использовать;
- какой status создать;
- какое взаимодействие запустить;
- какую угрозу устранить первой.

Бой не должен сводиться к:

"стоять рядом и ждать, пока питомцы автоматически убьют врага."

---

# 94. Главный критерий системы существ

Новое существо интересно не потому, что его BaseAttack = 57 вместо 52.

Оно интересно, если открывает:

- новый стиль;
- новую synergy;
- новую способность;
- новое решение;
- новый build.

---

# 95. Главный критерий лута

Хороший предмет должен заставить игрока хотя бы иногда подумать:

"Из-за этой вещи я могу попробовать совсем другой билд."

Это важнее бесконечного линейного увеличения Gear Score.

---

# 96. Главный критерий мира

Каждая зона должна быть:

- визуально узнаваемой;
- механически немного отличающейся;
- насыщенной событиями;
- достаточно компактной;
- достойной повторного посещения.

Не создавать огромные пустые пространства ради масштаба.

---

# 97. Главный критерий production architecture

Предполагается, что проект может расти несколько лет.

Поэтому архитектура должна поддерживать:

десятки систем,
сотни items,
сотни abilities,
большое количество creatures,
много зон,

без необходимости фундаментально переписывать игру.

Но не строить эти объёмы заранее.

Сначала создать фундамент, доказать его на маленьком наборе контента и затем масштабировать.

---

# 98. Приоритет при конфликте требований

Если возникает конфликт:

Visual spectacle
vs
Combat readability

выбирать Combat readability.

Если возникает конфликт:

чрезмерная универсальность
vs
простая понятная архитектура

выбирать простую архитектуру.

Если возникает конфликт:

больше контента
vs
качество core gameplay

выбирать качество.

Если возникает конфликт:

точное копирование механики источника вдохновения
vs
хорошая real-time ARPG mechanic

выбирать хорошую ARPG mechanic.

---

# 99. Интерпретация источников вдохновения

Diablo II является источником идей:

- темп исследования;
- структура регионов;
- лут;
- elite packs;
- bosses;
- build progression;
- ощущение роста силы.

Pokémon является источником идей:

- виды существ;
- коллекционирование;
- эволюции;
- команды;
- типы;
- способности;
- индивидуальность существ.

Нельзя механически копировать все системы любого из источников.

Каждая механика должна отвечать вопросу:

"Работает ли это в нашей real-time collection ARPG?"

---

# 100. Итоговое определение проекта

Проект должен ощущаться как:

высококачественная современная pixel-art collection ARPG,

где игрок исследует опасный мир,
сражается вместе со своей командой существ,
ловит новых,
развивает их,
находит редкие предметы,
строит синергии,
создаёт билды
и постепенно получает доступ к более сложным зонам и противникам.

Главными удовольствиями игры должны стать:

- красивый и живой мир;
- приятный action combat;
- поиск редкого лута;
- поиск интересных существ;
- экспериментирование с командой;
- создание сильных комбинаций;
- ощущение роста силы.

Все технические решения Codex должен оценивать относительно этой цели.
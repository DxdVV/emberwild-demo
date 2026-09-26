class_name Factions extends RefCounted
enum Team {TRAINER, COMPANION, WILD, HOSTILE, BOSS, NEUTRAL}
const FRIENDS := [Team.TRAINER,Team.COMPANION]
const ENEMIES := [Team.WILD,Team.HOSTILE,Team.BOSS]

static func hostile(a: int, b: int) -> bool:
	return (a in FRIENDS and b in ENEMIES) or (b in FRIENDS and a in ENEMIES)

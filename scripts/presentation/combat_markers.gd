class_name CombatMarkers extends Node2D

# One bounded presentation layer keeps team identity visible through overlapping
# bodies. It never participates in targeting, collisions or combat state.
const PLAYER: Array[String] = ["00100","01010","10001","01010","00100"]
const ONE: Array[String] = ["010","110","010","010","111"]
const TWO: Array[String] = ["110","001","010","100","111"]
const TARGET: Array[String] = ["00100","00100","11011","00100","00100"]
const INK := Color("10191c")
const TEAM := Color("cce9d5")
const FOCUS := Color("ffd589")
var world: GameWorld
var markers: Array[Dictionary] = []

func _ready() -> void:
	z_index = 40
	# Defeat pauses simulation immediately; stale living-player markers must clear.
	process_mode = Node.PROCESS_MODE_ALWAYS
	var canvas := CanvasItemMaterial.new()
	canvas.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	material = canvas
	refresh()

func _process(_delta: float) -> void:
	var stamp := CombatProfiler.start()
	refresh()
	CombatProfiler.finish("markers.update",stamp)

func eligible(actor) -> bool:
	return is_instance_valid(actor) and not actor.is_queued_for_deletion() and actor.world==world and actor.health.current>0 and actor.is_visible_in_tree() and actor.presentation.visible

func refresh() -> bool:
	var next: Array[Dictionary] = []
	append_marker(next,world.trainer,"player")
	for slot in mini(2,world.session.party.active_actors.size()):
		append_marker(next,world.session.party.active_actors[slot],str(slot+1))
	if TargetingSystem.valid(world.trainer,world.focus_target): append_marker(next,world.focus_target,"focus")
	if next==markers: return false
	markers = next
	queue_redraw()
	return true

func append_marker(result: Array[Dictionary], actor, kind: String) -> void:
	if not eligible(actor): return
	var anchor: Vector2 = actor.presentation.marker_anchor().snapped(Vector2(2,2))
	# Mirrored sprites still report their actual top center through the transform.
	var center := anchor+Vector2(0,-14)
	if not actor.statuses.entries.is_empty():
		center.y = minf(center.y,actor.global_position.y-actor.presentation.size-32)
	# Three coincident team members still receive separate, bounded glyphs.
	for offset in [0,-24,24,-48,48,-72,72]:
		var candidate := Rect2(center+Vector2(offset,0)-Vector2(10,10),Vector2(20,20))
		if result.any(func(entry): return candidate.grow(2).intersects(entry.rect)): continue
		result.append({"id":actor.identity,"kind":kind,"rect":candidate,"anchor":anchor})
		return

func _draw() -> void:
	for marker in markers:
		var rect: Rect2 = marker.rect
		var center := rect.get_center()
		var color := FOCUS if marker.kind=="focus" else TEAM
		var rows: Array[String] = PLAYER
		if marker.kind=="1": rows = ONE
		elif marker.kind=="2": rows = TWO
		elif marker.kind=="focus": rows = TARGET
		draw_line(marker.anchor,center+Vector2(0,8),INK,6)
		draw_line(marker.anchor,center+Vector2(0,8),color,2)
		draw_rect(rect,INK)
		# Stepped corners belong to the same coarse world pixel grid as the actors.
		for corner in [rect.position,Vector2(rect.end.x-4,rect.position.y),Vector2(rect.position.x,rect.end.y-4),rect.end-Vector2(4,4)]:
			draw_rect(Rect2(corner,Vector2(4,4)),color)
		StatusGlyph.draw(self,rows,(center-Vector2(rows[0].length(),rows.size())).snapped(Vector2(2,2)),color,2)

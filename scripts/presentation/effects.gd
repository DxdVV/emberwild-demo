class_name EffectsController extends Node2D

var particles: Array[Dictionary] = []
var labels: Array[Dictionary] = []
var rings: Array[Dictionary] = []
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	z_index = 30
	rng.seed = 129
	set_process(false)

func burst(at: Vector2, color: Color, amount: int = 10) -> void:
	set_process(true)
	for i in mini(amount*(Settings.effects_quality+1)/3,180-particles.size()):
		particles.append({"at":at,"velocity":Vector2.from_angle(rng.randf()*TAU)*rng.randf_range(25,110),"life":.5,"color":color,"size":rng.randf_range(1,3)})
	rings.append({"at":at,"life":.35,"color":color})

func floating(at: Vector2, message: String, color: Color) -> void:
	set_process(true)
	if labels.size()>=32: labels.pop_front()
	labels.append({"at":at+Vector2(rng.randf_range(-12,12),-70),"text":message,"life":1.1,"color":color})

func ability_area(at: Vector2, direction: Vector2, ability: AbilityData) -> void:
	set_process(true)
	var angle := deg_to_rad(ability.cone_angle) if ability.delivery=="cone" else TAU
	var radius := ability.reach if ability.delivery=="cone" else ability.radius
	# Readable boundary survives low decorative-effect settings; rasterized by the world viewport.
	rings.append({"at":at,"life":.35,"color":ability.color,"radius":radius,"angle":angle,"direction":direction.angle(),"area":true})

func _process(delta: float) -> void:
	var stamp := CombatProfiler.start()
	var drag := exp(-delta*4)
	for index in range(particles.size()-1,-1,-1):
		var particle: Dictionary = particles[index]
		particle.life -= delta
		if particle.life<=0:
			particles.remove_at(index)
			continue
		particle.at += particle.velocity*delta
		particle.velocity *= drag
	for index in range(labels.size()-1,-1,-1):
		var label: Dictionary = labels[index]
		label.life -= delta
		if label.life<=0:
			labels.remove_at(index)
			continue
		label.at.y -= delta*27
	for index in range(rings.size()-1,-1,-1):
		rings[index].life -= delta
		if rings[index].life<=0: rings.remove_at(index)
	queue_redraw()
	if particles.is_empty() and labels.is_empty() and rings.is_empty(): set_process(false)
	CombatProfiler.finish("effects.update",stamp)

func _draw() -> void:
	var stamp := CombatProfiler.start()
	for particle in particles: draw_rect(Rect2(particle.at.round(),Vector2.ONE*particle.size),Color(particle.color,minf(1,particle.life*3)))
	for ring in rings:
		if ring.get("area",false):
			draw_set_transform(ring.at)
			var radius: float = ring.radius*(1-ring.life/.35)
			var start: float = ring.direction-ring.angle*.5
			draw_arc(Vector2.ZERO,radius,start,start+ring.angle,32,Color(ring.color,ring.life*2),3)
			if ring.angle<TAU:
				draw_line(Vector2.ZERO,Vector2.from_angle(start)*radius,Color(ring.color,ring.life*2),2)
				draw_line(Vector2.ZERO,Vector2.from_angle(start+ring.angle)*radius,Color(ring.color,ring.life*2),2)
			continue
		draw_set_transform(ring.at,0,Vector2(1,.55))
		draw_arc(Vector2.ZERO,(.35-ring.life)*110,0,TAU,24,Color(ring.color,ring.life*2),2)
	draw_set_transform(Vector2.ZERO)
	for label in labels:
		draw_string_outline(ThemeDB.fallback_font,label.at,label.text,HORIZONTAL_ALIGNMENT_CENTER,-1,14,4,Color(0,0,0,minf(1,label.life*2)))
		draw_string(ThemeDB.fallback_font,label.at,label.text,HORIZONTAL_ALIGNMENT_CENTER,-1,14,Color(label.color,minf(1,label.life*2)))
	CombatProfiler.finish("effects.draw",stamp)

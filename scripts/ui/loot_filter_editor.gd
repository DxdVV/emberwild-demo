class_name LootFilterEditor extends VBoxContainer

var status: Label

func _ready() -> void: rebuild()

func rebuild() -> void:
	for child in get_children(): remove_child(child); child.queue_free()
	PartyDetails.wrapped(self,tr("loot.help")%Settings.inputs.label("show_all_loot"))
	add_child(UIStyle.label(tr("loot.minimum"),14,UIStyle.GOLD))
	var rarity := OptionButton.new()
	for index in 4: rarity.add_item(tr("rarity."+str(index)))
	rarity.select(Settings.loot_filter.minimum_rarity)
	rarity.item_selected.connect(func(index): Settings.loot_filter.minimum_rarity=index; save())
	add_child(rarity)
	for id in Settings.loot_filter.categories:
		var toggle := CheckButton.new()
		toggle.text = tr("loot.category."+str(id))
		toggle.button_pressed = Settings.loot_filter.categories[id]
		toggle.toggled.connect(func(value): Settings.loot_filter.categories[id]=value; save())
		add_child(toggle)
	var unique := CheckButton.new()
	unique.text = tr("loot.unique")
	unique.button_pressed = Settings.loot_filter.always_unique
	unique.toggled.connect(func(value): Settings.loot_filter.always_unique=value; save())
	add_child(unique)
	status = PartyDetails.wrapped(self,"")
	add_child(UIStyle.button(tr("loot.reset"),func():
		Settings.loot_filter.restore({})
		save()
		rebuild()))

func save() -> void:
	status.text = "" if Settings.persist()==OK else tr("settings.save_failed")

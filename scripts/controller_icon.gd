@tool
class_name ControllerIcon
extends Control

@export var controller_brand: Global.CONTROLLERS_BRANDS = Global.CONTROLLERS_BRANDS.MISSING:
	set(value):
		controller_brand = value
		if value in brands_controller_icon:
			size = brands_controller_icon[value].get_size()
			if get_child_count() == 1:
				%Icon.texture = brands_controller_icon[value]

@export var active: bool = false:
	set(value):
		active = value
		if value:
			%Icon.material.set_shader_parameter("width", 2)
		else:
			%Icon.material.set_shader_parameter("width", 0)

const brands_controller_icon: Dictionary[Global.CONTROLLERS_BRANDS, Texture2D] = {
	Global.CONTROLLERS_BRANDS.XBOX: preload("res://assets/controllers/xbox_64px.png"),
	Global.CONTROLLERS_BRANDS.XBOX_AS_XINPUT: preload("res://assets/controllers/xbox_64px.png"),
	Global.CONTROLLERS_BRANDS.PLAYSTATION: preload("res://assets/controllers/playstation.png"),
	Global.CONTROLLERS_BRANDS.NINTENDO: preload("res://assets/controllers/switch_64px.png"),
	Global.CONTROLLERS_BRANDS.GENERIC: preload("res://assets/controllers/legacy_64px.png"),
	Global.CONTROLLERS_BRANDS.MISSING: preload("res://assets/controllers/empty_64px.png"),
}

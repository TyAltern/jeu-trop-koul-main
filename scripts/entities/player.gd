class_name Player
extends Character 

func get_id() -> int:
	return Global.players.find(self)

var max_speed: int = 45 * player_scale
var acceleration: int = 7 * player_scale
var friction: int = 10 * player_scale

var is_moving: bool = false

@export var device_id: int = -2
@export var xinput_id: int = -3


@onready var sprite: Sprite2D = %Sprite
@onready var attack_manager: AttackManager = %AttackManager
@onready var player_state_machine: PlayerStateMachine = %PlayerStateMachine

var direction: Vector2
var facing_direction: GlobalPlayerMgmt.PLAYER_DIRECTION = GlobalPlayerMgmt.PLAYER_DIRECTION.DOWN:
	set(value):
		if value != facing_direction:
			var actual_time = player_state_machine.animation_player.current_animation_position
			facing_direction = value
			if !attack_manager.is_attack_animation_played:
				player_state_machine.play(player_state_machine.state,actual_time)
var memory_facing_direction: GlobalPlayerMgmt.PLAYER_DIRECTION = facing_direction


@onready var health_regeneration_timer: Timer = %HealthRegenerationTimer
@onready var hurt_timer: Timer = %HurtTimer
@onready var die_timer: Timer = %DieTimer
@onready var invulnerably_frames: Timer = %InvulnerablyFrames

var is_hurt:bool = false
var is_dead:bool = false
var is_invulnerable: bool = false

@export_enum('Blue','Green','Black','Red') var color: String = 'Blue'
var enemy: Player

var hold_actions:Array[String] = []

@export var frozen: bool = false

# Linked nodes
@onready var linked_camera: Camera2D = $RoomCamera
var linked_health_bar: HealthBar
var linked_inventory: InventoryUI
var linked_viewport_container: SubViewportContainer

func get_camera() -> Camera2D:
	return $RoomCamera


func _ready() -> void:
	sprite.set_sprite_texture(load("res://assets/Player/"+color+"/"+color.to_lower()+"_player_animation.png"))
	calculate_all_stats(false)
	player_stats.stat_effective_health = player_stats.stat_max_health
	
	
func _physics_process(delta: float) -> void:
	if linked_inventory.visible or \
	   frozen: return
	if device_id  == -2:
		direction = Vector2(
			Input.get_action_strength("move_right") - Input.get_action_strength("move_left"),
			Input.get_action_strength("move_down") - Input.get_action_strength("move_up"),
		).normalized()
	elif device_id >= 0:
		if Input.is_joy_button_pressed(device_id,JOY_BUTTON_DPAD_UP) or \
		   Input.is_joy_button_pressed(device_id,JOY_BUTTON_DPAD_DOWN) or \
		   Input.is_joy_button_pressed(device_id,JOY_BUTTON_DPAD_RIGHT) or \
		   Input.is_joy_button_pressed(device_id,JOY_BUTTON_DPAD_LEFT) or \
		   Input.is_joy_button_pressed(xinput_id,JOY_BUTTON_DPAD_UP) or \
		   Input.is_joy_button_pressed(xinput_id,JOY_BUTTON_DPAD_DOWN) or \
		   Input.is_joy_button_pressed(xinput_id,JOY_BUTTON_DPAD_RIGHT) or \
		   Input.is_joy_button_pressed(xinput_id,JOY_BUTTON_DPAD_LEFT):
			direction = Vector2(
				int(Input.is_joy_button_pressed(device_id,JOY_BUTTON_DPAD_RIGHT)) - int(Input.is_joy_button_pressed(device_id,JOY_BUTTON_DPAD_LEFT)),
				int(Input.is_joy_button_pressed(device_id,JOY_BUTTON_DPAD_DOWN)) - int(Input.is_joy_button_pressed(device_id,JOY_BUTTON_DPAD_UP)),
			)
			if xinput_id != -3:
				direction += Vector2(
					int(Input.is_joy_button_pressed(xinput_id,JOY_BUTTON_DPAD_RIGHT)) - int(Input.is_joy_button_pressed(xinput_id,JOY_BUTTON_DPAD_LEFT)),
					int(Input.is_joy_button_pressed(xinput_id,JOY_BUTTON_DPAD_DOWN)) - int(Input.is_joy_button_pressed(xinput_id,JOY_BUTTON_DPAD_UP)),
				)
			direction = direction.normalized()
		else:
			direction = Vector2(
				Input.get_joy_axis(device_id, JOY_AXIS_LEFT_X),
				Input.get_joy_axis(device_id, JOY_AXIS_LEFT_Y),
			)
			if xinput_id != -3:
				direction += Vector2(
					Input.get_joy_axis(xinput_id, JOY_AXIS_LEFT_X),
					Input.get_joy_axis(xinput_id, JOY_AXIS_LEFT_Y),
				)
			direction = direction.normalized()
	if direction.length() <= 0.3 or is_dead:
		direction = Vector2.ZERO
	# Gestion de la direction regardée par le joueur
	if direction.is_zero_approx():
		direction = Vector2.ZERO
	else:
		get_facing_direction()
				
	#if attack_manager.charged_attack_1_is_charged:
		#direction /= 4
	
	var lerp_weight = delta * (acceleration if direction else friction)
	velocity = lerp(velocity, max_speed * direction, lerp_weight)
	move_and_slide()
	
	is_moving = !velocity.length() <= 0.3

func get_facing_direction(_direction = Vector2.ZERO):
	if _direction == Vector2.ZERO: _direction = direction
	if _direction.length() <= 0.2: return facing_direction
	var _facing_direction
	var angle = _direction.rotated(PI/4).angle()
	if 0 <= angle and angle < PI/2:
		_facing_direction = GlobalPlayerMgmt.PLAYER_DIRECTION.RIGHT
	elif PI/2 <= angle and angle < PI:
		_facing_direction = GlobalPlayerMgmt.PLAYER_DIRECTION.DOWN
	elif -PI <= angle and angle < -PI/2:
		_facing_direction = GlobalPlayerMgmt.PLAYER_DIRECTION.LEFT
	elif -PI/2 <= angle and angle < 0:
		_facing_direction = GlobalPlayerMgmt.PLAYER_DIRECTION.UP
	else:
		_facing_direction = facing_direction
	if !attack_manager.is_attack_animation_played:
		facing_direction = _facing_direction
		return facing_direction
	else:
		memory_facing_direction = _facing_direction
		return facing_direction

func _process(_delta: float) -> void:
	pass
	#if "lock_attack_direction" in hold_actions:
		#attack_manager.attack_keep_pressed()
		
		
func _input(event: InputEvent) -> void:
	#if event is InputEventJoypadButton or event is InputEventJoypadMotion:
	# Gros if statement pour séparer les inputs des joueurs
	if (!(event is InputEventKey or event is InputEventMouse) and device_id == -2) or\
	 ((event is InputEventKey or event is InputEventMouse) and device_id >=0) or\
	(device_id >= 0 and event.device != device_id): return
	
	if is_dead: return
	# Mettre les Inputs ici
	if linked_inventory.visible: return
	
	#if event is InputEventJoypadButton:
		#print(Input.get_joy_info(event.device))
	
	if event.is_action_pressed("attack"):
		hold_actions.append("attack")
		attack_manager.attack_pressed()
	if event.is_action_released("attack"):
		hold_actions.erase("attack")
		attack_manager.attack_released()
	if event.is_action_pressed("right_click"):
		pass
	if event.is_action_pressed("lock_attack_direction"):
		attack_manager.lock_attack_direction()
	if event.is_action_released("lock_attack_direction"):
		attack_manager.unlock_attack_direction()
		
	if event.is_action_pressed("open_inventory"):
		if !linked_inventory.visible:
			linked_inventory.display_ui(inventory_storage)
		else:
			inventory_storage = linked_inventory.hide_ui()
			


func hit(damage: float, damage_mult:float = 1):
	if is_dead: return
	var damage_reduction: float = 0
	damage *= damage_mult

	if damage > 0:
		if is_invulnerable:
			return
		damage_reduction = (player_stats.stat_defense * damage) / (player_stats.stat_defense + 50)
	var effective_damage = snappedf(damage - damage_reduction,0.1)
	player_stats.stat_effective_health = clamp(player_stats.stat_effective_health - effective_damage, 0, player_stats.stat_max_health)
  
	linked_health_bar.health = player_stats.stat_effective_health

	if player_stats.stat_effective_health == 0:
		SignalBus.player_died.emit(self)
		player_state_machine.state = GlobalPlayerMgmt.PLAYER_STATE.DIE
		is_dead = true
		die_timer.start()
	else:
		if damage > 0:
			player_state_machine.state = GlobalPlayerMgmt.PLAYER_STATE.HURT
			is_hurt = true
			hurt_timer.start()
			is_invulnerable = false
			invulnerably_frames.start()
	linked_health_bar.health = player_stats.stat_effective_health
	GameController.health_change(self)
	
func hit_player(target_player: Player, damage_mult:float = 1):
	if frozen: return
	target_player.hit(GlobalItemsMgmt.calculate_damage(player_stats), damage_mult)


func _on_hurt_timer_timeout() -> void:
	is_hurt = false

func _on_die_timer_timeout() -> void:
	pass


func _on_invulnerably_frames_timeout() -> void:
	is_invulnerable = false














var is_inventory_open: bool = false
var inventory_storage: Dictionary = {
	"equiped_weapon" :null,# load("res://Resources/Items/Weapon/test_sword.tres").duplicate(),
	"equiped_armor":null,# load("res://Resources/Items/Armor/a_cool_chestplate.tres").duplicate(),
	"inventory": [
		preload("res://Resources/Items/Items_Modifiers/ham.tres").duplicate(),
		preload("res://Resources/Items/Weapon/la_faux_fouche.tres").duplicate(),
		preload("res://Resources/Items/Weapon/test_sword.tres").duplicate(),
		preload("res://Resources/Items/Armor/a_cool_chestplate.tres").duplicate(),
		preload("res://Resources/Items/Armor/t-shirt.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/attack_of_some.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/bread.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/attack_of_some.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/attack_of_some.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/ham.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/bread.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/bread.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/ham.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/attack_of_some.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/pile_of_coin.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/ham.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/attack_of_some.tres").duplicate(),
		preload("res://Resources/Items/Items_Modifiers/bread.tres").duplicate(),
	]
}

var player_stats: StatsSheet = StatsSheet.new()

func calculate_all_stats(display_in_console:bool = false):
	var equipements = [GlobalItemsMgmt.default_player_stats]
	var current_armor: Armor = inventory_storage['equiped_armor']
	equipements.append(current_armor)
	var current_weapon: Weapon = inventory_storage['equiped_weapon']
	equipements.append(current_weapon)
	var calculated_stats: StatsSheet = StatsSheet.new()
	for equipement  in equipements:
		if equipement == null:
			continue
		match equipement.class_type:
			GlobalItemsMgmt.TYPE_OF_ITEMS.WEAPON:
				if display_in_console: print(equipement.name.to_upper())
				calculated_stats = GlobalItemsMgmt.merge_stats_sheet(calculated_stats,equipement.calculate_stats(display_in_console),display_in_console)
			GlobalItemsMgmt.TYPE_OF_ITEMS.ARMOR:
				if display_in_console: print(equipement.name.to_upper())
				calculated_stats = GlobalItemsMgmt.merge_stats_sheet(calculated_stats,equipement.calculate_stats(display_in_console),display_in_console)

			GlobalItemsMgmt.TYPE_OF_ITEMS.STATS_SHEET:
				if display_in_console: print('Base Stats'.to_upper())
				calculated_stats = GlobalItemsMgmt.merge_stats_sheet(calculated_stats,equipement,display_in_console)
			
	GlobalItemsMgmt.display_stats_sheet(calculated_stats)
	player_stats = calculated_stats
	apply_stat()

func apply_stat():
	linked_health_bar.init_bar(0,player_stats.stat_max_health,player_stats.stat_effective_health)
	health_regeneration_timer.wait_time = -log(clamp(player_stats.stat_health_regeneration,0,100))/3 + 2
	print(health_regeneration_timer.wait_time)

func _on_health_regeneration_timer_timeout() -> void:
	if is_dead or frozen: return
	hit(-player_stats.stat_max_health/50)

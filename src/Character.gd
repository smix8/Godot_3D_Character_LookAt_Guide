extends KinematicBody


# sets the offset distance from the ground to your characters head, otherwise the angle will be calculated from the floor
export(float) var character_height = 1.8

# how fast the character can turn the head
export(float) var head_turn_speed = 4.0

# addition rotation degrees, use this with 180.0 if you have a +z forward oriented model e.g. Unity/DAZ
export(float) var additional_rotation = 0.0

# variable that holds our lookat target, if null resets/disables our lookat
var _head_target

# holds our animationtree node for the character
onready var animation_tree : AnimationTree = get_node("AnimationTree")

# a Spatial helper node used with Godot's look_at() function to get the rotation to the target without affecting the character
onready var lookatpointer : Spatial = get_node("LookAtPointer")


# function used from outside to give a target node to the lookat
func start_lookat(_new_lookat_target : Spatial) -> void:
	_head_target = _new_lookat_target
		
	
# function used from outside to stop the lookat and clear the target
func stop_lookat() -> void:
	_head_target = null

	
# default _process() to update the lookat each frame for a smooth movement as _physic_process() creates noticeable stutters at higher framerates
func _process(delta):
	_process_lookat_animation(delta)


func _process_lookat_animation(delta):
	# main lookat function to update the x and y values in our Blendspace2D with the new angles to the target

	# to avoid a sudden head movement when we start or stop the lookat we slowly increase/decrease the blend_amount of the 'blend_look_at' node
	if _head_target:
		animation_tree.set("parameters/blend_look_at/blend_amount", lerp(animation_tree.get("parameters/blend_look_at/blend_amount"), 1.0, delta))
	else:
		animation_tree.set("parameters/blend_look_at/blend_amount", lerp(animation_tree.get("parameters/blend_look_at/blend_amount"), 0.0, delta))
		# we have no target, no reason to run the rest of the code now
		return

	# move our helper pointer to the characters current height / head position
	lookatpointer.global_transform.origin.y = character_height
	
	# rotate the pointer node towards the target with Godot's build-in look_at() function
	lookatpointer.look_at(_head_target.get_global_transform().origin, Vector3.UP)
	
	#################################################################################  
	# What we now need is the correct characters horizontal and vertical angle towards the lookat target to feed the value in the Blendspace2D with our headposes.
	# The following code was made for -/+Z forward, +Y up, +X left orientation 3d models (e.g. Godot, Unity assets or DAZ imports). It needs adjustments for your character model if your orientation is different.
	# There are also parts marked as optional that are examples how to add a little flair to your characters movement behaviour but are not necessary.
	#################################################################################


	# vertical and horizontal rotation degrees (for more human-readable values compared to quats/radians) from our helper node
	var _horizontal_rotation_degrees : float = (lookatpointer.rotation_degrees.y) + additional_rotation
	var _vertical_rotation_degrees : float = (lookatpointer.rotation_degrees.x)
	
	var _look_x : float = _horizontal_rotation_degrees
	var _look_y : float = _vertical_rotation_degrees
	
	
	# optional - we flip values when target is behind the character for a cheap "overshoulder/eavesdrop" look without having dedicated animation poses for it
	if _horizontal_rotation_degrees > 180.0:
		_look_x = (360.0 - _look_x) * -1.0
	
	# we make sure the values stay inside the animation blendspace range
	_look_x = clamp(_look_x, -90.0, 90.0)
	_look_y = clamp(_look_y, -90.0, 90.0)


	# optional - behaviour modifications for different angels with interpolated values for smooth head movement
	if (_horizontal_rotation_degrees > 150.0 and _horizontal_rotation_degrees < 210.0):
		# optional - we are at a custom 'deadzone' angle behind (180°) our character
		if (_vertical_rotation_degrees > 70.0):
			# optional - if we are still behind the character but look down from the very top we want the character to look straight up
			_look_y = 90.0
			_look_x = animation_tree.get("parameters/look_at/blend_position").linear_interpolate( Vector2(0.0,_look_y), delta * head_turn_speed).x
			_look_y = animation_tree.get("parameters/look_at/blend_position").linear_interpolate( Vector2(0.0,_look_y), delta * head_turn_speed).y
		else:
			# optional - we are more or less directly behind the character, give the poor characters neck a break and reset the lookat to center/center position
			_look_x = animation_tree.get("parameters/look_at/blend_position").linear_interpolate( Vector2(0.0,0.0), delta * head_turn_speed).x
			_look_y = animation_tree.get("parameters/look_at/blend_position").linear_interpolate( Vector2(0.0,0.0), delta * head_turn_speed).y
	else:
		# default - we are in front or at a not to uncomfortable (neck breaking) angle behind the character so we use the full values
		_look_x = animation_tree.get("parameters/look_at/blend_position").linear_interpolate( Vector2(_look_x,_look_y), delta * head_turn_speed).x
		_look_y = animation_tree.get("parameters/look_at/blend_position").linear_interpolate( Vector2(_look_x,_look_y), delta * head_turn_speed).y
	
	# apply the new angle values to our blendspace2D x and y values
	animation_tree.set("parameters/look_at/blend_position", Vector2(_look_x, _look_y))

extends Node2D



@onready var bubble_particles: GPUParticles2D = $BubbleParticles

class Agent :
	var pos : Vector2
	var velocity : Vector2
	var acceleration : Vector2
	var color : Color
	var texture : Texture2D

	var distance_from_camera : float

	func _init(p : Vector2, v : Vector2, c : Color, d : float, t : Texture2D) -> void:
		pos = p
		velocity = v
		color = c
		acceleration = Vector2(0.0, 0.0)
		distance_from_camera = d
		texture = t

	func is_out_of_screen(screen_size : Vector2) -> bool:
		return pos.x < 0 or pos.x > screen_size.x or pos.y < 0 or pos.y > screen_size.y

	func handle_screen_edges(screen_size : Vector2) -> void:
		var p : Vector2 = pos
		if p.x < 0:
			p.x = screen_size.x
		elif p.x > screen_size.x:
			p.x = 0
		if p.y < 0:
			acceleration.y += 600.0
			velocity.y += 200.0
		elif p.y > screen_size.y:
			acceleration.y -= 800.0
			velocity.y -= 400.0
		pos = p

var agents: Array[Agent] = []

const FLOCK_SIZE = 150
const MAX_SPEED = 600
const MAX_FORCE = 200

const AGENT_COLOR = Color(0.2, 0.6, 1.0)
const AGENT_SIZE = 8



const WEIGHT_DODGE = 520
const WEIGHT_ALIGN = 80
const WEIGHT_COHESION = 30

const AWARE_RADIUS = 250
const COHESION_RADIUS = int(AWARE_RADIUS * 0.5)
const ALIGNMENT_RADIUS = int(AWARE_RADIUS * 1.0)
const DODGE_RADIUS = int(AWARE_RADIUS * 0.10)

var loaded_fish_textures: Array[Texture2D] = load_all_fish_textures()

func load_all_fish_textures() -> Array[Texture2D]:
	var textures: Array[Texture2D] = []
	var dir: DirAccess = DirAccess.open("res://assets")
	if dir:
		dir.list_dir_begin()
		var file_name: String = dir.get_next()
		while file_name != "":
			if file_name.get_extension() == "png":
				textures.append(load("res://assets/" + file_name))
			file_name = dir.get_next()
	return textures





func _ready() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	var agent_color: Color = Color(0, 0.2, 0.7)

	for i in range(FLOCK_SIZE):
		var random_pos: Vector2 = Vector2(
			randf() * viewport_size.x,
			randf() * viewport_size.y
		)
		var random_vel: Vector2 = Vector2(
			randf_range(-MAX_SPEED, MAX_SPEED),
			randf_range(-MAX_SPEED, MAX_SPEED)
		)
		var distance_from_camera: float = randf_range(0.4, 1.0)

		var texture: Texture2D = loaded_fish_textures.pick_random()



		var agent: Agent = Agent.new(random_pos, random_vel, agent_color, distance_from_camera, texture)
		agents.append(agent)


func update_phyics(agent: Agent, delta: float) -> void:
	if agent.velocity.length() <  0.5:
		agent.acceleration = Vector2(randf_range(-MAX_SPEED, MAX_SPEED), randf_range(-MAX_SPEED, MAX_SPEED))
	var noise_angle : float = randf_range(0, TAU)
	agent.acceleration += Vector2(cos(noise_angle), sin(noise_angle)) * 5
	agent.velocity += agent.acceleration * delta
	agent.velocity = agent.velocity.limit_length(MAX_SPEED)
	agent.pos += agent.velocity * delta

func _process(delta: float) -> void:
	# add a check for if it the mouse was clicked
	# when it was clicked, add this behavior :
	# apply in a radius MOUSE_CLICK_RADIUS a constant you should define up
	# a force in every direction in that radius
	# the force should be proportional to the distance from the mouse
	# push the agents away from the mouse
	var viewport_size: Vector2 = get_viewport_rect().size
	var blind_angle : float = 75.0

	for agent in agents :
		agent.acceleration = Vector2.ZERO

		var close_agents_slice : Array[Agent] = get_close_agents_slice(agent, agents, AWARE_RADIUS, blind_angle)

		var force_from_other_agents : Vector2 = calc_forces_from_other_agents(agent, close_agents_slice)
		var random_force_mag : float = force_from_other_agents.length() * randf_range(0.0, 0.2)
		var final_force : Vector2 = force_from_other_agents + Vector2.RIGHT.rotated(randf_range(0.0, TAU)) * random_force_mag

		agent.acceleration +=  final_force

		update_phyics(agent, delta)

		agent.handle_screen_edges(viewport_size)
		if randf() < 0.03:
			emit_particle(agent)

	queue_redraw()

func emit_particle(agent: Agent) -> void:
	var custom_transform : Transform2D = Transform2D(0.0, agent.pos)
	var custom_velocity : Vector2 = Vector2(
		agent.velocity.x * 0.2 + randf_range(-15.0, 15.0), 
		randf_range(-60.0, -30.0) 
	)
	bubble_particles.emit_particle(
		custom_transform, 
		custom_velocity, 
		Color.WHITE, 
		Color.WHITE, 
		GPUParticles2D.EMIT_FLAG_POSITION | GPUParticles2D.EMIT_FLAG_VELOCITY
	)

func _draw() -> void:
	var viewport_size: Vector2 = get_viewport_rect().size
	

	var water_surface_color : Color = Color(0.4, 0.8, 1.0)
	var water_deep_color : Color = Color(0.04, 0.2, 0.4)

	for agent in agents :


		var depth_ratio : float = clamp(agent.pos.y / viewport_size.y, 0.0, 1.0)
		

		var ambient_water_color : Color = water_surface_color.lerp(water_deep_color, depth_ratio)
		



		var fog_intensity : float = 1.0 - agent.distance_from_camera
		

		fog_intensity = clamp(fog_intensity * 1.5, 0.15, 0.9) 


		var draw_color : Color = Color.WHITE.lerp(ambient_water_color, fog_intensity)
		

		draw_color.a = 1.0 


		var scale_factor : float = (AGENT_SIZE * sqrt(agent.distance_from_camera)) / 40

		var scale_vector : Vector2 = Vector2(-scale_factor, scale_factor) 
		var rotation_angle : float = agent.velocity.angle()
		
		draw_set_transform(agent.pos, rotation_angle, scale_vector)
		var tex_size : Vector2 = agent.texture.get_size()
		var offset : Vector2 = -tex_size / 2.0
		draw_texture(agent.texture, offset, draw_color)

		




func calc_forces_from_other_agents(agent: Agent, close_agents_slice: Array[Agent]) -> Vector2:
	if close_agents_slice.size() == 0:
		return Vector2.ZERO

	var separation_sum : Vector2 = Vector2.ZERO
	var separation_count : int = 0
	var velocity_sum : Vector2 = Vector2.ZERO
	var align_count : int = 0
	var position_sum : Vector2 = Vector2.ZERO
	var cohesion_count : int = 0
	for other in close_agents_slice:
		var offset : Vector2 = agent.pos - other.pos
		var distance : float = offset.length()
		if distance <= DODGE_RADIUS:
			if distance == 0:
				distance = 0.01
			separation_sum += offset.normalized() * 1 / distance
			separation_count += 1
		if distance <= ALIGNMENT_RADIUS:
			velocity_sum += other.velocity
			align_count += 1
		if distance <= COHESION_RADIUS:
			position_sum += other.pos
			cohesion_count += 1

	var separation_force : Vector2 = Vector2.ZERO
	if separation_count > 0:
		var separation_desired : Vector2 = separation_sum.normalized() * MAX_SPEED
		var separation_steering : Vector2 = separation_desired - agent.velocity
		
		separation_steering.limit_length(MAX_FORCE)
		separation_force = separation_steering * WEIGHT_DODGE


	var align_force : Vector2 = Vector2.ZERO
	if align_count > 0:
		var average_velocity : Vector2 = velocity_sum / align_count
		var align_desired : Vector2 = average_velocity.normalized() * MAX_SPEED
		var align_steering : Vector2 = align_desired - agent.velocity
		align_steering.limit_length(MAX_FORCE)
		align_force = align_steering * WEIGHT_ALIGN

	var cohesion_force : Vector2 = Vector2.ZERO
	if cohesion_count > 0:
		var center : Vector2 = position_sum / cohesion_count
		var cohesion_desired : Vector2 = (center - agent.pos).normalized() * MAX_SPEED
		var cohesion_steering : Vector2 = cohesion_desired - agent.velocity
		cohesion_steering.limit_length(MAX_FORCE)
		cohesion_force = cohesion_steering * WEIGHT_COHESION

	return (separation_force + align_force + cohesion_force).limit_length(MAX_FORCE) / agent.distance_from_camera

func get_close_agents_slice(agent: Agent, all_agents: Array[Agent], area: float, blind_angle_deg: float) -> Array[Agent]:
	var result: Array[Agent] = []
	var opposite_dir : Vector2 = -agent.velocity.normalized()
	var half_angle : float = deg_to_rad(blind_angle_deg * 0.5)
	for other in all_agents:
		if other == agent:
			continue
		var offset : Vector2 = other.pos - agent.pos
		if offset.length() > area:
			continue
		var angle_to_other : float = opposite_dir.angle_to(offset)
		if abs(angle_to_other) < half_angle:
			continue
		result.append(other)
	return result

func get_triangle_points(center: Vector2, direction: Vector2, size: float) -> PackedVector2Array:
	const STRETCH = 2.0
	var dir : Vector2 = direction.normalized()
	var p0 : Vector2 = center + dir * (size * STRETCH)
	var p1 : Vector2 = center + dir.rotated(deg_to_rad(120)) * size
	var p2 : Vector2 = center + dir.rotated(deg_to_rad(-120)) * size
	
	return PackedVector2Array([p0, p1, p2])

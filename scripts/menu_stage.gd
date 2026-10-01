class_name MenuStage
extends SubViewportContainer
## メニュー画面の背景に使う3Dステージ（青空・回転台・カメラ）。

var viewport: SubViewport
var turntable: Node3D
var camera: Camera3D
var spin_speed := 0.5
var confetti: CPUParticles3D


func _init() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.msaa_3d = Viewport.MSAA_2X
	viewport.own_world_3d = true
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var env := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.15, 0.45, 0.95)
	sm.sky_horizon_color = Color(0.65, 0.88, 1.0)
	sm.ground_horizon_color = Color(0.65, 0.88, 1.0)
	sm.ground_bottom_color = Color(0.35, 0.6, 0.9)
	sky.sky_material = sm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.88)
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.15
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(30), 0)
	sun.light_energy = 1.2
	sun.shadow_enabled = true
	world.add_child(sun)
	# 回転台
	var base := Models.cyl(world, 5.2, 5.6, 0.6, Color(1, 0.82, 0.2), Vector3(0, -0.3, 0), Vector3.ZERO, 40)
	base.material_override = Models.mat(Color(1, 0.82, 0.2), 0.4)
	var top := Models.cyl(world, 4.8, 4.8, 0.62, Color(1, 1, 1), Vector3(0, -0.28, 0), Vector3.ZERO, 40)
	top.material_override = Models.mat(Color(1, 1, 1), 0.5)
	# 市松模様の床
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(120, 120)
	floor_mi.mesh = pm
	var img := Image.create(2, 2, false, Image.FORMAT_RGBA8)
	img.set_pixel(0, 0, Color(0.5, 0.8, 1.0)); img.set_pixel(1, 1, Color(0.5, 0.8, 1.0))
	img.set_pixel(1, 0, Color(0.62, 0.88, 1.0)); img.set_pixel(0, 1, Color(0.62, 0.88, 1.0))
	var fm := StandardMaterial3D.new()
	fm.albedo_texture = ImageTexture.create_from_image(img)
	fm.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	fm.uv1_scale = Vector3(30, 30, 1)
	floor_mi.material_override = fm
	floor_mi.position.y = -0.62
	world.add_child(floor_mi)
	turntable = Node3D.new()
	world.add_child(turntable)
	camera = Camera3D.new()
	camera.position = Vector3(0, 3.4, 8.5)
	camera.fov = 45
	world.add_child(camera)
	camera.look_at_from_position(camera.position, Vector3(0, 1.0, 0), Vector3.UP)
	confetti = CPUParticles3D.new()
	confetti.emitting = false
	confetti.amount = 120
	confetti.lifetime = 4.0
	confetti.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	confetti.emission_box_extents = Vector3(8, 0.5, 3)
	confetti.position = Vector3(0, 8, 0)
	confetti.direction = Vector3.DOWN
	confetti.initial_velocity_min = 0.5
	confetti.initial_velocity_max = 2.0
	confetti.gravity = Vector3(0, -2.5, 0)
	confetti.angular_velocity_min = -300
	confetti.angular_velocity_max = 300
	var q := QuadMesh.new()
	q.size = Vector2(0.18, 0.12)
	confetti.mesh = q
	var cm := StandardMaterial3D.new()
	cm.vertex_color_use_as_albedo = true
	cm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cm.cull_mode = BaseMaterial3D.CULL_DISABLED
	confetti.material_override = cm
	var g := Gradient.new()
	g.offsets = PackedFloat32Array([0.0, 0.25, 0.5, 0.75, 1.0])
	g.colors = PackedColorArray([Color(1, 0.3, 0.3), Color(1, 0.85, 0.2), Color(0.3, 0.8, 0.4), Color(0.3, 0.6, 1), Color(1, 0.5, 0.9)])
	confetti.color_initial_ramp = g
	world.add_child(confetti)


func _process(delta: float) -> void:
	turntable.rotation.y += delta * spin_speed


func clear() -> void:
	for c in turntable.get_children():
		c.queue_free()


func show_node(n: Node3D) -> void:
	clear()
	turntable.add_child(n)

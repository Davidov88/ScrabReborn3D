class_name ScrapEffects
extends RefCounted

static func sparks(parent: Node3D,pos: Vector3,color: Color,count: int=9):
	var particles=CPUParticles3D.new();particles.emitting=false;particles.one_shot=true;particles.amount=count;particles.lifetime=.55;particles.explosiveness=1.0;particles.direction=Vector3.UP;particles.spread=110;particles.gravity=Vector3(0,-7,0);particles.initial_velocity_min=2.0;particles.initial_velocity_max=4.5;particles.scale_amount_min=.7;particles.scale_amount_max=1.4
	var mesh=BoxMesh.new();mesh.size=Vector3(.024,.09,.024);particles.mesh=mesh
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color;particles.material_override=material
	parent.add_child(particles);particles.global_position=pos;particles.emitting=true
	var flash=OmniLight3D.new();flash.position=pos;flash.light_color=color;flash.light_energy=2;flash.omni_range=2;parent.add_child(flash)
	parent.get_tree().create_timer(.08).timeout.connect(flash.queue_free)
	particles.finished.connect(particles.queue_free)

static func smoke(parent: Node3D,pos: Vector3,life: float=1.4):
	var particles=CPUParticles3D.new();particles.emitting=false;particles.one_shot=true;particles.amount=6;particles.lifetime=life;particles.explosiveness=.5;particles.direction=Vector3.UP;particles.spread=18;particles.gravity=Vector3(0,.25,0);particles.initial_velocity_min=.12;particles.initial_velocity_max=.4;particles.scale_amount_min=.25;particles.scale_amount_max=.65
	var mesh=QuadMesh.new();mesh.size=Vector2(.35,.35);particles.mesh=mesh
	var material=StandardMaterial3D.new();material.transparency=BaseMaterial3D.TRANSPARENCY_ALPHA;material.billboard_mode=BaseMaterial3D.BILLBOARD_PARTICLES;material.albedo_color=Color(.15,.17,.18,.35);material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED
	if ResourceLoader.exists("res://assets/materials/smoke_05.png"):material.albedo_texture=load("res://assets/materials/smoke_05.png")
	particles.material_override=material;parent.add_child(particles);particles.global_position=pos;particles.emitting=true;particles.finished.connect(particles.queue_free)

static func pulse(parent: Node3D,pos: Vector3,color: Color,radius: float=3.0):
	var ring=MeshInstance3D.new();var torus=TorusMesh.new();torus.inner_radius=.92;torus.outer_radius=1.0;torus.rings=16;torus.ring_segments=6;ring.mesh=torus
	var material=StandardMaterial3D.new();material.shading_mode=BaseMaterial3D.SHADING_MODE_UNSHADED;material.albedo_color=color;ring.material_override=material;parent.add_child(ring);ring.global_position=pos;ring.scale=Vector3.ONE*.12
	var tween=parent.create_tween();tween.tween_property(ring,"scale",Vector3(radius,.15,radius),.35);tween.tween_callback(ring.queue_free)

extends Control

@onready var progress_bar = $Container/VBoxContainer/LoadingBar
@onready var status_label = $Container/VBoxContainer/StatusLabel

func _ready():
	progress_bar.custom_minimum_size = Vector2(500, 40)
	progress_bar.size = Vector2(500, 40)
	
	progress_bar.max_value = 100.0 
	progress_bar.step = 0.1 
	progress_bar.value = 0.0

	# Global'deki bitiş sinyalini dinle
	Global.initial_fetch_done.connect(_on_initial_fetch_ready)
	
	if Global.load_pool_from_disk() and Global.student_pool.size() >= Global.initial_target:
		_on_initial_fetch_ready()
	elif Global.access_token != "":
		status_label.text = "Downloading data..."
		Global.check_and_fill_buffer()
	elif Global.auth_code != "":
		status_label.text = "Login success. Downloading data..."
		Global.get_access_token(Global.auth_code)
	else:
		status_label.text = "HATA: Auth Code bulunamadı!"

func _process(delta):
	# Yüzdeyi kendimiz matematiksel olarak hesaplıyoruz: (Mevcut / Hedef) * 100
	var hedef_yuzde = (float(Global.student_pool.size()) / float(Global.initial_target)) * 100.0
	
	# Barı hesapladığımız bu tam yüzdeye (33.3, 66.6, 100) doğru akıcı şekilde doldur
	if progress_bar.value < hedef_yuzde:
		progress_bar.value = lerp(progress_bar.value, hedef_yuzde, 5.0 * delta)

func _on_initial_fetch_ready():
	status_label.text = "Game starting"
	progress_bar.value = progress_bar.max_value
	await get_tree().create_timer(1.0).timeout
	get_tree().call_deferred("change_scene_to_file", "res://scenes/Table.tscn")

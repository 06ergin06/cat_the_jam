extends Control

var status_label: Label

func _ready():
	status_label = Label.new()
	status_label.position = Vector2(20, 20)
	status_label.add_theme_font_size_override("font_size", 24)
	add_child(status_label)
	
	# Global'deki bitiş sinyalini dinle
	Global.initial_fetch_done.connect(_on_initial_fetch_ready)
	
	if Global.load_pool_from_disk() and Global.student_pool.size() >= Global.initial_target:
		# Diskten okunan veri zaten yeterliyse direkt oyuna geç
		_on_initial_fetch_ready()
	elif Global.access_token != "":
		status_label.text = "Eksik veriler arka planda tamamlanıyor..."
		Global.check_and_fill_buffer()
	elif Global.auth_code != "":
		status_label.text = "Giriş başarılı. İlk 3 öğrenci indiriliyor..."
		Global.get_access_token(Global.auth_code)
	else:
		status_label.text = "HATA: Auth Code bulunamadı!"

func _process(_delta):
	# Ekranda o an kaç kişi olduğunu canlı göster
	if Global.student_pool.size() < Global.initial_target:
		status_label.text = "İlk öğrenciler hazırlanıyor... (%d / %d)" % [Global.student_pool.size(), Global.initial_target]

func _on_initial_fetch_ready():
	status_label.text = "Gerekli minimum veri sağlandı! Oyun başlatılıyor..."
	await get_tree().create_timer(1.0).timeout
	get_tree().call_deferred("change_scene_to_file", "res://scenes/MainWorld.tscn")

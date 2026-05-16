extends Node2D

@onready var camera = $PlayerCamera
@onready var masa_alani = $Table/Table 

@onready var karar_paneli = $TextUI/Answerbox
@onready var btn_gecti = $TextUI/Answerbox/BtnOk
@onready var btn_kaldi = $TextUI/Answerbox/BtnNo
@onready var score_label = $TextUI/ScoreLabel

var masa_acik_mi: bool = false
var is_animating: bool = false
var masaya_bakildi: bool = false 

const CAMERA_YUKARI_Y = 0.0
const CAMERA_ASAGI_Y = 1080.0

var score : int = 0
var current_student : Dictionary = {}

func _ready():
	camera.position.y = CAMERA_YUKARI_Y
	set_masa_etkilesimi(false)
	
	btn_gecti.pressed.connect(_on_btn_gecti_pressed)
	btn_kaldi.pressed.connect(_on_btn_kaldi_pressed)
	
	# Eğer arka plan zaten veri çekmişse oyunu başlat
	if Global.student_pool.size() >= Global.initial_target:
		start_game()
	elif Global.load_pool_from_disk(): # Diskten okumayı dene
		start_game()
	else:
		# Hiç veri yoksa mecbur loading'e git
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")

func _input(event):
	if event.is_action_pressed("etkilesim_masa") and not is_animating:
		toggle_view()

func toggle_view():
	masa_acik_mi = !masa_acik_mi
	is_animating = true
	
	if masa_acik_mi:
		masaya_bakildi = true
		karar_paneli.hide()
	
	var tween = get_tree().create_tween()
	
	if masa_acik_mi:
		tween.tween_property(camera, "position:y", CAMERA_ASAGI_Y, 0.5)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		set_masa_etkilesimi(false)
		tween.tween_property(camera, "position:y", CAMERA_YUKARI_Y, 0.5)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			
	tween.tween_callback(_on_transition_finished)

func _on_transition_finished():
	is_animating = false
	if masa_acik_mi:
		set_masa_etkilesimi(true)
	else:
		if masaya_bakildi:
			karar_paneli.show()

func start_game():
	score = 0
	update_score_ui()
	yeni_ogrenci_geldi()

func yeni_ogrenci_geldi():
	masaya_bakildi = false 
	karar_paneli.hide()    
	
	var gercek_veri = Global.get_next_student()
	
	if gercek_veri == null:
		print("PANİK MODU: Arka plan yetişemedi! Sistem zorla uyandırılıyor...")
		
		# --- ŞOK CİHAZI BURASI ---
		# Eğer Global "ben şu an veri çekiyorum" (is_fetching = true) diyerek yalan söylüyor 
		# ve takılı kalmışsa, o durumu zorla iptal edip baştan başlatıyoruz.
		Global.is_fetching = false 
		Global.check_and_fill_buffer()
		
		await get_tree().create_timer(2.0).timeout
		yeni_ogrenci_geldi()
		return
	
	print("DEBBUG LOG | Havuzdan Çekilen Ham Veri: ", gercek_veri)
	
	var ogrenci_gecti_mi = (gercek_veri.get("pool_status", "unknown") == "passed")
	
	current_student = {
		"isim": gercek_veri.get("isim", "Bilinmiyor"),
		"level": gercek_veri.get("campus", "Bilinmiyor"),
		"passed": ogrenci_gecti_mi,
		"projeler": gercek_veri.get("projeler", "Proje verisi eksik."),
		"sinavlar": gercek_veri.get("sinavlar", "Sınav verisi eksik."),
		"feedback": gercek_veri.get("feedback", "Feedback verisi eksik.")
	}
	
	if masa_alani.has_method("update_cards"):
		masa_alani.update_cards(current_student)
	else:
		print("KRİTİK HATA: Table objesinde 'update_cards' fonksiyonu yok!")

func _on_btn_gecti_pressed():
	karar_kontrol(true)

func _on_btn_kaldi_pressed():
	karar_kontrol(false)

func karar_kontrol(oyuncu_karari: bool):
	karar_paneli.hide()
	
	if oyuncu_karari == current_student["passed"]:
		score += 10
		update_score_ui()
		yeni_ogrenci_geldi()
	else:
		game_over()

func game_over():
	print("YANLIŞ KARAR! Oyun Başa Sarıyor...")
	start_game()

func update_score_ui():
	if score_label:
		score_label.text = "Puan: " + str(score)

func set_masa_etkilesimi(active: bool):
	if masa_alani is Control:
		if active:
			masa_alani.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			masa_alani.mouse_filter = Control.MOUSE_FILTER_IGNORE

extends Node2D

@onready var camera = $PlayerCamera
@onready var masa_alani = $Table/Table 

# Arayüz Elemanları
@onready var karar_paneli = $TextUI/Answerbox
@onready var btn_gecti = $TextUI/Answerbox/BtnOk
@onready var btn_kaldi = $TextUI/Answerbox/BtnNo
@onready var score_label = $TextUI/ScoreLabel

# YENİ EKLENEN PANEL ELEMANLARI
@onready var result_label = $TextUI/Answerbox/ResultLabel
@onready var btn_profile = $TextUI/Answerbox/BtnProfile
@onready var btn_next = $TextUI/Answerbox/BtnNext

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
	
	# Buton Bağlantıları
	btn_gecti.pressed.connect(_on_btn_gecti_pressed)
	btn_kaldi.pressed.connect(_on_btn_kaldi_pressed)
	btn_next.pressed.connect(_on_btn_next_pressed)
	btn_profile.pressed.connect(_on_btn_profile_pressed)
	
	# Sonuç elemanlarını başlangıçta gizle
	result_label.hide()
	btn_profile.hide()
	btn_next.hide()
	
	if Global.student_pool.size() >= Global.initial_target:
		start_game()
	elif Global.load_pool_from_disk():
		start_game()
	else:
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
	
	# UI Durumunu Karar Verme Aşamasına Sıfırla
	result_label.hide()
	btn_profile.hide()
	btn_next.hide()
	btn_gecti.show()
	btn_kaldi.show()
	karar_paneli.hide()
	
	var gercek_veri = Global.get_next_student()
	
	if gercek_veri == null:
		print("PANİK MODU: Yeniden tetikleniyor...")
		Global.is_fetching = false 
		Global.check_and_fill_buffer()
		await get_tree().create_timer(1.5).timeout
		yeni_ogrenci_geldi()
		return
	
	var ogrenci_gecti_mi = (gercek_veri.get("pool_status", "unknown") == "passed")
	
	current_student = {
		"isim": gercek_veri.get("isim", "Bilinmiyor"),
		"tam_isim": gercek_veri.get("tam_isim", "Bilinmiyor"), # YENİ
		"level": gercek_veri.get("campus", "Bilinmiyor"),
		"passed": ogrenci_gecti_mi,
		"projeler": gercek_veri.get("projeler", "Veri yok."),
		"sinavlar": gercek_veri.get("sinavlar", "Veri yok."),
		"feedback": gercek_veri.get("feedback", "Veri yok.")
	}
	
	if masa_alani.has_method("update_cards"):
		masa_alani.update_cards(current_student)

func _on_btn_gecti_pressed():
	karar_kontrol(true)

func _on_btn_kaldi_pressed():
	karar_kontrol(false)

# REVEAL (İSİM GÖSTERME) AŞAMASI
func karar_kontrol(oyuncu_karari: bool):
	# Karar butonlarını gizle
	btn_gecti.hide()
	btn_kaldi.hide()
	
	var dogru_mu = (oyuncu_karari == current_student["passed"])
	
	if dogru_mu:
		score += 10
		update_score_ui()
		result_label.text = "DOĞRU KARAR!\nKullanıcı Adı: %s\nTam İsim: %s" % [current_student["isim"], current_student["tam_isim"]]
	else:
		result_label.text = "YANLIŞ KARAR! Oyun Sıfırlanıyor.\nKullanıcı Adı: %s\nTam İsim: %s" % [current_student["isim"], current_student["tam_isim"]]
		score = 0 # İstersen puanı sıfırla ya da game_over tetikle
		update_score_ui()

	# Sonuç ekranı elemanlarını göster
	result_label.show()
	btn_profile.show()
	btn_next.show()

# INTRA LINKINI TARAYICIDA AÇMA FONKSİYONU
func _on_btn_profile_pressed():
	var url = "https://profile.intra.42.fr/users/" + current_student["isim"]
	OS.shell_open(url) # Web exportunda otomatik yeni tab açar!

# SIRADAKİ ÖĞRENCİYE GEÇİŞ BUTONU
func _on_btn_next_pressed():
	yeni_ogrenci_geldi()

func update_score_ui():
	if score_label:
		score_label.text = "Puan: " + str(score)

func set_masa_etkilesimi(active: bool):
	if masa_alani is Control:
		if active: masa_alani.mouse_filter = Control.MOUSE_FILTER_PASS
		else: masa_alani.mouse_filter = Control.MOUSE_FILTER_IGNORE

extends Node2D

@onready var camera = $PlayerCamera

# DÜZELTİLDİ: İç içe olan Table düğümünün doğru yolu!
@onready var masa_alani = $Table/Table 

# Butonlar zaten bu sahnedeymiş, yolları doğru!
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
	
	# Butonları kendi sahnesinden bağlıyoruz
	btn_gecti.pressed.connect(_on_btn_gecti_pressed)
	btn_kaldi.pressed.connect(_on_btn_kaldi_pressed)
	
	if Global.load_pool_from_disk():
		start_game()
	else:
		print("HATA: Dosya bulunamadı! Loading ekranına dönülüyor...")
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
	
	# Arka plan o kadar hızlı çalışacak ki buraya girmesi neredeyse imkansız
	if gercek_veri == null:
		print("PANİK MODU: Oyuncu çok hızlı oynadı, arka plan yetişemedi. Bekleniyor...")
		# Geçici bir yazı yazdırabilir veya 1 saniye sonra bu fonksiyonu tekrar çağırabilirsin
		await get_tree().create_timer(1.5).timeout
		yeni_ogrenci_geldi()
		return
	
	var ogrenci_gecti_mi = (gercek_veri["pool_status"] == "passed")
	
	current_student = {
		"isim": gercek_veri["login"],
		"level": "Kampüs: " + gercek_veri["campus"],
		"passed": ogrenci_gecti_mi,
		"projeler": "Core Eğitimi: " + ("Geçti" if gercek_veri["is_core"] else "Hayır"),
		"feedback": "Havuz Durumu: " + gercek_veri["pool_status"].capitalize()
	}
	
	if masa_alani.has_method("update_cards"):
		masa_alani.update_cards(current_student)
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

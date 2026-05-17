extends Node2D

@onready var camera = $PlayerCamera
@onready var masa_alani = $Table/Table 

# Arayüz Elemanları (Geçti/Kaldı Paneli)
@onready var karar_paneli = $TextUI/Answerbox
@onready var btn_gecti = $TextUI/Answerbox/BtnOk
@onready var btn_kaldi = $TextUI/Answerbox/BtnNo
@onready var score_label = $TextUI/ScoreLabel
@onready var btn_exit_to_login = $TextUI/BtnExitToLogin

# Game Over Popup Elemanları
@onready var game_over_popup = $TextUI/GameOverPopup
@onready var btn_popup_profile = $TextUI/GameOverPopup/BtnPopupProfile
@onready var btn_popup_restart = $TextUI/GameOverPopup/BtnPopupRestart

var masa_acik_mi: bool = false
var is_animating: bool = false
var masaya_bakildi: bool = false 
var oyun_bitti_mi: bool = false 

const CAMERA_YUKARI_Y = 0.0
const CAMERA_ASAGI_Y = 1080.0

var score : int = 0
var current_student : Dictionary = {}

func _ready():
	camera.position.y = CAMERA_YUKARI_Y
	set_masa_etkilesimi(false)
	
	btn_gecti.pressed.connect(_on_btn_gecti_pressed)
	btn_kaldi.pressed.connect(_on_btn_kaldi_pressed)
	
	btn_popup_restart.pressed.connect(_on_btn_popup_restart_pressed)
	btn_popup_profile.pressed.connect(_on_btn_popup_profile_pressed)
	btn_exit_to_login.pressed.connect(_on_btn_exit_to_login_pressed)
	
	game_over_popup.hide()
	
	if Global.student_pool.size() >= Global.initial_target:
		start_game()
	elif Global.load_pool_from_disk():
		start_game()
	else:
		get_tree().change_scene_to_file("res://scenes/loading_screen.tscn")

func _input(event):
	if event.is_action_pressed("etkilesim_masa") and not is_animating and not oyun_bitti_mi:
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

# --- YENİLENEN START_GAME FONKSİYONU ---
func start_game():
	print("--- OYUN BAŞLATILDI / SIFIRLANDI ---")
	score = 0
	update_score_ui()
	oyun_bitti_mi = false
	game_over_popup.hide()
	yeni_ogrenci_geldi()

func yeni_ogrenci_geldi():
	oyun_bitti_mi = false 
	karar_paneli.hide()
	
	var gercek_veri = Global.get_next_student()
	
	if gercek_veri == null:
		print("PANİK MODU: Veri bekleniyor...")
		Global.is_fetching = false 
		Global.check_and_fill_buffer()
		await get_tree().create_timer(1.0).timeout
		yeni_ogrenci_geldi()
		return
	
	masaya_bakildi = masa_acik_mi 
	
	if game_over_popup:
		game_over_popup.hide()
		
	btn_gecti.show()
	btn_kaldi.show()
	
	var ogrenci_gecti_mi = (gercek_veri.get("pool_status", "unknown") == "passed")
	
	current_student = {
		"isim": gercek_veri.get("isim", "Bilinmiyor"),
		"tam_isim": gercek_veri.get("tam_isim", "Bilinmiyor"), 
		"level": gercek_veri.get("campus", "Bilinmiyor"),
		"passed": ogrenci_gecti_mi,
		"projeler": gercek_veri.get("projeler", "Veri yok."),
		"sinavlar": gercek_veri.get("sinavlar", "Veri yok."),
		"feedback": gercek_veri.get("feedback", "Veri yok.")
	}
	
	if masa_alani.has_method("update_cards"):
		masa_alani.update_cards(current_student)
		
	get_tree().call_group("kitap", "verileri_guncelle", current_student)
	print("YENİ ÖĞRENCİ GELDİ: ", current_student["isim"])

func _on_btn_gecti_pressed():
	# Butondan odağı hemen çek (Focus Bug'ını engellemek için)
	btn_gecti.release_focus()
	karar_kontrol(true)

func _on_btn_kaldi_pressed():
	# Butondan odağı hemen çek
	btn_kaldi.release_focus()
	karar_kontrol(false)

# --- YENİLENEN KARAR KONTROL ---
func karar_kontrol(oyuncu_karari: bool):
	print("Oyuncu Kararı: ", oyuncu_karari, " | Gerçek Durum: ", current_student["passed"])
	
	btn_gecti.hide()
	btn_kaldi.hide()
	
	var dogru_mu = (oyuncu_karari == current_student["passed"])
	
	if dogru_mu:
		print("KARAR: DOĞRU!")
		score += 10
		update_score_ui()
		await get_tree().create_timer(0.5).timeout 
		yeni_ogrenci_geldi()
	else:
		print("KARAR: YANLIŞ! Game Over tetikleniyor...")
		score = 0
		update_score_ui()
		oyun_bitti_mi = true 
		
		game_over_popup.show()
		# Paneli ne olursa olsun en öne getir
		game_over_popup.move_to_front() 
		print("Game Over paneli ekrana çizildi.")

func _on_btn_popup_profile_pressed():
	var url = "https://profile.intra.42.fr/users/" + current_student["isim"]
	OS.shell_open(url)

# --- YENİLENEN RESTART BUTONU ---
func _on_btn_popup_restart_pressed():
	print("Restart butonuna basıldı!")
	btn_popup_restart.release_focus() # UI Tıklama odağını temizle
	start_game() # Direkt öğrenci çağırmak yerine tüm oyunu sıfırla

func update_score_ui():
	if score_label:
		score_label.text = str(score)

func set_masa_etkilesimi(active: bool):
	if masa_alani is Control:
		if active: masa_alani.mouse_filter = Control.MOUSE_FILTER_PASS
		else: masa_alani.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _on_btn_exit_to_login_pressed():
	Global.access_token = "" 
	Global.student_pool.clear()
	
	get_tree().change_scene_to_file("res://scenes/login_screen.tscn")

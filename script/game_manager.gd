extends Control

# --- KART ELEMANLARI ---
@onready var feedback_card = $Cards/LogCard

# --- ARAYÜZ ELEMANLARI (TextUI'ın Table içinde olduğu varsayımıyla) ---
@onready var karar_paneli = $TextUI/Answerbox
@onready var btn_gecti = $TextUI/Answerbox/BtnOk
@onready var btn_kaldi = $TextUI/Answerbox/BtnNo
@onready var score_label = $TextUI/ScoreLabel
@onready var btn_exit_to_login = $TextUI/BtnExitToLogin

# --- GAME OVER POPUP ELEMANLARI ---
@onready var game_over_popup = $TextUI/GameOverPopup
@onready var btn_popup_profile = $TextUI/GameOverPopup/BtnPopupProfile
@onready var btn_popup_restart = $TextUI/GameOverPopup/BtnPopupRestart

var score : int = 0
var current_student : Dictionary = {}
var oyun_bitti_mi : bool = false 

func _ready():
	# Standart Buton Bağlantıları
	btn_gecti.pressed.connect(_on_btn_gecti_pressed)
	btn_kaldi.pressed.connect(_on_btn_kaldi_pressed)
	
	# Popup Buton Bağlantıları
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

# --- OYUN AKIŞI ---
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
	
	if game_over_popup:
		game_over_popup.hide()
		
	# Artık kamera inmesi olmadığı için veriler hazır olunca butonları direkt gösteriyoruz
	karar_paneli.show() 
	
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
	
	# Kartları ve kitapları güncelle
	update_cards(current_student)
	get_tree().call_group("kitap", "verileri_guncelle", current_student)
	
	print("YENİ ÖĞRENCİ GELDİ: ", current_student["isim"])

# --- KARTLARI GÜNCELLEME MANTIĞI ---
func update_cards(student_data: Dictionary):
	print("MASAYA VERİ GELDİ")
	
	if feedback_card and feedback_card.has_node("Label"):
		feedback_card.get_node("Label").text = "SON FEEDBACKLER\n-----------------\n" + str(student_data.get("feedback", "Veri Yok"))
		
	if has_node("Cards"):
		for card in $Cards.get_children():
			if card.has_method("reset_position"):
				card.reset_position()

# --- BUTON ETKİLEŞİMLERİ ---
func _on_btn_gecti_pressed():
	btn_gecti.release_focus()
	karar_kontrol(true)

func _on_btn_kaldi_pressed():
	btn_kaldi.release_focus()
	karar_kontrol(false)

func karar_kontrol(oyuncu_karari: bool):
	print("Oyuncu Kararı: ", oyuncu_karari, " | Gerçek Durum: ", current_student["passed"])
	
	karar_paneli.hide() # Karar anında butonları gizle
	
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
		game_over_popup.move_to_front() 
		print("Game Over paneli ekrana çizildi.")

func _on_btn_popup_profile_pressed():
	var url = "https://profile.intra.42.fr/users/" + current_student["isim"]
	OS.shell_open(url)

func _on_btn_popup_restart_pressed():
	print("Restart butonuna basıldı!")
	btn_popup_restart.release_focus() 
	start_game() 

func update_score_ui():
	if score_label:
		score_label.text = str(score)

func _on_btn_exit_to_login_pressed():
	Global.access_token = "" 
	Global.student_pool.clear()
	
	get_tree().change_scene_to_file("res://scenes/login_screen.tscn")

extends Node2D

@onready var camera = $PlayerCamera
@onready var masa_alani = $Table

# Arayüz Butonları ve Skor
@onready var karar_paneli = $TextUI/Answerbox
@onready var btn_gecti = $TextUI/Answerbox/BtnOk
@onready var btn_kaldi = $TextUI/Answerbox/BtnNo
@onready var score_label = $TextUI/ScoreLabel # <-- UI'a bir ScoreLabel eklemeyi unutma!

var masa_acik_mi: bool = false
var is_animating: bool = false
var masaya_bakildi: bool = false 

const CAMERA_YUKARI_Y = 0.0
const CAMERA_ASAGI_Y = 1080.0 # Kendi ekran çözünürlüğüne göre ayarla (örn: 648)

# --- OYUN DEĞİŞKENLERİ ---
var score : int = 0
var current_student : Dictionary = {}

var dummy_api_data = [
	{
		"isim": "oyuncu1", "level": 4.5, "passed": true,
		"projeler": "Libft: 100\nGet_Next_Line: 115\nMinishell: 90",
		"feedback": "Çok iyi kodlanmış ama norm hatası yüzünden 2 defa fail yedi. Sonra düzeltti."
	},
	{
		"isim": "oyuncu2", "level": 1.2, "passed": false,
		"projeler": "Libft: 0\nBorn2beroot: 0",
		"feedback": "Piscine'den sonra okula hiç gelmedi. Peer değerlendirmelerine katılmıyor."
	}
]

func _ready():
	camera.position.y = CAMERA_YUKARI_Y
	set_masa_etkilesimi(false)
	
	btn_gecti.pressed.connect(_on_btn_gecti_pressed)
	btn_kaldi.pressed.connect(_on_btn_kaldi_pressed)
	
	start_game()

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

# --- OYUN DÖNGÜSÜ (GAME LOOP) ---

func start_game():
	score = 0
	update_score_ui()
	yeni_ogrenci_geldi()

func yeni_ogrenci_geldi():
	masaya_bakildi = false 
	karar_paneli.hide()    
	
	# Rastgele yeni öğrenci seç
	current_student = dummy_api_data.pick_random()
	
	# Masa sahnesine "Şu verileri kartlara yaz" komutu gönderiyoruz
	if masa_alani.has_method("update_cards"):
		masa_alani.update_cards(current_student)

func _on_btn_gecti_pressed():
	karar_kontrol(true)

func _on_btn_kaldi_pressed():
	karar_kontrol(false)

func karar_kontrol(oyuncu_karari: bool):
	karar_paneli.hide()
	
	if oyuncu_karari == current_student["passed"]:
		# DOĞRU BİLDİ
		score += 10
		update_score_ui()
		yeni_ogrenci_geldi()
	else:
		# YANLIŞ BİLDİ
		game_over()

func game_over():
	# İstersen buraya bir kırmızı "Game Over" yazısı çıkartan panel ekleyebilirsin
	print("YANLIŞ KARAR! Oyun Başa Sarıyor...")
	start_game()

func update_score_ui():
	# Skoru TextUI içindeki Label'a yazdır
	score_label.text = "Puan: " + str(score)

func set_masa_etkilesimi(active: bool):
	if masa_alani is Control:
		if active:
			masa_alani.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			masa_alani.mouse_filter = Control.MOUSE_FILTER_IGNORE

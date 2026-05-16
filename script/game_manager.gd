extends Control

@onready var ok_area = $OkArea
@onready var no_area = $NoArea
@onready var score_label = $ScoreLabel

@onready var profile_card = $Cards/ProfileCard
@onready var project_card = $Cards/ProjectCard
@onready var feedback_card = $Cards/LogCard

var score : int = 0
var current_student : Dictionary = {}

# Detaylandırılmış sahte API verisi (42 konseptine uygun)
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
	# Tüm kartların 'card_dropped' sinyallerini bu betikteki fonksiyona bağlıyoruz
	for card in $Cards.get_children():
		card.card_dropped.connect(_on_card_dropped)
		
	start_game()

func start_game():
	score = 0
	update_score_ui()
	load_next_student()

func load_next_student():
	current_student = dummy_api_data.pick_random()
	
	# Kartların içindeki yazıları (Label) güncelliyoruz. 
	# Not: Kartların içine Label eklediğini ve adlarının "Label" olduğunu varsayıyorum.
	profile_card.get_node("Label").text = "İsim: " + current_student["isim"] + "\nSeviye: " + str(current_student["level"])
	project_card.get_node("Label").text = "Projeler:\n" + current_student["projeler"]
	feedback_card.get_node("Label").text = "Loglar:\n" + current_student["feedback"]
	
	# Kartları başlangıç pozisyonlarına geri gönder
	for card in $Cards.get_children():
		card.reset_position()

func _on_card_dropped(card):
	# Eğer bırakılan kart Profil kartı değilse umursama (panoda kalmaya devam etsin)
	if not card.is_profile_card:
		return
		
	# Kartın merkez noktasını bul
	var card_center = card.global_position + (card.size / 2)
	
	# Merkez noktası Geçti Alanı'nın içinde mi?
	if ok_area.get_global_rect().has_point(card_center):
		check_guess(true)
	# Merkez noktası Kaldı Alanı'nın içinde mi?
	elif no_area.get_global_rect().has_point(card_center):
		check_guess(false)

func check_guess(player_guess_passed: bool):
	if player_guess_passed == current_student["passed"]:
		# Doğru Bildi
		score += 10
		update_score_ui()
		# Hafif bir bekleyişten sonra yeni öğrenci
		await get_tree().create_timer(0.5).timeout
		load_next_student()
	else:
		# Yanlış Bildi
		game_over()

func game_over():
	# Basit bir Game Over mantığı
	score_label.text = "YANLIŞ BİLDİN!\nSon Skor: " + str(score)
	await get_tree().create_timer(2.0).timeout
	start_game()

func update_score_ui():
	score_label.text = "Puan: " + str(score)

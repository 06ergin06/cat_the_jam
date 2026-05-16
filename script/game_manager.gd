extends Control # veya Node2D (sahnenin kök düğümü neyse)

@onready var profile_card = $Cards/ProfileCard
@onready var project_card = $Cards/ProjectCard
@onready var feedback_card = $Cards/LogCard

func _ready():
	# Sürükle bırak mantığı DraggableCard betiklerinde kendi kendine çalışacak.
	# Burada ekstra bir sinyal dinlememize gerek kalmadı.
	pass

# MainWorld tarafından yeni öğrenci geldiğinde çağrılacak
func update_cards(student_data: Dictionary):
	# Kartların içindeki yazıları (Label) güncelliyoruz. 
	profile_card.get_node("Label").text = "İsim: " + student_data["isim"] + "\nSeviye: " + str(student_data["level"])
	project_card.get_node("Label").text = "Projeler:\n" + student_data["projeler"]
	feedback_card.get_node("Label").text = "Loglar:\n" + student_data["feedback"]
	
	# Kartları başlangıç pozisyonlarına geri gönder (Dağınıklığı topla)
	for card in $Cards.get_children():
		if card.has_method("reset_position"):
			card.reset_position()

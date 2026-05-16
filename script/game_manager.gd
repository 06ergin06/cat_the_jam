extends Control

@onready var profile_card = $Cards/ProfileCard
@onready var project_card = $Cards/ProjectCard
@onready var feedback_card = $Cards/LogCard
@onready var exam_card = $Cards/ExamCard

func update_cards(student_data: Dictionary):
	print("DEBBUG LOG | Masaya Yazdırılan Kart Verisi: ", student_data)
	
	# 1. ProfileCard
	if profile_card and profile_card.has_node("Label"):
		profile_card.get_node("Label").text = "İsim: " + str(student_data.get("isim", "Bilinmiyor")) + "\nKampüs: " + str(student_data.get("level", "Bilinmiyor"))
		
	# 2. ProjectCard
	if project_card and project_card.has_node("Label"):
		project_card.get_node("Label").text = "PROJELER\n-----------------\n" + str(student_data.get("projeler", "Veri Yok"))
		
	# 3. ExamCard
	if exam_card and exam_card.has_node("Label"):
		exam_card.get_node("Label").text = "SINAVLAR\n-----------------\n" + str(student_data.get("sinavlar", "Veri Yok"))
	else:
		print("HATA: ExamCard veya altındaki Label hiyerarşisi yanlış!")
		
	# 4. LogCard
	if feedback_card and feedback_card.has_node("Label"):
		feedback_card.get_node("Label").text = "SON FEEDBACKLER\n-----------------\n" + str(student_data.get("feedback", "Veri Yok"))
		
	# Kartları başlangıç noktasına sıfırla
	for card in $Cards.get_children():
		if card.has_method("reset_position"):
			card.reset_position()

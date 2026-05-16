extends Control

@onready var profile_card = $Cards/ProfileCard
@onready var project_card = $Cards/ProjectCard
@onready var feedback_card = $Cards/LogCard

func update_cards(student_data: Dictionary):
	print("MASAYA VERİ GELDİ: ", student_data)
	
	if profile_card and profile_card.has_node("Label"):
		profile_card.get_node("Label").text = "İsim: " + student_data["isim"] + "\n" + str(student_data["level"])
		
	if project_card and project_card.has_node("Label"):
		project_card.get_node("Label").text = str(student_data["projeler"])
		
	if feedback_card and feedback_card.has_node("Label"):
		feedback_card.get_node("Label").text = str(student_data["feedback"])
		
	for card in $Cards.get_children():
		if card.has_method("reset_position"):
			card.reset_position()

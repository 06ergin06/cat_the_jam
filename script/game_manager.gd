extends Control

# Artık masada sadece Feedback (Log) kartı var
@onready var feedback_card = $Cards/LogCard

func update_cards(student_data: Dictionary):
	print("MASAYA VERİ GELDİ")
	
	# Sadece LogCard (Feedbackler) güncelleniyor
	if feedback_card and feedback_card.has_node("Label"):
		feedback_card.get_node("Label").text = "SON FEEDBACKLER\n-----------------\n" + str(student_data.get("feedback", "Veri Yok"))
		
	# Masadaki kartların (şu an sadece LogCard'ın) pozisyonunu başlangıca sıfırla
	for card in $Cards.get_children():
		if card.has_method("reset_position"):
			card.reset_position()

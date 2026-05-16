extends Control

@onready var profile_card = $Cards/ProfileCard
@onready var project_card = $Cards/ProjectCard
@onready var feedback_card = $Cards/LogCard
@onready var exam_card = $Cards/ExamCard

func update_cards(student_data: Dictionary):
	print("MASAYA VERİ GELDİ")
	
	# --- GELİŞMİŞ İSİM MASKELEME MANTIĞI ---
	var tam_isim = str(student_data.get("tam_isim", "Bilinmiyor"))
	var gizli_isim = ""
	
	if tam_isim != "Bilinmiyor" and tam_isim.strip_edges() != "":
		var kelimeler = tam_isim.split(" ")
		var gizli_kelimeler = []
		
		for kelime in kelimeler:
			if kelime.length() > 1:
				# Kelimenin ilk harfini al, geri kalanı kadar yıldız (*) ekle
				var ilk_harf = kelime.substr(0, 1)
				var yildizlar = "*".repeat(kelime.length() - 1)
				gizli_kelimeler.append(ilk_harf + yildizlar)
			else:
				# Eğer kelime tek harfliyse aynen bırak (veya istersen yıldız yapabilirsin)
				gizli_kelimeler.append(kelime)
				
		# Yıldızlanan kelimeleri aralarında boşluk bırakarak geri birleştir
		gizli_isim = " ".join(gizli_kelimeler)
	else:
		gizli_isim = "B*********"
	
	# 1. ProfileCard (Maskelenmiş Tam İsim Yazdırılıyor)
	if profile_card and profile_card.has_node("Label"):
		profile_card.get_node("Label").text = "İsim: " + gizli_isim + "\nKampüs: " + str(student_data.get("level", "Bilinmiyor"))
		
	# 2. ProjectCard
	if project_card and project_card.has_node("Label"):
		project_card.get_node("Label").text = "PROJELER\n-----------------\n" + str(student_data.get("projeler", "Veri Yok"))
		
	# 3. ExamCard
	if exam_card and exam_card.has_node("Label"):
		exam_card.get_node("Label").text = "SINAVLAR\n-----------------\n" + str(student_data.get("sinavlar", "Veri Yok"))
		
	# 4. LogCard
	if feedback_card and feedback_card.has_node("Label"):
		feedback_card.get_node("Label").text = "SON FEEDBACKLER\n-----------------\n" + str(student_data.get("feedback", "Veri Yok"))
		
	for card in $Cards.get_children():
		if card.has_method("reset_position"):
			card.reset_position()

extends Node2D

# Sahne üzerindeki düğümleri senin isimlendirmene göre koda bağlıyoruz
@onready var camera = $PlayerCamera # Eğer küçük harfle 'camera' yazdıysan burayı $camera yapmalısın
@onready var table = $Table

# Geçiş durumlarını kontrol eden değişkenler
var masa_acik_mi: bool = false
var is_animating: bool = false

# Kamera konumları (Ekran çözünürlüğünüz 1920x1080 ise aşağıyı ona göre ayarla)
const CAMERA_YUKARI_Y = 0.0      # NPC'ye (karşıya) bakış pozisyonu
const CAMERA_ASAGI_Y = 1080.0    # Masaya (aşağıya) bakış pozisyonu

func _ready():
	# Oyun başladığında kameranın kesinlikle yukarıda (NPC'de) olmasını sağlıyoruz
	camera.position.y = CAMERA_YUKARI_Y
	
	# Oyun ilk başladığında masadaki kartların yanlışlıkla tıklanmasını önle
	set_masa_etkilesimi(false)

func _input(event):
	# Oyuncu F tuşuna bastığında ve kamera halihazırda hareket etmiyorsa geçiş yap
	if event.is_action_pressed("etkilesim_masa") and not is_animating:
		toggle_view()

func toggle_view():
	# Durumu tersine çeviriyoruz (Açıksa kapat, kapalıysa aç)
	masa_acik_mi = !masa_acik_mi
	is_animating = true # Animasyon kilidini aktif et (Spam yapılmasın)
	
	# Yumuşak geçiş için yeni bir Tween oluşturuyoruz
	var tween = get_tree().create_tween()
	
	if masa_acik_mi:
		# --- MASAYA (AŞAĞIYA) İNİŞ ANİMASYONU ---
		tween.tween_property(camera, "position:y", CAMERA_ASAGI_Y, 0.5)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
	else:
		# --- NPC'YE (YUKARIYA) ÇIKIŞ ANİMASYONU ---
		# Masa etkileşimini kamera yukarı çıkmaya başladığı an kapatıyoruz
		set_masa_etkilesimi(false)
		
		tween.tween_property(camera, "position:y", CAMERA_YUKARI_Y, 0.5)\
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN_OUT)
			
	# Kamera hedef noktaya ulaştığında bu fonksiyonu çalıştır
	tween.tween_callback(_on_transition_finished)

func _on_transition_finished():
	is_animating = false # Animasyon bitti, kilidi kaldır
	
	if masa_acik_mi:
		# Kamera tamamen aşağı indiğinde masa üzerindeki kartları tıklanabilir yap
		set_masa_etkilesimi(true)

# Masaya bakmıyorken kartların arkadan tıklanmasını engelleyen yardımcı fonksiyon
func set_masa_etkilesimi(active: bool):
	if table is Control:
		if active:
			table.mouse_filter = Control.MOUSE_FILTER_PASS
		else:
			table.mouse_filter = Control.MOUSE_FILTER_IGNORE

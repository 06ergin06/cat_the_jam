extends Area2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var content_label = $Label

var is_open: bool = false

func _ready():
	# Başlar başlamaz kapanma animasyonunu OYNATMAK YERİNE, 
	# sadece kapalı durduğu kareyi gösteriyoruz.
	# (Eğer kapalı hali "closed" animasyonunun son karesiyse veya 
	# "opening" animasyonunun ilk karesiyse onu ayarlamalısın)
	animated_sprite.animation = "opening" 
	animated_sprite.frame = 0 # İlk kare (kitabın tam kapalı olduğu an)
	
	# Kod üzerinden taşmayı engelleme ayarlarını yapıyoruz
	content_label.visible = false
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART # Kelimeleri bölmeden alt satıra atar
	content_label.clip_text = true # Eğer metin kitabın aşağısından da taşıyorsa görünmez yapar

func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		toggle_book()

func toggle_book():
	if is_open:
		# KAPATMA İŞLEMİ
		is_open = false
		content_label.visible = false # Kapatırken yazıyı anında gizle
		animated_sprite.play("closed")
	else:
		# AÇMA İŞLEMİ
		is_open = true
		animated_sprite.play("opening")
		show_text_delayed() # Yazıyı gecikmeli gösterme fonksiyonunu çağır

# Yazıyı 0.5 saniye sonra gösteren fonksiyon
func show_text_delayed():
	# 0.5 saniye bekle
	await get_tree().create_timer(0.38).timeout
	
	# Bekleme bittikten sonra kitap HALA açıksa yazıyı göster
	# (Oyuncu 0.5 saniye dolmadan kitabı tekrar kapatmış olabilir, bunu kontrol etmeliyiz)
	if is_open:
		content_label.visible = true

# Animasyon bitişini algılayan fonksiyon
func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation == "opening":
		animated_sprite.play("open_idle")

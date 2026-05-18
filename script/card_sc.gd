extends Panel

# Ana oyun yöneticisine kartın bırakıldığını haber vermek için özel sinyal
signal card_dropped(card_node)

@export var is_profile_card: bool = false # Inspector'dan Profil kartı için bunu TRUE yapacağız

var dragging = false
var drag_offset = Vector2()
var start_position = Vector2() # Yanlış bilince kartı eski yerine göndermek için

func _ready():
	start_position = global_position

func _gui_input(event):
	# Farenin sol tıkına basıldığında veya çekildiğinde
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			dragging = true
			# Fare imlecinin kartın neresinden tuttuğunu hesapla
			drag_offset = get_global_mouse_position() - global_position
			
			# Tıklanan kartı diğer kartların üstüne (en öne) getir
			get_parent().move_child(self, -1)
		else:
			dragging = false
			# Kart bırakıldığında ana sahneye haber ver
			card_dropped.emit(self)
			
	# Fare hareket ediyorsa ve kart tutuluyorsa
	if event is InputEventMouseMotion and dragging:
		global_position = get_global_mouse_position() - drag_offset

# Kartı başlangıç noktasına geri göndermek için fonksiyon
func reset_position():
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position", start_position, 0.3).set_trans(Tween.TRANS_SINE)

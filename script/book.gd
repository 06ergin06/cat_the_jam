extends Area2D

@onready var animated_sprite = $AnimatedSprite2D
@onready var content_label = $Label   # Sağ Sayfa
@onready var content_label2 = $Label2 # Sol Sayfa

var is_open: bool = false

# --- SÜRÜKLEME VE TIKLAMA DEĞİŞKENLERİ ---
var is_pressed_on_book = false
var dragging = false
var drag_offset = Vector2()
var start_position = Vector2()
var click_start_pos = Vector2() 
var is_dragging_now = false

func _ready():
	add_to_group("kitap")
	start_position = global_position
	
	animated_sprite.animation = "opening" 
	animated_sprite.frame = 0 
	
	content_label.visible = false
	content_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content_label.clip_text = true 

	content_label2.visible = false
	content_label2.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART 
	content_label2.clip_text = true 

# --- İSİM SANSÜRLEME FONKSİYONU ---
func sansurle_isim(isim: String) -> String:
	var kelimeler = isim.split(" ")
	var sansurlu_metin = ""
	
	for kelime in kelimeler:
		if kelime.length() > 2:
			var ilk_harf = kelime[0]
			var son_harf = kelime[kelime.length() - 1]
			var yildizlar = ""
			for i in range(kelime.length() - 2):
				yildizlar += "*"
			sansurlu_metin += ilk_harf + yildizlar + son_harf + " "
		elif kelime.length() == 2:
			sansurlu_metin += kelime[0] + "* "
		else:
			sansurlu_metin += kelime + " "
			
	return sansurlu_metin.strip_edges()

func verileri_guncelle(student_data: Dictionary):
	var gercek_tam_isim = student_data.get("tam_isim", "Bilinmiyor")
	var gizli_isim = sansurle_isim(gercek_tam_isim)
	
	content_label2.text = "\nName: %s\nCampus: %s\n\nEXAMS:\n%s" % [
		gizli_isim,
		student_data.get("level", "Bilinmiyor"),
		student_data.get("sinavlar", "Veri yok.")
	]
	
	content_label.text = "PROJECTS:\n%s" % [
		student_data.get("projeler", "Veri yok.")
	]

# Sadece farenin imleci kitabın üzerindeyken çalışır
func _on_input_event(viewport, event, shape_idx):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			is_pressed_on_book = true
			click_start_pos = get_global_mouse_position()
			
			if not is_open:
				dragging = true
				is_dragging_now = false
				drag_offset = get_global_mouse_position() - global_position
				z_index = 100 

func _input(event):
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if not event.pressed and is_pressed_on_book: 
			is_pressed_on_book = false
			
			if dragging:
				dragging = false
				z_index = 0
			
			if click_start_pos.distance_to(get_global_mouse_position()) < 10:
				toggle_book()
				
	if event is InputEventMouseMotion and dragging:
		if click_start_pos.distance_to(get_global_mouse_position()) >= 10:
			is_dragging_now = true
		
		if is_dragging_now:
			global_position = get_global_mouse_position() - drag_offset

func toggle_book():
	if is_open:
		is_open = false
		content_label.visible = false 
		content_label2.visible = false 
		animated_sprite.play("closed")
	else:
		is_open = true
		animated_sprite.play("opening")
		show_text_delayed()

func show_text_delayed():
	await get_tree().create_timer(0.38).timeout
	if is_open:
		content_label.visible = true
		content_label2.visible = true

func _on_animated_sprite_2d_animation_finished():
	if animated_sprite.animation == "opening":
		animated_sprite.play("open_idle")

func reset_position():
	var tween = get_tree().create_tween()
	tween.tween_property(self, "global_position", start_position, 0.3).set_trans(Tween.TRANS_SINE)

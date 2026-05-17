extends Button

# Büyüme oranları
var original_scale := Vector2(1.0, 1.0)
var hover_scale := Vector2(1.1, 1.1) # %10 büyür (İstersen 1.2 yapıp %20 büyütebilirsin)

var tween: Tween

func _ready():
	# ÇOK ÖNEMLİ: Büyümenin sol üst köşeden değil, tam merkezden olması için pivot noktasını ortalıyoruz.
	pivot_offset = size / 2.0 
	original_scale = scale
	
	# Sinyalleri kod üzerinden bağlıyoruz
	mouse_entered.connect(_on_hover)
	mouse_exited.connect(_on_exit)

func _on_hover():
	# Eğer hali hazırda çalışan bir animasyon varsa durdur
	if tween and tween.is_running():
		tween.kill()
		
	# Yeni bir yumuşak geçiş (Tween) oluştur ve büyüt
	tween = create_tween()
	tween.tween_property(self, "scale", hover_scale, 0.1).set_trans(Tween.TRANS_SINE)

func _on_exit():
	if tween and tween.is_running():
		tween.kill()
		
	# Fare çekildiğinde eski boyutuna geri döndür
	tween = create_tween()
	tween.tween_property(self, "scale", original_scale, 0.1).set_trans(Tween.TRANS_SINE)

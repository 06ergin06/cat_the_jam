extends Control

func _ready():
	# Sayfa yüklendiğinde URL'de yetkilendirme kodu olup olmadığını kontrol et
	if OS.has_feature("web"):
		var raw_query = JavaScriptBridge.eval("window.location.search")
		if raw_query != null and "code=" in str(raw_query):
			# Intra'dan yetkilendirme kodu ile dönülmüş. 
			# Tıklama beklemeden doğrudan giriş sahnesine yönlendir.
			get_tree().change_scene_to_file("res://scenes/login_screen.tscn")

func _input(event):
	# İlk giriş veya normal başlangıç durumu
	if (event is InputEventMouseButton and event.pressed) or (event is InputEventKey and event.pressed):
		oyuna_gecis_yap()

func oyuna_gecis_yap():
	if not GlobalMusic.playing:
		GlobalMusic.play()
	
	get_tree().change_scene_to_file("res://scenes/login_screen.tscn")

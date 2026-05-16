extends Control

const CLIENT_ID = "u-s4t2ud-debd00de78ddda9c18fdb066f19cca5573300c4410f072a2cf7cb6b112d47cc8"
const REDIRECT_URI = "http://localhost:8060/tmp_js_export.html" 
const AUTH_URL = "https://api.intra.42.fr/oauth/authorize?client_id=%s&redirect_uri=%s&response_type=code"

func _ready():
	if OS.has_feature("web"):
		await get_tree().create_timer(0.5).timeout
		check_for_auth_code()

func _on_button_pressed():
	var url = AUTH_URL % [CLIENT_ID, REDIRECT_URI]
	if OS.has_feature("web"):
		JavaScriptBridge.eval("window.top.location.href = '" + url + "';")
	else:
		OS.shell_open(url)

func check_for_auth_code():
	var raw_query = JavaScriptBridge.eval("window.location.search")
	var search_query = str(raw_query)
	
	# URL'de "code=" varsa güvenli bir şekilde parçala (ÇÖKMEYİ ENGELLEYEN KISIM)
	if "code=" in search_query:
		var auth_code = ""
		var params = search_query.replace("?", "").split("&")
		
		for param in params:
			if param.begins_with("code="):
				auth_code = param.replace("code=", "")
				break
				
		if auth_code != "":
			Global.auth_code = auth_code
			print("Kod başarıyla yakalandı: ", auth_code)
			
			# F5 ile sayfa yenilenirse aynı kodla patlamamak için URL'yi temizle
			JavaScriptBridge.eval("window.history.replaceState({}, document.title, window.location.pathname);")
			
			# Loading sahnesine geç (Senin klasör yapına uygun)
			get_tree().call_deferred("change_scene_to_file", "res://scenes/loading_screen.tscn")
		else:
			print("HATA: URL'de code parametresi var ama içi boş!")
	else:
		print("URL temiz, giriş yapılması bekleniyor...")

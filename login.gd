extends Control

const CLIENT_ID = "u-s4t2ud-debd00de78ddda9c18fdb066f19cca5573300c4410f072a2cf7cb6b112d47cc8"
const REDIRECT_URI = "http://localhost:8060/tmp_js_export.html" 
const AUTH_URL = "https://api.intra.42.fr/oauth/authorize?client_id=%s&redirect_uri=%s&response_type=code"
const CLIENT_SECRET = "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"

var current_access_token = ""

# --- YENİ DEPO SİSTEMİ DEĞİŞKENLERİ ---
var student_buffer = []      
var is_fetching = false      
const MAX_BUFFER_SIZE = 5    

func _ready():
	if OS.has_feature("web"):
		await get_tree().create_timer(0.5).timeout
		check_for_auth_code()

func _on_button_pressed() -> void:
	var url = AUTH_URL % [CLIENT_ID, REDIRECT_URI]
	if OS.has_feature("web"):
		var js_command = "window.top.location.href = '" + url + "';"
		JavaScriptBridge.eval(js_command)
	else:
		OS.shell_open(url)

func check_for_auth_code():
	var search_query = JavaScriptBridge.eval("window.location.search")
	if search_query and search_query.begins_with("?code="):
		var auth_code = search_query.replace("?code=", "").split("&")[0]
		$Button.hide()
		get_access_token(auth_code)

func get_access_token(code: String):
	$Label.text = "Token alınıyor..."
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_token_request_completed)
	
	var token_url = "https://api.intra.42.fr/oauth/token"
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var body = "grant_type=authorization_code&client_id=%s&client_secret=%s&code=%s&redirect_uri=%s" % [CLIENT_ID, CLIENT_SECRET, code, REDIRECT_URI]
	http_request.request(token_url, headers, HTTPClient.METHOD_POST, body)

func _on_token_request_completed(_result, response_code, _headers, body):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		current_access_token = json["access_token"]
		
		$NextStudentButton.show()
		$Label.text = "Giriş başarılı! Arka planda arşiv dolduruluyor..."
		
		# Token alındığı an depoyu doldurma döngüsünü başlat
		fill_buffer_loop()
	else:
		$Label.text = "Token hatası!"


# --- OPTİMİZE EDİLMİŞ ARKA PLAN DÖNGÜSÜ ---

func fill_buffer_loop():
	if is_fetching: return
	is_fetching = true
	
	print("Arka plan işçisi çalışmaya başladı...")
	
	while student_buffer.size() < MAX_BUFFER_SIZE:
		await get_tree().create_timer(0.6).timeout
		
		var http_list = HTTPRequest.new()
		add_child(http_list)
		
		var url_list = "https://api.intra.42.fr/v2/users?page[size]=50&page[number]=" + str(randi_range(1, 150))
		var err1 = http_list.request(url_list, ["Authorization: Bearer " + current_access_token], HTTPClient.METHOD_GET)
		
		# KRİTİK DÜZELTME 1
		if err1 != OK:
			print("SİSTEM HATASI: Liste isteği dışarı çıkamadı. Hata Kodu: ", err1)
			http_list.queue_free()
			continue
			
		var list_result = await http_list.request_completed
		http_list.queue_free()
		
		if list_result[1] == 401:
			print("KRİTİK HATA: Token geçersiz veya süresi dolmuş!")
			is_fetching = false
			return
			
		if list_result[1] != 200: 
			print("HATA 1: Liste API Hatası. Gelen Kod: ", list_result[1])
			continue 
		
		var list_body_str = list_result[3].get_string_from_utf8()
		var json_list = JSON.parse_string(list_body_str)
		
		if json_list == null or typeof(json_list) != TYPE_ARRAY or json_list.size() == 0:
			print("HATA 2: Seçilen sayfa boş veya bozuk geldi.")
			continue
		
		var user_id = json_list[randi_range(0, json_list.size() - 1)]["id"]
		
		await get_tree().create_timer(0.6).timeout
		
		var http_detail = HTTPRequest.new()
		add_child(http_detail)
		var url_detail = "https://api.intra.42.fr/v2/users/" + str(user_id)
		var err2 = http_detail.request(url_detail, ["Authorization: Bearer " + current_access_token], HTTPClient.METHOD_GET)
		
		# KRİTİK DÜZELTME 2
		if err2 != OK:
			print("SİSTEM HATASI: Detay isteği dışarı çıkamadı.")
			http_detail.queue_free()
			continue
			
		var detail_result = await http_detail.request_completed
		http_detail.queue_free()
		
		if detail_result[1] != 200: 
			print("HATA 3: Detay API Hatası. Gelen Kod: ", detail_result[1])
			continue
		
		var detail_body_str = detail_result[3].get_string_from_utf8()
		var json_detail = JSON.parse_string(detail_body_str)
		
		if json_detail == null or not json_detail.has("cursus_users"):
			print("HATA 4: Kullanıcı verisi eksik.")
			continue
		
		# --- Filtreleme ---
		var has_c_piscine = false
		var is_core_student = false
		for cursus in json_detail["cursus_users"]:
			if cursus["cursus"]["name"] == "42cursus": is_core_student = true
			if cursus["cursus"]["name"] == "C Piscine": has_c_piscine = true
			
		if not has_c_piscine:
			print("PAS GEÇİLDİ: Sadece Discovery veya Staff denk geldi (", json_detail.get("login", "Bilinmiyor"), ")")
			continue
			
		# --- Depoya Ekleme ---
		var campus_name = "Bilinmiyor"
		if json_detail.has("campus") and typeof(json_detail["campus"]) == TYPE_ARRAY and json_detail["campus"].size() > 0:
			campus_name = json_detail["campus"][0]["name"]
			
		var student_data = {
			"login": json_detail["login"],
			"campus": campus_name,
			"is_core": is_core_student
		}
		
		student_buffer.append(student_data)
		print("++ BAŞARILI! Depoya eklendi: ", student_data["login"], " (Depo: ", student_buffer.size(), "/5)")
		
		if $Label.text == "Arşivde dosya aranıyor, lütfen bekleyin...":
			show_student_from_buffer()

	is_fetching = false
	print("DEPO FULL: Arka plan işçisi dinlenmeye geçti.")


# --- BUTON VE EKRANA YANSITMA (SİLİNEN KISIM BURASIYDI) ---

func _on_next_student_button_pressed():
	show_student_from_buffer()

func show_student_from_buffer():
	if student_buffer.size() > 0:
		var student = student_buffer.pop_front()
		
		var text_to_show = "--- GELEN DOSYA ---\n"
		text_to_show += "Öğrenci: " + student["login"] + "\n"
		text_to_show += "Kampüs: " + student["campus"] + "\n\n"
		text_to_show += "[GİZLİ GERÇEK] Havuzu Geçti mi?: " + ("EVET" if student["is_core"] else "HAYIR")
		
		$Label.text = text_to_show
		
		# Depodan adam eksildiği için arka plan işçisini tekrar dürterek eksikleri tamamlamasını söylüyoruz
		fill_buffer_loop()
		
	else:
		$Label.text = "Arşivde dosya aranıyor, lütfen bekleyin..."

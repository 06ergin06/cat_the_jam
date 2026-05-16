extends Node

const CLIENT_ID = "u-s4t2ud-debd00de78ddda9c18fdb066f19cca5573300c4410f072a2cf7cb6b112d47cc8"
const REDIRECT_URI = "http://localhost:8060/tmp_js_export.html"
const CLIENT_SECRET = "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"

var auth_code = ""
var access_token = ""
var student_pool = []
var is_fetching = false

var initial_target = 3
var max_buffer_size = 15

signal initial_fetch_done
signal pool_updated

func load_pool_from_disk():
	if FileAccess.file_exists("user://pool_data.json"):
		DirAccess.remove_absolute("user://pool_data.json")
	return false

func save_current_pool():
	var file = FileAccess.open("user://pool_data.json", FileAccess.WRITE)
	file.store_string(JSON.stringify(student_pool, "\t"))
	file.close()

func get_next_student():
	check_and_fill_buffer()
	if student_pool.size() > 0:
		var student = student_pool.pop_front()
		save_current_pool()
		return student
	return null

func check_and_fill_buffer():
	if not is_fetching and student_pool.size() < max_buffer_size and access_token != "":
		is_fetching = true
		get_random_user()

func get_access_token(code: String):
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.timeout = 8.0 
	http_request.request_completed.connect(_on_token_received)
	
	var token_url = "https://api.intra.42.fr/oauth/token"
	var headers = ["Content-Type: application/x-www-form-urlencoded"]
	var body = "grant_type=authorization_code&client_id=%s&client_secret=%s&code=%s&redirect_uri=%s" % [
		CLIENT_ID, CLIENT_SECRET, code, REDIRECT_URI.uri_encode()
	]
	http_request.request(token_url, headers, HTTPClient.METHOD_POST, body)

func _on_token_received(_result, response_code, _headers, body):
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		access_token = json["access_token"]
		check_and_fill_buffer()
	else:
		print("Token Hatası: ", response_code)

func get_random_user():
	if student_pool.size() >= max_buffer_size:
		is_fetching = false
		return
		
	await get_tree().create_timer(0.6).timeout 
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.timeout = 8.0 
	http_request.request_completed.connect(_on_random_list_completed.bind(http_request))
	
	var random_page = randi_range(1, 150)
	var url = "https://api.intra.42.fr/v2/cursus/9/users?page[size]=50&page[number]=" + str(random_page)
	var headers = ["Authorization: Bearer " + access_token]
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func _on_random_list_completed(_result, response_code, _headers, body, http_request):
	http_request.queue_free()
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json != null and typeof(json) == TYPE_ARRAY and json.size() > 0:
			var random_index = randi_range(0, json.size() - 1)
			get_detailed_user_data(json[random_index]["id"])
		else:
			get_random_user()
	else:
		get_random_user()

func get_detailed_user_data(user_id: int):
	await get_tree().create_timer(0.6).timeout
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.timeout = 8.0 
	http_request.request_completed.connect(_on_detailed_data_completed.bind(http_request, user_id))
	
	var url = "https://api.intra.42.fr/v2/users/" + str(user_id)
	var headers = ["Authorization: Bearer " + access_token]
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func _on_detailed_data_completed(_result, response_code, _headers, body, http_request, user_id: int):
	http_request.queue_free()
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json == null or not json.has("cursus_users"):
			get_random_user()
			return
			
		var has_c_piscine = false
		var is_core_student = false
		var is_discovery_student = false
		var pool_status = "pending" 
		
		for cursus in json["cursus_users"]:
			var c_name = str(cursus["cursus"]["name"])
			if "discovery" in c_name.to_lower(): is_discovery_student = true
			if c_name == "42cursus": is_core_student = true
			if c_name == "C Piscine":
				has_c_piscine = true
				if cursus.has("grade") and cursus["grade"] != null:
					var grade_str = str(cursus["grade"]).strip_edges()
					if grade_str == "Passed": pool_status = "passed"
					elif grade_str != "": pool_status = "failed"
		
		if is_core_student: pool_status = "passed"
			
		if not has_c_piscine or pool_status == "pending" or is_discovery_student:
			get_random_user()
			return
			
		var campus_name = json["campus"][0]["name"] if json.has("campus") and json["campus"].size() > 0 else "Bilinmiyor"
		
		var projeler_listesi = []
		var sinavlar_listesi = []
		if json.has("projects_users"):
			for p in json["projects_users"]:
				var is_piscine_project = false
				if p.has("cursus_ids"):
					for cid in p["cursus_ids"]:
						if int(cid) == 9: is_piscine_project = true
				if not is_piscine_project and p.has("project") and p["project"].has("slug"):
					var p_slug = str(p["project"]["slug"]).to_lower()
					if "piscine" in p_slug and not "discovery" in p_slug: is_piscine_project = true

				if is_piscine_project:
					var p_name = str(p["project"]["name"])
					if "discovery" in p_name.to_lower(): continue
					var p_mark = str(p["final_mark"]) if p["final_mark"] != null else "0"
					var entry = p_name + ": " + p_mark
					if p_name.to_lower().find("exam") != -1: sinavlar_listesi.append(entry)
					else: projeler_listesi.append(entry)
						
		var student_data = {
			"isim": json["login"],
			"tam_isim": json.get("displayname", "Bilinmiyor"), # YENİ: Tam isim eklendi
			"campus": campus_name,
			"pool_status": pool_status,
			"projeler": "\n".join(projeler_listesi),
			"sinavlar": "\n".join(sinavlar_listesi),
			"feedback": ""
		}
		get_user_feedbacks(user_id, student_data)
	else:
		get_random_user()

func get_user_feedbacks(user_id: int, student_data: Dictionary):
	await get_tree().create_timer(0.6).timeout
	var http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.timeout = 8.0 
	http_request.request_completed.connect(_on_feedbacks_completed.bind(http_request, student_data, user_id))
	
	var url = "https://api.intra.42.fr/v2/users/" + str(user_id) + "/scale_teams/as_corrected?sort=-created_at&page[size]=3"
	var headers = ["Authorization: Bearer " + access_token]
	http_request.request(url, headers, HTTPClient.METHOD_GET)

func _on_feedbacks_completed(_result, response_code, _headers, body, http_request, student_data: Dictionary, user_id: int):
	http_request.queue_free()
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		var feedback_text = ""
		if typeof(json) == TYPE_ARRAY and json.size() > 0:
			for item in json:
				if item.has("comment") and item["comment"] != null:
					var clean = str(item["comment"]).replace("\n", " ").strip_edges()
					if clean.length() > 65: clean = clean.left(60) + "..."
					feedback_text += "- " + clean + "\n\n"
					
		student_data["feedback"] = feedback_text if feedback_text != "" else "Yorumsuz değerlendirmeler."
		student_pool.append(student_data)
		save_current_pool()
		if student_pool.size() == initial_target: initial_fetch_done.emit()
		get_random_user()
	else:
		get_random_user()

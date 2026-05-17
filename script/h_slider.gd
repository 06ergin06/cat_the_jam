extends HSlider

var master_bus_index: int

func _ready():
	master_bus_index = AudioServer.get_bus_index("Master")
	
	# Global'deki kayıtlı değeri alıp çubuğa yerleştir
	set_value_no_signal(Global.master_volume)
	value_changed.connect(_on_value_changed)

func _on_value_changed(yeni_deger: float):
	# 1. Sesi kıs/aç
	AudioServer.set_bus_volume_db(master_bus_index, linear_to_db(yeni_deger))
	
	# 2. AYARI DİSKE KAYDET! (Intra'ya gidip gelse bile unutmaz)
	Global.save_audio_settings(yeni_deger)

extends Node
## El sonido de la demo (sólo de la demo y la promoción, nunca del pack): las voces al empezar su clip, los efectos de
## cada acción en su FOTOGRAMA de contacto (pisadas según el animal y el suelo, mordiscos, aletazos, chapoteos, golpes,
## caídas, el abanico del pavo, el grano, el cubo, la puerta...) desde donde está quien la hace, y el ambiente por hora
## (pájaros al alba, el día, grillos y ranas de noche, la llovizna, el viento con cada ráfaga y el molino).
## Mezcla: voz > efecto > ambiente (sonidos/niveles.json, pico <= -3 dBFS); los efectos pequeños sólo se oyen de cerca
## (distancia a la cámara y zoom); un tope de reproductores; respeta SOUND; nada suena antes del primer clic (la web).
## Los fotogramas de contacto salen de los atlas: _tools/sonidos_accion.py -> sonidos/contactos.json.
## Prueba sin oírlo: -- --prueba_sonido (apunta cada disparo y a los 180 s imprime el resumen y lo que quedó mudo).

const Comp := preload("res://comportamiento.gd")
const MAX_VOCES := 6
var _voz_global := -99.0       # la última voz de toda la granja
const MAX_EFECTOS := 10
const MUDO_DB := -42.0        # por debajo, ni se reproduce (no gasta reproductor)
const MUDO_EFECTO_DB := -36.0 # un efecto pequeño más flojo que esto no se distingue: no ocupa reproductor
const POZO := Vector2(690, 330)
const PUERTA_CASA := Vector2(606, 200)
# quién pisa cómo: [tipo de pie, tono, dB de más] (la pezuña grande grave y fuerte; ave y pata agudas y flojas)
const PIES := {
	"Vaca": ["pezuna", 0.8, 0.0], "Toro": ["pezuna", 0.75, 1.0], "Semental": ["pezuna", 0.8, 1.0], "Caballo": ["pezuna", 0.82, 0.0],
	"Burro": ["pezuna", 0.9, -1.0], "BurroMacho": ["pezuna", 0.88, -1.0],
	"Ternero": ["pezuna", 1.05, -5.0], "Ternera": ["pezuna", 1.05, -5.0], "Potro": ["pezuna", 1.0, -4.0], "Pollino": ["pezuna", 1.1, -5.0],
	"Oveja": ["pezuna", 1.05, -4.0], "Carnero": ["pezuna", 0.98, -3.0], "Cordero": ["pezuna", 1.25, -8.0],
	"Cabra": ["pezuna", 1.1, -4.0], "MachoCabrio": ["pezuna", 1.0, -3.0], "Cabrito": ["pezuna", 1.3, -8.0],
	"Cerdo": ["pezuna", 1.05, -4.0], "Verraco": ["pezuna", 0.95, -3.0], "Lechon": ["pezuna", 1.35, -9.0],
	"Conejo": ["pata", 1.6, -11.0], "ConejoMacho": ["pata", 1.5, -10.0], "Gazapo": ["pata", 1.9, -14.0], "Raton": ["pata", 2.2, -16.0],
	"Gallina": ["ave", 1.45, -9.0], "Gallo": ["ave", 1.35, -8.0], "Pava": ["ave", 1.25, -7.0], "PavoMacho": ["ave", 1.15, -6.0],
	"PatoDomestico": ["ave", 1.3, -8.0], "PatoMacho": ["ave", 1.25, -8.0], "Ganso": ["ave", 1.1, -7.0], "GansoMacho": ["ave", 1.05, -6.0],
	"Pollito": ["ave", 2.0, -14.0], "Pavipollo": ["ave", 1.8, -13.0], "Patito": ["ave", 1.9, -14.0], "Ansarino": ["ave", 1.7, -13.0],
	"granjero": ["persona", 1.0, -2.0], "washerwoman": ["persona", 1.08, -3.0],
}
const AVES := ["Gallina", "Gallo", "Pava", "PavoMacho", "PatoDomestico", "PatoMacho", "Ganso", "GansoMacho", "Pollito",
	"Pavipollo", "Patito", "Ansarino"]
# la voz que falta en una especie: la de otra (cría de oca = patito, pavipollo = pollito, ternera = ternero) y las ocas
# graznan (honk) aunque el clip se llame quack
const VOZ_DE := {"Ansarino": "Patito", "Pavipollo": "Pollito", "Ternera": "Ternero"}
const ANIM_VOZ := {"Ganso": {"quack": "honk", "lay_egg": "honk"}, "GansoMacho": {"quack": "honk"},
	"Pava": {"lay_egg": "cluck"}, "PatoDomestico": {"lay_egg": "quack"}}
# el quejido de hurt de los que no tienen voz (conejos): el chillido del ratón, más grave
const QUEJIDO_DE := {"Conejo": ["Raton_squeak", 0.72], "ConejoMacho": ["Raton_squeak", 0.65], "Gazapo": ["Raton_squeak", 0.9]}

var mundo                       # la escena
var contactos := {}             # especie -> anim -> vista -> [fotogramas de contacto]
var activo := false             # tras el primer clic o tecla (la web no deja sonar antes)
var _voces: Array[AudioStreamPlayer2D] = []
var _efectos: Array[AudioStreamPlayer2D] = []
var _visto := {}                # actor -> [paso, fotograma] del último dibujado
var _ultima_voz := {}           # actor -> cuándo habló (que nadie repita sin parar)
var _ultimo_paso := {}          # actor -> cuándo pisó
var _dentro := {}               # granjero -> estaba en casa (para la puerta)
var _cache := {}                # ruta -> AudioStream
var _suelo := PackedByteArray() # rejilla de 4 px: 1 hierba, 0 tierra
var _suelo_w := 0
var _puente := Rect2()
var _molino := Vector2(948, 150)
var _t_molino := 0.0
var _t_rana := 0.0
# ambiente: capa -> reproductor, y su volumen lineal de ahora (va hacia el objetivo despacio: transiciones suaves)
var _amb := {}
var _amb_lin := {}
var _agua: AudioStreamPlayer2D
# la prueba
var _prueba := false
var _registro: Array = []
var _empezadas := {}            # "Especie/anim" -> veces que empezó
var _sonadas := {}              # "Especie/anim" -> veces que sonó algo suyo
var _t0 := 0


func prepara(escena) -> void:
	mundo = escena
	if FileAccess.file_exists("res://sonidos/contactos.json"):
		contactos = JSON.parse_string(FileAccess.get_file_as_string("res://sonidos/contactos.json"))
		# el JSON trae los fotogramas como float, y 3 in [3.0] es falso: a enteros
		for b in contactos:
			for an in contactos[b]:
				for dd in contactos[b][an]:
					contactos[b][an][dd] = contactos[b][an][dd].map(func(x): return int(x))
	_prepara_suelo()
	var E: Dictionary = mundo.E
	for s in E["sprites"]:
		var n: String = s[0]
		if n == "puente":
			var im: Dictionary = E["imagenes"][n]
			_puente = Rect2(float(s[1]), float(s[2]), float(im["w"]), float(im["h"])).grow(-3.0)
		elif n == "molino":
			_molino = Vector2(float(s[1]) + 30.0, float(s[2]) + 40.0)
	# el ambiente, en bucle y callado hasta el primer clic
	for capa in ["dia", "alba", "noche", "viento", "lluvia"]:
		var p := AudioStreamPlayer.new()
		p.stream = _bucle("res://sonidos/_amb_%s.ogg" % capa)
		p.volume_db = -80.0
		add_child(p)
		_amb[capa] = p
		_amb_lin[capa] = 0.0
	_agua = AudioStreamPlayer2D.new()
	_agua.stream = _bucle("res://sonidos/_amb_agua.ogg")
	_agua.position = mundo.estanque["c"]
	_agua.max_distance = 360.0
	_agua.attenuation = 1.4
	add_child(_agua)
	_prueba = "--prueba_sonido" in OS.get_cmdline_user_args()
	if _prueba:
		Engine.time_scale = 3.4   # 180 s de reloj = un día entero de la granja (alba, día, llovizna, noche)
		_t0 = Time.get_ticks_msec()
		_empieza_ambiente()
		mundo.cam.zoom = Vector2.ONE * 2.0   # de cerca: la cámara pasea sola por las familias


func _input(ev: InputEvent) -> void:
	if activo:
		return
	if (ev is InputEventMouseButton or ev is InputEventScreenTouch or ev is InputEventKey) and ev.pressed:
		_empieza_ambiente()


func _empieza_ambiente() -> void:
	activo = true
	for capa in _amb:
		if _amb[capa].stream:
			_amb[capa].play()
	if _agua.stream:
		_agua.play()


func _bucle(ruta: String) -> AudioStream:
	if not ResourceLoader.exists(ruta):
		return null
	var st: AudioStream = load(ruta)
	if st is AudioStreamOggVorbis:
		st.loop = true
	return st


func _carga(ruta: String) -> AudioStream:
	if not _cache.has(ruta):
		_cache[ruta] = load(ruta) if ResourceLoader.exists(ruta) else null
	return _cache[ruta]


func _prepara_suelo() -> void:
	## hierba o tierra, del color del suelo pintado (cada 4 px): para el sonido de la pisada
	var tex: Texture2D = load(mundo.DATOS + "suelo.png")
	if tex == null:
		return
	var img := tex.get_image()
	if img == null:
		return
	if img.is_compressed():
		img.decompress()
	_suelo_w = img.get_width() / 4
	var alto := img.get_height() / 4
	_suelo.resize(_suelo_w * alto)
	for y in alto:
		for x in _suelo_w:
			var c := img.get_pixel(x * 4 + 2, y * 4 + 2)
			_suelo[y * _suelo_w + x] = 1 if c.g >= c.r * 0.97 and c.g > c.b * 1.15 else 0


func superficie(p: Vector2) -> String:
	if _puente.has_point(p):
		return "madera"
	if mundo.agua(p):
		return "agua"
	var i := int(p.y / 4.0) * _suelo_w + int(p.x / 4.0)
	if _suelo_w > 0 and i >= 0 and i < _suelo.size() and p.x >= 0.0 and _suelo[i] == 1:
		return "hierba"
	return "tierra"


# ---------- mezcla ----------
func _ganancia(p: Vector2, papel: String) -> Array:
	## [dB por distancia y zoom, distancia]: la voz se oye en toda la granja (más baja lejos); el efecto pequeño sólo de
	## cerca, y en la vista general casi nada; lo posicional del ambiente (agua, ranas, molino), como la voz pero más corto
	var cam: Camera2D = mundo.cam
	var d := p.distance_to(cam.position)
	var media: Vector2 = mundo.get_viewport().get_visible_rect().size / cam.zoom / 2.0
	var radio := media.length()
	var lin := 1.0
	match papel:
		"voz":
			lin = clampf(1.0 - d / maxf(700.0, radio * 1.6), 0.15, 1.0)
		"efecto":
			lin = pow(clampf(1.0 - d / maxf(140.0, radio * 1.1), 0.0, 1.0), 1.5)
			if mundo.vista_general():
				lin = 0.0          # la granja entera: sólo voces y ambiente
			elif cam.zoom.x < 1.5:
				lin *= 0.4
		_:
			lin = pow(clampf(1.0 - d / maxf(360.0, radio * 1.3), 0.0, 1.0), 1.2)
	return [linear_to_db(maxf(lin, 0.0001)), d]


func _reproductor(lista: Array[AudioStreamPlayer2D], tope: int) -> AudioStreamPlayer2D:
	for v in lista:
		if not v.playing:
			return v
	if lista.size() >= tope:
		return null
	var p := AudioStreamPlayer2D.new()
	p.max_distance = 100000.0   # la distancia la pone _ganancia (con el zoom); el reproductor sólo pone el panorama
	p.attenuation = 0.00001
	add_child(p)
	lista.append(p)
	return p


func dispara(ruta: String, pos: Vector2, papel: String, db_mas := 0.0, tono := 1.0, quien := "", anim := "", cuadro := -1,
		corta := 0.0) -> void:
	## un sonido suelto, desde pos
	if not activo or not mundo.sonido:
		return
	var st := _carga(ruta)
	if st == null:
		_apunta(quien, anim, cuadro, ruta, -99.0, -1.0, "falta el archivo")
		return
	var g := _ganancia(pos, papel)
	var db: float = mundo.nivel(ruta) + db_mas + float(g[0])
	if db < (MUDO_EFECTO_DB if papel == "efecto" else MUDO_DB):
		_apunta(quien, anim, cuadro, ruta, db, g[1], "mudo (lejos)")
		return
	var lista: Array[AudioStreamPlayer2D] = _voces if papel == "voz" else _efectos
	var p := _reproductor(lista, MAX_VOCES if papel == "voz" else MAX_EFECTOS)
	if p == null:
		# todos ocupados: si este suena más que el más flojo de los que suenan, le quita el sitio (lo cercano manda)
		var flojo: AudioStreamPlayer2D = null
		for v in lista:
			if flojo == null or v.volume_db < flojo.volume_db:
				flojo = v
		if flojo != null and flojo.volume_db < db - 3.0:
			p = flojo
			p.stop()
	if p == null:
		_apunta(quien, anim, cuadro, ruta, db, g[1], "sin reproductor libre")
		return
	p.stream = st
	p.volume_db = db
	p.position = pos
	p.pitch_scale = tono * randf_range(0.96, 1.04)
	p.play()
	if corta > 0.0:
		# lo corto y agudo (el quejido): se para a tiempo
		get_tree().create_timer(corta, true, false, true).timeout.connect(func(): if p.stream == st: p.stop())
	_apunta(quien, anim, cuadro, ruta, db, g[1], "")


func _luego(s: float, ruta: String, pos: Vector2, papel: String, db_mas := 0.0, tono := 1.0, quien := "", anim := "") -> void:
	get_tree().create_timer(s).timeout.connect(func(): dispara(ruta, pos, papel, db_mas, tono, quien, anim))


func _uno(prefijo: String, n: int) -> String:
	return "res://sonidos/%s_%d.ogg" % [prefijo, randi_range(1, n)]


# ---------- voces ----------
func voz(a, anim: String) -> void:
	## la voz de una animación de voz, al empezar el clip (la llama escena.suena). Sólo voces de criatura: los ruidos de
	## acción van por cuadro(), en su fotograma
	var pedida: bool = a == mundo.elegido or a.encargo
	if not activo or not mundo.sonido or (not pedida and (mundo.reloj - _ultima_voz.get(a, -99.0) < 15.0 or mundo.reloj - _voz_global < 3.0)):
		return
	_voz_global = mundo.reloj
	var ruta := ruta_voz(a.nombre, anim)
	if ruta == "":
		return
	_ultima_voz[a] = mundo.reloj
	_sonado(a, anim)
	dispara(ruta, a.position, "voz", -8.0, 1.0, a.nombre, anim, 0)


func ruta_voz(nombre: String, anim: String) -> String:
	var base := nombre.split("_")[0]
	var an: String = ANIM_VOZ.get(base, {}).get(anim, anim)
	for b in [nombre, base, VOZ_DE.get(base, "")]:
		if b == "":
			continue
		var r := "res://sonidos/%s_%s.ogg" % [b, an]
		if ResourceLoader.exists(r):
			return r
	return ""


func _voz_propia(a) -> String:
	## la voz de su especie (para el quejido de hurt)
	for v in Comp.VOCES:
		if a.tiene(v):
			var r := ruta_voz(a.nombre, v)
			if r != "":
				return r
	return ""


# ---------- efectos en su fotograma ----------
func cuadro(a) -> void:
	## cada vez que el actor se dibuja: si ha pasado por un fotograma de contacto de lo que hace, su efecto
	_puerta(a)
	if a.paso.is_empty() or not a.visible:
		return
	var anim: String = a.paso.get("anim", "")
	var f: int = a._cuadro()
	var antes: Array = _visto.get(a, [])
	var nuevo: bool = antes.is_empty() or not is_same(antes[0], a.paso)
	_visto[a] = [a.paso, f]
	if nuevo:
		_empezada(a, anim)
		_al_empezar(a, anim)
	var lista := _contactos(a, anim)
	if lista.is_empty():
		return
	var n: int = a.pista()["ms"].size()
	# los fotogramas por los que ha pasado desde el último dibujado (con un delta largo se salta alguno)
	var desde: int = -1 if nuevo else int(antes[1])
	if not nuevo and desde == f:
		return
	var k := 0
	var i := desde
	while k < n:
		i = (i + 1) % n if i >= 0 else 0
		k += 1
		if i in lista:
			_efecto(a, anim, i)
			break
		if i == f:
			break


func _contactos(a, anim: String) -> Array:
	var por: Dictionary = contactos.get(a.base, {}).get(anim, {})
	if por.is_empty():
		return []
	if por.has(a.dir):
		return por[a.dir]
	# otra vista con otro número de fotogramas: a escala
	var otra: String = por.keys()[0]
	var n_otra: int = int(a.d["anims"][anim][otra]["ms"].size())
	var n: int = a.pista()["ms"].size()
	return por[otra].map(func(x): return int(round(float(x) * n / maxf(1.0, n_otra))) % n)


func _efecto(a, anim: String, f: int) -> void:
	var b: String = a.base
	var pie: Array = PIES.get(b, ["pezuna", 1.0, -4.0])
	var p: Vector2 = a.position
	var base_anim := anim.replace("_start", "").replace("_end", "")
	match base_anim:
		"walk", "run":
			if mundo.reloj - _ultimo_paso.get(a, -9.0) < 0.07:
				return
			_ultimo_paso[a] = mundo.reloj
			var suelo := superficie(p)
			var ruta := ""
			match suelo:
				"madera": ruta = _uno("_paso_madera", 4)
				"agua": ruta = _uno("_paso_agua", 3)
				"hierba": ruta = _uno("_paso_hierba", 4)
				_: ruta = _uno("_paso_casco", 4) if pie[0] == "pezuna" else _uno("_paso_tierra", 4)
			var mas: float = float(pie[2]) + (2.0 if base_anim == "run" else 0.0)
			if pie[0] == "pezuna" and suelo == "madera":
				mas += 3.0   # cascos en el puente: suenan huecos
			_sonado(a, anim)
			dispara(ruta, p, "efecto", mas, float(pie[1]), a.nombre, anim, f)
		"eat":
			_sonado(a, anim)
			if b in AVES:
				dispara(_uno("_picoteo", 3), p, "efecto", float(pie[2]) + 4.0, float(pie[1]) * 0.8, a.nombre, anim, f)
			else:
				dispara(_uno("_mordisco", 4), p, "efecto", -2.0 + float(pie[2]) * 0.5, clampf(float(pie[1]), 0.85, 1.4), a.nombre, anim, f)
		"suckle":
			_sonado(a, anim)
			dispara(_uno("_mamar", 3), p, "efecto", -6.0, 1.15, a.nombre, anim, f)
		"aleteo", "despegue", "aterrizaje", "fly":
			_sonado(a, anim)
			var tono: float = 1.25 if b in ["Pollito", "Patito", "Pavipollo", "Ansarino"] else (0.85 if b in ["Ganso", "GansoMacho", "PavoMacho", "Pava"] else 1.0)
			dispara(_uno("_ala", 3), p, "efecto", -2.0 if base_anim == "fly" else 0.0, tono, a.nombre, anim, f)
			if anim == "aterrizaje" and f >= a.pista()["ms"].size() - 4:
				dispara(_uno("_chapoteo", 3) if mundo.agua(p) else _uno("_paso_tierra", 4), p, "efecto", -4.0, 1.3, a.nombre, anim, f)
		"swim":
			_sonado(a, anim)
			if anim == "swim":
				dispara(_uno("_paso_agua", 3), p, "efecto", -8.0, 1.2, a.nombre, anim, f)   # el remo de las patas
			else:
				dispara(_uno("_chapoteo", 3), p, "efecto", 0.0 if anim == "swim_start" else -3.0, float(pie[1]) * 0.8, a.nombre, anim, f)
		"headbutt":
			_sonado(a, anim)
			dispara(_uno("_golpe", 2), p, "efecto", 2.0, 1.0, a.nombre, anim, f)
		"thump":
			_sonado(a, anim)
			dispara(_uno("_thump", 2), p, "efecto", 0.0, 1.2 if b == "Gazapo" else 1.0, a.nombre, anim, f)
		"attack":
			_sonado(a, anim)
			dispara(_uno("_ataque", 2), p, "efecto", 1.0, 0.85 if not b in AVES else 1.3, a.nombre, anim, f)
		"death":
			if a.paso.get("reversa", false):
				return   # levantarse no da golpe
			_sonado(a, anim)
			dispara(_uno("_caida", 2), p, "efecto", 2.0 if pie[0] == "pezuna" else -4.0, clampf(float(pie[1]), 0.7, 1.6), a.nombre, anim, f)
		"strut":
			_sonado(a, anim)
			dispara(_uno("_abanico", 2), p, "efecto", 2.0 if anim == "strut_start" else -2.0, 1.0, a.nombre, anim, f)
		"wash":
			_sonado(a, anim)
			dispara(_uno("_roce", 2), p, "efecto", -6.0, 1.3, a.nombre, anim, f)
		"oficio":
			_sonado(a, anim)
			dispara(_uno("_frota", 2), p + Vector2(10 if a.dir == "east" else -10, 0), "efecto", 0.0, 1.0, a.nombre, anim, f)
		"grano":
			_sonado(a, anim)
			var cae: Vector2 = p + Vector2(30 if a.dir == "east" else -30, 2)
			_luego(0.45, "res://sonidos/_grano.ogg", cae, "efecto", 0.0, 1.0, a.nombre, anim)


func _al_empezar(a, anim: String) -> void:
	## lo que suena al empezar el clip: el quejido de hurt y el cubo del granjero en el pozo o en el bebedero
	if anim == "hurt":
		var q: Array = QUEJIDO_DE.get(a.base, [])
		var ruta: String = ("res://sonidos/%s.ogg" % q[0]) if not q.is_empty() else _voz_propia(a)
		if ruta != "":
			_sonado(a, anim)
			dispara(ruta, a.position, "voz", -2.0, float(q[1]) if not q.is_empty() else 1.3, a.nombre, anim, 0, 0.45)
	elif a.nombre == "granjero" and anim == "idle" and int(a.paso.get("vueltas", 1)) == 5 and a.act == "tarea":
		var i: int = int(mundo._tarea.get(a.nombre, -1))
		var lista: Array = mundo.RUTINA["granjero"]
		if i < 0 or i >= lista.size() or lista[i][2] != "cubo":
			return
		var p: Vector2 = a.position
		_sonado(a, "cubo")
		if p.distance_to(POZO) < 45.0:
			# sacar agua: la polea, el cubo que da en el agua al fondo, la polea otra vez y el cubo en el brocal
			dispara("res://sonidos/_polea.ogg", POZO, "efecto", 0.0, 1.0, a.nombre, "cubo:pozo", 0)
			_luego(0.9, "res://sonidos/_polea.ogg", POZO, "efecto", -1.0, 0.92, a.nombre, "cubo:pozo")
			_luego(1.7, "res://sonidos/_chapoteo_3.ogg", POZO, "efecto", -10.0, 1.3, a.nombre, "cubo:pozo")
			_luego(2.6, "res://sonidos/_polea.ogg", POZO, "efecto", -1.0, 1.05, a.nombre, "cubo:pozo")
			_luego(3.6, "res://sonidos/_cubo.ogg", POZO, "efecto", -2.0, 1.0, a.nombre, "cubo:pozo")
		else:
			# en el bebedero: lo vacía
			_luego(0.4, "res://sonidos/_vierte.ogg", p, "efecto", 0.0, 1.0, a.nombre, "cubo:bebedero")
			_luego(2.2, "res://sonidos/_cubo.ogg", p, "efecto", -4.0, 1.1, a.nombre, "cubo:bebedero")


func _puerta(a) -> void:
	## los granjeros entran y salen de casa por la puerta: se oye abrirse y cerrarse
	if not a.nombre in ["granjero", "washerwoman"]:
		return
	var dentro: bool = not a.visible
	if _dentro.has(a) and _dentro[a] != dentro:
		dispara("res://sonidos/_puerta_abre.ogg", PUERTA_CASA, "efecto", 0.0, 1.0, a.nombre, "puerta", 0)
		_luego(0.8, "res://sonidos/_puerta_cierra.ogg", PUERTA_CASA, "efecto", 0.0, 1.0, a.nombre, "puerta")
		_sonado(a, "puerta")
	_dentro[a] = dentro


# ---------- ambiente por hora ----------
static func _franja(h: float, a: float, b: float, sube: float, baja: float) -> float:
	## 0..1 entre las horas a y b del día de 600 s (con vuelta), entrando en `sube` s y saliendo en `baja`
	var dur := fposmod(b - a, 600.0)
	var u := fposmod(h - a, 600.0)
	if u >= dur:
		return 0.0
	return clampf(minf(u / sube, (dur - u) / baja), 0.0, 1.0)


func _process(delta: float) -> void:
	if mundo == null:
		return
	# para que el ambiente de un actor que deja de dibujarse (en casa) también avise de la puerta
	for g in mundo.actores:
		if g.nombre in ["granjero", "washerwoman"] and not g.visible:
			_puerta(g)
	if _prueba and Time.get_ticks_msec() - _t0 > 180000 and _t0 > 0:
		_t0 = 0
		_resumen()
	if _prueba and Engine.get_process_frames() % 600 == 0:
		mundo.cam.zoom = Vector2.ONE * (2.0 if mundo.cam.zoom.x < 1.5 and randf() < 0.75 else 0.5)
	if not activo:
		return
	var h: float = mundo.hora
	var lluvia: float = mundo.ambiente.lluvia
	var ola: float = maxf(0.0, mundo.ambiente._ola(mundo.cam.position))   # la misma ráfaga que mece trigo y matas
	var obj := {
		"alba": _franja(h, 535.0, 75.0, 25.0, 30.0),                   # coro del alba
		"dia": _franja(h, 40.0, 410.0, 30.0, 35.0) * (1.0 - 0.7 * lluvia),
		"noche": _franja(h, 395.0, 565.0, 30.0, 25.0),                 # grillos del anochecer a la madrugada
		"viento": 0.35 + 0.65 * ola * ola,
		"lluvia": lluvia,
	}
	var k := 1.0 - exp(-delta * 0.8)
	for capa in obj:
		_amb_lin[capa] = lerpf(_amb_lin[capa], float(obj[capa]), k * (2.5 if capa == "viento" else 1.0))
		_amb[capa].volume_db = linear_to_db(maxf(_amb_lin[capa], 0.0001)) + (-2.0 if capa == "alba" else 0.0)
	_agua.volume_db = float(_ganancia(_agua.position, "amb")[0]) * 0.5
	# las ranas, cerca del estanque, al anochecer y de noche: croar suelto aquí y allá de la orilla
	var ranas: float = _franja(h, 400.0, 560.0, 20.0, 20.0)
	_t_rana -= delta
	if ranas > 0.05 and _t_rana <= 0.0:
		_t_rana = randf_range(0.35, 2.2) / ranas
		var e: Array = mundo.E["estanque"]["elipse"]
		var c := Vector2((float(e[0]) + float(e[2])) / 2.0, (float(e[1]) + float(e[3])) / 2.0)
		var r := Vector2((float(e[2]) - float(e[0])) / 2.0, (float(e[3]) - float(e[1])) / 2.0)
		var ang := randf() * TAU
		var donde := c + Vector2(cos(ang) * r.x, sin(ang) * r.y) * randf_range(0.85, 1.05)
		dispara("res://sonidos/_rana.ogg", donde, "amb", -12.0 + 6.0 * ranas, randf_range(0.85, 1.15), "estanque", "rana")
	# el molino cruje con cada cuarto de vuelta de las aspas (1,25 s), desde donde está
	_t_molino -= delta
	if _t_molino <= 0.0:
		_t_molino = 1.25 * randi_range(1, 2)
		dispara(_uno("_molino", 2), _molino, "amb", -10.0, randf_range(0.9, 1.05), "molino", "aspas")


# ---------- la prueba ----------
func _empezada(a, anim: String) -> void:
	if _prueba:
		var k := "%s/%s" % [a.base, anim]
		_empezadas[k] = _empezadas.get(k, 0) + 1


func _sonado(a, anim: String) -> void:
	if _prueba:
		var k := "%s/%s" % [a.base, anim]
		_sonadas[k] = _sonadas.get(k, 0) + 1


func _apunta(quien: String, anim: String, cuadro_: int, ruta: String, db: float, d: float, nota: String) -> void:
	if not _prueba:
		return
	_registro.append([snappedf(mundo.reloj, 0.01), snappedf(mundo.hora, 1.0), quien, anim, cuadro_, ruta.get_file(),
		snappedf(db, 0.1), snappedf(d, 1.0), nota])


func _resumen() -> void:
	print("SONIDO_PRUEBA ", _registro.size(), " disparos en 180 s (reloj x", Engine.time_scale, ")")
	var notas := {}
	for r in _registro:
		notas[r[8]] = notas.get(r[8], 0) + 1
	print("SONIDO_NOTAS ", notas)
	var por_archivo := {}
	for r in _registro:
		var clave: String = String(r[5]).get_basename().rstrip("0123456789").rstrip("_")
		por_archivo[clave] = por_archivo.get(clave, 0) + 1
	print("SONIDO_POR_TIPO ", por_archivo)
	# lo que empezó y debería sonar pero no sonó nunca
	var sin: Array = []
	for k in _empezadas:
		var an: String = k.split("/")[1]
		var deberia := an in ["walk", "run", "eat", "suckle", "aleteo", "despegue", "aterrizaje", "fly", "swim", "swim_start",
			"swim_end", "headbutt", "thump", "attack", "hurt", "death", "strut", "strut_start", "wash", "oficio", "grano"] \
			or an in Comp.VOCES or an == "lay_egg"
		if deberia and _sonadas.get(k, 0) == 0:
			sin.append("%s(x%d)" % [k, _empezadas[k]])
	sin.sort()
	print("SONIDO_SIN_SONIDO ", sin)
	print("SONIDO_AMBIENTE hora=", snappedf(mundo.hora, 1.0), " ", _amb_lin)
	# y el detalle: el primer disparo de cada quién+acción (todo entero serían miles de líneas)
	var visto := {}
	for r in _registro:
		var k := "%s/%s" % [r[2], r[3]]
		if not visto.has(k):
			visto[k] = true
			print("SONIDO t=%s h=%s %s %s f=%s %s %sdB d=%s %s" % r)

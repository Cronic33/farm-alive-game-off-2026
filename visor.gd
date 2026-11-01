extends Control
## Visor del pack: cualquier criatura del pack (especie, macho/hembra/cría, capa de color) con cualquiera de sus
## animaciones, en cualquiera de las cuatro vistas, a la velocidad y el zoom entero que se elija. Todo lo que se ve
## es del pack, tal cual.
##
## NORMA INDISPENSABLE (usuario, 24-10; docs/GIFS_NUEVO_ESTANDAR.md, NORMA_ANIMACION.md): el animal hace su «vida»
## seguida, como en el juego, sin parar: la misma cadena que los GIF de familia (trabajo/mascotas/scripts/
## gif_especie.py, lista AVE): reposo → andar → reposo → correr → comer → … → dormir → poner huevo, con un reposo corto
## (medio segundo de ida y vuelta) entre acción y acción. Nunca una animación suelta en bucle ni partida en piezas.
## La lista marca la acción que está haciendo; al pulsar una, la vida sigue desde ella cuando acaba la pieza en curso.

const UI := preload("res://ui.gd")
const Comp := preload("res://comportamiento.gd")
const ROLES := ["MALE", "FEMALE", "YOUNG"]
const VISTAS := [["ALL", "todas"], ["S", "south"], ["E", "east"], ["N", "north"], ["W", "west"]]
const CUATRO := ["south", "east", "north", "west"]
const AVANCE := {"south": Vector2(0, 1), "east": Vector2(1, 0), "north": Vector2(0, -1), "west": Vector2(-1, 0)}
const VELOCIDADES := [0.5, 1.0, 2.0]
# la vida: el orden de gif_especie.py (AVE), sin la muerte del final (la cadena da la vuelta)
const VIDA := ["idle", "idle", "walk_start", "walk", "walk", "walk", "walk_end", "idle", "run_start", "run", "run", "run",
	"run_end", "idle", "eat_start", "eat", "eat", "eat", "eat_end", "idle", "aleteo", "idle", "despegue", "fly", "fly",
	"fly", "aterrizaje", "idle", "attack", "idle", "crow", "idle", "peep", "idle", "bray", "idle", "neigh", "idle",
	"moo", "idle", "quack", "idle", "cluck", "idle", "bleat", "idle", "grunt", "idle", "headbutt", "idle",
	"suckle_start", "suckle", "suckle", "suckle_end", "idle", "swim_start", "swim", "swim", "swim", "swim_end", "idle",
	"sleep_start", "sleep", "sleep", "sleep", "sleep", "sleep_end", "idle", "lay_egg", "idle", "idle", "idle", "hurt",
	"idle"]
const REPOSO_CORTO := [0, 1, 2, 3, 2, 1]   # el reposo entre acciones: medio segundo de ida y vuelta (gif_especie.py)
const MUEVE := ["walk", "run", "swim", "fly"]
const ANDA := ["east", "west"]   # hacia donde anda solo
# encuadre de cada sitio (esquina en el mundo y zoom): el corral entero de las aves a 1x (el gallinero mide 100 px y a
# 2x no cabe sin cortarlo), el pavo con el pozo entero, los patos con su casita entera, y el recinto de vacas y
# caballos con sus comederos arriba (revisión independiente 18)
const ENCUADRES := {"aves": [973, 239, 1], "gallo": [973, 239, 1], "conejos": [880, 236, 2], "pavos": [590, 275, 2],
	"pato": [140, 561, 2], "orilla": [140, 561, 2], "vacas": [0, 172, 1], "toro": [0, 172, 1],
	"caballos": [700, 430, 1], "burros": [700, 430, 1]}
const RUEDA := ["south", "east", "north", "west"]   # hacia dónde mira en cada acción quieta: así se ven las cuatro   # las piezas en las que el animal avanza
const COLUMNA := 60   # ancho de las columnas de los lados (familias, acciones)
const SUELO_LIMPIO := Vector2(870, 440)   # un trozo de hierba del suelo de la granja sin caminos ni piezas

signal cerrar

var E: Dictionary
var ui
var texturas := {}
var fam := 0
var rol := 1
var capa := 0
var vista := "todas"
var vel := 1.0
var zoom := 2
var accion := "IDLE"      # la acción que está haciendo ahora (la lista la marca)
var _cuerpos := {}         # nombre/vista/pieza -> lo opaco de sus fotogramas
var _imagenes := {}        # nombre -> su atlas como imagen, para medirlo
var est := {}              # vista -> su estado (pieza, vuelta, fotograma, paseo): cada dirección vive su cadena
var secuencia: Array = []  # [pieza, vueltas, reposo_corto] en el orden en que se encadenan: toda la vida
var anim := "idle"         # la pieza que se está dibujando (sólo para dibujar, nunca se elige suelta)
var escenario: Control
var col_especies: VBoxContainer
var col_anims: VBoxContainer
var fila_roles: HBoxContainer
var fila_vistas: HBoxContainer
var fila_vel: HBoxContainer
var fila_zoom: HBoxContainer
var lbl_capa: Label
var _botones_accion := {}
var _voz: AudioStreamPlayer
var suelo: Texture2D
var _escena_r := Rect2()   # el escenario de la vida suelta (en «todas»): su recinto entero, en píxeles de pantalla
var _pantalla := Rect2()   # lo que se ve de él (el recuadro del visor)
var _cam := Vector2(-1, -1)   # cuánto se ha desplazado la cámara dentro del recinto (píxeles de pantalla)
var _marco := Rect2()      # el recinto entero, en el mundo
var _raton := {}           # el ratón que cruza (el suceso que la asusta)
var _tween_cielo: Tween
var _tapan := {}           # encuadre -> las piezas que pueden tapar al animal
var _ventanas := {}        # nombre/zoom/tamaño -> el encuadre de su recinto


func prepara(datos: Dictionary, la_ui) -> void:
	E = datos
	ui = la_ui
	suelo = load("res://datos/suelo.png")
	# la granja se atenúa detrás; el visor va opaco encima
	var velo := ColorRect.new()
	velo.color = Color(UI.VIOLETA, 0.78)
	velo.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(velo)
	var marco := PanelContainer.new()
	marco.add_theme_stylebox_override("panel", ui.marco([8, 6, 8, 7]))
	marco.set_anchors_preset(Control.PRESET_FULL_RECT)
	marco.offset_left = UI.MARGEN
	marco.offset_top = UI.MARGEN
	marco.offset_right = -UI.MARGEN
	marco.offset_bottom = -UI.MARGEN
	add_child(marco)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 5)
	marco.add_child(col)
	var cab := HBoxContainer.new()
	col.add_child(cab)
	var tit := Label.new()
	tit.text = "PACK VIEWER"
	tit.add_theme_color_override("font_color", UI.PERGAMINO)
	cab.add_child(tit)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(hueco)
	var x: Button = ui.boton_cerrar()
	x.pressed.connect(func(): cerrar.emit())
	cab.add_child(x)
	var cuerpo := HBoxContainer.new()
	cuerpo.add_theme_constant_override("separation", 8)
	cuerpo.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(cuerpo)
	# especies, con los mismos nombres y el mismo orden que la tira de abajo
	col_especies = VBoxContainer.new()
	col_especies.add_theme_constant_override("separation", 0)
	col_especies.custom_minimum_size = Vector2(COLUMNA, 0)   # las dos columnas, iguales: la vista queda centrada
	cuerpo.add_child(col_especies)
	for i in E["visor"].size():
		var b: Button = ui._boton(UI.FAMILIAS[i][0] if i < UI.FAMILIAS.size() else E["visor"][i]["en"].to_upper())
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN   # la raya, sólo bajo la palabra
		b.pressed.connect(func(): fam = i; rol = mini(1, E["visor"][i]["miembros"].size() - 1); capa = 0; _cambia_animal())
		col_especies.add_child(b)
	# el escenario y, debajo y centrados, los controles
	var centro := VBoxContainer.new()
	centro.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	centro.add_theme_constant_override("separation", 3)
	cuerpo.add_child(centro)
	var marco_esc := PanelContainer.new()
	marco_esc.add_theme_stylebox_override("panel", ui.marco([3, 3, 3, 3]))
	marco_esc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	centro.add_child(marco_esc)
	escenario = Control.new()
	escenario.clip_contents = true
	escenario.draw.connect(_dibuja)
	marco_esc.add_child(escenario)
	fila_roles = _fila(centro)
	var fila_capa := _fila(centro)
	var menos: Button = ui._boton("<", false)
	menos.custom_minimum_size = Vector2(12, 9)
	menos.alignment = HORIZONTAL_ALIGNMENT_CENTER
	menos.pressed.connect(func(): _cambia_capa(-1))
	fila_capa.add_child(menos)
	lbl_capa = Label.new()
	lbl_capa.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	fila_capa.add_child(lbl_capa)
	var mas: Button = ui._boton(">", false)
	mas.custom_minimum_size = Vector2(12, 9)
	mas.alignment = HORIZONTAL_ALIGNMENT_CENTER
	mas.pressed.connect(func(): _cambia_capa(1))
	fila_capa.add_child(mas)
	var ajustes := HBoxContainer.new()
	centro.add_child(ajustes)
	fila_vistas = _grupo(ajustes, "VIEW")
	var hueco1 := Control.new()
	hueco1.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ajustes.add_child(hueco1)
	for v in VISTAS:
		var b: Button = ui._boton(v[0])
		b.pressed.connect(func(): vista = v[1]; _arma_secuencia(); _refresca())
		fila_vistas.add_child(b)
	fila_vel = _grupo(ajustes, "SPEED")
	var hueco2 := Control.new()
	hueco2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for s in VELOCIDADES:
		var b: Button = ui._boton(("%.1fX" % s).replace(".0X", "X"))
		b.pressed.connect(func(): vel = s; _refresca())
		fila_vel.add_child(b)
	ajustes.add_child(hueco2)
	fila_zoom = _grupo(ajustes, "ZOOM")
	for z in [1, 2, 3, 4]:
		var b: Button = ui._boton("%dX" % z)
		b.pressed.connect(func(): zoom = z; _refresca())
		fila_zoom.add_child(b)
	# animaciones agrupadas por acción, cada pieza con su nombre del ZIP y sus fotogramas
	var der := VBoxContainer.new()
	der.add_theme_constant_override("separation", 2)
	cuerpo.add_child(der)

	var caja_lista := Control.new()
	caja_lista.size_flags_vertical = Control.SIZE_EXPAND_FILL
	caja_lista.custom_minimum_size = Vector2(COLUMNA, 0)
	der.add_child(caja_lista)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	caja_lista.add_child(scroll)
	var fundido := TextureRect.new()
	var gf := GradientTexture2D.new()
	gf.gradient = Gradient.new()
	gf.gradient.set_color(0, Color(UI.VIOLETA, 0.0))
	gf.gradient.set_color(1, Color(UI.VIOLETA, 1.0))
	gf.fill_to = Vector2(0, 1)
	gf.width = 4
	gf.height = 24
	fundido.texture = gf
	fundido.stretch_mode = TextureRect.STRETCH_SCALE
	fundido.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fundido.anchor_left = 0
	fundido.anchor_right = 1
	fundido.anchor_top = 1
	fundido.anchor_bottom = 1
	fundido.offset_top = -18
	fundido.offset_right = -4
	caja_lista.add_child(fundido)
	col_anims = VBoxContainer.new()
	col_anims.add_theme_constant_override("separation", 0)
	scroll.add_child(col_anims)
	var pie := HBoxContainer.new()
	col.add_child(pie)
	var teclas := HBoxContainer.new()
	teclas.add_theme_constant_override("separation", 3)
	ui.pon_teclas(teclas, [["WASD", "MOVE"], ["SHIFT", "RUN"], ["ESC", "BACK"]])
	pie.add_child(teclas)
	var hueco_n := Control.new()
	hueco_n.custom_minimum_size = Vector2(10, 0)
	pie.add_child(hueco_n)
	var nota := Label.new()
	nota.text = "EVERYTHING HERE IS IN THE PACK"
	nota.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nota.add_theme_color_override("font_color", Color(UI.PERGAMINO, 0.55))
	pie.add_child(nota)
	var comprar: Button = ui.boton_laton("GET THE PACK")
	comprar.pressed.connect(func(): OS.shell_open(UI.URL_PACK))
	pie.add_child(comprar)
	_cambia_animal()


func _fila(padre: Control) -> HBoxContainer:
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 6)
	f.alignment = BoxContainer.ALIGNMENT_CENTER
	padre.add_child(f)
	return f


func _grupo(padre: Control, titulo: String) -> HBoxContainer:
	var f := HBoxContainer.new()
	f.add_theme_constant_override("separation", 5)
	padre.add_child(f)
	var l := Label.new()
	l.text = titulo + " "
	l.add_theme_color_override("font_color", Color(UI.PERGAMINO, 0.7))
	f.add_child(l)
	return f


func muestra(nombre: String) -> void:
	## abre el visor en una criatura concreta (desde la ficha de un animal de la escena)
	for i in E["visor"].size():
		for j in E["visor"][i]["miembros"].size():
			var capas: Array = E["visor"][i]["miembros"][j]["capas"]
			if nombre in capas:
				fam = i
				rol = j
				capa = capas.find(nombre)
				accion = "IDLE"
				_cambia_animal_sin_capa()
				return


func _cambia_animal_sin_capa() -> void:
	var d := _datos()
	zoom = _zoom_de_entrada(d)
	_arma_secuencia()
	_refresca()


func _miembro() -> Dictionary:
	return E["visor"][fam]["miembros"][rol]


func _nombre() -> String:
	return _miembro()["capas"][capa]


func _datos() -> Dictionary:
	return E["animales"][_nombre()]


func _cambia_capa(k: int) -> void:
	var n: int = _miembro()["capas"].size()
	capa = (capa + k + n) % n
	_arma_secuencia()
	_refresca()


func _cambia_animal() -> void:
	# zoom de entrada según el tamaño del animal: que llene el escenario sin salirse
	var d := _datos()
	zoom = _zoom_de_entrada(d)
	_arma_secuencia()
	_refresca()


func _zoom_de_entrada(d: Dictionary) -> int:
	## en su sitio («todas»): los pequeños a 2x; los grandes a 1x, que es cuando cabe su recinto con su casa detrás
	## (a 2x sólo se verían 153 x 81 px de mundo: la casa fuera). En una vista suelta, que llene el escenario
	var alto := float(d["pie"]) - float(d["tope"])
	if vista == "todas":
		return 3 if alto <= 18.0 else 2
	return clampi(int(150.0 / maxf(alto, 1.0)), 1, 4)


func _refresca() -> void:
	var miembros: Array = E["visor"][fam]["miembros"]
	for i in col_especies.get_child_count():
		col_especies.get_child(i).set_pressed_no_signal(i == fam)
	for c in fila_roles.get_children():
		c.queue_free()
	for i in miembros.size():
		var b: Button = ui._boton(String(miembros[i]["en"]).replace("_", " ").to_upper())
		b.set_pressed_no_signal(i == rol)
		b.pressed.connect(func(): rol = i; capa = 0; _cambia_animal())
		fila_roles.add_child(b)
	var d := _datos()
	# capa de color con nombre y cuántas hay: «HEN · BLACK · 2/4»
	var base_en: String = _miembro()["en"].replace("_", " ")
	var color: String = d["en"].trim_prefix(base_en).strip_edges()
	lbl_capa.text = "%s · %d/%d" % [(color if color != "" else "standard").to_upper(), capa + 1, _miembro()["capas"].size()]
	var acciones: Array = ui.acciones_de(d["anims"], d["zip"])
	_botones_accion.clear()
	for c in col_anims.get_children():
		c.queue_free()
	for acc in acciones:
		var fila := HBoxContainer.new()
		var b: Button = ui._boton(acc[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		b.set_pressed_no_signal(acc[0] == accion)
		b.pressed.connect(func(): _salta_a(acc[0]))
		fila.add_child(b)
		col_anims.add_child(fila)
		_botones_accion[acc[0]] = b
	for i in VISTAS.size():
		fila_vistas.get_child(i + 1).set_pressed_no_signal(VISTAS[i][1] == vista)
	if vista == "todas" and zoom > 3:
		zoom = 3
	for i in VELOCIDADES.size():
		fila_vel.get_child(i + 1).set_pressed_no_signal(is_equal_approx(VELOCIDADES[i], vel))
	for i in 4:
		fila_zoom.get_child(i + 1).set_pressed_no_signal(i + 1 == zoom)


func _arma_secuencia() -> void:
	## la vida entera de este animal, en el orden de los GIF de familia: lo que no tiene se salta, dos reposos seguidos
	## no se repiten, y el reposo entre acciones es el corto (salvo al principio y tras poner el huevo, que se ve)
	var d := _datos()
	secuencia = []
	for a in VIDA:
		if not d["anims"].has(a):
			continue
		if a == "idle" and secuencia.size() > 1 and secuencia[-1][0] == "idle":
			var tras_huevo: bool = secuencia.size() > 1 and secuencia[-2][0] == "lay_egg"
			if not tras_huevo:
				continue
		if not secuencia.is_empty() and secuencia[-1][0] == a and a != "idle":
			secuencia[-1][1] += 1   # la misma pieza seguida: más vueltas
			continue
		var corto: bool = a == "idle" and not secuencia.is_empty() and secuencia[-1][0] != "lay_egg"
		secuencia.append([a, 1, corto])
	if secuencia.is_empty():
		secuencia = [["idle", 1, false]]
	if vista == "todas":
		secuencia = _dia(d)
	# cada dirección vive su cadena con sus propios fotogramas y su ritmo (una vista puede tener más fotogramas que
	# otra: con un solo reloj, la más larga se cortaba)
	est = {}
	for v in CUATRO:
		est[v] = {"ip": 0, "vuelta": 0, "paso_i": 0, "t": 0.0, "anim": secuencia[0][0], "fotograma": 0,
			"desplazado": 0.0, "bloque_ms": 0.0, "bloque_px": 0.0, "saltar": -1, "espera": false}
	# en «todas», el animal vive suelto en un solo escenario: anda por él, se para antes de girar y nunca sale
	_cam = Vector2(-1, -1)
	est["vida"] = {"ip": 0, "vuelta": 0, "paso_i": 0, "t": 0.0, "anim": secuencia[0][0], "fotograma": 0,
		"desplazado": 0.0, "bloque_ms": 0.0, "bloque_px": 0.0, "saltar": -1, "espera": false,
		"dir": "south", "pos": Vector2(-1, -1), "n": -1}
	anim = secuencia[0][0]
	_marca_accion()


func _dia(d: Dictionary) -> Array:
	## un día de su vida, con causa: pasea, come y hace sus cosas en distintos sitios; algo le pasa cerca (un ratón) y
	## reacciona (aletea, huye); anochece y se duerme; amanece, se levanta y pone el huevo. Cada pieza:
	## [pieza, vueltas, reposo corto, suceso]
	var a: Dictionary = d["anims"]
	var dia: Array = []
	_pon(dia, a, "idle", 1, false, "")
	_paseo(dia, a, 2)
	_comer(dia, a, 2)
	_paseo(dia, a, 1)
	for voz in Comp.VOCES:
		if a.has(voz):
			_pon(dia, a, voz, 1, false, "")
			_pon(dia, a, "idle", 1, true, "")
			_paseo(dia, a, 1)
	# lo demás que sabe hacer, en el orden de los GIF de familia (cada cadena entera)
	var hechas := ["idle", "walk", "walk_start", "walk_end", "run", "run_start", "run_end", "eat", "eat_start",
		"eat_end", "aleteo", "hurt", "death", "sleep", "sleep_start", "sleep_end", "lay_egg"] + Comp.VOCES
	var k := 0
	while k < VIDA.size():
		var p: String = VIDA[k]
		if a.has(p) and not p in hechas:
			var base := p.trim_suffix("_start")
			while k < VIDA.size() and VIDA[k].trim_suffix("_start").trim_suffix("_end") == base.trim_suffix("_end"):
				if dia.is_empty() or dia[-1][0] != VIDA[k]:
					_pon(dia, a, VIDA[k], 1, false, "")
				elif a.has(VIDA[k]):
					dia[-1][1] += 1
				hechas.append(VIDA[k])
				k += 1
			_pon(dia, a, "idle", 1, true, "")
			_paseo(dia, a, 1)
			continue
		k += 1
	# algo pasa cerca: se asusta (aletea) y sale corriendo
	if _nombre().split("_")[0] != "Raton" and (a.has("aleteo") or a.has("run")):
		_pon(dia, a, "idle", 1, false, "raton")
		_pon(dia, a, "aleteo", 1, false, "")
		_pon(dia, a, "run_start", 1, false, "huye")
		_pon(dia, a, "run", 2, false, "" if a.has("run_start") else "huye")
		_pon(dia, a, "run_end", 1, false, "")
		_pon(dia, a, "idle", 1, true, "")
	_comer(dia, a, 1)
	_paseo(dia, a, 1)
	# anochece: se duerme; amanece: se levanta y pone el huevo
	if a.has("sleep"):
		_pon(dia, a, "idle", 1, true, "a_casa")   # al caer la tarde vuelve a su sitio, delante de su casa
		_pon(dia, a, "idle", 1, false, "anochece")
		_pon(dia, a, "sleep_start", 1, false, "")
		_pon(dia, a, "sleep", 4, false, "")
		_pon(dia, a, "sleep_end", 1, false, "amanece")
		if not a.has("sleep_end"):
			dia[-1][3] = "amanece"
		_pon(dia, a, "idle", 1, false, "")
	_pon(dia, a, "lay_egg", 1, false, "")
	_pon(dia, a, "idle", 1, false, "")
	if dia.is_empty():
		dia = [["idle", 1, false, ""]]
	return dia


func _pon(dia: Array, a: Dictionary, p: String, n: int, corto: bool, suceso: String) -> void:
	if a.has(p):
		dia.append([p, n, corto, suceso])


func _paseo(dia: Array, a: Dictionary, n: int) -> void:
	if a.has("walk"):
		_pon(dia, a, "walk_start", 1, false, "")
		_pon(dia, a, "walk", n, false, "")
		_pon(dia, a, "walk_end", 1, false, "")
		_pon(dia, a, "idle", 1, true, "")


func _comer(dia: Array, a: Dictionary, n: int) -> void:
	if a.has("eat"):
		_pon(dia, a, "eat_start", 1, false, "")
		_pon(dia, a, "eat", n, false, "")
		_pon(dia, a, "eat_end", 1, false, "")
		_pon(dia, a, "idle", 1, true, "")


func _principal() -> String:
	## la vista que manda en la lista y en el sonido: la de frente en «todas», o la que se ve
	return "south" if vista == "todas" else vista


func _prepara_paseo(st: Dictionary, v: String) -> void:
	## al empezar un paseo, mide cuánto duran sus bucles en esta vista y cuánto avanzaría a su velocidad real; al
	## acabar (otra acción), vuelve a cero: el animal está otra vez en el centro
	var base: String = st["anim"].trim_suffix("_start").trim_suffix("_end")
	if not base in ["walk", "run", "swim"]:
		st["desplazado"] = 0.0
		st["bloque_ms"] = 0.0
		return
	if st["bloque_ms"] > 0.0:
		return   # ya dentro de este paseo
	var d := _datos()
	var ms := 0.0
	for k in range(st["ip"], secuencia.size()):
		var pz: String = secuencia[k][0]
		if pz.trim_suffix("_start").trim_suffix("_end") != base:
			break
		if pz == base:
			var pista: Dictionary = d["anims"][pz].get(v, d["anims"][pz].values()[0])
			for m in pista["ms"]:
				ms += float(m) * secuencia[k][1]
	var esp: Dictionary = Comp.ESPECIE.get(_nombre().split("_")[0], {})
	var v_real: float = float(esp.get("corre", float(esp.get("vel", 14.0)) * 2.5)) if base == "run" else float(esp.get("vel", 14.0))
	st["bloque_ms"] = maxf(ms, 1.0)
	st["bloque_px"] = v_real * ms / 1000.0
	st["desplazado"] = 0.0


func _suena_pieza() -> void:
	var ruta: String = load("res://escena.gd").ruta_sonido(_nombre(), anim)
	if ruta == "" or not get_tree().current_scene.sonido:
		return
	if _voz == null:
		_voz = AudioStreamPlayer.new()
		add_child(_voz)
	_voz.stream = load(ruta)
	_voz.volume_db = load("res://escena.gd").nivel(ruta)
	_voz.play()


func _salta_a(etiqueta: String) -> void:
	## la vida sigue desde esa acción: cuando acabe la pieza que está haciendo, entra por el arranque de la elegida
	var d := _datos()
	for acc in ui.acciones_de(d["anims"], d["zip"]):
		if acc[0] != etiqueta:
			continue
		for k in secuencia.size():
			if secuencia[k][0] in acc[1] and vista != "todas":
				for v in est:
					est[v]["saltar"] = k   # cada vista entra al acabar su pieza en curso
				return
		# no está en su día (morir, el golpe…), o en la vida suelta: se mete justo después de lo que hace, entera
		var vida: Dictionary = est.get("vida", {})
		var ip: int = int(vida.get("ip", 0)) if vista == "todas" else int(est.get("south", {}).get("ip", 0))
		var piezas: Array = []
		for p in acc[1]:
			if d["anims"].has(p):
				piezas.append([p, 3 if p in ["eat", "sleep", "swim"] else 1, false, ""])
		if piezas.is_empty():
			return
		if acc[1].has("death"):
			piezas[-1][3] = "tendido"   # se queda tendido un momento antes de levantarse
		piezas.append(["idle", 1, false, ""])
		for k in piezas.size():
			secuencia.insert(ip + 1 + k, piezas[k])
		for v in est:
			est[v]["saltar"] = ip + 1
			if vista == "todas" and v == "vida":
				est[v]["manual"] = false
				est[v]["espera"] = true   # sin esperar a que acabe el reposo: ya
		return


func _marca_accion() -> void:
	## la lista marca lo que está haciendo de verdad (la acción a la que pertenece la pieza en curso)
	var d := _datos()
	for acc in ui.acciones_de(d["anims"], d["zip"]):
		if anim in acc[1]:
			accion = acc[0]
	for k in _botones_accion:
		_botones_accion[k].set_pressed_no_signal(k == accion)


func _fotogramas_pieza(st: Dictionary, p: Dictionary) -> Array:
	## los índices de fotograma de la pieza en curso (el reposo corto es la ida y vuelta de los primeros)
	var n: int = p["ms"].size()
	if secuencia[st["ip"]][2] and n > 6:
		return REPOSO_CORTO
	return range(n)


func _pista(st: Dictionary, v: String) -> Dictionary:
	var a: Dictionary = _datos()["anims"][st["anim"]]
	return a.get(v, a.values()[0])


func _avanza(st: Dictionary, v: String, delta: float) -> void:
	var p := _pista(st, v)
	var idx: Array = _fotogramas_pieza(st, p)
	st["t"] += delta * 1000.0 * vel
	# andando, corriendo o nadando avanza: el paseo entero recorre un número entero de vueltas a su recuadro, a
	# velocidad casi real, para acabar donde empezó
	if st["bloque_ms"] > 0.0 and st["anim"] in ["walk", "run", "swim"]:
		st["desplazado"] = minf(1.0, st["desplazado"] + delta * 1000.0 * vel / st["bloque_ms"])
	if st.has("pos") and st["anim"] in MUEVE and not st["espera"] and _escena_r.size.x > 0 and not st.get("manual", false):
		st["pos"] = _dentro(st["pos"] + AVANCE[v] * _v_real(st["anim"]) * float(zoom) * delta * vel * (0.7 if v in ["north", "south"] else 1.0))
	while st["t"] >= p["ms"][idx[st["paso_i"]]]:
		if st["espera"] and not _en_bucle(st["anim"]):
			st["t"] = 0.0   # acabó su pieza: se queda en su último fotograma hasta que acaben las demás vistas
			break
		st["t"] -= p["ms"][idx[st["paso_i"]]]
		st["paso_i"] += 1
		if st["paso_i"] >= idx.size():
			if st["espera"]:
				st["paso_i"] = 0   # un bucle sigue en bucle mientras espera
				continue
			st["vuelta"] += 1
			var vueltas: int = st["n"] if st.get("n", -1) > 0 else secuencia[st["ip"]][1]
			if st.get("acecha", false) and st["saltar"] < 0:
				st["paso_i"] = 0   # sigue en su reposo hasta que ve venir al ratón
				continue
			if st["vuelta"] >= vueltas or st["saltar"] >= 0:
				st["espera"] = true
				if _en_bucle(st["anim"]):
					st["paso_i"] = 0
				else:
					st["paso_i"] = idx.size() - 1
					st["t"] = 0.0
					break
			else:
				st["paso_i"] = 0
	st["fotograma"] = idx[st["paso_i"]]


func _suceso(st: Dictionary, suceso: String) -> void:
	match suceso:
		"raton":
			_suelta_raton(st)
			if not _raton.is_empty():
				st["acecha"] = true
				st["dir"] = "west" if _raton["dir"] == "east" else "east"   # mira hacia donde viene
		"huye":
			# sale corriendo hacia arriba o hacia abajo, lejos de por donde pasa el ratón
			st["huye"] = "east" if st["dir"] == "west" else "west"   # de lado, hacia donde no está el ratón
		"a_casa":
			if st.has("casa_pos"):
				st["casa"] = true
				st["casa_fase"] = "x"
				st["manual"] = true
		"anochece":
			_cielo(Color(0.42, 0.40, 0.66))
		"amanece":
			_cielo(Color.WHITE)


func _cielo(c: Color) -> void:
	## el día y la noche en el escenario del visor (el mismo violeta frío que la noche de la granja)
	if _tween_cielo:
		_tween_cielo.kill()
	_tween_cielo = create_tween()
	_tween_cielo.tween_property(escenario, "modulate", c, 2.5)


func _suelta_raton(st: Dictionary) -> void:
	## un ratón del pack se acerca correteando por el lado hacia el que tiene sitio, se para delante de ella y la mira;
	## ella lo ve y aletea; él da media vuelta y se va corriendo por donde ha venido
	if not E["animales"].has("Raton") or _escena_r.size.x <= 0:
		return
	var rd: Dictionary = E["animales"]["Raton"]
	if not texturas.has("Raton"):
		texturas["Raton"] = load("res://datos/" + rd["archivo"])
	var z := float(zoom)
	var visto := Rect2(_pantalla.position + _cam, _pantalla.size)
	var por_oeste: bool = st["pos"].x - visto.position.x > visto.end.x - st["pos"].x   # por donde hay más sitio
	var x0: float = visto.position.x - float(rd["w"]) * z if por_oeste else visto.end.x + float(rd["w"]) * z
	var meta: float = st["pos"].x + (-1.0 if por_oeste else 1.0) * 17.0 * z
	_raton = {"x": x0, "y": st["pos"].y + 2.0 * z, "dir": "east" if por_oeste else "west", "anim": "run",
		"fase": "llega", "meta": meta, "vel": 45.0 * z, "t": 0.0, "i": 0, "quieto": 0.0}


func _mueve_raton(delta: float) -> void:
	if _raton.is_empty():
		return
	var z := float(zoom)
	var st: Dictionary = est.get("vida", {})
	match _raton["fase"]:
		"llega":
			var paso: float = _raton["vel"] * delta * vel
			var falta: float = _raton["meta"] - _raton["x"]
			if absf(falta) <= paso:
				_raton["x"] = _raton["meta"]
				_raton["fase"] = "mira"
				_cambia_raton("idle")
				# la gallina lo ve delante: deja el reposo en ese instante y aletea
				if st.get("acecha", false):
					st["acecha"] = false
					st["espera"] = true
			else:
				_raton["x"] += signf(falta) * paso
		"mira":
			_raton["quieto"] += delta * vel
			if _raton["quieto"] >= 0.7:   # el aleteo lo espanta
				_raton["fase"] = "huye"
				_raton["dir"] = "west" if _raton["dir"] == "east" else "east"
				_raton["vel"] = 110.0 * z
				_cambia_raton("run")
		"huye":
			_raton["x"] += (1.0 if _raton["dir"] == "east" else -1.0) * _raton["vel"] * delta * vel
	var pista: Dictionary = E["animales"]["Raton"]["anims"][_raton["anim"]][_raton["dir"]]
	_raton["t"] += delta * 1000.0 * vel
	while _raton["t"] >= float(pista["ms"][_raton["i"]]):
		_raton["t"] -= float(pista["ms"][_raton["i"]])
		_raton["i"] = (_raton["i"] + 1) % pista["ms"].size()
	var fuera: float = float(E["animales"]["Raton"]["w"]) * z
	var visto := Rect2(_pantalla.position + _cam, _pantalla.size)
	if _raton["fase"] == "huye" and (_raton["x"] < visto.position.x - fuera * 1.5 or _raton["x"] > visto.end.x + fuera * 1.5):
		_raton = {}


func _cambia_raton(a: String) -> void:
	_raton["anim"] = a
	_raton["i"] = 0
	_raton["t"] = 0.0


func _mando(st: Dictionary, delta: float) -> void:
	## quien juega lo lleva con WASD o las flechas (mayúsculas: corre). Anda con sus animaciones encadenadas, gira hacia
	## donde se le lleva y no sale de su recinto ni pasa por encima de nada; al soltar, acaba el paso y se para. A los
	## seis segundos sin tocar nada, vuelve a su vida
	if _escena_r.size.x <= 0:
		return
	var v := Vector2.ZERO
	for par in [[KEY_A, KEY_LEFT, Vector2.LEFT], [KEY_D, KEY_RIGHT, Vector2.RIGHT], [KEY_W, KEY_UP, Vector2.UP],
			[KEY_S, KEY_DOWN, Vector2.DOWN]]:
		if Input.is_physical_key_pressed(par[0]) or Input.is_physical_key_pressed(par[1]):
			v += par[2]
	if v != Vector2.ZERO:
		st["casa"] = false   # quien juega manda
	elif st.get("casa", false):
		v = _hacia_casa(st)
	if v != Vector2.ZERO:
		if not st.get("manual", false):
			st["manual"] = true
			st["acecha"] = false
			_raton = {}
			st["saltar"] = -1
		st["toque"] = 0.0
		var hacia := ("east" if v.x > 0 else "west") if absf(v.x) >= absf(v.y) else ("south" if v.y > 0 else "north")
		if hacia == "north":
			# hacia el norte se vuelve de espaldas, quieta (andando de espaldas parece que ande en el sitio)
			if st["anim"] in MUEVE:
				var n_n: int = _pista(st, st["dir"])["ms"].size()
				if st["paso_i"] == 0 or st["paso_i"] == n_n >> 1:
					var fin_n: String = st["anim"] + "_end"
					_pon_pieza(st, fin_n if _datos()["anims"].has(fin_n) else "idle")
			elif st["anim"] == "idle":
				st["dir"] = "north"
			return
		var corre: bool = Input.is_physical_key_pressed(KEY_SHIFT) and _datos()["anims"].has("run")
		var mov := "run" if corre else "walk"
		if not _datos()["anims"].has(mov):
			return
		if st["anim"] != mov:
			_pon_pieza(st, mov)
		st["dir"] = hacia
		var paso := _v_real(mov) * float(zoom) * delta * vel
		if _sitio(st["pos"], hacia) > paso:
			st["pos"] = st["pos"] + AVANCE[hacia] * paso
		return
	if not st.get("manual", false):
		return
	st["toque"] = st.get("toque", 0.0) + delta
	if st["anim"] in MUEVE:
		# suelta las teclas: termina en una pisada y se para con su parada
		var n: int = _pista(st, st["dir"])["ms"].size()
		if st["paso_i"] == 0 or st["paso_i"] == n >> 1:
			var fin: String = st["anim"] + "_end"
			_pon_pieza(st, fin if _datos()["anims"].has(fin) else "idle")
	elif st.get("casa", false) and st["casa_fase"] == "fin" and st["anim"] == "idle":
		st["casa"] = false   # ya en casa: sigue su día (se duerme)
		st["manual"] = false
		st["espera"] = true
	elif st["toque"] > 6.0 and st["anim"] == "idle":
		st["manual"] = false   # vuelve a su vida
		st["espera"] = true


func _hacia_casa(st: Dictionary) -> Vector2:
	## vuelve a su sitio andando: primero de lado, se para y gira, y luego arriba o abajo; si algo estorba, sigue por el
	## otro lado o se queda donde está
	var falta: Vector2 = st["casa_pos"] - st["pos"]
	match st["casa_fase"]:
		"x":
			var hacia := "east" if falta.x > 0 else "west"
			if absf(falta.x) < 1.5 or _sitio(st["pos"], hacia) < 8.0:
				if absf(falta.x) < 1.5:
					st["pos"].x = st["casa_pos"].x
				st["casa_fase"] = "giro"
				return Vector2.ZERO
			return Vector2(signf(falta.x), 0)
		"giro":
			if st["anim"] == "idle":
				st["casa_fase"] = "y"
			return Vector2.ZERO
		"y":
			var hacia := "south" if falta.y > 0 else "north"
			if absf(falta.y) < 1.5 or _sitio(st["pos"], hacia) < 8.0 or hacia == "north":   # de espaldas no anda
				if absf(falta.y) < 1.5:
					st["pos"].y = st["casa_pos"].y
				st["casa_fase"] = "fin"
				return Vector2.ZERO
			return Vector2(0, signf(falta.y))
	return Vector2.ZERO


func _mando_fin_pieza(st: Dictionary) -> void:
	st["espera"] = false
	st["vuelta"] = 0
	if not _en_bucle(st["anim"]) or st["anim"] in MUEVE:
		_pon_pieza(st, "idle" if not st["anim"] in MUEVE else st["anim"])


func _pon_pieza(st: Dictionary, a: String) -> void:
	st["anim"] = a
	st["paso_i"] = 0
	st["t"] = 0.0
	st["vuelta"] = 0
	st["espera"] = false
	st["n"] = 1
	st["fotograma"] = 0
	anim = a
	_suena_pieza()
	_marca_accion()


func _v_real(a: String) -> float:
	## la velocidad real de la especie, en píxeles del juego por segundo
	var base: String = a.trim_suffix("_start").trim_suffix("_end")
	var esp: Dictionary = Comp.ESPECIE.get(_nombre().split("_")[0], {})
	var andar := float(esp.get("vel", 14.0))
	match base:
		"run":
			return float(esp.get("corre", andar * 2.5))
		"fly":
			return andar * 3.0
	return andar


func _margenes() -> Rect2:
	## dónde pueden estar los pies para que el cuerpo entero quede dentro del escenario (mire hacia donde mire)
	var d := _datos()
	var z := float(zoom)
	var medio := float(d["w"]) / 2.0
	var ancho := 0.0
	var alto := 0.0
	for v in CUATRO:
		for a in ["idle", "walk", "run"]:
			if not d["anims"].has(a):
				continue
			var c := _cuerpo(_nombre(), v, d["anims"][a].get(v, d["anims"][a].values()[0]))
			ancho = maxf(ancho, maxf(medio - c.position.x, c.end.x - medio))
			alto = maxf(alto, float(d["pie"]) - c.position.y)
	var m := 6.0 + 8.0 * z
	var bajo := (float(d["h"]) - float(d["pie"])) * z
	var caja := Rect2(_escena_r.position + Vector2(ancho * z + m, alto * z + m),
		_escena_r.size - Vector2(2.0 * (ancho * z + m), alto * z + bajo + 2.0 * m))
	var recinto := _recinto()
	if recinto.size.x > 0:
		# nunca detrás de la valla de delante: los pies por encima de lo alto de sus postes, así no le tapa nada
		var valla := _valla_delante(recinto)
		if valla > 0.0:
			recinto.size.y = minf(recinto.size.y, valla - 14.0 - recinto.position.y)
		var r2 := Rect2(_a_escenario(recinto.position), recinto.size * z).intersection(caja)
		if r2.size.x > 20.0 and r2.size.y > 8.0:
			return r2
	return caja


func _recinto() -> Rect2:
	## su sitio en la granja (el de la escena: corral de aves, prado, pocilga, estanque…)
	var mundo = get_tree().current_scene
	var esp: Dictionary = Comp.ESPECIE.get(_nombre().split("_")[0], {})
	if mundo == null or not "zonas" in mundo or not mundo.zonas.has(esp.get("zona", "")):
		return Rect2()
	var zona = mundo.zonas[esp["zona"]]
	if zona is Dictionary and zona.has("b"):
		return zona["b"]
	return Rect2()


func _ventana() -> Rect2:
	## el trozo de granja que se ve en el escenario (en píxeles del mundo): su recinto, con sólo la puntita de la valla
	## de delante abajo, y desplazado a lo ancho para no cortar por los lados ninguna puerta ni pieza grande
	var z := float(zoom)
	var tam := (_escena_r.size / z).round()
	var clave := "%s/%d/%s" % [_nombre(), zoom, str(tam)]
	if _ventanas.has(clave):
		return _ventanas[clave]
	var mundo_tam := Vector2(float(E["W"]), float(E["H"]))
	if vista == "todas" and _marco.size.x > 0:
		return _marco
	var recinto := _recinto()
	var ven := Rect2(Vector2(870, 440), tam)
	var fijo: Array = ENCUADRES.get(_zona_de_la_especie(), [])
	if not fijo.is_empty() and int(fijo[2]) == zoom:
		ven = Rect2(Vector2(float(fijo[0]), float(fijo[1])).clamp(Vector2.ZERO, mundo_tam - tam), tam)
		_ventanas[clave] = ven
		return ven
	var casita := _casita_del_estanque()
	if casita.size.x > 0 and _zona_de_la_especie() in ["pato", "orilla", "agua"]:
		# el estanque con su casita: la casita a un lado, el agua y la orilla al otro
		var c2 := casita.get_center() + Vector2(tam.x * 0.22 * (1.0 if casita.get_center().x < float(E["W"]) / 2.0 else -1.0), 10.0)
		ven = Rect2((c2 - tam / 2.0).clamp(Vector2.ZERO, mundo_tam - tam).round(), tam)
		_ventanas[clave] = ven
		return ven
	if recinto.size.x > 0:
		var abajo := recinto.end.y + 30.0
		var valla := _valla_delante(recinto)
		if valla > 0.0:
			abajo = valla + 10.0
		var y0 := clampf(abajo - tam.y, 0.0, mundo_tam.y - tam.y)
		var mejor_x := recinto.get_center().x - tam.x / 2.0
		var coste_min := 1e12
		var x := recinto.position.x - tam.x / 2.0
		while x <= recinto.end.x - tam.x / 2.0:
			var xc := clampf(x, 0.0, mundo_tam.x - tam.x)
			# lo que asoma fuera de su recinto (la hierba de fuera de la valla) también estorba
			var fuera := maxf(recinto.position.x - 18.0 - xc, 0.0) + maxf(xc + tam.x - recinto.end.x - 18.0, 0.0)
			var c := _coste_corte(Rect2(xc, y0, tam.x, tam.y)) + fuera * tam.y * 2.0 + absf(xc + tam.x / 2.0 - recinto.get_center().x) * 0.5
			if c < coste_min:
				coste_min = c
				mejor_x = xc
			x += 4.0
		ven = Rect2(Vector2(mejor_x, y0).round(), tam)
	_ventanas[clave] = ven
	return ven


func _zona_de_la_especie() -> String:
	return String(Comp.ESPECIE.get(_nombre().split("_")[0], {}).get("zona", ""))


func _casita_del_estanque() -> Rect2:
	for sp in E["sprites"]:
		if sp[0] == "patos_1":
			var im: Dictionary = E["imagenes"]["patos_1"]
			return Rect2(float(sp[1]), float(sp[2]), float(im["w"]), float(im["h"]))
	return Rect2()


func _valla_delante(recinto: Rect2) -> float:
	## lo alto de la valla de abajo del recinto (la de delante), o 0 si no hay: la línea de pies que más tramos tiene
	## justo debajo del recinto (los postes de las vallas de los lados quedan fuera)
	var cuenta := {}
	for sp in E["sprites"]:
		var pie := float(sp[3])
		if not String(sp[0]).begins_with("valla_tramo") or pie < recinto.end.y or pie > recinto.end.y + 70.0:
			continue
		if float(sp[1]) < recinto.position.x - 20.0 or float(sp[1]) > recinto.end.x + 20.0:
			continue
		cuenta[pie] = cuenta.get(pie, 0) + 1
	if cuenta.is_empty():
		return 0.0
	var linea: float = cuenta.keys().reduce(func(x, y): return x if cuenta[x] >= cuenta[y] else y)
	var arriba := 0.0
	for sp in E["sprites"]:
		if (String(sp[0]).begins_with("valla_tramo") or String(sp[0]).begins_with("valla_poste")) and absf(float(sp[3]) - linea) <= 2.0:
			arriba = float(sp[2]) if arriba == 0.0 else minf(arriba, float(sp[2]))
	return arriba


func _coste_corte(ven: Rect2) -> float:
	## lo que queda cortado por los lados: puertas (siempre feas a medias) y piezas grandes
	var c := 0.0
	for sp in E["sprites"]:
		var n: String = sp[0]
		if n.begins_with("valla"):
			continue
		var im: Dictionary = E["imagenes"][n]
		var caja := Rect2(float(sp[1]), float(sp[2]), float(im["w"]), float(im["h"]))
		if not caja.intersects(ven):
			continue
		var dentro := caja.intersection(ven)
		var fuera_lado := (caja.size.x - dentro.size.x) * dentro.size.y
		if n.begins_with("puerta"):
			c += 1e6 if dentro.size != caja.size else 0.0   # una puerta, entera o nada
		elif im["h"] >= 30:
			c += fuera_lado * 4.0   # una pieza cortada se ve más que un poco de fuera del recinto
	return c


func _a_escenario(p: Vector2) -> Vector2:
	return _escena_r.position + (p - _ventana().position) * float(zoom)


func _libre(p: Vector2) -> bool:
	## los pies no pisan nada que estorbe (casetas, comederos, troncos) ni se meten detrás de algo alto
	var mundo = get_tree().current_scene
	if mundo == null or not "obst" in mundo:
		return true
	var w := _ventana().position + (p - _escena_r.position) / float(zoom)
	for o in mundo.obst:
		if o.grow(3.0).has_point(w):
			return false
	for o in mundo.detras:
		if o.has_point(w):
			return false
	# ni detrás de nada que la tape: su cuerpo no se mete bajo ninguna pieza que quede por delante de sus pies
	var d := _datos()
	var cuerpo := Rect2(w.x - float(d["w"]) * 0.35, w.y - (float(d["pie"]) - float(d["tope"])), float(d["w"]) * 0.7, float(d["pie"]) - float(d["tope"]))
	for sp in _piezas_delante():
		if float(sp[3]) > w.y and cuerpo.intersects(sp[4]):
			return false
	# ni encima de sus compañeros de recinto (los de la granja grande)
	if "actores" in mundo:
		for a in mundo.actores:
			if a.nombre == _nombre() or not a.visible or a.position.distance_to(w) > 60.0:
				continue
			if cuerpo.grow(-2.0).intersects(a.huella(a.position).grow(-2.0)):
				return false
	return true


func _piezas_delante() -> Array:
	## las piezas de su encuadre que pueden taparla (todo menos la valla de delante, que ya no la alcanza)
	var clave := str(_ventana())
	if _tapan.has(clave):
		return _tapan[clave]
	var lista: Array = []
	var ven := _ventana().grow(40.0)
	for sp in E["sprites"]:
		var n: String = sp[0]
		if n.begins_with("puerta"):
			continue
		var im: Dictionary = E["imagenes"][n]
		var caja := Rect2(float(sp[1]), float(sp[2]), float(im["w"]), float(im["h"]))
		if caja.size.x < 6.0 or caja.size.y < 6.0:
			continue   # recortes de travesaño de pocos píxeles: no tapan a nadie
		caja = caja.grow(-2.0)
		if caja.intersects(ven):
			lista.append([n, sp[1], sp[2], sp[3], caja])
	_tapan[clave] = lista
	return lista


func _dentro(p: Vector2) -> Vector2:
	var m := _margenes()
	return Vector2(clampf(p.x, m.position.x, m.end.x), clampf(p.y, m.position.y, m.end.y))


func _sitio(p: Vector2, v: String) -> float:
	## cuánto puede avanzar desde p en esa dirección sin salir de su recinto ni chocar con nada
	var m := _margenes()
	var hasta: float
	match v:
		"east":
			hasta = m.end.x - p.x
		"west":
			hasta = p.x - m.position.x
		"south":
			hasta = m.end.y - p.y
		_:
			hasta = p.y - m.position.y
	var paso := 2.0
	while paso <= hasta:
		if not _libre(p + AVANCE[v] * paso):
			return maxf(paso - 6.0, 0.0)
		paso += 2.0
	return maxf(hasta, 0.0)


func _ms_bucle(a: String, v: String) -> float:
	var d := _datos()
	var pista: Dictionary = d["anims"][a].get(v, d["anims"][a].values()[0])
	var ms := 0.0
	for x in pista["ms"]:
		ms += float(x)
	return ms


func _planifica(st: Dictionary) -> void:
	## la vida suelta: gira sólo estando parado (en el reposo antes de echar a andar), elige hacia dónde hay sitio, y
	## anda sólo las vueltas que caben: nunca se sale ni se para de golpe contra el borde
	var a: String = st["anim"]
	var n_sec := secuencia.size()
	var siguiente: String = secuencia[(st["ip"] + 1) % n_sec][0]
	var anterior: String = secuencia[(st["ip"] - 1 + n_sec) % n_sec][0]
	var base_sig: String = siguiente.trim_suffix("_start")
	var gira := false
	var base := ""
	var quieta: bool = not base_sig in MUEVE and siguiente != "idle" and not siguiente.trim_suffix("_end") in MUEVE
	if a == "idle" and quieta and not st.get("acecha", false) and not String(secuencia[(st["ip"] + 1) % n_sec][3]) == "tendido":
		if siguiente.begins_with("sleep"):
			# de lado, y siempre hacia el mismo (el de más sitio): cada noche igual, en su sitio
			st["dir"] = "east" if _sitio(st["pos"], "east") >= _sitio(st["pos"], "west") else "west"
		else:
			# la siguiente vista de la rueda: de cara, de lado, de espaldas, del otro lado…
			st["rueda"] = (int(st.get("rueda", -1)) + 1) % RUEDA.size()
			st["dir"] = RUEDA[st["rueda"]]
	if a == "idle" and base_sig in MUEVE:
		gira = true   # parado antes de echar a andar: aquí es donde se da la vuelta
		base = base_sig
	elif a.ends_with("_start") and a.trim_suffix("_start") in MUEVE and anterior != "idle":
		gira = true
		base = a.trim_suffix("_start")
	elif a in MUEVE and not anterior.begins_with(a) and anterior != "idle":
		gira = true
		base = a
	if gira and _escena_r.size.x > 0:
		var k: int = st["ip"]
		while k < n_sec and secuencia[k][0] != base:
			k += 1
		var vueltas: int = secuencia[k][1] if k < n_sec else 1
		var quiere: float = _v_real(base) * float(zoom) * _ms_bucle(base, st["dir"]) * vueltas / 1000.0
		# hacia donde quepa al menos una vuelta (luego anda sólo las que caben): así sale por las cuatro direcciones
		var una_v: float = quiere / maxf(float(vueltas), 1.0)
		# sólo de lado: andando hacia el norte, de espaldas, parece que ande en el sitio (usuario, 24-10); de cara o
		# de espaldas, quieto o haciendo sus cosas
		var opciones: Array = ANDA.filter(func(v): return _sitio(st["pos"], v) >= una_v)
		if opciones.is_empty():
			opciones = [ANDA.reduce(func(x, y): return x if _sitio(st["pos"], x) >= _sitio(st["pos"], y) else y)]
		if st.has("huye") and base == "run":
			opciones = [st["huye"]] if _sitio(st["pos"], st["huye"]) >= una_v else opciones
			st.erase("huye")
		# cambia de eje siempre que puede (si iba de lado, ahora sube o baja): se le ve en las cuatro direcciones
		var cruzadas: Array = opciones.filter(func(v): return (AVANCE[v].x == 0.0) != (AVANCE[st["dir"]].x == 0.0))
		if not cruzadas.is_empty() and opciones.size() > 1:
			opciones = cruzadas
		st["dir"] = opciones[randi() % opciones.size()]
	if a in MUEVE and _escena_r.size.x > 0:
		# las vueltas que caben hacia donde mira
		var una: float = _v_real(a) * float(zoom) * _ms_bucle(a, st["dir"]) / 1000.0
		var caben := int(floorf(_sitio(st["pos"], st["dir"]) / maxf(una, 1.0)))
		st["n"] = clampi(caben, 1, secuencia[st["ip"]][1])


func _en_bucle(a: String) -> bool:
	## las piezas que se repiten (reposo, andar, comer…); los arranques, las paradas y las acciones de una vez no
	return not (a.ends_with("_start") or a.ends_with("_end") or a in ["lay_egg", "hurt", "death", "attack"])


func _siguiente(st: Dictionary, v: String) -> void:
	## todas las vistas han acabado la pieza: entran juntas en la siguiente, cada una con sus fotogramas
	st["espera"] = false
	st["n"] = -1
	st["vuelta"] = 0
	st["paso_i"] = 0
	st["t"] = 0.0
	st["ip"] = st["saltar"] if st["saltar"] >= 0 else (st["ip"] + 1) % secuencia.size()
	st["saltar"] = -1
	var antes: String = st["anim"]
	st["anim"] = secuencia[st["ip"]][0]
	if antes in ["walk", "run", "swim"] and st["anim"] != antes:
		st["desplazado"] = 1.0   # el paseo acaba entero, con el animal otra vez en el centro
	_prepara_paseo(st, v)
	if st.has("pos"):
		_suceso(st, String(secuencia[st["ip"]][3]) if secuencia[st["ip"]].size() > 3 else "")
		_planifica(st)
		v = st["dir"]
	st["fotograma"] = _fotogramas_pieza(st, _pista(st, v))[0]
	if st.has("pos") or v == _principal():
		anim = st["anim"]
		_suena_pieza()
		_marca_accion()


func _unhandled_key_input(ev: InputEvent) -> void:
	if not visible or not ev.pressed:
		return
	var d := _datos()
	var lista: Array = ui.acciones_de(d["anims"], d["zip"]).map(func(a): return a[0])
	if vista == "todas" and ev.keycode in [KEY_LEFT, KEY_RIGHT, KEY_UP, KEY_DOWN, KEY_W, KEY_A, KEY_S, KEY_D]:
		get_viewport().set_input_as_handled()   # lo lleva _mando
		return
	match ev.keycode:
		KEY_LEFT, KEY_RIGHT:
			var i := VISTAS.map(func(v): return v[1]).find(vista)
			vista = VISTAS[(i + (1 if ev.keycode == KEY_RIGHT else -1) + VISTAS.size()) % VISTAS.size()][1]
			_refresca()
		KEY_UP, KEY_DOWN:
			var j := lista.find(accion)
			_salta_a(lista[(j + (1 if ev.keycode == KEY_DOWN else -1) + lista.size()) % lista.size()])
		KEY_PAGEUP, KEY_PAGEDOWN:
			_cambia_capa(1 if ev.keycode == KEY_PAGEDOWN else -1)
		KEY_ESCAPE, KEY_V:
			cerrar.emit()
		_:
			return
	get_viewport().set_input_as_handled()


func _process(delta: float) -> void:
	if not visible:
		return
	if secuencia.is_empty() or est.is_empty():
		_arma_secuencia()
	if vista == "todas":
		var st: Dictionary = est["vida"]
		_mando(st, delta)
		_avanza(st, st["dir"], delta)
		_mueve_raton(delta)
		var marca: String = String(secuencia[st["ip"]][3]) if secuencia[st["ip"]].size() > 3 else ""
		if st["espera"] and marca == "tendido":
			st["tendido"] = float(st.get("tendido", 0.0)) + delta
			if st["tendido"] < 1.5:
				escenario.queue_redraw()
				return   # tendido un momento (sin pasar aún a lo siguiente)
			st["tendido"] = 0.0
		if st["espera"] and st.get("manual", false) and st["saltar"] < 0:
			_mando_fin_pieza(st)
		elif st["espera"]:
			st["manual"] = false
			_siguiente(st, st["dir"])
		escenario.queue_redraw()
		return
	for v in CUATRO:
		_avanza(est[v], v, delta)
	# cada fase empieza a la vez en las cuatro direcciones (la lista y las vistas dicen siempre lo mismo)
	if CUATRO.all(func(v): return est[v]["espera"]):
		for v in CUATRO:
			_siguiente(est[v], v)
	escenario.queue_redraw()


func _dibuja() -> void:
	var tam := escenario.size
	if vista == "todas":
		_dibuja_vida(Rect2(Vector2.ZERO, tam))
		return
	var vistas: Array = [vista]
	# todos los recuadros del mismo ancho; lo que sobra se reparte a los lados
	var ancho := floorf(tam.x / vistas.size())
	var x0 := floorf((tam.x - ancho * vistas.size()) / 2.0)
	escenario.draw_rect(Rect2(Vector2.ZERO, tam), UI.TINTA)
	for i in vistas.size():
		_dibuja_vista(Rect2(x0 + i * ancho, 0, ancho, tam.y), vistas[i])
		if i > 0:
			escenario.draw_rect(Rect2(x0 + i * ancho, 0, 1, tam.y), UI.TINTA)   # filete de tinta entre vistas


func _cuerpo(nombre: String, v: String, pista: Dictionary) -> Rect2:
	## lo opaco de todos los fotogramas de esta pieza en esta vista, en píxeles del fotograma
	var clave := "%s/%s/%s" % [nombre, v, str(pista["xy"][0])]
	if _cuerpos.has(clave):
		return _cuerpos[clave]
	if not _imagenes.has(nombre):
		_imagenes[nombre] = texturas[nombre].get_image()
	var im: Image = _imagenes[nombre]
	var d := _datos()
	var caja := Rect2()
	for xy in pista["xy"]:
		var u := im.get_region(Rect2i(int(xy[0]), int(xy[1]), int(d["w"]), int(d["h"]))).get_used_rect()
		if u.size.x > 0:
			caja = Rect2(u) if caja.size.x == 0 else caja.merge(Rect2(u))
	if caja.size.x == 0:
		caja = Rect2(0, 0, float(d["w"]), float(d["h"]))
	_cuerpos[clave] = caja
	return caja


func _marco_del_recinto(tam_pantalla: Vector2) -> Rect2:
	## su recinto entero en el mundo: la casa del fondo entera arriba, la puntita de la valla de delante abajo; si no hay
	## recinto (patos, ratones), su sitio con aire alrededor. Nunca más pequeño que lo que se ve
	var mundo_tam := Vector2(float(E["W"]), float(E["H"]))
	var rec := _recinto()
	var casita := _casita_del_estanque()
	var m := Rect2()
	if casita.size.x > 0 and _zona_de_la_especie() in ["pato", "orilla", "agua"]:
		var el: Array = E["estanque"]["elipse"]
		m = Rect2(float(el[0]) - 24, float(el[1]) - 24, float(el[2]) - float(el[0]) + 48, float(el[3]) - float(el[1]) + 40)
	elif rec.size.x > 0:
		var abajo := rec.end.y + 24.0
		var valla := _valla_delante(rec)
		if valla > 0.0:
			abajo = valla + 10.0
		var arriba := rec.position.y - 20.0
		for sp in E["sprites"]:   # la casa o lo alto del fondo, entero
			var n: String = sp[0]
			if n.begins_with("valla") or n.begins_with("puerta"):
				continue
			var pie := float(sp[3])
			if pie > rec.position.y - 4.0 and pie < rec.end.y and float(sp[1]) < rec.end.x and float(sp[1]) + float(E["imagenes"][n]["w"]) > rec.position.x:
				arriba = minf(arriba, float(sp[2]) - 6.0)
		m = Rect2(rec.position.x - 20.0, arriba, rec.size.x + 40.0, abajo - arriba)
	else:
		m = Rect2(Vector2(870, 440), tam_pantalla)
	if m.size.x < tam_pantalla.x:
		m = m.grow_individual((tam_pantalla.x - m.size.x) / 2.0, 0, (tam_pantalla.x - m.size.x) / 2.0, 0)
	if m.size.y < tam_pantalla.y:
		m = m.grow_individual(0, tam_pantalla.y - m.size.y, 0, 0)
	m.position = m.position.clamp(Vector2.ZERO, mundo_tam - m.size)
	return Rect2(m.position.round(), m.size.round())


func _dibuja_vida(r_pantalla: Rect2) -> void:
	## el animal suelto en su sitio de la granja, a 2x: su recinto entero (con sus compañeros) y una cámara que lo sigue
	var z := float(zoom)
	_pantalla = r_pantalla
	_marco = _marco_del_recinto(r_pantalla.size / z)
	var r := Rect2(r_pantalla.position, _marco.size * z)
	_escena_r = r
	var ven := _ventana()
	var st0: Dictionary = est["vida"]
	if st0["pos"].x >= 0.0:
		var quiere: Vector2 = (st0["pos"] - r.position - r_pantalla.size / 2.0).clamp(Vector2.ZERO, r.size - r_pantalla.size)
		_cam = quiere if _cam.x < 0.0 else _cam.lerp(quiere, 0.12)
	else:
		_cam = Vector2.ZERO
	var off := _cam.round()
	escenario.draw_texture_rect_region(suelo, r_pantalla, Rect2(ven.position + off / z, r_pantalla.size / z))
	var d := _datos()
	var nombre := _nombre()
	if not texturas.has(nombre):
		texturas[nombre] = load("res://datos/" + d["archivo"])
	var st: Dictionary = est["vida"]
	if st["pos"].x < 0.0:
		st["pos"] = _arranque()
		st["casa_pos"] = st["pos"]   # su sitio: de ahí sale por la mañana y ahí vuelve a dormir
	var cosas: Array = []   # [línea de los pies en el mundo, textura, fuente, destino]
	for sp in E["sprites"]:
		var n: String = sp[0]
		var im: Dictionary = E["imagenes"][n]
		var tex: Texture2D
		var org := Vector2(float(sp[1]), float(sp[2]))
		var tam := Vector2(float(im["w"]), float(im["h"]))
		var fuente := Rect2(Vector2.ZERO, tam)
		if n == "puerta_abierta" and E.has("puertas"):
			var pe: Dictionary = E["puertas"]
			org -= Vector2(pe["puerta_abierta"]["recorte"][0], pe["puerta_abierta"]["recorte"][1])
			tex = _tex("puerta_cerrada", pe["puerta_cerrada"]["archivo"])
			tam = Vector2(float(pe["puerta_cerrada"]["w"]), float(pe["puerta_cerrada"]["h"]))
			fuente = Rect2(Vector2.ZERO, tam)
		else:
			tex = _tex(n, im["archivo"])
			if im.has("cuadros"):
				tam.x = float(tex.get_width()) / float(im["cuadros"])
				fuente = Rect2(Vector2.ZERO, Vector2(tam.x, float(tex.get_height())))
				tam.y = fuente.size.y
				org += Vector2(float(im["dx"]), float(im["dy"]))
		if not Rect2(org, tam).intersects(ven):
			continue
		cosas.append([float(sp[3]), tex, fuente, Rect2(r.position + (org - ven.position) * z - off, tam * z)])
	var pista := _pista(st, st["dir"])
	var xy: Array = pista["xy"][mini(st["fotograma"], pista["xy"].size() - 1)]
	var pie_mundo: float = ven.position.y + (st["pos"].y - r.position.y) / z
	var alto_fuente := float(d["h"])
	var mundo_pie := Vector2(ven.position.x + (st["pos"].x - r.position.x) / z, pie_mundo - 2.0)
	var escena = get_tree().current_scene
	if escena and escena.has_method("agua") and escena.agua(mundo_pie):
		var a2: Dictionary = d["anims"]
		if a2.has("swim"):
			# en el agua nada (como en la granja): su ciclo de nado, mire hacia donde mire de lado
			var nado: Dictionary = a2["swim"].get(st["dir"] if st["dir"] in ["east", "west"] else "east", a2["swim"].values()[0])
			var ms_n := 0.0
			for m in nado["ms"]:
				ms_n += float(m)
			var u := fposmod(Time.get_ticks_msec(), ms_n)
			var k := 0
			while k < nado["ms"].size() - 1 and u >= float(nado["ms"][k]):
				u -= float(nado["ms"][k])
				k += 1
			xy = nado["xy"][k]
		else:
			# sin nado: la línea de flotación esconde las patas (como actor.dibuja)
			alto_fuente = float(d["pie"]) - floorf((float(d["pie"]) - float(d["tope"])) * 0.3)
	cosas.append([pie_mundo, texturas[nombre], Rect2(float(xy[0]), float(xy[1]), float(d["w"]), alto_fuente),
		Rect2((st["pos"] - Vector2(float(d["w"]) / 2.0, float(d["pie"])) * z).round() - off, Vector2(float(d["w"]), alto_fuente) * z)])
	# sus compañeros de recinto, tal cual viven en la granja grande (el visor es un zoom de ella)
	var granja = get_tree().current_scene
	if granja and "actores" in granja:
		for a in granja.actores:
			if a.nombre == nombre or not a.visible or not ven.has_point(a.position):
				continue
			var reg: Rect2 = a.spr.region_rect
			var org_a: Vector2 = a.position + a.spr.offset
			cosas.append([a.position.y, a.spr.texture, reg, Rect2(r.position + (org_a - ven.position) * z - off, reg.size * z)])
	if not _raton.is_empty():
		var rd: Dictionary = E["animales"]["Raton"]
		var rp: Dictionary = rd["anims"][_raton["anim"]][_raton["dir"]]
		var rxy: Array = rp["xy"][_raton["i"] % rp["xy"].size()]
		var pos_r := Vector2(_raton["x"], _raton["y"])
		cosas.append([ven.position.y + (pos_r.y - r.position.y) / z, texturas["Raton"],
			Rect2(float(rxy[0]), float(rxy[1]), float(rd["w"]), float(rd["h"])),
			Rect2((pos_r - Vector2(float(rd["w"]) / 2.0, float(rd["pie"])) * z).round() - off, Vector2(float(rd["w"]), float(rd["h"])) * z)])
	cosas.sort_custom(func(x, y): return x[0] < y[0])
	for c in cosas:
		_pinta(c[1], c[2], c[3], r_pantalla)


func _tex(clave: String, archivo: String) -> Texture2D:
	if not texturas.has("pieza:" + clave):
		texturas["pieza:" + clave] = load("res://datos/" + archivo)
	return texturas["pieza:" + clave]


func _pinta(tex: Texture2D, fuente: Rect2, dst: Rect2, r: Rect2) -> void:
	## dibuja recortado al escenario, sin estirar: lo que cae fuera no se ve
	var vis := dst.intersection(r)
	if vis.size.x <= 0 or vis.size.y <= 0:
		return
	var k := fuente.size / dst.size
	escenario.draw_texture_rect_region(tex, vis, Rect2(fuente.position + (vis.position - dst.position) * k, vis.size * k))


func _arranque() -> Vector2:
	## dónde empieza: un sitio libre de su recinto, lo más en medio posible (desde ahí le cabe ir a cualquier lado)
	var m := _margenes()
	var mejor := m.get_center()
	var nota := -1e9
	for iy in 7:
		for ix in 9:
			var p := m.position + Vector2(m.size.x * (ix + 0.5) / 9.0, m.size.y * (iy + 0.5) / 7.0)
			if not _libre(p):
				continue
			var n: float = -absf(p.x - m.get_center().x) * 0.5 - absf(p.y - m.get_center().y)
			if n > nota:
				nota = n
				mejor = p
	return mejor.round()


func _dibuja_vista(r: Rect2, v: String) -> void:
	var z := float(zoom)   # en píxeles de interfaz: siempre un múltiplo entero de los de pantalla
	# el suelo de la granja, quieto: es el animal el que se mueve (el motor lo desplaza a su velocidad)
	escenario.draw_texture_rect_region(suelo, r, Rect2(SUELO_LIMPIO, r.size / z))
	var d := _datos()
	var nombre := _nombre()
	if not texturas.has(nombre):
		texturas[nombre] = load("res://datos/" + d["archivo"])
	var st: Dictionary = est[v]
	var pista := _pista(st, v)
	var xy: Array = pista["xy"][mini(st["fotograma"], pista["xy"].size() - 1)]
	var w := float(d["w"])
	var h := float(d["h"])
	var pie := r.position + Vector2(r.size.x / 2.0, r.size.y * 0.5 + (float(d["pie"]) - float(d["tope"])) * z / 2.0)
	# andando, el animal recorre su recuadro y vuelve a entrar por el otro lado; el recorrido se mide con su cuerpo
	# (lo opaco de todos sus fotogramas en esta vista): asoma por un lado justo cuando acaba de salir del todo por el
	# otro, así nunca se ve partido en dos ni el recuadro se queda vacío
	var por_x: bool = AVANCE[v].x != 0.0
	# el cuerpo del bucle (no el de su arranque o su parada): el mismo recorrido de principio a fin del paseo
	var bucle: String = st["anim"].trim_suffix("_start").trim_suffix("_end")
	var cuerpo := _cuerpo(nombre, v, _datos()["anims"][bucle].get(v, pista) if _datos()["anims"].has(bucle) else pista)
	var mide: float = (cuerpo.size.x if por_x else cuerpo.size.y) * z
	var hueco: float = r.size.x if por_x else r.size.y
	var largo: float = hueco + mide
	var vueltas_r: float = maxf(1.0, roundf(st["bloque_px"] * z / largo)) if st["bloque_ms"] > 0.0 else 0.0
	var avance: float = floorf(st["desplazado"] * vueltas_r * largo)
	if avance > 0.0:
		var esquina := pie - Vector2(w / 2.0, float(d["pie"])) * z + cuerpo.position * z   # donde empieza el cuerpo
		var e0: float = (esquina.x - r.position.x) if por_x else (esquina.y - r.position.y)
		var e1: float = fposmod(e0 + (AVANCE[v].x if por_x else AVANCE[v].y) * avance + mide, largo) - mide
		if por_x:
			pie.x += e1 - e0
		else:
			pie.y += e1 - e0
	var dst := Rect2((pie - Vector2(w / 2.0, float(d["pie"])) * z).round(), Vector2(w, h) * z)
	var visible_r := dst.intersection(r)   # recortado a su recuadro (en «todas», cada vista tiene el suyo)
	if visible_r.size.x > 0 and visible_r.size.y > 0:
		var fuente := Rect2(Vector2(xy[0], xy[1]) + (visible_r.position - dst.position) / z, visible_r.size / z)
		escenario.draw_texture_rect_region(texturas[nombre], visible_r, fuente)

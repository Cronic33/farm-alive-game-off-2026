extends CanvasLayer
## Interfaz de la escena viva, discreta y de la marca (docs/MARCA.md): la letra de 5 px dibujada a mano, el marco
## fino de latón biselado de las tarjetas, latón lleno sólo para lo importante (la compra y el nombre del animal) y
## violeta de fondo. El motor escala todo por un entero (proyecto: base 480 x 270, escalado entero), así que aquí se
## trabaja en píxeles de esa base; «escala» es ese entero, para lo que va en píxeles de pantalla (el puntero).
##   - arriba: el rótulo con su margen libre y, a la derecha, una sola placa con el visor, día/noche y la compra;
##   - abajo: una sola placa con las familias (y encima, la ayuda, que se apaga sola cuando ya se ha usado);
##   - al elegir un animal, su ficha ocupa la placa de abajo en lugar de las familias (nada más encima del arte):
##     su nombre, sexo/edad y capa, y todas sus animaciones, que se prueban en él.

const TINTA := Color("0e0805")
const LATON := Color("f2b630")
const LATON_HONDO := Color("7a3f1c")
const MARCO_AIRE := 3.0     # entre el cuerpo y las esquinas, en píxeles de la base
const RATON_HUECO := 5.0    # entre el nombre y el ratoncito
const PISTA_ESCALA := 1.0   # el nombre al pasar el ratón, al doble de la letra de 5 px (usuario 26-10: se veía pequeño)
const LATON_MEDIO := Color("d98a1f")
const BRILLO_LETRA := Color("ffe27a")
const PERGAMINO := Color("fff1c9")
const VIOLETA := Color("1c1228")
const VIOLETA_2 := Color("2a1d3a")
const VIOLETA_4 := Color("4a3862")
const MARGEN := 8   # el mismo margen al borde para todas las placas
const AIRE := [7, 5, 7, 5]   # el mismo aire dentro de todas (3 px de marco + el aire)
# GET THE PACK lleva a comprar (usuario 25-10): el diálogo de compra de la página de itch.io. La página vende por archivos
# con precio mínimo (sin recompensas), así que no hay reward_id con el que dejar el Complete ya elegido
const URL_PACK := "https://mutoscope.itch.io/top-down-farm-animals/purchase"
# un mismo orden y unos mismos nombres en toda la demo (la tira, el visor)
const FAMILIAS := [["CHICKENS", "Gallina"], ["TURKEYS", "Pava"], ["DUCKS", "PatoDomestico"], ["GEESE", "Ganso"],
	["SHEEP", "Oveja"], ["GOATS", "Cabra"], ["PIGS", "Cerdo"], ["COWS", "Vaca"], ["HORSES", "Semental"],
	["DONKEYS", "Burro"], ["RABBITS", "Conejo"], ["MICE", "Raton"]]
# acciones: cada una con sus piezas en el orden del pack (arranque, bucle, parada)
const ACCIONES := [["IDLE", ["idle"]], ["WALK", ["walk_start", "walk", "walk_end"]], ["RUN", ["run_start", "run", "run_end"]],
	["EAT", ["eat_start", "eat", "eat_end"]], ["SLEEP", ["sleep_start", "sleep", "sleep_end"]], ["FLAP", ["aleteo"]],
	["LAY EGG", ["lay_egg"]], ["CROW", ["crow"]], ["PEEP", ["peep"]], ["BRAY", ["bray"]], ["ATTACK", ["attack"]],
	["TAKE OFF", ["despegue"]], ["FLY", ["fly"]], ["LAND", ["aterrizaje"]], ["HURT", ["hurt"]], ["DEATH", ["death"]]]

signal familia_elegida(nombre: String)
signal accion_elegida(anim: String)
signal cerrar_ficha
signal noche_cambiada(noche: bool)
signal invierno_cambiado(invierno: bool)
signal sonido_cambiado(on: bool)
signal ver_en_visor(nombre: String)

var E: Dictionary
var escala := 2
var fuente: FontFile
var raiz: Control
var banda: TextureRect
var capa_rotulo: CanvasLayer
var rotulo: TextureRect
var placa_rotulo: PanelContainer
var arriba: PanelContainer
var b_noche: Button
var b_invierno: Button
var b_sonido: Button
var abajo: PanelContainer
var ayuda: HBoxContainer
var placa_ayuda: PanelContainer
var pila: Control
var fila_familias: HBoxContainer
var botones := {}
var ficha: PanelContainer
var ficha_nombre: Label
var ficha_sub: Label
var ficha_roles: HBoxContainer
var flecha_menos: Button
var pistas_ficha: HBoxContainer
var pista_animal: Control
var marcos: Control          # las esquinas de latón del elegido y del que está bajo el ratón
var _marco_elegido := Rect2()
var _marco_sobre := Rect2()
var _pista_texto := ""
var _pista_raton := true     # el ratoncito al lado del nombre, hasta el primer clic en un animal
var _pista_desde := 0.0      # cuándo empezó el ratón a estar encima (aparece a los 150 ms)
var _pista_de := ""
var _pistas := {}        # tecla («CLICK», «WASD|DRAG»…) -> su pieza de ayuda
var _usadas := {}        # las que ya se han usado (en memoria, por sesión)
var flecha_mas: Button
var ficha_lista: HBoxContainer
var actor: Actor = null
var _filas := {}
var visor
var _ayuda_apagada := false
var _ayuda_contaba := true   # si la fila de ayuda contaba en zona_libre() la última vez que se colocó


func _ready() -> void:
	fuente = load("res://ui/fuente5.fnt")
	raiz = Control.new()
	raiz.theme = _tema()
	raiz.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(raiz)
	# franja de arriba: un velo violeta que se desvanece, para que el rótulo y la placa no floten sobre cualquier cosa
	banda = TextureRect.new()
	banda.texture = load("res://ui/velo.png")   # banda de arriba, tramada, que se apaga hacia abajo
	banda.stretch_mode = TextureRect.STRETCH_TILE
	banda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(banda)
	var g := GradientTexture2D.new()
	g.gradient = Gradient.new()
	g.gradient.interpolation_mode = Gradient.GRADIENT_INTERPOLATE_CONSTANT
	g.gradient.set_color(0, Color(VIOLETA, 0.62))
	g.gradient.add_point(0.6, Color(VIOLETA, 0.4))
	g.gradient.add_point(0.82, Color(VIOLETA, 0.2))
	g.gradient.set_color(g.gradient.get_point_count() - 1, Color(VIOLETA, 0.0))
	g.fill_from = Vector2(0, 0)
	g.fill_to = Vector2(0, 1)
	g.width = 4
	g.height = 64

	# el rótulo va en su propia capa sin escalar: se usa el PNG de su escala, nunca uno ampliado
	capa_rotulo = CanvasLayer.new()
	capa_rotulo.layer = layer + 1
	add_child(capa_rotulo)
	rotulo = TextureRect.new()
	rotulo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	capa_rotulo.add_child(rotulo)
	placa_rotulo = PanelContainer.new()   # ya sin uso visible: el rótulo va sobre el velo, con su margen libre
	placa_rotulo.visible = false
	raiz.add_child(placa_rotulo)
	_arriba()
	_abajo()
	_ficha()
	get_viewport().size_changed.connect(_ajusta)
	_ajusta()
	get_tree().create_timer(8.0).timeout.connect(apaga_ayuda)


# ------------------------------------------------------------------------------------------------------ tema
func _pista(fila: HBoxContainer, par: Array) -> void:
	## una tecla de ayuda suelta, sin placa: la tecla con su canto y el verbo con un filo de tinta (se lee sobre hierba)
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 3)
	caja.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pon_teclas(caja, [par])
	for c in caja.find_children("*", "Label", true, false):
		_contorno(c)
	fila.add_child(caja)
	_pistas[par[0]] = caja


func _contorno(l: Label) -> void:
	l.add_theme_color_override("font_shadow_color", TINTA)
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 1)
	l.add_theme_constant_override("shadow_outline_size", 1)


func usa(teclas: Array) -> void:
	## se ha usado ese gesto: su pista se retira (fundido corto)
	for t in teclas:
		if _pistas.has(t) and not _usadas.has(t):
			_usadas[t] = true
			var p: Control = _pistas[t]
			var tw := create_tween()
			tw.tween_property(p, "modulate:a", 0.0, 0.4)
			tw.tween_callback(func(): p.visible = false; _coloca_pistas())


func muestra_ayuda() -> void:
	## «?»: vuelven todas
	_usadas.clear()
	for t in _pistas:
		_pistas[t].visible = true
		_pistas[t].modulate.a = 1.0
	_coloca_pistas()


func _coloca_pistas() -> void:
	var u := raiz.size
	placa_ayuda.visible = abajo.visible
	placa_ayuda.reset_size()
	placa_ayuda.position = Vector2(int((u.x - placa_ayuda.size.x) / 2), abajo.position.y - placa_ayuda.size.y - 2)
	pistas_ficha.visible = ficha.visible
	pistas_ficha.reset_size()
	pistas_ficha.position = Vector2(int((u.x - pistas_ficha.size.x) / 2), ficha.position.y - pistas_ficha.size.y - 2)
	# lo que deja libre la interfaz ha podido cambiar (se ha ido la última tecla o han vuelto todas): la granja se reencaja
	var ayuda_ahora := _ayuda_visible()
	if ayuda_ahora != _ayuda_contaba:
		_ayuda_contaba = ayuda_ahora
		if get_parent() != null and get_parent().has_method("_ajusta_zoom") and get_parent().cam != null:
			get_parent()._ajusta_zoom(true)


func pista_sobre(texto: String, r: Rect2, otros: Array = []) -> void:
	## el nombre del animal bajo el ratón (r: lo que ocupa, en píxeles de la base). Encima de sus esquinas, centrado en
	## ellas; si no cabe bajo la placa de arriba, debajo de las esquinas de abajo; si tampoco, a su derecha. Nunca encima
	## del animal ni de los de al lado (otros: sus cajas en pantalla). Aparece a los 150 ms y se va al momento.
	if texto == "":
		pista_animal.visible = false
		_pista_de = ""
		return
	var ahora := Time.get_ticks_msec() / 1000.0
	if texto != _pista_de:
		_pista_de = texto
		_pista_desde = ahora
	if ahora - _pista_desde < 0.15:
		pista_animal.visible = false
		return
	_pista_texto = texto
	var f: Font = raiz.get_theme_font("font", "Label")
	var ancho_texto: float = f.get_string_size(texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x
	var ancho: float = ancho_texto + (RATON_HUECO + 6.0 if _pista_raton else 0.0)
	pista_animal.size = Vector2(ancho + 2, 10) * PISTA_ESCALA
	var e := r.grow(MARCO_AIRE + 1)   # por fuera de las esquinas
	var tope := arriba.position.y + arriba.size.y + 2
	var suelo := (abajo.position.y if abajo.visible else ficha.position.y) - 2
	var t := pista_animal.size
	var cx := e.get_center().x - (ancho_texto + 2) * PISTA_ESCALA / 2.0
	var abajo_y := e.end.y + 2
	# por orden: arriba, abajo, abajo corrido hacia un lado, a la derecha, a la izquierda; la primera que cabe en la
	# pantalla y no pisa a otro animal; si ninguna, abajo
	var probar := [Vector2(cx, e.position.y - 2 - t.y), Vector2(cx, abajo_y)]
	for dx in [6.0, -6.0, 12.0, -12.0]:
		probar.append(Vector2(cx + dx, abajo_y))
	probar.append(Vector2(e.end.x + 3, e.get_center().y - t.y / 2.0))
	probar.append(Vector2(e.position.x - 3 - t.x, e.get_center().y - t.y / 2.0))
	var p: Vector2 = probar[1]
	var hallada := false
	for q in probar:
		var caja_r := Rect2(q, t)
		if q.y < tope or q.y + t.y > suelo or q.x < MARGEN or q.x + t.x > raiz.size.x - MARGEN:
			continue
		var pisa := false
		for o in otros:
			if caja_r.grow(1).intersects(o):
				pisa = true
				break
		if not pisa:
			p = q
			hallada = true
			break
	if not hallada:
		p.x = clampf(p.x, MARGEN, raiz.size.x - MARGEN - t.x)
		p.y = clampf(p.y, tope, suelo - t.y)
	pista_animal.position = p.round()
	pista_animal.visible = true
	pista_animal.queue_redraw()


func _dibuja_pista() -> void:
	var f: Font = raiz.get_theme_font("font", "Label")
	pista_animal.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE * PISTA_ESCALA)
	var base := Vector2(1, 7)
	# filo de tinta a los ocho vecinos (sólido, sin alfa: aguanta sobre tierra y pelaje marrón) y la letra en latón
	for d in [Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1), Vector2(0, 1),
			Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		pista_animal.draw_string(f, base + d, _pista_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, TINTA)
	pista_animal.draw_string(f, base, _pista_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 5, LATON)
	if _pista_raton:
		# un ratón de 6 x 8: contorno de tinta, canal entre los botones, el izquierdo en latón, el resto pergamino
		var x: float = f.get_string_size(_pista_texto, HORIZONTAL_ALIGNMENT_LEFT, -1, 5).x + RATON_HUECO
		var dibujo := [".KKKK.", "KLLKPK", "KLLKPK", "KKKKKK", "KPPPPK", "KPPPPK", "KPPPPK", ".KKKK."]
		var col := {"K": TINTA, "L": LATON, "P": PERGAMINO}
		for fy in dibujo.size():
			for fx in 6:
				var ch: String = dibujo[fy][fx]
				if ch != ".":
					pista_animal.draw_rect(Rect2(x + fx, fy, 1, 1), col[ch])


func pon_marcos(elegido_r: Rect2, sobre_r: Rect2, pulso: float) -> void:
	## las esquinas de latón (en píxeles de la base): el elegido, brazos largos con su sombra de latón hondo y un pulso
	## lento; bajo el ratón, más cortas, sin sombra y quietas
	_marco_elegido = elegido_r.grow(MARCO_AIRE + pulso) if elegido_r.size.x > 0.0 else Rect2()
	_marco_sobre = sobre_r.grow(MARCO_AIRE) if sobre_r.size.x > 0.0 else Rect2()
	marcos.queue_redraw()


func _dibuja_marcos() -> void:
	for par in [[_marco_elegido, true], [_marco_sobre, false]]:
		var r: Rect2 = par[0]
		if r.size.x == 0.0:
			continue
		var grueso := 2.0
		var k := 7.0 if par[1] else 5.0
		for esq in [[r.position, Vector2(1, 1)], [Vector2(r.end.x, r.position.y), Vector2(-1, 1)],
				[Vector2(r.position.x, r.end.y), Vector2(1, -1)], [r.end, Vector2(-1, -1)]]:
			var o: Vector2 = esq[0]
			var sg: Vector2 = esq[1]
			var brazos := [Rect2(o + Vector2(minf(0, sg.x * k), minf(0, sg.y * grueso)), Vector2(k, grueso)),
				Rect2(o + Vector2(minf(0, sg.x * grueso), minf(0, sg.y * k)), Vector2(grueso, k))]
			for b in brazos:
				marcos.draw_rect(b.grow(1), TINTA)   # contorno de tinta, como los sprites
			for b in brazos:
				marcos.draw_rect(b, LATON)
			if par[1]:
				# la sombra de latón hondo por el lado de dentro de cada brazo
				marcos.draw_rect(Rect2(brazos[0].position + Vector2(0, (grueso - 1) if sg.y > 0 else 0), Vector2(k, 1)), LATON_HONDO)
				marcos.draw_rect(Rect2(brazos[1].position + Vector2((grueso - 1) if sg.x > 0 else 0, 0), Vector2(1, k)), LATON_HONDO)


func ya_ha_elegido() -> void:
	_pista_raton = false


func pon_teclas(fila: HBoxContainer, pares: Array) -> void:
	## «TECLA verbo»: cada tecla en su pieza (canto oscuro de 2 px abajo, filete claro arriba), el verbo apagado
	for i in pares.size():
		var teclas: PackedStringArray = String(pares[i][0]).split("|")
		for j in teclas.size():
			if j > 0:
				var o := Label.new()
				o.text = "/"
				o.add_theme_color_override("font_color", Color(PERGAMINO, 0.55))
				fila.add_child(o)
			var canto := PanelContainer.new()
			canto.add_theme_stylebox_override("panel", _caja(Color.TRANSPARENT, TINTA, [0, 0, 0, 2], [0, 0, 0, 0]))
			var p := PanelContainer.new()
			p.add_theme_stylebox_override("panel", _caja(VIOLETA_2, VIOLETA_4, [0, 1, 0, 0], [3, 1, 3, 1]))
			var k := Label.new()
			k.text = teclas[j]
			p.add_child(k)
			canto.add_child(p)
			fila.add_child(canto)
		var l := Label.new()
		l.text = pares[i][1]
		l.add_theme_color_override("font_color", Color(PERGAMINO, 0.7))
		fila.add_child(l)
		if i < pares.size() - 1:
			var hueco := Control.new()
			hueco.custom_minimum_size = Vector2(6, 0)
			fila.add_child(hueco)


func _caja(fondo: Color, borde := Color.TRANSPARENT, grosor := [0, 0, 0, 0], margen := [0, 0, 0, 0]) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.border_width_left = grosor[0]
	s.border_width_top = grosor[1]
	s.border_width_right = grosor[2]
	s.border_width_bottom = grosor[3]
	s.content_margin_left = margen[0]
	s.content_margin_top = margen[1]
	s.content_margin_right = margen[2]
	s.content_margin_bottom = margen[3]
	s.anti_aliasing = false
	return s


func _nueve(archivo: String, margen := [3, 3, 3, 3]) -> StyleBoxTexture:
	var s := StyleBoxTexture.new()
	s.texture = load("res://ui/" + archivo)
	for i in 4:
		s.set_texture_margin(i, 3)
		s.set_content_margin(i, margen[i])
	return s


func marco(margen := [6, 5, 6, 6]) -> StyleBoxTexture:
	## el marco fino de latón biselado de las tarjetas de la marca, sobre violeta
	return _nueve("marco.png", margen)


func _tema() -> Theme:
	var t := Theme.new()
	t.default_font = fuente
	t.default_font_size = 5
	for tipo in ["Label", "Button"]:
		t.set_color("font_shadow_color", tipo, TINTA)
		t.set_constant("shadow_offset_x", tipo, 0)
		t.set_constant("shadow_offset_y", tipo, 1)
	t.set_color("font_color", "Label", PERGAMINO)
	# botón: sólo texto; al pasar, pergamino entero; elegido, latón con su raya de latón debajo
	var vacio := _caja(Color.TRANSPARENT, Color.TRANSPARENT, [0, 0, 0, 1], [0, 2, 0, 2])
	var elegido := _caja(Color.TRANSPARENT, LATON, [0, 0, 0, 1], [0, 2, 0, 2])
	t.set_stylebox("normal", "Button", vacio)
	t.set_stylebox("hover", "Button", _caja(Color.TRANSPARENT, Color(PERGAMINO, 0.45), [0, 0, 0, 1], [0, 2, 0, 2]))
	t.set_stylebox("pressed", "Button", elegido)
	t.set_stylebox("hover_pressed", "Button", elegido)
	t.set_stylebox("focus", "Button", StyleBoxEmpty.new())
	t.set_color("font_color", "Button", PERGAMINO)
	t.set_color("font_hover_color", "Button", PERGAMINO)
	t.set_color("font_pressed_color", "Button", LATON)
	t.set_color("font_hover_pressed_color", "Button", LATON)
	t.set_color("font_focus_color", "Button", PERGAMINO)
	# tooltips: el mismo marco y la misma letra
	t.set_stylebox("panel", "TooltipPanel", marco([4, 3, 4, 3]))
	t.set_color("font_color", "TooltipLabel", PERGAMINO)
	t.set_color("font_shadow_color", "TooltipLabel", TINTA)
	t.set_constant("shadow_offset_y", "TooltipLabel", 1)
	t.set_font("font", "TooltipLabel", fuente)
	t.set_font_size("font_size", "TooltipLabel", 5)
	# barra de desplazamiento fina: carril violeta y asa de latón
	var rail := _caja(Color.TRANSPARENT, Color(LATON_HONDO, 0.7), [0, 0, 1, 0], [1, 0, 0, 0])
	t.set_stylebox("scroll", "VScrollBar", rail)
	t.set_stylebox("scroll_focus", "VScrollBar", rail)
	t.set_stylebox("grabber", "VScrollBar", _caja(LATON_MEDIO, Color.TRANSPARENT, [0, 0, 0, 0], [1, 2, 1, 2]))
	t.set_stylebox("grabber_highlight", "VScrollBar", _caja(LATON, Color.TRANSPARENT, [0, 0, 0, 0], [1, 2, 1, 2]))
	t.set_stylebox("grabber_pressed", "VScrollBar", _caja(LATON, Color.TRANSPARENT, [0, 0, 0, 0], [1, 2, 1, 2]))
	return t


func _boton(texto: String, alternar := true) -> Button:
	var b := Button.new()
	b.text = texto
	b.toggle_mode = alternar
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b


func estilo_prieto(b: Button) -> void:
	## botón de lista con 1 px arriba y abajo (filas de 8 px)
	b.add_theme_stylebox_override("normal", _caja(Color.TRANSPARENT, Color.TRANSPARENT, [0, 0, 0, 1], [0, 1, 0, 1]))
	b.add_theme_stylebox_override("hover", _caja(Color.TRANSPARENT, Color(PERGAMINO, 0.45), [0, 0, 0, 1], [0, 1, 0, 1]))
	b.add_theme_stylebox_override("pressed", _caja(Color.TRANSPARENT, LATON, [0, 0, 0, 1], [0, 1, 0, 1]))
	b.add_theme_stylebox_override("hover_pressed", _caja(Color.TRANSPARENT, LATON, [0, 0, 0, 1], [0, 1, 0, 1]))


func boton_laton(texto: String) -> Button:
	## el único botón lleno: placa de latón biselada con letra de tinta
	var b := _boton(texto, false)
	b.add_theme_stylebox_override("normal", _nueve("placa.png", [5, 2, 5, 3]))
	b.add_theme_stylebox_override("hover", _nueve("placa_encima.png", [5, 2, 5, 3]))
	b.add_theme_stylebox_override("pressed", _nueve("placa_pulsada.png", [5, 3, 5, 2]))
	for k in ["font_color", "font_hover_color", "font_pressed_color"]:
		b.add_theme_color_override(k, TINTA)
	b.add_theme_color_override("font_shadow_color", Color(BRILLO_LETRA, 0.5))
	return b


func boton_cerrar() -> Button:
	var b := Button.new()
	b.icon = load("res://ui/cerrar.png")
	b.focus_mode = Control.FOCUS_NONE
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var s := _caja(Color.TRANSPARENT, Color.TRANSPARENT, [0, 0, 0, 0], [3, 2, 1, 2])
	for k in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(k, s)
	b.add_theme_color_override("icon_normal_color", LATON)
	b.add_theme_color_override("icon_hover_color", BRILLO_LETRA)
	b.add_theme_color_override("icon_pressed_color", LATON)
	return b


# ------------------------------------------------------------------------------------------------------ piezas
func _arriba() -> void:
	arriba = PanelContainer.new()
	arriba.add_theme_stylebox_override("panel", marco(AIRE))
	raiz.add_child(arriba)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 8)
	arriba.add_child(fila)
	b_noche = _interruptor(fila, "NIGHT", "DAY / NIGHT  (N)", false)
	b_noche.toggled.connect(func(on): noche_cambiada.emit(on))
	b_invierno = _interruptor(fila, "WINTER", "SHIFT THE SEASON: SUMMER / WINTER  (I)", false)
	b_invierno.toggled.connect(func(on): invierno_cambiado.emit(on))
	b_sonido = _interruptor(fila, "SOUND", "ANIMAL SOUNDS ON / OFF  (M)", true)
	b_sonido.toggled.connect(func(on): sonido_cambiado.emit(on))
	var ayuda_b := _boton("?", false)
	ayuda_b.tooltip_text = "HOW TO PLAY"
	ayuda_b.pressed.connect(muestra_ayuda)
	fila.add_child(ayuda_b)
	fila.add_child(_filete())
	var comprar := boton_laton("GET THE PACK")
	comprar.tooltip_text = "OPENS THE PACK PAGE ON ITCH.IO"
	comprar.pressed.connect(func(): OS.shell_open(URL_PACK))
	fila.add_child(comprar)


func _filete() -> ColorRect:
	var f := ColorRect.new()
	f.color = LATON_HONDO
	f.custom_minimum_size = Vector2(1, 9)
	f.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return f


func _interruptor(fila: HBoxContainer, texto: String, aviso: String, on: bool) -> Button:
	## un interruptor: su piloto (2 x 2) en latón cuando está encendido, apagado en violeta; la palabra no cambia de
	## estilo (el latón con raya es para lo elegido en una lista, no para encendido / apagado)
	var caja := HBoxContainer.new()
	caja.add_theme_constant_override("separation", 3)
	var piloto := ColorRect.new()
	piloto.custom_minimum_size = Vector2(3, 3)
	piloto.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	caja.add_child(piloto)
	var b := _boton(texto)
	b.tooltip_text = aviso
	var plano := _caja(Color.TRANSPARENT, Color.TRANSPARENT, [0, 0, 0, 1], [0, 2, 0, 2])
	b.add_theme_stylebox_override("pressed", plano)
	b.add_theme_stylebox_override("hover_pressed", _caja(Color.TRANSPARENT, Color(PERGAMINO, 0.45), [0, 0, 0, 1], [0, 2, 0, 2]))
	# encendido: la palabra en latón (como todo lo activo) y el piloto lleno; apagado, piloto hondo a la vista
	b.add_theme_color_override("font_pressed_color", LATON)
	b.add_theme_color_override("font_hover_pressed_color", LATON)
	b.toggled.connect(func(x): piloto.color = LATON if x else LATON_HONDO)
	b.button_pressed = on
	piloto.color = LATON if on else LATON_HONDO
	b.set_meta("piloto", piloto)
	caja.add_child(b)
	fila.add_child(caja)
	return b


func refresca_noche() -> void:
	## el piloto de NIGHT cuando el reloj lo cambia sin señal (set_pressed_no_signal)
	b_noche.get_meta("piloto").color = LATON if b_noche.button_pressed else LATON_HONDO


func _abajo() -> void:
	abajo = PanelContainer.new()
	abajo.add_theme_stylebox_override("panel", marco(AIRE))
	raiz.add_child(abajo)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	abajo.add_child(col)
	# una sola placa, de ancho fijo: al principio la fila es la ayuda; cuando se apaga, aparecen las familias en
	# el mismo sitio (nada salta ni cambia de tamaño)
	pila = Control.new()
	pila.mouse_filter = Control.MOUSE_FILTER_PASS
	col.add_child(pila)
	# la ayuda, SIN placa, suelta encima de las familias (crítico 26-10: la placa doble se leía como rejilla negra); cada
	# tecla se retira cuando se usa su gesto y vuelve con «?»
	placa_ayuda = PanelContainer.new()
	placa_ayuda.add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	placa_ayuda.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(placa_ayuda)
	ayuda = HBoxContainer.new()
	ayuda.add_theme_constant_override("separation", 8)
	ayuda.alignment = BoxContainer.ALIGNMENT_CENTER
	placa_ayuda.add_child(ayuda)
	var tactil := DisplayServer.is_touchscreen_available()
	# lo primero, qué hacer (elegir un animal); luego, cómo mirar (usuario 26-10: visibles, poco intrusivas y claras)
	var pares := [["TAP", "PLAY"], ["DRAG", "LOOK"], ["PINCH", "ZOOM"], ["HOLD", "FEED"]] if tactil else \
		[["CLICK", "PLAY"], ["WASD|DRAG", "LOOK"], ["WHEEL", "ZOOM"], ["RIGHT CLICK", "FEED"]]
	for par in pares:
		_pista(ayuda, par)
	var fila := HBoxContainer.new()
	fila.add_theme_constant_override("separation", 6)
	fila.alignment = BoxContainer.ALIGNMENT_CENTER
	pila.add_child(fila)
	fila_familias = fila
	fila.modulate.a = 1.0
	fila.visible = true
	for f in FAMILIAS:
		var b := _boton(f[0])
		b.pressed.connect(func(): familia_elegida.emit(f[1]))
		fila.add_child(b)
		botones[f[1]] = b


func _ficha() -> void:
	ficha = PanelContainer.new()
	ficha.add_theme_stylebox_override("panel", marco(AIRE))
	ficha.visible = false
	raiz.add_child(ficha)
	# dos filas: quién es (color, macho / hembra / cría, teclas) y lo que puede hacer
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	ficha.add_child(col)
	var cab := HBoxContainer.new()
	cab.add_theme_constant_override("separation", 6)
	col.add_child(cab)
	var fila_acc := HBoxContainer.new()
	fila_acc.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(fila_acc)
	# el nombre en su placa de latón, como en las tarjetas de la marca
	# el nombre en letra de latón, sin placa: la única placa llena de la pantalla es la de comprar
	ficha_nombre = Label.new()
	ficha_nombre.custom_minimum_size = Vector2(44, 0)
	ficha_nombre.add_theme_color_override("font_color", LATON)
	cab.add_child(ficha_nombre)
	ficha_sub = Label.new()
	ficha_sub.add_theme_color_override("font_color", Color(PERGAMINO, 0.5))   # dato, no acción: tenue
	ficha_sub.custom_minimum_size = Vector2(66, 0)   # cabe el color más largo con «n/n»: las flechas no se mueven
	ficha_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flecha_menos = _boton("<", false)
	var menos: Button = flecha_menos
	menos.tooltip_text = "PREVIOUS COLOUR"
	menos.pressed.connect(func(): _otra_capa(-1))
	cab.add_child(menos)
	cab.add_child(ficha_sub)
	flecha_mas = _boton(">", false)
	var mas: Button = flecha_mas
	mas.tooltip_text = "NEXT COLOUR"
	mas.pressed.connect(func(): _otra_capa(1))
	cab.add_child(mas)
	ficha_roles = HBoxContainer.new()
	ficha_roles.add_theme_constant_override("separation", 6)
	cab.add_child(_filete())
	cab.add_child(ficha_roles)
	cab.add_child(_filete())
	pistas_ficha = HBoxContainer.new()
	pistas_ficha.add_theme_constant_override("separation", 8)
	pistas_ficha.mouse_filter = Control.MOUSE_FILTER_IGNORE
	raiz.add_child(pistas_ficha)
	for par in [["WASD", "WALK"], ["SHIFT", "RUN"]]:
		_pista(pistas_ficha, par)
	# el nombre del animal bajo el ratón (crítico 26-10): en latón con un filo de tinta a los cuatro lados, sin placa, la
	# letra de 5 px de la marca; encima de sus esquinas; y un ratoncito al lado hasta el primer clic
	# las esquinas, por debajo de todas las placas
	marcos = Control.new()
	marcos.mouse_filter = Control.MOUSE_FILTER_IGNORE
	marcos.set_anchors_preset(Control.PRESET_FULL_RECT)
	marcos.draw.connect(_dibuja_marcos)
	raiz.add_child(marcos)
	raiz.move_child(marcos, 0)
	pista_animal = Control.new()
	pista_animal.visible = false
	pista_animal.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pista_animal.draw.connect(_dibuja_pista)
	raiz.add_child(pista_animal)
	var hueco := Control.new()
	hueco.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cab.add_child(hueco)
	ficha_lista = HBoxContainer.new()
	ficha_lista.add_theme_constant_override("separation", 8)
	fila_acc.add_child(ficha_lista)
	var x := boton_cerrar()
	x.pressed.connect(func(): cerrar_ficha.emit())
	cab.add_child(x)


# ------------------------------------------------------------------------------------------------------ colocación
func _ajusta() -> void:
	var u := get_viewport().get_visible_rect().size   # en píxeles de la base
	var win := Vector2(get_window().size)
	escala = maxi(1, int(min(win.x / 480.0, win.y / 270.0)))
	raiz.size = u
	# el rótulo: el PNG dibujado a su escala, pintado a 1/k de la base para que salga a 1:1 en pantalla
	var k := 2 if escala >= 2 else 1
	rotulo.texture = load("res://ui/rotulo_%d.png" % k)
	rotulo.scale = Vector2.ONE / k
	# el rótulo sobre el velo violeta, con el margen libre de MARCA: la altura de una letra (9 px de la base)
	var tam_rot := rotulo.texture.get_size() / k
	rotulo.position = Vector2(9, 9)
	banda.position = Vector2.ZERO
	banda.size = Vector2(u.x, banda.texture.get_height())
	# la placa de acciones, alineada con el rótulo: su texto a la altura del rótulo
	arriba.custom_minimum_size = Vector2(0, 0)
	arriba.reset_size()
	# la marca de agua arriba a la DERECHA, como en todo (MARCA.md); la placa de controles, a la izquierda
	arriba.position = Vector2(MARGEN, MARGEN)
	rotulo.position = Vector2(u.x - tam_rot.x - 9, maxf(9.0, floorf(MARGEN + (arriba.size.y - tam_rot.y) / 2.0)))
	# la fila de la placa mide lo que la más ancha de las dos (ayuda o familias): ancho fijo
	var m_fa := fila_familias.get_combined_minimum_size()
	var m := m_fa
	pila.custom_minimum_size = m
	fila_familias.position = Vector2(int((m.x - m_fa.x) / 2), 0)
	fila_familias.size = m_fa
	abajo.reset_size()
	if int(u.x - abajo.size.x) % 2 == 1:
		abajo.size.x += 1   # ancho par: centrada al píxel
	abajo.position = Vector2(int((u.x - abajo.size.x) / 2), u.y - abajo.size.y - MARGEN)
	_coloca_ficha()
	_coloca_pistas()
	if visor:
		visor.position = Vector2.ZERO
		visor.size = u
	var cur: Image = load("res://ui/cursor.png").get_image()
	cur.resize(cur.get_width() * escala, cur.get_height() * escala, Image.INTERPOLATE_NEAREST)
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(cur))
	Input.set_custom_mouse_cursor(ImageTexture.create_from_image(cur), Input.CURSOR_POINTING_HAND)


func _coloca_ficha() -> void:
	# en el sitio de la placa de las familias: abajo, centrada, al mismo margen
	var u := raiz.size
	# siempre el mismo ancho, el de la placa de abajo (o lo que pida la ficha si es más): nada salta al cambiar de color
	ficha.size = ficha.get_combined_minimum_size()
	ficha.size.x = maxf(ficha.size.x, u.x - 2.0 * MARGEN)
	if int(u.x - ficha.size.x) % 2 == 1:
		ficha.size.x += 1
	ficha.position = Vector2(int((u.x - ficha.size.x) / 2), u.y - ficha.size.y - MARGEN)


func zona_libre() -> Rect2:
	## lo que la interfaz deja ver de la granja, en píxeles de la base (para que la cámara encuadre ahí)
	var arriba_y := arriba.position.y + arriba.size.y
	var abajo_y := abajo.position.y
	if ficha.visible:
		abajo_y = ficha.position.y
	elif _ayuda_visible():
		abajo_y = placa_ayuda.position.y - 2   # la fila de ayuda tampoco tapa la granja (crítico 26-10, punto 6)
	return Rect2(0, arriba_y, raiz.size.x, abajo_y - arriba_y)


func _ayuda_visible() -> bool:
	## si queda alguna tecla de la ayuda a la vista (sobre la placa de abajo)
	if placa_ayuda == null or not placa_ayuda.visible:
		return false
	for t in _pistas:
		if _pistas[t].visible:
			return true
	return false


# ------------------------------------------------------------------------------------------------------ estado
func marca_familia(nombre: String) -> void:
	for n in botones:
		botones[n].set_pressed_no_signal(n == nombre)


func abre_ficha(a: Actor) -> void:
	actor = a
	var quien := _quien(a.nombre)
	ficha_nombre.text = quien[0]
	ficha_sub.text = quien[1]
	for c in ficha_lista.get_children():
		c.queue_free()
	_filas.clear()
	for c in ficha_roles.get_children():
		c.queue_free()
	var w := _donde(a.nombre)
	if not w.is_empty():
		var miembros: Array = E["visor"][w[0]]["miembros"]
		if miembros.size() > 1:
			for j in miembros.size():
				# por su nombre (BULL, COW, BULL CALF, HEIFER CALF): una especie puede tener más de tres
				var r := _boton(String(miembros[j]["en"]).replace("_", " ").to_upper())
				r.set_pressed_no_signal(j == w[1])
				r.pressed.connect(func(): _otro_miembro(j))
				ficha_roles.add_child(r)
		var n_capas: int = miembros[w[1]]["capas"].size()
		var varias := n_capas > 1
		flecha_menos.modulate.a = 1.0 if varias else 0.0
		flecha_mas.modulate.a = 1.0 if varias else 0.0
		flecha_menos.disabled = not varias
		flecha_mas.disabled = not varias
		ficha_sub.text = ("%s %d/%d" % [_quien(a.nombre)[1], w[2] + 1, n_capas]) if varias else _quien(a.nombre)[1]
	for acc in acciones_de(a.d["anims"], a.d["zip"]):
		var piezas: Array = acc[1]
		# todas (muerte y golpe también); despegar y posarse van dentro de volar
		if piezas.is_empty() or acc[0] in ["TAKE OFF", "LAND"]:
			continue
		# la acción que se pide es la del bucle (la del medio si hay arranque y parada); al lado, los fotogramas de
		# cada pieza en la vista de frente, como en el ZIP: EAT 15·8·14
		var base: String = piezas[1] if piezas.size() == 3 else (piezas[1] if piezas.size() == 2 and piezas[0].ends_with("_start") else piezas[0])
		var cuentas := []
		for p in piezas:
			var pistas: Dictionary = a.d["anims"][p]
			cuentas.append(str(pistas.get("south", pistas.values()[0])["ms"].size()))
		var fila := HBoxContainer.new()
		fila.add_theme_constant_override("separation", 0)
		var b := _boton(acc[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var relleno := Control.new()
		relleno.custom_minimum_size = Vector2(2, 0)
		b.pressed.connect(func(): accion_elegida.emit(base))
		fila.add_child(b)
		ficha_lista.add_child(fila)
		_filas[base] = b
	ficha.visible = true
	abajo.visible = false
	# las filas nuevas se miden en el fotograma siguiente: entonces se ajusta el tamaño y el sitio
	for i in 2:
		await get_tree().process_frame
		_coloca_ficha()
		_coloca_pistas()


func _donde(nombre: String) -> Array:
	## [familia, miembro, capa] de esa criatura en el catálogo del pack
	var fams: Array = E.get("visor", [])
	for i in fams.size():
		for j in fams[i]["miembros"].size():
			var capas: Array = fams[i]["miembros"][j]["capas"]
			if nombre in capas:
				return [i, j, capas.find(nombre)]
	return []


func _otra_capa(paso: int) -> void:
	if actor == null:
		return
	var w := _donde(actor.nombre)
	if w.is_empty():
		return
	var capas: Array = E["visor"][w[0]]["miembros"][w[1]]["capas"]
	actor.transforma(capas[(w[2] + paso + capas.size()) % capas.size()])
	abre_ficha(actor)


func _otro_miembro(j: int) -> void:
	if actor == null:
		return
	var w := _donde(actor.nombre)
	if w.is_empty():
		return
	var capas_nuevas: Array = E["visor"][w[0]]["miembros"][j]["capas"]
	var color := actor.nombre.trim_prefix(actor.nombre.split("_")[0])   # «_azul», o vacío
	var elegida: String = capas_nuevas[0]
	for c in capas_nuevas:
		if color != "" and c.ends_with(color):
			elegida = c
	actor.transforma(elegida)
	abre_ficha(actor)


func _quien(nombre: String) -> Array:
	## «HEN» y «FEMALE · BLACK», sacado del visor: especie, papel y capa de color
	for fam in E.get("visor", []):
		for i in fam["miembros"].size():
			var m: Dictionary = fam["miembros"][i]
			if nombre in m["capas"]:
				var base_en: String = m["en"].replace("_", " ")
				var color: String = E["animales"][nombre]["en"].trim_prefix(base_en).strip_edges()
				var papel: String = ["MALE", "FEMALE", "YOUNG"][i] if fam["miembros"].size() > 1 else "ONE ANIMAL"
				return [base_en.to_upper(), (color if color != "" else "standard").to_upper()]
	return [E["animales"][nombre]["en"].to_upper(), ""]


func acciones_de(anims: Dictionary, zip: Dictionary) -> Array:
	## [rótulo, piezas] de todas las animaciones: primero las conocidas en su orden, luego cualquier otra que el pack
	## traiga (moo, suckle, headbutt…), agrupada con su arranque y su parada
	var lista := []
	var vistas := {}
	for acc in ACCIONES:
		var piezas: Array = acc[1].filter(func(p): return anims.has(p))
		if not piezas.is_empty():
			lista.append([acc[0], piezas])
			for p in piezas:
				vistas[p] = true
	var nuevas := []
	for a in anims:
		if vistas.has(a):
			continue
		var base: String = a.trim_suffix("_start").trim_suffix("_end")
		if not base in nuevas:
			nuevas.append(base)
	for base in nuevas:
		var piezas := [base + "_start", base, base + "_end"].filter(func(p): return anims.has(p))
		lista.append([String(zip.get(base, base)).to_upper().replace("_", " "), piezas])
	return lista


func cierra_ficha() -> void:
	actor = null
	ficha.visible = false
	if visor == null or not visor.visible:
		abajo.visible = true
	_coloca_pistas()


func apaga_ayuda() -> void:
	if _ayuda_apagada:
		return
	_ayuda_apagada = true
	# usuario 25-10: «habría que explicar cómo moverte»: la ayuda no se va; las familias aparecen debajo
	fila_familias.visible = true
	var tw := create_tween()
	tw.tween_property(fila_familias, "modulate:a", 1.0, 0.5)


func abre_visor(nombre := "") -> void:
	if visor == null:
		visor = preload("res://visor.gd").new()
		raiz.add_child(visor)
		visor.prepara(E, self)
		visor.cerrar.connect(cierra_visor)
	if nombre != "":
		visor.muestra(nombre)
	visor.visible = true
	for c in [abajo, ficha, arriba, rotulo, banda]:
		c.visible = false
	_ajusta()
	if OS.get_cmdline_user_args().has("--medidas"):   # depuración: tamaños del visor a un archivo
		await get_tree().process_frame
		await get_tree().process_frame
		var f := FileAccess.open(OS.get_environment("TEMP").path_join("medidas_visor.txt"), FileAccess.WRITE)
		f.store_line("u=%s visor=%s" % [raiz.size, visor.get_rect()])
		for c in visor.find_children("*", "Control", true, false):
			if c.get_combined_minimum_size().y > 150 or c.size.y > 300:
				f.store_line("%s %s min=%s size=%s" % [c.get_path(), c.get_class(), c.get_combined_minimum_size(), c.size])
		f.close()


func cierra_visor() -> void:
	visor.visible = false
	for c in [arriba, rotulo, banda]:
		c.visible = true
	ficha.visible = actor != null
	abajo.visible = actor == null


func _process(delta: float) -> void:
	if fila_familias and fila_familias.visible and _ayuda_apagada:
		var cerca := get_viewport().get_mouse_position().y > raiz.size.y - 60.0 or abajo.get_global_rect().has_point(get_viewport().get_mouse_position())
		# la placa sigue entera; sólo su texto baja de tono (nada de placas fantasma)
		var meta := 1.0 if cerca else 0.8   # crítico 26-10 (punto 12): al 60 % se leían grises
		fila_familias.modulate.a = move_toward(fila_familias.modulate.a, meta, delta * 3.0)
	if actor == null:
		return
	# la acción que hace ahora, sin _start ni _end
	var anim: String = actor.paso["anim"].trim_suffix("_start").trim_suffix("_end")
	for k in _filas:
		_filas[k].set_pressed_no_signal(k == anim)

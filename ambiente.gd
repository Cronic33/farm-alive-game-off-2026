extends Node
## La vida de ambiente de la escena aprobada (docs/ENTREGA_ESCENA_GRANJA.md), hecha en el motor con los mismos números
## que el vídeo (_tools/vida_ambiente.py, vida_granja.py, vida_granja_noche.py): píxeles enteros, colores de la escena.
##   suelo: matas mecidas, corriente del arroyo, destellos, espuma de la orilla, oleaje y gotas del estanque, ondas bajo
##          los patos
##   alto:  humo de la chimenea, abejas, libélulas, mariposas, hojas, vilanos, el remolino de polvo (de día), la neblina
##          del alba sobre el agua, la llovizna y los faroles del camino
##   luz:   ventanas de la casa, puerta del granero, ventanuco del gallinero y faroles, con su charco y su halo; el azul de
##          la noche; luna en el agua y luciérnagas. Va en su propia capa para que la luz de la noche no las apague
##   marco: por fuera de la granja, el damasco de la marca y el marco fino de latón (crítico 26-10, punto 7)
## Lo que dura el bucle del vídeo (30 s) sigue igual: los ritmos de cada cosa son los aprobados.
## Crítico 26-10 (punto 4): todo lo que es de un píxel se dibuja en bloques de `s` × `s` píxeles de mundo, con s el
## tamaño de un píxel de pantalla en la vista de ahora: de cerca, 1; con la granja entera, 3 o 4. Así se lee de lejos.

const L := 30000.0
const CLARO := Color8(156, 204, 210)
const OSCURO := Color8(40, 70, 104)
const MEDIO := Color8(104, 156, 184)
const DESTELLO := Color8(232, 244, 240)   # #e8f4f0
const HUMO := [Color8(232, 230, 222), Color8(206, 204, 198), Color8(176, 174, 170)]
const ABEJAS := [Vector2(336, 64), Vector2(414, 124), Vector2(494, 62), Vector2(480, 132)]
const LIBELULAS := [[Vector2(110, 590), Vector2(150, 606), Vector2(226, 596), Vector2(190, 640), Vector2(120, 640)],
	[Vector2(250, 620), Vector2(200, 670), Vector2(90, 660), Vector2(170, 580)]]
const MARIPOSAS := [[Vector2(300, 300), Vector2(34, 14), Color8(236, 232, 214)], [Vector2(672, 470), Vector2(26, 18), Color8(238, 206, 92)],
	[Vector2(560, 440), Vector2(22, 12), Color8(230, 150, 170)]]
const ALAS := [[".c.c.", "ccKcc", ".c.c."], ["..c..", ".cKc.", "..K.."]]
const HOJAS_DE := [Vector2(30, 100), Vector2(62, 104), Vector2(126, 100), Vector2(158, 104), Vector2(222, 100), Vector2(254, 104),
	Vector2(746, 96), Vector2(784, 100), Vector2(20, 690)]
const HOJA_COL := [[Color8(232, 186, 76), Color8(176, 120, 44)], [Color8(214, 130, 52), Color8(150, 82, 34)], [Color8(176, 196, 92), Color8(110, 140, 56)]]
const SOMBRA_HOJA := Color8(54, 82, 40)
const VILANOS := [Vector2(800, 20), Vector2(860, 70), Vector2(930, 10), Vector2(1010, 40), Vector2(1090, 20), Vector2(1170, 60),
	Vector2(1230, 30), Vector2(840, 140), Vector2(1150, 120)]
const REMOLINO := Vector2(1112, 196)
const CHIMENEA := Vector2(675, 22)
const ORDEN_MATAS := ["mata_a", "mata_b", "flor_blanca", "flor_roja", "flor_amarilla", "flor_azul", "flor_morada"]
const CALIDA := Color8(255, 196, 104)    # #ffc468
const NUCLEO := Color8(255, 247, 220)    # #fff7dc: el punto más vivo de cada luz
const TINTA := Color8(14, 8, 5)
const REFLEJO := Color8(200, 210, 235)
const LUNA := Color8(236, 240, 250)
const AZUL_NOCHE := Color8(10, 20, 48)   # #0a1430, sumado de noche bajo las luces (crítico 26-10, punto 2)
const NEBLINA := Color8(200, 208, 224)   # #c8d0e0
const LLUVIA := Color8(168, 184, 208)    # #a8b8d0
const COPO := Color8(238, 243, 247)      # #eef3f7, la luz de la rampa de nieve del kit
const COPO_SOMBRA := Color8(147, 170, 196)   # #93aac4
# luciérnagas (crítico 26-10, punto 4): 32, también por el borde del trigal, el seto oeste y junto a la casa
const LUCIERNAGAS := [Vector2(140, 560), Vector2(220, 600), Vector2(300, 690), Vector2(40, 540), Vector2(470, 620), Vector2(700, 640),
	Vector2(560, 470), Vector2(860, 470), Vector2(1000, 640), Vector2(1180, 650), Vector2(120, 470), Vector2(250, 450),
	Vector2(940, 260), Vector2(760, 230),
	Vector2(806, 60), Vector2(800, 150), Vector2(832, 206), Vector2(900, 216), Vector2(980, 212), Vector2(1062, 210),
	Vector2(1150, 206), Vector2(1240, 200),
	Vector2(12, 200), Vector2(8, 300), Vector2(14, 420), Vector2(10, 520),
	Vector2(552, 214), Vector2(604, 222), Vector2(662, 214), Vector2(722, 200), Vector2(530, 182), Vector2(742, 150)]
const LUCIERNAGA := Color8(244, 255, 176)        # #f4ffb0
const LUCIERNAGA_HALO := Color8(168, 208, 80)    # #a8d050
# luces de la granja de noche (crítico 26-10, punto 3), en píxeles de mundo
const GRANERO_PUERTA := Rect2i(382, 320, 49, 41)     # el hueco de la puerta del granero (su interior oscuro)
const GRANERO_CHARCO := Vector2(406, 368)
const GALLINERO_VENTANA := Rect2i(1076, 269, 17, 19) # el ventanuco de cruz del gallinero
const GALLINERO_CHARCO := Vector2(1084, 349)
# los faroles, colgados de un brazo en el poste de cada lado de la entrada, hacia el camino: [esquina del farol, charco,
# brazo desde, brazo hasta (en la fila de arriba del farol)]
const FAROLES := [[Vector2(641, 576), Vector2(645, 616), 640, 643], [Vector2(674, 583), Vector2(676, 623), 676, 681]]
const FAROL := ["..K..", ".KKK.", "KgggK", "KgggK", "KgggK", ".KKK."]
const FAROL_APAGADO := Color8(138, 106, 58)

var escena
var E: Dictionary
var agua: Image
var hoja_matas: Texture2D
var suelo: Node2D       # sobre el suelo, bajo las piezas y los animales
var alto: Node2D        # sobre todo (bajo la interfaz)
var luces: CanvasLayer  # lo que da luz de noche: fuera de la luz de la escena
var capa_luz: Node2D
var azul: Node2D        # el azul de la noche, sumado (bajo las luces)
var espuma: Sprite2D
var marco_capa: CanvasLayer
var marco_nodo: Node2D
var damasco: Texture2D
var marco_caja: StyleBoxTexture
var nubes: Sprite2D
var trigo: ShaderMaterial
var arboles: Array = []   # [sprite, textura, textura mecida, punto]
var molino: Sprite2D
var aspas: Sprite2D
var patos: Array = []     # puntos donde nada un pato este instante (ondas bajo él)
var t := 0.0              # ms
var n := 0.0              # oscuridad 0..1
var s := 1.0              # el bloque de píxel de la vista, en píxeles de mundo (punto 4)
var ventanas_f := 0.0     # cuánto lucen las ventanas
var neblina := 0.0        # la neblina baja del alba, 0..1
var lluvia := 0.0         # la llovizna, 0..1
var granos: Array = []    # [punto, edad ms]: el puñado que echa el granjero (vida_granja.granos)
const GRANO := [Color8(246, 222, 132), Color8(232, 200, 104)]
const GRANO_SOMBRA := Color8(120, 88, 52)
const GRANO_PUNTOS := [Vector2(0, 0), Vector2(3, 1), Vector2(-2, 2), Vector2(5, -1), Vector2(1, 3), Vector2(-4, 0), Vector2(7, 2),
	Vector2(2, -2), Vector2(4, 3), Vector2(-1, -1), Vector2(6, 4), Vector2(-3, 3), Vector2(8, 0), Vector2(1, 5), Vector2(-5, 2), Vector2(3, -3)]
var _corriente: Array = []
var matas_nodo: Node2D
var _matas_estado := PackedByteArray()
var _paso_px := 0.0      # los efectos de píxel se redibujan a 15 fotogramas por segundo (se mueven a saltos de píxel)
var _ventanas_tex: Array = []   # [textura del cristal encendido, posición] por ventana
var _granero_tex: Texture2D
var _gallinero_tex: Texture2D
var _elipses := {}               # tamaño -> textura de elipse llena (halos y charcos)
var _total := 0.0
var _vista_antes := Transform2D()


func prepara(la_escena) -> void:
	escena = la_escena
	E = escena.E
	agua = (load(escena.DATOS + "agua.png") as Texture2D).get_image()
	hoja_matas = load(escena.DATOS + "piezas/matas_flores.png")
	matas_nodo = Node2D.new()
	matas_nodo.z_index = -1
	matas_nodo.draw.connect(_dibuja_matas)
	escena.add_child(matas_nodo)
	matas_nodo.material = escena.mat_estacion   # las matas con flores también pasan de estación
	# la espuma de la orilla, en el motor (espuma.gdshader), bajo la corriente y los destellos
	espuma = Sprite2D.new()
	var lienzo_agua := PlaceholderTexture2D.new()
	lienzo_agua.size = Vector2(float(E["W"]), float(E["H"]))
	espuma.texture = lienzo_agua
	espuma.centered = false
	espuma.z_index = -1
	var me := ShaderMaterial.new()
	me.shader = load("res://espuma.gdshader")
	me.set_shader_parameter("mascara", load(escena.DATOS + "agua.png"))
	me.set_shader_parameter("tam", lienzo_agua.size)
	espuma.material = me
	escena.add_child(espuma)
	suelo = Node2D.new()
	suelo.z_index = -1
	suelo.material = escena.mat_estacion
	suelo.draw.connect(_dibuja_suelo)
	escena.add_child(suelo)
	_matas_estado.resize(E["matas"].size())
	_prepara_ventanas()
	_granero_tex = _hueco_oscuro("granero_rojo", GRANERO_PUERTA, true)
	_gallinero_tex = _hueco_oscuro("gallinero_1", GALLINERO_VENTANA)
	alto = Node2D.new()
	alto.z_index = 20
	alto.draw.connect(_dibuja_alto)
	escena.add_child(alto)
	nubes = Sprite2D.new()
	var lienzo := PlaceholderTexture2D.new()
	lienzo.size = Vector2(float(E["W"]), float(E["H"]))
	nubes.texture = lienzo
	nubes.centered = false
	nubes.z_index = 19
	var mn := ShaderMaterial.new()
	mn.shader = load("res://nubes_granja.gdshader")
	mn.set_shader_parameter("tam", lienzo.size)
	nubes.material = mn
	escena.add_child(nubes)
	luces = CanvasLayer.new()
	luces.layer = 1
	luces.follow_viewport_enabled = true
	escena.add_child(luces)
	# el azul de la noche: un CanvasModulate solo multiplica, y el ocre se queda gris; sumado un azul hondo, la tierra
	# y la hierba pasan a azules (crítico 26-10, punto 2). Bajo las luces, que siguen cálidas
	azul = Node2D.new()
	var suma := CanvasItemMaterial.new()
	suma.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	azul.material = suma
	azul.draw.connect(func(): azul.draw_rect(Rect2(-4000, -4000, float(E["W"]) + 8000, float(E["H"]) + 8000), AZUL_NOCHE))
	azul.modulate = Color(1, 1, 1, 0)
	luces.add_child(azul)
	capa_luz = Node2D.new()
	capa_luz.draw.connect(_dibuja_luz)
	luces.add_child(capa_luz)
	# el marco de la granja: damasco de la marca por fuera y el marco fino de latón (ui/marco.png), por encima de las
	# luces y bajo la interfaz
	marco_capa = CanvasLayer.new()
	marco_capa.layer = 2
	marco_capa.follow_viewport_enabled = true
	escena.add_child(marco_capa)
	damasco = load("res://ui/damasco.png")
	marco_caja = StyleBoxTexture.new()
	marco_caja.texture = load("res://ui/marco.png")
	marco_caja.set_texture_margin_all(3)
	marco_caja.draw_center = false
	marco_nodo = Node2D.new()
	marco_nodo.texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED
	marco_nodo.draw.connect(_dibuja_marco)
	marco_capa.add_child(marco_nodo)
	var puntos: Array = E["arroyo"]
	for k in puntos.size() - 1:
		var a := Vector2(puntos[k][0], puntos[k][1])
		var b := Vector2(puntos[k + 1][0], puntos[k + 1][1])
		_corriente.append([a, b, _total, a.distance_to(b)])
		_total += a.distance_to(b)


func suelo_con_trigo(spr: Sprite2D) -> void:
	trigo = ShaderMaterial.new()
	trigo.shader = load("res://trigo.gdshader")
	trigo.set_shader_parameter("sube", load(escena.DATOS + "trigo_sube.png"))
	trigo.set_shader_parameter("tam", spr.texture.get_size())
	spr.material = trigo


func arbol(spr: Sprite2D, mece: Texture2D, x: float) -> void:
	var p: Vector2 = (spr.get_parent() as Node2D).position if spr.get_parent() is Node2D else Vector2(x, 0)
	arboles.append([spr, spr.texture, mece, p])


func pon_molino(spr: Sprite2D, tira_aspas: Texture2D, cuadros: int) -> void:
	molino = spr
	aspas = Sprite2D.new()
	aspas.texture = tira_aspas
	aspas.hframes = cuadros
	aspas.centered = false
	aspas.offset = spr.offset
	aspas.modulate = Color(0, 0, 0, 0)
	aspas.material = spr.material
	spr.get_parent().add_child(aspas)
	spr.get_parent().move_child(aspas, spr.get_index() + 1)


func _prepara_ventanas() -> void:
	for v in E["ventanas"]:
		var r: Array = v["rect"]
		var im := Image.create(int(r[2]) - int(r[0]) + 1, int(r[3]) - int(r[1]) + 1, false, Image.FORMAT_RGBA8)
		# sólo el cristal (lo oscuro del hueco en la pieza): marco, alféizar, dintel y cruz siguen oscuros (crítico r2, 1)
		var mt := _hueco_oscuro("aldea_casita_paja", Rect2i(int(r[0]), int(r[1]), im.get_width(), im.get_height()))
		var mascara: Image = mt.get_image() if mt else null
		for p in v["vidrio"]:
			var xx := int(p[0]) - int(r[0])
			var yy := int(p[1]) - int(r[1])
			if mascara == null:
				im.set_pixel(xx, yy, Color8(int(p[2]), int(p[3]), int(p[4])))
			elif mascara.get_pixel(xx, yy).a > 0.5:
				im.set_pixel(xx, yy, Color(Color("ffc468"), 0.95))
		_ventanas_tex.append([ImageTexture.create_from_image(im), Vector2(float(r[0]), float(r[1]))])


func _hueco_oscuro(pieza: String, r: Rect2i, hondo := false) -> Texture2D:
	## lo oscuro de un hueco de la pieza (el interior de la puerta, el cristal del ventanuco), en blanco: de noche se
	## pinta en cálido justo ahí, sin salirse del dibujo. hondo: un interior con fondo (la puerta del granero): la luz
	## sale del farol de abajo, así que arriba queda en penumbra y los lados en sombra, en escalones de píxel
	var donde := Vector2i(-99999, -99999)
	for sp in E["sprites"]:
		if String(sp[0]) == pieza:
			donde = Vector2i(int(sp[1]), int(sp[2]))
	if donde.x == -99999 or not E["imagenes"].has(pieza):
		return null
	var im := (load(escena.DATOS + E["imagenes"][pieza]["archivo"]) as Texture2D).get_image()
	var sale := Image.create(r.size.x, r.size.y, false, Image.FORMAT_RGBA8)
	for yy in r.size.y:
		for xx in r.size.x:
			var q := Vector2i(r.position.x + xx - donde.x, r.position.y + yy - donde.y)
			if q.x < 0 or q.y < 0 or q.x >= im.get_width() or q.y >= im.get_height():
				continue
			var c := im.get_pixel(q.x, q.y)
			if c.a > 0.5 and c.get_luminance() < 0.2:
				sale.set_pixel(xx, yy, Color.WHITE)
	if hondo:
		var arriba := r.size.y
		var abajo := 0
		for yy in r.size.y:
			for xx in r.size.x:
				if sale.get_pixel(xx, yy).a > 0.5:
					arriba = mini(arriba, yy)
					abajo = maxi(abajo, yy)
		var alto_h := maxf(1.0, float(abajo - arriba))
		for yy in r.size.y:
			var u := float(yy - arriba) / alto_h
			var col := Color8(196, 112, 56, 140) if u < 0.3 else (Color8(236, 160, 80, 200) if u < 0.62 else Color8(255, 206, 120, 240))
			var izq := -1
			var der := -1
			for xx in r.size.x:
				if sale.get_pixel(xx, yy).a > 0.5:
					if izq < 0:
						izq = xx
					der = xx
			for xx in r.size.x:
				if sale.get_pixel(xx, yy).a > 0.5:
					var c2 := col
					if xx - izq < 3 or der - xx < 3:
						c2 = Color(col.r * 0.72, col.g * 0.62, col.b * 0.6, col.a * 0.85)   # el canto del hueco, en sombra
					sale.set_pixel(xx, yy, c2)
	return ImageTexture.create_from_image(sale)


func _elipse_tex(r: Vector2) -> Texture2D:
	var clave := str(r)
	if not _elipses.has(clave):
		var w := int(r.x) * 2 + 3
		var h := int(r.y) * 2 + 1
		var im := Image.create(w, h, false, Image.FORMAT_RGBA8)
		for yy in h:
			var dy := (yy - r.y) / r.y
			if absf(dy) > 1.0:
				continue
			var ancho := r.x * sqrt(1.0 - dy * dy)
			for xx in range(int(roundf(r.x + 1 - ancho)), int(roundf(r.x + 1 + ancho)) + 1):
				if xx >= 0 and xx < w:
					im.set_pixel(xx, yy, Color.WHITE)
		_elipses[clave] = ImageTexture.create_from_image(im)
	return _elipses[clave]


func echa_grano(p: Vector2, hacia: String) -> void:
	## el gesto de echar grano: cae 0,6 s después, a 30 px delante, y se va picoteando de los 4,5 a los 9 s
	granos.append([p + Vector2(30 if hacia == "east" else -30, 2), 0.0])


func es_agua(x: int, y: int) -> bool:
	if x < 0 or y < 0 or x >= agua.get_width() or y >= agua.get_height():
		return false
	return agua.get_pixel(x, y).r > 0.5


func _ola(p: Vector2) -> float:
	## la ráfaga: una sola ola en diagonal cada 10 s que cruza matas, trigo y copas a la vez (crítico 26-10, punto 8)
	return cos(TAU * ((p.x * 0.8 + p.y * 0.6) / 300.0 - t / 10000.0))


func _franja(h: float, a: float, b: float, sube: float, baja: float) -> float:
	## 0..1: entre las horas a y b (con vuelta al día), entrando en `sube` segundos y saliendo en `baja`
	var dur := fposmod(b - a, 600.0)
	var u := fposmod(h - a, 600.0)
	if u >= dur:
		return 0.0
	return clampf(minf(u / sube, (dur - u) / baja), 0.0, 1.0)


func avanza(delta: float, oscuridad: float, ventanas: float) -> void:
	us["cuadros"] += 1
	t += delta * 1000.0
	n = oscuridad
	ventanas_f = ventanas
	var h: float = escena.hora
	neblina = _franja(h, 555.0, 60.0, 15.0, 30.0)   # al alba y a primera hora
	lluvia = _franja(h, 248.0, 292.0, 6.0, 8.0)     # una llovizna corta a media tarde, una vez por día
	lluvia *= 1.0 - escena.invierno                   # en invierno no llueve: nieva
	# el bloque de píxel: lo que mide un píxel de pantalla en el mundo (1 de cerca)
	var s_antes := s
	if escena.cam != null:
		var e: float = escena._escala_pantalla()
		s = maxf(1.0, ceilf(1.0 / (escena.cam.zoom.x * e) - 0.001))
	if trigo:
		trigo.set_shader_parameter("t", t / 1000.0)
		trigo.set_shader_parameter("dia", clampf(1.0 - n * 1.6, 0.0, 1.0))
		trigo.set_shader_parameter("mojado", lluvia)
	var me := espuma.material as ShaderMaterial
	me.set_shader_parameter("t", t)
	me.set_shader_parameter("bloque", s)
	me.set_shader_parameter("fuerza", 1.0 - 0.5 * n)
	(nubes.material as ShaderMaterial).set_shader_parameter("t", t)
	azul.modulate.a = 0.35 * n
	for a in arboles:
		a[0].texture = a[2] if _ola(a[3]) > 0.3 else a[1]
	if molino:
		var k := int(fmod(t, 1250.0) * molino.hframes / 1250.0)
		molino.frame = k
		aspas.frame = k
		aspas.modulate = Color(0, 0, 0, 0.25 * n)   # de noche, las aspas un 25 % más oscuras
	for g in granos:
		g[1] += delta * 1000.0
	granos = granos.filter(func(g): return g[1] < 9000.0)
	_mira_matas()
	# el marco va con la cámara: se redibuja sólo si la vista ha cambiado
	var vista: Transform2D = escena.get_viewport().get_canvas_transform()
	if vista != _vista_antes:
		_vista_antes = vista
		marco_nodo.queue_redraw()
	_paso_px += delta
	if _paso_px >= 1.0 / 15.0 or s != s_antes:
		_paso_px = 0.0
		suelo.queue_redraw()
		alto.queue_redraw()
		capa_luz.queue_redraw()


func _px(c: CanvasItem, x: float, y: float, col: Color) -> void:
	# un «píxel» de efecto: un bloque de s × s pegado a la rejilla de s (1 px de pantalla como mínimo)
	c.draw_rect(Rect2(floorf(x / s) * s, floorf(y / s) * s, s, s), col)


func _pf(c: CanvasItem, x: float, y: float, i: float, j: float, col: Color) -> void:
	# un píxel de una figura (abeja, mariposa, hoja…): la figura entera crece con el bloque, sin deformarse
	c.draw_rect(Rect2(floorf(x / s) * s + i * s, floorf(y / s) * s + j * s, s, s), col)


func _en_curva(d: float) -> Array:
	d = fposmod(d, _total)
	for sg in _corriente:
		if d <= sg[2] + sg[3]:
			var u: float = (d - sg[2]) / sg[3]
			var dirv: Vector2 = (sg[1] - sg[0]) / sg[3]
			return [sg[0].lerp(sg[1], u), dirv]
	var ult: Array = _corriente[-1]
	return [ult[1], (ult[1] - ult[0]) / ult[3]]


# ── marco ─────────────────────────────────────────────────────────────────────────────────────────────────────────────
func _dibuja_marco() -> void:
	## en píxeles de la base (los de la interfaz): el damasco a 1:1 y el marco de 3 px, como las placas de la marca
	if escena.cam == null:
		return
	var z: float = escena.cam.zoom.x
	var w := float(E["W"]) * z
	var h := float(E["H"]) * z
	marco_nodo.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE / z)
	var lejos := 6000.0
	for r in [Rect2(-lejos, -lejos, w + 2.0 * lejos, lejos - 3.0), Rect2(-lejos, h + 3.0, w + 2.0 * lejos, lejos),
			Rect2(-lejos, -3.0, lejos - 3.0, h + 6.0), Rect2(w + 3.0, -3.0, lejos, h + 6.0)]:
		# el dibujo del damasco va pegado al mundo (la misma rejilla en los cuatro lados)
		marco_nodo.draw_texture_rect_region(damasco, r, r)
	# sombra de tinta de 2 px abajo y a la derecha, como el banner enmarcado
	marco_nodo.draw_rect(Rect2(-1.0, h + 3.0, w + 6.0, 2.0), Color(TINTA, 0.55))
	marco_nodo.draw_rect(Rect2(w + 3.0, -1.0, 2.0, h + 4.0), Color(TINTA, 0.55))
	marco_nodo.draw_style_box(marco_caja, Rect2(-3.0, -3.0, w + 6.0, h + 6.0))


# ── suelo ─────────────────────────────────────────────────────────────────────────────────────────────────────────────
var us := {"suelo": 0, "alto": 0, "luz": 0, "avanza": 0, "cuadros": 0}


func _dibuja_suelo() -> void:
	var t0 := Time.get_ticks_usec()
	_dibuja_suelo_de_verdad()
	us["suelo"] += Time.get_ticks_usec() - t0


func _dibuja_matas() -> void:
	# matas y flores: las que coge la ráfaga (la misma ola que el trigo), en su posición mecida
	for i in E["matas"].size():
		var m: Array = E["matas"][i]
		var k := ORDEN_MATAS.find(String(m[0]))
		if k < 0:
			continue
		matas_nodo.draw_texture_rect_region(hoja_matas, Rect2(float(m[1]) - 7, float(m[2]) - 13, 14, 14), Rect2(k * 14, 14 * _matas_estado[i], 14, 14))


func _mira_matas() -> void:
	var cambio := false
	for i in E["matas"].size():
		var m: Array = E["matas"][i]
		var e := 1 if _ola(Vector2(float(m[1]), float(m[2]))) > 0.3 else 0
		if _matas_estado[i] != e:
			_matas_estado[i] = e
			cambio = true
	if cambio:
		matas_nodo.queue_redraw()


func _dibuja_suelo_de_verdad() -> void:
	var fino := s <= 1.0   # de cerca, los detalles de un píxel (sombras, filos); de lejos se quedan en la figura
	# el grano del granjero, en el suelo (bajo los animales), cada mota con su sombra
	for g in granos:
		if g[1] < 600.0:
			continue
		var vivos := GRANO_PUNTOS.size() if g[1] < 4500.0 else int(GRANO_PUNTOS.size() * (9000.0 - g[1]) / 4500.0)
		for k in vivos:
			var q: Vector2 = (g[0] + GRANO_PUNTOS[k]).floor()
			if fino:
				_px(suelo, q.x + 1, q.y + 1, GRANO_SOMBRA)
			_px(suelo, q.x, q.y, GRANO[k % 2])
	# corriente del arroyo: guiones claros que bajan (3 vueltas por bucle)
	for k in 46:
		var d := (k / 46.0) * _total + 3.0 * _total * fmod(t, L) / L
		var c := _en_curva(d)
		var p: Vector2 = c[0]
		var dv: Vector2 = c[1]
		var lado := ((k * 7) % 5 - 2) * 3.0
		p = Vector2(p.x - dv.y * lado, p.y + dv.x * lado)
		for j in (3 if k % 3 else 2):
			var q := (p + dv * j * s).round()
			if es_agua(int(q.x), int(q.y)):
				_px(suelo, q.x, q.y, CLARO)
	var el: Array = E["estanque"]["elipse"]
	var x0 := float(el[0])
	var y0 := float(el[1])
	var x1 := float(el[2])
	var y1 := float(el[3])
	# destellos del estanque (crítico 26-10, punto 10: más y más vivos), de 2 × 1
	for k in 40:
		var px := int(x0 + 20 + ((k * 61) % int(x1 - x0 - 40)))
		var py := int(y0 + 16 + ((k * 37) % int(y1 - y0 - 32)))
		if (int(t / 500.0) + k * 3) % 6 < 2:
			for j in 2:
				if es_agua(px + int(j * s), py):
					_pf(suelo, px, py, j, 0, DESTELLO)
	# y destellos sueltos en el arroyo, que también es agua al sol
	for k in 14:
		if (int(t / 450.0) + k * 5) % 7 < 2:
			var x := 300 + k * 66 + (k * 13) % 20
			var y := _agua_en_columna(x)
			if y >= 0:
				_pf(suelo, x, y, 0, 0, DESTELLO)
				_pf(suelo, x, y, 1, 0, DESTELLO)
	# oleaje que deriva despacio (una vuelta cada 15 s)
	var cx := (x0 + x1) / 2.0
	var cy := (y0 + y1) / 2.0
	var rx0 := (x1 - x0) / 2.0
	var ry0 := (y1 - y0) / 2.0
	for k in 34:
		var u := fmod(fmod(k * 0.618, 1.0) + t / 15000.0, 1.0)
		var fy := fmod(k * 0.383, 1.0) * 1.7 - 0.85
		var px := int(cx + (u * 2 - 1) * rx0 * 0.95)
		var py := int(cy + fy * ry0)
		if sin(PI * u) < 0.25:
			continue
		var largo := 3 + k % 3
		for j in largo:
			if es_agua(px + j, py) and es_agua(px + j, py + 1):
				_px(suelo, px + j, py, MEDIO)
				if fino and j > 0 and j < largo - 1:
					_px(suelo, px + j, py + 1, OSCURO)
	# gotas: anillos que se abren (cada uno cada 6 s); con la llovizna, muchos más y también en el arroyo
	var gotas := [Vector2(0.30, 0.35), Vector2(0.72, 0.30), Vector2(0.55, 0.72), Vector2(0.22, 0.68), Vector2(0.82, 0.62)]
	var anillos := []
	for k in gotas.size():
		anillos.append([Vector2(x0 + gotas[k].x * (x1 - x0), y0 + gotas[k].y * (y1 - y0)).floor(), fmod(t + k * 1300.0, 6000.0) / 1500.0, 7.0])
	if lluvia > 0.05:
		for k in int(22 * lluvia):
			var ciclo := 900.0 + (k * 137) % 500
			var vuelta := int((t + k * 311.0) / ciclo)
			var semilla := (vuelta * 7919 + k * 104729) % 1000
			var f := fmod(t + k * 311.0, ciclo) / ciclo
			var q: Vector2
			if k % 3 == 0:   # en el arroyo
				var cc := _en_curva(float(semilla) / 1000.0 * _total)
				q = (cc[0] as Vector2).floor()
			else:
				q = Vector2(x0 + 20 + semilla % int(x1 - x0 - 40), y0 + 14 + (semilla * 7) % int(y1 - y0 - 28))
			anillos.append([q, f, 4.0])
	for an in anillos:
		var f: float = an[1]
		if f >= 1.0:
			continue
		var g: Vector2 = an[0]
		var r: float = 1.0 + f * float(an[2])
		var cuantos := maxi(8, int(r * 5))
		for i in cuantos:
			var ang := TAU * i / cuantos
			var q := Vector2(g.x + r * cos(ang), g.y + r * 0.45 * sin(ang)).round()
			if es_agua(int(q.x), int(q.y)) and (f < 0.6 or i % 2):
				_px(suelo, q.x, q.y, CLARO if sin(ang) < 0 else MEDIO)
	# ondas bajo los patos que nadan: un anillo que se abre, claro arriba y oscuro abajo
	for p in patos:
		for fase in [0.0, 500.0]:
			var r := 4.0 + fmod(t + fase + int(p.x) * 13.0, 1000.0) / 1000.0 * 8.0
			var rx := 6.0 + r
			var ry := 2.0 + r * 0.35
			var cuantos := int(rx * 4 / s)
			for i in cuantos:
				var a := TAU * i / cuantos
				var q := Vector2(p.x + rx * cos(a), p.y + 1 + ry * sin(a)).round()
				if es_agua(int(q.x), int(q.y)) and i % 3:
					_px(suelo, q.x, q.y, CLARO if sin(a) < 0 else OSCURO)


# ── sobre todo ────────────────────────────────────────────────────────────────────────────────────────────────────────
func _dibuja_alto() -> void:
	var t0 := Time.get_ticks_usec()
	_dibuja_alto_de_verdad()
	us["alto"] += Time.get_ticks_usec() - t0


func _dibuja_alto_de_verdad() -> void:
	# los faroles del camino de entrada, colgados de los postes (de día, apagados; de noche los enciende la capa de luz)
	for fa in FAROLES:
		var o: Vector2 = fa[0]
		alto.draw_rect(Rect2(float(fa[2]), o.y - 1, float(fa[3]) - float(fa[2]) + 1, 1), TINTA)   # el brazo
		for j in FAROL.size():
			for i in FAROL[j].length():
				var ch: String = FAROL[j][i]
				if ch != ".":
					alto.draw_rect(Rect2(o.x + i, o.y + j, 1, 1), TINTA if ch == "K" else FAROL_APAGADO)
	# humo de la chimenea: una bocanada cada 600 ms que vive 3 s
	for k in 5:
		var edad := fmod(t + k * 600.0, 3000.0)
		var u := edad / 3000.0
		var c := Vector2(CHIMENEA.x + 22 * u + 3 * sin(edad / 380.0 + k), CHIMENEA.y - 2 - 46 * u)
		var r := 2.5 + 4.5 * u
		var col: Color = HUMO[mini(2, int(u * 3))]
		col.a = 245.0 * pow(1.0 - u, 0.9) / 255.0
		var paso := int(s)
		var ya := int(floorf((c.y - r - 1) / s) * s)
		var xa := int(floorf((c.x - r - 1) / s) * s)
		for yy in range(ya, int(c.y + r) + 2, paso):
			for xx in range(xa, int(c.x + r) + 2, paso):
				var mx := xx + s * 0.5
				var my := yy + s * 0.5
				if (mx - c.x) * (mx - c.x) + (my - c.y) * (my - c.y) <= r * r:
					alto.draw_rect(Rect2(xx, yy, s, s), col)
	_dibuja_neblina()
	_dibuja_lluvia()
	_dibuja_nieve()
	if n > 0.4 or lluvia > 0.4 or escena.invierno > 0.5:
		return   # de noche, con la llovizna o en invierno, sin bichos, mariposas, hojas ni polvo
	var f := TAU * fmod(t, L) / L
	var tt := fmod(t, L)
	# abejas: ochos pequeños sobre el huerto
	for k in ABEJAS.size():
		var x := roundf(ABEJAS[k].x + 14 * sin(f * (20 + k)))
		var y := roundf(ABEJAS[k].y + 6 * sin(f * (40 + 2 * k)) - 8)
		var am := Color8(240, 200, 64)
		var ne := Color8(36, 28, 22)
		var am2 := Color8(196, 150, 40)
		_pf(alto, x, y, 0, 0, am); _pf(alto, x, y, 1, 0, ne); _pf(alto, x, y, 2, 0, am)
		_pf(alto, x, y, 0, 1, am2); _pf(alto, x, y, 1, 1, ne); _pf(alto, x, y, 2, 1, am2)
		var bate := (int(t / 60.0) + k) % 2 == 0
		var ala := Color8(248, 250, 252) if bate else Color8(200, 214, 226)
		_pf(alto, x, y, 0, -1, ala); _pf(alto, x, y, 2, -1, ala)
		if bate:
			_pf(alto, x, y, -1, -1, ala); _pf(alto, x, y, 3, -1, ala)
	# libélulas: quietas y de golpe a otro sitio
	for k in LIBELULAS.size():
		var ruta: Array = LIBELULAS[k]
		var cuantos := ruta.size()
		var tramo := int(30000 / (cuantos * 2))
		var paso := int(tt + k * 900) % (tramo * cuantos)
		var i := paso / tramo
		var u := float(paso % tramo) / tramo
		var a0: Vector2 = ruta[i]
		var a1: Vector2 = ruta[(i + 1) % cuantos]
		u = 0.0 if u < 0.8 else (u - 0.8) / 0.2
		var x := roundf(a0.x + (a1.x - a0.x) * u + (1 if int(t / 100.0) % 2 else 0))
		var y := roundf(a0.y + (a1.y - a0.y) * u - 14)
		for j in 5:
			_pf(alto, x, y, j, 0, Color8(52, 132, 196) if j < 4 else Color8(24, 60, 100))
		var ala2 := Color8(214, 236, 244) if int(t / 50.0) % 2 else Color8(176, 210, 226)
		for dx in [1, 2]:
			_pf(alto, x, y, dx, -1, ala2); _pf(alto, x, y, dx, 1, ala2)
	# mariposas
	for k in MARIPOSAS.size():
		var m: Array = MARIPOSAS[k]
		var x := int(m[0].x + m[1].x * sin(f * (3 + k) + k) + 6 * sin(f * 17 + k))
		var y := int(m[0].y + m[1].y * sin(f * (2 + k) + 2 * k) - 10 + 3 * sin(f * 23 + k))
		var alas: Array = ALAS[(int(t / 120.0) + k) % 2]
		if s <= 1.0:
			_px(alto, x + 2, y + 16, Color8(40, 60, 32))   # su sombra en el suelo, de cerca
		for j in alas.size():
			var fila: String = alas[j]
			for i in fila.length():
				if fila[i] == ".":
					continue
				_pf(alto, x, y, i, j, Color8(40, 30, 26) if fila[i] == "K" else m[2])
	# hojas que se sueltan de las copas
	for k in HOJAS_DE.size():
		for j in 3:
			var u := fmod(tt + k * 1100 + j * 2000, 6000.0) / 4000.0
			if u >= 1.0:
				continue
			var x: float = HOJAS_DE[k].x + (k * 13 + j * 17) % 20 - 10 + 44 * u + 4 * sin(u * 4 * PI + k)
			var y: float = HOJAS_DE[k].y + 34 * u + 2 * sin(u * 6 * PI + j)
			var cols: Array = HOJA_COL[(k + j) % 3]
			var xi := roundf(x)
			var yi := roundf(y)
			if s <= 1.0:
				_px(alto, xi + 1, yi + 6 - int(5 * u), SOMBRA_HOJA)
			if (int(t / 240.0) + k + j) % 2:
				_pf(alto, xi, yi, 0, 0, cols[0]); _pf(alto, xi, yi, 1, 0, cols[0]); _pf(alto, xi, yi, 1, 1, cols[1])
			else:
				_pf(alto, xi, yi, 0, 0, cols[0]); _pf(alto, xi, yi, 0, 1, cols[0]); _pf(alto, xi, yi, 1, 1, cols[1])
	# vilanos con cada ráfaga del trigo
	for k in VILANOS.size():
		var u := fmod(t + k * 450, 10000.0) / 4000.0
		if u >= 1.0:
			continue
		var x := roundf(VILANOS[k].x + 70 * u + 3 * sin(u * 5 * PI + k))
		var y := roundf(VILANOS[k].y + 46 * u + 2 * sin(u * 7 * PI))
		for d in [Vector2(0, -1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, 1)]:
			_pf(alto, x, y, d.x, d.y, Color8(244, 240, 226))
		_pf(alto, x, y, 0, 0, Color8(176, 168, 146))
	# remolino de polvo en la era, cada 15 s
	var ur := fmod(t, 15000.0) / 3000.0
	if ur < 1.0:
		var c := Vector2(REMOLINO.x + 18 * ur, REMOLINO.y - 4 * ur)
		for i in 18:
			var ang := i * 0.7 + ur * 14
			var r := 2 + 8 * ur * (0.5 + i / 30.0)
			if (i + int(ur * 20)) % 4:
				_px(alto, roundf(c.x + r * cos(ang)), roundf(c.y + r * 0.45 * sin(ang) - i * 0.7),
					Color8(232, 206, 160) if i % 2 else Color8(210, 180, 132))


func _dibuja_neblina() -> void:
	## neblina baja al alba (crítico 26-10, punto 9): bandas de 2 px sobre el estanque y el arroyo que derivan con el
	## viento (hacia el sureste, como las nubes)
	if neblina <= 0.0:
		return
	var alto_b := 2.0 * s   # 2 px de pantalla: de lejos también se lee
	var el: Array = E["estanque"]["elipse"]
	var x0 := float(el[0])
	var y0 := float(el[1])
	var x1 := float(el[2])
	var y1 := float(el[3])
	# sobre el estanque: 9 bandas que cruzan despacio de izquierda a derecha y vuelven a entrar
	for k in 9:
		var largo := 34.0 + (k * 23) % 40
		var ancho_e := x1 - x0 + largo
		var x := x0 - largo + fposmod(k * 71.0 + t / 1000.0 * (3.0 + k % 3), ancho_e)
		var y := y0 + 14.0 + float((k * 37) % int(y1 - y0 - 28)) + 1.5 * sin(t / 2600.0 + k)
		var a := (0.24 + 0.10 * float(k % 2)) * neblina
		alto.draw_rect(Rect2(floorf(x / s) * s, floorf(y / s) * s, floorf(largo / s) * s, alto_b), Color(NEBLINA, a))
	# sobre el arroyo: bandas a lo largo de su curso, que también derivan
	for k in 14:
		var c := _en_curva(fposmod(k / 14.0 * _total + t / 1000.0 * 4.0, _total))
		var p: Vector2 = c[0]
		var largo := 26.0 + (k * 17) % 30
		var a := (0.24 + 0.10 * float((k + 1) % 2)) * neblina
		var y := p.y - 2.0 + float(k % 3) * 2.0
		alto.draw_rect(Rect2(floorf((p.x - largo / 2.0) / s) * s, floorf(y / s) * s, floorf(largo / s) * s, alto_b), Color(NEBLINA, a))


func _dibuja_lluvia() -> void:
	## llovizna corta (crítico 26-10, punto 9): rayas de 1 × 3 que caen con el viento por toda la granja
	if lluvia <= 0.0:
		return
	var w := float(E["W"])
	var h := float(E["H"])
	var col := Color(LLUVIA, 0.6 * lluvia)
	for k in 460:
		var vel := 0.30 + 0.06 * float(k % 4)   # px por ms
		var recorrido := h + 40.0
		var y := fposmod(float((k * 397) % 720) + t * vel, recorrido) - 20.0
		var x := fposmod(float((k * 733) % 1280) + y * 0.25, w)
		alto.draw_rect(Rect2(floorf(x / s) * s, floorf(y / s) * s, s, 3.0 * s), col)


func _dibuja_nieve() -> void:
	## la nevada del invierno (Game Off, SHIFT): copos de 1 px y algunos en cruz de 3 px, que caen despacio y se mecen.
	## Copo blanco con un píxel azul de la rampa de nieve debajo: sobre la nieve del suelo también se lee
	var f := escena.invierno as float
	if f <= 0.0:
		return
	var w := float(E["W"])
	var h := float(E["H"])
	for k in int(1500 * f):
		var vel := 0.022 + 0.008 * float(k % 5)   # px por ms: unos 25-50 px por segundo
		var recorrido := h + 40.0
		var y := fposmod(float((k * 397) % 720) + t * vel, recorrido) - 20.0
		var x := fposmod(float((k * 733) % 1280) + 6.0 * sin(t / 900.0 + k) + y * 0.08, w)
		var xi := floorf(x / s) * s
		var yi := floorf(y / s) * s
		if k % 4 == 0:
			alto.draw_rect(Rect2(xi - s, yi, 3.0 * s, s), COPO)
			alto.draw_rect(Rect2(xi, yi - s, s, 3.0 * s), COPO)
			alto.draw_rect(Rect2(xi, yi + 2.0 * s, s, s), COPO_SOMBRA)
		else:
			alto.draw_rect(Rect2(xi, yi, s, s), COPO)
			alto.draw_rect(Rect2(xi, yi + s, s, s), COPO_SOMBRA)


# ── lo que da luz de noche ────────────────────────────────────────────────────────────────────────────────────────────
func _dibuja_luz() -> void:
	var t0 := Time.get_ticks_usec()
	_dibuja_luz_de_verdad()
	us["luz"] += Time.get_ticks_usec() - t0


func _dibuja_luz_de_verdad() -> void:
	var f := ventanas_f
	if f > 0.0:
		var parpadeo := 0.92 + 0.08 * sin(t / 170.0)
		for v in E["ventanas"]:
			var r: Array = v["rect"]
			var c := Vector2((r[0] + r[2]) / 2.0, (r[1] + r[3]) / 2.0)
			# halo en dos escalones sobre el muro (más en la buhardilla); crítico 26-10: más fuertes
			if not v["buhardilla"]:   # la buhardilla lleva UN halo para las dos (abajo; crítico r2, 1)
				for hh in [[16.0, 0.14], [10.0, 0.26]]:
					_elipse(capa_luz, c, Vector2(hh[0] * 1.2, hh[0]), Color(CALIDA, hh[1] * f))
			if v["charco"].size() == 2:   # charco de luz en el suelo, en dos escalones
				var ch := Vector2(v["charco"][0], v["charco"][1])
				_elipse(capa_luz, ch, Vector2(22, 7), Color(CALIDA, 0.18 * f))
				_elipse(capa_luz, ch, Vector2(15, 5), Color(CALIDA, 0.34 * f))
		var bh := []   # el halo único de la buhardilla, centrado entre sus dos ventanas
		for v in E["ventanas"]:
			if v["buhardilla"]:
				bh.append(Vector2((v["rect"][0] + v["rect"][2]) / 2.0, (v["rect"][1] + v["rect"][3]) / 2.0))
		if bh.size() > 0:
			var cb := Vector2.ZERO
			for q in bh:
				cb += q / bh.size()
			_elipse(capa_luz, cb, Vector2(30, 16), Color(CALIDA, 0.14 * f))
			_elipse(capa_luz, cb, Vector2(20, 11), Color(CALIDA, 0.24 * f))
		for vt in _ventanas_tex:   # el cristal, en cálido (con su parpadeo leve)
			capa_luz.draw_texture(vt[0], vt[1], Color(parpadeo, parpadeo, parpadeo, f))
		for v in E["ventanas"]:    # y en su centro, un punto vivo
			var r: Array = v["rect"]
			_pl(floorf((r[0] + r[2]) / 2.0), floorf((r[1] + r[3]) / 2.0), Color(NUCLEO, f))
		# la puerta del granero, con el farol de dentro encendido, y su charco en la era
		if _granero_tex:
			var pc := Vector2(GRANERO_PUERTA.get_center())
			_elipse(capa_luz, pc, Vector2(30, 22), Color(CALIDA, 0.10 * f))
			_elipse(capa_luz, GRANERO_CHARCO, Vector2(26, 8), Color(CALIDA, 0.18 * f))
			_elipse(capa_luz, GRANERO_CHARCO, Vector2(17, 5), Color(CALIDA, 0.34 * f))
			capa_luz.draw_texture(_granero_tex, Vector2(GRANERO_PUERTA.position), Color(1, 1, 1, f * parpadeo))
		# el ventanuco del gallinero, con su charco pequeño
		if _gallinero_tex:
			var gc := Vector2(GALLINERO_VENTANA.get_center())
			_elipse(capa_luz, gc, Vector2(12, 10), Color(CALIDA, 0.14 * f))
			_elipse(capa_luz, GALLINERO_CHARCO, Vector2(10, 4), Color(CALIDA, 0.26 * f))
			capa_luz.draw_texture(_gallinero_tex, Vector2(GALLINERO_VENTANA.position), Color(CALIDA, 0.9 * f))
		# los faroles del camino: núcleo de 2 × 2, halo y charco en el suelo
		for fa in FAROLES:
			var o: Vector2 = fa[0]
			var nucleo := o + Vector2(1.5, 3)   # el centro del cristal (3 × 3)
			_elipse(capa_luz, nucleo, Vector2(12 * 1.2, 12), Color(CALIDA, 0.16 * f))
			_elipse(capa_luz, fa[1], Vector2(18, 6), Color(CALIDA, 0.22 * f))
			capa_luz.draw_rect(Rect2(o.x + 1, o.y + 2, 3, 3), Color(CALIDA, f))   # el cristal encendido
			var lado := maxf(2.0, s)
			capa_luz.draw_rect(Rect2(floorf((o.x + 2) / s) * s, floorf((o.y + 3) / s) * s, lado, lado), Color(NUCLEO, f * parpadeo))
	if n < 0.35:
		return
	var vis := (n - 0.35) / 0.65
	# la luna en el estanque: una columna de guiones que tiemblan y se apagan a destiempo
	var ys := [604, 611, 618, 626, 634, 641]
	for j in ys.size():
		if (int(t / 330.0) + j * 2) % 6 == 0:
			continue
		var w := 3 + (j * 5 + int(t / 600.0)) % 5
		var xa := 126 - w / 2 + ((int(t / 260.0) * 7 + j * 3) % 3) - 1
		for x in range(xa, xa + w, int(s)):
			if es_agua(x, ys[j]):
				_pl(x, ys[j], Color(REFLEJO, vis * 0.85))
	# destellos de luna en el arroyo
	for k in 10:
		if (int(t / 400.0) + k * 3) % 5 < 2:
			var x := 330 + k * 92
			var y := _agua_en_columna(x)
			if y >= 0:
				capa_luz.draw_rect(Rect2(floorf(x / s) * s, floorf(y / s) * s, 2.0 * s, s), Color(LUNA, vis))
	# luciérnagas: núcleo vivo y halo verde al 50 %, encendidas 5 de cada 9 pasos
	var fl := TAU * fmod(t, L) / L
	var halo_l := Color(LUCIERNAGA_HALO, 0.5 * vis)
	var nucleo_l := Color(LUCIERNAGA, vis)
	for k in LUCIERNAGAS.size():
		if (int(t / 250.0) + k * 5) % 9 >= 5:
			continue
		var x := int(LUCIERNAGAS[k].x + 14 * sin(fl * (2 + k % 3) + k) + 5 * sin(fl * 7 + k))
		var y := int(LUCIERNAGAS[k].y + 8 * sin(fl * (3 + k % 2) + 2 * k))
		var bx := floorf(x / s) * s
		var by := floorf(y / s) * s
		for d in [Vector2(1, 0), Vector2(-1, 0), Vector2(0, 1), Vector2(0, -1)]:
			capa_luz.draw_rect(Rect2(bx + d.x * s, by + d.y * s, s, s), halo_l)
		capa_luz.draw_rect(Rect2(bx, by, s, s), nucleo_l)


func _pl(x: float, y: float, col: Color) -> void:
	# un píxel de luz, en bloque de s × s
	capa_luz.draw_rect(Rect2(floorf(x / s) * s, floorf(y / s) * s, s, s), col)


var _columnas := {}


func _agua_en_columna(x: int) -> int:
	if not _columnas.has(x):
		var ys := []
		for y in range(601, agua.get_height()):
			if es_agua(x, y):
				ys.append(y)
		_columnas[x] = ys[ys.size() / 2] if not ys.is_empty() else -1
	return _columnas[x]


func _elipse(c: CanvasItem, centro: Vector2, r: Vector2, col: Color) -> void:
	# elipse llena de píxel entero (sin degradado), de una textura precalculada
	c.draw_texture(_elipse_tex(r), (centro - Vector2(r.x + 1, r.y)).round(), col)

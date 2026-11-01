class_name Actor
extends Node2D
## Un animal del pack. Encadena sus propias animaciones (reposo, andar, comer, dormir, su acción propia) con el
## ritmo real de cada fotograma (_ritmo.json del pack) y sin cortes: lo que empieza con _start acaba con _end, y un
## paso sólo se para sobre una pisada. Qué hace y con quién va lo dice la tabla de especies (comportamiento.gd,
## sacada de docs/COMPORTAMIENTO_ESCENA.md). La posición del nodo son los pies: el Y-sort ordena por ahí.

const Comp := preload("res://comportamiento.gd")
const VECTOR := {"east": Vector2(1, 0), "west": Vector2(-1, 0), "south": Vector2(0, 1), "north": Vector2(0, -1)}

var nombre: String
var base: String
var d: Dictionary          # datos del animal: atlas, tamaño, pie, anims {anim: {dir: {fila, ms}}}, en
var sp: Dictionary         # su especie
var zona: Dictionary       # {b: Rect2, ok: Callable o null}
var mundo                  # la escena (libre, a_la_vista, por_nombre)
var dir := "south"
var cola: Array = []
var paso: Dictionary = {}
var pide = null
var act := "idle"
var fotograma := 0
var t := 0.0
var vueltas := 1
var llego := false
var margen := 0.0
var t_onda := 0.0
var spr: Sprite2D
var mando := Vector2.ZERO  # hacia dónde lo lleva quien juega (WASD), o nada
var corre := false         # con mayúsculas, corre
var manual := false        # lo lleva quien juega; a los seis segundos sin tocarlo vuelve a su vida
var toque := 0.0


func prepara(n: String, datos: Dictionary, textura: Texture2D, escena) -> void:
	nombre = n
	base = n.split("_")[0]
	d = datos
	mundo = escena
	sp = _especie(n)
	zona = escena.zonas.get(sp["zona"], {"b": Rect2(0, 0, float(escena.E["W"]), float(escena.E["H"]))})
	margen = max(float(d["sombra"].get("east", 0)), float(d["sombra"].get("west", 0))) * 0.45
	dir = ["south", "west", "east", "north"].pick_random()
	# la sombra en el suelo mientras vuela (el pack no la trae en el bucle de vuelo: la pone el motor)
	_sombra_vuelo = Node2D.new()
	_sombra_vuelo.visible = false
	_sombra_vuelo.draw.connect(_dibuja_sombra_vuelo)
	add_child(_sombra_vuelo)
	spr = Sprite2D.new()
	spr.texture = textura
	spr.centered = false
	spr.region_enabled = true
	spr.offset = Vector2(-int(d["w"]) / 2, -int(d["pie"]))
	add_child(spr)
	_mide_cuerpo(textura)


var meta := Vector2.ZERO   # adónde va andando (o cero)
var _sombra_vuelo: Node2D
var _tendido_hasta := 0.0
var _bloqueado := 0.0
var encargo := false       # lo ha pedido quien juega (ficha): ni apartarse, ni sustos, ni vida social lo pisan  # tras morir, en el suelo hasta este instante (y luego se levanta)
# el guion aprobado de la escena (docs/ENTREGA_ESCENA_GRANJA.md; _tools/vida_granja.py reparto): de día hace exactamente
# lo suyo, con el reloj común (todos sincronizados: el carnero y el macho cabrío se topan, el pavo acude al grano). Sale
# del guion si lo llevan, le dan de comer o lo pulsan, y de noche; vuelve andando a su sitio y entra cuando su guion pasa
# por el principio (que empieza y acaba ahí): sin saltos
const L_GUION := 30000.0
# usuario 25-10: «es un motor de juego, no un vídeo: que cada animal vaya haciendo lo suyo según su naturaleza, social e
# individual, con el día y la noche pasando». El guion aprobado ya no se reproduce: de él sale su NATURALEZA (su sitio,
# su territorio, lo que hace y cuánto, a quién sigue) y la conducta libre decide en cada momento
# en el vídeo de la tienda cada animal hace su guion programado (el del vídeo aprobado), no la conducta libre de la
# demo (usuario 26-10: «programa cada cosa para que haga lo que tiene que hacer; es un vídeo»)
static var REPRODUCE_GUION: bool = "--video" in OS.get_cmdline_user_args()
const PERSONAS := {"granjero": {"zona": "patio", "vel": 16.0, "w": {"idle": 1}},
	"washerwoman": {"zona": "patio", "vel": 15.0, "w": {"idle": 2, "oficio": 1}}}   # usuario 26-10: quietos, sin dar vueltas
var guion := {}
var madre_g: Actor = null   # la cría sigue el guion de su madre
var modo := "libre"         # guion | libre | vuelta | noche
var _tg_prev := 0.0
# el guion de 30 s se repite a lo largo de un día de 10 minutos: para que no se note el bucle, tras unas vueltas cada
# recinto se suelta un rato a su aire (todos los de un recinto a la vez: las escenas a dos no se rompen) y vuelve
var _tg_guion := 0.0
var _vueltas := 0
var _libre_hasta := 0.0
# usuario 25-10: «que se vea todo el abanico de animaciones que tiene cada animal, lo vivo y encadenado que está»: lo que
# hace hace rato que no lo hace pesa más (rotación), así a lo largo de unos minutos sale todo su repertorio
# crítico 26-10: cuenta lo que se VE (lo que empieza de verdad), no lo que decide; si no, la prueba del abanico engaña
var _vistas := {}       # animación -> cuándo empezó por última vez (reloj de la escena)
var modo_noche := ""    # de noche: duerme | vigila | activo | dentro (los granjeros, en casa)
var _fallos := 0        # destinos sin hueco seguidos: al tercero busca en todo su recinto
var en_patio := false   # de día, suelto por el patio (unas gallinas y el pavo); de noche, a su corral
var patio_de_dia := false
var zona_corral := {}   # su zona de siempre (la de noche) cuando de día anda por el patio
var _despertar_pendiente := false
var cama_noche := Vector2.ZERO   # su sitio de esta noche (lo reparte la escena sin pisarse)
var reserva := Vector2.ZERO      # el granjero: el sitio de su tarea, que nadie ocupa mientras va y trabaja
var regreso: Array = []          # y por dónde vuelve de ella (si la tarea es fuera del patio)
var _susto_hasta := 0.0
var _envolvente := Rect2()   # la unión de los cuerpos de las cuatro vistas, relativa a los pies
var _cuerpo := {}   # vista -> Rect2 de los píxeles opacos del idle, relativo a los pies
var _img: Image
var _caja_pista := {}   # fotograma (su xy en el atlas) -> Rect2 de sus píxeles opacos, relativo a los pies
var _caja_suave := Rect2()   # la de las esquinas, que sigue a la del fotograma sin saltos
var _caja_suave_t := 0.0


func _especie(n: String) -> Dictionary:
	## su tabla (comportamiento.gd); una capa de color va con los suyos: la vaca negra con la manada, la yegua blanca
	## junto al semental
	var b := n.split("_")[0]
	var e: Dictionary = Comp.ESPECIE.get(b, PERSONAS.get(n, {"zona": "patio", "vel": 14.0, "w": {"idle": 1}})).duplicate(true)
	if n != b and not e.has("sigue") and Comp.LIDER_VARIANTE.has(b):
		e["sigue"] = Comp.LIDER_VARIANTE[b]
		e["cerca"] = 54.0
		e["lugar"] = "cerca"
		e["rebano"] = b == "Oveja"
	return e


func _mide_cuerpo(textura: Texture2D) -> void:
	var img := textura.get_image()
	# la imagen solo se guarda en el escritorio (pruebas y esquinas finas): cada atlas pesa hasta 120 MB descomprimido
	# y en la web se agotaba la memoria
	_img = null if OS.has_feature("web") else img
	_caja_pista = {}
	if img == null or not d["anims"].has("idle"):
		return
	for v in d["anims"]["idle"]:
		var xy: Array = d["anims"]["idle"][v]["xy"][0]
		var x0 := 9999
		var y0 := 9999
		var x1 := -1
		var y1 := -1
		for y in int(d["h"]):
			for x in int(d["w"]):
				# la sombra es tenue: sólo cuenta lo casi opaco
				if img.get_pixel(int(xy[0]) + x, int(xy[1]) + y).a > 0.7:
					x0 = mini(x0, x)
					y0 = mini(y0, y)
					x1 = maxi(x1, x)
					y1 = maxi(y1, y)
		if x1 >= 0:
			_cuerpo[v] = Rect2(x0 - int(d["w"]) / 2, y0 - int(d["pie"]), x1 - x0 + 1, y1 - y0 + 1)


func transforma(n: String) -> void:
	## el mismo animal, otra capa de color u otro miembro de su especie (macho, hembra, cría), en el mismo sitio
	if not mundo.E["animales"].has(n) or n == nombre:
		return
	var antes := nombre
	if mundo.por_nombre.get(nombre) == self:
		mundo.por_nombre.erase(nombre)
		# crítico 26-10: si queda otro con ese nombre, él pasa a ser el de la lista (si no, su manada se queda sin líder)
		for a in mundo.actores:
			if a != self and a.nombre == antes:
				mundo.por_nombre[antes] = a
				break
	if not mundo.por_nombre.has(n):
		mundo.por_nombre[n] = self
	nombre = n
	base = n.split("_")[0]
	d = mundo.E["animales"][n]
	spr.texture = load(mundo.DATOS + d["archivo"])
	spr.offset = Vector2(-int(d["w"]) / 2, -int(d["pie"]))
	var zona_antes := zona
	sp = _especie(n) if Comp.ESPECIE.has(base) or PERSONAS.has(n) else sp
	zona = zona_antes
	_cuerpo = {}
	_envolvente = Rect2()
	_mide_cuerpo(spr.texture)
	margen = max(float(d["sombra"].get("east", 0)), float(d["sombra"].get("west", 0))) * 0.45
	cola = []
	pide = null
	encargo = false
	# a quién sigue ahora (otra especie, otro papel); y los que le seguían a él, si ya no les vale, buscan a otro
	if guion.get("tipo", "") != "sigue":
		madre_g = null
	busca_lider()
	for a in mundo.actores:
		if a != self and a.madre_g == self and String(a.sp.get("sigue", "")) != base:
			a.madre_g = null
			a.busca_lider()
	# (otro cuerpo, otro tamaño: si ahora toca el decorado, al sitio libre de al lado)
	if mundo.cuerpo_toca(self, position) > 0.0:
		var libre_cerca = destino(position, 30.0)
		if libre_cerca == null:
			libre_cerca = destino()
		if libre_cerca != null:
			position = libre_cerca
	empieza({"anim": "idle", "vueltas": 1})
	dibuja()


func busca_lider() -> void:
	## a quién sigue (crítico 26-10: no por nombre exacto, que las capas de color no lo tienen): el más cercano de su
	## misma zona cuya especie es la que sigue; las crías, mejor con una madre que tenga pocas crías
	if not sp.has("sigue"):
		if guion.get("tipo", "") != "sigue":
			madre_g = null
		return
	var quiere: String = sp["sigue"]
	if madre_g != null and is_instance_valid(madre_g) and madre_g.base == quiere and madre_g.patio_de_dia == patio_de_dia:
		return
	var mejor: Actor = null
	var nota := INF
	for a in mundo.actores:
		if a == self or a.base != quiere or not a.visible and a.modo_noche != "dentro":
			continue
		# nada de círculos: el que ya me sigue (o sigue a quien me sigue) no puede ser mi líder
		var x: Actor = a
		var ciclo := false
		for k in 6:
			x = x.madre_g
			if x == null:
				break
			if x == self:
				ciclo = true
				break
		if ciclo:
			continue
		var crias := 0
		for c in mundo.actores:
			if c.madre_g == a:
				crias += 1
		var misma_zona: bool = String(a.sp.get("zona", "")) == String(sp.get("zona", ""))
		# la que de día anda suelta por el patio no sirve de líder a las del corral (crítico visual 26-10: las gallinas
		# del corral se amontonaban en la verja detrás de la que estaba fuera)
		var mismo_sitio: bool = a.patio_de_dia == patio_de_dia
		var n: float = position.distance_to(a.position) + crias * 400.0 + (0.0 if misma_zona else 5000.0) \
			+ (0.0 if mismo_sitio else 3000.0)
		# crítico visual 26-10: la cría, con una madre de su mismo color (el lechón rosa no mama de la cerda roja)
		n += 0.0 if nombre.trim_prefix(base) == a.nombre.trim_prefix(a.base) else 1500.0
		if n < nota:
			nota = n
			mejor = a
	madre_g = mejor


func tiene(a: String) -> bool:
	return d["anims"].has(a)


func pista() -> Dictionary:
	var a: Dictionary = d["anims"][paso["anim"]]
	if a.has(dir):
		return a[dir]
	return a["south"] if a.has("south") else a.values()[0]


func lider() -> Actor:
	if en_patio:
		return null   # suelto por el patio, de día va a lo suyo
	if madre_g != null:
		# de día, si su líder anda suelta por el patio y él no (o al revés), cada uno a lo suyo
		return madre_g if madre_g.en_patio == en_patio else null
	if sp.has("sigue") and sp["sigue"] != nombre:
		return mundo.por_nombre.get(sp["sigue"])
	return null


func coloca() -> void:
	var l := lider()
	var b: Rect2 = zona["b"]
	var ok := false
	for i in 800:
		var p := Vector2(randf_range(b.position.x, b.end.x), randf_range(b.position.y, b.end.y))
		if l and i < 200:
			p = l.position + Vector2(randf_range(-sp["cerca"], sp["cerca"]), randf_range(-12, 12))
		if mundo.libre(p, zona, margen, self) and mundo.a_la_vista(p) and mundo.espacio(p, self):
			position = p
			ok = true
			break
	if not ok:
		var mejor := b.get_center()
		var menos := INF
		for i in 300:
			var p := Vector2(randf_range(b.position.x, b.end.x), randf_range(b.position.y, b.end.y))
			if not mundo.libre(p, zona, margen, self):
				continue
			var tapa: float = mundo.solape(p, self)
			if tapa < menos:
				menos = tapa
				mejor = p
		position = mejor
	empieza({"anim": "idle", "vueltas": randi_range(1, 3)})
	# desfasados desde el principio: no hay dos animales que respiren a la vez
	fotograma = randi_range(0, pista()["ms"].size() - 1)
	dibuja()


func empieza(p: Dictionary) -> void:
	if mundo and paso.get("anim", "") == "lay_egg" and p.get("anim", "") != "lay_egg":
		_pone_huevo()
		# y se queda encima empollando un rato (como en la viñeta aprobada de las gallinas)
		if tiene("sleep"):
			var empolla: Array = cadena("sleep", 4)
			cola = empolla + cola
			p = cola.pop_front()
	if p.has("mama_en") and (lider() == null or position.distance_to(p["mama_en"]) > 3.0 \
			or position.distance_to(lider().position + p["mama_rel"]) > 3.0):
		# no ha llegado bajo su madre (algo le cortó el paso): no mama en el aire
		cola = cola.filter(func(s): return not s.has("mama_en"))
		p = {"anim": "idle", "vueltas": 1}
	paso = p
	if mundo:
		mundo.suena(self, p["anim"])
		_vistas[p["anim"]] = mundo.reloj
	# la meta es sólo mientras va hacia ella: parado no reserva nada (crítico 26-10: reservas fantasma)
	if p.has("a"):
		meta = p["a"]
	else:
		var anda_luego := false
		for s in cola:
			if s.has("a"):
				anda_luego = true
				break
		if not anda_luego:
			meta = Vector2.ZERO
	fotograma = 0
	t = 0.0
	vueltas = p.get("vueltas", 1)
	llego = false
	_andado = 0.0
	if p.has("mira") and p["mira"] != null:
		dir = p["mira"]
	if p.get("dentro", false):
		visible = false   # ha entrado en casa
	if p["anim"] == "grano" and mundo and not REPRODUCE_GUION:
		mundo.echa_grano(position, dir)
	if p.has("acuden") and mundo:
		mundo._acuden(p["acuden"][0], p["acuden"][1])   # el granjero ya está en la verja (o se va del bebedero)


func siguiente() -> void:
	if pide != null:
		# tendido tras morir, lo que le pidan (un clic, comida, la ficha) espera a que se levante deshaciendo la caída:
		# nunca salta del suelo a estar de pie
		if paso.get("anim", "") == "death" and paso.has("tendido") and not (pide.size() > 0 and pide[0].get("reversa", false)):
			pide = [{"anim": "death", "reversa": true}] + pide
		cola = pide
		pide = null
	if cola.is_empty():
		decide()
	empieza(cola.pop_front())


func cadena(anim: String, n: int, mira = null) -> Array:
	var c := []
	if tiene(anim + "_start"):
		c.append({"anim": anim + "_start", "mira": mira})
	c.append({"anim": anim, "vueltas": n, "mira": mira})
	if tiene(anim + "_end"):
		c.append({"anim": anim + "_end"})
	return c


func ir(p: Vector2, correr: bool, desde = null) -> Array:
	## hasta p (desde donde está, o desde otro punto si va después de otro tramo)
	meta = p   # adónde va: los demás no eligen ese sitio mientras tanto
	var de: Vector2 = position if desde == null else desde
	var anim := "run" if correr and tiene("run") else "walk"
	if tiene("swim") and mundo.agua(p) and mundo.agua(de):
		anim = "swim"   # en el agua se nada, con su animación
	var vel: float = sp.get("corre", sp["vel"] * 2.5) if anim == "run" else sp["vel"]
	var c := []
	if tiene(anim + "_start"):
		c.append({"anim": anim + "_start"})
	c.append({"anim": anim, "a": p, "vel": vel})
	if tiene(anim + "_end"):
		c.append({"anim": anim + "_end"})
	return c


func destino(centro = null, r := 0.0):
	var b: Rect2 = zona["b"]
	if _fallos >= 3:
		centro = null   # tres veces seguidas sin hueco alrededor: en todo su recinto
	# fuera de su sitio (le han llevado, ha ido a defender o a comer a la verja), el camino de vuelta no se mira: si
	# no, no encontraría nunca adónde ir
	var fuera: bool = not mundo.libre(position, zona, margen, self)   # (también si está tocando el decorado: sale de ahí)
	for i in 30:
		var p: Vector2
		if centro == null:
			p = Vector2(randf_range(b.position.x, b.end.x), randf_range(b.position.y, b.end.y))
		else:
			p = centro + Vector2(randf_range(-r, r), randf_range(-r * 0.5, r * 0.5))
		if p.distance_to(position) > 10 and mundo.libre(p, zona, margen, self) and mundo.a_la_vista(p) \
				and mundo.espacio(p, self) and (fuera or mundo.camino_libre(position, p, zona, margen, self)):
			_fallos = 0
			return p
	_fallos += 1
	return null


func destino_seguro(centro = null, r := 0.0):
	## adónde apartarse siempre: el sitio libre si lo hay; si no, el de su recinto que menos tapa a los demás (como en
	## coloca()), sin mirar si se ve o si el camino está despejado; nada si no mejora lo de ahora
	var p = destino(centro, r)
	if p == null and centro != null:
		p = destino()
	if p != null:
		return p
	var b: Rect2 = zona["b"]
	var mejor = null
	var menos: float = mundo.solape(position, self) - 1.0
	for i in 60:
		var q := Vector2(randf_range(b.position.x, b.end.x), randf_range(b.position.y, b.end.y))
		if q.distance_to(position) < 6.0 or not mundo.libre(q, zona, margen, self):
			continue
		var tapa: float = mundo.solape(q, self)
		if tapa < menos:
			menos = tapa
			mejor = q
	return mejor


func ir_por(puntos: Array, correr := false) -> Array:
	## andando por varios puntos seguidos sin pararse en los de paso (la verja), con un solo arranque y una parada
	var c := ir(puntos[-1], correr)
	for k in range(c.size()):
		if c[k].has("a"):
			for j in range(puntos.size() - 2, -1, -1):
				var s: Dictionary = c[k].duplicate()
				s["a"] = puntos[j]
				c.insert(k, s)
			break
	return c


func camino(p: Vector2, correr := false) -> Array:
	## hasta p; si hay que cruzar la valla de un recinto (al patio, a su sitio de noche), por su verja
	var puntos: Array = []
	var de: String = mundo.recinto_de(position)
	var a: String = mundo.recinto_de(p)
	if de != a:
		if de != "":
			var v: Dictionary = mundo.verja(de, position)
			puntos += [v["dentro"], v["fuera"]]
		if a != "":
			var v2: Dictionary = mundo.verja(a, p)
			puntos += [v2["fuera"], v2["dentro"]]
	if puntos.is_empty() and position.distance_to(p) <= 1.5:
		return []
	return ir_por(puntos + [p], correr)


func junto(l: Actor) -> Vector2:
	# dónde quiere estar respecto a quien sigue: detrás en fila, al lado, o cerca sin más
	# cada uno de los que le siguen tiene su hueco (crítico 26-10: dos crías de la misma madre iban al mismo sitio, «detrás»
	# o a un lado echado a suertes, y se quedaban una encima de otra): en fila, uno detrás de otro; al lado, uno a cada lado
	var k := 0
	var antes_de_mi := 0.0
	for a in mundo.actores:
		if a == self:
			break
		if a.lider() == l and a.sp.get("lugar", "cerca") == sp.get("lugar", "cerca"):
			k += 1
			antes_de_mi += a.huella(Vector2.ZERO).size.x + 3.0
	var v: Vector2 = VECTOR[l.dir]
	var sep: float = (huella(Vector2.ZERO).size.x + l.huella(Vector2.ZERO).size.x) / 2.0 + 3.0
	var lado := 1.0 if k % 2 == 0 else -1.0
	match sp.get("lugar", "cerca"):
		"detras":
			var s2: float = sep + antes_de_mi
			return l.position - Vector2(v.x * s2, v.y * s2 * 0.6)
		"lado":
			var s3: float = sep + (antes_de_mi if k >= 2 else 0.0)
			return l.position + Vector2(s3 * lado if v.y != 0 else randf_range(-6, 6), 12 * lado if v.x != 0 else 0.0)
	return l.position + Vector2(randf_range(-sp["cerca"], sp["cerca"]), randf_range(-14, 14))


func _va_de_camino() -> bool:
	if paso.has("a"):
		return true
	for st in cola:
		if st.has("a"):
			return true
	return false


func aparta():
	## crítico 26-10: se aparta lo justo de los que tiene encima, hacia el lado contrario (los cuerpos son altos: de lado
	## se separan antes); si contra la valla no puede, hacia el otro lado o arriba y abajo
	var empuje := Vector2.ZERO
	var mia := huella(position).grow(-2.0)
	for a in mundo.actores:
		if a == self or not a.visible or a == lider() or a.lider() == self:
			continue
		var otra: Rect2 = a.huella(a.position).grow(-2.0)
		if not mia.intersects(otra):
			continue
		var cruce := mia.intersection(otra)
		var lado := 1.0 if position.x > a.position.x else -1.0
		if absf(position.x - a.position.x) < 0.5:
			lado = 1.0 if get_instance_id() > a.get_instance_id() else -1.0
		empuje.x += lado * (cruce.size.x + 3.0)
	if empuje == Vector2.ZERO:
		return null
	for intento in [empuje, empuje * 1.5, empuje + Vector2(0, 10), empuje + Vector2(0, -10), -empuje * 1.2, empuje * 2.2,
			Vector2(0, 18), Vector2(0, -18)]:
		var q: Vector2 = position + intento
		if mundo.libre(q, zona, margen, self) and mundo.espacio(q, self):
			return q
	return null


func decide() -> void:
	encargo = false   # lo pedido ya se hizo entero
	reserva = Vector2.ZERO   # (y la tarea del granjero, acabada)
	if PERSONAS.has(nombre) and not regreso.is_empty() and not mundo.libre(position, zona, 0.0):
		# un granjero fuera del patio (le cortaron la tarea): vuelve por donde fue, no en línea recta por los recintos
		cola = ir_por(regreso) + cadena("idle", 1)
		regreso = []
		return
	regreso = []
	if manual:
		cola = cadena("idle", 1)
		return
	if modo == "noche":
		cola = _noche_quieto()
		return
	if not mundo.espacio(position, self) and modo == "libre" and act != "mamar":
		var aparte = aparta()
		if aparte == null:
			aparte = destino_seguro(position, 30.0)
		if aparte != null:
			cola = ir(aparte, false) + cadena("idle", 1)
			return
	if REPRODUCE_GUION and not guion.is_empty() and modo == "libre":
		var madre_suelta: bool = guion.get("tipo", "") == "sigue" and madre_g != null and madre_g.modo == "libre"
		if mundo.reloj >= _libre_hasta and not madre_suelta:
			vuelve_al_guion()
			return
		# a su aire en su recinto (la cría, detrás de su madre): la conducta libre de siempre, abajo
	if modo == "vuelta":
		cola = cadena("idle", 1)
		return
	var l := lider()
	if l:
		var dist := position.distance_to(l.position)
		# crítico 26-10: junto() le pone a una distancia de cuerpo a cuerpo que ya es más que «cerca» (cordero 44 contra
		# 20): con el umbral en «cerca» la cría no paraba nunca de perseguir a su madre
		var sep: float = (huella(Vector2.ZERO).size.x + l.huella(Vector2.ZERO).size.x) / 2.0 + 3.0
		var umbral: float = maxf(float(sp["cerca"]), sep + 12.0)
		# (si lleva ya rato sin hacer algo de su repertorio, a veces lo hace antes de ir tras ella)
		if dist > umbral * 1.5 and not (_deuda_vieja() and randf() < 0.5):
			var p = destino(junto(l), 8.0)
			if p == null:
				p = destino(l.position, umbral)
			if p != null:
				cola = ir(p, dist > umbral * 3.0 and sp.has("corre"))
				return
		elif l.act == "eat" and randf() < 0.4 and not mundo.cerca_de_comedero(self, position):
			# un rebaño pasta todo mirando hacia el mismo lado
			act = "eat"
			cola = cadena("eat", randi_range(2, 5), l.dir if sp.get("rebano", false) else null)
			return
	if mundo.noche and tiene("sleep") and modo_noche != "activo" and randf() < 0.8:
		# de noche duerme quien tiene dónde
		act = "sleep"
		cola = cadena("sleep", randi_range(10, 20))
		return
	var pesos: Dictionary = sp["w"].duplicate()
	for a in d["anims"]:
		if a.ends_with("_start") or a.ends_with("_end") or a in Comp.NO_PROPIAS or pesos.has(a):
			continue
		pesos[a] = 0.6 if a in Comp.VOCES else 0.3
	if tiene("eat") and not pesos.has("eat"):
		pesos["eat"] = 1.0
	if tiene("run") and not pesos.has("run"):
		pesos["run"] = 0.9 if sp.has("sigue") else 0.35   # las crías juegan corriendo; los mayores, de vez en cuando
	# rotación: lo que hace rato que no se le ve gana peso (hasta 5 veces), para que salga todo su repertorio
	for a in pesos.keys():
		if a in ["idle", "walk"]:
			continue
		var hace: float = mundo.reloj - float(_vistas.get(a, -200.0))
		pesos[a] = float(pesos[a]) * (1.0 + clampf(hace / 45.0, 0.0, 4.0))
	if Comp.MAMAN.has(base) and l and position.distance_to(l.position) < 120:
		pesos["mamar"] = Comp.MAMAN[base]
	var total := 0.0
	for a in pesos:
		if a in ["walk", "mamar", "salir"] or (a == "volar" and tiene("fly")) or tiene(a):
			total += pesos[a]
	var r := randf() * total
	act = "idle"
	for a in pesos:
		if a in ["walk", "mamar", "salir"] or (a == "volar" and tiene("fly")) or tiene(a):
			r -= pesos[a]
			if r <= 0:
				act = a
				break
	# crítico 26-10: con la rotación sola, a los tres minutos todo pesa igual de saturado y lo raro (poner un huevo,
	# el gluglú, embestir) no sale nunca. Deudas: de lo que tiene, lo que hace 75 s que no se le ve; a veces, lo más
	# antiguo pasa delante de todo
	var deuda := ""
	var mas_vieja := INF
	var empatadas: Array = []   # las que llevan igual de tiempo sin verse (nunca): una al azar
	var opciones: Array = pesos.keys()
	if Comp.MAMAN.has(base) and l and not "mamar" in opciones:
		opciones.append("mamar")   # lejos de su madre también: va a ella a mamar
	# todo su repertorio salvo la muerte (decisión del usuario 26-10: nunca muere solo): también la siesta, el vuelo,
	# nadar y el respingo (hurt), que no se eligen por peso
	for extra in ["hurt", "swim", "sleep", "walk"]:
		if tiene(extra) and not extra in opciones:
			opciones.append(extra)
	# (andar también: el ratón sólo corre, y las aves de agua, en el agua, todo su andar es nadar)
	for a in opciones:
		if a in ["idle", "salir", "death"]:
			continue
		var anim: String = {"mamar": "suckle", "volar": "fly"}.get(a, a)
		if not tiene(anim):
			continue
		var vista: float = float(_vistas.get(anim, -999.0))
		if mundo.reloj - vista >= 75.0 and vista < mas_vieja:
			mas_vieja = vista
			deuda = a
			empatadas = [a]
		elif mundo.reloj - vista >= 75.0 and vista == mas_vieja:
			empatadas.append(a)
	# lo que no se le ha visto nunca, pasados dos minutos y medio, casi seguro
	var por_deuda := deuda != "" and randf() < (0.85 if mas_vieja < -900.0 and mundo.reloj > 150.0 else 0.4)
	if por_deuda:
		act = empatadas.pick_random()
	match act:
		"mamar":
			var m := mamar(l, por_deuda)
			if not m.is_empty():
				cola = m
				return
			cola = cadena("idle", 2)
		"salir":
			if sal_por_la_puerta():
				return
			cola = cadena("idle", 2)
		"volar":
			var pv = destino_vuelo()
			cola = vuelo(pv) if pv != null else cadena("idle", 2)
		"walk", "run":
			# el ratón va pegado a la pared: corre a lo largo y se para
			var p = destino(Vector2(randf_range(zona["b"].position.x, zona["b"].end.x), position.y), 4.0) \
				if base == "Raton" else destino()
			if tiene("swim") and (act == "run" or por_deuda):
				# las aves de agua corren (y, a veces, andan) por la orilla, no sobre el agua
				for k in 6:
					if p == null or not mundo.agua(p):
						break
					p = destino()
				if p != null and mundo.agua(p):
					p = null
			if p == null and act == "run":
				p = destino_seguro()   # correr no se queda en nada por no encontrar un sitio perfecto
				if p != null and tiene("swim") and mundo.agua(p):
					p = null
			cola = ir(p, act == "run") if p != null else cadena("idle", 2)
			if p != null and act == "walk" and (base in Comp.MANADA or sp.get("rebano", false)):
				mundo.arrastra_grupo(self, p)   # el rebaño va detrás del que echa a andar
		"eat":
			# usuario 26-10: come en el suelo, en un sitio libre de su recinto y lejos de los comederos (junto a uno parecía
			# comer de él, flotando a su altura): si está pegado a uno, primero se aparta
			var q = null
			if mundo.cerca_de_comedero(self, position):
				for k in 4:
					q = destino()
					if q == null or not mundo.cerca_de_comedero(self, q):
						break
				if q != null and mundo.cerca_de_comedero(self, q):
					q = null
			if q == null and mundo.cerca_de_comedero(self, position):
				cola = cadena("idle", 2)   # (sin sitio lejos del comedero, mejor no comer que parecer que come de él)
			else:
				cola = (ir(q, false) if q != null else []) + cadena("eat", randi_range(3, 7))
		"sleep":
			cola = cadena("sleep", randi_range(6, 12))
		"hurt":
			cola = _respingo()
		"swim":
			cola = _a_nadar()
		"idle":
			cola = cadena("idle", randi_range(1, 4))
		_:
			cola = cadena(act, 1) + [{"anim": "idle", "vueltas": 1}]


func _deuda_vieja() -> bool:
	## si a los dos minutos y medio aún tiene algo de su repertorio (salvo la muerte) que no se le ha visto nunca
	if mundo.reloj < 150.0:
		return false
	for a in d["anims"]:
		if not a.ends_with("_start") and not a.ends_with("_end") and not a in ["death", "idle", "walk", "fly", "despegue",
				"aterrizaje", "swim"] and not _vistas.has(a):
			return true
	return false


func _respingo() -> Array:
	## un tábano, un pisotón: da un respingo (hurt) y se aparta unos pasos; nada más (nunca acaba en muerte)
	var c: Array = cadena("hurt", 1)
	var lejos = destino(position + Vector2(randf_range(-40.0, 40.0), randf_range(-14.0, 14.0)), 12.0)
	if lejos != null:
		c += ir(lejos, tiene("run") and randf() < 0.5)
	return c + [{"anim": "idle", "vueltas": 1}]


func _a_nadar() -> Array:
	## las aves de agua, un rato a nadar: al agua (andando si está en tierra), un trecho nadando y, el ganso, que vive
	## en la orilla, de vuelta a donde estaba
	var c: Vector2 = mundo.estanque["c"]
	var r: Vector2 = mundo.estanque["r"]
	var puntos: Array = []
	for i in 60:
		var q := c + Vector2(randf_range(-r.x, r.x), randf_range(-r.y, r.y))
		if not mundo.agua_honda(q) or not mundo.espacio(q, self):
			continue
		if puntos.is_empty() or q.distance_to(puntos[0]) > 30.0:
			puntos.append(q)
		if puntos.size() >= 2:
			break
	if puntos.size() < 2:
		return cadena("idle", 1)
	if not mundo.agua(position) and puntos[1].distance_to(position) < puntos[0].distance_to(position):
		puntos.reverse()   # entra por el más cercano
	var de := position
	var pasos: Array = ir(puntos[0], false) + ir(puntos[1], false, puntos[0]) + cadena("idle", 2)
	if not zona.get("agua", false):
		pasos += ir(de, false, puntos[1])   # el ganso vuelve a la orilla
	return pasos + [{"anim": "idle", "vueltas": 1}]


func asusta(de: Vector2) -> void:
	## pasa alguien cerca: las aves aletean, los conejos golpean el suelo y salen corriendo, lejos de quien viene
	if mundo.reloj < _susto_hasta or manual or encargo or modo != "libre" or mundo.noche:
		return
	_susto_hasta = mundo.reloj + 25.0
	var huye: Vector2 = position + (position - de).normalized() * 40.0
	var q = destino(huye, 14.0)
	var pasos: Array = []
	if tiene("aleteo"):
		pasos += cadena("aleteo", 1)
	elif tiene("thump"):
		pasos += cadena("thump", 1)
	if q != null and tiene("run"):
		pasos += ir(q, true)
	if pasos.is_empty():
		return
	pide = _cierre() + pasos + [{"anim": "idle", "vueltas": 1}]


func clic() -> void:
	## al pulsarlo hace lo suyo (la tabla de su especie: la gallina pone, el gallo canta); si no, su voz; si no, come
	var voz := ""
	for v in Comp.VOCES:
		if tiene(v):
			voz = v
			break
	if sp.has("clic") and tiene(sp["clic"]):
		haz(sp["clic"])
	elif sp.get("clic", "") == "attack" and tiene("headbutt"):
		haz("headbutt")
	elif voz != "":
		haz(voz)
	else:
		haz("eat")


func mamar(madre: Actor, forzar := false) -> Array:
	## usuario 26-10: la madre se queda quieta de frente (mirando al sur, o al norte si ya miraba hacia allí) y la cría
	## llega de perfil por un lado y mete la cabeza bajo su barriga, en la ubre, entre las patas. Se dibuja detrás de ella
	## (sus pies, un poco por encima de los de la madre: la tapan las patas de delante) y el resto de su cuerpo asoma por
	## el costado por el que ha llegado. Al acabar sale por ese mismo lado, sin atravesarla. Devuelve los pasos (o nada)
	if madre == null or not madre.visible or madre.manual or madre.encargo:
		return []
	if madre.paso.has("a") and not forzar:
		return []
	var de_cara: String = "north" if madre.dir == "north" else "south"
	var ella: Rect2 = madre._cuerpo.get(de_cara, madre.huella(Vector2.ZERO))
	# entre la línea de las patas de delante y la de las de atrás (en la vista de frente, unos píxeles por encima)
	var y := madre.position.y - clampf(ella.size.y * 0.08, 2.0, 6.0)
	var lados: Array = [true, false] if position.x < madre.position.x else [false, true]
	var elegido = null
	for desde_oeste in lados:
		var mira := "east" if desde_oeste else "west"
		var yo_c: Rect2 = _cuerpo.get(mira, huella(Vector2.ZERO))
		# la cara, justo pasado el centro de la barriga (la ubre)
		var x: float = madre.position.x - yo_c.end.x + 2.0 if desde_oeste else madre.position.x - yo_c.position.x - 2.0
		var p := Vector2(roundf(x), roundf(y))
		# por donde llega y por donde se va: a su lado, con el cuerpo ya fuera del de la madre
		var fx: float = madre.position.x + ella.position.x - yo_c.end.x - 3.0 if desde_oeste \
			else madre.position.x + ella.end.x - yo_c.position.x + 3.0
		var llega := Vector2(roundf(fx), roundf(y))
		var vale: bool = mundo.libre(p, zona, 0.0, self) and mundo.libre(llega, zona, 0.0, self) \
			and (position.distance_to(llega) <= 1.5 or mundo.camino_libre(position, llega, zona, 0.0, self))
		if vale or (forzar and elegido == null):
			elegido = [p, llega, mira]
			if vale:
				break
	if elegido == null:
		return []
	var p: Vector2 = elegido[0]
	var llega: Vector2 = elegido[1]
	var mira: String = elegido[2]
	var mama := "suckle" if tiene("suckle") else "idle"
	act = "mamar"
	# la madre le espera quieta y de frente (nadie la mueve mientras tanto) lo que tarda en llegar, mamar y salir
	var n_mama := randi_range(4, 7)
	var tarda: float = (position.distance_to(llega) + 2.0 * llega.distance_to(p)) / maxf(1.0, float(sp["vel"]) * 0.7) + 3.0 \
		+ _dura(mama) * n_mama + _dura(mama + "_start") + _dura(mama + "_end") + 1.0
	tarda = tarda * 1.5 + 4.0   # (con holgura: si se iba antes de que la cría acabara, la dejaba mamando en el aire)
	madre.pide = madre._cierre() + madre.cadena("idle", maxi(6, ceili(tarda / maxf(0.2, madre._dura("idle")))), de_cara)
	madre.encargo = true
	var mamando := cadena(mama, n_mama, mira)
	var entra := ir(p, false, llega)
	for s in entra:
		if s.has("a"):
			s["exacto"] = true   # (justo bajo la ubre: sin el paso de más hasta la pisada, se pasaba de largo)
	for s in mamando:
		s["mama_en"] = p   # (sólo si ha llegado y su madre sigue ahí: ver empieza)
		s["mama_rel"] = p - madre.position
	return (ir(llega, false) if position.distance_to(llega) > 1.5 else []) + entra + mamando \
		+ ir(llega, false, p) + [{"anim": "idle", "vueltas": 1}]


func _dura(anim: String) -> float:
	## lo que dura una vuelta de esa animación (s), o nada si no la tiene
	if not tiene(anim):
		return 0.0
	var s := 0.0
	for ms in _pista_de(anim, dir)["ms"]:
		s += float(ms)
	return s / 1000.0


func sal_por_la_puerta() -> bool:
	## de su corral al patio por la puerta (que se abre a su paso), un rato picoteando fuera, y de vuelta
	# usuario 26-10: ningún animal sale de su recinto; por las verjas sólo pasan los granjeros
	if not PERSONAS.has(nombre):
		return false
	var pu = mundo.puerta_cerca(position, 140.0)
	if pu == null:
		return false
	var c: Vector2 = pu["centro"]
	var dentro: Vector2 = pu.get("dentro", c + Vector2(0, 14))
	var fuera: Vector2 = pu.get("fuera", c + Vector2(0, -14))
	var hacia: Vector2 = (fuera - dentro).normalized()
	var paseo: Vector2 = fuera + hacia * randf_range(14, 34) + Vector2(-hacia.y, hacia.x) * randf_range(-30, 30)
	if mundo.recinto_de(paseo) != "" or not mundo.libre(paseo, {"b": Rect2(0, 0, float(mundo.E["W"]), float(mundo.E["H"]))}, 0.0):
		return false
	cola = ir_por([dentro, fuera, paseo]) + cadena("eat", randi_range(2, 4)) \
		+ ir_por([fuera, dentro]) + cadena("idle", 1)
	# en el camino no se le cortan los pasos por estar fuera de su zona
	act = "salir"
	return true


func destino_vuelo():
	## a otro sitio de su zona, lejos: el vuelo no mira caminos (va por el aire)
	var b: Rect2 = zona["b"]
	for i in 30:
		var p := Vector2(randf_range(b.position.x, b.end.x), randf_range(b.position.y, b.end.y))
		if p.distance_to(position) > 60 and mundo.libre(p, zona, margen, self) and mundo.espacio(p, self):
			return p
	return null


func _pone_huevo() -> void:
	## el huevo, dibujado aquí (6 × 7, colores de la gallina, contorno del pack): detrás de la cola, en el suelo;
	## se queda un rato y se va (como mucho unos pocos a la vez)
	var huevo := Node2D.new()
	var sentido := -1.0 if dir == "east" else (1.0 if dir == "west" else 0.0)
	var tras := Vector2(sentido * float(d["w"]) * 0.42, -1.0 if sentido != 0.0 else 2.0)   # asoma tras la cola mientras empolla
	huevo.position = position + tras
	huevo.z_index = 0
	var filas := ["..oo..", ".offo.", "olffmo", "offfmo", "offmso", ".omso.", "..oo.."]
	var col := {"o": Color8(1, 1, 1), "f": Color8(233, 223, 197), "l": Color8(248, 243, 226), "m": Color8(180, 161, 136),
		"s": Color8(160, 140, 117)}
	huevo.draw.connect(func():
		for y in filas.size():
			for x in 6:
				var ch: String = filas[y][x]
				if col.has(ch):
					huevo.draw_rect(Rect2(x - 3, y - 7, 1, 1), col[ch]))
	get_parent().add_child(huevo)
	get_parent().move_child(huevo, get_index())   # detrás de la gallina: ella se echa encima
	mundo.get_tree().create_timer(60.0).timeout.connect(huevo.queue_free)


func vuelo(p: Vector2) -> Array:
	## despegue en el sitio, vuelo hasta el destino y aterrizaje, con las tres animaciones del pack
	var c := []
	if tiene("despegue"):
		c.append({"anim": "despegue"})
	c.append({"anim": "fly", "a": p, "vel": 70.0, "vuela": true})
	if tiene("aterrizaje"):
		c.append({"anim": "aterrizaje"})
	return c + [{"anim": "idle", "vueltas": 1}]


func llama(p: Vector2) -> bool:
	## le echan de comer en p: va hasta allí (si es su sitio) y come con la cabeza baja, como en el pack
	# (en el suelo y lejos de los comederos: nunca a su altura como si comiera de ellos)
	var q = null
	for r in [14.0, 40.0, 40.0, 70.0]:
		q = destino(p, r)   # la comida cae junto a la valla: lo más cerca que pueda dentro de su sitio
		if q != null and not mundo.cerca_de_comedero(self, q):
			break
		q = null
	if q == null:
		return false
	deja_guion()
	pide = _cierre() + ir(q, position.distance_to(q) > 90 and sp.has("corre")) + cadena("eat", randi_range(3, 5)) 		+ [{"anim": "idle", "vueltas": 1}]
	act = "eat"
	return true


func _cierre() -> Array:
	if not paso["anim"].ends_with("_end"):
		for s in cola:
			if s["anim"].ends_with("_end"):
				return [s]
	return []


func haz(a: String, de_frente := false) -> void:
	## una animación pedida desde fuera (clic o ficha): lo que está en marcha se cierra antes (eat_end,
	## walk_end...), nada se corta
	deja_guion()
	var cierre := _cierre()
	# pedida desde la ficha, la hace mirando a la cámara (de perfil si no tiene vista de frente; andar, correr y volar
	# llevan su dirección)
	var mira = _de_frente(a) if de_frente and tiene(a) and not a in ["walk", "run", "fly", "lay_egg"] else null
	if a == "lay_egg":
		mira = dir if dir in ["east", "west"] else "east"   # de perfil: el huevo sale detrás de la cola (como en la viñeta)
	var nuevo := cadena(a, 3 if a in ["eat", "idle"] else (8 if a == "sleep" else 1), mira) \
		+ [{"anim": "idle", "vueltas": 1}]
	if a == "suckle" or a == "mamar":
		# crítico 26-10: desde la ficha mamaba en el aire; ahora va a su madre (si la tiene)
		var m := mamar(lider(), true)
		# (sin madre a mano o ocupada, no mama en el aire: se queda en reposo)
		nuevo = m if not m.is_empty() else cadena("idle", 1)
	if a == "death":
		# tendido un rato y se levanta deshaciendo la caída (los fotogramas de la muerte al revés), sin saltos
		nuevo = [{"anim": "death", "vueltas": 1, "tendido": 3.0, "mira": mira}, {"anim": "death", "reversa": true},
			{"anim": "idle", "vueltas": 1}]
	elif a == "fly" and tiene("fly") and base.begins_with("Pato") or a == "fly" and base.begins_with("Ganso"):
		mundo._vuelo_rio(self)
		return
	elif a == "fly" and tiene("fly"):
		var pv = destino_vuelo()
		nuevo = vuelo(pv) if pv != null else cadena("idle", 1)
	if a == "walk" or a == "run":
		var p = destino()
		nuevo = ir(p, a == "run") if p != null else cadena("idle", 1)
	pide = cierre + nuevo
	act = a
	encargo = true


func _de_frente(a: String) -> String:
	var pistas: Dictionary = d["anims"][a]
	if pistas.has("south"):
		return "south"
	if pistas.has(dir):
		return dir
	return "east" if pistas.has("east") else String(pistas.keys()[0])


func _mando(delta: float) -> void:
	## quien juega lo lleva: anda (o corre) hacia donde apunta, con sus animaciones encadenadas, sin salir de su recinto
	## ni pasar por encima de nada; al soltar, acaba el paso y se para con su parada
	if paso.get("anim", "") == "death":
		return   # muriendo, tendido o levantándose no se le lleva
	if mando == Vector2.ZERO:
		if manual:
			toque += delta
			# al soltar, se para en la siguiente pisada; pero si la tecla ha durado menos que el arranque, da antes un paso
			# de verdad (si no, un toque corto era arrancar y pararse sin moverse del sitio)
			if paso.has("a") and not llego and _andado >= 8.0:
				llego = true
			if toque > 6.0 and mundo.elegido != self:
				manual = false   # con su ficha abierta no se suelta solo
		return
	deja_guion()
	manual = true
	toque = 0.0
	var hacia := ("east" if mando.x > 0 else "west") if absf(mando.x) >= absf(mando.y) else ("south" if mando.y > 0 else "north")
	var meta: Vector2 = position + VECTOR[hacia] * 14.0
	# llevado a mano no sale de su recinto, no pisa el decorado ni se mete encima de otro (sus crías no cuentan)
	if not mundo.libre(meta, zona, margen, self) or not mundo.espacio_al_llevarlo(position + VECTOR[hacia] * 4.0, self) \
			or not mundo.paso_libre(position + VECTOR[hacia] * 3.0, self):
		if paso.has("a"):
			llego = true
		else:
			dir = hacia   # contra la valla: se gira, parado
		return
	var quiere := "run" if corre and tiene("run") else "walk"
	if paso.has("a") and not llego and paso["anim"] in ["walk", "run"] and paso["anim"] != quiere:
		# suelta o pulsa Mayúsculas andando: cambia de paso sin pararse
		paso["anim"] = quiere
		paso["vel"] = sp.get("corre", sp["vel"] * 2.5) if quiere == "run" else sp["vel"]
		act = quiere
	if paso.has("a") and paso["anim"] == quiere and not llego:
		paso["a"] = meta
	# (arrancando, walk_start / run_start, ya va de camino: antes se le volvía a pedir el arranque en cada fotograma y con
	# la tecla pulsada repetía el arranque sin echar a andar nunca)
	elif pide == null and ((not paso.has("a") and not String(paso.get("anim", "")).ends_with("_start")) or llego):
		dir = hacia
		pide = _cierre() + ir(meta, quiere == "run")
		act = quiere
		var en_marcha: String = paso.get("anim", "")
		# crítico 26-10: la voz y los gestos cortos tampoco hacen esperar a quien juega (2,3 s de retraso con el mugido)
		var corto: bool = en_marcha in Comp.VOCES or (not paso.has("a") and not en_marcha.ends_with("_start") \
			and not en_marcha in ["despegue", "aterrizaje"] \
			and not en_marcha.ends_with("_end") and not tiene(en_marcha + "_end") and _dura(en_marcha) <= 1.0)
		if en_marcha == "idle" or corto:
			siguiente()   # de pie, echa a andar en cuanto se le pide (no espera a acabar el reposo)
		elif not paso.has("a") and tiene(en_marcha + "_end"):
			# comiendo, durmiendo, mamando (bucles con parada): lo cierra ya con su parada y echa a andar; lo que se hace
			# de una vez (cantar, poner un huevo) se deja acabar
			pide = [{"anim": en_marcha + "_end"}] + ir(meta, quiere == "run")
			siguiente()


func _origen() -> Array:
	## dónde empieza y acaba su guion (la cría: junto a su madre)
	if guion.get("tipo", "") == "sigue" and madre_g:
		var o: Array = madre_g._origen()
		var dxs: float = float(guion["dx"]) if o[2] != "east" else -float(guion["dx"])
		return [o[0] + dxs, o[1] + float(guion["dy"]), o[2] if o[2] in ["east", "west"] else "west"]
	var g: Array = guion["origen"]
	return [float(g[0]), float(g[1]), String(g[2])]


func _des() -> float:
	if guion.get("tipo", "") == "sigue" and madre_g:
		return madre_g._des()
	return float(guion.get("des", 0.0))


func usa_guion(e: Dictionary, madre: Actor) -> void:
	guion = e
	madre_g = madre
	modo = "guion" if REPRODUCE_GUION and not PERSONAS.has(nombre) else "libre"   # los granjeros, en su sitio fijo también en el vídeo
	var o := _origen()
	position = Vector2(o[0], o[1])
	dir = o[2]
	if not REPRODUCE_GUION:
		_naturaleza()


func _naturaleza() -> void:
	## de su guion aprobado: su territorio (por donde se movía, dentro de su recinto) y su repertorio (lo que hacía
	## y cuánto rato): lo propio de cada uno se suma a lo de su especie
	var g: Dictionary = guion if guion.get("tipo", "") != "sigue" or madre_g == null else madre_g.guion
	if not g.has("tramos"):
		return
	var o := _origen()
	var caja := Rect2(Vector2(o[0], o[1]), Vector2.ZERO)
	var rato := {}
	for tr in g["tramos"]:
		caja = caja.expand(Vector2(float(tr[4]), float(tr[5]))).expand(Vector2(float(tr[6]), float(tr[7])))
		var b: String = String(tr[0]).trim_suffix("_start").trim_suffix("_end")
		rato[b] = rato.get(b, 0.0) + float(tr[3]) - float(tr[2])
	# usuario 25-10: «no tiene espacio para moverse»: dentro de un recinto, todo su recinto; suelto, un buen trozo
	# alrededor de donde vive
	var recinto: Rect2 = zona["b"].abs()
	if nombre in ["granjero", "washerwoman"] and mundo.zonas.has("patio"):
		caja = mundo.zonas["patio"]["b"]   # crítico 26-10: los granjeros, por todo el patio (no sólo su mitad)
		zona = mundo.zonas["patio"]
	elif recinto.has_point(Vector2(o[0], o[1])) and not nombre in ["granjero", "washerwoman"]:
		caja = recinto
	else:
		caja = caja.grow_individual(60, 30, 60, 30)
	zona = zona.duplicate()
	zona["b"] = caja
	if guion.get("tipo", "") == "sigue":
		return   # la cría: su madre manda (va detrás de ella)
	var total := 0.0
	for k in rato:
		total += rato[k]
	for k in rato:
		if k in ["idle", "walk", "death", "hurt"] or not (tiene(k) or k == "run"):
			continue   # (la muerte y el golpe, nunca por su cuenta)
		# lo que hacía en su guion pesa según el rato que le dedicaba (comer mucho, mugir de vez en cuando)
		var w: float = clampf(rato[k] / maxf(total, 1.0) * 12.0, 0.4, 7.0)
		sp["w"][k] = maxf(float(sp["w"].get(k, 0.0)), w)
	if rato.has("run"):
		sp["corre"] = sp.get("corre", float(sp.get("vel", 14.0)) * 2.5)


func deja_guion() -> void:
	if modo == "guion" or modo == "vuelta":
		modo = "libre"
		cola = []
		empieza({"anim": "idle", "vueltas": 1})


func vuelve_al_guion() -> void:
	## andando a su sitio; allí espera a que su guion pase por el principio
	var o := _origen()
	modo = "vuelta"
	var p := Vector2(o[0], o[1])
	cola = (ir(p, false) if position.distance_to(p) > 1.5 else []) + [{"anim": "idle", "vueltas": 1, "mira": o[2]}]
	_tg_prev = fposmod(mundo.reloj * 1000.0 + _des(), L_GUION)


func _plan_noche():
	## [x, y, mira, modo] de su sitio de noche (vida_granja_noche.NOCHE_PLAN); los que no lo tienen (los que se sumaron
	## a la granja después), junto a los suyos: su líder o el más cercano de su zona que tenga sitio
	var plan = guion.get("noche")
	if guion.get("tipo", "") == "sigue" and madre_g and madre_g.guion.has("noche"):
		plan = madre_g.guion.get("noche")
		if plan != null and plan[0] != null:
			var dxs: float = float(guion["dx"]) if String(plan[2]) != "east" else -float(guion["dx"])
			plan = [float(plan[0]) + dxs, float(plan[1]) + float(guion["dy"]), plan[2], plan[3]]
	if plan != null:
		return plan
	var otro: Actor = null
	var l: Actor = madre_g if madre_g != null else lider()
	if l != null and l.guion.get("noche") != null and l.guion["noche"][0] != null:
		otro = l
	else:
		var mejor := INF
		for a in mundo.actores:
			var q = a.guion.get("noche")
			if a == self or q == null or q[0] == null or String(q[3]) == "activo":
				continue
			if String(a.sp.get("zona", "")) != String(sp.get("zona", "")) and a.base != base:
				continue
			var dd := position.distance_to(a.position) + (0.0 if a.base == base else 300.0)
			if dd < mejor:
				mejor = dd
				otro = a
	if otro == null:
		return null
	var q2: Array = otro.guion["noche"]
	return [float(q2[0]) + randf_range(-24, 24), float(q2[1]) + randf_range(-8, 8), q2[2], "duerme"]


func a_dormir(deprisa := false) -> void:
	## cae la noche: a su sitio de noche (sin pisar los ya repartidos), y a dormir, a vigilar o a seguir activo;
	## los granjeros, a casa (con NIGHT, deprisa: el reloj les espera)
	if nombre in ["granjero", "washerwoman"] and mundo.E.has("casa"):
		if modo_noche == "dentro":
			return
		deja_guion()
		modo = "noche"
		modo_noche = "dentro"
		# crítico 26-10 (la lavandera seguía fuera a las 470): su camino a casa, desde el tramo que le queda más corto, no
		# siempre desde el principio (desde el este cruzaba todo el patio hasta el oeste antes de ir a la puerta)
		var ruta: Array = mundo.E["casa"]["rutas"][nombre]
		# si está en plena tarea fuera del patio (en el estanque), primero vuelve por donde fue; y el atajo, sólo si el
		# tramo recto no cruza ningún recinto (si no, atravesaba el de las ovejas)
		var puntos: Array = regreso.duplicate()
		var de: Vector2 = puntos[-1] if not puntos.is_empty() else position
		var desde := 0
		var mejor := INF
		for i in ruta.size():
			var r0 := Vector2(ruta[i][0], ruta[i][1])
			if i > 0 and not _tramo_sin_recintos(de, r0):
				continue
			var largo: float = de.distance_to(r0)
			for j in range(i, ruta.size() - 1):
				largo += Vector2(ruta[j][0], ruta[j][1]).distance_to(Vector2(ruta[j + 1][0], ruta[j + 1][1]))
			if largo < mejor:
				mejor = largo
				desde = i
		for i in range(desde, ruta.size()):
			puntos.append(Vector2(ruta[i][0], ruta[i][1]))
		var pu: Array = mundo.E["casa"]["puerta"]
		puntos += [Vector2(pu[0], pu[1]), Vector2(pu[0], pu[1] - 6)]
		var pasos := ir_por(puntos)
		if deprisa:
			for s in pasos:
				if s.has("a"):
					s["vel"] = float(s["vel"]) * 2.2
		pide = _cierre() + pasos + [{"anim": "idle", "vueltas": 1, "dentro": true}]
		return
	var plan = _plan_noche()
	if plan != null and String(plan[3]) == "activo":
		modo_noche = "activo"
		return   # el ratón es nocturno: sigue a lo suyo
	deja_guion()
	modo = "noche"
	modo_noche = String(plan[3]) if plan != null else "duerme"
	var p := Vector2(float(plan[0]), float(plan[1])) if plan != null and plan[0] != null else position
	if en_patio:
		p = position   # las sueltas del patio duermen en el patio: ningún animal cruza las vallas (usuario 26-10)
	p = mundo.cama(p, self)
	cama_noche = p
	var mira: String = String(plan[2]) if plan != null and plan[2] != null else dir
	# de lejos (las aves sueltas por el patio), a buen paso: que lleguen con la noche, no a medianoche
	var lejos: bool = position.distance_to(p) > 100.0 and tiene("run")
	pide = _cierre() + camino(p, lejos) + [{"anim": "idle", "vueltas": 1, "mira": mira}]


func al_corral() -> void:
	## al caer la tarde, las aves sueltas vuelven del patio a su corral por la verja (antes de que se haga de noche)
	if not en_patio or patio_de_dia:
		return   # (las del patio se quedan en él: ningún animal cruza las vallas, usuario 26-10)
	en_patio = false
	zona = zona_corral
	var p = destino()
	if p == null:
		p = destino_seguro()
	if p != null:
		pide = _cierre() + camino(p, position.distance_to(p) > 160.0 and tiene("run")) + cadena("idle", 1)


func _noche_quieto() -> Array:
	if modo_noche == "dentro":
		return [{"anim": "idle", "vueltas": 4, "dentro": true}]
	if modo_noche in ["duerme", ""] and tiene("sleep"):
		return cadena("sleep", 40)
	return cadena("idle", 4)


func despierta() -> void:
	## al alba, cada uno a su hora (de 0 a 20 s, el gallo el primero): nadie se levanta a la vez que los demás
	if modo_noche == "activo":
		modo_noche = ""
	if modo != "noche" or _despertar_pendiente:
		return
	_despertar_pendiente = true
	# (los granjeros salen de casa uno detrás de otro, no a la vez por la misma puerta)
	var espera := 0.0 if tiene("crow") else randf_range(0.0, 20.0)
	if modo_noche == "dentro":
		espera = randf_range(0.0, 2.0) if nombre == "granjero" else randf_range(7.0, 10.0)
	espera /= mundo.ritmo_dia   # con el reloj rápido del vídeo, el despertar va al mismo paso que la luz
	mundo.get_tree().create_timer(espera).timeout.connect(_despierta_ya)


func _despierta_ya() -> void:
	_despertar_pendiente = false
	if modo != "noche" or mundo.noche:
		return
	if modo_noche == "dentro":
		# sale de casa por la puerta y vuelve por su camino; si el otro aún está en la puerta, espera dentro
		var pu: Array = mundo.E["casa"]["puerta"]
		for o in mundo.actores:
			if o != self and mundo.es_persona(o) and o.visible and o.position.distance_to(Vector2(pu[0], pu[1])) < 30.0:
				mundo.get_tree().create_timer(1.0).timeout.connect(_despierta_ya)
				_despertar_pendiente = true
				return
		visible = true
		position = Vector2(pu[0], pu[1] - 6)
		dir = "south"
		var puntos: Array = [Vector2(pu[0], pu[1])]
		var ruta: Array = mundo.E["casa"]["rutas"][nombre].duplicate()
		ruta.reverse()
		for q in ruta:
			puntos.append(Vector2(q[0], q[1]))
		modo = "libre"
		modo_noche = ""
		cola = ir_por(puntos) + [{"anim": "idle", "vueltas": 1}]
		pide = null
		empieza(cola.pop_front())
		return
	modo = "libre"
	modo_noche = ""
	pide = _cierre() + [{"anim": "idle", "vueltas": 1}]
	if tiene("crow"):
		pide += cadena("crow", 1) + [{"anim": "idle", "vueltas": 1}]   # el gallo canta al amanecer
	if patio_de_dia:
		al_patio()


func al_patio() -> void:
	## de día, unas cuantas aves salen del corral al patio por la verja (crítico 26-10: el patio estaba vacío)
	if en_patio or not mundo.zonas.has("patio_aves"):
		return
	zona_corral = zona
	zona = mundo.zonas["patio_aves"]
	var p = destino()
	if p == null:
		zona = zona_corral
		return
	en_patio = true
	pide = (pide if pide != null else _cierre()) + camino(p) + [{"anim": "idle", "vueltas": 1}]


func estado_en(t: float) -> Array:
	## [anim, dir, fotograma, x, y] de su guion en el instante t (ms, con su desfase): Guion.en / Seguidor.en del vídeo
	if guion.get("tipo", "") == "sigue":
		var m: Array = madre_g.estado_en(t - float(guion["r"]))
		var anim: String = m[0]
		var dd: String = m[1]
		if dd in ["north", "south"]:
			var d0: String = madre_g._origen()[2]
			dd = d0 if d0 in ["east", "west"] else "west"
		var x: float = m[3] + (float(guion["dx"]) if dd != "east" else -float(guion["dx"]))
		var y: float = m[4] + float(guion["dy"])
		if not tiene(anim):
			anim = "walk" if anim in ["walk", "run"] and tiene("walk") else "idle"
		if anim == "idle":
			return [anim, dd, _reposo(dd, t), x, y]
		var durs: Array = _pista_de(anim, dd)["ms"]
		var c := 0.0
		for v in durs:
			c += float(v)
		var u := fposmod(fposmod(t, L_GUION) * maxf(1.0, roundf(L_GUION / c)) * c / L_GUION, c)
		return [anim, dd, _indice(durs, u), x, y]
	var tt := fposmod(t, L_GUION) * float(guion["t"]) / L_GUION
	for tr in guion["tramos"]:
		var t0 := float(tr[2])
		var t1 := float(tr[3])
		if tt >= t0 and tt < t1:
			var k := (tt - t0) / maxf(1e-6, t1 - t0)
			var x := lerpf(float(tr[4]), float(tr[6]), k)
			var y := lerpf(float(tr[5]), float(tr[7]), k)
			var anim: String = tr[0]
			var dd: String = tr[1]
			if not tiene(anim):
				anim = "idle"
			if anim == "idle":
				return [anim, dd, _reposo(dd, tt - t0), x, y]
			var durs: Array = _pista_de(anim, dd)["ms"]
			var c := 0.0
			for v in durs:
				c += float(v)
			var u := fposmod(tt - t0, c) if tr[8] else minf(tt - t0, c - 0.001)
			return [anim, dd, _indice(durs, u), x, y]
	var o: Array = guion["origen"]
	return ["idle", String(o[2]), 0, float(o[0]), float(o[1])]


func _pista_de(anim: String, dd: String) -> Dictionary:
	var a: Dictionary = d["anims"][anim]
	return a.get(dd, a.get("south", a.values()[0]))


func _indice(durs: Array, u: float) -> int:
	var i := 0
	while i < durs.size() - 1 and u >= float(durs[i]):
		u -= float(durs[i])
		i += 1
	return i


func _reposo(dd: String, t: float) -> int:
	## el reposo corto de ida y vuelta (0,1,2,3,2,1) con un número entero de vueltas en los 30 s
	var durs: Array = _pista_de("idle", dd)["ms"]
	var n := durs.size()
	var seq := [0, 1, 2, 3, 2, 1] if n >= 4 else range(n) + range(n - 2, 0, -1)
	seq = seq.filter(func(i): return i < n)
	if seq.is_empty():
		seq = [0]
	var total := 0.0
	for i in seq:
		total += float(durs[i])
	var veces := maxf(1.0, roundf(L_GUION / total))
	var u := fposmod(fposmod(t, L_GUION) * veces * total / L_GUION, total)
	for i in seq:
		if u < float(durs[i]):
			return i
		u -= float(durs[i])
	return seq[-1]


func _ritmo_del_recinto() -> Array:
	## cuántas vueltas de guion y cuánto rato suelto: el mismo número para todos los de un recinto
	var h: int = absi(hash(str(zona["b"].position.round())))
	return [2 + h % 2, 25.0 + float(h % 20)]


func _soltarse() -> void:
	deja_guion()
	_vueltas = 0
	_libre_hasta = mundo.reloj + float(_ritmo_del_recinto()[1])


func _sigue_guion() -> bool:
	## en su guion este instante (la cría, sólo si su madre también lo está)
	if not REPRODUCE_GUION or modo != "guion" or guion.is_empty():
		return false
	if guion.get("tipo", "") == "sigue":
		return madre_g != null and madre_g.modo == "guion"
	return true


static var us_total := 0
static var atraviesan := {}   # (para las pruebas: cuántas veces ha tenido que pasar por encima cada uno)


func _process(delta: float) -> void:
	var t_us := Time.get_ticks_usec()
	_process_de_verdad(delta)
	us_total += Time.get_ticks_usec() - t_us


var _mira_sitio := randf()


func _process_de_verdad(delta: float) -> void:
	if mundo.reloj < _tendido_hasta:
		fotograma = pista()["ms"].size() - 1   # tendido en el suelo
		dibuja()
		return
	_mira_sitio -= delta
	if _mira_sitio <= 0.0:
		_mira_sitio = 0.5
		if modo in ["libre", "noche"] and not manual and not encargo and visible and not paso.has("a") and pide == null \
				and act != "mamar" and not _va_de_camino() \
				and ((not mundo.espacio(position, self) if modo == "libre" else mundo.tapa_quieto(self)) \
					or mundo.cuerpo_toca(self, position) > 0.0):   # (ni quieto encima del decorado: sale de ahí)
			# (de noche, sólo si tapa a otro que también está quieto: uno que pasa por delante de su sitio no le echa de
			# él; antes se iba lejos de su sitio de dormir por cualquiera que pasara)
			# (ni si ya va de camino, arrancando o con un paso en la cola: si no, cada segundo le cambiaba el camino en
			# pleno arranque y se quedaba arrancando y parando en el sitio)
			var aparte = null
			if modo == "noche":
				# de noche, al sitio libre más cercano (sin pisar los de dormir ya repartidos), que pasa a ser el suyo
				mundo.suelta_cama(self)
				aparte = mundo.cama(position, self)
				cama_noche = aparte
				if position.distance_to(aparte) < 1.0:
					aparte = null
			else:
				aparte = aparta()
				if aparte == null:
					aparte = destino_seguro(position, 34.0)
			if aparte != null:
				var luego: Array = _noche_quieto() if modo == "noche" else cadena("idle", 1)
				pide = _cierre() + ir(aparte, false) + luego
				# un bucle con parada (comer, dormir) se cierra ya con su parada y se aparta; lo que se hace de una vez
				# (cantar, poner un huevo) se deja acabar
				var en_curso: String = paso.get("anim", "")
				if en_curso == "idle" or tiene(en_curso + "_end"):
					siguiente()
	if modo == "vuelta" and not paso.has("a") and pide == null:
		var o := _origen()
		if position.distance_to(Vector2(o[0], o[1])) < 3.0:
			position = Vector2(o[0], o[1])
			var tg := fposmod(mundo.reloj * 1000.0 + _des(), L_GUION)
			if tg < _tg_prev:
				modo = "guion"   # su guion pasa por el principio: entra sin saltos
			_tg_prev = tg
	if REPRODUCE_GUION and modo == "guion" and guion.get("tipo", "") == "sigue" and madre_g and madre_g.modo != "guion":
		deja_guion()   # su madre se ha soltado (o la llevan): la cría va con ella a su aire
	if _sigue_guion():
		var tg := fposmod(mundo.reloj * 1000.0 + _des(), L_GUION)
		if tg < _tg_guion:
			_vueltas += 1
			var suelta: bool = not nombre in ["granjero", "washerwoman"] and guion.get("tipo", "") != "sigue" \
				and not mundo.noche and _vueltas >= int(_ritmo_del_recinto()[0])
			if suelta:
				_tg_guion = tg
				_soltarse()
				return
		_tg_guion = tg
		var st := estado_en(mundo.reloj * 1000.0 + _des())
		var anim: String = st[0]
		if anim in ["walk", "run"] and tiene("swim") and mundo.agua(Vector2(st[3], st[4])):
			anim = "swim"
		position = Vector2(st[3], st[4])
		dir = st[1]
		if paso.get("anim", "") != anim:
			paso = {"anim": anim}
			if mundo:
				mundo.suena(self, anim)
				if anim == "grano":
					mundo.ambiente.echa_grano(position, dir)
		fotograma = mini(int(st[2]), pista()["ms"].size() - 1)
		dibuja()
		return
	_mando(delta)
	var ms := delta * 1000.0
	var p := pista()
	t += ms
	fotograma %= p["ms"].size()
	while t >= p["ms"][_cuadro()]:
		t -= p["ms"][_cuadro()]
		fotograma += 1
		var mitad: bool = fotograma == p["ms"].size() >> 1
		if fotograma >= p["ms"].size():
			fotograma = 0
			if not paso.has("a"):
				vueltas -= 1
				if vueltas <= 0 and paso.has("tendido") and not paso.get("_hecho", false):
					paso["_hecho"] = true
					_tendido_hasta = mundo.reloj + float(paso["tendido"])
					fotograma = p["ms"].size() - 1
					break
				if vueltas <= 0 or pide != null:
					siguiente()
					p = pista()
					continue
		# andando: sólo se para sobre una pisada (principio o mitad del ciclo), para que el paso apoye
		if paso.has("a") and (llego or pide != null) and (fotograma == 0 or mitad):
			siguiente()
			p = pista()
	if paso.has("a"):
		var s: float = paso["vel"] * delta * (0.7 if dir in ["north", "south"] else 1.0)
		if not llego:
			var hacia: Vector2 = paso["a"] - position
			# crítico 26-10 (vigilante de avance): si en 2 s no se ha acercado 2 px a donde va, está tapado aunque ande
			# (antes se quedaba minutos andando en el sitio)
			var dist_a: float = hacia.length()
			if paso["a"] != _vig_a or manual or paso.get("vuela", false):
				_vig_a = paso["a"]
				_vig_mejor = dist_a
				_vig_t = 0.0
			elif dist_a < _vig_mejor - 2.0:
				_vig_mejor = dist_a
				_vig_t = 0.0
			else:
				_vig_t += delta
				if _vig_t > 2.0 and pide == null:
					_vig_t = 0.0
					_vig_mejor = dist_a
					_rodeos += 1
					_sin_avance()
					dibuja()
					return
			var siguiente_p: Vector2 = paso["a"] if hacia.length() <= s else position + hacia.normalized() * s
			var tapado: bool = not paso.get("vuela", false) and not mundo.paso_libre(siguiente_p, self)
			if paso.get("atraviesa", false):
				if not tapado:
					paso.erase("atraviesa")   # pasar por encima, sólo lo justo: en cuanto hay paso, otra vez con cuidado
				tapado = false
			# usuario 26-10: el decorado es sólido y las vallas no se cruzan. Si el paso choca, lo bordea (sólo en x o sólo en
			# y); si tampoco, se para como si le taparan (los granjeros, que pasan si nadie les deja, no atraviesan las piezas)
			var resbala = null
			if not paso.get("vuela", false) and not (paso.get("atraviesa", false) and PERSONAS.has(nombre)) \
					and not mundo.paso_fisico(self, position, siguiente_p):
				# (un paso entero por el eje libre: si va casi recto contra la pieza, la otra componente es tan pequeña que no
				# avanzaba nada)
				# (nunca hacia atrás: subir y bajar a cada fotograma le dejaba temblando contra la pieza; de frente, rodea)
				# (crítico 26-10: sólo por el eje en que aún le queda camino, y sin pasarse; con 0,3 px en y daba un paso
				# entero, se pasaba, cambiaba de signo y temblaba en el sitio)
				var alts: Array = []
				if absf(hacia.x) >= 0.5:
					alts.append(position + Vector2(signf(hacia.x) * minf(s, absf(hacia.x)), 0.0))
				if absf(hacia.y) >= 0.5:
					alts.append(position + Vector2(0.0, signf(hacia.y) * minf(s, absf(hacia.y))))
				for alt in alts:
					if alt.distance_to(position) > 0.05 and mundo.paso_fisico(self, position, alt) and mundo.paso_libre(alt, self):
						resbala = alt
						break
				if resbala == null:
					tapado = true
			if tapado and (PERSONAS.has(nombre) or modo == "noche") and not manual:
				# los granjeros y el que va a su sitio de noche no pueden cambiar de destino (antes, con el apartarse de
				# siempre, perdían el resto del camino y se quedaban fuera o dormían donde les pillaba, hasta en el patio):
				# al granjero el animal le abre paso; si no, un paso a un lado y siguen su camino; y sólo si en mucho
				# rato sigue sin haber paso, pasan igual (de noche, antes: los que duermen no se apartan)
				if _bloqueado == 0.0 and PERSONAS.has(nombre):
					mundo.abre_paso(self, siguiente_p)
				_bloqueado += delta
				if mundo.cede_el_paso(self, siguiente_p):
					_bloqueado = 0.0   # el que tiene delante también va andando: le deja pasar (uno de los dos, no los dos)
				elif _bloqueado > 0.8 and pide == null:
					_bloqueado = 0.0
					_rodeos += 1
					var de_dia: bool = PERSONAS.has(nombre) and modo == "libre"
					if de_dia and _rodeos > 8 and _rodeos <= 24:
						# de día el granjero no pasa por encima de nadie: vuelve a pedir paso (a todos, también a los que iban a
						# lo suyo) y sigue probando; sólo si en mucho rato no hay manera (uno al que llevan a mano), pasa
						if not _rodeo():
							mundo.abre_paso(self, siguiente_p, true)
					elif _rodeos > (24 if de_dia else 10) or (not _rodeo() and _rodeos > (8 if PERSONAS.has(nombre) else 3)):
						# de noche, mejor echarse en otro sitio libre cerca que pasar por encima de los que duermen; y si no puede
						# (vuelve de fuera de su recinto), sigue rodeando un rato más antes de pasar
						if (PERSONAS.has(nombre) or not _otra_cama()) and (PERSONAS.has(nombre) or _rodeos > 10):
							paso["atraviesa"] = true
							atraviesan[nombre] = atraviesan.get(nombre, 0) + 1
			elif tapado:
				# alguien en medio: se para sobre la pisada; si sigue tapado un rato, busca otro sitio
				# cada tropiezo cuenta (si no, el que se para en la primera pisada no lo sumaba nunca y probaba otra vez lo
				# mismo, arranque y parada sin fin)
				_bloqueado += maxf(delta, 0.2)
				llego = true
				meta = position   # no llega: no reserva un sitio al que no va
				if _bloqueado > 0.5 and not manual and not encargo and pide == null:
					_bloqueado = 0.0
					var otro = aparta()
					if otro == null:
						otro = destino_seguro(position, 30.0)
					if otro != null:
						pide = ir(otro, false) + cadena("idle", 1)
			elif resbala != null:
				# (resbalar no cuenta como haber pasado: el vigilante de avance dice si de verdad se acerca)
				_andado += position.distance_to(resbala)
				position = resbala
			elif hacia.length() <= s:
				_bloqueado = 0.0
				if not paso.get("rodeo", false):
					_rodeos = 0
				position = paso["a"]
				llego = true
			else:
				_bloqueado = 0.0
				position += hacia.normalized() * s
				_andado += s
				# las vistas de perfil se leen mejor: se quedan salvo que vaya claramente arriba o abajo
				if absf(hacia.x) > absf(hacia.y) * 0.6:
					dir = "east" if hacia.x > 0 else "west"
				else:
					dir = "south" if hacia.y > 0 else "north"
		else:
			# hasta la pisada, sigue un poco en la misma dirección si hay sitio
			var q: Vector2 = position + VECTOR[dir] * s
			# volviendo a su guion se para justo en su sitio (si diera el paso de más, el guion empezaría desplazado); y de
			# noche, en el suyo de dormir (con el paso de más se metía en el sitio del de al lado)
			if not modo in ["vuelta", "noche"] and not paso.get("vuela", false) and not paso.get("exacto", false) \
					and mundo.libre(q, zona, margen, self) and mundo.paso_libre(q, self):
				position = q
	elif manual and mando != Vector2.ZERO and String(paso.get("anim", "")) in ["walk_start", "run_start"]:
		# crítico 26-10: llevado a mano, arrancando ya avanza, con la velocidad en rampa de 0 a la del paso (antes se
		# quedaba quieto todo el arranque y la tecla tardaba en notarse)
		var vel: float = sp.get("corre", sp["vel"] * 2.5) if paso["anim"] == "run_start" else sp["vel"]
		var frac: float = clampf((float(fotograma) + t / maxf(1.0, float(p["ms"][_cuadro()]))) / maxf(1.0, float(p["ms"].size())), 0.0, 1.0)
		var s2: float = vel * sqrt(frac) * delta * (0.7 if dir in ["north", "south"] else 1.0)
		var q2: Vector2 = position + VECTOR[dir] * s2
		if mundo.libre(q2, zona, margen, self) and mundo.paso_libre(q2, self) and mundo.paso_fisico(self, position, q2):
			position = q2
			_andado += s2
	dibuja()


var _rodeos := 0   # rodeos seguidos sin llegar (al quinto, pasa)
var _andado := 0.0  # lo andado en este paso
var _vig_a := Vector2.INF   # el vigilante de avance: adónde iba,
var _vig_mejor := INF       # lo más cerca que ha estado
var _vig_t := 0.0           # y cuánto rato lleva sin acercarse


func _sin_avance() -> void:
	## lleva 2 s andando sin acercarse a donde va: tapado. De día se queda donde está y busca otro sitio; de noche,
	## otra cama a mano; el granjero deja la tarea y vuelve por donde fue (de camino a casa sigue con su rodeo)
	if PERSONAS.has(nombre):
		if modo != "libre":
			return
		pide = (ir_por(regreso) if not regreso.is_empty() else []) + cadena("idle", 1)
		regreso = []
		reserva = Vector2.ZERO
		llego = true
		meta = position
		return
	llego = true
	if modo == "noche":
		if not _otra_cama():
			mundo.suelta_cama(self)
			cama_noche = mundo.cama(position, self)
			pide = ([] if position.distance_to(cama_noche) < 2.0 else ir(cama_noche, false)) + [{"anim": "idle", "vueltas": 1}]
		return
	meta = position
	var otro = destino_seguro()
	if otro != null:
		pide = ir(otro, false) + cadena("idle", 1)


func _tramo_sin_recintos(a: Vector2, b: Vector2) -> bool:
	for k in range(1, 41):
		# (ni por encima de una pieza: el atajo a casa cruzaba la carretilla)
		if mundo.recinto_de(a.lerp(b, k / 40.0)) != "" or mundo.cuerpo_toca(self, a.lerp(b, k / 40.0)) > 0.0:
			return false
	return true


func _otra_cama() -> bool:
	## de noche, sin paso hasta su sitio: el sitio libre más cercano de su mismo recinto (como uno de verdad, que se echa
	## donde puede)
	if modo != "noche" or mundo.recinto_de(position) != mundo.recinto_de(cama_noche) or position.distance_to(cama_noche) > 220.0:
		return false
	mundo.suelta_cama(self)
	cama_noche = mundo.cama(position, self)
	_rodeos = 0
	pide = ([] if position.distance_to(cama_noche) < 2.0 else ir(cama_noche, false)) + [{"anim": "idle", "vueltas": 1}]
	return true


func _rodeo() -> bool:
	## tapado en un camino que no puede perder: un paso a un lado y, desde ahí, a donde iba y lo que le quedaba
	var v: Vector2 = (paso["a"] - position).normalized()
	var lado := Vector2(-v.y, v.x)
	var todo := {"b": Rect2(0, 0, float(mundo.E["W"]), float(mundo.E["H"])), "agua": tiene("swim")}
	var rec: String = mundo.recinto_de(position)
	for k in [16.0, -16.0, 28.0, -28.0, 40.0, -40.0, 56.0, -56.0]:
		var q: Vector2 = position + lado * k + v * 6.0
		if mundo.recinto_de(q) != rec or not mundo.libre(q, todo, 0.0, self) or not mundo.sin_nadie(q, self) \
				or not mundo.camino_libre(position, q, todo, 0.0, self):
			continue
		var anda: String = paso["anim"]
		pide = [{"anim": anda, "a": q, "vel": paso["vel"], "rodeo": true},
			{"anim": anda, "a": paso["a"], "vel": paso["vel"], "rodeo": true}] + cola.duplicate()
		return true
	return false


func _cuadro() -> int:
	## el fotograma que se ve: el de ahora, o contando desde el final si el paso va al revés (levantarse)
	if paso.get("reversa", false):
		return pista()["ms"].size() - 1 - fotograma
	return fotograma


func dibuja() -> void:
	var vuela: bool = paso.get("vuela", false)
	var con_sombra: bool = vuela and not REPRODUCE_GUION   # en el vídeo, volando sin sombra (norma del pack)
	if _sombra_vuelo.visible != con_sombra:
		_sombra_vuelo.visible = con_sombra
		_sombra_vuelo.queue_redraw()
	var p := pista()
	var xy: Array = p["xy"][mini(_cuadro(), p["xy"].size() - 1)]   # al cambiar de pista, el fotograma puede quedar fuera un instante
	var alto := int(d["h"])
	if not paso.get("vuela", false) and not paso["anim"] in ["despegue", "aterrizaje"] \
			and not paso["anim"].begins_with("swim") and mundo.agua(position):
		# nadando: lo que queda por debajo de la línea de flotación no se ve
		alto = int(d["pie"]) - int((float(d["pie"]) - float(d["tope"])) * 0.3)
	spr.region_rect = Rect2(xy[0], xy[1], int(d["w"]), alto)
	if mundo.sfx:
		mundo.sfx.cuadro(self)   # el efecto de la acción en su fotograma de contacto (sonido.gd)


func huella(p: Vector2) -> Rect2:
	## lo que ocupa su cuerpo, mire hacia donde mire, si estuviera en p: para que nadie se le meta encima
	if _envolvente.size.x == 0.0:
		for v in _cuerpo:
			_envolvente = _cuerpo[v] if _envolvente.size.x == 0.0 else _envolvente.merge(_cuerpo[v])
		if _envolvente.size.x == 0.0:
			var w := float(d["w"]) * 0.6
			var alto := float(d["pie"]) - float(d.get("tope", 0))
			_envolvente = Rect2(-w / 2.0, -alto, w, alto)
	return Rect2(p + _envolvente.position, _envolvente.size)


func _dibuja_sombra_vuelo() -> void:
	## elipse llena de píxel entero, oscura y fría como las del pack, algo más pequeña que el cuerpo
	var rx := maxf(4.0, float(d["sombra"].get(dir, d["sombra"].get("east", 16))) * 0.4)
	var ry := maxf(2.0, rx * 0.35)
	for yy in range(-int(ry), int(ry) + 1):
		var ancho := rx * sqrt(maxf(0.0, 1.0 - pow(yy / ry, 2.0)))
		_sombra_vuelo.draw_rect(Rect2(roundf(-ancho), yy, roundf(ancho * 2.0) + 1, 1), Color(0.11, 0.09, 0.16, 0.32))


func caja_anim() -> Rect2:
	## lo que ocupa el cuerpo en el fotograma de ahora (sus píxeles opacos), suavizado para que las esquinas ciñan el
	## dibujo sin bailar a cada fotograma: siguen a la cabeza cuando baja a comer y vuelven cuando sube
	var xy: Array = pista()["xy"][_cuadro()]
	var k := str(xy)
	if not _caja_pista.has(k):
		_caja_pista[k] = _opaco([xy])
	var c: Rect2 = _caja_pista[k]
	if c.size.x == 0.0:
		return caja()
	var ahora := Time.get_ticks_msec() / 1000.0
	if _caja_suave.size.x == 0.0 or ahora - _caja_suave_t > 0.5:
		_caja_suave = c
	else:
		var f := clampf((ahora - _caja_suave_t) * 6.0, 0.0, 1.0)
		_caja_suave = Rect2(_caja_suave.position.lerp(c.position, f), _caja_suave.size.lerp(c.size, f))
	_caja_suave_t = ahora
	return Rect2(position + _caja_suave.position, _caja_suave.size)


func _opaco(xys: Array) -> Rect2:
	if _img == null:
		return Rect2()
	var x0 := 9999
	var y0 := 9999
	var x1 := -1
	var y1 := -1
	for xy in xys:
		for y in int(d["h"]):
			for x in int(d["w"]):
				if _img.get_pixel(int(xy[0]) + x, int(xy[1]) + y).a > 0.7:
					x0 = mini(x0, x)
					y0 = mini(y0, y)
					x1 = maxi(x1, x)
					y1 = maxi(y1, y)
	if x1 < 0:
		return Rect2()
	return Rect2(x0 - int(d["w"]) / 2, y0 - int(d["pie"]), x1 - x0 + 1, y1 - y0 + 1)


func caja() -> Rect2:
	## lo que ocupa el cuerpo en el idle de esta vista, para el clic y las esquinas de latón
	if _cuerpo.has(dir):
		var c: Rect2 = _cuerpo[dir]
		return Rect2(position + c.position, c.size)
	var w := float(d["sombra"].get(dir, d["sombra"].get("south", 20)))
	var alto := float(d["pie"]) - float(d.get("tope", 0))
	return Rect2(position.x - w / 2.0, position.y - alto, w, alto + 1)

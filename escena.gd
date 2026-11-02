extends Node2D
## La granja viva. Lee datos/escena.json (lo genera _tools/web_demo_granja.py --godot desde plano_granja.json, el
## kit de la escena y el pack), monta el suelo, las piezas y los animales en un mundo con Y-sort, y deja recorrerlo
## con la cámara: arrastrar o WASD/flechas, rueda para el zoom, clic en un animal para abrir su ficha y probar sus
## animaciones en él. Sin tocarlo un rato, la cámara pasea sola por las familias. La interfaz está en ui.gd.
##
## LA COMPOSICIÓN NO SE DECIDE AQUÍ: piezas y recintos vienen del plano; las zonas de los animales (abajo) salen
## de los recintos del plano y se ajustarán a lo que diga la dirección de arte.

const Comp := preload("res://comportamiento.gd")
const DATOS := "res://datos/"

var E: Dictionary
var zonas := {}
var por_nombre := {}
var actores: Array[Actor] = []
var obst: Array[Rect2] = []
var detras: Array[Rect2] = []
var objetos: Array = []      # las piezas sólidas, medidas en su imagen: {n, img, o, pie, dib, filas, suelo} (ver _solidos)
var viento: Array[Sprite2D] = []
var mundo: Node2D
var cam: Camera2D
var ui
var marco: Node2D          # esquinas de latón sobre el animal elegido o el que está bajo el ratón
var elegido: Actor = null
var bajo_raton: Actor = null
var tocado := false        # si alguien ha usado ya los controles (se apaga la ayuda)
var noche := false
var luz: CanvasModulate
var puertas: Array = []     # {spr, centro, abierta, hasta, recinto, dentro, fuera}
var _mascara: Image          # el agua del suelo (la del vídeo: azul por encima del rojo)
var ambiente                # la vida de ambiente de la escena aprobada (ambiente.gd)
# el día del jugador (usuario 25-10: «el ciclo del vídeo dura muy poco; en la web el tiempo pasa poco a poco, o lo cambia
# quien juega»): 10 minutos por día. Crítico 26-10 (punto 1): cada hora con su luz, todas ≤ 1 (el motor no pasa de 1):
# mañana cálida, mediodía blanco, tarde dorada, ocaso, noche azul y alba rosada
const DIA_S := 600.0
const LUZ_CLAVES := [[0.0, Color(1.0, 0.91, 0.80)], [90.0, Color(1.0, 0.92, 0.81)], [150.0, Color(1.0, 1.0, 1.0)],
	[270.0, Color(1.0, 0.98, 0.94)], [330.0, Color(1.0, 0.86, 0.66)], [385.0, Color(0.98, 0.70, 0.52)],
	[412.0, Color(0.60, 0.52, 0.68)], [440.0, Color(0.29, 0.29, 0.50)], [545.0, Color(0.29, 0.29, 0.50)],
	[565.0, Color(0.58, 0.54, 0.70)], [585.0, Color(0.98, 0.80, 0.80)], [600.0, Color(1.0, 0.91, 0.80)]]
const NOCHE_G := 0.29         # el verde de la noche cerrada: oscuridad 1
const ENCIENDE := 392.0       # las luces de la granja, con el ocaso (crítico 26-10, punto 3)
const APAGA := 585.0
var VIDEO := "--video" in OS.get_cmdline_user_args()
var ritmo_dia := 1.0          # 1 en la demo; en el vídeo de la tienda, el día entero en 90 s
var hora := 60.0              # segundos del día (empieza por la mañana)
var _hora_destino = null      # al pulsar NIGHT o DAY: hacia dónde corre el reloj, deprisa
var oscuridad := 0.0
var _granjeros_en_casa := false
var _voces: Array[AudioStreamPlayer2D] = []
var _ultima_voz := {}        # animal -> cuándo sonó por última vez (que nadie repita sin parar)
var sonido := true
var _amb_dia: AudioStreamPlayer
var _amb_viento: AudioStreamPlayer
var _amb_noche: AudioStreamPlayer
var sfx                      # el sonido: voces, efectos en su fotograma y ambiente por hora (sonido.gd)
var ultimo_gesto := 0.0
var gira := 0
var ir_a = null
var arrastre = null
var reloj := 0.0
var estanque := {}
var verjas := {}             # recinto -> [{centro, dentro, fuera}]: por donde se entra y se sale (del plano)
var _camas: Array = []       # [animal, huella] de los sitios de noche ya repartidos esta noche
var _tarea := {}             # granjero -> índice de la última tarea de su jornada (RUTINA)
var _pendientes := {}        # granjero -> índices de las tareas que ya tocaban y esperan a que acabe la anterior
var _espera_granjeros := 0.0 # con NIGHT, cuánto lleva el reloj esperando a que entren en casa
# las estaciones (Game Off 2026, tema SHIFT): el decorado lleva este material; los animales no
var mat_estacion := ShaderMaterial.new()
var invierno := 0.0          # 0..1, lo que lee el shader (global uniform «invierno»)
var invierno_meta := 0.0     # hacia dónde va: el cambio tarda CAMBIO_ESTACION segundos, píxel a píxel
var otono := 0.0             # lo mismo para el otoño (global uniform «otono»); el invierno va por encima
var otono_meta := 0.0
var estacion_i := 0          # 0 verano, 1 otoño, 2 invierno: el botón las va rotando
const ESTACIONES := ["SUMMER", "AUTUMN", "WINTER"]
const CAMBIO_ESTACION := 2.0


func _ready() -> void:
	randomize()
	mat_estacion.shader = load("res://estacion.gdshader")
	if "--invierno" in OS.get_cmdline_user_args():
		estacion_i = 2
	elif "--otono" in OS.get_cmdline_user_args():
		estacion_i = 1
	otono = 1.0 if estacion_i >= 1 else 0.0
	otono_meta = otono
	invierno = 1.0 if estacion_i == 2 else 0.0
	invierno_meta = invierno
	if "--cambia" in OS.get_cmdline_user_args():
		get_tree().create_timer(4.0).timeout.connect(cambia_estacion)   # para grabar el cambio de estación
	RenderingServer.global_shader_parameter_set("invierno", invierno)
	RenderingServer.global_shader_parameter_set("otono", otono)
	E = JSON.parse_string(FileAccess.get_file_as_string(DATOS + "escena.json"))
	var suelo := Sprite2D.new()
	suelo.texture = load(DATOS + "suelo.png")
	suelo.centered = false
	suelo.z_index = -1
	add_child(suelo)
	_mascara = (load(DATOS + "agua.png") as Texture2D).get_image()   # el agua del suelo (la del vídeo)
	ambiente = preload("res://ambiente.gd").new()
	add_child(ambiente)
	ambiente.prepara(self)
	ambiente.suelo_con_trigo(suelo)
	mundo = Node2D.new()
	mundo.y_sort_enabled = true
	add_child(mundo)
	_piezas()
	_zonas()
	_animales()
	var borde := Node2D.new()
	borde.z_index = 30
	borde.draw.connect(func():
		var w := float(E["W"])
		var h := float(E["H"])
		for r in [Rect2(-2000, -2000, w + 4000, 2000), Rect2(-2000, h, w + 4000, 2000), Rect2(-2000, 0, 2000, h), Rect2(w, 0, 2000, h)]:
			borde.draw_rect(r, Color("1c1228")))
	add_child(borde)
	marco = Node2D.new()
	marco.z_index = 10
	marco.draw.connect(_dibuja_marco)
	add_child(marco)
	_camara()
	sfx = preload("res://sonido.gd").new()   # (sustituye a _ambiente(): nada suena antes del primer clic)
	add_child(sfx)
	sfx.prepara(self)
	luz = CanvasModulate.new()
	add_child(luz)
	ui = preload("res://ui.gd").new()
	ui.layer = 5   # por encima de la luz de las ventanas y las luciérnagas (capa 1)
	ui.E = E
	add_child(ui)
	ui.noche_cambiada.connect(pon_noche)
	ui.estacion_pulsada.connect(cambia_estacion)
	ui.pon_estacion(ESTACIONES[estacion_i], estacion_i > 0)
	ui.sonido_cambiado.connect(pon_sonido)
	ui.familia_elegida.connect(func(n):
		elige(por_nombre[n])
		ultimo_gesto = reloj
		_usado())
	ui.accion_elegida.connect(func(a): if elegido: elegido.haz(a, true))
	ui.cerrar_ficha.connect(func(): elige(null))
	cam.position = Vector2(float(E["W"]), float(E["H"])) / 2.0
	# la granja entera se encaja en lo que dejan libre las placas: cuando la interfaz ya se ha medido
	# (salvo si se graba con --z: el zoom pedido manda; crítico 26-10, punto 0)
	get_tree().create_timer(0.05).timeout.connect(func(): if elegido == null and not "--z" in OS.get_cmdline_user_args(): _ajusta_zoom())
	# para grabar (Movie Maker, ver _tools/grabar_escena_godot.py): -- --x 330 --y 480 --z 2 --fija
	var args := OS.get_cmdline_user_args()
	for i in args.size() - 1:
		match args[i]:
			"--x": cam.position.x = float(args[i + 1])
			"--y": cam.position.y = float(args[i + 1])
			"--z": cam.zoom = Vector2.ONE * float(args[i + 1])
	if "--fija" in args:
		ultimo_gesto = 1e9
	if "--video" in args:
		# el vídeo de 90 s de la tienda: la granja entera, un día completo que cierra en bucle, con sonido desde el
		# principio y sin ayudas ni placas (solo la marca)
		ultimo_gesto = 1e9
		ritmo_dia = DIA_S / 90.0
		hora = 147.0   # 0-35 s día, 35-45 atardecer, 45-65 noche, 65-80 alba, 80-90 mañana: a los 90 s, otra vez 147 (bucle)
		# se graba con un override.cfg de base 1280x720 (_tools/grabar_video_granja.py): la granja (1280x720) cabe
		# entera a 1:1, nítida
		cam.zoom = Vector2.ONE
		cam.position = Vector2(float(E["W"]), float(E["H"])) / 2.0
		get_tree().create_timer(0.1).timeout.connect(func():
			for c in [ui.arriba, ui.abajo, ui.placa_ayuda, ui.pistas_ficha]:
				c.visible = false
				c.modulate.a = 0.0
			# la marca, a 1:1 en pantalla como en la demo, arriba a la derecha con aire (usuario 26-10: «más abajo y más
			# hacia dentro»; MARCA.md pide al menos una letra de margen)
			var t: Vector2 = ui.rotulo.texture.get_size()
			ui.rotulo.scale = Vector2.ONE
			ui.rotulo.position = Vector2(get_viewport().get_visible_rect().size.x - t.x - 56, 44)
			# los ratones del trigal, fuera del vídeo: su guion los deja en el borde de las espigas (usuario 26-10: «queda
			# pegote»); mejor menos animales que uno mal puesto
			for r in actores:
				if r.base == "Raton" and r.position.x > 560.0 and r.position.y < 390.0:
					r.visible = false
					r.set_process(false)
					r.position = Vector2(-5000, -5000)
			for g in actores:
				if es_persona(g) and RUTINA.has(g.nombre):
					var s0: Array = _sitio_tarea(g, String(RUTINA[g.nombre][0][1]))
					if not s0.is_empty():
						g.position = s0[0]
					g.sp["vel"] = float(g.sp["vel"]) * 2.2   # el reloj va ×6,7: al alba vuelven a su sitio antes del final
			# los patos vuelan un poco: despegar, volar y posarse (usuario 26-10)
			for par in [["PatoMacho", 16.0], ["PatoDomestico", 26.0], ["PatoMacho", 84.0]]:
				if por_nombre.has(par[0]):
					var pato: Actor = por_nombre[par[0]]
					get_tree().create_timer(float(par[1])).timeout.connect(func(): _vuelo_rio(pato))
			sfx._empieza_ambiente())
	if "--visor" in args:
		get_tree().create_timer(0.5).timeout.connect(func():
			var i_de := args.find("--de")   # el visor de una criatura concreta: -- --visor --de Gallina
			if i_de >= 0 and i_de + 1 < args.size():
				ui.abre_visor(args[i_de + 1])
			else:
				ui.abre_visor()
			var i_acc := args.find("--accion")   # para grabar el visor con una acción: -- --visor --accion WALK
			if i_acc >= 0 and i_acc + 1 < args.size():
				ui.visor._salta_a(args[i_acc + 1]))
	if "--prueba_rendimiento" in args:
		# cuánto tarda cada fotograma (proceso y dibujo), de día y de noche, en un archivo (para la web: el WASM va
		# más lento que el nativo; con margen de sobra aquí, allí no da tirones)
		var salida := OS.get_cmdline_user_args()[args.find("--prueba_rendimiento") + 1]
		var muestras := {"dia": [], "noche": []}
		var mide := func(fase: String):
			muestras[fase].append([Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0, Performance.get_monitor(Performance.TIME_FPS),
				Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
		for k in range(30):
			get_tree().create_timer(5.0 + k * 0.2).timeout.connect(func(): mide.call("dia"))
		get_tree().create_timer(12.0).timeout.connect(func(): pon_noche(true))
		for k in range(30):
			get_tree().create_timer(20.0 + k * 0.2).timeout.connect(func(): mide.call("noche"))
		get_tree().create_timer(27.0).timeout.connect(func():
			var f := FileAccess.open(salida, FileAccess.WRITE)
			muestras["ambiente_us"] = ambiente.us
			muestras["actores_us"] = Actor.us_total
			muestras["escena_us"] = _us_escena
			f.store_string(JSON.stringify(muestras))
			f.close()
			get_tree().quit())
	if "--prueba_solape" in args:
		# cuántas veces dos animales (que no son madre y cría) se tapan más de 4 px², cada medio segundo durante 5 min;
		# a los 150 s cae la noche
		var cuenta := [0, 0, {}]
		get_tree().create_timer(150.0).timeout.connect(func(): pon_noche(true))
		for k in range(600):
			get_tree().create_timer(0.5 + k * 0.5).timeout.connect(func():
				cuenta[1] += 1
				for i in actores.size():
					for j in range(i + 1, actores.size()):
						var a: Actor = actores[i]
						var b: Actor = actores[j]
						# (el que vuela va por el aire: pasar por encima de otro no es taparlo)
						if not a.visible or not b.visible or a.lider() == b or b.lider() == a or a.paso.get("vuela", false) \
								or b.paso.get("vuela", false):
							continue
						var ra: Rect2 = a.huella(a.position).grow(-2.0)
						var rb: Rect2 = b.huella(b.position).grow(-2.0)
						if ra.intersects(rb) and ra.intersection(rb).get_area() > 4.0:
							cuenta[0] += 1
							# quietos: ninguno de los dos anda (arrancar y pararse, walk_start / walk_end, ya es andar)
							var anda := func(x: Actor) -> bool:
								var an: String = x.paso.get("anim", "")
								return x.paso.has("a") or (an.ends_with("_start") or an.ends_with("_end")) \
									and an.split("_")[0] in ["walk", "run", "swim", "fly"]
							var par := ("N " if noche else "D ") + a.nombre + "+" + b.nombre + ("" if anda.call(a) or anda.call(b) else " quietos")
							cuenta[2][par] = cuenta[2].get(par, 0) + 1
							if "--depura" in args and cuenta[2][par] % 40 == 1:
								for x in [a, b]:
									print("  DEPURA ", snappedf(reloj, 0.1), " ", par, " | ", x.nombre, " pos=", x.position.round(), " zona=", x.zona["b"],
										" modo=", x.modo, "/", x.modo_noche, " act=", x.act, " anim=", x.paso.get("anim"), " pide=", x.pide != null,
										" enc=", x.encargo, " man=", x.manual, " esp=", espacio(x.position, x), " meta=", x.meta.round(),
										" lider=", x.lider().nombre if x.lider() else "-"))
		# crítico 26-10: andar sin avanzar (va hacia un sitio y en 3 s se ha movido menos de 3 px); objetivo 0
		var sin_avanzar := [0, {}, {}]
		for k3 in range(100):
			get_tree().create_timer(3.0 + k3 * 3.0).timeout.connect(func():
				var ahora := {}
				for a in actores:
					if a.visible and a.paso.has("a") and not a.manual:
						ahora[a] = a.position
						if sin_avanzar[1].has(a) and a.position.distance_to(sin_avanzar[1][a]) < 3.0:
							sin_avanzar[0] += 1
							sin_avanzar[2][a.nombre] = sin_avanzar[2].get(a.nombre, 0) + 1
				sin_avanzar[1] = ahora)
		get_tree().create_timer(302.0).timeout.connect(func():
			print("SOLAPE_SIN_AVANZAR ", sin_avanzar[0], " ", sin_avanzar[2])
			var peores: Array = cuenta[2].keys()
			peores.sort_custom(func(x, y): return cuenta[2][x] > cuenta[2][y])
			var quietos := 0
			for p in cuenta[2]:
				if String(p).ends_with(" quietos"):
					quietos += cuenta[2][p]
			var por := {"granjeros": 0, "noche": 0, "dia": 0}
			for p in cuenta[2]:
				var k := "granjeros" if ("granjero" in String(p) or "washerwoman" in String(p)) else ("noche" if String(p).begins_with("N ") else "dia")
				por[k] += cuenta[2][p]
			print("SOLAPE_ATRAVIESAN ", Actor.atraviesan)
			print("SOLAPE_POR ", por, " ", peores.slice(0, 16).map(func(p): return "%s=%d" % [p, cuenta[2][p]]))
			print("SOLAPE ", cuenta[0], " en ", cuenta[1], " muestras (", quietos, " de quietos); peores: ", peores.slice(0, 6).map(func(p): return "%s=%d" % [p, cuenta[2][p]]),
				"; quietos: ", peores.filter(func(p): return String(p).ends_with(" quietos")).map(func(p): return "%s=%d" % [p, cuenta[2][p]]))
			get_tree().quit())
	if "--prueba_fisica" in args:
		_prueba_fisica()
	if "--mamar_todos" in args:
		# para grabar las crías mamando: cada 12 s, todas las que tienen madre cerca se ponen a mamar
		for k in range(8):
			get_tree().create_timer(3.0 + k * 12.0).timeout.connect(func():
				for a in actores:
					if Comp.MAMAN.has(a.base) and a.lider() != null and a.position.distance_to(a.lider().position) < 160.0 \
							and a.act != "mamar":
						a.haz("suckle")
						a.encargo = true)
		for k2 in range(100):
			get_tree().create_timer(1.0 + k2).timeout.connect(func():
				for a in actores:
					if a.paso.get("anim", "") == "suckle" and a.lider() != null:
						print("MAMA ", snappedf(reloj, 0.1), " ", a.nombre, " ", a.position.round(), " ", a.dir, " madre=", a.lider().nombre,
							" ", a.lider().position.round(), " ", a.lider().dir, " anim=", a.paso.get("anim"), " cola=", a.cola.map(func(x): return x["anim"])))
	if "--prueba_abanico" in args:
		# qué animaciones ha hecho cada uno a los 5 minutos (para ver que sale todo el repertorio)
		# crítico 26-10: lo que se ha VISTO (lo que ha empezado de verdad), no lo que ha decidido
		get_tree().create_timer(300.0).timeout.connect(func():
			var con_faltas := 0
			var huecos := 0
			for a in actores:
				var faltan := []
				for an in a.d["anims"]:
					# todo salvo la muerte (decisión del usuario 26-10: en la web sólo desde la ficha, nunca solos)
					if an.ends_with("_start") or an.ends_with("_end") or an == "death":
						continue
					if not a._vistas.has(an):
						faltan.append(an)
				if not faltan.is_empty():
					con_faltas += 1
					huecos += faltan.size()
				print("ABANICO ", a.nombre, " visto=", a._vistas.keys(), " falta=", faltan)
			print("ABANICO_RESUMEN ", con_faltas, " de ", actores.size(), " con faltas; ", huecos, " animaciones sin ver")
			get_tree().quit())
	if "--prueba_libre" in args:
		for k in [30.0, 65.0, 95.0, 130.0]:
			get_tree().create_timer(k).timeout.connect(func():
				var cuenta := {}
				for a in actores:
					cuenta[a.modo] = cuenta.get(a.modo, 0) + 1
				print("LIBRE ", snappedf(reloj, 1.0), " ", cuenta))
	if "--prueba_noche" in args:
		# para comprobar el ciclo sin manos: noche, y a los 40 s otra vez de día; a los 110 s, en qué anda cada uno
		get_tree().create_timer(0.5).timeout.connect(func(): pon_noche(true))
		get_tree().create_timer(40.0).timeout.connect(func(): pon_noche(false))
		# en plena noche: los granjeros en casa (invisibles) y cada animal quieto en su sitio de noche, visible
		# (a los 30 s se apunta dónde está cada uno: a los 39, el que sigue andando y ha avanzado va llegando; el que no se
		# ha movido está atascado)
		var antes := {}
		get_tree().create_timer(30.0).timeout.connect(func():
			for a in actores:
				antes[a] = a.position)
		get_tree().create_timer(39.0).timeout.connect(func():
			var mal := 0
			var llegando := 0
			for a in actores:
				var falla := ""
				if a.nombre in ["granjero", "washerwoman"]:
					falla = "fuera de casa" if a.visible else ""
				elif not a.visible:
					falla = "invisible"
				elif a.modo_noche != "activo" and (a.modo != "noche" or a._va_de_camino() or a.position.distance_to(a.cama_noche) > 16.0):
					falla = "sin llegar a su sitio"
					if a._va_de_camino() and a.position.distance_to(antes.get(a, a.position)) > 10.0:
						llegando += 1
						print("NOCHE_LLEGANDO ", a.nombre, " ", a.position.round(), " a ", roundf(a.position.distance_to(a.cama_noche)), " px de su sitio")
						falla = ""
				if falla != "":
					mal += 1
					print("NOCHE_MAL ", a.nombre, " ", falla, " ", a.position.round(), " cama=", a.cama_noche.round(), " ", a.modo, "/", a.modo_noche,
						" anim=", a.paso.get("anim"))
					if "--depura" in args:
						print("  NOCHE_DEPURA toca=", cuerpo_toca(a, a.position), " fis(E,W,S,N)=",
							[Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)].map(func(v): return paso_fisico(a, a.position, a.position + v)),
							" libre(E,W,S,N)=", [Vector2(2, 0), Vector2(-2, 0), Vector2(0, 2), Vector2(0, -2)].map(func(v): return paso_libre(a.position + v, a)),
							" paso=", a.paso, " rodeos=", a._rodeos)
			print("NOCHE_RESUMEN ", mal, " mal de ", actores.size(), ", ", llegando, " aún llegando (hora ", snappedf(hora, 1.0), ")"))
		get_tree().create_timer(110.0).timeout.connect(func():
			var mal := 0
			for a in actores:
				print("MODO ", a.nombre, " ", a.modo, " ", a.position.round(), " visible=", a.visible)
				if not a.visible or a.modo != "libre":
					mal += 1
			print("DIA_RESUMEN ", mal, " sin volver a su vida de día (hora ", snappedf(hora, 1.0), ")"))
	if "--prueba_ficha" in args:
		# como quien juega: elige una vaca, cambia de capa y de miembro, la mata desde la ficha (DEATH) y mira que cae,
		# queda tendida y se levanta deshaciendo la caída; luego pide SUCKLE a un ternero y mira que mama junto a su madre
		get_tree().create_timer(1.0).timeout.connect(func(): elige(por_nombre["Vaca"]))
		get_tree().create_timer(2.0).timeout.connect(func(): ui._otra_capa(1))
		get_tree().create_timer(4.0).timeout.connect(func(): ui._otro_miembro(0))
		var visto := {"tendido": 0.0, "reversa": false, "de_pie": false, "quien": ""}
		get_tree().create_timer(6.0).timeout.connect(func():
			visto["quien"] = elegido.nombre if elegido else "nadie"
			ui.accion_elegida.emit("death"))
		for k in range(80):
			get_tree().create_timer(6.25 + k * 0.25).timeout.connect(func():
				if elegido == null:
					return
				if reloj < elegido._tendido_hasta:
					visto["tendido"] += 0.25
				if elegido.paso.get("reversa", false):
					visto["reversa"] = true
				if visto["reversa"] and elegido.paso.get("anim", "") != "death":
					visto["de_pie"] = true)
		get_tree().create_timer(27.0).timeout.connect(func():
			print("FICHA_MUERTE ", visto["quien"], " tendido=", visto["tendido"], " s, se levanta al revés=", visto["reversa"],
				", de pie=", visto["de_pie"], " -> ", "OK" if visto["tendido"] >= 2.5 and visto["reversa"] and visto["de_pie"] else "FALLA")
			var cria: Actor = null
			for a in actores:
				if a.base == "Ternero" and a.lider() != null:
					cria = a
			elige(cria)
			if cria:
				ui.accion_elegida.emit("suckle"))
		var mamo := {"visto": false, "dist": INF}
		for k in range(100):   # (hasta 25 s: a veces la madre está en la otra punta del corral)
			get_tree().create_timer(27.5 + k * 0.25).timeout.connect(func():
				if elegido and String(elegido.paso.get("anim", "")).begins_with("suckle"):
					mamo["visto"] = true
					if elegido.lider():
						mamo["dist"] = minf(mamo["dist"], elegido.position.distance_to(elegido.lider().position)))
		get_tree().create_timer(53.0).timeout.connect(func():
			print("FICHA_MAMA ", elegido.nombre if elegido else "-", " mama=", mamo["visto"], " a ", snappedf(mamo["dist"], 0.1), " px de su madre -> ",
				"OK" if mamo["visto"] and mamo["dist"] < 40.0 else "FALLA"))
	if "--prueba_reparto" in args:
		_prueba_reparto()
	var i_tr := args.find("--traza")   # para seguir a uno: -- --traza Gallina_negro (cada segundo, en qué anda)
	if i_tr >= 0 and i_tr + 1 < args.size():
		for k in range(300):
			get_tree().create_timer(1.0 + k).timeout.connect(func():
				var x: Actor = por_nombre.get(args[i_tr + 1])
				if x:
					print("TRAZA ", snappedf(hora, 1.0), " ", x.position.round(), " ", x.modo, "/", x.modo_noche, " ", x.paso, " cola=",
						x.cola.map(func(s): return s["anim"]), " rodeos=", x._rodeos, " cama=", x.cama_noche.round(), " cerca=",
						actores.filter(func(o): return o != x and o.visible and o.huella(o.position).intersects(x.huella(x.position).grow(6.0))).map(func(o): return "%s:%s:%s" % [o.nombre, o.modo, o.paso.get("anim")])))
	if "--prueba_casa" in args:
		# la tarde sin prisas (el reloj a su paso desde las 360): a las 440, de noche cerrada, los granjeros ya en casa
		get_tree().create_timer(0.3).timeout.connect(func(): _hora_destino = 360.0)
		for k in range(14):
			get_tree().create_timer(10.0 + k * 10.0).timeout.connect(func():
				for g in actores:
					if g.nombre in ["granjero", "washerwoman"]:
						print("CASA hora=", snappedf(hora, 1.0), " ", g.nombre, " visible=", g.visible, " ", g.position.round(), " ",
							g.modo, "/", g.modo_noche, " anim=", g.paso.get("anim")))
	var i_so := args.find("--prueba_sobre")
	if i_so >= 0 and i_so + 1 < args.size():
		_sobre_prueba = args[i_so + 1]
		get_tree().create_timer(0.3).timeout.connect(func():   # de cerca, que es cuando se nombra
			cam.zoom = Vector2.ONE * 2.0
			if por_nombre.has(_sobre_prueba):
				cam.position = por_nombre[_sobre_prueba].position)
	if "--prueba_huevo" in args:   # para grabar la puesta: -- --elige Gallina --prueba_huevo
		get_tree().create_timer(3.0).timeout.connect(func(): if elegido: elegido.haz("lay_egg", true))
	if "--prueba_mando" in args:
		_prueba_mando()   # para grabar el control sin manos: aprieta teclas como lo haría quien juega
	var i_h := args.find("--hora")   # para grabar otra hora del día con su rutina: corre el reloj hasta ahí
	if i_h >= 0 and i_h + 1 < args.size():
		get_tree().create_timer(0.3).timeout.connect(func(): _hora_destino = float(args[i_h + 1]))
	if "--noche" in args:
		get_tree().create_timer(0.5).timeout.connect(func(): ui.b_noche.button_pressed = true)
	var i_el := args.find("--elige")
	if i_el >= 0 and i_el + 1 < args.size():
		get_tree().create_timer(1.0).timeout.connect(func(): elige(por_nombre[args[i_el + 1]]))


func _prueba_fisica() -> void:
	## cada medio segundo durante 5 min (a los 150 s cae la noche): los animales cuyo cuerpo (lo opaco del fotograma) se
	## cruza más de 4 px² con el dibujo de una pieza (delante o detrás de ella), los que están fuera de su recinto y, en
	## cada fotograma, los que cruzan una valla. Objetivo: 0 en todo
	var c := {"delante": 0, "detras": 0, "fuera": 0, "cruces": 0, "pisan": 0, "muestras": 0, "peores": {}}
	var casa := {}
	var donde := {}
	get_tree().create_timer(0.4).timeout.connect(func():
		for a in actores:
			if not es_persona(a):
				casa[a] = recinto_de(a.position)
				donde[a] = casa[a]
		get_tree().process_frame.connect(func():
			for a in casa:
				if not is_instance_valid(a) or not a.visible:
					continue
				var r := recinto_de(a.position)
				if r != donde[a]:
					c["cruces"] += 1
					var k := "CRUCE %s %s->%s" % [a.nombre, donde[a], r]
					c["peores"][k] = c["peores"].get(k, 0) + 1
					donde[a] = r))
	get_tree().create_timer(150.0).timeout.connect(func(): pon_noche(true))
	for k in range(600):
		get_tree().create_timer(0.5 + k * 0.5).timeout.connect(func():
			c["muestras"] += 1
			for a in actores:
				if not a.visible or a.paso.get("vuela", false):
					continue
				if es_persona(a):
					if pisa_objeto(pies(a, a.position)) > 4.0:
						c["pisan"] += 1
						var kp := "PISA %s" % a.nombre
						c["peores"][kp] = c["peores"].get(kp, 0) + 1
					continue
				if casa.has(a) and recinto_de(a.position) != casa[a]:
					c["fuera"] += 1
					var kf := "FUERA %s de %s" % [a.nombre, casa[a]]
					c["peores"][kf] = c["peores"].get(kf, 0) + 1
				if String(a.paso.get("anim", "")).begins_with("eat"):
					# (comiendo al lado de un comedero: su cuerpo a menos de 6 px del borde, a la misma altura)
					for ob in objetos:
						if Comp.COMEDEROS.any(func(cm): return String(ob["n"]).begins_with(cm)) \
								and Rect2(a.position + envolvente(a).position, envolvente(a).size).grow(6.0).intersects(ob["dib"]):
							c["comen"] = c.get("comen", 0) + 1
							break
				var xy: Array = a.pista()["xy"][a._cuadro()]
				var w := int(a.d["w"])
				var h := int(a.spr.region_rect.size.y)
				var o := a.position + a.spr.offset
				var fr := Rect2(o, Vector2(w, h))
				for ob in objetos:
					var cruce: Rect2 = fr.intersection(ob["dib"])
					if cruce.size.x <= 0.0 or cruce.size.y <= 0.0:
						continue
					var img: Image = ob["img"]
					var n := 0
					for y in range(int(floor(cruce.position.y)), int(ceil(cruce.end.y))):
						for x in range(int(floor(cruce.position.x)), int(ceil(cruce.end.x))):
							var ix := x - int(ob["o"].x)
							var iy := y - int(ob["o"].y)
							var ax := x - int(o.x)
							var ay := y - int(o.y)
							if ix < 0 or iy < 0 or ix >= img.get_width() or iy >= img.get_height() or ax < 0 or ay < 0 or ax >= w or ay >= h:
								continue
							if img.get_pixel(ix, iy).a > 0.5 and a._img.get_pixel(int(xy[0]) + ax, int(xy[1]) + ay).a > 0.7:
								n += 1
					if n > 4:
						var lado := "delante" if a.position.y > float(ob["pie"]) else "detras"
						c[lado] += 1
						var kk := "%s %s %s anim=%s" % [lado.to_upper(), a.nombre, ob["n"], a.paso.get("anim", "")]
						c["peores"][kk] = c["peores"].get(kk, 0) + 1
						if "--depura" in OS.get_cmdline_user_args() and c["peores"][kk] == 1:
							print("  FISICA_DEPURA ", kk, " pos=", a.position, " n=", n, " huella=", a.huella(a.position), " toca=",
								cuerpo_toca(a, a.position), " fotograma=", a._opaco([xy]), " dib=", ob["dib"], " suelo=", ob["suelo"],
								" dir=", a.dir, " modo=", a.modo, " zona=", a.zona["b"]))
	get_tree().create_timer(302.0).timeout.connect(func():
		var peores: Array = c["peores"].keys()
		peores.sort_custom(func(x, y): return c["peores"][x] > c["peores"][y])
		for p in peores.slice(0, 25):
			print("FISICA_PEOR ", c["peores"][p], " ", p)
		print("FISICA delante=", c["delante"], " detras=", c["detras"], " fuera=", c["fuera"], " cruces=", c["cruces"],
			" granjeros_pisan=", c["pisan"], " en ", c["muestras"], " muestras; comiendo junto a un comedero: ", c.get("comen", 0))
		get_tree().quit())


func _prueba_reparto() -> void:
	## crítico visual 26-10: la vida repartida por el mapa. Cada 2 s durante 5 min: por dónde andan los granjeros, cuántos
	## animales hay en el patio, cuántas gallinas sueltas y a qué distancia mínima entre ellas, y cuántas se apiñan en la
	## verja del gallinero
	var granjeros := {"oeste": 0, "centro": 0, "este": 0}
	var patio_n: Array = []
	var gallinas_n: Array = []
	var gallinas_verja: Array = []
	var hueco_min := INF
	var en_valla := {}   # quién ha pisado la valla de atrás de su recinto (crítico visual 26-10, encargo 5)
	var lineas := {}
	for k in E["recintos"]:
		var c: Array = E["recintos"][k]["caja"]
		lineas[k] = valla_detras(Rect2(float(c[0]), float(c[1]), float(c[2]) - float(c[0]), float(c[3]) - float(c[1])))
	var pv: Vector2 = verja("aves", Vector2(1000, 380))["centro"] if verjas.has("aves") else Vector2(-999, -999)
	for k in range(145):
		await get_tree().create_timer(2.0).timeout
		var en_patio := 0
		var sueltas: Array = []
		var en_verja := 0
		for a in actores:
			if not a.visible:
				continue
			if a.nombre in ["granjero", "washerwoman"]:
				granjeros["oeste" if a.position.x < 500.0 else ("centro" if a.position.x < 760.0 else "este")] += 1
				continue
			if recinto_de(a.position) == "" and zonas["patio"]["b"].has_point(a.position):
				en_patio += 1
				if a.base == "Gallina":
					sueltas.append(a)
			if a.base == "Gallina" and a.position.distance_to(pv) < 40.0:
				en_verja += 1
			var rec := recinto_de(a.position)
			if rec != "" and float(lineas[rec]) > 0.0 and a.position.y < float(lineas[rec]) + 0.35 * a.huella(Vector2.ZERO).size.y - 1.0:
				en_valla[a.nombre] = en_valla.get(a.nombre, 0) + 1
		for i in sueltas.size():
			for j in range(i + 1, sueltas.size()):
				var ra: Rect2 = sueltas[i].huella(sueltas[i].position)
				var rb: Rect2 = sueltas[j].huella(sueltas[j].position)
				var dx := maxf(0.0, maxf(ra.position.x - rb.end.x, rb.position.x - ra.end.x))
				var dy := maxf(0.0, maxf(ra.position.y - rb.end.y, rb.position.y - ra.end.y))
				hueco_min = minf(hueco_min, Vector2(dx, dy).length())
		patio_n.append(en_patio)
		gallinas_n.append(sueltas.size())
		gallinas_verja.append(en_verja)
	var media := func(v: Array) -> float: return snappedf(v.reduce(func(s, x): return s + x, 0) / maxf(1.0, v.size()), 0.1)
	print("REPARTO sueltas de día: ", actores.filter(func(a): return a.patio_de_dia).map(func(a): return a.nombre))
	print("REPARTO granjeros ", granjeros, " · en el patio ", media.call(patio_n), " de media (mín ", patio_n.min(), ") · gallinas sueltas ",
		media.call(gallinas_n), " (mín ", gallinas_n.min(), ", máx ", gallinas_n.max(), ") · hueco mínimo entre ellas ", snappedf(hueco_min, 0.1),
		" px · gallinas en la verja ", media.call(gallinas_verja))
	print("REPARTO pisan la valla de atrás: ", en_valla)


func _prueba_mando() -> void:
	await get_tree().create_timer(4.0).timeout
	for paso in [[[KEY_D], 2.2], [[], 1.2], [[KEY_W], 1.0], [[], 1.0], [[KEY_SHIFT, KEY_A], 1.4], [[], 1.0],
			[[KEY_S], 0.8], [[], 1.0]]:
		for k in paso[0]:
			_tecla(k, true)
		await get_tree().create_timer(paso[1]).timeout
		for k in paso[0]:
			_tecla(k, false)


func _tecla(k: Key, abajo: bool) -> void:
	var ev := InputEventKey.new()
	ev.physical_keycode = k
	ev.keycode = k
	ev.pressed = abajo
	Input.parse_input_event(ev)


# ------------------------------------------------------------------------------------------------------ escenario
func _piezas() -> void:
	var texturas := {}
	for s in E["sprites"]:
		var n: String = s[0]
		var im: Dictionary = E["imagenes"][n]
		if not texturas.has(n):
			texturas[n] = load(DATOS + im["archivo"])
		# el nodo va en la línea del pie (orden), que es por donde ordena el Y-sort; el dibujo, donde toca
		var nodo := Node2D.new()
		nodo.position = Vector2(s[1], s[3])
		var spr := Sprite2D.new()
		spr.texture = texturas[n]
		spr.centered = false
		spr.offset = Vector2(0, float(s[2]) - float(s[3]))
		spr.material = mat_estacion
		var ruta_nieve: String = DATOS + String(im["archivo"]).get_basename() + "_nieve.png"
		if ResourceLoader.exists(ruta_nieve):
			# tejado y paja enteros bajo la nieve (crítico del usuario 02-11)
			var mat := mat_estacion.duplicate() as ShaderMaterial
			mat.set_shader_parameter("mascara", load(ruta_nieve))
			mat.set_shader_parameter("con_mascara", true)
			mat.set_shader_parameter("capa", n in ["molino", "conejera", "gallinero_1", "patos_1"])
			spr.material = mat
		if n == "puerta_abierta" and E.has("puertas"):
			# las puertas empiezan cerradas; se abren cuando llega alguien (ver _puertas)
			var pe: Dictionary = E["puertas"]
			var origen := Vector2(float(s[1]), float(s[2])) - Vector2(pe["puerta_abierta"]["recorte"][0], pe["puerta_abierta"]["recorte"][1])
			spr.texture = load(DATOS + pe["puerta_cerrada"]["archivo"])
			spr.offset = origen - nodo.position
			puertas.append({"spr": spr, "origen": origen, "nodo": nodo, "abierta": false, "hasta": 0.0,
				"centro": origen + Vector2(pe["puerta_cerrada"]["w"] / 2.0, float(s[3]) - origen.y),
				"tex_abierta": load(DATOS + pe["puerta_abierta"]["archivo"]), "tex_cerrada": spr.texture})
		elif n == "molino":
			# el molino: las aspas giran un cuarto de vuelta cada 1,25 s (lienzo entero: la posición no salta)
			spr.hframes = int(im["cuadros"])
			spr.offset += Vector2(im["dx"], im["dy"])
		elif im.has("cuadros"):
			spr.hframes = int(im["cuadros"])
			spr.offset += Vector2(im["dx"], im["dy"])
			viento.append(spr)
		nodo.add_child(spr)
		mundo.add_child(nodo)
		if n == "molino":
			ambiente.pon_molino(spr, load(DATOS + im["aspas"]), int(im["cuadros"]))
		elif im.has("mece"):
			ambiente.arbol(spr, load(DATOS + im["mece"]), float(s[1]))
	# las anclas (matas sobre el pie de las piezas): un animal que pasa por delante las tapa
	for a in E.get("anclas", []):
		var nodo := Node2D.new()
		nodo.position = Vector2(float(a[1]), float(a[3]))
		var spr := Sprite2D.new()
		spr.texture = load(DATOS + a[0])
		spr.centered = false
		spr.offset = Vector2(0, float(a[2]) - float(a[3]))
		spr.material = mat_estacion
		nodo.add_child(spr)
		mundo.add_child(nodo)
	# nadie se para detrás de algo alto (casas, árboles, plantas grandes), donde sólo asomaría la cabeza
	for s in E["sprites"]:
		var n: String = s[0]
		var im: Dictionary = E["imagenes"][n]
		var h := float(im["h"])
		if h < 40 or n.begins_with("valla") or n.begins_with("puerta") or n == "molino":
			continue
		var w := float(im["w"])
		detras.append(Rect2(float(s[1]) + w * 0.04, float(s[3]) - h * 0.95, w * 0.92, h * 0.95))
	_solidos(texturas)


func _solidos(texturas: Dictionary) -> void:
	## usuario 26-10: «tiene que tener sus físicas bien hechas». Cada pieza del decorado (comederos, heno, pozo, casas,
	## caseta del estanque, árboles…) se mide en su imagen al cargar: lo opaco de su dibujo, fila a fila (de qué x a qué
	## x), y su huella sólida en el suelo (la franja baja opaca). Nadie pisa la huella; ningún animal se dibuja encima del
	## dibujo (ni delante tapándolo ni detrás asomando)
	for s in E["sprites"]:
		var n: String = s[0]
		if n.begins_with("valla") or n.begins_with("puerta"):
			continue
		var im: Dictionary = E["imagenes"][n]
		var img: Image = (texturas[n] as Texture2D).get_image()
		if img == null:
			continue
		if img.is_compressed():
			img.decompress()
		var o := Vector2(float(s[1]), float(s[2]))
		if im.has("cuadros"):
			# (tira de cuadros: el primero, que es el que está quieto)
			img = img.get_region(Rect2i(0, 0, img.get_width() / int(im["cuadros"]), img.get_height()))
			o += Vector2(float(im["dx"]), float(im["dy"]))
		var filas := PackedFloat32Array()
		var y0 := -1
		var y1 := -1
		var x0 := 99999.0
		var x1 := -1.0
		for y in img.get_height():
			var a := -1
			var b := -1
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.5:
					if a < 0:
						a = x
					b = x
			filas.append(float(a) if a >= 0 else 1e9)
			filas.append(float(b + 1) if a >= 0 else -1e9)
			if a >= 0:
				if y0 < 0:
					y0 = y
				y1 = y
				x0 = minf(x0, float(a))
				x1 = maxf(x1, float(b + 1))
		if y0 < 0:
			continue
		var dib := Rect2(o + Vector2(x0, y0), Vector2(x1 - x0, y1 - y0 + 1))
		# la huella en el suelo: la franja de abajo (un tercio del alto, de 4 a 22 px), de su x más a la izquierda a la más
		# a la derecha en esas filas
		var fondo := clampi(int(float(y1 - y0 + 1) * 0.3), 4, 22)
		var sx0 := 1e9
		var sx1 := -1e9
		for y in range(y1 - fondo + 1, y1 + 1):
			sx0 = minf(sx0, filas[y * 2])
			sx1 = maxf(sx1, filas[y * 2 + 1])
		var suelo := Rect2(o.x + sx0, o.y + float(y1 - fondo + 1), sx1 - sx0, float(fondo))
		objetos.append({"n": n, "img": img, "o": o, "pie": float(s[3]), "dib": dib, "filas": filas, "suelo": suelo})
		obst.append(suelo)


func toca_objeto(r: Rect2) -> float:
	## cuánto dibujo de las piezas cae dentro del rectángulo r (px², fila a fila): 0 si no toca ninguna
	var total := 0.0
	for ob in objetos:
		var dib: Rect2 = ob["dib"]
		if not r.intersects(dib):
			continue
		var o: Vector2 = ob["o"]
		var filas: PackedFloat32Array = ob["filas"]
		var ya := maxi(int(floor(maxf(r.position.y, dib.position.y) - o.y)), 0)
		var yb := mini(int(ceil(minf(r.end.y, dib.end.y) - o.y)), filas.size() / 2)
		for y in range(ya, yb):
			var lo := maxf(r.position.x, o.x + filas[y * 2])
			var hi := minf(r.end.x, o.x + filas[y * 2 + 1])
			if hi > lo:
				total += hi - lo
	return total


func pisa_objeto(r: Rect2) -> float:
	## cuánto pisa r las huellas sólidas del suelo (para los granjeros: rodean las piezas, pasan por delante de las casas)
	var total := 0.0
	var puerta := Vector2(E["casa"]["puerta"][0], E["casa"]["puerta"][1]) if E.has("casa") else Vector2(-999, -999)
	for ob in objetos:
		var o: Rect2 = ob["suelo"]
		# (la casa de los granjeros, no: entran por su puerta)
		if r.intersects(o) and not o.grow(8.0).has_point(puerta):
			total += r.intersection(o).get_area()
	return total


func es_persona(a: Actor) -> bool:
	return a.nombre in ["granjero", "washerwoman"]


func pies(a: Actor, p: Vector2) -> Rect2:
	## lo que pisa una persona en p: el ancho de su cuerpo, una franja de 4 px en los pies
	var h: Rect2 = a.huella(p)
	return Rect2(p.x - h.size.x * 0.3, p.y - 3.0, h.size.x * 0.6, 4.0)


func cuerpo_toca(a: Actor, p: Vector2) -> float:
	## lo que chocaría con el decorado en p: el cuerpo entero de un animal (con un píxel de aire) contra el dibujo de las
	## piezas; los pies de una persona contra su huella
	if es_persona(a):
		return pisa_objeto(pies(a, p))
	var e := envolvente(a)
	return toca_objeto(Rect2(p + e.position, e.size).grow(1.0))


var _envolventes := {}   # nombre -> lo que ocupa con todas sus animaciones (relativo a los pies)


func envolvente(a: Actor) -> Rect2:
	## lo que ocupa su cuerpo en cualquier fotograma de cualquier animación que haga en el suelo (el gallo con las alas
	## arriba, el ratón con la cabeza alzada, el carnero corriendo): el reposo se queda corto contra el decorado. Sin la
	## muerte (sólo desde la ficha) ni el vuelo (va por el aire)
	if _envolventes.has(a.nombre):
		return _envolventes[a.nombre]
	var r := a.huella(Vector2.ZERO)
	if a._img != null:
		var w := int(a.d["w"])
		var h := int(a.d["h"])
		var vistos := {}
		for an in a.d["anims"]:
			if an in ["death", "fly", "despegue", "aterrizaje"]:
				continue
			for v in a.d["anims"][an]:
				for xy in a.d["anims"][an][v]["xy"]:
					var k := "%d,%d" % [int(xy[0]), int(xy[1])]
					if vistos.has(k):
						continue
					vistos[k] = true
					var u := a._img.get_region(Rect2i(int(xy[0]), int(xy[1]), w, h)).get_used_rect()
					if u.size.x > 0:
						r = r.merge(Rect2(float(u.position.x - w / 2), float(u.position.y - int(a.d["pie"])), float(u.size.x), float(u.size.y)))
	_envolventes[a.nombre] = r
	return r


func casa_de(a: Actor) -> String:
	## el recinto con valla donde vive (el de su zona), o "" si vive suelto
	return recinto_de(a.zona["b"].abs().get_center())


func paso_fisico(a: Actor, desde: Vector2, q: Vector2) -> bool:
	## el paso de desde a q no le mete en el decorado (más de lo que ya está) ni le saca de su recinto, ni le mete en uno
	## ajeno: ninguna valla se cruza (tampoco en diagonal entre dos postes ni por una esquina: la caja es el recinto
	## entero). Los granjeros tampoco entran en ningún recinto: las verjas no se abren (usuario 26-10: «atravesar la
	## puerta cerrada no tiene ningún sentido»); todo lo hacen desde fuera de la valla. Los ratones no pisan el trigal
	var rq := recinto_de(q)
	var rd := recinto_de(desde)
	if es_persona(a):
		if rq != "" and rq != rd:
			return false
	elif rq != rd and (rd != "" or rq != casa_de(a)):
		return false
	if a.base == "Raton" and es_trigal(q) and (not es_trigal(desde) or q.distance_to(_fuera_del_trigal(desde)) >= desde.distance_to(_fuera_del_trigal(desde))):
		return false   # nunca se mete; si ya está dentro, solo puede salir
	var antes := cuerpo_toca(a, desde)
	var luego := cuerpo_toca(a, q)
	return luego <= 0.0 or (antes > 0.0 and luego <= antes)   # (si ya lo toca, puede salir o bordearlo, nunca meterse más)


func _fuera_del_trigal(p: Vector2) -> Vector2:
	## el punto sin trigo más cercano (en pasos de 8 px), para que un ratón que esté dentro solo pueda salir
	for r in range(1, 40):
		for d in [Vector2(0, 1), Vector2(-1, 0), Vector2(1, 0), Vector2(0, -1)]:
			var q: Vector2 = p + d * 8.0 * r
			if not es_trigal(q):
				return q
	return p


var _trigal := PackedByteArray()   # rejilla de 8 px: 1 donde hay trigo (de las espigas de trigo_sube.png, ensanchadas)


func es_trigal(p: Vector2) -> bool:
	## si en p hay trigo: un ratón ahí quedaría pintado encima de las espigas (usuario 26-10: «queda pegote»)
	if _trigal.is_empty():
		var img: Image = (load(DATOS + "trigo_sube.png") as Texture2D).get_image()
		var cw := int(ceil(img.get_width() / 8.0))
		var ch := int(ceil(img.get_height() / 8.0))
		var cuenta := PackedInt32Array()
		cuenta.resize(cw * ch)
		for y in img.get_height():
			for x in img.get_width():
				if img.get_pixel(x, y).a > 0.0:
					cuenta[(y / 8) * cw + x / 8] += 1
		_trigal.resize(cw * ch)
		for cy in ch:
			for cx in cw:
				# una celda es trigal si ella o sus vecinas tienen espigas
				var n := 0
				for dy in [-1, 0, 1]:
					for dx in [-1, 0, 1]:
						var x2: int = clampi(cx + dx, 0, cw - 1)
						var y2: int = clampi(cy + dy, 0, ch - 1)
						n += cuenta[y2 * cw + x2]
				_trigal[cy * cw + cx] = 1 if n > 2 else 0
	var cw2 := int(ceil(float(E["W"]) / 8.0))
	var cx2 := clampi(int(p.x) / 8, 0, cw2 - 1)
	var cy2 := clampi(int(p.y) / 8, 0, _trigal.size() / cw2 - 1)
	return _trigal[cy2 * cw2 + cx2] == 1


func _vuelo_rio(pato: Actor) -> void:
	## el vuelo del vídeo (usuario 26-10): del estanque, río abajo por encima del agua, se posa en la orilla, come un
	## poco y vuelve volando a su sitio del estanque; siempre avanzando, sin cruzar casas ni animales
	if not pato.tiene("fly"):
		return
	var orig := pato.position
	var rio: Array = E["arroyo"]
	# la orilla de arriba del río, a la altura del tramo de x 560: lo primero seco subiendo desde el agua
	var en_rio := Vector2(float(rio[5][0]), float(rio[5][1]))
	var orilla := en_rio
	for dy in range(0, 40, 2):
		var q := en_rio - Vector2(0, dy)
		if not agua(q):
			orilla = q - Vector2(0, 3)
			break
	var por_el_rio := Vector2(float(rio[6][0]), float(rio[6][1]) - 6.0)   # sobre el agua, siguiendo el cauce
	pato.deja_guion()
	var ida: Array = pato.vuelo(orilla)
	ida.pop_back()   # (sin el reposo del final: sigue comiendo)
	ida.insert(1, {"anim": "fly", "a": por_el_rio, "vel": 70.0, "vuela": true})
	var vuelta: Array = pato.vuelo(orig)
	pato.pide = ida + pato.cadena("eat", 3) + vuelta
	pato.encargo = true


func _tramo_fisico(a: Actor, desde: Vector2, q: Vector2) -> bool:
	## el tramo recto de desde a q, en 10 muestras, pasa paso_fisico en cada una
	var antes := desde
	for i in range(1, 11):
		var m: Vector2 = desde.lerp(q, float(i) / 10.0)
		if not paso_fisico(a, antes, m):
			return false
		antes = m
	return true



func _zonas() -> void:
	var R: Dictionary = E["recintos"]
	if R.has("aves") and R.has("potrero"):
		_zonas_por_recintos(R)   # el plano del patio en U (v10+): cada recinto, preparado para el visor
		_sin_valla_delante()
		return
	var caja := func(b: Array, m: float) -> Rect2:
		# dentro de la valla, y lejos de la de delante para que no tape las patas
		return Rect2(b[0] + m, b[1] + m + 10, (b[2] - m) - (b[0] + m), (b[3] - 30) - (b[1] + m + 10))
	var prado: Rect2 = caja.call(R["prado"]["caja"], 18)
	var aves: Rect2 = caja.call(R["corral_aves"]["caja"], 18)
	var cercado: Rect2 = caja.call(R["cercado"]["caja"], 18)
	var el: Array = E["estanque"]["elipse"]
	estanque = {"c": Vector2((el[0] + el[2]) / 2.0, (el[1] + el[3]) / 2.0), "r": Vector2((el[2] - el[0]) / 2.0, (el[3] - el[1]) / 2.0)}
	var pieza := func(n: String) -> Dictionary:
		for p in E["piezas"]:
			if p["n"] == n:
				return p
		return {}
	# el plano cambia (lo lleva la sesión de marca): si una pieza ya no está, se usa la siguiente que sirva
	var primera := func(nombres: Array, defecto: Dictionary) -> Dictionary:
		for n in nombres:
			var p: Dictionary = pieza.call(n)
			if not p.is_empty():
				return p
		return defecto
	var henil: Dictionary = primera.call(["aldea_henil", "aldea_granero", "establo_n1"], {"n": "", "x": 480.0, "pie": 200.0})
	var henil_w := float(E["imagenes"][henil["n"]]["w"]) if E["imagenes"].has(henil["n"]) else 120.0
	var abrev: Dictionary = primera.call(["abrevadero_2", "abrevadero_1"], {"n": "", "x": 1160.0, "pie": cercado.end.y - 20})
	var conejera: Dictionary = primera.call(["conejera"], {"n": "", "x": prado.position.x + 60, "pie": prado.position.y + 60})
	var gallinero: Dictionary = primera.call(["gallinero_1"], {"n": "", "x": aves.position.x + 20, "pie": aves.end.y - 10})
	var r := func(x0: float, y0: float, x1: float, y1: float) -> Rect2:
		return Rect2(x0, y0, x1 - x0, y1 - y0)
	zonas = {
		# si el plano tiene conejar (24-10), los conejos viven en él; si no, junto a la conejera del prado
		"conejos": {"b": caja.call(R["conejar"]["caja"], 18)} if R.has("conejar") else 			{"b": r.call(prado.position.x, conejera["pie"] - 30, prado.end.x, conejera["pie"] + 70)},
		# ovejas y cabras se reparten el prado del plano: el rebaño arriba, las cabras abajo (con las rocas)
		"ovejas": {"b": r.call(prado.position.x, prado.position.y, prado.end.x, prado.position.y + prado.size.y * 0.55)},
		"cabras": {"b": r.call(prado.position.x, prado.position.y + prado.size.y * 0.45, prado.end.x, prado.end.y)},
		"aves": {"b": r.call(aves.position.x, aves.position.y, aves.end.x, aves.end.y - 6)},
		"gallo": {"b": r.call(gallinero["x"] - 6, gallinero["pie"] + 2, gallinero["x"] + 110, aves.end.y)},
		"pavos": {"b": r.call(600, 262, 950, 312)},
		"cerdos": {"b": caja.call(R["pocilga"]["caja"], 18)},
		"vacas": {"b": r.call(cercado.position.x + 40, 430, 1040, cercado.end.y)},
		"toro": {"b": r.call(cercado.position.x, cercado.position.y, 930, 520)},
		"caballos": {"b": r.call(1000, cercado.position.y, cercado.end.x, 570)},
		"burros": {"b": r.call(1020, abrev["pie"] - 70, cercado.end.x, cercado.end.y)},
		"agua": {"b": r.call(el[0] - 20, el[1] - 20, el[2] + 20, el[3] + 20), "agua": true, "ok": func(p: Vector2) -> bool: return agua_honda(p)},
		# patos: el estanque y su orilla; en el agua nadan, en la orilla andan
		"pato": {"b": r.call(el[0] - 30, el[1] - 30, el[2] + 30, el[3] + 6).intersection(prado), "agua": true,
			"ok": func(p: Vector2) -> bool: return agua_honda(p) or (not agua(p) and en_agua(p, 1.5))},
		# los gansos, en la orilla: un anillo alrededor del estanque, dentro del prado
		"orilla": {"b": r.call(el[0] - 40, el[1] - 40, el[2] + 40, el[3] + 10).intersection(prado),
			"ok": func(p: Vector2) -> bool: return not agua(p) and not agua(p + Vector2(0, 4)) and en_agua(p, 1.7)},
		"raton": {"b": r.call(henil["x"] + 10, henil["pie"] + 3, henil["x"] + henil_w - 10, henil["pie"] + 12)},
	}
	_sin_valla_delante()


func _sin_valla_delante() -> void:
	# nadie baja hasta la valla de delante de su recinto: detrás de los postes sólo asomaría medio animal (lo mismo
	# que en el visor, que es un zoom de esta granja)
	for z in zonas:
		var b: Rect2 = zonas[z]["b"]
		var valla := valla_delante(b)
		b = b.abs()
		if valla > 0.0 and valla - 2.0 > b.position.y + 8.0:
			b.size.y = minf(b.size.y, valla - 2.0 - b.position.y)
			zonas[z]["b"] = b


func _zonas_por_recintos(R: Dictionary) -> void:
	## cada recinto tiene su casa al fondo y un claro delante (acordado con la sesión del plano): los animales viven en
	## el claro, entre la base de la casa y la valla de delante; los que comparten recinto se lo reparten a lo ancho
	var claro := func(k: String) -> Rect2:
		var c: Array = R[k]["caja"]
		var x0 := float(c[0]) + 18.0
		var x1 := float(c[2]) - 18.0
		var arriba := float(c[1]) + 28.0
		for sp in E["sprites"]:
			var n: String = sp[0]
			if n.begins_with("valla") or n.begins_with("puerta"):
				continue
			var im: Dictionary = E["imagenes"][n]
			var pie := float(sp[3])
			if float(im["h"]) < 40.0 or pie < float(c[1]) or pie > float(c[3]) - 20.0:
				continue
			if float(sp[1]) + float(im["w"]) < x0 or float(sp[1]) > x1:
				continue
			arriba = maxf(arriba, pie + 3.0)   # por delante de la casa (su base), nunca detrás
		return Rect2(x0, arriba, x1 - x0, float(c[3]) - 10.0 - arriba)
	var trozo := func(b: Rect2, de: float, a: float) -> Rect2:
		return Rect2(b.position.x + b.size.x * de, b.position.y, b.size.x * (a - de), b.size.y)
	var aves: Rect2 = claro.call("aves")
	var vacas: Rect2 = claro.call("cercado")
	var pocilga: Rect2 = claro.call("pocilga")
	var prado: Rect2 = claro.call("ovejas")
	var potrero: Rect2 = claro.call("potrero")
	var el: Array = E["estanque"]["elipse"]
	estanque = {"c": Vector2((el[0] + el[2]) / 2.0, (el[1] + el[3]) / 2.0), "r": Vector2((el[2] - el[0]) / 2.0, (el[3] - el[1]) / 2.0)}
	var r := func(x0: float, y0: float, x1: float, y1: float) -> Rect2:
		return Rect2(x0, y0, x1 - x0, y1 - y0)
	var sacos := {}
	for p in E["piezas"]:
		if p["n"] == "lecheras_sacos":
			sacos = p
	var sacos_w := float(E["imagenes"]["lecheras_sacos"]["w"]) if not sacos.is_empty() else 80.0
	zonas = {
		# corral de aves: gallinas a la izquierda (gallinero), pavos en medio (su comedero), conejos a la derecha
		"aves": {"b": trozo.call(aves, 0.0, 0.5)},
		# el gallo, en el patio junto a la verja del corral (plano v11)
		"gallo": {"b": _junto_a_verja(R["aves"]) if R["aves"].has("puertas") else trozo.call(aves, 0.0, 0.55)},
		"pavos": {"b": trozo.call(aves, 0.3, 0.75)},
		"conejos": {"b": trozo.call(aves, 0.6, 1.0)},
		"cerdos": {"b": pocilga},
		"vacas": {"b": vacas},
		"toro": {"b": vacas},
		# ovejas a la izquierda (heno y comedero), cabras a la derecha (roquedal)
		# ovejas y cabras, caballos y burros: cada pareja de especies, por todo su recinto (crítico 26-10: en medio recinto
		# cada una no cabían y se pisaban; el heno y el comedero, el roquedal o el establo siguen siendo de todos)
		"ovejas": {"b": prado},
		"cabras": {"b": prado},
		"caballos": {"b": potrero},
		"burros": {"b": potrero},
		"agua": {"b": r.call(el[0] - 20, el[1] - 20, el[2] + 20, el[3] + 20), "agua": true, "ok": func(p: Vector2) -> bool: return agua_honda(p)},
		# patos y gansos, sueltos por el estanque y su orilla, pero nunca dentro de un recinto con valla ni encima de ella
		"pato": {"b": r.call(el[0] - 30, el[1] - 30, el[2] + 30, el[3] + 6), "agua": true,
			"ok": func(p: Vector2) -> bool: return (agua_honda(p) or (not agua(p) and en_agua(p, 1.5))) and not _en_recinto(p, R) \
				and not _carril(p)},
		"orilla": {"b": r.call(el[0] - 40, el[1] - 40, el[2] + 40, el[3] + 10),
			"ok": func(p: Vector2) -> bool: return not agua(p) and not agua(p + Vector2(0, 4)) and en_agua(p, 1.7) and not _en_recinto(p, R) \
				and not _carril(p)},
		"raton": {"b": r.call(float(sacos.get("x", 448)) + 6, float(sacos.get("pie", 366)) + 3,
			float(sacos.get("x", 448)) + sacos_w - 6, float(sacos.get("pie", 366)) + 14)},
	}
	# el patio de tierra del centro, entre los recintos y por delante de la casa: por donde andan los granjeros y,
	# de día, unas cuantas aves sueltas (crítico 26-10: estaba vacío)
	var casa_pie := 204.0
	for p in E["piezas"]:
		if p["n"] == "aldea_casita_paja":
			casa_pie = float(p["pie"])
	var abajo_y := minf(float(R["ovejas"]["caja"][1]), float(R["potrero"]["caja"][1])) - 16.0
	var patio: Rect2 = r.call(float(R["cercado"]["caja"][2]) + 24.0, casa_pie + 12.0, float(R["aves"]["caja"][0]) - 24.0, abajo_y)
	zonas["patio"] = {"b": patio, "ok": func(p: Vector2) -> bool: return not _en_recinto(p, R)}
	zonas["patio_aves"] = {"b": patio, "ok": func(p: Vector2) -> bool: return not _en_recinto(p, R) and a_la_vista(p)}
	# los conejos viven alrededor de su conejera, en el patio (usuario 25-10); crítico 26-10: su zona salía del trozo
	# del corral de aves unido a sus sitios del patio, una caja que cruzaba la valla del corral, y la atravesaban
	# (y no tan abajo: por debajo pasan los granjeros camino del corral de aves). Los pavos, igual: alrededor del pozo,
	# no en una caja que se metía en el corral de aves
	for p in E["piezas"]:
		if not E["imagenes"].has(p["n"]) or recinto_de(Vector2(float(p["x"]), float(p["pie"]))) != "":
			continue
		var w := float(E["imagenes"][p["n"]]["w"])
		var alrededor := Rect2()
		if p["n"] == "conejera":
			alrededor = Rect2(float(p["x"]) - 70.0, float(p["pie"]) - 14.0, w + 140.0, 56.0).intersection(patio)
			zonas["conejos"] = {"b": alrededor, "ok": func(q: Vector2) -> bool: return not _en_recinto(q, R) and a_la_vista(q)}
		elif String(p["n"]).begins_with("pozo"):
			# (sin el corro del brocal, donde sacan agua los granjeros)
			alrededor = Rect2(float(p["x"]) - 150.0, float(p["pie"]) - 96.0, 116.0, 84.0).intersection(patio)
			var brocal := Rect2(float(p["x"]) - 34.0, float(p["pie"]) - 52.0, w + 68.0, 66.0)
			zonas["pavos"] = {"b": alrededor, "ok": func(q: Vector2) -> bool: return not _en_recinto(q, R) and a_la_vista(q) \
				and not brocal.has_point(q)}
	# las verjas de cada recinto: el centro sobre la valla, un punto dentro y otro fuera
	verjas = {}
	for k in R:
		if not R[k].has("puertas"):
			continue
		var c: Array = R[k]["caja"]
		verjas[k] = []
		for pu in R[k]["puertas"]:
			var u := float(pu[1])
			var centro: Vector2
			var hacia_fuera: Vector2
			match String(pu[0]):
				"N":
					centro = Vector2(u, float(c[1]))
					hacia_fuera = Vector2(0, -1)
				"S":
					centro = Vector2(u, float(c[3]))
					hacia_fuera = Vector2(0, 1)
				"E":
					centro = Vector2(float(c[2]), u)
					hacia_fuera = Vector2(1, 0)
				_:
					centro = Vector2(float(c[0]), u)
					hacia_fuera = Vector2(-1, 0)
			verjas[k].append({"centro": centro, "dentro": centro - hacia_fuera * 18.0, "fuera": centro + hacia_fuera * 16.0,
				"lado": String(pu[0])})


func _carril(p: Vector2) -> bool:
	## el paso de los granjeros entre el cercado y el prado hasta la orilla (crítico 26-10): patos y gansos no se paran en él
	var R: Dictionary = E["recintos"]
	if not R.has("cercado") or not R.has("ovejas"):
		return false
	return p.x > float(R["cercado"]["caja"][2]) - 6.0 and p.x < float(R["ovejas"]["caja"][0]) + 30.0 \
		and p.y < float(R["ovejas"]["caja"][3]) + 50.0


func _junto_a_verja(rec: Dictionary) -> Rect2:
	## un trozo de patio delante de la verja del recinto (por fuera), donde ronda el gallo
	var c: Array = rec["caja"]
	var pu: Array = rec["puertas"][0]
	match String(pu[0]):
		"N":
			return Rect2(float(pu[1]) - 50.0, float(c[1]) - 44.0, 100.0, 30.0)
		"S":
			return Rect2(float(pu[1]) - 50.0, float(c[3]) + 14.0, 100.0, 30.0)
		"E":
			return Rect2(float(c[2]) + 10.0, float(pu[1]) - 10.0, 60.0, 30.0)
	return Rect2(float(c[0]) - 70.0, float(pu[1]) - 10.0, 60.0, 30.0)


func _en_recinto(p: Vector2, R: Dictionary) -> bool:
	## dentro de un recinto con valla, o en su valla (con un margen: que no se le vea encima de los postes)
	for k in R:
		var c: Array = R[k]["caja"]
		if Rect2(float(c[0]) - 22.0, float(c[1]) - 12.0, float(c[2]) - float(c[0]) + 44.0, float(c[3]) - float(c[1]) + 60.0).has_point(p):
			return true
	return false


func recinto_de(p: Vector2) -> String:
	## el recinto con valla en el que está p (dentro de su caja), o ""
	var R: Dictionary = E["recintos"]
	for k in R:
		var c: Array = R[k]["caja"]
		if p.x > float(c[0]) and p.x < float(c[2]) and p.y > float(c[1]) and p.y < float(c[3]):
			return k
	return ""


func verja(k: String, cerca_de: Vector2) -> Dictionary:
	## la verja de ese recinto más cercana a un punto (si no tiene, el centro de su caja: no debería pasar)
	var mejor := {}
	for v in verjas.get(k, []):
		if mejor.is_empty() or v["centro"].distance_to(cerca_de) < mejor["centro"].distance_to(cerca_de):
			mejor = v
	if mejor.is_empty():
		var c: Array = E["recintos"][k]["caja"]
		var m := Vector2((float(c[0]) + float(c[2])) / 2.0, (float(c[1]) + float(c[3])) / 2.0)
		mejor = {"centro": m, "dentro": m, "fuera": m}
	return mejor


func cama(p: Vector2, yo: Actor) -> Vector2:
	## el sitio de noche más cercano a p que no pisa a nadie ni a los sitios ya repartidos esta noche (se reparten en
	## orden: el primero que llega, el de su plan). Crítico 26-10: el pavo y el pavipollo tenían casi el mismo sitio
	var rec := recinto_de(p)
	var R: Dictionary = E["recintos"]
	# crítico visual 26-10: tampoco de noche encima de la valla de atrás (los pies, a un tercio del cuerpo por debajo)
	var tope := -INF
	if rec != "":
		var c0: Array = R[rec]["caja"]
		tope = float(c0[1]) + 14.0
		var linea := valla_detras(Rect2(float(c0[0]), float(c0[1]), float(c0[2]) - float(c0[0]), float(c0[3]) - float(c0[1])))
		if linea > 0.0:
			tope = maxf(tope, linea + 0.35 * yo.huella(Vector2.ZERO).size.y)
		p.y = maxf(p.y, tope)
	for radio in [0.0, 8.0, 14.0, 20.0, 28.0, 38.0, 50.0, 64.0, 80.0]:
		var n := 1 if radio == 0.0 else 16
		var giro := randf() * TAU
		for i in n:
			var ang := giro + TAU * float(i) / float(n)
			var q: Vector2 = p + Vector2(cos(ang) * radio, sin(ang) * radio * 0.6)
			if radio > 0.0:
				# que no cruce de recinto ni pise el decorado o el agua (si no es de agua)
				if recinto_de(q) != rec:
					continue
				if rec != "":
					var c: Array = R[rec]["caja"]
					if q.x < float(c[0]) + 12.0 or q.x > float(c[2]) - 12.0 or q.y < tope or q.y > float(c[3]) - 8.0:
						continue
				if not libre(q, {"b": Rect2(q - Vector2(1, 1), Vector2(2, 2)), "agua": yo.tiene("swim")}, 0.0):
					continue
			if cuerpo_toca(yo, q) > 0.0 or (not es_persona(yo) and recinto_de(q) != rec):
				continue   # ni a dormir encima del decorado (usuario 26-10)
			if false and recinto_de(yo.position) == rec and not _tramo_fisico(yo, yo.position, q):   # desactivado 26-10: empeoraba los atascos (Potro)
				continue   # ni una a la que no llega en recto (se quedaba andando en el sitio contra el decorado)
			if not es_persona(yo) and en_ruta_de_casa(q, yo):
				continue   # ni en el camino de los granjeros a casa (las aves que duermen en el patio)
			var h: Rect2 = yo.huella(q).grow(-1.0)
			var choca := false
			# ni en el paso de la verja: el que duerme ahí cierra el camino a los que vuelven (la gallina que volvía del
			# patio se quedaba en la puerta)
			for v in verjas.get(rec, []):
				if h.grow(4.0).has_point(v["dentro"]) or q.distance_to(v["dentro"]) < 26.0:
					choca = true
			for c2 in _camas:
				var otro: Actor = c2[0]
				# (sólo la cría duerme pegada a su madre; dos adultas que van juntas, cada una en su sitio: si no, al
				# despertarse una antes que la otra quedaban una encima de otra)
				if otro == yo or _madre_y_cria(otro, yo):
					continue
				if h.intersects(c2[1]):
					choca = true
					break
			if not choca:
				# los que están quietos donde están (el ratón, los que ya duermen) también cuentan; los que van andando a su
				# sitio, por su sitio repartido
				for a in actores:
					if a == yo or not a.visible or (a.modo == "noche" and a._va_de_camino()) or _madre_y_cria(a, yo):
						continue
					if h.intersects(a.huella(a.position).grow(-1.0)):
						choca = true
						break
			if not choca:
				_camas.append([yo, yo.huella(q).grow(-1.0)])
				return q
	# sin sitio libre de los demás: al menos, uno que no esté encima del decorado ni fuera de su recinto (si no, no
	# llegaba nunca: el paso no le deja meterse en la pieza)
	if cuerpo_toca(yo, p) > 0.0 or (not es_persona(yo) and recinto_de(p) != rec):
		for radio in [8.0, 16.0, 26.0, 38.0, 52.0, 70.0, 90.0, 120.0]:
			for i in 24:
				var ang := TAU * float(i) / 24.0
				var q2: Vector2 = p + Vector2(cos(ang) * radio, sin(ang) * radio * 0.6)
				if cuerpo_toca(yo, q2) <= 0.0 and libre(q2, yo.zona, 0.0, yo) and (es_persona(yo) or recinto_de(q2) == rec):
					_camas.append([yo, yo.huella(q2).grow(-1.0)])
					return q2
	_camas.append([yo, yo.huella(p).grow(-1.0)])
	return p


func en_ruta_de_casa(q: Vector2, yo: Actor) -> bool:
	## si en q su cuerpo cae en el camino por el que los granjeros vuelven a casa al anochecer (con 14 px de aire)
	if not E.has("casa"):
		return false
	var h: Rect2 = yo.huella(q).grow(14.0)
	var pu := Vector2(E["casa"]["puerta"][0], E["casa"]["puerta"][1])
	for nombre in E["casa"]["rutas"]:
		var ruta: Array = E["casa"]["rutas"][nombre]
		var puntos: Array = []
		for r in ruta:
			puntos.append(Vector2(r[0], r[1]))
		puntos.append(pu)
		for i in puntos.size() - 1:
			for k in 21:
				if h.has_point(puntos[i].lerp(puntos[i + 1], k / 20.0)):
					return true
	return false


func _madre_y_cria(a: Actor, b: Actor) -> bool:
	## si uno sigue al otro y es mucho más pequeño (una cría con su madre, no dos adultas que van juntas)
	if a.lider() != b and b.lider() != a:
		return false
	var sa := a.huella(Vector2.ZERO).get_area()
	var sb := b.huella(Vector2.ZERO).get_area()
	return minf(sa, sb) < maxf(sa, sb) * 0.6


func suelta_cama(yo: Actor) -> void:
	## deja libre el sitio de noche que tenía repartido (va a echarse en otro)
	_camas = _camas.filter(func(c): return c[0] != yo)


var _caja_come := {}   # "nombre/vista" -> lo opaco de todos sus fotogramas de comer en esa vista (relativo a los pies)


func caja_come(a: Actor, v: String) -> Rect2:
	## lo que ocupa comiendo de perfil (la cabeza baja llega más lejos que en reposo)
	var k := a.nombre + "/" + v
	if not _caja_come.has(k):
		var xys: Array = []
		for an in ["eat_start", "eat", "eat_end"]:
			if a.tiene(an) and a.d["anims"][an].has(v):
				xys += a.d["anims"][an][v]["xy"]
		var r: Rect2 = a._opaco(xys) if not xys.is_empty() else Rect2()
		_caja_come[k] = r if r.size.x > 0.0 else a.huella(Vector2.ZERO)
	return _caja_come[k]


func cerca_de_comedero(a: Actor, p: Vector2) -> bool:
	## si en p su cuerpo queda a menos de 12 px de un comedero, pesebre, bebedero o heno (ahí no se come: parecería
	## comer de él)
	var e := envolvente(a)
	var r := Rect2(p + e.position, e.size).grow(12.0)
	for ob in objetos:
		if Comp.COMEDEROS.any(func(c): return String(ob["n"]).begins_with(c)) and r.intersects(ob["dib"]):
			return true
	return false


func comedero_de(a: Actor, cerca_de = null):
	## (sin uso desde el 26-10: los animales comen en el suelo, lejos de los comederos)
	## [sitio, vista] para comer en el comedero, pesebre o bebedero de su recinto (contra la valla norte): al lado, pegado
	## a su borde y mirándolo, con la cabeza llegando; nunca encima ni delante tapándolo (usuario 26-10). O nada
	var b: Rect2 = a.zona["b"].abs()
	var desde: Vector2 = a.position if cerca_de == null else cerca_de
	var mejor = null
	for ob in objetos:
		var n: String = ob["n"]
		if not Comp.COMEDEROS.any(func(c): return n.begins_with(c)):
			continue
		var dib: Rect2 = ob["dib"]
		if not b.grow(40.0).intersects(dib):
			continue
		if cerca_de != null and not Rect2(cerca_de - Vector2(60, 60), Vector2(120, 120)).intersects(dib):
			continue   # (le llaman a comer a un sitio: sólo el comedero de al lado)
		for lado in [1.0, -1.0]:
			var v := "west" if lado > 0.0 else "east"
			var come := caja_come(a, v)
			# los pies, a la altura de los del comedero; la cabeza, en su borde
			var x0: float = dib.end.x + 1.0 - come.position.x if lado > 0.0 else dib.position.x - 1.0 - come.end.x
			var hecho := false
			for dy in [0.0, 3.0, -3.0, 6.0, 9.0, 12.0]:
				for dx in range(0, 24):
					var q := Vector2(x0 + lado * float(dx), dib.end.y + dy)
					if not libre(q, a.zona, a.margen, a) or not espacio(q, a) or not a_la_vista(q):
						continue
					if mejor == null or q.distance_to(desde) < mejor[0].distance_to(desde):
						mejor = [q, v]
					hecho = true
					break
				if hecho:
					break
	return mejor


func valla_detras(b: Rect2) -> float:
	## la línea de pies de la valla de arriba de una zona (la de atrás), o 0: la que tiene más tramos
	var cuenta := {}
	for sp in E["sprites"]:
		var pie := float(sp[3])
		if not String(sp[0]).begins_with("valla_tramo") or pie < b.position.y - 60.0 or pie > b.position.y + 16.0:
			continue
		if float(sp[1]) < b.position.x - 20.0 or float(sp[1]) > b.end.x + 20.0:
			continue
		cuenta[pie] = cuenta.get(pie, 0) + 1
	if cuenta.is_empty():
		return 0.0
	var linea: float = cuenta.keys().reduce(func(x, y): return x if cuenta[x] >= cuenta[y] else y)
	return linea if cuenta[linea] >= 3 else 0.0


func _sin_valla_detras(a: Actor) -> void:
	## crítico 26-10: nadie pisa la valla de atrás de su recinto (el caballo blanco andaba encima de la del potrero): los
	## pies, al menos a un tercio de su cuerpo por debajo de ella. Los comederos van contra esa valla: se sigue llegando
	if a.nombre in ["granjero", "washerwoman"]:
		return
	var b: Rect2 = a.zona["b"].abs()
	var linea := valla_detras(b)
	if linea <= 0.0:
		return
	var arriba := linea + 0.35 * a.huella(Vector2.ZERO).size.y
	if arriba <= b.position.y or arriba > b.end.y - 10.0:
		return
	a.zona = a.zona.duplicate()
	a.zona["b"] = Rect2(b.position.x, arriba, b.size.x, b.end.y - arriba)
	if a.position.y < arriba:
		a.position.y = arriba


func valla_delante(b: Rect2) -> float:
	## lo alto de la valla de debajo de una zona (la de delante), o 0: la línea de pies con más tramos justo debajo
	var cuenta := {}
	for sp in E["sprites"]:
		var pie := float(sp[3])
		if not String(sp[0]).begins_with("valla_tramo") or pie < b.end.y - 12.0 or pie > b.end.y + 70.0:
			continue
		if float(sp[1]) < b.position.x - 20.0 or float(sp[1]) > b.end.x + 20.0:
			continue
		cuenta[pie] = cuenta.get(pie, 0) + 1
	if cuenta.is_empty():
		return 0.0
	var linea: float = cuenta.keys().reduce(func(x, y): return x if cuenta[x] >= cuenta[y] else y)
	var arriba := 0.0
	for sp in E["sprites"]:
		if not (String(sp[0]).begins_with("valla_tramo") or String(sp[0]).begins_with("valla_poste")) or absf(float(sp[3]) - linea) > 2.0:
			continue
		if float(sp[1]) >= b.position.x - 20.0 and float(sp[1]) <= b.end.x + 20.0:
			arriba = float(sp[2]) if arriba == 0.0 else minf(arriba, float(sp[2]))
	return arriba


func agua(p: Vector2) -> bool:
	## si en ese píxel del suelo hay agua (la máscara sale de los píxeles azules del estanque del plano)
	var x := int(p.x)
	var y := int(p.y)
	if _mascara == null or x < 0 or y < 0 or x >= _mascara.get_width() or y >= _mascara.get_height():
		return false
	return _mascara.get_pixel(x, y).r > 0.5


func agua_honda(p: Vector2, borde := 6.0) -> bool:
	## agua con agua alrededor: donde un pato nada sin tocar la orilla
	return agua(p) and agua(p + Vector2(borde, 0)) and agua(p - Vector2(borde, 0)) \
		and agua(p + Vector2(0, borde * 0.6)) and agua(p - Vector2(0, borde * 0.6))


func en_agua(p: Vector2, k: float) -> bool:
	var q: Vector2 = (p - estanque["c"]) / (estanque["r"] * k)
	return q.length_squared() < 1.0


func libre(p: Vector2, z: Dictionary, m := 0.0, yo: Actor = null) -> bool:
	var b: Rect2 = z["b"]
	if p.x < b.position.x + m or p.x > b.end.x - m or p.y < b.position.y or p.y > b.end.y:
		return false
	if z.has("ok") and not z["ok"].call(p):
		return false
	if not z.get("agua", false) and (agua(p) or agua(p + Vector2(0, 4))):
		return false   # en tierra nadie pisa el estanque
	if yo != null:
		# con su cuerpo: ni encima del decorado ni fuera de su recinto (ni dentro de uno ajeno)
		if cuerpo_toca(yo, p) > 0.0:
			return false
		if not es_persona(yo) and recinto_de(p) != casa_de(yo):
			return false
		return true
	for o in obst:
		if o.has_point(p):
			return false
	return true


func arrastra_grupo(lider: Actor, p: Vector2) -> void:
	## el que manda echa a andar y los suyos que estén cerca arrancan a la vez, cada uno a su sitio a su lado
	## (el rebaño sigue al que echa a andar, sea quien sea: los de su especie que estén cerca y sin nada que hacer)
	var i := 0
	for a in actores:
		if a == lider or a.position.distance_to(lider.position) > 90 or a.modo != "libre" or a.manual or a.encargo \
				or a == elegido or a.act == "mamar" or a.pide != null or a._va_de_camino():
			continue
		if a.lider() != lider and not (a.base == lider.base and not a.base in Comp.CRIAS and randf() < 0.6):
			continue
		i += 1
		var lado := -1.0 if i % 2 else 1.0
		var sep := (lider.huella(Vector2.ZERO).size.x + a.huella(Vector2.ZERO).size.x) / 2.0 + 4.0
		var q = a.destino(p + Vector2(lado * sep * ceilf(i / 2.0), 6.0 * i), 6.0)
		if q != null:
			a.pide = a._cierre() + a.ir(q, false) + a.cadena("idle", 1)


func puerta_cerca(p: Vector2, radio := 70.0):
	## la puerta más cercana a p (para que las gallinas salgan del corral por ella)
	var mejor = null
	var todas: Array = puertas.duplicate()
	for k in verjas:
		todas += verjas[k]   # las verjas del plano (las puertas de sprite sólo si el kit las trae)
	for pu in todas:
		var d: float = pu["centro"].distance_to(p)
		if d < radio and (mejor == null or d < mejor["centro"].distance_to(p)):
			mejor = pu
	return mejor


func _puertas(delta: float) -> void:
	## una puerta se abre cuando alguien llega a ella, hacia el lado contrario del que viene, y se cierra
	## un momento después de que pase
	for pu in puertas:
		var quien: Actor = null
		for a in actores:
			if absf(a.position.x - pu["centro"].x) < 16 and absf(a.position.y - pu["centro"].y) < 20:
				quien = a
				break
		if quien:
			pu["hasta"] = reloj + 1.4
			if not pu["abierta"]:
				pu["abierta"] = true
				# viene de fuera (del lado de la cámara) o de dentro: la hoja se abre hacia el otro lado
				_gira_hoja(pu, -1.0 if quien.position.y > pu["centro"].y else 1.0)
		elif pu["abierta"] and reloj > pu["hasta"]:
			pu["abierta"] = false
			_gira_hoja(pu, 0.0)


func _gira_hoja(pu: Dictionary, hacia: float) -> void:
	## la hoja de la puerta gira sobre su bisagra: en ¾ eso es encoger de ancho hacia la bisagra y subir (abre
	## hacia dentro, hacia el fondo) o bajar (hacia fuera) un par de píxeles; con un rebote al cerrar
	if not pu.has("hoja"):
		_prepara_hoja(pu)
	var hoja: Sprite2D = pu["hoja"]
	if pu.has("tw") and pu["tw"].is_valid():
		pu["tw"].kill()
	var tw := create_tween().set_parallel(true)
	if hacia != 0.0:
		tw.tween_property(hoja, "scale:x", 0.22, 0.35).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
		tw.tween_property(hoja, "position:y", pu["hoja_y"] - 3.0 * hacia, 0.35)
		tw.tween_property(hoja, "modulate", Color(0.78, 0.74, 0.7), 0.35)
		hoja.z_index = 0 if hacia > 0 else 1
	else:
		tw.tween_property(hoja, "scale:x", 1.0, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(hoja, "position:y", pu["hoja_y"], 0.45)
		tw.tween_property(hoja, "modulate", Color.WHITE, 0.45)
	pu["tw"] = tw


func _prepara_hoja(pu: Dictionary) -> void:
	## la puerta cerrada del kit se parte en tres: los dos postes quietos y la hoja, que es lo que gira
	var tex: Texture2D = pu["tex_cerrada"]
	var spr: Sprite2D = pu["spr"]
	var HOJA := Rect2(28, 0, 38, tex.get_height())   # entre los dos postes del dibujo
	spr.region_enabled = true
	spr.region_rect = Rect2(0, 0, HOJA.position.x, tex.get_height())
	var der := Sprite2D.new()
	der.texture = tex
	der.centered = false
	der.region_enabled = true
	der.region_rect = Rect2(HOJA.end.x, 0, tex.get_width() - HOJA.end.x, tex.get_height())
	der.offset = spr.offset + Vector2(HOJA.end.x, 0)
	spr.get_parent().add_child(der)
	var hoja := Sprite2D.new()
	hoja.texture = tex
	hoja.centered = false
	hoja.region_enabled = true
	hoja.region_rect = HOJA
	hoja.position = spr.offset + Vector2(HOJA.position.x, 0)   # la bisagra, en el poste de la izquierda
	spr.get_parent().add_child(hoja)
	pu["hoja"] = hoja
	pu["hoja_y"] = hoja.position.y


func onda(_p: Vector2, _grande := 10.0) -> void:
	pass   # las ondas bajo los patos las pinta ambiente.gd (las de la escena aprobada)


# ── la vida social del mapa: lo que pasa entre unos y otros, de vez en cuando y con su porqué ─────────────────────────
# crítico 26-10: nada de nombres ni coordenadas fijas: reglas que valen para cualquier granja del pack
var _proximo_topetazo := 40.0
var _proximo_juego := 20.0
var _proximo_mirada := 0.0
var _defensas := {}          # defensor -> hasta cuándo descansa
# la jornada de los granjeros (hora del día, en segundos de los 600; de día va de 0 a ~380): adónde van y qué hacen.
# Recintos (su verja), el pozo, la conejera y el estanque; los animales del recinto acuden a la verja
# Crítico visual 26-10 (la vida, mal repartida): el granjero saca agua del pozo y la lleva con el cubo a los bebederos de
# los recintos (abrevadero:<recinto>); la lavandera trabaja entre el pozo y su rincón de levante (arriba del patio, junto
# al molino), no siempre junto a su puerta del oeste ni metida entre los conejos de la conejera
const RUTINA := {
	# (agua:<recinto> = tarea compuesta: al pozo, saca agua y la lleva al bebedero de ese recinto)
	"granjero": [[40.0, "aves", "grano"], [100.0, "aves", "grano"], [160.0, "aves", "grano"], [220.0, "aves", "grano"], [280.0, "aves", "grano"], [330.0, "aves", "grano"]],   # quieto delante del corral de las aves, echándoles grano (usuario 26-10)
	"washerwoman": [[30.0, "cercado", "oficio"], [110.0, "cercado", "oficio"], [190.0, "cercado", "oficio"], [270.0, "cercado", "oficio"]],
}
# a esta hora los granjeros dejan lo que hacen y van a casa (antes de que caiga la noche: a las 385 empieza el ocaso)
var A_CASA := 260.0 if "--video" in OS.get_cmdline_user_args() else 360.0   # en el vídeo el reloj va ×6,7: salen antes para llegar a casa con luz


func _vida_social(delta: float) -> void:
	if noche or ambiente == null:
		return
	_rutina()
	# los machos se topan: con otro de su especie o de su recinto, y si están solos, contra la valla
	if reloj >= _proximo_topetazo:
		_proximo_topetazo = reloj + randf_range(35.0, 70.0)
		_topetazo()
	# las crías de la misma especie juegan a correr juntas
	if reloj >= _proximo_juego:
		_proximo_juego = reloj + randf_range(25.0, 45.0)
		_juego_de_crias()
	if reloj < _proximo_mirada:
		return
	_proximo_mirada = reloj + 0.5
	for g in actores:
		if not RUTINA.has(g.nombre) or not g.visible or not g.paso.has("a") or g.llego:
			continue
		# los que tiene delante en su camino se apartan antes de que llegue (como cuando ven venir a alguien)
		var hacia: Vector2 = g.paso["a"] - g.position
		if hacia.length() > 4.0:
			abre_paso(g, g.position + hacia.normalized() * minf(50.0, hacia.length()))
		for a in actores:
			if a == g or a == elegido or a.position.distance_to(g.position) >= 34.0:
				continue
			# los granjeros, al pasar andando, asustan a las aves y a los conejos que tienen cerca
			if a.tiene("aleteo") or a.tiene("thump"):
				a.asusta(g.position)
			# y si pasan pegados a una cría de ave, el ganso o el gallo salen a por ellos
			if a.base in ["Pollito", "Pavipollo", "Patito", "Ansarino"] and a.position.distance_to(g.position) < 30.0:
				_defiende(a, g)


func _libre_para_social(a: Actor) -> bool:
	return a.modo == "libre" and not a.manual and not a.encargo and a != elegido and a.visible and a.pide == null \
		and a.act != "mamar" and not RUTINA.has(a.nombre) and not a._va_de_camino()


func _golpe(a: Actor) -> String:
	return "headbutt" if a.tiene("headbutt") else "attack"


func _topetazo() -> void:
	var machos: Array = actores.filter(func(a): return a.base in Comp.MACHOS and _libre_para_social(a) \
		and (a.tiene("attack") or a.tiene("headbutt")))
	if machos.is_empty():
		return
	var m: Actor = machos.pick_random()
	var rival: Actor = null
	var mejor := INF
	var rec := recinto_de(m.position)
	for o in machos:
		if o == m:
			continue
		var mismo: bool = o.base == m.base or (rec != "" and recinto_de(o.position) == rec)
		var dd: float = o.position.distance_to(m.position)
		if mismo and dd < 220.0 and dd < mejor:
			mejor = dd
			rival = o
	if rival:
		var izq: Actor = m if m.position.x <= rival.position.x else rival
		var der: Actor = rival if izq == m else m
		var medio := (m.position + rival.position) / 2.0
		var sx := (izq.huella(Vector2.ZERO).size.x + der.huella(Vector2.ZERO).size.x) / 4.0 + 2.0
		var p_izq := medio - Vector2(sx, 0)
		var p_der := medio + Vector2(sx, 0)
		if not libre(p_izq, izq.zona, 0.0) or not libre(p_der, der.zona, 0.0):
			return
		var pierde: Actor = [izq, der].pick_random()
		for par in [[izq, p_izq, "east"], [der, p_der, "west"]]:
			var a: Actor = par[0]
			var queja: Array = a.cadena("hurt", 1) if a == pierde and a.tiene("hurt") else []
			a.pide = a._cierre() + a.ir(par[1], false) + [{"anim": "idle", "vueltas": 1, "mira": par[2]}] \
				+ a.cadena(_golpe(a), 1, par[2]) + queja + [{"anim": "idle", "vueltas": 2}]
			a.act = _golpe(a)
		return
	# solo: contra la valla de su sitio, por el lado que tenga más cerca
	var b: Rect2 = m.zona["b"].abs()
	var oeste: bool = m.position.x - b.position.x < b.end.x - m.position.x
	var p := Vector2(b.position.x + m.margen + 3.0 if oeste else b.end.x - m.margen - 3.0, m.position.y)
	if not libre(p, m.zona, 0.0) or not espacio(p, m):
		return
	var hacia := "west" if oeste else "east"
	m.pide = m._cierre() + m.ir(p, false) + [{"anim": "idle", "vueltas": 1, "mira": hacia}] + m.cadena(_golpe(m), 1, hacia) \
		+ [{"anim": "idle", "vueltas": 1}] + m.cadena(_golpe(m), 1, hacia) + [{"anim": "idle", "vueltas": 2}]
	m.act = _golpe(m)


func _defiende(cria: Actor, g: Actor) -> void:
	## el macho de ave más cercano (o la gansa) se planta delante del granjero y le ataca
	var def: Actor = null
	var mejor := 160.0
	for a in actores:
		if not a.base in Comp.PROTECTORES or not a.tiene("attack") or not _libre_para_social(a) or reloj < float(_defensas.get(a, 0.0)):
			continue
		var dd: float = a.position.distance_to(cria.position)
		if dd < mejor:
			mejor = dd
			def = a
	if def == null:
		return
	var lado := 1.0 if def.position.x > g.position.x else -1.0
	var p: Vector2 = g.position + Vector2(lado * ((def.huella(Vector2.ZERO).size.x + g.huella(Vector2.ZERO).size.x) / 2.0 + 2.0), 0)
	var mira := "west" if lado > 0 else "east"
	_defensas[def] = reloj + 40.0
	def.pide = def._cierre() + def.ir(p, true) + [{"anim": "idle", "vueltas": 1, "mira": mira}] + def.cadena("attack", 1, mira) \
		+ [{"anim": "idle", "vueltas": 1}]
	def.act = "attack"
	# el granjero se para un momento, se gira hacia él y sigue con lo que hacía (sin perder el resto del camino: si no, el
	# que iba a casa se quedaba fuera)
	var sigue: Array = []
	if g.paso.has("a"):
		sigue = g.ir(g.paso["a"], false)
		if not g.cola.is_empty() and String(sigue[-1]["anim"]).ends_with("_end"):
			sigue.pop_back()
	g.pide = g._cierre() + [{"anim": "idle", "vueltas": 2, "mira": "east" if lado > 0 else "west"}] + sigue + g.cola


func _juego_de_crias() -> void:
	var crias: Array = actores.filter(func(a): return a.base in Comp.CRIAS and a.tiene("run") and _libre_para_social(a))
	crias.shuffle()
	for c in crias:
		for o in crias:
			if o == c or o.base != c.base or o.position.distance_to(c.position) > 110.0:
				continue
			var p = c.destino(c.position + Vector2(randf_range(-60, 60), randf_range(-20, 20)), 20.0)
			if p == null:
				continue
			var q = o.destino(p + (o.position - p).normalized() * 18.0, 12.0)
			if q == null:
				continue
			var vuelta = c.destino(c.position, 16.0)
			c.pide = c._cierre() + c.ir(p, true) + [{"anim": "idle", "vueltas": 1}] + (c.ir(vuelta, true) if vuelta != null else []) \
				+ [{"anim": "idle", "vueltas": 1}]
			o.pide = o._cierre() + o.ir(q, true) + [{"anim": "idle", "vueltas": 2}]
			c.act = "run"
			o.act = "run"
			return


func _rutina() -> void:
	## la jornada de cada granjero: a su hora, a su tarea (si nadie le lleva ni le ha pedido nada)
	if _hora_destino != null:
		return
	for g in actores:
		if not RUTINA.has(g.nombre):
			continue
		var lista: Array = RUTINA[g.nombre]
		var k := -1
		for i in lista.size():
			if hora >= float(lista[i][0]):
				k = i
		if k < 0:
			_tarea[g.nombre] = -1
			_pendientes[g.nombre] = []
			continue
		# las que han llegado a su hora van a su cola (antes, si coincidía con otra sin acabar, se saltaba y no volvía:
		# por eso el granjero nunca iba al pozo)
		var hecho := int(_tarea.get(g.nombre, -1))
		if k < hecho:
			hecho = -1   # (un día nuevo)
		var cola_g: Array = _pendientes.get(g.nombre, [])
		for i in range(hecho + 1, k + 1):
			cola_g.append(i)
		_pendientes[g.nombre] = cola_g
		_tarea[g.nombre] = k
		if cola_g.is_empty():
			continue
		if g.modo != "libre" or not g.visible or g == elegido or g.encargo or g.manual:
			continue
		if g.reserva != Vector2.ZERO:
			continue   # aún con la anterior: la siguiente espera en la cola a que acabe
		var t: int = cola_g.pop_front()
		if hora > A_CASA - 15.0:
			cola_g.clear()
			continue   # ya es hora de irse a casa: lo que quede, mañana
		_haz_tarea(g, String(lista[t][1]), String(lista[t][2]))


func _sitio_tarea(g: Actor, sitio: String) -> Array:
	## [dónde se pone, hacia dónde mira, puntos de paso, recinto o ""]
	var R: Dictionary = E["recintos"]
	if R.has(sitio):
		var v := verja(sitio, g.position)
		var mira: String = {"N": "south", "S": "north", "E": "west", "W": "east"}.get(v.get("lado", "N"), "south")
		var previos: Array = []
		if sitio == "cercado" and g.position.y < float(v["fuera"].y) - 40.0:
			previos = [Vector2(582.0, 392.0), Vector2(420.0, 392.0)]   # por delante del granero (usuario 26-10)
		return [v["fuera"], mira, previos, sitio]
	for p in E["piezas"]:
		var n: String = p["n"]
		if not E["imagenes"].has(n):
			continue
		var w := float(E["imagenes"][n]["w"])
		if sitio == "pozo" and n.begins_with("pozo"):
			# a los dos lados del brocal: a cada uno, el lado más cercano a él (si el otro ya lo tiene, el de enfrente)
			var pie := float(p["pie"])
			var oeste := Vector2(float(p["x"]) - 10.0, pie - 6.0)
			var este := Vector2(float(p["x"]) + w + 10.0, pie - 6.0)
			var al_oeste: bool = g.position.distance_to(oeste) <= g.position.distance_to(este)
			for o in actores:
				if o != g and RUTINA.has(o.nombre) and o.reserva.distance_to(oeste if al_oeste else este) < 8.0:
					al_oeste = not al_oeste
					break
			var lado: Vector2 = oeste if al_oeste else este
			# si le queda al otro lado (o detrás del brocal), primero por delante del pozo: si no, andaba contra él
			var previos: Array = []
			var cx := float(p["x"]) + w / 2.0
			if (g.position.x < cx) != al_oeste or g.position.y < pie - 6.0:
				previos = [Vector2(lado.x, pie + 12.0)]
			return [lado, "east" if al_oeste else "west", previos, ""]
		if sitio == "conejera" and n == "conejera":
			return [Vector2(float(p["x"]) + w / 2.0, float(p["pie"]) + 10.0), "north", [], ""]
	if sitio.begins_with("abrevadero:") and R.has(sitio.get_slice(":", 1)):
		# con el cubo hasta el bebedero (contra la valla norte): lo llena por encima de la valla, desde fuera, sin meterse
		# entre los animales; cuando se va, los del recinto acuden a beber
		var rec := sitio.get_slice(":", 1)
		var c_rec: Array = R[rec]["caja"]
		for p in E["piezas"]:
			var n: String = p["n"]
			if not n.begins_with("abrevadero") or not E["imagenes"].has(n):
				continue
			var w := float(E["imagenes"][n]["w"])
			var cx := float(p["x"]) + w / 2.0
			var pie := float(p["pie"])
			if recinto_de(Vector2(cx, pie + 4.0)) != rec:
				continue
			return [Vector2(cx, float(c_rec[1]) - 14.0), "south", [], rec, Vector2(cx, pie + 8.0), "al_irse"]
	if sitio == "este" and zonas.has("patio"):
		# un rincón libre en el lado de levante del patio, por arriba (abajo andan los conejos y los pavos)
		var b: Rect2 = zonas["patio"]["b"]
		for i in 40:
			var q := Vector2(randf_range(b.end.x - 170.0, b.end.x - 30.0), randf_range(b.position.y + 8.0, b.position.y + 56.0))
			if libre(q, zonas["patio"]) and a_la_vista(q):
				return [q, "west", [], ""]
	if sitio == "estanque" and R.has("cercado") and R.has("ovejas"):
		# por el paso entre el cercado y el prado, hasta la orilla de levante
		var x := (float(R["cercado"]["caja"][2]) + float(R["ovejas"]["caja"][0])) / 2.0
		var c: Vector2 = estanque["c"]
		var r: Vector2 = estanque["r"]
		var orilla := Vector2(c.x + r.x + 14.0, maxf(c.y + 10.0, float(R["ovejas"]["caja"][3]) + 26.0))
		return [orilla, "west", [Vector2(x, zonas["patio"]["b"].end.y), Vector2(x, float(R["ovejas"]["caja"][3]) + 14.0)], ""]
	return []


func _haz_tarea(g: Actor, sitio: String, que: String, antes: Array = []) -> void:
	if sitio.begins_with("agua:"):
		# tarea compuesta: al pozo, saca agua (con el cubo, quieto un rato) y la lleva al bebedero del recinto
		_haz_tarea(g, "pozo", que)
		if g.act != "tarea":
			return
		var ida: Array = g.pide
		g.regreso = []   # (la vuelta del pozo ya va en la ida)
		_haz_tarea(g, "abrevadero:" + sitio.get_slice(":", 1), que, ida)
		return
	var s := _sitio_tarea(g, sitio)
	if sitio == "pozo" and que == "hablar" and not s.is_empty():
		# la lavandera, si el granjero está en el pozo (o va), habla junto a él, del lado de fuera, y mirándolo
		for o in actores:
			if o == g or not RUTINA.has(o.nombre) or o.reserva == Vector2.ZERO:
				continue
			for p in E["piezas"]:
				var n: String = p["n"]
				if not n.begins_with("pozo") or not E["imagenes"].has(n):
					continue
				var cx := float(p["x"]) + float(E["imagenes"][n]["w"]) / 2.0
				# (su sitio en el pozo: el reservado o, en la tarea del agua, donde está sacándola)
				for q: Vector2 in [o.reserva, o.position]:
					if absf(q.y - (float(p["pie"]) - 6.0)) < 6.0 and absf(q.x - cx) < float(E["imagenes"][n]["w"]):
						var fuera := -1.0 if q.x < cx else 1.0
						s = [q + Vector2(fuera * 18.0, 2.0), "east" if fuera < 0.0 else "west", [], ""]
						break
				break
	if "--prueba_reparto" in OS.get_cmdline_user_args():
		print("TAREA ", snappedf(hora, 1.0), " ", g.nombre, " ", sitio, " ", que, " ", "" if s.is_empty() else str(s[0].round()))
	if s.is_empty():
		return
	var punto: Vector2 = s[0]
	var mira: String = s[1]
	var previos: Array = s[2]
	# si en su sitio hay un animal, se pone al lado (si no, se quedaba encima de la pava o de los conejos un buen rato)
	# (ni encima de la pieza: junto al pozo o la conejera, pegado a su huella pero sin pisarla)
	if not espacio(punto, g) or cuerpo_toca(g, punto) > 0.0:
		for radio in [4.0, 8.0, 14.0, 20.0, 26.0]:
			var hueco := false
			for i in 12:
				var q: Vector2 = punto + Vector2(cos(TAU * i / 12.0), sin(TAU * i / 12.0) * 0.6) * radio
				if espacio(q, g) and cuerpo_toca(g, q) <= 0.0 and (s[3] != "" or libre(q, zonas.get("patio", g.zona))):
					punto = q
					hueco = true
					break
			if hueco:
				break
	var anim := que
	if anim == "grano" and (not mira in ["east", "west"] or not g.tiene("grano")):
		anim = "pasto"   # sobre la valla de una verja de cara: le echa el pasto por encima
	var hace: Array = []
	match anim:
		"grano":
			hace = [{"anim": "idle", "vueltas": 1, "mira": mira}, {"anim": "grano", "mira": mira}, {"anim": "idle", "vueltas": 1},
				{"anim": "grano", "mira": mira}, {"anim": "idle", "vueltas": 2}]
		"oficio", "hablar":
			hace = (g.cadena(anim, 3, mira) if g.tiene(anim) else [{"anim": "idle", "vueltas": 3, "mira": mira}]) \
				+ [{"anim": "idle", "vueltas": 1}]
		_:
			hace = [{"anim": "idle", "vueltas": 5, "mira": mira}]   # sacando agua, echando pasto
	var vuelta: Array = previos.duplicate()
	vuelta.reverse()
	# los del recinto acuden a la verja (a comer) cuando él ya está allí, o al bebedero (a beber) cuando se ha ido (antes,
	# con un temporizador, llegaban antes que él y se quedaba encima de ellos)
	var fin: Array = [{"anim": "idle", "vueltas": 1}]
	if s[3] != "":
		var dentro: Vector2 = s[4] if s.size() > 4 else verja(s[3], punto)["dentro"]
		if s.size() > 5 and s[5] == "al_irse":
			fin[0]["acuden"] = [s[3], dentro]
		else:
			hace[0]["acuden"] = [s[3], dentro]
	g.deja_guion()
	# (si aún está fuera del patio, primero vuelve por donde fue)
	g.pide = (antes if not antes.is_empty() else g._cierre()) + g.ir_por(g.regreso + previos + [punto]) + hace + (g.ir_por(vuelta) if not vuelta.is_empty() else []) + fin
	g.act = "tarea"
	g.reserva = punto   # su sitio: mientras va y mientras trabaja, ningún animal se pone ahí
	g.regreso = vuelta


func _acuden(rec: String, p: Vector2) -> void:
	if noche:
		return
	var los: Array = actores.filter(func(a): return recinto_de(a.position) == rec and _libre_para_social(a) \
		and not a.base in ["Raton"])
	los.sort_custom(func(a, b): return a.position.distance_to(p) < b.position.distance_to(p))
	for a in los.slice(0, 5):
		if randf() < 0.85:
			a.llama(p + Vector2(randf_range(-14, 14), randf_range(0, 10)))


func echa_grano(p: Vector2, hacia: String) -> void:
	## el puñado cae 0,6 s después a 30 px delante; las aves que lo tienen cerca acuden a picotearlo
	ambiente.echa_grano(p, hacia)
	var punto := p + Vector2(30 if hacia == "east" else -30, 2)
	get_tree().create_timer(0.6).timeout.connect(func():
		var cerca: Array = actores.filter(func(a): return a.base in Comp.GRANO and a.position.distance_to(punto) < 110.0 \
			and _libre_para_social(a))
		cerca.sort_custom(func(a, b): return a.position.distance_to(punto) < b.position.distance_to(punto))
		for a in cerca.slice(0, 6):
			a.llama(punto + Vector2(randf_range(-10, 10), randf_range(-4, 6))))


func _patos_en_el_agua() -> void:
	## dónde nada un pato este instante: debajo, sus ondas (ambiente.gd)
	ambiente.patos.clear()
	for a in actores:
		if agua(a.position) and not a.paso.get("vuela", false):
			ambiente.patos.append(a.position + Vector2(0, -3))


func _luz_de(h: float) -> Color:
	for k in LUZ_CLAVES.size() - 1:
		var a: Array = LUZ_CLAVES[k]
		var b: Array = LUZ_CLAVES[k + 1]
		if h >= a[0] and h <= b[0]:
			var u: float = (h - a[0]) / maxf(1.0, b[0] - a[0])
			u = u * u * (3.0 - 2.0 * u)
			return a[1].lerp(b[1], u)
	return Color.WHITE


func _reloj_del_dia(delta: float) -> void:
	## el día pasa despacio; al pulsar NIGHT o DAY corre deprisa (unos segundos) hasta esa hora y sigue
	if _hora_destino != null:
		var falta := fposmod(float(_hora_destino) - hora, DIA_S)
		var paso := delta * 130.0
		# con NIGHT, el reloj espera al caer la tarde a que los granjeros, que van deprisa a casa, hayan entrado (crítico
		# 26-10: antes se teletransportaban); si en medio minuto no han llegado, entran solos
		var a_la_noche: bool = float(_hora_destino) >= 385.0 and float(_hora_destino) < 575.0
		if a_la_noche and hora <= 380.0 and hora + paso >= 380.0 and _granjeros_fuera():   # (<=: parado en 380, sigue esperando)
			_espera_granjeros += delta
			if _espera_granjeros < 30.0:
				paso = maxf(0.0, 380.0 - hora)
				falta = INF
			else:
				_mete_en_casa()
		else:
			_espera_granjeros = 0.0
		if falta <= paso:
			hora = float(_hora_destino)
			_hora_destino = null
		else:
			hora = fposmod(hora + paso, DIA_S)
	else:
		# también sin NIGHT (y en el vídeo, con el reloj rápido): no anochece con los granjeros fuera; el reloj espera en
		# las 380 a que entren (medio minuto como mucho)
		if hora <= 380.0 and hora + delta * ritmo_dia >= 380.0 and _granjeros_fuera():
			_espera_granjeros += delta
			if _espera_granjeros < 30.0:
				hora = 380.0
			else:
				_mete_en_casa()
				hora = fposmod(hora + delta * ritmo_dia, DIA_S)
		else:
			_espera_granjeros = 0.0
			hora = fposmod(hora + delta * ritmo_dia, DIA_S)
	var c := _luz_de(hora)
	# el motor pasa el tinte a lineal antes de multiplicar: se le da ya corregido, así la noche queda con los mismos
	# valores que el vídeo (178 × 0,34 = 60, y no 20)
	luz.color = Color(minf(c.r, 1.0), minf(c.g, 1.0), minf(c.b, 1.0)).linear_to_srgb()
	oscuridad = clampf((1.0 - c.g) / (1.0 - NOCHE_G), 0.0, 1.0)
	var ventanas := 0.0
	if hora >= ENCIENDE and hora < APAGA:
		ventanas = minf(1.0, minf((hora - ENCIENDE) / 3.0, (APAGA - hora) / 3.0))
	ambiente.avanza(delta, oscuridad, ventanas)
	# de noche se duermen; al amanecer se despiertan (y el botón dice lo que hay)
	var tarde := hora >= A_CASA and hora < 575.0
	if tarde != _granjeros_en_casa:
		_granjeros_en_casa = tarde
		for a in actores:
			if a.nombre in ["granjero", "washerwoman"]:
				if tarde:
					a.a_dormir(_hora_destino != null or VIDEO)
				else:
					a.despierta()
			elif tarde and a.en_patio and not a.manual and a != elegido:
				a.al_corral()   # y las aves sueltas, a su corral
			elif not tarde and a.patio_de_dia and not a.en_patio and a.modo == "libre":
				a.al_patio()   # (si vuelve el día antes de la noche, salen otra vez)
	var es_noche := oscuridad > 0.6
	if es_noche != noche:
		noche = es_noche
		ui.b_noche.set_pressed_no_signal(noche)
		ui.refresca_noche() if ui.has_method("refresca_noche") else null
		_camas.clear()
		for a in actores:
			if a.nombre in ["granjero", "washerwoman"]:
				continue   # los granjeros van por la hora de la tarde (arriba)
			# todos a su sitio de noche (también los que se sumaron sin guion: crítico 26-10, dormían con haz("sleep"),
			# como un encargo, y nadie los apartaba); los sitios se reparten en orden, sin pisarse
			if noche:
				a.a_dormir()
			else:
				a.despierta()


var _apartandose := {}   # animal -> hasta cuándo se está apartando del camino de un granjero


func abre_paso(yo: Actor, q: Vector2, todos := false) -> void:
	## un granjero se ha topado con un animal en su camino: el animal se aparta a un lado (como haría uno de verdad al
	## ver venir a alguien), y el granjero pasa
	var mia: Rect2 = yo.huella(q).grow(4.0).merge(yo.huella(yo.position.lerp(q, 0.5)).grow(4.0))
	var hacia: Vector2 = (q - yo.position).normalized()
	for a in actores:
		# (también los que van andando: se les cambia el camino por el paso a un lado)
		if a == yo or not a.visible or RUTINA.has(a.nombre) or a.manual or (a.encargo and not todos) or a == elegido \
				or a.modo != "libre" or (a.act == "mamar" and not todos) or not mia.intersects(a.huella(a.position).grow(-2.0)):
			continue
		# (al que ya se está apartando no se le vuelve a mandar: si no, arrancaba y paraba sin fin delante del granjero)
		if reloj < float(_apartandose.get(a, -9.0)):
			continue
		var lado := Vector2(-hacia.y, hacia.x)
		if lado.dot(a.position - yo.position) < 0.0:
			lado = -lado
		var sep: float = (yo.huella(Vector2.ZERO).size.x + a.huella(Vector2.ZERO).size.x) / 2.0 + 10.0
		# a un lado y alejándose de él (si el paso a un lado le cruzaba por delante, el granjero lo paraba y se quedaban
		# los dos atascados)
		var lejos: Vector2 = (a.position - yo.position).normalized()
		var p = null
		for v in [(lado + lejos * 0.6).normalized(), lado, (lejos - hacia * 0.3).normalized(), -hacia]:
			var q2: Vector2 = a.position + v * sep
			if a.huella(q2).intersects(yo.huella(yo.position.lerp(q, 0.5)).grow(2.0)):
				continue
			p = a.destino(q2, 8.0)
			if p != null:
				break
		if p != null:
			_apartandose[a] = reloj + 2.5
			a.pide = a._cierre() + a.ir(p, false) + [{"anim": "idle", "vueltas": 1}]
			if not a.paso.has("a") and (a.paso.get("anim", "") == "idle" or a.tiene(String(a.paso.get("anim", "")) + "_end")):
				a.siguiente()   # de pie o comiendo, se aparta ya (andando, en la pisada)


func paso_libre(q: Vector2, yo: Actor) -> bool:
	## el siguiente paso no le mete encima de otro más de lo que ya está (su madre y sus crías no cuentan); al que llevan
	## a mano se le deja aire de más, y también adonde va
	var mia: Rect2 = yo.huella(q).grow(-2.0)
	var ahora: Rect2 = yo.huella(yo.position).grow(-2.0)
	for a in actores:
		if a == yo or a == yo.lider() or a.lider() == yo or not a.visible or a.position == Vector2.ZERO:
			continue
		# (los cuerpos miden hasta noventa píxeles de alto: con menos margen, un caballo se metía en otro por arriba)
		if absf(a.position.x - q.x) > 130.0 or absf(a.position.y - q.y) > 110.0:
			continue
		if es_persona(yo) and (es_persona(a) or a.huella(Vector2.ZERO).size.x < 22.0):
			continue   # un granjero no se queda plantado ante una gallina o un pavo: el ave se aparta a su paso
		var otra: Rect2 = a.huella(a.position).grow(-2.0)
		if a.manual and a != yo:
			otra = otra.grow(6.0).merge(a.huella(a.position + Actor.VECTOR[a.dir] * 14.0).grow(-2.0))
		var m: Rect2 = mia
		var h: Rect2 = ahora
		if yo.base == a.base and Comp.SEPARA.has(yo.base) and not noche:
			# las gallinas, tampoco andando a menos de su aire (10 px) unas de otras
			m = mia.grow(float(Comp.SEPARA[yo.base]) + 4.0)
			h = ahora.grow(float(Comp.SEPARA[yo.base]) + 4.0)
		var nueva := m.intersection(otra).get_area() if m.intersects(otra) else 0.0
		var antes := h.intersection(otra).get_area() if h.intersects(otra) else 0.0
		# crítico 26-10: dos que ya se tapan se quedaban trabados (cualquier paso de uno aumentaba el cruce con el otro
		# y ninguno se movía): si ya se tapan, vale el paso que le aleja del otro, y así salen de ahí
		if antes > 0.0 and not a.manual and q.distance_to(a.position) >= yo.position.distance_to(a.position):
			continue
		# ni medio píxel de más: con margen, paso a paso (0,1 px cada uno) se iba metiendo encima sin que nada lo parara
		if nueva > antes:
			return false
	return true


func sin_nadie(p: Vector2, yo: Actor) -> bool:
	## en p no tocaría a nadie (para el paso a un lado de un rodeo: ahí sólo importa no pisar a otro)
	var mia: Rect2 = yo.huella(p).grow(-1.0)
	for a in actores:
		if a == yo or not a.visible or a == yo.lider() or a.lider() == yo:
			continue
		if mia.intersects(a.huella(a.position).grow(-1.0)):
			return false
	return true


func cede_el_paso(yo: Actor, q: Vector2) -> bool:
	## si lo que le tapa el paso son sólo otros que van andando, espera a que pasen: cede el que tiene el número más bajo,
	## el otro sigue con sus rodeos (si cedieran los dos se quedarían mirándose)
	var mia: Rect2 = yo.huella(q).grow(-2.0)
	var alguno := false
	for a in actores:
		if a == yo or not a.visible or a == yo.lider() or a.lider() == yo or not mia.intersects(a.huella(a.position).grow(-2.0)):
			continue
		if not a._va_de_camino() or a.get_instance_id() < yo.get_instance_id():
			return false
		alguno = true
	return alguno


func tapa_quieto(yo: Actor) -> bool:
	## de noche: si tapa a otro que también está quieto (los que pasan andando no cuentan)
	var mia: Rect2 = yo.huella(yo.position).grow(-2.0)
	for a in actores:
		if a == yo or not a.visible or a == yo.lider() or a.lider() == yo or a._va_de_camino():
			continue
		var otra: Rect2 = a.huella(a.position).grow(-2.0)
		if mia.intersects(otra) and mia.intersection(otra).get_area() > 4.0:
			return true
	return false


func espacio_al_llevarlo(p: Vector2, yo: Actor) -> bool:
	## a mano: no se mete encima de nadie (sus crías no cuentan: van pegadas a él); si ya está encima, puede salir
	var mia: Rect2 = yo.huella(p).grow(-2.0)
	var ahora: Rect2 = yo.huella(yo.position).grow(-2.0)
	for a in actores:
		if a == yo or a.lider() == yo or a.position == Vector2.ZERO or not a.visible:
			continue
		var otra: Rect2 = a.huella(a.position).grow(-2.0)
		if mia.intersects(otra) and mia.intersection(otra).get_area() > ahora.intersection(otra).get_area():
			return false
	return true


func espacio(p: Vector2, yo: Actor) -> bool:
	## cada uno guarda su sitio: ni encima de otro ni pegado; la cría con su madre, al lado pero no encima
	# con los cuerpos de verdad (lo opaco de sus cuatro vistas): un caballo mide sesenta píxeles, no lo que su sombra;
	# con un par de píxeles de aire, para que el que llega no acabe rozando al que ya estaba
	if yo.base == "Raton" and es_trigal(p):
		return false   # un ratón en el trigal queda pintado encima de las espigas (usuario 26-10)
	var mia: Rect2 = yo.huella(p).grow(0.0)
	for a in actores:
		if a == yo or a.position == Vector2.ZERO:
			continue
		var otra: Rect2 = a.huella(a.position).grow(-2.0)
		# el sitio de trabajo de un granjero (adonde va o donde está), libre
		if a.reserva != Vector2.ZERO and mia.intersects(a.huella(a.reserva).grow(2.0)):
			return false
		# también adónde va: si no, una manada que echa a andar acaba toda en el mismo sitio
		if a.meta != Vector2.ZERO and a.meta.distance_to(a.position) > 2.0 and mia.intersects(a.huella(a.meta).grow(-2.0)):
			return false
		var cria: bool = (a == yo.lider() and yo.huella(p).get_area() < a.huella(a.position).get_area() * 0.6) \
				or (yo == a.lider() and a.huella(a.position).get_area() < yo.huella(p).get_area() * 0.6)
		if cria:
			# mamando, la cría va pegada bajo la ubre: ni ella ni la madre se apartan por eso
			if (yo.act == "mamar" and a == yo.lider()) or (a.act == "mamar" and a.lider() == yo) \
					or String(yo.paso.get("anim", "")).begins_with("suckle") or String(a.paso.get("anim", "")).begins_with("suckle"):
				continue
			# la cría con su madre: se tocan, pero no se tapan (dos adultos, nunca). Por delante de la madre (por debajo
			# de su línea de pies) la taparía: ahí cuenta su cuerpo entero (crítico 26-10: antes, delante = prohibido
			# aunque no se tocaran, y la cría no podía ponerse a mamar)
			var delante: bool = yo != a.lider() and p.y > a.position.y + 1.0
			if not delante:
				otra = otra.grow_individual(-otra.size.x * 0.08, -otra.size.y * 0.15, -otra.size.x * 0.08, -otra.size.y * 0.25)
		var mia_aqui := mia
		if not cria and yo.base == a.base and Comp.SEPARA.has(yo.base) and not noche:
			# las gallinas, con aire entre ellas: 10 px de verdad (la otra va encogida 2 px)
			mia_aqui = yo.huella(p).grow(float(Comp.SEPARA[yo.base]) + 2.0)
		if mia_aqui.intersects(otra):
			return false
	return true


func solape(p: Vector2, yo: Actor) -> float:
	## cuánto taparía a los demás si estuviera en p (para elegir el sitio menos malo cuando no hay ninguno libre)
	var mia: Rect2 = yo.huella(p)
	var total := 0.0
	for a in actores:
		if a == yo or a.position == Vector2.ZERO:
			continue
		total += mia.intersection(a.huella(a.position)).get_area()
	return total


func a_la_vista(p: Vector2) -> bool:
	for o in detras:
		if o.has_point(p):
			return false
	return true


func camino_libre(a: Vector2, b: Vector2, z: Dictionary, m: float, yo: Actor = null) -> bool:
	var n := int(ceil(a.distance_to(b) / 4.0))
	for i in range(1, n + 1):
		if not libre(a.lerp(b, float(i) / n), z, m, yo):
			return false
	return true


# ------------------------------------------------------------------------------------------------------ animales
func _animales() -> void:
	if E.has("reparto"):
		_animales_del_reparto()
		return
	var nombres: Array = E["escena"].duplicate()
	# primero los que mandan, para poder colocar a los que siguen a su lado
	nombres.sort_custom(func(a, b):
		var sa := int(Comp.ESPECIE[a.split("_")[0]].has("sigue"))
		var sb := int(Comp.ESPECIE[b.split("_")[0]].has("sigue"))
		if sa != sb:
			return sa < sb
		return int("_" in a) < int("_" in b))
	for n in nombres:
		var datos: Dictionary = E["animales"][n]
		var a := Actor.new()
		a.prepara(n, datos, load(DATOS + datos["archivo"]), self)
		por_nombre[n] = a
		actores.append(a)
		mundo.add_child(a)
	for a in actores:
		a.coloca()


func _animales_del_reparto() -> void:
	## el reparto aprobado de la escena: cada uno en su sitio con su guion de día (las crías con su madre)
	var hechos: Array = []
	for e in E["reparto"]:
		var n: String = e["entidad"]
		if not E["animales"].has(n):
			hechos.append(null)
			continue
		var datos: Dictionary = E["animales"][n]
		var a := Actor.new()
		a.prepara(n, datos, load(DATOS + datos["archivo"]), self)
		if not por_nombre.has(n):
			por_nombre[n] = a
		actores.append(a)
		mundo.add_child(a)
		hechos.append(a)
	for k in hechos.size():
		var a: Actor = hechos[k]
		if a == null:
			continue
		var e: Dictionary = E["reparto"][k]
		var madre: Actor = hechos[int(e["madre"])] if e["tipo"] == "sigue" else null
		a.usa_guion(e, madre)
	for a in actores:
		a.empieza({"anim": "idle", "vueltas": 1})
		a.dibuja()
	# usuario 26-10: «si veus animals sols o pocs, fica'n més»: más de cada familia y más colores del pack, que viven
	# libres en su recinto según su naturaleza (el corral de aves ya va lleno: ahí no)
	for n in MAS_ANIMALES:
		if not E["animales"].has(n):
			continue
		var datos: Dictionary = E["animales"][n]
		var extra := Actor.new()
		extra.prepara(n, datos, load(DATOS + datos["archivo"]), self)
		# vive donde viven los suyos (todo el recinto que les da su naturaleza, no medio)
		for a in actores:
			if String(a.sp.get("zona", "")) == String(extra.sp.get("zona", "")) and not a.guion.is_empty():
				extra.zona = a.zona
				break
		# crítico 26-10: cupo por zona. Si ya no cabe holgado (sitio libre al menos tres veces lo que ocupan los
		# cuerpos), no se mete: un recinto lleno es un recinto donde todos se pisan
		var b: Rect2 = extra.zona["b"].abs()
		var ocupa := extra.huella(Vector2.ZERO).get_area()
		for a in actores:
			if b.has_point(a.position):
				ocupa += a.huella(Vector2.ZERO).get_area()
		if "--depura" in OS.get_cmdline_user_args():
			print("  CUPO ", n, " zona=", b, " razon=", snappedf(b.get_area() / maxf(ocupa, 1.0), 0.01))
		var i_cupo := OS.get_cmdline_user_args().find("--cupo")   # para medir otro cupo: -- --cupo 2
		var cupo: float = float(OS.get_cmdline_user_args()[i_cupo + 1]) if i_cupo >= 0 else CUPO
		if b.get_area() / maxf(ocupa, 1.0) < cupo and not extra.base in ["Gallina"]:
			extra.free()
			continue
		if not por_nombre.has(n):
			por_nombre[n] = extra
		actores.append(extra)
		mundo.add_child(extra)
		extra.coloca()
	# la zona de cada especie, donde vive de verdad en el reparto (el visor la encuadra; a mano, no sale de ahí)
	var donde := {}
	for a in actores:
		var z: String = String(a.sp.get("zona", ""))
		if z == "" or a.nombre in ["granjero", "washerwoman"]:
			continue
		donde[z] = donde.get(z, []) + [a.position]
	for z in donde:
		var caja := Rect2(donde[z][0], Vector2.ZERO)
		for p in donde[z]:
			caja = caja.expand(p)
		if zonas.has(z) and zonas[z]["b"].abs().encloses(caja.grow(-2.0).abs()):
			continue
		# crítico 26-10: la zona crece hasta abarcarlos, nunca encoge (antes se cambiaba por la caja de sus posiciones, una
		# franja de 46 px de alto donde caballos y burros se pisaban sin remedio)
		var nueva := caja.grow_individual(40, 16, 40, 16)
		if zonas.has(z):
			nueva = nueva.merge(zonas[z]["b"].abs())
		# sin salirse de su recinto (si vive en uno)
		var rec := recinto_de(caja.get_center())
		if rec != "":
			var c: Array = E["recintos"][rec]["caja"]
			var dentro := Rect2(float(c[0]) + 14.0, float(c[1]) + 14.0, float(c[2]) - float(c[0]) - 28.0, float(c[3]) - float(c[1]) - 24.0)
			if nueva.intersects(dentro):
				nueva = nueva.intersection(dentro)
		if zonas.has(z):
			zonas[z]["b"] = nueva
		else:
			zonas[z] = {"b": nueva}
		if rec == "" and not zonas[z].has("ok"):
			# suelta por fuera de los recintos: que crezca no la mete en ninguno (ni en su valla)
			var R: Dictionary = E["recintos"]
			zonas[z]["ok"] = func(q: Vector2) -> bool: return not _en_recinto(q, R)
		for a in actores:
			if String(a.sp.get("zona", "")) == z:
				# los solitarios que viven lejos unos de otros (los ratones) se quedan con su territorio: la caja que los abarca
				# a todos les mandaba a correr por media granja (y por encima de los granjeros)
				var suya: Rect2 = a.zona["b"].abs()
				if suya.has_point(a.position) and zonas[z]["b"].get_area() > suya.get_area() * 3.0 and not a.sp.has("sigue"):
					continue
				a.zona = zonas[z]
	for a in actores:
		_sin_valla_detras(a)
	# a quién sigue cada uno (las capas de color y los que se sumaron, también)
	for a in actores:
		a.busca_lider()
	# de día, unas gallinas (las que no crían) y el pavo andan sueltos por el patio; de noche vuelven a su corral
	var sueltas := 0
	for a in actores:
		# (sólo cuentan las crías: las gallinas de otro color que van con ella no la atan al corral)
		var cria_alguien := false
		for c in actores:
			if c.madre_g == a and c.base in Comp.CRIAS:
				cria_alguien = true
		var vale := false   # usuario 26-10: «tiene que estar todo en cada sitio»; nadie sale de su corral al patio
		if not vale or not zonas.has("patio_aves"):
			continue
		if a.base == "Gallina":
			sueltas += 1
		a.patio_de_dia = true
		a.zona_corral = a.zona
		a.zona = zonas["patio_aves"]
		a.en_patio = true
		a.coloca()
	# las del corral que iban detrás de una de las sueltas buscan otra líder dentro
	for a in actores:
		a.busca_lider()
	# los sitios del reparto, con los cuerpos de verdad, a veces se tapan (el caballo y la burra): antes de empezar, cada
	# uno se aparta lo justo, que nadie arranque encima de otro
	for vuelta in 3:
		for a in actores:
			if a.nombre in ["granjero", "washerwoman"]:
				continue
			if cuerpo_toca(a, a.position) > 0.0 or recinto_de(a.position) != casa_de(a):
				# (el sitio del reparto encima de una pieza o fuera de su recinto: al sitio libre más cercano de su recinto)
				a.coloca()   # (como al colocar a los que se suman: el sitio libre que menos tapa, junto a los suyos)
			if espacio(a.position, a):
				continue
			var q = a.aparta()
			if q == null:
				q = a.destino_seguro(a.position, 30.0)
			if q != null:
				a.position = q


# ------------------------------------------------------------------------------------------------------ cámara
func _camara() -> void:
	cam = Camera2D.new()   # sin límites: lo de fuera de la granja, el violeta del fondo, centrada (ver _process)
	add_child(cam)
	cam.make_current()
	get_viewport().size_changed.connect(_ajusta_zoom)
	_ajusta_zoom()


func _escala_pantalla() -> float:
	## cuántos píxeles de pantalla mide un píxel de la base (la ventana se escala por un entero)
	return maxf(1.0, floorf(float(DisplayServer.window_get_size().x) / get_viewport_rect().size.x + 0.01))


func _niveles_zoom() -> Array:
	## la granja entera (un píxel de pantalla por píxel de mundo: nítida, sin reescalar) y de cerca 1x, 2x, 3x, 4x
	var vista := get_viewport_rect().size   # en píxeles de la base: lo que mide la cámara con zoom 1
	var e := _escala_pantalla()
	var libre: Rect2 = ui.zona_libre() if ui != null else Rect2(Vector2.ZERO, vista)
	var encaja := minf(libre.size.x / float(E["W"]), libre.size.y / float(E["H"]))   # la granja entera, sin nada encima
	var nitida := 1.0 / e                                                    # un píxel de pantalla por píxel de mundo
	if encaja <= 0.01:
		encaja = 1.0 / e   # sin ventana (pruebas sin pantalla)
	# crítico 26-10 (punto 13): nada de zoom con decimales, que emborrona. Si cabe un nivel nítido (un número entero de
	# píxeles de pantalla por píxel de mundo), el mayor que quepa; si no, un píxel de la base por un número entero de
	# píxeles de mundo
	if floorf(encaja * e + 0.001) >= 1.0:
		encaja = floorf(encaja * e + 0.001) / e
	else:
		encaja = 1.0 / ceilf(1.0 / encaja - 0.001)
	var niveles := [encaja]
	if nitida > encaja + 0.01 and nitida < 1.0:
		niveles.append(nitida)
	return niveles + [1.0, 2.0, 3.0, 4.0]


func _zoom_minimo() -> int:
	return 1


func _ajusta_zoom(suave := false) -> void:
	if VIDEO:
		return   # el vídeo lleva su propia cámara: la granja entera a 1:1 en 1280x720
	# usuario 25-10: «hay que ver toda la granja»: de entrada, la granja entera. suave: la interfaz ha cambiado lo que
	# deja libre (se ha retirado la ayuda) y la granja se reencaja con un tween corto, sin salto
	var z := Vector2.ONE * float(_niveles_zoom()[0])
	if suave:
		if elegido == null and vista_general() and not cam.zoom.is_equal_approx(z):
			create_tween().tween_property(cam, "zoom", z, 0.4)
		return
	cam.zoom = z


func vista_general() -> bool:
	return cam.zoom.x < 1.0


func _zoom(paso: int) -> void:
	var niveles := _niveles_zoom()
	var i := 0
	for k in niveles.size():
		if absf(niveles[k] - cam.zoom.x) < 0.01:
			i = k
	var antes := cam.zoom.x
	var m := get_global_mouse_position()
	cam.zoom = Vector2.ONE * float(niveles[clampi(i + paso, 0, niveles.size() - 1)])
	if not elegido and cam.zoom.x != antes:
		cam.position = m - (m - cam.position) * antes / cam.zoom.x   # el punto bajo el ratón se queda quieto
	if paso > 0 and elegido:
		cam.position = elegido.position   # acercarse es acercarse al que tienes elegido


func visita(nombre: String, ya := false) -> void:
	var a: Actor = por_nombre[nombre]
	var libre_ui: Rect2 = ui.zona_libre()
	ir_a = a.position + Vector2(0, -20) + (get_viewport_rect().size / 2.0 - libre_ui.get_center()) / cam.zoom
	if ya:
		cam.position = ir_a
		ir_a = null
	ui.marca_familia(_familia_de(a) if not ya else "")


func _familia_de(a: Actor) -> String:
	# el que da nombre a la familia: el propio animal o aquel a quien sigue, hasta arriba
	var x := a
	while x.lider() != null:
		x = x.lider()
	return x.nombre


func elige(a: Actor) -> void:
	if a:
		ui.usa(["CLICK", "TAP"])
		ui.ya_ha_elegido()
	if elegido and elegido != a:
		elegido.mando = Vector2.ZERO   # el que suelta vuelve a su vida al rato
	if a and vista_general():
		create_tween().tween_property(cam, "zoom", Vector2.ONE * 2.0, 0.4)
	elif a == null and elegido != null and not vista_general():
		create_tween().tween_property(cam, "zoom", Vector2.ONE * float(_niveles_zoom()[0]), 0.4)
	elegido = a
	if a:
		ui.abre_ficha(a)
		ui.marca_familia(_familia_de(a))
	else:
		ui.cierra_ficha()
	marco.queue_redraw()


func pon_noche(on: bool) -> void:
	## NIGHT / DAY: el reloj corre deprisa hasta la noche cerrada o hasta la mañana, y sigue pasando despacio
	_hora_destino = 440.0 if on else 30.0
	if on and (hora < A_CASA or hora >= 575.0):
		# los granjeros echan a andar deprisa a casa antes de que corra el reloj (y el reloj les espera)
		for a in actores:
			if a.nombre in ["granjero", "washerwoman"]:
				a.a_dormir(true)


func _granjeros_fuera() -> bool:
	for a in actores:
		if a.nombre in ["granjero", "washerwoman"] and a.visible:
			return true
	return false


func _mete_en_casa() -> void:
	## el último recurso si no llegan: dentro ya
	for a in actores:
		if a.nombre in ["granjero", "washerwoman"] and a.visible:
			a.a_dormir()
			a.visible = false
			a.cola = [{"anim": "idle", "vueltas": 4, "dentro": true}]
			a.pide = null
			a.empieza(a.cola.pop_front())


func echa_comida(p: Vector2) -> void:
	## clic derecho: le echan de comer ahí; acuden los del recinto que estén cerca
	var cerca := actores.filter(func(a): return a.position.distance_to(p) < 120.0)
	cerca.sort_custom(func(a, b): return a.position.distance_to(p) < b.position.distance_to(p))
	for a in cerca.slice(0, 6):
		a.llama(p)


func suena(a: Actor, anim: String) -> void:
	## el sonido de una animación de voz, desde donde está el animal, al empezar el clip (sincronizado con él).
	## Los sonidos son de la demo (propios o CC0), no del pack: res://sonidos/<Criatura>_<anim>.ogg o .wav, y si no
	## hay de la capa de color, el de la especie. Lo lleva sonido.gd (con la mezcla, el tope y el primer clic)
	if sfx:
		sfx.voz(a, anim)


static var _niveles := {}


static func nivel(ruta: String) -> float:
	## la ganancia de ese sonido por su papel (voz > efecto > ambiente, pico bajo -3 dBFS): _tools/niveles_sonido.py
	if _niveles.is_empty() and FileAccess.file_exists("res://sonidos/niveles.json"):
		_niveles = JSON.parse_string(FileAccess.get_file_as_string("res://sonidos/niveles.json"))
	return float(_niveles.get(ruta.get_file().get_basename(), 0.0))


static func ruta_sonido(nombre: String, anim: String) -> String:
	## la voz de esa criatura (o de su especie) para esa animación, o el ruido común de la acción (_aleteo, _eat_start…)
	var base := nombre.split("_")[0]
	for r in ["res://sonidos/%s_%s.ogg" % [nombre, anim], "res://sonidos/%s_%s.ogg" % [base, anim], "res://sonidos/_%s.ogg" % anim]:
		if ResourceLoader.exists(r):
			return r
	return ""


func _ambiente() -> void:
	## el fondo: pájaros y algo de viento de día, grillos de noche, y el agua del estanque desde donde está
	_amb_dia = _bucle("res://sonidos/_amb_dia.ogg", 0.0)
	_amb_viento = _bucle("res://sonidos/_amb_viento.ogg", 0.0)
	_amb_noche = _bucle("res://sonidos/_amb_noche.ogg", -80.0)
	var agua := AudioStreamPlayer2D.new()
	agua.stream = _con_bucle("res://sonidos/_amb_agua.ogg")
	if agua.stream:
		agua.position = estanque["c"]
		agua.max_distance = 360.0
		agua.attenuation = 1.4
		agua.autoplay = true
		add_child(agua)


func _con_bucle(ruta: String) -> AudioStream:
	if not ResourceLoader.exists(ruta):
		return null
	var st: AudioStream = load(ruta)
	if st is AudioStreamOggVorbis:
		st.loop = true
	return st


func _bucle(ruta: String, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = _con_bucle(ruta)
	p.volume_db = db
	p.autoplay = p.stream != null
	add_child(p)
	return p


func pon_sonido(on: bool) -> void:
	sonido = on
	AudioServer.set_bus_mute(0, not on)


func _usado() -> void:
	if not tocado:
		tocado = true
		get_tree().create_timer(6.0).timeout.connect(ui.apaga_ayuda)


var _dedos := {}
var _pellizco := 0.0


func _unhandled_input(ev: InputEvent) -> void:
	# pellizco con dos dedos: un paso de zoom entero cada vez que la distancia cambia un 30 %
	if ev is InputEventScreenTouch:
		if ev.pressed:
			_dedos[ev.index] = ev.position
		else:
			_dedos.erase(ev.index)
		_pellizco = 0.0
	elif ev is InputEventScreenDrag and _dedos.size() == 2:
		_dedos[ev.index] = ev.position
		var d: float = _dedos.values()[0].distance_to(_dedos.values()[1])
		if _pellizco == 0.0:
			_pellizco = d
		elif d > _pellizco * 1.3 or d < _pellizco / 1.3:
			_zoom(1 if d > _pellizco else -1)
			ui.usa(["PINCH"])
			_pellizco = d
		arrastre = null
		return
	if ev is InputEventMouseButton:
		if ev.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN] and ev.pressed:
			ui.usa(["WHEEL"])
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP and ev.pressed:
			_zoom(1)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN and ev.pressed:
			_zoom(-1)
		elif ev.button_index == MOUSE_BUTTON_RIGHT and ev.pressed:
			ui.usa(["RIGHT CLICK"])
			echa_comida(get_global_mouse_position())
		elif ev.button_index == MOUSE_BUTTON_LEFT:
			if ev.pressed:
				arrastre = {"de": ev.position, "cam": cam.position, "movio": false, "t": reloj}
			else:
				if arrastre and not arrastre["movio"] and reloj - arrastre["t"] > 0.5:
					echa_comida(get_global_mouse_position())   # mantener pulsado: dar de comer
				elif arrastre and not arrastre["movio"]:
					var a := _animal_en(get_global_mouse_position())
					if a:
						a.clic()
					elige(a)
				arrastre = null
		ultimo_gesto = reloj
		_usado()
	elif ev is InputEventMouseMotion:
		if arrastre:
			var dd: Vector2 = ev.position - arrastre["de"]
			if dd.length() > 4:
				arrastre["movio"] = true
			if arrastre["movio"]:
				ui.usa(["WASD|DRAG", "DRAG"])
				cam.position = arrastre["cam"] - dd / cam.zoom
				ir_a = null
				ultimo_gesto = reloj
	elif ev is InputEventKey and ev.pressed:
		if ev.keycode == KEY_ESCAPE:
			elige(null)

		elif ev.keycode == KEY_N:
			ui.b_noche.button_pressed = not ui.b_noche.button_pressed
		elif ev.keycode == KEY_I:
			cambia_estacion()
		elif ev.keycode == KEY_M:
			ui.b_sonido.button_pressed = not ui.b_sonido.button_pressed
		elif ev.keycode in [KEY_PLUS, KEY_KP_ADD, KEY_EQUAL]:
			_zoom(1)
		elif ev.keycode in [KEY_MINUS, KEY_KP_SUBTRACT]:
			_zoom(-1)
		ultimo_gesto = reloj
		ir_a = null
		_usado()


func _animal_en(p: Vector2) -> Actor:
	var mejor: Actor = null
	for a in actores:
		if a.caja().grow(2).has_point(p) and (mejor == null or a.position.y > mejor.position.y):
			mejor = a
	return mejor


func _dibuja_marco() -> void:
	## las esquinas de latón (crítico 26-10): se dibujan en la interfaz, con píxeles de la base, para que compartan
	## rejilla con la letra y no engorden ni adelgacen con el zoom
	ui.pon_marcos(caja_en_pantalla(elegido), caja_en_pantalla(bajo_raton) if bajo_raton != elegido else Rect2(),
		floorf(fmod(reloj * 1.6, 2.0)))


func caja_en_pantalla(a: Actor) -> Rect2:
	## lo que ocupa su animación de ahora, en píxeles de la base y redondeado (vacío si no hay animal)
	if a == null:
		return Rect2()
	var r := a.caja_anim()
	var t := get_viewport().get_canvas_transform()
	var p0: Vector2 = (t * r.position).round()
	var p1: Vector2 = (t * r.end).round()
	return Rect2(p0, p1 - p0)


var _us_escena := 0
const MAS_ANIMALES := ["Ternera", "Cabra_chocolate", "Cabrito_chocolate", "Caballo_blanco", "Potro_bayo",
	"Burro_chocolate", "PatoDomestico", "Patito", "Ganso_canela", "Lechon_rojo", "Conejo_blanco", "Gazapo_gris",
	"Oveja", "Cordero", "Gallina_ocre"]
# cuánto sitio libre tiene que quedar en un recinto, en veces lo que ocupan los cuerpos, para meter uno más
const CUPO := 3.0
var _sobre_prueba := ""


func _process(delta: float) -> void:
	var t_us := Time.get_ticks_usec()
	_process_de_verdad(delta)
	_us_escena += Time.get_ticks_usec() - t_us


func _process_de_verdad(delta: float) -> void:
	reloj += delta
	_estacion(delta)
	_puertas(delta)
	_patos_en_el_agua()
	_reloj_del_dia(delta)
	_vida_social(delta)
	var k := int(reloj * 1000.0 / 140.0) % 8
	for s in viento:
		s.frame = k
	var v := Input.get_vector("ui_left", "ui_right", "ui_up", "ui_down")
	for par in [[KEY_A, Vector2.LEFT], [KEY_D, Vector2.RIGHT], [KEY_W, Vector2.UP], [KEY_S, Vector2.DOWN]]:
		if Input.is_physical_key_pressed(par[0]):
			v += par[1]
	if elegido and "--prueba_mando" in OS.get_cmdline_user_args() and Engine.get_process_frames() % 5 == 0:
		var estorban: Array = []
		var delante_r: Rect2 = elegido.huella(elegido.position + Actor.VECTOR[elegido.dir] * 4.0).grow(-2.0)
		for o in actores:
			if o != elegido and o.visible and delante_r.intersects(o.huella(o.position).grow(-2.0)):
				estorban.append(o.nombre)
		print("MANDO ", snappedf(reloj, 0.1), " v=", v, " pos=", elegido.position.round(), " act=", elegido.paso.get("anim"), " dir=", elegido.dir,
			" libre=", libre(elegido.position + Actor.VECTOR[elegido.dir] * 14.0, elegido.zona, elegido.margen), " estorban=", estorban)
	if elegido:
		# con un animal elegido, WASD y las flechas lo llevan a él (mayúsculas: corre); la cámara lo sigue
		elegido.mando = v
		elegido.corre = Input.is_physical_key_pressed(KEY_SHIFT)
		if v != Vector2.ZERO:
			ultimo_gesto = reloj
			ui.usa(["WASD"])
			if elegido.corre:
				ui.usa(["SHIFT"])
	elif v != Vector2.ZERO:
		ui.usa(["WASD|DRAG"])
		cam.position += v.normalized() * 140.0 * delta / sqrt(cam.zoom.x)
		ultimo_gesto = reloj
	# con un animal elegido, la cámara lo acompaña
	if elegido and arrastre == null and not vista_general():
		# se encuadra en lo que la interfaz deja libre, no en el centro de la ventana
		var libre_ui: Rect2 = ui.zona_libre()
		var desvio := (get_viewport_rect().size / 2.0 - libre_ui.get_center()) / cam.zoom
		ir_a = elegido.position + Vector2(0, -float(elegido.d["pie"] - elegido.d["tope"]) / 2.0) + desvio
	# solo, la cámara pasea por las familias
	if reloj - ultimo_gesto > 9.0 and ir_a == null and elegido == null and not vista_general():
		visita(ui.FAMILIAS[gira % ui.FAMILIAS.size()][1])
		gira += 1
		ultimo_gesto = reloj - 3.0
	if ir_a != null:
		cam.position = cam.position.lerp(ir_a, 1.0 - pow(0.04, delta))
		if cam.position.distance_to(ir_a) < 0.5 and elegido == null:
			ir_a = null
	var media := get_viewport_rect().size / cam.zoom / 2.0
	var mundo_tam := Vector2(float(E["W"]), float(E["H"]))
	var desvio_ui: Vector2 = (get_viewport_rect().size / 2.0 - ui.zona_libre().get_center()) / cam.zoom
	cam.position.x = mundo_tam.x / 2.0 + desvio_ui.x if media.x * 2.0 >= mundo_tam.x else clampf(cam.position.x, media.x, mundo_tam.x - media.x)
	cam.position.y = mundo_tam.y / 2.0 + desvio_ui.y if media.y * 2.0 >= mundo_tam.y else clampf(cam.position.y, media.y, mundo_tam.y - media.y)
	bajo_raton = _animal_en(get_global_mouse_position()) if arrastre == null else null
	if _sobre_prueba != "" and por_nombre.has(_sobre_prueba):
		bajo_raton = por_nombre[_sobre_prueba]   # para grabar la pista sin ratón: -- --prueba_sobre Gallina
	var llevando: bool = elegido != null and elegido.manual
	# en la vista de la granja entera, nada al pasar el ratón (los animales son diminutos y la etiqueta los taparía):
	# se señala y se nombra al acercarse (usuario 26-10)
	if vista_general():
		bajo_raton = null
	if bajo_raton and bajo_raton != elegido and arrastre == null and not llevando and not DisplayServer.is_touchscreen_available():
		var otros := []   # los de al lado, para que el nombre no los pise
		for a in actores:
			if a != bajo_raton and a.visible and a.position.distance_to(bajo_raton.position) < 60.0:
				otros.append(caja_en_pantalla(a))
		ui.pista_sobre(ui._quien(bajo_raton.nombre)[0], caja_en_pantalla(bajo_raton), otros)
	else:
		ui.pista_sobre("", Rect2())
	marco.queue_redraw()


# ------------------------------------------------------------------------------------------------------ estaciones
# SEASON (Game Off 2026, tema SHIFT): la granja rota verano → otoño → invierno → verano. El cambio va píxel a píxel
# (trama del shader), nunca con fundido.
func cambia_estacion() -> void:
	estacion_i = (estacion_i + 1) % 3
	otono_meta = 1.0 if estacion_i >= 1 else 0.0
	invierno_meta = 1.0 if estacion_i == 2 else 0.0
	if estacion_i == 0 and invierno >= 1.0:
		# del invierno al verano: bajo la nieve ya no queda otoño, así que lo que se destapa sale verde
		otono = 0.0
		RenderingServer.global_shader_parameter_set("otono", otono)
	ui.pon_estacion(ESTACIONES[estacion_i], estacion_i > 0)


func es_invierno() -> bool:
	return invierno_meta > 0.5


func _estacion(delta: float) -> void:
	if invierno != invierno_meta:
		invierno = move_toward(invierno, invierno_meta, delta / CAMBIO_ESTACION)
		RenderingServer.global_shader_parameter_set("invierno", invierno)
	if otono != otono_meta:
		otono = move_toward(otono, otono_meta, delta / CAMBIO_ESTACION)
		RenderingServer.global_shader_parameter_set("otono", otono)

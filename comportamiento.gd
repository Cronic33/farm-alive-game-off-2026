extends RefCounted
## Qué hace cada especie y con quién va (docs/COMPORTAMIENTO_ESCENA.md). w: pesos de lo que elige cuando está
## libre; las animaciones que la criatura no tenga se saltan. sigue/cerca/lugar: a quién sigue, a qué distancia y
## dónde se pone (detras = en fila, lado, cerca). zona: dónde vive (las zonas las calcula escena.gd desde el plano).

const ESPECIE := {
	"Gallina": {"zona": "aves", "vel": 16.0, "w": {"idle": 3, "eat": 7, "walk": 4, "aleteo": 0.4, "lay_egg": 0.25, "sleep": 0.3, "salir": 0.12}, "clic": "lay_egg"},
	"Gallo": {"zona": "gallo", "vel": 18.0, "w": {"idle": 5, "eat": 2, "walk": 2, "aleteo": 1, "crow": 1.2, "sleep": 0.2}, "clic": "crow"},
	"Pollito": {"zona": "aves", "vel": 15.0, "sigue": "Gallina", "cerca": 18.0, "lugar": "detras", "w": {"idle": 3, "eat": 5, "walk": 2, "peep": 1, "aleteo": 0.4, "sleep": 0.3}, "clic": "peep"},
	"PavoMacho": {"zona": "pavos", "vel": 16.0, "sigue": "Pava", "cerca": 40.0, "lugar": "lado", "w": {"idle": 4, "eat": 3, "walk": 2, "aleteo": 1.5}, "clic": "aleteo"},
	"Pava": {"zona": "pavos", "vel": 16.0, "w": {"idle": 3, "eat": 5, "walk": 3, "aleteo": 0.3}, "clic": "aleteo"},
	"Pavipollo": {"zona": "pavos", "vel": 15.0, "sigue": "Pava", "cerca": 22.0, "lugar": "detras", "w": {"idle": 3, "eat": 4, "walk": 2}},
	"Oveja": {"zona": "ovejas", "vel": 14.0, "w": {"idle": 2, "eat": 9, "walk": 2}},
	"Carnero": {"zona": "ovejas", "vel": 14.0, "sigue": "Oveja", "cerca": 40.0, "lugar": "lado", "rebano": true, "w": {"idle": 2, "eat": 8, "walk": 1}},
	"Cordero": {"zona": "ovejas", "vel": 15.0, "sigue": "Oveja", "cerca": 20.0, "lugar": "detras", "rebano": true, "w": {"idle": 3, "eat": 6, "walk": 1}},
	"Cabra": {"zona": "cabras", "vel": 18.0, "w": {"idle": 4, "eat": 5, "walk": 3}},
	"MachoCabrio": {"zona": "cabras", "vel": 18.0, "w": {"idle": 4, "eat": 4, "walk": 2, "attack": 0.5}, "clic": "attack"},
	"Cabrito": {"zona": "cabras", "vel": 18.0, "corre": 48.0, "sigue": "Cabra", "cerca": 42.0, "lugar": "cerca", "w": {"idle": 3, "eat": 3, "walk": 2, "run": 1.5}},
	"Cerdo": {"zona": "cerdos", "vel": 14.0, "w": {"idle": 3, "eat": 8, "walk": 2}},
	"Verraco": {"zona": "cerdos", "vel": 12.0, "w": {"idle": 7, "eat": 3, "walk": 1}},
	"Lechon": {"zona": "cerdos", "vel": 15.0, "sigue": "Cerdo", "cerca": 22.0, "lugar": "lado", "w": {"idle": 2, "eat": 6, "walk": 1}},
	"Vaca": {"zona": "vacas", "vel": 14.0, "w": {"idle": 3, "eat": 8, "walk": 2}},
	"Toro": {"zona": "toro", "vel": 14.0, "w": {"idle": 7, "eat": 3, "walk": 1}},
	"Ternero": {"zona": "vacas", "vel": 15.0, "sigue": "Vaca", "cerca": 30.0, "lugar": "lado", "w": {"idle": 3, "eat": 5, "walk": 1}},
	"Ternera": {"zona": "vacas", "vel": 15.0, "sigue": "Vaca", "cerca": 30.0, "lugar": "lado", "w": {"idle": 3, "eat": 5, "walk": 1}},
	"Semental": {"zona": "caballos", "vel": 20.0, "w": {"idle": 5, "eat": 4, "walk": 2}},
	"Caballo": {"zona": "caballos", "vel": 20.0, "sigue": "Semental", "cerca": 40.0, "lugar": "lado", "w": {"idle": 4, "eat": 4, "walk": 1}},
	"Potro": {"zona": "caballos", "vel": 20.0, "corre": 56.0, "sigue": "Caballo", "cerca": 50.0, "lugar": "cerca", "w": {"idle": 3, "eat": 2, "walk": 1, "run": 2}, "clic": "run"},
	"Burro": {"zona": "burros", "vel": 14.0, "w": {"idle": 6, "eat": 4, "walk": 1, "bray": 0.6, "sleep": 0.4}, "clic": "bray"},
	"BurroMacho": {"zona": "burros", "vel": 14.0, "sigue": "Burro", "cerca": 34.0, "lugar": "lado", "w": {"idle": 6, "eat": 4, "walk": 1}},
	"Pollino": {"zona": "burros", "vel": 14.0, "sigue": "Burro", "cerca": 22.0, "lugar": "detras", "w": {"idle": 4, "eat": 3, "walk": 1}},
	"PatoDomestico": {"zona": "pato", "vel": 12.0, "w": {"idle": 3, "eat": 2, "walk": 5, "volar": 0.12}},
	"PatoMacho": {"zona": "pato", "vel": 12.0, "sigue": "PatoDomestico", "cerca": 44.0, "lugar": "cerca", "w": {"idle": 4, "eat": 2, "walk": 3, "volar": 0.15}},
	"Patito": {"zona": "pato", "vel": 13.0, "sigue": "PatoDomestico", "cerca": 14.0, "lugar": "detras", "w": {"idle": 3, "eat": 2, "walk": 1}},
	"GansoMacho": {"zona": "orilla", "vel": 14.0, "w": {"idle": 9, "eat": 2, "walk": 2, "attack": 0.3, "volar": 0.1}},
	"Ganso": {"zona": "orilla", "vel": 14.0, "w": {"idle": 3, "eat": 5, "walk": 3, "volar": 0.08}},
	"Ansarino": {"zona": "orilla", "vel": 14.0, "sigue": "Ganso", "cerca": 16.0, "lugar": "detras", "w": {"idle": 3, "eat": 4, "walk": 1}},
	"Conejo": {"zona": "conejos", "vel": 22.0, "w": {"idle": 4, "eat": 6, "walk": 2}},
	"ConejoMacho": {"zona": "conejos", "vel": 22.0, "w": {"idle": 5, "eat": 5, "walk": 2}},
	"Gazapo": {"zona": "conejos", "vel": 20.0, "sigue": "Conejo", "cerca": 20.0, "lugar": "lado", "w": {"idle": 3, "eat": 5, "walk": 1}},
	"Raton": {"zona": "raton", "vel": 60.0, "corre": 60.0, "w": {"idle": 4, "run": 5}, "clic": "run"},
}
# crías que maman de su madre de vez en cuando (peso en su tabla «w»: mamar)
# las que crían (las crías las siguen); un macho no cría
const MADRES := ["Gallina", "Pava", "PatoDomestico", "Ganso", "Oveja", "Cabra", "Cerdo", "Vaca", "Caballo", "Burro", "Conejo"]
const MAMAN := {"Ternero": 1.2, "Ternera": 1.2, "Gazapo": 1.0, "Potro": 1.0, "Cordero": 1.2, "Cabrito": 0.8, "Lechon": 1.5, "Pollino": 1.0}
# los que, cuando echan a andar, arrastran a su grupo a la vez (manada, rebaño): no uno detrás de otro
const MANADA := ["Semental", "Oveja", "Burro", "Vaca"]
# las crías (juegan corriendo entre ellas; las de ave, las defienden el ganso y el gallo)
const CRIAS := ["Pollito", "Pavipollo", "Cordero", "Cabrito", "Lechon", "Ternero", "Ternera", "Potro", "Pollino", "Patito",
	"Ansarino", "Gazapo"]
# los machos: se topan con otro de su especie o de su recinto (y si están solos, contra la valla)
const MACHOS := ["Gallo", "PavoMacho", "Carnero", "MachoCabrio", "Verraco", "Toro", "Semental", "BurroMacho", "PatoMacho",
	"GansoMacho", "ConejoMacho"]
# quién sale a defender a las crías de ave si un granjero pasa demasiado cerca
const PROTECTORES := ["GansoMacho", "Ganso", "Gallo", "PavoMacho"]
# las aves que acuden al grano
const GRANO := ["Gallina", "Gallo", "Pollito", "Pava", "PavoMacho", "Pavipollo", "PatoDomestico", "PatoMacho", "Patito",
	"Ganso", "GansoMacho", "Ansarino"]
# los que guardan un poco de aire entre ellos (px): las gallinas no se amontonan
const SEPARA := {"Gallina": 10.0}
# las piezas del plano donde se come y se bebe (contra la valla norte de cada recinto)
const COMEDEROS := ["comedero", "pesebre", "abrevadero", "almiar", "pacas"]
# animaciones de voz: suenan (si hay sonido en res://sonidos/) y entran solas en lo que hace el animal
const VOCES := ["moo", "bray", "cluck", "crow", "peep", "quack", "bleat", "grunt", "neigh", "honk", "gobble", "squeak"]
# lo que no se elige como acción propia: ciclo de vida, piezas de arranque y parada, golpe, muerte y vuelo (que va aparte)
const NO_PROPIAS := ["idle", "walk", "run", "eat", "sleep", "swim", "suckle", "death", "hurt", "fly", "despegue",
	"aterrizaje"]
const LIDER_VARIANTE := {"Vaca": "Vaca", "Caballo": "Semental", "Gallina": "Gallina", "Oveja": "Oveja", "Conejo": "Conejo"}
const VERBO := {"lay_egg": "lays an egg", "crow": "crows", "peep": "peeps", "aleteo": "flaps", "bray": "brays",
	"attack": "attacks", "run": "runs", "eat": "grazes", "sleep": "sleeps", "idle": "rests", "walk": "walks"}
const FAMILIAS := [["Hens", "Gallina"], ["Turkeys", "Pava"], ["Sheep", "Oveja"], ["Goats", "Cabra"], ["Pigs", "Cerdo"],
	["Cows", "Vaca"], ["Horses", "Semental"], ["Donkeys", "Burro"], ["Ducks", "PatoDomestico"], ["Geese", "Ganso"],
	["Rabbits", "Conejo"], ["Mouse", "Raton"]]

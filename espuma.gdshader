// La orilla del agua (crítico 26-10, punto 10): una línea de espuma clara por dentro del borde del estanque y del
// arroyo, que late cada 2 s. Grosor = el bloque de píxel de la vista (1 px de cerca; de lejos, lo que mida un píxel de
// pantalla), así se lee también con la granja entera. Píxeles enteros, sin degradados.
shader_type canvas_item;

uniform sampler2D mascara : filter_nearest;   // agua.png: rojo = agua
uniform vec2 tam = vec2(1280.0, 720.0);
uniform float bloque = 1.0;                   // tamaño del píxel de la vista, en píxeles de mundo
uniform float t = 0.0;                         // ms
uniform float fuerza = 1.0;                    // de noche, algo menos
uniform vec4 espuma : source_color = vec4(0.612, 0.8, 0.824, 1.0);   // #9cccd2

bool agua(vec2 p) {
	return texture(mascara, (p + 0.5) / tam).r > 0.5;
}

void fragment() {
	vec2 p = floor(UV * tam);
	vec2 q = floor(p / bloque) * bloque;   // el bloque entero se decide junto
	float a = 0.0;
	if (agua(q)) {
		float b = bloque;
		bool orilla = !agua(q + vec2(b, 0.0)) || !agua(q - vec2(b, 0.0)) || !agua(q + vec2(0.0, b)) || !agua(q - vec2(0.0, b));
		if (orilla) {
			// late cada 2 s, en tres escalones (sin degradado continuo)
			float pulso = 0.5 + 0.5 * sin(6.2831853 * t / 2000.0 + q.x * 0.02);
			a = (0.30 + 0.30 * floor(pulso * 3.0) / 2.0) * fuerza;
		}
	}
	COLOR = vec4(espuma.rgb, a);
}

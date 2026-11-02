// Las estaciones (Game Off 2026, tema SHIFT; 02-11): cada color del decorado se cambia por otro de la estación,
// color a color, sin tonos intermedios. Es la misma tabla que _tools/estaciones_demo.py (la de las pruebas). La nieve
// es la rampa del mundo «nieve_granja» del kit de marca. El cambio entre estaciones va por píxeles sueltos (trama de
// Bayer 4x4), nunca por fundido.
global uniform float invierno;   // 0 = la granja de siempre, 1 = nevada

const vec3 NIEVE[6] = vec3[6](vec3(0.384, 0.475, 0.604), vec3(0.471, 0.565, 0.678), vec3(0.576, 0.667, 0.769),
	vec3(0.682, 0.749, 0.824), vec3(0.765, 0.820, 0.875), vec3(0.933, 0.953, 0.969));
const float VERDE_LO = 0.184;   // luminancia de la hierba más oscura y más clara del suelo (percentiles 5 y 95)
const float VERDE_HI = 0.609;

vec3 est_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 est_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

vec3 color_invierno(vec3 c) {
	vec3 h = est_hsv(c);
	float g = h.x * 360.0;
	if (h.z < 0.16) {
		return c;                                   // contornos y negros
	}
	bool verde = g >= 50.0 && g < 170.0 && h.y > 0.15;
	bool paja = g >= 38.0 && g < 50.0 && h.y > 0.3 && h.z > 0.55;
	if (verde || paja) {
		// la nieve es lisa: casi toda la hierba va a los tres tonos claros; solo las sombras bajan a los azules
		float k = clamp((dot(c, vec3(0.299, 0.587, 0.114)) - VERDE_LO) / (VERDE_HI - VERDE_LO), 0.0, 1.0);
		if (paja) {
			k = min(1.0, k + 0.15);
		}
		return k < 0.12 ? NIEVE[2] : k < 0.45 ? NIEVE[3] : k < 0.9 ? NIEVE[4] : NIEVE[5];
	}
	if (g >= 170.0 && g < 260.0 && h.y > 0.15) {
		return mix(c, vec3(0.416, 0.549, 0.682), 0.45);   // el agua, fría y gris azulada (#6a8cae; crítico 02-11, 4)
	}
	// madera, tierra y piedra: más frías y apagadas, como en una mañana helada
	vec3 o = est_rgb(vec3(h.x, h.y * 0.72, h.z * 0.95));
	return vec3(o.r * 0.95, o.g * 0.98, min(1.0, o.b * 1.06));
}

// solo el suelo: la tierra de los caminos queda bajo nieve pisada y lo más oscuro (rodadas, barro) se hiela gris azulado
// (crítico 02-11, 1 y 4)
vec3 suelo_invierno(vec3 c) {
	vec3 h = est_hsv(c);
	float g = h.x * 360.0;
	if (g >= 10.0 && g < 50.0 && h.y > 0.2 && h.z >= 0.16) {
		if (h.z > 0.5) {
			return h.z > 0.66 ? vec3(0.557, 0.608, 0.690) : vec3(0.498, 0.549, 0.639);   // #8e9bb0 / #7f8ca3: el camino, un paso más oscuro que el campo (crítico r2, 2)
		}
		// la tierra oscura (la sombra de contacto al pie de la casa, el barro): sombra fría de la nieve, para que
		// las piezas sigan asentadas cuando todo se vuelve blanco (crítico del usuario 02-11)
		return h.z >= 0.38 ? NIEVE[1] : NIEVE[0];
	}
	return color_invierno(c);
}

float est_bayer(vec2 px) {
	int x = int(mod(px.x, 4.0));
	int y = int(mod(px.y, 4.0));
	int m[16] = int[16](0, 8, 2, 10, 12, 4, 14, 6, 3, 11, 1, 9, 15, 7, 13, 5);
	return (float(m[y * 4 + x]) + 0.5) / 16.0;
}

// px: el píxel (de mundo o de pantalla) que decide en qué momento de la transición cambia este punto
bool en_invierno(vec2 px) {
	return invierno > 0.0 && (invierno >= 1.0 || est_bayer(px) < invierno);
}

vec3 estacion(vec3 c, vec2 px) {
	return en_invierno(px) ? color_invierno(c) : c;
}

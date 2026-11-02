// Las estaciones (Game Off 2026, tema SHIFT; 02-11): cada color del decorado se cambia por otro de la estación,
// color a color, sin tonos intermedios. Es la misma tabla que _tools/estaciones_demo.py (la de las pruebas). La nieve
// es la rampa del mundo «nieve_granja» del kit de marca. El cambio entre estaciones va por píxeles sueltos (trama de
// Bayer 4x4), nunca por fundido.
global uniform float invierno;   // 0 = la granja de siempre, 1 = nevada
global uniform float otono;      // 0 = la granja de siempre, 1 = otoño (el invierno, si lo hay, va por encima)

const vec3 NIEVE[6] = vec3[6](vec3(0.384, 0.475, 0.604), vec3(0.471, 0.565, 0.678), vec3(0.576, 0.667, 0.769),
	vec3(0.682, 0.749, 0.824), vec3(0.765, 0.820, 0.875), vec3(0.933, 0.953, 0.969));
// otoño (02-11): la hierba seca, de oliva a ocre; las copas y las matas en rojos, naranjas y oros, de sombra a luz
// (usuario 02-11: «se nota muy poco»): la hierba, de oliva pardo en la sombra a oro viejo en la luz; más amarilla que
// la tierra de los caminos (que es más roja) para que los caminos se sigan leyendo y las hojas rojas resalten
const vec3 HIERBA_OTONO[5] = vec3[5](vec3(0.322, 0.290, 0.133), vec3(0.443, 0.400, 0.165), vec3(0.569, 0.506, 0.208),
	vec3(0.686, 0.608, 0.255), vec3(0.784, 0.698, 0.314));
const vec3 HOJA_OTONO[6] = vec3[6](vec3(0.361, 0.165, 0.118), vec3(0.541, 0.227, 0.118), vec3(0.710, 0.322, 0.165),
	vec3(0.831, 0.451, 0.184), vec3(0.910, 0.604, 0.235), vec3(0.949, 0.761, 0.353));
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

bool en_otono(vec2 px) {
	return otono > 0.0 && (otono >= 1.0 || est_bayer(px) < otono);
}

float est_azar(vec2 p) {
	return fract(sin(dot(p, vec2(12.9898, 78.233))) * 43758.5453);
}

// la luminancia de la hierba, de 0 (la más oscura) a 1 (la más clara)
float est_k_verde(vec3 c) {
	return clamp((dot(c, vec3(0.299, 0.587, 0.114)) - VERDE_LO) / (VERDE_HI - VERDE_LO), 0.0, 1.0);
}

bool est_verde(vec3 c) {
	vec3 h = est_hsv(c);
	float g = h.x * 360.0;
	// hasta 140: el agua verdosa de bebederos y abrevaderos (140-170) no se vuelve naranja
	return h.z >= 0.16 && g >= 50.0 && g < 140.0 && h.y > 0.15;
}

// las piezas (copas, matas, setos): cada mancha de 5 px coge su tono (rojo, naranja u oro) y una de cada siete se queda
// en oliva, para que el árbol no sea un bloque de un color. La luz y la sombra del dibujo siguen: se cambia la rampa
// la luz de otoño: un punto más cálida y dorada sobre la madera, la tierra y la piedra
vec3 otono_luz(vec3 c) {
	return min(vec3(1.0), c * vec3(1.05, 0.99, 0.88));
}

vec3 color_otono(vec3 c, vec2 px) {
	if (!est_verde(c)) {
		vec3 h = est_hsv(c);
		float g = h.x * 360.0;
		// el agua (azules) y los contornos se quedan como están
		return (h.z < 0.16 || (g >= 140.0 && g < 260.0 && h.y > 0.15)) ? c : otono_luz(c);
	}
	float k = est_k_verde(c);
	float a = est_azar(floor(px / 5.0));
	if (a < 0.14) {
		return HIERBA_OTONO[int(clamp(floor(k * 4.0 + 0.5), 0.0, 4.0))];
	}
	int i = int(clamp(floor(k * 4.0 + 0.5) + (a < 0.45 ? 0.0 : a < 0.8 ? 1.0 : 2.0) - 0.5, 0.0, 5.0));
	return HOJA_OTONO[i];
}

// ruido suave por casillas de 40 px: dónde se amontonan las hojas
float est_ruido(vec2 p) {
	vec2 i = floor(p / 40.0);
	vec2 f = fract(p / 40.0);
	f = f * f * (3.0 - 2.0 * f);
	return mix(mix(est_azar(i), est_azar(i + vec2(1.0, 0.0)), f.x),
		mix(est_azar(i + vec2(0.0, 1.0)), est_azar(i + vec2(1.0, 1.0)), f.x), f.y);
}

// una hoja caída: cada bloque de 3 px puede llevar una (rojo, naranja u oro), con 3 de sus píxeles en la hoja y el de
// abajo a la derecha en su sombra; en los montones, muchas, y en el resto, alguna suelta
bool hoja_caida(vec2 px, float densidad, out vec3 col) {
	vec2 b = floor(px / 3.0);
	if (est_azar(b) >= densidad) {
		return false;
	}
	vec2 d = px - b * 3.0;
	if (d.x > 1.5 || d.y > 1.5) {
		return false;
	}
	int i = 1 + int(est_azar(b + 7.0) * 4.0);
	col = (d.x > 0.5 && d.y > 0.5) ? HOJA_OTONO[i - 1] : HOJA_OTONO[i];
	return true;
}

// el suelo: la hierba seca, y las hojas caídas por encima (también en los caminos, menos)
vec3 suelo_otono(vec3 c, vec2 px) {
	vec3 h = est_hsv(c);
	if (h.z < 0.16) {
		return c;
	}
	float monton = smoothstep(0.45, 0.85, est_ruido(px));
	vec3 hoja;
	if (est_verde(c)) {
		if (hoja_caida(px, 0.06 + 0.5 * monton, hoja)) {
			return hoja;
		}
		return HIERBA_OTONO[int(clamp(floor(est_k_verde(c) * 4.6), 0.0, 4.0))];
	}
	float g = h.x * 360.0;
	if (g >= 10.0 && g < 50.0 && h.y > 0.2 && hoja_caida(px, 0.02 + 0.2 * monton, hoja)) {
		return hoja;   // la tierra de los caminos
	}
	return otono_luz(c);
}

vec3 estacion(vec3 c, vec2 px) {
	return en_invierno(px) ? color_invierno(c) : en_otono(px) ? color_otono(c, px) : c;
}

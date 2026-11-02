// Las piezas del decorado (edificios, árboles, matas, vallas) en la estación del momento. Los animales no lo llevan.
shader_type canvas_item;

#include "res://estacion.gdshaderinc"

// en fragment(), COLOR ya viene multiplicado por la textura: el modulate se guarda aparte para no aplicarla dos veces
varying vec4 modula;

// el tejado entero bajo la nieve (crítico del usuario 02-11): las piezas con tejado o paja traen su máscara
// (_tools/mascaras_nieve.py); las demás, solo la nieve que se posa en el borde de arriba
uniform sampler2D mascara : filter_nearest;
uniform bool con_mascara = false;
// capa gruesa (molino y casetas; usuario 02-11): nieve lisa y un alero de nieve que cuelga 1-2 px bajo el tejado
uniform bool capa = false;

bool en_mascara(vec2 uv) {
	return uv.y >= 0.0 && texture(mascara, uv).a > 0.5;
}

void vertex() {
	modula = COLOR;
}

// ¿hay aire k píxeles más arriba? Las piezas van recortadas al contenido: fuera de la textura también es aire
bool aire(sampler2D tex, vec2 uv, float k, float alto) {
	float y = uv.y - k * alto;
	return y < 0.0 || texture(tex, vec2(uv.x, y)).a < 0.5;
}

void fragment() {
	vec4 c = texture(TEXTURE, UV);
	vec2 px = floor(FRAGCOORD.xy);
	vec3 rgb = estacion(c.rgb, px);
	// la nieve que se posa (crítico 02-11, 2): en invierno, lo que tiene aire justo encima (la cumbrera y el alero de
	// los tejados, la tapa de barriles y comederos) lleva 3 px de nieve: luz arriba y sombra en el borde de abajo
	vec3 hc = est_hsv(c.rgb);
	bool tejado = hc.y < 0.3 && hc.z < 0.42;   // gris oscuro y apagado: tejas y pizarra
	if (c.a > 0.5 && en_invierno(px)) {
		if (con_mascara && texture(mascara, UV).a > 0.5) {
			// la capa de nieve sigue el dibujo del tejado: las tablas y los haces quedan como sombras azules
			float k = dot(c.rgb, vec3(0.299, 0.587, 0.114));
			rgb = k < 0.15 ? NIEVE[2] : k < 0.25 ? NIEVE[3] : k < 0.55 ? NIEVE[4] : NIEVE[5];
			if (capa) {
				rgb = k < 0.15 ? NIEVE[4] : NIEVE[5];   // la capa tapa las tablas: solo se adivinan las juntas
			}
		} else if (con_mascara && capa && !(hc.y < 0.3 && hc.z > 0.6)) {   // las aspas, claras, pasan por delante
			// el alero de nieve: cuelga 1 o 2 px (según la columna) con la sombra fría debajo
			float paso = TEXTURE_PIXEL_SIZE.y;
			float largo = mod(floor(UV.x / TEXTURE_PIXEL_SIZE.x) * 7.0, 5.0) < 2.0 ? 2.0 : 1.0;
			if (en_mascara(UV - vec2(0.0, paso))) {
				rgb = NIEVE[4];
			} else if (largo > 1.5 && en_mascara(UV - vec2(0.0, 2.0 * paso))) {
				rgb = NIEVE[3];
			} else if (en_mascara(UV - vec2(0.0, (largo + 1.0) * paso))) {
				rgb = NIEVE[1];
			}
		}
		if (aire(TEXTURE, UV, 1.0, TEXTURE_PIXEL_SIZE.y)) {
			rgb = NIEVE[5];
		} else if (aire(TEXTURE, UV, 2.0, TEXTURE_PIXEL_SIZE.y)) {
			rgb = NIEVE[4];
		} else if (aire(TEXTURE, UV, 3.0, TEXTURE_PIXEL_SIZE.y)) {
			rgb = NIEVE[2];
		} else if (tejado && aire(TEXTURE, UV, 6.0, TEXTURE_PIXEL_SIZE.y)) {
			rgb = NIEVE[4];   // las vertientes oscuras (tejas, pizarra) cogen más masa de nieve (crítico r2, 1)
		} else if (tejado && aire(TEXTURE, UV, 7.0, TEXTURE_PIXEL_SIZE.y)) {
			rgb = NIEVE[1];
		}
	}
	COLOR = vec4(rgb, c.a) * modula;
}

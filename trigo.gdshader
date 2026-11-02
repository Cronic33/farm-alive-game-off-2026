// El viento en el trigo de la escena aprobada (vida_ambiente.viento_trigo): una ráfaga estrecha que cruza el trigal en
// diagonal cada 10 s; cada espiga que coge pasa al tono de la banda más clara (trigo_sube.png lo trae precalculado).
// El contorno no cambia: la silueta queda quieta. Píxeles enteros, nada de difuminados.
shader_type canvas_item;

#include "res://estacion.gdshaderinc"

uniform sampler2D sube : filter_nearest;
uniform vec2 tam = vec2(1280.0, 720.0);
uniform float t = 0.0;   // segundos (el reloj de la escena, el mismo de las matas)
uniform float dia = 1.0;     // 1 de día, 0 de noche: la hierba más viva de día (crítico 26-10, paleta)
uniform float mojado = 0.0;  // con la llovizna, el suelo un 8 % más oscuro

vec3 rgb_hsv(vec3 c) {
	vec4 K = vec4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
	vec4 p = mix(vec4(c.bg, K.wz), vec4(c.gb, K.xy), step(c.b, c.g));
	vec4 q = mix(vec4(p.xyw, c.r), vec4(c.r, p.yzx), step(p.x, c.r));
	float d = q.x - min(q.w, q.y);
	return vec3(abs(q.z + (q.w - q.y) / (6.0 * d + 1e-10)), d / (q.x + 1e-10), q.x);
}

vec3 hsv_rgb(vec3 c) {
	vec3 p = abs(fract(c.xxx + vec3(1.0, 2.0 / 3.0, 1.0 / 3.0)) * 6.0 - 3.0);
	return c.z * mix(vec3(1.0), clamp(p - 1.0, 0.0, 1.0), c.y);
}

void fragment() {
	vec2 px = floor(UV * tam);
	vec4 c = texture(TEXTURE, UV);
	vec3 original = c.rgb;
	vec4 s = texture(sube, (px + 0.5) / tam);
	if (s.a > 0.5) {
		float fase = (px.x * 0.8 + px.y * 0.6) / 300.0 - t / 10.0;
		// la misma ola que las matas y las copas: la ráfaga cruza todo a la vez (crítico 26-10, punto 8)
		if (cos(6.2831853 * fase) > 0.3) {
			c.rgb = s.rgb;
		}
	} else if (dia > 0.0) {
		// la hierba (verdes, no el trigo ni la tierra): de día, más saturada y un pelo más clara (#6a804a -> #6c8a44)
		vec3 h = rgb_hsv(c.rgb);
		if (h.x > 0.17 && h.x < 0.45 && h.y > 0.18) {
			h.y = min(1.0, h.y * (1.0 + 0.21 * dia));
			h.z = min(1.0, h.z * (1.0 + 0.07 * dia));
			c.rgb = hsv_rgb(h);
		}
	}
	// en invierno el trigal y la hierba están bajo la nieve: se toma el color de origen, sin la ráfaga ni el realce
	if (en_invierno(px)) {
		c.rgb = suelo_invierno(original);
		if (s.a > 0.5) {
			// el trigal seco bajo la helada: gris azulado claro con motas blancas (crítico r2, 3)
			float k = dot(original, vec3(0.299, 0.587, 0.114));
			c.rgb = k > 0.62 ? NIEVE[5] : k > 0.45 ? NIEVE[4] : k > 0.3 ? NIEVE[3] : NIEVE[2];
		}
	} else if (en_otono(px) && s.a < 0.5) {
		// en otoño la hierba se seca (el trigal, que ya es de oro, se queda con su ráfaga)
		c.rgb = suelo_otono(original, px);
	}
	c.rgb *= 1.0 - 0.08 * mojado;
	COLOR = c;
}

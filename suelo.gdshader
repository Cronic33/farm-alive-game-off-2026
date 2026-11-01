// El suelo vivo, hecho en el motor: el trigo se mece con el viento (cada píxel se desplaza un píxel entero, nunca
// medio, y una racha más clara lo cruza de vez en cuando) y los brillos del agua tiemblan. La máscara la saca
// _tools/web_demo_granja.py del plano: rojo = trigo, verde = agua.
shader_type canvas_item;

uniform sampler2D mascara : filter_nearest;
uniform vec2 tam = vec2(1280.0, 720.0);
uniform float viento = 1.0;

void fragment() {
	vec2 px = floor(UV * tam);
	vec4 m = texture(mascara, (px + 0.5) / tam);
	vec2 desv = vec2(0.0);
	float racha = sin(TIME * 0.7 - px.x * 0.03 + px.y * 0.015);
	if (m.r > 0.5) {
		// las espigas se mecen fila a fila; en la racha, más
		float fuerza = 0.55 + 0.75 * max(racha, 0.0);
		desv.x = floor(sin(TIME * 2.2 + px.y * 0.5 + px.x * 0.04) * fuerza * viento + 0.5);
	} else if (m.g > 0.5) {
		// el agua: sus líneas de brillo tiemblan un píxel, despacio
		desv.x = floor(sin(TIME * 1.4 + px.y * 0.8) * 0.85 + 0.5);
	}
	vec2 uv2 = (px + desv + 0.5) / tam;
	vec4 m2 = texture(mascara, uv2);
	// sólo se toma el píxel vecino si es de la misma superficie (el trigo no se come el camino)
	vec4 c = (m2.r == m.r && m2.g == m.g) ? texture(TEXTURE, uv2) : texture(TEXTURE, UV);
	if (m.r > 0.5) {
		c.rgb *= 1.0 + 0.07 * smoothstep(0.55, 1.0, racha) * viento;
	}
	COLOR = c;
}

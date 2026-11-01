// Sombras de nubes que pasan sobre la granja, hechas en el motor: ruido muy grande que se desplaza con el viento,
// cortado en dos tonos con un tramado ordenado de 2x2 para que el borde sea de píxel y no un degradado.
shader_type canvas_item;

uniform sampler2D ruido : repeat_enable, filter_linear;
uniform vec2 tam = vec2(1280.0, 720.0);
uniform vec4 sombra : source_color = vec4(0.11, 0.07, 0.16, 0.16);
uniform float corte = 0.58;

void fragment() {
	// la nube avanza a píxeles enteros y su tramado va pegado a ella: se desliza entera, sin motas que bailen
	vec2 px = floor(UV * tam) + floor(vec2(TIME * 9.0, TIME * 3.0));
	vec2 p = px / 900.0;
	float n = texture(ruido, p).r;
	// tramado 2x2: en el borde, uno de cada dos píxeles
	float bayer = mod(px.x + px.y * 2.0, 4.0) / 4.0;
	float dentro = step(corte + bayer * 0.05, n);
	COLOR = vec4(sombra.rgb, sombra.a * dentro);
}

// Las sombras de nube de la escena aprobada (vida_granja.nubes): tres nubes de tres lóbulos que cruzan en diagonal hacia
// abajo a la derecha, con el viento de todo lo demás (crítico 26-10, punto 8), y oscurecen TODO lo que pasan por debajo (suelo, piezas, animales y tejados), con el borde en
// escalones de píxel. Se multiplica sobre lo de debajo.
shader_type canvas_item;
render_mode blend_mul;

uniform vec2 tam = vec2(1280.0, 720.0);
uniform float t = 0.0;     // ms
uniform float ciclo = 30000.0;

float lobulo(vec2 p, vec2 c, vec2 r, float dx, float dy) {
	vec2 q = p - c;
	float ang = atan(q.y, q.x);
	float lob = 1.0 + 0.10 * sin(ang * 3.0 + dx) + 0.06 * sin(ang * 5.0 + dy);
	vec2 e = vec2(floor(q.x / 3.0) * 3.0, floor(q.y / 2.0) * 2.0);
	float d = pow(e.x / r.x, 2.0) + pow(e.y / r.y, 2.0);
	return d <= lob ? 1.0 : 0.0;
}

void fragment() {
	vec2 p = floor(UV * tam);
	float vx = (tam.x + 600.0) / ciclo;
	float vy = (tam.y + 300.0) / ciclo;
	float m = 0.0;
	// nube 1
	vec2 c1 = vec2(mod(0.0 + vx * t, tam.x + 600.0) - 300.0, mod(300.0 + vy * t, tam.y + 300.0) - 150.0);
	m = max(m, lobulo(p, c1 + vec2(0.0, 0.0), vec2(62.0, 24.0), 0.0, 0.0));
	m = max(m, lobulo(p, c1 + vec2(52.0, -8.0), vec2(54.0, 22.0), 52.0, -8.0));
	m = max(m, lobulo(p, c1 + vec2(-50.0, 6.0), vec2(50.0, 20.0), -50.0, 6.0));
	// nube 2
	vec2 c2 = vec2(mod(940.0 + vx * t, tam.x + 600.0) - 300.0, mod(810.0 + vy * t, tam.y + 300.0) - 150.0);
	m = max(m, lobulo(p, c2 + vec2(0.0, 0.0), vec2(66.0, 26.0), 0.0, 0.0));
	m = max(m, lobulo(p, c2 + vec2(56.0, 6.0), vec2(52.0, 20.0), 56.0, 6.0));
	m = max(m, lobulo(p, c2 + vec2(-52.0, -6.0), vec2(56.0, 22.0), -52.0, -6.0));
	// nube 3 (crítico 26-10, punto 9), más chica y a destiempo de las otras dos
	vec2 c3 = vec2(mod(1420.0 + vx * t, tam.x + 600.0) - 300.0, mod(560.0 + vy * t, tam.y + 300.0) - 150.0);
	m = max(m, lobulo(p, c3 + vec2(0.0, 0.0), vec2(48.0, 18.0), 0.0, 0.0));
	m = max(m, lobulo(p, c3 + vec2(40.0, 5.0), vec2(40.0, 16.0), 40.0, 5.0));
	m = max(m, lobulo(p, c3 + vec2(-38.0, -4.0), vec2(36.0, 15.0), -38.0, -4.0));
	COLOR = m > 0.5 ? vec4(0.88, 0.90, 0.95, 1.0) : vec4(1.0);
}

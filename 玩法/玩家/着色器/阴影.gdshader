shader_type canvas_item;

void fragment() {
	vec2 uv = UV - vec2(0.5);
	float a = 0.5;
	float b = 0.5;
	float dist = (uv.x * uv.x) / (a * a) + (uv.y * uv.y) / (b * b);
	if (dist > 1.0) {
		discard;
	}
}
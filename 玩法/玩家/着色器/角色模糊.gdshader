shader_type canvas_item;

uniform float 模糊强度: hint_range(0.0, 5.0) = 1.5;
uniform vec2 纹理尺寸 = vec2(64.0, 64.0);

void fragment() {
	vec2 texel_size = 1.0 / 纹理尺寸;
	float strength = 模糊强度;

	vec4 color = texture(TEXTURE, UV) * 0.30;
	color += texture(TEXTURE, UV + vec2(texel_size.x * strength, 0.0)) * 0.20;
	color += texture(TEXTURE, UV - vec2(texel_size.x * strength, 0.0)) * 0.20;
	color += texture(TEXTURE, UV + vec2(0.0, texel_size.y * strength)) * 0.15;
	color += texture(TEXTURE, UV - vec2(0.0, texel_size.y * strength)) * 0.15;

	COLOR = color;
}
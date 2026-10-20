
shader_type canvas_item;

uniform float xp_percent : hint_range(0.0, 1.0) = 0.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	if (UV.x > xp_percent) {
		color.a = 0.0;
	}

	COLOR = color;
}

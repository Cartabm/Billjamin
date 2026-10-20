
shader_type canvas_item;

uniform float health_percent : hint_range(0.0, 1.0) = 1.0;

void fragment() {
	vec4 color = texture(TEXTURE, UV);

	if (UV.x > health_percent) {
		color.a = 0.0;
	}

	COLOR = color;
}

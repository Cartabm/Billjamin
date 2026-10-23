
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_opaque;

uniform sampler2D backdrop_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform float fade_start : hint_range(0.0, 1.0) = 0.15;
uniform float fade_end : hint_range(0.0, 1.0) = 0.40;

void fragment() {
    vec4 tex = texture(backdrop_texture, UV);

    // Fade out the bottom of the cylinder.
    float fade = smoothstep(fade_start, fade_end, UV.y);

    ALBEDO = tex.rgb;
    ALPHA = fade;
}

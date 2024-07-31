shader_type canvas_item;
render_mode unshaded;

uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_nearest;

uniform float dist_mult;
uniform vec2 center;

void fragment() {
	vec4 c = textureLod(screen_texture, SCREEN_UV, 0.0);
	if (c.a > 0.0001) {
		c.rgb /= c.a;
	}
	COLOR *= c;
	
	vec2 centered = (UV - center) * 2.0;
	float dist = centered.x * centered.x + centered.y * centered.y;
	dist = sqrt(dist) * dist_mult;
	COLOR.a *= 1.0 - dist;
}

shader_type canvas_item;

const vec2 direction_r = vec2(1, 0);
const vec2 direction_g = vec2(-0.5, 0.86603);
const vec2 direction_b = vec2(0.5, -0.86603);
const float speed = 100.1;
uniform float alpha: hint_range(0.0, 1.0) = 1.0;
uniform sampler2D noise: repeat_enable;
global uniform float FPS_TIME;

vec4 overlay(vec4 base, vec4 blend){
	return base * blend;
}

void fragment()
{
	// image texture
	vec4 base = texture(TEXTURE, UV);
	// noise texture
	float time = mod(FPS_TIME, 100.0);
	vec3 blend = vec3(
		texture(noise, SCREEN_UV + ( direction_r * speed * time)).r ,
		texture(noise, SCREEN_UV + ( direction_g * speed * time)).g,
		texture(noise, SCREEN_UV + ( direction_b * speed * time)).b
		);
	
	COLOR = vec4(vec3(base.r) + blend * base.g, base.a * alpha);
}
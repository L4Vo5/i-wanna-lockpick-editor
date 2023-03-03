shader_type canvas_item;

const vec2 direction_r = vec2(1, 0);
const vec2 direction_g = vec2(-0.5, 0.86603);
const vec2 direction_b = vec2(0.5, -0.86603);
const float speed = 100.1;
uniform sampler2D noise;

vec4 overlay(vec4 base, vec4 blend){
	return base * blend;
}

void fragment()
{
	// image texture
	vec4 base = texture(TEXTURE, UV);
	// noise texture
	vec3 blend = vec3(
		texture(noise, UV + ( direction_r * speed * TIME)).r ,
		texture(noise, UV + ( direction_g * speed * TIME)).g,
		texture(noise, UV + ( direction_b * speed * TIME)).b
		);
	
	COLOR = vec4(vec3(base.r) + blend * base.g, base.a);
}
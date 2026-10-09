shader_type spatial;
render_mode cull_disabled;

uniform vec4 water_color : source_color = vec4(0.08, 0.28, 0.5, 0.72);
uniform float wave_speed : hint_range(0.0, 5.0) = 1.2;
uniform float wave_height : hint_range(0.0, 1.0) = 0.12;

void vertex() {
	float wave = sin(VERTEX.x * 0.55 + TIME * wave_speed) * cos(VERTEX.z * 0.45 + TIME * wave_speed * 0.8);
	VERTEX.y += wave * wave_height;
}

void fragment() {
	ALBEDO = water_color.rgb;
	ALPHA = water_color.a;
	METALNESS = 0.1;
	ROUGHNESS = 0.15;
}

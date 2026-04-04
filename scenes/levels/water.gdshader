shader_type canvas_item;
render_mode blend_mix;   // change to blend_premul_alpha if you prefer nicer transparency

// === NOISE TEXTURE (the one you created) ===
uniform sampler2D noise_texture : filter_linear, repeat_enable;

// === SCREEN TEXTURE (this is the Godot 4.6+ way) ===
uniform sampler2D SCREEN_TEXTURE : hint_screen_texture, filter_linear_mipmap;

// Scrolling speeds for the two noise layers
uniform vec2 scroll_speed_1 = vec2(0.08, 0.04);
uniform vec2 scroll_speed_2 = vec2(-0.05, 0.07);

// Strength of the distortion (wavy refraction)
uniform float distortion_strength : hint_range(0.0, 0.05) = 0.012;

// Water tint + overall transparency
uniform vec4 water_color : source_color = vec4(0.15, 0.55, 0.85, 0.75);

// Optional foam/highlight boost
uniform float highlight_boost : hint_range(0.0, 1.0) = 0.3;

void fragment() {
	// Sample two scrolling noise layers
	vec2 noise_uv1 = UV * 1.5 + TIME * scroll_speed_1;
	vec2 noise_uv2 = UV * 2.0 + TIME * scroll_speed_2;
	
	vec2 noise1 = texture(noise_texture, noise_uv1).rg * 2.0 - 1.0;
	vec2 noise2 = texture(noise_texture, noise_uv2).rg * 2.0 - 1.0;
	
	vec2 combined_noise = (noise1 + noise2) * 0.5;
	
	// Distort the screen coordinates
	vec2 distorted_uv = SCREEN_UV + combined_noise * distortion_strength;
	
	// Grab the pixels behind the water
	vec4 screen = texture(SCREEN_TEXTURE, distorted_uv);
	
	// Apply tint + subtle highlight on the waves
	float highlight = (combined_noise.x + combined_noise.y) * highlight_boost;
	COLOR = screen * water_color + vec4(highlight, highlight, highlight, 0.0);
}
shader_type canvas_item;
render_mode unshaded;  // Usually best for pure overlay fog effects

// Noise texture (use a seamless/cloudy noise texture, repeat enabled)
uniform sampler2D noise_texture : repeat_enable, filter_linear;

// Movement
uniform vec2 speed = vec2(0.015, 0.015);           // Overall drift speed
uniform vec2 detail_speed = vec2(0.04, -0.04);    // Faster secondary layer for turbulence

// Fog look
uniform float density : hint_range(0.0, 1.0) = 0.35;
uniform float softness : hint_range(0.1, 5.0) = 2.5;   // Higher = softer, more gradual fog
uniform vec4 fog_color : source_color = vec4(0.8, 0.85, 0.95, 1.0);  // Tint of the fog

// Extra polish
uniform float contrast : hint_range(0.5, 3.0) = 1.8;   // Makes patches more defined
uniform bool use_detail_layer = true;

void fragment() {
    // Moving UVs for the main fog layer
    vec2 uv1 = UV + speed * TIME;
    
    // Secondary faster layer for organic movement
    vec2 uv2 = UV * 1.8 + detail_speed * TIME;
    
    // Sample noise (two layers if enabled)
    float noise1 = texture(noise_texture, uv1).r;
    float noise2 = use_detail_layer ? texture(noise_texture, uv2).r : 0.0;
    
    // Combine layers (weighted average)
    float noise = mix(noise1, noise2, 0.4);
    
    // Remap noise to a more usable range and apply contrast/softness
    float fog = noise * 2.0 - 1.0;                    // -1 to 1
    fog = pow(abs(fog), 1.0 / softness) * sign(fog); // Softness control
    fog = clamp(fog * contrast, -1.0, 1.0);
    fog = (fog + 1.0) * 0.5;                          // Back to 0-1 range
    
    // Final alpha (multiplies the original sprite/texture alpha)
    float final_alpha = fog * density;
    
    // Apply fog color while preserving original RGB (or you can tint more)
    COLOR.rgb = mix(COLOR.rgb, fog_color.rgb, final_alpha * fog_color.a);
    COLOR.a *= final_alpha;
}
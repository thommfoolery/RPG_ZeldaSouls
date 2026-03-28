shader_type canvas_item;

uniform vec4 flash_color : source_color = vec4(1.0);
uniform float flash_intensity : hint_range(0.0, 1.0) = 0.0;

void fragment() {
    vec4 original = texture(TEXTURE, UV);
    
    // Only apply flash to non-transparent pixels
    if (original.a > 0.01) {
        COLOR = mix(original, flash_color, flash_intensity);
    } else {
        COLOR = original;
    }
}
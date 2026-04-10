shader_type canvas_item;

uniform vec4 silhouette_color : source_color = vec4(0.0, 0.0, 0.0, 0.75);

void fragment()
{
    vec4 tex = texture(TEXTURE, UV);

    if (tex.a < 0.1) {
        discard;
    }

    vec4 screen_pixel = texture(SCREEN_TEXTURE, SCREEN_UV);

    float occluded = step(0.01, screen_pixel.a);

    vec4 result = tex;

    if (occluded > 0.5) {
        result.rgb = silhouette_color.rgb;
        result.a = tex.a * silhouette_color.a;
    }

    COLOR = result;
}
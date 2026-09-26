shader_type canvas_item;
varying vec4 tint;

void vertex() { tint = COLOR; }

void fragment() {
    vec4 pixel = texture(TEXTURE,UV);
    // Solid pixel edges avoid the soft semi-transparent silhouette of generated art.
    pixel.a = step(0.5,pixel.a);
    COLOR = tint * vec4(floor(pixel.rgb*31.0+.5)/31.0,pixel.a);
}

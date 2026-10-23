// Trilobit doll palette shader.  Index sprites store material * 8 + shade in the red channel (0 = empty); the doll's
// palette (8 x 32, one row per material) gives the colour.  Nearest sampling only: an index must never be blended.
shader_type canvas_item;

uniform sampler2D palette : filter_nearest, repeat_disable;
varying vec4 modulate_colour;

void vertex() {
	modulate_colour = COLOR;
}

void fragment() {
	float v = texture(TEXTURE, UV).r * 255.0;
	if (v < 0.5) {
		discard;
	}
	float idx = floor(v + 0.5);
	float shade = mod(idx, 8.0);
	float mat = floor(idx / 8.0);
	vec4 c = texture(palette, vec2((shade + 0.5) / 8.0, (mat + 0.5) / 32.0));
	COLOR = c * modulate_colour;
}

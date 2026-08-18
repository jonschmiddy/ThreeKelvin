shader_type canvas_item;

// Cold universe, warm ship. Drive `heat` from 0..1.7 and the sprite shifts from
// its cold palette toward ember, with emissive bloom past 1.0 (overheating).
// Attach to a Sprite2D and animate the uniform — this replaces the CPU-side
// palette lerp in ShipView once you have real art.

uniform float heat : hint_range(0.0, 1.7) = 0.0;
uniform vec3 warm_tint : source_color = vec3(0.85, 0.42, 0.15);
uniform vec3 glow_tint : source_color = vec3(1.0, 0.82, 0.54);
uniform float dither_strength : hint_range(0.0, 1.0) = 0.35;

// 2x2 ordered dither so gradients stay pixel-art crisp instead of smooth.
float dither2x2(vec2 pos) {
	int x = int(mod(pos.x, 2.0));
	int y = int(mod(pos.y, 2.0));
	int index = x + y * 2;
	if (index == 0) return 0.0;
	if (index == 1) return 0.5;
	if (index == 2) return 0.75;
	return 0.25;
}

void fragment() {
	vec4 tex = texture(TEXTURE, UV);
	float t = clamp(heat * 0.6, 0.0, 1.0);

	// Warm the whole hull as heat climbs.
	vec3 col = mix(tex.rgb, tex.rgb * 0.55 + warm_tint * 0.75, t);

	// Emissive bloom on bright pixels once you pass capacity.
	float over = max(heat - 1.0, 0.0);
	if (over > 0.0) {
		float lum = dot(tex.rgb, vec3(0.299, 0.587, 0.114));
		float d = dither2x2(FRAGCOORD.xy);
		float bloom = step(d, over * dither_strength + lum * 0.4);
		col = mix(col, glow_tint, bloom * clamp(over, 0.0, 1.0));
	}

	COLOR = vec4(col, tex.a);
}

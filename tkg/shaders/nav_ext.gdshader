shader_type canvas_item;

// THE MAP'S CLOUD PAST ITS PICTURE (Jon, Oct 18, cloud:A -- of a system inside
// a gas cloud, the map's picture "reads as a lit rectangle"): the map's own sky
// (`SystemView`'s scene: the cloud, the star's light, the dust), drawn again
// round the picture across the screens' area, keyed onto the field as the
// picture is (`nav_key.gdshader`'s void band), fading out over `fade` px at the
// area's edges and its own. Inside the picture the picture draws it; at the
// picture's soft edge this gives exactly what is missing, so the two add to one
// layer of the same gas: e = k (1 - fp) / (1 - k fp), with fp the picture's own
// edge fade there and k the key.

uniform float lo = 0.046;
uniform float hi = 0.085;
uniform float dark = 0.018;
uniform float dark_w = 0.010;
// the picture (its own soft edge), and where this may draw (viewport px)
uniform vec4 inner = vec4(0.0);
uniform vec4 outer = vec4(0.0, 0.0, 960.0, 540.0);
uniform float fade = 24.0;
// the map's own sky ends short of the screens' right edge (the side panel's
// side): thinned out over this many px to its end there, not cut
uniform float tex_right = 99999.0;
uniform float fade_right = 120.0;

float inside(vec2 p, vec4 r) {
	return min(min(p.x - r.x, p.y - r.y), min(r.x + r.z - p.x, r.y + r.w - p.y));
}

void fragment() {
	vec4 c = COLOR;
	float L = dot(c.rgb, vec3(0.299, 0.587, 0.114));
	float k = max(smoothstep(lo, hi, L), 1.0 - smoothstep(dark - dark_w, dark, L)) * c.a;
	vec2 p = FRAGCOORD.xy;
	float fp = inner.z > 0.0 ? smoothstep(0.0, fade, inside(p, inner)) : 0.0;
	float e = k * (1.0 - fp) / max(1.0 - k * fp, 0.001);
	e *= smoothstep(0.0, fade, inside(p, outer));
	e *= smoothstep(0.0, fade_right, tex_right - p.x);
	COLOR = vec4(c.rgb, clamp(e, 0.0, 1.0));
}

shader_type canvas_item;

// INTERLACE, the spool look Jon picked: rows of the ship slipping a pixel either
// way as the drive charges, like a signal breaking up. "i like interlace, but
// let's make it less strong and the modules should also be affected".
//
// A SHADER, NOT A PASS OVER THE HULL IMAGE, because the modules are not in that
// image: `MountPoints` draws them in its own `_draw()`, scaled by `_mag`. Set on
// the ShipView with its children using the parent's material, one set of
// uniforms moves the hull and everything bolted to it together.
//
// ROWS ARE CANVAS ROWS, so a slipped row is the same row across the hull and a
// module on it. With the project's viewport stretch at 960x540, a canvas unit is
// one game pixel. The shift is one game pixel too, worked out per fragment from
// the derivatives, so it is a pixel on the hull and a pixel on a module drawn at
// 1.25x -- never a fraction, and never scaled.

// The share of rows slipping right now, 0 to 1. Pushed from JumpFx every frame.
uniform float rows = 0.0;
// Which rows: changes a dozen times a second.
uniform float seed = 0.0;

varying vec2 world;
varying vec4 tint;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).xy;
	tint = COLOR;
}

// A hash kept in small, exact numbers. It was the usual fract(sin(x) * 43758.5453),
// and under the Compatibility renderer that ran out of float precision: its
// values bunched up, so 100% still slipped rows while 20% and 10% slipped none at
// all -- measured pixel-identical to no effect, every frame. Row and seed stay
// under a few tens of thousands here, which floats hold exactly.
float pick(float row) {
	float n = mod(row * 37.0 + seed * 101.0, 211.0);
	return fract(n * 0.618034);
}

void fragment() {
	vec2 uv = UV;
	float row = floor(world.y);
	if (rows > 0.0 && pick(row) < rows) {
		float dir = mod(row, 2.0) < 1.0 ? 1.0 : -1.0;
		float per_px = dFdx(UV.x) / max(abs(dFdx(world.x)), 1e-6);
		uv.x -= dir * per_px;
	}
	COLOR = texture(TEXTURE, uv) * tint;
}

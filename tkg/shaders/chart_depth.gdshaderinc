// A GALAXY'S DEPTH AT ITS RIM (SIMPLIFIED; `ChartSky.gal_depth`, `-- galdepth=0|1|2`,
// 0 today). Jon, Oct 19: "let's also explore giving the galaxies some depth. They seem
// like a flat image right now. This is especially evident on the edges" -- a spiral's
// outer edge read as a flat cut-out tilted on the chart.
//
// What was tried before and kept (Oct 11-13): the layers floated AROUND the galaxy
// read flat whatever their height ("still too high up ... like it's a single plane");
// what worked was the galaxy itself as a solid object (the camera, the gas as a lit
// height field standing toward it, the edge dissolving into black). So this builds
// on the disc itself: the disc has a THICKNESS, and the camera sees it.
//   1  thickness at the rim: the disc's material stands above and below the plane,
//      thicker toward the bulge. A ray through a block meets that material wherever
//      it passes it, so past the near rim the lower half of the disc shows as a side
//      wall in shade, past the far rim the top of the far side shows, lit; the height
//      itself is broken into puffs at the edge, so the outline frays into wisps above
//      and below; and a faint thick halo of stars rises over and under the disc.
//   2  1, and parallax: the camera's foot follows the view's centre instead of staying
//      on the core, so as the chart slides the material above and below the plane
//      slides against the plane itself.
// Light, in the disc's own colours, added where the plane's own light has faded (the
// disc's interior keeps its light as approved). Fixed sizes in gu: a zoom only
// magnifies it.
//
// THE INCLUDING SHADER PROVIDES chart_solid (fluffToward, edgeMask, u_solidW, u_phi)
// and u_struct / bakeUV (the disc's own bake).

// the mode (0 off, 1 thickness, 2 and parallax), the view's centre on the plane (gu,
// turned to the view, as `fluffToward` reads the camera's foot), 0
uniform vec4 u_depth = vec4(0.0);

const float DEPTH_H = 0.09;          // the disc's half height at the bulge, gu
const float DEPTH_HALO = 0.012;     // the thick halo of stars' light
const float DEPTH_WALL = 0.12;      // the rim's wall and top's light

// how thick the disc is at plane radius r: thickest toward the bulge, thin at the rim
float depthH(float r) {
	return DEPTH_H * (0.5 + 0.5 * exp(-r / 0.45));
}

// the plane's shift per unit of height toward the camera: the solid look's own, or,
// with parallax, from a camera whose foot is under the view's centre
vec2 depthToward(vec2 p) {
	if (u_depth.x < 1.5 || !u_solid) {
		return fluffToward(p);
	}
	vec2 q = kitRot(u_phi) * p;
	float D = u_solidW.x;
	vec2 cxy = u_depth.yz + vec2(0.0, D * u_solidW.z);
	return kitRot(-u_phi) * ((cxy - q) / (D * u_solidW.y));
}

// the disc's material at plane point q: its own envelope, ridged where its arms are
float depthMat(vec2 q) {
	vec4 S = textureLod(u_struct, bakeUV(q), 3.0);
	return edgeMask(q) * (0.4 + 0.9 * S.r) * exp(-length(q) / 0.85);
}

// the light seen off the plane at the block whose plane point is p; `emHere` how much of
// the plane's own light is left there (its edge's fade), `blk` a block (gu)
vec3 depthLight(vec2 p, float emHere, float blk) {
	if (u_depth.x < 0.5) {
		return vec3(0.0);
	}
	// THE OUTLINE: where the plane's own light has fallen to about a third (`edgeMask`).
	// Outside it, a block may still meet the disc's material off the plane: below it,
	// past the near rim (the side wall, in shade), and above it, past the far rim (the
	// top, lit). Inside it the disc's approved light, lanes and all, is left alone
	// (spread over them, this light filled the lanes and flattened the arms).
	float outside = 1.0 - smoothstep(0.08, 0.22, emHere);
	if (outside <= 0.0) {
		return vec3(0.0);
	}
	vec2 dT = depthToward(p);
	vec3 L = vec3(0.0);
	for (int k = 0; k < 4; k++) {
		float hf = k == 0 ? -1.0 : (k == 1 ? -0.5 : (k == 2 ? 0.5 : 1.0));
		vec2 q0 = p + hf * depthH(length(p)) * dT;
		// (the height broken into puffs, each a cloud of its own: the outline frays
		// above and below into wisps rather than standing as a clean wall)
		float pf = kitFbm2(q0 * 6.0 + vec2(hf * 3.1, 1.7), 3);
		float H = depthH(length(q0)) * (0.45 + 1.2 * smoothstep(-0.25, 0.5, pf));
		vec2 q = p + hf * H * dT;
		// inside the outline there, at that height: the disc
		float inq = smoothstep(0.06, 0.3, edgeMask(q));
		float puff = smoothstep(0.2, 0.45, kitFbm2(q * 8.0 + vec2(5.3, hf), 3));
		// the side wall under the plane in shade, the top over it lit, the middle of the
		// thickness the brightest (it is where the disc's stars are)
		float shade = hf < 0.0 ? 0.55 : 1.25;
		vec4 S = textureLod(u_struct, bakeUV(q), 3.0);
		vec3 col = mix(vec3(1.0, 0.74, 0.48), vec3(0.42, 0.56, 1.0), smoothstep(0.12, 0.55, length(q)));
		L += col * inq * puff * shade * (0.5 + 0.8 * S.r) * exp(-hf * hf * 0.5) * 0.25;
	}
	L *= DEPTH_WALL * outside;
	// a faint thick halo of stars over and under the disc, past the rim
	float hz = smoothstep(1.35, 0.8, length(p)) * outside;
	L += vec3(0.75, 0.8, 1.0) * hz * DEPTH_HALO * (0.5 + 0.8 * smoothstep(0.2, 0.7, kitFbm2(p * 14.0 + 2.3, 2)));
	return L;
}

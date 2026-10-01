shader_type canvas_item;
render_mode unshaded;

// THE FLOOR LAMPS' POOLS, WITH THE SHIPS' SHADOWS IN THEM: the Yard Drones
// page's `bakeShips`, run once whenever the ships are stood. Each floor lamp
// (a row of them per depth, out of the picture above) either reaches a patch of
// floor or a hull is in the way: from the patch, look at the lamp from five
// points across it -- so a shadow's edge is soft -- and see whether the line
// passes through a hull (a slab 45 deep either side of the ships' depth).
// Worked on the page's half grid, one fragment per cell, and written as 16-bit
// fixed point in R and G; `yard_light.gdshader` eases it up to the picture.
//
// THE STANDS THROW NONE. Each stand's lamp shadow fell differently at every
// spot, and Jon: "all of the stands should have the same shadow." They all get
// one picture instead (`YardScene._draw_ships`).

uniform sampler2D mask : filter_nearest, repeat_disable;
uniform float floorx[12];
uniform int nfloor = 11;
uniform vec2 rows[4];
uniform int nrows = 4;
uniform float vx = 383.0;
uniform float hy = 30.0;
uniform float f = 500.0;
uniform float ch = 300.0;
uniform float wallrow = 207.0;
uniform float bayr = 115.0;
uniform float lamph = 330.0;
uniform float zs = 535.714;
uniform float zsf = 0.9333;
uniform vec4 bounds = vec4(0.0);
uniform bool ships = false;
uniform float scale = 2.0;

float z_of(float y) {
	return ch * f / max(0.5, y - hy);
}

float u_of(float x, float y) {
	return (x - vx) * z_of(y) / f;
}

float pool_v(float u0, float z0, float x, float y) {
	if (y < wallrow) {
		return 0.0;
	}
	float du = u_of(x, y) - u0;
	float dz = z_of(y) - z0;
	float d = sqrt(du * du + dz * dz) / bayr;
	if (d >= 1.0) {
		return 0.0;
	}
	float e = 1.0 - d;
	return e * e * (3.0 - 2.0 * e);
}

bool hit_at(float up, float zp, float ul, float zl) {
	for (int j = -1; j <= 1; j++) {
		float zk = zs + float(j) * 45.0;
		float s = (zk - zp) / (zl - zp);
		if (!(s > 0.0 && s < 1.0)) {
			continue;
		}
		float u = up + s * (ul - up);
		float h = s * lamph;
		int xm = int(floor(vx + u * zsf + 0.5));
		int ym = int(floor(hy + (ch - h) * zsf + 0.5));
		if (xm >= 0 && xm < 766 && ym >= 0 && ym < 482) {
			if (texelFetch(mask, ivec2(xm, ym), 0).r > 0.5) {
				return true;
			}
		}
	}
	return false;
}

void fragment() {
	vec2 cell = floor(UV * vec2(384.0, 242.0));
	float x = cell.x * 2.0;
	float y = cell.y * 2.0;
	float acc = 0.0;
	if (y >= wallrow) {
		float zp = z_of(y);
		float up = u_of(x, y);
		float zw = z_of(wallrow);
		for (int i = 0; i < 12; i++) {
			if (i >= nfloor) {
				break;
			}
			float ul = (floorx[i] - vx) * zw / f;
			for (int r = 0; r < 4; r++) {
				if (r >= nrows) {
					break;
				}
				float zl = rows[r].x;
				float v = pool_v(ul, zl, x, y);
				if (v <= 0.0) {
					continue;
				}
				float vis = 1.0;
				if (ships) {
					float s = (zs - zp) / (zl - zp);
					if (s > -0.3 && s < 1.3) {
						float um = up + s * (ul - up);
						float hm = s * lamph;
						float pad = 85.0;
						if (um > bounds.x - pad && um < bounds.y + pad && hm > bounds.z - pad && hm < bounds.w + pad) {
							float hits = 0.0;
							if (hit_at(up, zp, ul, zl)) { hits += 1.0; }
							if (hit_at(up, zp, ul + 40.0, zl)) { hits += 1.0; }
							if (hit_at(up, zp, ul - 40.0, zl)) { hits += 1.0; }
							if (hit_at(up, zp, ul, zl + 40.0)) { hits += 1.0; }
							if (hit_at(up, zp, ul, zl - 40.0)) { hits += 1.0; }
							vis = 1.0 - hits / 5.0;
						}
					}
				}
				acc += rows[r].y * v * vis;
			}
		}
	}
	float q = floor(clamp(acc / scale, 0.0, 1.0) * 65535.0 + 0.5);
	float hi = floor(q / 256.0);
	COLOR = vec4(hi / 255.0, (q - hi * 256.0) / 255.0, 0.0, 1.0);
}

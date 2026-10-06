shader_type canvas_item;
render_mode unshaded, blend_disabled;

// The radiant star chart's place pass at GRAPHICS LOW (`chart_r_place.gdshaderinc`):
// no billow volume (one lit sheet over the arms), the clouds in 6 steps, one
// flow phase, fewer slab steps (`ChartRadiant`).
#define LOW 1
#include "res://shaders/chart_r_place.gdshaderinc"

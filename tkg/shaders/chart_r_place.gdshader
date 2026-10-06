shader_type canvas_item;
render_mode unshaded, blend_disabled;

// The radiant star chart's place pass, in full (`chart_r_place.gdshaderinc`).
#define LOW 0
#include "res://shaders/chart_r_place.gdshaderinc"

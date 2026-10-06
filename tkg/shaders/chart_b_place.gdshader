shader_type canvas_item;
render_mode unshaded, blend_disabled;

// The painted star chart's place pass, in full (`chart_b_place.gdshaderinc`).
#define LOW 0
#include "res://shaders/chart_b_place.gdshaderinc"

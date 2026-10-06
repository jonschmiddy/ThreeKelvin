shader_type canvas_item;
render_mode unshaded, blend_disabled;

// The simplified star chart's place pass, in full (`chart_c_place.gdshaderinc`).
#define LOW 0
#include "res://shaders/chart_c_place.gdshaderinc"

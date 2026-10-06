shader_type canvas_item;
render_mode unshaded, blend_disabled;

// The painted star chart's place pass at GRAPHICS LOW (`chart_b_place.gdshaderinc`):
// no billows, one flow phase, one texture octave.
#define LOW 1
#include "res://shaders/chart_b_place.gdshaderinc"

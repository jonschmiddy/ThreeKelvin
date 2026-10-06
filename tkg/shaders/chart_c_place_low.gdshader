shader_type canvas_item;
render_mode unshaded, blend_disabled;

// The simplified star chart's place pass at GRAPHICS LOW (`chart_c_place.gdshaderinc`):
// no billow march, no wisps or under-sheet, one flow phase, no fine octaves.
#define LOW 1
#include "res://shaders/chart_c_place.gdshaderinc"

shader_type canvas_item;
// A vertical, WORLD-ANCHORED colour wash for the dungeon tilemap (floor + walls): cool near the
// bottom (the entrance), shifting WARM toward the top (the higher, tougher nodes → the boss). It's
// keyed to world position, not screen, so a tile keeps its colour as the camera scrolls.
//
// dungeon_view.gd sets y_top / y_bottom to the map's world-Y extent (smaller y = higher on screen).
// Overlaid at `strength` so the tiles' own texture/shading still reads through.

uniform float y_top = 0.0;        // world Y of the topmost tiles
uniform float y_bottom = 1000.0;  // world Y of the bottommost tiles
uniform vec4 cool : source_color = vec4(0.22, 0.62, 0.95, 1.0);   // bottom
uniform vec4 warm : source_color = vec4(1.00, 0.48, 0.26, 1.0);   // top
uniform float strength : hint_range(0.0, 1.0) = 0.42;

varying float v_world_y;

void vertex() {
	v_world_y = (MODEL_MATRIX * vec4(VERTEX, 0.0, 1.0)).y;
}

void fragment() {
	float t = clamp((v_world_y - y_top) / max(y_bottom - y_top, 0.001), 0.0, 1.0);
	vec3 tint = mix(warm.rgb, cool.rgb, t);   // t = 0 at top (warm) … 1 at bottom (cool)
	// Blend the tile TOWARD the gradient colour (not a multiply): a multiply just desaturates blue
	// walls to grey at the warm end, whereas blending gives them an actual warm cast. Keep the
	// tile's own luminance so its texture/shading still reads through.
	float lum = dot(COLOR.rgb, vec3(0.299, 0.587, 0.114));
	vec3 washed = mix(COLOR.rgb, tint * (0.6 + 0.8 * lum), strength);
	COLOR.rgb = washed;
}

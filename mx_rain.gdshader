shader_type canvas_item;
// Matrix rain with a camera flying through it (Godot 4.x)
// Put this on a full-screen ColorRect (Layout -> Full Rect) and assign mx_atlas.png to "atlas".
// Atlas: 512x512, 8x8 glyphs (64 glyphs), read row by row, left to right.

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;

group_uniforms atlas_settings;
uniform bool glyph_is_dark_on_light = false;   // true if atlas has black glyphs on white
uniform bool mirror_glyphs = true;             // movie-style mirrored katakana
uniform float glyph_size : hint_range(0.3, 1.0) = 0.85; // glyph fill inside its cell

group_uniforms camera;
uniform int layers : hint_range(1, 16) = 12;           // depth layers
uniform float fly_speed = 0.10;                        // camera speed (layer cycles / sec)
uniform float near_depth = 0.5;
uniform float far_depth = 7.0;
uniform float sway = 3.0;                              // lateral camera drift (in cells)
uniform float roll = 0.08;                             // slow camera roll (radians)

group_uniforms rain;
uniform float grid_scale = 14.0;                       // rows visible at depth 1
uniform float fall_speed = 7.0;                        // cells / second
uniform float trail_length = 16.0;
uniform float column_density : hint_range(0.0, 1.0) = 0.7;
uniform float glyph_change_rate = 4.0;

group_uniforms look;
uniform vec4 rain_color : source_color = vec4(0.0, 0.9, 0.25, 1.0);
uniform vec4 head_color : source_color = vec4(0.8, 1.0, 0.85, 1.0);
uniform float brightness = 1.6;
uniform float vignette = 0.6;

float hash11(float p) {
	p = fract(p * 0.1031);
	p *= p + 33.33;
	p *= p + p;
	return fract(p);
}

float hash21(vec2 p) {
	vec3 p3 = fract(vec3(p.xyx) * 0.1031);
	p3 += dot(p3, p3.yzx + 33.33);
	return fract((p3.x + p3.y) * p3.z);
}

void fragment() {
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 p = (UV - 0.5) * vec2(aspect, 1.0);

	// slow camera roll
	float a = sin(TIME * 0.17) * roll;
	p = mat2(vec2(cos(a), -sin(a)), vec2(sin(a), cos(a))) * p;

	// lateral camera drift in world space
	vec2 cam = vec2(sin(TIME * 0.31), cos(TIME * 0.23)) * sway;

	vec3 col = vec3(0.0);

	for (int i = 0; i < layers; i++) {
		float t = float(i) / float(layers) + TIME * fly_speed;
		float cycle = floor(t);
		float z = fract(t);                    // 0 = far, 1 = near
		float id = cycle * float(layers) + float(i);
		float seed = hash11(id * 0.731) * 100.0;

		float depth = mix(far_depth, near_depth, z);

		// world position on this layer's plane
		vec2 w = p * depth * grid_scale + cam + vec2(seed * 3.7, seed * 1.3);
		vec2 cell = floor(w);
		vec2 f = fract(w);

		// per-column randoms
		float r1 = hash21(vec2(cell.x, seed));
		if (r1 > column_density) continue;
		float r2 = hash21(vec2(cell.x + 7.1, seed));
		float r3 = hash21(vec2(cell.x + 13.7, seed));
		float r4 = hash21(vec2(cell.x + 21.3, seed));

		float spd = fall_speed * mix(0.5, 1.3, r2);
		float len = trail_length * mix(0.6, 1.6, r3);
		float period = len * mix(1.5, 3.0, r4);

		// distance of this cell behind the falling head (head moves down = +y)
		float head = TIME * spd + r4 * period * 10.0;
		float dist = mod(head - cell.y, period);
		if (dist > len) continue;

		float trail = pow(1.0 - dist / len, 1.8);
		float is_head = step(dist, 1.0);

		// glyph choice (changes over time, heads flicker faster)
		float rate = glyph_change_rate * mix(0.2, 1.0, hash21(cell + seed)) * (1.0 + is_head * 3.0);
		float tick = floor(TIME * rate);
		float rnd = hash21(cell * 1.37 + vec2(tick * 1.7, seed + tick * 0.3));
		int idx = min(int(rnd * 64.0), 63);

		// position inside glyph cell
		vec2 gp = (f - 0.5) / glyph_size + 0.5;
		if (gp.x < 0.0 || gp.x > 1.0 || gp.y < 0.0 || gp.y > 1.0) continue;
		if (mirror_glyphs) gp.x = 1.0 - gp.x;

		vec2 auv = (vec2(float(idx % 8), float(idx / 8)) + gp) / 8.0;
		vec4 g = texture(atlas, auv);
		float m = max(max(g.r, g.g), g.b);
		if (glyph_is_dark_on_light) m = 1.0 - m;
		m *= g.a;

		// fade layers in/out as they wrap around, dim far ones
		float fade = smoothstep(0.0, 0.2, z) * (1.0 - smoothstep(0.75, 1.0, z));
		float dim = mix(0.35, 1.0, z);

		vec3 c = mix(rain_color.rgb * trail, head_color.rgb, is_head);
		col += c * m * fade * dim * brightness;
	}

	// soft tonemap + vignette
	col = 1.0 - exp(-col);
	float v = length(UV - 0.5);
	col *= 1.0 - vignette * smoothstep(0.3, 0.85, v);

	COLOR = vec4(col, 1.0);
}

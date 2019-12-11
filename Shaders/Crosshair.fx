#include "ReShade.fxh"

struct Rect {
	float2 position;
	float2 size;
	float2 pivot;
};

static const float cPi = 3.14159;
static const float cDegreesToRadians = cPi / 180;
static const float cRadiansToDegrees = 180 / cPi;
static const float cQuarterPi = cPi * 0.25;

uniform float uScale <
	ui_label = "Scale";
	ui_tooltip =
		"Defines the pixel scale of the crosshair.\n"
		"With 1.0 each cross is a pixel wide.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 1.0;
	ui_max = 10.0;
> = 1.0;

uniform float uSeparation <
	ui_label = "Separation";
	ui_tooltip =
		"Amount of pixels between each cross.\n"
		"\nDefault: 1";
	ui_type = "slider";
	ui_min = 0;
	ui_max = 200;
	ui_step = 1;
> = 1;

uniform float uSize <
	ui_label = "Size";
	ui_tooltip =
		"Size of each cross.\n"
		"\nDefault: 3";
	ui_type = "slider";
	ui_min = 0;
	ui_max = 100;
	ui_step = 1;
> = 3;

uniform float uThickness <
	ui_label = "Thickness";
	ui_tooltip =
		"Thickness of each cross.\n"
		"\nDefault: 1";
	ui_type = "slider";
	ui_min = 0;
	ui_max = 10;
	ui_step = 1;
> = 1;

uniform float uRotation <
	ui_label = "Rotation";
	ui_tooltip =
		"Rotation of the crosshair.\n"
		"-1.0: -45ª\n"
		"0.0: 0º\n"
		"1.0: 45º\n"
		"\nDefault: 0.0";
	ui_type = "slider";
	ui_min = -1.0;
	ui_max = 1.0;
> = 0.0;

uniform float uCircle <
	ui_label = "Circle";
	ui_tooltip =
		"Create a circle around the crosshair.\n"
		"\nDefault: 0";
	ui_type = "slider";
	ui_min = 0;
	ui_max = 200;
	ui_step = 1;
> = 0;

uniform float uCircleThickness <
	ui_label = "Circle Thickness";
	ui_tooltip =
		"Thickness of the circle around the crosshair.\n"
		"\nDefault: 2";
	ui_type = "slider";
	ui_min = 0;
	ui_max = 10;
	ui_step = 1;
> = 2;

uniform float uBorderSize <
	ui_label = "Border Size";
	ui_tooltip =
		"Size of the crosshair's border.\n"
		"Set to 0 to disable it.\n"
		"\nDefault: 2";
	ui_type = "slider";
	ui_min = 0;
	ui_max = 6;
	ui_step = 1;
> = 2;

uniform float2 uPosition <
	ui_label = "Position";
	ui_tooltip =
		"Position of the crosshair on the screen.\n"
		"First value represents Left<->Right.\n"
		"Second value represents Bottom<->Top.\n"
		"\nDefault: 0.5 0.5";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = float2(0.5, 0.5);

uniform float2 uOffset <
	ui_label = "Offset";
	ui_tooltip =
		"Pixel-per-pixel offset to the position.\n"
		"Useful for making small corrections to the position.\n"
		"\nDefault: 0.0 0.0";
	ui_type = "drag";
	ui_min = -20;
	ui_max = 20;
	ui_step = 0.01;
> = float2(0.0, 0.0);

uniform float4 uColor <
	ui_label = "Color";
	ui_tooltip =
		"Color of the crosshair.\n"
		"\nDefault: 0.0 1.0 0.0 1.0";
	ui_type = "color";
> = float4(0.0, 1.0, 0.0, 1.0);

uniform float4 uBorderColor <
	ui_label = "Border Color";
	ui_tooltip =
		"Color of the crosshair's border.\n"
		"\nDefault: 0.0 0.0 0.0 1.0";
	ui_type = "color";
> = float4(0.0, 0.0, 0.0, 1.0);

uniform bool uInvertColor <
	ui_label = "Use Color Inversion";
	ui_tooltip =
		"If enabled the crosshair will be colored the inverse of the image "
		"color underneath it (but keeping the border color).\n"
		"\nDefault: Off";
> = false;

uniform bool uShowTop <
	ui_label = "Show Top Cross";
	ui_tooltip = "Default: On";
	ui_category = "Shape";
> = true;

uniform bool uShowBottom <
	ui_label = "Show Bottom Cross";
	ui_tooltip = "Default: On";
	ui_category = "Shape";
> = true;

uniform bool uShowLeft <
	ui_label = "Show Left Cross";
	ui_tooltip = "Default: On";
	ui_category = "Shape";
> = true;

uniform bool uShowRight <
	ui_label = "Show Right Cross";
	ui_tooltip = "Default: On";
	ui_category = "Shape";
> = true;

uniform float2 uDepthRange <
	ui_label = "Depth Range";
	ui_tooltip =
		"Determines the range of depth that affects the crosshair.\n"
		"Values outside this range will be clamped.\n"
		"\nDefault: 0.0 1.0";
	ui_category = "Depth";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = float2(0.0, 1.0);

uniform float uDepthFarSeparation <
	ui_label = "Far Separation";
	ui_tooltip =
		"Amount of separation for far objects.\n"
		"You can disable this by setting it lower or equal to the normal "
		"separation.\n"
		"\nDefault: 1";
	ui_category = "Depth";
	ui_type = "slider";
	ui_min = 1;
	ui_max = 200;
	ui_step = 1;
> = 1;

uniform float uDepthFarCircle <
	ui_label = "Far Circle";
	ui_tooltip =
		"Size of the circle for far objects.\n"
		"You can disable this by setting it to lower or equal to the normal "
		"circle.\n"
		"\nDefault: 1";
	ui_category = "Depth";
	ui_type = "slider";
	ui_min = 0;
	ui_max = 200;
	ui_step = 1;
> = 0;

uniform float2 uDepthColorRange <
	ui_label = "Color Range";
	ui_tooltip =
		"Range for the depth-based colors.\n"
		"First value: maximum distance for the near color.\n"
		"Second value: minimum distance for the far color.\n"
		"You can disable this by setting both values to 0.0.\n"
		"\nDefault: 0.0 0.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = float2(0.0, 0.0);

uniform float4 uDepthNearColor <
	ui_label = "Near Color";
	ui_tooltip =
		"Color of the crosshair when pointing at near objects.\n"
		"\nDefault: 255 255 255 255";
	ui_type = "color";
> = float4(1.0, 0.0, 0.0, 1.0);

uniform float4 uDepthFarColor <
	ui_label = "Far Color";
	ui_tooltip =
		"Color of the crosshair when pointing at far objects.\n"
		"\nDefault: 255 255 255 255";
	ui_type = "color";
> = float4(1.0, 1.0, 0.0, 1.0);

uniform float uRightClickSeparation <
	ui_label = "Right Click Separation";
	ui_tooltip =
		"Separation applied while the right mouse button is held.\n"
		"You can disable this by setting it to greater or equal to the normal "
		"separation.\n"
		"\nDefault: 0";
	ui_type = "slider";
	ui_min = 0;
	ui_max = 200;
	ui_step = 1;
> = 0;

uniform bool uRightClick <source = "mousebutton"; keycode = 1; mode = "";>;

float2 scale_uv(float2 uv, float2 scale, float2 origin) {
	return (uv - origin) * scale + origin;
}

float2 rotate_uv(float2 uv, float angle_radians, float2 origin) {
	float s, c;
	sincos(angle_radians, s, c);

	uv -= origin;
	return float2(
		uv.x * c - uv.y * s,
		uv.x * s + uv.y * c
	) + origin;
}

float2 apply_pivot(Rect rect) {
	return rect.position - rect.size * rect.pivot;
}

float inside(float2 uv, Rect rect, float margin) {
	float2 pos = apply_pivot(rect);

	return
		step(pos.x - margin, uv.x) *
		step(uv.x, pos.x + rect.size.x + margin) *
		step(pos.y - margin, uv.y) *
		step(uv.y, pos.y + rect.size.y + margin);
}

void draw_line(
	inout float crosshair,
	inout float border,
	float2 uv,
	float2 pos,
	float sep,
	float2 size,
	float2 pivot
) {
	pos += sep - sep * 2.0 * pivot;
	Rect r;
	r.position = pos;
	r.size = size;
	r.pivot = pivot;

	crosshair += inside(uv, r, 0.0);
	border += inside(uv, r, uBorderSize);
}

void draw_circle(
	inout float crosshair,
	inout float border,
	float2 uv,
	float2 pos,
	float radius
) {
	float dist = distance(pos, uv);
	
	crosshair +=
		step(radius, dist) *
		step(dist, radius + uCircleThickness);
	border +=
		step(radius - uBorderSize, dist) *
		step(dist, radius + uCircleThickness + uBorderSize) *
		step(1.0, uCircle + uCircleThickness);
}

float3 inverse(float3 color) {
	return 1.0 - lerp(0.5, color, 2.0);
}

float4 PS_Crosshair(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
	float3 color = tex2D(ReShade::BackBuffer, uv).rgb;
	float2 coord = scale_uv(uv, 1.0 / uScale, 0.5) * ReShade::ScreenSize;
	
	float2 center =
		uPosition *
		ReShade::ScreenSize +
		float2(-uOffset.x, uOffset.y);
	
	coord = rotate_uv(coord, uRotation * -cQuarterPi, center);
	//coord += 0.5;

	float depth = ReShade::GetLinearizedDepth(center * ReShade::PixelSize);
	depth = clamp(depth, uDepthRange.x, uDepthRange.y);
	depth -= uDepthRange.x;
	depth *= 1.0 + (uDepthRange.y - uDepthRange.x);
	
	float2 size = float2(uSize, uThickness);
	float sep = lerp(uSeparation, max(uSeparation, uDepthFarSeparation), depth);
	sep = uRightClick ? min(uRightClickSeparation, sep) : sep;
	
	float border = 0.0;
	float crosshair = 0.0;

	// Left.
	if (uShowLeft)
		draw_line(
			crosshair, border, coord, center, sep, size, float2(1.0, 0.5)
		);

	// Right.
	if (uShowRight)
		draw_line(
			crosshair, border, coord, center, sep, size, float2(0.0, 0.5)
		);
		
	// Top.
	if (uShowTop)
		draw_line(
			crosshair, border, coord, center, sep, size.yx, float2(0.5, 1.0)
		);

	// Bottom.
	if (uShowBottom)
		draw_line(
			crosshair, border, coord, center, sep, size.yx, float2(0.5, 0.0)
		);
	
	// Circle.
	float circle = lerp(uCircle, max(uDepthFarCircle, uCircle), depth);
	draw_circle(crosshair, border, coord, center, circle);

	border = min(border, 1.0);
	crosshair = min(crosshair, 1.0);

	float3 backup_color = color.rgb;

	if (uInvertColor) {
		color.rgb = lerp(color.rgb, inverse(backup_color), crosshair);
	} else {
		float4 ch_color = uColor;
		
		depth = smoothstep(uDepthRange.x, uDepthRange.y, depth);

		ch_color = lerp(uDepthNearColor, ch_color, smoothstep(0.0, uDepthColorRange.x, depth));
		ch_color = lerp(ch_color, uDepthFarColor, smoothstep(uDepthColorRange.y, 1.0, depth));

		color.rgb = lerp(color.rgb, uBorderColor.rgb, border * uBorderColor.a);
		color.rgb = lerp(color.rgb, ch_color.rgb, crosshair * ch_color.a);
	}
	
	return float4(color, 1.0);
}

technique Crosshair {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_Crosshair;
	}
}
#include "ReShade.fxh"

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
	ui_max = 100;
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
	ui_max = 100;
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
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = float2(0.0, 1.0);

uniform float uSeparationDepth <
	ui_label = "Separation Depth Scale";
	ui_tooltip =
		"How larger the separation becomes with depth changes.\n"
		"A value of 1.0 disables this.\n"
		"\nDefault: 1.0";
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = 10.0;
	ui_step = 0.01;
> = 1.0;

uniform float uTimer <source = "timer";>;

float2 scale_uv(float2 uv, float2 scale, float2 origin) {
	return (uv - origin) * scale + origin;
}
float2 scale_uv(float2 uv, float2 scale) {
	return scale_uv(uv, scale, 0.5);
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
float2 rotate_uv(float2 uv, float angle_radians) {
	return rotate_uv(uv, angle_radians, 0.5);
}

// Returns 1.0 if the point is inside the rect, 0.0 otherwise.
// The rect's pivot/origin is determined as:
//   .x => Left<->Right
//   .y => Top<->Bottom
float inside(float2 uv, float4 rect, float2 pivot) {
	rect.xy -= (rect.zw - rect.xy) * pivot;

	return
		step(rect.x, uv.x) *
		step(uv.x, rect.x + rect.z) *
		step(rect.y, uv.y) *
		step(uv.y, rect.y + rect.w);
}
float inside(float2 uv, float4 rect) {
	return inside(uv, rect, 0.0);
}

float4 PS_Crosshair(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
	float3 color = tex2D(ReShade::BackBuffer, uv).rgb;
	float2 coord = scale_uv(uv, 1.0 / uScale, 0.5) * ReShade::ScreenSize;
	
	float2 center =
		uPosition *
		ReShade::ScreenSize +
		float2(-uOffset.x, uOffset.y) * 0.5;
	
	coord = rotate_uv(coord, uRotation * -cQuarterPi, center);
	//coord += 0.5;

	float depth = ReShade::GetLinearizedDepth(center * ReShade::PixelSize);
	depth = clamp(depth, uDepthRange.x, uDepthRange.y);
	depth -= uDepthRange.x;
	depth /= uDepthRange.y - uDepthRange.x;
	
	float sep = uSeparation * 0.5;
	sep *= lerp(1.0, uSeparationDepth, depth);

	float size = uSize * 0.5;
	float thick = uThickness * 0.5;
	float start, end, crosshair = 0;

	// TODO: Replace manual positioning with rects.

	// Left.
	if (uShowLeft) {
		/*
		crosshair += inside(
			coord - center,
			float4(-sep, 0.0, uSize, uThickness),
			float2(1.0, 0.5)
		);
		*/

		start = center.x - sep;
		end = start - size;
		crosshair +=
			step(coord.x, start) *
			step(end, coord.x) *
			step(center.y - thick, coord.y) *
			step(coord.y, center.y + thick);
	}

	
	// Right.
	if (uShowRight) {
		/*
		crosshair += inside(
			coord - center,
			float4(sep, 0.0, uSize, uThickness),
			float2(0.0, 0.5)
		);
		*/

		start = center.x + sep;
		end = start + size;
		crosshair +=
			step(start, coord.x) *
			step(coord.x, end) *
			step(center.y - thick, coord.y) *
			step(coord.y, center.y + thick);
	}
	
	// Top.
	if (uShowTop) {
		/*
		crosshair += inside(
			coord - center + float2(0.0, sep),
			float4(0.0, 0.0, uThickness, uSize),
			float2(0.5, 0.0)
		);
		*/

		start = center.y - sep;
		end = start - size;
		crosshair +=
			step(coord.y, start) *
			step(end, coord.y) *
			step(center.x - thick, coord.x) *
			step(coord.x, center.x + thick);
	}

	// Bottom.
	if (uShowBottom) {
		start = center.y + sep;
		end = start + size;
		crosshair +=
			step(start, coord.y) *
			step(coord.y, end) *
			step(center.x - thick, coord.x) *
			step(coord.x, center.x + thick);
	}
	
	// Circle.
	float circle = uCircle * 0.5;
	float circle_thick = uCircleThickness * 0.5;
	float circle_dist = distance(center, coord);
	crosshair +=
		step(circle, circle_dist) *
		step(circle_dist, circle + circle_thick);

	color = lerp(color, uColor.rgb, min(crosshair, 1.0) * uColor.a);
	return float4(color, 1.0);
}

technique Crosshair {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_Crosshair;
	}
}
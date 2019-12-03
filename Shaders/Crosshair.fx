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
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 100.0;
	ui_step = 1.0;
> = 1.0;

uniform float uSize <
	ui_label = "Size";
	ui_tooltip =
		"Size of each cross.\n"
		"\nDefault: 3.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 100.0;
	ui_step = 1.0;
> = 3.0;

uniform float uThickness <
	ui_label = "Thickness";
	ui_tooltip =
		"Thickness of each cross.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 1.0;
> = 1.0;

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
		"\nDefault: 0.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 100.0;
	ui_step = 1.0;
> = 0.0;

uniform float uCircleThickness <
	ui_label = "Circle Thickness";
	ui_tooltip =
		"Thickness of the circle around the crosshair.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 1.0;
> = 0.0;

uniform float2 uCenter <
	ui_label = "Center";
	ui_tooltip =
		"Position of the crosshair on the screen.\n"
		"\nDefault: 0.5 0.5";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = float2(0.5, 0.5);

uniform float4 uColor <
	ui_label = "Color";
	ui_tooltip =
		"Color of the crosshair.\n"
		"\nDefault: 0.0 1.0 0.0 1.0";
	ui_type = "color";
> = float4(0.0, 1.0, 0.0, 1.0);

uniform int uShape <
	ui_label = "Shape";
	ui_tooltip =
		"Crosshair shape.\n"
		"\nDefault: Normal";
	ui_type = "combo";
	ui_items = "Normal\0T\0Horizontal\0Vertical\0";
> = 0;

float2 scale_uv(float2 uv, float2 scale, float2 origin) {
	return (origin - uv) * scale + origin;
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

float4 PS_Crosshair(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
	float3 color = tex2D(ReShade::BackBuffer, uv).rgb;
	float2 coord = scale_uv(uv, 1.0 / uScale, 0.5) * ReShade::ScreenSize;
	float2 center = uCenter * ReShade::ScreenSize;
	coord = rotate_uv(coord, uRotation * -cQuarterPi, center);
	//coord += 0.5;
	
	float sep = uSeparation * 0.5;
	float size = uSize * 0.5;
	float thick = uThickness * 0.5;
	float start, end, crosshair = 0;

	// Horizontal.
	if (uShape != 3) {
		// Left.
		start = center.x + sep;
		end = start + size;
		crosshair +=
			step(start, coord.x) *
			step(coord.x, end) *
			step(center.y - thick, coord.y) *
			step(coord.y, center.y + thick);
		
		// Right.
		start = center.x - sep;
		end = start - size;
		crosshair +=
			step(coord.x, start) *
			step(end, coord.x) *
			step(center.y - thick, coord.y) *
			step(coord.y, center.y + thick);
	}
	
	// Vertical
	if (uShape != 2) {
		// Top.
		if (uShape != 1) {
			start = center.y + sep;
			end = start + size;
			crosshair +=
				step(start, coord.y) *
				step(coord.y, end) *
				step(center.x - thick, coord.x) *
				step(coord.x, center.x + thick);
		}
		
		// Bottom.
		start = center.y - sep;
		end = start - size;
		crosshair +=
			step(coord.y, start) *
			step(end, coord.y) *
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

	color = lerp(color, uColor.rgb, crosshair * uColor.a);
	return float4(color, 1.0);
}

technique Crosshair {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_Crosshair;
	}
}
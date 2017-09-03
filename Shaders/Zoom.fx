#include "ReShade.fxh"

#ifndef ZOOM_KEY
#define ZOOM_KEY 0x12
#endif

#ifndef ZOOM_TOGGLE
#define ZOOM_TOGGLE false
#endif

uniform float fZoom <
	ui_label = "Zoom Scale";
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = 100.0;
	ui_step = 0.1;
> = 10.0;

uniform float2 f2Center <
	ui_label = "Center";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = float2(0.5, 0.5);

uniform bool bFollowMouse <
	ui_label = "Follow Mouse (may not be accurate)";
> = false;

uniform float2 f2Mouse <source="mousepoint";>;

#ifdef ZOOM_MOUSEBUTTON
uniform bool bZoomKey <source="mousebutton"; keycode=ZOOM_MOUSEBUTTON; toggle=ZOOM_TOGGLE;>;
#else
uniform bool bZoomKey <source="key"; keycode=ZOOM_KEY; toggle=ZOOM_TOGGLE;>;
#endif

float2 scale_uv(float2 uv, float2 scale, float2 center) {
	return (uv - center) * scale + center;
}

float2 scale_uv(float2 uv, float2 scale) {
	return scale_uv(uv, scale, 0.5);
}

float4 PS_Zoom(
	float4 pos : SV_POSITION, 
	float2 uv : TEXCOORD
) : SV_TARGET {
	float2 mouse_pos = clamp(f2Mouse, 0.0, ReShade::ScreenSize) * ReShade::PixelSize;

	float2 uv_zoom = scale_uv(
		uv, 
		bZoomKey ? (1.0 / fZoom) : 1.0, 
		bFollowMouse ? mouse_pos : f2Center
	);

	float3 col = tex2D(ReShade::BackBuffer, uv_zoom).rgb;

	return float4(col, 1.0);
}

technique Zoom {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_Zoom;
	}
}

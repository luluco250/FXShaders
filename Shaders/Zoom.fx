#include "ReShade.fxh"
#include "KeyCodes.fxh"

#ifndef ZOOM_KEY
#define ZOOM_KEY KEY_ALT
#endif

#ifndef ZOOM_TOGGLE
#define ZOOM_TOGGLE false
#endif

#ifndef ZOOM_FILTER
#define ZOOM_FILTER LINEAR
#endif

uniform float fZoom <
	ui_label   = "Zoom Scale";
	ui_tooltip = "How much zoom to apply to the image.\n"
	             "Fractional values zoom out.\n"
				 "\nDefault: 10.0";
	ui_type    = "drag";
	ui_min     = 0.01;
	ui_max     = 100.0;
	ui_step    = 0.01;
> = 10.0;

uniform float2 f2Center <
	ui_label   = "Center";
	ui_tooltip = "Where on the screen to zoom into.\n"
	             "Coordinates are in the 0.0<->1.0 range.\n"
				 "(0.5, 0.5) is the middle of the screen.\n"
				 "\nDefault: (0.5, 0.5)";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = float2(0.5, 0.5);

uniform bool bFollowMouse <
	ui_label   = "Follow Mouse";
	ui_tooltip = "May not be accurate.\n"
	             "\nDefault: Off";
> = false;

uniform float2 f2Mouse <source = "mousepoint";>;

uniform bool bZoomKey <
	#ifdef ZOOM_MOUSE_BUTTON
	source  = "mousebutton";
	keycode = ZOOM_MOUSE_BUTTON;
	#else
	source  = "key";
	keycode = ZOOM_KEY;
	#endif
	toggle  = ZOOM_TOGGLE;
>;

sampler2D sBackBuffer {
	Texture   = ReShade::BackBufferTex;
	MinFilter = ZOOM_FILTER;
	MagFilter = ZOOM_FILTER;
	MipFilter = ZOOM_FILTER;
	AddressU  = BORDER;
	AddressV  = BORDER;
};

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

	float3 color = tex2D(sBackBuffer, uv_zoom).rgb;
	return float4(color, 1.0);
}

technique Zoom {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_Zoom;
	}
}

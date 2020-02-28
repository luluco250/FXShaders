//#region Preprocessor

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

// Alt key.
#ifndef ZOOM_HOTKEY
#define ZOOM_HOTKEY 0x12
#endif

#ifndef ZOOM_USE_MOUSE_BUTTON
#define ZOOM_USE_MOUSE_BUTTON 0
#endif

#ifndef ZOOM_MOUSE_BUTTON
#define ZOOM_MOUSE_BUTTON 1
#endif

#ifndef ZOOM_TOGGLE
#define ZOOM_TOGGLE 0
#endif

#ifndef ZOOM_REVERSE
#define ZOOM_REVERSE 0
#endif

#ifndef ZOOM_ALWAYS_ZOOM
#define ZOOM_ALWAYS_ZOOM 0
#endif

#ifndef ZOOM_USE_LINEAR_FILTERING
#define ZOOM_USE_LINEAR_FILTERING 1
#endif

//#endregion

//#region Uniforms

uniform int _Help
<
	ui_text =
		"To use this effect, set the ZOOM_HOTKEY to the virtual key code of "
		"the keyboard key you'd like to use for zooming. The default key code "
		"is 0x12, which represents the alt key.\n"
		"You can check for the available key codes by searching \"virtual key "
		"codes\" on the internet.\n"
		"\n"
		"Alternatively you can set ZOOM_USE_MOUSE_BUTTON to 1 to use a mouse "
		"button instead of a keyboard key, setting ZOOM_MOUSE_BUTTON to the "
		"number of the button you want to use.\n"
		"The available mouse buttons are:\n"
		" 0 - Left.\n"
		" 1 - Right.\n"
		" 2 - Middle.\n"
		" 3 - Extra 1.\n"
		" 4 - Extra 2.\n"
		"\n"
		"Setting ZOOM_TOGGLE to 1 will make the effect toggle when the hotkey/"
		"mouse button is pressed, instead of only being in effect while it's "
		"held down.\n"
		"\n"
		"Setting ZOOM_REVERSE to 1 will make the effect be active when the set "
		"hotkey/mouse button is *not* being held or toggled and vice versa.\n"
		"\n"
		"Setting ZOOM_ALWAYS_ZOOM will simply cause the effect to always be "
		"enabled. This will obviously override ZOOM_REVERSE.\n"
		"This can be combined with ReShade's own toggle hotkey mechanism to "
		"disable the effect entirely instead of using hotkey logic inside it.\n"
		"\n"
		"Setting ZOOM_USE_LINEAR_FILTERING to 0 will cause the zoomed image to "
		"be pixelated, instead of being smooth filtered.\n"
		"Note that this filter is a native hardware feature, usually enabled "
		"by default, and shouldn't impact performance.\n"
		;
	ui_category = "Help";
	ui_category_closed = true;
	ui_label = " ";
	ui_type = "radio";
>;

uniform float ZoomAmount
<
	__UNIFORM_SLIDER_FLOAT1

	ui_label = "Zoom Amount";
	ui_tooltip =
		"Amount of zoom applied to the image.\n"
		"\nDefault: 10.0";
	ui_min = 1.0;
	ui_max = 100.0;
> = 10.0;

uniform float2 CenterPoint
<
	__UNIFORM_DRAG_FLOAT2

	ui_label = "Center Point";
	ui_tooltip =
		"The center point of zoom in the screen.\n"
		"Viewport scale is used, thus:\n"
		" (0.5, 0.5) - Center.\n"
		" (0.0, 0.0) - Top left.\n"
		" (1.0, 0.0) - Top right.\n"
		" (1.0, 1.0) - Bottom right.\n"
		" (0.0, 1.0) - Bottom left.\n"
		"\nDefault: 0.5 0.5";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = float2(0.5, 0.5);

uniform bool FollowMouse
<
	ui_label = "Follow Mouse";
	ui_tooltip =
		"When enabled, the center point becomes the mouse cursor position.\n"
		"May not work with certain games due to how they may handle mouse "
		"input.\n"
		"\nDefault: Off";
> = false;

uniform float2 MousePoint < source = "mousepoint"; >;

uniform bool ShouldZoom
<
	#if ZOOM_USE_MOUSE_BUTTON
		source = "mousebutton";
		keycode = ZOOM_MOUSE_BUTTON;
	#else
		source = "key";
		keycode = ZOOM_HOTKEY;
	#endif

	#if ZOOM_TOGGLE
		mode = "toggle";
	#endif
>;

//#endregion

//#region Textures

sampler BackBuffer
{
	Texture = ReShade::BackBufferTex;

	#if !ZOOM_USE_LINEAR_FILTERING
	MagFilter = POINT;
	#endif
};

//#endregion

//#region Functions

float2 scale_uv(float2 uv, float2 scale, float2 pivot)
{
	return mad((uv - pivot), scale, pivot);
}

//#endregion

//#region Shaders

float4 MainPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
	float2 pivot = FollowMouse ? MousePoint * ReShade::PixelSize : 0.5;
	pivot = saturate(pivot);

	uv =
		#if !ZOOM_ALWAYS_ZOOM
			#if ZOOM_REVERSE
				!
			#endif
			ShouldZoom ?
		#endif
		scale_uv(uv, rcp(ZoomAmount), pivot)
		#if !ZOOM_ALWAYS_ZOOM
			: uv
		#endif
		;
	
	return tex2D(BackBuffer, uv);
}

//#endregion

//#region Technique

technique Zoom
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = MainPS;
	}
}

//#endregion
//#region Preprocessor

#include "ReShade.fxh"
#include "ReShadeUI.fxh"
#include "FXShaders/Common.fxh"
#include "FXShaders/KeyCodes.fxh"

#ifndef DEPTH_APLHA_SCREENSHOT_KEY
#define DEPTH_APLHA_SCREENSHOT_KEY VK_SNAPSHOT
#endif

//#endregion

//#region Uniforms

FXSHADERS_CREATE_HELP(
	"This effect allows you to overwrite the transparency of screenshots using "
	"the scene depth as the alpha channel.\n"
	"\n"
	"You'll need a version of ReShade with the option to disable "
	"\"Clear Alpha Channel\" in the screenshot settings.\n"
	"\n"
	"If you use a different key for taking screenshots, it may be useful to "
	"change the value of DEPTH_ALPHA_SCREENSHOT_KEY to something other than "
	"VK_SNAPSHOT (the keycode for the printscreen key).\n"
	"\n"
	"To see which keycodes are available, refer to the \"KeyCodes.fxh\" file "
	"in the FXShaders repository shaders folder."
);

uniform float2 DepthCurve
<
	__UNIFORM_DRAG_FLOAT1

	ui_category = "Features";
	ui_label = "Depth Curve";
	ui_tooltip =
		"The tranparency fall-off curve.\n"
		"Use Colorize Transparency to see what it does.\n"
		"\nDefault: 0.0 1.0";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = float2(0.0, 1.0);

uniform bool ColorizeTransparency
<
	ui_category = "Debug";
	ui_label = "Colorize Transparency";
	ui_tooltip =
		"Preview transparency by colorizing it.\n"
		"This option is automatically disabled when the key defined in "
		"DEPTH_ALPHA_SCREEENSHOT_KEY is being held down, which is the "
		"printscreen key by default.\n"
		"There's a small chance that the test color might still appear in the "
		"screenshot, but keeping the screenshot key held for a small time "
		"seems to help.\n"
		"You can also simply disable this option before taking a screenshot.\n"
		"\nDefault: Off";
> = false;

uniform float4 TestColor
<
	__UNIFORM_COLOR_FLOAT4

	ui_category = "Debug";
	ui_label = "Transparency Test Color";
	ui_tooltip =
		"The color used when Colorize Transparency is enabled.\n"
		"The alpha channel of this color has nothing to do with the final "
		"result, it merely serves to determine the opacity of this color while "
		"testing.\n"
		"\nDefault: 0 0 0 255";
> = float4(0.0, 0.0, 0.0, 1.0);

uniform bool IsScreenshotKeyDown
<
	source = "key";
	keycode = DEPTH_APLHA_SCREENSHOT_KEY;
>;

//#endregion

//#region Shaders

float4 MainPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
	float4 color = tex2D(ReShade::BackBuffer, uv);

	float depth = ReShade::GetLinearizedDepth(uv);
	if (DepthCurve.x < DepthCurve.y)
		color.a = smoothstep(DepthCurve.x, DepthCurve.y, 1.0 - depth);
	else
		color.a = smoothstep(DepthCurve.y, DepthCurve.x, depth);

	if (!IsScreenshotKeyDown && ColorizeTransparency)
		color.rgb = lerp(
			lerp(color.rgb, TestColor.rgb, TestColor.a),
			color.rgb,
			color.a);

	return color;
}

//#endregion

//#region Technique

technique DepthAlpha
<
	ui_tooltip =
		"Effect that uses depth as transparency to allow for screenshots with "
		"transparency, like a chroma-key.";
>
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = MainPS;
	}
}

//#endregion

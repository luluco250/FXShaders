//#region Preprocessor

#include "ReShade.fxh"
#include "ReShadeUI.fxh"

//#endregion

//#region Uniforms

uniform int Mode
<
	__UNIFORM_COMBO_INT1

	ui_text =
		"How to use:\n"
		"\n"
		"First, choose what kind of chromatic aberration you wish to use by "
		"setting the Mode. Check it's description for details.\n"
		"\n"
		"Secondly, define the Ratio. This controls the chromatic aberration's "
		"\"colors\".\n"
		"\n"
		"Finally, set how large the chromatic aberration will be by setting "
		"the Multiplier.\n"
		" ";
	ui_tooltip =
		"Mode defining how the chromatic aberration is created.\n"
		"\n"
		"  Translate:\n"
		"    Move channels horizontally and vertically.\n"
		"\n"
		"  Scale:\n"
		"    Zoom channels from the center.\n"
		"  Lens Distortion:\n"
		"    Applies lens distortion to the channels.\n"
		"\n"
		"Default: Scale";
	ui_items = "Translate\0Scale\0Lens Distortion\0";
> = 1;

uniform float3 Ratio
<
	__UNIFORM_SLIDER_FLOAT3

	ui_tooltip =
		"Ratio of how each channel is distorted.\n"
		"The values control the red, green and blue channels respectively.\n"
		"\n"
		"Default: -1.0 0.0 1.0";
	ui_min = -1.0;
	ui_max = 1.0;
> = float3(-1.0, 0.0, 1.0);

uniform float Multiplier
<
	__UNIFORM_SLIDER_FLOAT1

	ui_tooltip =
		"Multiplier of the ratio, defining how much distortion there is.\n"
		"\n"
		"Default: 1.0";
	ui_min = 0.0;
	ui_max = 6.0;
	ui_step = 0.001;
> = 1.0;

//#endregion

//#region Textures

sampler BackBuffer
{
	Texture = ReShade::BackBufferTex;
	AddressU = BORDER;
	AddressV = BORDER;
};

//#endregion

//#region Functions

float2 scale_uv(float2 uv, float2 scale, float2 center)
{
	return (uv - center) * scale + center;
}

float2 lens_distortion(float2 uv, float amount)
{
	// 0.0 <-> 1.0 --> -1.0 <-> 1.0
	uv = uv * 2.0 - 1.0;

	//uv = lerp(uv, 0.0, sqrt(uv) * amount);
	//uv = scale_uv(uv, 1.0 / amount, 0.0);

	//uv = pow(abs(uv), 0.9) * sign(uv);

	//uv = lerp(uv, abs(uv) * abs(uv.yx) * sign(uv), 0.25);

	//uv += distance(abs(uv), 0.2) * sign(uv);

	//uv *= lerp(1.0, distance(uv, 0.0), 0.5);

	/*float theta = atan2(uv.y, uv.x);
	float radius = length(uv);
	radius = pow(abs(radius), amount);

	float s, c;
	sincos(theta, s, c);

	uv.x = radius * cos(theta);
	uv.y = radius * sin(theta);*/

	uv *= smoothstep(6.0, 3.0, distance(uv, 0.0));

	// -1.0 <-> 1.0 --> 0.0 <-> 1.0
	uv = uv * 0.5 + 0.5;

	return uv;
}

//#endregion

//#region Shaders

float4 MainPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
	const float2 ps = ReShade::PixelSize;

	float2 uv_r = uv;
	float2 uv_g = uv;
	float2 uv_b = uv;

	float3 ratio;

	switch (Mode)
	{
		case 0: // Translate
			ratio = Ratio * Multiplier;

			uv_r += ps * ratio.r;
			uv_g += ps * ratio.g;
			uv_b += ps * ratio.b;
			break;
		case 1: // Scale
			ratio = Multiplier * length(ps) + 1.0;
			ratio = lerp(ratio, 1.0 / ratio, Ratio * 0.5 + 0.5);

			uv_r = scale_uv(uv_r, ratio.r, 0.5);
			uv_g = scale_uv(uv_g, ratio.g, 0.5);
			uv_b = scale_uv(uv_b, ratio.b, 0.5);
			break;
		case 2: // Lens Distortion
			ratio = Ratio * Multiplier;

			uv_r = lens_distortion(uv_r, ratio.r);
			uv_g = lens_distortion(uv_g, ratio.g);
			uv_b = lens_distortion(uv_b, ratio.b);
			break;
	}

	float3 color = float3(
		tex2D(ReShade::BackBuffer, uv_r).r,
		tex2D(ReShade::BackBuffer, uv_g).g,
		tex2D(ReShade::BackBuffer, uv_b).b);

	return float4(color, 1.0);
}

//#endregion

//#region Technique

technique FlexibleCA
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = MainPS;
	}
}

//#endregion
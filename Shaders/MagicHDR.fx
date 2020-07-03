//#region Includes

#include "FXShaders/Common.fxh"
#include "FXShaders/Tonemap.fxh"

//#endregion

//#region Preprocessor

#ifndef MAGIC_HDR_BLUR_SAMPLES
#define MAGIC_HDR_BLUR_SAMPLES 21
#endif

#ifndef MAGIC_HDR_DOWNSAMPLE
#define MAGIC_HDR_DOWNSAMPLE 2
#endif

//#endregion

namespace FXShaders
{

//#region Constants

static const int2 Downsample = MAGIC_HDR_DOWNSAMPLE;

static const int BlurSamples = MAGIC_HDR_BLUR_SAMPLES;

// Arbitrary margin of error/round-off value.
static const float FloatEpsilon = 0.001;

//#endregion

//#region Uniforms

uniform float BloomAmount
<
	ui_category = "Bloom Appearance";
	ui_label = "Bloom Amount";
	ui_tooltip =
		"Amount of bloom to blend with the image.\n"
		"\nDefault: 0.5";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.5;

uniform float Whitepoint
<
	ui_category = "Reverse Tonemap";
	ui_label = "Whitepoint";
	ui_tooltip =
		"The whitepoint of the HDR image.\n"
		"Anything with this brightness is pure white.\n"
		"\nDefault: 4.0";
	ui_type = "slider";
	ui_min = 1.0;
	ui_max = 10.0;
	ui_step = 1.0;
> = 4.0;

uniform float BlurSize
<
	ui_category = "Blur Appearance";
	ui_label = "Blur Size";
	ui_tooltip =
		"The size of the gaussian blur.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.01;
	ui_max = 1.0;
> = 1.0;

//#endregion

//#region Textures

texture ColorTex : COLOR;

sampler Color
{
	Texture = ColorTex;
	SRGBTexture = true;
};

texture ColorHdrATex <pooled = true;>
{
	Width = BUFFER_WIDTH / Downsample.x;
	Height = BUFFER_HEIGHT / Downsample.y;
	Format = RGBA16F;
};

sampler ColorHdrA
{
	Texture = ColorHdrATex;
};

texture ColorHdrBTex <pooled = true;>
{
	Width = BUFFER_WIDTH / Downsample.x;
	Height = BUFFER_HEIGHT / Downsample.y;
	Format = RGBA16F;
};

sampler ColorHdrB
{
	Texture = ColorHdrBTex;
};

//#endregion

//#region Functions

float3 ApplyReverseTonemap(float3 color)
{
	color = ReinhardInv(color, rcp(max(Whitepoint, FloatEpsilon)));

	return color;
}

//#endregion

//#region Shaders

float4 ReverseTonemapPS(
	float4 p : SV_POSITION,
	float2 uv : TEXCOORD) : SV_TARGET
{
	float4 color = tex2D(Color, uv);
	color.rgb = ApplyReverseTonemap(color.rgb);

	return color;
}

float4 BlurHorizontalPS(
	float4 p : SV_POSITION,
	float2 uv : TEXCOORD) : SV_TARGET
{
	float4 color = GaussianBlur1D(
		ColorHdrA,
		uv,
		float2(BUFFER_RCP_WIDTH * Downsample.x, 0.0),
		sqrt(BlurSamples) * BlurSize,
		BlurSamples);

	return color;
}

float4 BlurVerticalPS(
	float4 p : SV_POSITION,
	float2 uv : TEXCOORD) : SV_TARGET
{
	float4 color = GaussianBlur1D(
		ColorHdrB,
		uv,
		float2(0.0, BUFFER_RCP_HEIGHT * Downsample.y),
		sqrt(BlurSamples) * BlurSize,
		BlurSamples);

	return color;
}

float4 TonemapPS(
	float4 p : SV_POSITION,
	float2 uv : TEXCOORD) : SV_TARGET
{
	float4 color = tex2D(Color, uv);
	color.rgb = ApplyReverseTonemap(color.rgb);

	float4 bloom = tex2D(ColorHdrA, uv);

	color.rgb = lerp(color.rgb, bloom.rgb, log(BloomAmount + 1.0));
	color.rgb = Reinhard(color.rgb);

	return color;
}

//#endregion

//#region Technique

technique MagicHDR
{
	pass ReverseTonemap
	{
		VertexShader = ScreenVS;
		PixelShader = ReverseTonemapPS;
		RenderTarget = ColorHdrATex;
	}
	pass BlurHorizontal
	{
		VertexShader = ScreenVS;
		PixelShader = BlurHorizontalPS;
		RenderTarget = ColorHdrBTex;
	}
	pass BlurVertical
	{
		VertexShader = ScreenVS;
		PixelShader = BlurVerticalPS;
		RenderTarget = ColorHdrATex;
	}
	pass Tonemap
	{
		VertexShader = ScreenVS;
		PixelShader = TonemapPS;
		SRGBWriteEnable = true;
	}
}

//#endregion

} // Namespace.

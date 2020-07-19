//#region Includes

#include "FXShaders/Common.fxh"
#include "FXShaders/Convolution.fxh"
#include "FXShaders/Math.fxh"
#include "FXShaders/Tonemap.fxh"

//#endregion

//#region Preprocessor Directives

#ifndef MAGIC_HDR_BLUR_SAMPLES
#define MAGIC_HDR_BLUR_SAMPLES 21
#endif

#if MAGIC_HDR_BLUR_SAMPLES < 1
	#error "Blur samples cannot be less than 1"
#endif

#ifndef MAGIC_HDR_DOWNSAMPLE
#define MAGIC_HDR_DOWNSAMPLE 1
#endif

#if MAGIC_HDR_DOWNSAMPLE < 1
	#error "Downsample cannot be less than 1x"
#endif

#ifndef MAGIC_HDR_SRGB_INPUT
#define MAGIC_HDR_SRGB_INPUT 1
#endif

#ifndef MAGIC_HDR_SRGB_OUTPUT
#define MAGIC_HDR_SRGB_OUTPUT 1
#endif

//#endregion

namespace FXShaders
{

//#region Constants

static const int2 DownsampleAmount = MAGIC_HDR_DOWNSAMPLE;

static const int BlurSamples = MAGIC_HDR_BLUR_SAMPLES;

static const int DitherPatternSize = 4;
static const int DitherPattern[DitherPatternSize * DitherPatternSize] =
{
	0, 8, 2, 10,
	12, 4, 14, 6,
	3, 11, 1, 9,
	15, 7, 13, 5
};

static const int
	InvTonemap_Reinhard = 0,
	InvTonemap_Lottes = 1,
	InvTonemap_Unreal3 = 2,
	InvTonemap_NarkowiczACES = 3,
	InvTonemap_Uncharted2Filmic = 4,
	InvTonemap_BakingLabACES = 5;

static const int
	Tonemap_Reinhard = 0,
	Tonemap_Lottes = 1,
	Tonemap_Unreal3 = 2,
	Tonemap_NarkowiczACES = 3,
	Tonemap_Uncharted2Filmic = 4,
	Tonemap_BakingLabACES = 5;

//#endregion

//#region Uniforms

FXSHADERS_WIP_WARNING();

FXSHADERS_CREDITS();

FXSHADERS_HELP(
	"This effect allows you to add both bloom and tonemapping, drastically "
	"changing the mood of the image.\n"
	"\n"
	"Care should be taken to select an appropriate inverse tonemapper that can "
	"accurately extract HDR information from the original image.\n"
	"HDR10 users should also take care to select a tonemapper that's "
	"compatible with what the HDR monitor is expecting from the LDR output of "
	"the game, which *is* tonemapped too.\n"
	"\n"
	"Available preprocessor directives:\n"
	"\n"
	"MAGIC_HDR_BLUR_SAMPLES:\n"
	"  Determines how many pixels are sampled during each blur pass for the "
	"bloom effect.\n"
	"  This value directly influences the Blur Size, so the more samples the "
	"bigger the blur size can be.\n"
	"  Setting MAGIC_HDR_DOWNSAMPLE above 1x will also increase the blur size "
	"to compensate for the lower resolution. This effect may be desirable, "
	"however.\n"
	"\n"
	"MAGIC_HDR_DOWNSAMPLE:\n"
	"  Serves to divide the resolution of the textures used for processing the "
	"bloom effect.\n"
	"  Leave at 1x for maximum detail, 2x or 4x should still be fine.\n"
	"  Values too high may introduce flickering.\n"
);

uniform float Whitepoint
<
	ui_category = "Tonemapping";
	ui_category_closed = true;
	ui_label = "Whitepoint";
	ui_tooltip =
		"The whitepoint of the HDR image.\n"
		"Anything with this brightness is pure white.\n"
		"It controls how bright objects are perceived after inverse "
		"tonemapping, with higher values leading to a brighter bloom effect.\n"
		"\nDefault: 2";
	ui_type = "slider";
	ui_min = 1;
	ui_max = 10;
	ui_step = 1;
> = 2;

uniform float InputExposure
<
	ui_category = "Tonemapping";
	ui_label = "Input Exposure";
	ui_tooltip =
		"Approximate exposure of the original image.\n"
		"This value is measured in f-stops.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = -3.0;
	ui_max = 3.0;
> = 0.0;

uniform float Exposure
<
	ui_category = "Tonemapping";
	ui_label = "Output Exposure";
	ui_tooltip =
		"Exposure applied at the end of the effect.\n"
		"This value is measured in f-stops.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = -3.0;
	ui_max = 3.0;
> = 1.0;

uniform int InvTonemap
<
	ui_category = "Tonemapping";
	ui_label = "Input Tonemapper";
	ui_tooltip =
		"The inverse tonemapping operator used at the beginning of the "
		"effect.\n"
		"\nDefault: Reinhard";
	ui_type = "combo";
	ui_items =
		"Reinhard\0Lottes\0Unreal 3\0Narkowicz ACES\0Uncharted 2 Filmic\0Baking Lab ACES\0";
> = InvTonemap_Reinhard;

uniform int Tonemap
<
	ui_category = "Tonemapping";
	ui_label = "Output Tonemapper";
	ui_tooltip =
		"The tonemapping operator used at the end of the effect.\n"
		"\nDefault: Baking Lab ACES";
	ui_type = "combo";
	ui_items =
		"Reinhard\0Lottes\0Unreal 3\0Narkowicz ACES\0Uncharted 2 Filmic\0Baking Lab ACES\0";
> = Tonemap_BakingLabACES;

uniform float BloomAmount
<
	ui_category = "Bloom";
	ui_category_closed = true;
	ui_label = "Bloom Amount";
	ui_tooltip =
		"Amount of bloom to apply to the image.\n"
		"\nDefault: 0.2";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.2;

uniform float WhitepointScale
<
	ui_category = "Bloom";
	ui_label = "Whitepoint Scale";
	ui_tooltip =
		"This option determines how much the bloom amount is scaled by the "
		"whitepoint value.\n"
		"At 0.0 no scale is applied.\n"
		"At 1.0 the amount is divided by the whitepoint.\n"
		"\nDefault: 0.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.0;

uniform float BlurSize
<
	ui_category = "Bloom - Advanced";
	ui_category_closed = true;
	ui_label = "Blur Size";
	ui_tooltip =
		"The size of the gaussian blur applied to create the bloom effect.\n"
		"This value is directly influenced by the values of "
		"MAGIC_HDR_BLUR_SAMPLES and MAGIC_HDR_DOWNSAMPLE.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.01;
	ui_max = 1.0;
> = 1.0;

uniform float Mean
<
	ui_category = "Bloom - Advanced";
	ui_label = "Distribution Mean";
	ui_tooltip =
		"Determines the "
		"\nDefault: 0.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.0;

uniform float Variance
<
	ui_category = "Bloom - Advanced";
	ui_label = "Distribution Variance";
	ui_tooltip =
		""
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = 1.0;

//#endregion

//#region Textures

texture ColorTex : COLOR;

sampler Color
{
	Texture = ColorTex;

	#if MAGIC_HDR_SRGB_INPUT
		SRGBTexture = true;
	#endif
};

#define DEF_DOWNSAMPLED_TEX(name, downscale) \
texture name##Tex <pooled = true;> \
{ \
	Width = BUFFER_WIDTH / DownsampleAmount.x / downscale; \
	Height = BUFFER_HEIGHT / DownsampleAmount.y / downscale; \
	Format = RGBA16F; \
}; \
\
sampler name \
{ \
	Texture = name##Tex; \
}

// This texture is used as a sort of "HDR backbuffer".
DEF_DOWNSAMPLED_TEX(Temp, 1);

// These are the textures in which the many bloom LODs are stored.
DEF_DOWNSAMPLED_TEX(Bloom0, 1);
DEF_DOWNSAMPLED_TEX(Bloom1, 2);
DEF_DOWNSAMPLED_TEX(Bloom2, 4);
DEF_DOWNSAMPLED_TEX(Bloom3, 8);
DEF_DOWNSAMPLED_TEX(Bloom4, 16);
DEF_DOWNSAMPLED_TEX(Bloom5, 32);
DEF_DOWNSAMPLED_TEX(Bloom6, 64);

//#endregion

//#region Functions

float GetWhitepoint()
{
	float w = max(Whitepoint, FloatEpsilon);
	w = exp2(w);

	return w;
}

float3 ApplyDither(float3 color, float2 uv)
{
	int2 pos = uv * GetResolution();
	pos %= DitherPatternSize;

	float value = DitherPattern[pos.x * DitherPatternSize + pos.y];
	value /= DitherPatternSize * DitherPatternSize;

	//color *= 1.0 + (value - 0.5) * 2.0;
	color *= value + value;

	// float noise = GetRandom(uv);
	// noise = 1.0 + (noise * 2.0 - 1.0) * 0.1;
	// color *= noise;

	return color;
}

float3 ApplyInverseTonemap(float3 color, float2 uv)
{
	float w = rcp(GetWhitepoint());

	switch (InvTonemap)
	{
		case InvTonemap_Reinhard:
			color = Reinhard::InvTonemap(color, w);
			break;
		case InvTonemap_Lottes:
			color = Lottes::InvTonemap(color, w);
			break;
		case InvTonemap_Unreal3:
			color = Unreal3::InvTonemap(color, w);
			break;
		case InvTonemap_NarkowiczACES:
			color = NarkowiczACES::InvTonemap(color);
			break;
		case InvTonemap_Uncharted2Filmic:
			color = Uncharted2Filmic::InvTonemap(color);
			break;
		case InvTonemap_BakingLabACES:
			color = BakingLabACES::InvTonemap(color);
			break;
	}

	color /= exp(InputExposure);

	return color;
}

float3 ApplyTonemap(float3 color, float2 uv)
{
	// TODO: Implement adaptation.
	float exposure = exp(Exposure);

	switch (Tonemap)
	{
		case Tonemap_Reinhard:
			color = Reinhard::Tonemap(color * exposure);
			break;
		case Tonemap_Lottes:
			color = Lottes::Tonemap(color * exposure);
			break;
		case Tonemap_Unreal3:
			color = Unreal3::Tonemap(color * exposure);
			break;
		case Tonemap_NarkowiczACES:
			color = NarkowiczACES::Tonemap(color * exposure);
			break;
		case Tonemap_Uncharted2Filmic:
			color = Uncharted2Filmic::Tonemap(color * exposure);
			break;
		case Tonemap_BakingLabACES:
			color = BakingLabACES::Tonemap(color * exposure);
			break;
	}

	return color;
}

float4 Blur(sampler sp, float2 uv, float2 dir)
{
	float4 color = GaussianBlur1D(
		sp,
		uv,
		dir * GetPixelSize() * DownsampleAmount,
		sqrt(BlurSamples) * BlurSize,
		BlurSamples);

	return color;
}

//#endregion

//#region Shaders

float4 InverseTonemapPS(
	float4 p : SV_POSITION,
	float2 uv : TEXCOORD) : SV_TARGET
{
	float4 color = tex2D(Color, uv);
	color.rgb = ApplyInverseTonemap(color.rgb, uv);

	// TODO: Saturation and other color filtering options?

	return color;
}

#define DEF_BLUR_SHADER(x, y, input, scale) \
float4 Blur##x##PS( \
	float4 p : SV_POSITION, \
	float2 uv : TEXCOORD) : SV_TARGET \
{ \
	return Blur(input, uv, float2(scale, 0.0)); \
} \
\
float4 Blur##y##PS( \
	float4 p : SV_POSITION, \
	float2 uv : TEXCOORD) : SV_TARGET \
{ \
	return Blur(Temp, uv, float2(0.0, scale)); \
}

DEF_BLUR_SHADER(0, 1, Bloom0, 1)
DEF_BLUR_SHADER(2, 3, Bloom0, 2)
DEF_BLUR_SHADER(4, 5, Bloom1, 4)
DEF_BLUR_SHADER(6, 7, Bloom2, 8)
DEF_BLUR_SHADER(8, 9, Bloom3, 16)
DEF_BLUR_SHADER(10, 11, Bloom4, 32)
DEF_BLUR_SHADER(12, 13, Bloom5, 64)

float4 TonemapPS(
	float4 p : SV_POSITION,
	float2 uv : TEXCOORD) : SV_TARGET
{
	float4 color = tex2D(Color, uv);
	color.rgb = ApplyInverseTonemap(color.rgb, uv);

	float mean = Mean * 7;
	float vari = (Variance + 0.1) * 7;

	float4 bloom =
		tex2D(Bloom0, uv) * NormalDistribution(1, mean, vari) +
		tex2D(Bloom1, uv) * NormalDistribution(2, mean, vari) +
		tex2D(Bloom2, uv) * NormalDistribution(3, mean, vari) +
		tex2D(Bloom3, uv) * NormalDistribution(4, mean, vari) +
		tex2D(Bloom4, uv) * NormalDistribution(5, mean, vari) +
		tex2D(Bloom5, uv) * NormalDistribution(6, mean, vari) +
		tex2D(Bloom6, uv) * NormalDistribution(7, mean, vari);

	bloom /= 7;

	float amount = BloomAmount;

	float w = GetWhitepoint();

	amount = lerp(amount, amount / w, WhitepointScale);
	amount = log10(amount + 1.0);

	color.rgb = lerp(color.rgb, bloom.rgb, amount);

	color.rgb = ApplyTonemap(color.rgb, uv);

	return color;
}

//#endregion

//#region Technique

technique MagicHDR <ui_tooltip = "FXShaders - Bloom and tonemapping effect.";>
{
	pass InverseTonemap
	{
		VertexShader = ScreenVS;
		PixelShader = InverseTonemapPS;
		RenderTarget = Bloom0Tex;
	}

	#define DEF_BLUR_PASS(index, x, y) \
	pass Blur##x \
	{ \
		VertexShader = ScreenVS; \
		PixelShader = Blur##x##PS; \
		RenderTarget = TempTex; \
	} \
	pass Blur##y \
	{ \
		VertexShader = ScreenVS; \
		PixelShader = Blur##y##PS; \
		RenderTarget = Bloom##index##Tex; \
	}

	DEF_BLUR_PASS(0, 0, 1)
	DEF_BLUR_PASS(1, 2, 3)
	DEF_BLUR_PASS(2, 4, 5)
	DEF_BLUR_PASS(3, 6, 7)
	DEF_BLUR_PASS(4, 8, 9)
	DEF_BLUR_PASS(5, 10, 11)
	DEF_BLUR_PASS(6, 12, 13)

	pass Tonemap
	{
		VertexShader = ScreenVS;
		PixelShader = TonemapPS;

		#if MAGIC_HDR_SRGB_OUTPUT
			SRGBWriteEnable = true;
		#endif
	}
}

//#endregion

} // Namespace.

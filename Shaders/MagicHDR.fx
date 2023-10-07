//#region Includes

#include "FXShaders/API.fxh"
#include "FXShaders/Canvas.fxh"
#include "FXShaders/Common.fxh"
#include "FXShaders/Convolution.fxh"
#include "FXShaders/Math.fxh"
#include "FXShaders/Tonemap.fxh"

//#endregion

//#region Preprocessor Directives

#ifndef MAGIC_HDR_NITS_SCALING
#define MAGIC_HDR_NITS_SCALING 0
#endif

#ifndef MAGIC_HDR_BLUR_SAMPLES
#define MAGIC_HDR_BLUR_SAMPLES 13
#endif

#if MAGIC_HDR_BLUR_SAMPLES < 1
	#error "Blur samples cannot be less than 1"
#endif

#ifndef MAGIC_HDR_DOWNSAMPLE
#define MAGIC_HDR_DOWNSAMPLE 4
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

#ifndef MAGIC_HDR_ENABLE_ADAPTATION
#define MAGIC_HDR_ENABLE_ADAPTATION 0
#endif

#ifndef MAGIC_HDR_ENABLE_BLOOM_CONTRAST
#define MAGIC_HDR_ENABLE_BLOOM_CONTRAST 0
#endif

#ifndef MAGIC_HDR_ENABLE_BLOOM_NORMALIZATION 
#define MAGIC_HDR_ENABLE_BLOOM_NORMALIZATION 0
#endif

//#endregion

namespace FXShaders
{

//#region Constants

static const int2 DownsampleAmount = MAGIC_HDR_DOWNSAMPLE;

static const int BlurSamples = MAGIC_HDR_BLUR_SAMPLES;

static const float2 AdaptFocusPointDebugSize = 10.0;

static const int
	InvTonemap_Reinhard = 0,
	InvTonemap_Reinhard2 = 1,
	InvTonemap_Uncharted2Filmic = 2,
	InvTonemap_BakingLabACES = 3,
	InvTonemap_Lottes = 4,
	InvTonemap_Lottes2 = 5,
	InvTonemap_NarkowiczACES = 6,
	InvTonemap_Unreal3 = 7,
	InvTonemap_Fallout4 = 8,
	InvTonemap_Frostbite = 9,
	InvTonemap_Uchimura = 10,
	InvTonemap_ReinhardJodie = 11,
	InvTonemap_iCAM06m = 12,
	InvTonemap_HuePreserving = 13,
	InvTonemap_Linear = 14,
	InvTonemap_None = 15;
	
static const int
	Tonemap_Reinhard = 0,
	Tonemap_Reinhard2 = 1,
	Tonemap_Uncharted2Filmic = 2,
	Tonemap_BakingLabACES = 3,
	Tonemap_Lottes = 4,
	Tonemap_Lottes2 = 5,
	Tonemap_NarkowiczACES = 6,
	Tonemap_Unreal3 = 7,
	Tonemap_Fallout4 = 8,
	Tonemap_Frostbite = 9,
	Tonemap_Uchimura = 10,
	Tonemap_ReinhardJodie = 11,
	Tonemap_iCAM06m = 12,
	Tonemap_HuePreserving = 13,
	Tonemap_Linear = 14,
	Tonemap_None = 15;
	
static const int 
	Additive = 0,
	Overlay = 1;
static const int 
	Exponential = 0,
	Multiplication = 1;

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

uniform bool TonemapBloomOnly
<
	ui_category = "Tonemapping";
	ui_label = "Only bloom texture tonemapping";
	ui_tooltip =
		"Applies inverse and regular tonemapping only to bloom texture,\n"
		"rather than both input\output color and bloom texture";
> = true;

uniform float InputExposure
<
	ui_category = "Tonemapping";
	ui_label = "Input Exposure";
	ui_tooltip =
		"Approximate exposure of the original image.\n"
		"This value is measured in f-stops.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = -10.0;
	ui_max = 10.0;
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
	ui_min = -10.0;
	ui_max = 10.0;
> = 0.0;

uniform int InvTonemap
<
	ui_category = "Tonemapping";
	ui_label = "Inverse Tonemapper";
	ui_tooltip =
		"The inverse tonemapping operator used to obtain HDR information.\n"
		"\nDefault: Reinhard";
	ui_type = "combo";
	ui_items =
		"Reinhard\0Reinhard2\0Uncharted 2 Filmic\0Baking Lab ACES\0Lottes\0Lottes2\0Narkowicz ACES\0Unreal 3\0Fallout4\0Frostbite\0Uchimura\0ReinhardJodie\0iCAM06m\0HuePreserving\0Linear\0None\0";
> = InvTonemap_Reinhard;

uniform int Tonemap
<
	ui_category = "Tonemapping";
	ui_label = "Output Tonemapper";
	ui_tooltip =
		"The tonemapping operator applied at the end of the effect.\n"
		"\nIt is highly suggested to choose 'none' in true HDR display.\n"
		"\nDefault: Baking Lab ACES";
	ui_type = "combo";
	ui_items =
		"Reinhard\0Reinhard2\0Uncharted 2 Filmic\0Baking Lab ACES\0Lottes\0Lottes2\0Narkowicz ACES\0Unreal 3\0Fallout4\0Frostbite\0Uchimura\0ReinhardJodie\0iCAM06m\0HuePreserving\0Linear\0None\0";
> = Tonemap_None;

#if MAGIC_HDR_NITS_SCALING

uniform float MaxNitsInverse
<
	ui_category = "Tonemapping";
	ui_label = "Max Nits Input";
	ui_tooltip =
		"Value of nits output before tonemapping, potential maximum HDR value a game might output. On SDR, values around 100-1000 seem to work the best.\n"
		"\nDefault: 10000 nits";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 100000.0;
	ui_step = 100.0;
> = 100000.0;

uniform float MaxNitsApply
<
	ui_category = "Tonemapping";
	ui_label = "Max Nits Output";
	ui_tooltip =
		"Value of nits output after tonemapping. Usually around 100 for SDR displays. For HDR displays, good starting values is 1000.\n"
		"\nDefault: 1000 nits";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 10000.0;
	ui_step = 100.0;
> = 1000.0;

#endif

uniform float BloomAmount
<
	ui_category = "Bloom";
	ui_category_closed = true;
	ui_label = "Amount";
	ui_tooltip =
		"The amount of bloom to apply to the image.\n"
		"\nDefault: 0.5. You can use higher than 1.0 in additive mode.";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.05;

uniform int BloomBrightnessMethod
<
	ui_category = "Bloom";
	ui_label = "Brightness Method";
	ui_tooltip =
		"Methods of multiplying bloom texture\n"
		"\nDefault: Multiplication";
	ui_type = "combo";
	ui_items = "Exponential\0Multiplication\0";
> = Multiplication;

uniform float BloomBrightness
<
	ui_category = "Bloom";
	ui_label = "Brightness";
	ui_tooltip =
		"This value is used to multiply the bloom texture brightness.\n"
		"This is different from the amount in it directly affects the "
		"brightness, rather than acting as a percentage of blending between "
		"the HDR color and the bloom color.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.001;
	ui_max = 5.0;
> = 1.0;

uniform float BloomMaximization
<
	ui_category = "Bloom";
	ui_label = "Brightness2";
	ui_tooltip =
		"This value is used to maximize the bloom texture brightness.\n"
		"This is different from the brightness in it attempt to "
		"maximizes the highlights, rather than multiplying "
		"the HDR color and the bloom color.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 2.0;
> = 0.0;

#if MAGIC_HDR_ENABLE_BLOOM_CONTRAST

uniform float BloomContrast
<
	ui_category = "Bloom";
	ui_label = "Contrast Hard";
	ui_tooltip =
		"This value is used to contrast the bloom texture.\n"
		"\nDefault: 7.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 100.0;
> = 8.0;

uniform float BloomContrastSoft
<
	ui_category = "Bloom";
	ui_label = "Contrast Soft";
	ui_tooltip =
		"This value is used to soften the contrast of the bloom texture.\n"
		"\nDefault: 0.05";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.025;

#endif

uniform float BloomSaturation
<
	ui_category = "Bloom";
	ui_label = "Saturation";
	ui_tooltip =
		"Determines the saturation of bloom.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 2.0;
> = 1.0;

uniform float BlurSize
<
	ui_category = "Bloom - Advanced";
	ui_category_closed = true;
	ui_label = "Blur Size";
	ui_tooltip =
		"The size of the gaussian blur applied to create the bloom effect.\n"
		"This value is directly influenced by the values of "
		"MAGIC_HDR_BLUR_SAMPLES and MAGIC_HDR_DOWNSAMPLE.\n"
		"\nDefault: 0.5";
	ui_type = "slider";
	ui_min = 0.01;
	ui_max = 1.0;
> = 0.5;

#if MAGIC_HDR_ENABLE_BLOOM_NORMALIZATION

uniform float BlendingAmount
<
	ui_category = "Bloom - Advanced";
	ui_label = "Blending Amount";
	ui_tooltip =
		"How much to blend the various bloom textures used internally.\n"
		"Reducing this value will make the bloom more uniform, with less "
		"variation.\n"
		"\nDefault: 0.5";
	ui_type = "slider";
	ui_min = 0.1;
	ui_max = 1.0;
> = 0.5;

uniform float BlendingBase
<
	ui_category = "Bloom - Advanced";
	ui_label = "Blending Base";
	ui_tooltip =
		"Determines the base bloom size when blending.\n"
		"It's more effective with a lower Blending Amount.\n"
		"\nDefault: 0.8";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.5;

#endif

uniform int BlendingType
<
	ui_category = "Bloom - Advanced";
	ui_label = "Blending Type";
	ui_tooltip =
		"Methods of blending bloom with image.\n"
		"\nDefault: Additive";
	ui_type = "combo";
	ui_items = "Additive\0Overlay\0";
> = Additive;

#if MAGIC_HDR_ENABLE_ADAPTATION

uniform float AdaptTime
<
	ui_category = "Adaptation";
	ui_category_closed = true;
	ui_label = "Delay";
	ui_tooltip =
		"Determines the time in seconds it takes for adaptation to transition "
		"between the previous value and the next.\n"
		"\nDefault: 1.0";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;

uniform float2 AdaptMinMax
<
	ui_category = "Adaptation";
	ui_label = "Range";
	ui_tooltip =
		"Determines the minimum and maximum values for adaptation, "
		"respectively.\n"
		"Increasing the minimum will reduce how bright the image can become.\n"
		"Decreasing the maximum will reduce how dark the image can become.\n"
		"\nDefault: 0.0 1.0";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 3.0;
	ui_step = 0.001;
> = float2(0.0, 1.0);

uniform float AdaptSensitivity
<
	ui_category = "Adaptation - Advanced";
	ui_category_closed = true;
	ui_label = "Sensitivity";
	ui_tooltip =
		"Determines the sensitivity of adaptation towards bright objects.\n"
		"\nDefault: 1.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 2.0;
> = 1.0;

uniform float AdaptPrecision
<
	ui_category = "Adaptation - Advanced";
	ui_label = "Precision";
	ui_tooltip =
		"Determines which parts of the image influence adaptation more.\n"
		"At 0.0, adaptation is influenced by the entire image equally.\n"
		"At 1.0, adaptation will be influenced by objects closer to the Focus "
		"Point more than the rest of the scene.\n"
		"\nDefault: 0.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.0;

uniform float2 AdaptPoint
<
	ui_category = "Adaptation - Advanced";
	ui_label = "Focus Point";
	ui_tooltip =
		"Determines the point on the screen that is used for determining the "
		"adaptation value.\n"
		"The first value determines the horizontal position, from left to "
		"right.\n"
		"The second value determines the vertical position, from top to "
		"bottom.\n"
		"(0.5, 0.5) is the screen center.\n"
		"\nDefault: 0.5 0.5";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = 0.5;

uniform float FrameTime <source = "frametime";>;

#endif

uniform bool ShowBloom
<
	ui_category = "Debug";
	ui_category_closed = true;
	ui_label = "Show Bloom";
	ui_tooltip =
		"Displays the bloom texture.\n"
		"\nDefault: Off";
> = false;

#if MAGIC_HDR_ENABLE_ADAPTATION

uniform bool ShowAdapt
<
	ui_category = "Debug";
	ui_label = "Show Adaptation";
	ui_tooltip =
		"Displays the texture used for adaptation and the focus point.\n"
		"\nDefault: Off";
> = false;

#endif

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

#define DEF_DOWNSAMPLED_TEX(name, downscale, maxMip) \
texture name##Tex <pooled = true;> \
{ \
	Width = BUFFER_WIDTH / DownsampleAmount.x / downscale; \
	Height = BUFFER_HEIGHT / DownsampleAmount.y / downscale; \
	Format = RGBA16F; \
	MipLevels = maxMip; \
}; \
\
sampler name \
{ \
	Texture = name##Tex; \
	AddressU = Border; \
    AddressV = Border; \
}

// This texture is used as a sort of "HDR backbuffer".
DEF_DOWNSAMPLED_TEX(Temp, 1, 1);

// These are the textures in which the many bloom LODs are stored.
DEF_DOWNSAMPLED_TEX(Bloom0, 1, 1);
DEF_DOWNSAMPLED_TEX(Bloom1, 2, 1);
DEF_DOWNSAMPLED_TEX(Bloom2, 4, 1);
DEF_DOWNSAMPLED_TEX(Bloom3, 8, 1);
DEF_DOWNSAMPLED_TEX(Bloom4, 16, 1);
DEF_DOWNSAMPLED_TEX(Bloom5, 32, 1);

#if MAGIC_HDR_ENABLE_ADAPTATION
	#define MAGIC_HDR_ADAPT_TEXTURE_RESOLUTION \
		FXSHADERS_NPOT(FXSHADERS_MAX(BUFFER_WIDTH, BUFFER_HEIGHT) / 64)

	texture Bloom6Tex <pooled = true;>
	{
		Width = MAGIC_HDR_ADAPT_TEXTURE_RESOLUTION;
		Height = MAGIC_HDR_ADAPT_TEXTURE_RESOLUTION;
		Format = RGBA16F;
		MipLevels = FXSHADERS_GET_MAX_MIP(
			MAGIC_HDR_ADAPT_TEXTURE_RESOLUTION,
			MAGIC_HDR_ADAPT_TEXTURE_RESOLUTION);
	};

	sampler Bloom6
	{
		Texture = Bloom6Tex;
	};
	#else
		DEF_DOWNSAMPLED_TEX(Bloom6, 64, 1);
#endif

#if MAGIC_HDR_ENABLE_ADAPTATION

texture AdaptTex <pooled = true;>
{
	Format = R32F;
};

sampler Adapt
{
	Texture = AdaptTex;
};

texture LastAdaptTex
{
	Format = R32F;
};

sampler LastAdapt
{
	Texture = LastAdaptTex;
};

#endif

//#endregion

//#region Functions


float3 ApplyInverseTonemap(float3 color, float2 uv)
{
	// Scaling down to LDR range to avoid NaN\Inf artifacts
	// It is scaled up again at the output.
	#if MAGIC_HDR_NITS_SCALING
		color /= (MaxNitsInverse*0.0125);
	#endif
	
	switch (InvTonemap)
	{
		case InvTonemap_Reinhard:
			color = Tonemap::Reinhard::Inverse(color);
			break;
		case InvTonemap_Reinhard2:
			color = Tonemap::Reinhard2::Inverse(color);
			break;
		case InvTonemap_Uncharted2Filmic:
			color = Tonemap::Uncharted2Filmic::Inverse(color);
			break;
		case InvTonemap_BakingLabACES:
			color = Tonemap::BakingLabACES::Inverse(color);
			break;
		case InvTonemap_Lottes:
			color = Tonemap::Lottes::Inverse(color);
			break;
		case InvTonemap_Lottes2:
			color = Tonemap::Lottes2::Inverse(color);
			break;
		case InvTonemap_NarkowiczACES:
			color = Tonemap::NarkowiczACES::Inverse(color);
			break;
		case InvTonemap_Unreal3:
			color = Tonemap::Unreal3::Inverse(color);
			break;
		case InvTonemap_Fallout4:
			color = Tonemap::Fallout4::Inverse(color);
			break;
		case InvTonemap_Frostbite:
			color = Tonemap::Frostbite::Inverse(color);
			break;
		case InvTonemap_Uchimura:
			color = Tonemap::Uchimura::Inverse(color);
			break;
		case InvTonemap_ReinhardJodie:
			color = Tonemap::ReinhardJodie::Inverse(color);
			break;
		case InvTonemap_iCAM06m:
			color = Tonemap::iCAM06m::Inverse(color);
			break;
		case InvTonemap_HuePreserving:
			color = Tonemap::HuePreserving::Inverse(color);
			break;
		case InvTonemap_Linear:
			color = Tonemap::Linear::Inverse(color);
			break;
		case InvTonemap_None:
			color = Tonemap::None::Inverse(color);
			break;
	}

	color /= exp(InputExposure);
	
	#if MAGIC_HDR_NITS_SCALING
		color *=(MaxNitsInverse*0.0125);
		color = clamp(color, 0.0, (MaxNitsInverse*0.0125));
	#endif
	
	return color;
}

float3 ApplyTonemap(float3 color, float2 uv)
{
	float exposure = exp(Exposure);

	#if MAGIC_HDR_ENABLE_ADAPTATION
		exposure /= tex2Dfetch(Adapt, 0).x;
	#endif

	#if MAGIC_HDR_NITS_SCALING
		color /= (MaxNitsApply*0.0125);
	#endif

	switch (Tonemap)
	{
		case Tonemap_Reinhard:
			color = Tonemap::Reinhard::Apply(color * exposure);
			break;
		case Tonemap_Reinhard2:
			color = Tonemap::Reinhard2::Apply(color * exposure);
			break;
		case Tonemap_Uncharted2Filmic:
			color = Tonemap::Uncharted2Filmic::Apply(color * exposure);
			break;
		case Tonemap_BakingLabACES:
			color = Tonemap::BakingLabACES::Apply(color * exposure);
			break;
		case Tonemap_Lottes:
			color = Tonemap::Lottes::Apply(color * exposure);
			break;
		case Tonemap_Lottes2:
			color = Tonemap::Lottes2::Apply(color * exposure);
			break;
		case Tonemap_NarkowiczACES:
			color = Tonemap::NarkowiczACES::Apply(color * exposure);
			break;
		case Tonemap_Unreal3:
			color = Tonemap::Unreal3::Apply(color * exposure);
			break;
		case Tonemap_Fallout4:
			color = Tonemap::Fallout4::Apply(color * exposure);
			break;
		case Tonemap_Frostbite:
			color = Tonemap::Frostbite::Apply(color * exposure);
			break;
		case Tonemap_Uchimura:
			color = Tonemap::Uchimura::Apply(color * exposure);
			break;
		case Tonemap_ReinhardJodie:
			color = Tonemap::ReinhardJodie::Apply(color * exposure);
			break;
		case Tonemap_iCAM06m:
			color = Tonemap::iCAM06m::Apply(color * exposure);
			break;
		case Tonemap_HuePreserving:
			color = Tonemap::HuePreserving::Apply(color * exposure);
			break;
		case Tonemap_Linear:
			color = Tonemap::Linear::Apply(color * exposure);
			break;
		case Tonemap_None:
			color = Tonemap::None::Apply(color * exposure);
			break;
	}
	
	#if MAGIC_HDR_NITS_SCALING
		color *=(MaxNitsApply*0.0125);
		color = clamp(color, 0.0, (MaxNitsApply*0.0125));
	#endif
	
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

#if MAGIC_HDR_ENABLE_ADAPTATION

float GetAdaptSensitivity()
{
	return log10(AdaptSensitivity + 1.0);
}

#endif

//#endregion

//#region Shaders

float4 InverseTonemapPS(
	float4 p : SV_POSITION,
	float2 uv : TEXCOORD) : SV_TARGET
{
	float4 color = tex2D(Color, uv);

	float saturation = BloomSaturation;

	color.rgb = ApplySaturation(color.rgb, saturation);
	
	#if MAGIC_HDR_SRGB_INPUT
		// Precise sRGB to Linear
		color.rgb = color.rgb * (color.rgb * (color.rgb * 0.305306011 + 0.682171111) + 0.012522878);
	#endif

	color.rgb = ApplyInverseTonemap(color.rgb, uv);

	// Thresholding
	#if MAGIC_HDR_ENABLE_BLOOM_CONTRAST > 0	
	color = (GetLumaLinear(color.rgb) > BloomContrast)
		? color
		: (color * BloomContrastSoft) * GetLumaLinear(color.rgb);
	#endif

	// Find the maximum component value (max of R, G, B)
    float maxComponent = max(max(color.r, color.g), color.b);

    // Boost only the maximum component to avoid color shifting
    color = color + (color * maxComponent * BloomMaximization);

	// TODO: Saturation and other color filtering options?
	if (BloomBrightnessMethod == 0)	
		color.rgb *= exp(BloomBrightness);
	else if (BloomBrightnessMethod == 1)
		color.rgb *= (BloomBrightness);
		
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

#if MAGIC_HDR_ENABLE_ADAPTATION

float4 CalcAdaptPS(
	float4 p : SV_POSITION,
	float2 uv : TEXCOORD) : SV_TARGET
{
	#if FXSHADERS_API_IS(FXSHADERS_API_OPENGL)
		float mip = FXSHADERS_GET_MAX_MIP(
			MAGIC_HDR_ADAPT_TEXTURE_RESOLUTION,
			MAGIC_HDR_ADAPT_TEXTURE_RESOLUTION);
	#else
		float mip = FXSHADERS_GET_MAX_MIP(
			BUFFER_WIDTH / 64,
			BUFFER_HEIGHT / 64);
	#endif

	mip *= AdaptPrecision;

	float3 color = tex2Dlod(Bloom6, float4(AdaptPoint, 0.0, mip)).rgb;
	float adapt = GetLumaLinear(color);

	// adapt = lerp(0.5, adapt, AdaptSensitivity);
	adapt *= GetAdaptSensitivity();

	float2 minMax = AdaptMinMax;
	minMax = (minMax.x > minMax.y) ? minMax.yx : minMax;

	adapt = clamp(adapt, max(minMax.x, 0.001), minMax.y);

	if (AdaptTime > 0.001)
	{
		float last = tex2Dfetch(LastAdapt, 0).x;
		float dt = FrameTime * 0.001;

		adapt = lerp(last, adapt, saturate(dt / max(AdaptTime, 0.001)));
	}

	return adapt;
}

float4 SaveAdaptPS(
	float4 p : SV_POSITION,
	float2 uv : TEXCOORD) : SV_TARGET
{
	return tex2Dfetch(Adapt, 0);
}

#endif

float4 TonemapPS(
	float4 p : SV_POSITION,
	float2 uv : TEXCOORD) : SV_TARGET
{
	#if MAGIC_HDR_ENABLE_ADAPTATION
		if (ShowAdapt)
		{
			float mip = FXSHADERS_GET_MAX_MIP(
				BUFFER_WIDTH / 64,
				BUFFER_HEIGHT / 64) * AdaptPrecision;

			float4 color = tex2Dlod(Bloom6, float4(uv, 0.0, mip));
			color.rgb *= GetAdaptSensitivity();
			//color.rgb = lerp(0.5, color.rgb, AdaptSensitivity);

			float2 res = GetResolution();
			float2 coord = uv * res;
			float2 pointPos = AdaptPoint * res;

			float4 pointColor = float4(1.0 - color.rgb, color.a);
			pointColor.rgb = (abs(pointColor.rgb - color.rgb) < 0.1)
				? pointColor.rgb * 1.5
				: pointColor.rgb;

			float4 rect = ConvertToRect(pointPos, AdaptFocusPointDebugSize);

			FillRect(color, coord, rect, pointColor);
			
			#if MAGIC_HDR_SRGB_OUTPUT
				// Precise Linear to sRGB
				color = max(1.055 * pow(color, 0.416666667) - 0.055, 0);
			#endif

			return color;
		}
	#endif

	float4 color = tex2D(Color, uv);
	float4 bloom = 0.0;
	
	if (TonemapBloomOnly)
	{
		bloom.rgb = ApplyInverseTonemap(bloom.rgb, uv);
	}
	else
	{
		color.rgb = ApplyInverseTonemap(color.rgb, uv);
	}

	float mean = 0.0;
	float variance = 0.0;	

	#if MAGIC_HDR_ENABLE_BLOOM_NORMALIZATION
		{

		mean = BlendingBase * 7;
		variance = BlendingAmount * 7;
	
		bloom =
			tex2D(Bloom0, uv) * NormalDistribution(1, mean, variance) +
			tex2D(Bloom1, uv) * NormalDistribution(2, mean, variance) +
			tex2D(Bloom2, uv) * NormalDistribution(3, mean, variance) +
			tex2D(Bloom3, uv) * NormalDistribution(4, mean, variance) +
			tex2D(Bloom4, uv) * NormalDistribution(5, mean, variance) +
			tex2D(Bloom5, uv) * NormalDistribution(6, mean, variance) +
			tex2D(Bloom6, uv) * NormalDistribution(7, mean, variance);
	
		bloom /= 7;
		}		
	#else 	
		{		
		bloom =
			tex2D(Bloom0, uv) +
			tex2D(Bloom1, uv) +
			tex2D(Bloom2, uv) +
			tex2D(Bloom3, uv) +
			tex2D(Bloom4, uv) +
			tex2D(Bloom5, uv) +
			tex2D(Bloom6, uv);
		bloom /= 7;
		}
	#endif	
	
	if (BlendingType == Overlay)	
	{
	color.rgb = ShowBloom
		? bloom.rgb
		: lerp(color.rgb, bloom.rgb, log10(BloomAmount + 1.0));
	}
	
	else if (BlendingType == Additive)	
	{
	color.rgb = ShowBloom
		? bloom.rgb
		: color.rgb + (bloom.rgb * BloomAmount);
	}
	
	if (TonemapBloomOnly)
	{
		bloom.rgb = ApplyTonemap(bloom.rgb, uv);
	}
	else
	{
		color.rgb = ApplyTonemap(color.rgb, uv);
	}	

	#if MAGIC_HDR_SRGB_OUTPUT
		// Precise Linear to sRGB
		color.rgb = max(1.055 * pow(color.rgb, 0.416666667) - 0.055, 0);
	#endif

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

	#if MAGIC_HDR_ENABLE_ADAPTATION
		pass CalcAdapt
		{
			VertexShader = ScreenVS;
			PixelShader = CalcAdaptPS;
			RenderTarget = AdaptTex;
		}
		pass SaveAdapt
		{
			VertexShader = ScreenVS;
			PixelShader = SaveAdaptPS;
			RenderTarget = LastAdaptTex;
		}
	#endif

	pass Tonemap
	{
		VertexShader = ScreenVS;
		PixelShader = TonemapPS;		
	}
}

//#endregion

} // Namespace.

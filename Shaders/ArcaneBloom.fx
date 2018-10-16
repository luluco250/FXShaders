#include "ArcaneBloom.fxh"
#include "ReShade.fxh"

// Would be unenecessary if we had "using namespace".
namespace ArcaneBloom { namespace _ {

  //========//
 // Macros //
//========//

#define NONE 0
#define SRGB 1
#define CUSTOM 2

#ifndef ARCANE_BLOOM_USE_DIRT
#define ARCANE_BLOOM_USE_DIRT 0
#endif

#ifndef ARCANE_BLOOM_USE_CUSTOM_DISTRIBUTION
#define ARCANE_BLOOM_USE_CUSTOM_DISTRIBUTION 0
#endif

#ifndef ARCANE_BLOOM_NORMALIZE_BRIGHTNESS
#define ARCANE_BLOOM_NORMALIZE_BRIGHTNESS 1
#endif

#ifndef ARCANE_BLOOM_USE_TEMPERATURE
#define ARCANE_BLOOM_USE_TEMPERATURE 0
#endif

#ifndef ARCANE_BLOOM_USE_SATURATION
#define ARCANE_BLOOM_USE_SATURATION 0
#endif

#ifndef ARCANE_BLOOM_PRECISION_FIX
#define ARCANE_BLOOM_PRECISION_FIX 0
#endif

#ifndef ARCANE_BLOOM_WHITE_POINT_FIX
#define ARCANE_BLOOM_WHITE_POINT_FIX 0
#endif

#ifndef ARCANE_BLOOM_GAMMA_MODE
#define ARCANE_BLOOM_GAMMA_MODE SRGB
#endif

#ifndef ARCANE_BLOOM_DEBUG
#define ARCANE_BLOOM_DEBUG 0
#endif

#define MAKE_SHADER(NAME) \
float4 PS_##NAME( \
	float4 position : SV_POSITION, \
	float2 uv       : TEXCOORD \
) : SV_TARGET

#define MAKE_PASS(NAME, DEST) \
pass NAME { \
	VertexShader = PostProcessVS; \
	PixelShader  = PS_##NAME; \
	RenderTarget = tArcaneBloom_##DEST; \
}

#define DEF_BLOOM_TEX(NAME, DIV) \
texture2D tArcaneBloom_##NAME { \
	Width  = BUFFER_WIDTH / DIV; \
	Height = BUFFER_HEIGHT / DIV; \
	Format = RGBA16F; \
}; \
sampler2D s##NAME { \
	Texture = tArcaneBloom_##NAME; \
}

#define DEF_DOWN_SHADER(NAME, DIV) \
MAKE_SHADER(DownSample_##NAME) { \
	return float4(box_blur(s##NAME, uv, ReShade::PixelSize * DIV), 1.0); \
}

#define DEF_DOWN_PASS(SOURCE, DEST) \
MAKE_PASS(DownSample_##SOURCE, DEST)

#define DEF_BLUR_SHADER(A, B, DIV) \
MAKE_SHADER(BlurX_##A) { \
	float2 dir = float2(BUFFER_RCP_WIDTH * DIV, 0.0); \
	return float4(gaussian_blur(s##A, uv, dir), 1.0); \
} \
MAKE_SHADER(BlurY_##B) { \
	float2 dir = float2(0.0, BUFFER_RCP_HEIGHT * DIV); \
	return float4(gaussian_blur(s##B, uv, dir), 1.0); \
}

#define DEF_BLUR_PASS(A, B) \
MAKE_PASS(BlurX_##A, B) \
MAKE_PASS(BlurY_##B, A) \
MAKE_PASS(BlurX_##A, B) \
MAKE_PASS(BlurY_##B, A)

  //==========//
 // Uniforms //
//==========//

uniform float uBloomIntensity <
	ui_label   = "Bloom Intensity";
	ui_tooltip = "Default: 1.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 100.0;
	ui_step    = 0.01;
> = 1.0;

#if ARCANE_BLOOM_USE_DIRT

uniform float uDirtIntensity <
	ui_label = "Dirt Intensity";
	ui_tooltip = "Default: 1.0";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 100.0;
	ui_step = 0.01;
> = 1.0;

#endif

#if ARCANE_BLOOM_USE_TEMPERATURE

uniform float uBloomTemperature <
	ui_label = "Bloom Temperature";
	ui_tooltip = "Default: 1.0";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 3.0;
	ui_step = 0.001;
> = 1.0;

#endif

#if ARCANE_BLOOM_USE_SATURATION

uniform float uBloomSaturation <
	ui_label = "Bloom Saturation";
	ui_tooltip = "Default: 1.0";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 3.0;
	ui_step = 0.001;
> = 1.0;

#endif

uniform float uExposure <
	ui_label   = "Exposure";
	ui_tooltip = "Default: 1.0";
	ui_type    = "drag";
	ui_min     = 0.001;
	ui_max     = 3.0;
	ui_step    = 0.001;
> = 1.0;

#if ARCANE_BLOOM_USE_ADAPTATION

uniform float uAdapt_Intensity <
	ui_label   = "Adaptation Intensity";
	ui_tooltip = "Default: 1.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = 1.0;

uniform float uAdapt_Time <
	ui_label   = "Adaptation Time (Seconds)";
	ui_tooltip = "Default: 100.0";
	ui_type    = "drag";
	ui_min     = 0.01;
	ui_max     = 10.0;
	ui_step    = 0.01;
> = 1.0;

uniform float uAdapt_Sensitivity <
	ui_label   = "Adaptation Sensitivity";
	ui_tooltip = "Default: 1.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 3.0;
	ui_step    = 0.001;
> = 1.0;

uniform int uAdapt_Precision <
	ui_label   = "Adaptation Precision";
	ui_tooltip = "Default: 0";
	ui_type    = "drag";
	ui_min     = 0;
	ui_max     = 11;
	ui_step    = 0.01;
> = 0;

uniform bool uAdapt_DoLimits <
	ui_label   = "Limit Adaptation?";
	ui_tooltip = "Default: On";
> = true;

uniform float2 uAdapt_Limits <
	ui_label   = "Adaptation Limits (Min/Max)";
	ui_tooltip = "Default: (0.0, 1.0)";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = float2(0.0, 1.0);

#endif

#if ARCANE_BLOOM_USE_CUSTOM_DISTRIBUTION

uniform float uMean <
	ui_label = "Distribution Mean";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 100.0;
	ui_step = 0.01;
> = 0.0;

uniform float uVariance <
	ui_label = "Distribution Variance";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 100.0;
	ui_step = 0.01;
> = 1.0;

#endif

uniform float uMaxBrightness <
	ui_label   = "Max Brightness";
	ui_tooltip = "Default: 100.0";
	ui_type    = "drag";
	ui_min     = 1.0;
	ui_max     = 100.0;
	ui_step    = 0.1;
> = 100.0;

#if ARCANE_BLOOM_WHITE_POINT_FIX

uniform float uWhitePoint <
	ui_label = "White Point";
	ui_tooltip = "Default: 1.0";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.01;
> = 1.0;

#endif

#if ARCANE_BLOOM_GAMMA_MODE == CUSTOM
uniform float uGamma <
	ui_label   = "Gamma";
	ui_tooltip = "Default: 2.2";
	ui_type    = "drag";
	ui_min     = 0.4545;
	ui_max     = 6.6;
	ui_step    = 0.001;
> = 2.2;
#endif

uniform float uTime <source = "timer";>;
uniform float uFrameTime <source = "frametime";>;

  //==========//
 // Textures //
//==========//

sampler2D sBackBuffer {
	Texture     = ReShade::BackBufferTex;
	#if ARCANE_BLOOM_GAMMA_MODE == SRGB
	SRGBTexture = true;
	#endif
};

DEF_BLOOM_TEX(Bloom0Alt, 2);
DEF_BLOOM_TEX(Bloom1Alt, 4);
DEF_BLOOM_TEX(Bloom2Alt, 8);
DEF_BLOOM_TEX(Bloom3Alt, 16);
DEF_BLOOM_TEX(Bloom4Alt, 32);
DEF_BLOOM_TEX(Bloom5Alt, 64);

#if ARCANE_BLOOM_USE_ADAPTATION
texture2D tArcaneBloom_Small {
	Width     = 1024;
	Height    = 1024;
	Format    = R32F;
	MipLevels = 11;
};
sampler2D sSmall {
	Texture = tArcaneBloom_Small;
};

texture2D tArcaneBloom_LastAdapt {
	Format = R32F;
};
sampler2D sLastAdapt {
	Texture   = tArcaneBloom_LastAdapt;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU  = CLAMP;
	AddressV  = CLAMP;
	AddressW  = CLAMP;
};
#endif

#if ARCANE_BLOOM_USE_DIRT

texture2D tArcaneBloom_Dirt <
	source = "ArcaneBloom_Dirt.png";
> {
	Width = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
};
sampler2D sDirt {
	Texture = tArcaneBloom_Dirt;
	SRGBTexture = true;
};

#endif

  //===========//
 // Functions //
//===========//

float get_bloom_weight(int i) {
	#if !ARCANE_BLOOM_USE_CUSTOM_DISTRIBUTION
	return 1.0;
	#else
	return normal_distribution(i, uMean, uVariance);
	#endif
}

float3 blend_overlay(float3 a, float3 b, float w) {
	float3 c = lerp(
		2.0 * a * b,
		1.0 - 2.0 * (1.0 - a) * (1.0 - b),
		step(0.5, a)
	);
	return lerp(a, c, w);
}

#if ARCANE_BLOOM_USE_DIRT

float3 apply_dirt(float3 bloom, float2 uv) {
	float3 dirt = tex2D(sDirt, uv).rgb;
	//return blend_overlay(bloom, dirt, uDirtIntensity);

	return lerp(bloom, mad(bloom, dirt, bloom), uDirtIntensity);
}

#endif

  //=========//
 // Shaders //
//=========//

MAKE_SHADER(GetHDR) {
	float3 color = tex2D(sBackBuffer, uv).rgb;

	#if ARCANE_BLOOM_GAMMA_MODE == CUSTOM
	color = pow(color, uGamma);
	#endif

	#if ARCANE_BLOOM_USE_TEMPERATURE
	color = lerp(color, color * color * color, uBloomTemperature);
	#endif

	#if ARCANE_BLOOM_USE_SATURATION
	color = lerp(get_luma_linear(color), color, uBloomSaturation);
	#endif

	#if ARCANE_BLOOM_PRECISION_FIX
	color = clamp(color, 0.0, 32767.0);
	#endif

	color = inv_reinhard_lum(color, 1.0 / uMaxBrightness);
	return float4(color, 1.0);
}

#if ARCANE_BLOOM_USE_ADAPTATION

MAKE_SHADER(GetSmall) {
	float3 color = tex2D(sBloom0Alt, uv).rgb;
	return float4(get_luma_linear(color), 0.0, 0.0, 1.0);
}

MAKE_SHADER(GetAdapt) {
	float adapt = tex2Dlod(sSmall, float4(uv, 0, 11 - uAdapt_Precision)).x;
	adapt *= uAdapt_Sensitivity;
	
	if (uAdapt_DoLimits)
		adapt = clamp(adapt, uAdapt_Limits.x, uAdapt_Limits.y);
	
	float last = tex2D(sLastAdapt, 0).x;
	adapt = lerp(last, adapt, (uFrameTime * 0.001) / uAdapt_Time);

	return float4(adapt, 0.0, 0.0, 1.0);
}

MAKE_SHADER(SaveAdapt) {
	return tex2D(sAdapt, 0);
}

#endif

DEF_DOWN_SHADER(Bloom0Alt, 2)
DEF_BLUR_SHADER(Bloom0, Bloom0Alt, 2 * 0.333)

DEF_DOWN_SHADER(Bloom0, 4)
DEF_BLUR_SHADER(Bloom1, Bloom1Alt, 4 * 0.666)

DEF_DOWN_SHADER(Bloom1, 8)
DEF_BLUR_SHADER(Bloom2, Bloom2Alt, 8 * 0.999)

DEF_DOWN_SHADER(Bloom2, 16)
DEF_BLUR_SHADER(Bloom3, Bloom3Alt, 16 * 1.0)

DEF_DOWN_SHADER(Bloom3, 32)
DEF_BLUR_SHADER(Bloom4, Bloom4Alt, 32 * 1.0)

DEF_DOWN_SHADER(Bloom4, 64)
DEF_BLUR_SHADER(Bloom5, Bloom5Alt, 64 * 1.0)

MAKE_SHADER(Blend) {
	float3 color = tex2D(sBackBuffer, uv).rgb;
	color = inv_reinhard(color, 1.0 / uMaxBrightness);
	
	float3 bloom = tex2D(sBloom0, uv).rgb * get_bloom_weight(0)
	             + tex2D(sBloom1, uv).rgb * get_bloom_weight(1)
				 + tex2D(sBloom2, uv).rgb * get_bloom_weight(2)
				 + tex2D(sBloom3, uv).rgb * get_bloom_weight(3)
				 + tex2D(sBloom4, uv).rgb * get_bloom_weight(4)
				 + tex2D(sBloom5, uv).rgb * get_bloom_weight(5);
	
	#if ARCANE_BLOOM_USE_DIRT
	bloom = apply_dirt(bloom, uv);
	#endif

	#if ARCANE_BLOOM_NORMALIZE_BRIGHTNESS
	color += bloom * uBloomIntensity / uMaxBrightness;
	#else
	color += bloom * uBloomIntensity;
	#endif

	#if ARCANE_BLOOM_USE_ADAPTATION
	//float adapt = tex2Dfetch(sAdapt, (int4)0).x;
	float adapt = tex2D(sAdapt, 0).x;
	float exposure = uExposure / max(adapt, 0.001);

	color *= lerp(1.0, exposure, uAdapt_Intensity);
	
	#if ARCANE_BLOOM_WHITE_POINT_FIX
	float white = uWhitePoint * lerp(1.0, exposure, uAdapt_Intensity);
	#endif

	#else
	color *= uExposure;

	#if ARCANE_BLOOM_WHITE_POINT_FIX
	float white = uWhitePoint * uExposure;
	#endif

	#endif

	color = reinhard(color);

	#if ARCANE_BLOOM_WHITE_POINT_FIX
	color /= reinhard(white);
	#endif

	#if ARCANE_BLOOM_GAMMA_MODE == CUSTOM
	color = pow(color, 1.0 / uGamma);
	#endif

	return float4(color, 1.0);
}

#if ARCANE_BLOOM_DEBUG

MAKE_SHADER(DisplayTexture) {
	float3 bloom = tex2D(sBloom0, uv).rgb * get_bloom_weight(0)
	             + tex2D(sBloom1, uv).rgb * get_bloom_weight(1)
				 + tex2D(sBloom2, uv).rgb * get_bloom_weight(2)
				 + tex2D(sBloom3, uv).rgb * get_bloom_weight(3)
				 + tex2D(sBloom4, uv).rgb * get_bloom_weight(4)
				 + tex2D(sBloom5, uv).rgb * get_bloom_weight(5);
	
	#if ARCANE_BLOOM_USE_DIRT
	bloom = apply_dirt(bloom, uv);
	#endif
	
	#if ARCANE_BLOOM_NORMALIZE_BRIGHTNESS
	bloom = bloom * uBloomIntensity / uMaxBrightness;
	#else
	bloom = bloom * uBloomIntensity;
	#endif

	#if ARCANE_BLOOM_USE_ADAPTATION
	//float adapt = tex2Dfetch(sAdapt, (int4)0).x;
	float adapt = tex2D(sAdapt, 0).x;
	float exposure = uExposure / max(adapt, 0.001);

	bloom *= lerp(1.0, exposure, uAdapt_Intensity);
	
	#if ARCANE_BLOOM_WHITE_POINT_FIX
	float white = uWhitePoint * lerp(1.0, exposure, uAdapt_Intensity);
	#endif

	#else
	bloom *= uExposure;

	#if ARCANE_BLOOM_WHITE_POINT_FIX
	float white = uWhitePoint * uExposure;
	#endif

	#endif

	bloom = reinhard(bloom);

	#if ARCANE_BLOOM_WHITE_POINT_FIX
	bloom /= reinhard(white);
	#endif

	return float4(bloom, 1.0);
}

#endif

  //============//
 // Techniques //
//============//

technique ArcaneBloom {
	MAKE_PASS(GetHDR, Bloom0Alt)

	#if ARCANE_BLOOM_USE_ADAPTATION
	MAKE_PASS(GetSmall, Small)
	MAKE_PASS(GetAdapt, Adapt)
	MAKE_PASS(SaveAdapt, LastAdapt)
	#endif

	DEF_DOWN_PASS(Bloom0Alt, Bloom0)
	DEF_BLUR_PASS(Bloom0, Bloom0Alt)

	DEF_DOWN_PASS(Bloom0, Bloom1)
	DEF_BLUR_PASS(Bloom1, Bloom1Alt)

	DEF_DOWN_PASS(Bloom1, Bloom2)
	DEF_BLUR_PASS(Bloom2, Bloom2Alt)

	DEF_DOWN_PASS(Bloom2, Bloom3)
	DEF_BLUR_PASS(Bloom3, Bloom3Alt)

	DEF_DOWN_PASS(Bloom3, Bloom4)
	DEF_BLUR_PASS(Bloom4, Bloom4Alt)

	DEF_DOWN_PASS(Bloom4, Bloom5)
	DEF_BLUR_PASS(Bloom5, Bloom5Alt)

	pass Blend {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_Blend;
		#if ARCANE_BLOOM_GAMMA_MODE == SRGB
		SRGBWriteEnable = true;
		#endif
	}
}

#if ARCANE_BLOOM_DEBUG

technique ArcaneBloom_DisplayTexture {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_DisplayTexture;
	}
}

#endif

}}

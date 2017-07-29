#include "ReShade.fxh"

//Macros//////////////////////////////////////////////////////////////////////////////////////

#ifndef MAGICBLOOM_SAMPLES
#define MAGICBLOOM_SAMPLES 5
#endif

#ifndef MAGICBLOOM_NOADAPT
#define MAGICBLOOM_NOADAPT 0
#endif

#ifndef MAGICBLOOM_ADAPTRES
#define MAGICBLOOM_ADAPTRES 256
#endif

#define BLUR_SCALE_1 2
#define BLUR_SCALE_2 4
#define BLUR_SCALE_3 8
#define BLUR_SCALE_4 16
#define BLUR_SCALE_5 32
#define BLUR_SCALE_6 64
#define BLUR_SCALE_7 128
#define BLUR_SCALE_8 256
#define BLUR_SCALE_9 512

#define DEF_BLOOM_TEX(N) \
texture tMagicBloom_Blur##N { Width = BUFFER_WIDTH / BLUR_SCALE_##N; Height = BUFFER_HEIGHT / BLUR_SCALE_##N; Format = RGBA16F; }; \
sampler sMagicBloom_Blur##N { Texture = tMagicBloom_Blur##N; };

#define DEF_BLOOM_SHADER(PREV, NEXT) \
float4 PS_Blur##NEXT(float4 pos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {\
	return float4(blur(sMagicBloom_##PREV, uv, BLUR_SCALE_##NEXT), 1.0);\
}

#define DEF_BLOOM_PASS(N) \
pass Blur##N {\
	VertexShader = PostProcessVS;\
	PixelShader = PS_Blur##N;\
	RenderTarget = tMagicBloom_Blur##N;\
}

//Statics/////////////////////////////////////////////////////////////////////////////////////

static const float pi = atan(1.0) * 4.0;
static const int samples = MAGICBLOOM_SAMPLES;
static const float sigma = 1.0;
static const int lowest_mip = int(log(MAGICBLOOM_ADAPTRES) / log(2)) + 1;

//Uniforms////////////////////////////////////////////////////////////////////////////////////

uniform float fBloom_Intensity <
	ui_label = "Bloom Intensity";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;

uniform float fExposure <
	ui_label = "Exposure";
	ui_type = "drag";
	ui_min = 0.001;
	ui_max = 3.0;
	ui_step = 0.01;
> = 1.0;

#if !MAGICBLOOM_NOADAPT

uniform float fAdapt_Speed <
	ui_label = "Adaptation Speed";
	ui_type = "drag";
	ui_min = 0.001;
	ui_max = 1.0;
	ui_step = 0.001;
> = 0.01;

uniform float fAdapt_Sensitivity <
	ui_label = "Adaptation Sensitivity";
	ui_type = "drag";
	ui_min = 0.001;
	ui_max = 3.0;
	ui_step = 0.001;
> = 1.0;

uniform int iAdapt_Precision <
	ui_label = "Adaptation Precision";
	ui_type = "drag";
	ui_min = 0;
	ui_max = lowest_mip;
	ui_step = 0.1;
> = 0;

uniform uint uiAdapt_Formula <
	ui_label = "Adaptation Formula";
	ui_type = "combo";
	ui_items = "Luminance\0Average\0Luma\0Luma (Linear)\0Magnitude\0";
> = 2;

uniform uint uiAdapt_Mode <
	ui_label = "Adaptation Mode";
	ui_type = "combo";
	ui_items = "Disabled\0Adapt Full Image\0Adapt Only Bloom\0";
> = 1;

#endif

uniform float fMaxBrightness <
	ui_label = "Max Brightness";
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = 1000.0;
	ui_step = 1.0;
> = 100.0;

uniform uint uiTonemapper <
	ui_label = "Tonemapper";
	ui_type = "combo";
	ui_items = "Pow\0Reinhard\0";
> = 0;

uniform bool bShowTexture <
	ui_label = "Show Texture";
> = false;

//Textures////////////////////////////////////////////////////////////////////////////////////

#if !MAGICBLOOM_NOADAPT

texture tMagicBloom_Small { Width = MAGICBLOOM_ADAPTRES; Height = MAGICBLOOM_ADAPTRES; Format = R16F; MipLevels = lowest_mip; };
sampler sMagicBloom_Small { Texture = tMagicBloom_Small; };

texture tMagicBloom_Adapt { Format = R16F; };
sampler sMagicBloom_Adapt { Texture = tMagicBloom_Adapt; };

texture tMagicBloom_Last { Format = R16F; };
sampler sMagicBloom_Last { Texture = tMagicBloom_Last; };

#endif

texture tMagicBloom_HDR { Width = BUFFER_WIDTH; Height = BUFFER_HEIGHT; Format = RGBA16F; };
sampler sMagicBloom_HDR { Texture = tMagicBloom_HDR; };

DEF_BLOOM_TEX(1)
DEF_BLOOM_TEX(2)
DEF_BLOOM_TEX(3)
DEF_BLOOM_TEX(4)
DEF_BLOOM_TEX(5)
DEF_BLOOM_TEX(6)
DEF_BLOOM_TEX(7)
DEF_BLOOM_TEX(8)
DEF_BLOOM_TEX(9)

//Functions///////////////////////////////////////////////////////////////////////////////////

float4 _tex2D(sampler sp, float2 uv) {
	return tex2Dlod(sp, float4(uv, 0.0, 0.0));
}

float3 nozero(float3 f) {
	return max(f, 1.0 / fMaxBrightness);
}

float gaussian(float2 i) {
	return (1.0 / (2.0 * pi * sigma * sigma)) * exp(-((i.x * i.x + i.y * i.y) / (2.0 * sigma * sigma)));
}

float3 blur(sampler sp, float2 uv, float2 scale) {
	float2 ps = ReShade::PixelSize * scale;

	float3 col = 0.0;
	float2 offset = 0.0;
	float weight = 0.0;
	float accum = 0.0;

	[unroll]
	for (int x = -samples / 2; x <= samples / 2; ++x) {
		[unroll]
		for (int y = -samples / 2; y <= samples / 2; ++y) {
			offset = float2(x, y);// - samples * 0.5;
			weight = gaussian(offset);
			col += _tex2D(sp, uv + ps * offset).rgb * weight;
			accum += weight;
		}
	}

	return col / accum;
}

float get_value(float3 col) {
	if (uiAdapt_Formula == 0)      //Luminance
		return max(col.r, max(col.g, col.b));
	else if (uiAdapt_Formula == 1) //Average
		return dot(col, 0.333);
	else if (uiAdapt_Formula == 2) //Luma
		return dot(col, float3(0.299, 0.587, 0.114));
	else if (uiAdapt_Formula == 3) //Luma (Linear)
		return dot(col, float3(0.2126, 0.7152, 0.0722));
	else if (uiAdapt_Formula == 4) //Magnitude
		return length(col);
	else
		return 0.0;
}

float3 i_reinhard(float3 col) {
	return (col / nozero(1.0 - col));
}

float3 t_reinhard(float3 col, float exposure) {
	col *= exposure;
	return col / (1.0 + col);
}

//Shaders/////////////////////////////////////////////////////////////////////////////////////

float4 PS_GetHDR(
	float4 pos : SV_POSITION,
	float2 uv : TEXCOORD
) : SV_TARGET {
	float3 col = tex2D(ReShade::BackBuffer, uv).rgb;

	if (uiTonemapper == 0)
		col = pow(col, fExposure);
	else if (uiTonemapper == 1)
		col = i_reinhard(col);

	return float4(col, 1.0);
}

float PS_GetSmall(
	float4 pos : SV_POSITION,
	float2 uv : TEXCOORD
) : SV_TARGET {
	float3 col = tex2D(sMagicBloom_HDR, uv).rgb;
	return get_value(col);
}

float PS_GetAdapt(
	float4 pos : SV_POSITION,
	float2 uv : TEXCOORD
) : SV_TARGET {
	float adapt = tex2Dlod(sMagicBloom_Small, float4(uv, 0.0, lowest_mip - iAdapt_Precision)).x;
	float last = tex2D(sMagicBloom_Last, uv).x;

	adapt *= fAdapt_Sensitivity;

	return lerp(last, adapt, fAdapt_Speed);
}

float PS_SaveAdapt(
	float4 pos : SV_POSITION,
	float2 uv : TEXCOORD
) : SV_TARGET {
	return tex2D(sMagicBloom_Adapt, uv).x;
}

DEF_BLOOM_SHADER(HDR, 1)
DEF_BLOOM_SHADER(Blur1, 2)
DEF_BLOOM_SHADER(Blur2, 3)
DEF_BLOOM_SHADER(Blur3, 4)
DEF_BLOOM_SHADER(Blur4, 5)
DEF_BLOOM_SHADER(Blur5, 6)
DEF_BLOOM_SHADER(Blur6, 7)
DEF_BLOOM_SHADER(Blur7, 8)
DEF_BLOOM_SHADER(Blur8, 9)

float4 PS_Blend(
	float4 pos : SV_POSITION,
	float2 uv : TEXCOORD
) : SV_TARGET {
	float3 col = tex2D(sMagicBloom_HDR, uv).rgb;
	float3 bloom = tex2D(sMagicBloom_Blur1, uv).rgb
	             + tex2D(sMagicBloom_Blur2, uv).rgb
				 + tex2D(sMagicBloom_Blur3, uv).rgb
				 + tex2D(sMagicBloom_Blur4, uv).rgb
				 + tex2D(sMagicBloom_Blur5, uv).rgb
				 + tex2D(sMagicBloom_Blur6, uv).rgb
				 + tex2D(sMagicBloom_Blur7, uv).rgb
				 + tex2D(sMagicBloom_Blur8, uv).rgb
				 + tex2D(sMagicBloom_Blur9, uv).rgb;
	bloom /= 9.0;

	#if !MAGICBLOOM_NOADAPT
	float exposure = fExposure / tex2D(sMagicBloom_Adapt, uv).x;
	#else
	float exposure = fExposure;
	#endif

	if (uiAdapt_Mode == 0)
		exposure = 1.0;
	else if (uiAdapt_Mode == 2) {
		bloom *= exposure;
		exposure = 1.0;
	}

	col = bShowTexture ? bloom : col + bloom * fBloom_Intensity;

	if (uiTonemapper == 0)
		col = pow(col, 1.0 / exposure);
	else if (uiTonemapper == 1)
		col = t_reinhard(col, exposure);
	
	return float4(col, 1.0);
}

//Technique///////////////////////////////////////////////////////////////////////////////////

technique MagicBloom_HDR {
	pass GetHDR {
		VertexShader = PostProcessVS;
		PixelShader = PS_GetHDR;
		RenderTarget = tMagicBloom_HDR;
	}
	pass GetSmall {
		VertexShader = PostProcessVS;
		PixelShader = PS_GetSmall;
		RenderTarget = tMagicBloom_Small;
	}
	pass GetAdapt {
		VertexShader = PostProcessVS;
		PixelShader = PS_GetAdapt;
		RenderTarget = tMagicBloom_Adapt;
	}
	pass SaveAdapt {
		VertexShader = PostProcessVS;
		PixelShader = PS_SaveAdapt;
		RenderTarget = tMagicBloom_Last;
	}
	DEF_BLOOM_PASS(1)
	DEF_BLOOM_PASS(2)
	DEF_BLOOM_PASS(3)
	DEF_BLOOM_PASS(4)
	DEF_BLOOM_PASS(5)
	DEF_BLOOM_PASS(6)
	DEF_BLOOM_PASS(7)
	DEF_BLOOM_PASS(8)
	pass Blend {
		VertexShader = PostProcessVS;
		PixelShader = PS_Blend;
	}
}

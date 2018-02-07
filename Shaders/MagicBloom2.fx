/*	             __     __       _____      _______   ______    _______
	            /  \   /  \     /  _  \    /  _____\ |_    _|  /  _____\
	           /    \_/    \   /  /_\  \  /  / ____    |  |   /  /
	          /   /\   /\   \ /  _____  \ \  \___\ \  _|  |_  \  \_____
	          \__/  \_/  \__/ \_/     \_/  \_______/ |______|  \_______/
	 _______    __       _______     _______      __     __        ______   ______
	|   __  \  |  |     /  ___  \   /  ___  \    /  \   /  \      |_    _| |_    _|
	|  |__) /  |  |    /  /   \  \ /  /   \  \  /    \_/    \       |  |     |  |
	|  |__)  \ |  |___ \  \___/  / \  \___/  / /   /\   /\   \     _|  |_   _|  |_
	|________/ |______| \_______/   \_______/  \__/  \_/  \__/    |______| |______|
	                                                          by luluco250

	Copyright (c) 2017 Lucas Melo

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/

#include "ReShade.fxh"

//Macros////////////////////////////////////////////////////////////////////////////////////////////////////

#ifndef MAGICBLOOM2_DEBUG
#define MAGICBLOOM2_DEBUG 0
#endif

#ifndef MAGICBLOOM2_BLURSAMPLES
#define MAGICBLOOM2_BLURSAMPLES 21
#endif

#ifndef MAGICBLOOM2_TWOPASS_BLUR
#define MAGICBLOOM2_TWOPASS_BLUR 1
#endif

#ifndef MAGICBLOOM2_NOADAPT
#define MAGICBLOOM2_NOADAPT 0
#endif

#ifndef MAGICBLOOM2_ADAPT_NODELAY
#define MAGICBLOOM2_ADAPT_NODELAY 0
#endif

#ifndef MAGICBLOOM2_NODIRT
#define MAGICBLOOM2_NODIRT 0
#endif

#ifndef MAGICBLOOM2_NOTHRESHOLD
#define MAGICBLOOM2_NOTHRESHOLD 0
#endif

#define NONE 0
#define CUSTOM 1
#define SRGB 2

#ifndef MAGICBLOOM2_CURVE
#define MAGICBLOOM2_CURVE SRGB
#endif

#define _tex2D(sp, uv) tex2Dlod(sp, float4(uv, 0.0, 0.0))
#define pow2(x) (x * x)

//Constants/////////////////////////////////////////////////////////////////////////////////////////////////

static const float pi = 3.1415926535897932384626433832795;
static const float2 pad = ReShade::PixelSize * 25.0;
#if BUFFER_WIDTH > BUFFER_HEIGHT
static const int max_mip = int(log(BUFFER_WIDTH) / log(2)) + 1;
#else
static const int max_mip = int(log(BUFFER_HEIGHT) / log(2)) + 1;
#endif
static const int max_steps = 8;

//Uniforms//////////////////////////////////////////////////////////////////////////////////////////////////

uniform float fBloom_Intensity <
	ui_label = "Bloom Intensity";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 1.0;
	ui_step  = 0.001;
> = 1.0;

#if !MAGICBLOOM2_NOTHRESHOLD
uniform float fBloom_Threshold <
	ui_label = "Bloom Threshold";
	ui_type  = "drag";
	ui_min   = 1.0;
	ui_max   = 10.0;
	ui_step  = 0.001;
> = 1.0;
#endif

#if MAGICBLOOM2_CURVE == CUSTOM
uniform float fBloom_Curve <
	ui_label = "Bloom Curve";
	ui_type  = "drag";
	ui_min   = 1.0;
	ui_max   = 10.0;
	ui_step = 0.001;
> = 2.2;
#endif

#if !MAGICBLOOM2_NODIRT
uniform float fDirt_Intensity <
	ui_label = "Dirt Intensity";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 3.0;
	ui_step  = 0.001;
> = 0.0;
#endif

#if !MAGICBLOOM2_NOADAPT
uniform float fAdapt_Exposure <
	ui_label = "Adaptation Exposure";
	ui_type  = "drag";
	ui_min   = 0.001;
	ui_max   = 10.0;
	ui_step  = 0.001;
> = 1.0;

#if !MAGICBLOOM2_ADAPT_NODELAY
uniform float fAdapt_Delay <
	ui_label = "Adaptation Delay (Seconds)";
	ui_type  = "drag";
	ui_min   = 0.001;
	ui_max   = 20.0;
	ui_step  = 0.001;
> = 1.0;
#endif

uniform float fAdapt_Sensitivity <
	ui_label = "Adaptation Sensitivity";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 10.0;
	ui_step  = 0.001;
> = 1.0;

uniform bool bAdapt_DoLimit <
	ui_label = "Limit Adaptation";
> = true;

uniform float2 f2Adapt_MinMax <
	ui_label = "Adaptation Min/Max Limits";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 10.0;
	ui_step  = 0.001;
> = float2(0.0, 1.0);

uniform float fAdapt_Precision <
	ui_label = "Adaptation Precision";
	ui_type  = "drag";
	ui_min   = 0;
	ui_max   = max_mip;
	ui_step  = 0.01;
> = 0;

uniform int iAdapt_Mode <
	ui_label = "Adaptation Mode";
	ui_type  = "combo";
	ui_items = "Disabled\0Adapt Final Image\0Adapt Only Bloom\0";
> = 1;
#endif

uniform float fMaxBrightness <
	ui_label = "Max Brightness";
	ui_type  = "drag";
	ui_min   = 1.0;
	ui_max   = 1000.0;
	ui_step  = 1.0;
> = 10.0;

uniform float fBlur_Sigma <
	ui_label = "Blur Sigma";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 100.0;
	ui_step  = 0.001;
> = 4.0;

#if MAGICBLOOM2_DEBUG
uniform int iDebug <
	ui_label = "Debug Options";
	ui_type  = "combo";
	ui_items = "None\0Show Bloom Texture\0Show Unscaled Textures\0";
> = 0;
#endif

uniform float fDeltaTime <source="frametime";>;

//Textures//////////////////////////////////////////////////////////////////////////////////////////////////

#if !MAGICBLOOM2_NODIRT
texture2D tMagicBloom2_Dirt <source="MagicBloom_Dirt.png";> {
	Width  = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
};
sampler2D sMagicBloom2_Dirt {
	Texture = tMagicBloom2_Dirt;
};
#endif

sampler2D sBackBuffer {
	Texture = ReShade::BackBufferTex;
	#if MAGICBLOOM2_CURVE == SRGB
	SRGBTexture = true;
	#endif
};

texture2D tMagicBloom2_A {
	Width = BUFFER_WIDTH / 2;
	Height = BUFFER_HEIGHT / 2;
	Format = RGBA16F;
	MipLevels = max_mip;
};
sampler2D sMagicBloom2_A {
	Texture = tMagicBloom2_A;
};

texture2D tMagicBloom2_B {
	Width = BUFFER_WIDTH / 2;
	Height = BUFFER_HEIGHT / 2;
	Format = RGBA16F;
};
sampler2D sMagicBloom2_B {
	Texture = tMagicBloom2_B;
};

#if !MAGICBLOOM2_NOADAPT
texture2D tMagicBloom2_Adapt {
	Format = R16F;
};
sampler2D sMagicBloom2_Adapt {
	Texture = tMagicBloom2_Adapt;
};

#if !MAGICBLOOM2_ADAPT_NODELAY
texture2D tMagicBloom2_LastAdapt {
	Format = R16F;
};
sampler2D sMagicBloom2_LastAdapt {
	Texture = tMagicBloom2_LastAdapt;
};
#endif
#endif

//Functions/////////////////////////////////////////////////////////////////////////////////////////////////

float2 get_offset(int i) {
	static const float2 offset[max_steps] = {
		float2(0.0, 0.0),
		float2(0.7, 0.0),
		float2(0.6, 0.35),
		float2(0.725, 0.35),
		float2(0.55, 0.475),
		float2(0.58125, 0.475),
		float2(0.6, 0.475),
		float2(0.6125, 0.475)
	};
	return offset[i];
}

float3 i_reinhard(float3 col) {
	return (col / max(1.0 - col, 1.0 / fMaxBrightness));
}

float3 t_reinhard(float3 col) {
	return col / (1.0 + col);
}

float get_luma_linear(float3 col) {
	return dot(col, float3(0.2126, 0.7152, 0.0722));
}

float gaussian1D(float i) {
	return (1.0 / sqrt(2.0 * pi * pow2(fBlur_Sigma))) * exp(-(pow2(i) / (2.0 * pow2(fBlur_Sigma))));
}

float gaussian2D(float2 i) {
	return (1.0 / (2.0 * pi * pow2(fBlur_Sigma))) * exp(-((pow2(i.x) + pow2(i.y)) / (2.0 * pow2(fBlur_Sigma))));
}

float2 scale_uv(float2 uv, float2 scale, float2 center) {
	return (uv - center) * scale + center;
}

bool within(float2 uv, float4 bounds) {
	return uv.x >= bounds.x && uv.x <= bounds.y && uv.y >= bounds.z && uv.y <= bounds.w;
}

float4 blur1D(sampler2D sp, float2 uv, float2 scale) {
	const float2 ps = ReShade::PixelSize * scale;

	float4 color = 0.0;
	float accum = 0.0;
	float offset, weight;

	[unroll]
	for (int i = -MAGICBLOOM2_BLURSAMPLES / 2; i <= MAGICBLOOM2_BLURSAMPLES / 2; ++i) {
		offset = i;
		weight = gaussian1D(offset);

		color += _tex2D(sp, uv + ps * offset) * weight;
		accum += weight;
	}

	color /= accum;
	return color;
}

float4 blur2D(sampler2D sp, float2 uv, float2 scale) {
	const float2 ps = ReShade::PixelSize * scale;

	float4 color = 0.0;
	float accum = 0.0;
	float2 offset;
	float weight;

	[unroll]
	for (int x = -MAGICBLOOM2_BLURSAMPLES / 2; x <= MAGICBLOOM2_BLURSAMPLES / 2; ++x) {
		[unroll]
		for (int y = -MAGICBLOOM2_BLURSAMPLES / 2; y <= MAGICBLOOM2_BLURSAMPLES / 2; ++y) {
			offset = float2(x, y);
			weight = gaussian2D(offset);

			color += _tex2D(sp, uv + ps * offset) * weight;
			accum += weight;
		}
	}

	color /= accum;
	return color;
}

//Shaders///////////////////////////////////////////////////////////////////////////////////////////////////

void PS_MakeHDR(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD,
	out float4 color : SV_TARGET
) {
	color = tex2D(sBackBuffer, uv);
	#if MAGICBLOOM2_CURVE == CUSTOM
	color = pow(color, fBloom_Curve);
	#endif
	#if !MAGICBLOOM2_NOTHRESHOLD
	color = pow(color, fBloom_Threshold);
	#endif
	color.rgb = i_reinhard(color.rgb);
}
#if !MAGICBLOOM2_NOADAPT
void PS_CalcAdapt(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD,
	out float adapt : SV_TARGET
) {
	float3 color = tex2Dlod(sMagicBloom2_A, float4(0.5, 0.5, 0.0, max_mip - fAdapt_Precision)).rgb;
	adapt = get_luma_linear(color.rgb);
	adapt *= fAdapt_Sensitivity;
	adapt = bAdapt_DoLimit ? clamp(adapt, f2Adapt_MinMax.x, f2Adapt_MinMax.y) : adapt;

	#if !MAGICBLOOM2_ADAPT_NODELAY
	float last = tex2D(sMagicBloom2_LastAdapt, uv).x;
	//adapt = lerp(last, adapt, fAdapt_Speed * fDeltaTime * 0.001);
	adapt = lerp(last, adapt, (fDeltaTime * 0.001) / fAdapt_Delay);
	#endif
}
#if !MAGICBLOOM2_ADAPT_NODELAY
void PS_SaveAdapt(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD,
	out float last  : SV_TARGET
) {
	last = tex2D(sMagicBloom2_Adapt, uv).x;
}
#endif
#endif
void PS_Split(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD,
	out float4 color : SV_TARGET
) {
	color = 0.0;
	float lod;
	float2 scaled_uv;

	[unroll]
	for (int i = 0; i < max_steps; ++i) {
		lod = pow(2, i + 1);
		scaled_uv = scale_uv(uv, lod, get_offset(i));

		if (within(scaled_uv, float4(-pad.x, 1.0 + pad.x, -pad.y, 1.0 + pad.y)))
			color += tex2Dlod(sMagicBloom2_A, float4(scaled_uv, 0.0, i));
	}
}

#if MAGICBLOOM2_TWOPASS_BLUR
void PS_BlurX(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD,
	out float4 color : SV_TARGET
) {
	color = blur1D(sMagicBloom2_B, uv, float2(2.0, 0.0));
}

void PS_BlurY(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD,
	out float4 color : SV_TARGET
) {
	color = blur1D(sMagicBloom2_A, uv, float2(0.0, 2.0));
}
#else
void PS_Blur2D(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD,
	out float4 color : SV_TARGET
) {
	color = blur2D(sMagicBloom2_B, uv, 2.0);
}
#endif

void PS_Blend(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD,
	out float4 color : SV_TARGET
) {
	#if MAGICBLOOM2_TWOPASS_BLUR
	#define sMagicBloom2_Final sMagicBloom2_B
	#else
	#define sMagicBloom2_Final sMagicBloom2_A
	#endif

	#if MAGICBLOOM2_DEBUG
	if (iDebug == 2) {
		color = tex2D(sMagicBloom2_Final, uv);
		#if MAGICBLOOM2_CURVE == CUSTOM
		color = pow(color, 1.0 / fBloom_Curve);
		#endif
		return;
	}
	#endif

	#if !MAGICBLOOM2_NOADAPT
	float adapt = tex2D(sMagicBloom2_Adapt, uv).x;
	float exposure = fAdapt_Exposure / max(adapt, 1.0 / fMaxBrightness);
	#endif

	float4 bloom = 0.0;
	float lod;
	float2 scaled_uv;

	[unroll]
	for (int i = 0; i < max_steps; ++i) {
		lod = pow(2, i + 1);
		scaled_uv = scale_uv(uv, 1.0 / lod, get_offset(i));

		bloom += tex2D(sMagicBloom2_Final, scaled_uv);// * (max_steps - i + 1);
	}

	bloom /= max_steps;
	bloom *= fBloom_Intensity;
	#if !MAGICBLOOM2_NOADAPT
	bloom *= iAdapt_Mode == 2 ? exposure : 1.0;
	#endif

	#if !MAGICBLOOM2_NODIRT
	float bloom_lum = max(bloom.r, max(bloom.g, bloom.b));
	float4 dirt = tex2D(sMagicBloom2_Dirt, uv);
	//bloom = lerp(bloom, bloom + dirt * bloom, fDirt_Intensity);
	bloom += dirt * bloom * fDirt_Intensity;

	#endif

	color = tex2D(sBackBuffer, uv);
	#if MAGICBLOOM2_CURVE == CUSTOM
	color = pow(color, fBloom_Curve);
	#endif
	color.rgb = i_reinhard(color.rgb);

	color += bloom;
	#if !MAGICBLOOM2_NOADAPT
	color *= iAdapt_Mode == 1 ? exposure : 1.0;
	#endif
	color.rgb = t_reinhard(color.rgb);

	#if MAGICBLOOM2_DEBUG
	color.rgb = iDebug == 1 ? bloom.rgb : color.rgb;
	#endif

	#if MAGICBLOOM2_CURVE == CUSTOM
	color = pow(color, 1.0 / fBloom_Curve);
	#endif

	#undef sMagicBloom2_Final
}

//Technique/////////////////////////////////////////////////////////////////////////////////////////////////

technique MagicBloom2 {
	pass MakeHDR {
		VertexShader = PostProcessVS;
		PixelShader  = PS_MakeHDR;
		RenderTarget = tMagicBloom2_A;
	}
	#if !MAGICBLOOM2_NOADAPT
	pass CalcAdapt {
		VertexShader = PostProcessVS;
		PixelShader  = PS_CalcAdapt;
		RenderTarget = tMagicBloom2_Adapt;
	}
	#if !MAGICBLOOM2_ADAPT_NODELAY
	pass SaveAdapt {
		VertexShader = PostProcessVS;
		PixelShader  = PS_SaveAdapt;
		RenderTarget = tMagicBloom2_LastAdapt;
	}
	#endif
	#endif
	pass Split {
		VertexShader = PostProcessVS;
		PixelShader  = PS_Split;
		RenderTarget = tMagicBloom2_B;
	}
	#if MAGICBLOOM2_TWOPASS_BLUR
	pass BlurX {
		VertexShader = PostProcessVS;
		PixelShader  = PS_BlurX;
		RenderTarget = tMagicBloom2_A;
	}
	pass BlurY {
		VertexShader = PostProcessVS;
		PixelShader  = PS_BlurY;
		RenderTarget = tMagicBloom2_B;
	}
	#else
	pass Blur2D {
		VertexShader = PostProcessVS;
		PixelShader  = PS_Blur2D;
		RenderTarget = tMagicBloom2_A;
	}
	#endif
	pass Blend {
		VertexShader = PostProcessVS;
		PixelShader  = PS_Blend;
		#if MAGICBLOOM2_CURVE == SRGB
		SRGBWriteEnable = true;
		#endif
	}
}

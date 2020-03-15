#include "ReShade.fxh"

//Macros////////////////////////////////////////////////////////////////////////////////////

#ifndef MAGIC_BLOOM_LIGHT_BLUR_SAMPLES
#define MAGIC_BLOOM_LIGHT_BLUR_SAMPLES 21
#endif

#define pow2(x) (x * x)
#define _tex2D(sp, uv) tex2Dlod(sp, float4(uv, 0.0, 0.0))

//Constants/////////////////////////////////////////////////////////////////////////////////

static const float pi = 3.1415926535897932384626433832795;
static const int max_steps = 8;
static const float2 pad = ReShade::PixelSize * 25.0;

//Uniforms//////////////////////////////////////////////////////////////////////////////////

uniform float fBloom_Amount <
	ui_label = "Bloom Amount";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 1.0;
	ui_step  = 0.001;
> = 1.0;

uniform float fBloom_Threshold <
	ui_label = "Bloom Threshold";
	ui_type  = "drag";
	ui_min   = 1.0;
	ui_max   = 10.0;
	ui_step  = 0.001;
> = 3.0;

uniform float fGhosting <
	ui_label = "Ghosting";
	ui_type  = "drag";
	ui_min   = 0.001;
	ui_max   = 10.0;
	ui_step  = 0.001;
> = 0.5;

uniform float fBlur_Sigma <
	ui_label = "Blur Sigma";
	ui_type  = "drag";
	ui_min   = 0.001;
	ui_max   = 10.0;
	ui_step  = 0.001;
> = 4.0;

uniform int iSteps <
	ui_label = "Bloom Steps";
	ui_type  = "drag";
	ui_min   = 1;
	ui_max   = max_steps;
	ui_step  = 0.01;
> = 5;

uniform float2 f2Bloom_Scale <
	ui_label = "Bloom Scale";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 10.0;
	ui_step  = 0.001;
> = float2(1.0, 1.0);

uniform float fFrameTime <source = "frametime";>;

//Textures//////////////////////////////////////////////////////////////////////////////////

sampler2D sBackBuffer {
	Texture     = ReShade::BackBufferTex;
	SRGBTexture = true;
	AddressU    = BORDER;
	AddressV    = BORDER;
};

texture2D tMagicBloom_Light_Original {
	Width  = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
};
sampler2D sMagicBloom_Light_Original {
	Texture = tMagicBloom_Light_Original;
	SRGBTexture = true;
};

texture2D tMagicBloom_Light_Last {
	Width  = BUFFER_WIDTH / 4;
	Height = BUFFER_HEIGHT / 4;
};
sampler2D sMagicBloom_Light_Last {
	Texture     = tMagicBloom_Light_Last;
	SRGBTexture = true;
};

//Functions/////////////////////////////////////////////////////////////////////////////////

float2 scale_uv(float2 uv, float2 scale, float2 center) {
	return (center - uv) * scale + center;
}

float gaussian1D(float i) {
	return (1.0 / sqrt(2.0 * pi * pow2(fBlur_Sigma))) * exp(-(pow2(i) / (2.0 * pow2(fBlur_Sigma))));
}

float3 blur1D(sampler2D sp, float2 uv, float2 scale) {
	const float2 ps = ReShade::PixelSize * scale;

	float3 color = 0.0;
	float accum = 0.0;
	float offset, weight;

	[unroll]
	for (int i = -MAGIC_BLOOM_LIGHT_BLUR_SAMPLES / 2; i <= MAGIC_BLOOM_LIGHT_BLUR_SAMPLES / 2; ++i) {
		offset = i;
		weight = gaussian1D(offset);

		color += _tex2D(sp, uv + ps * offset).rgb * weight;
		accum += weight;
	}

	color /= accum;
	return color;
}

float3 blend_screen(float3 a, float3 b, float w) {
	return lerp(a, 1.0 - (1.0 - a) * (1.0 - b), w);
}

float2 get_offset(int i) {
	static const float2 offset[max_steps] = {
		float2(0.0, 0.0),
		float2(0.7, 0.0),
		float2(0.6, 0.35),
		float2(0.725, 0.35),
		float2(0.55, 0.485),
		float2(0.5875, 0.485),
		float2(0.6125, 0.485),
		float2(0.63125, 0.485)
	};
	return offset[i];
}

bool within(float2 uv, float4 bounds) {
	return uv.x >= bounds.x && uv.x <= bounds.y && uv.y >= bounds.z && uv.y <= bounds.w;
}

//Shaders///////////////////////////////////////////////////////////////////////////////////

float4 PS_SaveOriginal(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	return tex2D(sBackBuffer, uv);
}

float4 PS_ThresholdAndSplit(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = 0.0;
	float lod;
	float2 lod_uv;
	
	[unroll]
	for (int i = 0; i < max_steps; ++i) {
		lod = pow(2, i + 1);
		lod_uv = scale_uv(uv, lod, get_offset(i));
		
		if (within(lod_uv, float4(-pad.x, 1.0 + pad.x, -pad.y, 1.0 + pad.y)))
			color += pow(tex2D(sBackBuffer, lod_uv).rgb, fBloom_Threshold);
	}
	
	return float4(color, 1.0);
}

float4 PS_BlurX(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = blur1D(sBackBuffer, uv, float2(f2Bloom_Scale.x, 0.0));
	return float4(color, 1.0);
}

float4 PS_BlurY(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = blur1D(sBackBuffer, uv, float2(0.0, f2Bloom_Scale.y));
	
	float3 last = tex2D(sMagicBloom_Light_Last, uv).rgb;
	color = lerp(last, color, saturate(1.0 / (fGhosting * fFrameTime)));
	
	return float4(color, 1.0);
}

float4 PS_Blend(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 bloom = 0.0;
	float lod;
	float2 lod_uv;
	float accum = 0.0;
	float weight;
	
	[unroll]
	for (int i = 0; i < iSteps; ++i) {
		lod = pow(2, i + 1);
		lod_uv = scale_uv(uv, 1.0 / lod, get_offset(i));
		
		weight = max_steps - (i + 1);
		bloom += tex2D(sBackBuffer, lod_uv).rgb * weight;
		accum += weight;
	}
	bloom /= accum;
	
	float3 color = tex2D(sMagicBloom_Light_Original, uv).rgb;

	color = blend_screen(color, bloom, fBloom_Amount);
	return float4(color, 1.0);
}

float4 PS_SaveLast(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = tex2D(sBackBuffer, uv).rgb;
	color *= step(1.e-36, color);
	return float4(color, 1.0);
}

//Technique/////////////////////////////////////////////////////////////////////////////////

technique MagicBloom_Light {
	pass SaveOriginal {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_SaveOriginal;
		RenderTarget    = tMagicBloom_Light_Original;
		SRGBWriteEnable = true;
	}
	pass ThresholdAndSplit {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_ThresholdAndSplit;
		SRGBWriteEnable = true;
	}
	pass BlurX {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_BlurX;
		SRGBWriteEnable = true;
	}
	pass BlurY {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_BlurY;
		SRGBWriteEnable = true;
	}
	pass PS_SaveLast {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_SaveLast;
		RenderTarget    = tMagicBloom_Light_Last;
		SRGBWriteEnable = true;
	}
	pass Blend {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_Blend;
		SRGBWriteEnable = true;
	}
}

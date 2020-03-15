//#region Includes

#include "ReShade.fxh"

//#endregion

//#region Preprocessor

#ifndef VIRTUAL_RESOLUTION_UPFILTER
#define VIRTUAL_RESOLUTION_UPFILTER POINT
#endif

#ifndef VIRTUAL_RESOLUTION_DOWNFILTER
#define VIRTUAL_RESOLUTION_DOWNFILTER LINEAR
#endif

#ifndef VIRTUAL_RESOLUTION_DYNAMIC
#define VIRTUAL_RESOLUTION_DYNAMIC 1
#endif

#ifndef VIRTUAL_RESOLUTION_WIDTH
#define VIRTUAL_RESOLUTION_WIDTH BUFFER_WIDTH
#endif

#ifndef VIRTUAL_RESOLUTION_HEIGHT
#define VIRTUAL_RESOLUTION_HEIGHT BUFFER_HEIGHT
#endif

//#endregion

//#region Uniforms

uniform uint ScaleMode <
	ui_label = "Scale Mode";
	ui_type = "combo";
	ui_items = "None\0Crop\0Stretch\0";
> = 0;

#if VIRTUAL_RESOLUTION_DYNAMIC

uniform float ResolutionX <
	ui_label = "Virtual Resolution Width";
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = BUFFER_WIDTH;
	ui_step = 1.0;
> = BUFFER_WIDTH;

uniform float ResolutionY <
	ui_label = "Virtual Resolution Height";
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = BUFFER_HEIGHT;
	ui_step = 1.0;
> = BUFFER_HEIGHT;

#else

static const float ResolutionX = VIRTUAL_RESOLUTION_WIDTH;
static const float ResolutionY = VIRTUAL_RESOLUTION_HEIGHT;

#endif

#define Resolution float2(ResolutionX, ResolutionY)

//#endregion

//#region Textures

sampler DownSample
{
	Texture = ReShade::BackBufferTex;
	MinFilter = VIRTUAL_RESOLUTION_DOWNFILTER;
	MagFilter = VIRTUAL_RESOLUTION_DOWNFILTER;
	AddressU = BORDER;
	AddressV = BORDER;
};

#if VIRTUAL_RESOLUTION_DYNAMIC

sampler UpSample
{
	Texture = ReShade::BackBufferTex;
	MinFilter = VIRTUAL_RESOLUTION_UPFILTER;
	MagFilter = VIRTUAL_RESOLUTION_UPFILTER;
	AddressU = BORDER;
	AddressV = BORDER;
};

#else

texture VirtualResolution_DownSampled
{
	Width = VIRTUAL_RESOLUTION_WIDTH;
	Height = VIRTUAL_RESOLUTION_HEIGHT;
};
sampler UpSample
{
	Texture = VirtualResolution_DownSampled;
	MinFilter = VIRTUAL_RESOLUTION_UPFILTER;
	MagFilter = VIRTUAL_RESOLUTION_UPFILTER;
	AddressU = BORDER;
	AddressV = BORDER;
};

#endif

//#endregion

//#region Functions

float get_aspect_ratio_scale(out float x_or_y)
{
	float ar_real = ReShade::AspectRatio;
	float ar_virtual = ResolutionX / ResolutionY;
	
	x_or_y = step(ar_real, ar_virtual);
	return lerp(ar_virtual / ar_real, ar_real / ar_virtual, x_or_y);
}

float2 scale_uv(float2 uv, float2 scale, float2 center)
{
	return (uv - center) * scale + center;
}
float2 scale_uv(float2 uv, float2 scale)
{
	return scale_uv(uv, scale, 0.5);
}

float get_crop(float2 uv, float ar_scale, float x_or_y)
{
	float crop = ar_scale;
	crop = (1.0 - crop) * 0.5;

	float pos = lerp(uv.x, uv.y, x_or_y);

	return step(crop, pos) * step(pos, 1.0 - crop);
}

float2 get_stretch(float2 uv, float ar_scale, float x_or_y)
{
	float2 scale = float2(ar_scale, 1.0);
	scale = lerp(scale, scale.yx, x_or_y);

	return scale_uv(uv, 1.0 / scale);
}

//#endregion

//#region Shaders

float4 PS_DownSample(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
	#if VIRTUAL_RESOLUTION_DYNAMIC

	float2 scale = Resolution * ReShade::PixelSize;
	uv = scale_uv(uv, 1.0 / scale);

	#endif

	return tex2D(DownSample, uv);
}

float4 PS_UpSample(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
	float2 uv_original = uv;

	#if VIRTUAL_RESOLUTION_DYNAMIC

	float2 scale = Resolution * ReShade::PixelSize;
	uv = scale_uv(uv, scale);

	#endif

	float4 color;

	if (ScaleMode != 0)
	{
		float x_or_y = 0.0;
		float ar = get_aspect_ratio_scale(x_or_y);
		float visible = 1.0;

		switch (ScaleMode)
		{
			case 1:
				visible = get_crop(uv_original, ar, x_or_y);
				break;
			case 2:
				uv = get_stretch(uv, ar, x_or_y);
				break;
		}

		color = tex2D(UpSample, uv) * visible;
	}
	else
	{
		color = tex2D(UpSample, uv);
	}

	return color;
}

//#endregion

//#region Technique

technique VirtualResolution
{
	pass DownSample
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_DownSample;

		#if !VIRTUAL_RESOLUTION_DYNAMIC
		RenderTarget = VirtualResolution_DownSampled;
		#endif
	}
	pass UpSample
	{
		VertexShader = PostProcessVS;
		PixelShader = PS_UpSample;
	}
}

//#endregion
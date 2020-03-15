#include "ReShade.fxh"

  //==========//
 // Uniforms //
//==========//

  //===========//
 // Constants //
//===========//

static const float3 cFilterColor = float3(0.88, 0.8, 0.44);
static const float3 cLuminanceFilter = float3(0.2125f,	0.7154f, 0.0721f);
static const float cSaturation = 0.5;
static const int cGaussianTaps = 13;

  //==========//
 // Textures //
//==========//

sampler sColor_sRGB {
	Texture = ReShade::BackBufferTex;
	SRGBTexture = true;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

sampler sColor {
	Texture = ReShade::BackBufferTex;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

sampler sColor_Linear_sRGB {
	Texture = ReShade::BackBufferTex;
	SRGBTexture = true;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

sampler sColor_Linear {
	Texture = ReShade::BackBufferTex;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

  //===========//
 // Functions //
//===========//

float get_gaussian_weight(int i) {
	static const float cGaussianWeights[cGaussianTaps] = {
		0.017997,
		0.033159,
		0.054670,
		0.080657,
		0.106483,
		0.125794,
		0.132981,
		0.125794,
		0.106483,
		0.080657,
		0.054670,
		0.033159,
		0.017997
	};
	return cGaussianWeights[i];
}

float get_lum(float3 color) {
	return dot(color, cLuminanceFilter);
}

float4 gaussian_blur(sampler sp, float2 uv, float2 dir) {
	float4 color = 0.0;
	uv -= dir * floor(cGaussianTaps * 0.5);

	[unroll]
	for (int i = 0; i < cGaussianTaps; ++i) {
		color += tex2D(sp, uv) * get_gaussian_weight(i);
		uv += dir;
	}

	return color;
}

  //=========//
 // Shaders //
//=========//

float4 PS_AlphaToLum(
	float4 p : SV_POSITION, float2 uv : TEXCOORD
) : SV_TARGET {
	float4 color = tex2D(sColor_sRGB, uv);
	color.a = get_lum(color.rgb);
	return color;
}

float4 PS_BlurX(
	float4 p : SV_POSITION, float2 uv : TEXCOORD
) : SV_TARGET {
	float4 color = tex2D(sColor, uv);
	color.a = gaussian_blur(sColor_Linear, uv, float2(BUFFER_RCP_WIDTH * 2.0, 0.0)).a;
	return color;
}

float4 PS_BlurY(
	float4 p : SV_POSITION, float2 uv : TEXCOORD
) : SV_TARGET {
	float4 color = tex2D(sColor, uv);
	color.a = gaussian_blur(sColor_Linear, uv, float2(0.0, BUFFER_RCP_HEIGHT * 2.0)).a;
	return color;
}

float4 PS_NFSMW(
	float4 p : SV_POSITION, float2 uv : TEXCOORD
) : SV_TARGET {
	float4 color = tex2D(sColor, uv);
	//float lum = get_lum(color);
	//color = color.a;

	color.rgb += color.rgb * color.a;

	//color = lerp(lum, color, cFilterColor + 1.0 - cSaturation);
	//color *= cFilterColor;
	//color = lum * (1.0 - cSaturation) + color * cSaturation;

	return float4(color.rgb, 1.0);
}

  //===========//
 // Technique //
//===========//

technique NFSMW {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_AlphaToLum;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_BlurX;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_BlurY;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_NFSMW;
		SRGBWriteEnable = true;
	}
}

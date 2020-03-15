#include "ReShade.fxh"

//Macros////////////////////////////////////////////////////////////////////////////////////////////

#ifndef TTAA_DEBUG
#define TTAA_DEBUG 0
#endif

#if __RESHADE_PERFORMANCE_MODE__
#define _UNROLL_ [unroll]
#else
#define _UNROLL_ 
#endif

#define ps ReShade::PixelSize

//Constants/////////////////////////////////////////////////////////////////////////////////////////
//Uniforms//////////////////////////////////////////////////////////////////////////////////////////

uniform float fEdgeIntensity <
	ui_label = "Edge Intensity";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 1000.0;
	ui_step  = 0.1;
> = 1.0;

uniform int iMaxSteps <
	ui_label = "Max Steps";
	ui_type  = "drag";
	ui_min   = 1;
	ui_max   = 254;
	ui_step  = 0.1;
> = 70;

#if TTAA_DEBUG
uniform int iViewEdges <
	ui_label = "View Edges";
	ui_type  = "combo";
	ui_items = "Disabled\0Left-Half\0Right-Half\0Top-Half\0Bottom-Half\0Full-Screen\0";
> = 0;
#endif

//Textures//////////////////////////////////////////////////////////////////////////////////////////

sampler sBackBuffer {
	Texture = ReShade::BackBufferTex;
	SRGBTexture = true;
	MinFilter = POINT;
	MagFilter = POINT;
};

texture2D tTTAA_Edges {
	Width  = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RG16F;
};
sampler2D sEdges {
	Texture = tTTAA_Edges;
	MinFilter = POINT;
	MagFilter = POINT;
};

//Functions/////////////////////////////////////////////////////////////////////////////////////////

float get_luma_linear(float3 col) {
	return dot(col, float3(0.2126, 0.7152, 0.0722));
}

//Shaders///////////////////////////////////////////////////////////////////////////////////////////

float4 PS_GetLuma(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = tex2D(sBackBuffer, uv).rgb;
	//float luma = get_luma_linear(color);
	float luma = length(color);

	return float4(color, luma);
}

float2 PS_GetEdges(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	#define _fetch(uv, x, y) tex2Dlodoffset(sBackBuffer, float4(uv, 0.0, 0.0), int2(x, y)).w
	float2 edges = float2(
		_fetch(uv,-1, 0) - _fetch(uv, 1, 0),
		_fetch(uv, 0,-1) - _fetch(uv, 0, 1)
	) * ps * 2.0;
	edges *= fEdgeIntensity;

	return edges;
	#undef _fetch
}

float4 PS_Blur(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	#define _fetch(uv, offset) tex2Dlod(sBackBuffer, float4(uv + ps * offset, 0.0, 0.0)).rgb

	float3 color = tex2D(sBackBuffer, uv).rgb;
	float2 edges = tex2D(sEdges, uv).xy;
	edges = float2(-edges.y, edges.x); // Rotate by 90º

	#if TTAA_DEBUG
	if ((iViewEdges == 1 && uv.x < 0.5)
	 || (iViewEdges == 2 && uv.x > 0.5)
	 || (iViewEdges == 3 && uv.y < 0.5)
	 || (iViewEdges == 4 && uv.y > 0.5)
	 || (iViewEdges == 5))
		return float4(abs(edges), 0.0, 1.0);
	#endif

	int steps = iMaxSteps * saturate(length(edges));
	if (steps > 1) {
		for (int i = 1; i < steps; ++i) {
			float offset = i - steps * 0.5;
			color += _fetch(uv, edges * offset);
		}
		color /= steps;
	}

	return float4(color, 1.0);

	#undef _fetch
}

//Technique/////////////////////////////////////////////////////////////////////////////////////////

technique TTAA {
	pass GetLuma {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_GetLuma;
		SRGBWriteEnable = true;
	}
	pass GetEdges {
		VertexShader = PostProcessVS;
		PixelShader  = PS_GetEdges;
		RenderTarget = tTTAA_Edges;
	}
	pass Blur {
		VertexShader = PostProcessVS;
		PixelShader  = PS_Blur;
		SRGBWriteEnable = true;
	}
}

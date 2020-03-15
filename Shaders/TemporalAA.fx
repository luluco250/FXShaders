#include "ReShade.fxh"

uniform float fThreshold <
	ui_label   = "Edge Threshold";
	ui_tooltip = "Default: 0.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
> = 0.0;

uniform float3 f3Kernel0 <
	ui_label = "Kernel";
	ui_type  = "drag";
	ui_min   = -20.0;
	ui_max   =  20.0;
	ui_step  =  0.001;
> = float3(1.0, 1.0, 1.0);

uniform float3 f3Kernel1 <
	ui_label = "Kernel";
	ui_type  = "drag";
	ui_min   = -20.0;
	ui_max   =  20.0;
	ui_step  =  0.001;
> = float3(1.0, 1.0, 1.0);

uniform float3 f3Kernel2 <
	ui_label = "Kernel";
	ui_type  = "drag";
	ui_min   = -20.0;
	ui_max   =  20.0;
	ui_step  =  0.001;
> = float3(1.0, 1.0, 1.0);

sampler2D sBackBuffer_ToLinear {
	Texture = ReShade::BackBufferTex;
	SRGBTexture = true;
};
sampler2D sBackBuffer {
	Texture = ReShade::BackBufferTex;
};

texture2D tTemporalAA_Luma {
	Width  = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = R8;
};
sampler2D sLuma {
	Texture = tTemporalAA_Luma;
};

float get_luma_linear(float3 col) {
	return dot(col, float3(0.2126, 0.7152, 0.0722));
}

float get_edge(float2 uv, int2 offset) {
	return normalize(
		(tex2Doffset(sLuma, uv, offset).x - tex2Doffset(sLuma, uv, -offset).x) * 2.0
	);
}

float4 PS_GetLuma(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = tex2D(sBackBuffer_ToLinear, uv).rgb;
	float luma = get_luma_linear(color);
	
	return float4(color, luma);
}

float4 PS_GetEdges(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	/*float2 edges = float2(
		(tex2Doffset(sLuma, uv, int2(1,0)).x - tex2Doffset(sLuma, uv, int2(-1,0)).x) * (2.0 * BUFFER_RCP_WIDTH),
		(tex2Doffset(sLuma, uv, int2(0,1)).x - tex2Doffset(sLuma, uv, int2(0,-1)).x) * (2.0 * BUFFER_RCP_HEIGHT)
	);
	edges = normalize(edges);
	edges = edges * step(fThreshold, edges);
	

	return float4(edges, 0.0, 1.0);*/

	/*static const int neighbor_count = 4;
	static const int2 neighbors[neighbor_count] = {
		int2( 0, 1),
		int2( 0,-1),
		int2(-1, 0),
		int2( 1, 0)
	};

	float3 color = tex2D(sBackBuffer, uv).rgb;
	float accum = 1.0;

	[unroll]
	for (int i = 0; i < neighbor_count; ++i) {
		float edge = get_edge(uv, neighbors[i]);
		float3 neighbor = tex2Doffset(sBackBuffer, uv, neighbors[i]).rgb;

		color += neighbor * edge;
		accum += edge;
	}

	return float4(color / accum, 1.0);*/

	/*#define _GET_LUMA(X, Y) (1.0 - tex2Doffset(sLuma, uv, int2(X, Y)).x)
	const float kernel[9] = {
		_GET_LUMA(-1, 1), _GET_LUMA( 0, 1), _GET_LUMA( 1, 1),
		_GET_LUMA(-1, 0), _GET_LUMA( 0, 0), _GET_LUMA( 1, 0),
		_GET_LUMA(-1,-1), _GET_LUMA( 0,-1), _GET_LUMA( 1,-1)
		f3Kernel0.x, f3Kernel0.y, f3Kernel0.z,
		f3Kernel1.x, f3Kernel1.y, f3Kernel1.z,
		f3Kernel2.x, f3Kernel2.y, f3Kernel2.z
	};
	#undef _GET_LUMA*/

	static const int2 offsets[8] = {
		int2(-1, 1),  int2( 0, 1),  int2( 1, 1),
		int2(-1, 0),/*int2( 0, 0),*/int2( 1, 0),
		int2(-1,-1),  int2( 0,-1),  int2( 1,-1)
	};

	float4 center = tex2D(sBackBuffer, uv);
	float accum = 1.0;

	[unroll]
	for (int i = 0; i < 8; ++i) {
		/*float4 neighbor = tex2Doffset(sBackBuffer, uv, offsets[i]);
		float diff = 1.0 - normalize(center.w - neighbor.w);

		center.rgb += neighbor.rgb * diff;
		accum += diff;*/
	}

	return float4(center.rgb / accum, 1.0);
}

technique TemporalAA {
	pass GetLuma {
		VertexShader = PostProcessVS;
		PixelShader  = PS_GetLuma;
		//RenderTarget = tTemporalAA_Luma;
	}
	pass GetEdges {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_GetEdges;
		SRGBWriteEnable = true;
	}
}

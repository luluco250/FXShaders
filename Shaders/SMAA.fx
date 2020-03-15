#include "ReShade.fxh"

#define DEPTH  0
#define LUMA   1
#define COLOR  2

#ifndef SMAA_FX_EDGE_DETECTION_TYPE
#define SMAA_FX_EDGE_DETECTION_TYPE LUMA
#endif

#ifndef SMAA_FX_DEBUG
#define SMAA_FX_DEBUG 0
#endif

uniform float fThreshold <
	ui_label   = "Edge Detection Threshold";
	ui_tooltip = "Specifies the threshold or sensitivity to edges. "
	             "Lowering this value you will be able to detect more "
				 "edges at the expense of performance.\n"
				 "  0.1 is a reasonable value, allowing us to catch most visible edges.\n"
				 "  0.05 is a rather overkill value, allowing us to catch 'em all.\n"
				 "If temporal super-sampling is used, 0.2 could be a reasonable value, "
				 "as low contrast edges are properly filtered by just 2x.\n"
	             "\nDefault: 0.1";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 0.5;
	ui_step    = 0.001;
> = 0.1;

uniform int iSearchSteps <
	ui_label   = "Max Search Steps";
	ui_tooltip = "Specifies the maximum steps performed in the "
	             "horizontal/vertical pattern searches, at each side of the pixel.\n"
				 "In number of pixels, it's actually the double. So the maximum line "
				 "length perfectly handled by, for example 16, is 64 (by perfectly, "
				 "we mean that longer lines won't look as good, but still anti-aliased).\n"
	             "\nDefault: 16";
	ui_type    = "drag";
	ui_min     = 0;
	ui_max     = 112;
	ui_step    = 0.1;
> = 16;

uniform int iSearchSteps_Diagonal <
	ui_label   = "Max Diagonal Search Steps";
	ui_tooltip = "Specifies the maximum steps performed in the diagonal "
	             "pattern searches, at each side of the pixel. In this case "
				 "we jump one pixel at time, instead of two.\n"
				 "On high-end machines it is cheap (between a 0.8x and 0.9x "
				 "slower for 16 steps), but it can have a significant impact on older machines.\n"
				 "Define SMAA_DISABLE_DIAG_DETECTION to disable diagonal processing.\n"
	             "\nDefault: 8";
	ui_type    = "drag";
	ui_min     = 0;
	ui_max     = 20;
	ui_step    = 0.1;
> = 8;

uniform int iCornerRounding <
	ui_label   = "Corner Rounding";
	ui_tooltip = "Specifies how much sharp corners will be rounded.\n"
	             "\nDefault: 25";
	ui_type    = "drag";
	ui_min     = 0;
	ui_max     = 100;
	ui_step    = 0.1;
> = 25;

#if SMAA_FX_DEBUG
uniform int iDebug <
	ui_label = "Debug Options";
	ui_type  = "combo";
	ui_items = "None\0Show Edges Texture\0Show Blend Texture\0";
> = 0;
#endif

sampler2D sBackBuffer_Linear {
	Texture     = ReShade::BackBufferTex;
	MinFilter   = LINEAR;
	MagFilter   = LINEAR;
	AddressU    = CLAMP;
	AddressV    = CLAMP;
	SRGBTexture = true;
};
sampler2D sBackBuffer_Gamma {
	Texture     = ReShade::BackBufferTex;
	MinFilter   = LINEAR;
	MagFilter   = LINEAR;
	AddressU    = CLAMP;
	AddressV    = CLAMP;
	SRGBTexture = false;
};

sampler2D sDepthBuffer {
	Texture     = ReShade::DepthBufferTex;
	MinFilter   = LINEAR;
	MagFilter   = LINEAR;
	AddressU    = CLAMP;
	AddressV    = CLAMP;
	SRGBTexture = false;
};

texture2D tSMAA_Edges {
	Width  = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RG8;
};
sampler2D sEdges {
	Texture     = tSMAA_Edges;
	MinFilter   = LINEAR;
	MagFilter   = LINEAR;
	AddressU    = CLAMP;
	AddressV    = CLAMP;
	SRGBTexture = false;
};

texture2D tSMAA_Blend {
	Width  = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
	Format = RGBA8;
};
sampler2D sBlend {
	Texture     = tSMAA_Blend;
	MinFilter   = LINEAR;
	MagFilter   = LINEAR;
	AddressU    = CLAMP;
	AddressV    = CLAMP;
	SRGBTexture = false;
};

texture2D tSMAA_Area <
	source = "SMAA_AreaTex.dds";
> {
	Width  = 160;
	Height = 560;
	//Format = RG8;
};
sampler2D sArea {
	Texture     = tSMAA_Area;
	MinFilter   = LINEAR;
	MagFilter   = LINEAR;
	AddressU    = CLAMP;
	AddressV    = CLAMP;
	SRGBTexture = false;
};

texture2D tSMAA_Search <
	source = "SMAA_SearchTex.dds";
> {
	Width  = 64;
	Height = 16;
	//Format = R8;
};
sampler2D sSearch {
	Texture     = tSMAA_Search;
	MinFilter   = LINEAR;
	MagFilter   = LINEAR;
	AddressU    = CLAMP;
	AddressV    = CLAMP;
	SRGBTexture = false;
};

#define SMAA_RT_METRICS float4(ReShade::PixelSize, ReShade::ScreenSize)

#define SMAA_CUSTOM_SL
	#define SMAATexture2D(SP) sampler2D SP
	#define SMAATexturePass2D(SP) SP
	#define SMAASampleLevelZero(SP, UV) tex2Dlod(SP, float4(UV, 0.0, 0.0))
	#define SMAASampleLevelZeroPoint(SP, UV) SMAASampleLevelZero(SP, UV)
	#define SMAASampleLevelZeroOffset(SP, UV, OFF) tex2Dlodoffset(SP, float4(UV, UV), OFF)
	#define SMAASample(SP, UV) tex2D(SP, UV)
	#define SMAASamplePoint(SP, UV) SMAASample(SP, UV)
	#define SMAASampleOffset(SP, UV, OFF) tex2Doffset(SP, UV, OFF)
	#define SMAA_FLATTEN [flatten]
	#define SMAA_BRANCH [branch]
#if __RENDERER__ & 0x10000
	#define SMAAGather(SP, UV) tex2Dgather(SP, UV, 0)
#endif

#define SMAA_PRESET_CUSTOM
	#define SMAA_THRESHOLD fThreshold
	#define SMAA_MAX_SEARCH_STEPS iSearchSteps
	#define SMAA_MAX_SEARCH_STEPS_DIAG iSearchSteps_Diagonal
	#define SMAA_CORNER_ROUNDING iCornerRounding

#include "SMAA.fxh"

void VS_EdgeDetection(
	uint id              : SV_VERTEXID,
	out float4 position  : SV_POSITION,
	out float2 uv        : TEXCOORD0,
	out float4 offset[3] : TEXCOORD1
) {
	PostProcessVS(id, position, uv);
	SMAAEdgeDetectionVS(uv, offset);
}

float4 PS_EdgeDetection(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD0,
	float4 offset[3] : TEXCOORD1
) : SV_TARGET {
	#if SMAA_FX_EDGE_DETECTION_TYPE == DEPTH
	return float4(SMAADepthEdgeDetectionPS(uv, offset, sDepthBuffer), 0.0, 0.0);
	#elif SMAA_FX_EDGE_DETECTION_TYPE == LUMA
	return float4(SMAALumaEdgeDetectionPS(uv, offset, sBackBuffer_Gamma), 0.0, 0.0);
	#elif SMAA_FX_EDGE_DETECTION_TYPE == COLOR
	return float4(SMAAColorEdgeDetectionPS(uv, offset, sBackBuffer_Gamma), 0.0, 0.0);
	#endif
}

void VS_BlendingWeightCalculation(
	uint id              : SV_VERTEXID,
	out float4 position  : SV_POSITION,
	out float2 uv        : TEXCOORD0,
	out float2 coord     : TEXCOORD1,
	out float4 offset[3] : TEXCOORD2
) {
	PostProcessVS(id, position, uv);
	SMAABlendingWeightCalculationVS(uv, coord, offset);
}

float4 PS_BlendingWeightCalculation(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD0,
	float2 coord     : TEXCOORD1,
	float4 offset[3] : TEXCOORD2
) : SV_TARGET {
	return SMAABlendingWeightCalculationPS(uv, coord, offset, sEdges, sArea, sSearch, 0.0);
}

void VS_NeighborhoodBlending(
	uint id             : SV_VERTEXID,
	out float4 position : SV_POSITION,
	out float2 uv       : TEXCOORD0,
	out float4 offset   : TEXCOORD1
) {
	PostProcessVS(id, position, uv);
	SMAANeighborhoodBlendingVS(uv, offset);
}

float4 PS_NeighborhoodBlending(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD0,
	float4 offset   : TEXCOORD1
) : SV_TARGET {
	#if SMAA_FX_DEBUG
	if (iDebug == 1)
		return tex2D(sEdges, uv);
	if (iDebug == 2)
		return tex2D(sBlend, uv);
	#endif

	return SMAANeighborhoodBlendingPS(uv, offset, sBackBuffer_Linear, sBlend);
}

technique SMAA {
	pass EdgeDetection {
		VertexShader = VS_EdgeDetection;
		PixelShader  = PS_EdgeDetection;
		RenderTarget = tSMAA_Edges;
		ClearRenderTargets = true;
		StencilEnable = true;
		StencilPass = REPLACE;
		StencilRef = 1;
	}
	pass BlendingWeightCalculation {
		VertexShader = VS_BlendingWeightCalculation;
		PixelShader  = PS_BlendingWeightCalculation;
		RenderTarget = tSMAA_Blend;
		ClearRenderTargets = true;
		StencilEnable = true;
		StencilPass = KEEP;
		StencilFunc = EQUAL;
		StencilRef = 1;
	}
	pass NeighborhoodBlending {
		VertexShader    = VS_NeighborhoodBlending;
		PixelShader     = PS_NeighborhoodBlending;
		SRGBWriteEnable = true;
		StencilEnable = false;
	}
}

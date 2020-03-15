#include "ReShade.fxh"

float4 PS_DepthTest(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	return float4(ReShade::GetLinearizedDepth(uv).xxx, 1.0);
}

technique DepthTest {
	pass {
		VertexShader = PostProcessVS;
		PixelShader  = PS_DepthTest;
	}
}

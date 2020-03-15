#include "ReShade.fxh"

float4 PS_Normals(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
	float depth = ReShade::GetLinearizedDepth(uv);

	return float4(depth.xxx, 1.0);
}

technique RimLighting {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_Normals;
	}
}

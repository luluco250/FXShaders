#include "ReShade.fxh"

uniform float fFade <
	ui_label = "Fade";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.01;
> = 1.0;

float3 fade(float3 col, float w) {
	return col * pow(w, float3(4.0, 2.0, 1.0));
}

float4 PS_SonicFade(
	float4 pos : SV_POSITION,
	float2 uv : TEXCOORD
) : SV_TARGET {
	float3 col = tex2D(ReShade::BackBuffer, uv).rgb;

	col = fade(col, fFade);

	return float4(col, 1.0);
}

technique SonicFade {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_SonicFade;
	}
}

#include "ReShade.fxh"

uniform float fIntensity <
	ui_label = "Intensity";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 3.0;
	ui_step = 0.001;
> = 1.0;

uniform float fSharpness <
	ui_label = "Sharpness";
	ui_type = "drag";
	ui_min = 0.001;
	ui_max = 3.0;
	ui_step = 0.001;
> = 1.0;

float get_vignette(float2 uv) {
	return 1.0 - pow(distance(uv, 0.5) * fIntensity, fSharpness);
}

float4 PS_Vignette(
	float4 pos : SV_POSITION,
	float2 uv : TEXCOORD
) : SV_TARGET {
	float3 col = tex2D(ReShade::BackBuffer, uv).rgb;
	float vignette = get_vignette(uv);
	
	col *= vignette;

	return float4(col, 1.0);
}

technique Vignette {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_Vignette;
	}
}

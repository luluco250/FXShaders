#include "ReShade.fxh"

uniform float fIntensity <
	ui_label = "Intensity";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 10.0;
	ui_step  = 0.001;
> = 1.0;

uniform bool bViewEdges <
	ui_label = "View Edges";
> = false;

sampler2D sBackBuffer {
	Texture = ReShade::BackBufferTex;
	SRGBTexture = true;
};

float3 get_tex(float2 uv) {
	return tex2D(sBackBuffer, uv).rgb;
}

float3 get_tex(float2 uv, float2 offset) {
	return tex2D(sBackBuffer, uv + ReShade::PixelSize * offset).rgb;
}

float3 lerp3(float3 a, float3 b, float3 w) {
	return float3(
		lerp(a.x, b.x, w.x),
		lerp(a.y, b.y, w.y),
		lerp(a.z, b.z, w.z)
	);
}

void PS_EdgeAA(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD,
	out float4 color : SV_TARGET
) {
	color = tex2D(sBackBuffer, uv);

	static const float2 points[8] = {
		float2(-1.0, 1.0), float2( 0.0, 1.0), float2( 1.0, 1.0),
		float2(-1.0, 0.0),                    float2( 1.0, 0.0),
		float2(-1.0,-1.0), float2( 0.0,-1.0), float2( 1.0,-1.0)
	};

	float3 total = 0.0;
	float3 accum = 0.0;
	
	[unroll]
	for (int i = 0; i < 8; ++i) {
		float3 point = tex2D(sBackBuffer, uv + ReShade::PixelSize * points[i]).rgb;
		float3 diff  = abs(color.rgb - point);
		total += point * diff;
		accum += diff;
	}
	total /= accum;

	color.rgb = (color.rgb + total.rgb) / 2;

	/*float3 top       = get_tex(uv, float2( 0.0,-1.0));
	float3 bottom    = get_tex(uv, float2( 0.0, 1.0));
	float3 right     = get_tex(uv, float2( 1.0, 0.0));
	float3 left      = get_tex(uv, float2(-1.0, 0.0));

	float3 diff_top    = (1.0 - abs(color.rgb - top))    * fIntensity;
	float3 diff_bottom = (1.0 - abs(color.rgb - bottom)) * fIntensity;
	float3 diff_right  = (1.0 - abs(color.rgb - right))  * fIntensity;
	float3 diff_left   = (1.0 - abs(color.rgb - left))   * fIntensity;

	if (bViewEdges) {
		color.rgb  = diff_top + diff_bottom + diff_right + diff_left;
		color.rgb *= 0.25;
		return;
	}

	float3 accum = 1.0;

	color.rgb += top * diff_top;
	accum += diff_top;
	color.rgb += bottom * diff_bottom;
	accum += diff_bottom;
	color.rgb += right * diff_right;
	accum += diff_right;
	color.rgb += left * diff_left;
	accum += diff_left;
	
	color.rgb /= accum;*/

	/*color.rgb = lerp3(center, top, diff_top);
	color.rgb = lerp3(center, bottom, diff_bottom);
	color.rgb = lerp3(center, right, diff_right);
	color.rgb = lerp3(center, left, diff_left);*/
}

technique EdgeAA {
	pass {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_EdgeAA;
		SRGBWriteEnable = true;
	}
}

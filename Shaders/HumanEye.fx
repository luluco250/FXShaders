#include "ReShade.fxh"

uniform float fLuma_Influence <
	ui_label = "Luma Influence";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 1000.0;
	ui_step  = 0.1;
> = 300.0;

uniform float fContrast <
	ui_label = "Contrast";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 1.0;
	ui_step  = 0.001;
> = 0.5;

sampler2D sBackBuffer {
	Texture     = ReShade::BackBufferTex;
	SRGBTexture = true;
};

float get_luma_linear(float3 color) {
	return dot(color, float3(0.2126, 0.7152, 0.0722));
}

float3 rgb2hsv(float3 c) {
    float4 K = float4(0.0, -1.0 / 3.0, 2.0 / 3.0, -1.0);
    float4 p = lerp(float4(c.bg, K.wz), float4(c.gb, K.xy), step(c.b, c.g));
    float4 q = lerp(float4(p.xyw, c.r), float4(c.r, p.yzx), step(p.x, c.r));
 
    float d = q.x - min(q.w, q.y);
    float e = 1.0e-10;
    return float3(abs(q.z + (q.w - q.y) / (6.0 * d + e)), d / (q.x + e), q.x);
}

float3 hsv2rgb(float3 c) {
    float4 K = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
    float3 p = abs(frac(c.xxx + K.xyz) * 6.0 - K.www);
    return c.z * lerp(K.xxx, saturate(p - K.xxx), c.y);
}

float4 PS_RodCell(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	/*float3 color = tex2D(sBackBuffer, uv).rgb;
	float luma = get_luma_linear(color);
	float total_light = color.r + color.g + color.b;
	total_light = saturate(total_light * 10.0);

	float3 rod_hsv = float3(0.58, 0.698, total_light);
	float3 rod_cell = hsv2rgb(float3(0.58, 0.698, color.r + color.g + color.b));

	color = lerp(rod_cell * 1.5, color, smoothstep(0.0, 1.0, luma * fLuma_Influence));*/

	float3 center = tex2D(sBackBuffer, uv).rgb;

	static const float filter[9] = {
		0.25,  0.50,  0.25,
		0.50,  1.00,  0.50,
		0.25,  0.50,  0.25
	};
	static const float2 offsets[9] = {
		float2(-1.0,-1.0), float2( 0.0,-1.0), float2( 1.0,-1.0),
		float2(-1.0, 0.0), float2( 0.0, 0.0), float2( 1.0, 0.0),
		float2(-1.0, 1.0), float2( 0.0, 1.0), float2( 1.0, 1.0)
	};
	float3 color = 0.0;
	float accum = 0.0;

	[unroll]
	for (int i = 0; i < 9; ++i) {
		if (i == 4)
			color += center * filter[i];
		else
			color += tex2D(sBackBuffer, uv + ReShade::PixelSize * offsets[i]).rgb * filter[i];
		accum += filter[i];
	}
	color /= accum;
	color = saturate(color);

	color = lerp(center, color, (fContrast - 0.5) * 2.0);

	return float4(color, 1.0);
}

technique HumanEye {
	pass RodCell {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_RodCell;
		//RenderTarget    = tHumanEye_RodCell;
		SRGBWriteEnable = true;
	}
}

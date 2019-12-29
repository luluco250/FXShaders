#include "ReShade.fxh"

#ifndef ASPECT_RATIOS_VALUES
#define ASPECT_RATIOS_VALUES 1.0, 16.0 / 9.0, 4.0 / 3.0
#endif

#ifndef ASPECT_RATIOS_VALUES_COUNT
#define ASPECT_RATIOS_VALUES_COUNT 3
#endif

static const float ASPECT_RATIOS[] = {ASPECT_RATIOS_VALUES};

uniform bool ShowBlackBackground <
	ui_label = "Show Black Background";
	ui_tooltip = "Default: Off";
> = false;

float3 hsv_to_rgb(float3 hsv)
{
	float4 k = float4(1.0, 2.0 / 3.0, 1.0 / 3.0, 3.0);
	float3 p = abs(frac(hsv.xxx + k.xyz) * 6.0 - k.www);
	return hsv.z * lerp(k.xxx, saturate(p - k.xxx), hsv.y);
}

float apply_ratio(float2 uv, float ar)
{
	// Is the letterboxing horizontal or vertical?
	float hori = step(ReShade::AspectRatio, ar);
	float pos = lerp(uv.x, uv.y, hori);
	float pixel = lerp(BUFFER_RCP_WIDTH, BUFFER_RCP_HEIGHT, hori);

	float ratio = lerp(
		ar / ReShade::AspectRatio,
		ReShade::AspectRatio / ar,
		hori
	);
	float mask = (1.0 - ratio) * 0.5;
	float inv_mask = 1.0 - mask;
	
	return
		(step(pos, mask - pixel) + step(mask + pixel, pos)) *
		(step(pos, inv_mask - pixel) + step(inv_mask + pixel, pos));
}

float4 MainPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
	float4 color = tex2D(ReShade::BackBuffer, uv);
	color = ShowBlackBackground ? float4(0.0, 0.0, 0.0, 1.0) : color;

	[unroll]
	for (int i = 0; i < ASPECT_RATIOS_VALUES_COUNT; ++i)
	{
		float3 ratio_color = hsv_to_rgb(float3(
			float(i) / ASPECT_RATIOS_VALUES_COUNT, 1.0, 1.0));
		float lines = apply_ratio(uv, ASPECT_RATIOS[i]);
		
		color.rgb = lerp(ratio_color, color.rgb, lines);
	}

	return color;
}

technique AspectRatios
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = MainPS;
	}
}
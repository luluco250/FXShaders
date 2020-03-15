#include "ReShade.fxh"

#ifndef LUT_CELL_SIZE
#define LUT_CELL_SIZE 16
#endif

#ifndef LUT_CELL_COUNT
#define LUT_CELL_COUNT 16
#endif

#ifndef LUT_FILE_NAME
#define LUT_FILE_NAME "lut.png"
#endif

texture2D tLUT <
	source = LUT_FILE_NAME;
> {
	Width = LUT_CELL_SIZE * LUT_CELL_COUNT;
	Height = LUT_CELL_SIZE;
};
sampler2D sLUT {
	Texture = tLUT;
};

/*float3 apply_lut(float3 color) {
	static const float inv_size = 1.0 / LUT_CELL_SIZE;

	float b = color.b * (LUT_CELL_COUNT - 1.0);
	float f = frac(b);

	float2 uv = color.rg;
	uv.x += b - f; // floor(b)
	uv.x *= inv_size;

	float3 color1 = tex2D(sLUT, uv).rgb;
	float3 color2 = tex2D(sLUT, float2(uv.x + inv_size, uv.y)).rgb;

	return lerp(color1, color2, f);
}*/

float3 apply_lut(float3 color) {
	static const float inv_size = 1.0 / LUT_CELL_SIZE;
	static const float inv_count = 1.0 / LUT_CELL_COUNT;

	float2 ps = float2(inv_size * inv_count, inv_size);

	float b = color.b * LUT_CELL_SIZE - color.b;
	float f = frac(b);

	float2 uv = color.rg * LUT_CELL_SIZE - color.rg + 0.5;
	uv *= ps;
	uv.x += (b - f) * inv_size; // floor(b)

	color = lerp(
		tex2D(sLUT, uv).rgb,
		tex2D(sLUT, float2(uv.x + ps.x, uv.y)).rgb,
		f
	);

	color = normalize(color) * length(color);
	return color;
}

float4 PS_LUT(
	float4 position : SV_POSITION,
	float2 uv : TEXCOORD
) : SV_TARGET {
	float3 color = tex2D(ReShade::BackBuffer, uv).rgb;
	color = apply_lut(color);
	return float4(color, 1.0);
}

technique LUT {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_LUT;
	}
}

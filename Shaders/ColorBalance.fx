#include "ReShade.fxh"

uniform float3 f3Shadows <
	ui_label = "Color Balance - Shadows";
	ui_type  = "color";
	ui_min   = 0.0;
	ui_max   = 1.0;
	ui_step  = 0.001;
> = float3(0.0, 0.0, 0.0);

uniform float3 f3Midtones <
	ui_label = "Color Balance - Midtones";
	ui_type  = "color";
	ui_min   = 0.0;
	ui_max   = 1.0;
	ui_step  = 0.001;
> = float3(0.0, 0.0, 0.0);

uniform float3 f3Highlights <
	ui_label = "Color Balance - Highlights";
	ui_type  = "color";
	ui_min   = 0.0;
	ui_max   = 1.0;
	ui_step  = 0.001;
> = float3(0.0, 0.0, 0.0);

uniform bool bPreserveLum <
	ui_label = "Color Balance - Preserve Luminosity";
> = true;

uniform float fIntensity <
	ui_label = "Color Balance - Intensity";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 1.0;
	ui_step  = 0.001;
> = 0.0;

sampler2D sColorBalance_BackBuffer {
	Texture = ReShade::BackBufferTex;
	SRGBTexture = true;
};

float3 rgb2hsl(float3 col) {
	float _min = min(col.r, min(col.g, col.b));
	float _max = max(col.r, max(col.g, col.b));
	float delta = _max - _min;

	float3 hsl;
	hsl.z = (_max + _min) * 0.5;

	if (delta == 0.0) {
		hsl.x = 0.0;
		hsl.y = 0.0;
	} else {
		if (hsl.z < 0.5)
			hsl.y = delta / (_max + _min);
		else
			hsl.y = delta / (2.0 - _max - _min);
		
		float3 col_delta = (((_max - col) / 6.0) + (delta / 2.0)) / delta;

		if (col.r == _max)
			hsl.x = col_delta.b - col_delta.g;
		else if (col.g == _max)
			hsl.x = (1.0 / 3.0) + col_delta.r - col_delta.b;
		else if (col.b == _max)
			hsl.x = (2.0 / 3.0) + col_delta.g - col_delta.r;

		if (hsl.x < 0.0)
			hsl.x += 1.0;
		else if (hsl.x > 1.0)
			hsl.x -= 1.0;
	}

	return hsl;
}

float hue2rgb(float a, float b, float hue) {
	if (hue < 0.0)
		hue += 1.0;
	else if (hue > 1.0)
		hue -= 1.0;
	//hue += (hue < 0.0) ? 1.0 : (hue > 1.0) ? -1.0 : 0.0;
	
	if ((6.0 * hue) < 1.0)
		return a + (b - a) * 6.0 * hue;
	else if ((2.0 * hue) < 1.0)
		return b;
	else if ((3.0 * hue) < 2.0)
		return a + (b - a) * ((2.0 / 3.0) - hue) * 6.0;
	else
		return a;
}

float3 hsl2rgb(float3 hsl) {
	if (hsl.y == 0.0) {
		return hsl.z;
	} else {
		float f2;

		if (hsl.z < 0.5)
			f2 = hsl.z * (1.0 + hsl.y);
		else
			f2 = (hsl.z + hsl.y) - (hsl.y * hsl.z);
		
		float f1 = 2.0 * hsl.z - f2;

		return float3(
			hue2rgb(f1, f2, hsl.x + (1.0 / 3.0)),
			hue2rgb(f1, f2, hsl.x),
			hue2rgb(f1, f2, hsl.x - (1.0 / 3.0))
		);
	}
}

float rgb2l(float3 col) {
	float _min = min(col.r, min(col.g, col.b));
	float _max = max(col.r, max(col.g, col.b));
	return (_max + _min) * 0.5;
}

void PS_ColorBalance(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD,
	out float4 color : SV_TARGET
) {
	color = tex2D(sColorBalance_BackBuffer, uv);
	float3 lightness = color.rgb;

	static const float a = 0.25;
	static const float b = 0.333;
	static const float scale = 0.7;

	float3 shadows = f3Shadows * (saturate((lightness - b) / -a + 0.5) * scale);
	float3 midtones = f3Midtones * (saturate((lightness - b) / a + 0.5) *
	                                   saturate((lightness + b - 1.0) / -a + 0.5) * scale);
	float3 highlights = f3Highlights * (saturate((lightness + b - 1.0) / a + 0.5) * scale);

	float3 new_col = saturate(color.rgb + shadows + midtones + highlights);

	if (bPreserveLum) {
		float3 new_hsl = rgb2hsl(new_col);
		float old_lum = rgb2l(color.rgb);
		color.rgb = lerp(color.rgb, hsl2rgb(float3(new_hsl.x, new_hsl.y, old_lum)), fIntensity);
	} else {
		color.rgb = lerp(color.rgb, new_col, fIntensity);
	}
}

technique ColorBalance {
	pass {
		VertexShader = PostProcessVS;
		PixelShader  = PS_ColorBalance;
		SRGBWriteEnable = true;
	}
}

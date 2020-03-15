#include "ReShade.fxh"

#ifndef PHOTO_RAYS_SAMPLES
#define PHOTO_RAYS_SAMPLES 12
#endif

#ifndef PHOTO_RAYS_DOWNSCALE
#define PHOTO_RAYS_DOWNSCALE 1
#endif

uniform float uIntensity <
	ui_label = "Intensity";
	ui_tooltip = "Default: 1.0";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.001;
> = 1.0;

uniform float uDepthThreshold <
	ui_label = "Threshold";
	ui_tooltip = "Default: 3.0";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = 0.9;

uniform float uFallOff <
	ui_label = "Fall-Off";
	ui_tooltip = "Default: 0.0";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.001;
> = 0.0;

uniform float2 uCenter <
	ui_label = "Center";
	ui_tooltip = "Default: 0.5 0.5";
	ui_type = "drag";
	ui_min = -2.0;
	ui_max = 2.0;
	ui_step = 0.001;
> = float2(0.5, 0.5);

uniform float uScale <
	ui_label = "Scale";
	ui_tooltip = "Default: 0.1";
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = 25.0;
	ui_step = 0.001;
> = 1.0;

texture2D tPhotoRays_Prepared {
	Width = BUFFER_WIDTH / PHOTO_RAYS_DOWNSCALE;
	Height = BUFFER_HEIGHT / PHOTO_RAYS_DOWNSCALE;
};
sampler2D sPrepared {
	Texture = tPhotoRays_Prepared;
	AddressU = BORDER;
	AddressV = BORDER;
};

float4 PS_Prepare(
	float4 position : SV_POSITION,
	float2 uv : TEXCOORD
) : SV_TARGET {
	float3 color = tex2D(ReShade::BackBuffer, uv).rgb;
	float depth = ReShade::GetLinearizedDepth(uv);
	color *= depth * step(uDepthThreshold, depth);
	//color = pow(abs(color), uThreshold);
	// color *= step(uThreshold, color);
	return float4(color, 1.0);
}

float4 PS_ApplyRays(
	float4 position : SV_POSITION,
	float2 uv : TEXCOORD
) : SV_TARGET {
	float3 color = tex2D(ReShade::BackBuffer, uv).rgb;
	float3 rays = 0.0;
	float accum = 0.0;

	uv -= uCenter;

	[unroll]
	for (int i = 1; i < PHOTO_RAYS_SAMPLES; ++i) {
		// float weight = lerp(1.0, PHOTO_RAYS_SAMPLES - i, uFallOff);
		float weight = PHOTO_RAYS_SAMPLES - i;

		uv /= (PHOTO_RAYS_SAMPLES * (1.0 + uScale * 0.001)) / PHOTO_RAYS_SAMPLES;
		rays += tex2D(sPrepared, uv + uCenter).rgb * weight;
		accum += weight;
	}
	rays /= accum;

	color = 1.0 - (1.0 - color) * (1.0 - rays * uIntensity);
	
	return float4(color, 1.0);
}

technique PhotoRays {
	pass Prepare {
		VertexShader = PostProcessVS;
		PixelShader = PS_Prepare;
		RenderTarget = tPhotoRays_Prepared;
	}
	pass ApplyRays {
		VertexShader = PostProcessVS;
		PixelShader = PS_ApplyRays;
	}
}

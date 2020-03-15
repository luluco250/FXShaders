#include "ReShade.fxh"

#ifndef MOTION_BLUR_SEPARATE_CHANNELS
#define MOTION_BLUR_SEPARATE_CHANNELS 0
#endif

uniform float fShutterSpeed <
	ui_label   = "Shutter Speed";
	ui_tooltip = "The higher this value, the more motion blur.\n"
	             "\nDefault: 1.0";
	ui_type    = "drag";
	ui_min     = 0.001;
	ui_max     = 100.0;
	ui_step    = 0.001;
> = 15.0;

#if MOTION_BLUR_SEPARATE_CHANNELS
uniform float3 f3ChannelScales <
	ui_label   = "Channel Scales";
	ui_tooltip = "These values control the RGB channel speed scales.\n"
	             "\nDefault: (0.25, 0.5, 1.0)";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = float3(0.25, 0.5, 1.0);
#endif

uniform float fFrameTime <source = "frametime";>;

sampler2D sBackBuffer {
	Texture = ReShade::BackBufferTex;
	SRGBTexture = true;
};

texture2D tMotionBlur_Last {
	Width  = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
};
sampler2D sMotionBlur_Last {
	Texture     = tMotionBlur_Last;
	SRGBTexture = true;
};

float4 PS_Blend(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 curr = tex2D(sBackBuffer, uv).rgb;
	float3 last = tex2D(sMotionBlur_Last, uv).rgb;
	
	#if MOTION_BLUR_SEPARATE_CHANNELS
	float3 speed = fShutterSpeed * f3ChannelScales;
	#else
	float speed = fShutterSpeed;
	#endif

	curr = lerp(last, curr, saturate(fFrameTime / speed));
	return float4(curr, 1.0);
}

float4 PS_Save(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	return tex2D(sBackBuffer, uv);
}

technique MotionBlur {
	pass Blend {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_Blend;
		SRGBWriteEnable = true;
	}
	pass Save {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_Save;
		RenderTarget    = tMotionBlur_Last;
		SRGBWriteEnable = true;
	}
}

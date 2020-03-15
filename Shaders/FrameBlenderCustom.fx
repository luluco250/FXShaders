/*
	Frame Blender by luluco250
	
	Collects and blends frames to simulate motion blur.
*/

#include "ReShade.fxh"

//user variables////////////////////////////////////////////////////////////////////////////////////////////////

uniform float fFrameBlender_Intensity <
	ui_label = "Blending Intensity [Frame Blender]";
	ui_tooltip = "How much are the blended frames applied to the original image.";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
> = 0.8;

uniform float fFrameBlender_ShutterSpeed <
	ui_label = "Shutter Speed [Frame Blender]";
	ui_tooltip = "How slow are the camera lenses to capture the image in motion.\nThat just means that lower values will provide a more intense amount of blending/motion blur.";
	ui_type = "drag";
	ui_min = 0.01;
	ui_max = 0.1;
> = 0.01;

uniform bool bFrameBlender_UseNoise <
	ui_label = "Use Noise [Frame Blender]";
	ui_tooltip = "Use random noise to smooth frame blending.\nSeen in Sonic Ether's Unbelievable Shaders for Minecraft's motion blur.";
> = true;

uniform float2 f2FrameBlender_NoiseCurve <
	ui_label = "Noise Curve [FrameBlender]";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 1.0;
	ui_step  = 0.001;
> = float2(0.0, 1.0);

uniform float fFrameBlender_NoiseSpeed <
	ui_label = "Noise Speed [Frame Blender]";
	ui_type  = "drag";
	ui_min   = 0.0;
	ui_max   = 100.0;
	ui_step  = 0.001;
> = 1.0;

uniform float2 f2FrameBlender_Vignette <
	ui_label = "Vignette Mask [Frame Blender]";
	ui_tooltip = "Masks out previous frames within a vignette-ish mask.\nVignette is simply how close to the center of the screen a pixel is, so the center of the screen will not have as much blending.\nThis was used in Halo 3 to give better focus to the center of the screen.\nFirst value determines the intensity.\nSecond value determines the curve.";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 3.0;
> = float2(0.0, 1.0);

uniform bool bFrameBlender_ViewVignette <
	ui_label = "View Vignette Mask [Frame Blender]";
	ui_tooltip = "Visualize the mask that'll be applied to blending.\nBrighter pixels will have less blending applied to them.";
> = false;

//system variables//////////////////////////////////////////////////////////////////////////////////////////////

//we'll use the time it took to render a frame (reciprocal of framerate) to avoid ghosting when the FPS is low
uniform float fFrameBlender_FrameTime <source="frametime";>;
uniform float fTime <source = "timer";>;

//textures//////////////////////////////////////////////////////////////////////////////////////////////////////

texture tFrameBlender_LastFrame { Width=BUFFER_WIDTH; Height=BUFFER_HEIGHT; };

//samplers//////////////////////////////////////////////////////////////////////////////////////////////////////

sampler sFrameBlender_LastFrame { Texture=tFrameBlender_LastFrame; };

//functions/////////////////////////////////////////////////////////////////////////////////////////////////////

float getNoise(float2 uv) {
	//return saturate(frac(sin(dot(uv + fFrameBlender_FrameTime, float2(12.9898, 78.233))) * 43758.5453));
	
	float t     = (fTime*0.001) * fFrameBlender_NoiseSpeed;
	float3 color = tex2D(ReShade::BackBuffer, uv).rgb;
    float seed  = dot(uv + fFrameBlender_FrameTime, float2(12.9898, 78.233));
    float noise = frac(sin(seed) * 43758.5453 + t);
    float lum   = max(color.r, max(color.g, color.b));
	noise = smoothstep(f2FrameBlender_NoiseCurve.x, f2FrameBlender_NoiseCurve.y, noise);
	
	return noise;
}

float getVignette(float2 uv) {
	return saturate(lerp(1, distance(uv, 0.5) * f2FrameBlender_Vignette.y, f2FrameBlender_Vignette.x));
}

//shaders///////////////////////////////////////////////////////////////////////////////////////////////////////

//shader that blends the previous frame with the current one
float3 Blend(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target {
	float3 org = tex2D(ReShade::BackBuffer, uv).rgb;
	float weight = saturate(fFrameBlender_FrameTime * fFrameBlender_ShutterSpeed) * (bFrameBlender_UseNoise ? getNoise(uv) : 1.0);
	float3 col = lerp(tex2D(sFrameBlender_LastFrame, uv).rgb, org, weight);
	col = lerp(org, col, lerp(0, fFrameBlender_Intensity, getVignette(uv)));
	
	return bFrameBlender_ViewVignette ? 1.0 - getVignette(uv) : col;
}

//shader that saves the previous frame
float3 Save(float4 pos : SV_Position, float2 uv : TEXCOORD0) : SV_Target {
	return tex2D(ReShade::BackBuffer, uv).rgb;
}

//techniques////////////////////////////////////////////////////////////////////////////////////////////////////

technique FrameBlender_Blend {
	pass Blend {
		VertexShader=PostProcessVS;
		PixelShader=Blend;
	}
	pass Save {
		VertexShader=PostProcessVS;
		PixelShader=Save;
		RenderTarget=tFrameBlender_LastFrame;
	}
}

/*
	Light Depth of Field 2 by luluco250
*/

#include "ReShade.fxh"

//Macros//////////////////////////////////////////////////////////////////////////////////////////////////////

#define MANUAL 0
#define AUTO 1
#define AUTOMATIC AUTO

#ifndef LIGHT_DOF_2_FOCUS_MODE
#define LIGHT_DOF_2_FOCUS_MODE AUTO
#endif

#ifndef LIGHT_DOF_2_AUTO_FOCUS_RES
#define LIGHT_DOF_2_AUTO_FOCUS_RES 256
#endif

#ifndef LIGHT_DOF_2_BLUR_SAMPLES
#define LIGHT_DOF_2_BLUR_SAMPLES 9
#endif

#define _tex2D(SP, UV) tex2Dlod(SP, float4(UV, 0.0, 0.0))

//Constants///////////////////////////////////////////////////////////////////////////////////////////////////

#if LIGHT_DOF_2_FOCUS_MODE == AUTO
static const float max_precision = int(log(LIGHT_DOF_2_AUTO_FOCUS_RES) / log(2)) + 1;
#endif

//Uniforms////////////////////////////////////////////////////////////////////////////////////////////////////

uniform float fBlur_Scale <
	ui_label   = "Blur Scale";
	ui_tooltip = "Default: 1.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 100.0;
	ui_step    = 0.01;
> = 1.0;

uniform float fBlur_Noise <
	ui_label   = "Blur Noise";
	ui_tooltip = "Default: 0.25";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = 0.25;

uniform float2 f2CoC <
	ui_label   = "Circle of Confusion";
	ui_tooltip = "Default: (0.0, 1.0)";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = float2(0.0, 1.0);

#if LIGHT_DOF_2_FOCUS_MODE == AUTO
uniform bool bUseMouseFocus <
	ui_label   = "Use Mouse Auto Focus";
	ui_tooltip = "Default: Off";
> = false;

uniform float2 f2AutoFocus_Point <
	ui_label   = "Auto Focus Point";
	ui_tooltip = "Default: (0.5, 0.5)";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = float2(0.5, 0.5);

uniform float fAutoFocus_Precision <
	ui_label   = "Auto Focus Precision";
	ui_tooltip = "Default: 0.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = max_precision;
	ui_step    = 0.001;
> = 0.0;

uniform float fAutoFocus_Time <
	ui_label   = "Auto Focus Time";
	ui_tooltip = "Default: 1.0";
	ui_type    = "drag";
	ui_min     = 0.05;
	ui_max     = 1000.0;
	ui_step    = 0.01;
> = 1.0;
#endif

#if LIGHT_DOF_2_FOCUS_MODE == AUTO
uniform float2 f2MousePoint <source = "mousepoint";>;
uniform float fFrameTime <source = "frametime";>;
uniform float fTimer <source = "timer";>;
#endif

//Textures////////////////////////////////////////////////////////////////////////////////////////////////////

sampler2D sBackBuffer {
	Texture     = ReShade::BackBufferTex;
	SRGBTexture = true;
};

sampler2D sBackBuffer_Point {
	Texture     = ReShade::BackBufferTex;
	SRGBTexture = true;
	MinFilter   = POINT;
	MagFilter   = POINT;
};

texture2D tLightDOF2_Blur {
	Width  = BUFFER_WIDTH / 2;
	Height = BUFFER_HEIGHT / 2;
	Format = RGBA16F;
};
sampler2D sBlur {
	Texture = tLightDOF2_Blur;
};

#if LIGHT_DOF_2_FOCUS_MODE == AUTO
texture2D tLightDOF2_Small {
	Width     = LIGHT_DOF_2_AUTO_FOCUS_RES;
	Height    = LIGHT_DOF_2_AUTO_FOCUS_RES;
	Format    = R8;
	MipLevels = max_precision;
};
sampler2D sSmall {
	Texture = tLightDOF2_Small;
};

texture2D tLightDOF2_Focus {};
sampler2D sFocus {
	Texture   = tLightDOF2_Focus;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
};

texture2D tLightDOF2_LastFocus {};
sampler2D sLastFocus {
	Texture   = tLightDOF2_LastFocus;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
};
#endif

//Functions///////////////////////////////////////////////////////////////////////////////////////////////////

float2 rotate(float2 coord, float angle, float length) {
	float s, c;
	sincos(angle, s, c);
	return float2(
		coord.x * c - coord.y * s,
		coord.y * c + coord.x * s
	) * length;
}

// get circle of confusion
float get_coc(float2 uv) {
	float z = ReShade::GetLinearizedDepth(uv);
	z = smoothstep(f2CoC.x, f2CoC.y, z);
	return z;
}

float fmod(float a, float b) {
	float c = frac(abs(a / b)) * abs(b);
	return (a < 0) ? -c : c;
}

float2 fmod(float2 a, float2 b) {
	float2 c = frac(abs(a / b)) * abs(b);
	return (a < 0) ? -c : c;
}

float rand(float2 uv) {
    static const float a  = 12.9898;
    static const float b  = 78.233;
    static const float c  = 43758.5453;
    const float dt = dot(uv, float2(a,b));
    const float sn = fmod(dt, 3.1415);
    return frac(sin(sn) * c);
}

//Shaders/////////////////////////////////////////////////////////////////////////////////////////////////////

#if LIGHT_DOF_2_FOCUS_MODE == AUTO
float4 PS_GetSmall(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	return float4(ReShade::GetLinearizedDepth(uv), 1.0, 1.0, 1.0);
}

float4 PS_GetFocus(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float2 focus_uv;
	if (bUseMouseFocus)
		focus_uv = f2MousePoint * ReShade::PixelSize;
	else
		focus_uv = f2AutoFocus_Point;

	float z = tex2Dlod(sSmall, float4(focus_uv, 0.0, max_precision - fAutoFocus_Precision)).x;
	float last = tex2Dfetch(sLastFocus, (int4)0).x;

	z = lerp(last, z, fFrameTime / fAutoFocus_Time);
	return float4(z, 0.0, 0.0, 0.0);
}

float4 PS_SaveFocus(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	return tex2Dfetch(sFocus, (int4)0);
}
#endif

float4 PS_Blur(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float2 ps = ReShade::PixelSize * fBlur_Scale;
	float4 color = float4(tex2D(sBackBuffer, uv).rgb, 1.0);

	#define fetch(uv) float4(_tex2D(sBackBuffer, uv).rgb, 1.0)
	#define ANGLE_SAMPLES 16
	#define OFFSET_SAMPLES 4
	#define radian2degree(a) (a * 57.295779513082)
    #define degree2radian(a) (a * 0.017453292519)

	ps *= lerp(1.0, rand(uv), fBlur_Noise);

	//float coc = get_coc(uv);
	//ps *= coc;

	//if (coc > 0.0) {
		for (int a = 0; a < 360; a += 360 / ANGLE_SAMPLES) {
			for (int o = 1; o < OFFSET_SAMPLES; ++o) {
				float2 dir = rotate(float2(0.0, 1.0), degree2radian(a), o);
				color += fetch(uv + ps * dir * get_coc(uv + ps * dir)) * o * o;
			}
		}
		color.rgb /= color.a;
	//}

	return float4(color.rgb, 1.0);
}

float4 PS_Blend(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = tex2D(sBackBuffer_Point, uv).rgb;
	float3 blur = tex2D(sBlur, uv).rgb;

	float coc = get_coc(uv);
	color = lerp(color, blur, coc);

	return float4(color, 1.0);
}

//Technique///////////////////////////////////////////////////////////////////////////////////////////////////

technique LightDOF2 {
	#if LIGHT_DOF_2_FOCUS_MODE == AUTO
	pass GetSmall {
		VertexShader = PostProcessVS;
		PixelShader  = PS_GetSmall;
		RenderTarget = tLightDOF2_Small;
	}
	pass GetFocus {
		VertexShader = PostProcessVS;
		PixelShader  = PS_GetFocus;
		RenderTarget = tLightDOF2_Focus;
	}
	pass SaveFocus {
		VertexShader = PostProcessVS;
		PixelShader  = PS_SaveFocus;
		RenderTarget = tLightDOF2_LastFocus;
	}
	#endif
	pass Blur {
		VertexShader = PostProcessVS;
		PixelShader  = PS_Blur;
		RenderTarget = tLightDOF2_Blur;
	}
	pass Blend {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_Blend;
		SRGBWriteEnable = true;
	}
}

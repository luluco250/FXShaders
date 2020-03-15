/*
	MultiFX by luluco250

	A compilation of common post processing effects combined into a single pass.
*/

#include "ReShade.fxh"

//Macros/////////////////////////////////////////////////////////////////////////////////////////////////////////

#define NONE 0
#define SRGB 1
#define CUSTOM

#ifndef MULTIFX_GAMMA_MODE
#define MULTIFX_GAMMA_MODE SRGB
#endif

#ifndef MULTIFX_DEBUG
#define MULTIFX_DEBUG 0
#endif

#ifndef MULTIFX_SRGB
#define MULTIFX_SRGB 1
#endif

#ifndef MULTIFX_CA
#define MULTIFX_CA 1
#endif

#ifndef MULTIFX_VIGNETTE
#define MULTIFX_VIGNETTE 1
#endif

#ifndef MULTIFX_FILMGRAIN
#define MULTIFX_FILMGRAIN 1
#endif

#ifndef MULTIFX_COLOR
#define MULTIFX_COLOR 1
#endif

//Uniforms///////////////////////////////////////////////////////////////////////////////////////////////////////

/*#if MULTIFX_CA
uniform float3 uCA_Intensity <
	ui_label   = "[Chromatic Aberration] Intensity";
	ui_tooltip = "Controls the scale of each color channel in the image. "
	             "(Red, Green, Blue)\n"
				 "Default: (0.0, 0.0, 0.0)";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = float3(0.0, 0.0, 0.0);
#endif*/

uniform float uVignette_Intensity <
	ui_label   = "[Vignette] Opacity";
	ui_tooltip = "Default: 0.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 3.0;
	ui_step    = 0.001;
> = 0.0;

uniform float2 uVignette_StartEnd <
	ui_label   = "[Vignette] Start/End";
	ui_tooltip = "Controls the range/contrast of vignette by defining start "
	             "and end offsets.\n"
				 "\nDefault: (0.0, 1.0)";
	ui_type    = "drag";
	ui_min     =-10.0;
	ui_max     = 10.0;
	ui_step    = 0.001;
> = float2(0.0, 1.0);

uniform float uFilmGrain_Intensity <
	ui_label   = "[Film Grain] Intensity";
	ui_tooltip = "Default: 0.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = 0.0;

uniform float uFilmGrain_Speed <
	ui_label   = "[Film Grain] Speed";
	ui_tooltip = "Default: 1.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 100.0;
	ui_step    = 0.001;
> = 1.0;

uniform float uFilmGrain_Mean <
	ui_label   = "[Film Grain] Mean";
	ui_tooltip = "Default: 0.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = 0.0;

uniform float uFilmGrain_Variance <
	ui_label   = "[Film Grain] Variance";
	ui_tooltip = "Default: 0.5";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = 0.5;

/*#if MULTIFX_DEBUG
uniform bool uFilmGrain_ShowNoise <
	ui_label = "[Film Grain] Show Noise";
	ui_tooltip = "Default: Off";
> = false;
#endif*/

/*#if MULTIFX_COLOR
uniform float uColor_Brightness <
	ui_label   = "[Color] Brightness";
	ui_tooltip = "Default: 1.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 3.0;
	ui_step    = 0.001;
> = 1.0;

uniform float uColor_Contrast <
	ui_label   = "[Color] Contrast";
	ui_tooltip = "Default: 1.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 3.0;
	ui_step    = 0.001;
> = 1.0;

uniform float uColor_Saturation <
	ui_label   = "[Color] Saturation";
	ui_tooltip = "Default: 1.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 3.0;
	ui_step    = 0.001;
> = 1.0;

uniform float uColor_Temperature <
	ui_label   = "[Color] Temperature";
	ui_tooltip = "Default: 0.0";
	ui_type    = "drag";
	ui_min     = -1.0;
	ui_max     =  1.0;
	ui_step    =  0.001;
> = 0.0;
#endif*/

/*#if MULTIFX_GAMMA_MODE == CUSTOM
uniform float uGamma <
	ui_label   = "[Global] Gamma";
	ui_tooltip = "Default: 2.2";
	ui_type    = "drag";
	ui_min     = 0.4545;
	ui_max     = 6.6;
	ui_step    = 0.001;
> = 2.2;
#endif*/

uniform float uTime <source = "timer";>;

//Textures///////////////////////////////////////////////////////////////////////////////////////////////////////

sampler2D sMultiFX_BackBuffer {
	Texture = ReShade::BackBufferTex;
	/*#if MULTIFX_GAMMA_MODE == SRGB
	SRGBTexture = true;
	#endif*/
};

//Functions//////////////////////////////////////////////////////////////////////////////////////////////////////

float2 scale_uv(float2 uv, float2 scale, float2 center) {
	return (uv - center) * scale + center;
}

float2 scale_uv(float2 uv, float2 scale) {
	return scale_uv(uv, scale, 0.5);
}

float fmod(float a, float b) {
	float c = frac(abs(a / b)) * abs(b);
	return (a < 0.0) ? -c : c;
}

float rand(float2 uv) {
	float a = 12.9898;
	float b = 78.233;
	float c = 43758.5453;
	float dt = dot(uv, float2(a, b));
	float sn = fmod(dt, 3.1415);
	return frac(sin(sn) * c);
}

float3 blend_dodge(float3 a, float3 b, float w) {
	return lerp(a, a / max(1.0 - b, 0.0000001), w);
}

float gaussian(float z, float u, float o) {
    return (1.0 / (o * sqrt(2.0 * 3.1415))) * exp(-(((z - u) * (z - u)) / (2.0 * (o * o))));
}

float get_lum(float3 color) {
	return max(color.r, max(color.g, color.b));
}

float get_luma_linear(float3 c) {
	return dot(c, float3(0.2126, 0.7152, 0.0722));
}

//Effects////////////////////////////////////////////////////////////////////////////////////////////////////////
/*
void ChromaticAberration(out float3 color, float2 uv) {
	color = float3(
		tex2D(sMultiFX_BackBuffer, scale_uv(uv, 1.0 - uCA_Intensity.r * 0.01)).r,
		tex2D(sMultiFX_BackBuffer, scale_uv(uv, 1.0 - uCA_Intensity.g * 0.01)).g,
		tex2D(sMultiFX_BackBuffer, scale_uv(uv, 1.0 - uCA_Intensity.b * 0.01)).b
	);

	/*#if MULTIFX_GAMMA_MODE == CUSTOM
	color = pow(color, uGamma);
	#endif*/
}
*/
void Vignette(inout float3 color, float2 uv) {
	float vignette = 1.0 - smoothstep(
		uVignette_StartEnd.x,
		uVignette_StartEnd.y,
		distance(uv, 0.5)
	);
	color = lerp(color, color * vignette, uVignette_Intensity);
}

void FilmGrain(inout float3 color, float2 uv) {
	float t     = uTime * 0.001 * uFilmGrain_Speed;
    float seed  = dot(uv, float2(12.9898, 78.233));
    float noise = frac(sin(seed) * 43758.5453 + t);
	noise = gaussian(noise, uFilmGrain_Mean, uFilmGrain_Variance * uFilmGrain_Variance);
    
	/*#if MULTIFX_DEBUG
	if (uFilmGrain_ShowNoise)
		color = noise;
	else
	#endif*/

	float3 grain = noise * (1.0 - color);
	color += grain * uFilmGrain_Intensity * 0.01;
}

void Color(inout float3 color, float2 uv) {
	// Brightness
	color *= uColor_Brightness;
	// Contrast
	color = lerp(color, smoothstep(0.0, 1.0, color), uColor_Contrast - 1.0);
	// Saturation
	color = lerp(get_luma_linear(color), color, uColor_Saturation);
	// Temperature
	color *= lerp(1.0, float3(1.0, 0.5, 0.0), uColor_Temperature);
}

//Shader/////////////////////////////////////////////////////////////////////////////////////////////////////////

float4 PS_MultiFX(
	float4 position  : SV_POSITION,
	float2 uv        : TEXCOORD
) : SV_TARGET {
	float3 color;

	/*#if MULTIFX_CA
	ChromaticAberration(color, uv);
	#else

	#if MULTIFX_GAMMA_MODE == CUSTOM
	color = pow(tex2D(sMultiFX_BackBuffer, uv).rgb, uGamma);
	#else
	color = tex2D(sMultiFX_BackBuffer, uv).rgb;
	#endif

	#endif

	#if MULTIFX_VIGNETTE
	Vignette(color, uv);
	#endif

	#if MULTIFX_FILMGRAIN
	FilmGrain(color, uv);
	#endif

	#if MULTIFX_COLOR
	Color(color, uv);
	#endif

	#if MULTIFX_GAMMA_MODE == CUSTOM
	color = pow(color, 1.0 / uGamma);
	#endif*/

	return float4(color, 1.0);
}

//Technique//////////////////////////////////////////////////////////////////////////////////////////////////////

technique MultiFX {
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_MultiFX;
		/*#if MULTIFX_GAMMA_MODE == SRGB
		SRGBWriteEnable = true;
		#endif*/
	}
}

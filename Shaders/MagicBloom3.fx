/*	                __     __       _____      _______   ______    _______
	               /  \   /  \     /  _  \    /  _____\ |_    _|  /  _____\
	              /    \_/    \   /  /_\  \  /  / ____    |  |   /  /
	             /   /\   /\   \ /  _____  \ \  \___\ \  _|  |_  \  \_____
	             \__/  \_/  \__/ \_/     \_/  \_______/ |______|  \_______/
	 _______    __       _______     _______      __     __        ______   ______   ______
	|   __  \  |  |     /  ___  \   /  ___  \    /  \   /  \      |_    _| |_    _| |_    _|
	|  |__) /  |  |    /  /   \  \ /  /   \  \  /    \_/    \       |  |     |  |     |  |
	|  |__)  \ |  |___ \  \___/  / \  \___/  / /   /\   /\   \     _|  |_   _|  |_   _|  |_
	|________/ |______| \_______/   \_______/  \__/  \_/  \__/    |______| |______| |______|
	                                                          by luluco250

	Copyright (c) 2018 Lucas Melo

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/

#include "ReShade.fxh"

//Macros//////////////////////////////////////////////////////////////////////////////////////////////////

/*
	You can use these by setting them up with the
	'Preprocessor Definitions' configuration in the
	'Settings' tab of the ReShade menu.

	Simply write the macro name, followed by 
	an '=' and the value you want, like so:

	MAGIC_BLOOM_3_DEBUG=1
	MAGIC_BLOOM_3_DISTRIBUTION=FOGGY
	MAGIC_BLOOM_3_DIRT_TEXTURE_FILE="MyTexture.jpg"
*/

#ifndef MAGIC_BLOOM_3_DEBUG
#define MAGIC_BLOOM_3_DEBUG 0
#endif

#ifndef MAGIC_BLOOM_3_BLUR_SAMPLES
#define MAGIC_BLOOM_3_BLUR_SAMPLES 21
#endif

#ifndef MAGIC_BLOOM_3_RESOLUTION
#define MAGIC_BLOOM_3_RESOLUTION 1024
#endif

#ifndef MAGIC_BLOOM_3_NO_THRESHOLD
#define MAGIC_BLOOM_3_NO_THRESHOLD 0
#endif

#ifndef MAGIC_BLOOM_3_NO_DIRT
#define MAGIC_BLOOM_3_NO_DIRT 0
#endif

#ifndef MAGIC_BLOOM_3_DIRT_TEXTURE_FILE
#define MAGIC_BLOOM_3_DIRT_TEXTURE_FILE "MagicBloom_Dirt.png"
#endif

#ifndef MAGIC_BLOOM_3_NO_ADAPT
#define MAGIC_BLOOM_3_NO_ADAPT 0
#endif

#ifndef MAGIC_BLOOM_3_ADAPT_NO_DELAY
#define MAGIC_BLOOM_3_ADAPT_NO_DELAY 0
#endif

/*
	MAGIC_BLOOM_3_DISTRIBUTION controls the weight
	of the bloom textures when being blended.

	NORMAL:
		Simple average of all textures.
		Results in an in-between of CLEAR and FOGGY.
	CLEAR:
		Prefer the first, more detailed textures.
		Leads to more detail bloom.
	FOGGY:
		Prefer the last, less detailed textures.
		Leads to more fuzzy, blurry bloom.
*/

#define NORMAL 0
#define CLEAR 1
#define FOGGY 2

#ifndef MAGIC_BLOOM_3_DISTRIBUTION
#define MAGIC_BLOOM_3_DISTRIBUTION CLEAR
#endif

// Lazy? Yes. But it's a bit more readable to me.
#define pow2(x) (x * x)
// I once got a suggestion from Marty McFly that
// tex2Dlod is/can be faster at reading offset
// coordinates in a loop.
#define _tex2D(sp, uv) tex2Dlod(sp, float4(uv, 0.0, 0.0))

//Constants///////////////////////////////////////////////////////////////////////////////////////////////

static const int max_mip = int(log(MAGIC_BLOOM_3_RESOLUTION) / log(2)) + 1;
static const float pi = 3.1415926535897932384626433832795;
static const int max_steps = 8;

//Value used for adding padding around the bloom textures
//to avoid darkness around the edges caused by blurring.
//Inspired by a nice trick used in Minecraft SEUS.
static const float2 pad = ReShade::PixelSize * 25.0;

//Uniforms////////////////////////////////////////////////////////////////////////////////////////////////

uniform float fBloom_Intensity <
	ui_label   = "Bloom Intensity";
	ui_tooltip = "Controls how much bloom to blend with the image.\n"
	             "Very low values may be necessary depending "
	             "on the max brightness set.\n"
	             "\nDefault: 1.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 1.0;
	ui_step    = 0.001;
> = 1.0;

#if !MAGIC_BLOOM_3_NO_THRESHOLD
uniform float fBloom_Threshold <
	ui_label   = "Bloom Threshold";
	ui_tooltip = "Increases the contrast between colors, "
	             "making bloom a bit sharper but also "
				 "causes color shifting.\n"
				 "1.0 disables thresholding. "
				 "Define MAGIC_BLOOM_3_NO_THRESHOLD=1 "
				 "to completely disable thresholding "
				 "(disables thresholding code for performance).\n"
				 "\nDefault: 1.0";
	ui_type    = "drag";
	ui_min     = 1.0;
	ui_max     = 10.0;
	ui_step    = 0.001;
> = 1.0;
#endif

#if !MAGIC_BLOOM_3_NO_DIRT
uniform float fDirt_Intensity <
	ui_label   = "Dirt Intensity";
	ui_tooltip = "Controls how much dirt to blend with bloom.\n"
	             "Uses \"MagicBloom_Dirt.png\" from the textures folder.\n"
				 "Define MAGIC_BLOOM_3_DIRT_TEXTURE_FILE=\"filename\" "
				 "to use a different texture. With 'filename' being "
				 "something like \"MagicBloom_Dirt.png\".\n"
				 "Define MAGIC_BLOOM_3_NO_DIRT=1 to completely disable "
				 "dirt. (disables dirt code for performance).\n"
	             "\nDefault: 0.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 10.0;
	ui_step    = 0.001;
> = 0.0;
#endif

#if !MAGIC_BLOOM_3_NO_ADAPT
uniform float fAdapt_Exposure <
	ui_label   = "Adaptation Exposure";
	ui_tooltip = "The average luminance that bloom should adapt to.\n"
	             "Lower values lead to a darker image, while"
				 "higher ones lead to a brighter image.\n"
				 "\nDefault: 1.0";
	ui_type    = "drag";
	ui_min     = 0.001;
	ui_max     = 10.0;
	ui_step    = 0.001;
> = 1.0;

#if !MAGIC_BLOOM_3_ADAPT_NO_DELAY
uniform float fAdapt_Delay <
	ui_label   = "Adaptation Delay (Seconds)";
	ui_tooltip = "How much time should it take for bloom to adapt.\n"
	             "Define MAGIC_BLOOM_3_ADAPT_NO_DELAY=1 to completely "
				 "disable delaying and make adaptation instantaneous "
				 "(disables adaptation interpolation code for "
				 "performance).\n"
	             "\nDefault: 1.0";
	ui_type    = "drag";
	ui_min     = 0.001;
	ui_max     = 20.0;
	ui_step    = 0.001;
> = 1.0;
#endif

uniform float fAdapt_Sensitivity <
	ui_label   = "Adaptation Sensitivity";
	ui_tooltip = "Controls adaptation's sensitivity towards "
	             "bright scenes by multiplying the source image.\n"
	             "\nDefault: 1.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 10.0;
	ui_step    = 0.001;
> = 1.0;

uniform bool bAdapt_DoLimit <
	ui_label   = "Limit Adaptation";
	ui_tooltip = "Clamp adaptation between the values provided "
	             "by Adaptation Min/Max.\n"
				 "\nDefault: On";
> = true;

uniform float2 f2Adapt_MinMax <
	ui_label   = "Adaptation Min/Max";
	ui_tooltip = "The minimum and maximum luminance "
	             "values that bloom can adapt to.\n"
				 "By increasing the first value "
				 "bloom will adapt less to darker "
				 "scenes, becoming brighter.\n"
	             "By increasing the second value "
				 "bloom will adapt more to brighter "
				 "scenes, becoming darker.\n"
				 "It's easier to test these values "
				 "by yourself to understand what they do.\n"
	             "\nDefault: (0.0, 1.0)";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 10.0;
	ui_step    = 0.001;
> = float2(0.0, 1.0);

uniform float fAdapt_Precision <
	ui_label   = "Adaptation Precision";
	ui_tooltip = "Higher values will make adaptation"
	             "focus more on the center of the image.\n"
	             "\nDefault: 0.0";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = max_mip;
	ui_step    = 0.01;
> = 0.0;

uniform int iAdapt_Mode <
	ui_label   = "Adaptation Mode";
	ui_tooltip = "Determines what adaptation will affect.\n"
	             "Different settings may work better with "
				 "certain art styles.\n"
				 "Cartoonish looks may look better with "
				 "\"Adapt Only Bloom\", while \"Adapt Final Image\" "
				 "works better with more natural imagery.\n"
	             "\nDisabled:\n"
				 "\tDisable adaptation. Define"
				 "MAGIC_BLOOM_3_NO_ADAPT=1 to completely"
				 "disable adaptation, which disables all"
				 "adaptation code for performance.\n"
	             "Adapt Final Image:\n"
	             "\tAdapt the image texture after"
				 "blending it with the bloom texture.\n"
				 "Adapt Only Bloom:\n"
				 "\tAdapt the bloom texture before"
				 "blending it with the image texture.\n"
	             "\nDefault: Adapt Final Image";
	ui_type    = "combo";
	ui_items   = "Disabled\0Adapt Final Image\0Adapt Only Bloom\0";
> = 1;
#endif

uniform float fMaxBrightness <
	ui_label   = "Max Brightness";
	ui_tooltip = "The maximum brightness allowed to extract "
	             "from the source image when transforming into "
				 "HDR color space.\n"
				 "Higher values will increase highlights, "
				 "which may require adjusting the bloom intensity.\n"
				 "Lower values will give bloom a hazier look.\n"
				 "1.0 will cause loss of whites.\n"
	             "\nDefault: 10.0";
	ui_type    = "drag";
	ui_min     = 1.0;
	ui_max     = 1000.0;
	ui_step    = 1.0;
> = 10.0;

uniform float fBlur_Sigma <
	ui_label   = "Blur Sigma";
	ui_tooltip = "How much to blur the bloom textures.\n"
	             "Too little and bloom will be pixelated.\n"
				 "Too much (without enough blur samples) and "
				 "bloom will be \"squary\" (think box blur).\n"
				 "To increase the amount of samples, define "
				 "MAGIC_BLOOM_3_BLUR_SAMPLES=N, with 'N' being "
				 "an integer number. Default: 21.\n"
				 "The cost of blurring is O(n + n).\n"
	             "\nDefault: 4.0";
	ui_type    = "drag";
	ui_min     = 1.0;
	ui_max     = 10.0;
	ui_step    = 0.1;
> = 4.0;

uniform int iSteps <
	ui_label = "Steps";
	ui_tooltip = "How many bloom textures/steps to use. "
	             "Lower values lead to smaller bloom.\n"
	             "\nDefault: 8";
	ui_type  = "drag";
	ui_min   = 1;
	ui_max   = max_steps;
	ui_step  = 0.1;
> = max_steps;

#if MAGIC_BLOOM_3_DEBUG
uniform int iDebug <
	ui_label   = "Debug Options";
	ui_tooltip = "None:\n"
	             "\tDisable debugging. Prefer disabling the macro.\n"
				 "Show Bloom Only:\n"
	             "\tShow only the blended bloom texture.\n"
				 "Show Unscaled Textures:\n"
				 "\tShow the separated bloom textures.\n"
				 "Show Adaptation Texture:\n"
				 "\tShow the texture used for adaptation.\n"
	             "\nDefault: None";
	ui_type    = "combo";
	ui_items   = "None\0Show Bloom Only\0Show Unscaled Textures\0Show Adaptation Texture\0";
> = 0;
#endif

uniform float fDeltaTime <source = "frametime";>;

//Textures////////////////////////////////////////////////////////////////////////////////////////////////

sampler2D sBackBuffer {
	Texture     = ReShade::BackBufferTex;
	SRGBTexture = true;
};

#if !MAGIC_BLOOM_3_NO_DIRT
texture2D tMagicBloom3_Dirt <
	source = MAGIC_BLOOM_3_DIRT_TEXTURE_FILE;
> {
	Width  = BUFFER_WIDTH;
	Height = BUFFER_HEIGHT;
};
sampler2D sMagicBloom3_Dirt {
	Texture = tMagicBloom3_Dirt;
};
#endif

texture2D tMagicBloom3_A {
	Width  = MAGIC_BLOOM_3_RESOLUTION;
	Height = MAGIC_BLOOM_3_RESOLUTION;
	Format = RGBA16F;
	MipLevels = max_mip;
};
sampler2D sMagicBloom3_A {
	Texture = tMagicBloom3_A;
};

texture2D tMagicBloom3_B {
	Width  = MAGIC_BLOOM_3_RESOLUTION;
	Height = MAGIC_BLOOM_3_RESOLUTION;
	Format = RGBA16F;
};
sampler2D sMagicBloom3_B {
	Texture = tMagicBloom3_B;
};

#if !MAGIC_BLOOM_3_NO_ADAPT
texture2D tMagicBloom3_Adapt {
	Format = R16F;
};
sampler2D sMagicBloom3_Adapt {
	Texture = tMagicBloom3_Adapt;
};

#if !MAGIC_BLOOM_3_ADAPT_NO_DELAY
texture2D tMagicBloom3_LastAdapt {
	Format = R16F;
};
sampler2D sMagicBloom3_LastAdapt {
	Texture = tMagicBloom3_LastAdapt;
};
#endif
#endif

//Functions///////////////////////////////////////////////////////////////////////////////////////////////

float3 i_reinhard(float3 col) {
	return (col / max(1.0 - col, 1.0 / fMaxBrightness));
}

float3 t_reinhard(float3 col) {
	return col / (1.0 + col);
}

float get_luma_linear(float3 col) {
	return dot(col, float3(0.2126, 0.7152, 0.0722));
}

float2 scale_uv(float2 uv, float2 scale, float2 center) {
	return (uv - center) * scale + center;
}

float2 scale_uv(float2 uv, float2 scale) {
	return scale_uv(uv, scale, 0.5);
}

float gaussian1D(float i) {
	return (1.0 / sqrt(2.0 * pi * pow2(fBlur_Sigma))) * exp(-(pow2(i) / (2.0 * pow2(fBlur_Sigma))));
}

float gaussian2D(float2 i) {
	return (1.0 / (2.0 * pi * pow2(fBlur_Sigma))) * exp(-((pow2(i.x) + pow2(i.y)) / (2.0 * pow2(fBlur_Sigma))));
}

float3 blur1D(sampler2D sp, float2 uv, float2 scale) {
	const float2 ps = ReShade::PixelSize * scale;

	float3 color = 0.0;
	float accum = 0.0;
	float offset, weight;

	[unroll]
	for (int i = -MAGIC_BLOOM_3_BLUR_SAMPLES / 2; i <= MAGIC_BLOOM_3_BLUR_SAMPLES / 2; ++i) {
		offset = i;
		weight = gaussian1D(offset);

		color += _tex2D(sp, uv + ps * offset).rgb * weight;
		accum += weight;
	}

	color /= accum;
	return color;
}

float3 blur2D(sampler2D sp, float2 uv, float2 scale) {
	const float2 ps = ReShade::PixelSize * scale;

	float3 color = 0.0;
	float accum = 0.0;
	float2 offset;
	float weight;

	[unroll]
	for (int x = -MAGIC_BLOOM_3_BLUR_SAMPLES / 2; x <= MAGIC_BLOOM_3_BLUR_SAMPLES / 2; ++x) {
		[unroll]
		for (int y = -MAGIC_BLOOM_3_BLUR_SAMPLES / 2; y <= MAGIC_BLOOM_3_BLUR_SAMPLES / 2; ++y) {
			offset = float2(x, y);
			weight = gaussian2D(offset);

			color += i_reinhard(_tex2D(sp, uv + ps * offset).rgb) * weight;
			accum += weight;
		}
	}

	color /= accum;
	return color;
}

float2 get_offset(int i) {
	static const float2 offset[max_steps] = {
		float2(0.0, 0.0),
		float2(0.7, 0.0),
		float2(0.6, 0.35),
		float2(0.725, 0.35),
		float2(0.55, 0.485),
		float2(0.5875, 0.485),
		float2(0.6125, 0.485),
		float2(0.63125, 0.485)
	};
	return offset[i];
}

bool within(float2 uv, float4 bounds) {
	return uv.x >= bounds.x && uv.x <= bounds.y && uv.y >= bounds.z && uv.y <= bounds.w;
}

float get_delta_time() {
	return fDeltaTime * 0.001;
}

//Shaders/////////////////////////////////////////////////////////////////////////////////////////////////

float4 PS_MakeHDR(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_Target {
	float3 color = tex2D(sBackBuffer, uv).rgb;

	#if !MAGIC_BLOOM_3_NO_THRESHOLD
	color = pow(color, fBloom_Threshold);
	#endif

	color = i_reinhard(color);
	return float4(color, 1.0);
}

/*
	You might ask yourself why I'm going to read the adaptation
	textures using uv, rather than just 0.0 (as they're 1x1 textures).

	There's this little optimization GPUs can do if they don't have modified
	coordinates, I'm not sure if static coordinates are better, but
	so far it seems to work nice enough.
*/

#if !MAGIC_BLOOM_3_NO_ADAPT
float PS_CalcAdapt(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = tex2Dlod(sMagicBloom3_A, float4(0.5, 0.5, 0.0, max_mip - fAdapt_Precision)).rgb;
	float adapt = get_luma_linear(color.rgb);
	adapt *= fAdapt_Sensitivity;
	adapt = bAdapt_DoLimit ? clamp(adapt, f2Adapt_MinMax.x, f2Adapt_MinMax.y) : adapt;

	#if !MAGIC_BLOOM_3_ADAPT_NO_DELAY
	float last = tex2D(sMagicBloom3_LastAdapt, uv).x;
	adapt = lerp(last, adapt, get_delta_time() / fAdapt_Delay);
	#endif

	return adapt;
}

#if !MAGIC_BLOOM_3_ADAPT_NO_DELAY
float PS_SaveAdapt(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	return tex2D(sMagicBloom3_Adapt, uv).x;
}
#endif
#endif

float4 PS_Split(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = 0.0;
	float lod;
	float2 lod_uv;

	[unroll]
	for (int i = 0; i < iSteps; ++i) {
		lod = pow(2, i + 1); // mipmaps are in power of two
		lod_uv = scale_uv(uv, lod, get_offset(i));
		
		// Padding to avoid darkened edges (sort of like a vignette)
		if (within(lod_uv, float4(-pad.x, 1.0 + pad.x, -pad.y, 1.0 + pad.y)))
			color += tex2Dlod(sMagicBloom3_A, float4(lod_uv, 0.0, i)).rgb;
	}

	return float4(color, 1.0);
}

float4 PS_BlurX(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	/*
		Fix the bloom aspect ratio

		Here we actually "counter stretch" the texture,
		so we can negate the distortion caused by writing
		to the 1:1 textures.
	*/
	#if BUFFER_WIDTH > BUFFER_HEIGHT
	uv = scale_uv(uv, float2(1, BUFFER_WIDTH / BUFFER_HEIGHT));
	#elif BUFFER_HEIGHT > BUFFER_WIDTH
	uv = scale_uv(uv, float2(BUFFER_HEIGHT / BUFFER_WIDTH, 1));
	#endif
	
	float3 color = blur1D(
		sMagicBloom3_B,
		uv,
		float2(BUFFER_WIDTH / MAGIC_BLOOM_3_RESOLUTION, 0.0)
	);
	return float4(color, 1.0);
}

float4 PS_BlurY(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	float3 color = blur1D(
		sMagicBloom3_A,
		uv,
		float2(0.0, BUFFER_HEIGHT / MAGIC_BLOOM_3_RESOLUTION)
	);
	return float4(color, 1.0);
}

float4 PS_FixAspect(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	/*
		Fix the bloom aspect ratio

		Now we undo the "counter stretch" and get the
		texture with a nicely preserved aspect ratio.
	*/
	#if BUFFER_WIDTH > BUFFER_HEIGHT
	uv = scale_uv(uv, 1.0 / float2(1, BUFFER_WIDTH / BUFFER_HEIGHT));
	#elif BUFFER_HEIGHT > BUFFER_WIDTH
	uv = scale_uv(uv, 1.0 / float2(BUFFER_HEIGHT / BUFFER_WIDTH, 1));
	#endif

	return float4(tex2D(sMagicBloom3_B, uv).rgb, 1.0);
}

float4 PS_Blend(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	#if MAGIC_BLOOM_3_DEBUG
	if (iDebug == 2) // Show unscaled textures
		return float4(t_reinhard(tex2D(sMagicBloom3_A, uv).rgb), 1.0);

	#if !MAGIC_BLOOM_3_NO_ADAPT
	if (iDebug == 3) // Show adaptation texture
		return float4(tex2D(sMagicBloom3_Adapt, uv).x, 0.0, 0.0, 1.0);
	#endif
	#endif

	float3 bloom = 0.0;
	float lod;
	float2 lod_uv;
	
	#if MAGIC_BLOOM_3_DISTRIBUTION != NORMAL
	float accum = 0.0;
	float weight;
	#endif

	[unroll]
	for (int i = 0; i < iSteps; ++i) {
		lod = pow(2, i + 1); // mipmaps are in power of two
		lod_uv = scale_uv(uv, 1.0 / lod, get_offset(i));
		
		#if MAGIC_BLOOM_3_DISTRIBUTION == CLEAR
		weight = iSteps - (i + 1);
		#elif MAGIC_BLOOM_3_DISTRIBUTION == FOGGY
		weight = i + 1;
		#endif

		#if MAGIC_BLOOM_3_DISTRIBUTION != NORMAL
		bloom += tex2D(sMagicBloom3_A, lod_uv).rgb * weight;
		accum += weight;
		#else
		bloom += tex2D(sMagicBloom3_A, lod_uv).rgb;
		#endif
	}
	
	#if MAGIC_BLOOM_3_DISTRIBUTION != NORMAL
	bloom /= accum;
	#else
	bloom /= iSteps;
	#endif

	#if !MAGIC_BLOOM_3_NO_DIRT
	float bloom_lum = max(bloom.r, max(bloom.g, bloom.b));
	float3 dirt = tex2D(sMagicBloom3_Dirt, uv).rgb;
	bloom += dirt * bloom * fDirt_Intensity;
	#endif

	#if MAGIC_BLOOM_3_DEBUG
	if (iDebug == 1) // Show bloom only
		return float4(t_reinhard(bloom), 1.0);
	#endif

	float3 color = tex2D(sBackBuffer, uv).rgb;
	color = i_reinhard(color);

	#if !MAGIC_BLOOM_3_NO_ADAPT
	float adapt = tex2D(sMagicBloom3_Adapt, uv).x;
	float exposure = fAdapt_Exposure / max(adapt, 1.0 / fMaxBrightness);

	bloom *= (iAdapt_Mode == 2) ? exposure : 1.0;
	#endif

	color += bloom * fBloom_Intensity;

	#if !MAGIC_BLOOM_3_NO_ADAPT
	color *= (iAdapt_Mode == 1) ? exposure : 1.0;
	#endif

	color = t_reinhard(color);
	return float4(color, 1.0);
}

//Techniques//////////////////////////////////////////////////////////////////////////////////////////////

technique MagicBloom3 {
	pass MakeHDR {
		VertexShader = PostProcessVS;
		PixelShader  = PS_MakeHDR;
		RenderTarget = tMagicBloom3_A;
	}
	#if !MAGIC_BLOOM_3_NO_ADAPT
	pass CalcAdapt {
		VertexShader = PostProcessVS;
		PixelShader  = PS_CalcAdapt;
		RenderTarget = tMagicBloom3_Adapt;
	}
	#if !MAGIC_BLOOM_3_ADAPT_NO_DELAY
	pass SaveAdapt {
		VertexShader = PostProcessVS;
		PixelShader  = PS_SaveAdapt;
		RenderTarget = tMagicBloom3_LastAdapt;
	}
	#endif
	#endif
	pass Split {
		VertexShader = PostProcessVS;
		PixelShader  = PS_Split;
		RenderTarget = tMagicBloom3_B;
	}
	pass BlurX {
		VertexShader = PostProcessVS;
		PixelShader  = PS_BlurX;
		RenderTarget = tMagicBloom3_A;
	}
	pass BlurY {
		VertexShader = PostProcessVS;
		PixelShader  = PS_BlurY;
		RenderTarget = tMagicBloom3_B;
	}
	pass FixAspect {
		VertexShader = PostProcessVS;
		PixelShader  = PS_FixAspect;
		RenderTarget = tMagicBloom3_A;
	}
	pass Blend {
		VertexShader    = PostProcessVS;
		PixelShader     = PS_Blend;
		SRGBWriteEnable = true;
	}
}

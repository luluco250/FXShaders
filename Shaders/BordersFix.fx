#include "ReShade.fxh"

#define LEFT 1
#define RIGHT 2
#define UP 4
#define DOWN 8

#ifndef BORDERS_FLAGS
#define BORDERS_FLAGS LEFT|RIGHT|UP|DOWN
#endif

uniform float4 f4BorderSize <
	ui_label   = "Border Sizes (L,R,U,D)";
	ui_tooltip = "Size of each border:\n"
	             "\tx = Left\n"
				 "\ty = Right\n"
				 "\tz = Up\n"
				 "\tw = Down\n"
				 "\nDefault: (1.0, 1.0, 1.0, 1.0)";
	ui_type    = "drag";
	ui_min     = 0.0;
	ui_max     = 100.0;
	ui_step    = 1.0;
> = float4(1.0, 1.0, 1.0, 1.0);

sampler2D sBackBuffer {
	Texture   = ReShade::BackBufferTex;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU  = BORDER;
	AddressV  = BORDER;
};

float4 PS_BordersFix(
	float4 position : SV_POSITION,
	float2 uv       : TEXCOORD
) : SV_TARGET {
	static const float2 res   = ReShade::ScreenSize;
	static const float2 ps    = ReShade::PixelSize;
	const float2 coord = uv * res;
	
	float3 color = tex2D(sBackBuffer, uv).rgb;

	color *= step(f4BorderSize.x, coord.x)
	       * step(coord.x, res.x - f4BorderSize.y)
		   * step(f4BorderSize.z, coord.y)
		   * step(coord.y, res.y - f4BorderSize.w);

	/*#if BORDERS_FLAGS & LEFT
	color *= step(ps.x, uv.x);
	#endif
	#if BORDERS_FLAGS & RIGHT
	//if (coord.x < res.x * 0.5)
		//color = 0.0;
	//color *= uv.x <= res.x - ps.x; //step(uv.x, res.x - ps.x);
	#endif
	#if BORDERS_FLAGS & UP
	color *= step(uv.y, ps.y);
	#endif
	#if BORDERS_FLAGS & DOWN
	color *= step(res.y - ps.y, uv.y);
	#endif*/

	return float4(color, 1.0);
}

technique BordersFix {
	pass {
		VertexShader = PostProcessVS;
		PixelShader  = PS_BordersFix;
	}
}

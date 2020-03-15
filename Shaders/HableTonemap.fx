#include "ReShade.fxh"

  //=========//
 //Constants//
//=========//

static const float3 cDebugLine_Color = float3(1.0, 0.0, 0.0);
static const float cDebugLine_Thickness = 3.0;
static const float2 cPixelSize = ReShade::PixelSize;

  //========//
 //Uniforms//
//========//

uniform float uExposure <
	ui_label = "Exposure";
	ui_tooltip = "Exposure level in F-stops.";
	ui_type = "drag";
	ui_min = -2.0;
	ui_max = 10.0;
	ui_step = 0.001;
> = 0.0;

uniform float3 uColorFilter <
	ui_label = "Color Filter";
	ui_type = "color";
> = float3(1.0, 1.0, 1.0);

uniform float uSaturation <
	ui_label = "Saturation";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 3.0;
	ui_step = 0.001;
> = 1.0;

uniform float uContrast <
	ui_label = "Contrast";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 3.0;
	ui_step = 0.001;
> = 1.0;

uniform float uToeStrength <
	ui_label = "Toe Strength";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = 0.5;

uniform float uToeLength <
	ui_label = "Toe Length";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = 0.5;

uniform float uShoulderStrength <
	ui_label = "Shoulder Strength";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 10.0;
	ui_step = 0.001;
> = 2.0;

uniform float uShoulderLength <
	ui_label = "Shoulder Length";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = 0.5;

uniform float uShoulderAngle <
	ui_label = "Shoulder Angle";
	ui_type = "drag";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = 1.0;

uniform float uGamma <
	ui_label = "Gamma";
	ui_type = "drag";
	ui_min = 0.1;
	ui_max = 3.0;
	ui_step = 0.001;
> = 1.0;

uniform float uMaxBrightness <
	ui_label = "Max Brightness";
	ui_type = "drag";
	ui_min = 1.0;
	ui_max = 100.0;
	ui_step = 0.1;
> = 100.0;

  //========//
 //Textures//
//========//

sampler2D sColor {
	Texture = ReShade::BackBufferTex;
	SRGBTexture = true;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

  //=======//
 //Structs//
//=======//

struct ParamsFromVS {
	float4 data0 : TEXCOORD1;
	float3 data1 : TEXCOORD2;
};

struct Params {
	float2 linear_start;
	float2 linear_stop;
	float2 overshoot;
	float white_point;
};

struct CurveSegment {
	float a, b;
	float2 offset, scale;
};

struct FullCurve {
	float2 linear_start, linear_stop, overshoot;
	float white_point, inv_white_point;

	CurveSegment segments[3];
};

  //=========//
 //Functions//
//=========//

CurveSegment make_segment(float a, float b, float2 offset, float2 scale) {
	CurveSegment segment;
	segment.a = a;
	segment.b = b;
	segment.offset = offset;
	segment.scale = scale;
	return segment;
}

FullCurve make_curve(
	float2 linear_start,
	float2 linear_stop,
	float2 overshoot,
	float white_point,
	float inv_white_point,
	CurveSegment toe,
	CurveSegment middle,
	CurveSegment shoulder
) {
	FullCurve curve;
	curve.linear_start = linear_start;
	curve.linear_stop = linear_stop;
	curve.overshoot = overshoot;
	curve.white_point = white_point;
	curve.inv_white_point = inv_white_point;
	curve.segments[0] = toe;
	curve.segments[1] = middle;
	curve.segments[2] = shoulder;
	return curve;
}

float eval_segment(CurveSegment segment, float x) {
	float2 p = float2((x - segment.offset.x) * segment.scale.x, 0.0);
	if (p.x > 0.0)
		p.y = exp(segment.a + segment.b * log(p.x));
	
	return p.y * segment.scale.y + segment.offset.y;
}

float eval_segment_inv(CurveSegment segment, float y) {
	float2 p = float2(0.0, (y - segment.offset.y) / segment.scale.y);
	if (p.y > 0.0)
		p.x = exp((log(p.y) - segment.a) / segment.b);
	
	return p.x / segment.scale.x + segment.offset.x;
}

void solve_ab(out float a, out float b, float2 p, float m) {
	b = (m * p.x) / p.y;
	a = log(p.y) - b * log(p.x);
}

void as_slope_intercept(inout float m, inout float b, float2 start, float2 stop) {
	float2 diff = stop - start;
	if (diff.x == 0.0)
		m = 1.0;
	else
		m = diff.y / diff.x;
	b = start.y - start.x * m;
}

float eval_derivative_linear_gamma(float m, float b, float g, float x) {
	return g * m * pow(m * x + b, g - 1.0);
}

Params get_params() {
	Params params;

	static const float perceptual_gamma = 2.2;

	// Toe parameters
	params.linear_start.x = pow(uToeLength, perceptual_gamma) * 0.5;
	params.linear_start.y = (1.0 - uToeStrength) * params.linear_start.x;

	// Shoulder parameters
	float remaining_y = 1.0 - params.linear_start.y;
	float linear_stop_y_offset = (1.0 - uShoulderLength) * remaining_y;
	params.linear_stop = params.linear_start + linear_stop_y_offset;
	params.white_point = params.linear_start.x + remaining_y + (exp2(uShoulderStrength) - 1.0);

	// Overshoot parameters
	params.overshoot.x = (params.white_point * 2.0) * uShoulderAngle * uShoulderStrength;
	params.overshoot.y = 0.5 * uShoulderAngle * uShoulderStrength;

	return params;
}

ParamsFromVS pack_params(Params params) {
	ParamsFromVS v;
	v.data0 = float4(params.linear_start, params.linear_stop);
	v.data1 = float3(params.overshoot, params.white_point);
	return v;
}

Params unpack_params(ParamsFromVS v) {
	Params params;
	params.linear_start = v.data0.xy;
	params.linear_stop = v.data0.zw;
	params.overshoot = v.data1.xy;
	params.white_point = v.data1.z;
	return params;
}

CurveSegment get_middle(inout Params params, inout float toe_m, inout float shoulder_m) {
	float m, b;
	as_slope_intercept(m, b, params.linear_start, params.linear_stop);

	CurveSegment segment;
	segment.offset = float2(-(b / m), 0.0);
	segment.scale = 1.0;
	segment.a = uGamma * log(m);
	segment.b = uGamma;

	toe_m = eval_derivative_linear_gamma(m, b, uGamma, params.linear_start.x);
	shoulder_m = eval_derivative_linear_gamma(m, b, uGamma, params.linear_stop.x);

	params.linear_start.y = max(pow(params.linear_start.y, uGamma), 1e-5);
	params.linear_stop.y = max(pow(params.linear_stop.y, uGamma), 1e-5);

	params.overshoot.y = pow(1.0 + params.overshoot.y, uGamma) - 1.0;

	return segment;
}

CurveSegment get_toe(Params params, float toe_m) {
	CurveSegment segment;
	segment.offset = 0.0;
	segment.scale = 1.0;

	solve_ab(segment.a, segment.b, params.linear_start, toe_m);

	return segment;
}

CurveSegment get_shoulder(Params params, float shoulder_m) {
	float2 start = (1.0 + params.overshoot) - params.linear_stop;
	float a = 0.0, b = 0.0;
	solve_ab(a, b, start, shoulder_m);

	CurveSegment segment;
	segment.offset = 1.0 + params.overshoot;

	segment.scale = -1.0;
	segment.a = a;
	segment.b = b;

	return segment;
}

void normalize_curve(inout FullCurve curve) {
	float scale = eval_segment(curve.segments[2], 1.0);
	float inv_scale = 1.0 / scale;

	curve.segments[0].offset.y *= inv_scale;
	curve.segments[0].scale.y *= inv_scale;

	curve.segments[1].offset.y *= inv_scale;
	curve.segments[1].scale.y *= inv_scale;

	curve.segments[2].offset.y *= inv_scale;
	curve.segments[2].scale.y *= inv_scale;
}

FullCurve get_curve(Params params) {
	Params cpy_params = params;

	FullCurve curve;
	curve.white_point = params.white_point;
	curve.inv_white_point = 1.0 / params.white_point;

	cpy_params.white_point = 1.0;
	cpy_params.linear_start.x /= params.white_point;
	cpy_params.linear_stop.x /= params.white_point;
	cpy_params.overshoot.x = params.overshoot.x / params.white_point;

	float toe_m = 0.0, shoulder_m = 0.0, endpoint_m = 0.0;
	curve.segments[1] = get_middle(cpy_params, toe_m, shoulder_m);
	
	curve.linear_start = cpy_params.linear_start;
	curve.linear_stop = cpy_params.linear_stop;

	curve.segments[0] = get_toe(cpy_params, toe_m);

	curve.segments[2] = get_shoulder(cpy_params, shoulder_m);

	normalize_curve(curve);

	return curve;
}

float eval_curve(FullCurve curve, float x) {
	float norm = x * curve.inv_white_point;
	int index = (norm < curve.linear_start.x) ? 0
	          : (norm < curve.linear_stop.x) ? 1 : 2;

	return eval_segment(curve.segments[index], norm);
}

float within(float x, float y, float s) {
	// x + s > y && x - s < y
	return step(y, x + s) * step(x - s, y);
}

float3 inv_reinhard(float3 color, float inv_max) {
	return (color / max(1.0 - color, inv_max));
}

float3 inv_reinhard_lum(float3 color, float inv_max) {
	float lum = max(color.r, max(color.g, color.b));
	return color * (lum / max(1.0 - lum, inv_max));
}

float get_luma_linear(float3 color) {
	return dot(color, float3(0.2126, 0.7152, 0.0722));
}

float3 color_grading(float3 color) {
	// Exposure and color filter
	color *= exp2(uExposure) * uColorFilter;
	
	// Saturation
	float gray = get_luma_linear(color);
	color = gray + uSaturation * (color - gray);

	// Contrast
	color = log(color);
	color = 0.5 + (color - 0.5) * uContrast;
	color = exp(color);

	return color;
}

  //======//
 //Shader//
//======//

void VS_FilmicCurve(
	uint id : SV_VERTEXID,
	out float4 position : SV_POSITION,
	out float2 uv : TEXCOORD0,
	out ParamsFromVS params_vs
) {
	PostProcessVS(id, position, uv);
	params_vs = pack_params(get_params());
}

float4 PS_HableTonemap(
	float4 position : SV_POSITION,
	float2 uv : TEXCOORD0,
	ParamsFromVS params_vs
) : SV_TARGET {
	float3 color = tex2D(sColor, uv).rgb;
	color = inv_reinhard(color, 1.0 / uMaxBrightness);
	//color *= exp2(uExposure);
	color = color_grading(color);

	FullCurve curve = get_curve(unpack_params(params_vs));
	color.r = eval_curve(curve, color.r);
	color.g = eval_curve(curve, color.g);
	color.b = eval_curve(curve, color.b);

	return float4(color, 1.0);
}

float4 PS_DebugLine(
	float4 position : SV_POSITION,
	float2 uv : TEXCOORD0,
	ParamsFromVS params_vs
) : SV_TARGET {
	float3 color = tex2D(sColor, uv).rgb;

	float3 debug_line = uv.x;
	debug_line = inv_reinhard(debug_line, 1.0 / uMaxBrightness);
	debug_line = color_grading(debug_line);
	//debug_line *= exp2(uExposure);
	FullCurve curve = get_curve(unpack_params(params_vs));
	debug_line.r = eval_curve(curve, debug_line.r);
	debug_line.g = eval_curve(curve, debug_line.g);
	debug_line.b = eval_curve(curve, debug_line.b);

	color = lerp(color, float3(0.0, 0.0, 1.0), within(debug_line.b, 1.0 - uv.y, cPixelSize.y * cDebugLine_Thickness));
	color = lerp(color, float3(0.0, 1.0, 0.0), within(debug_line.g, 1.0 - uv.y, cPixelSize.y * cDebugLine_Thickness));
	color = lerp(color, float3(1.0, 0.0, 0.0), within(debug_line.r, 1.0 - uv.y, cPixelSize.y * cDebugLine_Thickness));

	return float4(color, 1.0);
}

  //==========//
 //Techniques//
//==========//

technique HableTonemap {
	pass {
		VertexShader = VS_FilmicCurve;
		PixelShader = PS_HableTonemap;
		SRGBWriteEnable = true;
	}
}

technique HableTonemap_DebugLine {
	pass {
		VertexShader = VS_FilmicCurve;
		PixelShader = PS_DebugLine;
		SRGBWriteEnable = true;
	}
}

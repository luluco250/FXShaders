//#region Preprocessor

#include "ReShade.fxh"
#include "ReShadeUI.fxh"
#include "DrawText.fxh"
#include "FXShaders/Common.fxh"

#define DECLARE_VARIABLE_TEX(name, format) \
texture name##Tex \
{ \
	Format = format; \
}; \
\
sampler name \
{ \
	Texture = name##Tex; \
	MinFilter = POINT; \
	MagFilter = POINT; \
	MipFilter = POINT; \
}

//#endregion

namespace FXShaders
{

//#region Constants

static const float BallInitialYPercent = 0.2;
static const float2 BallSize = 50;
static const float2 PaddleSize = float2(250, 50);
static const float PaddleYPercent = 0.9;
static const float BallSpeedIncreasePercent = 1.1;

//#endregion

//#region Uniforms

uniform float Opacity
<
	__UNIFORM_SLIDER_FLOAT1

	ui_category = "Appearance";
	ui_tooltip =
		"Global opacity of the pong game.\n"
		"\nDefault: 255";
	ui_min = 0.0;
	ui_max = 1.0;
> = 1.0;

uniform float4 BackgroundColor
<
	__UNIFORM_COLOR_FLOAT4

	ui_category = "Appearance";
	ui_label = "Background Color";
	ui_tooltip =
		"Color of the pong game background, can be transparent.\n"
		"\nDefault: 0 0 0 127";
> = float4(0.0, 0.0, 0.0, 1.0);

uniform float4 BallColor
<
	__UNIFORM_COLOR_FLOAT4

	ui_category = "Appearance";
	ui_label = "Ball Color";
	ui_tooltip =
		"Color of the pong ball, can be transparent.\n"
		"\nDefault: 255 0 0 255";
> = float4(1.0, 0.0, 0.0, 1.0);

uniform float4 PaddleColor
<
	__UNIFORM_COLOR_FLOAT4

	ui_category = "Appearance";
	ui_label = "Paddle Color";
	ui_tooltip =
		"Color of the pong paddle, can be transparent.\n"
		"\nDefault: 0 0 255 255";
> = float4(0.0, 0.0, 1.0, 1.0);

uniform float RandomSpeed <source = "random"; min = 200; max = 500;>;
uniform float RandomDirection <source = "random"; min = 45; max = 135;>;

uniform float2 MousePoint <source = "mousepoint";>;

uniform float FrameTime <source = "frametime";>;
#define DeltaTime (FrameTime * 0.001)

//#endregion

//#region Textures

DECLARE_VARIABLE_TEX(Initialized, R8);
DECLARE_VARIABLE_TEX(CurrBallPosSpeed, RGBA16F);
DECLARE_VARIABLE_TEX(LastBallPosSpeed, RGBA16F);

//#endregion

//#region Functions

void FillRect(inout float4 color, float2 coord, float4 rect, float4 fillColor)
{
	if (
		coord.x >= rect.x && coord.x <= rect.z &&
		coord.y >= rect.y && coord.y <= rect.w)
	{
		color = fillColor;
	}
}

float4 ConvertToRect(float2 pos, float2 size)
{
	return mad(float2(-0.5, 0.5).xxyy, size.xyxy, pos.xyxy);
	//return pos.xyxy + size.xyxy * float2(-0.5, 0.5).xxyy;
	// size *= 0.5;
	// return float4(pos - size, pos + size);
}

float2 GetBallPos()
{
	return tex2Dfetch(CurrBallPosSpeed, 0).xy;
}

void RenderBall(inout float4 color, float2 coord, float2 ballPos)
{
	float4 rect = ConvertToRect(ballPos, BallSize);
	FillRect(color, coord, rect, BallColor);
}

void RenderScore(inout float4 color, float2 coord, int score)
{

}

float2 GetPaddlePos()
{
	float2 paddlePos = float2(MousePoint.x, BUFFER_HEIGHT * PaddleYPercent);

	float paddleHalfWidth = PaddleSize.x * 0.5;
	paddlePos.x = clamp(
		paddlePos.x,
		paddleHalfWidth,
		BUFFER_WIDTH - paddleHalfWidth);

	return paddlePos;
}

void RenderPaddle(inout float4 color, float2 coord, float2 paddlePos)
{
	float4 rect = ConvertToRect(paddlePos, PaddleSize);
	FillRect(color, coord, rect, PaddleColor);
}

/*
    y           y
  +---+       +---+
x | A | z   x | B | z
  +---+       +---+
    w           w
*/
bool AABBCollision(float4 a, float4 b)
{
	return
		a.x < b.z && b.x < a.z &&
		a.y < b.w && b.y < a.w;
}

//#endregion

//#region Shaders

void InitPS(
	float4 p : SV_POSITION,
	float2 uv : TEXCOORD,
	out float4 initialized : SV_TARGET0,
	out float4 currBallPosSpeed : SV_TARGET1,
	out float4 lastBallPosSpeed : SV_TARGET2)
{
	initialized = 1.0;

	float2 startPos = BUFFER_SCREEN_SIZE * float2(0.5, BallInitialYPercent);

	float2 startSpeed = GetDirectionFromAngleMagnitude(
		RandomDirection * DegreesToRadians,
		RandomSpeed);

	currBallPosSpeed = float4(startPos, startSpeed);
	lastBallPosSpeed = currBallPosSpeed;
}

void CheckInitVS(
	uint id : SV_VERTEXID,
	out float4 pos : SV_POSITION,
	out float2 uv : TEXCOORD)
{
	pos = 0;
	uv = 0;

	float initialized = tex2Dfetch(Initialized, 0).x;

	if (initialized > 0.0)
		PostProcessVS(id, pos, uv);
}

float4 CalcPosSpeedPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
	float4 posSpeed = tex2Dfetch(LastBallPosSpeed, 0);
	posSpeed.xy += posSpeed.zw * DeltaTime;

	float2 paddlePos = GetPaddlePos();

	float4 ballRect = ConvertToRect(posSpeed.xy, BallSize);
	float4 paddleRect = ConvertToRect(paddlePos, PaddleSize);

	if (AABBCollision(ballRect, paddleRect))
	{
		float2 delta = posSpeed.xy - paddlePos;
		float angle = atan2(delta.y, delta.x);
		float speed = length(posSpeed.zw) * BallSpeedIncreasePercent;

		posSpeed.zw = GetDirectionFromAngleMagnitude(angle, speed);
	}

	if (ballRect.x < 0.0)
		posSpeed.z = abs(posSpeed.z) * BallSpeedIncreasePercent;
	else if (ballRect.z > BUFFER_WIDTH)
		posSpeed.z = -abs(posSpeed.z) * BallSpeedIncreasePercent;

	if (ballRect.y < 0.0)
		posSpeed.w = abs(posSpeed.w) * BallSpeedIncreasePercent;

	return posSpeed;
}

float4 SavePosSpeedPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
	return tex2Dfetch(CurrBallPosSpeed, 0);
}

float4 RenderPS(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET
{
	float2 coord = uv * BUFFER_SCREEN_SIZE;
	float4 color = tex2D(ReShade::BackBuffer, uv);

	float4 pongGame = BackgroundColor;

	RenderBall(pongGame, coord, GetBallPos());

	RenderPaddle(pongGame, coord, GetPaddlePos());

	color.rgb = lerp(color.rgb, pongGame.rgb, pongGame.a * Opacity);

	return color;
}

//#endregion

//#region Technique

technique Pong_Init <enabled = true; hidden = true; timeout = 1000;>
{
	pass
	{
		VertexShader = PostProcessVS;
		PixelShader = InitPS;
		RenderTarget0 = InitializedTex;
		RenderTarget1 = CurrBallPosSpeedTex;
		RenderTarget2 = LastBallPosSpeedTex;
	}
}

technique Pong
{
	pass CalcPosSpeed
	{
		VertexShader = CheckInitVS;
		PixelShader = CalcPosSpeedPS;
		RenderTarget = CurrBallPosSpeedTex;
	}
	pass SavePosSpeed
	{
		VertexShader = CheckInitVS;
		PixelShader = SavePosSpeedPS;
		RenderTarget = LastBallPosSpeedTex;
	}
	pass Render
	{
		VertexShader = CheckInitVS;
		PixelShader = RenderPS;
	}
}

//#endregion

} // Namespace.

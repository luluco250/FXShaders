#include "ReShade.fxh"

uniform float uSmoothness <
	ui_label = "Smoothness";
	ui_tooltip = "Default: 0.01";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 1.0;
	ui_step = 0.001;
> = 0.01;

uniform float sContrast <
	ui_label = "Contrast";
	ui_tooltip = "Default: 1.0";
	ui_type = "slider";
	ui_min = 0.0;
	ui_max = 2.0;
	ui_step = 0.001;
> = 1.0;

texture tSmall {
	Width = 64;
	Height = 64;
	Format = R8;
	MipLevels = 7;
};
sampler sSmall {
	Texture = tSmall;
	MinFilter = LINEAR;
	MagFilter = LINEAR;
	MipFilter = LINEAR;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

texture tLight {
	Format = R8;
};
sampler sLight {
	Texture = tLight;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
};

texture tLastLight {
	Format = R8;
};
sampler sLastLight {
	Texture = tLastLight;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
};

sampler sColor {
	Texture = ReShade::BackBufferTex;
	MinFilter = POINT;
	MagFilter = POINT;
	MipFilter = POINT;
	AddressU = CLAMP;
	AddressV = CLAMP;
};

float PS_GetSmall(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
	float3 color = tex2D(sColor, uv).rgb;
	float gray = dot(color, 0.33333);

	return gray;
}

float PS_GetLight(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
	float gray = tex2Dlod(sSmall, float4(0.5, 0.5, 0, 7)).r;
	float last = tex2D(sLastLight, 0).r;
	gray = lerp(last, gray, uSmoothness);
	
	return gray;
}

float PS_SaveLight(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
	return tex2D(sLight, 0).r;
}

// Valid from 1000 to 40000 K (and additionally 0 for pure full white)
float3 colorTemperatureToRGB(float temperature){
	// Values from: http://blenderartists.org/forum/showthread.php?270332-OSL-Goodness&p=2268693&viewfull=1#post2268693   
	float3x3 m;
	
	if (temperature <= 6500.0)
		m = float3x3(
			float3(0.0, -2902.1955373783176, -8257.7997278925690),
			float3(0.0, 1669.5803561666639, 2575.2827530017594),
			float3(1.0, 1.3302673723350029, 1.8993753891711275)
		);
	else
		m = float3x3(
			float3(1745.0425298314172, 1216.6168361476490, -8257.7997278925690),
			float3(-2666.3474220535695, -2173.1012343082230, 2575.2827530017594),
			float3(0.55995389139931482, 0.70381203140554553, 1.8993753891711275)
		);
	
	return lerp(
		saturate(
			m[0] / (clamp(temperature, 1000.0, 40000.0) + m[1]) + m[2]
		),
		1.0,
		smoothstep(1000.0, 0.0, temperature)
	);
}

float4 PS_LightColor(float4 p : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
	float4 color = tex2D(sColor, uv);
	float light = tex2D(sLight, 0).r;

	//color *= lerp(1.0, float3(1.0, 0.5, 0.0), (light - 0.5) * 2.0);

	float temp = lerp(0.5, light, sContrast);
	temp *= 39000 + 1000;
	color *= colorTemperatureToRGB(temp);
	
	return color;
}

technique LightColor {
	pass GetSmall {
		VertexShader = PostProcessVS;
		PixelShader = PS_GetSmall;
		RenderTarget = tSmall;
	}
	pass GetLight {
		VertexShader = PostProcessVS;
		PixelShader = PS_GetLight;
		RenderTarget = tLight;
	}
	pass SaveLight {
		VertexShader = PostProcessVS;
		PixelShader = PS_SaveLight;
		RenderTarget = tLastLight;
	}
	pass {
		VertexShader = PostProcessVS;
		PixelShader = PS_LightColor;
	}
}
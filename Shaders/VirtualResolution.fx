#include "ReShade.fxh"

#ifndef VIRTUAL_RESOLUTION_UPFILTER
#define VIRTUAL_RESOLUTION_UPFILTER POINT
#endif

#ifndef VIRTUAL_RESOLUTION_DOWNFILTER
#define VIRTUAL_RESOLUTION_DOWNFILTER LINEAR
#endif

uniform uint iScaleMode <
    ui_label = "Scale Mode";
    ui_type = "combo";
    ui_items = "None\0Crop\0";
> = 0;

uniform float fResolutionX <
    ui_label = "Virtual Resolution Width";
    ui_type = "drag";
    ui_min = 1.0;
    ui_max = BUFFER_WIDTH;
    ui_step = 1.0;
> = BUFFER_WIDTH;

uniform float fResolutionY <
    ui_label = "Virtual Resolution Height";
    ui_type = "drag";
    ui_min = 1.0;
    ui_max = BUFFER_HEIGHT;
    ui_step = 1.0;
> = BUFFER_HEIGHT;

#define f2Resolution float2(fResolutionX, fResolutionY)

sampler sBackBuffer_Down {
    Texture = ReShade::BackBufferTex;
    AddressU = BORDER;
    AddressV = BORDER;
    MinFilter = VIRTUAL_RESOLUTION_DOWNFILTER;
    MagFilter = VIRTUAL_RESOLUTION_DOWNFILTER;
};

sampler sBackBuffer_Up {
    Texture = ReShade::BackBufferTex;
    MinFilter = VIRTUAL_RESOLUTION_UPFILTER;
    MagFilter = VIRTUAL_RESOLUTION_UPFILTER;
};

float2 scaleUV(float2 uv, float2 scale) {
    return (uv - 0.5) * scale + 0.5;
}

float ruleOfThree(float a, float b, float c) {
    return (b * c) / a;
}

bool Crop(float2 uv) {
    static const float ar_real = ReShade::AspectRatio;
    float ar_virtual = fResolutionX / fResolutionY;

    //crop horizontally or vertically? (true = x, false = y)
    bool x_or_y = ar_real > ar_virtual;
    float ar_result = x_or_y ? (ar_virtual / ar_real) : 
                               (ar_real / ar_virtual);
    
    float mask = (1.0 - (ar_result)) * 0.5;
    return x_or_y ? (uv.x > mask && uv.x < 1.0 - mask) : 
                    (uv.y > mask && uv.y < 1.0 - mask);
}

float4 PS_DownSample(float4 pos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
    float2 scale = f2Resolution * ReShade::PixelSize;
    float3 col = tex2D(ReShade::BackBuffer, scaleUV(uv, 1.0 / scale)).rgb;
    return float4(col, 1.0);
}

float4 PS_UpSample(float4 pos : SV_POSITION, float2 uv : TEXCOORD) : SV_TARGET {
    float2 scale = f2Resolution * ReShade::PixelSize;
    float3 col = tex2D(sBackBuffer_Up, scaleUV(uv, scale)).rgb;

    col *= iScaleMode == 1 ? Crop(uv) : 1.0;

    return float4(col, 1.0);
}

technique VirtualResolution {
    pass DownSample {
        VertexShader = PostProcessVS;
        PixelShader = PS_DownSample;
    }
    pass UpSample {
        VertexShader = PostProcessVS;
        PixelShader = PS_UpSample;
    }
}

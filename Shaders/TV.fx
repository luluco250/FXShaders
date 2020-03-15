/*
    TV-like effects by luluco250
*/

#include "ReShade.fxh"

texture2D tTV_Last {
    Width  = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
};
sampler2D sTV_Last {
    Texture = tTV_Last;
};

texture2D tTV_Original {
    Width  = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
};
sampler2D sTV_Original {
    Texture = tTV_Original;
};

float fmod(float a, float b) {
    float c = frac(abs(a / b)) * abs(b);
    return (a < 0.0) ? -c : c;
}

void PS_SaveOriginal(
    float4 position  : SV_POSITION,
    float2 uv        : TEXCOORD,
    out float4 color : SV_TARGET
) {
    color = tex2D(ReShade::BackBuffer, uv);
}

void PS_TV(
    float4 position  : SV_POSITION,
    float2 uv        : TEXCOORD,
    out float4 color : SV_TARGET
) {
    color = tex2D(ReShade::BackBuffer, uv);
    float4 last = tex2D(sTV_Last, uv);

    color = (color + ddx(color) + ddy(color)) / 3.0;
    last  = (last + ddx(last) + ddy(last)) / 3.0;

    color = (color - last) * 2.0;

    /*color = tex2D(ReShade::BackBuffer, uv);
    float4 last = tex2D(sTV_Last, uv);
    float2 coord = uv * ReShade::ScreenSize;
    float pair = fmod(uv.y * BUFFER_HEIGHT, 2.0);

    color = color * pair + last * (1.0 - pair);

    color += ddx(color);
    color += ddy(color);*/
    //color /= 2.0;
}

void PS_SaveLast(
    float4 position  : SV_POSITION,
    float2 uv        : TEXCOORD,
    out float4 color : SV_TARGET
) {
    color = tex2D(sTV_Original, uv);
}

technique TV {
    pass SaveOriginal {
        VertexShader = PostProcessVS;
        PixelShader  = PS_SaveOriginal;
        RenderTarget = tTV_Original;
    }
    pass TV {
        VertexShader = PostProcessVS;
        PixelShader  = PS_TV;
    }
    pass SaveLast {
        VertexShader = PostProcessVS;
        PixelShader  = PS_SaveLast;
        RenderTarget = tTV_Last;
    }
}

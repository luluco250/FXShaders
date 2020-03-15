#include "ReShade.fxh"

#define _tex2D(sp, uv) tex2Dlod(sp, float4(uv, 0.0, 0.0))

sampler2D sPixelMotion_BackBuffer {
    Texture = ReShade::BackBufferTex;
    SRGBTexture = true;
};

texture2D tPixelMotion_Motion {
    Width  = BUFFER_WIDTH / 16;
    Height = BUFFER_HEIGHT / 16;
    Format = RG16F;
};
sampler2D sPixelMotion_Motion {
    Texture = tPixelMotion_Motion;
};

texture2D tPixelMotion_Last {
    Width  = BUFFER_WIDTH;
    Height = BUFFER_HEIGHT;
    Format = R8;
};
sampler2D sPixelMotion_Last {
    Texture = tPixelMotion_Last;
};

float3 get_lum(float3 color) {
    return max(color.r, max(color.g, color.b));
}

void PS_GetMotion(
    float4 position   : SV_POSITION,
    float2 uv         : TEXCOORD,
    out float2 motion : SV_TARGET
) {
    float lum  = get_lum(tex2D(sPixelMotion_BackBuffer, uv).rgb);
    float last = tex2D(sPixelMotion_Last, uv).x;

    motion = float2(ddx(lum), ddy(lum));
    float2 last_motion = float2(ddx(last), ddy(last));

    motion = (motion - last_motion) * 2.0;
    //motion *= 10.0;
    //motion = normalize(motion);

    /*motion = float2(
        ddx(lum) - ddx(last),
        ddy(lum) - ddy(last)
    ) * 2.0;*/
    //motion = normalize(motion) * 20.0;
}

void PS_SaveLast(
    float4 position : SV_POSITION,
    float2 uv       : TEXCOORD,
    out float lum   : SV_TARGET
) {
    lum = get_lum(tex2D(sPixelMotion_BackBuffer, uv).rgb);
}

void PS_Blur(
    float4 position  : SV_POSITION,
    float2 uv        : TEXCOORD,
    out float4 color : SV_TARGET
) {
    float2 motion = tex2D(sPixelMotion_Motion, uv).xy;

    color = 0.0;

    [unroll]
    for (int i = 0; i < 21; ++i) {
        color += _tex2D(sPixelMotion_BackBuffer, uv + ReShade::PixelSize * motion * i);
    }

    color /= 21.0;
}

technique PixelMotion {
    pass GetMotion {
        VertexShader = PostProcessVS;
        PixelShader  = PS_GetMotion;
        RenderTarget = tPixelMotion_Motion;
    }
    pass SaveLast {
        VertexShader = PostProcessVS;
        PixelShader  = PS_SaveLast;
        RenderTarget = tPixelMotion_Last;
    }
    pass Blur {
        VertexShader = PostProcessVS;
        PixelShader  = PS_Blur;
        SRGBWriteEnable = true;
    }
}

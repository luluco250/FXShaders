#pragma once

#define FXSHADERS_TONEMAPPER_LIST \
"Reinhard\0" \
"Reinhard2\0" \
"Uncharted 2 Filmic\0" \
"BakingLab ACES\0"  \
"Lottes\0" \
"Lottes2\0" \
"Narkowicz ACES\0" \
"Unreal3\0" \
"Fallout4\0" \
"Frostbite\0" \
"Uchimura\0" \
"ReinhardJodie\0" \
"iCAM06m\0" \
"HuePreserving\0" \
"Linear\0" \
"None\0"

namespace FXShaders { namespace Tonemap
{

namespace Type
{
	static const int Reinhard = 0;
	static const int Reinhard2 = 1;
	static const int Uncharted2Filmic = 2;
	static const int BakingLabACES = 3;
	static const int Lottes = 4;
	static const int Lottes2 = 5;
	static const int NarkowiczACES = 6;
	static const int Unreal3 = 7;
	static const int Fallout4 = 8;
	static const int Frostbite = 9;
	static const int Uchimura = 10;
	static const int ReinhardJodie = 11;
	static const int iCAM06m = 12;
	static const int HuePreserving = 13;
	static const int Linear = 14;
	static const int None = 15;
}

namespace Reinhard
{
	/**
	* Standard Reinhard tonemapping formula.
	*
	* @param color The color to apply tonemapping to.
	*/
	float3 Apply(float3 color)
	{
		return color / (1.0 + color);
	}

	/**
	* Inverse of the standard Reinhard tonemapping formula.
	*
	* @param color The color to apply inverse tonemapping to.
	*/
	float3 Inverse(float3 color)
	{
		return -(color / min(color - 1.0, -0.1));
	}

	/**
	* Incorrect inverse of the standard Reinhard tonemapping formula.
	* This is only here for NeoBloom right now.
	*
	* @param color The color to apply inverse tonemapping to.
	* @param w The inverse/reciprocal of the maximum brightness to be
	*          generated.
	*          Sample parameter: rcp(100.0)
	*float3 InverseOld(float3 color, float w)
	*{
	*	return color / max(1.0 - color, w);
	*}
	*/

	/**
	* Modified inverse of the Reinhard tonemapping formula that only applies to
	* the luma.
	*
	* @param color The color to apply inverse tonemapping to.
	* @param w The inverse/reciprocal of the maximum brightness to be
	*          generated.
	*          Sample parameter: rcp(100.0)
	*
	*float3 InverseOldLum(float3 color, float w)
	*{
	*	float lum = max(color.r, max(color.g, color.b));
	*	return color * (lum / max(1.0 - lum, w));
	*}
	*/
}

namespace Reinhard2
{
	static const float L_white = 1000000.0;
	/**
	* Alternative Reinhard tonemapping formula that allows whitepoint editing.
	*/
	float3 Apply(float3 color)
	{
		return (color * (1.0 + color / (L_white * L_white))) / (1.0 + color);
	}

	/**
	* Inverse of the standard Reinhard tonemapping formula.
	*/
	float3 Inverse(float3 color)
	{
		return (color * (1.0 + color)) / (1.0 + color / (L_white * L_white));	
	}
}

namespace Uncharted2Filmic
{
	// Shoulder strength.
	static const float A = 0.15;

	// Linear strength.
	static const float B = 0.50;

	// Linear angle.
	static const float C = 0.10;

	// Toe strength.
	static const float D = 0.20;

	// Toe numerator.
	static const float E = 0.02;

	// Toe denominator.
	static const float F = 0.30;

	// Whitepoint.
	//static const float W = 11.2;

	float3 Apply(float3 color)
	{
		color = color;
		color =
		(
			(color * (A * color + C * B) + D * E) /
			(color * (A * color + B) + D * F)
		) - E / F;
		
		return color;
	}

	float3 Inverse(float3 color)
	{
		abs(
			((B * C * F - B * E - B * F * color) -
			sqrt(
				pow(abs(-B * C * F + B * E + B * F * color), 2.0) -
				4.0 * D * (F * F) * color * (A * E + A * F * color - A * F))) /
			(2.0 * A * (E + F * color - F)));
		return color = color;
	}
}

namespace BakingLabACES
{
	static const float A = 0.0245786;
	static const float B = 0.000090537;
	static const float C = 0.983729;
	static const float D = 0.4329510;
	static const float E = 0.238081;

	float3 Apply(float3 color)
	{
		return
			(color * (color + A) - B) /
			(color * (C * color + D) + E);
	}

	float3 Inverse(float3 color)
	{
        float3 discriminant = sqrt(color * color - 4.0 * (C * color - 1.0) * (B + E * color));
        float3 numerator = A - D * color - discriminant;
        float3 denominator = 2.0 * (C * color - 1.0);

        return numerator / denominator;
	}
}

namespace Lottes
{
	float3 Apply(float3 color)
	{
		return color * rcp(max(color.r, max(color.g, color.b)) + 1.0);
	}
	
	float3 Inverse(float3 color)
	{
		return color * rcp(max(1.0 - max(color.r, max(color.g, color.b)), 0.1));
	}
	
}

namespace Lottes2
{
	/**
	* Alternative Lottes tonemapping formula that allows variables editing.
	*/
    static const float a = 1.6;
    static const float d = 0.977;
    static const float hdrMax = 1000000.0;
    static const float midIn = 0.18;
    static const float midOut = 0.267;
		
	float3 Apply(float3 color)
	{
		float b =
        (-pow(midIn, a) + pow(hdrMax, a) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
        
        float c =
        (pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * pow(midIn, a * d) * midOut) /
        ((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut);
	
		return color = pow(color, a) / (pow(color, a * d) * b + c);
	}
	
	float3 Inverse(float3 color)
	{
		float k = pow(midIn, a) / midOut;
		float n = a / (a * d - 1.0);

		// Compute the tonemapped color
		float3 tonemapped = pow(color, a) 
			/ (pow(color, a * d) * 
			((-pow(midIn, a) + pow(hdrMax, a) * midOut) / 
			((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut)) + 
			((pow(hdrMax, a * d) * pow(midIn, a) - pow(hdrMax, a) * 
			pow(midIn, a * d) * midOut) / 
			((pow(hdrMax, a * d) - pow(midIn, a * d)) * midOut)));
		// Compute the inverse function to approximate the input color
		float3 invTonemapped = pow(tonemapped / k, 2.2 / n);

		return invTonemapped;
	}
}

namespace NarkowiczACES
{
	static const float A = 2.51;
	static const float B = 0.03;
	static const float C = 2.43;
	static const float D = 0.59;
	static const float E = 0.14;

	float3 Apply(float3 color)
	{
		return 
			(color * (A * color + B)) / (color * (C * color + D) + E);
	}

	float3 Inverse(float3 color)
	{
		return
			((D * color - B) +
			sqrt(
				4.0 * A * E * color + B * B -
				2.0 * B * D * color -
				4.0 * C * E * color * color +
				D * D * color * color)) /
			(2.0 * (A - C * color));
	}
}

namespace Unreal3
{
	float3 Apply(float3 color)
	{
		return color / (color + 0.155) * 1.019;		
	}

	float3 Inverse(float3 color)
	{
		return abs((color * -0.155) / (max(color, 0.01) - 1.019));
	}
}

namespace Fallout4
{
	//CREDIT TO KINGERIC ON ENB FORUMS FOR RESEARCHING THE FORMULA: 
	//http://enbseries.enbdev.com/forum/viewtopic.php?f=7&t=4695
	//NOTE: It's highly adivsed to remove vanilla bloom in CK,
	//Otherwise, it messes up the precison of MagicHDR bloom.

	// Shoulder Strength
	static const float A = 0.3;

	// Linear Strength float
	static const float B = 0.50;

	// Linear Angle float
	static const float C = 0.10;

	// Toe Strength float 
	static const float D = 0.10;

	// Toe Numerator, usually 0.02, (not static, modifiable in CK ImageSpaces!!!).
	static const float E = 0.02;

	// Toe Denominator 
	static const float F = 0.30;
	
	// LinearWhite, white level 
	//static const float W = 4.2;
 	
	
	float3 Apply(float3 color)
	{
		color =
		(
			(color * (A * color + C * B) + D * E) /
			(color * (A * color + B) + D * F)
		) - E / F;
		return color;
	}
	
	float3 Inverse(float3 color)
	{
        color =
        (
            abs(
            ((B * C * F - B * E - B * F * color) -
            sqrt(
                max(0.0, pow(abs(-B * C * F + B * E + B * F * color), 2.0) -
                4.0 * D * (F * F) * color * (A * E + A * F * color - A * F)))) /
            (2.0 * A * (E + F * color - F)))
        );
        return color;
	}

}

namespace Frostbite
{
    // Constants	
    static const float PQ_constant_N = (2610.0 / 4096.0 / 4.0);
    static const float PQ_constant_M = (2523.0 / 4096.0 * 128.0);
    static const float PQ_constant_C1 = (3424.0 / 4096.0);
    static const float PQ_constant_C2 = (2413.0 / 4096.0 * 32.0);
    static const float PQ_constant_C3 = (2392.0 / 4096.0 * 32.0);

    // Helper Functions

    // PQ (Perceptual Quantizer; ST.2084) encode/decode used for HDR TV and grading
    float3 linearTOPQ(float3 linearCol, const float maxPqValue)
    {
        linearCol /= maxPqValue;

        float3 colToPow = pow(linearCol, PQ_constant_N);
        float3 numerator = PQ_constant_C1 + PQ_constant_C2 * colToPow;
        float3 denominator = 1.0 + PQ_constant_C3 * colToPow;
        float3 pq = pow(numerator / denominator, PQ_constant_M);

        return pq;
    }

    float3 PQtoLinear(float3 linearCol, const float maxPqValue)
    {
        float3 colToPow = pow(linearCol, 1.0 / PQ_constant_M);
        float3 numerator = max(colToPow, PQ_constant_C1);
        float3 denominator = PQ_constant_C2 - (PQ_constant_C3 * colToPow);
        float3 linearColor = pow(numerator / denominator, 1.0 / PQ_constant_N);

        linearColor *= maxPqValue;
        //return saturate(linearColor);
        return linearColor;
    }
    
	    float SCurve(float x)
	{
	    float a = 2.51;
	    float b = 0.03;
	    float c = 2.43;
	    float d = 0.59;
	    float e = 0.14;
	
	    x = max(x, 0.0);
	    return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
	}
	
	float3 DScurve(float3 x)
	{
	    float a = 2.51;
	    float b = 0.03;
	    float c = 2.43;
	    float d = 0.59;
	    float e = 0.14;
	
	    x = max(x, 0.0);
	    float3 r = (x * (c * x + d) + e);
	    return (a * x * (d * x + 2.0 * e) + b * (e - c * x * x)) / (r * r);
	}

    // RGB with SRGB/Rec.709 primaries to CIE XYZ
    float3 RGBTOXYZ(float3 c)
    {
        float3x3 mat = float3x3(
			0.4124564, 0.3575761, 0.1804375,
	        0.2126729, 0.7151522, 0.0721750,
	        0.0193339, 0.1191920, 0.9503041
		);

        return float3(
            dot(mat[0], c),
            dot(mat[1], c),
            dot(mat[2], c)
        );
    }
    
    float3 XYZTORGB(float3 c)
	{
	    
		float3x3 mat = float3x3(
			3.24045483602140870, -1.53713885010257510, -0.49853154686848090,
			-0.96926638987565370, 1.87601092884249100, 0.04155608234667354,
			0.05564341960421366,  -0.20402585426769815, 1.05722516245792870
		);
	
        return float3(
            dot(mat[0], c),
            dot(mat[1], c),
            dot(mat[2], c)
        );
	}

    // Converts XYZ tristimulus values into cone responses for the three types of cones in the human visual system, matching long, medium, and short wavelengths.
    // Note that there are many LMS color spaces; this one follows the ICtCp color space specification.
    float3 XYZTOLMS(float3 c)
    {
        float3x3 mat = float3x3(
			0.3592, 0.6976, -0.0358,
	        -0.1922, 1.1004, 0.0755,
	        0.0070, 0.0749, 0.8434
		);

        return float3(
            dot(mat[0], c),
            dot(mat[1], c),
            dot(mat[2], c)
        );
    }

    float3 LMSTOXYZ(float3 c)
    {
        float3x3 mat = float3x3(
			2.07018005669561320, -1.32645687610302100, 0.206616006847855170,
	        0.36498825003265756, 0.68046736285223520, -0.045421753075853236,
	        -0.04959554223893212, -0.04942116118675749, 1.187995941732803400
		);

        return float3(
            dot(mat[0], c),
            dot(mat[1], c),
            dot(mat[2], c)
        );
    }

    // RGB with SRGB/Rec.709 primaries to ICtCp
    float3 RGBTOICtCp(float3 col)
    {
        col = RGBTOXYZ(col);
        col = XYZTOLMS(col);
        // 1.0f 100 nits, 100.0f 10k nits
        col = linearTOPQ(max(0.0.xxx, col), 100);

        // Convert PQ-LMS into ICtCp. Note that the "s" channel is not used,
        // but overlap between the cone responses for long, medium, and short wavelengths
        // ensures that the corresponding part of the spectrum contributes to luminance.
        float3x3 mat = float3x3(
			0.5000, 0.5000, 0.0000,
	        1.6137, -3.3234, 1.7097,
	        4.3780, -4.2455, -0.1325
		);

        return float3(
            dot(mat[0], col),
            dot(mat[1], col),
            dot(mat[2], col)
        );
    }

    float3 ICtCpTORGB(float3 col)
    {
        float3x3 mat = float3x3(
			1.0, 0.00860514569398152, 0.11103560447547328,
			1.0, -0.00860514569398152, -0.11103560447547328,
			1.0, 0.56004885956263900, -0.32063747023212210
		);

        col = float3(
            dot(mat[0], col),
            dot(mat[1], col),
            dot(mat[2], col)
        );
        // 1.0f 100 nits, 100.0f = 10k nits
        col = PQtoLinear(col, 0.00080);
        col = LMSTOXYZ(col);
        return XYZTORGB(col);
    }

    // Aplies exponential ("Photographic") luma compression
    float rangeCompress(float x)
    {
        return 1.0 - exp(-x);
    }

    float rangeCompress(float val, float threshold)
    {
        float vl = val;
        float v2 = threshold + (1 - threshold) * rangeCompress((val - threshold) / (1 - threshold));
        return val < threshold ? vl : v2;
    }

    float3 rangeCompress(float3 val, float threshold)
    {
        return float3(
            rangeCompress(val.x, threshold),
            rangeCompress(val.y, threshold),
            rangeCompress(val.z, threshold)
        );
    }

	// Code: Display Mapper
	float3 Apply(float3 color)
	{
	    float3 ictcp = RGBTOICtCp(color);
	
	    // Hue-preserving range compression requires desaturation in order to achieve a natural look. We adaptively desaturate the input based on its luminance. 
	    float saturationAmount = pow(smoothstep(1.0, 0.3, ictcp.x), 1.3);
	    color = ICtCpTORGB(ictcp * float3(1, saturationAmount, saturationAmount));
	
	    // Only compress luminance starting at a certain point. Dimmer inputs are passed through without modification.
	    float linearSegmentEnd = 0.25;
	
	    // Hue-preserving mapping
	    float maxCol = max(color.x, max(color.y, color.z));
	    float mappedMax = rangeCompress(maxCol, linearSegmentEnd);
	    float3 compressedHuePreserving = color * mappedMax / maxCol;
	
	    // Non-hue preserving mapping
	    float3 perChannelCompressed = rangeCompress(color, linearSegmentEnd);
	
	    // Combine hue-preserving and non-hue-preserving colors. Absolute hue preservation looks unnatural, as bright colors appear to have been hue shifted. 
	    // Actually doing some amount of hue shifting looks more pleasing 
	    color = lerp(perChannelCompressed, compressedHuePreserving, 0.6);
	
	    float3 ictcpMapped = RGBTOICtCp(color);
	
	    // Smoothly ramp off saturation as brightness increases, but keep some even for very bright input
	    float postCompressionSaturationBoost = 0.3 * smoothstep(1.0, 0.5, ictcp.x);
	
	    // Re-introduce some hue from the pre-compression color. Something similar could be accomplished by delaying the luma-dependent desaturation before range compression.
	    // Doing it here, however, does a better job of preserving perceptual luminance of highly saturated colors. Because in the hue-preserving path, we only range-compress the max channel, 
	    // saturated colors lose luminance. By desaturating them more aggressively first, compressing, and then re-adding some saturation, we can preserve their brightness to a greater extent.
	    ictcpMapped.yz = lerp(ictcpMapped.yz, ictcp.yz * ictcpMapped.x / max(1e-3, ictcp.x), postCompressionSaturationBoost);
	
	    color = ICtCpTORGB(ictcpMapped);
	    return color;
	}
	
	float3 Inverse(float3 color)
	{
	    // Reverse the saturation adjustment
	    float3 ictcp = RGBTOICtCp(color);
	    float initialSaturationAmount = pow(smoothstep(1.0, 0.3, ictcp.x), 1.3);
	    ictcp.yz /= float2(initialSaturationAmount, initialSaturationAmount); // Reverse the saturation scaling
	
	    // Reverse the luminance compression
	    float linearSegmentEnd = 0.25;
	    float maxCol = max(color.x, max(color.y, color.z));
	    float mappedMax = rangeCompress(maxCol, linearSegmentEnd);
	    float3 uncompressedColor = color / mappedMax * maxCol; // Reverse the luminance compression
	
	    // Blend between hue-preserving and non-hue-preserving colors
	    float3 perChannelUncompressed = rangeCompress(uncompressedColor, linearSegmentEnd);
	    float3 compressedHuePreserving = uncompressedColor * mappedMax / maxCol; // Reverse the hue-preserving compression
	    float blendFactor = 0.6;
	    color = lerp(perChannelUncompressed, compressedHuePreserving, blendFactor);
	
	    // Reverse the saturation boost
	    float postCompressionSaturationBoost = 0.3 * smoothstep(1.0, 0.5, ictcp.x);
	    ictcp.yz /= float2(1.0 + postCompressionSaturationBoost, 1.0 + postCompressionSaturationBoost); // Reverse the saturation boost
	
	    // Convert back from ICtCp to RGB
	    color = ICtCpTORGB(ictcp);
	
	    // Convert back from HDR to linear
	    color = PQtoLinear(color, 0.00080);
	    
	    return color;
	}

}


namespace Uchimura
{
	/**
	* Grand Tourismo Tonemapping.
	*/
    static const float P = 1000000;  // max display brightness
    static const float a = 1.0;  // contrast
    static const float m = 0.22; // linear section start
    static const float l = 0.4;  // linear section length
    static const float c = 1.33; // black
    static const float b = 0.0;  // pedestal
	
	float3 Apply(float3 color)
	{
	
		float l0 = ((P - m) * l) / a;
		float L0 = m - m / a;
		float L1 = m + (1.0 - m) / a;
		float S0 = m + l0;
		float S1 = m + a * l0;
		float C2 = (a * P) / (P - S1);
		float CP = -C2 / P;

		float3 w0 = 1.0 - smoothstep(0.0, m, color);
		float3 w2 = step(m + l0, color);
		float3 w1 = 1.0 - w0 - w2;

		float3 T = m * pow(color / m, c) + b;
		float3 S = P - (P - S1) * exp(CP * (color - S0));
		float3 L = m + a * (color - m);

		float3 result = T * w0 + L * w1 + S * w2;
		return result;
	}

	float3 Inverse(float3 color)
	{

		float l0 = ((P - m) * l) / a;
		float L0 = m - m / a;
		float L1 = m + (1.0 - m) / a;
		float S0 = m + l0;
		float S1 = m + a * l0;
		float C2 = (a * P) / (P - S1);
		float CP = -C2 / P;

		float3 w0 = 1.0 - smoothstep(0.0, m, color);
		float3 w2 = step(m + l0, color);
		float3 w1 = 1.0 - w0 - w2;

		float3 T = pow(((color - b + 0.0001) / m), 2.2);
		float3 S = log(max(0.0001, (P - color) / (P - S1))) / CP + S0;
		float3 L = (color - m) / a + m;

		float3 result = T * w0 + L * w1 + S * w2;
		result = pow(result / P, 1.0 / c) * P;

		//result = clamp(result, 0.0, P);

		return result;
	}
}


namespace ReinhardJodie
{
	/**
	* Alternative Reinhard tonemapping formula that attempts to preserve a bit of saturation on highlights.
	*/
	float3 Apply(float3 color)
	{	    
		float3 luma = (0.2126, 0.7152, 0.0722);
		float3 l = dot(color, luma);
		float3 tc=color/(color+1.);
		float3 finalcolor = lerp(color/(l+1.),tc,tc);
		
		return finalcolor;
	}
	
	float3 Inverse(float3 color)
	{
		float3 luma = float3(0.2126, 0.7152, 0.0722);
		float3 l = dot(color, luma);
		float3 tc = lerp(color / (l + 1.0), color / (color + 1.0), color / (color + 1.0));
		return tc / (1.0 - tc);
	}
}

namespace iCAM06m
{

    // Define the color conversion matrices
	static const float RGBtoXYZ[] = { 0.4124564, 0.3575761, 0.1804375, 0.2126729, 0.7151522, 0.0721750, 0.0193339, 0.1191920, 0.9503041 };
    static const float XYZtoRGB[] = { 3.2404542, -1.5371385, -0.4985314, -0.9692660, 1.8760108, 0.0415560, 0.0556434, -0.2040259, 1.0572252 };
	static const float Exposure = -4.0;
	static const float Whitepoint = 100.0;
	
	/**
	* iCAM06m tonemapping formula that attempts to preserve a bit of saturation on highlights.
	*/
	
	float3 Apply(float3 color)
    {
        // Compute the luminance of the input color
        float L = dot(color, float3(0.2126, 0.7152, 0.0722));

        // Normalize the luminance using the whitepoint
        float Lw = dot(float3(Whitepoint,Whitepoint,Whitepoint), float3(RGBtoXYZ[0], RGBtoXYZ[1], RGBtoXYZ[2]));
        L = L / Lw;

        // Compute the local adaptation luminance
        float La = L / (1.0 + L);

        // Compute the surround factor
        float F = 0.2 * pow(abs(La), 0.4);

        // Compute the chromatic adaptation factor
        float Fc = pow(1.219 + pow(F, 0.4), 1.0 / 0.4);

        // Apply the exposure adjustment
        color *= pow(2.0, Exposure);

        // Compute the scaled luminance
        float3 XYZ = float3(
            RGBtoXYZ[0] * color.x + RGBtoXYZ[1] * color.y + RGBtoXYZ[2] * color.z,
            RGBtoXYZ[3] * color.x + RGBtoXYZ[4] * color.y + RGBtoXYZ[5] * color.z,
            RGBtoXYZ[6] * color.x + RGBtoXYZ[7] * color.y + RGBtoXYZ[8] * color.z);

        // Normalize the luminance using the whitepoint
        XYZ /= Lw;

        // Apply the chromatic adaptation factor
        XYZ *= Fc;

        // Compute the adapted XYZ values
        XYZ *= Lw;

        // Convert the adapted XYZ values back to RGB
        color = float3(
            XYZtoRGB[0] * XYZ.x + XYZtoRGB[1] * XYZ.y + XYZtoRGB[2] * XYZ.z,
            XYZtoRGB[3] * XYZ.x + XYZtoRGB[4] * XYZ.y + XYZtoRGB[5] * XYZ.z,
            XYZtoRGB[6] * XYZ.x + XYZtoRGB[7] * XYZ.y + XYZtoRGB[8] * XYZ.z);

        return color;
    }
	
	float3 Inverse(float3 color)
	{

        // Convert the input RGB values to XYZ color space
        float3 XYZ = float3(
            RGBtoXYZ[0] * color.x + RGBtoXYZ[1] * color.y + RGBtoXYZ[2] * color.z,
            RGBtoXYZ[3] * color.x + RGBtoXYZ[4] * color.y + RGBtoXYZ[5] * color.z,
            RGBtoXYZ[6] * color.x + RGBtoXYZ[7] * color.y + RGBtoXYZ[8] * color.z);

        // Normalize the luminance using the whitepoint
        float Lw = dot(float3(Whitepoint,Whitepoint,Whitepoint), float3(RGBtoXYZ[0], RGBtoXYZ[1], RGBtoXYZ[2]));
        XYZ /= Lw;

        // Undo the chromatic adaptation factor
        float F = 0.2 * pow(abs(XYZ.y / Lw), 0.4);
        float Fc = pow(1.219 + pow(F, 0.4), 1.0 / 0.4);
        XYZ /= Fc;

        // Compute the adapted RGB values
        float3 RGB = float3(
            XYZtoRGB[0] * XYZ.x + XYZtoRGB[1] * XYZ.y + XYZtoRGB[2] * XYZ.z,
            XYZtoRGB[3] * XYZ.x + XYZtoRGB[4] * XYZ.y + XYZtoRGB[5] * XYZ.z,
            XYZtoRGB[6] * XYZ.x + XYZtoRGB[7] * XYZ.y + XYZtoRGB[8] * XYZ.z);

        // Undo exposure adjustment
        RGB /= pow(2.0, (Exposure + (Exposure * 1.5)));

        return RGB;
	}
}

//
// https://www.shadertoy.com/view/fsXcz4
//
namespace HuePreserving 
{
    static const float softness_scale = 0.2; // controls softness of RGB clipping
    static const float offset = 0.75; // controls how colors desaturate as they brighten. 0 results in that colors never fluoresce, 1 in very saturated colors 
    static const float chroma_scale = 1.2; // overall scale of chroma

    float3 s_curve(float3 x)
    {
        float a = 2.51;
        float b = 0.03;
        float c = 2.43;
        float d = 0.59;
        float e = 0.14;
        x = max(x, 0.0);
        return clamp((x * (a * x + b)) / (x * (c * x + d) + e), 0.0, 1.0);
    }

    float3 d_s_curve(float3 x)
    {
        float a = 2.51;
        float b = 0.03;
        float c = 2.43;
        float d = 0.59;
        float e = 0.14;
        x = max(x, 0.0);
        float3 r = (x * (c * x + d) + e);
        return (a * x * (d * x + 2.0 * e) + b * (e - c * x * x)) / (r * r);
    }

    float2 findCenterAndPurity(float3 x)
    {
        // Define the matrix M
        float3x3 M = float3x3(
            2.26775149, -1.43293879, 0.1651873,
            -0.98535505, 2.1260072, -0.14065215,
            -0.02501605, -0.26349465, 1.2885107
        );

        x = float3(
		    dot(x, M[0]),
		    dot(x, M[1]),
		    dot(x, M[2])
		);

        float x_min = min(x.r,min(x.g,x.b));
        float x_max = max(x.r,max(x.g,x.b));

        float c = 0.5 * (x_max + x_min);
        float s = (x_max - x_min);

        // Math trickery to create values close to c and s, but without producing hard edges
        float3 y = (x - c) / s;
        float c_smooth = c + dot(y * y * y, 1.0 / 3.0) * s;
        float s_smooth = sqrt(dot(x - c_smooth, x - c_smooth) / 2.0);
        return float2(c_smooth, s_smooth);
    }

    float3 toLms(float3 c)
    {
        float3x3 rgbToLms = float3x3(
            0.4122214708, 0.5363325363, 0.0514459929,
            0.2119034982, 0.6806995451, 0.1073969566,
            0.0883024619, 0.2817188376, 0.6299787005
        );

        float3 lms_ =float3(
		    dot(c, rgbToLms[0]),
		    dot(c, rgbToLms[1]),
		    dot(c, rgbToLms[2])
		);
        return sign(lms_) * pow(abs(lms_), 1.0 / 3.0);
    }

	float calculateC(float3 lms)
	{	
	    float a = 1.9779984951 * lms.x - 2.4285922050 * lms.y + 0.4505937099 * lms.z;
	    float b = 0.0259040371 * lms.x + 0.7827717662 * lms.y - 0.8086757660 * lms.z;
	
	    return sqrt(a * a + b * b);
	}


    float2 calculateMC(float3 c)
    {
        float3 lms = toLms(c);

        float M = findCenterAndPurity(lms).x;

        return float2(M, calculateC(lms));
    }

    float2 expandShape(float3 rgb, float2 ST)
    {
        float2 MC = calculateMC(rgb);
        float2 STnew = float2((MC.x) / MC.y, (1.0 - MC.x) / MC.y);
        STnew = (STnew + 3.0 * STnew * STnew * MC.y);

        return float2(min(ST.x, STnew.x), min(ST.y, STnew.y));
    }

    float expandScale(float3 rgb, float2 ST, float scale)
    {
        float2 MC = calculateMC(rgb);
        float Cnew = (1.0 / ((ST.x / (MC.x)) + (ST.y / (1.0 - MC.x))));

        return max(MC.y / Cnew, scale);
    }

    float2 approximateShape()
    {
        float m = -softness_scale * 0.2;
        float s = 1.0 + (softness_scale * 0.2 + softness_scale * 0.8);

        float2 ST = float2(1000.0, 1000.0);
        ST = expandShape(m + s * float3(1.0, 0.0, 0.0), ST);
        ST = expandShape(m + s * float3(1.0, 1.0, 0.0), ST);
        ST = expandShape(m + s * float3(0.0, 1.0, 0.0), ST);
        ST = expandShape(m + s * float3(0.0, 1.0, 1.0), ST);
        ST = expandShape(m + s * float3(0.0, 0.0, 1.0), ST);
        ST = expandShape(m + s * float3(1.0, 0.0, 1.0), ST);

        float scale = 0.0;
        scale = expandScale(m + s * float3(1.0, 0.0, 0.0), ST, scale);
        scale = expandScale(m + s * float3(1.0, 1.0, 0.0), ST, scale);
        scale = expandScale(m + s * float3(0.0, 1.0, 0.0), ST, scale);
        scale = expandScale(m + s * float3(0.0, 1.0, 1.0), ST, scale);
        scale = expandScale(m + s * float3(0.0, 0.0, 1.0), ST, scale);
        scale = expandScale(m + s * float3(1.0, 0.0, 1.0), ST, scale);

        return ST / scale;
    }

    float3 tonemap_hue_preserving(float3 c)
    {
        float3x3 toLms = float3x3(
            0.4122214708, 0.5363325363, 0.0514459929,
            0.2119034982, 0.6806995451, 0.1073969566,
            0.0883024619, 0.2817188376, 0.6299787005);

        float3x3 fromLms = float3x3(
            +4.0767416621, -3.3077115913, +0.2309699292,
            -1.2684380046, +2.6097574011, -0.3413193965,
            -0.0041960863, -0.7034186147, +1.7076147010);

        float3 lms_ = float3(
		    dot(c, toLms[0]),
		    dot(c, toLms[1]),
		    dot(c, toLms[2])
		);
        float3 lms = sign(lms_) * pow(abs(lms_), 1.0 / 3.0);

        float2 MP = findCenterAndPurity(lms);

        // Apply tone curve

        // Approach 1: scale chroma based on the derivative of the chroma curve
        if (true)
        {
            float I = (MP.x + (1.0 - offset) * MP.y);
            lms = lms * I * I;

            I = I * I * I;
            float3 dLms = lms - I;

            float Icurve = s_curve(float3(I, I, I)).x;
            lms = 1.0 + chroma_scale * dLms * d_s_curve(float3(I, I, I)) / Icurve;
            I = pow(Icurve, 1.0 / 3.0);

            lms = lms * I;
        }

        // Approach 2: Separate color into a whiteness/blackness part, apply scale to them independently
        if (false)
        {
            lms = chroma_scale * (lms - MP.x) + MP.x;

            float invBlackness = (MP.x + MP.y);
            float whiteness = (MP.x - MP.y);

            float invBlacknessC = pow(s_curve(float3(invBlackness, invBlackness, invBlackness)).x, 1.0 / 3.0);
            float whitenessC = pow(s_curve(float3(whiteness, whiteness, whiteness)).x, 1.0 / 3.0);

            lms = (invBlacknessC + whitenessC) / 2.0 + (lms - (invBlackness + whiteness) / 2.0) * (invBlacknessC - whitenessC) / (invBlackness - whiteness);
        }

        // Compress to a smooth approximation of the target gamut
        {
        float M = findCenterAndPurity(lms).x;
        float2 ST = approximateShape();
        float C_smooth_gamut = (1.0) / ((ST.x / M) + (ST.y / (1.0 - M)));
        float C = calculateC(lms);

        // Adjust the line below to change the compression of chroma values
        lms = (lms - M) / sqrt(C * C / C_smooth_gamut / C_smooth_gamut + 1.0) + M;
        }

        float3 rgb = float3(
		    dot(lms * lms * lms, fromLms[0]),
		    dot(lms * lms * lms, fromLms[1]),
		    dot(lms * lms * lms, fromLms[2])
		);

        return rgb;
    }

    float3 softSaturate(float3 x, float3 a)
    {
        a = clamp(a, 0.0, softness_scale);
        a = 1.0 + a;
        x = min(x, a);
        float3 b = (a - 1.0) * sqrt(a / (2.0 - a));
        return 1.0 - (sqrt((x - a) * (x - a) + b * b) - b) / (sqrt(a * a + b * b) - b);
    }

    float3 softClipColor(float3 color)
    {
        // Soft clip of RGB values to avoid artifacts of hard clipping
        // Causes hue distortions, but is a smooth mapping
        // Not quite sure this mapping is easy to invert, but should be possible to construct similar ones that do

        float grey = 0.2;

        float3 x = color - grey;

        float3 xsgn = sign(x);
        float3 xscale = 0.5 + xsgn * (0.5 - grey);
        x /= xscale;

        float maxRGB = max(color.r, max(color.g, color.b));
        float minRGB = min(color.r, min(color.g, color.b));

        float softness_0 = maxRGB / (1.0 + softness_scale) * softness_scale;
        float softness_1 = (1.0 - minRGB) / (1.0 + softness_scale) * softness_scale;

        float3 softness = 0.5 * (softness_0 + softness_1 + xsgn * (softness_1 - softness_0));

        return grey + xscale * xsgn * softSaturate(abs(x), softness);
    }

    float3 Apply(float3 color)
    {
        color = tonemap_hue_preserving(color);
        color = softClipColor(color);
        return color;
    }
	
	float3 Inverse(float3 color)
	{
	    float grey = 0.2;
	    float3 x = color - grey;
	    float3 xsgn = sign(x);
	    float3 xscale = 0.5 + xsgn * (0.5 - grey);
	    x /= xscale;
	
	    float maxRGB = max(color.r, max(color.g, color.b));
	    float minRGB = min(color.r, min(color.g, color.b));
	    float softness_0 = maxRGB / (1.0 + softness_scale) * softness_scale;
	    float softness_1 = (1.0 - minRGB) / (1.0 + softness_scale) * softness_scale;
	    float3 softness = 0.5 * (softness_0 + softness_1 + xsgn * (softness_1 - softness_0));
	
	    float3 result = grey + xscale * xsgn * softSaturate(abs(x), softness);
	
	    float3x3 toLms = float3x3(
	        0.4122214708, 0.5363325363, 0.0514459929,
	        0.2119034982, 0.6806995451, 0.1073969566,
	        0.0883024619, 0.2817188376, 0.6299787005);
	
	    float3x3 fromLms = float3x3(
	        +4.0767416621, -3.3077115913, +0.2309699292,
	        -1.2684380046, +2.6097574011, -0.3413193965,
	        -0.0041960863, -0.7034186147, +1.7076147010);
	
	    float3 lms_ = float3(
	        dot(result, toLms[0]),
	        dot(result, toLms[1]),
	        dot(result, toLms[2])
	    );
	
	    float3 lms = sign(lms_) * pow(abs(lms_), 1.0 / 3.0);
	
	    float2 MP = findCenterAndPurity(lms);
	
	    float3 invertedLms = lms;
	
	    // Reverse the tonemapping operations while preserving luminance
	    {
	        float M = findCenterAndPurity(lms).x;
	        float2 ST = approximateShape();
	        float C_smooth_gamut = (1.0) / ((ST.x / M) + (ST.y / (1.0 - M)));
	        float C = calculateC(lms);
	
	        // Adjust the line below to change the compression of chroma values
	        invertedLms = (lms - M) / sqrt(C * C / C_smooth_gamut / C_smooth_gamut + 1.0) + M;
	    }
	
	    float3 invertedRgb = float3(
	        dot(invertedLms * invertedLms * invertedLms, fromLms[0]),
	        dot(invertedLms * invertedLms * invertedLms, fromLms[1]),
	        dot(invertedLms * invertedLms * invertedLms, fromLms[2])
	    );
	
	    // Clamp to ensure values stay within the range
	
	    return invertedRgb;
	}


}

namespace Linear 
{
	float3 Apply(float3 color)
	{
		color = pow(color, 1.0 / 2.2);
		// Precise Linear to sRGB
		//color = max(1.055 * pow(color, 0.416666667) - 0.055, 0);
		return color;
	}

	float3 Inverse(float3 color)
	{
		color = pow(color, 2.2);
		// Precise sRGB to Linear
		//color = color * (color * (color * 0.305306011 + 0.682171111) + 0.012522878);
		return color;
	}
}

namespace None 
{
	float3 Apply(float3 color)
	{
		return color;
	}

	float3 Inverse(float3 color)
	{
		return color;
	}
}

float3 Apply(int type, float3 color)
{
	switch (type)
	{
		case Type::Reinhard:
			return Reinhard::Apply(color);
		case Type::Reinhard2:
			return Reinhard2::Apply(color);
		case Type::Uncharted2Filmic:
			return Uncharted2Filmic::Apply(color);
		case Type::BakingLabACES:
			return BakingLabACES::Apply(color);
		case Type::Lottes:
			return Lottes::Apply(color);
		case Type::Lottes2:
			return Lottes2::Apply(color);
		case Type::NarkowiczACES:
			return NarkowiczACES::Apply(color);
		case Type::Unreal3:
			return Unreal3::Apply(color);
		case Type::Fallout4:
			return Fallout4::Apply(color);
		case Type::Frostbite:
			return Frostbite::Apply(color);
		case Type::Uchimura:
			return Uchimura::Apply(color);
		case Type::ReinhardJodie:
			return ReinhardJodie::Apply(color);
		case Type::iCAM06m:
			return iCAM06m::Apply(color);
		case Type::HuePreserving:
			return HuePreserving::Apply(color);
		case Type::Linear:
			return Linear::Apply(color);
		case Type::None:
			return None::Apply(color);
	}

	return color;
}

float3 Inverse(int type, float3 color)
{
	switch (type)
	{
		case Type::Reinhard:
			return Reinhard::Inverse(color);
		case Type::Reinhard2:
			return Reinhard2::Inverse(color);
		case Type::Uncharted2Filmic:
			return Uncharted2Filmic::Inverse(color);
		case Type::BakingLabACES:
			return BakingLabACES::Inverse(color);
		case Type::Lottes:
			return Lottes::Inverse(color);
		case Type::Lottes2:
			return Lottes2::Inverse(color);
		case Type::NarkowiczACES:
			return NarkowiczACES::Inverse(color);
		case Type::Unreal3:
			return Unreal3::Inverse(color);
		case Type::Fallout4:
			return Fallout4::Inverse(color);
		case Type::Frostbite:
			return Frostbite::Inverse(color);
		case Type::Uchimura:
			return Uchimura::Inverse(color);
		case Type::ReinhardJodie:
			return ReinhardJodie::Inverse(color);
		case Type::iCAM06m:
			return iCAM06m::Inverse(color);
		case Type::HuePreserving:
			return HuePreserving::Inverse(color);
		case Type::Linear:
			return Linear::Inverse(color);
		case Type::None:
			return None::Inverse(color);
	}

	return color;
}

}} // Namespace.

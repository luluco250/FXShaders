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
"AMDLPM\0" \
"Uchimura\0" \
"ReinhardJodie\0"

float FindMaxLuminance(float3 color)
{
    return max(max(color.r, color.g), color.b);
}

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
	static const int AMDLPM = 9;
	static const int Uchimura = 10;
	static const int ReinhardJodie = 11;
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
	static const float L_white = 40.0;
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
	static const float W = 11.2;

	float3 Apply(float3 color)
	{
		color =
		(
			(color * (A * color + C * B) + D * E) /
			(color * (A * color + B) + D * F)
		) - E / F;

		color = color * W / (W + 1.0);
		
		float3 finalcolor = clamp(color, 0.0, 1.0);
		return finalcolor;
	}

	float3 Inverse(float3 color)
	{
		color = color * (W + 1.0) / W;

		return abs(
			((B * C * F - B * E - B * F * color) -
			sqrt(
				pow(abs(-B * C * F + B * E + B * F * color), 2.0) -
				4.0 * D * (F * F) * color * (A * E + A * F * color - A * F))) /
			(2.0 * A * (E + F * color - F)));
	}
}

namespace BakingLabACES
{
	// sRGB => XYZ => D65_2_D60 => AP1 => RRT_SAT
	static const float3x3 ACESInputMat = float3x3
	(
		0.59719, 0.35458, 0.04823,
		0.07600, 0.90834, 0.01566,
		0.02840, 0.13383, 0.83777
	);

	// ODT_SAT => XYZ => D60_2_D65 => sRGB
	static const float3x3 ACESOutputMat = float3x3
	(
		1.60475, -0.53108, -0.07367,
		-0.10208,  1.10813, -0.00605,
		-0.00327, -0.07276,  1.07602
	);

	float3 RRTAndODTFit(float3 v)
	{
		float3 a = v * (v + 0.0245786f) - 0.000090537f;
		float3 b = v * (0.983729f * v + 0.4329510f) + 0.238081f;
		return a / b;
	}

	float3 ACESFitted(float3 color)
	{
		color = mul(ACESInputMat, color);

		// Apply RRT and ODT
		color = RRTAndODTFit(color);

		color = mul(ACESOutputMat, color);

		// Clamp to [0, 1]
		color = saturate(color);

		return color;
	}

	static const float A = 0.0245786;
	static const float B = 0.000090537;
	static const float C = 0.983729;
	static const float D = 0.4329510;
	static const float E = 0.238081;

	float3 Apply(float3 color)
	{
		return saturate(
			(color * (color + A) - B) /
			(color * (C * color + D) + E));
	}

	float3 Inverse(float3 color)
	{
		return abs(
			((A - D * color) -
			sqrt(
				pow(abs(D * color - A), 2.0) -
				4.0 * (C * color - 1.0) * (B + E * color))) /
			(2.0 * (C * color - 1.0)));
	}
}

namespace Lottes
{
	float3 Apply(float3 color)
	{
	float3 finalcolor =  color * rcp(max(color.r, max(color.g, color.b)) + 1.0);
	
	return finalcolor = clamp(finalcolor, 0.0, 1.0);
	}
	
	float3 Inverse(float3 color)
	{
		float3 finalcolor = color * rcp(max(1.0 - max(color.r, max(color.g, color.b)), 0.1));
		//return clamp(finalcolor, 0.0, 1.0);
		return finalcolor;
	}
	
}

namespace Lottes2
{
	/**
	* Alternative Lottes tonemapping formula that allows variables editing.
	*/
    static const float a = 1.6;
    static const float d = 0.977;
    static const float hdrMax = 100.0;
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
	
		float3 finalcolor = pow(color, a) / (pow(color, a * d) * b + c);
		finalcolor = clamp(finalcolor, 0.0, 1.0);
		return finalcolor;
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

		// Clamp the tonemapped color to avoid out-of-range values
		tonemapped = clamp(tonemapped, 0.0, 1.0);

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
		return saturate(
			(color * (A * color + B)) / (color * (C * color + D) + E));
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
		return (color * -0.155) / (max(color, 0.01) - 1.019);
	}
}

namespace Fallout4
{
	//CREDIT TO KINGERIC ON ENB FORUMS FOR RESEARCHING THE FORMULA: 
	//http://enbseries.enbdev.com/forum/viewtopic.php?f=7&t=4695
	//NOTE: It's highly adivsed to remove vanilla bloom in CK,
	//Otherwise, it messes up the precison of MagicHDR bloom.
	//Also, even without vanilla bloom, there seems to be a lot of precision lost,
	//Manifesting in random bloom color shifts. Perhaps I did something wrong?

	// Filmic operator.
	static const float A = 0.3;

	// Shoulder Strength.
	static const float B = 0.50;

	// Linear Strength.
	static const float C = 0.10;

	// Linear Angle.
	static const float D = 0.10;

	// Toe Strength, usually 0.02, (not static, modifiable in CK ImageSpaces!!!).
	static const float E = 0.02;

	// Toe Numerator.
	static const float F = 0.30;
	
	//Toe Denominator
	static const float W = 5.6;
	
	//Max HDR Value for preventing "out of range" artifacts in the highlights
	static const float max_value = 100.0;
 	
	
	float3 Apply(float3 color)
	{
		color =
		(
			(color * (A * color + C * B) + D * E) /
			(color * (A * color + B) + D * F)
		) - E / F;
		
		color = saturate(color);

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

        float3 finalcolor = color * W;
        finalcolor = clamp(finalcolor, 0.0, max_value);
        return finalcolor;
	}

}

namespace AMDLPM
{
	/**
	* AMD Lume Preserving Mapper written by ChatGPT AI. Can not guarantee that it is a proper implementation, needs more testing and research!
	*/
    static const float epsilon = 0.0001;
    static const float epsilon2 = 0.00001;
    static const float exposure = -0.50;
    static const float shoulder = 0.5;
    static const float midIn = 0.18;
    static const float midOut = 0.18;
    static const float highIn = 10.00;
    static const float highOut = 2.00;
    static const float lowIn = 0.001;
    static const float lowOut = 0.001;
    static const float maxHDR = 100.00;
    static const float3 R = float3(0.299, 0.587, 0.114);
    static const float3 W = float3(0.25, 0.25, 0.25);
	static const float TonemapContrast = 1.00;
	static const float Saturation = 0.25;
	static const float3 SaturationCrosstalk = float3(1.0/1.0,1.0/4.0,1.0/32.0);

    float3 Apply(float3 color)
	{
		float3 linearColor = color;
		//float3 colorScaled = linearColor * maxHDR;
		float3 colorScaled = clamp(linearColor, 0.0, maxHDR); //clamp the value to ensure it's in range

		// Apply tonemapping curve to luminance
		float luminance = dot(colorScaled, R);
		float mappedLuminance;
		if (luminance == 0.0)
		mappedLuminance = ((luminance * 1.0 * 3.0) + W.r) / (luminance * (1.0 * 3.0) + 1.0 + epsilon);
		else if (exposure > 0.0) // fix for negative exposure
		mappedLuminance = ((luminance * exposure * 3.0) + W.r) / (luminance * (exposure * 3.0) + 1.0 + epsilon);
		else // fix for negative exposure
		mappedLuminance = ((luminance / (-exposure * 3.0) + W.r) / (luminance / (-exposure * 3.0) + 1.0 + epsilon));
		
		float exposureOffset = (exposure < 0 ? -1 : 1) * abs(lowOut); //add offset based on the sign of exposure
		mappedLuminance = pow(mappedLuminance + exposureOffset, 1.0 / shoulder);
		float3 mappedColor = colorScaled * (mappedLuminance / (luminance + epsilon));

		// Apply LPM curve
		float3 midInScaled = midIn / maxHDR;
		float3 midOutScaled = midOut / maxHDR;
		float3 highInScaled = highIn / maxHDR;
		float3 highOutScaled = highOut / maxHDR;
		float3 lowInScaled = lowIn / maxHDR;
		float3 lowOutScaled = max(0.0001, lowOut - 0.05) / maxHDR;

		float3 p = pow(mappedColor, shoulder);
		float3 q = pow(midInScaled, shoulder) + p;
		float3 r = pow(highInScaled, shoulder) + p;

		float3 s = pow(lowOutScaled, shoulder);
		float3 t = pow(midOutScaled, shoulder) + s;
		float3 u = pow(highOutScaled, shoulder) + s;

		float3 v = pow(q / (q + r), 2.0 / shoulder);
		float3 w = pow(t / (t + u), 2.0 / shoulder);

		float3 x = ((mappedColor - midInScaled) * v) + midInScaled;
		float3 y = ((mappedColor - midOutScaled) * w) + midOutScaled;
		//float3 z = clamp(y, 0.0, 1.0);
		
		// Apply saturation and saturation crosstalk
		float3 mappedColorScaled = (y * (highOutScaled - lowOutScaled)) + lowOutScaled;
		float3 tonemappedColor = lerp(mappedColorScaled, mappedColor, TonemapContrast);
		
		float3 average = dot(tonemappedColor, R);
		float3 desaturated = lerp(average, tonemappedColor, clamp(Saturation, 0.0, 1.0));
		float3 saturated = lerp(desaturated, tonemappedColor, clamp(Saturation, 0.0, 1.0));
		float3 saturationCrosstalk = SaturationCrosstalk * (1.0 - Saturation);
		float3 saturationAdjusted = saturated + saturationCrosstalk * (desaturated - average);

		tonemappedColor = saturate(saturationAdjusted);
		float3 finalcolor = tonemappedColor;

    return finalcolor;
	
	}
	
	float3 Inverse(float3 color)
	{	 
		// Reverse the saturation adjustment
		float3 average = dot(color, R);
		float3 desaturated = lerp(average, color, clamp(Saturation, 0.0, 1.0));
		float3 saturated = lerp(desaturated, color, clamp(Saturation, 0.0, 1.0));
		float3 saturationCrosstalk = SaturationCrosstalk + (SaturationCrosstalk / (1.0 - Saturation));
		float3 saturationAdjusted = saturated + saturationCrosstalk * (desaturated - average);
		
		// Reverse the LPM curve
		float3 midInScaled = midIn / maxHDR;
		float3 midOutScaled = midOut / maxHDR;
		float3 highInScaled = highIn / maxHDR;
		float3 highOutScaled = highOut / maxHDR;
		float3 lowInScaled = lowIn / maxHDR;
		float3 lowOutScaled = max(0.0001, lowOut - 0.05) / maxHDR;

		float3 p = pow(saturationAdjusted, 1.0 / shoulder);
		float3 q = pow(midInScaled, 1.0 / shoulder) + p;
		float3 r = pow(highInScaled, 1.0 / shoulder) + p;

		float3 s = pow(lowOutScaled, 1.0 / shoulder);
		float3 t = pow(midOutScaled, 1.0 / shoulder) + s;
		float3 u = pow(highOutScaled, 1.0 / shoulder) + s;

		float3 v = pow(q / (q + r), 0.5 * shoulder);
		float3 w = pow(t / (t + u), 0.5 * shoulder);

		float3 x = ((saturationAdjusted - midInScaled) / v) + midInScaled;
		float3 y = ((saturationAdjusted - midOutScaled) / w) + midOutScaled;

		// Reverse the tonemapping curve
		float3 linearColor = y / (1.0 + (shoulder * pow(y, 1.0 - TonemapContrast)));
		float3 colorScaled = clamp(linearColor, 0.0, maxHDR); //clamp the value to ensure it's in range
		return colorScaled;
	}
}

namespace Uchimura
{
	/**
	* Grand Tourismo Tonemapping.
	*/
    static const float P = 1.0;  // max display brightness
    static const float a = 0.75;  // contrast
    static const float m = 0.22; // linear section start
    static const float l = 0.15;  // linear section length
    static const float c = 1.5; // black
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
		result = pow(result, 1.0/2.2);
		result = clamp(result, 0.0,1.0);
		return result;
	}

	float3 Inverse(float3 color)
	{
		color = pow(color, 2.2);

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

		result = pow(result, 1.0 / 2.2);
		result = clamp(result, 0.0, P);

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
		finalcolor = clamp(finalcolor, 0.0, 1.0);
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
		case Type::AMDLPM:
			return AMDLPM::Apply(color);
		case Type::Uchimura:
			return Uchimura::Apply(color);
		case Type::ReinhardJodie:
			return ReinhardJodie::Apply(color);
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
		case Type::AMDLPM:
			return AMDLPM::Inverse(color);
		case Type::Uchimura:
			return Uchimura::Inverse(color);
		case Type::ReinhardJodie:
			return ReinhardJodie::Inverse(color);
	}

	return color;
}

}} // Namespace.

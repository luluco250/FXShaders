#pragma once

namespace FXShaders
{

/**
 * Standard Reinhard tonemapping formula.
 *
 * @param color The color to apply tonemapping to.
 */
float3 Reinhard(float3 color)
{
	return color / (1.0 + color);
}

/**
 * Inverse of the standard Reinhard tonemapping formula.
 *
 * @param color The color to apply inverse tonemapping to.
 * @param inv_max The inverse/reciprocal of the maximum brightness to be
 *                generated.
 *                Sample parameter: rcp(100.0)
 */
float3 ReinhardInv(float3 color, float inv_max)
{
	return (color / max(1.0 - color, inv_max));
}

/**
 * Modified inverse of the Reinhard tonemapping formula that only applies to
 * the luma.
 *
 * @param color The color to apply inverse tonemapping to.
 * @param inv_max The inverse/reciprocal of the maximum brightness to be
 *                generated.
 *                Sample parameter: rcp(100.0)
 */
float3 ReinhardInvLum(float3 color, float inv_max)
{
	float lum = max(color.r, max(color.g, color.b));
	return color * (lum / max(1.0 - lum, inv_max));
}

/**
 * The standard, copy/paste Uncharted 2 filmic tonemapping formula.
 *
 * @param color The color to apply tonemapping to.
 * @param exposure The amount of exposure to be applied to the color during
 *                 tonemapping.
 */
float3 Uncharted2Tonemap(float3 color, float exposure) {
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

	// Linear white point value.
	static const float W = 11.2;

    static const float white =
		1.0 / ((
			(W * (A * W + C * B) + D * E) /
			(W * (A * W + B) + D * F)
		) - E / F);

	color *= exposure;

    color = (
		(color * (A * color + C * B) + D * E) /
		(color * (A * color + B) + D * F)
	) - E / F;

	color *= white;

    return color;
}

} // Namespace.

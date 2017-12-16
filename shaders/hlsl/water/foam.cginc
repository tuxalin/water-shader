//
// Description : Foam color based on water depth, near the shore
//

half FoamColor(sampler2D tex, float2 texCoord, float2 texCoord2, float2 ranges, half2 factors, float waterDepth, half baseColor)
{
	float f1 = tex2D(tex, texCoord).r;
	float f2 = tex2D(tex, texCoord2).r;
	return lerp(f1 * factors.x + f2 * factors.y, baseColor, smoothstep(ranges.x, ranges.y, waterDepth));
}

// surfacePosition, depthPosition, eyeVec in world space
// waterDepth is the horizontal water depth in world space
half FoamValue(sampler2D shoreTexture, sampler2D foamTexture, float2 foamTiling,
	float4 foamNoise, float2 foamSpeed, float3 foamRanges, float maxAmplitude,
	float3 surfacePosition, float3 depthPosition, float3 eyeVec, float waterDepth,
	float2 timedWindDir, float timer)
{
	float2 position = (surfacePosition.xz + eyeVec.xz * 0.1) * 0.5;

	float s = sin(timer * 0.01 + depthPosition.x);
	float2 texCoord = position + timer * 0.01 * foamSpeed + s * 0.05;
	s = sin(timer * 0.01 + depthPosition.z);
	float2 texCoord2 = (position + timer * 0.015 * foamSpeed + s * 0.05) * -0.5; // also flip
	float2 texCoord3 = texCoord * foamTiling.x;
	float2 texCoord4 = (position + timer * 0.015 * -foamSpeed * 0.3 + s * 0.05) * -0.5 * foamTiling.x; // reverse direction
	texCoord *= foamTiling.y;
	texCoord2 *= foamTiling.y;

	float2 ranges = foamRanges.xy;
	ranges.x += snoise(surfacePosition.xz + foamNoise.z * timedWindDir) * foamNoise.x;
	ranges.y += snoise(surfacePosition.xz + foamNoise.w * timedWindDir) * foamNoise.y;
	ranges = clamp(ranges, 0.0, 10.0);

	float foamEdge = max(ranges.x, ranges.y);
	half deepFoam = FoamColor(foamTexture, texCoord, texCoord2, float2(ranges.x, foamEdge), half2(1.0, 0.5), waterDepth, 0.0);
	half foam = FoamColor(shoreTexture, texCoord3 * 0.25, texCoord4, float2(0.0, ranges.x), half2(0.75, 1.5), waterDepth, deepFoam);

	// high waves foam
	if (surfacePosition.y - foamRanges.z > 0.0001f)
	{
		half amount = saturate((surfacePosition.y - foamRanges.z) / maxAmplitude) * 0.25;
		foam += (tex2D(shoreTexture, texCoord3).x + tex2D(shoreTexture, texCoord4).x * 0.5f) * amount;
	}

	return foam;
}

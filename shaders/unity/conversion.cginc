//
// Description : Utilties for NDC to world/clip coordinates and other
//

#define INVERSE_FOG_COLOR(fogCoord, color) UNITY_CALC_FOG_FACTOR((fogCoord)); color = yInverseLerp(unity_FogColor, color, saturate(unityFogFactor))

float4 NdcToClipPos(float3 ndc)
{
	// map xy to -1,1
	float4 clipPos = float4(ndc.xy * 2.0f - 1.0f, ndc.z, 1.0f);

#if defined(UNITY_REVERSED_Z)
	//D3d with reversed Z
	clipPos.z = 1.0f - clipPos.z;
#elif UNITY_UV_STARTS_AT_TOP
	//D3d without reversed z
#else
	//opengl, map to -1,1
	clipPos.z = clipPos.z * 2.0f - 1.0f;
#endif

	return clipPos;
}

float3 NdcToWorldPos(float4x4 inverseVP, float3 ndc)
{
	float4 clipPos = NdcToClipPos(ndc);
	float4 pos = mul(inverseVP, clipPos);
	pos.xyz /= pos.w;

	return pos.xyz;
}

float3 yInverseLerp(float3 x, float3 y, float a)
{
	if (a)
		return (y - x * (1 - a)) / a;
	return y;
}

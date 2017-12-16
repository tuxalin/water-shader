//
// Description : Utilties for waves displacement
//

#include "waves.cginc"

float2 GetNoise(in float2 position, in float2 timedWindDir)
{
	float2 noise;
	noise.x = snoise(position * 0.015 + timedWindDir * 0.0005); // large and slower noise 
	noise.y = snoise(position * 0.1 + timedWindDir * 0.002); // smaller and faster noise
	return saturate(noise);
}

void AdjustWavesValues(in float2 noise, inout half4 wavesNoise, inout half4 wavesIntensity)
{
	wavesNoise = wavesNoise * half4(noise.y * 0.25, noise.y * 0.25, noise.x + noise.y, noise.y);
	wavesIntensity = wavesIntensity + half4(saturate(noise.y - noise.x), noise.x, noise.y, noise.x + noise.y);
	wavesIntensity = clamp(wavesIntensity, 0.01, 10);
}

// uv in texture space, normal in world space
half3 ComputeNormal(sampler2D normalTexture, float2 worldPos, float2 texCoord,
	half3 normal, half3 tangent, half3 bitangent,
	half4 wavesNoise, half4 wavesIntensity, float2 timedWindDir)
{
	float2 noise = GetNoise(worldPos, timedWindDir * 0.5);
	AdjustWavesValues(noise, wavesNoise, wavesIntensity);

	float2 texCoords[4] = { texCoord * 1.6 + timedWindDir * 0.064 + wavesNoise.x,
		texCoord * 0.8 + timedWindDir * 0.032 + wavesNoise.y,
		texCoord * 0.5 + timedWindDir * 0.016 + wavesNoise.z,
		texCoord * 0.3 + timedWindDir * 0.008 + wavesNoise.w };

	half3 wavesNormal = half3(0, 1, 0);
#ifdef USE_DISPLACEMENT
	normal = normalize(normal);
	tangent = normalize(tangent);
	bitangent = normalize(bitangent);
	for (int i = 0; i < 4; ++i)
	{
		wavesNormal += ComputeSurfaceNormal(normal, tangent, bitangent, normalTexture, texCoords[i]) * wavesIntensity[i];
	}
#else
	for (int i = 0; i < 4; ++i)
	{
		wavesNormal += UnpackNormal(tex2D(normalTexture, texCoords[i])) * wavesIntensity[i];
	}
	wavesNormal.xyz = wavesNormal.xzy; // flip zy to avoid btn multiplication
#endif // #ifdef USE_DISPLACEMENT

	return wavesNormal;
}

#ifdef USE_DISPLACEMENT
float ComputeNoiseHeight(sampler2D heightTexture, float4 wavesIntensity, float4 wavesNoise, float2 texCoord, float2 noise, float2 timedWindDir)
{
	AdjustWavesValues(noise, wavesNoise, wavesIntensity);

	float2 texCoords[4] = { texCoord * 1.6 + timedWindDir * 0.064 + wavesNoise.x,
							texCoord * 0.8 + timedWindDir * 0.032 + wavesNoise.y,
							texCoord * 0.5 + timedWindDir * 0.016 + wavesNoise.z,
							texCoord * 0.3 + timedWindDir * 0.008 + wavesNoise.w };
	float height = 0;
	for (int i = 0; i < 4; ++i)
	{
		height += tex2Dlod(heightTexture, float4(texCoords[i], 0, 0)).x * wavesIntensity[i];
	}

	return height;
}

float3 ComputeDisplacement(float3 worldPos, float cameraDistance, float2 noise, float timer,
	float4 waveSettings, float4 waveAmplitudes, float4 wavesIntensity, float4 waveNoise,
	out half3 normal, out half3 tangent)
{
	float2 windDir = waveSettings.xy;
	float waveSteepness = waveSettings.z;
	float waveTiling = waveSettings.w;

	//TODO: improve motion/simulation instead of just noise
	//TODO: fix UV due to wave distortion

	wavesIntensity = normalize(wavesIntensity);
	waveNoise = half4(noise.x - noise.x * 0.2 + noise.y * 0.1, noise.x + noise.y * 0.5 - noise.y * 0.1, noise.x, noise.x) * waveNoise;
	half4 wavelengths = half4(1, 4, 3, 6) + waveNoise;
	half4 amplitudes = waveAmplitudes + half4(0.5, 1, 4, 1.5) * waveNoise;

	// reduce wave intensity base on distance to reduce aliasing
	wavesIntensity *= 1.0 - saturate(half4(cameraDistance / 120.0, cameraDistance / 150.0, cameraDistance / 170.0, cameraDistance / 400.0));

	// compute position and normal from several sine and gerstner waves
	tangent = normal = half3(0, 1, 0);
	float2 timers = float2(timer * 0.5, timer * 0.25);
	for (int i = 2; i < 4; ++i)
	{
		float A = wavesIntensity[i] * amplitudes[i];
		float3 vals = SineWaveValues(worldPos.xz * waveTiling, windDir, A, wavelengths[i], timer);
		normal += wavesIntensity[i] * SineWaveNormal(windDir, A, vals);
		tangent += wavesIntensity[i] * SineWaveTangent(windDir, A, vals);
		worldPos.y += SineWaveDelta(A, vals);
	}

	// using normalized wave steepness, tranform to Q
	float2 Q = waveSteepness / ((2 * 3.14159265 / wavelengths.xy) * amplitudes.xy);
	for (int j = 0; j < 2; ++j)
	{
		float A = wavesIntensity[j] * amplitudes[j];
		float3 vals = GerstnerWaveValues(worldPos.xz * waveTiling, windDir, A, wavelengths[j], Q[j], timer);
		normal += wavesIntensity[j] * GerstnerWaveNormal(windDir, A, Q[j], vals);
		tangent += wavesIntensity[j] * GerstnerWaveTangent(windDir, A, Q[j], vals);
		worldPos += GerstnerWaveDelta(windDir, A, Q[j], vals);
	}

	normal = normalize(normal);
	tangent = normalize(tangent);
	if (length(wavesIntensity) < 0.01)
	{
		normal = half3(0, 1, 0);
		tangent = half3(0, 0, 1);
	}

	return worldPos;
}
#endif

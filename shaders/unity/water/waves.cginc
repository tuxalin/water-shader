//
// Description : Utilties for waves simulation
//
// based on GPU Gems Chapter 1. Effective Water Simulation from Physical Models, by Mark Finch and Cyan Worlds
//

float3 GerstnerWaveValues(float2 position, float2 D, float amplitude, float wavelength, float Q, float timer)
{
	float w = 2 * 3.14159265 / wavelength;
	float dotD = dot(position, D);
	float v = w * dotD + timer;
	return float3(cos(v), sin(v), w);
}

half3 GerstnerWaveNormal(float2 D, float A, float Q, float3 vals)
{
	half C = vals.x;
	half S = vals.y;
	half w = vals.z;
	half WA = w * A;
	half WAC = WA * C;
	half3 normal = half3(-D.x * WAC, 1.0 - Q * WA * S, -D.y * WAC);
	return normalize(normal);
}

half3 GerstnerWaveTangent(float2 D, float A, float Q, float3 vals)
{
	half C = vals.x;
	half S = vals.y;
	half w = vals.z;
	half WA = w * A;
	half WAS = WA * S;
	half3 normal = half3(Q * -D.x * D.y * WAS, D.y * WA * C, 1.0 - Q * D.y * D.y * WAS);
	return normalize(normal);
}

float3 GerstnerWaveDelta(float2 D, float A, float Q, float3 vals)
{
	float C = vals.x;
	float S = vals.y;
	float QAC = Q * A * C;
	return float3(QAC * D.x, A * S, QAC * D.y);
}

void GerstnerWave(float2 windDir, float tiling, float amplitude, float wavelength, float Q, float timer, inout float3 position, out half3 normal)
{
	float2 D = windDir;
	float3 vals = GerstnerWaveValues(position.xz * tiling, D, amplitude, wavelength, Q, timer);
	normal = GerstnerWaveNormal(D, amplitude, Q, vals);
	position += GerstnerWaveDelta(D, amplitude, Q, vals);
}

float3 SineWaveValues(float2 position, float2 D, float amplitude, float wavelength, float timer)
{
	float w = 2 * 3.14159265 / wavelength;
	float dotD = dot(position, D);
	float v = w * dotD + timer;
	return float3(cos(v), sin(v), w);
}

half3 SineWaveNormal(float2 D, float A, float3 vals)
{
	half C = vals.x;
	half w = vals.z;
	half WA = w * A;
	half WAC = WA * C;
	half3 normal = half3(-D.x * WAC, 1.0, -D.y * WAC);
	return normalize(normal);
}

half3 SineWaveTangent(float2 D, float A, float3 vals)
{
	half C = vals.x;
	half w = vals.z;
	half WAC = w * A * C;
	half3 normal = half3(0.0, D.y * WAC, 1.0);
	return normalize(normal);
}

float SineWaveDelta(float A, float3 vals)
{
	return vals.y * A;
}

void SineWave(float2 windDir, float tiling, float amplitude, float wavelength, float timer, inout float3 position, out half3 normal)
{
	float2 D = windDir;
	float3 vals = SineWaveValues(position.xz * tiling, D, amplitude, wavelength, timer);
	normal = SineWaveNormal(D, amplitude, vals);
	position.y += SineWaveDelta(amplitude, vals);
}

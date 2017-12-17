
#include "unpack.cginc"
#include "snoise.cginc"
#include "bicubic.cginc"
#include "normals.cginc"
#include "water/displacement.cginc"
#include "water/meansky.cginc"
#include "water/radiance.cginc"
#include "water/depth.cginc"
#include "water/foam.cginc"

uniform sampler2D _CameraDepthTexture;
uniform sampler2D _NormalTexture;
uniform sampler2D _FoamTexture;
uniform sampler2D _ShoreTexture;
uniform sampler2D _ReflectionTexture; 
uniform float4 _ReflectionTexture_TexelSize;
uniform sampler2D _RefractionTexture;
#ifdef USE_DISPLACEMENT
uniform sampler2D _HeightTexture;
#endif
#ifdef USE_MEAN_SKY_RADIANCE
uniform samplerCUBE _SkyTexture;
#endif

uniform float4 _WorldSpaceCameraPos;
uniform float4 _WorldSpaceLightPos0;
uniform float4x4 _ModelMatrix;
uniform float4x4 _ModelMatrixInverse;
uniform float4x4 _ViewProjectMatrix;
uniform float4x4 _ViewProjectMatrixInverse;
uniform float4x4 _ModelViewProjectMatrix;

uniform float _Time;
uniform float _AmbientDensity;
uniform float _DiffuseDensity;
uniform float _HeightIntensity;
uniform float _NormalIntensity;
uniform float _TextureTiling;

uniform float4 _LightColor0;
uniform float4 _AmbientColor;
uniform float3 _SurfaceColor;
uniform float3 _ShoreColor;
uniform float3 _DepthColor;
// Wind direction in world coordinates, amplitude encoded as the length of the vector
uniform float2 _WindDirection;
uniform float _WaveTiling;
uniform float _WaveSteepness;
uniform float _WaveAmplitudeFactor;
// Displacement amplitude of multiple waves, x = smallest waves, w = largest waves
uniform float4 _WaveAmplitude;
// Intensity of multiple waves, affects the frequency of specific waves, x = smallest waves, w = largest waves
uniform float4 _WavesIntensity;
// Noise of multiple waves, x = smallest waves, w = largest waves
uniform float4 _WavesNoise;
// Affects how fast the colors will fade out, thus, use smaller values (eg. 0.05f).
// to have crystal clear water and bigger to achieve "muddy" water.
uniform float _WaterClarity;
// Water transparency along eye vector
uniform float _WaterTransparency;
// Horizontal extinction of the RGB channels, in world coordinates. 
// Red wavelengths dissapear(get absorbed) at around 5m, followed by green(75m) and blue(300m).
uniform float3 _HorizontalExtinction;
uniform float _Shininess;
// xy = Specular intensity values, z = shininess exponential factor.
uniform float3 _SpecularValues;
// x = index of refraction constant, y = refraction intensity
// if you want to empasize reflections use values smaller than 0 for refraction intensity.
uniform float2 _RefractionValues;
// Amount of wave refraction, of zero then no refraction. 
uniform float _RefractionScale;
// Reflective radiance factor.
uniform float _RadianceFactor;
// Reflection distortion, the higher the more distortion.
uniform float _Distortion;
// x = range for shore foam, y = range for near shore foam, z = threshold for wave foam
uniform float3 _FoamRanges;
// x = noise for shore, y = noise for outer
// z = speed of the noise for shore, y = speed of the noise for outer, not that speed can be negative
uniform float4 _FoamNoise;
uniform float2 _FoamTiling;
// Extra speed applied to the wind speed near the shore
uniform float _FoamSpeed;
uniform float _FoamIntensity;
uniform float _ShoreFade;

struct VertexInput {
	float4 vertex : POSITION;
};
struct VertexOutput {
	float4 pos : SV_POSITION;
	float2 uv : TEXCOORD0;
	float3 normal : TEXCOORD1;  // world normal
	float3 tangent : TEXCOORD2;
	float3 bitangent : TEXCOORD3;
	float3 worldPos : TEXCOORD4;
	float4 projPos : TEXCOORD5;
	float timer : TEXCOORD6;
	float4 wind : TEXCOORD7; // xy = normalized wind, zw = wind multiplied with timer
};

float4 ClipToScreenPos(float4 pos) 
{
    float4 o = pos * 0.5f;
    o.xy += o.w;
    o.zw = pos.zw;
    return o;
}

VertexOutput vert(VertexInput v)
{
	VertexOutput o = (VertexOutput)0;

	float2 windDir = _WindDirection;
	float windSpeed = length(_WindDirection);
	windDir /= windSpeed;
	float timer = _Time * windSpeed * 10;

	float4 modelPos = v.vertex;
	float3 worldPos = mul(_ModelMatrix, float4(modelPos.xyz, 1));
	half3 normal = half3(0, 1, 0);

#ifdef USE_DISPLACEMENT
	float cameraDistance = length(_WorldSpaceCameraPos.xyz - worldPos);
	float2 noise = GetNoise(worldPos.xz, timer * windDir * 0.5);

	half3 tangent;
	float4 waveSettings = float4(windDir, _WaveSteepness, _WaveTiling);
	float4 waveAmplitudes = _WaveAmplitude * _WaveAmplitudeFactor;
	worldPos = ComputeDisplacement(worldPos, cameraDistance, noise, timer, 
		waveSettings, waveAmplitudes, _WavesIntensity, _WavesNoise, 
		normal, tangent);

	// add extra noise height from a heightmap
	float heightIntensity = _HeightIntensity * (1.0 - cameraDistance / 100.0) * _WaveAmplitude;
	float2 texCoord = worldPos.xz * 0.05 *_TextureTiling;
	if (heightIntensity > 0.02)
	{
		float height = ComputeNoiseHeight(_HeightTexture, _WavesIntensity, _WavesNoise, 
			texCoord, noise, timer);
		worldPos.y += height * heightIntensity;
	}

	modelPos = mul(_ModelMatrixInverse, float4(worldPos, 1.0));
	o.tangent = tangent;
	o.bitangent = cross(normal, tangent);
#endif
	float2 uv = worldPos.xz;

	o.timer = timer;
	o.wind.xy = windDir;
	o.wind.zw = windDir * timer;

	o.uv = uv  * 0.05 * _TextureTiling;
	o.pos = mul(_ModelViewProjectMatrix, float4(modelPos.xyz, 1.0));
	o.worldPos = worldPos;
	o.projPos = ClipToScreenPos(o.pos);
	o.normal = normal;

	return o;
}

float4 NdcToClipPos(float3 ndc)
{
	// map xy to -1,1
	float4 clipPos = float4(ndc.xy * 2.0f - 1.0f, ndc.z, 1.0f);

#if defined(REVERSED_Z)
	//D3d with reversed Z
	clipPos.z = 1.0f - clipPos.z;
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

float4 frag(VertexOutput fs_in, float facing : VFACE) : COLOR
{
	float timer = fs_in.timer;
	float2 windDir = fs_in.wind.xy;
	float2 timedWindDir = fs_in.wind.zw;
	float2 ndcPos = float2(fs_in.projPos.xy / fs_in.projPos.w);
	float3 eyeDir = normalize(_WorldSpaceCameraPos.xyz - fs_in.worldPos);
	float3 surfacePosition = fs_in.worldPos;
	half3 lightColor = _LightColor0.rgb;

	//wave normal
#ifdef USE_DISPLACEMENT
	half3 normal = ComputeNormal(_NormalTexture, surfacePosition.xz, fs_in.uv,
		fs_in.normal, fs_in.tangent, fs_in.bitangent, _WavesNoise, _WavesIntensity, timedWindDir);
#else
	half3 normal = ComputeNormal(_NormalTexture, surfacePosition.xz, fs_in.uv,
		fs_in.normal, 0, 0, _WavesNoise, _WavesIntensity, timedWindDir);
#endif
	normal = normalize(lerp(fs_in.normal, normalize(normal), _NormalIntensity));

	// compute refracted color
	float depth = tex2Dproj(_CameraDepthTexture, fs_in.projPos.xyww);
	float3 depthPosition = NdcToWorldPos(_ViewProjectMatrixInverse, float3(ndcPos, depth));
	float waterDepth = surfacePosition.y - depthPosition.y; // horizontal water depth
	float viewWaterDepth = length(surfacePosition - depthPosition); // water depth from the view direction(water accumulation)
	float2 dudv = ndcPos;
	{
		// refraction based on water depth
		float refractionScale = _RefractionScale * min(waterDepth, 1.0f);
		float2 delta = float2(sin(timer + 3.0f * abs(depthPosition.y)),
							  sin(timer + 5.0f * abs(depthPosition.y)));
		dudv += windDir * delta * refractionScale;
	}
	half3 pureRefractionColor = tex2D(_RefractionTexture, dudv).rgb;
	float2 waterTransparency = float2(_WaterClarity, _WaterTransparency);
	float2 waterDepthValues = float2(waterDepth, viewWaterDepth);
	float shoreRange = max(_FoamRanges.x, _FoamRanges.y) * 2.0;
	half3 refractionColor = DepthRefraction(waterTransparency, waterDepthValues, shoreRange, _HorizontalExtinction,
											pureRefractionColor, _ShoreColor, _SurfaceColor, _DepthColor);

	// compute ligths's reflected radiance
	float3 lightDir = normalize(_WorldSpaceLightPos0);
	half fresnel = FresnelValue(_RefractionValues, normal, eyeDir);
	half3 specularColor = ReflectedRadiance(_Shininess, _SpecularValues, lightColor, lightDir, eyeDir, normal, fresnel);

	// compute sky's reflected radiance
#ifdef USE_MEAN_SKY_RADIANCE
	half3 reflectColor = fresnel * MeanSkyRadiance(_SkyTexture, eyeDir, normal) * _RadianceFactor;
#else
	half3 reflectColor = 0;
#endif // #ifndef USE_MEAN_SKY_RADIANCE

	// compute reflected color
	dudv = ndcPos + _Distortion * normal.xz;
#ifdef USE_FILTERING
	reflectColor += tex2DBicubic(_ReflectionTexture, _ReflectionTexture_TexelSize.z, dudv).rgb;
#else
	reflectColor += tex2D(_ReflectionTexture, dudv).rgb;
#endif // #ifdef USE_FILTERING

	// shore foam
#ifdef USE_FOAM
	float maxAmplitude = max(max(_WaveAmplitude.x, _WaveAmplitude.y), _WaveAmplitude.z);
	half foam = FoamValue(_ShoreTexture, _FoamTexture, _FoamTiling,
				_FoamNoise, _FoamSpeed * windDir, _FoamRanges, maxAmplitude,
				surfacePosition, depthPosition, eyeDir, waterDepth, timedWindDir, timer);
	foam *= _FoamIntensity;
#else
	half foam = 0;
#endif // #ifdef USE_FOAM

	half  shoreFade = saturate(waterDepth * _ShoreFade);
	// ambient + diffuse
	half3 ambientColor = _AmbientColor.rgb * _AmbientDensity + saturate(dot(normal, lightDir)) * _DiffuseDensity;
	// refraction color with depth based color
	pureRefractionColor = lerp(pureRefractionColor, reflectColor, fresnel * saturate(waterDepth / (_FoamRanges.x * 0.4)));
	pureRefractionColor = lerp(pureRefractionColor, _ShoreColor, 0.30 * shoreFade);
	// compute final color
	half3 color = lerp(refractionColor, reflectColor, fresnel);
	color = saturate(ambientColor + color + max(specularColor, foam * lightColor));
	color = lerp(pureRefractionColor + specularColor * shoreFade, color, shoreFade);

#ifdef DEBUG_NORMALS
	color.rgb = 0.5 + 2 * ambientColor + specularColor + clamp(dot(normal, lightDir), 0, 1) * 0.5;
#endif

	return float4(color, 1.0);
}

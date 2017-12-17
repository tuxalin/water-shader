
Shader "Water" {
	Properties{
		[Header(Features)]
		[Toggle(USE_DISPLACEMENT)] _UseDisplacement("Displacement", Float) = 0
		[Toggle(USE_MEAN_SKY_RADIANCE)] _UseMeanSky("Mean sky radiance", Float) = 0
		[Toggle(USE_FILTERING)] _UseFiltering("Filtering", Float) = 0
		[Toggle(USE_FOAM)] _UseFoam("Foam", Float) = 0
		[Toggle(BLINN_PHONG)] _UsePhong("Blinn Phong", Float) = 0

		[Header(Basic settings)]
		_AmbientDensity("Ambient Intensity",  Range(0, 1)) = 0.15
		_DiffuseDensity("Diffuse Intensity",  Range(0, 1)) = 0.1
		_SurfaceColor("Surface Color", Color) = (0.0078, 0.5176, 0.7)
		_ShoreColor("Shore Tint Color", Color) = (0.0078, 0.5176, 0.7)
		_DepthColor("Deep Color", Color) = (0.0039, 0.00196, 0.145)
		[NoScaleOffset]_SkyTexture("Sky Texture", Cube) = "white" {}
		[NoScaleOffset]_NormalTexture("Normal Texture", 2D) = "white" {}
		_NormalIntensity("Normal Intensity",  Range(0, 1)) = 0.5
		_TextureTiling("Texture Tiling", Float) = 1
		_WindDirection("Wind Direction", Vector) = (3,5,0)

		[Header(Displacement settings)]
		[NoScaleOffset]_HeightTexture("Height Texture", 2D) = "white" {}
		_HeightIntensity("Height Intensity",  Range(0, 1)) = 0.5
		_WaveTiling("Wave Tiling", Float) = 1
		_WaveAmplitudeFactor("Wave Amplitude Factor",Float) = 1.0
		_WaveSteepness("Wave Steepness", Range(0, 1)) = 0.5
		_WaveAmplitude("Waves Amplitude", Vector) = (0.05, 0.1, 0.2, 0.3)
		_WavesIntensity("Waves Intensity", Vector) = (3, 2, 2, 10)
		_WavesNoise("Waves Noise", Vector) = (0.05, 0.15, 0.03, 0.05)

		[Header(Refraction settings)]
		_WaterClarity("Water Clarity",  Range(0, 3)) = 0.75
		_WaterTransparency("Water Transparency",  Range(0, 30)) = 10.0
		_HorizontalExtinction("Horizontal Extinction", Vector) = (3.0, 10.0, 12.0)
		_RefractionValues("Refraction/Reflection", Vector) = (0.3, 0.01, 1.0)
		_RefractionScale("Refraction Scale",  Range(0, 0.03)) = 0.005

		[Header(Reflection settings)]
		_Shininess("Shininess",  Range(0, 3)) = 0.5
		_SpecularValues("Specular Intensity", Vector) = (12, 768, 0.15)
		_Distortion("Distortion", Range(0, 0.15)) = 0.05
		_RadianceFactor("Radiance Factor", Range(0, 1.0)) = 1.0
		[HideInInspector]_ReflectionTexture("Reflection Texture", 2D) = "white" {}

		[Header(Foam settings)]
		[NoScaleOffset]_FoamTexture("Foam Texture", 2D) = "white" {}
		[NoScaleOffset]_ShoreTexture("Shore Texture", 2D) = "white" {}
		_FoamTiling("Foam Tiling", Vector) = (2.0, 0.5, 0.0)
		_FoamRanges("Foam Ranges", Vector) = (2.0, 3.0, 100.0)
		_FoamNoise("Foam Noise", Vector) = (0.1, 0.3, 0.1, 0.3)
		_FoamSpeed("Foam Speed", Float) = 10
		_FoamIntensity("Foam Intensity", Range(0, 1)) = 0.5
		_ShoreFade("Shore Fade",  Range(0.1, 3)) = 0.3
	}
		SubShader{
		Tags{
		"IgnoreProjector" = "True"
		"Queue" = "Transparent"
		"RenderType" = "Transparent"
		}
		GrabPass{ "_RefractionTexture" }
		Pass{
		Name "Base"
		Tags{ "LightMode" = "ForwardBase" }
		Blend SrcAlpha OneMinusSrcAlpha
		Cull False
		ZWrite True

		CGPROGRAM
		#pragma vertex vert
		#pragma fragment frag
		#include "UnityCG.cginc"
		#include "conversion.cginc"
		#include "hlsl/snoise.cginc"
		#include "hlsl/bicubic.cginc"
		#include "hlsl/normals.cginc"
		#include "hlsl/water/displacement.cginc"
		#include "hlsl/water/meansky.cginc"
		#include "hlsl/water/radiance.cginc"
		#include "hlsl/water/depth.cginc"
		#include "hlsl/water/foam.cginc"
		#pragma multi_compile_fog
		#pragma shader_feature USE_DISPLACEMENT
		#pragma shader_feature USE_MEAN_SKY_RADIANCE
		#pragma shader_feature USE_FILTERING
		#pragma shader_feature USE_FOAM
		#pragma shader_feature BLINN_PHONG
		#pragma exclude_renderers d3d11_9x 
		#pragma target 3.0

		uniform sampler2D _CameraDepthTexture;
		uniform sampler2D _HeightTexture;
		uniform sampler2D _NormalTexture;
		uniform sampler2D _FoamTexture;
		uniform sampler2D _ShoreTexture;
		uniform sampler2D _ReflectionTexture; uniform float4 _ReflectionTexture_TexelSize;
		uniform samplerCUBE _SkyTexture;
		uniform sampler2D _RefractionTexture;

		uniform float4x4 _ViewProjectInverse;

		uniform float4 _TimeEditor;
		uniform float _AmbientDensity;
		uniform float _DiffuseDensity;
		uniform float _HeightIntensity;
		uniform float _NormalIntensity;
		uniform float _TextureTiling;

		uniform float4 _LightColor0;
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
			UNITY_FOG_COORDS(8)
		};

		VertexOutput vert(VertexInput v)
		{
			VertexOutput o = (VertexOutput)0;

			float2 windDir = _WindDirection;
			float windSpeed = length(_WindDirection);
			windDir /= windSpeed;
			float timer = (_Time + _TimeEditor) * windSpeed * 10;

			float4 modelPos = v.vertex;
			float3 worldPos = mul(unity_ObjectToWorld, float4(modelPos.xyz, 1));
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

			modelPos = mul(unity_WorldToObject, float4(worldPos, 1));
			o.tangent = tangent;
			o.bitangent = cross(normal, tangent);
#endif
			float2 uv = worldPos.xz;

			o.timer = timer;
			o.wind.xy = windDir;
			o.wind.zw = windDir * timer;

			o.uv = uv  * 0.05 * _TextureTiling;
			o.pos = UnityObjectToClipPos(modelPos);
			o.worldPos = worldPos;
			o.projPos = ComputeScreenPos(o.pos);
			o.normal = normal;

			UNITY_TRANSFER_FOG(o, o.pos);

			return o;
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
			float depth = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(fs_in.projPos.xyww));
			float3 depthPosition = NdcToWorldPos(_ViewProjectInverse, float3(ndcPos, depth));
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
			{
				// reverse existing applied fog for correct shore color
				INVERSE_FOG_COLOR(fs_in.fogCoord, pureRefractionColor);
			}
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
			half3 ambientColor = UNITY_LIGHTMODEL_AMBIENT.rgb * _AmbientDensity + saturate(dot(normal, lightDir)) * _DiffuseDensity;
			// refraction color with depth based color
			pureRefractionColor = lerp(pureRefractionColor, reflectColor, fresnel * saturate(waterDepth / (_FoamRanges.x * 0.4)));
			pureRefractionColor = lerp(pureRefractionColor, _ShoreColor, 0.30 * shoreFade);
			// compute final color
			half3 color = lerp(refractionColor, reflectColor, fresnel);
			color = saturate(ambientColor + color + max(specularColor, foam * lightColor));
			color = lerp(pureRefractionColor + specularColor * shoreFade, color, shoreFade);
			UNITY_APPLY_FOG(fs_in.fogCoord, color);

#ifdef DEBUG_NORMALS
			color.rgb = 0.5 + 2 * ambientColor + specularColor + clamp(dot(normal, lightDir), 0, 1) * 0.5;
#endif

			return float4(color, 1.0);
		}
		ENDCG
		}
		}
			CustomEditor "WaterShaderGUI"
			FallBack "Diffuse"
}

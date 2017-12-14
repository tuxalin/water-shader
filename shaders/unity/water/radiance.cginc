//
// Description : Reflected water radiance
//

// refractionValues, x = index of refraction constant, y = refraction strength
// normal and eyeVec in world space
half FresnelValue(float2 refractionValues, float3 normal, float3 eyeVec)
{
	// R0 is a constant related to the index of refraction (IOR).
	float R0 = refractionValues.x;
	// This value modifies current fresnel term. If you want to weaken
	// reflections use bigger value.
	float refractionStrength = refractionValues.y;
#ifdef SIMPLIFIED_FRESNEL
	return R0 + (1.0f - R0) * pow(1.0f - dot(eyeVec, normal), 5.0f);
#else		
	float angle = 1.0f - saturate(dot(normal, eyeVec));
	float fresnel = angle * angle;
	fresnel *= fresnel;
	fresnel *= angle;
	return saturate(fresnel * (1.0f - saturate(R0)) + R0 - refractionStrength);
#endif // #ifdef SIMPLIFIED_FRESNEL
}

// lightDir, eyeDir and normal in world space
half3 ReflectedRadiance(float shininess, half3 specularValues, half3 lightColor, float3 lightDir, float3 eyeDir, float3 normal, float fresnel)
{
	float shininessExp = specularValues.z;

#ifdef BLINN_PHONG
	// a variant of the blinn phong shading
	float specularIntensity = specularValues.x * 0.0075;

	float3 H = normalize(eyeDir + lightDir);
	float e = shininess * shininessExp * 800;
	float kS = saturate(dot(normal, lightDir));
	half3 specular = kS * specularIntensity * pow(saturate(dot(normal, H)), e) * sqrt((e + 1) / 2);
	specular *= lightColor;
#else
	float2 specularIntensity = specularValues.xy;
	// reflect the eye vector such that the incident and emergent angles are equal
	float3 mirrorEye = reflect(-eyeDir, normal);
	half dotSpec = saturate(dot(mirrorEye, lightDir) * 0.5f + 0.5f);
	half3 specular = (1.0f - fresnel) * saturate(lightDir.y) * pow(dotSpec, specularIntensity.y) * (shininess * shininessExp + 0.2f) * lightColor;
	specular += specular * specularIntensity.x * saturate(shininess - 0.05f) * lightColor;
#endif // #ifdef BLINN_PHONG
	return specular;
}

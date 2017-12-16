
float3 UnpackNormal(float4 n) 
{
    n.xyz = n.xyz * 2.0 - 1.0;
    return n.xyz;
}

float3 UnpackNormalRecZ(float4 packednormal) 
{
	float3 normal;
    normal.xy = packednormal.wy * 2 - 1;
    normal.z = sqrt(1 - normal.x*normal.x - normal.y * normal.y);
    return normal;
}

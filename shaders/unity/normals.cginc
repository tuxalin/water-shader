//
// Description : Utilties for normal mapping
//

// Project the surface gradient (dhdx, dhdy) onto the surface (n, dpdx, dpdy).
float3  ComputeSurfaceGradient(float3 n, float3 dpdx, float3 dpdy, float dhdx, float dhdy)
{
	float3 r1 = cross(dpdy, n);
	float3 r2 = cross(n, dpdx);

	return (r1 * dhdx + r2 * dhdy) / dot(dpdx, r1);
}

// Move the normal away from the surface normal in the opposite surface gradient direction.
float3 PerturbNormal(float3 n, float3 dpdx, float3 dpdy, float dhdx, float dhdy)
{
	return normalize(n - ComputeSurfaceGradient(n, dpdx, dpdy, dhdx, dhdy));
}

// Returns the surface normal using screen-space partial derivatives of the height field.
float3 ComputeSurfaceNormal(float3 position, float3 normal, float height)
{
	float3 dpdx = ddx(position);
	float3 dpdy = ddy(position);

	float dhdx = ddx(height);
	float dhdy = ddy(height);

	return PerturbNormal(normal, dpdx, dpdy, dhdx, dhdy);
}

float ApplyChainRule(float dhdu, float dhdv, float dud_, float dvd_)
{
	return dhdu * dud_ + dhdv * dvd_;
}

// Calculate the surface normal using the uv-space gradient (dhdu, dhdv)
// Requires height field gradient, double storage.
float3 CalculateSurfaceNormal(float3 position, float3 normal, float2 gradient, float2 duvdx, float2 duvdy)
{
	float3 dpdx = ddx(position);
	float3 dpdy = ddy(position);

	float dhdx = ApplyChainRule(gradient.x, gradient.y, duvdx.x, duvdx.y);
	float dhdy = ApplyChainRule(gradient.x, gradient.y, duvdy.x, duvdy.y);

	return PerturbNormal(normal, dpdx, dpdy, dhdx, dhdy);
}

// Returns the surface normal using screen-space partial derivatives of world position.
// Will result in hard shading normals.
float3 ComputeSurfaceNormal(float3 position)
{
	return normalize(cross(ddx(position), ddy(position)));
}

// portability reasons
float3 mul2x3(float2 val, float3 row1, float3 row2)
{
	float3 res;
	for (int i = 0; i < 3; i++)
	{
		float2 col = float2(row1[i], row2[i]);
		res[i] = dot(val, col);
	}

	return res;
}

float3 ComputeSurfaceNormal(float3 normal, float3 tangent, float3 bitangent, sampler2D tex, float2 uv)
{
	float3x3 tangentFrame = float3x3(normalize(bitangent), normalize(tangent), normal);

#ifndef USE_FILTERING
	normal = UnpackNormal(tex2D(tex, uv));
#else
	float2 duv1 = ddx(uv) * 2;
	float2 duv2 = ddy(uv) * 2;
	normal = UnpackNormal(tex2Dgrad(tex, uv, duv1, duv2));
#endif
	return normalize(mul(normal, tangentFrame));
}

float3x3 ComputeTangentFrame(float3 normal, float3 position, float2 uv)
{
	float3 dp1 = ddx(position);
	float3 dp2 = ddy(position);
	float2 duv1 = ddx(uv);
	float2 duv2 = ddy(uv);

	float3x3 M = float3x3(dp1, dp2, cross(dp1, dp2));
	float3 inverseM1 = float3(cross(M[1], M[2]));
	float3 inverseM2 = float3(cross(M[2], M[0]));
	float3 T = mul2x3(float2(duv1.x, duv2.x), inverseM1, inverseM2);
	float3 B = mul2x3(float2(duv1.y, duv2.y), inverseM1, inverseM2);

	return float3x3(normalize(T), normalize(B), normal);
}

// Returns the surface normal using screen-space partial derivatives of the uv and position coordinates.
float3 ComputeSurfaceNormal(float3 normal, float3 position, sampler2D tex, float2 uv)
{
	float3x3 tangentFrame = ComputeTangentFrame(normal, position, uv);

#ifndef USE_FILTERING
	normal = UnpackNormal(tex2D(tex, uv));
#else
	float2 duv1 = ddx(uv) * 2;
	float2 duv2 = ddy(uv) * 2;
	normal = UnpackNormal(tex2Dgrad(tex, uv, duv1, duv2));
#endif
	return normalize(mul(normal, tangentFrame));
}

float3 ComputeNormal(float4 heights, float strength)
{
	float hL = heights.x;
	float hR = heights.y;
	float hD = heights.z;
	float hT = heights.w;

	float3 normal = float3(hL - hR, strength, hD - hT);
	return normalize(normal);
}

float3 ComputeNormal(sampler2D tex, float2 uv, float texelSize, float strength)
{
	float3 off = float3(texelSize, texelSize, 0.0);
	float4 heights;
	heights.x = tex2D(tex, uv.xy - off.xz); // hL
	heights.y = tex2D(tex, uv.xy + off.xz); // hR
	heights.z = tex2D(tex, uv.xy - off.zy); // hD
	heights.w = tex2D(tex, uv.xy + off.zy); // hT

	return ComputeNormal(heights, strength);
}

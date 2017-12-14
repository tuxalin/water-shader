//
// Description : Bicubic filtering functions
//

float4 cubic(float v)
{
	float4 n = float4(1.0, 2.0, 3.0, 4.0) - v;
	float4 s = n * n * n;
	float x = s.x;
	float y = s.y - 4.0 * s.x;
	float z = s.z - 4.0 * s.y + 6.0 * s.x;
	float w = 6.0 - x - y - z;
	return float4(x, y, z, w) * (1.0 / 6.0);
}

// 4 taps bicubic filtering, requires sampler to use bilinear filtering
float4 tex2DBicubic(sampler2D tex, float texSize, float2 texCoords)
{
	float2 texSize2 = texSize;
	float2 invTexSize = 1.0 / texSize2;

	texCoords = texCoords * texSize2 - 0.5;
	float2 fxy = frac(texCoords);
	texCoords -= fxy;

	float4 xcubic = cubic(fxy.x);
	float4 ycubic = cubic(fxy.y);

	float4 c = texCoords.xxyy + float2(-0.5, +1.5).xyxy;

	float4 s = float4(xcubic.xz + xcubic.yw, ycubic.xz + ycubic.yw);
	float4 offset = c + float4(xcubic.yw, ycubic.yw) / s;

	offset *= invTexSize.xxyy;

	float4 sample0 = tex2D(tex, offset.xz);
	float4 sample1 = tex2D(tex, offset.yz);
	float4 sample2 = tex2D(tex, offset.xw);
	float4 sample3 = tex2D(tex, offset.yw);

	float sx = s.x / (s.x + s.y);
	float sy = s.z / (s.z + s.w);

	return lerp(lerp(sample3, sample2, sx), lerp(sample1, sample0, sx), sy);
}



//RasterizerState wireframe
//{
//	CullMode = Back;
//	FillMode = wireframe;
//};

SamplerState linearSampler
{
	Filter = MIN_MAG_MIP_LINEAR;
	AddressU = Wrap;
	AddressV = Wrap;

};

Texture2D terrainHeightMap;
float sizeTerrain;
float heightMultiplier;
float minDistance;
float maxDistance;
float minTessExp;
float maxTessExp;
int   sqrtNumPatch;


cbuffer cbPerObject
{
	float4x4 gWorldViewProj;
	float3 eyePosition;
};

struct VertexIn
{
	float3 Pos   : POSITION;
	float4 Color : COLOR;
};

struct VSOut
{
	float3 PosH  : POSITION;
	float3 vVec0 : VECTOR0;
	float3 vVec1 : VECTOR1;
	float3 vVec2 : VECTOR2;
	float3 vVec3 : VECTOR3;
};

VSOut VS(VertexIn vin)
{
	VSOut vout;


	/*float2 coord = float2(vin.Pos.x / sizeTerrain, vin.Pos.z / sizeTerrain);
	float height = terrainHeightMap.SampleLevel(linearSampler, coord, 0).x * heightMultiplier;
	float3 pos = float3(vin.Pos.x, height, vin.Pos.z);*/

	float increment = sizeTerrain / sqrtNumPatch;
	float2 coord = float2(vin.Pos.x, vin.Pos.z);
		float2 coord0 = float2(vin.Pos.x, vin.Pos.z + increment);
		float2 coord1 = float2(vin.Pos.x + increment, vin.Pos.z);
		float2 coord2 = float2(vin.Pos.x, vin.Pos.z - increment);
		float2 coord3 = float2(vin.Pos.x - increment, vin.Pos.z);

		float height = terrainHeightMap.SampleLevel(linearSampler, coord / sizeTerrain, 0).x * heightMultiplier;
	float height0 = terrainHeightMap.SampleLevel(linearSampler, (coord0 / sizeTerrain), 0).x * heightMultiplier;
	float height1 = terrainHeightMap.SampleLevel(linearSampler, (coord1 / sizeTerrain), 0).x * heightMultiplier;
	float height2 = terrainHeightMap.SampleLevel(linearSampler, (coord2 / sizeTerrain), 0).x * heightMultiplier;
	float height3 = terrainHeightMap.SampleLevel(linearSampler, (coord3 / sizeTerrain), 0).x * heightMultiplier;

	float3 pos = float3(coord.x, height, coord.y);
		float3 pos0 = float3(coord0.x, height0, coord0.y);
		float3 pos1 = float3(coord1.x, height1, coord1.y);
		float3 pos2 = float3(coord2.x, height2, coord2.y);
		float3 pos3 = float3(coord3.x, height3, coord3.y);

		vout.vVec0 = normalize(pos0 - pos);
	vout.vVec1 = normalize(pos1 - pos);
	vout.vVec2 = normalize(pos2 - pos);
	vout.vVec3 = normalize(pos3 - pos);

	//vout.PosH = mul(float4(pos, 1.0f), gWorldViewProj);

	vout.PosH = pos;


	return vout;
}

struct HS_CONSTANT_DATA_OUTPUT
{
	float Edges[4] : SV_TessFactor;
	float Inside[2] : SV_InsideTessFactor;
	float mipLevel[4] : MIPLEVELVERTEXS;
};
struct HS_OUTPUT
{
	float3 vPosition : POSITION;
};

HS_CONSTANT_DATA_OUTPUT TerrainConstantHS(InputPatch<VSOut, 4> ip, uint PatchID : SV_PrimitiveID)
{
	HS_CONSTANT_DATA_OUTPUT Output;

	float3 middlePoint = (ip[0].PosH + ip[1].PosH + ip[2].PosH + ip[3].PosH) / 4;
		float3 middlePointEdge0 = (ip[0].PosH + ip[1].PosH) / 2;
		float3 middlePointEdge1 = (ip[3].PosH + ip[0].PosH) / 2;
		float3 middlePointEdge2 = (ip[2].PosH + ip[3].PosH) / 2;
		float3 middlePointEdge3 = (ip[1].PosH + ip[2].PosH) / 2;

		float2 correctionInside = float2(1, 1);
		float4 correctionEdges = float4(1, 1, 1, 1);
		float4 correctionVertexs = float4(1, 1, 1, 1);

		//if (applyCorrection)


		float4 magnitudeVertexs;
	magnitudeVertexs.x = clamp(distance(ip[0].PosH, eyePosition), minDistance, maxDistance);
	magnitudeVertexs.y = clamp(distance(ip[1].PosH, eyePosition), minDistance, maxDistance);
	magnitudeVertexs.z = clamp(distance(ip[2].PosH, eyePosition), minDistance, maxDistance);
	magnitudeVertexs.w = clamp(distance(ip[3].PosH, eyePosition), minDistance, maxDistance);

	float minMipmapLevel = 11 - log2(sqrtNumPatch * pow(2, maxTessExp));
	float maxMipmapLevel = 11 - log2(sqrtNumPatch * pow(2, minTessExp));
	if (minMipmapLevel < 0)
		minMipmapLevel = 0;


	float diffDistance = maxDistance - minDistance;

	float4 factorVertexs = clamp(((magnitudeVertexs - minDistance) / diffDistance)*correctionVertexs, float4(0, 0, 0, 0), float4(1, 1, 1, 1));

		//float factorX = clamp(((magnitudeVertexs.x - minDistance) / diffDistance), 0, 1);
		//float factorY = clamp(((magnitudeVertexs.y - minDistance) / diffDistance), 0, 1);
		//float factorZ = clamp(((magnitudeVertexs.z - minDistance) / diffDistance), 0, 1);
		//float factorW = clamp(((magnitudeVertexs.w - minDistance) / diffDistance), 0, 1);

		Output.mipLevel[0] = lerp(minMipmapLevel, maxMipmapLevel, factorVertexs.x);
	Output.mipLevel[1] = lerp(minMipmapLevel, maxMipmapLevel, factorVertexs.y);
	Output.mipLevel[2] = lerp(minMipmapLevel, maxMipmapLevel, factorVertexs.z);
	Output.mipLevel[3] = lerp(minMipmapLevel, maxMipmapLevel, factorVertexs.w);

	float magnitude = clamp(distance(middlePoint, eyePosition), minDistance, maxDistance);

	float4 magnitudeEdges;
	magnitudeEdges.x = clamp(distance(middlePointEdge0, eyePosition), minDistance, maxDistance);
	magnitudeEdges.y = clamp(distance(middlePointEdge1, eyePosition), minDistance, maxDistance);
	magnitudeEdges.z = clamp(distance(middlePointEdge2, eyePosition), minDistance, maxDistance);
	magnitudeEdges.w = clamp(distance(middlePointEdge3, eyePosition), minDistance, maxDistance);

	float2 factorInside = 1 - saturate(((magnitude - minDistance) / diffDistance) * correctionInside);
		float4 factorEdges = 1 - saturate(((magnitudeEdges - minDistance) / diffDistance) * correctionEdges);

		/*Output.Edges[0] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.x))));
		Output.Edges[1] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.y))));
		Output.Edges[2] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.z))));
		Output.Edges[3] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.w))));

		Output.Inside[0] = pow(2, round(lerp(minTessExp, maxTessExp, factorInside.x)));
		Output.Inside[1] = pow(2, round(lerp(minTessExp, maxTessExp, factorInside.y)));*/

		Output.Edges[0] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.x))));
	Output.Edges[1] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.y))));
	Output.Edges[2] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.z))));
	Output.Edges[3] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.w))));

	Output.Inside[0] = pow(2, round(lerp(minTessExp, maxTessExp, factorInside.x)));
	Output.Inside[1] = pow(2, round(lerp(minTessExp, maxTessExp, factorInside.y)));

	return Output;



}

[domain("quad")]
[partitioning("integer")]
[outputtopology("triangle_cw")]
[outputcontrolpoints(4)]
[patchconstantfunc("TerrainConstantHS")]

HS_OUTPUT hsTerrain(InputPatch<VSOut, 4> p, uint i : SV_OutputControlPointID, uint Patch : SV_PrimitiveID)
{
	HS_OUTPUT Output;
	Output.vPosition = p[i].PosH;
	return Output;
}

struct DS_OUTPUT
{
	float4 vPosition : SV_POSITION;
	//float3 vNormal : NORMAL;
	//float2 tex : TEXCOORD0;
};

[domain("quad")]
DS_OUTPUT dsTerrain(HS_CONSTANT_DATA_OUTPUT input, float2 UV:SV_DomainLocation, const OutputPatch<HS_OUTPUT, 4> patch)
{
	float WorldPosX = patch[0].vPosition.x + ((patch[2].vPosition.x - patch[0].vPosition.x) * UV.x);
	float WorldPosY;
	float WorldPosZ = patch[0].vPosition.z + ((patch[2].vPosition.z - patch[0].vPosition.z) * UV.y);

	float2 textCoord = float2(WorldPosX, WorldPosZ) / sizeTerrain;

		float mipLevel01 = (UV.y * input.mipLevel[1] + (1 - UV.y) * input.mipLevel[0]);
	float mipLevel32 = (UV.y * input.mipLevel[2] + (1 - UV.y) * input.mipLevel[3]);
	float mipLevel = (UV.x * mipLevel32 + (1 - UV.x) * mipLevel01);

	WorldPosY = terrainHeightMap.SampleLevel(linearSampler, textCoord, mipLevel).x * heightMultiplier;

	//float3 normal = terrainNormalMap.SampleLevel(linearSampler, textCoord, mipLevel).xyz;

	DS_OUTPUT Output;
	Output.vPosition = mul(float4(float3(WorldPosX, WorldPosY, WorldPosZ), 1), gWorldViewProj);
	//Output.vNormal = normalize(normal * 2.0f - 1.0f);
	//Output.tex = textCoord;

	return Output;


}

float4 PS(DS_OUTPUT pin) : SV_Target
{

	return float4(0.5, 0.5, 0.5, 1);
}

technique11 ColorTech
{
	pass P0
	{
		SetVertexShader(CompileShader(vs_5_0, VS()));

		SetHullShader(CompileShader(hs_5_0, hsTerrain()));
		SetDomainShader(CompileShader(ds_5_0, dsTerrain()));
		SetPixelShader(CompileShader(ps_5_0, PS()));

	}
}




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
bool applyCorrection;
Texture2D sobelMap;


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
	float4 color : COLOR;
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
		//0709///
		////distance between true point with plane of the patch
		/*float incrementIn4 = sizeTerrain / (sqrtNumPatch*4);
		float2 q0Coord = float2((ip[0].PosH.x + ip[1].PosH.x + ip[2].PosH.x + ip[3].PosH.x) / 4, (ip[0].PosH.z + ip[1].PosH.z + ip[2].PosH.z + ip[3].PosH.z) / 4);
		float2 q1Coord = float2(0.75*ip[0].PosH.x + 0.25*ip[1].PosH.x, 0.75*ip[0].PosH.z + 0.25*ip[3].PosH.z);
		float2 q2Coord = float2(0.25*ip[0].PosH.x + 0.75*ip[1].PosH.x, 0.75*ip[1].PosH.z + 0.25*ip[2].PosH.z);
		float2 q3Coord = float2(0.75*ip[3].PosH.x + 0.25*ip[2].PosH.x, 0.75*ip[3].PosH.z + 0.25*ip[0].PosH.z);
		float2 q4Coord = float2(0.25*ip[3].PosH.x + 0.75*ip[2].PosH.x, 0.75*ip[2].PosH.z + 0.25*ip[1].PosH.z);

		float planeHeitght0 = float(0.5*ip[0].PosH.y + 0.5*ip[2].PosH.y);
		float planeHeitght1 = float(0.75*ip[0].PosH.y + 0.25*ip[2].PosH.y);
		float planeHeitght4 = float(0.25*ip[0].PosH.y + 0.75*ip[2].PosH.y);
		float planeHeitght2 = float(0.75*ip[1].PosH.y + 0.25*ip[3].PosH.y);
		float planeHeitght3 = float(0.75*ip[3].PosH.y + 0.25*ip[1].PosH.y);

		float height0 = terrainHeightMap.SampleLevel(linearSampler, q0Coord / sizeTerrain, 0).x * heightMultiplier;
		float height1 = terrainHeightMap.SampleLevel(linearSampler, q1Coord / sizeTerrain, 0).x * heightMultiplier;
		float height2 = terrainHeightMap.SampleLevel(linearSampler, q2Coord / sizeTerrain, 0).x * heightMultiplier;
		float height3 = terrainHeightMap.SampleLevel(linearSampler, q3Coord / sizeTerrain, 0).x * heightMultiplier;
		float height4 = terrainHeightMap.SampleLevel(linearSampler, q4Coord / sizeTerrain, 0).x * heightMultiplier;

		float3 crossProductNormal = normalize(cross((ip[1].PosH - ip[0].PosH), (ip[3].PosH - ip[0].PosH)));

		float dis0 = abs(dot(crossProductNormal, float3(0, height0 - planeHeitght0, 0)));
		float dis1 = abs(dot(crossProductNormal, float3(0, height1 - planeHeitght1, 0)));
		float dis2 = abs(dot(crossProductNormal, float3(0, height2 - planeHeitght2, 0)));
		float dis3 = abs(dot(crossProductNormal, float3(0, height3 - planeHeitght3, 0)));
		float dis4 = abs(dot(crossProductNormal, float3(0, height4 - planeHeitght4, 0)));

		float variance = (dis0 + dis1 + dis2 + dis3 + dis4) / 5;

		float varColor = variance / (incrementIn4 );*/

		/////////

		/////0710///
		//float incrementIn2 = sizeTerrain / (sqrtNumPatch * 2);
		/*float2 q1coord = float2(0.5*ip[0].PosH.x + 0.5*ip[3].PosH.x, 0.5*ip[0].PosH.z + 0.5*ip[3].PosH.z);
		float2 q10coord = float2(ip[0].PosH.x + 0.25*(ip[0].PosH.x - ip[1].PosH.x), 0.75*ip[0].PosH.z + 0.25*ip[3].PosH.z);
		float2 q11coord = float2(ip[0].PosH.x + 0.25*(-ip[0].PosH.x + ip[1].PosH.x), 0.75*ip[0].PosH.z + 0.25*ip[3].PosH.z);
		float2 q12coord = float2(ip[0].PosH.x + 0.25*(-ip[0].PosH.x + ip[1].PosH.x), 0.25*ip[0].PosH.z + 0.75*ip[3].PosH.z);
		float2 q13coord = float2(ip[0].PosH.x + 0.25*(ip[0].PosH.x - ip[1].PosH.x), 0.25*ip[0].PosH.z + 0.75*ip[3].PosH.z);

		float q1PlaneHeight = float(0.5*ip[0].PosH.y + 0.5*ip[3].PosH.y);
		float q10PlaneHeight = float(0.75*ip[0].PosH.y + 0.25*ip[2].PosH.y);*/

	////////////
	float2 correctionInside = float2(1, 1);
	float4 correctionEdges = float4(1, 1, 1, 1);
	float4 correctionVertexs = float4(1, 1, 1, 1);

		//if Correction
		if (applyCorrection)
		{
			//

			float3 insideDirection0 = normalize(middlePointEdge0 - middlePointEdge2);
			float3 insideDirection1 = normalize(middlePointEdge1 - middlePointEdge3);
			float3 edgeDirection0 = normalize(ip[0].PosH - ip[1].PosH);
			float3 edgeDirection1 = normalize(ip[3].PosH - ip[0].PosH);
			float3 edgeDirection2 = normalize(ip[2].PosH - ip[3].PosH);
			float3 edgeDirection3 = normalize(ip[1].PosH - ip[2].PosH);

			float3 toCameraMiddle = normalize(eyePosition - middlePoint);
			float3 toCameraEdge0 = normalize(eyePosition - middlePointEdge0);
			float3 toCameraEdge1 = normalize(eyePosition - middlePointEdge1);
			float3 toCameraEdge2 = normalize(eyePosition - middlePointEdge2);
			float3 toCameraEdge3 = normalize(eyePosition - middlePointEdge3);

			float rank = 0.4;
			float shift = 1 - rank / 2;
			correctionInside.x = ((1.57 - acos(abs(dot(toCameraMiddle, insideDirection0)))) / 1.57) * rank + shift;
			correctionInside.y = ((1.57 - acos(abs(dot(toCameraMiddle, insideDirection1)))) / 1.57) * rank + shift;

			correctionEdges.x = ((1.57 - acos(abs((dot(toCameraEdge0, edgeDirection0))))) / 1.57) * rank + shift;
			correctionEdges.y = ((1.57 - acos(abs((dot(toCameraEdge1, edgeDirection1))))) / 1.57) * rank + shift;
			correctionEdges.z = ((1.57 - acos(abs((dot(toCameraEdge2, edgeDirection2))))) / 1.57) * rank + shift;
			correctionEdges.w = ((1.57 - acos(abs((dot(toCameraEdge3, edgeDirection3))))) / 1.57) * rank + shift;

			float3 toCameraVertex0 = normalize(eyePosition - ip[0].PosH);
			float3 toCameraVertex1 = normalize(eyePosition - ip[1].PosH);
			float3 toCameraVertex2 = normalize(eyePosition - ip[2].PosH);
			float3 toCameraVertex3 = normalize(eyePosition - ip[3].PosH);

			float angle0 = (acos(abs(dot(toCameraVertex0, ip[0].vVec0))) + acos(abs(dot(toCameraVertex0, ip[0].vVec1))) + acos(abs(dot(toCameraVertex0, ip[0].vVec2))) + acos(abs(dot(toCameraVertex0, ip[0].vVec3)))) / 4;
			float angle1 = (acos(abs(dot(toCameraVertex1, ip[1].vVec0))) + acos(abs(dot(toCameraVertex1, ip[1].vVec1))) + acos(abs(dot(toCameraVertex1, ip[1].vVec2))) + acos(abs(dot(toCameraVertex1, ip[1].vVec3)))) / 4;
			float angle2 = (acos(abs(dot(toCameraVertex2, ip[2].vVec0))) + acos(abs(dot(toCameraVertex2, ip[2].vVec1))) + acos(abs(dot(toCameraVertex2, ip[2].vVec2))) + acos(abs(dot(toCameraVertex2, ip[2].vVec3)))) / 4;
			float angle3 = (acos(abs(dot(toCameraVertex3, ip[3].vVec0))) + acos(abs(dot(toCameraVertex3, ip[3].vVec1))) + acos(abs(dot(toCameraVertex3, ip[3].vVec2))) + acos(abs(dot(toCameraVertex3, ip[3].vVec3)))) / 4;

			correctionVertexs.x = (1 - ((1.57 - angle0) / 1.57)) * rank + shift;
			correctionVertexs.y = (1 - ((1.57 - angle1) / 1.57)) * rank + shift;
			correctionVertexs.z = (1 - ((1.57 - angle2) / 1.57)) * rank + shift;
			correctionVertexs.w = (1 - ((1.57 - angle3) / 1.57)) * rank + shift;

		}


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

	////////////0715//////////////sobel
		//float2 samplecoordSobel = float2((ip[0].PosH.x, ip[0].PosH.z) / (sizeTerrain-1));
		
		float sobelPerPatch = sobelMap.SampleLevel(linearSampler, float2(ip[0].PosH.x, ip[0].PosH.z) / (sizeTerrain - 1), 0).x;

	float3 point003 = ip[0].PosH + (ip[0].PosH - ip[3].PosH);
		float3 point001 = ip[0].PosH + (ip[0].PosH - ip[1].PosH);

		float sobelPoint003 = sobelMap.SampleLevel(linearSampler, float2(point003.x, point003.z) / (sizeTerrain - 1), 0).x;
	float sobelPoint1 = sobelMap.SampleLevel(linearSampler, float2(ip[1].PosH.x, ip[1].PosH.z) / (sizeTerrain - 1), 0).x;
	float sobelPoint3 = sobelMap.SampleLevel(linearSampler, float2(ip[3].PosH.x, ip[3].PosH.z) / (sizeTerrain - 1), 0).x;
	float sobelPoint001 = sobelMap.SampleLevel(linearSampler, float2(point001.x, point001.z) / (sizeTerrain - 1), 0).x;

	float4 edgeSobel = float4((sobelPoint003 + sobelPerPatch) / 2, (sobelPoint001 + sobelPerPatch) / 2, (sobelPoint3 + sobelPerPatch) / 2, (sobelPoint1 + sobelPerPatch) / 2);

		float4 factorClampEdgeSobel = clamp(edgeSobel, float4(1, 1, 1, 1), float4(10, 10, 10, 10)) / 10;
		float factorClampSobelPerPatch = clamp(sobelPerPatch, float(1), float(10)) / 10;

		int addx = int(0);
	int addy = int(0);
	int addz = int(0);
	int addw = int(0);
	int addInside = int(0);
	int factorAdd = int(1);
	int factorViewRange = int(4);
	float factorSobelRange = float(0.6);
	if (round(lerp(minTessExp, maxTessExp, (factorEdges.x)))<factorViewRange && factorClampEdgeSobel.x>factorSobelRange)
		{
			addx = factorAdd;
		}
	if (round(lerp(minTessExp, maxTessExp, (factorEdges.y)))<factorViewRange && factorClampEdgeSobel.y>factorSobelRange)
	{
		addy = factorAdd;
	}
	if (round(lerp(minTessExp, maxTessExp, (factorEdges.z)))<factorViewRange && factorClampEdgeSobel.z>factorSobelRange)
	{
		addz = factorAdd;
	}
	if (round(lerp(minTessExp, maxTessExp, (factorEdges.w)))<factorViewRange && factorClampEdgeSobel.w>factorSobelRange)
	{
		addw = factorAdd;
	}
	if (round(lerp(minTessExp, maxTessExp, factorInside.x)) < factorViewRange && factorClampSobelPerPatch > factorSobelRange)
	{
		addInside = factorAdd;
	}



	/////////////////////////

	Output.Edges[0] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.x)))+addx);
	Output.Edges[1] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.y)))+addy);
	Output.Edges[2] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.z)))+addz);
	Output.Edges[3] = pow(2, round(lerp(minTessExp, maxTessExp, (factorEdges.w)))+addw);

	Output.Inside[0] = pow(2, round(lerp(minTessExp, maxTessExp, factorInside.x)) + addInside);
	Output.Inside[1] = pow(2, round(lerp(minTessExp, maxTessExp, factorInside.y)) + addInside);
	///ADD KK///
	//float averageFactor = (round(lerp(minTessExp, maxTessExp, (factorEdges.x))) + round(lerp(minTessExp, maxTessExp, (factorEdges.y))) + round(lerp(minTessExp, maxTessExp, (factorEdges.z))) + round(lerp(minTessExp, maxTessExp, (factorEdges.w))))/4;
	//float averageFactor = round(lerp(minTessExp, maxTessExp, (factorEdges.x)));
	float averageFactor = round(lerp(minTessExp, maxTessExp, factorInside.x)) + addInside;
	float4 color = float4(0, 0, 0, 0);
		if (averageFactor == 6)
		{
		color = float4(0.862745, 0.078431, 0.235294, 1);
		}
		if (averageFactor == 5)
		{
		color = float4(0.78039, 0.08235, 0.521568, 1);
		}
		if (averageFactor == 4)
		{
		color = float4(1, 0, 1, 1);
		}
		if (averageFactor == 3)
		{
		color = float4(0.580392, 0, 0.827450, 1);
		}
		if (averageFactor == 2)
		{
		color = float4(0.482352, 0.407843, 0.933333, 1);
		}
		if (averageFactor < 2)
		{
		color = float4(0.415686, 0.352941, 0.80392156, 1);
		}
		//color = float4(varColor, varColor, varColor, 1);
	Output.color = color;
	////////////

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
	float4 ds_color : COLOR;
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
	Output.ds_color = input.color;
	return Output;


}

float4 PS(DS_OUTPUT pin) : SV_Target
{

	/*return float4(0.5, 0.5, 0.5, 1);*/
	return pin.ds_color;
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




#include "d3dApp.h"
#include "d3dx11Effect.h"
#include "GeometryGenerator.h"
#include "MathHelper.h"
#include "d3dUtil.h"
#include "Camera.h"

struct HeightMapInfo
{
	std::wstring HeightMapFileName;
	float HeightScale;
	UINT HeightmapWidth;
	UINT HeightmapHeight;
	float CellSpacing;
};

struct Vertex
{
	XMFLOAT3 Pos;
	XMFLOAT4 Color;
};

class TerrainApp : public D3DApp
{
public:
	TerrainApp(HINSTANCE hInstance);
	~TerrainApp();

	bool Init();
	void OnResize();
	void UpdateScene(float dt);
	void DrawScene();

	void OnMouseDown(WPARAM btnState, int x, int y);
	void OnMouseUp(WPARAM btnState, int x, int y);
	void OnMouseMove(WPARAM btnState, int x, int y);

private:
	void BuildGeometryBuffers();
	void BuildFX();
	void BuildVertexLayout();

public://0705 add
	void LoadHeightMap();
	HeightMapInfo mHeightMapInfo;
	std::vector<float> mHeightmap;
	UINT mNumPatchVertices;
	UINT mNumPatchQuadFaces;
	UINT mNumPatchVertRows;
	UINT mNumPatchVertCols;
	static const int CellNumPerRowOfPatch = 64;

	void BuildHeightMapSRV();
	ID3D11ShaderResourceView* mHeightMapResourceView;
	ID3DX11EffectShaderResourceVariable* mHeightMapEffectVar;
	ID3DX11EffectVectorVariable* mEyePosition;//float3
	ID3DX11EffectScalarVariable* mWidthHightMap;//float
	ID3DX11EffectScalarVariable* mHightScale;
	ID3DX11EffectScalarVariable* mMinDistance;
	ID3DX11EffectScalarVariable* mMaxDistance;
	ID3DX11EffectScalarVariable* mMinTesselltion;
	ID3DX11EffectScalarVariable* mMaxTesselltion;
	ID3DX11EffectScalarVariable* mIsApplyCorrect;//bool
	ID3DX11EffectScalarVariable* mSqrtNumPatch;//int
	ID3DX11EffectScalarVariable* mTextSize;//int

	XMFLOAT3 mTempEyePosition;


	//0706
	Camera mCam;


private:
	ID3D11Buffer* mVB;
	ID3D11Buffer* mIB;

	ID3DX11Effect* mFX;
	ID3DX11EffectTechnique* mTech;
	ID3DX11EffectMatrixVariable* mfxWorldViewProj;

	ID3D11InputLayout* mInputLayout;

	ID3D11RasterizerState* mWireframeRS;

	// Define transformations from local spaces to world space.
	XMFLOAT4X4 mSkullWorld;

	UINT mSkullIndexCount;

	XMFLOAT4X4 mView;
	XMFLOAT4X4 mProj;

	float mTheta;
	float mPhi;
	float mRadius;

	POINT mLastMousePos;
};

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE prevInstance,
	PSTR cmdLine, int showCmd)
{
	// Enable run-time memory check for debug builds.
#if defined(DEBUG) | defined(_DEBUG)
	_CrtSetDbgFlag(_CRTDBG_ALLOC_MEM_DF | _CRTDBG_LEAK_CHECK_DF);
#endif

	TerrainApp theApp(hInstance);

	if (!theApp.Init())
		return 0;

	return theApp.Run();
}


TerrainApp::TerrainApp(HINSTANCE hInstance)
	: D3DApp(hInstance), mVB(0), mIB(0), mFX(0), mTech(0),
	mfxWorldViewProj(0), mInputLayout(0), mWireframeRS(0), mSkullIndexCount(0),
	mTheta(1.5f*MathHelper::Pi), mPhi(0.1f*MathHelper::Pi), mRadius(20.0f)
{
	mMainWndCaption = L"Terrain Demo";

	mLastMousePos.x = 0;
	mLastMousePos.y = 0;

	XMMATRIX I = XMMatrixIdentity();
	XMStoreFloat4x4(&mView, I);
	XMStoreFloat4x4(&mProj, I);

	XMMATRIX T = XMMatrixTranslation(0.0f, -10.0f, 0.0f);
	XMStoreFloat4x4(&mSkullWorld, T);
	///////////////

	mHeightMapInfo.HeightMapFileName = L"Textures/terrain.raw";
	mHeightMapInfo.HeightmapHeight = 2049;
	mHeightMapInfo.HeightmapWidth = 2049;
	mHeightMapInfo.HeightScale = 50.0f;
	mHeightMapInfo.CellSpacing = 1.0f;
	mNumPatchVertRows = ((mHeightMapInfo.HeightmapHeight - 1) / CellNumPerRowOfPatch) + 1;
	mNumPatchVertCols = ((mHeightMapInfo.HeightmapWidth - 1) / CellNumPerRowOfPatch) + 1;
	mNumPatchVertices = mNumPatchVertCols * mNumPatchVertRows;
	mNumPatchQuadFaces = (mNumPatchVertRows - 1) * (mNumPatchVertCols - 1);

	//0706
	mCam.SetPosition(0, 20, 0);
}

TerrainApp::~TerrainApp()
{
	ReleaseCOM(mVB);
	ReleaseCOM(mIB);
	ReleaseCOM(mFX);
	ReleaseCOM(mInputLayout);
	ReleaseCOM(mWireframeRS);
}

bool TerrainApp::Init()
{
	if (!D3DApp::Init())
		return false;

	LoadHeightMap();
	BuildHeightMapSRV();
	BuildGeometryBuffers();
	BuildFX();
	BuildVertexLayout();

	D3D11_RASTERIZER_DESC wireframeDesc;
	ZeroMemory(&wireframeDesc, sizeof(D3D11_RASTERIZER_DESC));
	wireframeDesc.FillMode = D3D11_FILL_WIREFRAME;
	wireframeDesc.CullMode = D3D11_CULL_NONE;
	wireframeDesc.FrontCounterClockwise = false;
	wireframeDesc.DepthClipEnable = true;

	HR(md3dDevice->CreateRasterizerState(&wireframeDesc, &mWireframeRS));

	return true;
}

void TerrainApp::OnResize()
{
	D3DApp::OnResize();

	/*XMMATRIX P = XMMatrixPerspectiveFovLH(0.25f*MathHelper::Pi, AspectRatio(), 1.0f, 1000.0f);
	XMStoreFloat4x4(&mProj, P);*/

	mCam.SetLens(0.25f*MathHelper::Pi, AspectRatio(), 1.0f, 3000.0f);
}

void TerrainApp::UpdateScene(float dt)
{
	// Convert Spherical to Cartesian coordinates.
	//float x = mRadius*sinf(mPhi)*cosf(mTheta);
	//float z = mRadius*sinf(mPhi)*sinf(mTheta);
	//float y = mRadius*cosf(mPhi);

	//// Build the view matrix.
	//XMVECTOR pos    = XMVectorSet(x, y, z, 1.0f);
	//XMVECTOR target = XMVectorZero();
	//XMVECTOR up     = XMVectorSet(0.0f, 1.0f, 0.0f, 0.0f);

	//mTempEyePosition = XMFLOAT3(x, y, z);

	//XMMATRIX V = XMMatrixLookAtLH(pos, target, up);
	//XMStoreFloat4x4(&mView, V);

	if (GetAsyncKeyState('W') & 0x8000)
		mCam.Walk(100.0f*dt);

	if (GetAsyncKeyState('S') & 0x8000)
		mCam.Walk(-100.0f*dt);

	if (GetAsyncKeyState('A') & 0x8000)
		mCam.Strafe(-100.0f*dt);

	if (GetAsyncKeyState('D') & 0x8000)
		mCam.Strafe(100.0f*dt);

	mCam.UpdateViewMatrix();
}

void TerrainApp::DrawScene()
{
	md3dImmediateContext->ClearRenderTargetView(mRenderTargetView, reinterpret_cast<const float*>(&Colors::LightSteelBlue));
	md3dImmediateContext->ClearDepthStencilView(mDepthStencilView, D3D11_CLEAR_DEPTH | D3D11_CLEAR_STENCIL, 1.0f, 0);

	md3dImmediateContext->IASetInputLayout(mInputLayout);
	md3dImmediateContext->IASetPrimitiveTopology(D3D11_PRIMITIVE_TOPOLOGY_4_CONTROL_POINT_PATCHLIST);

	md3dImmediateContext->RSSetState(mWireframeRS);

	UINT stride = sizeof(Vertex);
	UINT offset = 0;
	md3dImmediateContext->IASetVertexBuffers(0, 1, &mVB, &stride, &offset);
	md3dImmediateContext->IASetIndexBuffer(mIB, DXGI_FORMAT_R32_UINT, 0);

	// Set constants

	/*XMMATRIX view  = XMLoadFloat4x4(&mView);
	XMMATRIX proj  = XMLoadFloat4x4(&mProj);
	XMMATRIX world = XMLoadFloat4x4(&mSkullWorld);
	XMMATRIX worldViewProj = world*view*proj;*/

	XMMATRIX viewProj = mCam.ViewProj();
	XMMATRIX world = XMLoadFloat4x4(&mSkullWorld);
	//XMMATRIX worldInvTranspose = MathHelper::InverseTranspose(world);
	XMMATRIX worldViewProj = world*viewProj;

	mfxWorldViewProj->SetMatrix(reinterpret_cast<float*>(&worldViewProj));

	mHeightMapEffectVar->SetResource(mHeightMapResourceView);
	mEyePosition->SetRawValue(&mCam.GetPosition(), 0, sizeof(XMFLOAT3));
	mWidthHightMap->SetFloat(mHeightMapInfo.HeightmapWidth);
	mHightScale->SetFloat(mHeightMapInfo.HeightScale);
	mMinDistance->SetFloat(300);
	mMaxDistance->SetFloat(1000);
	mMinTesselltion->SetFloat(1);
	mMaxTesselltion->SetFloat(6);
	mSqrtNumPatch->SetInt(mNumPatchVertRows - 1);


	D3DX11_TECHNIQUE_DESC techDesc;
	mTech->GetDesc(&techDesc);
	for (UINT p = 0; p < techDesc.Passes; ++p)
	{
		mTech->GetPassByIndex(p)->Apply(0, md3dImmediateContext);
		md3dImmediateContext->DrawIndexed(mSkullIndexCount, 0, 0);
	}

	HR(mSwapChain->Present(0, 0));
}

void TerrainApp::OnMouseDown(WPARAM btnState, int x, int y)
{
	mLastMousePos.x = x;
	mLastMousePos.y = y;

	SetCapture(mhMainWnd);
}

void TerrainApp::OnMouseUp(WPARAM btnState, int x, int y)
{
	ReleaseCapture();
}

void TerrainApp::OnMouseMove(WPARAM btnState, int x, int y)
{
	if ((btnState & MK_LBUTTON) != 0)
	{
		// Make each pixel correspond to a quarter of a degree.
		float dx = XMConvertToRadians(0.25f*static_cast<float>(x - mLastMousePos.x));
		float dy = XMConvertToRadians(0.25f*static_cast<float>(y - mLastMousePos.y));

		// Update angles based on input to orbit camera around box.
		/*mTheta += dx;
		mPhi   += dy;*/
		mCam.Pitch(dy);
		mCam.RotateY(dx);

		// Restrict the angle mPhi.
		mPhi = MathHelper::Clamp(mPhi, 0.1f, MathHelper::Pi - 0.1f);
	}
	else if ((btnState & MK_RBUTTON) != 0)
	{
		// Make each pixel correspond to 0.2 unit in the scene.
		//float dx = 0.05f*static_cast<float>(x - mLastMousePos.x);
		//float dy = 0.05f*static_cast<float>(y - mLastMousePos.y);

		//// Update the camera radius based on input.
		//mRadius += dx - dy;

		//// Restrict the radius.
		//mRadius = MathHelper::Clamp(mRadius, 5.0f, 50.0f);
	}

	mLastMousePos.x = x;
	mLastMousePos.y = y;
}

void TerrainApp::BuildGeometryBuffers()
{
	//std::ifstream fin("Models/skull.txt");
	//
	//if(!fin)
	//{
	//	MessageBox(0, L"Models/skull.txt not found.", 0, 0);
	//	return;
	//}

	//UINT vcount = 0;
	//UINT tcount = 0;
	//std::string ignore;

	//fin >> ignore >> vcount;
	//fin >> ignore >> tcount;
	//fin >> ignore >> ignore >> ignore >> ignore;
	//
	//float nx, ny, nz;
	//XMFLOAT4 black(0.0f, 0.0f, 0.0f, 1.0f);

	//std::vector<Vertex> vertices(vcount);
	//for(UINT i = 0; i < vcount; ++i)
	//{
	//	fin >> vertices[i].Pos.x >> vertices[i].Pos.y >> vertices[i].Pos.z;

	//	vertices[i].Color = black;

	//	// Normal not used in this demo.
	//	fin >> nx >> ny >> nz;
	//}

	//fin >> ignore;
	//fin >> ignore;
	//fin >> ignore;

	//mSkullIndexCount = 3*tcount;
	//std::vector<UINT> indices(mSkullIndexCount);
	//for(UINT i = 0; i < tcount; ++i)
	//{
	//	fin >> indices[i*3+0] >> indices[i*3+1] >> indices[i*3+2];
	//}

	//fin.close();

	//   D3D11_BUFFER_DESC vbd;
	//   vbd.Usage = D3D11_USAGE_IMMUTABLE;
	//vbd.ByteWidth = sizeof(Vertex) * vcount;
	//   vbd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
	//   vbd.CPUAccessFlags = 0;
	//   vbd.MiscFlags = 0;
	//   D3D11_SUBRESOURCE_DATA vinitData;
	//   vinitData.pSysMem = &vertices[0];
	//   HR(md3dDevice->CreateBuffer(&vbd, &vinitData, &mVB));

	////
	//// Pack the indices of all the meshes into one index buffer.
	////

	//D3D11_BUFFER_DESC ibd;
	//   ibd.Usage = D3D11_USAGE_IMMUTABLE;
	//ibd.ByteWidth = sizeof(UINT) * mSkullIndexCount;
	//   ibd.BindFlags = D3D11_BIND_INDEX_BUFFER;
	//   ibd.CPUAccessFlags = 0;
	//   ibd.MiscFlags = 0;
	//   D3D11_SUBRESOURCE_DATA iinitData;
	//iinitData.pSysMem = &indices[0];
	//   HR(md3dDevice->CreateBuffer(&ibd, &iinitData, &mIB));


	///////////////////////////////////////////////////
	//BOX//
	//////////////////////////////////////////////
	/*GeometryGenerator::MeshData BoxMesh;
	GeometryGenerator geo;
	geo.CreateBox(1, 1, 1, BoxMesh);

	XMFLOAT4 black(0.0f, 0.0f, 0.0f, 1.0f);

	std::vector<Vertex> BoxVectex(BoxMesh.Vertices.size());

	for (size_t i = 0; i < BoxMesh.Vertices.size(); ++i)
	{
	BoxVectex[i].Pos = BoxMesh.Vertices[i].Position;
	BoxVectex[i].Color = black;
	}

	D3D11_BUFFER_DESC vbd;
	vbd.Usage = D3D11_USAGE_IMMUTABLE;
	vbd.ByteWidth = sizeof(Vertex)*BoxVectex.size();
	vbd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
	vbd.CPUAccessFlags = 0;
	vbd.MiscFlags = 0;
	vbd.StructureByteStride = 0;

	D3D11_SUBRESOURCE_DATA vinitData;
	vinitData.pSysMem = &BoxVectex[0];

	HR(md3dDevice->CreateBuffer(&vbd, &vinitData, &mVB));

	mSkullIndexCount = BoxMesh.Indices.size();


	std::vector<UINT> indices16;
	indices16.assign(BoxMesh.Indices.begin(), BoxMesh.Indices.end());


	D3D11_BUFFER_DESC ibd;
	ibd.Usage = D3D11_USAGE_IMMUTABLE;
	ibd.ByteWidth = sizeof(UINT) * mSkullIndexCount;
	ibd.BindFlags = D3D11_BIND_INDEX_BUFFER;
	ibd.CPUAccessFlags = 0;
	ibd.StructureByteStride = 0;
	ibd.MiscFlags = 0;


	D3D11_SUBRESOURCE_DATA iinitData;
	iinitData.pSysMem = &indices16[0];

	HR(md3dDevice->CreateBuffer(&ibd, &iinitData, &mIB));*/




	////patch //////////////
	//VB
	std::vector<Vertex> patchVertex(mNumPatchVertices);
	float patchWidth = CellNumPerRowOfPatch;
	float du = 1.0f / (mNumPatchVertRows - 1);
	float dv = 1.0f / (mNumPatchVertCols - 1);
	XMFLOAT4 black(0.0f, 0.0f, 0.0f, 1.0f);

	for (int i = 0; i < mNumPatchVertRows; i++)
	{
		for (int j = 0; j < mNumPatchVertCols; j++)
		{
			patchVertex[i*mNumPatchVertRows + j].Pos = XMFLOAT3(j * patchWidth, 0.0, i * patchWidth);
			/*patchVertex[i*mNumPatchVertRows + j].Tex.x = j * du;
			patchVertex[i*mNumPatchVertRows + j].Tex.y = i * dv;*/
			patchVertex[i*mNumPatchVertRows + j].Color = black;

		}
	}



	D3D11_BUFFER_DESC vbd;
	vbd.Usage = D3D11_USAGE_IMMUTABLE;
	vbd.ByteWidth = sizeof(Vertex) * patchVertex.size();
	vbd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
	vbd.CPUAccessFlags = 0;
	vbd.MiscFlags = 0;
	vbd.StructureByteStride = 0;

	D3D11_SUBRESOURCE_DATA vinitData;
	vinitData.pSysMem = &patchVertex[0];
	HR(md3dDevice->CreateBuffer(&vbd, &vinitData, &mVB));
	//IB//////////////////
	std::vector<UINT>patchIndices(mNumPatchQuadFaces * 4);
	int k = 0;
	for (int i = 0; i < mNumPatchVertRows - 1; i++)
	{
		for (int j = 0; j < mNumPatchVertCols - 1; j++)
		{
			patchIndices[k] = i*mNumPatchVertCols + j;
			patchIndices[k + 1] = i*mNumPatchVertCols + j + 1;
			patchIndices[k + 3] = (i + 1)*mNumPatchVertCols + j;
			patchIndices[k + 2] = (i + 1)*mNumPatchVertCols + j + 1;
			k += 4;
		}
	}

	D3D11_BUFFER_DESC ibd;
	ibd.Usage = D3D11_USAGE_IMMUTABLE;
	ibd.ByteWidth = sizeof(UINT) * patchIndices.size();
	ibd.BindFlags = D3D11_BIND_INDEX_BUFFER;
	ibd.CPUAccessFlags = 0;
	ibd.MiscFlags = 0;
	ibd.StructureByteStride = 0;

	mSkullIndexCount = patchIndices.size();
	D3D11_SUBRESOURCE_DATA iinitData;
	iinitData.pSysMem = &patchIndices[0];
	HR(md3dDevice->CreateBuffer(&ibd, &iinitData, &mIB));

	//new box////////////////

	//Vertex vertices[] =
	//{
	//	{ XMFLOAT3(-5.0f, -5.0f, -5.0f), (const float*)&Colors::White },
	//	{ XMFLOAT3(-5.0f, +5.0f, -5.0f), (const float*)&Colors::Black },
	//	{ XMFLOAT3(+5.0f, +5.0f, -5.0f), (const float*)&Colors::Red },
	//	{ XMFLOAT3(+5.0f, -5.0f, -5.0f), (const float*)&Colors::Green },
	//	{ XMFLOAT3(-5.0f, -5.0f, +5.0f), (const float*)&Colors::Blue },
	//	{ XMFLOAT3(-5.0f, +5.0f, +5.0f), (const float*)&Colors::Yellow },
	//	{ XMFLOAT3(+5.0f, +5.0f, +5.0f), (const float*)&Colors::Cyan },
	//	{ XMFLOAT3(+5.0f, -5.0f, +5.0f), (const float*)&Colors::Magenta }
	//};
	//

	//D3D11_BUFFER_DESC vbd;
	//vbd.Usage = D3D11_USAGE_IMMUTABLE;
	//vbd.ByteWidth = sizeof(Vertex) * 8;
	//vbd.BindFlags = D3D11_BIND_VERTEX_BUFFER;
	//vbd.CPUAccessFlags = 0; 
	//vbd.MiscFlags = 0;
	//vbd.StructureByteStride = 0;
	//D3D11_SUBRESOURCE_DATA vinitData;
	//vinitData.pSysMem = vertices;
	//HR(md3dDevice->CreateBuffer(&vbd, &vinitData, &mVB));


	//// Create the index buffer

	//UINT indices[] = {
	//	// front face
	//	0, 1, 2,
	//	0, 2, 3,

	//	// back face
	//	4, 6, 5,
	//	4, 7, 6,

	//	// left face
	//	4, 5, 1,
	//	4, 1, 0,

	//	// right face
	//	3, 2, 6,
	//	3, 6, 7,

	//	// top face
	//	1, 5, 6,
	//	1, 6, 2,

	//	// bottom face
	//	4, 0, 3,
	//	4, 3, 7
	//};

	//D3D11_BUFFER_DESC ibd;
	//ibd.Usage = D3D11_USAGE_IMMUTABLE;
	//ibd.ByteWidth = sizeof(UINT) * 36;
	//ibd.BindFlags = D3D11_BIND_INDEX_BUFFER;
	//ibd.CPUAccessFlags = 0;
	//ibd.MiscFlags = 0;
	//ibd.StructureByteStride = 0;
	//D3D11_SUBRESOURCE_DATA iinitData;
	//iinitData.pSysMem = indices;
	//HR(md3dDevice->CreateBuffer(&ibd, &iinitData, &mIB));


}

void TerrainApp::BuildFX()
{
	/*std::ifstream fin("fx/color.fxo", std::ios::binary);

	fin.seekg(0, std::ios_base::end);
	int size = (int)fin.tellg();
	fin.seekg(0, std::ios_base::beg);
	std::vector<char> compiledShader(size);

	fin.read(&compiledShader[0], size);
	fin.close();

	HR(D3DX11CreateEffectFromMemory(&compiledShader[0], size,
	0, md3dDevice, &mFX));*/
	///////////////////////////////////////////////////////////////////////////
	DWORD shaderFlags = 0;
	shaderFlags |= D3D10_SHADER_DEBUG;
	shaderFlags |= D3D10_SHADER_SKIP_OPTIMIZATION;

	ID3D10Blob* compiledShader = 0;
	ID3D10Blob* compilationMsgs = 0;
	HRESULT hr = D3DX11CompileFromFile(L"Terrain.fx", 0, 0, 0, "fx_5_0", shaderFlags, 0, 0, &compiledShader, &compilationMsgs, 0);

	if (compilationMsgs != 0)
	{
		MessageBoxA(0, (char*)compilationMsgs->GetBufferPointer(), 0, 0);
		ReleaseCOM(compilationMsgs);
	}

	if (FAILED(hr))
	{
		DXTrace(__FILE__, (DWORD)__LINE__, hr, L"D3DX11CompileFromFile", true);
	}

	HR(D3DX11CreateEffectFromMemory(compiledShader->GetBufferPointer(), compiledShader->GetBufferSize(), 0, md3dDevice, &mFX));

	ReleaseCOM(compiledShader);
	///////

	mTech = mFX->GetTechniqueByName("ColorTech");
	mfxWorldViewProj = mFX->GetVariableByName("gWorldViewProj")->AsMatrix();

	mHeightMapEffectVar = mFX->GetVariableByName("terrainHeightMap")->AsShaderResource();
	mEyePosition = mFX->GetVariableByName("eyePosition")->AsVector();
	mWidthHightMap = mFX->GetVariableByName("sizeTerrain")->AsScalar();
	mHightScale = mFX->GetVariableByName("heightMultiplier")->AsScalar();
	mMinDistance = mFX->GetVariableByName("minDistance")->AsScalar();
	mMaxDistance = mFX->GetVariableByName("maxDistance")->AsScalar();
	mMinTesselltion = mFX->GetVariableByName("minTessExp")->AsScalar();
	mMaxTesselltion = mFX->GetVariableByName("maxTessExp")->AsScalar();
	/*mIsApplyCorrect = mFX->GetVariableByName("applyCorrection")->AsScalar();*/
	mSqrtNumPatch = mFX->GetVariableByName("sqrtNumPatch")->AsScalar();
	mTextSize = mFX->GetVariableByName("textSize")->AsScalar();

}

void TerrainApp::BuildVertexLayout()
{
	// Create the vertex input layout.
	D3D11_INPUT_ELEMENT_DESC vertexDesc[] =
	{
		{ "POSITION", 0, DXGI_FORMAT_R32G32B32_FLOAT, 0, 0, D3D11_INPUT_PER_VERTEX_DATA, 0 },
		{ "COLOR", 0, DXGI_FORMAT_R32G32B32A32_FLOAT, 0, 12, D3D11_INPUT_PER_VERTEX_DATA, 0 }
	};

	// Create the input layout
	D3DX11_PASS_DESC passDesc;
	mTech->GetPassByIndex(0)->GetDesc(&passDesc);
	HR(md3dDevice->CreateInputLayout(vertexDesc, 2, passDesc.pIAInputSignature,
		passDesc.IAInputSignatureSize, &mInputLayout));
}

void TerrainApp::LoadHeightMap()
{
	std::vector<unsigned char> in(mHeightMapInfo.HeightmapWidth * mHeightMapInfo.HeightmapHeight);


	std::ifstream inFile;
	inFile.open(mHeightMapInfo.HeightMapFileName.c_str(), std::ios_base::binary);

	if (inFile)
	{

		inFile.read((char*)&in[0], (std::streamsize)in.size());


		inFile.close();
	}


	mHeightmap.resize(mHeightMapInfo.HeightmapHeight * mHeightMapInfo.HeightmapWidth, 0);
	for (UINT i = 0; i < mHeightMapInfo.HeightmapHeight * mHeightMapInfo.HeightmapWidth; ++i)
	{
		mHeightmap[i] = (in[i] / 255.0f);
	}
}

void TerrainApp::BuildHeightMapSRV()
{
	D3D11_TEXTURE2D_DESC texDesc;
	texDesc.Width = mHeightMapInfo.HeightmapWidth;
	texDesc.Height = mHeightMapInfo.HeightmapHeight;
	texDesc.MipLevels = 1;   //mip on
	texDesc.ArraySize = 1;
	texDesc.Format = DXGI_FORMAT_R16_FLOAT;
	texDesc.SampleDesc.Count = 1;
	texDesc.SampleDesc.Quality = 0;
	texDesc.Usage = D3D11_USAGE_DEFAULT;
	texDesc.BindFlags = D3D11_BIND_SHADER_RESOURCE;
	texDesc.CPUAccessFlags = 0;
	texDesc.MiscFlags = 0;

	std::vector<HALF> hmap(mHeightmap.size());
	std::transform(mHeightmap.begin(), mHeightmap.end(), hmap.begin(), XMConvertFloatToHalf);

	D3D11_SUBRESOURCE_DATA data;
	data.pSysMem = &hmap[0];
	data.SysMemPitch = mHeightMapInfo.HeightmapWidth*sizeof(HALF);
	data.SysMemSlicePitch = 0;

	ID3D11Texture2D* hmapTex = 0;
	HR(md3dDevice->CreateTexture2D(&texDesc, &data, &hmapTex));

	D3D11_SHADER_RESOURCE_VIEW_DESC srvDesc;
	srvDesc.Format = texDesc.Format;
	srvDesc.ViewDimension = D3D11_SRV_DIMENSION_TEXTURE2D;
	srvDesc.Texture2D.MostDetailedMip = 0;
	srvDesc.Texture2D.MipLevels = -1;
	HR(md3dDevice->CreateShaderResourceView(hmapTex, &srvDesc, &mHeightMapResourceView));

	// SRV saves reference.
	ReleaseCOM(hmapTex);
}
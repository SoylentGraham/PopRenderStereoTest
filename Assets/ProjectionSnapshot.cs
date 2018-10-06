using System.Collections;
using System.Collections.Generic;
using UnityEngine;


[RequireComponent(typeof(MeshRenderer))]
[RequireComponent(typeof(MeshFilter))]
public class ProjectionSnapshot : MonoBehaviour {

	public Camera FrameCamera;
	[TexturePreview]
	public RenderTexture FrameColour;
	public Matrix4x4 FrameTransform;
	public bool ClearToAlpha = true;
	//public Texture2D FrameDepth;
	MeshFilter Filter { get { return GetComponent<MeshFilter>(); } }
	MeshRenderer Renderer { get { return GetComponent<MeshRenderer>(); } }
	public Mesh LineMesh { set { Filter.sharedMesh = value; } }
	public Material LineMaterial { get { return Renderer.sharedMaterial; } }


	public Material IntersectionTestMaterial;
	public string IntersectionTestTransformUniform = "FrameTransformA";
	public string IntersectionTestTextureUniform = "FrameTextureA";

	[InspectorButton("Capture")]
	public bool _Capture;

	public int Width = 512;
	public int Height = 256;
	public LayerMask RenderLayers = -1;

	void Capture()
	{
		var DepthBits = 24;
		FrameColour = new RenderTexture(Width, Height, DepthBits, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Default);
		FrameColour.filterMode = FilterMode.Point;
		FrameColour.useMipMap = false;
		FrameColour.autoGenerateMips = false;

		var OldLayerMask = FrameCamera.cullingMask;
		var OldClearMode = FrameCamera.clearFlags;
		var OldClearColour = FrameCamera.backgroundColor;

		if (ClearToAlpha)
		{
			FrameCamera.clearFlags = CameraClearFlags.Color;
			FrameCamera.backgroundColor = new Color(0, 1, 0, 0);
		}
		FrameCamera.cullingMask = RenderLayers;
		FrameCamera.targetTexture = FrameColour;
		FrameCamera.Render();
		FrameCamera.targetTexture = null;
		FrameTransform = (FrameCamera.projectionMatrix * FrameCamera.worldToCameraMatrix).inverse;
	
		//	restore
		FrameCamera.cullingMask = OldLayerMask;
		FrameCamera.clearFlags = OldClearMode;
		FrameCamera.backgroundColor = OldClearColour;
	
		LineMesh = MakeLineMesh(Width, Height);

		LineMaterial.mainTexture = FrameColour;
		LineMaterial.SetMatrix("FrameTransform",FrameTransform);

		IntersectionTestMaterial.SetMatrix(IntersectionTestTransformUniform, FrameTransform);
		IntersectionTestMaterial.SetTexture(IntersectionTestTextureUniform, FrameColour);
	}

	static Mesh MakeLineMesh(int Width,int Height)
	{
		var Mesh = new Mesh();
		var Positions = new List<Vector3>();

		System.Action<int,int> AddLine = (x,y)=>
		{
			var a = new Vector3(x, y, 0);
			var b = new Vector3(x, y, 1);
			Positions.Add(a);
			Positions.Add(b);
		};

		for (int y = 0; y < Height; y++)
			for (int x = 0; x < Width; x++)
				AddLine(x, y);

		var LineIndexes = new List<int>();
		for (int i = 0; i < Positions.Count; i++)
			LineIndexes.Add(i);

		Mesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
		Mesh.SetVertices( Positions );
		Mesh.SetIndices( LineIndexes.ToArray(), MeshTopology.Lines, 0 );
		Mesh.RecalculateBounds();
		Mesh.UploadMeshData(false);
		return Mesh;
	}

}

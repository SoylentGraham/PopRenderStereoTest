using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class MakeDumbMesh : MonoBehaviour {

	[Range(1,900)]
	public int QuadCountThousand = 100;
	public int PointCount { get { return QuadCount * 4; } }
	public int QuadCount { get { return QuadCountThousand * 1000; } }


	[InspectorButton("GenerateMesh")]
	public bool _GenerateMesh;


	void GenerateMesh()
	{
		var NewMesh = MakeMesh(QuadCount);
		var mf = GetComponent<MeshFilter>();
		mf.sharedMesh = NewMesh;
	}



	public static void AddQuadToMesh(ref List<Vector3> Positions,ref List<Vector2> Uvs, ref List<int> Indexes, int Index)
	{
		//	gr: if we have all triangles in the same place, this causes huge overdraw and cripples the GPU when it tries to render the raw mesh.
		//	change z (ignore in shader!) and all okay
		var pos0 = new Vector3(0, 0, Index);
		var pos1 = new Vector3(0, 1, Index);
		var pos2 = new Vector3(1, 1, Index);
		var pos3 = new Vector3(1, 0, Index);

		var i0 = Positions.Count;
		var i1 = i0 + 1;
		var i2 = i0 + 2;
		var i3 = i0 + 3;

		var uv0 = new Vector2(Index, 0);
		var uv1 = new Vector2(Index, 1);
		var uv2 = new Vector2(Index, 2);
		var uv3 = new Vector2(Index, 3);

		Positions.Add(pos0);
		Positions.Add(pos1);
		Positions.Add(pos2);
		Positions.Add(pos3);

		Uvs.Add(uv0);
		Uvs.Add(uv1);
		Uvs.Add(uv2);
		Uvs.Add(uv3);

		Indexes.Add(i0);
		Indexes.Add(i1);
		Indexes.Add(i2);

		Indexes.Add(i2);
		Indexes.Add(i3);
		Indexes.Add(i0);
	}

	public static Mesh MakeMesh(int QuadCount)
	{
		var Positions = new List<Vector3>();
		var Uvs = new List<Vector2>();
		var Indexes = new List<int>();

		for (int i = 0; i < QuadCount; i++)
		{
			AddQuadToMesh(ref Positions, ref Uvs, ref Indexes, i);
		}

		var NewMesh = new Mesh();
		NewMesh.name = "Quad Mesh x" + QuadCount;

		NewMesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;
		NewMesh.SetVertices(Positions);
		NewMesh.SetUVs(0,Uvs);

		NewMesh.indexFormat = UnityEngine.Rendering.IndexFormat.UInt32;

		NewMesh.SetIndices(Indexes.ToArray(), MeshTopology.Triangles, 0, true );

		return NewMesh;
	}
}

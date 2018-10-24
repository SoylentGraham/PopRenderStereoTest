using System.Collections;
using System.Collections.Generic;
using UnityEngine;

[ExecuteInEditMode]
public class BigPointRenderer : MonoBehaviour 
{
	[Range(0.001f, 1.0f)]
	public float Scale = 0.1f;
	public Vector3 Scale3 { get { return new Vector3(Scale, Scale, Scale); }}
	public List<List<Matrix4x4>> PositionSets;

	public bool ApplyThisMatrix = true;

	public void PushPoint(Vector3 Position)
	{
		Pop.AllocIfNull( ref PositionSets );

		if (PositionSets.Count == 0)
			PositionSets.Add(new List<Matrix4x4>() );
		if ( PositionSets[PositionSets.Count-1].Count >= 1023 )
			PositionSets.Add(new List<Matrix4x4>());

		var PositionSet = PositionSets[PositionSets.Count - 1];
		var PosMtx = Matrix4x4.TRS(Position, Quaternion.identity, Scale3);

		if (ApplyThisMatrix)
			PosMtx = this.transform.localToWorldMatrix * PosMtx;

		PositionSet.Add(PosMtx);
	}

	void Update()
	{
		if (PositionSets == null)
			return;
		
		var Mesh = GetComponent<MeshFilter>().sharedMesh;
		var Material = GetComponent<MeshRenderer>().sharedMaterial;
		foreach ( var Set in PositionSets )
			Graphics.DrawMeshInstanced(Mesh, 0, Material, Set);
	}

}

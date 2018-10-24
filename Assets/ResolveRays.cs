using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public struct PointHit
{
	public float Score;
	public float Distance;
	public Vector3 Position;
	//public Color Colour;
};

[System.Serializable]
public class UnityEvent_Vector3 : UnityEngine.Events.UnityEvent<Vector3> { }




public class ResolveRays : MonoBehaviour {

	public ProjectionSnapshot RaySetA;
	public ProjectionSnapshot RaySetB;
	[Header("else, by score")]
	public bool SortByDistance = true;

	int CurrentIndex = 0;
	int CurrentX { get { return CurrentIndex % RaySetB.FrameColour.width; } }
	int CurrentY { get { return CurrentIndex / RaySetB.FrameColour.width; } }

	//	best hit for each ray in B (because we iterate over that)... we could do both?
	PointHit?[,] BestHit;
	Texture2D BestHitOutput;
	public UnityEvent_Texture OnHitOutput;
	public bool OutputDistance = true;
	public UnityEvent_Vector3 OnAnyHitFound;
	public UnityEvent_Vector3 OnBestHitFound;

	public Material IntersectionShader;
	public string IntersectionShaderUniform_X = "FrameBRayX";
	public string IntersectionShaderUniform_Y = "FrameBRayY";
	public string IntersectionShaderUniform_TextureA = "FrameTextureA";
	public string IntersectionShaderUniform_TextureB = "FrameTextureB";

	[Range(0, 100)]
	public int IterationsPerFrame = 1;

	[Range(1, 100)]
	public float MaxDistance = 10;


	void Update()
	{
		for (int i = 0; i < IterationsPerFrame; i++)
			Iteration();
		BestHitOutput.Apply(false,false);
		OnHitOutput.Invoke(BestHitOutput);
	}

	void Iteration()
	{
		var SetBWidth = RaySetB.FrameColour.width;
		var SetBHeight = RaySetB.FrameColour.height;
		if (BestHit==null)
		{
			BestHit = new PointHit?[SetBWidth,SetBHeight];
			CurrentIndex = 0;
		}

		var xb = CurrentX;
		var yb = CurrentY;
		if (xb >= SetBWidth)
			return;
		if (yb >= SetBHeight)
			return;

		var Hit = GetRayHit(xb, yb);
		BestHit[xb,yb] = Hit;
		OutputResult(xb, yb, Hit);

		CurrentIndex++;
	}

	void OutputResult(int xb,int yb,PointHit? Hit)
	{
		var SetBWidth = RaySetB.FrameColour.width;
		var SetBHeight = RaySetB.FrameColour.height;
		if (!BestHitOutput)
			BestHitOutput = new Texture2D(SetBWidth, SetBHeight, TextureFormat.RGBA32, false);

		if (Hit.HasValue)
			OnBestHitFound.Invoke(Hit.Value.Position);

		//	output colour
		Color Rgba = Color.black;
		if ( Hit.HasValue )
		{
			Debug.Log(Hit.Value.Position);
			if (OutputDistance)
			{
				var DistanceNorm = Hit.Value.Distance / MaxDistance;
				if (DistanceNorm > 1)
					DistanceNorm = 1;
				Rgba = PopColor.NormalToRedGreenClamped(DistanceNorm);
			}
			else
			{
				Rgba.r = Hit.Value.Position.x;
				Rgba.g = Hit.Value.Position.y;
				Rgba.b = Hit.Value.Position.z;
			}
			Rgba.a = 1;
		}
		BestHitOutput.SetPixel(xb,yb,Rgba);
		//BestHitOutput.Apply(false,false);
		//OnHitOutput.Invoke(BestHitOutput);
	}

	PointHit? GetRayHit(int xb, int yb)
	{
		var Hits = GetRayHits(xb, yb);
		if (Hits.Count == 0)
			return null;

		//Debug.Log(xb + "," + yb + " got " + Hits.Count + " hits");
		//	sort by distance
		System.Func<PointHit,PointHit,int> Compare = (a,b)=>
		{
			if ( SortByDistance )
			{
				if (a.Distance < b.Distance)
					return -1;
				if (a.Distance > b.Distance)
					return 1;
			}
			else
			{
				if (a.Score < b.Score)
					return 1;
				if (a.Score > b.Score)
					return -1;
			}
			return 0;
		};
		Hits.Sort( (a,b)=>Compare(a,b) );

		for (int h = 0; h < Hits.Count; h++)
			OnAnyHitFound.Invoke(Hits[h].Position);

		return Hits[0];
	}


	RenderTexture HitTexture;
	Texture2D HitTexture2d;
	List<PointHit> GetRayHits(int xb, int yb)
	{
		var SetAWidth = RaySetA.FrameColour.width;
		var SetAHeight = RaySetA.FrameColour.height;
		var SetBWidth = RaySetB.FrameColour.width;
		var SetBHeight = RaySetB.FrameColour.height;
		IntersectionShader.SetTexture(IntersectionShaderUniform_TextureA, RaySetA.FrameColour);
		IntersectionShader.SetTexture(IntersectionShaderUniform_TextureB, RaySetB.FrameColour);
		IntersectionShader.SetInt(IntersectionShaderUniform_X, xb);
		IntersectionShader.SetInt(IntersectionShaderUniform_Y, yb);
		IntersectionShader.SetInt("FrameWidthA", SetAWidth);
		IntersectionShader.SetInt("FrameHeightA", SetAHeight);
		IntersectionShader.SetInt("FrameWidthB", SetBWidth);
		IntersectionShader.SetInt("FrameHeightB", SetBHeight);

		var CameraPosA = RaySetA.FrameTransform.MultiplyPoint(new Vector3(0, 0, -1));
		var CameraPosB = RaySetB.FrameTransform.MultiplyPoint(new Vector3(0, 0, -1));

		var Hits = new List<PointHit>();
		System.Action<int,int,Color> AddHit = (xa,ya,ResultColour)=>
		{
			float Score = ResultColour.a;
			if (Score < 0.001f)
				return;
			var xyz = new Vector3(ResultColour.r, ResultColour.g, ResultColour.b);
			//Debug.Log(xyz);
			var Distance = Vector3.Distance(CameraPosB, xyz);
			var Hit = new PointHit();
			Hit.Distance = Distance;
			Hit.Position = xyz;
			Hit.Score = Score;
			Hits.Add(Hit);
		};


		if (!HitTexture)
		{
			HitTexture = RenderTexture.GetTemporary(SetAWidth, SetAHeight, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
			HitTexture.filterMode = FilterMode.Point;
		}
		Graphics.Blit(null,HitTexture,IntersectionShader);
		//var HitTexure2d = PopX.Textures.GetTexture2D(HitTexture,TextureFormat.RGBAFloat);
		PopX.Textures.GetTexture2D(HitTexture, ref HitTexture2d, TextureFormat.RGBAFloat);
		//RenderTexture.ReleaseTemporary(HitTexture);
		var HitPixels = HitTexture2d.GetPixels();
		for (int i = 0; i < HitPixels.Length;	i++ )
		{
			var xa = i % SetAWidth;
			var ya = i / SetAWidth;
			var rgba = HitPixels[i];
			AddHit(xa, ya, rgba);
		}

		return Hits;
	}

}

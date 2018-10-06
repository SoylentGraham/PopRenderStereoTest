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

public class ResolveRays : MonoBehaviour {

	public ProjectionSnapshot RaySetA;
	public ProjectionSnapshot RaySetB;

	int CurrentIndex = 0;
	int CurrentX { get { return CurrentIndex % RaySetB.FrameColour.width; } }
	int CurrentY { get { return CurrentIndex / RaySetB.FrameColour.width; } }

	//	best hit for each ray in B (because we iterate over that)... we could do both?
	PointHit?[,] BestHit;
	Texture2D BestHitOutput;
	public UnityEvent_Texture OnHitOutput;
	public bool OutputDistance = true;

	public Material IntersectionShader;
	public string IntersectionShaderUniform_X = "FrameBRayX";
	public string IntersectionShaderUniform_Y = "FrameBRayY";
	public string IntersectionShaderUniform_TextureA = "FrameTextureA";
	public string IntersectionShaderUniform_TextureB = "FrameTextureB";

	[Range(0, 50)]
	public int IterationsPerFrame = 1;

	[Range(1, 100)]
	public float MaxDistance = 10;


	void Update()
	{
		for (int i = 0; i < IterationsPerFrame; i++)
			Iteration();
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

		//	output colour
		Color Rgba = Color.black;
		if ( Hit.HasValue )
		{
			var DistanceNorm = Hit.Value.Distance / MaxDistance;
			if (DistanceNorm > 1)
				DistanceNorm = 1;
			Rgba = PopColor.NormalToRedGreenClamped(DistanceNorm);

			if (!OutputDistance)
			{
				Rgba.r = Hit.Value.Position.x;
				Rgba.g = Hit.Value.Position.y;
				Rgba.b = Hit.Value.Position.z;
			}
			Rgba.a = 1;
		}
		BestHitOutput.SetPixel(xb,yb,Rgba);
		BestHitOutput.Apply(false,false);
		OnHitOutput.Invoke(BestHitOutput);
	}

	PointHit? GetRayHit(int xb, int yb)
	{
		var Hits = GetRayHits(xb, yb);
		if (Hits.Count == 0)
			return null;

		//	sort by distance
		System.Func<PointHit,PointHit,int> Compare = (a,b)=>
		{
			if (a.Distance < b.Distance)
				return -1;
			if (a.Distance > b.Distance)
				return 1;
			return 0;
		};
		Hits.Sort( (a,b)=>Compare(a,b) );

		return Hits[0];
	}

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

		var CameraPosA = RaySetA.FrameTransform.MultiplyPoint(Vector3.zero);

		var Hits = new List<PointHit>();
		System.Action<int,int,Color> AddHit = (xa,ya,ResultColour)=>
		{
			float Score = ResultColour.a;
			if (Score < 0.001f)
				return;
			var xyz = new Vector3(ResultColour.r, ResultColour.g, ResultColour.b);
			var Distance = Vector3.Distance(CameraPosA, xyz);
			var Hit = new PointHit();
			Hit.Distance = Distance;
			Hit.Position = xyz;
			Hit.Score = Score;
			Hits.Add(Hit);
		};

		var HitTexture = RenderTexture.GetTemporary(SetAWidth, SetAHeight, 0, RenderTextureFormat.ARGBFloat, RenderTextureReadWrite.Linear);
		Graphics.Blit(null,HitTexture,IntersectionShader);
		var HitTexure2d = PopX.Textures.GetTexture2D(HitTexture,TextureFormat.RGBAFloat);
		RenderTexture.ReleaseTemporary(HitTexture);
		var HitPixels = HitTexure2d.GetPixels();
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

using System.Collections;
using System.Collections.Generic;
using UnityEngine;

public class LineIntersectionTest : MonoBehaviour
{
	public bool ClampToLine = true;
	public Transform StartA_Node;
	public Transform EndA_Node;
	public Transform StartB_Node;
	public Transform EndB_Node;

	public Vector3 StartA { get { return StartA_Node.position; } }
	public Vector3 EndA { get { return EndA_Node.position; } }
	public Vector3 StartB { get { return StartB_Node.position; } }
	public Vector3 EndB { get { return EndB_Node.position; } }

	[Range(0,100)]
	public float coPlanerThreshold = 0.7f; // Some threshold value that is application dependent
	const double lengthErrorThreshold = 1e-3;

	//	https://www.codefull.org/2015/06/intersection-of-a-ray-and-a-line-segment-in-3d/
	void GetIntersection(out Vector3 IntersectionA, out Vector3 IntersectionB)
	{
		if (ClampToLine)
		{
			PopMath.GetLineLineIntersection(StartA, EndA, StartB, EndB, out IntersectionA, out IntersectionB);
		}
		else
		{
			var RayA = new Ray(StartA, EndA - StartA);
			var RayB = new Ray(StartB, EndB - StartB);
			PopMath.GetRayRayIntersection(RayA, RayB, out IntersectionA, out IntersectionB);
		}

	}
	/*
	void GetIntersection(out Vector3 IntersectionA,out Vector3 IntersectionB)
	{
		var da = EndA - StartA;
		var db = EndB - StartB;
		var dc = StartB - StartA;

		float IntersectionTimeA;
		float IntersectionTimeB;
		float a = Vector3.Dot(da, da);         // always >= 0
		float b = Vector3.Dot(da, db);
		float c = Vector3.Dot(db, db);         // always >= 0
		float d = Vector3.Dot(da, dc);
		float e = Vector3.Dot(db, dc);
		float D = a * c - b * b;        // always >= 0

		// compute the line parameters of the two closest points
		// the lines are almost parallel
		float EPSILON = 0.000001f;
		if (D < EPSILON)
		if (false)
		//if ( D == 0 )
		{
			IntersectionTimeA = 2;
			IntersectionTimeB = 2;

			IntersectionTimeA = 0;
			// use the largest denominator
			IntersectionTimeB = (b > c ? d / b : e / c);
		
		}
		else
		{
			IntersectionTimeA = (b * e - c * d) / D;
			IntersectionTimeB = (a * e - b * d) / D;

			if ( false )
			{
				//	nearest points are out of bounds of line
				if ( IntersectionTimeA < 0.f || IntersectionTimeA > 1.f || IntersectionTimeB < 0.f || IntersectionTimeB > 1.f )
				{
					IntersectionTimeA = Clamp01(IntersectionTimeA);
					IntersectionTimeB = Clamp01(IntersectionTimeB);
					return false;
				}
			}
			
		}


		//	gr: to get nearest distance
		// get the difference of the two closest points
		//vec3f dP = dc + (sc * da) - (tc * db);  // =  L1(sc) - L2(tc)
		//return dP.length();   // return the closest distance
		IntersectionA = Vector3.Lerp(StartA, EndA, IntersectionTimeA);
		IntersectionB = Vector3.Lerp(StartB, EndB, IntersectionTimeB);
	}
	*/

	void OnDrawGizmos()
	{
		Gizmos.matrix = Matrix4x4.identity;
		Vector3 IntersectionA, IntersectionB;
		GetIntersection(out IntersectionA, out IntersectionB);

		var Scalef = Vector3.Distance(StartA, EndA) * 0.1f;

		Gizmos.color = Color.yellow;
		Gizmos.DrawLine(StartA, EndA);
		Gizmos.DrawCube(IntersectionA, Scalef.xxx() );

		Gizmos.color = Color.cyan;
		Gizmos.DrawLine(StartB, EndB);
		Gizmos.DrawCube(IntersectionB, Scalef.xxx());
	}


}

Shader "NewChromantics/IntersectionTest"
{
	Properties
	{
		MaxLightnessDiff("MaxLightnessDiff", Range(0,1) ) = 0.1
		MaxHueDiff("MaxHueDiff", Range(0,1) ) = 0.1
		MaxSatDiff("MaxSatDiff", Range(0,1) ) = 0.1
		//FrameTransformA
		FrameTextureA("FrameTextureA", 2D ) = "black" {}
		[IntRange]FrameWidthA("FrameWidthA", Range(0,1024) ) = 1024
		[IntRange]FrameHeightA("FrameHeightA", Range(0,1024) ) = 512

		//FrameTransformA
		FrameTextureB("FrameTextureB", 2D ) = "black" {}
		[IntRange]FrameWidthB("FrameWidthB", Range(0,1024) ) = 1024
		[IntRange]FrameHeightB("FrameHeightB", Range(0,1024) ) = 512
		[IntRange]FrameBRayX("FrameBRayX", Range(0,512) ) = 0
		[IntRange]FrameBRayY("FrameBRayY", Range(0,512) ) = 0

		PositionAdd("PositionAdd", Range(0,20) ) = 0
		PositionScalar("PositionScalar", Range(0.001,1) ) = 0.1
		MaxIntersectionDistance("MaxIntersectionDistance", Range(0.0001,10) ) = 1
		[Toggle]Debug_ColourScore("Debug_ColourScore",Range(0,1))=0
		[Toggle]Debug_IntersectionDistanceScore("Debug_IntersectionDistanceScore",Range(0,1))=0
	}
	SubShader
	{
		Tags { "Queue"="Transparent" "RenderType"="Transparent" "IgnoreProjector"="True" }
		LOD 100
		//Blend SrcAlpha One
		Blend One Zero

		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "PopUnityCommon/PopCommon.cginc"

			struct appdata
			{
				float4 vertex : POSITION;
				float2 uv : TEXCOORD0;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};


			float4x4 FrameTransformA;
			sampler2D FrameTextureA;
			float FrameWidthA;
			float FrameHeightA;

			float4x4 FrameTransformB;
			sampler2D FrameTextureB;
			float FrameWidthB;
			float FrameHeightB;
			int FrameBRayX;
			int FrameBRayY;

			float PositionAdd;
			float PositionScalar;
			float MaxLightnessDiff;
			float MaxHueDiff;
			float MaxSatDiff;


			float MaxIntersectionDistance;
			float Debug_ColourScore;
			float Debug_IntersectionDistanceScore;
			#define DEBUG_COLOURSCORE	(Debug_ColourScore>0.5f)
			#define DEBUG_INTERSECTIONDISTANCESCORE	(Debug_IntersectionDistanceScore>0.5f)


			v2f vert (appdata v)
			{
				v2f o;
				o.vertex = UnityObjectToClipPos(v.vertex);
				o.uv = v.uv;

				return o;
			}

			float GetColourScore(float4 ColourA,float4 ColourB)
			{
				if ( ColourA.w == 0 )
					return 0;
				if ( ColourB.w == 0 )
					return 0;

				float3 HslA = RgbToHsl(ColourA);
				float3 HslB = RgbToHsl(ColourB);

				float3 HslDiff = abs(HslA - HslB);

				if ( HslDiff.z > MaxLightnessDiff )
					return 0;
				if ( HslDiff.x > MaxHueDiff )
					return 0;
				if ( HslDiff.y > MaxSatDiff )
					return 0;

				float LightnessDiff = HslDiff.z;
				LightnessDiff /= MaxLightnessDiff;
				return 1 - LightnessDiff;
			}

			float4 GetRayIntersection(float3 RayStartA,float3 RayEndA,float4 ColourA,float3 RayStartB,float3 RayEndB,float4 ColourB)
			{
				float ColourScore = GetColourScore( ColourA, ColourB );
				float IntersectionTimeA = 0;
				float IntersectionTimeB = 0;
				float ScoreMult = 1;
				if ( !GetLineLineIntersection3( RayStartA, RayEndA, RayStartB, RayEndB, IntersectionTimeA, IntersectionTimeB ) )
					ScoreMult = 0;
				//	these are the nearest points on the line for an intersection
				float3 IntersectionPosA = lerp( RayStartA, RayEndA, IntersectionTimeA );
				float3 IntersectionPosB = lerp( RayStartB, RayEndB, IntersectionTimeB );

				//	world space rejections
				//	underneath floor plane
				if ( IntersectionPosA.y < 0 )
					ScoreMult = 0;
				if ( IntersectionPosB.y < 0 )
					ScoreMult = 0;

				float3 IntersectionPos = lerp( IntersectionPosA, IntersectionPosB, 0.5f );
				//float3 IntersectionPos = IntersectionPosB;

				float IntersectionDistance = length(IntersectionPosA-IntersectionPosB);
				float IntersectionDistanceScore = ( IntersectionDistance / MaxIntersectionDistance );
				if ( IntersectionDistanceScore > 1 )
					ScoreMult = 0;
				IntersectionDistanceScore = 1 - min( 1, IntersectionDistanceScore );

				if ( DEBUG_INTERSECTIONDISTANCESCORE )
					return float4( IntersectionPos, ScoreMult * IntersectionDistanceScore );
				if ( DEBUG_COLOURSCORE )
					return float4( IntersectionPos, ScoreMult * ColourScore );

				float Score = ScoreMult * ColourScore * IntersectionDistanceScore;
				//float Score = ScoreMult * IntersectionDistanceScore;
				return float4( IntersectionPos, Score );
			}

			float3 GetFramePosition(float4x4 FrameTransform,float2 xy,float Depth,float2 FrameSize)
			{
				//	move to camera viewspace (-1..1,-1..1,-1..1)
				xy /= FrameSize;
				xy = lerp( -1, 1, xy );
			
			 	float z = lerp( -1, 1, Depth );
				//float z = lerp( -1, 1, Depth );
				float4 Position = float4( xy, z, 1 );
				Position = mul( FrameTransform, Position );
				Position.xyz /= Position.w;
				return Position;
			}

			fixed4 frag (v2f i) : SV_Target
			{
				//	get rays
				float2 uvA = i.uv;
				float3 RayStartA = GetFramePosition( FrameTransformA, uvA, 0, float2(FrameWidthA,FrameHeightA) );
				float3 RayEndA = GetFramePosition( FrameTransformA, uvA, 1, float2(FrameWidthA,FrameHeightA) );
				int FrameARayX = uvA.x * FrameWidthA;
				int FrameARayY = uvA.y * FrameHeightA;
				float4 FrameColourA = tex2D( FrameTextureA, uvA );

				float2 uvB = float2( FrameBRayX/(float)FrameWidthB, FrameBRayY/(float)FrameHeightB );
				float3 RayStartB = GetFramePosition( FrameTransformB, uvB, 0, float2(FrameWidthB,FrameHeightB) );
				float3 RayEndB = GetFramePosition( FrameTransformB, uvB, 1, float2(FrameWidthB,FrameHeightB) );
				float4 FrameColourB = tex2D( FrameTextureB, uvB );

				float4 Intersection = GetRayIntersection( RayStartA, RayEndA, FrameColourA, RayStartB, RayEndB, FrameColourB );

				Intersection.xyz += PositionAdd;
				Intersection.xyz *= PositionScalar;

				if ( Intersection.w == 0 )
					return float4(1,0,0,0);

				if ( DEBUG_COLOURSCORE || DEBUG_INTERSECTIONDISTANCESCORE )
				{
					Intersection.xyz = Intersection.w;
				}

				//return float4(1,0,0,0);
				return Intersection;
			}
			ENDCG
		}
	}
}

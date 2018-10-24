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

		//[Enum(OutputColourA,0,OutputColourB,1,OutputPositionA,2,OutputPositonB,3,OutputPositionAverage,4,OutputScore,5,OutputTestRayPoint,6,OutputTimeA,7,OutputTimeB,8)]OutputFormat("OutputFormat", float) = 0
		[Enum(OutputColourA,0,OutputColourB,1,OutputPositionA,2,OutputPositonB,3,OutputTestRayPoint,6,OutputIntersectionTimeA,7,OutputIntersectionTimeB,8)]OutputFormat("OutputFormat", float) = 0
		PositionAdd("PositionAdd", Range(0,20) ) = 0
		PositionScalar("PositionScalar", Range(-1,1) ) = 0.1
		MaxIntersectionDistance("MaxIntersectionDistance", Range(0.0001,1000) ) = 1
		[Toggle]Debug_ColourScore("Debug_ColourScore",Range(0,1))=0
		[Toggle]Debug_IntersectionDistanceScore("Debug_IntersectionDistanceScore",Range(0,1))=0
		[Toggle]Debug_ShowRayBPos("Debug_ShowRayBPos",Range(0,1))=0
		[Toggle]Debug_UseSameFrame("Debug_UseSameFrame",Range(0,1))=0

		Hit_MinY("Hit_MinY", Range(-100,0) ) = 0
		Hit_MinZ("Hit_MinZ", Range(-1000,10) ) = -100
		Hit_MaxZ("Hit_MaxZ", Range(-10,1000) ) = 100

		ErrorColour("ErrorColour", COLOR ) = (1,0,1,0)
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

			float4 ErrorColour;
			#define ERROR_COLOUR ErrorColour;

			float MaxIntersectionDistance;
			float Debug_ColourScore;
			float Debug_IntersectionDistanceScore;
			float Debug_ShowRayBPos;
			float Debug_UseSameFrame;
			#define SCORE_INCLUDE_COLOUR	(Debug_ColourScore>0.5f)
			#define SCORE_INCLUDE_DISTANCE	(Debug_IntersectionDistanceScore>0.5f)
			#define DEBUG_SHOWRAYBPOS	(Debug_ShowRayBPos>0.5f)
			#define DEBUG_USESAMEFRAME	(Debug_UseSameFrame>0.5f)

			float OutputFormat;
			#define OutputColourA			( (int)OutputFormat == 0 )
			#define OutputColourB			( (int)OutputFormat == 1 )
			#define OutputPositionA			( (int)OutputFormat == 2 )
			#define OutputPositonB			( (int)OutputFormat == 3 )
			#define OutputPositionAverage	( (int)OutputFormat == 4 )
			#define OutputScore				( (int)OutputFormat == 5 )
			#define OutputTestRayPoint		( (int)OutputFormat == 6 )
			#define OutputIntersectionTimeA	( (int)OutputFormat == 7 )
			#define OutputIntersectionTimeB	( (int)OutputFormat == 8 )
			float Hit_MinY;
			float Hit_MinZ;
			float Hit_MaxZ;


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
				GetLineLineIntersection3( RayStartA, RayEndA, RayStartB, RayEndB, IntersectionTimeA, IntersectionTimeB );

				//	these are the nearest points on the line for an intersection
				float3 IntersectionPosA = lerp( RayStartA, RayEndA, IntersectionTimeA );
				float3 IntersectionPosB = lerp( RayStartB, RayEndB, IntersectionTimeB );

				//	world space rejections
				//	underneath floor plane
				int OutOfBounds = 0;
				OutOfBounds += ( IntersectionPosA.y < Hit_MinY );
				OutOfBounds += ( IntersectionPosB.y < Hit_MinY );

				OutOfBounds += ( IntersectionPosA.z < Hit_MinZ );
				OutOfBounds += ( IntersectionPosB.z < Hit_MinZ );
				OutOfBounds += ( IntersectionPosA.z > Hit_MaxZ );
				OutOfBounds += ( IntersectionPosB.z > Hit_MaxZ );

				if ( OutOfBounds )
				{
					ScoreMult = 0;
					return float4(1,0,0,0);
				}


				//IntersectionPosA += PositionAdd.xxx;
				//IntersectionPosB += PositionAdd.xxx;
				//IntersectionPosA *= PositionScalar.xxx;
				//IntersectionPosB *= PositionScalar.xxx;

				float IntersectionDistance = length(IntersectionPosA-IntersectionPosB);
				float IntersectionDistanceScore = ( IntersectionDistance / MaxIntersectionDistance );
				if ( IntersectionDistanceScore > 1 )
				{
					//ScoreMult = 0;
				}
				IntersectionDistanceScore = 1 - min( 1, IntersectionDistanceScore );

				//float Score = ScoreMult;
				float Score = 1;
				if ( SCORE_INCLUDE_DISTANCE )
					Score *= IntersectionDistanceScore;
				if ( SCORE_INCLUDE_COLOUR )
					Score *= ColourScore;

				float3 OutputData = float3(1,0,0);
				float3 IntersectionPos = lerp( IntersectionPosA, IntersectionPosB, 0.5f );
				if ( OutputColourA )
					OutputData = ColourA;
				if ( OutputColourB )
					OutputData = ColourB;
				if ( OutputPositionA )
					OutputData = IntersectionPosA;
				if ( OutputPositonB )
					OutputData = IntersectionPosB;
				if ( OutputPositionAverage )
					OutputData = IntersectionPos;
				if ( OutputScore )
					OutputData = Score.xxx;
				if ( OutputTestRayPoint )
				{
					OutputData = lerp( RayStartA, RayEndA, 0.5f );
					//Score = 1;
				}
				if ( OutputIntersectionTimeA )
				{
					OutputData = IntersectionTimeA.xxx;
					OutputData.z = (IntersectionTimeA < 0);
					OutputData.y = (IntersectionTimeA > 1);
				}
				if ( OutputIntersectionTimeB )
				{
					OutputData = IntersectionTimeB.xxx;
					OutputData.z = (IntersectionTimeB < 0);
					OutputData.y = (IntersectionTimeB > 1);
				}
	
				//float Score = ScoreMult * ColourScore * IntersectionDistanceScore;
				//float Score = IntersectionDistanceScore;
				//Score = min(1,Score);

				//float Score = ScoreMult * IntersectionDistanceScore;
				return float4( OutputData, Score );
			}

			float3 GetFramePosition(float4x4 FrameTransform,float2 xy,float Depth,float2 FrameSize)
			{
				//	move to camera viewspace (-1..1,-1..1,-1..1)
				//xy /= FrameSize;
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

				if ( DEBUG_USESAMEFRAME )
				{
					//uvB = uvA;
					RayStartB = RayStartA;
					RayEndB = RayEndA;
					FrameColourB = FrameColourA;
				}

				float4 Intersection = GetRayIntersection( RayStartA, RayEndA, FrameColourA, RayStartB, RayEndB, FrameColourB );

				if ( DEBUG_SHOWRAYBPOS  )
				{
			
					if ( length(i.uv-uvB) < 0.01f )
					{
						return float4(1,0,0,0);
					}
				}

				//Intersection.xyz += PositionAdd;
				//Intersection.xyz *= PositionScalar;

				//Intersection.xyz *= max(Intersection.w,0.2f);
				if ( Intersection.w == 0 )
				{
					return ERROR_COLOUR;
				}

				//return float4(Intersection.www,1);
/*
				if ( DEBUG_COLOURSCORE || DEBUG_INTERSECTIONDISTANCESCORE )
				{
					Intersection.xyz = Intersection.w;
				}
				*/
				//return float4(1,0,0,0);
				return Intersection;
			}
			ENDCG
		}
	}
}

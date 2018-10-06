﻿Shader "NewChromantics/IntersectionTest"
{
	Properties
	{
		MaxLightnessDiff("MaxLightnessDiff", Range(0,1) ) = 0.1
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
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100

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

			float MaxLightnessDiff;
			
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

				float LightnessDiff = abs(HslA.z - HslB.z);
				if ( LightnessDiff > MaxLightnessDiff )
					return 0;

				return 1 - LightnessDiff;
			}

			float4 GetRayIntersection(float3 RayStartA,float3 RayEndA,float4 ColourA,float3 RayStartB,float3 RayEndB,float4 ColourB)
			{
				float ColourScore = GetColourScore( ColourA, ColourB );
				float IntersectionTimeA = 0;
				float IntersectionTimeB = 0;
				if ( !GetLineLineIntersection3( RayStartA, RayEndA, RayStartB, RayEndB, IntersectionTimeA, IntersectionTimeB ) )
					ColourScore = 0;
				float3 IntersectionPos = lerp( RayStartA, RayEndA, IntersectionTimeA );

				//	underneath floor plane
				if ( IntersectionPos.y < 0 )
					ColourScore = 0;
				return float4( IntersectionPos, ColourScore );
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

				return float4( Intersection.w, Intersection.w, Intersection.w, 1 );
			}
			ENDCG
		}
	}
}

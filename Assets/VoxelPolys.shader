Shader "NewChromantics/VoxelPolys"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		VoxelSize("VoxelSize", Range(0.001,0.50))= 0.010
	}
	SubShader
	{
		Tags { "RenderType"="Opaque" }
		LOD 100
		//Cull Off
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag

			#include "UnityCG.cginc"
			#include "PopUnityCommon/PopCommon.cginc"

			struct appdata
			{
				float4 LocalXYIndex : POSITION;
				float2 VoxelindexVertexIndex : TEXCOORD0;
			};

			struct v2f
			{
				float Score : TEXCOORD0;
				float4 WorldPosScore : TEXCOORD1;
				float4 ClipPos : SV_POSITION;
			};

			float VoxelSize;

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4 _MainTex_TexelSize;

			float4 GetWorldPosScore(int VoxelIndex)
			{
				int w = _MainTex_TexelSize.z;
				int h = _MainTex_TexelSize.w;
				int x = VoxelIndex % w;
				int y = VoxelIndex / w;
				float u = x / (float)w;
				float v = y / (float)h;
				float4 xyzscore = tex2Dlod( _MainTex, float4(u,v,0,0) );

				//xyzscore.z = 0;
				//xyzscore.w = 1;
				//xyzscore = float4(u,v,0,1);
				//xyzscore.xy = float2(u,v);

				//	voxel out of texture range
				if ( y >= h )
					xyzscore.w = 0;
				
				return xyzscore;
			}


			v2f vert (appdata v)
			{
				v2f o;

				//int Index = v.LocalXYIndex.z;
				int Index = v.VoxelindexVertexIndex.x;
				float4 WorldPosScore = GetWorldPosScore(Index);

				/*
				float3 LocalPos = float3( v.LocalXYIndex.xyz );
				float3 WorldPos = UnityObjectToWorldPos(LocalPos);
				*/


				float3 LocalPos = float3( v.LocalXYIndex.xy, 0 );
				LocalPos *= VoxelSize;
				//	apply scale and offset to local pos
				float3 WorldPos = UnityObjectToWorldPos(LocalPos);



				WorldPos += WorldPosScore.xyz;


				o.WorldPosScore = WorldPosScore;
				o.ClipPos = UnityWorldToClipPos( float4(WorldPos,1) );
				o.Score = WorldPosScore.w;

				//	degenerate
				if ( WorldPosScore.w == 0 )
					o.ClipPos = 0;
				if ( Index == 0 )
				{
				//	o.ClipPos = 0;
				}
				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				return float4( NormalToRedGreen( i.Score), 1 );
				return float4( i.WorldPosScore.xyz, 1 );
				return float4( i.Score, i.Score, i.Score, 1 );
			}
			ENDCG
		}
	}
}

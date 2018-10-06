Shader "NewChromantics/ProjectionLines"
{
	Properties
	{
		_MainTex ("Texture", 2D) = "white" {}
		[IntRange]FrameWidth("FrameWidth", Range(0,1024) ) = 1024
		[IntRange]FrameHeight("FrameHeight", Range(0,1024) ) = 512
		RayStart("RayStart", Range(-1,1) ) = -1
		//RayEnd("RayEnd", Range(-1,1) ) = 1
		RayLength("RayLength", Range(0.001,2) ) = 2
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

		
			struct appdata
			{
				float3 vertex : POSITION;
			};

			struct v2f
			{
				float2 uv : TEXCOORD0;
				float4 vertex : SV_POSITION;
			};

			sampler2D _MainTex;
			float4 _MainTex_ST;
			float4x4 FrameTransform;
			#define FrameTexture	_MainTex
			#define FrameTextureSize	( _MainTex_ST.zw )
			float FrameWidth;
			float FrameHeight;
			float RayStart;
			float RayLength;
			float a,b,c,d;

			float Range(float Min,float Max,float Value)
			{
				return (Value-Min) / (Max-Min);
			}

			float3 GetFramePosition(float4x4 FrameTransform,float2 xy,float Depth)
			{
				//	move to camera viewspace (-1..1,-1..1,-1..1)
				xy /= float2(FrameWidth,FrameHeight);
				xy = lerp( -1, 1, xy );
			
			 	float z = lerp( RayStart, RayStart+RayLength, Depth );
				//float z = lerp( -1, 1, Depth );
				float4 Position = float4( xy, z, 1 );
				Position = mul( FrameTransform, Position );
				Position.xyz /= Position.w;
				return Position;
			}

			v2f vert (appdata v)
			{
				v2f o;

				float2 FrameXy = v.vertex.xy;
				float2 FrameUv = FrameXy / float2(FrameWidth,FrameHeight);
				float FrameDepthScalar = v.vertex.z;

				float3 Position;
				Position = GetFramePosition( FrameTransform, FrameXy, FrameDepthScalar );
				//Position.xy = v.vertex.xy / float2(FrameWidth,FrameHeight);
				//Position.z = v.vertex.z;
				o.uv = FrameUv;

				o.vertex = UnityWorldToClipPos( float4(Position,1) );

				//	degenerate alpha'd pixels
				float4 ColourSample = tex2Dlod( _MainTex, float4(o.uv,0,0) );
				if ( ColourSample.w == 0 )
					o.vertex = float4(0,0,0,0);

				return o;
			}
			
			fixed4 frag (v2f i) : SV_Target
			{
				if ( i.uv.x < 0 || i.uv.y < 0 || i.uv.x >= 1 || i.uv.y >= 1 )
					return float4(0,0,1,1);
				float4 rgba = tex2D( _MainTex, i.uv );
				return rgba;
				return float4( i.uv, 0, 1 );
			}
			ENDCG
		}
	}
}

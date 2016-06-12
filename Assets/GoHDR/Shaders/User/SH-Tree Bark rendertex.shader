Shader "Hidden/TerrainEngine/Soft Occlusion Bark rendertex" {
	Properties {
		_Color ("Main Color", Color) = (1,1,1,0)
		_MainTex ("Main Texture", 2D) = "white" {  }
		
		_BaseLight ("BaseLight", range (0, 1)) = 0.35
		_AO ("Amb. Occlusion", range (0, 10)) = 2.4
		_Scale ("Scale", Vector) = (1,1,1,1)
		_SquashAmount ("Squash", Float) = 1
	}
	
	SubShader {
		Fog { Mode Off }
		
		Pass {
			
			CGPROGRAM
			#include "../GoHDR.cginc"
			#include "../LinLighting.cginc"
			#pragma vertex vert
			#include "../UnityCGGoHDR.cginc"
			#include "../TerrainEngineGoHDR.cginc"
			
			uniform float _Occlusion, _AO, _BaseLight;
			uniform float4 _Color;
			uniform float3 _TerrainTreeLightDirections[4];
			uniform float4 _TerrainTreeLightColors[4];
			
			struct v2f {
				float4 pos : POSITION;
				float fog : FOGC;
				float4 uv : TEXCOORD0;
				float4 color : COLOR0;
			};
			
			v2f vert(appdata_tree v)
			{
				v2f o;
				
				TerrainAnimateTree(v.vertex, LLDecodeGamma( v.color.w ));
				
				float3 viewpos = mul(UNITY_MATRIX_MV, v.vertex);
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.fog = o.pos.z;
				o.uv = v.texcoord;
				
				float4 lightDir;
				lightDir.w = _AO;
				
				float4 lightColor = LLDecodeGamma( UNITY_LIGHTMODEL_AMBIENT * 1.47 );
				for (int i = 0; i < 4; i++) {
					lightDir.xyz = _TerrainTreeLightDirections[i];
					float atten = 1.0;
					
					float occ = dot (lightDir.xyz, v.normal);
					occ = max(0, occ);
					occ *= atten;
					lightColor += _TerrainTreeLightColors[i] * occ;
				}
				
				lightColor.a = 1;
				o.color = lightColor * LLDecodeGamma( _Color );
				o.color.a = 1;
				return o; 
			}
			
			#pragma fragment frag 
			sampler2D _MainTex;
			uniform float _Cutoff;
			
			half4 frag(v2f input) : COLOR
			{
				half4 col = input.color;
				col.rgb *= 2.0f * LLDecodeTex( tex2D( _MainTex, input.uv.xy).rgb );
				
				return LLEncodeGamma( GoHDRApplyCorrection( col ) );
			}
			
			ENDCG
		}
	}
	
	SubShader {
		Fog { Mode Off }
		
		Pass {
			
			CGPROGRAM
			#include "../GoHDR.cginc"
			#include "../LinLighting.cginc"
			#pragma vertex vert
			#pragma exclude_renderers gles
			#include "../UnityCGGoHDR.cginc"
			#include "../TerrainEngineGoHDR.cginc"
			
			uniform float _Occlusion, _AO, _BaseLight;
			uniform float4 _Color;
			uniform float3 _TerrainTreeLightDirections[4];
			uniform float4 _TerrainTreeLightColors[4];
			
			struct v2f {
				float4 pos : POSITION;
				float fog : FOGC;
				float4 uv : TEXCOORD0;
				float4 color : COLOR0;
			};
			
			v2f vert(appdata_tree v)
			{
				v2f o;
				
				TerrainAnimateTree(v.vertex, LLDecodeGamma( v.color.w ));
				
				float3 viewpos = mul(UNITY_MATRIX_MV, v.vertex);
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.fog = o.pos.z;
				o.uv = v.texcoord;
				
				float4 lightDir;
				lightDir.w = _AO;
				
				float4 lightColor = LLDecodeGamma( UNITY_LIGHTMODEL_AMBIENT * 1.47 );
				for (int i = 0; i < 4; i++) {
					lightDir.xyz = _TerrainTreeLightDirections[i];
					float atten = 1.0;
					
					float occ = dot (lightDir.xyz, v.normal);
					occ = max(0, occ);
					occ *= atten;
					lightColor += _TerrainTreeLightColors[i] * occ;
				}
				
				lightColor.a = 1;
				o.color = lightColor * LLDecodeGamma( _Color );
				o.color.a = 1;
				return o; 
			}
			
			ENDCG
			
			SetTexture [_MainTex] {
				combine primary * texture double, primary
			}
		}
	}
}


//Original shader:

//Shader "Hidden/TerrainEngine/Soft Occlusion Bark rendertex" {
//	Properties {
//		_Color ("Main Color", Color) = (1,1,1,0)
//		_MainTex ("Main Texture", 2D) = "white" {  }
//		_BaseLight ("BaseLight", range (0, 1)) = 0.35
//		_AO ("Amb. Occlusion", range (0, 10)) = 2.4
//		_Scale ("Scale", Vector) = (1,1,1,1)
//		_SquashAmount ("Squash", Float) = 1
//	}
//	SubShader {
//		Fog { Mode Off }
//		Pass {
//			CGPROGRAM
//			#pragma vertex vert
//			#include "SH_Vertex.cginc"
//			#pragma fragment frag 
//			sampler2D _MainTex;
//			uniform float _Cutoff;
//			half4 frag(v2f input) : COLOR
//			{
//				half4 col = input.color;
//				col.rgb *= 2.0f * tex2D( _MainTex, input.uv.xy).rgb;
//				return col;
//			}
//			ENDCG
//		}
//	}
//	SubShader {
//		Fog { Mode Off }
//		Pass {
//			CGPROGRAM
//			#pragma vertex vert
//			#pragma exclude_renderers gles
//			#include "SH_Vertex.cginc"
//			ENDCG
//			
//			SetTexture [_MainTex] {
//				combine primary * texture double, primary
//			}
//		}
//	}
//	
//	Fallback Off
//}

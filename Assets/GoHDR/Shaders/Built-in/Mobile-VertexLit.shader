Shader "GoHDR/Mobile/VertexLit" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		
		
	}
	
	SubShader {
		Tags { "RenderType"="Opaque" }
		
		LOD 80
		
		Pass {
			Tags { "LightMode" = "Vertex" }
			
			Material {
				Diffuse (1,1,1,1)
				Ambient (1,1,1,1)
			} 
			
			Lighting On
			SetTexture [_MainTex] {
				Combine texture * primary DOUBLE, texture * primary
			} 
		}
		
		Pass {
			Tags { "LightMode" = "VertexLM" }
			
			BindChannels {
				Bind "Vertex", vertex
				Bind "normal", normal
				Bind "texcoord1", texcoord0 
				Bind "texcoord", texcoord1 
			}
			
			SetTexture [unity_Lightmap] {
				matrix [unity_LightmapMatrix]
				combine texture
			}
			
			SetTexture [_MainTex] {
				combine texture * previous DOUBLE, texture * primary
			}
		}
		
		Pass {
			Tags { "LightMode" = "VertexLMRGBM" }
			
			BindChannels {
				Bind "Vertex", vertex
				Bind "normal", normal
				Bind "texcoord1", texcoord0 
				Bind "texcoord", texcoord1 
			}
			
			SetTexture [unity_Lightmap] {
				matrix [unity_LightmapMatrix]
				combine texture * texture alpha DOUBLE
			}
			
			SetTexture [_MainTex] {
				combine texture * previous QUAD, texture * primary
			}
		}
		
		Pass {
			Name "ShadowCaster"
			Tags { "LightMode" = "ShadowCaster" }
			Fog {Mode Off}
			
			ZWrite On ZTest LEqual Cull Off
			Offset 1, 1
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"
			
			struct v2f { 
				V2F_SHADOW_CASTER;
			};
			
			v2f vert( appdata_base v )
			{
				v2f o;
				TRANSFER_SHADOW_CASTER(o)
				return o;
			}
			
			float4 frag( v2f i ) : COLOR
			{
				SHADOW_CASTER_FRAGMENT(i)
			}
			
			ENDCG
		}
		
		Pass {
			Name "ShadowCollector"
			Tags { "LightMode" = "ShadowCollector" }
			Fog {Mode Off}
			
			ZWrite On ZTest LEqual
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcollector
			
			#define SHADOW_COLLECTOR_PASS
			#include "UnityCG.cginc"
			
			struct appdata {
				float4 vertex : POSITION;
			};
			
			struct v2f {
				V2F_SHADOW_COLLECTOR;
			};
			
			v2f vert (appdata v)
			{
				v2f o;
				TRANSFER_SHADOW_COLLECTOR(o)
				return o;
			}
			
			fixed4 frag (v2f i) : COLOR
			{
				SHADOW_COLLECTOR_FRAGMENT(i)
			}
			
			ENDCG
		}
	}
}


//Original shader:

//// Simplified VertexLit shader. Differences from regular VertexLit one:
//// - no per-material color
//// - no specular
//// - no emission
//
//Shader "Mobile/VertexLit" {
//Properties {
//	_MainTex ("Base (RGB)", 2D) = "white" {}
//}
//
//SubShader {
//	Tags { "RenderType"="Opaque" }
//	LOD 80
//	
//	// Non-lightmapped
//	Pass {
//		Tags { "LightMode" = "Vertex" }
//		
//		Material {
//			Diffuse (1,1,1,1)
//			Ambient (1,1,1,1)
//		} 
//		Lighting On
//		SetTexture [_MainTex] {
//			Combine texture * primary DOUBLE, texture * primary
//		} 
//	}
//	
//	// Lightmapped, encoded as dLDR
//	Pass {
//		Tags { "LightMode" = "VertexLM" }
//		
//		BindChannels {
//			Bind "Vertex", vertex
//			Bind "normal", normal
//			Bind "texcoord1", texcoord0 // lightmap uses 2nd uv
//			Bind "texcoord", texcoord1 // main uses 1st uv
//		}
//		
//		SetTexture [unity_Lightmap] {
//			matrix [unity_LightmapMatrix]
//			combine texture
//		}
//		SetTexture [_MainTex] {
//			combine texture * previous DOUBLE, texture * primary
//		}
//	}
//	
//	// Lightmapped, encoded as RGBM
//	Pass {
//		Tags { "LightMode" = "VertexLMRGBM" }
//		
//		BindChannels {
//			Bind "Vertex", vertex
//			Bind "normal", normal
//			Bind "texcoord1", texcoord0 // lightmap uses 2nd uv
//			Bind "texcoord", texcoord1 // main uses 1st uv
//		}
//		
//		SetTexture [unity_Lightmap] {
//			matrix [unity_LightmapMatrix]
//			combine texture * texture alpha DOUBLE
//		}
//		SetTexture [_MainTex] {
//			combine texture * previous QUAD, texture * primary
//		}
//	}	
//	
//	// Pass to render object as a shadow caster
//	Pass 
//	{
//		Name "ShadowCaster"
//		Tags { "LightMode" = "ShadowCaster" }
//		
//		Fog {Mode Off}
//		ZWrite On ZTest LEqual Cull Off
//		Offset 1, 1
//
//		CGPROGRAM
//		#pragma vertex vert
//		#pragma fragment frag
//		#pragma multi_compile_shadowcaster
//		#include "UnityCG.cginc"
//
//		struct v2f { 
//			V2F_SHADOW_CASTER;
//		};
//
//		v2f vert( appdata_base v )
//		{
//			v2f o;
//			TRANSFER_SHADOW_CASTER(o)
//			return o;
//		}
//
//		float4 frag( v2f i ) : COLOR
//		{
//			SHADOW_CASTER_FRAGMENT(i)
//		}
//		ENDCG
//	}
//	
//	// Pass to render object as a shadow collector
//	// note: editor needs this pass as it has a collector pass.
//	Pass
//	{
//		Name "ShadowCollector"
//		Tags { "LightMode" = "ShadowCollector" }
//		
//		Fog {Mode Off}
//		ZWrite On ZTest LEqual
//
//		CGPROGRAM
//		#pragma vertex vert
//		#pragma fragment frag
//		#pragma multi_compile_shadowcollector
//
//		#define SHADOW_COLLECTOR_PASS
//		#include "UnityCG.cginc"
//
//		struct appdata {
//			float4 vertex : POSITION;
//		};
//
//		struct v2f {
//			V2F_SHADOW_COLLECTOR;
//		};
//
//		v2f vert (appdata v)
//		{
//			v2f o;
//			TRANSFER_SHADOW_COLLECTOR(o)
//			return o;
//		}
//
//		fixed4 frag (v2f i) : COLOR
//		{
//			SHADOW_COLLECTOR_FRAGMENT(i)
//		}
//		ENDCG
//	}
//}
//}

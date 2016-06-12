Shader "GoHDR/Nature/Tree Soft Occlusion Leaves" {
	Properties {
		_Color ("Main Color", Color) = (1,1,1,1)
		_MainTex ("Main Texture", 2D) = "white" {  }
		
		_Cutoff ("Alpha cutoff", Range(0.25,0.9)) = 0.5
		_BaseLight ("Base Light", Range(0, 1)) = 0.35
		_AO ("Amb. Occlusion", Range(0, 10)) = 2.4
		_Occlusion ("Dir Occlusion", Range(0, 20)) = 7.5
		
		_Scale ("Scale", Vector) = (1,1,1,1)
		_SquashAmount ("Squash", Float) = 1
	}
	
	SubShader {
		Tags {
			"Queue" = "Transparent-99"
			"IgnoreProjector"="True"
			"RenderType" = "TreeTransparentCutout"
		}
		
		Cull Off
		ColorMask RGB
		
		Pass {
			Lighting On
			
			CGPROGRAM
			#include "../../../GoHDR.cginc"
			#include "../../../LinLighting.cginc"
			#pragma vertex leaves
			#pragma fragment frag 
			#pragma glsl_no_auto_normalization
			#include "HLSLSupport.cginc"
			#include "UnityCG.cginc"
			#include "../TerrainEngineGoHDR.cginc"
			
			float _Occlusion, _AO, _BaseLight;
			fixed4 _Color;
			
			#ifdef USE_CUSTOM_LIGHT_DIR
				CBUFFER_START(UnityTerrainImposter)
				float3 _TerrainTreeLightDirections[4];
				float4 _TerrainTreeLightColors[4];
				CBUFFER_END
			#endif
			
			CBUFFER_START(UnityPerCamera2)
			float4x4 _CameraToWorld;
			CBUFFER_END
			
			float _HalfOverCutoff;
			
			struct v2f {
				float4 pos : POSITION;
				float4 uv : TEXCOORD0;
				fixed4 color : COLOR0;
			};
			
			v2f leaves(appdata_tree v)
			{
				v2f o;
				
				TerrainAnimateTree(v.vertex, LLDecodeGamma( v.color.w ));
				
				float3 viewpos = mul(UNITY_MATRIX_MV, v.vertex);
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uv = v.texcoord;
				
				float4 lightDir = 0;
				float4 lightColor = 0;
				lightDir.w = _AO;
				
				float4 light = LLDecodeGamma( UNITY_LIGHTMODEL_AMBIENT * 1.47 );
				
				for (int i = 0; i < 4; i++) {
					float atten = 1.0;
					
					#ifdef USE_CUSTOM_LIGHT_DIR
						lightDir.xyz = _TerrainTreeLightDirections[i];
						lightColor = _TerrainTreeLightColors[i];
						#else
						float3 toLight = unity_LightPosition[i].xyz - viewpos.xyz * unity_LightPosition[i].w;
						toLight.z *= -1.0;
						lightDir.xyz = mul( (float3x3)_CameraToWorld, normalize(toLight) );
						float lengthSq = dot(toLight, toLight);
						atten = 1.0 / (1.0 + lengthSq * unity_LightAtten[i].z);
						
						lightColor.rgb = unity_LightColor[i].rgb;
					#endif
					
					lightDir.xyz *= _Occlusion;
					float occ =  dot (v.tangent, lightDir);
					occ = max(0, occ);
					occ += _BaseLight;
					light += lightColor * (occ * atten);
				}
				
				o.color = light * LLDecodeGamma( _Color );
				o.color.a = 0.5 * _HalfOverCutoff;
				
				return o; 
			}
			
			v2f bark(appdata_tree v)
			{
				v2f o;
				
				TerrainAnimateTree(v.vertex, LLDecodeGamma( v.color.w ));
				
				float3 viewpos = mul(UNITY_MATRIX_MV, v.vertex);
				o.pos = mul(UNITY_MATRIX_MVP, v.vertex);
				o.uv = v.texcoord;
				
				float4 lightDir = 0;
				float4 lightColor = 0;
				lightDir.w = _AO;
				
				float4 light = LLDecodeGamma( UNITY_LIGHTMODEL_AMBIENT * 1.47 );
				
				for (int i = 0; i < 4; i++) {
					float atten = 1.0;
					
					#ifdef USE_CUSTOM_LIGHT_DIR
						lightDir.xyz = _TerrainTreeLightDirections[i];
						lightColor = _TerrainTreeLightColors[i];
						#else
						float3 toLight = unity_LightPosition[i].xyz - viewpos.xyz * unity_LightPosition[i].w;
						toLight.z *= -1.0;
						lightDir.xyz = mul( (float3x3)_CameraToWorld, normalize(toLight) );
						float lengthSq = dot(toLight, toLight);
						atten = 1.0 / (1.0 + lengthSq * unity_LightAtten[i].z);
						
						lightColor.rgb = unity_LightColor[i].rgb;
					#endif
					
					float diffuse = dot (v.normal, lightDir.xyz);
					diffuse = max(0, diffuse);
					diffuse *= _AO * v.tangent.w + _BaseLight;
					light += lightColor * (diffuse * atten);
				}
				
				light.a = 1;
				o.color = light * LLDecodeGamma( _Color );
				
				#ifdef WRITE_ALPHA_1
					o.color.a = 1;
				#endif
				
				return o; 
			}
			
			sampler2D _MainTex;
			fixed _Cutoff;
			
			fixed4 frag(v2f input) : COLOR
			{
				fixed4 c = LLDecodeTex( tex2D( _MainTex, input.uv.xy) );
				c.rgb *= 2.0f * input.color.rgb;
				
				clip (c.a - _Cutoff);
				
				return LLEncodeGamma( GoHDRApplyCorrection( c ) );
			}
			
			ENDCG
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
			#pragma glsl_no_auto_normalization
			#pragma multi_compile_shadowcaster
			#include "UnityCG.cginc"
			#include "TerrainEngine.cginc"
			
			struct v2f { 
				V2F_SHADOW_CASTER;
				float2 uv : TEXCOORD1;
			};
			
			struct appdata {
				float4 vertex : POSITION;
				fixed4 color : COLOR;
				float4 texcoord : TEXCOORD0;
			};
			
			v2f vert( appdata v )
			{
				v2f o;
				TerrainAnimateTree(v.vertex, v.color.w);
				TRANSFER_SHADOW_CASTER(o)
				o.uv = v.texcoord;
				return o;
			}
			
			sampler2D _MainTex;
			fixed _Cutoff;
			
			float4 frag( v2f i ) : COLOR
			{
				fixed4 texcol = tex2D( _MainTex, i.uv );
				clip( texcol.a - _Cutoff );
				SHADOW_CASTER_FRAGMENT(i)
			}
			
			ENDCG	
		}
	}
	
	SubShader {
		Tags {
			"Queue" = "Transparent-99"
			"IgnoreProjector"="True"
			"RenderType" = "TransparentCutout"
		}
		
		Cull Off
		ColorMask RGB
		Pass {
			Tags { "LightMode" = "Vertex" }
			
			AlphaTest GEqual [_Cutoff]
			Lighting On
			Material {
				Diffuse [_Color]
				Ambient [_Color]
			}
			SetTexture [_MainTex] { combine primary * texture DOUBLE, texture }
		}
	}
	
	Dependency "BillboardShader" = "Hidden/Nature/Tree Soft Occlusion Leaves Rendertex"
}


//Original shader:

//Shader "GoHDR/Nature/Tree Soft Occlusion Leaves" {
//	Properties {
//		_Color ("Main Color", Color) = (1,1,1,1)
//		_MainTex ("Main Texture", 2D) = "white" {  }
//		_Cutoff ("Alpha cutoff", Range(0.25,0.9)) = 0.5
//		_BaseLight ("Base Light", Range(0, 1)) = 0.35
//		_AO ("Amb. Occlusion", Range(0, 10)) = 2.4
//		_Occlusion ("Dir Occlusion", Range(0, 20)) = 7.5
//		
//		// These are here only to provide default values
//		_Scale ("Scale", Vector) = (1,1,1,1)
//		_SquashAmount ("Squash", Float) = 1
//	}
//	
//	SubShader {
//		Tags {
//			"Queue" = "Transparent-99"
//			"IgnoreProjector"="True"
//			"RenderType" = "TreeTransparentCutout"
//		}
//		Cull Off
//		ColorMask RGB
//		
//		Pass {
//			Lighting On
//		
//			CGPROGRAM
//			#pragma vertex leaves
//			#pragma fragment frag 
//			#pragma glsl_no_auto_normalization
//			#include "SH_Vertex.cginc"
//			
//			sampler2D _MainTex;
//			fixed _Cutoff;
//			
//			fixed4 frag(v2f input) : COLOR
//			{
//				fixed4 c = tex2D( _MainTex, input.uv.xy);
//				c.rgb *= 2.0f * input.color.rgb;
//				
//				clip (c.a - _Cutoff);
//				
//				return c;
//			}
//			ENDCG
//		}
//		
//		Pass {
//			Name "ShadowCaster"
//			Tags { "LightMode" = "ShadowCaster" }
//			
//			Fog {Mode Off}
//			ZWrite On ZTest LEqual Cull Off
//			Offset 1, 1
//	
//			CGPROGRAM
//			#pragma vertex vert
//			#pragma fragment frag
//			#pragma glsl_no_auto_normalization
//			#pragma multi_compile_shadowcaster
//			#include "UnityCG.cginc"
//			#include "TerrainEngine.cginc"
//			
//			struct v2f { 
//				V2F_SHADOW_CASTER;
//				float2 uv : TEXCOORD1;
//			};
//			
//			struct appdata {
//			    float4 vertex : POSITION;
//			    fixed4 color : COLOR;
//			    float4 texcoord : TEXCOORD0;
//			};
//			v2f vert( appdata v )
//			{
//				v2f o;
//				TerrainAnimateTree(v.vertex, v.color.w);
//				TRANSFER_SHADOW_CASTER(o)
//				o.uv = v.texcoord;
//				return o;
//			}
//			
//			sampler2D _MainTex;
//			fixed _Cutoff;
//					
//			float4 frag( v2f i ) : COLOR
//			{
//				fixed4 texcol = tex2D( _MainTex, i.uv );
//				clip( texcol.a - _Cutoff );
//				SHADOW_CASTER_FRAGMENT(i)
//			}
//			ENDCG	
//		}
//	}
//	
//	// This subshader is never actually used, but is only kept so
//	// that the tree mesh still assumes that normals are needed
//	// at build time (due to Lighting On in the pass). The subshader
//	// above does not actually use normals, so they are stripped out.
//	// We want to keep normals for backwards compatibility with Unity 4.2
//	// and earlier.
//	SubShader {
//		Tags {
//			"Queue" = "Transparent-99"
//			"IgnoreProjector"="True"
//			"RenderType" = "TransparentCutout"
//		}
//		Cull Off
//		ColorMask RGB
//		Pass {
//			Tags { "LightMode" = "Vertex" }
//			AlphaTest GEqual [_Cutoff]
//			Lighting On
//			Material {
//				Diffuse [_Color]
//				Ambient [_Color]
//			}
//			SetTexture [_MainTex] { combine primary * texture DOUBLE, texture }
//		}		
//	}
//
//	Dependency "BillboardShader" = "Hidden/Nature/Tree Soft Occlusion Leaves Rendertex"
//	Fallback Off
//}

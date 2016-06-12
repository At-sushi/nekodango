Shader "GoHDR/Mobile/Unlit (Supports Lightmap) CG" {
	Properties {
		_MainTex ("Base (RGB)", 2D) = "white" {}
		
		
	}
	
	SubShader {
		Tags {"Queue"="Geometry"  "IgnoreProjector"="True"}
		
		LOD 100
		
		Pass {
			Tags { LightMode = Vertex } 
			
			CGPROGRAM
			
			#include "../GoHDR.cginc"
			#include "../LinLighting.cginc"
			
			#pragma vertex vert  
			#pragma fragment frag
			
			#include "../UnityCGGoHDR.cginc"
			
			#define UNLIT_SHADER
			
			#ifndef UNLIT_SHADER
				fixed4 _Color;
				fixed4 _SpecColor;
				fixed4 _Emission;
				
				half _Shininess;
			#endif
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv_MainTex : TEXCOORD0;
				
				#ifndef UNLIT_SHADER
					fixed3 diff : COLOR;
					
					#ifdef ADD_SPECULAR
						fixed3 spec : TEXCOORD1;
					#endif

				#endif
			};
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
				o.uv_MainTex = TRANSFORM_TEX (v.texcoord, _MainTex);
				
				float3 viewpos = mul (UNITY_MATRIX_MV, v.vertex).xyz;
				
				#ifndef UNLIT_SHADER
					o.diff = LLDecodeGamma( UNITY_LIGHTMODEL_AMBIENT.xyz * 1.47 );
					
					#ifdef ADD_SPECULAR
						o.spec = 0;
						fixed3 viewDirObj = normalize( ObjSpaceViewDir(v.vertex) );
					#endif
					
					for (int i = 0; i < 4; i++) {
						half3 toLight = unity_LightPosition[i].xyz - viewpos.xyz * unity_LightPosition[i].w;
						half lengthSq = dot(toLight, toLight);
						half atten = 1.0 / (1.0 + lengthSq * unity_LightAtten[i].z );
						
						fixed3 lightDirObj = mul( (float3x3)UNITY_MATRIX_T_MV, toLight);	
						
						lightDirObj = normalize(lightDirObj);
						
						fixed diff = max ( 0, dot (v.normal, lightDirObj) );
						o.diff += unity_LightColor[i].rgb * (diff * atten);
						
						#ifdef ADD_SPECULAR
							fixed3 h = normalize (viewDirObj + lightDirObj);
							fixed nh = max (0, dot (v.normal, h));
							
							fixed spec = pow (nh, _Shininess * 128.0);
							o.spec += spec * unity_LightColor[i].rgb * atten;
						#endif
					}
					
					o.diff = (o.diff * _Color.rgb + _Emission.rgb) * 2;
					
					#ifdef ADD_SPECULAR
						o.spec *= _SpecColor.rgb;
					#endif

				#endif
				
				return o;
			}
			
			fixed4 frag (v2f i) : COLOR {
				fixed4 c;
				
				fixed4 mainTex = LLDecodeTex( tex2D (_MainTex, i.uv_MainTex) );
				
				#ifndef UNLIT_SHADER
					
					#ifdef ADD_SPECULAR
						c.rgb = (mainTex.rgb * i.diff + i.spec);
						#else
						c.rgb = (mainTex.rgb * i.diff);
					#endif
					
					#else
					c.rgb = mainTex.rgb;
				#endif
				
				c.a = 0;
				
				return LLEncodeGamma( GoHDRApplyCorrection( c ) );
			}
			
			ENDCG
		}
		
		Pass {
			Tags { "LightMode" = "VertexLM" }
			
			CGPROGRAM
			
			#include "../GoHDR.cginc"
			#include "../LinLighting.cginc"
			#pragma vertex vert  
			#pragma fragment frag
			
			#include "../UnityCGGoHDR.cginc"
			
			float4 unity_LightmapST;
			sampler2D unity_Lightmap;
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 lmap : TEXCOORD0;
			};
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
				
				o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				
				return o;
			}
			
			fixed4 frag (v2f i) : COLOR {
				fixed4 lmtex = tex2D(unity_Lightmap, i.lmap.xy);
				fixed3 lm = (8.0 * lmtex.a) * lmtex.rgb;
				
				return LLEncodeGamma( GoHDRApplyCorrection( fixed4(lm, 1) ) );
			}
			
			ENDCG
		}
		
		Pass {
			Tags { "LightMode" = "VertexLMRGBM" }
			
			CGPROGRAM
			
			#include "../GoHDR.cginc"
			#include "../LinLighting.cginc"
			#pragma vertex vert  
			#pragma fragment frag
			
			#include "../UnityCGGoHDR.cginc"
			
			float4 unity_LightmapST;
			sampler2D unity_Lightmap;
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 lmap : TEXCOORD0;
			};
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
				
				o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				
				return o;
			}
			
			fixed4 frag (v2f i) : COLOR {
				fixed4 lmtex = tex2D(unity_Lightmap, i.lmap.xy);
				fixed3 lm = (8.0 * lmtex.a) * lmtex.rgb;
				
				return LLEncodeGamma( GoHDRApplyCorrection( fixed4(lm, 1) ) );
			}
			
			ENDCG
		}
	}
	
	Fallback "Mobile/Unlit (Supports Lightmap)"
}


//Original shader:

//Shader "Mobile/Unlit (Supports Lightmap) CG" {
//Properties {
//	_MainTex ("Base (RGB)", 2D) = "white" {}
//}
//
//SubShader {
//	Tags {"Queue"="Geometry"  "IgnoreProjector"="True"}
//	LOD 100
//	
//	Pass {
//		Tags { LightMode = Vertex } 
//		CGPROGRAM
//		
//		#pragma vertex vert  
//		#pragma fragment frag
//		
//		#include "UnityCG.cginc"
//		
//		//#define ADD_SPECULAR
//		#define UNLIT_SHADER
//		
//		#ifndef UNLIT_SHADER
//		fixed4 _Color;
//		fixed4 _SpecColor;
//		fixed4 _Emission;
//		
//		half _Shininess;
//		#endif
//		
//		sampler2D _MainTex;
//		float4 _MainTex_ST;
//		
//		struct v2f {
//			float4 pos : SV_POSITION;
//			float2 uv_MainTex : TEXCOORD0;
//			
//			#ifndef UNLIT_SHADER
//				fixed3 diff : COLOR;
//				
//				#ifdef ADD_SPECULAR
//				fixed3 spec : TEXCOORD1;
//				#endif
//			#endif
//		};
//		
//		v2f vert (appdata_full v)
//		{
//		    v2f o;
//		    o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
//		    o.uv_MainTex = TRANSFORM_TEX (v.texcoord, _MainTex);
//			
//			float3 viewpos = mul (UNITY_MATRIX_MV, v.vertex).xyz;
//			
//			#ifndef UNLIT_SHADER
//				o.diff = UNITY_LIGHTMODEL_AMBIENT.xyz;
//				
//				#ifdef ADD_SPECULAR
//				o.spec = 0;
//				fixed3 viewDirObj = normalize( ObjSpaceViewDir(v.vertex) );
//				#endif
//				
//				//All calculations are in object space
//				for (int i = 0; i < 4; i++) {
//					half3 toLight = unity_LightPosition[i].xyz - viewpos.xyz * unity_LightPosition[i].w;
//					half lengthSq = dot(toLight, toLight);
//					half atten = 1.0 / (1.0 + lengthSq * unity_LightAtten[i].z );
//					
//					fixed3 lightDirObj = mul( (float3x3)UNITY_MATRIX_T_MV, toLight);	//View => model
//					
//					lightDirObj = normalize(lightDirObj);
//					
//					fixed diff = max ( 0, dot (v.normal, lightDirObj) );
//					o.diff += unity_LightColor[i].rgb * (diff * atten);
//					
//					#ifdef ADD_SPECULAR
//					fixed3 h = normalize (viewDirObj + lightDirObj);
//					fixed nh = max (0, dot (v.normal, h));
//					
//					fixed spec = pow (nh, _Shininess * 128.0);
//					o.spec += spec * unity_LightColor[i].rgb * atten;
//					#endif
//				}
//				
//				o.diff = (o.diff * _Color.rgb + _Emission.rgb) * 2;
//				#ifdef ADD_SPECULAR
//				o.spec *= _SpecColor.rgb;
//				#endif
//			#endif
//				
//			return o;
//		}
//		
//		fixed4 frag (v2f i) : COLOR {
//			fixed4 c;
//			
//			fixed4 mainTex = tex2D (_MainTex, i.uv_MainTex);
//			
//			#ifndef UNLIT_SHADER
//				#ifdef ADD_SPECULAR
//				c.rgb = (mainTex.rgb * i.diff + i.spec);
//				#else
//				c.rgb = (mainTex.rgb * i.diff);
//				#endif
//			#else
//				c.rgb = mainTex.rgb;
//			#endif
//			
//			c.a = 0;
//			
//			return c;
//		}
//		
//		ENDCG
//	}
//	
//	//Lightmap pass, dLDR;
//	Pass {
//		Tags { "LightMode" = "VertexLM" }
//		
//		CGPROGRAM
//		#pragma vertex vert  
//		#pragma fragment frag
//		
//		#include "UnityCG.cginc"
//		
//		float4 unity_LightmapST;
//		sampler2D unity_Lightmap;
//		
//		struct v2f {
//			float4 pos : SV_POSITION;
//			float2 lmap : TEXCOORD0;
//		};
//		
//		v2f vert (appdata_full v)
//		{
//		    v2f o;
//		    o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
//		    
//		    o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
//		    
//		    return o;
//		 }
//		
//		fixed4 frag (v2f i) : COLOR {
//			fixed4 lmtex = tex2D(unity_Lightmap, i.lmap.xy);
//			fixed3 lm = (8.0 * lmtex.a) * lmtex.rgb;
//			return fixed4(lm, 1);
//		}
//		
//		ENDCG
//	}
//	
//	//Lightmap pass, RGBM;
//	Pass {
//		Tags { "LightMode" = "VertexLMRGBM" }
//		
//		CGPROGRAM
//		#pragma vertex vert  
//		#pragma fragment frag
//		
//		#include "UnityCG.cginc"
//		
//		float4 unity_LightmapST;
//		sampler2D unity_Lightmap;
//		
//		struct v2f {
//			float4 pos : SV_POSITION;
//			float2 lmap : TEXCOORD0;
//		};
//		
//		v2f vert (appdata_full v)
//		{
//		    v2f o;
//		    o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
//		    
//		    o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
//		    
//		    return o;
//		 }
//		
//		fixed4 frag (v2f i) : COLOR {
//			fixed4 lmtex = tex2D(unity_Lightmap, i.lmap.xy);
//			fixed3 lm = (8.0 * lmtex.a) * lmtex.rgb;
//			return fixed4(lm, 1);
//		}
//		
//		ENDCG
//	}
//}
//
//Fallback "Mobile/Unlit (Supports Lightmap)"
//}

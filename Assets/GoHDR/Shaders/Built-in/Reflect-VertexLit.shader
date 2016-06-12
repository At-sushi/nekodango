Shader "GoHDR/Reflective/VertexLit CG" {
	Properties {
		_Color ("Main Color", Color) = (1,1,1,1)
		_SpecColor ("Spec Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range (0.03, 1)) = 0.7
		_ReflectColor ("Reflection Color", Color) = (1,1,1,0.5)
		_MainTex ("Base (RGB) RefStrength (A)", 2D) = "white" {} 
		_Cube ("Reflection Cubemap", Cube) = "_Skybox" { TexGen CubeReflect }
		
		
	}
	
	Category {
		Tags { "RenderType"="Opaque" }
		
		LOD 150
		
		SubShader {
			
			Pass {
				Name "BASE"
				Tags {"LightMode" = "Always"}
				
				CGPROGRAM
				
				#include "../GoHDR.cginc"
				#include "../LinLighting.cginc"
				#pragma exclude_renderers gles xbox360 ps3
				#pragma vertex vert
				#pragma fragment frag
				#pragma fragmentoption ARB_precision_hint_fastest
				#include "../UnityCGGoHDR.cginc"
				
				struct v2f {
					float4 pos : SV_POSITION;
					float2 uv : TEXCOORD0;
					float3 I : TEXCOORD1;
				};
				
				uniform float4 _MainTex_ST;
				
				v2f vert(appdata_tan v)
				{
					v2f o;
					o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
					o.uv = TRANSFORM_TEX(v.texcoord,_MainTex);
					
					float3 viewDir = WorldSpaceViewDir( v.vertex );
					float3 worldN = mul((float3x3)_Object2World, v.normal * unity_Scale.w);
					o.I = reflect( -viewDir, worldN );
					
					return o; 
				}
				
				uniform sampler2D _MainTex;
				uniform samplerCUBE _Cube;
				uniform fixed4 _ReflectColor;
				
				fixed4 frag (v2f i) : COLOR
				{
					fixed4 texcol = LLDecodeTex( tex2D (_MainTex, i.uv) );
					fixed4 reflcol = LLDecodeTex( texCUBE( _Cube, i.I ) );
					reflcol *= texcol.a;
					
					return LLEncodeGamma( GoHDRApplyCorrection( reflcol * LLDecodeGamma( _ReflectColor ) ) );
				} 
				
				ENDCG
			}
			
			Pass {
				Tags { "LightMode" = "Vertex" }
				
				Blend One One
				ZWrite Off
				Fog { Color (0,0,0,0) }
				
				CGPROGRAM
				
				#include "../GoHDR.cginc"
				#include "../LinLighting.cginc"
				#pragma exclude_renderers shaderonly
				#pragma vertex vert
				#pragma fragment frag
				#pragma fragmentoption ARB_precision_hint_fastest
				
				#include "../UnityCGGoHDR.cginc"
				
				#define ADD_SPECULAR
				
				struct v2f {
					float4 pos : SV_POSITION;
					float2 uv : TEXCOORD0;
					fixed4 diff : COLOR;
					
					#ifdef ADD_SPECULAR
						fixed3 spec : COLOR1;
					#endif
				};
				
				sampler2D _MainTex;
				float4 _MainTex_ST;
				
				fixed4 _ReflectColor;
				fixed4 _SpecColor;
				
				fixed4 _Color;
				
				half _Shininess;
				
				v2f vert (appdata_full v)
				{
					v2f o;
					o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
					o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
					
					float3 viewpos = mul (UNITY_MATRIX_MV, v.vertex).xyz;
					
					o.diff = LLDecodeGamma( UNITY_LIGHTMODEL_AMBIENT.xyzw * 1.47 );
					
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
						o.diff += unity_LightColor[i].rgba * (diff * atten);
						
						#ifdef ADD_SPECULAR
							fixed3 h = normalize (viewDirObj + lightDirObj);
							fixed nh = max (0, dot (v.normal, h));
							
							fixed spec = pow (nh, _Shininess * 128.0);
							o.spec += spec * unity_LightColor[i].rgb * atten;
						#endif
					}
					
					o.diff = (o.diff * LLDecodeGamma( _Color.rgba ));
					
					#ifdef ADD_SPECULAR
						o.spec *= LLDecodeGamma( _SpecColor.rgb ) * 2;
					#endif
					
					return o;
				}
				
				fixed4 frag (v2f i) : COLOR
				{
					fixed4 temp = LLDecodeTex( tex2D (_MainTex, i.uv).rgba );	
					fixed4 c;
					c.rgb = (temp.rgb * i.diff.rgb + temp.a * i.spec.rgb );
					
					c.a = temp.a * (i.diff.a + Luminance(i.spec.rgb) * LLDecodeGamma( _SpecColor.a ));
					
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
			
			Pass {
				Name "Caster"
				Tags { "LightMode" = "ShadowCaster" }
				
				Offset 1, 1
				Fog {Mode Off}
				
				ZWrite On ZTest LEqual Cull Off
				
				CGPROGRAM
				#pragma vertex vert
				#pragma fragment frag
				#pragma multi_compile_shadowcaster
				#pragma fragmentoption ARB_precision_hint_fastest
				#include "UnityCG.cginc"
				
				struct v2f { 
					V2F_SHADOW_CASTER;
					float2  uv : TEXCOORD1;
				};
				
				uniform float4 _MainTex_ST;
				
				v2f vert( appdata_base v )
				{
					v2f o;
					TRANSFER_SHADOW_CASTER(o)
					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
					return o;
				}
				
				uniform sampler2D _MainTex;
				uniform fixed _Cutoff;
				uniform fixed4 _Color;
				
				float4 frag( v2f i ) : COLOR
				{
					fixed4 texcol = tex2D( _MainTex, i.uv );
					clip( texcol.a*_Color.a - _Cutoff );
					
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
				#pragma fragmentoption ARB_precision_hint_fastest
				#pragma multi_compile_shadowcollector
				
				#define SHADOW_COLLECTOR_PASS
				#include "UnityCG.cginc"
				
				struct v2f {
					V2F_SHADOW_COLLECTOR;
					float2  uv : TEXCOORD5;
				};
				
				uniform float4 _MainTex_ST;
				
				v2f vert (appdata_base v)
				{
					v2f o;
					TRANSFER_SHADOW_COLLECTOR(o)
					o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
					return o;
				}
				
				uniform sampler2D _MainTex;
				uniform fixed _Cutoff;
				uniform fixed4 _Color;
				
				fixed4 frag (v2f i) : COLOR
				{
					fixed4 texcol = tex2D( _MainTex, i.uv );
					clip( texcol.a*_Color.a - _Cutoff );
					
					SHADOW_COLLECTOR_FRAGMENT(i)
				}
				
				ENDCG
			}
		}
		
		SubShader {
			Pass {
				Name "BASE"
				Tags { "LightMode" = "Vertex" }
				
				Material {
					Diffuse [_Color]
					Ambient (1,1,1,1)
					Shininess [_Shininess]
					Specular [_SpecColor]
				}
				
				Lighting On
				SeparateSpecular on
				SetTexture [_MainTex] {
					combine texture * primary DOUBLE, texture * primary
				}
				
				SetTexture [_Cube] {
					combine texture * previous alpha + previous, previous
				}
			}
		}
		
		Fallback "GoHDR/VertexLit CG"
	}
}


//Original shader:

//Shader "Reflective/VertexLit CG" {
//Properties {
//	_Color ("Main Color", Color) = (1,1,1,1)
//	_SpecColor ("Spec Color", Color) = (1,1,1,1)
//	_Shininess ("Shininess", Range (0.03, 1)) = 0.7
//	_ReflectColor ("Reflection Color", Color) = (1,1,1,0.5)
//	_MainTex ("Base (RGB) RefStrength (A)", 2D) = "white" {} 
//	_Cube ("Reflection Cubemap", Cube) = "_Skybox" { TexGen CubeReflect }
//}
//
//Category {
//	Tags { "RenderType"="Opaque" }
//	LOD 150
//
//	// ------------------------------------------------------------------
//	// Pixel shader cards
//	
//	SubShader {
//	
//		// First pass does reflection cubemap
//		Pass { 
//			Name "BASE"
//			Tags {"LightMode" = "Always"}
//CGPROGRAM
//#pragma exclude_renderers gles xbox360 ps3
//#pragma vertex vert
//#pragma fragment frag
//#pragma fragmentoption ARB_precision_hint_fastest
//#include "UnityCG.cginc"
//
//struct v2f {
//	float4 pos : SV_POSITION;
//	float2 uv : TEXCOORD0;
//	float3 I : TEXCOORD1;
//};
//
//uniform float4 _MainTex_ST;
//
//v2f vert(appdata_tan v)
//{
//	v2f o;
//	o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
//	o.uv = TRANSFORM_TEX(v.texcoord,_MainTex);
//
//	// calculate world space reflection vector	
//	float3 viewDir = WorldSpaceViewDir( v.vertex );
//	float3 worldN = mul((float3x3)_Object2World, v.normal * unity_Scale.w);
//	o.I = reflect( -viewDir, worldN );
//	
//	return o; 
//}
//
//uniform sampler2D _MainTex;
//uniform samplerCUBE _Cube;
//uniform fixed4 _ReflectColor;
//
//fixed4 frag (v2f i) : COLOR
//{
//	fixed4 texcol = tex2D (_MainTex, i.uv);
//	fixed4 reflcol = texCUBE( _Cube, i.I );
//	reflcol *= texcol.a;
//	//return fixed4(reflcol.rgb * texcol.a, 1);
//	//return 0;
//	return reflcol * _ReflectColor;
//} 
//ENDCG
//		}
//		
//		// Vertex Lit
//		Pass {
//			Tags { "LightMode" = "Vertex" }
//			Blend One One
//			ZWrite Off
//			Fog { Color (0,0,0,0) }
//CGPROGRAM
//#pragma exclude_renderers shaderonly
//#pragma vertex vert
//#pragma fragment frag
//#pragma fragmentoption ARB_precision_hint_fastest
//
//#include "UnityCG.cginc"
//
//#define ADD_SPECULAR
//
//struct v2f {
//	float4 pos : SV_POSITION;
//	float2 uv : TEXCOORD0;
//	fixed4 diff : COLOR;
//	
//	#ifdef ADD_SPECULAR
//	fixed3 spec : COLOR1;
//	#endif
//};
//
//sampler2D _MainTex;
//float4 _MainTex_ST;
//
//fixed4 _ReflectColor;
//fixed4 _SpecColor;
//
//fixed4 _Color;
//
//half _Shininess;
//
//v2f vert (appdata_full v)
//{
//    v2f o;
//    o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
//    o.uv = TRANSFORM_TEX (v.texcoord, _MainTex);
//	
//	float3 viewpos = mul (UNITY_MATRIX_MV, v.vertex).xyz;
//	
//	o.diff = UNITY_LIGHTMODEL_AMBIENT.xyzw;
//	
//	#ifdef ADD_SPECULAR
//	o.spec = 0;
//	fixed3 viewDirObj = normalize( ObjSpaceViewDir(v.vertex) );
//	#endif
//	
//	//All calculations are in object space
//	for (int i = 0; i < 4; i++) {
//		half3 toLight = unity_LightPosition[i].xyz - viewpos.xyz * unity_LightPosition[i].w;
//		half lengthSq = dot(toLight, toLight);
//		half atten = 1.0 / (1.0 + lengthSq * unity_LightAtten[i].z );
//		
//		fixed3 lightDirObj = mul( (float3x3)UNITY_MATRIX_T_MV, toLight);	//View => model
//		
//		lightDirObj = normalize(lightDirObj);
//		
//		fixed diff = max ( 0, dot (v.normal, lightDirObj) );
//		o.diff += unity_LightColor[i].rgba * (diff * atten);
//		
//		#ifdef ADD_SPECULAR
//		fixed3 h = normalize (viewDirObj + lightDirObj);
//		fixed nh = max (0, dot (v.normal, h));
//		
//		fixed spec = pow (nh, _Shininess * 128.0);
//		o.spec += spec * unity_LightColor[i].rgb * atten;
//		#endif
//	}
//	
//	o.diff = (o.diff * _Color.rgba);// * 2;	//No *2 - magic???
//	#ifdef ADD_SPECULAR
//	o.spec *= _SpecColor.rgb * 2;
//	#endif
//	
//	return o;
//}
//
//fixed4 frag (v2f i) : COLOR
//{
//	fixed4 temp = tex2D (_MainTex, i.uv).rgba;	
//	fixed4 c;
//	c.rgb = (temp.rgb * i.diff.rgb + temp.a * i.spec.rgb );
//	//c.rgb = (temp.a * i.spec.rgb ) * 2;
//	//c.rgb = (temp.rgb * i.diff.rgb) * 0.5;
//	c.a = temp.a * (i.diff.a + Luminance(i.spec.rgb) * _SpecColor.a);
//	//return fixed4(0,0,0,0);
//	return c;
//} 
//ENDCG
////			SetTexture[_MainTex] {}
//		}
//		
//		//Lightmap pass, dLDR;
//		Pass {
//			Tags { "LightMode" = "VertexLM" }
//			
//			CGPROGRAM
//			#pragma vertex vert  
//			#pragma fragment frag
//			
//			#include "UnityCG.cginc"
//			
//			float4 unity_LightmapST;
//			sampler2D unity_Lightmap;
//			
//			struct v2f {
//				float4 pos : SV_POSITION;
//				float2 lmap : TEXCOORD0;
//			};
//			
//			v2f vert (appdata_full v)
//			{
//			    v2f o;
//			    o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
//			    
//			    o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
//			    
//			    return o;
//			 }
//			
//			fixed4 frag (v2f i) : COLOR {
//				fixed4 lmtex = tex2D(unity_Lightmap, i.lmap.xy);
//				fixed3 lm = (8.0 * lmtex.a) * lmtex.rgb;
//				return fixed4(lm, 1);
//			}
//			
//			ENDCG
//		}
//		
//		//Lightmap pass, RGBM;
//		Pass {
//			Tags { "LightMode" = "VertexLMRGBM" }
//			
//			CGPROGRAM
//			#pragma vertex vert  
//			#pragma fragment frag
//			
//			#include "UnityCG.cginc"
//			
//			float4 unity_LightmapST;
//			sampler2D unity_Lightmap;
//			
//			struct v2f {
//				float4 pos : SV_POSITION;
//				float2 lmap : TEXCOORD0;
//			};
//			
//			v2f vert (appdata_full v)
//			{
//			    v2f o;
//			    o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
//			    
//			    o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
//			    
//			    return o;
//			 }
//			
//			fixed4 frag (v2f i) : COLOR {
//				fixed4 lmtex = tex2D(unity_Lightmap, i.lmap.xy);
//				fixed3 lm = (8.0 * lmtex.a) * lmtex.rgb;
//				return fixed4(lm, 1);
//			}
//			
//			ENDCG
//		}
//	
//		Pass {
//			Name "Caster"
//			Tags { "LightMode" = "ShadowCaster" }
//			Offset 1, 1
//			
//			Fog {Mode Off}
//			ZWrite On ZTest LEqual Cull Off
//	
//		CGPROGRAM
//		#pragma vertex vert
//		#pragma fragment frag
//		#pragma multi_compile_shadowcaster
//		#pragma fragmentoption ARB_precision_hint_fastest
//		#include "UnityCG.cginc"
//		
//		struct v2f { 
//			V2F_SHADOW_CASTER;
//			float2  uv : TEXCOORD1;
//		};
//		
//		uniform float4 _MainTex_ST;
//		
//		v2f vert( appdata_base v )
//		{
//			v2f o;
//			TRANSFER_SHADOW_CASTER(o)
//			o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
//			return o;
//		}
//		
//		uniform sampler2D _MainTex;
//		uniform fixed _Cutoff;
//		uniform fixed4 _Color;
//		
//		float4 frag( v2f i ) : COLOR
//		{
//			fixed4 texcol = tex2D( _MainTex, i.uv );
//			clip( texcol.a*_Color.a - _Cutoff );
//			
//			SHADOW_CASTER_FRAGMENT(i)
//		}
//		ENDCG
//		
//			}
//			
//			// Pass to render object as a shadow collector
//			Pass {
//				Name "ShadowCollector"
//				Tags { "LightMode" = "ShadowCollector" }
//				
//				Fog {Mode Off}
//				ZWrite On ZTest LEqual
//		
//		CGPROGRAM
//		#pragma vertex vert
//		#pragma fragment frag
//		#pragma fragmentoption ARB_precision_hint_fastest
//		#pragma multi_compile_shadowcollector
//		
//		#define SHADOW_COLLECTOR_PASS
//		#include "UnityCG.cginc"
//		
//		struct v2f {
//			V2F_SHADOW_COLLECTOR;
//			float2  uv : TEXCOORD5;
//		};
//		
//		uniform float4 _MainTex_ST;
//		
//		v2f vert (appdata_base v)
//		{
//			v2f o;
//			TRANSFER_SHADOW_COLLECTOR(o)
//			o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
//			return o;
//		}
//		
//		uniform sampler2D _MainTex;
//		uniform fixed _Cutoff;
//		uniform fixed4 _Color;
//		
//		fixed4 frag (v2f i) : COLOR
//		{
//			fixed4 texcol = tex2D( _MainTex, i.uv );
//			clip( texcol.a*_Color.a - _Cutoff );
//			
//			SHADOW_COLLECTOR_FRAGMENT(i)
//		}
//		ENDCG
//	}
//}
//	
//	// ------------------------------------------------------------------
//	// Old cards
//	
//	SubShader {
//		Pass { 
//			Name "BASE"
//			Tags { "LightMode" = "Vertex" }
//			Material {
//				Diffuse [_Color]
//				Ambient (1,1,1,1)
//				Shininess [_Shininess]
//				Specular [_SpecColor]
//			}
//			Lighting On
//			SeparateSpecular on
//			SetTexture [_MainTex] {
//				combine texture * primary DOUBLE, texture * primary
//			}
//			SetTexture [_Cube] {
//				combine texture * previous alpha + previous, previous
//			}
//		}
//	}
//}
//
//// Fallback for cards that don't do cubemapping
//FallBack "VertexLit"
//}

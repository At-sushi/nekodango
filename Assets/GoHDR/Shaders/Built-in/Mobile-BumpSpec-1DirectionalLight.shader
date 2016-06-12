Shader "GoHDR/Mobile/Bumped Specular (1 Directional Light)" {
	Properties {
		_Shininess ("Shininess", Range (0.03, 1)) = 0.078125
		_MainTex ("Base (RGB) Gloss (A)", 2D) = "white" {}
		_BumpMap ("Normalmap", 2D) = "bump" {}
		
		
	}
	
	SubShader {
		Tags { "RenderType"="Opaque" }
		
		LOD 250
		
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			
			CGPROGRAM
			
			#include "../GoHDR.cginc"
			#include "../LinLighting.cginc"
			#pragma vertex vert_surf
			#pragma fragment frag_surf
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_fwdbase nolightmap nodirlightmap novertexlight
			#include "HLSLSupport.cginc"
			#include "UnityShaderVariables.cginc"
			#define UNITY_PASS_FORWARDBASE
			#include "../UnityCGGoHDR.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			#define INTERNAL_DATA
			#define WorldReflectionVector(data,normal) data.worldRefl
			#define WorldNormalVector(data,normal) normal
			
			inline fixed4 LightingMobileBlinnPhong (SurfaceOutput s, fixed3 lightDir, fixed3 halfDir, fixed atten)
			{
				fixed diff = max (0, dot (s.Normal, lightDir));
				fixed nh = max (0, dot (s.Normal, halfDir));
				fixed spec = pow (nh, s.Specular*128) * s.Gloss;
				
				fixed4 c;
				c.rgb = (s.Albedo * _LightColor0.rgb * diff + _LightColor0.rgb * spec) * (atten*2);
				c.a = 0.0;
				return c;
			}
			
			sampler2D _MainTex;
			sampler2D _BumpMap;
			half _Shininess;
			
			struct Input {
				float2 uv_MainTex;
			};
			
			void surf (Input IN, inout SurfaceOutput o) {
				fixed4 tex = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) );
				o.Albedo = tex.rgb;
				o.Gloss = tex.a;
				o.Alpha = tex.a;
				o.Specular = _Shininess;
				o.Normal = UnpackNormal (tex2D(_BumpMap, IN.uv_MainTex));
			}
			
			#ifdef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float2 pack0 : TEXCOORD0;
					fixed3 lightDir : TEXCOORD1;
					fixed3 vlight : TEXCOORD2;
					fixed3 viewDir : TEXCOORD3;
					LIGHTING_COORDS(4,5)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float2 pack0 : TEXCOORD0;
					float2 lmap : TEXCOORD1;
					LIGHTING_COORDS(2,3)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				float4 unity_LightmapST;
			#endif
			
			float4 _MainTex_ST;
			
			v2f_surf vert_surf (appdata_full v) {
				v2f_surf o;
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
				o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				
				#ifndef LIGHTMAP_OFF
					o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				#endif
				
				float3 worldN = mul((float3x3)_Object2World, SCALED_NORMAL);
				TANGENT_SPACE_ROTATION;
				float3 lightDir = mul (rotation, ObjSpaceLightDir(v.vertex));
				
				#ifdef LIGHTMAP_OFF
					o.lightDir = lightDir;
				#endif
				
				#ifdef LIGHTMAP_OFF
					float3 viewDirForLight = mul (rotation, ObjSpaceViewDir(v.vertex));
					o.viewDir = normalize (lightDir + normalize(viewDirForLight));
				#endif
				
				#ifdef LIGHTMAP_OFF
					o.vlight = LLDecodeGamma( UNITY_LIGHTMODEL_AMBIENT.rgb * 1.47 );
				#endif
				
				TRANSFER_VERTEX_TO_FRAGMENT(o);
				return o;
			}
			
			#ifndef LIGHTMAP_OFF
				sampler2D unity_Lightmap;
				
				#ifndef DIRLIGHTMAP_OFF
					sampler2D unity_LightmapInd;
				#endif

			#endif
			
			fixed4 frag_surf (v2f_surf IN) : COLOR {
				Input surfIN;
				surfIN.uv_MainTex = IN.pack0.xy;
				
				#ifdef UNITY_COMPILER_HLSL
					SurfaceOutput o = (SurfaceOutput)0;
					#else
					SurfaceOutput o;
				#endif
				
				o.Albedo = 0.0;
				o.Emission = 0.0;
				o.Specular = 0.0;
				o.Alpha = 0.0;
				o.Gloss = 0.0;
				surf (surfIN, o);
				fixed atten = LIGHT_ATTENUATION(IN);
				fixed4 c = 0;
				
				#ifdef LIGHTMAP_OFF
					c = LightingMobileBlinnPhong (o, IN.lightDir, IN.viewDir, atten);
				#endif
				
				#ifdef LIGHTMAP_OFF
					c.rgb += o.Albedo * IN.vlight;
				#endif
				
				#ifndef LIGHTMAP_OFF
					
					#ifndef DIRLIGHTMAP_OFF
						fixed4 lmtex = tex2D(unity_Lightmap, IN.lmap.xy);
						fixed4 lmIndTex = tex2D(unity_LightmapInd, IN.lmap.xy);
						half3 lm = LightingLambert_DirLightmap(o, lmtex, lmIndTex, 1).rgb;
						#else 
						fixed4 lmtex = tex2D(unity_Lightmap, IN.lmap.xy);
						fixed3 lm = DecodeLightmap (lmtex);
					#endif
					
					#ifdef SHADOWS_SCREEN
						#if (defined(SHADER_API_GLES) || defined(SHADER_API_GLES3)) && defined(SHADER_API_MOBILE)
						c.rgb += o.Albedo * min(lm, atten*2);
						#else
						c.rgb += o.Albedo * max(min(lm,(atten*2)*lmtex.rgb), lm*atten);
					#endif
					
					#else 
					c.rgb += o.Albedo * lm;
				#endif
				
				c.a = o.Alpha;
			#endif
			
			return LLEncodeGamma( GoHDRApplyCorrection( c ) );
		}
		
		ENDCG
	}
}

Fallback "GoHDR/Mobile/VertexLit"
}


//Original shader:

//// Simplified Bumped Specular shader. Differences from regular Bumped Specular one:
//// - no Main Color nor Specular Color
//// - specular lighting directions are approximated per vertex
//// - writes zero to alpha channel
//// - Normalmap uses Tiling/Offset of the Base texture
//// - no Deferred Lighting support
//// - no Lightmap support
//// - supports ONLY 1 directional light. Other lights are completely ignored.
//
//Shader "Mobile/Bumped Specular (1 Directional Light)" {
//Properties {
//	_Shininess ("Shininess", Range (0.03, 1)) = 0.078125
//	_MainTex ("Base (RGB) Gloss (A)", 2D) = "white" {}
//	_BumpMap ("Normalmap", 2D) = "bump" {}
//}
//SubShader { 
//	Tags { "RenderType"="Opaque" }
//	LOD 250
//	
//CGPROGRAM
//#pragma surface surf MobileBlinnPhong exclude_path:prepass nolightmap noforwardadd halfasview novertexlights
//
//inline fixed4 LightingMobileBlinnPhong (SurfaceOutput s, fixed3 lightDir, fixed3 halfDir, fixed atten)
//{
//	fixed diff = max (0, dot (s.Normal, lightDir));
//	fixed nh = max (0, dot (s.Normal, halfDir));
//	fixed spec = pow (nh, s.Specular*128) * s.Gloss;
//	
//	fixed4 c;
//	c.rgb = (s.Albedo * _LightColor0.rgb * diff + _LightColor0.rgb * spec) * (atten*2);
//	c.a = 0.0;
//	return c;
//}
//
//sampler2D _MainTex;
//sampler2D _BumpMap;
//half _Shininess;
//
//struct Input {
//	float2 uv_MainTex;
//};
//
//void surf (Input IN, inout SurfaceOutput o) {
//	fixed4 tex = tex2D(_MainTex, IN.uv_MainTex);
//	o.Albedo = tex.rgb;
//	o.Gloss = tex.a;
//	o.Alpha = tex.a;
//	o.Specular = _Shininess;
//	o.Normal = UnpackNormal (tex2D(_BumpMap, IN.uv_MainTex));
//}
//ENDCG
//}
//
//FallBack "Mobile/VertexLit"
//}

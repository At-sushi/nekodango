Shader "GoHDR/Custom/Terrain_3Textures" {
	Properties {
		_Splat0 ("Layer 1", 2D) = "white" {}
		_Splat1 ("Layer 2", 2D) = "white" {}		
		_Splat2 ("Layer 3", 2D) = "white" {}
		_Control ("Control (RGBA)", 2D) = "white" {}
		_MainTex ("Never Used", 2D) = "white" {}
		
		
	}
	
	SubShader {
		Tags {
			"SplatCount" = "3"
			"RenderType" = "Opaque"
		}
		
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			
			CGPROGRAM
			
			#include "../GoHDR.cginc"
			#include "../LinLighting.cginc"
			#pragma vertex vert_surf
			#pragma fragment frag_surf
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_fwdbase nodirlightmap
			#include "HLSLSupport.cginc"
			#include "UnityShaderVariables.cginc"
			#define UNITY_PASS_FORWARDBASE
			#include "../UnityCGGoHDR.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			#define INTERNAL_DATA
			#define WorldReflectionVector(data,normal) data.worldRefl
			#define WorldNormalVector(data,normal) normal
			
			#pragma exclude_renderers xbox360 ps3 flash
			
			inline fixed4 LightingT4M (SurfaceOutput s, fixed3 lightDir, fixed atten)
			{
				fixed diff = max (0, dot (s.Normal, lightDir));
				fixed4 c;
				c.rgb = s.Albedo * _LightColor0.rgb * (diff * atten * 2);
				c.a = 0.0;
				return c;
			}
			
			struct Input {
				float2 uv_Control : TEXCOORD0;
				float2 uv_Splat0 : TEXCOORD1;
				float2 uv_Splat1 : TEXCOORD2;
				float2 uv_Splat2 : TEXCOORD3;
			};
			
			sampler2D _Control;
			sampler2D _Splat0,_Splat1,_Splat2;
			
			void surf (Input IN, inout SurfaceOutput o) {
				fixed4 splat_control = tex2D (_Control, IN.uv_Control).rgba;
				
				fixed3 lay1 = LLDecodeTex( tex2D (_Splat0, IN.uv_Splat0).rgb );
				fixed3 lay2 = LLDecodeTex( tex2D (_Splat1, IN.uv_Splat1).rgb );
				fixed3 lay3 = LLDecodeTex( tex2D (_Splat2, IN.uv_Splat2).rgb );
				o.Alpha = 0.0;
				o.Albedo.rgb = lay1 * splat_control.r + lay2 * splat_control.g + lay3 * splat_control.b;
			}
			
			#ifdef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					float4 pack1 : TEXCOORD1;
					fixed3 normal : TEXCOORD2;
					fixed3 vlight : TEXCOORD3;
					LIGHTING_COORDS(4,5)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					float4 pack1 : TEXCOORD1;
					float2 lmap : TEXCOORD2;
					LIGHTING_COORDS(3,4)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				float4 unity_LightmapST;
			#endif
			
			float4 _Control_ST;
			float4 _Splat0_ST;
			float4 _Splat1_ST;
			float4 _Splat2_ST;
			
			v2f_surf vert_surf (appdata_full v) {
				v2f_surf o;
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
				o.pack0.xy = TRANSFORM_TEX(v.texcoord, _Control);
				o.pack0.zw = TRANSFORM_TEX(v.texcoord, _Splat0);
				o.pack1.xy = TRANSFORM_TEX(v.texcoord, _Splat1);
				o.pack1.zw = TRANSFORM_TEX(v.texcoord, _Splat2);
				
				#ifndef LIGHTMAP_OFF
					o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				#endif
				
				float3 worldN = mul((float3x3)_Object2World, SCALED_NORMAL);
				
				#ifdef LIGHTMAP_OFF
					o.normal = worldN;
				#endif
				
				#ifdef LIGHTMAP_OFF
					float3 shlight = ShadeSH9 (float4(worldN,1.0));
					o.vlight = shlight;
					
					#ifdef VERTEXLIGHT_ON
						float3 worldPos = mul(_Object2World, v.vertex).xyz;
						o.vlight += Shade4PointLights (
						unity_4LightPosX0, unity_4LightPosY0, unity_4LightPosZ0,
						unity_LightColor[0].rgb, unity_LightColor[1].rgb, unity_LightColor[2].rgb, unity_LightColor[3].rgb,
						unity_4LightAtten0, worldPos, worldN );
					#endif

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
				surfIN.uv_Control = IN.pack0.xy;
				surfIN.uv_Splat0 = IN.pack0.zw;
				surfIN.uv_Splat1 = IN.pack1.xy;
				surfIN.uv_Splat2 = IN.pack1.zw;
				
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
				
				#ifdef LIGHTMAP_OFF
					o.Normal = IN.normal;
				#endif
				
				surf (surfIN, o);
				fixed atten = LIGHT_ATTENUATION(IN);
				fixed4 c = 0;
				
				#ifdef LIGHTMAP_OFF
					c = LightingT4M (o, _WorldSpaceLightPos0.xyz, atten);
				#endif
				
				#ifdef LIGHTMAP_OFF
					c.rgb += o.Albedo * IN.vlight;
				#endif
				
				#ifndef LIGHTMAP_OFF
					
					#ifndef DIRLIGHTMAP_OFF
						fixed4 lmtex = tex2D(unity_Lightmap, IN.lmap.xy);
						fixed4 lmIndTex = tex2D(unity_LightmapInd, IN.lmap.xy);
						half3 lm = LightingLambert_DirLightmap(o, lmtex, lmIndTex, 0).rgb;
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
	
	Pass {
		Name "FORWARD"
		Tags { "LightMode" = "ForwardAdd" }
		ZWrite Off Blend One One Fog { Color (0,0,0,0) }
		
		CGPROGRAM
		
		#include "../GoHDR.cginc"
		#include "../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma fragmentoption ARB_precision_hint_fastest
		#pragma multi_compile_fwdadd nodirlightmap
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_FORWARDADD
		#include "../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		#include "AutoLight.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#pragma exclude_renderers xbox360 ps3 flash
		
		inline fixed4 LightingT4M (SurfaceOutput s, fixed3 lightDir, fixed atten)
		{
			fixed diff = max (0, dot (s.Normal, lightDir));
			fixed4 c;
			c.rgb = s.Albedo * _LightColor0.rgb * (diff * atten * 2);
			c.a = 0.0;
			return c;
		}
		
		struct Input {
			float2 uv_Control : TEXCOORD0;
			float2 uv_Splat0 : TEXCOORD1;
			float2 uv_Splat1 : TEXCOORD2;
			float2 uv_Splat2 : TEXCOORD3;
		};
		
		sampler2D _Control;
		sampler2D _Splat0,_Splat1,_Splat2;
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 splat_control = tex2D (_Control, IN.uv_Control).rgba;
			
			fixed3 lay1 = LLDecodeTex( tex2D (_Splat0, IN.uv_Splat0).rgb );
			fixed3 lay2 = LLDecodeTex( tex2D (_Splat1, IN.uv_Splat1).rgb );
			fixed3 lay3 = LLDecodeTex( tex2D (_Splat2, IN.uv_Splat2).rgb );
			o.Alpha = 0.0;
			o.Albedo.rgb = lay1 * splat_control.r + lay2 * splat_control.g + lay3 * splat_control.b;
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			float4 pack1 : TEXCOORD1;
			fixed3 normal : TEXCOORD2;
			half3 lightDir : TEXCOORD3;
			LIGHTING_COORDS(4,5)
		};
		
		float4 _Control_ST;
		float4 _Splat0_ST;
		float4 _Splat1_ST;
		float4 _Splat2_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _Control);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _Splat0);
			o.pack1.xy = TRANSFORM_TEX(v.texcoord, _Splat1);
			o.pack1.zw = TRANSFORM_TEX(v.texcoord, _Splat2);
			o.normal = mul((float3x3)_Object2World, SCALED_NORMAL);
			float3 lightDir = WorldSpaceLightDir( v.vertex );
			o.lightDir = lightDir;
			TRANSFER_VERTEX_TO_FRAGMENT(o);
			return o;
		}
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			Input surfIN;
			surfIN.uv_Control = IN.pack0.xy;
			surfIN.uv_Splat0 = IN.pack0.zw;
			surfIN.uv_Splat1 = IN.pack1.xy;
			surfIN.uv_Splat2 = IN.pack1.zw;
			
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
			o.Normal = IN.normal;
			surf (surfIN, o);
			
			#ifndef USING_DIRECTIONAL_LIGHT
				fixed3 lightDir = normalize(IN.lightDir);
				#else
				fixed3 lightDir = IN.lightDir;
			#endif
			
			fixed4 c = LightingT4M (o, lightDir, LIGHT_ATTENUATION(IN));
			c.a = 0.0;
			
			return LLEncodeGamma( GoHDRApplyCorrection( c ) );
		}
		
		ENDCG
	}
}

Fallback "GoHDR/VertexLit CG"
}


//Original shader:

//Shader "Custom/Terrain_3Textures" {
//	Properties {
//		_Splat0 ("Layer 1", 2D) = "white" {}
//		_Splat1 ("Layer 2", 2D) = "white" {}		
//		_Splat2 ("Layer 3", 2D) = "white" {}
//		_Control ("Control (RGBA)", 2D) = "white" {}
//		
//		_MainTex ("Never Used", 2D) = "white" {}
//	}
//	
//	SubShader {
//		Tags {
//	   "SplatCount" = "3"
//	   "RenderType" = "Opaque"
//		}
//		
//		CGPROGRAM
//		#pragma surface surf T4M exclude_path:prepass approxview halfasview
//		#pragma exclude_renderers xbox360 ps3 flash
//		//#pragma multi_compile NOT_IN_EDITOR_MODE IN_EDITOR_MODE
//		
//		inline fixed4 LightingT4M (SurfaceOutput s, fixed3 lightDir, fixed atten)
//		{
//			fixed diff = max (0, dot (s.Normal, lightDir));
//			fixed4 c;
//			c.rgb = s.Albedo * _LightColor0.rgb * (diff * atten * 2);
//			c.a = 0.0;
//			return c;
//		}
//		
//		struct Input {
//			float2 uv_Control : TEXCOORD0;
//			float2 uv_Splat0 : TEXCOORD1;
//			float2 uv_Splat1 : TEXCOORD2;
//			float2 uv_Splat2 : TEXCOORD3;
//		};
//		 
//		sampler2D _Control;
//		sampler2D _Splat0,_Splat1,_Splat2;
//
//		 
//		void surf (Input IN, inout SurfaceOutput o) {
//			fixed4 splat_control = tex2D (_Control, IN.uv_Control).rgba;
//			
//			fixed3 lay1 = tex2D (_Splat0, IN.uv_Splat0).rgb;
//			fixed3 lay2 = tex2D (_Splat1, IN.uv_Splat1).rgb;
//			fixed3 lay3 = tex2D (_Splat2, IN.uv_Splat2).rgb;
//			o.Alpha = 0.0;
//			o.Albedo.rgb = lay1 * splat_control.r + lay2 * splat_control.g + lay3 * splat_control.b;
//		}
//		ENDCG 
//	}
//	// Fallback to VertexLit
//	Fallback "VertexLit"
//}

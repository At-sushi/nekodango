Shader "Hidden/TerrainEngine/Splatmap/Lightmap-AddPass" {
	Properties {
		_Control ("Control (RGBA)", 2D) = "black" {}
		_Splat3 ("Layer 3 (A)", 2D) = "white" {}
		_Splat2 ("Layer 2 (B)", 2D) = "white" {}
		_Splat1 ("Layer 1 (G)", 2D) = "white" {}
		_Splat0 ("Layer 0 (R)", 2D) = "white" {}
	}
	
	SubShader {
		Tags {
			"SplatCount" = "4"
			"Queue" = "Geometry-99"
			"IgnoreProjector"="True"
			"RenderType" = "Opaque"
		}
		
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			Blend One One ZWrite Off Fog { Color (0,0,0,0) }
			
			CGPROGRAM
			#include "../../../GoHDR.cginc"
			#include "../../../LinLighting.cginc"
			#pragma vertex vert_surf
			#pragma fragment frag_surf
			#pragma multi_compile_fwdbase
			#include "HLSLSupport.cginc"
			#include "UnityShaderVariables.cginc"
			#define UNITY_PASS_FORWARDBASE
			#include "../../../UnityCGGoHDR.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			#define INTERNAL_DATA
			#define WorldReflectionVector(data,normal) data.worldRefl
			#define WorldNormalVector(data,normal) normal
			
			struct Input {
				float2 uv_Control : TEXCOORD0;
				float2 uv_Splat0 : TEXCOORD1;
				float2 uv_Splat1 : TEXCOORD2;
				float2 uv_Splat2 : TEXCOORD3;
				float2 uv_Splat3 : TEXCOORD4;
			};
			
			sampler2D _Control;
			sampler2D _Splat0,_Splat1,_Splat2,_Splat3;
			
			void surf (Input IN, inout SurfaceOutput o) {
				fixed4 splat_control = tex2D (_Control, IN.uv_Control);
				fixed3 col;
				col  = splat_control.r * LLDecodeTex( tex2D (_Splat0, IN.uv_Splat0).rgb );
				col += splat_control.g * LLDecodeTex( tex2D (_Splat1, IN.uv_Splat1).rgb );
				col += splat_control.b * LLDecodeTex( tex2D (_Splat2, IN.uv_Splat2).rgb );
				col += splat_control.a * LLDecodeTex( tex2D (_Splat3, IN.uv_Splat3).rgb );
				o.Albedo = col;
				o.Alpha = 0.0;
			}
			
			#ifdef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					float4 pack1 : TEXCOORD1;
					float2 pack2 : TEXCOORD2;
					fixed3 normal : TEXCOORD3;
					fixed3 vlight : TEXCOORD4;
					LIGHTING_COORDS(5,6)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					float4 pack1 : TEXCOORD1;
					float2 pack2 : TEXCOORD2;
					float2 lmap : TEXCOORD3;
					LIGHTING_COORDS(4,5)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				float4 unity_LightmapST;
			#endif
			
			float4 _Control_ST;
			float4 _Splat0_ST;
			float4 _Splat1_ST;
			float4 _Splat2_ST;
			float4 _Splat3_ST;
			
			v2f_surf vert_surf (appdata_full v) {
				v2f_surf o;
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
				o.pack0.xy = TRANSFORM_TEX(v.texcoord, _Control);
				o.pack0.zw = TRANSFORM_TEX(v.texcoord, _Splat0);
				o.pack1.xy = TRANSFORM_TEX(v.texcoord, _Splat1);
				o.pack1.zw = TRANSFORM_TEX(v.texcoord, _Splat2);
				o.pack2.xy = TRANSFORM_TEX(v.texcoord, _Splat3);
				
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
				
				#ifdef UNITY_COMPILER_HLSL
					Input surfIN = (Input)0;
					#else
					Input surfIN;
				#endif
				
				surfIN.uv_Control = IN.pack0.xy;
				surfIN.uv_Splat0 = IN.pack0.zw;
				surfIN.uv_Splat1 = IN.pack1.xy;
				surfIN.uv_Splat2 = IN.pack1.zw;
				surfIN.uv_Splat3 = IN.pack2.xy;
				
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
					c = LightingLambert (o, _WorldSpaceLightPos0.xyz, atten);
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
		Blend One One ZWrite Off Fog { Color (0,0,0,0) }
		
		CGPROGRAM
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_fwdadd
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_FORWARDADD
		#include "../../../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		#include "AutoLight.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		struct Input {
			float2 uv_Control : TEXCOORD0;
			float2 uv_Splat0 : TEXCOORD1;
			float2 uv_Splat1 : TEXCOORD2;
			float2 uv_Splat2 : TEXCOORD3;
			float2 uv_Splat3 : TEXCOORD4;
		};
		
		sampler2D _Control;
		sampler2D _Splat0,_Splat1,_Splat2,_Splat3;
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 splat_control = tex2D (_Control, IN.uv_Control);
			fixed3 col;
			col  = splat_control.r * LLDecodeTex( tex2D (_Splat0, IN.uv_Splat0).rgb );
			col += splat_control.g * LLDecodeTex( tex2D (_Splat1, IN.uv_Splat1).rgb );
			col += splat_control.b * LLDecodeTex( tex2D (_Splat2, IN.uv_Splat2).rgb );
			col += splat_control.a * LLDecodeTex( tex2D (_Splat3, IN.uv_Splat3).rgb );
			o.Albedo = col;
			o.Alpha = 0.0;
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			float4 pack1 : TEXCOORD1;
			float2 pack2 : TEXCOORD2;
			fixed3 normal : TEXCOORD3;
			half3 lightDir : TEXCOORD4;
			LIGHTING_COORDS(5,6)
		};
		
		float4 _Control_ST;
		float4 _Splat0_ST;
		float4 _Splat1_ST;
		float4 _Splat2_ST;
		float4 _Splat3_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _Control);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _Splat0);
			o.pack1.xy = TRANSFORM_TEX(v.texcoord, _Splat1);
			o.pack1.zw = TRANSFORM_TEX(v.texcoord, _Splat2);
			o.pack2.xy = TRANSFORM_TEX(v.texcoord, _Splat3);
			o.normal = mul((float3x3)_Object2World, SCALED_NORMAL);
			float3 lightDir = WorldSpaceLightDir( v.vertex );
			o.lightDir = lightDir;
			TRANSFER_VERTEX_TO_FRAGMENT(o);
			return o;
		}
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
			surfIN.uv_Control = IN.pack0.xy;
			surfIN.uv_Splat0 = IN.pack0.zw;
			surfIN.uv_Splat1 = IN.pack1.xy;
			surfIN.uv_Splat2 = IN.pack1.zw;
			surfIN.uv_Splat3 = IN.pack2.xy;
			
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
			
			fixed4 c = LightingLambert (o, lightDir, LIGHT_ATTENUATION(IN));
			c.a = 0.0;
			
			
			
			return LLEncodeGamma( GoHDRApplyCorrection( c ) );
		}
		
		ENDCG
	}
	
	Pass {
		Name "PREPASS"
		Tags { "LightMode" = "PrePassFinal" }
		
		ZWrite Off
		Blend One One Fog { Color (0,0,0,0) }
		
		CGPROGRAM
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_prepassfinal
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_PREPASSFINAL
		#include "../../../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		struct Input {
			float2 uv_Control : TEXCOORD0;
			float2 uv_Splat0 : TEXCOORD1;
			float2 uv_Splat1 : TEXCOORD2;
			float2 uv_Splat2 : TEXCOORD3;
			float2 uv_Splat3 : TEXCOORD4;
		};
		
		sampler2D _Control;
		sampler2D _Splat0,_Splat1,_Splat2,_Splat3;
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 splat_control = tex2D (_Control, IN.uv_Control);
			fixed3 col;
			col  = splat_control.r * LLDecodeTex( tex2D (_Splat0, IN.uv_Splat0).rgb );
			col += splat_control.g * LLDecodeTex( tex2D (_Splat1, IN.uv_Splat1).rgb );
			col += splat_control.b * LLDecodeTex( tex2D (_Splat2, IN.uv_Splat2).rgb );
			col += splat_control.a * LLDecodeTex( tex2D (_Splat3, IN.uv_Splat3).rgb );
			o.Albedo = col;
			o.Alpha = 0.0;
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			float4 pack1 : TEXCOORD1;
			float2 pack2 : TEXCOORD2;
			float4 screen : TEXCOORD3;
			
			#ifdef LIGHTMAP_OFF
				float3 vlight : TEXCOORD4;
				#else
				float2 lmap : TEXCOORD4;
				
				#ifdef DIRLIGHTMAP_OFF
					float4 lmapFadePos : TEXCOORD5;
				#endif

			#endif
		};
		
		#ifndef LIGHTMAP_OFF
			float4 unity_LightmapST;
		#endif
		
		float4 _Control_ST;
		float4 _Splat0_ST;
		float4 _Splat1_ST;
		float4 _Splat2_ST;
		float4 _Splat3_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _Control);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _Splat0);
			o.pack1.xy = TRANSFORM_TEX(v.texcoord, _Splat1);
			o.pack1.zw = TRANSFORM_TEX(v.texcoord, _Splat2);
			o.pack2.xy = TRANSFORM_TEX(v.texcoord, _Splat3);
			o.screen = ComputeScreenPos (o.pos);
			
			#ifndef LIGHTMAP_OFF
				o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				
				#ifdef DIRLIGHTMAP_OFF
					o.lmapFadePos.xyz = (mul(_Object2World, v.vertex).xyz - unity_ShadowFadeCenterAndType.xyz) * unity_ShadowFadeCenterAndType.w;
					o.lmapFadePos.w = (-mul(UNITY_MATRIX_MV, v.vertex).z) * (1.0 - unity_ShadowFadeCenterAndType.w);
				#endif
				
				#else
				float3 worldN = mul((float3x3)_Object2World, SCALED_NORMAL);
				o.vlight = ShadeSH9 (float4(worldN,1.0));
			#endif
			
			return o;
		}
		
		sampler2D _LightBuffer;
		#if defined (SHADER_API_XBOX360) && defined (HDR_LIGHT_PREPASS_ON)
			sampler2D _LightSpecBuffer;
		#endif
		
		#ifndef LIGHTMAP_OFF
			sampler2D unity_Lightmap;
			sampler2D unity_LightmapInd;
			float4 unity_LightmapFade;
		#endif
		
		fixed4 unity_Ambient;
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
			surfIN.uv_Control = IN.pack0.xy;
			surfIN.uv_Splat0 = IN.pack0.zw;
			surfIN.uv_Splat1 = IN.pack1.xy;
			surfIN.uv_Splat2 = IN.pack1.zw;
			surfIN.uv_Splat3 = IN.pack2.xy;
			
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
			half4 light = tex2Dproj (_LightBuffer, UNITY_PROJ_COORD(IN.screen));
			#if defined (SHADER_API_GLES) || defined (SHADER_API_GLES3)
				light = max(light, half4(0.001));
			#endif
			
			#ifndef HDR_LIGHT_PREPASS_ON
				light = -log2(light);
			#endif
			
			#if defined (SHADER_API_XBOX360) && defined (HDR_LIGHT_PREPASS_ON)
				light.w = tex2Dproj (_LightSpecBuffer, UNITY_PROJ_COORD(IN.screen)).r;
			#endif
			
			#ifndef LIGHTMAP_OFF
				
				#ifdef DIRLIGHTMAP_OFF
					fixed4 lmtex = tex2D(unity_Lightmap, IN.lmap.xy);
					fixed4 lmtex2 = tex2D(unity_LightmapInd, IN.lmap.xy);
					half lmFade = length (IN.lmapFadePos) * unity_LightmapFade.z + unity_LightmapFade.w;
					half3 lmFull = DecodeLightmap (lmtex);
					half3 lmIndirect = DecodeLightmap (lmtex2);
					half3 lm = lerp (lmIndirect, lmFull, saturate(lmFade));
					light.rgb += lm;
					#else
					fixed4 lmtex = tex2D(unity_Lightmap, IN.lmap.xy);
					fixed4 lmIndTex = tex2D(unity_LightmapInd, IN.lmap.xy);
					half4 lm = LightingLambert_DirLightmap(o, lmtex, lmIndTex, 0);
					light += lm;
				#endif
				
				#else
				light.rgb += IN.vlight;
			#endif
			
			half4 c = LightingLambert_PrePass (o, light);
			
			return LLEncodeGamma( GoHDRApplyCorrection( c ) );
		}
		
		ENDCG
	}
}
}


//Original shader:

//Shader "Hidden/TerrainEngine/Splatmap/Lightmap-AddPass" {
//Properties {
//	_Control ("Control (RGBA)", 2D) = "black" {}
//	_Splat3 ("Layer 3 (A)", 2D) = "white" {}
//	_Splat2 ("Layer 2 (B)", 2D) = "white" {}
//	_Splat1 ("Layer 1 (G)", 2D) = "white" {}
//	_Splat0 ("Layer 0 (R)", 2D) = "white" {}
//}
//	
//SubShader {
//	Tags {
//		"SplatCount" = "4"
//		"Queue" = "Geometry-99"
//		"IgnoreProjector"="True"
//		"RenderType" = "Opaque"
//	}
//	
//CGPROGRAM
//#pragma surface surf Lambert decal:add
//struct Input {
//	float2 uv_Control : TEXCOORD0;
//	float2 uv_Splat0 : TEXCOORD1;
//	float2 uv_Splat1 : TEXCOORD2;
//	float2 uv_Splat2 : TEXCOORD3;
//	float2 uv_Splat3 : TEXCOORD4;
//};
//
//sampler2D _Control;
//sampler2D _Splat0,_Splat1,_Splat2,_Splat3;
//
//void surf (Input IN, inout SurfaceOutput o) {
//	fixed4 splat_control = tex2D (_Control, IN.uv_Control);
//	fixed3 col;
//	col  = splat_control.r * tex2D (_Splat0, IN.uv_Splat0).rgb;
//	col += splat_control.g * tex2D (_Splat1, IN.uv_Splat1).rgb;
//	col += splat_control.b * tex2D (_Splat2, IN.uv_Splat2).rgb;
//	col += splat_control.a * tex2D (_Splat3, IN.uv_Splat3).rgb;
//	o.Albedo = col;
//	o.Alpha = 0.0;
//}
//ENDCG  
//}
//
//Fallback off
//}

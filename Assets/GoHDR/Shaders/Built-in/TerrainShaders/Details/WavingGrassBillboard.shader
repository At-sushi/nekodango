Shader "Hidden/TerrainEngine/Details/BillboardWavingDoublePass" {
	Properties {
		_WavingTint ("Fade Color", Color) = (.7,.6,.5, 0)
		_MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}
		
		_WaveAndDistance ("Wave and distance", Vector) = (12, 3.6, 1, 1)
		_Cutoff ("Cutoff", float) = 0.5
	}
	
	SubShader {
		Tags {
			"Queue" = "Geometry+200"
			"IgnoreProjector"="True"
			"RenderType"="GrassBillboard"
		}
		
		Cull Off
		LOD 200
		ColorMask RGB
		
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			
			CGPROGRAM
			#include "../../../GoHDR.cginc"
			#include "../../../LinLighting.cginc"
			#pragma vertex vert_surf
			#pragma fragment frag_surf
			#pragma multi_compile_fwdbase
			#pragma glsl_no_auto_normalization
			#include "HLSLSupport.cginc"
			#include "UnityShaderVariables.cginc"
			#define UNITY_PASS_FORWARDBASE
			#include "../../../UnityCGGoHDR.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			#define INTERNAL_DATA
			#define WorldReflectionVector(data,normal) data.worldRefl
			#define WorldNormalVector(data,normal) normal
			
			#include "../TerrainEngineGoHDR.cginc"
			#pragma glsl_no_auto_normalization
			
			struct v2f {
				float4 pos : POSITION;
				fixed4 color : COLOR;
				float4 uv : TEXCOORD0;
			};
			
			v2f BillboardVert (appdata_full v) {
				v2f o;
				WavingGrassBillboardVert (v);
				o.color = LLDecodeGamma( v.color );
				
				o.color.rgb *= ShadeVertexLights (v.vertex, v.normal);
				
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);	
				o.uv = v.texcoord;
				return o;
			}
			
			#pragma exclude_renderers flash
			
			sampler2D _MainTex;
			fixed _Cutoff;
			
			struct Input {
				float2 uv_MainTex;
				fixed4 color : COLOR;
			};
			
			void surf (Input IN, inout SurfaceOutput o) {
				fixed4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) ) * IN.color;
				o.Albedo = c.rgb;
				o.Alpha = c.a;
				clip (o.Alpha - _Cutoff);
				o.Alpha *= IN.color.a;
			}
			
			#ifdef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float2 pack0 : TEXCOORD0;
					fixed4 color : COLOR0;
					fixed3 normal : TEXCOORD1;
					fixed3 vlight : TEXCOORD2;
					LIGHTING_COORDS(3,4)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float2 pack0 : TEXCOORD0;
					fixed4 color : COLOR0;
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
				WavingGrassBillboardVert (v);
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
				o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.color = LLDecodeGamma( v.color );
				
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
				
				surfIN.uv_MainTex = IN.pack0.xy;
				surfIN.color = IN.color;
				
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
		
		CGPROGRAM
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_fwdadd
		#pragma glsl_no_auto_normalization
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_FORWARDADD
		#include "../../../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		#include "AutoLight.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#include "../../../UnityCGGoHDR.cginc"
		#include "../TerrainEngineGoHDR.cginc"
		#pragma glsl_no_auto_normalization
		
		struct v2f {
			float4 pos : POSITION;
			fixed4 color : COLOR;
			float4 uv : TEXCOORD0;
		};
		
		v2f BillboardVert (appdata_full v) {
			v2f o;
			WavingGrassBillboardVert (v);
			o.color = LLDecodeGamma( v.color );
			
			o.color.rgb *= ShadeVertexLights (v.vertex, v.normal);
			
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);	
			o.uv = v.texcoord;
			return o;
		}
		
		#pragma exclude_renderers flash
		
		sampler2D _MainTex;
		fixed _Cutoff;
		
		struct Input {
			float2 uv_MainTex;
			fixed4 color : COLOR;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) ) * IN.color;
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			clip (o.Alpha - _Cutoff);
			o.Alpha *= IN.color.a;
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float2 pack0 : TEXCOORD0;
			fixed4 color : COLOR0;
			fixed3 normal : TEXCOORD1;
			half3 lightDir : TEXCOORD2;
			LIGHTING_COORDS(3,4)
		};
		
		float4 _MainTex_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			WavingGrassBillboardVert (v);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.color = LLDecodeGamma( v.color );
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
			
			surfIN.uv_MainTex = IN.pack0.xy;
			surfIN.color = IN.color;
			
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
		Tags { "LightMode" = "PrePassBase" }
		Fog {Mode Off}
		
		CGPROGRAM
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		
		#pragma glsl_no_auto_normalization
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_PREPASSBASE
		#include "../../../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#include "../../../UnityCGGoHDR.cginc"
		#include "../TerrainEngineGoHDR.cginc"
		#pragma glsl_no_auto_normalization
		
		struct v2f {
			float4 pos : POSITION;
			fixed4 color : COLOR;
			float4 uv : TEXCOORD0;
		};
		
		v2f BillboardVert (appdata_full v) {
			v2f o;
			WavingGrassBillboardVert (v);
			o.color = LLDecodeGamma( v.color );
			
			o.color.rgb *= ShadeVertexLights (v.vertex, v.normal);
			
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);	
			o.uv = v.texcoord;
			return o;
		}
		
		#pragma exclude_renderers flash
		
		sampler2D _MainTex;
		fixed _Cutoff;
		
		struct Input {
			float2 uv_MainTex;
			fixed4 color : COLOR;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) ) * IN.color;
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			clip (o.Alpha - _Cutoff);
			o.Alpha *= IN.color.a;
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float2 pack0 : TEXCOORD0;
			fixed4 color : COLOR0;
			fixed3 normal : TEXCOORD1;
		};
		
		float4 _MainTex_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			WavingGrassBillboardVert (v);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.color = LLDecodeGamma( v.color );
			o.normal = mul((float3x3)_Object2World, SCALED_NORMAL);
			return o;
		}
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
			surfIN.uv_MainTex = IN.pack0.xy;
			surfIN.color = IN.color;
			
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
			fixed4 res;
			res.rgb = o.Normal * 0.5 + 0.5;
			res.a = o.Specular;
			
			return LLEncodeGamma( GoHDRApplyCorrection( res ) );
		}
		
		ENDCG
	}
	
	Pass {
		Name "PREPASS"
		Tags { "LightMode" = "PrePassFinal" }
		
		ZWrite Off
		
		CGPROGRAM
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_prepassfinal
		#pragma glsl_no_auto_normalization
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_PREPASSFINAL
		#include "../../../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#include "../../../UnityCGGoHDR.cginc"
		#include "../TerrainEngineGoHDR.cginc"
		#pragma glsl_no_auto_normalization
		
		struct v2f {
			float4 pos : POSITION;
			fixed4 color : COLOR;
			float4 uv : TEXCOORD0;
		};
		
		v2f BillboardVert (appdata_full v) {
			v2f o;
			WavingGrassBillboardVert (v);
			o.color = LLDecodeGamma( v.color );
			
			o.color.rgb *= ShadeVertexLights (v.vertex, v.normal);
			
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);	
			o.uv = v.texcoord;
			return o;
		}
		
		#pragma exclude_renderers flash
		
		sampler2D _MainTex;
		fixed _Cutoff;
		
		struct Input {
			float2 uv_MainTex;
			fixed4 color : COLOR;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) ) * IN.color;
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			clip (o.Alpha - _Cutoff);
			o.Alpha *= IN.color.a;
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float2 pack0 : TEXCOORD0;
			fixed4 color : COLOR0;
			float4 screen : TEXCOORD1;
			
			#ifdef LIGHTMAP_OFF
				float3 vlight : TEXCOORD2;
				#else
				float2 lmap : TEXCOORD2;
				
				#ifdef DIRLIGHTMAP_OFF
					float4 lmapFadePos : TEXCOORD3;
				#endif

			#endif
		};
		
		#ifndef LIGHTMAP_OFF
			float4 unity_LightmapST;
		#endif
		
		float4 _MainTex_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			WavingGrassBillboardVert (v);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.color = LLDecodeGamma( v.color );
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
			
			surfIN.uv_MainTex = IN.pack0.xy;
			surfIN.color = IN.color;
			
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
	
	Pass {
		Name "ShadowCaster"
		Tags { "LightMode" = "ShadowCaster" }
		Fog {Mode Off}
		
		ZWrite On ZTest LEqual Cull Off
		Offset 1, 1
		
		CGPROGRAM
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_shadowcaster
		#pragma glsl_no_auto_normalization
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_SHADOWCASTER
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#include "UnityCG.cginc"
		#include "TerrainEngine.cginc"
		#pragma glsl_no_auto_normalization
		
		struct v2f {
			float4 pos : POSITION;
			fixed4 color : COLOR;
			float4 uv : TEXCOORD0;
		};
		
		v2f BillboardVert (appdata_full v) {
			v2f o;
			WavingGrassBillboardVert (v);
			o.color = v.color;
			
			o.color.rgb *= ShadeVertexLights (v.vertex, v.normal);
			
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);	
			o.uv = v.texcoord;
			return o;
		}
		
		#pragma exclude_renderers flash
		
		sampler2D _MainTex;
		fixed _Cutoff;
		
		struct Input {
			float2 uv_MainTex;
			fixed4 color : COLOR;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * IN.color;
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			clip (o.Alpha - _Cutoff);
			o.Alpha *= IN.color.a;
		}
		
		struct v2f_surf {
			V2F_SHADOW_CASTER;
			float2 pack0 : TEXCOORD1;
			fixed4 color : COLOR0;
		};
		
		float4 _MainTex_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			WavingGrassBillboardVert (v);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.color = v.color;
			TRANSFER_SHADOW_CASTER(o)
			return o;
		}
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
			surfIN.uv_MainTex = IN.pack0.xy;
			surfIN.color = IN.color;
			
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
			SHADOW_CASTER_FRAGMENT(IN)
		}
		
		ENDCG
	}
	
	Pass {
		Name "ShadowCollector"
		Tags { "LightMode" = "ShadowCollector" }
		Fog {Mode Off}
		
		ZWrite On ZTest LEqual
		
		CGPROGRAM
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_shadowcollector
		#pragma glsl_no_auto_normalization
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_SHADOWCOLLECTOR
		#define SHADOW_COLLECTOR_PASS
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#include "UnityCG.cginc"
		#include "TerrainEngine.cginc"
		#pragma glsl_no_auto_normalization
		
		struct v2f {
			float4 pos : POSITION;
			fixed4 color : COLOR;
			float4 uv : TEXCOORD0;
		};
		
		v2f BillboardVert (appdata_full v) {
			v2f o;
			WavingGrassBillboardVert (v);
			o.color = v.color;
			
			o.color.rgb *= ShadeVertexLights (v.vertex, v.normal);
			
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);	
			o.uv = v.texcoord;
			return o;
		}
		
		#pragma exclude_renderers flash
		
		sampler2D _MainTex;
		fixed _Cutoff;
		
		struct Input {
			float2 uv_MainTex;
			fixed4 color : COLOR;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * IN.color;
			o.Albedo = c.rgb;
			o.Alpha = c.a;
			clip (o.Alpha - _Cutoff);
			o.Alpha *= IN.color.a;
		}
		
		struct v2f_surf {
			V2F_SHADOW_COLLECTOR;
			float2 pack0 : TEXCOORD5;
			fixed4 color : COLOR0;
		};
		
		float4 _MainTex_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			WavingGrassBillboardVert (v);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.color = v.color;
			TRANSFER_SHADOW_COLLECTOR(o)
			return o;
		}
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
			surfIN.uv_MainTex = IN.pack0.xy;
			surfIN.color = IN.color;
			
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
			SHADOW_COLLECTOR_FRAGMENT(IN)
		}
		
		ENDCG
	}
}

SubShader {
	Tags {
		"Queue" = "Geometry+200"
		"IgnoreProjector"="True"
		"RenderType"="GrassBillboard"
	}
	
	ColorMask RGB
	Cull Off
	Lighting On
	
	Pass {
		
		#LINE 78
		
		AlphaTest Greater [_Cutoff]
		SetTexture [_MainTex] { combine texture * primary DOUBLE, texture * primary }
	}
}
}


//Original shader:

//Shader "Hidden/TerrainEngine/Details/BillboardWavingDoublePass" {
//	Properties {
//		_WavingTint ("Fade Color", Color) = (.7,.6,.5, 0)
//		_MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}
//		_WaveAndDistance ("Wave and distance", Vector) = (12, 3.6, 1, 1)
//		_Cutoff ("Cutoff", float) = 0.5
//	}
//	
//CGINCLUDE
//#include "UnityCG.cginc"
//#include "TerrainEngine.cginc"
//#pragma glsl_no_auto_normalization
//
//struct v2f {
//	float4 pos : POSITION;
//	fixed4 color : COLOR;
//	float4 uv : TEXCOORD0;
//};
//v2f BillboardVert (appdata_full v) {
//	v2f o;
//	WavingGrassBillboardVert (v);
//	o.color = v.color;
//	
//	o.color.rgb *= ShadeVertexLights (v.vertex, v.normal);
//		
//	o.pos = mul (UNITY_MATRIX_MVP, v.vertex);	
//	o.uv = v.texcoord;
//	return o;
//}
//ENDCG
//
//	SubShader {
//		Tags {
//			"Queue" = "Geometry+200"
//			"IgnoreProjector"="True"
//			"RenderType"="GrassBillboard"
//		}
//		Cull Off
//		LOD 200
//		ColorMask RGB
//				
//CGPROGRAM
//#pragma surface surf Lambert vertex:WavingGrassBillboardVert addshadow
//#pragma exclude_renderers flash
//			
//sampler2D _MainTex;
//fixed _Cutoff;
//
//struct Input {
//	float2 uv_MainTex;
//	fixed4 color : COLOR;
//};
//
//void surf (Input IN, inout SurfaceOutput o) {
//	fixed4 c = tex2D(_MainTex, IN.uv_MainTex) * IN.color;
//	o.Albedo = c.rgb;
//	o.Alpha = c.a;
//	clip (o.Alpha - _Cutoff);
//	o.Alpha *= IN.color.a;
//}
//
//ENDCG			
//	}
//
//	SubShader {
//		Tags {
//			"Queue" = "Geometry+200"
//			"IgnoreProjector"="True"
//			"RenderType"="GrassBillboard"
//		}
//
//		ColorMask RGB
//		Cull Off
//		Lighting On
//		
//		Pass {
//			CGPROGRAM
//			#pragma vertex BillboardVert
//			#pragma exclude_renderers shaderonly
//			ENDCG
//
//			AlphaTest Greater [_Cutoff]
//
//			SetTexture [_MainTex] { combine texture * primary DOUBLE, texture * primary }
//		}
//	} 
//	
//	Fallback Off
//}

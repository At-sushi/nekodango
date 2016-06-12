Shader "GoHDR/Enviro/2-sided Bumped Specular" {
	Properties {
		_Color ("Main Color", Color) = (1,1,1,1)
		_SpecColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 0)
		_Shininess ("Shininess", Range (0.01, 10)) = 0.078125
		_MainTex ("Base (RGB) TransGloss (A)", 2D) = "white" {}
		_BumpMap ("Normalmap", 2D) = "bump" {}
		
		_Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
	}
	
	SubShader {
		Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout"}
		
		LOD 400
		
		Cull Back
		
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			
			ColorMask RGB
			
			CGPROGRAM
			#include "../GoHDR.cginc"
			#include "../LinLighting.cginc"
			#pragma vertex vert_surf
			#pragma fragment frag_surf
			#pragma multi_compile_fwdbase
			#include "HLSLSupport.cginc"
			#include "UnityShaderVariables.cginc"
			#define UNITY_PASS_FORWARDBASE
			#include "../UnityCGGoHDR.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			#define INTERNAL_DATA
			#define WorldReflectionVector(data,normal) data.worldRefl
			#define WorldNormalVector(data,normal) normal
			
			#pragma target 3.0
			
			sampler2D _MainTex;
			sampler2D _BumpMap;
			fixed4 _Color;
			half _Shininess;
			
			struct Input {
				float2 uv_MainTex;
				float2 uv_BumpMap;
			};
			
			void surf (Input IN, inout SurfaceOutput o) {
				fixed4 tex = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) );
				o.Albedo = tex.rgb * LLDecodeGamma( _Color.rgb );
				o.Gloss = tex.rgb * LLDecodeGamma( _Color.rgb );
				o.Alpha = tex.a * LLDecodeGamma( _Color.a );
				o.Specular = _Shininess;
				o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
			}
			
			#ifdef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					fixed3 lightDir : TEXCOORD1;
					fixed3 vlight : TEXCOORD2;
					float3 viewDir : TEXCOORD3;
					LIGHTING_COORDS(4,5)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					float2 lmap : TEXCOORD1;
					
					#ifndef DIRLIGHTMAP_OFF
						float3 viewDir : TEXCOORD2;
						LIGHTING_COORDS(3,4)
						#else
						LIGHTING_COORDS(2,3)
					#endif
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				float4 unity_LightmapST;
			#endif
			
			float4 _MainTex_ST;
			float4 _BumpMap_ST;
			
			v2f_surf vert_surf (appdata_full v) {
				v2f_surf o;
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
				o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.pack0.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);
				
				#ifndef LIGHTMAP_OFF
					o.lmap.xy = v.texcoord1.xy * unity_LightmapST.xy + unity_LightmapST.zw;
				#endif
				
				float3 worldN = mul((float3x3)_Object2World, SCALED_NORMAL);
				TANGENT_SPACE_ROTATION;
				float3 lightDir = mul (rotation, ObjSpaceLightDir(v.vertex));
				
				#ifdef LIGHTMAP_OFF
					o.lightDir = lightDir;
				#endif
				
				#if defined (LIGHTMAP_OFF) || !defined (DIRLIGHTMAP_OFF)
					float3 viewDirForLight = mul (rotation, ObjSpaceViewDir(v.vertex));
					o.viewDir = viewDirForLight;
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
			
			fixed _Cutoff;
			
			fixed4 frag_surf (v2f_surf IN) : COLOR {
				
				#ifdef UNITY_COMPILER_HLSL
					Input surfIN = (Input)0;
					#else
					Input surfIN;
				#endif
				
				surfIN.uv_MainTex = IN.pack0.xy;
				surfIN.uv_BumpMap = IN.pack0.zw;
				
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
				clip (o.Alpha - _Cutoff);
				fixed atten = LIGHT_ATTENUATION(IN);
				fixed4 c = 0;
				
				#ifdef LIGHTMAP_OFF
					c = LightingBlinnPhong (o, IN.lightDir, normalize(half3(IN.viewDir)), atten);
				#endif
				
				#ifdef LIGHTMAP_OFF
					c.rgb += o.Albedo * IN.vlight;
				#endif
				
				#ifndef LIGHTMAP_OFF
					
					#ifndef DIRLIGHTMAP_OFF
						half3 specColor;
						fixed4 lmtex = tex2D(unity_Lightmap, IN.lmap.xy);
						fixed4 lmIndTex = tex2D(unity_LightmapInd, IN.lmap.xy);
						half3 lm = LightingBlinnPhong_DirLightmap(o, lmtex, lmIndTex, normalize(half3(IN.viewDir)), 1, specColor).rgb;
						c.rgb += specColor;
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
			
			c.a = o.Alpha;
			
			return LLEncodeGamma( GoHDRApplyCorrection( c ) );
		}
		
		ENDCG
	}
	
	Pass {
		Name "FORWARD"
		Tags { "LightMode" = "ForwardAdd" }
		ZWrite Off Blend One One Fog { Color (0,0,0,0) }
		
		ColorMask RGB
		
		CGPROGRAM
		#include "../GoHDR.cginc"
		#include "../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_fwdadd
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_FORWARDADD
		#include "../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		#include "AutoLight.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#pragma target 3.0
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		fixed4 _Color;
		half _Shininess;
		
		struct Input {
			float2 uv_MainTex;
			float2 uv_BumpMap;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 tex = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) );
			o.Albedo = tex.rgb * LLDecodeGamma( _Color.rgb );
			o.Gloss = tex.rgb * LLDecodeGamma( _Color.rgb );
			o.Alpha = tex.a * LLDecodeGamma( _Color.a );
			o.Specular = _Shininess;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			half3 lightDir : TEXCOORD1;
			half3 viewDir : TEXCOORD2;
			LIGHTING_COORDS(3,4)
		};
		
		float4 _MainTex_ST;
		float4 _BumpMap_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);
			TANGENT_SPACE_ROTATION;
			float3 lightDir = mul (rotation, ObjSpaceLightDir(v.vertex));
			o.lightDir = lightDir;
			float3 viewDirForLight = mul (rotation, ObjSpaceViewDir(v.vertex));
			o.viewDir = viewDirForLight;
			TRANSFER_VERTEX_TO_FRAGMENT(o);
			return o;
		}
		
		fixed _Cutoff;
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
			surfIN.uv_MainTex = IN.pack0.xy;
			surfIN.uv_BumpMap = IN.pack0.zw;
			
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
			clip (o.Alpha - _Cutoff);
			
			#ifndef USING_DIRECTIONAL_LIGHT
				fixed3 lightDir = normalize(IN.lightDir);
				#else
				fixed3 lightDir = IN.lightDir;
			#endif
			
			fixed4 c = LightingBlinnPhong (o, lightDir, normalize(half3(IN.viewDir)), LIGHT_ATTENUATION(IN));
			c.a = o.Alpha;
			
			return LLEncodeGamma( GoHDRApplyCorrection( c ) );
		}
		
		ENDCG
	}
	
	Pass {
		Name "PREPASS"
		Tags { "LightMode" = "PrePassBase" }
		Fog {Mode Off}
		
		CGPROGRAM
		#include "../GoHDR.cginc"
		#include "../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_PREPASSBASE
		#include "../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#pragma target 3.0
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		fixed4 _Color;
		half _Shininess;
		
		struct Input {
			float2 uv_MainTex;
			float2 uv_BumpMap;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 tex = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) );
			o.Albedo = tex.rgb * LLDecodeGamma( _Color.rgb );
			o.Gloss = tex.rgb * LLDecodeGamma( _Color.rgb );
			o.Alpha = tex.a * LLDecodeGamma( _Color.a );
			o.Specular = _Shininess;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			float3 TtoW0 : TEXCOORD1;
			float3 TtoW1 : TEXCOORD2;
			float3 TtoW2 : TEXCOORD3;
		};
		
		float4 _MainTex_ST;
		float4 _BumpMap_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);
			TANGENT_SPACE_ROTATION;
			o.TtoW0 = mul(rotation, ((float3x3)_Object2World)[0].xyz)*unity_Scale.w;
			o.TtoW1 = mul(rotation, ((float3x3)_Object2World)[1].xyz)*unity_Scale.w;
			o.TtoW2 = mul(rotation, ((float3x3)_Object2World)[2].xyz)*unity_Scale.w;
			return o;
		}
		
		fixed _Cutoff;
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
			surfIN.uv_MainTex = IN.pack0.xy;
			surfIN.uv_BumpMap = IN.pack0.zw;
			
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
			clip (o.Alpha - _Cutoff);
			fixed3 worldN;
			worldN.x = dot(IN.TtoW0, o.Normal);
			worldN.y = dot(IN.TtoW1, o.Normal);
			worldN.z = dot(IN.TtoW2, o.Normal);
			o.Normal = worldN;
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
		#include "../GoHDR.cginc"
		#include "../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_prepassfinal
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_PREPASSFINAL
		#include "../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#pragma target 3.0
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		fixed4 _Color;
		half _Shininess;
		
		struct Input {
			float2 uv_MainTex;
			float2 uv_BumpMap;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 tex = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) );
			o.Albedo = tex.rgb * LLDecodeGamma( _Color.rgb );
			o.Gloss = tex.rgb * LLDecodeGamma( _Color.rgb );
			o.Alpha = tex.a * LLDecodeGamma( _Color.a );
			o.Specular = _Shininess;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			float4 screen : TEXCOORD1;
			
			#ifdef LIGHTMAP_OFF
				float3 vlight : TEXCOORD2;
				#else
				float2 lmap : TEXCOORD2;
				
				#ifdef DIRLIGHTMAP_OFF
					float4 lmapFadePos : TEXCOORD3;
					#else
					float3 viewDir : TEXCOORD3;
				#endif

			#endif
		};
		
		#ifndef LIGHTMAP_OFF
			float4 unity_LightmapST;
		#endif
		
		float4 _MainTex_ST;
		float4 _BumpMap_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);
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
			
			#ifndef DIRLIGHTMAP_OFF
				TANGENT_SPACE_ROTATION;
				o.viewDir = mul (rotation, ObjSpaceViewDir(v.vertex));
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
		fixed _Cutoff;
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
			surfIN.uv_MainTex = IN.pack0.xy;
			surfIN.uv_BumpMap = IN.pack0.zw;
			
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
			clip (o.Alpha - _Cutoff);
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
					half3 specColor;
					fixed4 lmtex = tex2D(unity_Lightmap, IN.lmap.xy);
					fixed4 lmIndTex = tex2D(unity_LightmapInd, IN.lmap.xy);
					half4 lm = LightingBlinnPhong_DirLightmap(o, lmtex, lmIndTex, normalize(half3(IN.viewDir)), 1, specColor);
					light += lm;
				#endif
				
				#else
				light.rgb += IN.vlight;
			#endif
			
			half4 c = LightingBlinnPhong_PrePass (o, light);
			
			return LLEncodeGamma( GoHDRApplyCorrection( c ) );
		}
		
		ENDCG
	}
	
	Pass {
		Name "FORWARD"
		Tags { "LightMode" = "ForwardBase" }
		
		ColorMask RGB
		Program "fp" {
			
			SubProgram "opengl " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				"3.0-!!ARBfp1.0
				# 35 ALU, 2 TEX
				PARAM c[6] = { program.local[0..4],
				{ 2, 1, 0, 128 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEX R1.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MAD R1.xy, R1.wyzw, c[5].x, -c[5].y;
				DP3 R0.w, fragment.texcoord[3], fragment.texcoord[3];
				MOV R2.x, c[5].w;
				MUL R1.zw, R1.xyxy, R1.xyxy;
				RSQ R0.w, R0.w;
				MOV R0.xyz, fragment.texcoord[1];
				MAD R0.xyz, R0.w, fragment.texcoord[3], R0;
				ADD_SAT R0.w, R1.z, R1;
				DP3 R1.z, R0, R0;
				RSQ R1.z, R1.z;
				ADD R0.w, -R0, c[5].y;
				MUL R0.xyz, R1.z, R0;
				RSQ R0.w, R0.w;
				RCP R1.z, R0.w;
				DP3 R0.x, -R1, R0;
				MAX R1.w, R0.x, c[5].z;
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				MUL R2.x, R2, c[3];
				DP3 R1.x, -R1, fragment.texcoord[1];
				MAX R2.w, R1.x, c[5].z;
				MUL R0.w, R0, c[2];
				MOV R1.xyz, c[1];
				MUL R0.xyz, R0, c[2];
				POW R1.w, R1.w, R2.x;
				MUL R2.xyz, R0, c[0];
				MUL R1.w, R1, R0.x;
				MUL R2.xyz, R2, R2.w;
				MUL R1.xyz, R1, c[0];
				MAD R1.xyz, R1, R1.w, R2;
				MUL R1.xyz, R1, c[5].x;
				MAD result.color.xyz, fragment.texcoord[2], R0, R1;
				SLT R0.x, R0.w, c[4];
				MOV result.color.w, R0;
				KIL -R0.x;
				END
				# 35 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				"ps_3_0
				; 37 ALU, 3 TEX
				dcl_2d s0
				dcl_2d s1
				def c5, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c6, 128.00000000, 0, 0, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1.xyz
				dcl_texcoord2 v2.xyz
				dcl_texcoord3 v3.xyz
				texld r0.yw, v0.zwzw, s1
				mad_pp r0.xy, r0.wyzw, c5.z, c5.w
				mul_pp r0.zw, r0.xyxy, r0.xyxy
				add_pp_sat r0.z, r0, r0.w
				dp3_pp r1.w, v3, v3
				add_pp r0.z, -r0, c5.y
				rsq_pp r0.z, r0.z
				rcp_pp r0.z, r0.z
				rsq_pp r1.w, r1.w
				mov_pp r1.xyz, v1
				mad_pp r1.xyz, r1.w, v3, r1
				dp3_pp r0.w, r1, r1
				rsq_pp r0.w, r0.w
				mul_pp r1.xyz, r0.w, r1
				dp3_pp r0.w, -r0, r1
				mov_pp r1.w, c3.x
				mul_pp r1.x, c6, r1.w
				max_pp r0.w, r0, c5.x
				pow r2, r0.w, r1.x
				texld r1, v0, s0
				mul_pp r1.w, r1, c2
				mul_pp r1.xyz, r1, c2
				mov r0.w, r2.x
				dp3_pp r0.x, -r0, v1
				max_pp r2.x, r0, c5
				mul_pp r0.xyz, r1, c0
				mul_pp r0.xyz, r0, r2.x
				mov_pp r2.xyz, c0
				mul r0.w, r0, r1.x
				mul_pp r2.xyz, c1, r2
				mad r0.xyz, r2, r0.w, r0
				mul r2.xyz, r0, c5.z
				add_pp r2.w, r1, -c4.x
				cmp r0.w, r2, c5.x, c5.y
				mov_pp r0, -r0.w
				mad_pp oC0.xyz, v2, r1, r2
				texkill r0.xyzw
				mov_pp oC0.w, r1
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				Vector 2 [_Color]
				Float 4 [_Cutoff]
				Vector 0 [_LightColor0]
				Float 3 [_Shininess]
				Vector 1 [_SpecColor]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				
				"ps_360
				backbbaaaaaaableaaaaabjmaaaaaaaaaaaaaaceaaaaabfmaaaaabieaaaaaaaa
				aaaaaaaaaaaaabdeaaaaaabmaaaaabchppppadaaaaaaaaahaaaaaabmaaaaaaaa
				aaaaabcaaaaaaakiaaadaaabaaabaaaaaaaaaaleaaaaaaaaaaaaaameaaacaaac
				aaabaaaaaaaaaammaaaaaaaaaaaaaanmaaacaaaeaaabaaaaaaaaaaoeaaaaaaaa
				aaaaaapeaaacaaaaaaabaaaaaaaaaammaaaaaaaaaaaaababaaadaaaaaaabaaaa
				aaaaaaleaaaaaaaaaaaaabakaaacaaadaaabaaaaaaaaaaoeaaaaaaaaaaaaabbf
				aaacaaabaaabaaaaaaaaaammaaaaaaaafpechfgnhaengbhaaaklklklaaaeaaam
				aaabaaabaaabaaaaaaaaaaaafpedgpgmgphcaaklaaabaaadaaabaaaeaaabaaaa
				aaaaaaaafpedhfhegpggggaaaaaaaaadaaabaaabaaabaaaaaaaaaaaafpemgjgh
				giheedgpgmgphcdaaafpengbgjgofegfhiaafpfdgigjgogjgogfhdhdaafpfdha
				gfgdedgpgmgphcaahahdfpddfpdaaadccodacodcdadddfddcodaaaklaaaaaaaa
				aaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaeaaaaaabfmbaaaagaaaaaaaaaeaaaaaaaaaaaadeieaaapaaap
				aaaaaacbaaaapafaaaaahbfbaaaahcfcaaaahdfdaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaalpiaaaaaedaaaaaa
				dpiaaaaaeaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabajfaadaaaabcaameaaaaaa
				aaaagaaigaaobcaabcaaaaaaaaaagabecabkbcaaccaaaaaabaaieaabbpbppgii
				aaaaeaaamiacaaaaaablblaakbaeacaaliiiacababloloebnaadadaemiaaaaaa
				aagmblaahjpoacaadibiaaabbpbpphpjaaaaeaaamiahaaafaaleleaacbaaabaa
				fiehaaaeaamamablkbaeacibmiadaaagaagpgmlbilaapppomjabaaaaaalalagm
				nbagagpomiahaaadaamgmamaolaaadabmiaeaaaaaaloloaapaadadaafiebaaaa
				aegmblmgkaaapoiakaehagadaamamggmobadaaiamiabaaaaaeloloaapaagabaa
				beaeaaaaaclologmnaadagadamifabaaaamegmmgicaapopoeaihaaabaalelemg
				kbaeaaiamiapaaadaadecmaaobabaaaadibnabaaaapapablobaeacadmiaiaaae
				aagmgmaaobaeabaamiaoaaabaahgflaaobafaeaamiabaaabaablgmaaobababaa
				miahaaabaamamaaaoaadabaamianaaaaaapagmaeklabppaamiapiaaaaajejeaa
				ocaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0003c020000ffff0000000000000848003000000
				[Offsets]
				5
				_LightColor0 2 0
				00000220000001b0
				_SpecColor 1 0
				00000200
				_Color 1 0
				00000020
				_Shininess 1 0
				000000c0
				_Cutoff 1 0
				00000040
				[Microcode]
				688
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				940217025c011c9dc8000001c8003fe106880440ce041c9d00020000aa020000
				000040000000bf800000000000000000ee803940c8011c9dc8000029c800bfe1
				1080b840c9101c9dc9100001c8000001028a014000021c9cc8000001c8000001
				00000000000000000000000000000000ae840140c8011c9dc8000001c8003fe1
				0e800340c9081c9dc9000001c80000010e863940c9001c9dc8000029c8000001
				02800340ff001c9f00020000c800000100003f80000000000000000000000000
				1080024001141c9caa020000c800000100000000000043000000000000000000
				08883b4001003c9cc9000001c800000110880540c9101c9fc90c0001c8000001
				10020900c9101c9d00020000c800000100000000000000000000000000000000
				02800540c9101c9fc9080001c800000102021d00fe041c9dc8000001c8000001
				0e860140c8021c9dc8000001c800000100000000000000000000000000000000
				1004020000041c9cc9000001c8000001ce880140c8011c9dc8000001c8003fe1
				04001c00fe081c9dc8000001c80000010e8a0240c90c1c9dc8020001c8000001
				000000000000000000000000000000000e840240f3041c9dc8020001c8000001
				000000000000000000000000000000001084090001001c9cc8020001c8000001
				000000000000000000000000000000000e840240c9081c9dff080001c8000001
				10020200ab041c9caa000000c80000011e020100c8041c9dc8000001c8000001
				0e800400c9141c9dfe041001c90800011080014001041c9cc8000001c8000001
				0e810440f3041c9dc9100001c9000001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				ConstBuffer "$Globals" 128 
				Vector 16 [_LightColor0] 4
				Vector 32 [_SpecColor] 4
				Vector 48 [_Color] 4
				Float 64 [_Shininess]
				Float 112 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 0
				SetTexture 1 [_BumpMap] 2D 1
				
				"ps_4_0
				eefiecedoopmhnnagkjlfkllkihcfamemjeljaghabaaaaaagiafaaaaadaaaaaa
				cmaaaaaammaaaaaaaaabaaaaejfdeheojiaaaaaaafaaaaaaaiaaaaaaiaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaimaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaaimaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				ahahaaaaimaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaaimaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaahahaaaafdfgfpfaepfdejfeejepeoaa
				feeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaa
				aaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklkl
				fdeieefcgaaeaaaaeaaaaaaabiabaaaafjaaaaaeegiocaaaaaaaaaaaaiaaaaaa
				fkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaafibiaaaeaahabaaa
				aaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaaffffaaaagcbaaaadpcbabaaa
				abaaaaaagcbaaaadhcbabaaaacaaaaaagcbaaaadhcbabaaaadaaaaaagcbaaaad
				hcbabaaaaeaaaaaagfaaaaadpccabaaaaaaaaaaagiaaaaacadaaaaaaefaaaaaj
				pcaabaaaaaaaaaaaegbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaaaaaaaaa
				dcaaaaambcaabaaaabaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaadaaaaaa
				akiacaiaebaaaaaaaaaaaaaaahaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaa
				aaaaaaaaegiocaaaaaaaaaaaadaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaa
				abaaaaaaabeaaaaaaaaaaaaaanaaaeadakaabaaaabaaaaaabaaaaaahbcaabaaa
				abaaaaaaegbcbaaaaeaaaaaaegbcbaaaaeaaaaaaeeaaaaafbcaabaaaabaaaaaa
				akaabaaaabaaaaaadcaaaaajhcaabaaaabaaaaaaegbcbaaaaeaaaaaaagaabaaa
				abaaaaaaegbcbaaaacaaaaaabaaaaaahicaabaaaabaaaaaaegacbaaaabaaaaaa
				egacbaaaabaaaaaaeeaaaaaficaabaaaabaaaaaadkaabaaaabaaaaaadiaaaaah
				hcaabaaaabaaaaaapgapbaaaabaaaaaaegacbaaaabaaaaaaefaaaaajpcaabaaa
				acaaaaaaogbkbaaaabaaaaaaeghobaaaabaaaaaaaagabaaaabaaaaaadcaaaaap
				dcaabaaaacaaaaaahgapbaaaacaaaaaaaceaaaaaaaaaaaeaaaaaaaeaaaaaaaaa
				aaaaaaaaaceaaaaaaaaaialpaaaaialpaaaaaaaaaaaaaaaaapaaaaahicaabaaa
				abaaaaaaegaabaaaacaaaaaaegaabaaaacaaaaaaddaaaaahicaabaaaabaaaaaa
				dkaabaaaabaaaaaaabeaaaaaaaaaiadpaaaaaaaiicaabaaaabaaaaaadkaabaia
				ebaaaaaaabaaaaaaabeaaaaaaaaaiadpelaaaaafecaabaaaacaaaaaadkaabaaa
				abaaaaaabaaaaaaibcaabaaaabaaaaaaegacbaiaebaaaaaaacaaaaaaegacbaaa
				abaaaaaabaaaaaaiccaabaaaabaaaaaaegacbaiaebaaaaaaacaaaaaaegbcbaaa
				acaaaaaadeaaaaakdcaabaaaabaaaaaaegaabaaaabaaaaaaaceaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaacpaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaa
				diaaaaaiecaabaaaabaaaaaaakiacaaaaaaaaaaaaeaaaaaaabeaaaaaaaaaaaed
				diaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaackaabaaaabaaaaaabjaaaaaf
				bcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaahbcaabaaaabaaaaaaakaabaaa
				aaaaaaaaakaabaaaabaaaaaadiaaaaajhcaabaaaacaaaaaaegiccaaaaaaaaaaa
				abaaaaaaegiccaaaaaaaaaaaacaaaaaadiaaaaahncaabaaaabaaaaaaagaabaaa
				abaaaaaaagajbaaaacaaaaaadiaaaaaihcaabaaaacaaaaaaegacbaaaaaaaaaaa
				egiccaaaaaaaaaaaabaaaaaadcaaaaajhcaabaaaabaaaaaaegacbaaaacaaaaaa
				fgafbaaaabaaaaaaigadbaaaabaaaaaaaaaaaaahhcaabaaaabaaaaaaegacbaaa
				abaaaaaaegacbaaaabaaaaaadcaaaaajhccabaaaaaaaaaaaegacbaaaaaaaaaaa
				egbcbaaaadaaaaaaegacbaaaabaaaaaadgaaaaaficcabaaaaaaaaaaadkaabaaa
				aaaaaaaadoaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				Vector 0 [_Color]
				Float 1 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [unity_Lightmap] 2D
				"3.0-!!ARBfp1.0
				# 10 ALU, 2 TEX
				PARAM c[3] = { program.local[0..1],
				{ 8 } };
				
				TEMP R0;
				TEMP R1;
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				TEX R1, fragment.texcoord[1], texture[2], 2D;
				MUL R0.xyz, R0, c[0];
				MUL R1.xyz, R1.w, R1;
				MUL R1.xyz, R1, R0;
				MUL R0.x, R0.w, c[0].w;
				SLT R0.y, R0.x, c[1].x;
				MUL result.color.xyz, R1, c[2].x;
				MOV result.color.w, R0.x;
				KIL -R0.y;
				END
				# 10 instructions, 2 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				Vector 0 [_Color]
				Float 1 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [unity_Lightmap] 2D
				"ps_3_0
				; 9 ALU, 3 TEX
				dcl_2d s0
				dcl_2d s2
				def c2, 0.00000000, 1.00000000, 8.00000000, 0
				dcl_texcoord0 v0.xy
				dcl_texcoord1 v1.xy
				texld r0, v0, s0
				mul_pp r0.w, r0, c0
				add_pp r1.x, r0.w, -c1
				cmp r2.x, r1, c2, c2.y
				texld r1, v1, s2
				mul_pp r1.xyz, r1.w, r1
				mul_pp r0.xyz, r0, c0
				mul_pp r0.xyz, r1, r0
				mov_pp r1, -r2.x
				mul_pp oC0.xyz, r0, c2.z
				texkill r1.xyzw
				mov_pp oC0.w, r0
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				Vector 0 [_Color]
				Float 1 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [unity_Lightmap] 2D
				
				"ps_360
				backbbaaaaaaabfeaaaaaanaaaaaaaaaaaaaaaceaaaaabaeaaaaabcmaaaaaaaa
				aaaaaaaaaaaaaanmaaaaaabmaaaaaamoppppadaaaaaaaaaeaaaaaabmaaaaaaaa
				aaaaaamhaaaaaagmaaacaaaaaaabaaaaaaaaaaheaaaaaaaaaaaaaaieaaacaaab
				aaabaaaaaaaaaaimaaaaaaaaaaaaaajmaaadaaaaaaabaaaaaaaaaakiaaaaaaaa
				aaaaaaliaaadaaabaaabaaaaaaaaaakiaaaaaaaafpedgpgmgphcaaklaaabaaad
				aaabaaaeaaabaaaaaaaaaaaafpedhfhegpggggaaaaaaaaadaaabaaabaaabaaaa
				aaaaaaaafpengbgjgofegfhiaaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaa
				hfgogjhehjfpemgjghgihegngbhaaahahdfpddfpdaaadccodacodcdadddfddco
				daaaklklaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeaaaaaaajabaaaacaaaaaaaaaeaaaaaaaa
				aaaabiecaaadaaadaaaaaacbaaaapafaaaaadbfbaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaebaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabajfaacaaaabcaameaaaaaa
				aaaaeaahaaaaccaaaaaaaaaabaaiaaabbpbppefiaaaaeaaakicaaaaaaaaaaaab
				mcaaaaaalibhaaacabbemaebibaaaaabmiaaaaaaaalbgmaahjppaaaababibacb
				bpbppgiiaaaaeaaakmbaaaaaaaaaaaedmcaaaappmianaaaaaagmpaaaobaaabaa
				mianaaaaaapaaeaaobacaaaamiapiaaaaajejeaaocaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				Vector 0 [_Color]
				Float 1 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [unity_Lightmap] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0000c0200003fffe000000000000848002000000
				[Offsets]
				2
				_Color 1 0
				00000020
				_Cutoff 1 0
				00000040
				[Microcode]
				160
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				1080014001041c9cc8000001c8000001be021704c8011c9dc8000001c8003fe1
				0e800240f3041c9dfe040001c80000010e810240c9001c9dc8043001c8000001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				ConstBuffer "$Globals" 144 
				Vector 48 [_Color] 4
				Float 128 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 0
				SetTexture 1 [unity_Lightmap] 2D 1
				
				"ps_4_0
				eefiecednofjggokjjfoknmnpkmccafgbfeiceaoabaaaaaaiaacaaaaadaaaaaa
				cmaaaaaajmaaaaaanaaaaaaaejfdeheogiaaaaaaadaaaaaaaiaaaaaafaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaafmaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapadaaaafmaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				adadaaaafdfgfpfaepfdejfeejepeoaafeeffiedepepfceeaaklklklepfdeheo
				cmaaaaaaabaaaaaaaiaaaaaacaaaaaaaaaaaaaaaaaaaaaaaadaaaaaaaaaaaaaa
				apaaaaaafdfgfpfegbhcghgfheaaklklfdeieefckiabaaaaeaaaaaaagkaaaaaa
				fjaaaaaeegiocaaaaaaaaaaaajaaaaaafkaaaaadaagabaaaaaaaaaaafkaaaaad
				aagabaaaabaaaaaafibiaaaeaahabaaaaaaaaaaaffffaaaafibiaaaeaahabaaa
				abaaaaaaffffaaaagcbaaaaddcbabaaaabaaaaaagcbaaaaddcbabaaaacaaaaaa
				gfaaaaadpccabaaaaaaaaaaagiaaaaacacaaaaaaefaaaaajpcaabaaaaaaaaaaa
				egbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaaaaaaaaadcaaaaambcaabaaa
				abaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaadaaaaaaakiacaiaebaaaaaa
				aaaaaaaaaiaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaaegiocaaa
				aaaaaaaaadaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaa
				aaaaaaaaanaaaeadakaabaaaabaaaaaaefaaaaajpcaabaaaabaaaaaaegbabaaa
				acaaaaaaeghobaaaabaaaaaaaagabaaaabaaaaaadiaaaaahicaabaaaabaaaaaa
				dkaabaaaabaaaaaaabeaaaaaaaaaaaebdiaaaaahhcaabaaaabaaaaaaegacbaaa
				abaaaaaapgapbaaaabaaaaaadiaaaaahhccabaaaaaaaaaaaegacbaaaaaaaaaaa
				egacbaaaabaaaaaadgaaaaaficcabaaaaaaaaaaadkaabaaaaaaaaaaadoaaaaab
				"
			}
			
			SubProgram "gles " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_OFF" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [unity_Lightmap] 2D
				SetTexture 3 [unity_LightmapInd] 2D
				"3.0-!!ARBfp1.0
				# 45 ALU, 4 TEX
				PARAM c[8] = { program.local[0..3],
					{ 2, 1, 8, 0 },
					{ -0.40824828, -0.70710677, 0.57735026, 128 },
					{ -0.40824831, 0.70710677, 0.57735026 },
				{ 0.81649655, 0, 0.57735026 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEMP R3;
				TEX R1.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MAD R3.xy, R1.wyzw, c[4].x, -c[4].y;
				TEX R0, fragment.texcoord[1], texture[3], 2D;
				MUL R0.xyz, R0.w, R0;
				MUL R2.xyz, R0, c[4].z;
				MUL R0.xyz, R2.y, c[6];
				MAD R0.xyz, R2.x, c[7], R0;
				MAD R0.xyz, R2.z, c[5], R0;
				DP3 R0.w, R0, R0;
				RSQ R0.w, R0.w;
				MUL R0.xyz, R0.w, R0;
				DP3 R0.w, fragment.texcoord[2], fragment.texcoord[2];
				RSQ R0.w, R0.w;
				MUL R1.xy, R3, R3;
				MAD R0.xyz, R0.w, fragment.texcoord[2], R0;
				ADD_SAT R0.w, R1.x, R1.y;
				DP3 R1.x, R0, R0;
				RSQ R1.x, R1.x;
				ADD R0.w, -R0, c[4].y;
				RSQ R0.w, R0.w;
				RCP R3.z, R0.w;
				MUL R0.xyz, R1.x, R0;
				DP3 R0.x, -R3, R0;
				MOV R0.w, c[5];
				MUL R0.y, R0.w, c[2].x;
				MAX R0.x, R0, c[4].w;
				POW R1.w, R0.x, R0.y;
				TEX R0, fragment.texcoord[1], texture[2], 2D;
				DP3_SAT R1.z, -R3, c[5];
				DP3_SAT R1.y, -R3, c[6];
				DP3_SAT R1.x, -R3, c[7];
				DP3 R1.x, R1, R2;
				MUL R0.xyz, R0.w, R0;
				MUL R1.xyz, R0, R1.x;
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				MUL R0.w, R0, c[1];
				MUL R2.xyz, R0, c[1];
				MUL R1.xyz, R1, c[4].z;
				MUL R0.xyz, R1, c[0];
				MUL R0.xyz, R0, R2.x;
				MUL R0.xyz, R0, R1.w;
				MAD result.color.xyz, R1, R2, R0;
				SLT R0.x, R0.w, c[3];
				MOV result.color.w, R0;
				KIL -R0.x;
				END
				# 45 instructions, 4 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [unity_Lightmap] 2D
				SetTexture 3 [unity_LightmapInd] 2D
				"ps_3_0
				; 45 ALU, 5 TEX
				dcl_2d s0
				dcl_2d s1
				dcl_2d s2
				dcl_2d s3
				def c4, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c5, -0.40824828, -0.70710677, 0.57735026, 8.00000000
				def c6, -0.40824831, 0.70710677, 0.57735026, 128.00000000
				def c7, 0.81649655, 0.00000000, 0.57735026, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1.xy
				dcl_texcoord2 v2.xyz
				texld r0, v1, s3
				mul_pp r0.xyz, r0.w, r0
				mul_pp r2.xyz, r0, c5.w
				mul r0.xyz, r2.y, c6
				mad r0.xyz, r2.x, c7, r0
				mad r0.xyz, r2.z, c5, r0
				dp3 r0.w, r0, r0
				rsq r0.w, r0.w
				texld r1.yw, v0.zwzw, s1
				mad_pp r1.xy, r1.wyzw, c4.z, c4.w
				mul r0.xyz, r0.w, r0
				dp3_pp r0.w, v2, v2
				rsq_pp r0.w, r0.w
				mul_pp r1.zw, r1.xyxy, r1.xyxy
				mad_pp r0.xyz, r0.w, v2, r0
				add_pp_sat r0.w, r1.z, r1
				dp3_pp r1.z, r0, r0
				rsq_pp r1.z, r1.z
				add_pp r0.w, -r0, c4.y
				mul_pp r0.xyz, r1.z, r0
				rsq_pp r0.w, r0.w
				rcp_pp r1.z, r0.w
				dp3_pp r0.x, -r1, r0
				mov_pp r0.w, c2.x
				mul_pp r2.w, c6, r0
				max_pp r1.w, r0.x, c4.x
				pow r0, r1.w, r2.w
				dp3_pp_sat r0.w, -r1, c5
				dp3_pp_sat r0.z, -r1, c6
				dp3_pp_sat r0.y, -r1, c7
				dp3_pp r0.y, r0.yzww, r2
				texld r2, v0, s0
				mul_pp r1.w, r2, c1
				texld r3, v1, s2
				mul_pp r1.xyz, r3.w, r3
				mul_pp r1.xyz, r1, r0.y
				add_pp r2.w, r1, -c3.x
				mov r0.w, r0.x
				mul_pp r1.xyz, r1, c5.w
				mul_pp r2.xyz, r2, c1
				mul_pp r0.xyz, r1, c0
				mul_pp r0.xyz, r0, r2.x
				mul r3.xyz, r0, r0.w
				cmp r2.w, r2, c4.x, c4.y
				mov_pp r0, -r2.w
				mad_pp oC0.xyz, r1, r2, r3
				texkill r0.xyzw
				mov_pp oC0.w, r1
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_OFF" }
				
				Vector 1 [_Color]
				Float 3 [_Cutoff]
				Float 2 [_Shininess]
				Vector 0 [_SpecColor]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [unity_Lightmap] 2D
				SetTexture 3 [unity_LightmapInd] 2D
				
				"ps_360
				backbbaaaaaaabniaaaaacaiaaaaaaaaaaaaaaceaaaaabieaaaaabkmaaaaaaaa
				aaaaaaaaaaaaabfmaaaaaabmaaaaabepppppadaaaaaaaaaiaaaaaabmaaaaaaaa
				aaaaabeiaaaaaalmaaadaaabaaabaaaaaaaaaamiaaaaaaaaaaaaaaniaaacaaab
				aaabaaaaaaaaaaoaaaaaaaaaaaaaaapaaaacaaadaaabaaaaaaaaaapiaaaaaaaa
				aaaaabaiaaadaaaaaaabaaaaaaaaaamiaaaaaaaaaaaaabbbaaacaaacaaabaaaa
				aaaaaapiaaaaaaaaaaaaabbmaaacaaaaaaabaaaaaaaaaaoaaaaaaaaaaaaaabch
				aaadaaacaaabaaaaaaaaaamiaaaaaaaaaaaaabdgaaadaaadaaabaaaaaaaaaami
				aaaaaaaafpechfgnhaengbhaaaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaa
				fpedgpgmgphcaaklaaabaaadaaabaaaeaaabaaaaaaaaaaaafpedhfhegpggggaa
				aaaaaaadaaabaaabaaabaaaaaaaaaaaafpengbgjgofegfhiaafpfdgigjgogjgo
				gfhdhdaafpfdhagfgdedgpgmgphcaahfgogjhehjfpemgjghgihegngbhaaahfgo
				gjhehjfpemgjghgihegngbhaejgogeaahahdfpddfpdaaadccodacodcdadddfdd
				codaaaklaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeaaaaaabmibaaaagaaaaaaaaaeaaaaaaaa
				aaaacegdaaahaaahaaaaaacbaaaapafaaaaadbfbaaaahcfcdpiaaaaaedaaaaaa
				aaaaaaaaaaaaaaaaeaaaaaaaebaaaaaaaaaaaaaalpiaaaaadpbdmndklonbafom
				dpdfaepddpfbafollonbafollpdfaepddpbdmndkdpfbafolafajgaaebaakbcaa
				bcaaaaabaaaaaaaagaalmeaabcaaaaaaaaaagabbgabhbcaabcaaaaaaaaaagabn
				cacdbcaaccaaaaaabaaidaabbpbppgbbaaaaeaaamiaeaaabaablblaakbadabaa
				lmiiabacabloloecnaacacadmiaaaaaaaamgblaahjpnabaabacigacbbpbppgii
				aaaaeaaadibiaaabbpbpppnjaaaaeaaabadifacbbpbppgiiaaaaeaaamiaiaaae
				aagmlbaacbacpmaamiakaaabaagbgmblilaapnpnbebcaaaaaabllbblkbagpnaf
				kibhaaaeaalbmaiambaaagpnmjacaaaaaabjbjmgnbababpnfibnabaaaagmonbl
				obaaafickiehacafaagmmamambabacpolicpaaagaaeogdebibaapopmkabkabac
				aammbblboaagagiamjabaaacaegnmhmgjbabpppnmiahaaagaablmabfklaappac
				miacaaaaaaloloaapaagagaafjccaaacaebamalblaabpoiamiahaaafaamalbma
				olagaaafmiacaaaaaaloloaapaafafaafjceaaacaebalolblaabppiamiahaaaf
				aamalbaaobafaaaabecbaaabaclobamgpaafabadkibcababaagmmgebicabpnab
				eacbaaaaaaghlolbpaaaacibkmcpabaaaaaakmiaobaeaaabkmihabacaamamamb
				kbaaaaabmiahaaaaaabamaaaobabaaaadiilaaabaamagmblobacabaamialaaab
				aabablmaolabaaaamiapiaaaaananaaaocababaaaaaaaaaaaaaaaaaaaaaaaaaa
				"
			}
			
			SubProgram "ps3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [unity_Lightmap] 2D
				SetTexture 3 [unity_LightmapInd] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0001c0200007fffa000000000000848004000000
				[Offsets]
				4
				_SpecColor 1 0
				00000310
				_Color 1 0
				00000020
				_Shininess 1 0
				00000070
				_Cutoff 1 0
				00000040
				[Microcode]
				848
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				1080014000021c9cc8000001c800000100000000000000000000000000000000
				be041706c8011c9dc8000001c8003fe1ce843940c8011c9dc8000029c800bfe1
				0e860240fe081c9dc8083001c80000010e060200ab0c1c9cc8020001c8000001
				05ecbed104f33f35cd3a3f130000000010800240c9001c9dc8020001c8000001
				000000000000000000000000000043000e060400010c1c9cc8020001c80c0001
				05eb3f5100000000cd3a3f1300000000940417025c011c9dc8000001c8003fe1
				068a0440ce081c9d00020000aa020000000040000000bf800000000000000000
				1084b840c9141c9dc9140001c800000110840340c9081c9f00020000c8000001
				00003f800000000000000000000000000e060400550c1c9df2020001c80c0001
				0000000005ebbed104f3bf35cd3a3f13088a3b40ff083c9dff080001c8000001
				08808540c9141c9fc8020001c800000105ebbed104f3bf35cd3a3f1300000000
				04808540c9141c9fc8020001c800000105ecbed104f33f35cd3a3f1300000000
				10060500c80c1c9dc80c0001c80000010e8c3b00c80c1c9dfe0c0001c8000001
				0e060340c9181c9dc9080001c80000010280b84005141c9e08020000c8000001
				cd3a3f1305eb3f51000000000000000018020100c8041c9dc8000001c8000001
				02800540c9001c9dc90c0001c80000010e883940c80c1c9dc8000029c8000001
				04800540c9141c9fc9100001c8000001be021704c8011c9dc8000001c8003fe1
				02800240fe041c9dc9000001c800000110020900ab001c9c00020000c8000001
				000000000000000000000000000000000e84024001001c9cc8043001c8000001
				08021d00fe041c9dc8000001c80000010e800240f3041c9dc9080001c8000001
				1002020054041c9dc9000001c800000110801c00fe041c9dc8000001c8000001
				0e840240c9081c9dc8020001c800000100000000000000000000000000000000
				0e840240ab041c9cc9080001c80000010e800440c9081c9dff000001c9000001
				1081014001041c9cc8000001c8000001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_OFF" }
				
				ConstBuffer "$Globals" 144 
				Vector 32 [_SpecColor] 4
				Vector 48 [_Color] 4
				Float 64 [_Shininess]
				Float 128 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 0
				SetTexture 1 [_BumpMap] 2D 1
				SetTexture 2 [unity_Lightmap] 2D 2
				SetTexture 3 [unity_LightmapInd] 2D 3
				
				"ps_4_0
				eefiecedifkddglpknaiflibhjhcndbfgfeeheidabaaaaaadeahaaaaadaaaaaa
				cmaaaaaaleaaaaaaoiaaaaaaejfdeheoiaaaaaaaaeaaaaaaaiaaaaaagiaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaheaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaaheaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				adadaaaaheaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaafdfgfpfa
				epfdejfeejepeoaafeeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaa
				aiaaaaaacaaaaaaaaaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfe
				gbhcghgfheaaklklfdeieefceeagaaaaeaaaaaaajbabaaaafjaaaaaeegiocaaa
				aaaaaaaaajaaaaaafkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaa
				fkaaaaadaagabaaaacaaaaaafkaaaaadaagabaaaadaaaaaafibiaaaeaahabaaa
				aaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaaffffaaaafibiaaaeaahabaaa
				acaaaaaaffffaaaafibiaaaeaahabaaaadaaaaaaffffaaaagcbaaaadpcbabaaa
				abaaaaaagcbaaaaddcbabaaaacaaaaaagcbaaaadhcbabaaaadaaaaaagfaaaaad
				pccabaaaaaaaaaaagiaaaaacafaaaaaaefaaaaajpcaabaaaaaaaaaaaegbabaaa
				abaaaaaaeghobaaaaaaaaaaaaagabaaaaaaaaaaadcaaaaambcaabaaaabaaaaaa
				dkaabaaaaaaaaaaadkiacaaaaaaaaaaaadaaaaaaakiacaiaebaaaaaaaaaaaaaa
				aiaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaaegiocaaaaaaaaaaa
				adaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaaaaaaaaaa
				anaaaeadakaabaaaabaaaaaabaaaaaahbcaabaaaabaaaaaaegbcbaaaadaaaaaa
				egbcbaaaadaaaaaaeeaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaah
				hcaabaaaabaaaaaaagaabaaaabaaaaaaegbcbaaaadaaaaaaefaaaaajpcaabaaa
				acaaaaaaegbabaaaacaaaaaaeghobaaaadaaaaaaaagabaaaadaaaaaadiaaaaah
				icaabaaaabaaaaaadkaabaaaacaaaaaaabeaaaaaaaaaaaebdiaaaaahhcaabaaa
				acaaaaaaegacbaaaacaaaaaapgapbaaaabaaaaaadiaaaaakhcaabaaaadaaaaaa
				fgafbaaaacaaaaaaaceaaaaaomafnblopdaedfdpdkmnbddpaaaaaaaadcaaaaam
				hcaabaaaadaaaaaaagaabaaaacaaaaaaaceaaaaaolaffbdpaaaaaaaadkmnbddp
				aaaaaaaaegacbaaaadaaaaaadcaaaaamhcaabaaaadaaaaaakgakbaaaacaaaaaa
				aceaaaaaolafnblopdaedflpdkmnbddpaaaaaaaaegacbaaaadaaaaaabaaaaaah
				icaabaaaabaaaaaaegacbaaaadaaaaaaegacbaaaadaaaaaaeeaaaaaficaabaaa
				abaaaaaadkaabaaaabaaaaaadcaaaaajhcaabaaaabaaaaaaegacbaaaadaaaaaa
				pgapbaaaabaaaaaaegacbaaaabaaaaaabaaaaaahicaabaaaabaaaaaaegacbaaa
				abaaaaaaegacbaaaabaaaaaaeeaaaaaficaabaaaabaaaaaadkaabaaaabaaaaaa
				diaaaaahhcaabaaaabaaaaaapgapbaaaabaaaaaaegacbaaaabaaaaaaefaaaaaj
				pcaabaaaadaaaaaaogbkbaaaabaaaaaaeghobaaaabaaaaaaaagabaaaabaaaaaa
				dcaaaaapdcaabaaaadaaaaaahgapbaaaadaaaaaaaceaaaaaaaaaaaeaaaaaaaea
				aaaaaaaaaaaaaaaaaceaaaaaaaaaialpaaaaialpaaaaaaaaaaaaaaaaapaaaaah
				icaabaaaabaaaaaaegaabaaaadaaaaaaegaabaaaadaaaaaaddaaaaahicaabaaa
				abaaaaaadkaabaaaabaaaaaaabeaaaaaaaaaiadpaaaaaaaiicaabaaaabaaaaaa
				dkaabaiaebaaaaaaabaaaaaaabeaaaaaaaaaiadpelaaaaafecaabaaaadaaaaaa
				dkaabaaaabaaaaaabaaaaaaibcaabaaaabaaaaaaegacbaiaebaaaaaaadaaaaaa
				egacbaaaabaaaaaadeaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaa
				aaaaaaaacpaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaaiccaabaaa
				abaaaaaaakiacaaaaaaaaaaaaeaaaaaaabeaaaaaaaaaaaeddiaaaaahbcaabaaa
				abaaaaaaakaabaaaabaaaaaabkaabaaaabaaaaaabjaaaaafbcaabaaaabaaaaaa
				akaabaaaabaaaaaaapcaaaalbcaabaaaaeaaaaaaaceaaaaaolaffbdpdkmnbddp
				aaaaaaaaaaaaaaaaigaabaiaebaaaaaaadaaaaaabacaaaalccaabaaaaeaaaaaa
				aceaaaaaomafnblopdaedfdpdkmnbddpaaaaaaaaegacbaiaebaaaaaaadaaaaaa
				bacaaaalecaabaaaaeaaaaaaaceaaaaaolafnblopdaedflpdkmnbddpaaaaaaaa
				egacbaiaebaaaaaaadaaaaaabaaaaaahccaabaaaabaaaaaaegacbaaaaeaaaaaa
				egacbaaaacaaaaaaefaaaaajpcaabaaaacaaaaaaegbabaaaacaaaaaaeghobaaa
				acaaaaaaaagabaaaacaaaaaadiaaaaahecaabaaaabaaaaaadkaabaaaacaaaaaa
				abeaaaaaaaaaaaebdiaaaaahhcaabaaaacaaaaaaegacbaaaacaaaaaakgakbaaa
				abaaaaaadiaaaaahocaabaaaabaaaaaafgafbaaaabaaaaaaagajbaaaacaaaaaa
				diaaaaaihcaabaaaacaaaaaajgahbaaaabaaaaaaegiccaaaaaaaaaaaacaaaaaa
				diaaaaahocaabaaaabaaaaaaagajbaaaaaaaaaaafgaobaaaabaaaaaadiaaaaah
				hcaabaaaaaaaaaaaagaabaaaaaaaaaaaegacbaaaacaaaaaadgaaaaaficcabaaa
				aaaaaaaadkaabaaaaaaaaaaadcaaaaajhccabaaaaaaaaaaaegacbaaaaaaaaaaa
				agaabaaaabaaaaaajgahbaaaabaaaaaadoaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_OFF" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_ShadowMapTexture] 2D
				"3.0-!!ARBfp1.0
				# 37 ALU, 3 TEX
				PARAM c[6] = { program.local[0..4],
				{ 2, 1, 0, 128 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEMP R3;
				TEX R1.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MAD R1.xy, R1.wyzw, c[5].x, -c[5].y;
				DP3 R0.w, fragment.texcoord[3], fragment.texcoord[3];
				TXP R3.x, fragment.texcoord[4], texture[2], 2D;
				MUL R1.zw, R1.xyxy, R1.xyxy;
				RSQ R0.w, R0.w;
				MOV R0.xyz, fragment.texcoord[1];
				MAD R0.xyz, R0.w, fragment.texcoord[3], R0;
				ADD_SAT R0.w, R1.z, R1;
				DP3 R1.z, R0, R0;
				RSQ R1.z, R1.z;
				ADD R0.w, -R0, c[5].y;
				MUL R0.xyz, R1.z, R0;
				RSQ R0.w, R0.w;
				RCP R1.z, R0.w;
				DP3 R0.y, -R1, R0;
				MOV R0.x, c[5].w;
				MUL R2.x, R0, c[3];
				MAX R1.w, R0.y, c[5].z;
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				MUL R0.w, R0, c[2];
				MUL R0.xyz, R0, c[2];
				POW R1.w, R1.w, R2.x;
				DP3 R1.x, -R1, fragment.texcoord[1];
				MAX R2.x, R1, c[5].z;
				MUL R1.xyz, R0, c[0];
				MUL R2.xyz, R1, R2.x;
				MOV R1.xyz, c[1];
				MUL R1.w, R1, R0.x;
				MUL R1.xyz, R1, c[0];
				MUL R2.w, R3.x, c[5].x;
				MAD R1.xyz, R1, R1.w, R2;
				MUL R1.xyz, R1, R2.w;
				MAD result.color.xyz, fragment.texcoord[2], R0, R1;
				SLT R0.x, R0.w, c[4];
				MOV result.color.w, R0;
				KIL -R0.x;
				END
				# 37 instructions, 4 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_ShadowMapTexture] 2D
				"ps_3_0
				; 37 ALU, 4 TEX
				dcl_2d s0
				dcl_2d s1
				dcl_2d s2
				def c5, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c6, 128.00000000, 0, 0, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1.xyz
				dcl_texcoord2 v2.xyz
				dcl_texcoord3 v3.xyz
				dcl_texcoord4 v4
				texld r1.yw, v0.zwzw, s1
				mad_pp r1.xy, r1.wyzw, c5.z, c5.w
				dp3_pp r0.w, v3, v3
				mul_pp r1.zw, r1.xyxy, r1.xyxy
				rsq_pp r0.w, r0.w
				mov_pp r0.xyz, v1
				mad_pp r0.xyz, r0.w, v3, r0
				add_pp_sat r0.w, r1.z, r1
				dp3_pp r1.z, r0, r0
				rsq_pp r1.z, r1.z
				add_pp r0.w, -r0, c5.y
				mul_pp r0.xyz, r1.z, r0
				rsq_pp r0.w, r0.w
				rcp_pp r1.z, r0.w
				dp3_pp r0.x, -r1, r0
				mov_pp r0.w, c3.x
				mul_pp r2.x, c6, r0.w
				max_pp r1.w, r0.x, c5.x
				pow r0, r1.w, r2.x
				texld r2, v0, s0
				mul_pp r2.xyz, r2, c2
				mul r0.w, r0.x, r2.x
				dp3_pp r0.x, -r1, v1
				max_pp r1.w, r0.x, c5.x
				mul_pp r1.xyz, r2, c0
				mul_pp r1.xyz, r1, r1.w
				mul_pp r1.w, r2, c2
				mov_pp r0.xyz, c0
				mul_pp r0.xyz, c1, r0
				mad r0.xyz, r0, r0.w, r1
				texldp r1.x, v4, s2
				add_pp r0.w, r1, -c4.x
				mul_pp r1.x, r1, c5.z
				mul r1.xyz, r0, r1.x
				cmp r0.w, r0, c5.x, c5.y
				mov_pp r0, -r0.w
				mad_pp oC0.xyz, v2, r2, r1
				texkill r0.xyzw
				mov_pp oC0.w, r1
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				Vector 2 [_Color]
				Float 4 [_Cutoff]
				Vector 0 [_LightColor0]
				Float 3 [_Shininess]
				Vector 1 [_SpecColor]
				SetTexture 0 [_ShadowMapTexture] 2D
				SetTexture 1 [_MainTex] 2D
				SetTexture 2 [_BumpMap] 2D
				
				"ps_360
				backbbaaaaaaaboaaaaaabmaaaaaaaaaaaaaaaceaaaaabieaaaaabkmaaaaaaaa
				aaaaaaaaaaaaabfmaaaaaabmaaaaabenppppadaaaaaaaaaiaaaaaabmaaaaaaaa
				aaaaabegaaaaaalmaaadaaacaaabaaaaaaaaaamiaaaaaaaaaaaaaaniaaacaaac
				aaabaaaaaaaaaaoaaaaaaaaaaaaaaapaaaacaaaeaaabaaaaaaaaaapiaaaaaaaa
				aaaaabaiaaacaaaaaaabaaaaaaaaaaoaaaaaaaaaaaaaabbfaaadaaabaaabaaaa
				aaaaaamiaaaaaaaaaaaaabboaaadaaaaaaabaaaaaaaaaamiaaaaaaaaaaaaabda
				aaacaaadaaabaaaaaaaaaapiaaaaaaaaaaaaabdlaaacaaabaaabaaaaaaaaaaoa
				aaaaaaaafpechfgnhaengbhaaaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaa
				fpedgpgmgphcaaklaaabaaadaaabaaaeaaabaaaaaaaaaaaafpedhfhegpggggaa
				aaaaaaadaaabaaabaaabaaaaaaaaaaaafpemgjghgiheedgpgmgphcdaaafpengb
				gjgofegfhiaafpfdgigbgegphhengbhafegfhihehfhcgfaafpfdgigjgogjgogf
				hdhdaafpfdhagfgdedgpgmgphcaahahdfpddfpdaaadccodacodcdadddfddcoda
				aaklklklaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeaaaaaabiabaaaahaaaaaaaaaeaaaaaaaa
				aaaaeekfaabpaabpaaaaaacbaaaapafaaaaahbfbaaaahcfcaaaahdfdaaaapefe
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaedaaaaaadpiaaaaalpiaaaaa
				afajgaadaaaabcaameaaaaaaaaaagaajgaapbcaabcaaaaaaaaaagabfeablbcaa
				ccaaaaaababifaabbpbppgiiaaaaeaaaemicabaaaablblblkbafacaeliidabae
				abbllaebmbabaeaemiaaaaaaaagmblaahjppabaabaaieaibbpbppppiaaaaeaaa
				dicieaabbpbppompaaaaeaaamiahaaagaamamaaacbaaabaamiabaaaaaaloloaa
				paadadaamiahaaafaamamaaakbafacaafibhaaaeaalelegmoaaeaeiamiahaaah
				aagmmamaolaaadabmiaeaaaaaaloloaapaahahaamiadaaadaamfblaakaaeppaa
				mjabaaaaaalalagmnbadadppfiebaaaaaegmmgmgkaaappiakaehadahaamamggm
				obahaaiamiabaaaaaeloloaapaadabaabeaeaaaaaclologmnaahadadamifabaa
				aamegmlbicaappppeaihaaabaamamamgkbafaaiamiapaaadaaaacmaaobabaaaa
				dibnabaaaapapablobafacadmiaiaaafaagmgmaaobafabaamiaoaaabaaebflaa
				obagafaamiabaaabaablgmaaobababaamiahaaabaamamaaaoaadabaamianaaaa
				aapagmaeolabaeaamiapiaaaaajejeaaocaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				"
			}
			
			SubProgram "ps3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_ShadowMapTexture] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0007c020001fffe0000000000000848004000000
				[Offsets]
				5
				_LightColor0 2 0
				00000230000000a0
				_SpecColor 1 0
				00000120
				_Color 1 0
				00000020
				_Shininess 1 0
				000000d0
				_Cutoff 1 0
				00000040
				[Microcode]
				720
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				940217025c011c9dc8000001c8003fe106840440ce041c9d00020000aa020000
				000040000000bf8000000000000000000e8a0140c8021c9dc8000001c8000001
				000000000000000000000000000000000888b840c9081c9dc9080001c8000001
				028c014000021c9cc8000001c800000100000000000000000000000000000000
				ee803940c8011c9dc8000029c800bfe11080034055101c9fc8020001c8000001
				00000000000000000000000000003f800e8a0240c9141c9dc8020001c8000001
				00000000000000000000000000000000ae860140c8011c9dc8000001c8003fe1
				1084024001181c9c00020000c800000100004300000000000000000000000000
				0e800340c90c1c9dc9000001c800000108843b40ff003c9dff000001c8000001
				1080014001041c9cc8000001c80000010e803940c9001c9dc8000029c8000001
				10860540c9081c9fc9000001c800000102800540c9081c9fc90c0001c8000001
				10020900c90c1c9d00020000c800000100000000000000000000000000000000
				02860900c9001c9d00020000c800000100000000000000000000000000000000
				02001d00fe041c9dc8000001c80000011002020000001c9cc9080001c8000001
				0e840240f3041c9dc8020001c800000100000000000000000000000000000000
				0e840240c9081c9d010c0000c800000102001c00fe041c9dc8000001c8000001
				10020200ab041c9c00000000c8000001ce800140c8011c9dc8000001c8003fe1
				0e020400c9141c9dfe041001c908000102041805c8011c9dc8000001c8003fe1
				1e7e7d00c8001c9dc8000001c80000010e840200c8041c9d00080000c8000001
				0e810440f3041c9dc9000001c9080001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				ConstBuffer "$Globals" 192 
				Vector 16 [_LightColor0] 4
				Vector 32 [_SpecColor] 4
				Vector 112 [_Color] 4
				Float 128 [_Shininess]
				Float 176 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 1
				SetTexture 1 [_BumpMap] 2D 2
				SetTexture 2 [_ShadowMapTexture] 2D 0
				
				"ps_4_0
				eefiecedkagalbdpmaohdmflnfjmkgcdcbhpaemaabaaaaaaaeagaaaaadaaaaaa
				cmaaaaaaoeaaaaaabiabaaaaejfdeheolaaaaaaaagaaaaaaaiaaaaaajiaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaakeaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaakeaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				ahahaaaakeaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaakeaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaahahaaaakeaaaaaaaeaaaaaaaaaaaaaa
				adaaaaaaafaaaaaaapalaaaafdfgfpfaepfdejfeejepeoaafeeffiedepepfcee
				aaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklklfdeieefcoeaeaaaa
				eaaaaaaadjabaaaafjaaaaaeegiocaaaaaaaaaaaamaaaaaafkaaaaadaagabaaa
				aaaaaaaafkaaaaadaagabaaaabaaaaaafkaaaaadaagabaaaacaaaaaafibiaaae
				aahabaaaaaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaaffffaaaafibiaaae
				aahabaaaacaaaaaaffffaaaagcbaaaadpcbabaaaabaaaaaagcbaaaadhcbabaaa
				acaaaaaagcbaaaadhcbabaaaadaaaaaagcbaaaadhcbabaaaaeaaaaaagcbaaaad
				lcbabaaaafaaaaaagfaaaaadpccabaaaaaaaaaaagiaaaaacadaaaaaaefaaaaaj
				pcaabaaaaaaaaaaaegbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaabaaaaaa
				dcaaaaambcaabaaaabaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaahaaaaaa
				akiacaiaebaaaaaaaaaaaaaaalaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaa
				aaaaaaaaegiocaaaaaaaaaaaahaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaa
				abaaaaaaabeaaaaaaaaaaaaaanaaaeadakaabaaaabaaaaaabaaaaaahbcaabaaa
				abaaaaaaegbcbaaaaeaaaaaaegbcbaaaaeaaaaaaeeaaaaafbcaabaaaabaaaaaa
				akaabaaaabaaaaaadcaaaaajhcaabaaaabaaaaaaegbcbaaaaeaaaaaaagaabaaa
				abaaaaaaegbcbaaaacaaaaaabaaaaaahicaabaaaabaaaaaaegacbaaaabaaaaaa
				egacbaaaabaaaaaaeeaaaaaficaabaaaabaaaaaadkaabaaaabaaaaaadiaaaaah
				hcaabaaaabaaaaaapgapbaaaabaaaaaaegacbaaaabaaaaaaefaaaaajpcaabaaa
				acaaaaaaogbkbaaaabaaaaaaeghobaaaabaaaaaaaagabaaaacaaaaaadcaaaaap
				dcaabaaaacaaaaaahgapbaaaacaaaaaaaceaaaaaaaaaaaeaaaaaaaeaaaaaaaaa
				aaaaaaaaaceaaaaaaaaaialpaaaaialpaaaaaaaaaaaaaaaaapaaaaahicaabaaa
				abaaaaaaegaabaaaacaaaaaaegaabaaaacaaaaaaddaaaaahicaabaaaabaaaaaa
				dkaabaaaabaaaaaaabeaaaaaaaaaiadpaaaaaaaiicaabaaaabaaaaaadkaabaia
				ebaaaaaaabaaaaaaabeaaaaaaaaaiadpelaaaaafecaabaaaacaaaaaadkaabaaa
				abaaaaaabaaaaaaibcaabaaaabaaaaaaegacbaiaebaaaaaaacaaaaaaegacbaaa
				abaaaaaabaaaaaaiccaabaaaabaaaaaaegacbaiaebaaaaaaacaaaaaaegbcbaaa
				acaaaaaadeaaaaakdcaabaaaabaaaaaaegaabaaaabaaaaaaaceaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaacpaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaa
				diaaaaaiecaabaaaabaaaaaaakiacaaaaaaaaaaaaiaaaaaaabeaaaaaaaaaaaed
				diaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaackaabaaaabaaaaaabjaaaaaf
				bcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaahbcaabaaaabaaaaaaakaabaaa
				aaaaaaaaakaabaaaabaaaaaadiaaaaajhcaabaaaacaaaaaaegiccaaaaaaaaaaa
				abaaaaaaegiccaaaaaaaaaaaacaaaaaadiaaaaahncaabaaaabaaaaaaagaabaaa
				abaaaaaaagajbaaaacaaaaaadiaaaaaihcaabaaaacaaaaaaegacbaaaaaaaaaaa
				egiccaaaaaaaaaaaabaaaaaadcaaaaajhcaabaaaabaaaaaaegacbaaaacaaaaaa
				fgafbaaaabaaaaaaigadbaaaabaaaaaaaoaaaaahdcaabaaaacaaaaaaegbabaaa
				afaaaaaapgbpbaaaafaaaaaaefaaaaajpcaabaaaacaaaaaaegaabaaaacaaaaaa
				eghobaaaacaaaaaaaagabaaaaaaaaaaaaaaaaaahicaabaaaabaaaaaaakaabaaa
				acaaaaaaakaabaaaacaaaaaadiaaaaahhcaabaaaaaaaaaaaegacbaaaaaaaaaaa
				egbcbaaaadaaaaaadgaaaaaficcabaaaaaaaaaaadkaabaaaaaaaaaaadcaaaaaj
				hccabaaaaaaaaaaaegacbaaaabaaaaaapgapbaaaabaaaaaaegacbaaaaaaaaaaa
				doaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				Vector 0 [_Color]
				Float 1 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_ShadowMapTexture] 2D
				SetTexture 3 [unity_Lightmap] 2D
				"3.0-!!ARBfp1.0
				# 16 ALU, 3 TEX
				PARAM c[3] = { program.local[0..1],
				{ 8, 2 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEX R0, fragment.texcoord[1], texture[3], 2D;
				TXP R2.x, fragment.texcoord[2], texture[2], 2D;
				MUL R1.xyz, R0, R2.x;
				MUL R0.xyz, R0.w, R0;
				MUL R0.xyz, R0, c[2].x;
				MUL R1.xyz, R1, c[2].y;
				MIN R1.xyz, R0, R1;
				MUL R2.xyz, R0, R2.x;
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				MUL R0.w, R0, c[0];
				MUL R0.xyz, R0, c[0];
				MAX R1.xyz, R1, R2;
				MUL result.color.xyz, R0, R1;
				SLT R0.x, R0.w, c[1];
				MOV result.color.w, R0;
				KIL -R0.x;
				END
				# 16 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				Vector 0 [_Color]
				Float 1 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_ShadowMapTexture] 2D
				SetTexture 3 [unity_Lightmap] 2D
				"ps_3_0
				; 14 ALU, 4 TEX
				dcl_2d s0
				dcl_2d s2
				dcl_2d s3
				def c2, 0.00000000, 1.00000000, 8.00000000, 2.00000000
				dcl_texcoord0 v0.xy
				dcl_texcoord1 v1.xy
				dcl_texcoord2 v2
				texld r1, v0, s0
				mul_pp r1.w, r1, c0
				texldp r2.x, v2, s2
				texld r0, v1, s3
				mul_pp r2.yzw, r0.xxyz, r2.x
				mul_pp r0.xyz, r0.w, r0
				add_pp r0.w, r1, -c1.x
				mul_pp r0.xyz, r0, c2.z
				mul_pp r2.yzw, r2, c2.w
				min_pp r2.yzw, r0.xxyz, r2
				mul_pp r0.xyz, r0, r2.x
				max_pp r2.xyz, r2.yzww, r0
				cmp r0.w, r0, c2.x, c2.y
				mov_pp r0, -r0.w
				mul_pp r1.xyz, r1, c0
				mul_pp oC0.xyz, r1, r2
				texkill r0.xyzw
				mov_pp oC0.w, r1
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				Vector 0 [_Color]
				Float 1 [_Cutoff]
				SetTexture 0 [_ShadowMapTexture] 2D
				SetTexture 1 [_MainTex] 2D
				SetTexture 2 [unity_Lightmap] 2D
				
				"ps_360
				backbbaaaaaaabhmaaaaabamaaaaaaaaaaaaaaceaaaaabciaaaaabfaaaaaaaaa
				aaaaaaaaaaaaabaaaaaaaabmaaaaaapeppppadaaaaaaaaafaaaaaabmaaaaaaaa
				aaaaaaonaaaaaaiaaaacaaaaaaabaaaaaaaaaaiiaaaaaaaaaaaaaajiaaacaaab
				aaabaaaaaaaaaakaaaaaaaaaaaaaaalaaaadaaabaaabaaaaaaaaaalmaaaaaaaa
				aaaaaammaaadaaaaaaabaaaaaaaaaalmaaaaaaaaaaaaaanoaaadaaacaaabaaaa
				aaaaaalmaaaaaaaafpedgpgmgphcaaklaaabaaadaaabaaaeaaabaaaaaaaaaaaa
				fpedhfhegpggggaaaaaaaaadaaabaaabaaabaaaaaaaaaaaafpengbgjgofegfhi
				aaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaafpfdgigbgegphhengbhafegf
				hihehfhcgfaahfgogjhehjfpemgjghgihegngbhaaahahdfpddfpdaaadccodaco
				dcdadddfddcodaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaaba
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeaaaaaaammbaaaadaaaaaaaaae
				aaaaaaaaaaaacigdaaahaaahaaaaaacbaaaapafaaaaadbfbaaaapcfcaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaebaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaafajgaac
				aaaabcaameaaaaaaaaaagaaicaaobcaaccaaaaaababiaaabbpbppgecaaaaeaaa
				emeiabaaaablblblkbaaaaaclibmacababmgkmedmbabacabmiaaaaaaaalbgmaa
				hjppacaabacicacbbpbppgiiaaaaeaaaliaibacbbpbppbppaaaaeaaaaabbabad
				aablgmblkbacppabmiahaaabaagmmaaaobabacaabecoaaacaagmpmlbobadacaa
				kibhacadaabfblebmbacabaakichacabaabfmaicmdacabaakiehacabaamamama
				mcadabaamiahaaaaaamamaaaobacabaamiapiaaaaaaaaaaaocaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				Vector 0 [_Color]
				Float 1 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_ShadowMapTexture] 2D
				SetTexture 3 [unity_Lightmap] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0001c0200007fffa000000000000848004000000
				[Offsets]
				2
				_Color 1 0
				00000020
				_Cutoff 1 0
				00000040
				[Microcode]
				256
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				1080014001041c9cc8000001c8000001be021706c8011c9dc8000001c8003fe1
				0e800240fe041c9dc8043001c8000001c2061804c8011c9dc8000001c8003fe1
				0e880240c9001c9d000c0000c800000106060100c80c1c9dc8000001c8000001
				0e840240c8041c9d000c1000c80000010e800840c9001c9dc9080001c8000001
				0e800940c9001c9dc9100001c80000010e810240f3041c9dc9000001c8000001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				ConstBuffer "$Globals" 208 
				Vector 112 [_Color] 4
				Float 192 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 1
				SetTexture 1 [_ShadowMapTexture] 2D 0
				SetTexture 2 [unity_Lightmap] 2D 2
				
				"ps_4_0
				eefiecedgpfalfliblpbjineielilcbdnjcgfedaabaaaaaaimadaaaaadaaaaaa
				cmaaaaaaleaaaaaaoiaaaaaaejfdeheoiaaaaaaaaeaaaaaaaiaaaaaagiaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaheaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapadaaaaheaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				adadaaaaheaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaapalaaaafdfgfpfa
				epfdejfeejepeoaafeeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaa
				aiaaaaaacaaaaaaaaaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfe
				gbhcghgfheaaklklfdeieefcjmacaaaaeaaaaaaakhaaaaaafjaaaaaeegiocaaa
				aaaaaaaaanaaaaaafkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaa
				fkaaaaadaagabaaaacaaaaaafibiaaaeaahabaaaaaaaaaaaffffaaaafibiaaae
				aahabaaaabaaaaaaffffaaaafibiaaaeaahabaaaacaaaaaaffffaaaagcbaaaad
				dcbabaaaabaaaaaagcbaaaaddcbabaaaacaaaaaagcbaaaadlcbabaaaadaaaaaa
				gfaaaaadpccabaaaaaaaaaaagiaaaaacadaaaaaaefaaaaajpcaabaaaaaaaaaaa
				egbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaabaaaaaadcaaaaambcaabaaa
				abaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaahaaaaaaakiacaiaebaaaaaa
				aaaaaaaaamaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaaegiocaaa
				aaaaaaaaahaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaa
				aaaaaaaaanaaaeadakaabaaaabaaaaaaaoaaaaahdcaabaaaabaaaaaaegbabaaa
				adaaaaaapgbpbaaaadaaaaaaefaaaaajpcaabaaaabaaaaaaegaabaaaabaaaaaa
				eghobaaaabaaaaaaaagabaaaaaaaaaaaaaaaaaahccaabaaaabaaaaaaakaabaaa
				abaaaaaaakaabaaaabaaaaaaefaaaaajpcaabaaaacaaaaaaegbabaaaacaaaaaa
				eghobaaaacaaaaaaaagabaaaacaaaaaadiaaaaahocaabaaaabaaaaaafgafbaaa
				abaaaaaaagajbaaaacaaaaaadiaaaaahicaabaaaacaaaaaadkaabaaaacaaaaaa
				abeaaaaaaaaaaaebdiaaaaahhcaabaaaacaaaaaaegacbaaaacaaaaaapgapbaaa
				acaaaaaaddaaaaahocaabaaaabaaaaaafgaobaaaabaaaaaaagajbaaaacaaaaaa
				diaaaaahhcaabaaaacaaaaaaagaabaaaabaaaaaaegacbaaaacaaaaaadeaaaaah
				hcaabaaaabaaaaaajgahbaaaabaaaaaaegacbaaaacaaaaaadiaaaaahhccabaaa
				aaaaaaaaegacbaaaaaaaaaaaegacbaaaabaaaaaadgaaaaaficcabaaaaaaaaaaa
				dkaabaaaaaaaaaaadoaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "SHADOWS_SCREEN" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_SCREEN" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_ShadowMapTexture] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"3.0-!!ARBfp1.0
				# 51 ALU, 5 TEX
				PARAM c[8] = { program.local[0..3],
					{ 2, 1, 8, 0 },
					{ -0.40824828, -0.70710677, 0.57735026, 128 },
					{ -0.40824831, 0.70710677, 0.57735026 },
				{ 0.81649655, 0, 0.57735026 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEMP R3;
				TEMP R4;
				TEX R1.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MAD R2.xy, R1.wyzw, c[4].x, -c[4].y;
				TEX R0, fragment.texcoord[1], texture[4], 2D;
				MUL R0.xyz, R0.w, R0;
				MUL R3.xyz, R0, c[4].z;
				MUL R0.xyz, R3.y, c[6];
				MAD R0.xyz, R3.x, c[7], R0;
				MAD R0.xyz, R3.z, c[5], R0;
				DP3 R0.w, R0, R0;
				RSQ R0.w, R0.w;
				MUL R0.xyz, R0.w, R0;
				DP3 R0.w, fragment.texcoord[2], fragment.texcoord[2];
				RSQ R0.w, R0.w;
				MUL R1.xy, R2, R2;
				MAD R0.xyz, R0.w, fragment.texcoord[2], R0;
				ADD_SAT R0.w, R1.x, R1.y;
				DP3 R1.x, R0, R0;
				RSQ R1.x, R1.x;
				ADD R0.w, -R0, c[4].y;
				RSQ R0.w, R0.w;
				RCP R2.z, R0.w;
				MUL R4.xyz, R1.x, R0;
				TEX R0, fragment.texcoord[1], texture[3], 2D;
				DP3_SAT R1.z, -R2, c[5];
				DP3_SAT R1.x, -R2, c[7];
				DP3_SAT R1.y, -R2, c[6];
				DP3 R1.w, R1, R3;
				MUL R1.xyz, R0.w, R0;
				MUL R1.xyz, R1, R1.w;
				DP3 R1.w, -R2, R4;
				TXP R3.x, fragment.texcoord[3], texture[2], 2D;
				MUL R0.xyz, R0, R3.x;
				MUL R1.xyz, R1, c[4].z;
				TEX R2, fragment.texcoord[0], texture[0], 2D;
				MUL R0.xyz, R0, c[4].x;
				MOV R0.w, c[5];
				MUL R3.xyz, R1, R3.x;
				MIN R0.xyz, R1, R0;
				MAX R0.xyz, R0, R3;
				MUL R2.xyz, R2, c[1];
				MUL R1.xyz, R1, c[0];
				MAX R1.w, R1, c[4];
				MUL R0.w, R0, c[2].x;
				POW R0.w, R1.w, R0.w;
				MUL R1.xyz, R1, R2.x;
				MUL R1.xyz, R1, R0.w;
				MUL R0.w, R2, c[1];
				MAD result.color.xyz, R0, R2, R1;
				SLT R0.x, R0.w, c[3];
				MOV result.color.w, R0;
				KIL -R0.x;
				END
				# 51 instructions, 5 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_SCREEN" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_ShadowMapTexture] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"ps_3_0
				; 50 ALU, 6 TEX
				dcl_2d s0
				dcl_2d s1
				dcl_2d s2
				dcl_2d s3
				dcl_2d s4
				def c4, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c5, -0.40824828, -0.70710677, 0.57735026, 8.00000000
				def c6, -0.40824831, 0.70710677, 0.57735026, 128.00000000
				def c7, 0.81649655, 0.00000000, 0.57735026, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1.xy
				dcl_texcoord2 v2.xyz
				dcl_texcoord3 v3
				texld r0, v1, s4
				mul_pp r0.xyz, r0.w, r0
				mul_pp r2.xyz, r0, c5.w
				mul r0.xyz, r2.y, c6
				mad r0.xyz, r2.x, c7, r0
				mad r1.xyz, r2.z, c5, r0
				texld r0.yw, v0.zwzw, s1
				mad_pp r3.xy, r0.wyzw, c4.z, c4.w
				mul_pp r3.zw, r3.xyxy, r3.xyxy
				dp3 r0.x, r1, r1
				rsq r0.x, r0.x
				mul r1.xyz, r0.x, r1
				add_pp_sat r0.w, r3.z, r3
				dp3_pp r0.x, v2, v2
				rsq_pp r0.x, r0.x
				mad_pp r0.xyz, r0.x, v2, r1
				dp3_pp r1.x, r0, r0
				rsq_pp r1.x, r1.x
				add_pp r0.w, -r0, c4.y
				rsq_pp r0.w, r0.w
				rcp_pp r3.z, r0.w
				mul_pp r0.xyz, r1.x, r0
				dp3_pp r0.x, -r3, r0
				mov_pp r0.w, c2.x
				mul_pp r1.y, c6.w, r0.w
				max_pp r1.x, r0, c4
				pow r0, r1.x, r1.y
				texld r1, v1, s3
				dp3_pp_sat r0.w, -r3, c5
				dp3_pp_sat r0.z, -r3, c6
				dp3_pp_sat r0.y, -r3, c7
				dp3_pp r0.y, r0.yzww, r2
				mul_pp r3.xyz, r1.w, r1
				mul_pp r3.xyz, r3, r0.y
				texldp r2.x, v3, s2
				mul_pp r1.xyz, r1, r2.x
				mul_pp r3.xyz, r3, c5.w
				mov r2.w, r0.x
				texld r0, v0, s0
				mul_pp r1.w, r0, c1
				mul_pp r1.xyz, r1, c4.z
				add_pp r0.w, r1, -c3.x
				mul_pp r2.xyz, r3, r2.x
				min_pp r1.xyz, r3, r1
				max_pp r1.xyz, r1, r2
				mul_pp r2.xyz, r3, c0
				mul_pp r3.xyz, r0, c1
				mul_pp r0.xyz, r2, r3.x
				mul r2.xyz, r0, r2.w
				cmp r0.w, r0, c4.x, c4.y
				mov_pp r0, -r0.w
				mad_pp oC0.xyz, r1, r3, r2
				texkill r0.xyzw
				mov_pp oC0.w, r1
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_SCREEN" }
				
				Vector 1 [_Color]
				Float 3 [_Cutoff]
				Float 2 [_Shininess]
				Vector 0 [_SpecColor]
				SetTexture 0 [_ShadowMapTexture] 2D
				SetTexture 1 [_MainTex] 2D
				SetTexture 2 [_BumpMap] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				
				"ps_360
				backbbaaaaaaacaeaaaaaceeaaaaaaaaaaaaaaceaaaaabkmaaaaabneaaaaaaaa
				aaaaaaaaaaaaabieaaaaaabmaaaaabhfppppadaaaaaaaaajaaaaaabmaaaaaaaa
				aaaaabgoaaaaaanaaaadaaacaaabaaaaaaaaaanmaaaaaaaaaaaaaaomaaacaaab
				aaabaaaaaaaaaapeaaaaaaaaaaaaabaeaaacaaadaaabaaaaaaaaabamaaaaaaaa
				aaaaabbmaaadaaabaaabaaaaaaaaaanmaaaaaaaaaaaaabcfaaadaaaaaaabaaaa
				aaaaaanmaaaaaaaaaaaaabdhaaacaaacaaabaaaaaaaaabamaaaaaaaaaaaaabec
				aaacaaaaaaabaaaaaaaaaapeaaaaaaaaaaaaabenaaadaaadaaabaaaaaaaaaanm
				aaaaaaaaaaaaabfmaaadaaaeaaabaaaaaaaaaanmaaaaaaaafpechfgnhaengbha
				aaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaafpedgpgmgphcaaklaaabaaad
				aaabaaaeaaabaaaaaaaaaaaafpedhfhegpggggaaaaaaaaadaaabaaabaaabaaaa
				aaaaaaaafpengbgjgofegfhiaafpfdgigbgegphhengbhafegfhihehfhcgfaafp
				fdgigjgogjgogfhdhdaafpfdhagfgdedgpgmgphcaahfgogjhehjfpemgjghgihe
				gngbhaaahfgogjhehjfpemgjghgihegngbhaejgogeaahahdfpddfpdaaadccoda
				codcdadddfddcodaaaklklklaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabe
				abpmaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeaaaaaacaebaaaaiaa
				aaaaaaaeaaaaaaaaaaaadeieaaapaaapaaaaaacbaaaapafaaaaadbfbaaaahcfc
				aaaapdfdaaaaaaaalpiaaaaaebaaaaaaedaaaaaadpbdmndklonbafomdpdfaepd
				dpfbafoldpbdmndklonbafollpdfaepddpfbafoldpiaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaafajgaaecaakbcaabcaaaaafaaaaaaaagaammeaabcaaaaaaaaaagabc
				gabibcaabcaaaaaaaaaagabogacebcaaccaaaaaababieaabbpbppgbbaaaaeaaa
				emieababaablblblkbaeabadlmidabadabbllaecmbabadadmiaaaaaaaagmblaa
				hjpmabaabaaidagbbpbpppmhaaaaeaaadicidaabbpbppghpaaaaeaaabadigacb
				bpbppgiiaaaaeaaabaeiaacbbpbppeedaaaaeaaabebbaaabaalologmpaacacaa
				kiciababaablmgmaibagpmpmfibhabafaablmagmobabagibaabhabahaagmmalb
				obabacadaacnabaaaalbdcblobabaaadaaipabaiaaeogdmgkbaapnadmiagaaac
				aabblbaakaabpmaakicfaiaiaamebjmamaaiaipnmjacaaaaaamfmfgmnbacacpm
				libhabagaagmmaebmbabagppmiahaaaiaablgfmaklaapoaikabcacaaaalologm
				paaiaiibmjabaaabaegngpgmjbacpopmfjccaaabaemamalblaacpniamiahaaah
				aamalbmaolaiaaahmiacaaaaaaloloaapaahahaafjciaaabaemamalblaacpoia
				miahaaahaamalbaaobahaaaabeacaaaaaclomagmnaahacacamicafaaaalbgmbl
				icaapmpmeacbaaaaaaghlplbpaaaabiabecpaaacaaaakmmgobafaaaekibladab
				aamamaebibacaaabkichadafaamalbiembacadabkiehadaaaamamamfmdacagab
				mialaaabaabagmaaobabadaamiahaaaaaamamaaaocafaaaadiihaaaaaamamabl
				obadaaacmialaaabaabablmaolabaaaamiapiaaaaananaaaocababaaaaaaaaaa
				aaaaaaaaaaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_SCREEN" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_ShadowMapTexture] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0003c020000ffff2000000000000848004000000
				[Offsets]
				4
				_SpecColor 1 0
				00000320
				_Color 1 0
				00000020
				_Shininess 1 0
				00000070
				_Cutoff 1 0
				00000040
				[Microcode]
				960
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				1080014000021c9cc8000001c800000100000000000000000000000000000000
				940417025c011c9dc8000001c8003fe106880440ce081c9d00020000aa020000
				000040000000bf80000000000000000010800240c9001c9d54020001c8000001
				00000000000000000000430000000000be021708c8011c9dc8000001c8003fe1
				0e840240fe041c9dc8043001c80000010e060200ab081c9cc8020001c8000001
				05ecbed104f33f35cd3a3f13000000000280b840c9101c9dc9100001c8000001
				02800340c9001c9f00020000c800000100003f80000000000000000000000000
				0e06040001081c9cc8020001c80c000105eb3f5100000000cd3a3f1300000000
				0e06040055081c9dc8020001c80c000105ebbed104f3bf35cd3a3f1300000000
				08020500c80c1c9dc80c0001c800000108883b4001003c9cc9000001c8000001
				08808540c9101c9fc8020001c800000105ebbed104f3bf35cd3a3f1300000000
				04808540c9101c9fc8020001c800000105ecbed104f33f35cd3a3f1300000000
				0280b84005101c9e08020000c8000001cd3a3f1305eb3f510000000000000000
				06000100c8001c9dc8000001c800000110880540c9001c9dc9080001c8000001
				0e8a3b00c80c1c9d54040001c8000001be021706c8011c9dc8000001c8003fe1
				ce803940c8011c9dc8000029c800bfe10e800340c9141c9dc9000001c8000001
				0e803940c9001c9dc8000029c8000001108a0540c9101c9fc9000001c8000001
				10880240c8041c9dc9100001c8000001e2061804c8011c9dc8000001c8003fe1
				0e8a0240c8041c9d000c1000c80000010e880240ff101c9dc8043001c8000001
				10020900c9141c9d00020000c800000100000000000000000000000000000000
				1e7e7d00c8001c9dc8000001c80000010e800840c9101c9dc9140001c8000001
				0e840240c9101c9d000c0000c80000010e880240c9101c9dc8020001c8000001
				0000000000000000000000000000000008041d00fe041c9dc8000001c8000001
				0e800940c9001c9dc9080001c80000010e800240f3041c9dc9000001c8000001
				1000020054081c9dc9000001c80000011e7e7d00c8001c9dc8000001c8000001
				0e840240ab041c9cc9100001c800000110801c00fe001c9dc8000001c8000001
				0e800440c9081c9dff000001c90000011081014001041c9cc8000001c8000001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_SCREEN" }
				
				ConstBuffer "$Globals" 208 
				Vector 32 [_SpecColor] 4
				Vector 112 [_Color] 4
				Float 128 [_Shininess]
				Float 192 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 1
				SetTexture 1 [_BumpMap] 2D 2
				SetTexture 2 [_ShadowMapTexture] 2D 0
				SetTexture 3 [unity_Lightmap] 2D 3
				SetTexture 4 [unity_LightmapInd] 2D 4
				
				"ps_4_0
				eefieceddjlnnomcddpgicgddcicillpnidpdifaabaaaaaaeaaiaaaaadaaaaaa
				cmaaaaaammaaaaaaaaabaaaaejfdeheojiaaaaaaafaaaaaaaiaaaaaaiaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaimaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaaimaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				adadaaaaimaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaaimaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaapalaaaafdfgfpfaepfdejfeejepeoaa
				feeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaa
				aaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklkl
				fdeieefcdiahaaaaeaaaaaaamoabaaaafjaaaaaeegiocaaaaaaaaaaaanaaaaaa
				fkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaafkaaaaadaagabaaa
				acaaaaaafkaaaaadaagabaaaadaaaaaafkaaaaadaagabaaaaeaaaaaafibiaaae
				aahabaaaaaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaaffffaaaafibiaaae
				aahabaaaacaaaaaaffffaaaafibiaaaeaahabaaaadaaaaaaffffaaaafibiaaae
				aahabaaaaeaaaaaaffffaaaagcbaaaadpcbabaaaabaaaaaagcbaaaaddcbabaaa
				acaaaaaagcbaaaadhcbabaaaadaaaaaagcbaaaadlcbabaaaaeaaaaaagfaaaaad
				pccabaaaaaaaaaaagiaaaaacafaaaaaaefaaaaajpcaabaaaaaaaaaaaegbabaaa
				abaaaaaaeghobaaaaaaaaaaaaagabaaaabaaaaaadcaaaaambcaabaaaabaaaaaa
				dkaabaaaaaaaaaaadkiacaaaaaaaaaaaahaaaaaaakiacaiaebaaaaaaaaaaaaaa
				amaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaaegiocaaaaaaaaaaa
				ahaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaaaaaaaaaa
				anaaaeadakaabaaaabaaaaaabaaaaaahbcaabaaaabaaaaaaegbcbaaaadaaaaaa
				egbcbaaaadaaaaaaeeaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaah
				hcaabaaaabaaaaaaagaabaaaabaaaaaaegbcbaaaadaaaaaaefaaaaajpcaabaaa
				acaaaaaaegbabaaaacaaaaaaeghobaaaaeaaaaaaaagabaaaaeaaaaaadiaaaaah
				icaabaaaabaaaaaadkaabaaaacaaaaaaabeaaaaaaaaaaaebdiaaaaahhcaabaaa
				acaaaaaaegacbaaaacaaaaaapgapbaaaabaaaaaadiaaaaakhcaabaaaadaaaaaa
				fgafbaaaacaaaaaaaceaaaaaomafnblopdaedfdpdkmnbddpaaaaaaaadcaaaaam
				hcaabaaaadaaaaaaagaabaaaacaaaaaaaceaaaaaolaffbdpaaaaaaaadkmnbddp
				aaaaaaaaegacbaaaadaaaaaadcaaaaamhcaabaaaadaaaaaakgakbaaaacaaaaaa
				aceaaaaaolafnblopdaedflpdkmnbddpaaaaaaaaegacbaaaadaaaaaabaaaaaah
				icaabaaaabaaaaaaegacbaaaadaaaaaaegacbaaaadaaaaaaeeaaaaaficaabaaa
				abaaaaaadkaabaaaabaaaaaadcaaaaajhcaabaaaabaaaaaaegacbaaaadaaaaaa
				pgapbaaaabaaaaaaegacbaaaabaaaaaabaaaaaahicaabaaaabaaaaaaegacbaaa
				abaaaaaaegacbaaaabaaaaaaeeaaaaaficaabaaaabaaaaaadkaabaaaabaaaaaa
				diaaaaahhcaabaaaabaaaaaapgapbaaaabaaaaaaegacbaaaabaaaaaaefaaaaaj
				pcaabaaaadaaaaaaogbkbaaaabaaaaaaeghobaaaabaaaaaaaagabaaaacaaaaaa
				dcaaaaapdcaabaaaadaaaaaahgapbaaaadaaaaaaaceaaaaaaaaaaaeaaaaaaaea
				aaaaaaaaaaaaaaaaaceaaaaaaaaaialpaaaaialpaaaaaaaaaaaaaaaaapaaaaah
				icaabaaaabaaaaaaegaabaaaadaaaaaaegaabaaaadaaaaaaddaaaaahicaabaaa
				abaaaaaadkaabaaaabaaaaaaabeaaaaaaaaaiadpaaaaaaaiicaabaaaabaaaaaa
				dkaabaiaebaaaaaaabaaaaaaabeaaaaaaaaaiadpelaaaaafecaabaaaadaaaaaa
				dkaabaaaabaaaaaabaaaaaaibcaabaaaabaaaaaaegacbaiaebaaaaaaadaaaaaa
				egacbaaaabaaaaaadeaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaa
				aaaaaaaacpaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaaiccaabaaa
				abaaaaaaakiacaaaaaaaaaaaaiaaaaaaabeaaaaaaaaaaaeddiaaaaahbcaabaaa
				abaaaaaaakaabaaaabaaaaaabkaabaaaabaaaaaabjaaaaafbcaabaaaabaaaaaa
				akaabaaaabaaaaaaapcaaaalbcaabaaaaeaaaaaaaceaaaaaolaffbdpdkmnbddp
				aaaaaaaaaaaaaaaaigaabaiaebaaaaaaadaaaaaabacaaaalccaabaaaaeaaaaaa
				aceaaaaaomafnblopdaedfdpdkmnbddpaaaaaaaaegacbaiaebaaaaaaadaaaaaa
				bacaaaalecaabaaaaeaaaaaaaceaaaaaolafnblopdaedflpdkmnbddpaaaaaaaa
				egacbaiaebaaaaaaadaaaaaabaaaaaahccaabaaaabaaaaaaegacbaaaaeaaaaaa
				egacbaaaacaaaaaaefaaaaajpcaabaaaacaaaaaaegbabaaaacaaaaaaeghobaaa
				adaaaaaaaagabaaaadaaaaaadiaaaaahecaabaaaabaaaaaadkaabaaaacaaaaaa
				abeaaaaaaaaaaaebdiaaaaahhcaabaaaadaaaaaaegacbaaaacaaaaaakgakbaaa
				abaaaaaadiaaaaahocaabaaaabaaaaaafgafbaaaabaaaaaaagajbaaaadaaaaaa
				aoaaaaahdcaabaaaadaaaaaaegbabaaaaeaaaaaapgbpbaaaaeaaaaaaefaaaaaj
				pcaabaaaadaaaaaaegaabaaaadaaaaaaeghobaaaacaaaaaaaagabaaaaaaaaaaa
				aaaaaaahicaabaaaacaaaaaaakaabaaaadaaaaaaakaabaaaadaaaaaadiaaaaah
				hcaabaaaadaaaaaajgahbaaaabaaaaaaagaabaaaadaaaaaadiaaaaahhcaabaaa
				acaaaaaaegacbaaaacaaaaaapgapbaaaacaaaaaaddaaaaahhcaabaaaacaaaaaa
				jgahbaaaabaaaaaaegacbaaaacaaaaaadiaaaaaiocaabaaaabaaaaaafgaobaaa
				abaaaaaaagijcaaaaaaaaaaaacaaaaaadiaaaaahocaabaaaabaaaaaaagaabaaa
				aaaaaaaafgaobaaaabaaaaaadeaaaaahhcaabaaaacaaaaaaegacbaaaadaaaaaa
				egacbaaaacaaaaaadiaaaaahhcaabaaaaaaaaaaaegacbaaaaaaaaaaaegacbaaa
				acaaaaaadgaaaaaficcabaaaaaaaaaaadkaabaaaaaaaaaaadcaaaaajhccabaaa
				aaaaaaaajgahbaaaabaaaaaaagaabaaaabaaaaaaegacbaaaaaaaaaaadoaaaaab
				"
			}
			
			SubProgram "gles " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_SCREEN" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_SCREEN" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "DIRECTIONAL" "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "SHADOWS_SCREEN" }
				
				"!!GLES3"
			}
		}
	}
	
	Pass {
		Name "FORWARD"
		Tags { "LightMode" = "ForwardAdd" }
		ZWrite Off Blend One One Fog { Color (0,0,0,0) }
		
		ColorMask RGB
		Program "fp" {
			
			SubProgram "opengl " {
				Keywords { "POINT" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTexture0] 2D
				"3.0-!!ARBfp1.0
				# 39 ALU, 3 TEX
				PARAM c[6] = { program.local[0..4],
				{ 2, 1, 0, 128 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				DP3 R0.x, fragment.texcoord[1], fragment.texcoord[1];
				RSQ R0.x, R0.x;
				DP3 R1.w, fragment.texcoord[2], fragment.texcoord[2];
				MUL R1.xyz, R0.x, fragment.texcoord[1];
				TEX R0.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MAD R0.xy, R0.wyzw, c[5].x, -c[5].y;
				MUL R0.zw, R0.xyxy, R0.xyxy;
				ADD_SAT R0.z, R0, R0.w;
				RSQ R1.w, R1.w;
				MAD R2.xyz, R1.w, fragment.texcoord[2], R1;
				DP3 R0.w, R2, R2;
				RSQ R0.w, R0.w;
				ADD R0.z, -R0, c[5].y;
				RSQ R0.z, R0.z;
				RCP R0.z, R0.z;
				DP3 R1.x, -R0, R1;
				MUL R2.xyz, R0.w, R2;
				DP3 R0.w, -R0, R2;
				MAX R1.z, R0.w, c[5];
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				MUL R0.w, R0, c[2];
				MOV R1.y, c[5].w;
				MUL R1.y, R1, c[3].x;
				DP3 R1.w, fragment.texcoord[3], fragment.texcoord[3];
				MUL R0.xyz, R0, c[2];
				POW R1.y, R1.z, R1.y;
				MUL R2.x, R1.y, R0;
				MUL R0.xyz, R0, c[0];
				MAX R1.x, R1, c[5].z;
				MUL R1.xyz, R0, R1.x;
				MOV R0.xyz, c[1];
				MUL R0.xyz, R0, c[0];
				MAD R0.xyz, R0, R2.x, R1;
				TEX R1.w, R1.w, texture[2], 2D;
				MUL R1.x, R1.w, c[5];
				MUL result.color.xyz, R0, R1.x;
				SLT R0.x, R0.w, c[4];
				MOV result.color.w, R0;
				KIL -R0.x;
				END
				# 39 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "POINT" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTexture0] 2D
				"ps_3_0
				; 40 ALU, 4 TEX
				dcl_2d s0
				dcl_2d s1
				dcl_2d s2
				def c5, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c6, 128.00000000, 0, 0, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1.xyz
				dcl_texcoord2 v2.xyz
				dcl_texcoord3 v3.xyz
				texld r0.yw, v0.zwzw, s1
				dp3_pp r0.z, v1, v1
				rsq_pp r1.x, r0.z
				mad_pp r0.xy, r0.wyzw, c5.z, c5.w
				mul_pp r0.zw, r0.xyxy, r0.xyxy
				add_pp_sat r0.z, r0, r0.w
				dp3_pp r0.w, v2, v2
				add_pp r0.z, -r0, c5.y
				rsq_pp r0.z, r0.z
				mul_pp r1.xyz, r1.x, v1
				rsq_pp r0.w, r0.w
				mad_pp r2.xyz, r0.w, v2, r1
				rcp_pp r0.z, r0.z
				dp3_pp r0.w, r2, r2
				rsq_pp r0.w, r0.w
				mul_pp r2.xyz, r0.w, r2
				dp3_pp r1.x, -r0, r1
				dp3_pp r0.x, -r0, r2
				mov_pp r0.w, c3.x
				mul_pp r0.y, c6.x, r0.w
				max_pp r0.x, r0, c5
				pow r2, r0.x, r0.y
				texld r0, v0, s0
				mov r1.y, r2.x
				mul_pp r0.xyz, r0, c2
				mul r1.w, r1.y, r0.x
				max_pp r2.x, r1, c5
				mul_pp r1.xyz, r0, c0
				mov_pp r0.xyz, c0
				mul_pp r0.xyz, c1, r0
				mul_pp r1.xyz, r1, r2.x
				mad r1.xyz, r0, r1.w, r1
				mul_pp r1.w, r0, c2
				dp3 r0.x, v3, v3
				texld r0.x, r0.x, s2
				mul_pp r2.x, r0, c5.z
				add_pp r0.y, r1.w, -c4.x
				cmp r0.y, r0, c5.x, c5
				mov_pp r0, -r0.y
				mul oC0.xyz, r1, r2.x
				texkill r0.xyzw
				mov_pp oC0.w, r1
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "POINT" }
				
				Vector 2 [_Color]
				Float 4 [_Cutoff]
				Vector 0 [_LightColor0]
				Float 3 [_Shininess]
				Vector 1 [_SpecColor]
				SetTexture 0 [_LightTexture0] 2D
				SetTexture 1 [_MainTex] 2D
				SetTexture 2 [_BumpMap] 2D
				
				"ps_360
				backbbaaaaaaabniaaaaabmmaaaaaaaaaaaaaaceaaaaabiaaaaaabkiaaaaaaaa
				aaaaaaaaaaaaabfiaaaaaabmaaaaabekppppadaaaaaaaaaiaaaaaabmaaaaaaaa
				aaaaabedaaaaaalmaaadaaacaaabaaaaaaaaaamiaaaaaaaaaaaaaaniaaacaaac
				aaabaaaaaaaaaaoaaaaaaaaaaaaaaapaaaacaaaeaaabaaaaaaaaaapiaaaaaaaa
				aaaaabaiaaacaaaaaaabaaaaaaaaaaoaaaaaaaaaaaaaabbfaaadaaaaaaabaaaa
				aaaaaamiaaaaaaaaaaaaabceaaadaaabaaabaaaaaaaaaamiaaaaaaaaaaaaabcn
				aaacaaadaaabaaaaaaaaaapiaaaaaaaaaaaaabdiaaacaaabaaabaaaaaaaaaaoa
				aaaaaaaafpechfgnhaengbhaaaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaa
				fpedgpgmgphcaaklaaabaaadaaabaaaeaaabaaaaaaaaaaaafpedhfhegpggggaa
				aaaaaaadaaabaaabaaabaaaaaaaaaaaafpemgjghgiheedgpgmgphcdaaafpemgj
				ghgihefegfhihehfhcgfdaaafpengbgjgofegfhiaafpfdgigjgogjgogfhdhdaa
				fpfdhagfgdedgpgmgphcaahahdfpddfpdaaadccodacodcdadddfddcodaaaklkl
				aaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaeaaaaaabimbaaaaeaaaaaaaaaeaaaaaaaaaaaadeie
				aaapaaapaaaaaacbaaaapafaaaaahbfbaaaahcfcaaaahdfdaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaedaaaaaadpiaaaaalpiaaaaaafajgaadaaaabcaa
				meaaaaaaaaaagaajgaapbcaabcaaaaaaaaaagabffablbcaaccaaaaaababieaab
				bpbppgiiaaaaeaaamiacaaaaaablblaakbaeacaaliiiacababloloebnaadadae
				miaaaaaaaagmblaahjppacaapmaidacbbpbppppiaaaaeaaadicidaabbpbppomp
				aaaaeaaamiaiaaabaaloloaapaacacaamiabaaaaaaloloaapaababaamiahaaae
				aamamaaakbaeacaafibhaaadaalelegmoaadadiamianaaaaaagmpaaaobaaabaa
				fiedababaamfblblkaadppibmiahaaacaamgmabeolabacaamiaiaaabaaloloaa
				paacacaamjaeaaabaalalagmnbababppfiieababaemgmgblkaabppibkaehabac
				aamablmgobacabibmiabaaaaacmploaapaaaabaabeaeaaaaaclologmnaacabad
				amifabaaaamegmlbicaappppeaihaaabaamamamgkbaeaaiamiapaaacaaaacmaa
				obabaaaadibhaaabaamamablcbaaabacmiaiaaaeaagmgmaaobaeaaaamiaoaaab
				aaebflaaobabaeaamiabaaabaablgmaaobabaaaamianaaaaaapapaaaoaacabaa
				mianaaaaaagmaeaaobadaaaamiapiaaaaajejeaaocaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "POINT" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTexture0] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0003c020000ffff0000000000000848004000000
				[Offsets]
				5
				_LightColor0 2 0
				0000022000000160
				_SpecColor 1 0
				000001e0
				_Color 1 0
				00000020
				_Shininess 1 0
				00000070
				_Cutoff 1 0
				00000040
				[Microcode]
				704
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				1086014000021c9cc8000001c800000100000000000000000000000000000000
				ee020100c8011c9dc8000001c8003fe102000500c8041c9dc8040001c8000001
				940417025c011c9dc8000001c8003fe1068a0440ce081c9d00020000aa020000
				000040000000bf8000000000000000000200170400001c9cc8000001c8000001
				ae843940c8011c9dc8000029c800bfe10880b840c9141c9dc9140001c8000001
				ce863940c8011c9dc8000029c800bfe11088034055001c9f00020000c8000001
				00003f800000000000000000000000000e860340c9081c9dc90c0001c8000001
				0e863940c90c1c9dc8000029c80000010e880140c8021c9dc8000001c8000001
				00000000000000000000000000000000088a3b40ff103c9dff100001c8000001
				10840540c9141c9fc90c0001c800000102860240ff0c1c9d00020000c8000001
				0000430000000000000000000000000010020900c9081c9daa020000c8000001
				000000000000000000000000000000000e880240c9101c9dc8020001c8000001
				0000000000000000000000000000000010021d00fe041c9dc8000001c8000001
				08800540c9141c9fc9080001c80000010e8c0240f3041c9dc8020001c8000001
				0000000000000000000000000000000010000200c8041c9d010c0000c8000001
				028e090055001c9d00020000c800000100000000000000000000000000000000
				04001c00fe001c9dc8000001c800000110000200ab041c9caa000000c8000001
				0e840240c9181c9d011c0000c80000010e020400c9101c9dfe001001c9080001
				1080014001041c9cc8000001c80000010e810200c8041c9d00000000c8000001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "POINT" }
				
				ConstBuffer "$Globals" 192 
				Vector 16 [_LightColor0] 4
				Vector 32 [_SpecColor] 4
				Vector 112 [_Color] 4
				Float 128 [_Shininess]
				Float 176 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 1
				SetTexture 1 [_BumpMap] 2D 2
				SetTexture 2 [_LightTexture0] 2D 0
				
				"ps_4_0
				eefiecedhcgeaagaelpappdakccnholijmemmdhdabaaaaaaaiagaaaaadaaaaaa
				cmaaaaaammaaaaaaaaabaaaaejfdeheojiaaaaaaafaaaaaaaiaaaaaaiaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaimaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaaimaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				ahahaaaaimaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaaimaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaahahaaaafdfgfpfaepfdejfeejepeoaa
				feeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaa
				aaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklkl
				fdeieefcaaafaaaaeaaaaaaaeaabaaaafjaaaaaeegiocaaaaaaaaaaaamaaaaaa
				fkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaafkaaaaadaagabaaa
				acaaaaaafibiaaaeaahabaaaaaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaa
				ffffaaaafibiaaaeaahabaaaacaaaaaaffffaaaagcbaaaadpcbabaaaabaaaaaa
				gcbaaaadhcbabaaaacaaaaaagcbaaaadhcbabaaaadaaaaaagcbaaaadhcbabaaa
				aeaaaaaagfaaaaadpccabaaaaaaaaaaagiaaaaacaeaaaaaaefaaaaajpcaabaaa
				aaaaaaaaegbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaabaaaaaadcaaaaam
				bcaabaaaabaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaahaaaaaaakiacaia
				ebaaaaaaaaaaaaaaalaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaa
				egiocaaaaaaaaaaaahaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaa
				abeaaaaaaaaaaaaaanaaaeadakaabaaaabaaaaaabaaaaaahbcaabaaaabaaaaaa
				egbcbaaaadaaaaaaegbcbaaaadaaaaaaeeaaaaafbcaabaaaabaaaaaaakaabaaa
				abaaaaaabaaaaaahccaabaaaabaaaaaaegbcbaaaacaaaaaaegbcbaaaacaaaaaa
				eeaaaaafccaabaaaabaaaaaabkaabaaaabaaaaaadiaaaaahocaabaaaabaaaaaa
				fgafbaaaabaaaaaaagbjbaaaacaaaaaadcaaaaajhcaabaaaacaaaaaaegbcbaaa
				adaaaaaaagaabaaaabaaaaaajgahbaaaabaaaaaabaaaaaahbcaabaaaabaaaaaa
				egacbaaaacaaaaaaegacbaaaacaaaaaaeeaaaaafbcaabaaaabaaaaaaakaabaaa
				abaaaaaadiaaaaahhcaabaaaacaaaaaaagaabaaaabaaaaaaegacbaaaacaaaaaa
				efaaaaajpcaabaaaadaaaaaaogbkbaaaabaaaaaaeghobaaaabaaaaaaaagabaaa
				acaaaaaadcaaaaapdcaabaaaadaaaaaahgapbaaaadaaaaaaaceaaaaaaaaaaaea
				aaaaaaeaaaaaaaaaaaaaaaaaaceaaaaaaaaaialpaaaaialpaaaaaaaaaaaaaaaa
				apaaaaahbcaabaaaabaaaaaaegaabaaaadaaaaaaegaabaaaadaaaaaaddaaaaah
				bcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaaaaaaiadpaaaaaaaibcaabaaa
				abaaaaaaakaabaiaebaaaaaaabaaaaaaabeaaaaaaaaaiadpelaaaaafecaabaaa
				adaaaaaaakaabaaaabaaaaaabaaaaaaibcaabaaaabaaaaaaegacbaiaebaaaaaa
				adaaaaaaegacbaaaacaaaaaabaaaaaaiccaabaaaabaaaaaaegacbaiaebaaaaaa
				adaaaaaajgahbaaaabaaaaaadeaaaaakdcaabaaaabaaaaaaegaabaaaabaaaaaa
				aceaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaacpaaaaafbcaabaaaabaaaaaa
				akaabaaaabaaaaaadiaaaaaiecaabaaaabaaaaaaakiacaaaaaaaaaaaaiaaaaaa
				abeaaaaaaaaaaaeddiaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaackaabaaa
				abaaaaaabjaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaahbcaabaaa
				abaaaaaaakaabaaaaaaaaaaaakaabaaaabaaaaaadiaaaaajhcaabaaaacaaaaaa
				egiccaaaaaaaaaaaabaaaaaaegiccaaaaaaaaaaaacaaaaaadiaaaaahncaabaaa
				abaaaaaaagaabaaaabaaaaaaagajbaaaacaaaaaadiaaaaaihcaabaaaaaaaaaaa
				egacbaaaaaaaaaaaegiccaaaaaaaaaaaabaaaaaadgaaaaaficcabaaaaaaaaaaa
				dkaabaaaaaaaaaaadcaaaaajhcaabaaaaaaaaaaaegacbaaaaaaaaaaafgafbaaa
				abaaaaaaigadbaaaabaaaaaabaaaaaahicaabaaaaaaaaaaaegbcbaaaaeaaaaaa
				egbcbaaaaeaaaaaaefaaaaajpcaabaaaabaaaaaapgapbaaaaaaaaaaaeghobaaa
				acaaaaaaaagabaaaaaaaaaaaaaaaaaahicaabaaaaaaaaaaaakaabaaaabaaaaaa
				akaabaaaabaaaaaadiaaaaahhccabaaaaaaaaaaapgapbaaaaaaaaaaaegacbaaa
				aaaaaaaadoaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { "POINT" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "POINT" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "POINT" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "DIRECTIONAL" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				"3.0-!!ARBfp1.0
				# 34 ALU, 2 TEX
				PARAM c[6] = { program.local[0..4],
				{ 2, 1, 0, 128 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEX R1.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MAD R1.xy, R1.wyzw, c[5].x, -c[5].y;
				DP3 R0.w, fragment.texcoord[2], fragment.texcoord[2];
				MOV R2.x, c[5].w;
				MUL R1.zw, R1.xyxy, R1.xyxy;
				RSQ R0.w, R0.w;
				MOV R0.xyz, fragment.texcoord[1];
				MAD R0.xyz, R0.w, fragment.texcoord[2], R0;
				ADD_SAT R0.w, R1.z, R1;
				DP3 R1.z, R0, R0;
				RSQ R1.z, R1.z;
				ADD R0.w, -R0, c[5].y;
				MUL R0.xyz, R1.z, R0;
				RSQ R0.w, R0.w;
				RCP R1.z, R0.w;
				DP3 R0.x, -R1, R0;
				MAX R1.w, R0.x, c[5].z;
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				MUL R2.x, R2, c[3];
				POW R1.w, R1.w, R2.x;
				MUL R0.xyz, R0, c[2];
				DP3 R2.x, -R1, fragment.texcoord[1];
				MUL R1.w, R1, R0.x;
				MUL R1.xyz, R0, c[0];
				MAX R2.x, R2, c[5].z;
				MOV R0.xyz, c[1];
				MUL R0.xyz, R0, c[0];
				MUL R1.xyz, R1, R2.x;
				MAD R1.xyz, R0, R1.w, R1;
				MUL R0.x, R0.w, c[2].w;
				SLT R0.y, R0.x, c[4].x;
				MUL result.color.xyz, R1, c[5].x;
				MOV result.color.w, R0.x;
				KIL -R0.y;
				END
				# 34 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "DIRECTIONAL" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				"ps_3_0
				; 35 ALU, 3 TEX
				dcl_2d s0
				dcl_2d s1
				def c5, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c6, 128.00000000, 0, 0, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1.xyz
				dcl_texcoord2 v2.xyz
				texld r1.yw, v0.zwzw, s1
				mad_pp r1.xy, r1.wyzw, c5.z, c5.w
				dp3_pp r0.w, v2, v2
				mul_pp r1.zw, r1.xyxy, r1.xyxy
				rsq_pp r0.w, r0.w
				mov_pp r0.xyz, v1
				mad_pp r0.xyz, r0.w, v2, r0
				add_pp_sat r0.w, r1.z, r1
				dp3_pp r1.z, r0, r0
				rsq_pp r1.z, r1.z
				add_pp r0.w, -r0, c5.y
				mul_pp r0.xyz, r1.z, r0
				rsq_pp r0.w, r0.w
				rcp_pp r1.z, r0.w
				dp3_pp r0.x, -r1, r0
				mov_pp r0.w, c3.x
				mul_pp r2.x, c6, r0.w
				max_pp r1.w, r0.x, c5.x
				pow r0, r1.w, r2.x
				texld r2, v0, s0
				mul_pp r1.w, r2, c2
				mul_pp r2.xyz, r2, c2
				mul r0.w, r0.x, r2.x
				dp3_pp r0.x, -r1, v1
				max_pp r1.x, r0, c5
				mul_pp r0.xyz, r2, c0
				mul_pp r1.xyz, r0, r1.x
				add_pp r2.x, r1.w, -c4
				mov_pp r0.xyz, c0
				mul_pp r0.xyz, c1, r0
				mad r1.xyz, r0, r0.w, r1
				cmp r2.x, r2, c5, c5.y
				mov_pp r0, -r2.x
				mul oC0.xyz, r1, c5.z
				texkill r0.xyzw
				mov_pp oC0.w, r1
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "DIRECTIONAL" }
				
				Vector 2 [_Color]
				Float 4 [_Cutoff]
				Vector 0 [_LightColor0]
				Float 3 [_Shininess]
				Vector 1 [_SpecColor]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				
				"ps_360
				backbbaaaaaaablaaaaaabjaaaaaaaaaaaaaaaceaaaaabfmaaaaabieaaaaaaaa
				aaaaaaaaaaaaabdeaaaaaabmaaaaabchppppadaaaaaaaaahaaaaaabmaaaaaaaa
				aaaaabcaaaaaaakiaaadaaabaaabaaaaaaaaaaleaaaaaaaaaaaaaameaaacaaac
				aaabaaaaaaaaaammaaaaaaaaaaaaaanmaaacaaaeaaabaaaaaaaaaaoeaaaaaaaa
				aaaaaapeaaacaaaaaaabaaaaaaaaaammaaaaaaaaaaaaababaaadaaaaaaabaaaa
				aaaaaaleaaaaaaaaaaaaabakaaacaaadaaabaaaaaaaaaaoeaaaaaaaaaaaaabbf
				aaacaaabaaabaaaaaaaaaammaaaaaaaafpechfgnhaengbhaaaklklklaaaeaaam
				aaabaaabaaabaaaaaaaaaaaafpedgpgmgphcaaklaaabaaadaaabaaaeaaabaaaa
				aaaaaaaafpedhfhegpggggaaaaaaaaadaaabaaabaaabaaaaaaaaaaaafpemgjgh
				giheedgpgmgphcdaaafpengbgjgofegfhiaafpfdgigjgogjgogfhdhdaafpfdha
				gfgdedgpgmgphcaahahdfpddfpdaaadccodacodcdadddfddcodaaaklaaaaaaaa
				aaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaeaaaaaabfabaaaaeaaaaaaaaaeaaaaaaaaaaaacigdaaahaaah
				aaaaaacbaaaapafaaaaahbfbaaaahcfcaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaalpiaaaaaedaaaaaadpiaaaaa
				eaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabajfaadaaaabcaameaaaaaaaaaagaai
				gaaobcaabcaaaaaaaaaagabebabkbcaaccaaaaaabaaidaabbpbppgiiaaaaeaaa
				miacaaaaaablblaakbadacaaliiiacababloloebnaacacaemiaaaaaaaagmblaa
				hjpoacaadibiaaabbpbppghpaaaaeaaafibhaaadaamamablkbadacibmiadaaae
				aamhgmlbilaapppomjaeaaaaaalalagmnbaeaepomiahaaacaagmmamaolaaacab
				miabaaaaaaloloaapaacacaafibiaaabaemgblgmkaaapoiakaenaeaaaapagmbl
				obacaaibmiabaaaaacmploaapaaaaeaabeaeaaaaaelologmnaaeabadambmabaa
				aaomgmmgicaapopoeaboaaabaapmpmmgkbadaaiamiapaaacaaaabiaaobabaaaa
				dibhaaabaamamagmcbaaabacmiaiaaadaagmgmaaobadaaaamiaoaaabaaebflaa
				obabadaamiabaaabaablgmaaobabaaaamianaaaaaaafpaaaoaacabaamianaaaa
				aaaeaeaaoaaaaaaamiapiaaaaajejeaaocaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				"
			}
			
			SubProgram "ps3 " {
				Keywords { "DIRECTIONAL" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0001c0200007fff8000000000000848003000000
				[Offsets]
				5
				_LightColor0 2 0
				000001e000000130
				_SpecColor 1 0
				000001b0
				_Color 1 0
				00000020
				_Shininess 1 0
				000000c0
				_Cutoff 1 0
				00000040
				[Microcode]
				640
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				940417025c011c9dc8000001c8003fe106880440ce081c9d00020000aa020000
				000040000000bf800000000000000000ae800140c8011c9dc8000001c8003fe1
				1080b840c9101c9dc9100001c8000001028a014000021c9cc8000001c8000001
				00000000000000000000000000000000ce843940c8011c9dc8000029c800bfe1
				0e020340c9001c9dc9080001c800000110800340c9001c9f00020000c8000001
				00003f800000000000000000000000000e843940c8041c9dc8000029c8000001
				0e860140c8021c9dc8000001c800000100000000000000000000000000000000
				1088024001141c9cc8020001c800000100000000000000000000000000004300
				08883b40ff003c9dff000001c800000102840540c9101c9fc9080001c8000001
				1004090001081c9cc8020001c800000100000000000000000000000000000000
				0e860240c90c1c9dc8020001c800000100000000000000000000000000000000
				08041d00fe081c9dc8000001c80000010e840240f3041c9dc8020001c8000001
				000000000000000000000000000000001000020054081c9dc9100001c8000001
				02800540c9101c9fc9000001c800000102800900c9001c9d00020000c8000001
				0000000000000000000000000000000004001c00fe001c9dc8000001c8000001
				10000200ab041c9caa000000c80000010e800240c9081c9d01000000c8000001
				0e800400c90c1c9dfe001001c90000011081014001041c9cc8000001c8000001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "DIRECTIONAL" }
				
				ConstBuffer "$Globals" 128 
				Vector 16 [_LightColor0] 4
				Vector 32 [_SpecColor] 4
				Vector 48 [_Color] 4
				Float 64 [_Shininess]
				Float 112 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 0
				SetTexture 1 [_BumpMap] 2D 1
				
				"ps_4_0
				eefiecedkomhnlijlopnpkpobfagmgoapcaippppabaaaaaacaafaaaaadaaaaaa
				cmaaaaaaleaaaaaaoiaaaaaaejfdeheoiaaaaaaaaeaaaaaaaiaaaaaagiaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaheaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaaheaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				ahahaaaaheaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaafdfgfpfa
				epfdejfeejepeoaafeeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaa
				aiaaaaaacaaaaaaaaaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfe
				gbhcghgfheaaklklfdeieefcdaaeaaaaeaaaaaaaamabaaaafjaaaaaeegiocaaa
				aaaaaaaaaiaaaaaafkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaa
				fibiaaaeaahabaaaaaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaaffffaaaa
				gcbaaaadpcbabaaaabaaaaaagcbaaaadhcbabaaaacaaaaaagcbaaaadhcbabaaa
				adaaaaaagfaaaaadpccabaaaaaaaaaaagiaaaaacadaaaaaaefaaaaajpcaabaaa
				aaaaaaaaegbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaaaaaaaaadcaaaaam
				bcaabaaaabaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaadaaaaaaakiacaia
				ebaaaaaaaaaaaaaaahaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaa
				egiocaaaaaaaaaaaadaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaa
				abeaaaaaaaaaaaaaanaaaeadakaabaaaabaaaaaabaaaaaahbcaabaaaabaaaaaa
				egbcbaaaadaaaaaaegbcbaaaadaaaaaaeeaaaaafbcaabaaaabaaaaaaakaabaaa
				abaaaaaadcaaaaajhcaabaaaabaaaaaaegbcbaaaadaaaaaaagaabaaaabaaaaaa
				egbcbaaaacaaaaaabaaaaaahicaabaaaabaaaaaaegacbaaaabaaaaaaegacbaaa
				abaaaaaaeeaaaaaficaabaaaabaaaaaadkaabaaaabaaaaaadiaaaaahhcaabaaa
				abaaaaaapgapbaaaabaaaaaaegacbaaaabaaaaaaefaaaaajpcaabaaaacaaaaaa
				ogbkbaaaabaaaaaaeghobaaaabaaaaaaaagabaaaabaaaaaadcaaaaapdcaabaaa
				acaaaaaahgapbaaaacaaaaaaaceaaaaaaaaaaaeaaaaaaaeaaaaaaaaaaaaaaaaa
				aceaaaaaaaaaialpaaaaialpaaaaaaaaaaaaaaaaapaaaaahicaabaaaabaaaaaa
				egaabaaaacaaaaaaegaabaaaacaaaaaaddaaaaahicaabaaaabaaaaaadkaabaaa
				abaaaaaaabeaaaaaaaaaiadpaaaaaaaiicaabaaaabaaaaaadkaabaiaebaaaaaa
				abaaaaaaabeaaaaaaaaaiadpelaaaaafecaabaaaacaaaaaadkaabaaaabaaaaaa
				baaaaaaibcaabaaaabaaaaaaegacbaiaebaaaaaaacaaaaaaegacbaaaabaaaaaa
				baaaaaaiccaabaaaabaaaaaaegacbaiaebaaaaaaacaaaaaaegbcbaaaacaaaaaa
				deaaaaakdcaabaaaabaaaaaaegaabaaaabaaaaaaaceaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaacpaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaai
				ecaabaaaabaaaaaaakiacaaaaaaaaaaaaeaaaaaaabeaaaaaaaaaaaeddiaaaaah
				bcaabaaaabaaaaaaakaabaaaabaaaaaackaabaaaabaaaaaabjaaaaafbcaabaaa
				abaaaaaaakaabaaaabaaaaaadiaaaaahbcaabaaaabaaaaaaakaabaaaaaaaaaaa
				akaabaaaabaaaaaadiaaaaajhcaabaaaacaaaaaaegiccaaaaaaaaaaaabaaaaaa
				egiccaaaaaaaaaaaacaaaaaadiaaaaahncaabaaaabaaaaaaagaabaaaabaaaaaa
				agajbaaaacaaaaaadiaaaaaihcaabaaaaaaaaaaaegacbaaaaaaaaaaaegiccaaa
				aaaaaaaaabaaaaaadgaaaaaficcabaaaaaaaaaaadkaabaaaaaaaaaaadcaaaaaj
				hcaabaaaaaaaaaaaegacbaaaaaaaaaaafgafbaaaabaaaaaaigadbaaaabaaaaaa
				aaaaaaahhccabaaaaaaaaaaaegacbaaaaaaaaaaaegacbaaaaaaaaaaadoaaaaab
				"
			}
			
			SubProgram "gles " {
				Keywords { "DIRECTIONAL" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "DIRECTIONAL" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "DIRECTIONAL" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "SPOT" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTexture0] 2D
				SetTexture 3 [_LightTextureB0] 2D
				"3.0-!!ARBfp1.0
				# 45 ALU, 4 TEX
				PARAM c[7] = { program.local[0..4],
					{ 2, 1, 0, 128 },
				{ 0.5 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				DP3 R0.x, fragment.texcoord[1], fragment.texcoord[1];
				RSQ R0.x, R0.x;
				DP3 R1.w, fragment.texcoord[2], fragment.texcoord[2];
				MUL R1.xyz, R0.x, fragment.texcoord[1];
				TEX R0.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MAD R0.xy, R0.wyzw, c[5].x, -c[5].y;
				MUL R0.zw, R0.xyxy, R0.xyxy;
				ADD_SAT R0.z, R0, R0.w;
				RSQ R1.w, R1.w;
				MAD R2.xyz, R1.w, fragment.texcoord[2], R1;
				DP3 R0.w, R2, R2;
				RSQ R0.w, R0.w;
				ADD R0.z, -R0, c[5].y;
				RSQ R0.z, R0.z;
				MUL R2.xyz, R0.w, R2;
				RCP R0.z, R0.z;
				DP3 R0.w, -R0, R1;
				DP3 R1.w, -R0, R2;
				MAX R1.x, R1.w, c[5].z;
				MOV R0.x, c[5].w;
				MUL R1.y, R0.x, c[3].x;
				TEX R2, fragment.texcoord[0], texture[0], 2D;
				DP3 R1.w, fragment.texcoord[3], fragment.texcoord[3];
				MUL R0.xyz, R2, c[2];
				POW R1.x, R1.x, R1.y;
				MUL R2.z, R1.x, R0.x;
				MAX R0.w, R0, c[5].z;
				MUL R0.xyz, R0, c[0];
				MUL R1.xyz, R0, R0.w;
				RCP R0.w, fragment.texcoord[3].w;
				MAD R2.xy, fragment.texcoord[3], R0.w, c[6].x;
				TEX R0.w, R2, texture[2], 2D;
				MOV R0.xyz, c[1];
				MUL R0.xyz, R0, c[0];
				SLT R2.x, c[5].z, fragment.texcoord[3].z;
				MAD R0.xyz, R0, R2.z, R1;
				TEX R1.w, R1.w, texture[3], 2D;
				MUL R0.w, R2.x, R0;
				MUL R0.w, R0, R1;
				MUL R1.x, R0.w, c[5];
				MUL R0.w, R2, c[2];
				MUL result.color.xyz, R0, R1.x;
				SLT R0.x, R0.w, c[4];
				MOV result.color.w, R0;
				KIL -R0.x;
				END
				# 45 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "SPOT" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTexture0] 2D
				SetTexture 3 [_LightTextureB0] 2D
				"ps_3_0
				; 45 ALU, 5 TEX
				dcl_2d s0
				dcl_2d s1
				dcl_2d s2
				dcl_2d s3
				def c5, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c6, 128.00000000, 0.50000000, 0, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1.xyz
				dcl_texcoord2 v2.xyz
				dcl_texcoord3 v3
				texld r0.yw, v0.zwzw, s1
				dp3_pp r0.z, v1, v1
				rsq_pp r1.x, r0.z
				mad_pp r0.xy, r0.wyzw, c5.z, c5.w
				mul_pp r0.zw, r0.xyxy, r0.xyxy
				add_pp_sat r0.z, r0, r0.w
				dp3_pp r0.w, v2, v2
				add_pp r0.z, -r0, c5.y
				rsq_pp r0.z, r0.z
				mul_pp r1.xyz, r1.x, v1
				rsq_pp r0.w, r0.w
				mad_pp r2.xyz, r0.w, v2, r1
				rcp_pp r0.z, r0.z
				dp3_pp r0.w, r2, r2
				rsq_pp r0.w, r0.w
				mul_pp r2.xyz, r0.w, r2
				dp3_pp r1.x, -r0, r1
				dp3_pp r0.x, -r0, r2
				mov_pp r0.w, c3.x
				mul_pp r0.y, c6.x, r0.w
				max_pp r0.x, r0, c5
				pow r2, r0.x, r0.y
				texld r0, v0, s0
				mov r1.y, r2.x
				mul_pp r0.xyz, r0, c2
				mul r1.w, r1.y, r0.x
				max_pp r2.x, r1, c5
				mul_pp r1.xyz, r0, c0
				mov_pp r0.xyz, c0
				mul_pp r0.xyz, c1, r0
				mul_pp r1.xyz, r1, r2.x
				mad r1.xyz, r0, r1.w, r1
				mul_pp r1.w, r0, c2
				rcp r0.x, v3.w
				mad r2.xy, v3, r0.x, c6.y
				dp3 r0.x, v3, v3
				texld r0.w, r2, s2
				cmp r0.z, -v3, c5.x, c5.y
				mul_pp r0.z, r0, r0.w
				texld r0.x, r0.x, s3
				mul_pp r0.z, r0, r0.x
				add_pp r0.y, r1.w, -c4.x
				mul_pp r2.x, r0.z, c5.z
				cmp r0.x, r0.y, c5, c5.y
				mov_pp r0, -r0.x
				mul oC0.xyz, r1, r2.x
				texkill r0.xyzw
				mov_pp oC0.w, r1
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "SPOT" }
				
				Vector 2 [_Color]
				Float 4 [_Cutoff]
				Vector 0 [_LightColor0]
				Float 3 [_Shininess]
				Vector 1 [_SpecColor]
				SetTexture 0 [_LightTexture0] 2D
				SetTexture 1 [_LightTextureB0] 2D
				SetTexture 2 [_MainTex] 2D
				SetTexture 3 [_BumpMap] 2D
				
				"ps_360
				backbbaaaaaaabpmaaaaacaiaaaaaaaaaaaaaaceaaaaabkeaaaaabmmaaaaaaaa
				aaaaaaaaaaaaabhmaaaaaabmaaaaabgoppppadaaaaaaaaajaaaaaabmaaaaaaaa
				aaaaabghaaaaaanaaaadaaadaaabaaaaaaaaaanmaaaaaaaaaaaaaaomaaacaaac
				aaabaaaaaaaaaapeaaaaaaaaaaaaabaeaaacaaaeaaabaaaaaaaaabamaaaaaaaa
				aaaaabbmaaacaaaaaaabaaaaaaaaaapeaaaaaaaaaaaaabcjaaadaaaaaaabaaaa
				aaaaaanmaaaaaaaaaaaaabdiaaadaaabaaabaaaaaaaaaanmaaaaaaaaaaaaabei
				aaadaaacaaabaaaaaaaaaanmaaaaaaaaaaaaabfbaaacaaadaaabaaaaaaaaabam
				aaaaaaaaaaaaabfmaaacaaabaaabaaaaaaaaaapeaaaaaaaafpechfgnhaengbha
				aaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaafpedgpgmgphcaaklaaabaaad
				aaabaaaeaaabaaaaaaaaaaaafpedhfhegpggggaaaaaaaaadaaabaaabaaabaaaa
				aaaaaaaafpemgjghgiheedgpgmgphcdaaafpemgjghgihefegfhihehfhcgfdaaa
				fpemgjghgihefegfhihehfhcgfecdaaafpengbgjgofegfhiaafpfdgigjgogjgo
				gfhdhdaafpfdhagfgdedgpgmgphcaahahdfpddfpdaaadccodacodcdadddfddco
				daaaklklaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeaaaaaabmibaaaagaaaaaaaaaeaaaaaaaa
				aaaadiieaaapaaapaaaaaacbaaaapafaaaaahbfbaaaahcfcaaaapdfdaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaadpaaaaaa
				aaaaaaaaedaaaaaadpiaaaaalpiaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaajgaae
				daakbcaabcaaaabfaaaaaaaagaanmeaabcaaaaaaaaaagabdgabjbcaabcaaaaaa
				aaaagabpaaaaccaaaaaaaaaabacigaabbpbppgiiaaaaeaaaemciaaabaalolobl
				paadadadmiadaaaeaalblagmmlaaadpomiacaaaaaablblaakbagacaalieiaeac
				abloloebnaababaemiaaaaaaaalbmgaahjpoaeaadidiaaabbpbppghpaaaaeaaa
				pmbiaacbbpbppppiaaaaeaaabaaifaibbpbpppplaaaaeaaafiiiacabaalolobl
				paacacicfibhabaeaablmablobacabibmiaoaaafaagmpmpmolabacaecabcabab
				aamdmdmgpaafafadficbabadaagmmglbcbadpoibmiapaaafaaaalaaaobafabaa
				miabaaaaaagmgmaaobafaaaamiahaaabaamimiaaoaaaaaaamiagaaadaambgmaa
				kaabppaamjabaaaaaamfmflbnbadadpolibaaaaaaaaaaaaamcaaaapokaihadac
				aamamagmkbagaciamiabaaaaacmdmdaapaafadaamiaeaaaaaclomdaapaaeadaa
				miamaaaaaaomlbaakcaapoaaeaboaaadaapmpmmgkbacaaiamiapaaadaaaabiaa
				obadaaaadibhaaaeaamamagmcbaaabadmiaiaaacaagmgmaaobacaaaamiaoaaac
				aaebflaaobaeacaamiabaaacaablgmaaobacaaaamianaaaaaaafpaaaoaadacaa
				mianaaaaaagmaeaaobabaaaamiapiaaaaajejeaaocaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "SPOT" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTexture0] 2D
				SetTexture 3 [_LightTextureB0] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0003c020000ffff0000000000000848004000000
				[Offsets]
				5
				_LightColor0 2 0
				0000026000000100
				_SpecColor 1 0
				00000130
				_Color 1 0
				00000020
				_Shininess 1 0
				000001f0
				_Cutoff 1 0
				00000040
				[Microcode]
				848
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				fe060100c8011c9dc8000001c8003fe108020500c80c1c9dc80c0001c8000001
				940217025c011c9dc8000001c8003fe106880440ce041c9d00020000aa020000
				000040000000bf80000000000000000006063a00c80c1c9dfe0c0001c8000001
				0280b840c9101c9dc9100001c80000011080034001001c9ec8020001c8000001
				00000000000000000000000000003f800e800140c8021c9dc8000001c8000001
				00000000000000000000000000000000ae8a3940c8011c9dc8000029c800bfe1
				0e840240c9001c9dc8020001c800000100000000000000000000000000000000
				08883b40ff003c9dff000001c800000106000300c80c1c9d00020000c8000001
				00003f0000000000000000000000000010021704c8001c9dc8000001c8000001
				10800d00540c1c9d00020000c800000100000000000000000000000000000000
				ce803940c8011c9dc8000029c800bfe10e060340c9141c9dc9000001c8000001
				0e8c3940c80c1c9dc8000029c8000001028c0540c9101c9fc9180001c8000001
				108c014000021c9cc8000001c800000100000000000000000000000000000000
				1006090001181c9c00020000c800000100000000000000000000000000000000
				08800240ff181c9daa020000c800000100000000000043000000000000000000
				08061d00fe0c1c9dc8000001c80000010e8c0240f3041c9dc8020001c8000001
				0000000000000000000000000000000010060200540c1c9d55000001c8000001
				06000100c8001c9dc8000001c8000001108c0540c9101c9fc9140001c8000001
				10800240c9001c9dc8040001c80000010200170654041c9dc8000001c8000001
				028e0900ff181c9d00020000c800000100000000000000000000000000000000
				10001c00fe0c1c9dc8000001c800000110040200ab041c9cc8000001c8000001
				0e880240c9181c9d011c0000c80000010e040400c9081c9dfe080001c9100001
				02800240ff001c9dc8001001c80000011080014001041c9cc8000001c8000001
				0e810200c8081c9d01000000c8000001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "SPOT" }
				
				ConstBuffer "$Globals" 192 
				Vector 16 [_LightColor0] 4
				Vector 32 [_SpecColor] 4
				Vector 112 [_Color] 4
				Float 128 [_Shininess]
				Float 176 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 2
				SetTexture 1 [_BumpMap] 2D 3
				SetTexture 2 [_LightTexture0] 2D 0
				SetTexture 3 [_LightTextureB0] 2D 1
				
				"ps_4_0
				eefiecedcacgdcgjipbdhbfjcooehdpnobeieolmabaaaaaaoaagaaaaadaaaaaa
				cmaaaaaammaaaaaaaaabaaaaejfdeheojiaaaaaaafaaaaaaaiaaaaaaiaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaimaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaaimaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				ahahaaaaimaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaaimaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaapapaaaafdfgfpfaepfdejfeejepeoaa
				feeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaa
				aaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklkl
				fdeieefcniafaaaaeaaaaaaahgabaaaafjaaaaaeegiocaaaaaaaaaaaamaaaaaa
				fkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaafkaaaaadaagabaaa
				acaaaaaafkaaaaadaagabaaaadaaaaaafibiaaaeaahabaaaaaaaaaaaffffaaaa
				fibiaaaeaahabaaaabaaaaaaffffaaaafibiaaaeaahabaaaacaaaaaaffffaaaa
				fibiaaaeaahabaaaadaaaaaaffffaaaagcbaaaadpcbabaaaabaaaaaagcbaaaad
				hcbabaaaacaaaaaagcbaaaadhcbabaaaadaaaaaagcbaaaadpcbabaaaaeaaaaaa
				gfaaaaadpccabaaaaaaaaaaagiaaaaacaeaaaaaaefaaaaajpcaabaaaaaaaaaaa
				egbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaacaaaaaadcaaaaambcaabaaa
				abaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaahaaaaaaakiacaiaebaaaaaa
				aaaaaaaaalaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaaegiocaaa
				aaaaaaaaahaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaa
				aaaaaaaaanaaaeadakaabaaaabaaaaaabaaaaaahbcaabaaaabaaaaaaegbcbaaa
				adaaaaaaegbcbaaaadaaaaaaeeaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaa
				baaaaaahccaabaaaabaaaaaaegbcbaaaacaaaaaaegbcbaaaacaaaaaaeeaaaaaf
				ccaabaaaabaaaaaabkaabaaaabaaaaaadiaaaaahocaabaaaabaaaaaafgafbaaa
				abaaaaaaagbjbaaaacaaaaaadcaaaaajhcaabaaaacaaaaaaegbcbaaaadaaaaaa
				agaabaaaabaaaaaajgahbaaaabaaaaaabaaaaaahbcaabaaaabaaaaaaegacbaaa
				acaaaaaaegacbaaaacaaaaaaeeaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaa
				diaaaaahhcaabaaaacaaaaaaagaabaaaabaaaaaaegacbaaaacaaaaaaefaaaaaj
				pcaabaaaadaaaaaaogbkbaaaabaaaaaaeghobaaaabaaaaaaaagabaaaadaaaaaa
				dcaaaaapdcaabaaaadaaaaaahgapbaaaadaaaaaaaceaaaaaaaaaaaeaaaaaaaea
				aaaaaaaaaaaaaaaaaceaaaaaaaaaialpaaaaialpaaaaaaaaaaaaaaaaapaaaaah
				bcaabaaaabaaaaaaegaabaaaadaaaaaaegaabaaaadaaaaaaddaaaaahbcaabaaa
				abaaaaaaakaabaaaabaaaaaaabeaaaaaaaaaiadpaaaaaaaibcaabaaaabaaaaaa
				akaabaiaebaaaaaaabaaaaaaabeaaaaaaaaaiadpelaaaaafecaabaaaadaaaaaa
				akaabaaaabaaaaaabaaaaaaibcaabaaaabaaaaaaegacbaiaebaaaaaaadaaaaaa
				egacbaaaacaaaaaabaaaaaaiccaabaaaabaaaaaaegacbaiaebaaaaaaadaaaaaa
				jgahbaaaabaaaaaadeaaaaakdcaabaaaabaaaaaaegaabaaaabaaaaaaaceaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaacpaaaaafbcaabaaaabaaaaaaakaabaaa
				abaaaaaadiaaaaaiecaabaaaabaaaaaaakiacaaaaaaaaaaaaiaaaaaaabeaaaaa
				aaaaaaeddiaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaackaabaaaabaaaaaa
				bjaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaahbcaabaaaabaaaaaa
				akaabaaaaaaaaaaaakaabaaaabaaaaaadiaaaaajhcaabaaaacaaaaaaegiccaaa
				aaaaaaaaabaaaaaaegiccaaaaaaaaaaaacaaaaaadiaaaaahncaabaaaabaaaaaa
				agaabaaaabaaaaaaagajbaaaacaaaaaadiaaaaaihcaabaaaaaaaaaaaegacbaaa
				aaaaaaaaegiccaaaaaaaaaaaabaaaaaadgaaaaaficcabaaaaaaaaaaadkaabaaa
				aaaaaaaadcaaaaajhcaabaaaaaaaaaaaegacbaaaaaaaaaaafgafbaaaabaaaaaa
				igadbaaaabaaaaaaaoaaaaahdcaabaaaabaaaaaaegbabaaaaeaaaaaapgbpbaaa
				aeaaaaaaaaaaaaakdcaabaaaabaaaaaaegaabaaaabaaaaaaaceaaaaaaaaaaadp
				aaaaaadpaaaaaaaaaaaaaaaaefaaaaajpcaabaaaabaaaaaaegaabaaaabaaaaaa
				eghobaaaacaaaaaaaagabaaaaaaaaaaadbaaaaahicaabaaaaaaaaaaaabeaaaaa
				aaaaaaaackbabaaaaeaaaaaaabaaaaahicaabaaaaaaaaaaadkaabaaaaaaaaaaa
				abeaaaaaaaaaiadpdiaaaaahicaabaaaaaaaaaaadkaabaaaabaaaaaadkaabaaa
				aaaaaaaabaaaaaahbcaabaaaabaaaaaaegbcbaaaaeaaaaaaegbcbaaaaeaaaaaa
				efaaaaajpcaabaaaabaaaaaaagaabaaaabaaaaaaeghobaaaadaaaaaaaagabaaa
				abaaaaaaapaaaaahicaabaaaaaaaaaaapgapbaaaaaaaaaaaagaabaaaabaaaaaa
				diaaaaahhccabaaaaaaaaaaapgapbaaaaaaaaaaaegacbaaaaaaaaaaadoaaaaab
				"
			}
			
			SubProgram "gles " {
				Keywords { "SPOT" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "SPOT" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "SPOT" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "POINT_COOKIE" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTextureB0] 2D
				SetTexture 3 [_LightTexture0] CUBE
				"3.0-!!ARBfp1.0
				# 41 ALU, 4 TEX
				PARAM c[6] = { program.local[0..4],
				{ 2, 1, 0, 128 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				DP3 R0.x, fragment.texcoord[1], fragment.texcoord[1];
				RSQ R0.x, R0.x;
				DP3 R1.w, fragment.texcoord[2], fragment.texcoord[2];
				MUL R1.xyz, R0.x, fragment.texcoord[1];
				TEX R0.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MAD R0.xy, R0.wyzw, c[5].x, -c[5].y;
				MUL R0.zw, R0.xyxy, R0.xyxy;
				ADD_SAT R0.z, R0, R0.w;
				RSQ R1.w, R1.w;
				MAD R2.xyz, R1.w, fragment.texcoord[2], R1;
				DP3 R0.w, R2, R2;
				RSQ R0.w, R0.w;
				ADD R0.z, -R0, c[5].y;
				RSQ R0.z, R0.z;
				MUL R2.xyz, R0.w, R2;
				RCP R0.z, R0.z;
				DP3 R0.w, -R0, R1;
				DP3 R1.w, -R0, R2;
				MAX R1.x, R1.w, c[5].z;
				MOV R0.x, c[5].w;
				MUL R1.y, R0.x, c[3].x;
				TEX R2, fragment.texcoord[0], texture[0], 2D;
				DP3 R1.w, fragment.texcoord[3], fragment.texcoord[3];
				MUL R0.xyz, R2, c[2];
				POW R1.x, R1.x, R1.y;
				MUL R2.x, R1, R0;
				MUL R1.xyz, R0, c[0];
				MAX R0.w, R0, c[5].z;
				MUL R1.xyz, R1, R0.w;
				MOV R0.xyz, c[1];
				MUL R0.xyz, R0, c[0];
				MAD R0.xyz, R0, R2.x, R1;
				TEX R0.w, fragment.texcoord[3], texture[3], CUBE;
				TEX R1.w, R1.w, texture[2], 2D;
				MUL R0.w, R1, R0;
				MUL R1.x, R0.w, c[5];
				MUL R0.w, R2, c[2];
				MUL result.color.xyz, R0, R1.x;
				SLT R0.x, R0.w, c[4];
				MOV result.color.w, R0;
				KIL -R0.x;
				END
				# 41 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "POINT_COOKIE" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTextureB0] 2D
				SetTexture 3 [_LightTexture0] CUBE
				"ps_3_0
				; 41 ALU, 5 TEX
				dcl_2d s0
				dcl_2d s1
				dcl_2d s2
				dcl_cube s3
				def c5, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c6, 128.00000000, 0, 0, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1.xyz
				dcl_texcoord2 v2.xyz
				dcl_texcoord3 v3.xyz
				texld r0.yw, v0.zwzw, s1
				dp3_pp r0.z, v1, v1
				rsq_pp r1.x, r0.z
				mad_pp r0.xy, r0.wyzw, c5.z, c5.w
				mul_pp r0.zw, r0.xyxy, r0.xyxy
				add_pp_sat r0.z, r0, r0.w
				dp3_pp r0.w, v2, v2
				add_pp r0.z, -r0, c5.y
				rsq_pp r0.z, r0.z
				mul_pp r1.xyz, r1.x, v1
				rsq_pp r0.w, r0.w
				mad_pp r2.xyz, r0.w, v2, r1
				rcp_pp r0.z, r0.z
				dp3_pp r1.x, -r0, r1
				dp3_pp r0.w, r2, r2
				rsq_pp r0.w, r0.w
				mul_pp r2.xyz, r0.w, r2
				dp3_pp r0.x, -r0, r2
				mov_pp r0.w, c3.x
				mul_pp r0.y, c6.x, r0.w
				max_pp r0.x, r0, c5
				pow r2, r0.x, r0.y
				texld r0, v0, s0
				mul_pp r1.w, r0, c2
				mov r1.y, r2.x
				mul_pp r0.xyz, r0, c2
				mul r2.x, r1.y, r0
				mul_pp r0.xyz, r0, c0
				max_pp r1.x, r1, c5
				mul_pp r1.xyz, r0, r1.x
				mov_pp r0.xyz, c0
				mul_pp r0.xyz, c1, r0
				mad r1.xyz, r0, r2.x, r1
				dp3 r0.x, v3, v3
				add_pp r0.y, r1.w, -c4.x
				texld r0.w, v3, s3
				texld r0.x, r0.x, s2
				mul r0.z, r0.x, r0.w
				mul_pp r2.x, r0.z, c5.z
				cmp r0.x, r0.y, c5, c5.y
				mov_pp r0, -r0.x
				mul oC0.xyz, r1, r2.x
				texkill r0.xyzw
				mov_pp oC0.w, r1
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "POINT_COOKIE" }
				
				Vector 2 [_Color]
				Float 4 [_Cutoff]
				Vector 0 [_LightColor0]
				Float 3 [_Shininess]
				Vector 1 [_SpecColor]
				SetTexture 0 [_LightTexture0] CUBE
				SetTexture 1 [_LightTextureB0] 2D
				SetTexture 2 [_MainTex] 2D
				SetTexture 3 [_BumpMap] 2D
				
				"ps_360
				backbbaaaaaaacamaaaaacaiaaaaaaaaaaaaaaceaaaaableaaaaabnmaaaaaaaa
				aaaaaaaaaaaaabimaaaaaabmaaaaabhoppppadaaaaaaaaajaaaaaabmaaaaaaaa
				aaaaabhhaaaaaanaaaadaaadaaabaaaaaaaaaanmaaaaaaaaaaaaaaomaaacaaac
				aaabaaaaaaaaaapeaaaaaaaaaaaaabaeaaacaaaeaaabaaaaaaaaabamaaaaaaaa
				aaaaabbmaaacaaaaaaabaaaaaaaaaapeaaaaaaaaaaaaabcjaaadaaaaaaabaaaa
				aaaaabdiaaaaaaaaaaaaabeiaaadaaabaaabaaaaaaaaaanmaaaaaaaaaaaaabfi
				aaadaaacaaabaaaaaaaaaanmaaaaaaaaaaaaabgbaaacaaadaaabaaaaaaaaabam
				aaaaaaaaaaaaabgmaaacaaabaaabaaaaaaaaaapeaaaaaaaafpechfgnhaengbha
				aaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaafpedgpgmgphcaaklaaabaaad
				aaabaaaeaaabaaaaaaaaaaaafpedhfhegpggggaaaaaaaaadaaabaaabaaabaaaa
				aaaaaaaafpemgjghgiheedgpgmgphcdaaafpemgjghgihefegfhihehfhcgfdaaa
				aaaeaaaoaaabaaabaaabaaaaaaaaaaaafpemgjghgihefegfhihehfhcgfecdaaa
				fpengbgjgofegfhiaafpfdgigjgogjgogfhdhdaafpfdhagfgdedgpgmgphcaaha
				hdfpddfpdaaadccodacodcdadddfddcodaaaklklaaaaaaaaaaaaaaabaaaaaaaa
				aaaaaaaaaaaaaabeabpmaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaea
				aaaaabmibaaaagaaaaaaaaaeaaaaaaaaaaaadeieaaapaaapaaaaaacbaaaapafa
				aaaahbfbaaaahcfcaaaahdfdaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaadpmaaaaaedaaaaaadpiaaaaalpiaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaajgaaedaakbcaabcaaaabfaaaaaaaagaanmeaa
				bcaaaaaaaaaagabdgabjbcaabcaaaaaaaaaagabpaaaaccaaaaaaaaaabacifaab
				bpbppgiiaaaaeaaamiapaaaeaakgmnaapcadadaaemicabaaaablblmgkbafacie
				miadaaagaagnbllbmlaeabpoliiiacababloloebnaadadaebeeaagaaaagmblbl
				hjpoacaedididaabbpbppompaaaaeaaajaaiaambbpbppoppaaaamaaapmbiaacb
				bpbppppiaaaaeaaamiabaaadaamggmaaobaaaaaamiaiaaabaaloloaapaacacaa
				miabaaaaaaloloaapaababaafibhaaaeaamamagmkbafaciamianaaaaaagmpaaa
				obaaabaafiihababaalelebloaadadibmiahaaadaablmabeolabacaamiaeaaac
				aaloloaapaadadaamiadaaacaamfgmaakaabppaamjaiaaabaalalagmnbacacpo
				fieiacabaeblblmgkaabpoickaehacadaamamgblobadacibmiabaaaaacmploaa
				paaaacaabeaeaaaaaclologmnaadacadamifacaaaamegmmgicaapopoeaihaaac
				aamamamgkbaeaaiamiapaaadaaaacmaaobacaaaadibhaaacaamamablcbaaabad
				miaiaaaeaagmgmaaobaeaaaamiaoaaacaaebflaaobacaeaamiabaaacaablgmaa
				obacaaaamianaaaaaapapaaaoaadacaamianaaaaaagmaeaaobabaaaamiapiaaa
				aajejeaaocaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "POINT_COOKIE" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTextureB0] 2D
				SetTexture 3 [_LightTexture0] CUBE
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0003c020000ffff0000000000000848004000000
				[Offsets]
				5
				_LightColor0 2 0
				00000220000000e0
				_SpecColor 1 0
				00000120
				_Color 1 0
				00000020
				_Shininess 1 0
				00000180
				_Cutoff 1 0
				00000040
				[Microcode]
				736
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				ee020100c8011c9dc8000001c8003fe110040500c8041c9dc8040001c8000001
				940217025c011c9dc8000001c8003fe1068e0440ce041c9d00020000aa020000
				000040000000bf800000000000000000ae8c3940c8011c9dc8000029c800bfe1
				1080b840c91c1c9dc91c0001c80000010e800140c8021c9dc8000001c8000001
				0000000000000000000000000000000010800340c9001c9fc8020001c8000001
				00000000000000000000000000003f800e840240c9001c9dc8020001c8000001
				0000000000000000000000000000000002001704fe081c9dc8000001c8000001
				ce883940c8011c9dc8000029c800bfe10e040340c9181c9dc9100001c8000001
				088e3b40ff003c9dff000001c80000011080014000021c9cc8000001c8000001
				000000000000000000000000000000000e883940c8081c9dc8000029c8000001
				08800540c91c1c9fc9100001c80000011004090055001c9d00020000c8000001
				0000000000000000000000000000000008800540c91c1c9fc9180001c8000001
				028a0240ff001c9d00020000c800000100004300000000000000000000000000
				10041d00fe081c9dc8000001c80000010e880240f3041c9dc8020001c8000001
				0000000000000000000000000000000010040200c8081c9d01140000c8000001
				10041c00fe081c9dc8000001c8000001028a090055001c9d00020000c8000001
				0000000000000000000000000000000004000200c9041c9dfe080001c8000001
				1c82024021101c9d01140000c8000001f0021706c8011c9dc8000001c8003fe1
				0e020400c9081c9daa000000f30400011080020000001c9cc8041001c8000001
				0e800200c8041c9dff000001c80000011081014001041c9cc8000001c8000001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "POINT_COOKIE" }
				
				ConstBuffer "$Globals" 192 
				Vector 16 [_LightColor0] 4
				Vector 32 [_SpecColor] 4
				Vector 112 [_Color] 4
				Float 128 [_Shininess]
				Float 176 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 2
				SetTexture 1 [_BumpMap] 2D 3
				SetTexture 2 [_LightTextureB0] 2D 1
				SetTexture 3 [_LightTexture0] CUBE 0
				
				"ps_4_0
				eefiecedklidcohcoegnjpakhmbnnaoigifhbmdgabaaaaaaeiagaaaaadaaaaaa
				cmaaaaaammaaaaaaaaabaaaaejfdeheojiaaaaaaafaaaaaaaiaaaaaaiaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaimaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaaimaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				ahahaaaaimaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaaimaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaahahaaaafdfgfpfaepfdejfeejepeoaa
				feeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaa
				aaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklkl
				fdeieefceaafaaaaeaaaaaaafaabaaaafjaaaaaeegiocaaaaaaaaaaaamaaaaaa
				fkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaafkaaaaadaagabaaa
				acaaaaaafkaaaaadaagabaaaadaaaaaafibiaaaeaahabaaaaaaaaaaaffffaaaa
				fibiaaaeaahabaaaabaaaaaaffffaaaafibiaaaeaahabaaaacaaaaaaffffaaaa
				fidaaaaeaahabaaaadaaaaaaffffaaaagcbaaaadpcbabaaaabaaaaaagcbaaaad
				hcbabaaaacaaaaaagcbaaaadhcbabaaaadaaaaaagcbaaaadhcbabaaaaeaaaaaa
				gfaaaaadpccabaaaaaaaaaaagiaaaaacaeaaaaaaefaaaaajpcaabaaaaaaaaaaa
				egbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaacaaaaaadcaaaaambcaabaaa
				abaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaahaaaaaaakiacaiaebaaaaaa
				aaaaaaaaalaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaaegiocaaa
				aaaaaaaaahaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaa
				aaaaaaaaanaaaeadakaabaaaabaaaaaabaaaaaahbcaabaaaabaaaaaaegbcbaaa
				adaaaaaaegbcbaaaadaaaaaaeeaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaa
				baaaaaahccaabaaaabaaaaaaegbcbaaaacaaaaaaegbcbaaaacaaaaaaeeaaaaaf
				ccaabaaaabaaaaaabkaabaaaabaaaaaadiaaaaahocaabaaaabaaaaaafgafbaaa
				abaaaaaaagbjbaaaacaaaaaadcaaaaajhcaabaaaacaaaaaaegbcbaaaadaaaaaa
				agaabaaaabaaaaaajgahbaaaabaaaaaabaaaaaahbcaabaaaabaaaaaaegacbaaa
				acaaaaaaegacbaaaacaaaaaaeeaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaa
				diaaaaahhcaabaaaacaaaaaaagaabaaaabaaaaaaegacbaaaacaaaaaaefaaaaaj
				pcaabaaaadaaaaaaogbkbaaaabaaaaaaeghobaaaabaaaaaaaagabaaaadaaaaaa
				dcaaaaapdcaabaaaadaaaaaahgapbaaaadaaaaaaaceaaaaaaaaaaaeaaaaaaaea
				aaaaaaaaaaaaaaaaaceaaaaaaaaaialpaaaaialpaaaaaaaaaaaaaaaaapaaaaah
				bcaabaaaabaaaaaaegaabaaaadaaaaaaegaabaaaadaaaaaaddaaaaahbcaabaaa
				abaaaaaaakaabaaaabaaaaaaabeaaaaaaaaaiadpaaaaaaaibcaabaaaabaaaaaa
				akaabaiaebaaaaaaabaaaaaaabeaaaaaaaaaiadpelaaaaafecaabaaaadaaaaaa
				akaabaaaabaaaaaabaaaaaaibcaabaaaabaaaaaaegacbaiaebaaaaaaadaaaaaa
				egacbaaaacaaaaaabaaaaaaiccaabaaaabaaaaaaegacbaiaebaaaaaaadaaaaaa
				jgahbaaaabaaaaaadeaaaaakdcaabaaaabaaaaaaegaabaaaabaaaaaaaceaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaacpaaaaafbcaabaaaabaaaaaaakaabaaa
				abaaaaaadiaaaaaiecaabaaaabaaaaaaakiacaaaaaaaaaaaaiaaaaaaabeaaaaa
				aaaaaaeddiaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaackaabaaaabaaaaaa
				bjaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaahbcaabaaaabaaaaaa
				akaabaaaaaaaaaaaakaabaaaabaaaaaadiaaaaajhcaabaaaacaaaaaaegiccaaa
				aaaaaaaaabaaaaaaegiccaaaaaaaaaaaacaaaaaadiaaaaahncaabaaaabaaaaaa
				agaabaaaabaaaaaaagajbaaaacaaaaaadiaaaaaihcaabaaaaaaaaaaaegacbaaa
				aaaaaaaaegiccaaaaaaaaaaaabaaaaaadgaaaaaficcabaaaaaaaaaaadkaabaaa
				aaaaaaaadcaaaaajhcaabaaaaaaaaaaaegacbaaaaaaaaaaafgafbaaaabaaaaaa
				igadbaaaabaaaaaabaaaaaahicaabaaaaaaaaaaaegbcbaaaaeaaaaaaegbcbaaa
				aeaaaaaaefaaaaajpcaabaaaabaaaaaapgapbaaaaaaaaaaaeghobaaaacaaaaaa
				aagabaaaabaaaaaaefaaaaajpcaabaaaacaaaaaaegbcbaaaaeaaaaaaeghobaaa
				adaaaaaaaagabaaaaaaaaaaaapaaaaahicaabaaaaaaaaaaaagaabaaaabaaaaaa
				pgapbaaaacaaaaaadiaaaaahhccabaaaaaaaaaaapgapbaaaaaaaaaaaegacbaaa
				aaaaaaaadoaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { "POINT_COOKIE" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "POINT_COOKIE" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "POINT_COOKIE" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "DIRECTIONAL_COOKIE" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTexture0] 2D
				"3.0-!!ARBfp1.0
				# 36 ALU, 3 TEX
				PARAM c[6] = { program.local[0..4],
				{ 2, 1, 0, 128 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEX R1.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MAD R1.xy, R1.wyzw, c[5].x, -c[5].y;
				DP3 R0.w, fragment.texcoord[2], fragment.texcoord[2];
				MOV R2.x, c[5].w;
				MUL R1.zw, R1.xyxy, R1.xyxy;
				RSQ R0.w, R0.w;
				MOV R0.xyz, fragment.texcoord[1];
				MAD R0.xyz, R0.w, fragment.texcoord[2], R0;
				ADD_SAT R0.w, R1.z, R1;
				DP3 R1.z, R0, R0;
				RSQ R1.z, R1.z;
				ADD R0.w, -R0, c[5].y;
				MUL R0.xyz, R1.z, R0;
				RSQ R0.w, R0.w;
				RCP R1.z, R0.w;
				DP3 R0.x, -R1, R0;
				MAX R1.w, R0.x, c[5].z;
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				MUL R2.x, R2, c[3];
				POW R1.w, R1.w, R2.x;
				MUL R0.xyz, R0, c[2];
				DP3 R2.x, -R1, fragment.texcoord[1];
				MUL R0.w, R0, c[2];
				MUL R1.w, R1, R0.x;
				MUL R1.xyz, R0, c[0];
				MAX R2.x, R2, c[5].z;
				MOV R0.xyz, c[1];
				MUL R1.xyz, R1, R2.x;
				MUL R0.xyz, R0, c[0];
				MAD R0.xyz, R0, R1.w, R1;
				TEX R2.w, fragment.texcoord[3], texture[2], 2D;
				MUL R1.x, R2.w, c[5];
				MUL result.color.xyz, R0, R1.x;
				SLT R0.x, R0.w, c[4];
				MOV result.color.w, R0;
				KIL -R0.x;
				END
				# 36 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "DIRECTIONAL_COOKIE" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTexture0] 2D
				"ps_3_0
				; 37 ALU, 4 TEX
				dcl_2d s0
				dcl_2d s1
				dcl_2d s2
				def c5, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c6, 128.00000000, 0, 0, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1.xyz
				dcl_texcoord2 v2.xyz
				dcl_texcoord3 v3.xy
				texld r1.yw, v0.zwzw, s1
				mad_pp r1.xy, r1.wyzw, c5.z, c5.w
				dp3_pp r0.w, v2, v2
				mul_pp r1.zw, r1.xyxy, r1.xyxy
				rsq_pp r0.w, r0.w
				mov_pp r0.xyz, v1
				mad_pp r0.xyz, r0.w, v2, r0
				add_pp_sat r0.w, r1.z, r1
				dp3_pp r1.z, r0, r0
				rsq_pp r1.z, r1.z
				add_pp r0.w, -r0, c5.y
				mul_pp r0.xyz, r1.z, r0
				rsq_pp r0.w, r0.w
				rcp_pp r1.z, r0.w
				dp3_pp r0.x, -r1, r0
				dp3_pp r1.x, -r1, v1
				mov_pp r0.w, c3.x
				mul_pp r2.x, c6, r0.w
				max_pp r1.w, r0.x, c5.x
				pow r0, r1.w, r2.x
				texld r2, v0, s0
				mov r0.w, r0.x
				mul_pp r0.xyz, r2, c2
				mul r0.w, r0, r0.x
				mul_pp r1.w, r2, c2
				mul_pp r0.xyz, r0, c0
				max_pp r1.x, r1, c5
				mul_pp r1.xyz, r0, r1.x
				mov_pp r0.xyz, c0
				mul_pp r0.xyz, c1, r0
				mad r1.xyz, r0, r0.w, r1
				texld r0.w, v3, s2
				mul_pp r2.x, r0.w, c5.z
				add_pp r0.x, r1.w, -c4
				cmp r0.x, r0, c5, c5.y
				mov_pp r0, -r0.x
				mul oC0.xyz, r1, r2.x
				texkill r0.xyzw
				mov_pp oC0.w, r1
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "DIRECTIONAL_COOKIE" }
				
				Vector 2 [_Color]
				Float 4 [_Cutoff]
				Vector 0 [_LightColor0]
				Float 3 [_Shininess]
				Vector 1 [_SpecColor]
				SetTexture 0 [_LightTexture0] 2D
				SetTexture 1 [_MainTex] 2D
				SetTexture 2 [_BumpMap] 2D
				
				"ps_360
				backbbaaaaaaabniaaaaabkiaaaaaaaaaaaaaaceaaaaabiaaaaaabkiaaaaaaaa
				aaaaaaaaaaaaabfiaaaaaabmaaaaabekppppadaaaaaaaaaiaaaaaabmaaaaaaaa
				aaaaabedaaaaaalmaaadaaacaaabaaaaaaaaaamiaaaaaaaaaaaaaaniaaacaaac
				aaabaaaaaaaaaaoaaaaaaaaaaaaaaapaaaacaaaeaaabaaaaaaaaaapiaaaaaaaa
				aaaaabaiaaacaaaaaaabaaaaaaaaaaoaaaaaaaaaaaaaabbfaaadaaaaaaabaaaa
				aaaaaamiaaaaaaaaaaaaabceaaadaaabaaabaaaaaaaaaamiaaaaaaaaaaaaabcn
				aaacaaadaaabaaaaaaaaaapiaaaaaaaaaaaaabdiaaacaaabaaabaaaaaaaaaaoa
				aaaaaaaafpechfgnhaengbhaaaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaa
				fpedgpgmgphcaaklaaabaaadaaabaaaeaaabaaaaaaaaaaaafpedhfhegpggggaa
				aaaaaaadaaabaaabaaabaaaaaaaaaaaafpemgjghgiheedgpgmgphcdaaafpemgj
				ghgihefegfhihehfhcgfdaaafpengbgjgofegfhiaafpfdgigjgogjgogfhdhdaa
				fpfdhagfgdedgpgmgphcaahahdfpddfpdaaadccodacodcdadddfddcodaaaklkl
				aaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaeaaaaaabgibaaaafaaaaaaaaaeaaaaaaaaaaaadaie
				aaapaaapaaaaaacbaaaapafaaaaahbfbaaaahcfcaaaaddfdaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaedaaaaaadpiaaaaalpiaaaaaafajgaadaaaabcaa
				meaaaaaaaaaagaajgaapbcaabcaaaaaaaaaagabfcablbcaaccaaaaaababieaab
				bpbppgiiaaaaeaaamiacaaaaaablblaakbaeacaaliihabaeabmamaebibaeacae
				miaaaaaaaagmblaahjppabaabaaidagbbpbpppplaaaaeaaadicidaabbpbppomp
				aaaaeaaamiabaaaaaaloloaapaacacaafibhaaadaalelegmoaadadiamiahaaaf
				aagmmamaolaaacabmiabaaaaaaloloaapaafafaamiadaaacaamfblaakaadppaa
				mjaeaaaaaalalagmnbacacppfibiaaabaemgmggmkaaappiakaenacaaaapagmbl
				obafaaibmiabaaaaacmploaapaaaacaabeaeaaaaaelologmnaacabadambmabaa
				aaomgmlbicaappppeaboaaabaapmpmmgkbaeaaiamiapaaacaaaabiaaobabaaaa
				dibhaaabaamamagmcbaaabacmiaiaaaeaagmgmaaobaeaaaamiaoaaabaaebflaa
				obabaeaamiabaaabaablgmaaobabaaaamianaaaaaaafpaaaoaacabaamianaaaa
				aagmaeaaobadaaaamiapiaaaaajejeaaocaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				"
			}
			
			SubProgram "ps3 " {
				Keywords { "DIRECTIONAL_COOKIE" }
				
				Vector 0 [_LightColor0]
				Vector 1 [_SpecColor]
				Vector 2 [_Color]
				Float 3 [_Shininess]
				Float 4 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightTexture0] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0003c020000ffff8000000000000848004000000
				[Offsets]
				5
				_LightColor0 2 0
				000001f000000110
				_SpecColor 1 0
				00000160
				_Color 1 0
				00000020
				_Shininess 1 0
				00000070
				_Cutoff 1 0
				00000040
				[Microcode]
				688
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				1084014000021c9cc8000001c800000100000000000000000000000000000000
				940617025c011c9dc8000001c8003fe1068c0440ce0c1c9d00020000aa020000
				000040000000bf800000000000000000ae800140c8011c9dc8000001c8003fe1
				1080b840c9181c9dc9180001c8000001028e0240ff081c9d00020000c8000001
				00004300000000000000000000000000ce863940c8011c9dc8000029c800bfe1
				0e840140c8021c9dc8000001c800000100000000000000000000000000000000
				10800340c9001c9fc8020001c800000100000000000000000000000000003f80
				0e040340c9001c9dc90c0001c80000010e840240c9081c9dc8020001c8000001
				00000000000000000000000000000000088c3b40ff003c9dff000001c8000001
				06000100c8001c9dc8000001c800000102800540c9181c9fc9000001c8000001
				0e863940c8081c9dc8000029c8000001108c0540c9181c9fc90c0001c8000001
				10060900c9181c9dc8020001c800000100000000000000000000000000000000
				0e860240f3041c9dc8020001c800000100000000000000000000000000000000
				10061d00fe0c1c9dc8000001c800000110000200c80c1c9d011c0000c8000001
				02800900c9001c9d00020000c800000100000000000000000000000000000000
				04001c00fe001c9dc8000001c800000110000200ab041c9caa000000c8000001
				0e800240c90c1c9d01000000c80000010e020400c9081c9dfe001001c9000001
				1080014001041c9cc8000001c8000001f0001704c8011c9dc8000001c8003fe1
				0e810200c8041c9dfe000001c8000001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "DIRECTIONAL_COOKIE" }
				
				ConstBuffer "$Globals" 192 
				Vector 16 [_LightColor0] 4
				Vector 32 [_SpecColor] 4
				Vector 112 [_Color] 4
				Float 128 [_Shininess]
				Float 176 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 1
				SetTexture 1 [_BumpMap] 2D 2
				SetTexture 2 [_LightTexture0] 2D 0
				
				"ps_4_0
				eefiecedkkecfaidmbdplhnmdcdehieiofohlbapabaaaaaakaafaaaaadaaaaaa
				cmaaaaaammaaaaaaaaabaaaaejfdeheojiaaaaaaafaaaaaaaiaaaaaaiaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaimaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaaimaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				ahahaaaaimaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaaimaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaadadaaaafdfgfpfaepfdejfeejepeoaa
				feeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaa
				aaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklkl
				fdeieefcjiaeaaaaeaaaaaaacgabaaaafjaaaaaeegiocaaaaaaaaaaaamaaaaaa
				fkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaafkaaaaadaagabaaa
				acaaaaaafibiaaaeaahabaaaaaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaa
				ffffaaaafibiaaaeaahabaaaacaaaaaaffffaaaagcbaaaadpcbabaaaabaaaaaa
				gcbaaaadhcbabaaaacaaaaaagcbaaaadhcbabaaaadaaaaaagcbaaaaddcbabaaa
				aeaaaaaagfaaaaadpccabaaaaaaaaaaagiaaaaacadaaaaaaefaaaaajpcaabaaa
				aaaaaaaaegbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaabaaaaaadcaaaaam
				bcaabaaaabaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaahaaaaaaakiacaia
				ebaaaaaaaaaaaaaaalaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaa
				egiocaaaaaaaaaaaahaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaa
				abeaaaaaaaaaaaaaanaaaeadakaabaaaabaaaaaabaaaaaahbcaabaaaabaaaaaa
				egbcbaaaadaaaaaaegbcbaaaadaaaaaaeeaaaaafbcaabaaaabaaaaaaakaabaaa
				abaaaaaadcaaaaajhcaabaaaabaaaaaaegbcbaaaadaaaaaaagaabaaaabaaaaaa
				egbcbaaaacaaaaaabaaaaaahicaabaaaabaaaaaaegacbaaaabaaaaaaegacbaaa
				abaaaaaaeeaaaaaficaabaaaabaaaaaadkaabaaaabaaaaaadiaaaaahhcaabaaa
				abaaaaaapgapbaaaabaaaaaaegacbaaaabaaaaaaefaaaaajpcaabaaaacaaaaaa
				ogbkbaaaabaaaaaaeghobaaaabaaaaaaaagabaaaacaaaaaadcaaaaapdcaabaaa
				acaaaaaahgapbaaaacaaaaaaaceaaaaaaaaaaaeaaaaaaaeaaaaaaaaaaaaaaaaa
				aceaaaaaaaaaialpaaaaialpaaaaaaaaaaaaaaaaapaaaaahicaabaaaabaaaaaa
				egaabaaaacaaaaaaegaabaaaacaaaaaaddaaaaahicaabaaaabaaaaaadkaabaaa
				abaaaaaaabeaaaaaaaaaiadpaaaaaaaiicaabaaaabaaaaaadkaabaiaebaaaaaa
				abaaaaaaabeaaaaaaaaaiadpelaaaaafecaabaaaacaaaaaadkaabaaaabaaaaaa
				baaaaaaibcaabaaaabaaaaaaegacbaiaebaaaaaaacaaaaaaegacbaaaabaaaaaa
				baaaaaaiccaabaaaabaaaaaaegacbaiaebaaaaaaacaaaaaaegbcbaaaacaaaaaa
				deaaaaakdcaabaaaabaaaaaaegaabaaaabaaaaaaaceaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaacpaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaai
				ecaabaaaabaaaaaaakiacaaaaaaaaaaaaiaaaaaaabeaaaaaaaaaaaeddiaaaaah
				bcaabaaaabaaaaaaakaabaaaabaaaaaackaabaaaabaaaaaabjaaaaafbcaabaaa
				abaaaaaaakaabaaaabaaaaaadiaaaaahbcaabaaaabaaaaaaakaabaaaaaaaaaaa
				akaabaaaabaaaaaadiaaaaajhcaabaaaacaaaaaaegiccaaaaaaaaaaaabaaaaaa
				egiccaaaaaaaaaaaacaaaaaadiaaaaahncaabaaaabaaaaaaagaabaaaabaaaaaa
				agajbaaaacaaaaaadiaaaaaihcaabaaaaaaaaaaaegacbaaaaaaaaaaaegiccaaa
				aaaaaaaaabaaaaaadgaaaaaficcabaaaaaaaaaaadkaabaaaaaaaaaaadcaaaaaj
				hcaabaaaaaaaaaaaegacbaaaaaaaaaaafgafbaaaabaaaaaaigadbaaaabaaaaaa
				efaaaaajpcaabaaaabaaaaaaegbabaaaaeaaaaaaeghobaaaacaaaaaaaagabaaa
				aaaaaaaaaaaaaaahicaabaaaaaaaaaaadkaabaaaabaaaaaadkaabaaaabaaaaaa
				diaaaaahhccabaaaaaaaaaaapgapbaaaaaaaaaaaegacbaaaaaaaaaaadoaaaaab
				"
			}
			
			SubProgram "gles " {
				Keywords { "DIRECTIONAL_COOKIE" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "DIRECTIONAL_COOKIE" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "DIRECTIONAL_COOKIE" }
				
				"!!GLES3"
			}
		}
	}
	
	Pass {
		Name "PREPASS"
		Tags { "LightMode" = "PrePassBase" }
		Fog {Mode Off}
		
		Program "fp" {
			
			SubProgram "opengl " {
				Keywords { }
				
				Vector 0 [_Color]
				Float 1 [_Shininess]
				Float 2 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				"3.0-!!ARBfp1.0
				# 16 ALU, 2 TEX
				PARAM c[4] = { program.local[0..2],
				{ 2, 1, 0.5 } };
				
				TEMP R0;
				TEMP R1;
				TEX R0.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MAD R1.xy, R0.wyzw, c[3].x, -c[3].y;
				MUL R0.xy, R1, R1;
				ADD_SAT R0.x, R0, R0.y;
				ADD R0.x, -R0, c[3].y;
				RSQ R0.x, R0.x;
				RCP R1.z, R0.x;
				TEX R0.w, fragment.texcoord[0], texture[0], 2D;
				MUL R0.w, R0, c[0];
				SLT R0.w, R0, c[2].x;
				DP3 R0.z, fragment.texcoord[3], -R1;
				DP3 R0.y, -R1, fragment.texcoord[2];
				DP3 R0.x, -R1, fragment.texcoord[1];
				MAD result.color.xyz, R0, c[3].z, c[3].z;
				KIL -R0.w;
				MOV result.color.w, c[1].x;
				END
				# 16 instructions, 2 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { }
				
				Vector 0 [_Color]
				Float 1 [_Shininess]
				Float 2 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				"ps_3_0
				; 15 ALU, 3 TEX
				dcl_2d s0
				dcl_2d s1
				def c3, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c4, 0.50000000, 0, 0, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1.xyz
				dcl_texcoord2 v2.xyz
				dcl_texcoord3 v3.xyz
				texld r0.yw, v0.zwzw, s1
				mad_pp r2.xy, r0.wyzw, c3.z, c3.w
				mul_pp r0.xy, r2, r2
				add_pp_sat r0.x, r0, r0.y
				add_pp r0.y, -r0.x, c3
				rsq_pp r0.y, r0.y
				rcp_pp r2.z, r0.y
				mov_pp r0.x, c2
				texld r0.w, v0, s0
				mad_pp r0.x, r0.w, c0.w, -r0
				cmp r0.x, r0, c3, c3.y
				mov_pp r1, -r0.x
				dp3 r0.z, v3, -r2
				dp3 r0.x, -r2, v1
				dp3 r0.y, -r2, v2
				mad_pp oC0.xyz, r0, c4.x, c4.x
				texkill r1.xyzw
				mov_pp oC0.w, c1.x
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { }
				
				Vector 0 [_Color]
				Float 2 [_Cutoff]
				Float 1 [_Shininess]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				
				"ps_360
				backbbaaaaaaabheaaaaabaaaaaaaaaaaaaaaaceaaaaabbmaaaaabeeaaaaaaaa
				aaaaaaaaaaaaaapeaaaaaabmaaaaaaohppppadaaaaaaaaafaaaaaabmaaaaaaaa
				aaaaaaoaaaaaaaiaaaadaaabaaabaaaaaaaaaaimaaaaaaaaaaaaaajmaaacaaaa
				aaabaaaaaaaaaakeaaaaaaaaaaaaaaleaaacaaacaaabaaaaaaaaaalmaaaaaaaa
				aaaaaammaaadaaaaaaabaaaaaaaaaaimaaaaaaaaaaaaaanfaaacaaabaaabaaaa
				aaaaaalmaaaaaaaafpechfgnhaengbhaaaklklklaaaeaaamaaabaaabaaabaaaa
				aaaaaaaafpedgpgmgphcaaklaaabaaadaaabaaaeaaabaaaaaaaaaaaafpedhfhe
				gpggggaaaaaaaaadaaabaaabaaabaaaaaaaaaaaafpengbgjgofegfhiaafpfdgi
				gjgogjgogfhdhdaahahdfpddfpdaaadccodacodcdadddfddcodaaaklaaaaaaaa
				aaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaeaaaaaaamabaaaaeaaaaaaaaaeaaaaaaaaaaaadeieaaapaaap
				aaaaaacbaaaapafaaaaahbfbaaaahcfcaaaahdfdaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaadpaaaaaalpiaaaaa
				dpiaaaaaeaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaejeaacaaaabcaameaaaaaa
				aaaagaagdaambcaaccaaaaaabaaibaabbpbpphppaaaaeaaamiaiaaababblblgm
				ilabaaacmiaaaaaaaagmblaahjpoabaadibiaaabbpbpppnjaaaaeaaamiadaaae
				aagngmmgilaapppobeiaiaaaaaaaaagmmcaaaaabmjabaaaaaalalagmnbaeaepo
				libaaaaaaaaaaaaamcaaaapokaeaaeaaaaaaaagmocaaaaiamiabaaaaaeloloaa
				paaeabaamiacaaaaaeloloaapaaeacaamiaeaaaaaeloloaapaaeadaamiahiaaa
				aamalblbilaapopoaaaaaaaaaaaaaaaaaaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { }
				
				Vector 0 [_Color]
				Float 1 [_Shininess]
				Float 2 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0003c020000ffff0000000000000848002000000
				[Offsets]
				3
				_Color 1 0
				00000020
				_Shininess 1 0
				000000a0
				_Cutoff 1 0
				00000040
				[Microcode]
				320
				90001700c8011c9dc8000001c8003fe102800240fe001c9dfe020001c8000001
				00000000000000000000000000000000037e4a80c9001c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				940017025c011c9dc8000001c8003fe106820440ce001c9daa02000054020001
				00000000000040000000bf80000000001080014000021c9cc8000001c8000001
				000000000000000000000000000000000280b840c9041c9dc9040001c8000001
				02800340c9001c9f00020000c800000100003f80000000000000000000000000
				08823b4001003c9cc9000001c8000001e8800500c8011c9dc9040003c8003fe1
				c4800500c9041c9fc8010001c8003fe1a2800500c9041c9fc8010001c8003fe1
				0e810440c9001c9d000200000002000000003f00000000000000000000000000
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { }
				
				ConstBuffer "$Globals" 128 
				Vector 48 [_Color] 4
				Float 64 [_Shininess]
				Float 112 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 0
				SetTexture 1 [_BumpMap] 2D 1
				
				"ps_4_0
				eefiecedpjipjoichehhcpohbkddggkiaebmhbacabaaaaaajmadaaaaadaaaaaa
				cmaaaaaammaaaaaaaaabaaaaejfdeheojiaaaaaaafaaaaaaaiaaaaaaiaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaimaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaaimaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				ahahaaaaimaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaaimaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaahahaaaafdfgfpfaepfdejfeejepeoaa
				feeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaa
				aaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklkl
				fdeieefcjeacaaaaeaaaaaaakfaaaaaafjaaaaaeegiocaaaaaaaaaaaaiaaaaaa
				fkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaafibiaaaeaahabaaa
				aaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaaffffaaaagcbaaaadpcbabaaa
				abaaaaaagcbaaaadhcbabaaaacaaaaaagcbaaaadhcbabaaaadaaaaaagcbaaaad
				hcbabaaaaeaaaaaagfaaaaadpccabaaaaaaaaaaagiaaaaacacaaaaaaefaaaaaj
				pcaabaaaaaaaaaaaegbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaaaaaaaaa
				dcaaaaambcaabaaaaaaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaadaaaaaa
				akiacaiaebaaaaaaaaaaaaaaahaaaaaadbaaaaahbcaabaaaaaaaaaaaakaabaaa
				aaaaaaaaabeaaaaaaaaaaaaaanaaaeadakaabaaaaaaaaaaaefaaaaajpcaabaaa
				aaaaaaaaogbkbaaaabaaaaaaeghobaaaabaaaaaaaagabaaaabaaaaaadcaaaaap
				dcaabaaaaaaaaaaahgapbaaaaaaaaaaaaceaaaaaaaaaaaeaaaaaaaeaaaaaaaaa
				aaaaaaaaaceaaaaaaaaaialpaaaaialpaaaaaaaaaaaaaaaaapaaaaahicaabaaa
				aaaaaaaaegaabaaaaaaaaaaaegaabaaaaaaaaaaaddaaaaahicaabaaaaaaaaaaa
				dkaabaaaaaaaaaaaabeaaaaaaaaaiadpaaaaaaaiicaabaaaaaaaaaaadkaabaia
				ebaaaaaaaaaaaaaaabeaaaaaaaaaiadpelaaaaafecaabaaaaaaaaaaadkaabaaa
				aaaaaaaabaaaaaaibcaabaaaabaaaaaaegbcbaaaacaaaaaaegacbaiaebaaaaaa
				aaaaaaaabaaaaaaiccaabaaaabaaaaaaegbcbaaaadaaaaaaegacbaiaebaaaaaa
				aaaaaaaabaaaaaaiecaabaaaabaaaaaaegbcbaaaaeaaaaaaegacbaiaebaaaaaa
				aaaaaaaadcaaaaaphccabaaaaaaaaaaaegacbaaaabaaaaaaaceaaaaaaaaaaadp
				aaaaaadpaaaaaadpaaaaaaaaaceaaaaaaaaaaadpaaaaaadpaaaaaadpaaaaaaaa
				dgaaaaagiccabaaaaaaaaaaaakiacaaaaaaaaaaaaeaaaaaadoaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { }
				
				"!!GLES3"
			}
		}
	}
	
	Pass {
		Name "PREPASS"
		Tags { "LightMode" = "PrePassFinal" }
		
		ZWrite Off
		Program "fp" {
			
			SubProgram "opengl " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				"3.0-!!ARBfp1.0
				# 16 ALU, 2 TEX
				PARAM c[3] = { program.local[0..2] };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TXP R1, fragment.texcoord[1], texture[2], 2D;
				LG2 R0.x, R1.x;
				LG2 R0.z, R1.z;
				LG2 R0.y, R1.y;
				ADD R1.xyz, -R0, fragment.texcoord[2];
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				MUL R0.xyz, R0, c[1];
				LG2 R1.w, R1.w;
				MUL R1.w, -R1, R0.x;
				MUL R0.w, R0, c[1];
				MUL R2.xyz, R1, c[0];
				MUL R2.xyz, R1.w, R2;
				MAD result.color.xyz, R0, R1, R2;
				SLT R0.x, R0.w, c[2];
				MAD result.color.w, R1, c[0], R0;
				KIL -R0.x;
				END
				# 16 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				"ps_3_0
				; 16 ALU, 3 TEX
				dcl_2d s0
				dcl_2d s2
				def c3, 0.00000000, 1.00000000, 0, 0
				dcl_texcoord0 v0.xy
				dcl_texcoord1 v1
				dcl_texcoord2 v2.xyz
				texldp r1, v1, s2
				log_pp r0.x, r1.x
				log_pp r0.z, r1.z
				log_pp r0.y, r1.y
				add_pp r1.xyz, -r0, v2
				texld r0, v0, s0
				mul_pp r0.xyz, r0, c1
				log_pp r1.w, r1.w
				mul_pp r2.w, -r1, r0.x
				mul_pp r2.xyz, r1, c0
				mov_pp r1.w, c2.x
				mul_pp r2.xyz, r2.w, r2
				mad_pp oC0.xyz, r0, r1, r2
				mad_pp r1.w, r0, c1, -r1
				cmp r0.y, r1.w, c3.x, c3
				mul_pp r0.x, r0.w, c1.w
				mov_pp r1, -r0.y
				mad_pp oC0.w, r2, c0, r0.x
				texkill r1.xyzw
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 1 [_Color]
				Float 2 [_Cutoff]
				Vector 0 [_SpecColor]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_LightBuffer] 2D
				
				"ps_360
				backbbaaaaaaabheaaaaabbiaaaaaaaaaaaaaaceaaaaabcaaaaaabeiaaaaaaaa
				aaaaaaaaaaaaaapiaaaaaabmaaaaaaolppppadaaaaaaaaafaaaaaabmaaaaaaaa
				aaaaaaoeaaaaaaiaaaacaaabaaabaaaaaaaaaaiiaaaaaaaaaaaaaajiaaacaaac
				aaabaaaaaaaaaakaaaaaaaaaaaaaaalaaaadaaabaaabaaaaaaaaaamaaaaaaaaa
				aaaaaanaaaadaaaaaaabaaaaaaaaaamaaaaaaaaaaaaaaanjaaacaaaaaaabaaaa
				aaaaaaiiaaaaaaaafpedgpgmgphcaaklaaabaaadaaabaaaeaaabaaaaaaaaaaaa
				fpedhfhegpggggaaaaaaaaadaaabaaabaaabaaaaaaaaaaaafpemgjghgiheechf
				gggggfhcaaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaafpengbgjgofegfhi
				aafpfdhagfgdedgpgmgphcaahahdfpddfpdaaadccodacodcdadddfddcodaaakl
				aaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaeaaaaaaanibaaaadaaaaaaaaaeaaaaaaaaaaaacmgd
				aaahaaahaaaaaacbaaaapafaaaaapbfbaaaahcfcaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaabajfaacaaaabcaameaaaaaa
				aaaagaaheaanbcaaccaaaaaabaaidaabbpbppgiiaaaaeaaaembeaaabaablblbl
				kbadabablmedaaaaabgmlaecmbaaabacmiaaaaaaaagmmgaahjppaaaababiaaab
				bpbppefiaaaaeaaaeabaaaaaaaaaaagmocaaaaiaeaeaaaaaaaaaaamgocaaaaia
				eaiaaaaaaaaaaablocaaaaiaeachaaadaamamalbkbadabiabealaaabaebemagm
				oaaaacadambhaaacabbamalbkbabaaaabealaaabaamabagmobadabacamegaaac
				aambgmgmobacaaadkiibacacacmglbaambaaaaaamiapiaaaaanaaaaaoaabacaa
				aaaaaaaaaaaaaaaaaaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0001c0200007fff8000000000000848002000000
				[Offsets]
				3
				_SpecColor 2 0
				00000120000000f0
				_Color 1 0
				00000020
				_Cutoff 1 0
				00000040
				[Microcode]
				304
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				be021804c8011c9dc8000001c8003fe102801d40c8041c9dc8000001c8000001
				04801d40aa041c9cc8000001c800000108801d4054041c9dc8000001c8000001
				ce800300c8011c9dc9000003c8003fe10e840240f3041c9dc9000001c8000001
				10801d40fe041c9dc8000001c800000110800240ab041c9cc9000003c8000001
				0e800240c9001c9dc8020001c800000100000000000000000000000000000000
				0e800440ff001c9dc9000001c908000110810440c9001c9dc802000101040000
				00000000000000000000000000000000
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				ConstBuffer "$Globals" 144 
				Vector 32 [_SpecColor] 4
				Vector 48 [_Color] 4
				Float 128 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 0
				SetTexture 1 [_LightBuffer] 2D 1
				
				"ps_4_0
				eefiecednfbopeflhdknkjadnncnafebpglibmhmabaaaaaadeadaaaaadaaaaaa
				cmaaaaaaleaaaaaaoiaaaaaaejfdeheoiaaaaaaaaeaaaaaaaiaaaaaagiaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaheaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapadaaaaheaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				apalaaaaheaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaafdfgfpfa
				epfdejfeejepeoaafeeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaa
				aiaaaaaacaaaaaaaaaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfe
				gbhcghgfheaaklklfdeieefceeacaaaaeaaaaaaajbaaaaaafjaaaaaeegiocaaa
				aaaaaaaaajaaaaaafkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaa
				fibiaaaeaahabaaaaaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaaffffaaaa
				gcbaaaaddcbabaaaabaaaaaagcbaaaadlcbabaaaacaaaaaagcbaaaadhcbabaaa
				adaaaaaagfaaaaadpccabaaaaaaaaaaagiaaaaacadaaaaaaefaaaaajpcaabaaa
				aaaaaaaaegbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaaaaaaaaadcaaaaam
				bcaabaaaabaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaadaaaaaaakiacaia
				ebaaaaaaaaaaaaaaaiaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaa
				egiocaaaaaaaaaaaadaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaa
				abeaaaaaaaaaaaaaanaaaeadakaabaaaabaaaaaaaoaaaaahdcaabaaaabaaaaaa
				egbabaaaacaaaaaapgbpbaaaacaaaaaaefaaaaajpcaabaaaabaaaaaaegaabaaa
				abaaaaaaeghobaaaabaaaaaaaagabaaaabaaaaaacpaaaaafpcaabaaaabaaaaaa
				egaobaaaabaaaaaaaaaaaaaihcaabaaaabaaaaaaegacbaiaebaaaaaaabaaaaaa
				egbcbaaaadaaaaaadiaaaaaiicaabaaaabaaaaaaakaabaaaaaaaaaaadkaabaia
				ebaaaaaaabaaaaaadiaaaaaihcaabaaaacaaaaaaegacbaaaabaaaaaaegiccaaa
				aaaaaaaaacaaaaaadiaaaaahhcaabaaaacaaaaaapgapbaaaabaaaaaaegacbaaa
				acaaaaaadcaaaaakiccabaaaaaaaaaaadkaabaaaabaaaaaadkiacaaaaaaaaaaa
				acaaaaaadkaabaaaaaaaaaaadcaaaaajhccabaaaaaaaaaaaegacbaaaaaaaaaaa
				egacbaaaabaaaaaaegacbaaaacaaaaaadoaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Vector 2 [unity_LightmapFade]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"3.0-!!ARBfp1.0
				# 27 ALU, 4 TEX
				PARAM c[5] = { program.local[0..3],
				{ 8 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEX R1, fragment.texcoord[2], texture[3], 2D;
				TEX R0, fragment.texcoord[2], texture[4], 2D;
				MUL R0.xyz, R0.w, R0;
				DP4 R0.w, fragment.texcoord[3], fragment.texcoord[3];
				RSQ R0.w, R0.w;
				RCP R0.w, R0.w;
				MUL R1.xyz, R1.w, R1;
				MUL R0.xyz, R0, c[4].x;
				MAD R2.xyz, R1, c[4].x, -R0;
				TXP R1, fragment.texcoord[1], texture[2], 2D;
				MAD_SAT R0.w, R0, c[2].z, c[2];
				MAD R0.xyz, R0.w, R2, R0;
				LG2 R1.x, R1.x;
				LG2 R1.y, R1.y;
				LG2 R1.z, R1.z;
				ADD R1.xyz, -R1, R0;
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				MUL R0.xyz, R0, c[1];
				LG2 R1.w, R1.w;
				MUL R1.w, -R1, R0.x;
				MUL R0.w, R0, c[1];
				MUL R2.xyz, R1, c[0];
				MUL R2.xyz, R1.w, R2;
				MAD result.color.xyz, R0, R1, R2;
				SLT R0.x, R0.w, c[3];
				MAD result.color.w, R1, c[0], R0;
				KIL -R0.x;
				END
				# 27 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Vector 2 [unity_LightmapFade]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"ps_3_0
				; 25 ALU, 5 TEX
				dcl_2d s0
				dcl_2d s2
				dcl_2d s3
				dcl_2d s4
				def c4, 0.00000000, 1.00000000, 8.00000000, 0
				dcl_texcoord0 v0.xy
				dcl_texcoord1 v1
				dcl_texcoord2 v2.xy
				dcl_texcoord3 v3
				texld r1, v2, s3
				texld r0, v2, s4
				mul_pp r0.xyz, r0.w, r0
				dp4 r0.w, v3, v3
				rsq r0.w, r0.w
				rcp r0.w, r0.w
				mul_pp r1.xyz, r1.w, r1
				mul_pp r0.xyz, r0, c4.z
				mad_pp r2.xyz, r1, c4.z, -r0
				texldp r1, v1, s2
				mad_sat r0.w, r0, c2.z, c2
				mad_pp r0.xyz, r0.w, r2, r0
				log_pp r1.w, r1.w
				log_pp r1.x, r1.x
				log_pp r1.y, r1.y
				log_pp r1.z, r1.z
				add_pp r1.xyz, -r1, r0
				texld r0, v0, s0
				mul_pp r0.xyz, r0, c1
				mul_pp r2.w, -r1, r0.x
				mul_pp r2.xyz, r1, c0
				mov_pp r1.w, c3.x
				mul_pp r2.xyz, r2.w, r2
				mad_pp oC0.xyz, r0, r1, r2
				mad_pp r1.w, r0, c1, -r1
				mul_pp r1.x, r0.w, c1.w
				cmp r0.x, r1.w, c4, c4.y
				mov_pp r0, -r0.x
				mad_pp oC0.w, r2, c0, r1.x
				texkill r0.xyzw
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 1 [_Color]
				Float 3 [_Cutoff]
				Vector 0 [_SpecColor]
				Vector 2 [unity_LightmapFade]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_LightBuffer] 2D
				SetTexture 2 [unity_Lightmap] 2D
				SetTexture 3 [unity_LightmapInd] 2D
				
				"ps_360
				backbbaaaaaaaboiaaaaabgmaaaaaaaaaaaaaaceaaaaabjaaaaaabliaaaaaaaa
				aaaaaaaaaaaaabgiaaaaaabmaaaaabflppppadaaaaaaaaaiaaaaaabmaaaaaaaa
				aaaaabfeaaaaaalmaaacaaabaaabaaaaaaaaaameaaaaaaaaaaaaaaneaaacaaad
				aaabaaaaaaaaaanmaaaaaaaaaaaaaaomaaadaaabaaabaaaaaaaaaapmaaaaaaaa
				aaaaabamaaadaaaaaaabaaaaaaaaaapmaaaaaaaaaaaaabbfaaacaaaaaaabaaaa
				aaaaaameaaaaaaaaaaaaabcaaaadaaacaaabaaaaaaaaaapmaaaaaaaaaaaaabcp
				aaacaaacaaabaaaaaaaaaameaaaaaaaaaaaaabecaaadaaadaaabaaaaaaaaaapm
				aaaaaaaafpedgpgmgphcaaklaaabaaadaaabaaaeaaabaaaaaaaaaaaafpedhfhe
				gpggggaaaaaaaaadaaabaaabaaabaaaaaaaaaaaafpemgjghgiheechfgggggfhc
				aaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaafpengbgjgofegfhiaafpfdha
				gfgdedgpgmgphcaahfgogjhehjfpemgjghgihegngbhaaahfgogjhehjfpemgjgh
				gihegngbhaeggbgegfaahfgogjhehjfpemgjghgihegngbhaejgogeaahahdfpdd
				fpdaaadccodacodcdadddfddcodaaaklaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaa
				aaaaaabeabpmaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeaaaaaabcm
				baaaagaaaaaaaaaeaaaaaaaaaaaadiieaaapaaapaaaaaacbaaaapafaaaaapbfb
				aaaadcfcaaaapdfdaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaebaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaafajgaadbaajbcaabcaaaaabaaaaaaaagaakmeaabcaaaaaa
				aaaagabacabgbcaaccaaaaaabaaigaabbpbppgiiaaaaeaaaembeaaabaablblbl
				kbagabablmedaaaaabgmlaecmbaaabadmiaaaaaaaalbmgaahjppaaaabadifaeb
				bpbppgiiaaaaeaaabacieaebbpbppgiiaaaaeaaababiaaabbpbppefiaaaaeaaa
				eabcaaabaakhkhgmopadadiaeaebaaadaablgmmgkbaeppiaeacbaaabaablgmlb
				kbafppiakachabacaamamalbkbagabibmjaiaaacaalbmgblilabacaceailaaab
				aagmmablobabafiamiahaaadabgmmabaoladaeabmialaaabaamablbaoladacab
				bealaaabacbabegmoaabaaacambhaaadabbamalbkbabaaaabealaaabaamabagm
				obacabadamegaaacaambgmgmobadaaackiibacacacmglbaambaaaaaamiapiaaa
				aanaaaaaoaabacaaaaaaaaaaaaaaaaaaaaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Vector 2 [unity_LightmapFade]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0003c020000ffff4000000000000848004000000
				[Offsets]
				4
				_SpecColor 2 0
				00000220000001e0
				_Color 1 0
				00000020
				unity_LightmapFade 2 0
				00000150000000e0
				_Cutoff 1 0
				00000040
				[Microcode]
				560
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				de021708c8011c9dc8000001c8003fe10e800240fe041c9dc8043001c8000001
				fe040100c8011c9dc8000001c8003fe102020600c8081c9dc8080001c8000001
				02041b00c8041c9dc8000001c8000001be021804c8011c9dc8000001c8003fe1
				02841d40c8041c9dc8000001c800000102063a0054021c9dc8080001c8000001
				0000000000000000000000000000000004841d40aa041c9cc8000001c8000001
				de041706c8011c9dc8000001c8003fe110800140c8081c9dc8003001c8000001
				0e880440ff001c9dc8080001c900000310801d40fe041c9dc8000001c8000001
				10848300000c1c9cc8020001c800000100000000000000000000000000000000
				08020100c8041c9dc8000001c80000010e880440ff081c9dc9100001c9000001
				08841d4054041c9dc8000001c800000110800240ab041c9cc9000003c8000001
				06040100c8081c9dc8000001c80000010e800340c9081c9fc9100001c8000001
				0e840240f3041c9dc9000001c80000010e800240c9001c9dc8020001c8000001
				000000000000000000000000000000000e800440ff001c9dc9000001c9080001
				1e7e7e00c8001c9dc8000001c800000110810440c9001c9dc802000101040000
				00000000000000000000000000000000
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				ConstBuffer "$Globals" 176 
				Vector 32 [_SpecColor] 4
				Vector 48 [_Color] 4
				Vector 128 [unity_LightmapFade] 4
				Float 160 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 0
				SetTexture 1 [_LightBuffer] 2D 1
				SetTexture 2 [unity_Lightmap] 2D 2
				SetTexture 3 [unity_LightmapInd] 2D 3
				
				"ps_4_0
				eefiecedhmoifmoienkgmmjfdlbhigcocmbbdppkabaaaaaaneaeaaaaadaaaaaa
				cmaaaaaammaaaaaaaaabaaaaejfdeheojiaaaaaaafaaaaaaaiaaaaaaiaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaimaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapadaaaaimaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				apalaaaaimaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaadadaaaaimaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaapapaaaafdfgfpfaepfdejfeejepeoaa
				feeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaa
				aaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklkl
				fdeieefcmmadaaaaeaaaaaaapdaaaaaafjaaaaaeegiocaaaaaaaaaaaalaaaaaa
				fkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaafkaaaaadaagabaaa
				acaaaaaafkaaaaadaagabaaaadaaaaaafibiaaaeaahabaaaaaaaaaaaffffaaaa
				fibiaaaeaahabaaaabaaaaaaffffaaaafibiaaaeaahabaaaacaaaaaaffffaaaa
				fibiaaaeaahabaaaadaaaaaaffffaaaagcbaaaaddcbabaaaabaaaaaagcbaaaad
				lcbabaaaacaaaaaagcbaaaaddcbabaaaadaaaaaagcbaaaadpcbabaaaaeaaaaaa
				gfaaaaadpccabaaaaaaaaaaagiaaaaacadaaaaaaefaaaaajpcaabaaaaaaaaaaa
				egbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaaaaaaaaadcaaaaambcaabaaa
				abaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaadaaaaaaakiacaiaebaaaaaa
				aaaaaaaaakaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaaegiocaaa
				aaaaaaaaadaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaa
				aaaaaaaaanaaaeadakaabaaaabaaaaaabbaaaaahbcaabaaaabaaaaaaegbobaaa
				aeaaaaaaegbobaaaaeaaaaaaelaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaa
				dccaaaalbcaabaaaabaaaaaaakaabaaaabaaaaaackiacaaaaaaaaaaaaiaaaaaa
				dkiacaaaaaaaaaaaaiaaaaaaefaaaaajpcaabaaaacaaaaaaegbabaaaadaaaaaa
				eghobaaaadaaaaaaaagabaaaadaaaaaadiaaaaahccaabaaaabaaaaaadkaabaaa
				acaaaaaaabeaaaaaaaaaaaebdiaaaaahocaabaaaabaaaaaaagajbaaaacaaaaaa
				fgafbaaaabaaaaaaefaaaaajpcaabaaaacaaaaaaegbabaaaadaaaaaaeghobaaa
				acaaaaaaaagabaaaacaaaaaadiaaaaahicaabaaaacaaaaaadkaabaaaacaaaaaa
				abeaaaaaaaaaaaebdcaaaaakhcaabaaaacaaaaaapgapbaaaacaaaaaaegacbaaa
				acaaaaaajgahbaiaebaaaaaaabaaaaaadcaaaaajhcaabaaaabaaaaaaagaabaaa
				abaaaaaaegacbaaaacaaaaaajgahbaaaabaaaaaaaoaaaaahdcaabaaaacaaaaaa
				egbabaaaacaaaaaapgbpbaaaacaaaaaaefaaaaajpcaabaaaacaaaaaaegaabaaa
				acaaaaaaeghobaaaabaaaaaaaagabaaaabaaaaaacpaaaaafpcaabaaaacaaaaaa
				egaobaaaacaaaaaaaaaaaaaihcaabaaaabaaaaaaegacbaaaabaaaaaaegacbaia
				ebaaaaaaacaaaaaadiaaaaaiicaabaaaabaaaaaaakaabaaaaaaaaaaadkaabaia
				ebaaaaaaacaaaaaadiaaaaaihcaabaaaacaaaaaaegacbaaaabaaaaaaegiccaaa
				aaaaaaaaacaaaaaadiaaaaahhcaabaaaacaaaaaapgapbaaaabaaaaaaegacbaaa
				acaaaaaadcaaaaakiccabaaaaaaaaaaadkaabaaaabaaaaaadkiacaaaaaaaaaaa
				acaaaaaadkaabaaaaaaaaaaadcaaaaajhccabaaaaaaaaaaaegacbaaaaaaaaaaa
				egacbaaaabaaaaaaegacbaaaacaaaaaadoaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_OFF" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"3.0-!!ARBfp1.0
				# 51 ALU, 5 TEX
				PARAM c[8] = { program.local[0..3],
					{ 2, 1, 8, 0 },
					{ -0.40824828, -0.70710677, 0.57735026, 128 },
					{ -0.40824831, 0.70710677, 0.57735026 },
				{ 0.81649655, 0, 0.57735026 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEX R0, fragment.texcoord[2], texture[4], 2D;
				MUL R0.xyz, R0.w, R0;
				MUL R1.xyz, R0, c[4].z;
				MUL R0.xyz, R1.y, c[6];
				MAD R0.xyz, R1.x, c[7], R0;
				MAD R2.xyz, R1.z, c[5], R0;
				DP3 R0.x, R2, R2;
				RSQ R0.x, R0.x;
				DP3 R1.w, fragment.texcoord[3], fragment.texcoord[3];
				TEX R0.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MUL R2.xyz, R0.x, R2;
				MAD R0.xy, R0.wyzw, c[4].x, -c[4].y;
				MUL R0.zw, R0.xyxy, R0.xyxy;
				ADD_SAT R0.z, R0, R0.w;
				RSQ R1.w, R1.w;
				MAD R2.xyz, R1.w, fragment.texcoord[3], R2;
				DP3 R0.w, R2, R2;
				RSQ R0.w, R0.w;
				ADD R0.z, -R0, c[4].y;
				RSQ R0.z, R0.z;
				MUL R2.xyz, R0.w, R2;
				RCP R0.z, R0.z;
				DP3 R0.w, -R0, R2;
				DP3_SAT R2.z, -R0, c[5];
				DP3_SAT R2.x, -R0, c[7];
				DP3_SAT R2.y, -R0, c[6];
				DP3 R2.y, R2, R1;
				TEX R1, fragment.texcoord[2], texture[3], 2D;
				MUL R0.xyz, R1.w, R1;
				MOV R2.x, c[5].w;
				MUL R0.xyz, R0, R2.y;
				MUL R1.x, R2, c[2];
				MAX R0.w, R0, c[4];
				POW R2.w, R0.w, R1.x;
				TEX R1, fragment.texcoord[0], texture[0], 2D;
				MUL R2.xyz, R0, c[4].z;
				TXP R0, fragment.texcoord[1], texture[2], 2D;
				MUL R1.xyz, R1, c[1];
				MUL R1.w, R1, c[1];
				LG2 R0.x, R0.x;
				LG2 R0.y, R0.y;
				LG2 R0.z, R0.z;
				LG2 R0.w, R0.w;
				ADD R0, -R0, R2;
				MUL R0.w, R0, R1.x;
				MUL R2.xyz, R0, c[0];
				MUL R2.xyz, R0.w, R2;
				MAD result.color.xyz, R0, R1, R2;
				SLT R0.x, R1.w, c[3];
				MAD result.color.w, R0, c[0], R1;
				KIL -R0.x;
				END
				# 51 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"ps_3_0
				; 51 ALU, 6 TEX
				dcl_2d s0
				dcl_2d s1
				dcl_2d s2
				dcl_2d s3
				dcl_2d s4
				def c4, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c5, -0.40824828, -0.70710677, 0.57735026, 8.00000000
				def c6, -0.40824831, 0.70710677, 0.57735026, 128.00000000
				def c7, 0.81649655, 0.00000000, 0.57735026, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1
				dcl_texcoord2 v2.xy
				dcl_texcoord3 v3.xyz
				texld r0, v2, s4
				mul_pp r0.xyz, r0.w, r0
				mul_pp r2.xyz, r0, c5.w
				mul r0.xyz, r2.y, c6
				mad r0.xyz, r2.x, c7, r0
				mad r0.xyz, r2.z, c5, r0
				dp3 r0.w, r0, r0
				rsq r0.w, r0.w
				texld r1.yw, v0.zwzw, s1
				mad_pp r1.xy, r1.wyzw, c4.z, c4.w
				mul r0.xyz, r0.w, r0
				dp3_pp r0.w, v3, v3
				rsq_pp r0.w, r0.w
				mul_pp r1.zw, r1.xyxy, r1.xyxy
				mad_pp r0.xyz, r0.w, v3, r0
				add_pp_sat r0.w, r1.z, r1
				dp3_pp r1.z, r0, r0
				rsq_pp r1.z, r1.z
				add_pp r0.w, -r0, c4.y
				mul_pp r0.xyz, r1.z, r0
				rsq_pp r0.w, r0.w
				rcp_pp r1.z, r0.w
				dp3_pp r0.x, -r1, r0
				mov_pp r0.w, c2.x
				mul_pp r2.w, c6, r0
				max_pp r1.w, r0.x, c4.x
				pow r0, r1.w, r2.w
				dp3_pp_sat r0.z, -r1, c5
				dp3_pp_sat r0.x, -r1, c7
				dp3_pp_sat r0.y, -r1, c6
				dp3_pp r1.x, r0, r2
				texld r3, v2, s3
				mul_pp r0.xyz, r3.w, r3
				mul_pp r0.xyz, r0, r1.x
				texldp r1, v1, s2
				mov r2.w, r0
				mul_pp r2.xyz, r0, c5.w
				texld r0, v0, s0
				mul_pp r0.xyz, r0, c1
				log_pp r1.x, r1.x
				log_pp r1.y, r1.y
				log_pp r1.z, r1.z
				log_pp r1.w, r1.w
				add_pp r1, -r1, r2
				mov_pp r2.w, c3.x
				mul_pp r1.w, r1, r0.x
				mul_pp r2.xyz, r1, c0
				mul_pp r2.xyz, r1.w, r2
				mad_pp oC0.xyz, r1, r0, r2
				mad_pp r2.w, r0, c1, -r2
				mul_pp r1.x, r0.w, c1.w
				cmp r0.x, r2.w, c4, c4.y
				mov_pp r0, -r0.x
				mad_pp oC0.w, r1, c0, r1.x
				texkill r0.xyzw
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 1 [_Color]
				Float 3 [_Cutoff]
				Float 2 [_Shininess]
				Vector 0 [_SpecColor]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				
				"ps_360
				backbbaaaaaaabpmaaaaacfaaaaaaaaaaaaaaaceaaaaabkeaaaaabmmaaaaaaaa
				aaaaaaaaaaaaabhmaaaaaabmaaaaabhappppadaaaaaaaaajaaaaaabmaaaaaaaa
				aaaaabgjaaaaaanaaaadaaabaaabaaaaaaaaaanmaaaaaaaaaaaaaaomaaacaaab
				aaabaaaaaaaaaapeaaaaaaaaaaaaabaeaaacaaadaaabaaaaaaaaabamaaaaaaaa
				aaaaabbmaaadaaacaaabaaaaaaaaaanmaaaaaaaaaaaaabcjaaadaaaaaaabaaaa
				aaaaaanmaaaaaaaaaaaaabdcaaacaaacaaabaaaaaaaaabamaaaaaaaaaaaaabdn
				aaacaaaaaaabaaaaaaaaaapeaaaaaaaaaaaaabeiaaadaaadaaabaaaaaaaaaanm
				aaaaaaaaaaaaabfhaaadaaaeaaabaaaaaaaaaanmaaaaaaaafpechfgnhaengbha
				aaklklklaaaeaaamaaabaaabaaabaaaaaaaaaaaafpedgpgmgphcaaklaaabaaad
				aaabaaaeaaabaaaaaaaaaaaafpedhfhegpggggaaaaaaaaadaaabaaabaaabaaaa
				aaaaaaaafpemgjghgiheechfgggggfhcaafpengbgjgofegfhiaafpfdgigjgogj
				gogfhdhdaafpfdhagfgdedgpgmgphcaahfgogjhehjfpemgjghgihegngbhaaahf
				gogjhehjfpemgjghgihegngbhaejgogeaahahdfpddfpdaaadccodacodcdadddf
				ddcodaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeaaaaaacbabaaaahaaaaaaaaaeaaaaaaaa
				aaaadeieaaapaaapaaaaaacbaaaapafaaaaapbfbaaaadcfcaaaahdfddpiaaaaa
				edaaaaaaaaaaaaaaaaaaaaaaeaaaaaaaebaaaaaaaaaaaaaalpiaaaaadpbdmndk
				lonbafomdpdfaepddpfbafollonbafollpdfaepddpbdmndkdpfbafolaeajgaae
				daakbcaabcaaaabfaaaaaaaagaanmeaabcaaaaaaaaaagabdgabjbcaabcaaaaaa
				aaaagabpgacfbcaaccaaaaaabaaieaabbpbppgiiaaaaeaaaemeiacacaalolobl
				paadadabmiapaaaeaaaaaaaakbaeabaaliedabababmglaehmbacabadmiaaaaaa
				aamgmgaahjpnabaabacifacbbpbppgiiaaaaeaaabadihaebbpbppgiiaaaaeaaa
				dibiaaabbpbpppnjaaaaeaaabaeigaebbpbppgiiaaaaeaaamiabaaabaagmlbaa
				cbacpmaamiagaaacaagbgmblilaapnpnbebcaaaaaabllbblkbahpnagkiboaaab
				aalbpmiambaaahpnmjacaaaaaamfmfmgnbacacpnfibnacaaaagmonblobaaagic
				kiehadagaagmmamambacadpolicpaaahaaeogdebibaapopmkabkacadaammbblb
				oaahahiamjabaaadaegnmhmgjbacpppnmiahaaahaablmabfklaappadmiacaaaa
				aaloloaapaahahaafjccaaadaemamalblaacpoiamiahaaagaamalbmaolahaaag
				miacaaaaaaloloaapaagagaafjceaaadaemalolblaacppiaeachaaagaamalbbl
				obagaaifeabcacacaclomagmpaagacifeaceacacaalbmglbkcacpnifeabeaaaa
				aaghlomgpaaaadiceaepacabaaffegmgobabaaifdibhaaabacmamabloaabacab
				miabaaaaacgmlbaaoaaaaaaamiaiaaabaagmgmaaobaeaaaamiapaaacaacfcfaa
				kbabaaaamiaiiaaaaablblaaoaaeacaamiaiaaaaaamggmaaobacaeaamiagaaaa
				aalmblaaobacabaamiabaaaaaablgmaaobaaaaaamiahiaaaaamamamaolaeabaa
				aaaaaaaaaaaaaaaaaaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_OFF" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0003c020000ffff4000000000000848004000000
				[Offsets]
				4
				_SpecColor 2 0
				000003a000000370
				_Color 1 0
				00000020
				_Shininess 1 0
				000002c0
				_Cutoff 1 0
				00000040
				[Microcode]
				944
				9e001700c8011c9dc8000001c8003fe11e84024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9081c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				de001708c8011c9dc8000001c8003fe1ee8a3940c8011c9dc8000029c800bfe1
				0e880240fe001c9dc8003001c8000001940017025c011c9dc8000001c8003fe1
				06860440ce001c9d00020000aa020000000040000000bf800000000000000000
				0e000200ab101c9cc8020001c800000105ecbed104f33f35cd3a3f1300000000
				0e00040001101c9cc8020001c800000105eb3f5100000000cd3a3f1300000000
				0882b840c90c1c9dc90c0001c80000011082034055041c9f00020000c8000001
				00003f800000000000000000000000000e00040055101c9df2020001c8000001
				0000000005ebbed104f3bf35cd3a3f1308863b40ff043c9dff040001c8000001
				10000500c8001c9dc8000001c80000010e803b00c8001c9dfe000001c8000001
				0e8c0340c9001c9dc9140001c8000001be001804c8011c9dc8000001c8003fe1
				02801d40c8001c9dc8000001c8000001088a8540c90c1c9fc8020001c8000001
				05ebbed104f3bf35cd3a3f1300000000028ab840050c1c9e08020000c8000001
				cd3a3f1305eb3f510000000000000000048a8540c90c1c9fc8020001c8000001
				05ecbed104f33f35cd3a3f13000000000e8c3940c9181c9dc8000029c8000001
				04801d40aa001c9cc8000001c8000001108c0540c9141c9dc9100001c8000001
				08000100c8001c9dc8000001c8000001de041706c8011c9dc8000001c8003fe1
				08801d4054001c9dc8000001c800000102820540c90c1c9fc9180001c8000001
				10801d40fe001c9dc8000001c800000102060900c9041c9d00020000c8000001
				000000000000000000000000000000001082014000021c9cc8000001c8000001
				00000000000000000000000000000000028e0240ff041c9d00020000c8000001
				0000430000000000000000000000000002061d00c80c1c9dc8000001c8000001
				10020200000c1c9c011c0000c800000102820240fe081c9dff180001c8000001
				0e82024001041c9cc8083001c800000110821c00fe041c9dc8000001c8000001
				1e800340c9001c9fc9040001c80000011e820240cb081c9d27000001c8000001
				0e800240c9001c9dc8020001c800000100000000000000000000000000000000
				0e80044001041c9cc9000001f30400011081044001041c9cc802000101080000
				00000000000000000000000000000000
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_OFF" }
				
				ConstBuffer "$Globals" 176 
				Vector 32 [_SpecColor] 4
				Vector 48 [_Color] 4
				Float 64 [_Shininess]
				Float 160 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 0
				SetTexture 1 [_BumpMap] 2D 1
				SetTexture 2 [_LightBuffer] 2D 2
				SetTexture 3 [unity_Lightmap] 2D 3
				SetTexture 4 [unity_LightmapInd] 2D 4
				
				"ps_4_0
				eefiecedffnapfokafjekkmekhfhlfpfmbbbpkcpabaaaaaaoaahaaaaadaaaaaa
				cmaaaaaammaaaaaaaaabaaaaejfdeheojiaaaaaaafaaaaaaaiaaaaaaiaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaimaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaaimaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				apalaaaaimaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaadadaaaaimaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaahahaaaafdfgfpfaepfdejfeejepeoaa
				feeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaa
				aaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklkl
				fdeieefcniagaaaaeaaaaaaalgabaaaafjaaaaaeegiocaaaaaaaaaaaalaaaaaa
				fkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaafkaaaaadaagabaaa
				acaaaaaafkaaaaadaagabaaaadaaaaaafkaaaaadaagabaaaaeaaaaaafibiaaae
				aahabaaaaaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaaffffaaaafibiaaae
				aahabaaaacaaaaaaffffaaaafibiaaaeaahabaaaadaaaaaaffffaaaafibiaaae
				aahabaaaaeaaaaaaffffaaaagcbaaaadpcbabaaaabaaaaaagcbaaaadlcbabaaa
				acaaaaaagcbaaaaddcbabaaaadaaaaaagcbaaaadhcbabaaaaeaaaaaagfaaaaad
				pccabaaaaaaaaaaagiaaaaacagaaaaaaefaaaaajpcaabaaaaaaaaaaaegbabaaa
				abaaaaaaeghobaaaaaaaaaaaaagabaaaaaaaaaaadcaaaaambcaabaaaabaaaaaa
				dkaabaaaaaaaaaaadkiacaaaaaaaaaaaadaaaaaaakiacaiaebaaaaaaaaaaaaaa
				akaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaaegiocaaaaaaaaaaa
				adaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaaaaaaaaaa
				anaaaeadakaabaaaabaaaaaaaoaaaaahdcaabaaaabaaaaaaegbabaaaacaaaaaa
				pgbpbaaaacaaaaaaefaaaaajpcaabaaaabaaaaaaegaabaaaabaaaaaaeghobaaa
				acaaaaaaaagabaaaacaaaaaacpaaaaafpcaabaaaabaaaaaadgajbaaaabaaaaaa
				baaaaaahbcaabaaaacaaaaaaegbcbaaaaeaaaaaaegbcbaaaaeaaaaaaeeaaaaaf
				bcaabaaaacaaaaaaakaabaaaacaaaaaadiaaaaahhcaabaaaacaaaaaaagaabaaa
				acaaaaaaegbcbaaaaeaaaaaaefaaaaajpcaabaaaadaaaaaaegbabaaaadaaaaaa
				eghobaaaaeaaaaaaaagabaaaaeaaaaaadiaaaaahicaabaaaacaaaaaadkaabaaa
				adaaaaaaabeaaaaaaaaaaaebdiaaaaahhcaabaaaadaaaaaaegacbaaaadaaaaaa
				pgapbaaaacaaaaaadiaaaaakhcaabaaaaeaaaaaafgafbaaaadaaaaaaaceaaaaa
				omafnblopdaedfdpdkmnbddpaaaaaaaadcaaaaamhcaabaaaaeaaaaaaagaabaaa
				adaaaaaaaceaaaaaolaffbdpaaaaaaaadkmnbddpaaaaaaaaegacbaaaaeaaaaaa
				dcaaaaamhcaabaaaaeaaaaaakgakbaaaadaaaaaaaceaaaaaolafnblopdaedflp
				dkmnbddpaaaaaaaaegacbaaaaeaaaaaabaaaaaahicaabaaaacaaaaaaegacbaaa
				aeaaaaaaegacbaaaaeaaaaaaeeaaaaaficaabaaaacaaaaaadkaabaaaacaaaaaa
				dcaaaaajhcaabaaaacaaaaaaegacbaaaaeaaaaaapgapbaaaacaaaaaaegacbaaa
				acaaaaaabaaaaaahicaabaaaacaaaaaaegacbaaaacaaaaaaegacbaaaacaaaaaa
				eeaaaaaficaabaaaacaaaaaadkaabaaaacaaaaaadiaaaaahhcaabaaaacaaaaaa
				pgapbaaaacaaaaaaegacbaaaacaaaaaaefaaaaajpcaabaaaaeaaaaaaogbkbaaa
				abaaaaaaeghobaaaabaaaaaaaagabaaaabaaaaaadcaaaaapdcaabaaaaeaaaaaa
				hgapbaaaaeaaaaaaaceaaaaaaaaaaaeaaaaaaaeaaaaaaaaaaaaaaaaaaceaaaaa
				aaaaialpaaaaialpaaaaaaaaaaaaaaaaapaaaaahicaabaaaacaaaaaaegaabaaa
				aeaaaaaaegaabaaaaeaaaaaaddaaaaahicaabaaaacaaaaaadkaabaaaacaaaaaa
				abeaaaaaaaaaiadpaaaaaaaiicaabaaaacaaaaaadkaabaiaebaaaaaaacaaaaaa
				abeaaaaaaaaaiadpelaaaaafecaabaaaaeaaaaaadkaabaaaacaaaaaabaaaaaai
				bcaabaaaacaaaaaaegacbaiaebaaaaaaaeaaaaaaegacbaaaacaaaaaadeaaaaah
				bcaabaaaacaaaaaaakaabaaaacaaaaaaabeaaaaaaaaaaaaacpaaaaafbcaabaaa
				acaaaaaaakaabaaaacaaaaaadiaaaaaiccaabaaaacaaaaaaakiacaaaaaaaaaaa
				aeaaaaaaabeaaaaaaaaaaaeddiaaaaahbcaabaaaacaaaaaaakaabaaaacaaaaaa
				bkaabaaaacaaaaaabjaaaaafbcaabaaaacaaaaaaakaabaaaacaaaaaaapcaaaal
				bcaabaaaafaaaaaaaceaaaaaolaffbdpdkmnbddpaaaaaaaaaaaaaaaaigaabaia
				ebaaaaaaaeaaaaaabacaaaalccaabaaaafaaaaaaaceaaaaaomafnblopdaedfdp
				dkmnbddpaaaaaaaaegacbaiaebaaaaaaaeaaaaaabacaaaalecaabaaaafaaaaaa
				aceaaaaaolafnblopdaedflpdkmnbddpaaaaaaaaegacbaiaebaaaaaaaeaaaaaa
				baaaaaahbcaabaaaadaaaaaaegacbaaaafaaaaaaegacbaaaadaaaaaaefaaaaaj
				pcaabaaaaeaaaaaaegbabaaaadaaaaaaeghobaaaadaaaaaaaagabaaaadaaaaaa
				diaaaaahccaabaaaadaaaaaadkaabaaaaeaaaaaaabeaaaaaaaaaaaebdiaaaaah
				ocaabaaaadaaaaaaagajbaaaaeaaaaaafgafbaaaadaaaaaadiaaaaahocaabaaa
				acaaaaaaagaabaaaadaaaaaafgaobaaaadaaaaaaaaaaaaaipcaabaaaabaaaaaa
				egaobaiaebaaaaaaabaaaaaaegaobaaaacaaaaaadiaaaaahpcaabaaaacaaaaaa
				agajbaaaaaaaaaaaegaobaaaabaaaaaadiaaaaaihcaabaaaaaaaaaaajgahbaaa
				abaaaaaaegiccaaaaaaaaaaaacaaaaaadcaaaaajhccabaaaaaaaaaaaegacbaaa
				aaaaaaaaagaabaaaacaaaaaajgahbaaaacaaaaaadcaaaaakiccabaaaaaaaaaaa
				akaabaaaacaaaaaadkiacaaaaaaaaaaaacaaaaaadkaabaaaaaaaaaaadoaaaaab
				"
			}
			
			SubProgram "gles " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_OFF" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_OFF" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				"3.0-!!ARBfp1.0
				# 12 ALU, 2 TEX
				PARAM c[3] = { program.local[0..2] };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				TXP R1, fragment.texcoord[1], texture[2], 2D;
				MUL R0.xyz, R0, c[1];
				ADD R1.xyz, R1, fragment.texcoord[2];
				MUL R1.w, R1, R0.x;
				MUL R0.w, R0, c[1];
				MUL R2.xyz, R1, c[0];
				MUL R2.xyz, R1.w, R2;
				MAD result.color.xyz, R0, R1, R2;
				SLT R0.x, R0.w, c[2];
				MAD result.color.w, R1, c[0], R0;
				KIL -R0.x;
				END
				# 12 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				"ps_3_0
				; 12 ALU, 3 TEX
				dcl_2d s0
				dcl_2d s2
				def c3, 0.00000000, 1.00000000, 0, 0
				dcl_texcoord0 v0.xy
				dcl_texcoord1 v1
				dcl_texcoord2 v2.xyz
				texld r0, v0, s0
				texldp r1, v1, s2
				mul_pp r0.xyz, r0, c1
				mul_pp r2.w, r1, r0.x
				add_pp r1.xyz, r1, v2
				mul_pp r2.xyz, r1, c0
				mov_pp r1.w, c2.x
				mul_pp r2.xyz, r2.w, r2
				mad_pp oC0.xyz, r0, r1, r2
				mad_pp r1.w, r0, c1, -r1
				cmp r0.y, r1.w, c3.x, c3
				mul_pp r0.x, r0.w, c1.w
				mov_pp r1, -r0.y
				mad_pp oC0.w, r2, c0, r0.x
				texkill r1.xyzw
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 1 [_Color]
				Float 2 [_Cutoff]
				Vector 0 [_SpecColor]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_LightBuffer] 2D
				SetTexture 2 [_LightSpecBuffer] 2D
				
				"ps_360
				backbbaaaaaaabjiaaaaabamaaaaaaaaaaaaaaceaaaaabeeaaaaabgmaaaaaaaa
				aaaaaaaaaaaaabbmaaaaaabmaaaaabbappppadaaaaaaaaagaaaaaabmaaaaaaaa
				aaaaabajaaaaaajeaaacaaabaaabaaaaaaaaaajmaaaaaaaaaaaaaakmaaacaaac
				aaabaaaaaaaaaaleaaaaaaaaaaaaaameaaadaaabaaabaaaaaaaaaaneaaaaaaaa
				aaaaaaoeaaadaaacaaabaaaaaaaaaaneaaaaaaaaaaaaaapfaaadaaaaaaabaaaa
				aaaaaaneaaaaaaaaaaaaaapoaaacaaaaaaabaaaaaaaaaajmaaaaaaaafpedgpgm
				gphcaaklaaabaaadaaabaaaeaaabaaaaaaaaaaaafpedhfhegpggggaaaaaaaaad
				aaabaaabaaabaaaaaaaaaaaafpemgjghgiheechfgggggfhcaaklklklaaaeaaam
				aaabaaabaaabaaaaaaaaaaaafpemgjghgihefdhagfgdechfgggggfhcaafpengb
				gjgofegfhiaafpfdhagfgdedgpgmgphcaahahdfpddfpdaaadccodacodcdadddf
				ddcodaaaaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabeabpmaabaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeaaaaaaammbaaaadaaaaaaaaaeaaaaaaaa
				aaaacmgdaaahaaahaaaaaacbaaaapafaaaaapbfbaaaahcfcaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaafajgaacaaaabcaa
				meaaaaaaaaaagaaicaaobcaaccaaaaaabaaiaaabbpbppgiiaaaaeaaaembpaaad
				aaaaaablkbaaabablmbgaaaaabgmlmedobaaabacmiaaaaaaaagmgmaahjppaaaa
				geciaaabbpbppppiaaaaeaaagebiaaabbpbppeehaaaaeaaamiahaaabaabfmaaa
				oaaaacaamiaiaaabaagmgmaaobadaaaamiapaaacaacfcfaakbabaaaamiaiiaaa
				aablblaaoaadacaamiaiaaaaaamggmaaobacadaamiagaaaaaalmblaaobacabaa
				miabaaaaaablgmaaobaaaaaamiahiaaaaamamamaoladabaaaaaaaaaaaaaaaaaa
				aaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0001c0200007fff8000000000000848002000000
				[Offsets]
				3
				_SpecColor 2 0
				000000e0000000b0
				_Color 1 0
				00000020
				_Cutoff 1 0
				00000040
				[Microcode]
				240
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				be021804c8011c9dc8000001c8003fe110800240ab041c9cc8040001c8000001
				ce800300c8011c9dc8040001c8003fe10e840240f3041c9dc9000001c8000001
				0e800240c9001c9dc8020001c800000100000000000000000000000000000000
				0e800440ff001c9dc9000001c908000110810440c9001c9dc802000101040000
				00000000000000000000000000000000
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				ConstBuffer "$Globals" 144 
				Vector 32 [_SpecColor] 4
				Vector 48 [_Color] 4
				Float 128 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 0
				SetTexture 1 [_LightBuffer] 2D 1
				
				"ps_4_0
				eefiecedfjjdkmncpibdnnhadkfknfiadpnlkffaabaaaaaabiadaaaaadaaaaaa
				cmaaaaaaleaaaaaaoiaaaaaaejfdeheoiaaaaaaaaeaaaaaaaiaaaaaagiaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaheaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapadaaaaheaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				apalaaaaheaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaahahaaaafdfgfpfa
				epfdejfeejepeoaafeeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaa
				aiaaaaaacaaaaaaaaaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfe
				gbhcghgfheaaklklfdeieefcciacaaaaeaaaaaaaikaaaaaafjaaaaaeegiocaaa
				aaaaaaaaajaaaaaafkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaa
				fibiaaaeaahabaaaaaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaaffffaaaa
				gcbaaaaddcbabaaaabaaaaaagcbaaaadlcbabaaaacaaaaaagcbaaaadhcbabaaa
				adaaaaaagfaaaaadpccabaaaaaaaaaaagiaaaaacadaaaaaaefaaaaajpcaabaaa
				aaaaaaaaegbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaaaaaaaaadcaaaaam
				bcaabaaaabaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaadaaaaaaakiacaia
				ebaaaaaaaaaaaaaaaiaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaa
				egiocaaaaaaaaaaaadaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaa
				abeaaaaaaaaaaaaaanaaaeadakaabaaaabaaaaaaaoaaaaahdcaabaaaabaaaaaa
				egbabaaaacaaaaaapgbpbaaaacaaaaaaefaaaaajpcaabaaaabaaaaaaegaabaaa
				abaaaaaaeghobaaaabaaaaaaaagabaaaabaaaaaaaaaaaaahhcaabaaaabaaaaaa
				egacbaaaabaaaaaaegbcbaaaadaaaaaadiaaaaahicaabaaaabaaaaaaakaabaaa
				aaaaaaaadkaabaaaabaaaaaadiaaaaaihcaabaaaacaaaaaaegacbaaaabaaaaaa
				egiccaaaaaaaaaaaacaaaaaadiaaaaahhcaabaaaacaaaaaapgapbaaaabaaaaaa
				egacbaaaacaaaaaadcaaaaakiccabaaaaaaaaaaadkaabaaaabaaaaaadkiacaaa
				aaaaaaaaacaaaaaadkaabaaaaaaaaaaadcaaaaajhccabaaaaaaaaaaaegacbaaa
				aaaaaaaaegacbaaaabaaaaaaegacbaaaacaaaaaadoaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "LIGHTMAP_OFF" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Vector 2 [unity_LightmapFade]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"3.0-!!ARBfp1.0
				# 23 ALU, 4 TEX
				PARAM c[5] = { program.local[0..3],
				{ 8 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEX R0, fragment.texcoord[2], texture[3], 2D;
				MUL R1.xyz, R0.w, R0;
				TEX R0, fragment.texcoord[2], texture[4], 2D;
				MUL R0.xyz, R0.w, R0;
				MUL R0.xyz, R0, c[4].x;
				DP4 R1.w, fragment.texcoord[3], fragment.texcoord[3];
				RSQ R0.w, R1.w;
				RCP R0.w, R0.w;
				MAD R1.xyz, R1, c[4].x, -R0;
				MAD_SAT R0.w, R0, c[2].z, c[2];
				MAD R2.xyz, R0.w, R1, R0;
				TEX R0, fragment.texcoord[0], texture[0], 2D;
				TXP R1, fragment.texcoord[1], texture[2], 2D;
				ADD R1.xyz, R1, R2;
				MUL R0.xyz, R0, c[1];
				MUL R1.w, R1, R0.x;
				MUL R0.w, R0, c[1];
				MUL R2.xyz, R1, c[0];
				MUL R2.xyz, R1.w, R2;
				MAD result.color.xyz, R0, R1, R2;
				SLT R0.x, R0.w, c[3];
				MAD result.color.w, R1, c[0], R0;
				KIL -R0.x;
				END
				# 23 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Vector 2 [unity_LightmapFade]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"ps_3_0
				; 21 ALU, 5 TEX
				dcl_2d s0
				dcl_2d s2
				dcl_2d s3
				dcl_2d s4
				def c4, 0.00000000, 1.00000000, 8.00000000, 0
				dcl_texcoord0 v0.xy
				dcl_texcoord1 v1
				dcl_texcoord2 v2.xy
				dcl_texcoord3 v3
				texld r0, v2, s3
				mul_pp r1.xyz, r0.w, r0
				texld r0, v2, s4
				mul_pp r0.xyz, r0.w, r0
				mul_pp r0.xyz, r0, c4.z
				dp4 r1.w, v3, v3
				rsq r0.w, r1.w
				rcp r0.w, r0.w
				mad_pp r1.xyz, r1, c4.z, -r0
				mad_sat r0.w, r0, c2.z, c2
				mad_pp r2.xyz, r0.w, r1, r0
				texld r0, v0, s0
				texldp r1, v1, s2
				add_pp r1.xyz, r1, r2
				mul_pp r0.xyz, r0, c1
				mul_pp r2.w, r1, r0.x
				mul_pp r2.xyz, r1, c0
				mov_pp r1.w, c3.x
				mul_pp r2.xyz, r2.w, r2
				mad_pp oC0.xyz, r0, r1, r2
				mad_pp r1.w, r0, c1, -r1
				mul_pp r1.x, r0.w, c1.w
				cmp r0.x, r1.w, c4, c4.y
				mov_pp r0, -r0.x
				mad_pp oC0.w, r2, c0, r1.x
				texkill r0.xyzw
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 1 [_Color]
				Float 3 [_Cutoff]
				Vector 0 [_SpecColor]
				Vector 2 [unity_LightmapFade]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_LightBuffer] 2D
				SetTexture 2 [_LightSpecBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				
				"ps_360
				backbbaaaaaaacamaaaaabhiaaaaaaaaaaaaaaceaaaaableaaaaabnmaaaaaaaa
				aaaaaaaaaaaaabimaaaaaabmaaaaabiappppadaaaaaaaaajaaaaaabmaaaaaaaa
				aaaaabhjaaaaaanaaaacaaabaaabaaaaaaaaaaniaaaaaaaaaaaaaaoiaaacaaad
				aaabaaaaaaaaaapaaaaaaaaaaaaaabaaaaadaaabaaabaaaaaaaaabbaaaaaaaaa
				aaaaabcaaaadaaacaaabaaaaaaaaabbaaaaaaaaaaaaaabdbaaadaaaaaaabaaaa
				aaaaabbaaaaaaaaaaaaaabdkaaacaaaaaaabaaaaaaaaaaniaaaaaaaaaaaaabef
				aaadaaadaaabaaaaaaaaabbaaaaaaaaaaaaaabfeaaacaaacaaabaaaaaaaaaani
				aaaaaaaaaaaaabghaaadaaaeaaabaaaaaaaaabbaaaaaaaaafpedgpgmgphcaakl
				aaabaaadaaabaaaeaaabaaaaaaaaaaaafpedhfhegpggggaaaaaaaaadaaabaaab
				aaabaaaaaaaaaaaafpemgjghgiheechfgggggfhcaaklklklaaaeaaamaaabaaab
				aaabaaaaaaaaaaaafpemgjghgihefdhagfgdechfgggggfhcaafpengbgjgofegf
				hiaafpfdhagfgdedgpgmgphcaahfgogjhehjfpemgjghgihegngbhaaahfgogjhe
				hjfpemgjghgihegngbhaeggbgegfaahfgogjhehjfpemgjghgihegngbhaejgoge
				aahahdfpddfpdaaadccodacodcdadddfddcodaaaaaaaaaaaaaaaaaabaaaaaaaa
				aaaaaaaaaaaaaabeabpmaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaea
				aaaaabdibaaaaeaaaaaaaaaeaaaaaaaaaaaadiieaaapaaapaaaaaacbaaaapafa
				aaaapbfbaaaadcfcaaaapdfdaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaebaaaaaa
				aaaaaaaaaaaaaaaaaaaaaaaaaeajgaaddaajbcaabcaaaabfaaaaaaaagaammeaa
				bcaaaaaaaaaagabcbabibcaaccaaaaaabaaiaaabbpbppgiiaaaaeaaaemeeacae
				aakhkhblopadadabmiapaaadaaaaaaaakbaaabaalmbdaaababmglaedobacabad
				miaaaaaaaalbgmaahjppaaaababiaacbbpbppeehaaaaeaaabaciaacbbpbppppi
				aaaaeaaabaeibaebbpbppgiiaaaaeaaabadicaebbpbppgiiaaaaeaaakibaaeaa
				aaaaaaedocaaaappkaecaeaeaablgmmgkbabppiemjaiaaabaamgmgblilaeacac
				beahaaabaalbmagmobaeabadmiahaaacabgmmamaolaeacabmiahaaabaamablma
				olacababamihababaamabfgmoaabaaaamiapaaacaacfcfaakbabaaaamiaiiaaa
				aablblaaoaadacaamiaiaaaaaamggmaaobacadaamiagaaaaaalmblaaobacabaa
				miabaaaaaablgmaaobaaaaaamiahiaaaaamamamaoladabaaaaaaaaaaaaaaaaaa
				aaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Vector 2 [unity_LightmapFade]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0003c020000ffff4000000000000848003000000
				[Offsets]
				4
				_SpecColor 2 0
				000001c000000180
				_Color 1 0
				00000020
				unity_LightmapFade 2 0
				00000110000000f0
				_Cutoff 1 0
				00000040
				[Microcode]
				464
				9e001700c8011c9dc8000001c8003fe11e82024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9041c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				fe020100c8011c9dc8000001c8003fe102000600c8041c9dc8040001c8000001
				de041706c8011c9dc8000001c8003fe110800140c8081c9dc8003001c8000001
				10041b00c8001c9dc8000001c8000001de021708c8011c9dc8000001c8003fe1
				0e800240fe041c9dc8043001c80000010e880440ff001c9dc8080001c9000003
				10023a0054021c9dfe080001c800000100000000000000000000000000000000
				10888300c8041c9dc8020001c800000100000000000000000000000000000000
				0e800440ff101c9dc9100001c9000001be021804c8011c9dc8000001c8003fe1
				0e800340c8041c9dc9000001c800000110800240ab041c9cc8040001c8000001
				0e840240f3041c9dc9000001c80000010e800240c9001c9dc8020001c8000001
				000000000000000000000000000000000e800440ff001c9dc9000001c9080001
				1e7e7e00c8001c9dc8000001c800000110810440c9001c9dc802000101040000
				00000000000000000000000000000000
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				ConstBuffer "$Globals" 176 
				Vector 32 [_SpecColor] 4
				Vector 48 [_Color] 4
				Vector 128 [unity_LightmapFade] 4
				Float 160 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 0
				SetTexture 1 [_LightBuffer] 2D 1
				SetTexture 2 [unity_Lightmap] 2D 2
				SetTexture 3 [unity_LightmapInd] 2D 3
				
				"ps_4_0
				eefiecedjlihoacdameekkfpckoblekclpgfgdjhabaaaaaaliaeaaaaadaaaaaa
				cmaaaaaammaaaaaaaaabaaaaejfdeheojiaaaaaaafaaaaaaaiaaaaaaiaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaimaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapadaaaaimaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				apalaaaaimaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaadadaaaaimaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaapapaaaafdfgfpfaepfdejfeejepeoaa
				feeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaa
				aaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklkl
				fdeieefclaadaaaaeaaaaaaaomaaaaaafjaaaaaeegiocaaaaaaaaaaaalaaaaaa
				fkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaafkaaaaadaagabaaa
				acaaaaaafkaaaaadaagabaaaadaaaaaafibiaaaeaahabaaaaaaaaaaaffffaaaa
				fibiaaaeaahabaaaabaaaaaaffffaaaafibiaaaeaahabaaaacaaaaaaffffaaaa
				fibiaaaeaahabaaaadaaaaaaffffaaaagcbaaaaddcbabaaaabaaaaaagcbaaaad
				lcbabaaaacaaaaaagcbaaaaddcbabaaaadaaaaaagcbaaaadpcbabaaaaeaaaaaa
				gfaaaaadpccabaaaaaaaaaaagiaaaaacadaaaaaaefaaaaajpcaabaaaaaaaaaaa
				egbabaaaabaaaaaaeghobaaaaaaaaaaaaagabaaaaaaaaaaadcaaaaambcaabaaa
				abaaaaaadkaabaaaaaaaaaaadkiacaaaaaaaaaaaadaaaaaaakiacaiaebaaaaaa
				aaaaaaaaakaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaaegiocaaa
				aaaaaaaaadaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaa
				aaaaaaaaanaaaeadakaabaaaabaaaaaabbaaaaahbcaabaaaabaaaaaaegbobaaa
				aeaaaaaaegbobaaaaeaaaaaaelaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaa
				dccaaaalbcaabaaaabaaaaaaakaabaaaabaaaaaackiacaaaaaaaaaaaaiaaaaaa
				dkiacaaaaaaaaaaaaiaaaaaaefaaaaajpcaabaaaacaaaaaaegbabaaaadaaaaaa
				eghobaaaadaaaaaaaagabaaaadaaaaaadiaaaaahccaabaaaabaaaaaadkaabaaa
				acaaaaaaabeaaaaaaaaaaaebdiaaaaahocaabaaaabaaaaaaagajbaaaacaaaaaa
				fgafbaaaabaaaaaaefaaaaajpcaabaaaacaaaaaaegbabaaaadaaaaaaeghobaaa
				acaaaaaaaagabaaaacaaaaaadiaaaaahicaabaaaacaaaaaadkaabaaaacaaaaaa
				abeaaaaaaaaaaaebdcaaaaakhcaabaaaacaaaaaapgapbaaaacaaaaaaegacbaaa
				acaaaaaajgahbaiaebaaaaaaabaaaaaadcaaaaajhcaabaaaabaaaaaaagaabaaa
				abaaaaaaegacbaaaacaaaaaajgahbaaaabaaaaaaaoaaaaahdcaabaaaacaaaaaa
				egbabaaaacaaaaaapgbpbaaaacaaaaaaefaaaaajpcaabaaaacaaaaaaegaabaaa
				acaaaaaaeghobaaaabaaaaaaaagabaaaabaaaaaaaaaaaaahhcaabaaaabaaaaaa
				egacbaaaabaaaaaaegacbaaaacaaaaaadiaaaaahicaabaaaabaaaaaaakaabaaa
				aaaaaaaadkaabaaaacaaaaaadiaaaaaihcaabaaaacaaaaaaegacbaaaabaaaaaa
				egiccaaaaaaaaaaaacaaaaaadiaaaaahhcaabaaaacaaaaaapgapbaaaabaaaaaa
				egacbaaaacaaaaaadcaaaaakiccabaaaaaaaaaaadkaabaaaabaaaaaadkiacaaa
				aaaaaaaaacaaaaaadkaabaaaaaaaaaaadcaaaaajhccabaaaaaaaaaaaegacbaaa
				aaaaaaaaegacbaaaabaaaaaaegacbaaaacaaaaaadoaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_OFF" "HDR_LIGHT_PREPASS_ON" }
				
				"!!GLES3"
			}
			
			SubProgram "opengl " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"3.0-!!ARBfp1.0
				# 47 ALU, 5 TEX
				PARAM c[8] = { program.local[0..3],
					{ 2, 1, 8, 0 },
					{ -0.40824828, -0.70710677, 0.57735026, 128 },
					{ -0.40824831, 0.70710677, 0.57735026 },
				{ 0.81649655, 0, 0.57735026 } };
				
				TEMP R0;
				TEMP R1;
				TEMP R2;
				TEX R0, fragment.texcoord[2], texture[4], 2D;
				MUL R0.xyz, R0.w, R0;
				MUL R1.xyz, R0, c[4].z;
				MUL R0.xyz, R1.y, c[6];
				MAD R0.xyz, R1.x, c[7], R0;
				MAD R2.xyz, R1.z, c[5], R0;
				DP3 R0.x, R2, R2;
				RSQ R0.x, R0.x;
				DP3 R1.w, fragment.texcoord[3], fragment.texcoord[3];
				TEX R0.yw, fragment.texcoord[0].zwzw, texture[1], 2D;
				MUL R2.xyz, R0.x, R2;
				MAD R0.xy, R0.wyzw, c[4].x, -c[4].y;
				MUL R0.zw, R0.xyxy, R0.xyxy;
				ADD_SAT R0.z, R0, R0.w;
				RSQ R1.w, R1.w;
				MAD R2.xyz, R1.w, fragment.texcoord[3], R2;
				DP3 R0.w, R2, R2;
				RSQ R0.w, R0.w;
				ADD R0.z, -R0, c[4].y;
				RSQ R0.z, R0.z;
				MUL R2.xyz, R0.w, R2;
				RCP R0.z, R0.z;
				DP3 R0.w, -R0, R2;
				DP3_SAT R2.z, -R0, c[5];
				DP3_SAT R2.x, -R0, c[7];
				DP3_SAT R2.y, -R0, c[6];
				DP3 R2.y, R2, R1;
				TEX R1, fragment.texcoord[2], texture[3], 2D;
				MUL R0.xyz, R1.w, R1;
				MOV R2.x, c[5].w;
				MUL R0.xyz, R0, R2.y;
				MUL R1.x, R2, c[2];
				MAX R0.w, R0, c[4];
				POW R2.w, R0.w, R1.x;
				TEX R1, fragment.texcoord[0], texture[0], 2D;
				MUL R2.xyz, R0, c[4].z;
				TXP R0, fragment.texcoord[1], texture[2], 2D;
				ADD R0, R0, R2;
				MUL R1.xyz, R1, c[1];
				MUL R2.xyz, R0, c[0];
				MUL R0.w, R0, R1.x;
				MUL R1.w, R1, c[1];
				MUL R2.xyz, R0.w, R2;
				MAD result.color.xyz, R0, R1, R2;
				SLT R0.x, R1.w, c[3];
				MAD result.color.w, R0, c[0], R1;
				KIL -R0.x;
				END
				# 47 instructions, 3 R-regs
				"
			}
			
			SubProgram "d3d9 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"ps_3_0
				; 47 ALU, 6 TEX
				dcl_2d s0
				dcl_2d s1
				dcl_2d s2
				dcl_2d s3
				dcl_2d s4
				def c4, 0.00000000, 1.00000000, 2.00000000, -1.00000000
				def c5, -0.40824828, -0.70710677, 0.57735026, 8.00000000
				def c6, -0.40824831, 0.70710677, 0.57735026, 128.00000000
				def c7, 0.81649655, 0.00000000, 0.57735026, 0
				dcl_texcoord0 v0
				dcl_texcoord1 v1
				dcl_texcoord2 v2.xy
				dcl_texcoord3 v3.xyz
				texld r0, v2, s4
				mul_pp r0.xyz, r0.w, r0
				mul_pp r2.xyz, r0, c5.w
				mul r0.xyz, r2.y, c6
				mad r0.xyz, r2.x, c7, r0
				mad r0.xyz, r2.z, c5, r0
				dp3 r0.w, r0, r0
				rsq r0.w, r0.w
				texld r1.yw, v0.zwzw, s1
				mad_pp r1.xy, r1.wyzw, c4.z, c4.w
				mul r0.xyz, r0.w, r0
				dp3_pp r0.w, v3, v3
				rsq_pp r0.w, r0.w
				mul_pp r1.zw, r1.xyxy, r1.xyxy
				mad_pp r0.xyz, r0.w, v3, r0
				add_pp_sat r0.w, r1.z, r1
				dp3_pp r1.z, r0, r0
				rsq_pp r1.z, r1.z
				add_pp r0.w, -r0, c4.y
				mul_pp r0.xyz, r1.z, r0
				rsq_pp r0.w, r0.w
				rcp_pp r1.z, r0.w
				dp3_pp r0.x, -r1, r0
				mov_pp r0.w, c2.x
				mul_pp r2.w, c6, r0
				max_pp r1.w, r0.x, c4.x
				pow r0, r1.w, r2.w
				mov r1.w, r0
				texld r0, v2, s3
				dp3_pp_sat r3.z, -r1, c5
				dp3_pp_sat r3.x, -r1, c7
				dp3_pp_sat r3.y, -r1, c6
				dp3_pp r1.x, r3, r2
				mul_pp r0.xyz, r0.w, r0
				mul_pp r1.xyz, r0, r1.x
				texld r0, v0, s0
				mul_pp r0.xyz, r0, c1
				texldp r2, v1, s2
				mul_pp r1.xyz, r1, c5.w
				add_pp r1, r2, r1
				mov_pp r2.w, c3.x
				mul_pp r1.w, r1, r0.x
				mul_pp r2.xyz, r1, c0
				mul_pp r2.xyz, r1.w, r2
				mad_pp oC0.xyz, r1, r0, r2
				mad_pp r2.w, r0, c1, -r2
				mul_pp r1.x, r0.w, c1.w
				cmp r0.x, r2.w, c4, c4.y
				mov_pp r0, -r0.x
				mad_pp oC0.w, r1, c0, r1.x
				texkill r0.xyzw
				"
			}
			
			SubProgram "xbox360 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 1 [_Color]
				Float 3 [_Cutoff]
				Float 2 [_Shininess]
				Vector 0 [_SpecColor]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [_LightSpecBuffer] 2D
				SetTexture 4 [unity_Lightmap] 2D
				SetTexture 5 [unity_LightmapInd] 2D
				
				"ps_360
				backbbaaaaaaacceaaaaacfaaaaaaaaaaaaaaaceaaaaabmmaaaaabpeaaaaaaaa
				aaaaaaaaaaaaabkeaaaaaabmaaaaabjfppppadaaaaaaaaakaaaaaabmaaaaaaaa
				aaaaabioaaaaaaoeaaadaaabaaabaaaaaaaaaapaaaaaaaaaaaaaabaaaaacaaab
				aaabaaaaaaaaabaiaaaaaaaaaaaaabbiaaacaaadaaabaaaaaaaaabcaaaaaaaaa
				aaaaabdaaaadaaacaaabaaaaaaaaaapaaaaaaaaaaaaaabdnaaadaaadaaabaaaa
				aaaaaapaaaaaaaaaaaaaabeoaaadaaaaaaabaaaaaaaaaapaaaaaaaaaaaaaabfh
				aaacaaacaaabaaaaaaaaabcaaaaaaaaaaaaaabgcaaacaaaaaaabaaaaaaaaabai
				aaaaaaaaaaaaabgnaaadaaaeaaabaaaaaaaaaapaaaaaaaaaaaaaabhmaaadaaaf
				aaabaaaaaaaaaapaaaaaaaaafpechfgnhaengbhaaaklklklaaaeaaamaaabaaab
				aaabaaaaaaaaaaaafpedgpgmgphcaaklaaabaaadaaabaaaeaaabaaaaaaaaaaaa
				fpedhfhegpggggaaaaaaaaadaaabaaabaaabaaaaaaaaaaaafpemgjghgiheechf
				gggggfhcaafpemgjghgihefdhagfgdechfgggggfhcaafpengbgjgofegfhiaafp
				fdgigjgogjgogfhdhdaafpfdhagfgdedgpgmgphcaahfgogjhehjfpemgjghgihe
				gngbhaaahfgogjhehjfpemgjghgihegngbhaejgogeaahahdfpddfpdaaadccoda
				codcdadddfddcodaaaklklklaaaaaaaaaaaaaaabaaaaaaaaaaaaaaaaaaaaaabe
				abpmaabaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaeaaaaaacbabaaaahaa
				aaaaaaaeaaaaaaaaaaaadeieaaapaaapaaaaaacbaaaapafaaaaapbfbaaaadcfc
				aaaahdfddpiaaaaaedaaaaaaaaaaaaaaaaaaaaaaeaaaaaaaebaaaaaaaaaaaaaa
				lpiaaaaadpbdmndklonbafomdpdfaepddpfbafollonbafollpdfaepddpbdmndk
				dpfbafolaeajgaaeeaakbcaabcaaaaffaaaaaaaagaaomeaabcaaaaaaaaaagabe
				gabkbcaabcaaaaaaaaaagacafacgbcaaccaaaaaabaaieaabbpbppgiiaaaaeaaa
				emeiacadaaloloblpaadadabmiapaaaeaaaaaaaakbaeabaaliedabababmglaeh
				mbacabadmiaaaaaaaamgmgaahjpnabaabadibacbbpbppbppaaaaeaaabacibacb
				bpbppoiiaaaaeaaabaeihaebbpbppgiiaaaaeaaadibiaaabbpbpppnjaaaaeaaa
				bafigaebbpbppgiiaaaaeaaamiagaaafaagbgmblilaapnpnbebcaaaaaabllbbl
				kbahpnagkiboaaacaalbpmiambaaahpnmjacaaaaaamfmfmgnbafafpnfibnacaa
				aagmonblobaaagidkiehadagaagmmamambacadpolicpaaahaaeogdebibaapopm
				kabjafadaamebjlboaahahiamjacaaadaegnmhmgjbafpppnmiahaaahaablmabe
				klaappadmiacaaaaaaloloaapaahahaafjceaaadaemamalblaafpoiamiahaaag
				aamalbmaolahaaagmiacaaaaaaloloaapaagagaafjciaaadaemalolblaafppia
				miahaaagaamalbaaobagaaaabeacaaaaaclomagmnaagafacambbacadaalbmglb
				icaapnpmeabcaaaaaaghmdgmpaaaadidmiapaaaaaaaalaaaobacaaaadibhaaab
				aabfmagmoaaaabaamiabaaaaaagmblaaoaaaabaamiaiaaabaagmgmaaobaeaaaa
				miapaaacaacfcfaakbabaaaamiaiiaaaaablblaaoaaeacaamiaiaaaaaamggmaa
				obacaeaamiagaaaaaalmblaaobacabaamiabaaaaaablgmaaobaaaaaamiahiaaa
				aamamamaolaeabaaaaaaaaaaaaaaaaaaaaaaaaaa"
			}
			
			SubProgram "ps3 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_ON" }
				
				Vector 0 [_SpecColor]
				Vector 1 [_Color]
				Float 2 [_Shininess]
				Float 3 [_Cutoff]
				SetTexture 0 [_MainTex] 2D
				SetTexture 1 [_BumpMap] 2D
				SetTexture 2 [_LightBuffer] 2D
				SetTexture 3 [unity_Lightmap] 2D
				SetTexture 4 [unity_LightmapInd] 2D
				"sce_fp_rsx 
				[Configuration]
				24
				ffffffff0003c020000ffff4000000000000848004000000
				[Offsets]
				4
				_SpecColor 2 0
				0000034000000320
				_Color 1 0
				00000020
				_Shininess 1 0
				00000250
				_Cutoff 1 0
				00000040
				[Microcode]
				864
				9e001700c8011c9dc8000001c8003fe11e84024026001c9d26020001c8000001
				00000000000000000000000000000000037e4a80c9081c9d00020168c8000001
				00000000000000000000000000000000067e5200c8000015c8000001c8000001
				940417025c011c9dc8000001c8003fe1068a0440ce081c9d00020000aa020000
				000040000000bf800000000000000000de001708c8011c9dc8000001c8003fe1
				0e820240fe001c9dc8003001c80000010e060200ab041c9cc8020001c8000001
				05ecbed104f33f35cd3a3f13000000000280b840c9141c9dc9140001c8000001
				02800340c9001c9f00020000c800000100003f80000000000000000000000000
				0e06040001041c9cc8020001c80c000105eb3f5100000000cd3a3f1300000000
				088a3b4001003c9cc9000001c800000108888540c9141c9fc8020001c8000001
				05ebbed104f3bf35cd3a3f130000000004888540c9141c9fc8020001c8000001
				05ecbed104f33f35cd3a3f13000000000288b84005141c9e08020000c8000001
				cd3a3f1305eb3f51000000000000000002860540c9101c9dc9040001c8000001
				0e06040055041c9dc8020001c80c000105ebbed104f3bf35cd3a3f1300000000
				ee803940c8011c9dc8000029c800bfe108000500c80c1c9dc80c0001c8000001
				0e823b00c80c1c9d54000001c80000010e060340c9041c9dc9000001c8000001
				0e883940c80c1c9dc8000029c800000104860540c9141c9fc9100001c8000001
				10020900ab0c1c9caa020000c800000100000000000000000000000000000000
				0486014000021c9cc8000001c800000100000000000000000000000000000000
				04860240c90c1c9d00020000c800000100004300000000000000000000000000
				10021d00fe041c9dc8000001c8000001de001706c8011c9dc8000001c8003fe1
				02860240fe001c9dc90c0001c800000110000200c8041c9dab0c0000c8000001
				0e800240010c1c9cc8003001c800000110801c00fe001c9dc8000001c8000001
				be041804c8011c9dc8000001c8003fe11e800340c8081c9dc9000001c8000001
				1e820240cb081c9d27000001c80000010e800240c9001c9dc8020001c8000001
				000000000000000000000000000000001080044001041c9cc802000101080000
				000000000000000000000000000000000e81044001041c9cc9000001f3040001
				"
			}
			
			SubProgram "d3d11 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_ON" }
				
				ConstBuffer "$Globals" 176 
				Vector 32 [_SpecColor] 4
				Vector 48 [_Color] 4
				Float 64 [_Shininess]
				Float 160 [_Cutoff]
				BindCB "$Globals" 0
				SetTexture 0 [_MainTex] 2D 0
				SetTexture 1 [_BumpMap] 2D 1
				SetTexture 2 [_LightBuffer] 2D 2
				SetTexture 3 [unity_Lightmap] 2D 3
				SetTexture 4 [unity_LightmapInd] 2D 4
				
				"ps_4_0
				eefiecedbmopjekgflojhhpfamjdeelddombjeelabaaaaaamiahaaaaadaaaaaa
				cmaaaaaammaaaaaaaaabaaaaejfdeheojiaaaaaaafaaaaaaaiaaaaaaiaaaaaaa
				aaaaaaaaabaaaaaaadaaaaaaaaaaaaaaapaaaaaaimaaaaaaaaaaaaaaaaaaaaaa
				adaaaaaaabaaaaaaapapaaaaimaaaaaaabaaaaaaaaaaaaaaadaaaaaaacaaaaaa
				apalaaaaimaaaaaaacaaaaaaaaaaaaaaadaaaaaaadaaaaaaadadaaaaimaaaaaa
				adaaaaaaaaaaaaaaadaaaaaaaeaaaaaaahahaaaafdfgfpfaepfdejfeejepeoaa
				feeffiedepepfceeaaklklklepfdeheocmaaaaaaabaaaaaaaiaaaaaacaaaaaaa
				aaaaaaaaaaaaaaaaadaaaaaaaaaaaaaaapaaaaaafdfgfpfegbhcghgfheaaklkl
				fdeieefcmaagaaaaeaaaaaaalaabaaaafjaaaaaeegiocaaaaaaaaaaaalaaaaaa
				fkaaaaadaagabaaaaaaaaaaafkaaaaadaagabaaaabaaaaaafkaaaaadaagabaaa
				acaaaaaafkaaaaadaagabaaaadaaaaaafkaaaaadaagabaaaaeaaaaaafibiaaae
				aahabaaaaaaaaaaaffffaaaafibiaaaeaahabaaaabaaaaaaffffaaaafibiaaae
				aahabaaaacaaaaaaffffaaaafibiaaaeaahabaaaadaaaaaaffffaaaafibiaaae
				aahabaaaaeaaaaaaffffaaaagcbaaaadpcbabaaaabaaaaaagcbaaaadlcbabaaa
				acaaaaaagcbaaaaddcbabaaaadaaaaaagcbaaaadhcbabaaaaeaaaaaagfaaaaad
				pccabaaaaaaaaaaagiaaaaacagaaaaaaefaaaaajpcaabaaaaaaaaaaaegbabaaa
				abaaaaaaeghobaaaaaaaaaaaaagabaaaaaaaaaaadcaaaaambcaabaaaabaaaaaa
				dkaabaaaaaaaaaaadkiacaaaaaaaaaaaadaaaaaaakiacaiaebaaaaaaaaaaaaaa
				akaaaaaadiaaaaaipcaabaaaaaaaaaaaegaobaaaaaaaaaaaegiocaaaaaaaaaaa
				adaaaaaadbaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaaaaaaaaaa
				anaaaeadakaabaaaabaaaaaabaaaaaahbcaabaaaabaaaaaaegbcbaaaaeaaaaaa
				egbcbaaaaeaaaaaaeeaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaah
				hcaabaaaabaaaaaaagaabaaaabaaaaaaegbcbaaaaeaaaaaaefaaaaajpcaabaaa
				acaaaaaaegbabaaaadaaaaaaeghobaaaaeaaaaaaaagabaaaaeaaaaaadiaaaaah
				icaabaaaabaaaaaadkaabaaaacaaaaaaabeaaaaaaaaaaaebdiaaaaahhcaabaaa
				acaaaaaaegacbaaaacaaaaaapgapbaaaabaaaaaadiaaaaakhcaabaaaadaaaaaa
				fgafbaaaacaaaaaaaceaaaaaomafnblopdaedfdpdkmnbddpaaaaaaaadcaaaaam
				hcaabaaaadaaaaaaagaabaaaacaaaaaaaceaaaaaolaffbdpaaaaaaaadkmnbddp
				aaaaaaaaegacbaaaadaaaaaadcaaaaamhcaabaaaadaaaaaakgakbaaaacaaaaaa
				aceaaaaaolafnblopdaedflpdkmnbddpaaaaaaaaegacbaaaadaaaaaabaaaaaah
				icaabaaaabaaaaaaegacbaaaadaaaaaaegacbaaaadaaaaaaeeaaaaaficaabaaa
				abaaaaaadkaabaaaabaaaaaadcaaaaajhcaabaaaabaaaaaaegacbaaaadaaaaaa
				pgapbaaaabaaaaaaegacbaaaabaaaaaabaaaaaahicaabaaaabaaaaaaegacbaaa
				abaaaaaaegacbaaaabaaaaaaeeaaaaaficaabaaaabaaaaaadkaabaaaabaaaaaa
				diaaaaahhcaabaaaabaaaaaapgapbaaaabaaaaaaegacbaaaabaaaaaaefaaaaaj
				pcaabaaaadaaaaaaogbkbaaaabaaaaaaeghobaaaabaaaaaaaagabaaaabaaaaaa
				dcaaaaapdcaabaaaadaaaaaahgapbaaaadaaaaaaaceaaaaaaaaaaaeaaaaaaaea
				aaaaaaaaaaaaaaaaaceaaaaaaaaaialpaaaaialpaaaaaaaaaaaaaaaaapaaaaah
				icaabaaaabaaaaaaegaabaaaadaaaaaaegaabaaaadaaaaaaddaaaaahicaabaaa
				abaaaaaadkaabaaaabaaaaaaabeaaaaaaaaaiadpaaaaaaaiicaabaaaabaaaaaa
				dkaabaiaebaaaaaaabaaaaaaabeaaaaaaaaaiadpelaaaaafecaabaaaadaaaaaa
				dkaabaaaabaaaaaabaaaaaaibcaabaaaabaaaaaaegacbaiaebaaaaaaadaaaaaa
				egacbaaaabaaaaaadeaaaaahbcaabaaaabaaaaaaakaabaaaabaaaaaaabeaaaaa
				aaaaaaaacpaaaaafbcaabaaaabaaaaaaakaabaaaabaaaaaadiaaaaaiccaabaaa
				abaaaaaaakiacaaaaaaaaaaaaeaaaaaaabeaaaaaaaaaaaeddiaaaaahbcaabaaa
				abaaaaaaakaabaaaabaaaaaabkaabaaaabaaaaaabjaaaaafbcaabaaaabaaaaaa
				akaabaaaabaaaaaaaoaaaaahdcaabaaaaeaaaaaaegbabaaaacaaaaaapgbpbaaa
				acaaaaaaefaaaaajpcaabaaaaeaaaaaaegaabaaaaeaaaaaaeghobaaaacaaaaaa
				aagabaaaacaaaaaaapcaaaalbcaabaaaafaaaaaaaceaaaaaolaffbdpdkmnbddp
				aaaaaaaaaaaaaaaaigaabaiaebaaaaaaadaaaaaabacaaaalccaabaaaafaaaaaa
				aceaaaaaomafnblopdaedfdpdkmnbddpaaaaaaaaegacbaiaebaaaaaaadaaaaaa
				bacaaaalecaabaaaafaaaaaaaceaaaaaolafnblopdaedflpdkmnbddpaaaaaaaa
				egacbaiaebaaaaaaadaaaaaabaaaaaahbcaabaaaacaaaaaaegacbaaaafaaaaaa
				egacbaaaacaaaaaaefaaaaajpcaabaaaadaaaaaaegbabaaaadaaaaaaeghobaaa
				adaaaaaaaagabaaaadaaaaaadiaaaaahccaabaaaacaaaaaadkaabaaaadaaaaaa
				abeaaaaaaaaaaaebdiaaaaahocaabaaaacaaaaaaagajbaaaadaaaaaafgafbaaa
				acaaaaaadiaaaaahocaabaaaabaaaaaaagaabaaaacaaaaaafgaobaaaacaaaaaa
				aaaaaaahpcaabaaaabaaaaaaegaobaaaabaaaaaadgajbaaaaeaaaaaadiaaaaah
				pcaabaaaacaaaaaaagajbaaaaaaaaaaaegaobaaaabaaaaaadiaaaaaihcaabaaa
				aaaaaaaajgahbaaaabaaaaaaegiccaaaaaaaaaaaacaaaaaadcaaaaajhccabaaa
				aaaaaaaaegacbaaaaaaaaaaaagaabaaaacaaaaaajgahbaaaacaaaaaadcaaaaak
				iccabaaaaaaaaaaaakaabaaaacaaaaaadkiacaaaaaaaaaaaacaaaaaadkaabaaa
				aaaaaaaadoaaaaab"
			}
			
			SubProgram "gles " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_ON" }
				
				"!!GLES"
			}
			
			SubProgram "glesdesktop " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_ON" }
				
				"!!GLES"
			}
			
			SubProgram "gles3 " {
				Keywords { "LIGHTMAP_ON" "DIRLIGHTMAP_ON" "HDR_LIGHT_PREPASS_ON" }
				
				"!!GLES3"
			}
		}
	}
}

Fallback "GoHDR/Transparent/Cutout/VertexLit CG"
}


//Original shader:

//Shader "Enviro/2-sided Bumped Specular" {
//Properties {
//_Color ("Main Color", Color) = (1,1,1,1)
//_SpecColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 0)
//_Shininess ("Shininess", Range (0.01, 10)) = 0.078125
//_MainTex ("Base (RGB) TransGloss (A)", 2D) = "white" {}
//_BumpMap ("Normalmap", 2D) = "bump" {}
//_Cutoff ("Alpha cutoff", Range(0,1)) = 0.5
//}
//
//SubShader {
//Tags {"Queue"="AlphaTest" "IgnoreProjector"="True" "RenderType"="TransparentCutout"}
//LOD 400
//
//Cull Back
//
//CGPROGRAM
//#pragma surface surf BlinnPhong alphatest:_Cutoff
//#pragma target 3.0
//
//sampler2D _MainTex;
//sampler2D _BumpMap;
//fixed4 _Color;
//half _Shininess;
//
//struct Input {
//float2 uv_MainTex;
//float2 uv_BumpMap;
//};
//
//void surf (Input IN, inout SurfaceOutput o) {
//fixed4 tex = tex2D(_MainTex, IN.uv_MainTex);
//o.Albedo = tex.rgb * _Color.rgb;
//o.Gloss = tex.rgb * _Color.rgb;
//o.Alpha = tex.a * _Color.a;
//o.Specular = _Shininess;
//o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
//}
//ENDCG
//
//Cull Front
//
//CGPROGRAM
//#pragma surface surf BlinnPhong alphatest:_Cutoff
//#pragma target 3.0
//
//sampler2D _MainTex;
//sampler2D _BumpMap;
//fixed4 _Color;
//half _Shininess;
//
//struct Input {
//float2 uv_MainTex;
//float2 uv_BumpMap;
//};
//
//void surf (Input IN, inout SurfaceOutput o) {
//fixed4 tex = tex2D(_MainTex, IN.uv_MainTex);
//o.Albedo = tex.rgb * _Color.rgb;
//o.Gloss = tex.rgb * _Color.rgb;
//o.Alpha = tex.a * _Color.a;
//o.Specular = _Shininess;
//o.Normal = -UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
//}
//ENDCG
//
//}
//
//FallBack "Transparent/Cutout/VertexLit"
//}

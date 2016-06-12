Shader "GoHDR/Nature/ats Soft Occlusion Bark" {
	Properties {
		_Color ("Main Color", Color) = (1,1,1,0)
		_MainTex ("Main Texture", 2D) = "white" {  }
		_BumpMap ("Bump Map", 2D) = "white" {  }
		
		_Scale ("Scale", Vector) = (1,1,1,1)
		_SquashAmount ("Squash", Float) = 0.5
	}
	
	SubShader {
		Tags {
			"RenderType"="Opaque"
		}
		
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			
			CGPROGRAM
			#include "../GoHDR.cginc"
			#include "../LinLighting.cginc"
			#pragma vertex vert_surf
			#pragma fragment frag_surf
			#pragma multi_compile_fwdbase nolightmap
			#include "HLSLSupport.cginc"
			#include "UnityShaderVariables.cginc"
			#define UNITY_PASS_FORWARDBASE
			#include "../UnityCGGoHDR.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			#define INTERNAL_DATA
			#define WorldReflectionVector(data,normal) data.worldRefl
			#define WorldNormalVector(data,normal) normal
			
			#include "../TerrainEngineGoHDR.cginc"
			
			void treevertex (inout appdata_full v) {
				TerrainAnimateTree(v.vertex, LLDecodeGamma( v.color.w ));
				
				float3 T1 = float3(1, 0, 1);
				float3 Bi = cross(T1, v.normal);
				float3 newTangent = cross(v.normal, Bi);
				normalize(newTangent);
				v.tangent.xyz = newTangent.xyz;
				if (dot(cross(v.normal,newTangent),Bi) < 0)
				v.tangent.w = -1.0f;
				else
				v.tangent.w = 1.0f;
			}
			
			sampler2D _MainTex;
			sampler2D _BumpMap;
			
			float4 _Color;
			
			struct Input {
				float2 uv_MainTex;
				float2 uv_BumpMap;
			};
			
			void surf (Input IN, inout SurfaceOutput o) {
				half4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) ) * LLDecodeGamma( _Color );
				o.Albedo = c.rgb;
				o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
				o.Alpha = c.a;
			}
			
			#ifdef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					fixed3 lightDir : TEXCOORD1;
					fixed3 vlight : TEXCOORD2;
					LIGHTING_COORDS(3,4)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					float2 lmap : TEXCOORD1;
					LIGHTING_COORDS(2,3)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				float4 unity_LightmapST;
			#endif
			
			float4 _MainTex_ST;
			float4 _BumpMap_ST;
			
			v2f_surf vert_surf (appdata_full v) {
				v2f_surf o;
				treevertex (v);
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
				fixed atten = LIGHT_ATTENUATION(IN);
				fixed4 c = 0;
				
				#ifdef LIGHTMAP_OFF
					c = LightingLambert (o, IN.lightDir, atten);
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
	
	Pass {
		Name "FORWARD"
		Tags { "LightMode" = "ForwardAdd" }
		ZWrite Off Blend One One Fog { Color (0,0,0,0) }
		
		CGPROGRAM
		#include "../GoHDR.cginc"
		#include "../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_fwdadd nolightmap
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_FORWARDADD
		#include "../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		#include "AutoLight.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#include "../TerrainEngineGoHDR.cginc"
		
		void treevertex (inout appdata_full v) {
			TerrainAnimateTree(v.vertex, LLDecodeGamma( v.color.w ));
			
			float3 T1 = float3(1, 0, 1);
			float3 Bi = cross(T1, v.normal);
			float3 newTangent = cross(v.normal, Bi);
			normalize(newTangent);
			v.tangent.xyz = newTangent.xyz;
			if (dot(cross(v.normal,newTangent),Bi) < 0)
			v.tangent.w = -1.0f;
			else
			v.tangent.w = 1.0f;
		}
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		
		float4 _Color;
		
		struct Input {
			float2 uv_MainTex;
			float2 uv_BumpMap;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			half4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) ) * LLDecodeGamma( _Color );
			o.Albedo = c.rgb;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
			o.Alpha = c.a;
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			half3 lightDir : TEXCOORD1;
			LIGHTING_COORDS(2,3)
		};
		
		float4 _MainTex_ST;
		float4 _BumpMap_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			treevertex (v);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _BumpMap);
			TANGENT_SPACE_ROTATION;
			float3 lightDir = mul (rotation, ObjSpaceLightDir(v.vertex));
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
		#include "../GoHDR.cginc"
		#include "../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_prepassbase nolightmap
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_PREPASSBASE
		#include "../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#include "../TerrainEngineGoHDR.cginc"
		
		void treevertex (inout appdata_full v) {
			TerrainAnimateTree(v.vertex, LLDecodeGamma( v.color.w ));
			
			float3 T1 = float3(1, 0, 1);
			float3 Bi = cross(T1, v.normal);
			float3 newTangent = cross(v.normal, Bi);
			normalize(newTangent);
			v.tangent.xyz = newTangent.xyz;
			if (dot(cross(v.normal,newTangent),Bi) < 0)
			v.tangent.w = -1.0f;
			else
			v.tangent.w = 1.0f;
		}
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		
		float4 _Color;
		
		struct Input {
			float2 uv_MainTex;
			float2 uv_BumpMap;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			half4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) ) * LLDecodeGamma( _Color );
			o.Albedo = c.rgb;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
			o.Alpha = c.a;
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float2 pack0 : TEXCOORD0;
			float3 TtoW0 : TEXCOORD1;
			float3 TtoW1 : TEXCOORD2;
			float3 TtoW2 : TEXCOORD3;
		};
		
		float4 _BumpMap_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			treevertex (v);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _BumpMap);
			TANGENT_SPACE_ROTATION;
			o.TtoW0 = mul(rotation, ((float3x3)_Object2World)[0].xyz)*unity_Scale.w;
			o.TtoW1 = mul(rotation, ((float3x3)_Object2World)[1].xyz)*unity_Scale.w;
			o.TtoW2 = mul(rotation, ((float3x3)_Object2World)[2].xyz)*unity_Scale.w;
			return o;
		}
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
			surfIN.uv_BumpMap = IN.pack0.xy;
			
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
		#pragma multi_compile_prepassfinal nolightmap
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_PREPASSFINAL
		#include "../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#include "../TerrainEngineGoHDR.cginc"
		
		void treevertex (inout appdata_full v) {
			TerrainAnimateTree(v.vertex, LLDecodeGamma( v.color.w ));
			
			float3 T1 = float3(1, 0, 1);
			float3 Bi = cross(T1, v.normal);
			float3 newTangent = cross(v.normal, Bi);
			normalize(newTangent);
			v.tangent.xyz = newTangent.xyz;
			if (dot(cross(v.normal,newTangent),Bi) < 0)
			v.tangent.w = -1.0f;
			else
			v.tangent.w = 1.0f;
		}
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		
		float4 _Color;
		
		struct Input {
			float2 uv_MainTex;
			float2 uv_BumpMap;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			half4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) ) * LLDecodeGamma( _Color );
			o.Albedo = c.rgb;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
			o.Alpha = c.a;
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
			treevertex (v);
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
					half4 lm = LightingLambert_DirLightmap(o, lmtex, lmIndTex, 1);
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
		#pragma multi_compile_shadowcaster nolightmap
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_SHADOWCASTER
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#include "TerrainEngine.cginc"
		
		void treevertex (inout appdata_full v) {
			TerrainAnimateTree(v.vertex, v.color.w);
			
			float3 T1 = float3(1, 0, 1);
			float3 Bi = cross(T1, v.normal);
			float3 newTangent = cross(v.normal, Bi);
			normalize(newTangent);
			v.tangent.xyz = newTangent.xyz;
			if (dot(cross(v.normal,newTangent),Bi) < 0)
			v.tangent.w = -1.0f;
			else
			v.tangent.w = 1.0f;
		}
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		
		float4 _Color;
		
		struct Input {
			float2 uv_MainTex;
			float2 uv_BumpMap;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			half4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
			o.Alpha = c.a;
		}
		
		struct v2f_surf {
			V2F_SHADOW_CASTER;
		};
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			treevertex (v);
			TRANSFER_SHADOW_CASTER(o)
			return o;
		}
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
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
		#pragma multi_compile_shadowcollector nolightmap
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_SHADOWCOLLECTOR
		#define SHADOW_COLLECTOR_PASS
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#include "TerrainEngine.cginc"
		
		void treevertex (inout appdata_full v) {
			TerrainAnimateTree(v.vertex, v.color.w);
			
			float3 T1 = float3(1, 0, 1);
			float3 Bi = cross(T1, v.normal);
			float3 newTangent = cross(v.normal, Bi);
			normalize(newTangent);
			v.tangent.xyz = newTangent.xyz;
			if (dot(cross(v.normal,newTangent),Bi) < 0)
			v.tangent.w = -1.0f;
			else
			v.tangent.w = 1.0f;
		}
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		
		float4 _Color;
		
		struct Input {
			float2 uv_MainTex;
			float2 uv_BumpMap;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			half4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
			o.Albedo = c.rgb;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
			o.Alpha = c.a;
		}
		
		struct v2f_surf {
			V2F_SHADOW_COLLECTOR;
		};
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			treevertex (v);
			TRANSFER_SHADOW_COLLECTOR(o)
			return o;
		}
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
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
		"RenderType"="Opaque"
	}
	
	Pass {
		
		#LINE 110
		SetTexture [_MainTex] { combine primary * texture DOUBLE, constant }
	}
}

SubShader {
	Tags {
		"RenderType" = "Opaque"
	}
	
	Pass {
		Tags { "LightMode" = "Vertex" }
		
		Lighting On
		Material {
			Diffuse [_Color]
			Ambient [_Color]
		}
		SetTexture [_MainTex] { combine primary * texture DOUBLE, constant }
	}
}

Dependency "BillboardShader" = "GoHDR/Hidden/TerrainEngine/Soft Occlusion Bark rendertex"
}


//Original shader:

//Shader "Nature/ats Soft Occlusion Bark" {
//	Properties {
//		_Color ("Main Color", Color) = (1,1,1,0)
//		_MainTex ("Main Texture", 2D) = "white" {  }
//		_BumpMap ("Bump Map", 2D) = "white" {  }
//		
//		_Scale ("Scale", Vector) = (1,1,1,1)
//		_SquashAmount ("Squash", Float) = 0.5
//	}
//	SubShader {
//		Tags {
//			"RenderType"="Opaque"
//		}
//		CGPROGRAM
//		#pragma surface surf Lambert vertex:treevertex addshadow nolightmap
//		#include "TerrainEngine.cginc"
//		void treevertex (inout appdata_full v) {
//			TerrainAnimateTree(v.vertex, v.color.w);
//		
//			/* Code provided by Chris Morris of Six Times Nothing (http://www.sixtimesnothing.com) */
//
//			// A general tangent estimation	
//			float3 T1 = float3(1, 0, 1);
//			float3 Bi = cross(T1, v.normal);
//			float3 newTangent = cross(v.normal, Bi);
//			normalize(newTangent);
//			v.tangent.xyz = newTangent.xyz;
//			if (dot(cross(v.normal,newTangent),Bi) < 0)
//			v.tangent.w = -1.0f;
//			else
//			v.tangent.w = 1.0f;
//			//
//		
//		}
//		
//		sampler2D _MainTex;
//		sampler2D _BumpMap;
//
//		float4 _Color;
//		
//		struct Input {
//			float2 uv_MainTex;
//			float2 uv_BumpMap;
//		};
//		
//		void surf (Input IN, inout SurfaceOutput o) {
//			half4 c = tex2D(_MainTex, IN.uv_MainTex) * _Color;
//			o.Albedo = c.rgb;
//			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_BumpMap));
//			o.Alpha = c.a;
//		}
//		ENDCG
//	}
//	
//	SubShader {
//		Tags {
//			"RenderType"="Opaque"
//		}
//
//		Pass {
//			CGPROGRAM
//			#pragma vertex vert
//			#pragma exclude_renderers gles
//			#include "SH_Vertex.cginc"
//			ENDCG
//						
//			SetTexture [_MainTex] { combine primary * texture DOUBLE, constant }
//		}
//	}
//	SubShader {
//		Tags {
//			"RenderType" = "Opaque"
//		}
//		Pass {
//			Tags { "LightMode" = "Vertex" }
//			Lighting On
//			Material {
//				Diffuse [_Color]
//				Ambient [_Color]
//			}
//			SetTexture [_MainTex] { combine primary * texture DOUBLE, constant }
//		}		
//	}
//	
//	
//	
//	Dependency "BillboardShader" = "Hidden/TerrainEngine/Soft Occlusion Bark rendertex"
//	Fallback Off
//}

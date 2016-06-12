Shader "GoHDR/Nature/Tree Creator Bark" {
	Properties {
		_Color ("Main Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range (0.01, 1)) = 0.078125
		_MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}
		_BumpMap ("Normalmap", 2D) = "bump" {}
		_GlossMap ("Gloss (A)", 2D) = "black" {}
		
		_SpecColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
		_Scale ("Scale", Vector) = (1,1,1,1)
		_SquashAmount ("Squash", Float) = 1
	}
	
	SubShader {
		Tags { "RenderType"="TreeBark" }
		
		LOD 200
		
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			
			CGPROGRAM
			#pragma target 3.0
			#include "../../../GoHDR.cginc"
			#include "../../../LinLighting.cginc"
			#pragma vertex vert_surf
			#pragma fragment frag_surf
			#pragma multi_compile_fwdbase nolightmap
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
			
			#pragma exclude_renderers flash
			#pragma glsl_no_auto_normalization
			
			#ifndef TREE_CG_INCLUDED
				#define TREE_CG_INCLUDED
				
				#include "../TerrainEngineGoHDR.cginc"
				
				fixed4 _Color;
				fixed3 _TranslucencyColor;
				fixed _TranslucencyViewDependency;
				half _ShadowStrength;
				
				struct LeafSurfaceOutput {
					fixed3 Albedo;
					fixed3 Normal;
					fixed3 Emission;
					fixed Translucency;
					half Specular;
					fixed Gloss;
					fixed Alpha;
				};
				
				inline half4 LightingTreeLeaf (LeafSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
				{
					half3 h = normalize (lightDir + viewDir);
					
					half nl = dot (s.Normal, lightDir);
					
					half nh = max (0, dot (s.Normal, h));
					half spec = pow (nh, s.Specular * 128.0) * s.Gloss;
					
					fixed backContrib = saturate(dot(viewDir, -lightDir));
					
					backContrib = lerp(saturate(-nl), backContrib, _TranslucencyViewDependency);
					
					fixed3 translucencyColor = backContrib * s.Translucency * _TranslucencyColor;
					
					nl = max(0, nl * 0.6 + 0.4);
					
					fixed4 c;
					c.rgb = s.Albedo * (translucencyColor * 2 + nl);
					c.rgb = c.rgb * _LightColor0.rgb + spec;
					
					#if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
						c.rgb *= lerp(2, atten * 2, _ShadowStrength);
						#else
						c.rgb *= 2*atten;
					#endif
					
					return c;
				}
			#endif
			
			sampler2D _MainTex;
			sampler2D _BumpMap;
			sampler2D _GlossMap;
			half _Shininess;
			
			struct Input {
				float2 uv_MainTex;
				fixed4 color : COLOR;
			};
			
			void surf (Input IN, inout SurfaceOutput o) {
				fixed4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) );
				o.Albedo = c.rgb * LLDecodeGamma( _Color.rgb ) * IN.color.a;
				o.Gloss = tex2D(_GlossMap, IN.uv_MainTex).a;
				o.Alpha = c.a;
				o.Specular = _Shininess;
				o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
			}
			
			#ifdef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float2 pack0 : TEXCOORD0;
					fixed4 color : COLOR0;
					fixed3 lightDir : TEXCOORD1;
					fixed3 vlight : TEXCOORD2;
					float3 viewDir : TEXCOORD3;
					LIGHTING_COORDS(4,5)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float2 pack0 : TEXCOORD0;
					fixed4 color : COLOR0;
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
			
			v2f_surf vert_surf (appdata_full v) {
				v2f_surf o;
				TreeVertBark (v);
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
				o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.color = LLDecodeGamma( v.color );
				
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
			
			return LLEncodeGamma( GoHDRApplyCorrection( c ) );
		}
		
		ENDCG
	}
	
	Pass {
		Name "FORWARD"
		Tags { "LightMode" = "ForwardAdd" }
		ZWrite Off Blend One One Fog { Color (0,0,0,0) }
		
		CGPROGRAM
		#pragma target 3.0
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_fwdadd nolightmap
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
		
		#pragma exclude_renderers flash
		#pragma glsl_no_auto_normalization
		
		#ifndef TREE_CG_INCLUDED
			#define TREE_CG_INCLUDED
			
			#include "../TerrainEngineGoHDR.cginc"
			
			fixed4 _Color;
			fixed3 _TranslucencyColor;
			fixed _TranslucencyViewDependency;
			half _ShadowStrength;
			
			struct LeafSurfaceOutput {
				fixed3 Albedo;
				fixed3 Normal;
				fixed3 Emission;
				fixed Translucency;
				half Specular;
				fixed Gloss;
				fixed Alpha;
			};
			
			inline half4 LightingTreeLeaf (LeafSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
			{
				half3 h = normalize (lightDir + viewDir);
				
				half nl = dot (s.Normal, lightDir);
				
				half nh = max (0, dot (s.Normal, h));
				half spec = pow (nh, s.Specular * 128.0) * s.Gloss;
				
				fixed backContrib = saturate(dot(viewDir, -lightDir));
				
				backContrib = lerp(saturate(-nl), backContrib, _TranslucencyViewDependency);
				
				fixed3 translucencyColor = backContrib * s.Translucency * _TranslucencyColor;
				
				nl = max(0, nl * 0.6 + 0.4);
				
				fixed4 c;
				c.rgb = s.Albedo * (translucencyColor * 2 + nl);
				c.rgb = c.rgb * _LightColor0.rgb + spec;
				
				#if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
					c.rgb *= lerp(2, atten * 2, _ShadowStrength);
					#else
					c.rgb *= 2*atten;
				#endif
				
				return c;
			}
		#endif
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _GlossMap;
		half _Shininess;
		
		struct Input {
			float2 uv_MainTex;
			fixed4 color : COLOR;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) );
			o.Albedo = c.rgb * LLDecodeGamma( _Color.rgb ) * IN.color.a;
			o.Gloss = tex2D(_GlossMap, IN.uv_MainTex).a;
			o.Alpha = c.a;
			o.Specular = _Shininess;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float2 pack0 : TEXCOORD0;
			fixed4 color : COLOR0;
			half3 lightDir : TEXCOORD1;
			half3 viewDir : TEXCOORD2;
			LIGHTING_COORDS(3,4)
		};
		
		float4 _MainTex_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			TreeVertBark (v);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.color = LLDecodeGamma( v.color );
			TANGENT_SPACE_ROTATION;
			float3 lightDir = mul (rotation, ObjSpaceLightDir(v.vertex));
			o.lightDir = lightDir;
			float3 viewDirForLight = mul (rotation, ObjSpaceViewDir(v.vertex));
			o.viewDir = viewDirForLight;
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
			surf (surfIN, o);
			
			#ifndef USING_DIRECTIONAL_LIGHT
				fixed3 lightDir = normalize(IN.lightDir);
				#else
				fixed3 lightDir = IN.lightDir;
			#endif
			
			fixed4 c = LightingBlinnPhong (o, lightDir, normalize(half3(IN.viewDir)), LIGHT_ATTENUATION(IN));
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
		#pragma target 3.0
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_prepassbase nolightmap
		#pragma glsl_no_auto_normalization
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_PREPASSBASE
		#include "../../../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#pragma exclude_renderers flash
		#pragma glsl_no_auto_normalization
		
		#ifndef TREE_CG_INCLUDED
			#define TREE_CG_INCLUDED
			
			#include "../TerrainEngineGoHDR.cginc"
			
			fixed4 _Color;
			fixed3 _TranslucencyColor;
			fixed _TranslucencyViewDependency;
			half _ShadowStrength;
			
			struct LeafSurfaceOutput {
				fixed3 Albedo;
				fixed3 Normal;
				fixed3 Emission;
				fixed Translucency;
				half Specular;
				fixed Gloss;
				fixed Alpha;
			};
			
			inline half4 LightingTreeLeaf (LeafSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
			{
				half3 h = normalize (lightDir + viewDir);
				
				half nl = dot (s.Normal, lightDir);
				
				half nh = max (0, dot (s.Normal, h));
				half spec = pow (nh, s.Specular * 128.0) * s.Gloss;
				
				fixed backContrib = saturate(dot(viewDir, -lightDir));
				
				backContrib = lerp(saturate(-nl), backContrib, _TranslucencyViewDependency);
				
				fixed3 translucencyColor = backContrib * s.Translucency * _TranslucencyColor;
				
				nl = max(0, nl * 0.6 + 0.4);
				
				fixed4 c;
				c.rgb = s.Albedo * (translucencyColor * 2 + nl);
				c.rgb = c.rgb * _LightColor0.rgb + spec;
				
				#if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
					c.rgb *= lerp(2, atten * 2, _ShadowStrength);
					#else
					c.rgb *= 2*atten;
				#endif
				
				return c;
			}
		#endif
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _GlossMap;
		half _Shininess;
		
		struct Input {
			float2 uv_MainTex;
			fixed4 color : COLOR;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) );
			o.Albedo = c.rgb * LLDecodeGamma( _Color.rgb ) * IN.color.a;
			o.Gloss = tex2D(_GlossMap, IN.uv_MainTex).a;
			o.Alpha = c.a;
			o.Specular = _Shininess;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float2 pack0 : TEXCOORD0;
			float3 TtoW0 : TEXCOORD1;
			float3 TtoW1 : TEXCOORD2;
			float3 TtoW2 : TEXCOORD3;
		};
		
		float4 _MainTex_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			TreeVertBark (v);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
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
		#pragma target 3.0
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_prepassfinal nolightmap
		#pragma glsl_no_auto_normalization
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_PREPASSFINAL
		#include "../../../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#pragma exclude_renderers flash
		#pragma glsl_no_auto_normalization
		
		#ifndef TREE_CG_INCLUDED
			#define TREE_CG_INCLUDED
			
			#include "../TerrainEngineGoHDR.cginc"
			
			fixed4 _Color;
			fixed3 _TranslucencyColor;
			fixed _TranslucencyViewDependency;
			half _ShadowStrength;
			
			struct LeafSurfaceOutput {
				fixed3 Albedo;
				fixed3 Normal;
				fixed3 Emission;
				fixed Translucency;
				half Specular;
				fixed Gloss;
				fixed Alpha;
			};
			
			inline half4 LightingTreeLeaf (LeafSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
			{
				half3 h = normalize (lightDir + viewDir);
				
				half nl = dot (s.Normal, lightDir);
				
				half nh = max (0, dot (s.Normal, h));
				half spec = pow (nh, s.Specular * 128.0) * s.Gloss;
				
				fixed backContrib = saturate(dot(viewDir, -lightDir));
				
				backContrib = lerp(saturate(-nl), backContrib, _TranslucencyViewDependency);
				
				fixed3 translucencyColor = backContrib * s.Translucency * _TranslucencyColor;
				
				nl = max(0, nl * 0.6 + 0.4);
				
				fixed4 c;
				c.rgb = s.Albedo * (translucencyColor * 2 + nl);
				c.rgb = c.rgb * _LightColor0.rgb + spec;
				
				#if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
					c.rgb *= lerp(2, atten * 2, _ShadowStrength);
					#else
					c.rgb *= 2*atten;
				#endif
				
				return c;
			}
		#endif
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _GlossMap;
		half _Shininess;
		
		struct Input {
			float2 uv_MainTex;
			fixed4 color : COLOR;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) );
			o.Albedo = c.rgb * LLDecodeGamma( _Color.rgb ) * IN.color.a;
			o.Gloss = tex2D(_GlossMap, IN.uv_MainTex).a;
			o.Alpha = c.a;
			o.Specular = _Shininess;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
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
					#else
					float3 viewDir : TEXCOORD3;
				#endif

			#endif
		};
		
		#ifndef LIGHTMAP_OFF
			float4 unity_LightmapST;
		#endif
		
		float4 _MainTex_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			TreeVertBark (v);
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
		Name "ShadowCaster"
		Tags { "LightMode" = "ShadowCaster" }
		Fog {Mode Off}
		
		ZWrite On ZTest LEqual Cull Off
		Offset 1, 1
		
		CGPROGRAM
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_shadowcaster nolightmap
		#pragma glsl_no_auto_normalization
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_SHADOWCASTER
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#pragma exclude_renderers flash
		#pragma glsl_no_auto_normalization
		
		#ifndef TREE_CG_INCLUDED
			#define TREE_CG_INCLUDED
			
			#include "TerrainEngine.cginc"
			
			fixed4 _Color;
			fixed3 _TranslucencyColor;
			fixed _TranslucencyViewDependency;
			half _ShadowStrength;
			
			struct LeafSurfaceOutput {
				fixed3 Albedo;
				fixed3 Normal;
				fixed3 Emission;
				fixed Translucency;
				half Specular;
				fixed Gloss;
				fixed Alpha;
			};
			
			inline half4 LightingTreeLeaf (LeafSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
			{
				half3 h = normalize (lightDir + viewDir);
				
				half nl = dot (s.Normal, lightDir);
				
				half nh = max (0, dot (s.Normal, h));
				half spec = pow (nh, s.Specular * 128.0) * s.Gloss;
				
				fixed backContrib = saturate(dot(viewDir, -lightDir));
				
				backContrib = lerp(saturate(-nl), backContrib, _TranslucencyViewDependency);
				
				fixed3 translucencyColor = backContrib * s.Translucency * _TranslucencyColor;
				
				nl = max(0, nl * 0.6 + 0.4);
				
				fixed4 c;
				c.rgb = s.Albedo * (translucencyColor * 2 + nl);
				c.rgb = c.rgb * _LightColor0.rgb + spec;
				
				#if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
					c.rgb *= lerp(2, atten * 2, _ShadowStrength);
					#else
					c.rgb *= 2*atten;
				#endif
				
				return c;
			}
		#endif
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _GlossMap;
		half _Shininess;
		
		struct Input {
			float2 uv_MainTex;
			fixed4 color : COLOR;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb * _Color.rgb * IN.color.a;
			o.Gloss = tex2D(_GlossMap, IN.uv_MainTex).a;
			o.Alpha = c.a;
			o.Specular = _Shininess;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
		}
		
		struct v2f_surf {
			V2F_SHADOW_CASTER;
		};
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			TreeVertBark (v);
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
		
		#pragma exclude_renderers flash
		#pragma glsl_no_auto_normalization
		
		#ifndef TREE_CG_INCLUDED
			#define TREE_CG_INCLUDED
			
			#include "TerrainEngine.cginc"
			
			fixed4 _Color;
			fixed3 _TranslucencyColor;
			fixed _TranslucencyViewDependency;
			half _ShadowStrength;
			
			struct LeafSurfaceOutput {
				fixed3 Albedo;
				fixed3 Normal;
				fixed3 Emission;
				fixed Translucency;
				half Specular;
				fixed Gloss;
				fixed Alpha;
			};
			
			inline half4 LightingTreeLeaf (LeafSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
			{
				half3 h = normalize (lightDir + viewDir);
				
				half nl = dot (s.Normal, lightDir);
				
				half nh = max (0, dot (s.Normal, h));
				half spec = pow (nh, s.Specular * 128.0) * s.Gloss;
				
				fixed backContrib = saturate(dot(viewDir, -lightDir));
				
				backContrib = lerp(saturate(-nl), backContrib, _TranslucencyViewDependency);
				
				fixed3 translucencyColor = backContrib * s.Translucency * _TranslucencyColor;
				
				nl = max(0, nl * 0.6 + 0.4);
				
				fixed4 c;
				c.rgb = s.Albedo * (translucencyColor * 2 + nl);
				c.rgb = c.rgb * _LightColor0.rgb + spec;
				
				#if defined(DIRECTIONAL) || defined(DIRECTIONAL_COOKIE)
					c.rgb *= lerp(2, atten * 2, _ShadowStrength);
					#else
					c.rgb *= 2*atten;
				#endif
				
				return c;
			}
		#endif
		
		sampler2D _MainTex;
		sampler2D _BumpMap;
		sampler2D _GlossMap;
		half _Shininess;
		
		struct Input {
			float2 uv_MainTex;
			fixed4 color : COLOR;
		};
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
			o.Albedo = c.rgb * _Color.rgb * IN.color.a;
			o.Gloss = tex2D(_GlossMap, IN.uv_MainTex).a;
			o.Alpha = c.a;
			o.Specular = _Shininess;
			o.Normal = UnpackNormal(tex2D(_BumpMap, IN.uv_MainTex));
		}
		
		struct v2f_surf {
			V2F_SHADOW_COLLECTOR;
		};
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			TreeVertBark (v);
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

Dependency "OptimizedShader" = "Hidden/Nature/Tree Creator Bark Optimized"
Fallback "GoHDR/Diffuse"
}


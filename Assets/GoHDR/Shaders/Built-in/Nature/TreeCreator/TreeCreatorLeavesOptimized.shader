Shader "Hidden/Nature/Tree Creator Leaves Optimized" {
	Properties {
		_Color ("Main Color", Color) = (1,1,1,1)
		_TranslucencyColor ("Translucency Color", Color) = (0.73,0.85,0.41,1) 
		_Cutoff ("Alpha cutoff", Range(0,1)) = 0.3
		_TranslucencyViewDependency ("View dependency", Range(0,1)) = 0.7
		_ShadowStrength("Shadow Strength", Range(0,1)) = 0.8
		_ShadowOffsetScale ("Shadow Offset Scale", Float) = 1
		_MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}
		_ShadowTex ("Shadow (RGB)", 2D) = "white" {}
		_BumpSpecMap ("Normalmap (GA) Spec (R) Shadow Offset (B)", 2D) = "bump" {}
		_TranslucencyMap ("Trans (B) Gloss(A)", 2D) = "white" {}
		
		_Scale ("Scale", Vector) = (1,1,1,1)
		_SquashAmount ("Squash", Float) = 1
	}
	
	SubShader {
		Tags {
			"IgnoreProjector"="True"
			"RenderType"="TreeLeaf"
		}
		
		LOD 200
		
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			
			ColorMask RGB
			
			CGPROGRAM
			#include "../../../GoHDR.cginc"
			#include "../../../LinLighting.cginc"
			#pragma vertex vert_surf
			#pragma fragment frag_surf
			#pragma multi_compile_fwdbase nolightmap nodirlightmap
			#pragma glsl_no_auto_normalization
			#include "HLSLSupport.cginc"
			#include "UnityShaderVariables.cginc"
			#define UNITY_PASS_FORWARDBASE
			#include "../../../UnityCGGoHDR.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			#pragma target 3.0
			
			#define INTERNAL_DATA
			#define WorldReflectionVector(data,normal) data.worldRefl
			#define WorldNormalVector(data,normal) normal
			
			#pragma exclude_renderers flash
			#pragma glsl_no_auto_normalization
			#include "Lighting.cginc"
			
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
					
					fixed3 translucencyColor = backContrib * s.Translucency * LLDecodeGamma( _TranslucencyColor );
					
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
			sampler2D _BumpSpecMap;
			sampler2D _TranslucencyMap;
			
			struct Input {
				float2 uv_MainTex;
				fixed4 color : COLOR; 
			};
			
			void surf (Input IN, inout LeafSurfaceOutput o) {
				fixed4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) );
				o.Albedo = c.rgb * LLDecodeGamma( _Color.rgb ) * IN.color.a;
				
				fixed4 trngls = tex2D (_TranslucencyMap, IN.uv_MainTex);
				o.Translucency = trngls.b;
				o.Gloss = trngls.a * LLDecodeGamma( _Color.r );
				o.Alpha = c.a;
				
				half4 norspc = tex2D (_BumpSpecMap, IN.uv_MainTex);
				o.Specular = norspc.r;
				o.Normal = UnpackNormalDXT5nm(norspc);
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
					LIGHTING_COORDS(2,3)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				float4 unity_LightmapST;
			#endif
			
			float4 _MainTex_ST;
			
			v2f_surf vert_surf (appdata_full v) {
				v2f_surf o;
				TreeVertLeaf (v);
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
				
				#ifdef LIGHTMAP_OFF
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
				surfIN.color = IN.color;
				
				#ifdef UNITY_COMPILER_HLSL
					LeafSurfaceOutput o = (LeafSurfaceOutput)0;
					#else
					LeafSurfaceOutput o;
				#endif
				
				o.Albedo = 0.0;
				o.Emission = 0.0;
				o.Specular = 0.0;
				o.Alpha = 0.0;
				surf (surfIN, o);
				clip (o.Alpha - _Cutoff);
				fixed atten = LIGHT_ATTENUATION(IN);
				fixed4 c = 0;
				
				#ifdef LIGHTMAP_OFF
					c = LightingTreeLeaf (o, IN.lightDir, normalize(half3(IN.viewDir)), atten);
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
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_fwdadd nolightmap nodirlightmap
		#pragma glsl_no_auto_normalization
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_FORWARDADD
		#include "../../../UnityCGGoHDR.cginc"
		#include "Lighting.cginc"
		#include "AutoLight.cginc"
		
		#pragma target 3.0
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#pragma exclude_renderers flash
		#pragma glsl_no_auto_normalization
		#include "Lighting.cginc"
		
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
				
				fixed3 translucencyColor = backContrib * s.Translucency * LLDecodeGamma( _TranslucencyColor );
				
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
		sampler2D _BumpSpecMap;
		sampler2D _TranslucencyMap;
		
		struct Input {
			float2 uv_MainTex;
			fixed4 color : COLOR; 
		};
		
		void surf (Input IN, inout LeafSurfaceOutput o) {
			fixed4 c = LLDecodeTex( tex2D(_MainTex, IN.uv_MainTex) );
			o.Albedo = c.rgb * LLDecodeGamma( _Color.rgb ) * IN.color.a;
			
			fixed4 trngls = tex2D (_TranslucencyMap, IN.uv_MainTex);
			o.Translucency = trngls.b;
			o.Gloss = trngls.a * LLDecodeGamma( _Color.r );
			o.Alpha = c.a;
			
			half4 norspc = tex2D (_BumpSpecMap, IN.uv_MainTex);
			o.Specular = norspc.r;
			o.Normal = UnpackNormalDXT5nm(norspc);
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
			TreeVertLeaf (v);
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
		
		fixed _Cutoff;
		
		fixed4 frag_surf (v2f_surf IN) : COLOR {
			
			#ifdef UNITY_COMPILER_HLSL
				Input surfIN = (Input)0;
				#else
				Input surfIN;
			#endif
			
			surfIN.uv_MainTex = IN.pack0.xy;
			surfIN.color = IN.color;
			
			#ifdef UNITY_COMPILER_HLSL
				LeafSurfaceOutput o = (LeafSurfaceOutput)0;
				#else
				LeafSurfaceOutput o;
			#endif
			
			o.Albedo = 0.0;
			o.Emission = 0.0;
			o.Specular = 0.0;
			o.Alpha = 0.0;
			surf (surfIN, o);
			clip (o.Alpha - _Cutoff);
			
			#ifndef USING_DIRECTIONAL_LIGHT
				fixed3 lightDir = normalize(IN.lightDir);
				#else
				fixed3 lightDir = IN.lightDir;
			#endif
			
			fixed4 c = LightingTreeLeaf (o, lightDir, normalize(half3(IN.viewDir)), LIGHT_ATTENUATION(IN));
			c.a = o.Alpha;
			
			return LLEncodeGamma( GoHDRApplyCorrection( c ) );
		}
		
		ENDCG
	}
	
	// Pass to render object as a shadow caster
	Pass {
		Name "ShadowCaster"
		Tags { "LightMode" = "ShadowCaster" }
		
		Fog {Mode Off}
		ZWrite On ZTest LEqual Cull Off
		Offset 1, 1

		CGPROGRAM
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma exclude_renderers noshadows flash
		#pragma glsl_no_auto_normalization
		#pragma multi_compile_shadowcaster
		#include "HLSLSupport.cginc"
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		
		#include "../../../LinLighting.cginc"

		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl

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
					
					fixed3 translucencyColor = backContrib * s.Translucency * LLDecodeGamma( _TranslucencyColor );
					
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


		sampler2D _ShadowTex;

		struct Input {
			float2 uv_MainTex;
		};

		struct v2f_surf {
			V2F_SHADOW_CASTER;
			float2 hip_pack0 : TEXCOORD1;
		};
		float4 _ShadowTex_ST;
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			TreeVertLeaf (v);
			o.hip_pack0.xy = TRANSFORM_TEX(v.texcoord, _ShadowTex);
			TRANSFER_SHADOW_CASTER(o)
			return o;
		}
		fixed _Cutoff;
		float4 frag_surf (v2f_surf IN) : COLOR {
			half alpha = tex2D(_ShadowTex, IN.hip_pack0.xy).r;
			clip (alpha - _Cutoff);
			SHADOW_CASTER_FRAGMENT(IN)
		}
		ENDCG
	}
	
	// Pass to render object as a shadow collector
	Pass {
		Name "ShadowCollector"
		Tags { "LightMode" = "ShadowCollector" }
		
		Fog {Mode Off}
		ZWrite On ZTest LEqual

		CGPROGRAM
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma exclude_renderers noshadows flash
		#pragma multi_compile_shadowcollector
		#pragma glsl_no_auto_normalization
		#include "HLSLSupport.cginc"
		#define SHADOW_COLLECTOR_PASS
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		
		#include "../../../LinLighting.cginc"

		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl

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
					
					fixed3 translucencyColor = backContrib * s.Translucency * LLDecodeGamma( _TranslucencyColor );
					
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
		sampler2D _BumpSpecMap;
		sampler2D _TranslucencyMap;
		float _ShadowOffsetScale;

		struct Input {
			float2 uv_MainTex;
		};

		struct v2f_surf {
			V2F_SHADOW_COLLECTOR;
			float2 hip_pack0 : TEXCOORD5;
			float3 normal : TEXCOORD6;
		};
		
		float4 _MainTex_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			TreeVertLeaf (v);
			o.hip_pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			
			float3 worldN = mul((float3x3)_Object2World, SCALED_NORMAL);
			o.normal = mul(_World2Shadow, half4(worldN, 0)).xyz;

			TRANSFER_SHADOW_COLLECTOR(o)
			return o;
		}
		
		fixed _Cutoff;
		
		half4 frag_surf (v2f_surf IN) : COLOR {
			half alpha = tex2D(_MainTex, IN.hip_pack0.xy).a;

			float3 shadowOffset = _ShadowOffsetScale * IN.normal * tex2D (_BumpSpecMap, IN.hip_pack0.xy).b;
			clip (alpha - _Cutoff);

			IN._ShadowCoord0 += shadowOffset;
			IN._ShadowCoord1 += shadowOffset;
			IN._ShadowCoord2 += shadowOffset;
			IN._ShadowCoord3 += shadowOffset;

			SHADOW_COLLECTOR_FRAGMENT(IN)
		}
		ENDCG
	}
}

SubShader {
	Tags {
		"IgnoreProjector"="True"
		"RenderType"="TreeLeaf"
	}
	
	ColorMask RGB
	Lighting On
	
	Pass {
		
		#LINE 431
		
		AlphaTest Greater [_Cutoff]
		SetTexture [_MainTex] { combine texture * primary DOUBLE, texture }
		
		SetTexture [_MainTex] {
			ConstantColor [_Color]
			Combine previous * constant, previous
		} 
	}
}

Dependency "BillboardShader" = "Hidden/Nature/Tree Creator Leaves Rendertex"
}


//Original shader:

//Shader "Hidden/Nature/Tree Creator Leaves Optimized" {
//Properties {
//	_Color ("Main Color", Color) = (1,1,1,1)
//	_TranslucencyColor ("Translucency Color", Color) = (0.73,0.85,0.41,1) // (187,219,106,255)
//	_Cutoff ("Alpha cutoff", Range(0,1)) = 0.3
//	_TranslucencyViewDependency ("View dependency", Range(0,1)) = 0.7
//	_ShadowStrength("Shadow Strength", Range(0,1)) = 0.8
//	_ShadowOffsetScale ("Shadow Offset Scale", Float) = 1
//	
//	_MainTex ("Base (RGB) Alpha (A)", 2D) = "white" {}
//	_ShadowTex ("Shadow (RGB)", 2D) = "white" {}
//	_BumpSpecMap ("Normalmap (GA) Spec (R) Shadow Offset (B)", 2D) = "bump" {}
//	_TranslucencyMap ("Trans (B) Gloss(A)", 2D) = "white" {}
//
//	// These are here only to provide default values
//	_Scale ("Scale", Vector) = (1,1,1,1)
//	_SquashAmount ("Squash", Float) = 1
//}
//
//SubShader { 
//	Tags {
//		"IgnoreProjector"="True"
//		"RenderType"="TreeLeaf"
//	}
//	LOD 200
//	
//CGPROGRAM
//#pragma surface surf TreeLeaf alphatest:_Cutoff vertex:TreeVertLeaf nolightmap
//#pragma exclude_renderers flash
//#pragma glsl_no_auto_normalization
//#include "Lighting.cginc"
//#include "Tree.cginc"
//
//sampler2D _MainTex;
//sampler2D _BumpSpecMap;
//sampler2D _TranslucencyMap;
//
//struct Input {
//	float2 uv_MainTex;
//	fixed4 color : COLOR; // color.a = AO
//};
//
//void surf (Input IN, inout LeafSurfaceOutput o) {
//	fixed4 c = tex2D(_MainTex, IN.uv_MainTex);
//	o.Albedo = c.rgb * _Color.rgb * IN.color.a;
//	
//	fixed4 trngls = tex2D (_TranslucencyMap, IN.uv_MainTex);
//	o.Translucency = trngls.b;
//	o.Gloss = trngls.a * _Color.r;
//	o.Alpha = c.a;
//	
//	half4 norspc = tex2D (_BumpSpecMap, IN.uv_MainTex);
//	o.Specular = norspc.r;
//	o.Normal = UnpackNormalDXT5nm(norspc);
//}
//ENDCG
//
//	// Pass to render object as a shadow caster
//	Pass {
//		Name "ShadowCaster"
//		Tags { "LightMode" = "ShadowCaster" }
//		
//		Fog {Mode Off}
//		ZWrite On ZTest LEqual Cull Off
//		Offset 1, 1
//
//		CGPROGRAM
//		#pragma vertex vert_surf
//		#pragma fragment frag_surf
//		#pragma exclude_renderers noshadows flash
//		#pragma glsl_no_auto_normalization
//		#pragma multi_compile_shadowcaster
//		#include "HLSLSupport.cginc"
//		#include "UnityCG.cginc"
//		#include "Lighting.cginc"
//
//		#define INTERNAL_DATA
//		#define WorldReflectionVector(data,normal) data.worldRefl
//
//		#include "Tree.cginc"
//
//		sampler2D _ShadowTex;
//
//		struct Input {
//			float2 uv_MainTex;
//		};
//
//		struct v2f_surf {
//			V2F_SHADOW_CASTER;
//			float2 hip_pack0 : TEXCOORD1;
//		};
//		float4 _ShadowTex_ST;
//		v2f_surf vert_surf (appdata_full v) {
//			v2f_surf o;
//			TreeVertLeaf (v);
//			o.hip_pack0.xy = TRANSFORM_TEX(v.texcoord, _ShadowTex);
//			TRANSFER_SHADOW_CASTER(o)
//			return o;
//		}
//		fixed _Cutoff;
//		float4 frag_surf (v2f_surf IN) : COLOR {
//			half alpha = tex2D(_ShadowTex, IN.hip_pack0.xy).r;
//			clip (alpha - _Cutoff);
//			SHADOW_CASTER_FRAGMENT(IN)
//		}
//		ENDCG
//	}
//	
//	// Pass to render object as a shadow collector
//	Pass {
//		Name "ShadowCollector"
//		Tags { "LightMode" = "ShadowCollector" }
//		
//		Fog {Mode Off}
//		ZWrite On ZTest LEqual
//
//		CGPROGRAM
//		#pragma vertex vert_surf
//		#pragma fragment frag_surf
//		#pragma exclude_renderers noshadows flash
//		#pragma multi_compile_shadowcollector
//		#pragma glsl_no_auto_normalization
//		#include "HLSLSupport.cginc"
//		#define SHADOW_COLLECTOR_PASS
//		#include "UnityCG.cginc"
//		#include "Lighting.cginc"
//
//		#define INTERNAL_DATA
//		#define WorldReflectionVector(data,normal) data.worldRefl
//
//		#include "Tree.cginc"
//
//		sampler2D _MainTex;
//		sampler2D _BumpSpecMap;
//		sampler2D _TranslucencyMap;
//		float _ShadowOffsetScale;
//
//		struct Input {
//			float2 uv_MainTex;
//		};
//
//		struct v2f_surf {
//			V2F_SHADOW_COLLECTOR;
//			float2 hip_pack0 : TEXCOORD5;
//			float3 normal : TEXCOORD6;
//		};
//		
//		float4 _MainTex_ST;
//		
//		v2f_surf vert_surf (appdata_full v) {
//			v2f_surf o;
//			TreeVertLeaf (v);
//			o.hip_pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
//			
//			float3 worldN = mul((float3x3)_Object2World, SCALED_NORMAL);
//			o.normal = mul(_World2Shadow, half4(worldN, 0)).xyz;
//
//			TRANSFER_SHADOW_COLLECTOR(o)
//			return o;
//		}
//		
//		fixed _Cutoff;
//		
//		half4 frag_surf (v2f_surf IN) : COLOR {
//			half alpha = tex2D(_MainTex, IN.hip_pack0.xy).a;
//
//			float3 shadowOffset = _ShadowOffsetScale * IN.normal * tex2D (_BumpSpecMap, IN.hip_pack0.xy).b;
//			clip (alpha - _Cutoff);
//
//			IN._ShadowCoord0 += shadowOffset;
//			IN._ShadowCoord1 += shadowOffset;
//			IN._ShadowCoord2 += shadowOffset;
//			IN._ShadowCoord3 += shadowOffset;
//
//			SHADOW_COLLECTOR_FRAGMENT(IN)
//		}
//		ENDCG
//	}
//}
//
//SubShader {
//	Tags {
//		"IgnoreProjector"="True"
//		"RenderType"="TreeLeaf"
//	}
//	
//	ColorMask RGB
//	Lighting On
//	
//	Pass {
//		CGPROGRAM
//		#pragma vertex TreeVertLit
//		#pragma exclude_renderers shaderonly
//		
//		#include "UnityCG.cginc"
//		#include "Lighting.cginc"
//		#include "Tree.cginc"
//		
//		struct v2f {
//			float4 pos : SV_POSITION;
//			fixed4 color : COLOR;
//			float4 uv : TEXCOORD0;
//		};
//		
//		v2f TreeVertLit (appdata_full v) {
//			v2f o;
//			TreeVertLeaf(v);
//
//			o.color.rgb = ShadeVertexLights (v.vertex, v.normal);
//				
//			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);	
//			o.uv = v.texcoord;
//			o.color.a = 1.0f;
//			return o;
//		}
//		ENDCG
//
//		AlphaTest Greater [_Cutoff]
//		SetTexture [_MainTex] { combine texture * primary DOUBLE, texture }
//		SetTexture [_MainTex] {
//			ConstantColor [_Color]
//			Combine previous * constant, previous
//		} 
//	}
//}
//Dependency "BillboardShader" = "Hidden/Nature/Tree Creator Leaves Rendertex"
//}

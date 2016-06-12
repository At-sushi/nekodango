Shader "GoHDR/Enviro/DoubleBumpedMetalic" {
	Properties {
		_MainTex("Base (RGB) Gloss (A)", 2D) = "white" {}
		_DecalTex("Decal", 2D) = "white" {}
		_BumpMap("Normalmap", 2D) = "bump" {}
		_BumpMapDetail("Normal Detail", 2D) = "bump" {}
		
		_Shininess("_Shininess", Range(0.01,1) ) = 0.5
		_Color("_Color", Color) = (1,1,1,1)
	}
	
	SubShader {
		Tags
		{
			"Queue"="Geometry"
			"IgnoreProjector"="False"
			"RenderType"="Opaque"
		}
		
		Cull Back
		ZWrite On
		ZTest LEqual
		ColorMask RGBA
		Fog{
		}
		
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			
			CGPROGRAM
			#pragma target 3.0
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
			
			sampler2D _MainTex;
			sampler2D _DecalTex;
			sampler2D _BumpMap;
			sampler2D _BumpMapDetail;
			float _Shininess;
			float4 _Color;
			
			struct EditorSurfaceOutput {
				half3 Albedo;
				half3 Normal;
				half3 Emission;
				half3 Gloss;
				half Specular;
				half Alpha;
				half4 Custom;
			};
			
			inline half4 LightingBlinnPhongEditor_PrePass (EditorSurfaceOutput s, half4 light)
			{
				half3 spec = light.a * s.Gloss;
				half4 c;
				c.rgb = (s.Albedo * light.rgb + light.rgb * spec);
				c.a = s.Alpha;
				return c;
			}
			
			inline half4 LightingBlinnPhongEditor (EditorSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
			{
				half3 h = normalize (lightDir + viewDir);
				
				half diff = max (0, dot ( lightDir, s.Normal ));
				
				float nh = max (0, dot (s.Normal, h));
				float spec = pow (nh, s.Specular*128.0);
				
				half4 res;
				res.rgb = _LightColor0.rgb * diff;
				res.w = spec * Luminance (_LightColor0.rgb);
				res *= atten * 2.0;
				
				return LightingBlinnPhongEditor_PrePass( s, res );
			}
			
			inline half4 LightingBlinnPhongEditor_DirLightmap (EditorSurfaceOutput s, fixed4 color, fixed4 scale, half3 viewDir, bool surfFuncWritesNormal, out half3 specColor)
			{
				UNITY_DIRBASIS
				half3 scalePerBasisVector;
				
				half3 lm = DirLightmapDiffuse (unity_DirBasis, color, scale, s.Normal, surfFuncWritesNormal, scalePerBasisVector);
				
				half3 lightDir = normalize (scalePerBasisVector.x * unity_DirBasis[0] + scalePerBasisVector.y * unity_DirBasis[1] + scalePerBasisVector.z * unity_DirBasis[2]);
				half3 h = normalize (lightDir + viewDir);
				
				float nh = max (0, dot (s.Normal, h));
				float spec = pow (nh, s.Specular * 128.0);
				
				specColor = lm * _SpecColor.rgb * s.Gloss * spec;
				
				return half4(lm, spec);
			}
			
			struct Input {
				float2 uv_MainTex;
				float2 uv_DecalTex;
				float2 uv_BumpMap;
				float2 uv_BumpMapDetail;
			};
			
			void vert (inout appdata_full v, out Input o) {
				float4 VertexOutputMaster0_0_NoInput = float4(0,0,0,0);
				float4 VertexOutputMaster0_1_NoInput = float4(0,0,0,0);
				float4 VertexOutputMaster0_2_NoInput = float4(0,0,0,0);
				float4 VertexOutputMaster0_3_NoInput = float4(0,0,0,0);
			}
			
			void surf (Input IN, inout EditorSurfaceOutput o) {
				o.Normal = float3(0.0,0.0,1.0);
				o.Alpha = 1.0;
				o.Albedo = 0.0;
				o.Emission = 0.0;
				o.Gloss = 0.0;
				o.Specular = 0.0;
				o.Custom = 0.0;
				
				float4 Sampled2D0=LLDecodeTex( tex2D(_MainTex,IN.uv_MainTex.xy) );
				float4 Sampled2D3=LLDecodeTex( tex2D(_DecalTex,IN.uv_DecalTex.xy) );
				float4 Multiply1=Sampled2D0 * Sampled2D3;
				float4 Multiply3=Multiply1 * LLDecodeGamma( _Color );
				float4 Tex2DNormal1=float4(UnpackNormal( tex2D(_BumpMap,(IN.uv_BumpMap.xyxy).xy)).xyz, 1.0 );
				float4 Tex2DNormal0=float4(UnpackNormal( tex2D(_BumpMapDetail,(IN.uv_BumpMapDetail.xyxy).xy)).xyz, 1.0 );
				float4 Add0=Tex2DNormal1 + Tex2DNormal0;
				float4 Master0_2_NoInput = float4(0,0,0,0);
				float4 Master0_5_NoInput = float4(1,1,1,1);
				float4 Master0_7_NoInput = float4(0,0,0,0);
				float4 Master0_6_NoInput = float4(1,1,1,1);
				o.Albedo = Multiply3;
				o.Normal = Add0;
				o.Specular = _Shininess.xxxx;
				o.Gloss = Multiply3;
				
				o.Normal = normalize(o.Normal);
			}
			
			#ifdef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					float4 pack1 : TEXCOORD1;
					fixed3 lightDir : TEXCOORD2;
					fixed3 vlight : TEXCOORD3;
					float3 viewDir : TEXCOORD4;
					LIGHTING_COORDS(5,6)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					float4 pack1 : TEXCOORD1;
					float2 lmap : TEXCOORD2;
					
					#ifndef DIRLIGHTMAP_OFF
						float3 viewDir : TEXCOORD3;
						LIGHTING_COORDS(4,5)
						#else
						LIGHTING_COORDS(3,4)
					#endif
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				float4 unity_LightmapST;
			#endif
			
			float4 _MainTex_ST;
			float4 _DecalTex_ST;
			float4 _BumpMap_ST;
			float4 _BumpMapDetail_ST;
			
			v2f_surf vert_surf (appdata_full v) {
				v2f_surf o;
				Input customInputData;
				vert (v, customInputData);
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
				o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
				o.pack0.zw = TRANSFORM_TEX(v.texcoord, _DecalTex);
				o.pack1.xy = TRANSFORM_TEX(v.texcoord, _BumpMap);
				o.pack1.zw = TRANSFORM_TEX(v.texcoord, _BumpMapDetail);
				
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
				surfIN.uv_DecalTex = IN.pack0.zw;
				surfIN.uv_BumpMap = IN.pack1.xy;
				surfIN.uv_BumpMapDetail = IN.pack1.zw;
				
				#ifdef UNITY_COMPILER_HLSL
					EditorSurfaceOutput o = (EditorSurfaceOutput)0;
					#else
					EditorSurfaceOutput o;
				#endif
				
				o.Albedo = 0.0;
				o.Emission = 0.0;
				o.Specular = 0.0;
				o.Alpha = 0.0;
				surf (surfIN, o);
				fixed atten = LIGHT_ATTENUATION(IN);
				fixed4 c = 0;
				
				#ifdef LIGHTMAP_OFF
					c = LightingBlinnPhongEditor (o, IN.lightDir, normalize(half3(IN.viewDir)), atten);
				#endif
				
				#ifdef LIGHTMAP_OFF
					c.rgb += o.Albedo * IN.vlight;
				#endif
				
				#ifndef LIGHTMAP_OFF
					
					#ifndef DIRLIGHTMAP_OFF
						half3 specColor;
						fixed4 lmtex = tex2D(unity_Lightmap, IN.lmap.xy);
						fixed4 lmIndTex = tex2D(unity_LightmapInd, IN.lmap.xy);
						half3 lm = LightingBlinnPhongEditor_DirLightmap(o, lmtex, lmIndTex, normalize(half3(IN.viewDir)), 1, specColor).rgb;
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
			
			c.rgb += o.Emission;
			
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
		
		sampler2D _MainTex;
		sampler2D _DecalTex;
		sampler2D _BumpMap;
		sampler2D _BumpMapDetail;
		float _Shininess;
		float4 _Color;
		
		struct EditorSurfaceOutput {
			half3 Albedo;
			half3 Normal;
			half3 Emission;
			half3 Gloss;
			half Specular;
			half Alpha;
			half4 Custom;
		};
		
		inline half4 LightingBlinnPhongEditor_PrePass (EditorSurfaceOutput s, half4 light)
		{
			half3 spec = light.a * s.Gloss;
			half4 c;
			c.rgb = (s.Albedo * light.rgb + light.rgb * spec);
			c.a = s.Alpha;
			return c;
		}
		
		inline half4 LightingBlinnPhongEditor (EditorSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
		{
			half3 h = normalize (lightDir + viewDir);
			
			half diff = max (0, dot ( lightDir, s.Normal ));
			
			float nh = max (0, dot (s.Normal, h));
			float spec = pow (nh, s.Specular*128.0);
			
			half4 res;
			res.rgb = _LightColor0.rgb * diff;
			res.w = spec * Luminance (_LightColor0.rgb);
			res *= atten * 2.0;
			
			return LightingBlinnPhongEditor_PrePass( s, res );
		}
		
		inline half4 LightingBlinnPhongEditor_DirLightmap (EditorSurfaceOutput s, fixed4 color, fixed4 scale, half3 viewDir, bool surfFuncWritesNormal, out half3 specColor)
		{
			UNITY_DIRBASIS
			half3 scalePerBasisVector;
			
			half3 lm = DirLightmapDiffuse (unity_DirBasis, color, scale, s.Normal, surfFuncWritesNormal, scalePerBasisVector);
			
			half3 lightDir = normalize (scalePerBasisVector.x * unity_DirBasis[0] + scalePerBasisVector.y * unity_DirBasis[1] + scalePerBasisVector.z * unity_DirBasis[2]);
			half3 h = normalize (lightDir + viewDir);
			
			float nh = max (0, dot (s.Normal, h));
			float spec = pow (nh, s.Specular * 128.0);
			
			specColor = lm * _SpecColor.rgb * s.Gloss * spec;
			
			return half4(lm, spec);
		}
		
		struct Input {
			float2 uv_MainTex;
			float2 uv_DecalTex;
			float2 uv_BumpMap;
			float2 uv_BumpMapDetail;
		};
		
		void vert (inout appdata_full v, out Input o) {
			float4 VertexOutputMaster0_0_NoInput = float4(0,0,0,0);
			float4 VertexOutputMaster0_1_NoInput = float4(0,0,0,0);
			float4 VertexOutputMaster0_2_NoInput = float4(0,0,0,0);
			float4 VertexOutputMaster0_3_NoInput = float4(0,0,0,0);
		}
		
		void surf (Input IN, inout EditorSurfaceOutput o) {
			o.Normal = float3(0.0,0.0,1.0);
			o.Alpha = 1.0;
			o.Albedo = 0.0;
			o.Emission = 0.0;
			o.Gloss = 0.0;
			o.Specular = 0.0;
			o.Custom = 0.0;
			
			float4 Sampled2D0=LLDecodeTex( tex2D(_MainTex,IN.uv_MainTex.xy) );
			float4 Sampled2D3=LLDecodeTex( tex2D(_DecalTex,IN.uv_DecalTex.xy) );
			float4 Multiply1=Sampled2D0 * Sampled2D3;
			float4 Multiply3=Multiply1 * LLDecodeGamma( _Color );
			float4 Tex2DNormal1=float4(UnpackNormal( tex2D(_BumpMap,(IN.uv_BumpMap.xyxy).xy)).xyz, 1.0 );
			float4 Tex2DNormal0=float4(UnpackNormal( tex2D(_BumpMapDetail,(IN.uv_BumpMapDetail.xyxy).xy)).xyz, 1.0 );
			float4 Add0=Tex2DNormal1 + Tex2DNormal0;
			float4 Master0_2_NoInput = float4(0,0,0,0);
			float4 Master0_5_NoInput = float4(1,1,1,1);
			float4 Master0_7_NoInput = float4(0,0,0,0);
			float4 Master0_6_NoInput = float4(1,1,1,1);
			o.Albedo = Multiply3;
			o.Normal = Add0;
			o.Specular = _Shininess.xxxx;
			o.Gloss = Multiply3;
			
			o.Normal = normalize(o.Normal);
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			float4 pack1 : TEXCOORD1;
			half3 lightDir : TEXCOORD2;
			half3 viewDir : TEXCOORD3;
			LIGHTING_COORDS(4,5)
		};
		
		float4 _MainTex_ST;
		float4 _DecalTex_ST;
		float4 _BumpMap_ST;
		float4 _BumpMapDetail_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			Input customInputData;
			vert (v, customInputData);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _DecalTex);
			o.pack1.xy = TRANSFORM_TEX(v.texcoord, _BumpMap);
			o.pack1.zw = TRANSFORM_TEX(v.texcoord, _BumpMapDetail);
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
			surfIN.uv_DecalTex = IN.pack0.zw;
			surfIN.uv_BumpMap = IN.pack1.xy;
			surfIN.uv_BumpMapDetail = IN.pack1.zw;
			
			#ifdef UNITY_COMPILER_HLSL
				EditorSurfaceOutput o = (EditorSurfaceOutput)0;
				#else
				EditorSurfaceOutput o;
			#endif
			
			o.Albedo = 0.0;
			o.Emission = 0.0;
			o.Specular = 0.0;
			o.Alpha = 0.0;
			surf (surfIN, o);
			
			#ifndef USING_DIRECTIONAL_LIGHT
				fixed3 lightDir = normalize(IN.lightDir);
				#else
				fixed3 lightDir = IN.lightDir;
			#endif
			
			fixed4 c = LightingBlinnPhongEditor (o, lightDir, normalize(half3(IN.viewDir)), LIGHT_ATTENUATION(IN));
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
		
		sampler2D _MainTex;
		sampler2D _DecalTex;
		sampler2D _BumpMap;
		sampler2D _BumpMapDetail;
		float _Shininess;
		float4 _Color;
		
		struct EditorSurfaceOutput {
			half3 Albedo;
			half3 Normal;
			half3 Emission;
			half3 Gloss;
			half Specular;
			half Alpha;
			half4 Custom;
		};
		
		inline half4 LightingBlinnPhongEditor_PrePass (EditorSurfaceOutput s, half4 light)
		{
			half3 spec = light.a * s.Gloss;
			half4 c;
			c.rgb = (s.Albedo * light.rgb + light.rgb * spec);
			c.a = s.Alpha;
			return c;
		}
		
		inline half4 LightingBlinnPhongEditor (EditorSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
		{
			half3 h = normalize (lightDir + viewDir);
			
			half diff = max (0, dot ( lightDir, s.Normal ));
			
			float nh = max (0, dot (s.Normal, h));
			float spec = pow (nh, s.Specular*128.0);
			
			half4 res;
			res.rgb = _LightColor0.rgb * diff;
			res.w = spec * Luminance (_LightColor0.rgb);
			res *= atten * 2.0;
			
			return LightingBlinnPhongEditor_PrePass( s, res );
		}
		
		inline half4 LightingBlinnPhongEditor_DirLightmap (EditorSurfaceOutput s, fixed4 color, fixed4 scale, half3 viewDir, bool surfFuncWritesNormal, out half3 specColor)
		{
			UNITY_DIRBASIS
			half3 scalePerBasisVector;
			
			half3 lm = DirLightmapDiffuse (unity_DirBasis, color, scale, s.Normal, surfFuncWritesNormal, scalePerBasisVector);
			
			half3 lightDir = normalize (scalePerBasisVector.x * unity_DirBasis[0] + scalePerBasisVector.y * unity_DirBasis[1] + scalePerBasisVector.z * unity_DirBasis[2]);
			half3 h = normalize (lightDir + viewDir);
			
			float nh = max (0, dot (s.Normal, h));
			float spec = pow (nh, s.Specular * 128.0);
			
			specColor = lm * _SpecColor.rgb * s.Gloss * spec;
			
			return half4(lm, spec);
		}
		
		struct Input {
			float2 uv_MainTex;
			float2 uv_DecalTex;
			float2 uv_BumpMap;
			float2 uv_BumpMapDetail;
		};
		
		void vert (inout appdata_full v, out Input o) {
			float4 VertexOutputMaster0_0_NoInput = float4(0,0,0,0);
			float4 VertexOutputMaster0_1_NoInput = float4(0,0,0,0);
			float4 VertexOutputMaster0_2_NoInput = float4(0,0,0,0);
			float4 VertexOutputMaster0_3_NoInput = float4(0,0,0,0);
		}
		
		void surf (Input IN, inout EditorSurfaceOutput o) {
			o.Normal = float3(0.0,0.0,1.0);
			o.Alpha = 1.0;
			o.Albedo = 0.0;
			o.Emission = 0.0;
			o.Gloss = 0.0;
			o.Specular = 0.0;
			o.Custom = 0.0;
			
			float4 Sampled2D0=LLDecodeTex( tex2D(_MainTex,IN.uv_MainTex.xy) );
			float4 Sampled2D3=LLDecodeTex( tex2D(_DecalTex,IN.uv_DecalTex.xy) );
			float4 Multiply1=Sampled2D0 * Sampled2D3;
			float4 Multiply3=Multiply1 * LLDecodeGamma( _Color );
			float4 Tex2DNormal1=float4(UnpackNormal( tex2D(_BumpMap,(IN.uv_BumpMap.xyxy).xy)).xyz, 1.0 );
			float4 Tex2DNormal0=float4(UnpackNormal( tex2D(_BumpMapDetail,(IN.uv_BumpMapDetail.xyxy).xy)).xyz, 1.0 );
			float4 Add0=Tex2DNormal1 + Tex2DNormal0;
			float4 Master0_2_NoInput = float4(0,0,0,0);
			float4 Master0_5_NoInput = float4(1,1,1,1);
			float4 Master0_7_NoInput = float4(0,0,0,0);
			float4 Master0_6_NoInput = float4(1,1,1,1);
			o.Albedo = Multiply3;
			o.Normal = Add0;
			o.Specular = _Shininess.xxxx;
			o.Gloss = Multiply3;
			
			o.Normal = normalize(o.Normal);
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			float3 TtoW0 : TEXCOORD1;
			float3 TtoW1 : TEXCOORD2;
			float3 TtoW2 : TEXCOORD3;
		};
		
		float4 _BumpMap_ST;
		float4 _BumpMapDetail_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			Input customInputData;
			vert (v, customInputData);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _BumpMap);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _BumpMapDetail);
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
			surfIN.uv_BumpMapDetail = IN.pack0.zw;
			
			#ifdef UNITY_COMPILER_HLSL
				EditorSurfaceOutput o = (EditorSurfaceOutput)0;
				#else
				EditorSurfaceOutput o;
			#endif
			
			o.Albedo = 0.0;
			o.Emission = 0.0;
			o.Specular = 0.0;
			o.Alpha = 0.0;
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
		
		sampler2D _MainTex;
		sampler2D _DecalTex;
		sampler2D _BumpMap;
		sampler2D _BumpMapDetail;
		float _Shininess;
		float4 _Color;
		
		struct EditorSurfaceOutput {
			half3 Albedo;
			half3 Normal;
			half3 Emission;
			half3 Gloss;
			half Specular;
			half Alpha;
			half4 Custom;
		};
		
		inline half4 LightingBlinnPhongEditor_PrePass (EditorSurfaceOutput s, half4 light)
		{
			half3 spec = light.a * s.Gloss;
			half4 c;
			c.rgb = (s.Albedo * light.rgb + light.rgb * spec);
			c.a = s.Alpha;
			return c;
		}
		
		inline half4 LightingBlinnPhongEditor (EditorSurfaceOutput s, half3 lightDir, half3 viewDir, half atten)
		{
			half3 h = normalize (lightDir + viewDir);
			
			half diff = max (0, dot ( lightDir, s.Normal ));
			
			float nh = max (0, dot (s.Normal, h));
			float spec = pow (nh, s.Specular*128.0);
			
			half4 res;
			res.rgb = _LightColor0.rgb * diff;
			res.w = spec * Luminance (_LightColor0.rgb);
			res *= atten * 2.0;
			
			return LightingBlinnPhongEditor_PrePass( s, res );
		}
		
		inline half4 LightingBlinnPhongEditor_DirLightmap (EditorSurfaceOutput s, fixed4 color, fixed4 scale, half3 viewDir, bool surfFuncWritesNormal, out half3 specColor)
		{
			UNITY_DIRBASIS
			half3 scalePerBasisVector;
			
			half3 lm = DirLightmapDiffuse (unity_DirBasis, color, scale, s.Normal, surfFuncWritesNormal, scalePerBasisVector);
			
			half3 lightDir = normalize (scalePerBasisVector.x * unity_DirBasis[0] + scalePerBasisVector.y * unity_DirBasis[1] + scalePerBasisVector.z * unity_DirBasis[2]);
			half3 h = normalize (lightDir + viewDir);
			
			float nh = max (0, dot (s.Normal, h));
			float spec = pow (nh, s.Specular * 128.0);
			
			specColor = lm * _SpecColor.rgb * s.Gloss * spec;
			
			return half4(lm, spec);
		}
		
		struct Input {
			float2 uv_MainTex;
			float2 uv_DecalTex;
			float2 uv_BumpMap;
			float2 uv_BumpMapDetail;
		};
		
		void vert (inout appdata_full v, out Input o) {
			float4 VertexOutputMaster0_0_NoInput = float4(0,0,0,0);
			float4 VertexOutputMaster0_1_NoInput = float4(0,0,0,0);
			float4 VertexOutputMaster0_2_NoInput = float4(0,0,0,0);
			float4 VertexOutputMaster0_3_NoInput = float4(0,0,0,0);
		}
		
		void surf (Input IN, inout EditorSurfaceOutput o) {
			o.Normal = float3(0.0,0.0,1.0);
			o.Alpha = 1.0;
			o.Albedo = 0.0;
			o.Emission = 0.0;
			o.Gloss = 0.0;
			o.Specular = 0.0;
			o.Custom = 0.0;
			
			float4 Sampled2D0=LLDecodeTex( tex2D(_MainTex,IN.uv_MainTex.xy) );
			float4 Sampled2D3=LLDecodeTex( tex2D(_DecalTex,IN.uv_DecalTex.xy) );
			float4 Multiply1=Sampled2D0 * Sampled2D3;
			float4 Multiply3=Multiply1 * LLDecodeGamma( _Color );
			float4 Tex2DNormal1=float4(UnpackNormal( tex2D(_BumpMap,(IN.uv_BumpMap.xyxy).xy)).xyz, 1.0 );
			float4 Tex2DNormal0=float4(UnpackNormal( tex2D(_BumpMapDetail,(IN.uv_BumpMapDetail.xyxy).xy)).xyz, 1.0 );
			float4 Add0=Tex2DNormal1 + Tex2DNormal0;
			float4 Master0_2_NoInput = float4(0,0,0,0);
			float4 Master0_5_NoInput = float4(1,1,1,1);
			float4 Master0_7_NoInput = float4(0,0,0,0);
			float4 Master0_6_NoInput = float4(1,1,1,1);
			o.Albedo = Multiply3;
			o.Normal = Add0;
			o.Specular = _Shininess.xxxx;
			o.Gloss = Multiply3;
			
			o.Normal = normalize(o.Normal);
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			float4 pack1 : TEXCOORD1;
			float4 screen : TEXCOORD2;
			
			#ifdef LIGHTMAP_OFF
				float3 vlight : TEXCOORD3;
				#else
				float2 lmap : TEXCOORD3;
				
				#ifdef DIRLIGHTMAP_OFF
					float4 lmapFadePos : TEXCOORD4;
					#else
					float3 viewDir : TEXCOORD4;
				#endif

			#endif
		};
		
		#ifndef LIGHTMAP_OFF
			float4 unity_LightmapST;
		#endif
		
		float4 _MainTex_ST;
		float4 _DecalTex_ST;
		float4 _BumpMap_ST;
		float4 _BumpMapDetail_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			Input customInputData;
			vert (v, customInputData);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _MainTex);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _DecalTex);
			o.pack1.xy = TRANSFORM_TEX(v.texcoord, _BumpMap);
			o.pack1.zw = TRANSFORM_TEX(v.texcoord, _BumpMapDetail);
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
			surfIN.uv_DecalTex = IN.pack0.zw;
			surfIN.uv_BumpMap = IN.pack1.xy;
			surfIN.uv_BumpMapDetail = IN.pack1.zw;
			
			#ifdef UNITY_COMPILER_HLSL
				EditorSurfaceOutput o = (EditorSurfaceOutput)0;
				#else
				EditorSurfaceOutput o;
			#endif
			
			o.Albedo = 0.0;
			o.Emission = 0.0;
			o.Specular = 0.0;
			o.Alpha = 0.0;
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
					half4 lm = LightingBlinnPhongEditor_DirLightmap(o, lmtex, lmIndTex, normalize(half3(IN.viewDir)), 1, specColor);
					light += lm;
				#endif
				
				#else
				light.rgb += IN.vlight;
			#endif
			
			half4 c = LightingBlinnPhongEditor_PrePass (o, light);
			c.rgb += o.Emission;
			
			return LLEncodeGamma( GoHDRApplyCorrection( c ) );
		}
		
		ENDCG
	}
}

Fallback "GoHDR/Diffuse"
}


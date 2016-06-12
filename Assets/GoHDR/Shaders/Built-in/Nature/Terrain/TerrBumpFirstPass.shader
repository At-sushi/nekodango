Shader "GoHDR/Nature/Terrain/Bumped Specular" {
	Properties {
		_SpecColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
		_Shininess ("Shininess", Range (0.03, 1)) = 0.078125
		[HideInInspector] _Control ("Control (RGBA)", 2D) = "red" {}
		[HideInInspector] _Splat3 ("Layer 3 (A)", 2D) = "white" {}
		[HideInInspector] _Splat2 ("Layer 2 (B)", 2D) = "white" {}
		[HideInInspector] _Splat1 ("Layer 1 (G)", 2D) = "white" {}
		[HideInInspector] _Splat0 ("Layer 0 (R)", 2D) = "white" {}
		[HideInInspector] _Normal3 ("Normal 3 (A)", 2D) = "bump" {}
		[HideInInspector] _Normal2 ("Normal 2 (B)", 2D) = "bump" {}
		[HideInInspector] _Normal1 ("Normal 1 (G)", 2D) = "bump" {}
		[HideInInspector] _Normal0 ("Normal 0 (R)", 2D) = "bump" {}
		[HideInInspector] _MainTex ("BaseMap (RGB)", 2D) = "white" {}
		
		[HideInInspector] _Color ("Main Color", Color) = (1,1,1,1)
	}
	
	SubShader {
		Tags {
			"SplatCount" = "4"
			"Queue" = "Geometry-100"
			"RenderType" = "Opaque"
		}
		
		Pass {
			Name "FORWARD"
			Tags { "LightMode" = "ForwardBase" }
			
			CGPROGRAM
			#include "../../../GoHDR.cginc"
			#include "../../../LinLighting.cginc"
			#pragma vertex vert_surf
			#pragma fragment frag_surf
			#pragma multi_compile_fwdbase
			#include "HLSLSupport.cginc"
			#include "UnityShaderVariables.cginc"
			#define UNITY_PASS_FORWARDBASE
			#include "UnityCG.cginc"
			#include "Lighting.cginc"
			#include "AutoLight.cginc"
			
			#define INTERNAL_DATA
			#define WorldReflectionVector(data,normal) data.worldRefl
			#define WorldNormalVector(data,normal) normal
			
			#pragma target 3.0
			
			void vert (inout appdata_full v)
			{
				v.tangent.xyz = cross(v.normal, float3(0,0,1));
				v.tangent.w = -1;
			}
			
			struct Input {
				float2 uv_Control : TEXCOORD0;
				float2 uv_Splat0 : TEXCOORD1;
				float2 uv_Splat1 : TEXCOORD2;
				float2 uv_Splat2 : TEXCOORD3;
				float2 uv_Splat3 : TEXCOORD4;
			};
			
			sampler2D _Control;
			sampler2D _Splat0,_Splat1,_Splat2,_Splat3;
			sampler2D _Normal0,_Normal1,_Normal2,_Normal3;
			half _Shininess;
			
			void surf (Input IN, inout SurfaceOutput o) {
				fixed4 splat_control = tex2D (_Control, IN.uv_Control);
				fixed4 col;
				col  = splat_control.r * LLDecodeTex( tex2D (_Splat0, IN.uv_Splat0) );
				col += splat_control.g * LLDecodeTex( tex2D (_Splat1, IN.uv_Splat1) );
				col += splat_control.b * LLDecodeTex( tex2D (_Splat2, IN.uv_Splat2) );
				col += splat_control.a * LLDecodeTex( tex2D (_Splat3, IN.uv_Splat3) );
				o.Albedo = col.rgb;
				
				fixed4 nrm;
				nrm  = splat_control.r * tex2D (_Normal0, IN.uv_Splat0);
				nrm += splat_control.g * tex2D (_Normal1, IN.uv_Splat1);
				nrm += splat_control.b * tex2D (_Normal2, IN.uv_Splat2);
				nrm += splat_control.a * tex2D (_Normal3, IN.uv_Splat3);
				
				fixed splatSum = dot(splat_control, fixed4(1,1,1,1));
				fixed4 flatNormal = fixed4(0.5,0.5,1,0.5); 
				nrm = lerp(flatNormal, nrm, splatSum);
				o.Normal = UnpackNormal(nrm);
				
				o.Gloss = col.a * splatSum;
				o.Specular = _Shininess;
				
				o.Alpha = 0.0;
			}
			
			#ifdef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					float4 pack1 : TEXCOORD1;
					float2 pack2 : TEXCOORD2;
					fixed3 lightDir : TEXCOORD3;
					fixed3 vlight : TEXCOORD4;
					float3 viewDir : TEXCOORD5;
					LIGHTING_COORDS(6,7)
				};
			#endif
			
			#ifndef LIGHTMAP_OFF
				struct v2f_surf {
					float4 pos : SV_POSITION;
					float4 pack0 : TEXCOORD0;
					float4 pack1 : TEXCOORD1;
					float2 pack2 : TEXCOORD2;
					float2 lmap : TEXCOORD3;
					
					#ifndef DIRLIGHTMAP_OFF
						float3 viewDir : TEXCOORD4;
						LIGHTING_COORDS(5,6)
						#else
						LIGHTING_COORDS(4,5)
					#endif
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
				vert (v);
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
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_fwdadd
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_FORWARDADD
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		#include "AutoLight.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#pragma target 3.0
		
		void vert (inout appdata_full v)
		{
			v.tangent.xyz = cross(v.normal, float3(0,0,1));
			v.tangent.w = -1;
		}
		
		struct Input {
			float2 uv_Control : TEXCOORD0;
			float2 uv_Splat0 : TEXCOORD1;
			float2 uv_Splat1 : TEXCOORD2;
			float2 uv_Splat2 : TEXCOORD3;
			float2 uv_Splat3 : TEXCOORD4;
		};
		
		sampler2D _Control;
		sampler2D _Splat0,_Splat1,_Splat2,_Splat3;
		sampler2D _Normal0,_Normal1,_Normal2,_Normal3;
		half _Shininess;
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 splat_control = tex2D (_Control, IN.uv_Control);
			fixed4 col;
			col  = splat_control.r * LLDecodeTex( tex2D (_Splat0, IN.uv_Splat0) );
			col += splat_control.g * LLDecodeTex( tex2D (_Splat1, IN.uv_Splat1) );
			col += splat_control.b * LLDecodeTex( tex2D (_Splat2, IN.uv_Splat2) );
			col += splat_control.a * LLDecodeTex( tex2D (_Splat3, IN.uv_Splat3) );
			o.Albedo = col.rgb;
			
			fixed4 nrm;
			nrm  = splat_control.r * tex2D (_Normal0, IN.uv_Splat0);
			nrm += splat_control.g * tex2D (_Normal1, IN.uv_Splat1);
			nrm += splat_control.b * tex2D (_Normal2, IN.uv_Splat2);
			nrm += splat_control.a * tex2D (_Normal3, IN.uv_Splat3);
			
			fixed splatSum = dot(splat_control, fixed4(1,1,1,1));
			fixed4 flatNormal = fixed4(0.5,0.5,1,0.5); 
			nrm = lerp(flatNormal, nrm, splatSum);
			o.Normal = UnpackNormal(nrm);
			
			o.Gloss = col.a * splatSum;
			o.Specular = _Shininess;
			
			o.Alpha = 0.0;
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			float4 pack1 : TEXCOORD1;
			float2 pack2 : TEXCOORD2;
			half3 lightDir : TEXCOORD3;
			half3 viewDir : TEXCOORD4;
			LIGHTING_COORDS(5,6)
		};
		
		float4 _Control_ST;
		float4 _Splat0_ST;
		float4 _Splat1_ST;
		float4 _Splat2_ST;
		float4 _Splat3_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			vert (v);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _Control);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _Splat0);
			o.pack1.xy = TRANSFORM_TEX(v.texcoord, _Splat1);
			o.pack1.zw = TRANSFORM_TEX(v.texcoord, _Splat2);
			o.pack2.xy = TRANSFORM_TEX(v.texcoord, _Splat3);
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
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_PREPASSBASE
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#pragma target 3.0
		
		void vert (inout appdata_full v)
		{
			v.tangent.xyz = cross(v.normal, float3(0,0,1));
			v.tangent.w = -1;
		}
		
		struct Input {
			float2 uv_Control : TEXCOORD0;
			float2 uv_Splat0 : TEXCOORD1;
			float2 uv_Splat1 : TEXCOORD2;
			float2 uv_Splat2 : TEXCOORD3;
			float2 uv_Splat3 : TEXCOORD4;
		};
		
		sampler2D _Control;
		sampler2D _Splat0,_Splat1,_Splat2,_Splat3;
		sampler2D _Normal0,_Normal1,_Normal2,_Normal3;
		half _Shininess;
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 splat_control = tex2D (_Control, IN.uv_Control);
			fixed4 col;
			col  = splat_control.r * LLDecodeTex( tex2D (_Splat0, IN.uv_Splat0) );
			col += splat_control.g * LLDecodeTex( tex2D (_Splat1, IN.uv_Splat1) );
			col += splat_control.b * LLDecodeTex( tex2D (_Splat2, IN.uv_Splat2) );
			col += splat_control.a * LLDecodeTex( tex2D (_Splat3, IN.uv_Splat3) );
			o.Albedo = col.rgb;
			
			fixed4 nrm;
			nrm  = splat_control.r * tex2D (_Normal0, IN.uv_Splat0);
			nrm += splat_control.g * tex2D (_Normal1, IN.uv_Splat1);
			nrm += splat_control.b * tex2D (_Normal2, IN.uv_Splat2);
			nrm += splat_control.a * tex2D (_Normal3, IN.uv_Splat3);
			
			fixed splatSum = dot(splat_control, fixed4(1,1,1,1));
			fixed4 flatNormal = fixed4(0.5,0.5,1,0.5); 
			nrm = lerp(flatNormal, nrm, splatSum);
			o.Normal = UnpackNormal(nrm);
			
			o.Gloss = col.a * splatSum;
			o.Specular = _Shininess;
			
			o.Alpha = 0.0;
		}
		
		struct v2f_surf {
			float4 pos : SV_POSITION;
			float4 pack0 : TEXCOORD0;
			float4 pack1 : TEXCOORD1;
			float2 pack2 : TEXCOORD2;
			float3 TtoW0 : TEXCOORD3;
			float3 TtoW1 : TEXCOORD4;
			float3 TtoW2 : TEXCOORD5;
		};
		
		float4 _Control_ST;
		float4 _Splat0_ST;
		float4 _Splat1_ST;
		float4 _Splat2_ST;
		float4 _Splat3_ST;
		
		v2f_surf vert_surf (appdata_full v) {
			v2f_surf o;
			vert (v);
			o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			o.pack0.xy = TRANSFORM_TEX(v.texcoord, _Control);
			o.pack0.zw = TRANSFORM_TEX(v.texcoord, _Splat0);
			o.pack1.xy = TRANSFORM_TEX(v.texcoord, _Splat1);
			o.pack1.zw = TRANSFORM_TEX(v.texcoord, _Splat2);
			o.pack2.xy = TRANSFORM_TEX(v.texcoord, _Splat3);
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
		#include "../../../GoHDR.cginc"
		#include "../../../LinLighting.cginc"
		#pragma vertex vert_surf
		#pragma fragment frag_surf
		#pragma multi_compile_prepassfinal
		#include "HLSLSupport.cginc"
		#include "UnityShaderVariables.cginc"
		#define UNITY_PASS_PREPASSFINAL
		#include "UnityCG.cginc"
		#include "Lighting.cginc"
		
		#define INTERNAL_DATA
		#define WorldReflectionVector(data,normal) data.worldRefl
		#define WorldNormalVector(data,normal) normal
		
		#pragma target 3.0
		
		void vert (inout appdata_full v)
		{
			v.tangent.xyz = cross(v.normal, float3(0,0,1));
			v.tangent.w = -1;
		}
		
		struct Input {
			float2 uv_Control : TEXCOORD0;
			float2 uv_Splat0 : TEXCOORD1;
			float2 uv_Splat1 : TEXCOORD2;
			float2 uv_Splat2 : TEXCOORD3;
			float2 uv_Splat3 : TEXCOORD4;
		};
		
		sampler2D _Control;
		sampler2D _Splat0,_Splat1,_Splat2,_Splat3;
		sampler2D _Normal0,_Normal1,_Normal2,_Normal3;
		half _Shininess;
		
		void surf (Input IN, inout SurfaceOutput o) {
			fixed4 splat_control = tex2D (_Control, IN.uv_Control);
			fixed4 col;
			col  = splat_control.r * LLDecodeTex( tex2D (_Splat0, IN.uv_Splat0) );
			col += splat_control.g * LLDecodeTex( tex2D (_Splat1, IN.uv_Splat1) );
			col += splat_control.b * LLDecodeTex( tex2D (_Splat2, IN.uv_Splat2) );
			col += splat_control.a * LLDecodeTex( tex2D (_Splat3, IN.uv_Splat3) );
			o.Albedo = col.rgb;
			
			fixed4 nrm;
			nrm  = splat_control.r * tex2D (_Normal0, IN.uv_Splat0);
			nrm += splat_control.g * tex2D (_Normal1, IN.uv_Splat1);
			nrm += splat_control.b * tex2D (_Normal2, IN.uv_Splat2);
			nrm += splat_control.a * tex2D (_Normal3, IN.uv_Splat3);
			
			fixed splatSum = dot(splat_control, fixed4(1,1,1,1));
			fixed4 flatNormal = fixed4(0.5,0.5,1,0.5); 
			nrm = lerp(flatNormal, nrm, splatSum);
			o.Normal = UnpackNormal(nrm);
			
			o.Gloss = col.a * splatSum;
			o.Specular = _Shininess;
			
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
					#else
					float3 viewDir : TEXCOORD5;
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
			vert (v);
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
}

Dependency "AddPassShader" = "Hidden/Nature/Terrain/Bumped Specular AddPass"
Dependency "BaseMapShader" = "GoHDR/Specular"
Fallback "GoHDR/Nature/Terrain/Diffuse"
}


//Original shader:

//Shader "GoHDR/Nature/Terrain/Bumped Specular" {
//Properties {
//	_SpecColor ("Specular Color", Color) = (0.5, 0.5, 0.5, 1)
//	_Shininess ("Shininess", Range (0.03, 1)) = 0.078125
//
//	// set by terrain engine
//	[HideInInspector] _Control ("Control (RGBA)", 2D) = "red" {}
//	[HideInInspector] _Splat3 ("Layer 3 (A)", 2D) = "white" {}
//	[HideInInspector] _Splat2 ("Layer 2 (B)", 2D) = "white" {}
//	[HideInInspector] _Splat1 ("Layer 1 (G)", 2D) = "white" {}
//	[HideInInspector] _Splat0 ("Layer 0 (R)", 2D) = "white" {}
//	[HideInInspector] _Normal3 ("Normal 3 (A)", 2D) = "bump" {}
//	[HideInInspector] _Normal2 ("Normal 2 (B)", 2D) = "bump" {}
//	[HideInInspector] _Normal1 ("Normal 1 (G)", 2D) = "bump" {}
//	[HideInInspector] _Normal0 ("Normal 0 (R)", 2D) = "bump" {}
//	// used in fallback on old cards & base map
//	[HideInInspector] _MainTex ("BaseMap (RGB)", 2D) = "white" {}
//	[HideInInspector] _Color ("Main Color", Color) = (1,1,1,1)
//}
//	
//SubShader {
//	Tags {
//		"SplatCount" = "4"
//		"Queue" = "Geometry-100"
//		"RenderType" = "Opaque"
//	}
//CGPROGRAM
//#pragma surface surf BlinnPhong vertex:vert
//#pragma target 3.0
//
//void vert (inout appdata_full v)
//{
//	v.tangent.xyz = cross(v.normal, float3(0,0,1));
//	v.tangent.w = -1;
//}
//
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
//sampler2D _Normal0,_Normal1,_Normal2,_Normal3;
//half _Shininess;
//
//void surf (Input IN, inout SurfaceOutput o) {
//	fixed4 splat_control = tex2D (_Control, IN.uv_Control);
//	fixed4 col;
//	col  = splat_control.r * tex2D (_Splat0, IN.uv_Splat0);
//	col += splat_control.g * tex2D (_Splat1, IN.uv_Splat1);
//	col += splat_control.b * tex2D (_Splat2, IN.uv_Splat2);
//	col += splat_control.a * tex2D (_Splat3, IN.uv_Splat3);
//	o.Albedo = col.rgb;
//
//	fixed4 nrm;
//	nrm  = splat_control.r * tex2D (_Normal0, IN.uv_Splat0);
//	nrm += splat_control.g * tex2D (_Normal1, IN.uv_Splat1);
//	nrm += splat_control.b * tex2D (_Normal2, IN.uv_Splat2);
//	nrm += splat_control.a * tex2D (_Normal3, IN.uv_Splat3);
//	// Sum of our four splat weights might not sum up to 1, in
//	// case of more than 4 total splat maps. Need to lerp towards
//	// "flat normal" in that case.
//	fixed splatSum = dot(splat_control, fixed4(1,1,1,1));
//	fixed4 flatNormal = fixed4(0.5,0.5,1,0.5); // this is "flat normal" in both DXT5nm and xyz*2-1 cases
//	nrm = lerp(flatNormal, nrm, splatSum);
//	o.Normal = UnpackNormal(nrm);
//
//	o.Gloss = col.a * splatSum;
//	o.Specular = _Shininess;
//
//	o.Alpha = 0.0;
//}
//ENDCG  
//}
//
//Dependency "AddPassShader" = "Hidden/Nature/Terrain/Bumped Specular AddPass"
//Dependency "BaseMapShader" = "Specular"
//
//Fallback "GoHDR/Nature/Terrain/Diffuse"
//}

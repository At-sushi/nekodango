Shader "GoHDR/Self-Illumin/VertexLit CG" {
	Properties {
		_Color ("Main Color", Color) = (1,1,1,1)
		_SpecColor ("Spec Color", Color) = (1,1,1,1)
		_Shininess ("Shininess", Range (0.1, 1)) = 0.7
		_MainTex ("Base (RGB)", 2D) = "white" {}
		_Illum ("Illumin (A)", 2D) = "white" {}
		
		_EmissionLM ("Emission (Lightmapper)", Float) = 0
		
	}
	
	SubShader {
		Tags {"Queue"="Geometry" "IgnoreProjector"="True" "RenderType"="Opaque"}
		
		LOD 100
		
		Pass {
			Tags { LightMode = Vertex } 
			
			CGPROGRAM
			
			#include "../GoHDR.cginc"
			#include "../LinLighting.cginc"
			
			#pragma vertex vert  
			#pragma fragment frag
			
			#include "../UnityCGGoHDR.cginc"
			
			#define ADD_SPECULAR
			
			fixed4 _Color;
			fixed4 _SpecColor;
			
			fixed4 _EmissionLM;
			
			half _Shininess;
			
			sampler2D _MainTex;
			float4 _MainTex_ST;
			
			sampler2D _Illum;
			float4 _Illum_ST;
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv_MainTex : TEXCOORD0;
				fixed3 diff : COLOR;
				
				#ifdef ADD_SPECULAR
					fixed3 spec : TEXCOORD1;
				#endif
				
				float2 uv_Illum : TEXCOORD2;
			};
			
			v2f vert (appdata_full v)
			{
				v2f o;
				o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
				o.uv_MainTex = TRANSFORM_TEX (v.texcoord, _MainTex);
				o.uv_Illum = TRANSFORM_TEX (v.texcoord, _Illum);
				
				float3 viewpos = mul (UNITY_MATRIX_MV, v.vertex).xyz;
				
				o.diff = LLDecodeGamma( UNITY_LIGHTMODEL_AMBIENT.xyz * 1.47 );
				
				#ifdef ADD_SPECULAR
					o.spec = 0;
					fixed3 viewDirObj = normalize( ObjSpaceViewDir(v.vertex) );
				#endif
				
				for (int i = 0; i < 4; i++) {
					half3 toLight = unity_LightPosition[i].xyz - viewpos.xyz * unity_LightPosition[i].w;
					half lengthSq = dot(toLight, toLight);
					half atten = 1.0 / (1.0 + lengthSq * unity_LightAtten[i].z );
					
					fixed3 lightDirObj = mul( (float3x3)UNITY_MATRIX_T_MV, toLight);	
					
					lightDirObj = normalize(lightDirObj);
					
					fixed diff = max ( 0, dot (v.normal, lightDirObj) );
					o.diff += unity_LightColor[i].rgb * (diff * atten);
					
					#ifdef ADD_SPECULAR
						fixed3 h = normalize (viewDirObj + lightDirObj);
						fixed nh = max (0, dot (v.normal, h));
						
						fixed spec = pow (nh, _Shininess * 128.0);
						o.spec += spec * unity_LightColor[i].rgb * atten;
					#endif
				}
				
				o.diff = (o.diff) * 2;
				
				#ifdef ADD_SPECULAR
					o.spec *= LLDecodeGamma( _SpecColor.rgb );
				#endif
				
				return o;
			}
			
			fixed4 frag (v2f i) : COLOR {
				fixed4 c;
				
				fixed4 mainTex = LLDecodeTex( tex2D (_MainTex, i.uv_MainTex) ) * LLDecodeGamma( _Color );
				
				#ifdef ADD_SPECULAR
					c.rgb = (mainTex.rgb * i.diff + i.spec);
					#else
					c.rgb = (mainTex.rgb * i.diff);
				#endif
				
				c.rgb += mainTex.rgb * LLDecodeTex( tex2D(_Illum, i.uv_Illum).a );
				
				c.a = mainTex.a;
				
				return LLEncodeGamma( GoHDRApplyCorrection( c ) );
			}
			
			ENDCG
		}
		
		Pass {
			Name "Caster"
			Tags { "LightMode" = "ShadowCaster" }
			
			Offset 1, 1
			Fog {Mode Off}
			
			ZWrite On ZTest LEqual Cull Off
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma multi_compile_shadowcaster
			#pragma fragmentoption ARB_precision_hint_fastest
			#include "UnityCG.cginc"
			
			struct v2f { 
				V2F_SHADOW_CASTER;
				float2  uv : TEXCOORD1;
			};
			
			uniform float4 _MainTex_ST;
			
			v2f vert( appdata_base v )
			{
				v2f o;
				TRANSFER_SHADOW_CASTER(o)
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				return o;
			}
			
			uniform sampler2D _MainTex;
			uniform fixed _Cutoff;
			uniform fixed4 _Color;
			
			float4 frag( v2f i ) : COLOR
			{
				fixed4 texcol = tex2D( _MainTex, i.uv );
				clip( texcol.a*_Color.a - _Cutoff );
				
				SHADOW_CASTER_FRAGMENT(i)
			}
			
			ENDCG
		}
		
		Pass {
			Name "ShadowCollector"
			Tags { "LightMode" = "ShadowCollector" }
			Fog {Mode Off}
			
			ZWrite On ZTest LEqual
			
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			#pragma fragmentoption ARB_precision_hint_fastest
			#pragma multi_compile_shadowcollector
			
			#define SHADOW_COLLECTOR_PASS
			#include "UnityCG.cginc"
			
			struct v2f {
				V2F_SHADOW_COLLECTOR;
				float2  uv : TEXCOORD5;
			};
			
			uniform float4 _MainTex_ST;
			
			v2f vert (appdata_base v)
			{
				v2f o;
				TRANSFER_SHADOW_COLLECTOR(o)
				o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
				return o;
			}
			
			uniform sampler2D _MainTex;
			uniform fixed _Cutoff;
			uniform fixed4 _Color;
			
			fixed4 frag (v2f i) : COLOR
			{
				fixed4 texcol = tex2D( _MainTex, i.uv );
				clip( texcol.a*_Color.a - _Cutoff );
				
				SHADOW_COLLECTOR_FRAGMENT(i)
			}
			
			ENDCG
		}
	}
	
	Fallback "Self-Illumin/VertexLit"
}


//Original shader:

//Shader "Self-Illumin/VertexLit CG" {
//Properties {
//	_Color ("Main Color", Color) = (1,1,1,1)
//	_SpecColor ("Spec Color", Color) = (1,1,1,1)
//	_Shininess ("Shininess", Range (0.1, 1)) = 0.7
//	_MainTex ("Base (RGB)", 2D) = "white" {}
//	_Illum ("Illumin (A)", 2D) = "white" {}
//	_EmissionLM ("Emission (Lightmapper)", Float) = 0
//}
//
//SubShader {
//	Tags {"Queue"="Geometry" "IgnoreProjector"="True" "RenderType"="Opaque"}
//	LOD 100
//	
//	Pass {
//		Tags { LightMode = Vertex } 
//		CGPROGRAM
//		
//		#pragma vertex vert  
//		#pragma fragment frag
//		
//		#include "UnityCG.cginc"
//		
//		#define ADD_SPECULAR
//		
//		fixed4 _Color;
//		fixed4 _SpecColor;
//		
//		fixed4 _EmissionLM;
//		
//		half _Shininess;
//		
//		sampler2D _MainTex;
//		float4 _MainTex_ST;
//		
//		sampler2D _Illum;
//		float4 _Illum_ST;
//		
//		struct v2f {
//			float4 pos : SV_POSITION;
//			float2 uv_MainTex : TEXCOORD0;
//			fixed3 diff : COLOR;
//			
//			#ifdef ADD_SPECULAR
//			fixed3 spec : TEXCOORD1;
//			#endif
//			
//			float2 uv_Illum : TEXCOORD2;
//		};
//		
//		v2f vert (appdata_full v)
//		{
//		    v2f o;
//		    o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
//		    o.uv_MainTex = TRANSFORM_TEX (v.texcoord, _MainTex);
//		    o.uv_Illum = TRANSFORM_TEX (v.texcoord, _Illum);
//			
//			float3 viewpos = mul (UNITY_MATRIX_MV, v.vertex).xyz;
//			
//			o.diff = UNITY_LIGHTMODEL_AMBIENT.xyz;
//			
//			#ifdef ADD_SPECULAR
//			o.spec = 0;
//			fixed3 viewDirObj = normalize( ObjSpaceViewDir(v.vertex) );
//			#endif
//			
//			//All calculations are in object space
//			for (int i = 0; i < 4; i++) {
//				half3 toLight = unity_LightPosition[i].xyz - viewpos.xyz * unity_LightPosition[i].w;
//				half lengthSq = dot(toLight, toLight);
//				half atten = 1.0 / (1.0 + lengthSq * unity_LightAtten[i].z );
//				
//				fixed3 lightDirObj = mul( (float3x3)UNITY_MATRIX_T_MV, toLight);	//View => model
//				
//				lightDirObj = normalize(lightDirObj);
//				
//				fixed diff = max ( 0, dot (v.normal, lightDirObj) );
//				o.diff += unity_LightColor[i].rgb * (diff * atten);
//				
//				#ifdef ADD_SPECULAR
//				fixed3 h = normalize (viewDirObj + lightDirObj);
//				fixed nh = max (0, dot (v.normal, h));
//				
//				fixed spec = pow (nh, _Shininess * 128.0);
//				o.spec += spec * unity_LightColor[i].rgb * atten;
//				#endif
//			}
//			
//			o.diff = (o.diff) * 2;
//			#ifdef ADD_SPECULAR
//			o.spec *= _SpecColor.rgb;
//			#endif
//			
//			return o;
//		}
//		
//		fixed4 frag (v2f i) : COLOR {
//			fixed4 c;
//			
//			fixed4 mainTex = tex2D (_MainTex, i.uv_MainTex) * _Color;
//			
//			#ifdef ADD_SPECULAR
//			c.rgb = (mainTex.rgb * i.diff + i.spec);
//			#else
//			c.rgb = (mainTex.rgb * i.diff);
//			#endif
//			
//			//Emission
//			c.rgb += mainTex.rgb * tex2D(_Illum, i.uv_Illum).a;
//			
//			c.a = mainTex.a;
//			
//			
//			return c;
//		}
//		
//		ENDCG
//	}
//	
//	Pass {
//		Name "Caster"
//		Tags { "LightMode" = "ShadowCaster" }
//		Offset 1, 1
//		
//		Fog {Mode Off}
//		ZWrite On ZTest LEqual Cull Off
//
//	CGPROGRAM
//	#pragma vertex vert
//	#pragma fragment frag
//	#pragma multi_compile_shadowcaster
//	#pragma fragmentoption ARB_precision_hint_fastest
//	#include "UnityCG.cginc"
//	
//	struct v2f { 
//		V2F_SHADOW_CASTER;
//		float2  uv : TEXCOORD1;
//	};
//	
//	uniform float4 _MainTex_ST;
//	
//	v2f vert( appdata_base v )
//	{
//		v2f o;
//		TRANSFER_SHADOW_CASTER(o)
//		o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
//		return o;
//	}
//	
//	uniform sampler2D _MainTex;
//	uniform fixed _Cutoff;
//	uniform fixed4 _Color;
//	
//	float4 frag( v2f i ) : COLOR
//	{
//		fixed4 texcol = tex2D( _MainTex, i.uv );
//		clip( texcol.a*_Color.a - _Cutoff );
//		
//		SHADOW_CASTER_FRAGMENT(i)
//	}
//	ENDCG
//	
//		}
//		
//		// Pass to render object as a shadow collector
//		Pass {
//			Name "ShadowCollector"
//			Tags { "LightMode" = "ShadowCollector" }
//			
//			Fog {Mode Off}
//			ZWrite On ZTest LEqual
//	
//	CGPROGRAM
//	#pragma vertex vert
//	#pragma fragment frag
//	#pragma fragmentoption ARB_precision_hint_fastest
//	#pragma multi_compile_shadowcollector
//	
//	#define SHADOW_COLLECTOR_PASS
//	#include "UnityCG.cginc"
//	
//	struct v2f {
//		V2F_SHADOW_COLLECTOR;
//		float2  uv : TEXCOORD5;
//	};
//	
//	uniform float4 _MainTex_ST;
//	
//	v2f vert (appdata_base v)
//	{
//		v2f o;
//		TRANSFER_SHADOW_COLLECTOR(o)
//		o.uv = TRANSFORM_TEX(v.texcoord, _MainTex);
//		return o;
//	}
//	
//	uniform sampler2D _MainTex;
//	uniform fixed _Cutoff;
//	uniform fixed4 _Color;
//	
//	fixed4 frag (v2f i) : COLOR
//	{
//		fixed4 texcol = tex2D( _MainTex, i.uv );
//		clip( texcol.a*_Color.a - _Cutoff );
//		
//		SHADOW_COLLECTOR_FRAGMENT(i)
//	}
//	ENDCG
//	}
//}
//
//Fallback "Self-Illumin/VertexLit"
//}

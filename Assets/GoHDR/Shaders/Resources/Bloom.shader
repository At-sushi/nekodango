Shader "GoHDR/Bloom" {
	Properties {
//		_LuminosityTex ("Luminosity (RG)", 2D) = "white" {}
		_MainCameraTex ("Main camera texture (RGB)", 2D) = "white" {}
		_BlurDeltaUV ("Blur Delta UV", float) = 0.00390625
		_BloomBias ("Bloom Bias", float) = 0.98
		_BloomStrength ("Bloom Strength", float) = 25.0
	}
	SubShader {
		Tags {"Queue"="Overlay"}
		LOD 100
		
		Pass {
			Tags { "Queue"="Overlay" "IgnoreProjector"="True" "RenderType"="Opaque"}
//			Blend SrcAlpha OneMinusSrcAlpha
//			Blend SrcAlpha One
			Blend One One
			Lighting Off
			Cull Off
			Fog { Mode Off }
			ZWrite Off
			
			CGPROGRAM
			#pragma glsl
			//#define _BlurDeltaUV 0.03125
			//#define _BlurDeltaUV 0.0078125
			//#define _BlurDeltaUV 0.00390625
			//#define _BlurDeltaUV 0.00194174757
			
			//#define GAUSSIAN_BLUR
			
			#ifdef GAUSSIAN_BLUR
				//#define THREE_BLUR_STEPS
				#define FIVE_BLUR_STEPS
			#else
				#define BLUR_SIZE 2
			#endif
			//#define REAL_LUMINANCE_BLOOM
			
			#pragma vertex vert  
			#pragma fragment frag
			
			#pragma target 3.0
			
			#include "UnityCG.cginc"
			
			#include "../GoHDR.cginc"

//			sampler2D _LuminosityTex;
//			float4 _LuminosityTex_ST;
			
			sampler2D _MainCameraTex;
			float4 _MainCameraTex_ST;
			
			float _BlurDeltaUV;
			float _BloomBias;
			float _BloomStrength;
			
			struct v2f {
				float4 pos : SV_POSITION;
				float2 uv_MainCameraTex : TEXCOORD0;
			};
			
			v2f vert (appdata_full v)
			{
			    v2f o;
			    o.pos = mul (UNITY_MATRIX_MVP, v.vertex);
			    o.uv_MainCameraTex = TRANSFORM_TEX (v.texcoord, _MainCameraTex);
			
				return o;
			}
			
			fixed4 frag (v2f i) : COLOR {
				fixed4 c;
				
//				c.rgb = tex2D(_LuminosityTex, i.uv_MainCameraTex).rgb;
//				
//				c.a = 1.0;
//				
//				return c;
				
				#ifdef GAUSSIAN_BLUR
					//
					//Get the uvs
					//#ifdef THREE_BLUR_STEPS
					//0 1 2 3 4
					//1        
					//2   +
					//3        
					//4       -
					
					//Top -1 row
					float2 uv21 = i.uv_MainCameraTex;	uv21.y -= _BlurDeltaUV;		//+
					float2 uv11 = uv21;					uv11.x -=	_BlurDeltaUV;		//+
					float2 uv31 = uv21;					uv31.x +=	_BlurDeltaUV;		//+
					
					//Middle row
					float2 uv22 = i.uv_MainCameraTex;									//+
					float2 uv12 = uv22;					uv12.x -=	_BlurDeltaUV;		//+
					float2 uv32 = uv22;					uv32.x +=	_BlurDeltaUV;		//+
					
					//Bottom -1 row
					float2 uv23 = i.uv_MainCameraTex;	uv23.y += _BlurDeltaUV;		//+
					float2 uv13 = uv23;					uv13.x -=	_BlurDeltaUV;		//+
					float2 uv33 = uv23;					uv33.x +=	_BlurDeltaUV;		//+
					
					#ifdef FIVE_BLUR_STEPS
					//Top row
					float2 uv20 = uv21;					uv20.y -= _BlurDeltaUV;		//+
					float2 uv10 = uv20;					uv10.x -=	_BlurDeltaUV;		//+
					float2 uv30 = uv20;					uv30.x +=	_BlurDeltaUV;		//+
					
					float2 uv00 = uv10;					uv00.x -=	_BlurDeltaUV;		//+
					float2 uv40 = uv30;					uv40.x +=	_BlurDeltaUV;		//+
					
					//Top -1
					float2 uv01 = uv11;					uv01.x -=	_BlurDeltaUV;		//+
					float2 uv41 = uv31;					uv41.x +=	_BlurDeltaUV;		//+
					
					//Middle
					float2 uv02 = uv12;					uv02.x -=	_BlurDeltaUV;		//+
					float2 uv42 = uv32;					uv42.x +=	_BlurDeltaUV;		//+
					
					//Bottom -1
					float2 uv03 = uv11;					uv03.x -=	_BlurDeltaUV;
					float2 uv43 = uv31;					uv43.x +=	_BlurDeltaUV;
					
					//Bottom row
					float2 uv24 = uv23;					uv24.y += _BlurDeltaUV;
					float2 uv14 = uv24;					uv14.x -=	_BlurDeltaUV;
					float2 uv34 = uv24;					uv34.x +=	_BlurDeltaUV;
					
					float2 uv04 = uv14;					uv04.x -=	_BlurDeltaUV;
					float2 uv44 = uv34;					uv44.x +=	_BlurDeltaUV;
					
					#endif
					
					#ifdef REAL_LUMINANCE_BLOOM
					//Sample the luminosity texture
					float lumDec21 = DecodeFloatRG( tex2D (_LuminosityTex, uv21 ).rg );
					float lumDec11 = DecodeFloatRG( tex2D (_LuminosityTex, uv11 ).rg );
					float lumDec31 = DecodeFloatRG( tex2D (_LuminosityTex, uv31 ).rg );
					
					float lumDec22 = DecodeFloatRG( tex2D (_LuminosityTex, uv22 ).rg );
					float lumDec12 = DecodeFloatRG( tex2D (_LuminosityTex, uv12 ).rg );
					float lumDec32 = DecodeFloatRG( tex2D (_LuminosityTex, uv32 ).rg );
					
					float lumDec23 = DecodeFloatRG( tex2D (_LuminosityTex, uv23 ).rg );
					float lumDec13 = DecodeFloatRG( tex2D (_LuminosityTex, uv13 ).rg );
					float lumDec33 = DecodeFloatRG( tex2D (_LuminosityTex, uv33 ).rg );
					#endif
					
					//Sample the main camera texture
					float pix21 = Luminance(tex2D (_MainCameraTex, uv21 ).rgb);		pix21 = saturate( pix21 - _BloomBias ) * _BloomStrength;
					float pix11 = Luminance(tex2D (_MainCameraTex, uv11 ).rgb);		pix11 = saturate( pix11 - _BloomBias ) * _BloomStrength;
					float pix31 = Luminance(tex2D (_MainCameraTex, uv31 ).rgb);		pix31 = saturate( pix31 - _BloomBias ) * _BloomStrength;
					
					float pix22 = Luminance(tex2D (_MainCameraTex, uv22 ).rgb);		pix22 = saturate( pix22 - _BloomBias ) * _BloomStrength;
					float pix12 = Luminance(tex2D (_MainCameraTex, uv12 ).rgb);		pix12 = saturate( pix12 - _BloomBias ) * _BloomStrength;
					float pix32 = Luminance(tex2D (_MainCameraTex, uv32 ).rgb);		pix32 = saturate( pix32 - _BloomBias ) * _BloomStrength;
					
					float pix23 = Luminance(tex2D (_MainCameraTex, uv23 ).rgb);		pix23 = saturate( pix23 - _BloomBias ) * _BloomStrength;
					float pix13 = Luminance(tex2D (_MainCameraTex, uv13 ).rgb);		pix13 = saturate( pix13 - _BloomBias ) * _BloomStrength;
					float pix33 = Luminance(tex2D (_MainCameraTex, uv33 ).rgb);		pix33 = saturate( pix33 - _BloomBias ) * _BloomStrength;
					
					
					#ifdef FIVE_BLUR_STEPS
						#ifdef REAL_LUMINANCE_BLOOM
						//Lum
						float lumDec20 = DecodeFloatRG( tex2D (_LuminosityTex, uv20 ).rg );
						float lumDec10 = DecodeFloatRG( tex2D (_LuminosityTex, uv10 ).rg );
						float lumDec30 = DecodeFloatRG( tex2D (_LuminosityTex, uv30 ).rg );
						
						float lumDec00 = DecodeFloatRG( tex2D (_LuminosityTex, uv00 ).rg );
						float lumDec40 = DecodeFloatRG( tex2D (_LuminosityTex, uv40 ).rg );
						
						
						float lumDec01 = DecodeFloatRG( tex2D (_LuminosityTex, uv01 ).rg );
						float lumDec41 = DecodeFloatRG( tex2D (_LuminosityTex, uv41 ).rg );
						
						float lumDec02 = DecodeFloatRG( tex2D (_LuminosityTex, uv02 ).rg );
						float lumDec42 = DecodeFloatRG( tex2D (_LuminosityTex, uv42 ).rg );
						
						float lumDec03 = DecodeFloatRG( tex2D (_LuminosityTex, uv03 ).rg );
						float lumDec43 = DecodeFloatRG( tex2D (_LuminosityTex, uv43 ).rg );
						
						
						float lumDec24 = DecodeFloatRG( tex2D (_LuminosityTex, uv24 ).rg );
						float lumDec14 = DecodeFloatRG( tex2D (_LuminosityTex, uv14 ).rg );
						float lumDec34 = DecodeFloatRG( tex2D (_LuminosityTex, uv34 ).rg );
						
						float lumDec04 = DecodeFloatRG( tex2D (_LuminosityTex, uv04 ).rg );
						float lumDec44 = DecodeFloatRG( tex2D (_LuminosityTex, uv44 ).rg );
						#endif
					
					//Main cam
					float pix20 = Luminance(tex2D (_MainCameraTex, uv20 ).rgb);		pix20 = saturate( pix20 - _BloomBias ) * _BloomStrength;
					float pix10 = Luminance(tex2D (_MainCameraTex, uv10 ).rgb);		pix10 = saturate( pix10 - _BloomBias ) * _BloomStrength;
					float pix30 = Luminance(tex2D (_MainCameraTex, uv30 ).rgb);		pix30 = saturate( pix30 - _BloomBias ) * _BloomStrength;
					
					float pix00 = Luminance(tex2D (_MainCameraTex, uv00 ).rgb);		pix00 = saturate( pix00 - _BloomBias ) * _BloomStrength;
					float pix40 = Luminance(tex2D (_MainCameraTex, uv40 ).rgb);		pix40 = saturate( pix40 - _BloomBias ) * _BloomStrength;
					
					
					float pix01 = Luminance(tex2D (_MainCameraTex, uv01 ).rgb);		pix01 = saturate( pix01 - _BloomBias ) * _BloomStrength;
					float pix41 = Luminance(tex2D (_MainCameraTex, uv41 ).rgb);		pix41 = saturate( pix41 - _BloomBias ) * _BloomStrength;
					
					float pix02 = Luminance(tex2D (_MainCameraTex, uv02 ).rgb);		pix02 = saturate( pix02 - _BloomBias ) * _BloomStrength;
					float pix42 = Luminance(tex2D (_MainCameraTex, uv42 ).rgb);		pix42 = saturate( pix42 - _BloomBias ) * _BloomStrength;
					
					float pix03 = Luminance(tex2D (_MainCameraTex, uv03 ).rgb);		pix03 = saturate( pix03 - _BloomBias ) * _BloomStrength;
					float pix43 = Luminance(tex2D (_MainCameraTex, uv43 ).rgb);		pix43 = saturate( pix43 - _BloomBias ) * _BloomStrength;
					
					
					float pix24 = Luminance(tex2D (_MainCameraTex, uv24 ).rgb);		pix24 = saturate( pix24 - _BloomBias ) * _BloomStrength;
					float pix14 = Luminance(tex2D (_MainCameraTex, uv14 ).rgb);		pix14 = saturate( pix14 - _BloomBias ) * _BloomStrength;
					float pix34 = Luminance(tex2D (_MainCameraTex, uv34 ).rgb);		pix34 = saturate( pix34 - _BloomBias ) * _BloomStrength;
					
					float pix04 = Luminance(tex2D (_MainCameraTex, uv04 ).rgb);		pix04 = saturate( pix04 - _BloomBias ) * _BloomStrength;
					float pix44 = Luminance(tex2D (_MainCameraTex, uv44 ).rgb);		pix44 = saturate( pix44 - _BloomBias ) * _BloomStrength;
					#endif
					//pix00 = saturate(pix00 - .98) + .98;
					
	//				float blurRes = lumDec00 * 0.0625 +	lumDec10 * 0.125 + 	lumDec20 * 0.0625 +
	//								lumDec01 * 0.125 + 	lumDec11 * 0.25 + 	lumDec21 * 0.125 +
	//								lumDec02 * 0.0625 +	lumDec12 * 0.125 +	lumDec22 * 0.0625;
	
					#ifndef FIVE_BLUR_STEPS
					float blurRes = pix01 * lumDec01 * 0.0625 +	pix11 * lumDec11 * 0.125 + 	pix21 * lumDec21 * 0.0625 +
									pix02 * lumDec02 * 0.125 + 	pix12 * lumDec12 * 0.25 + 	pix22 * lumDec22 * 0.125 +
									pix03 * lumDec03 * 0.0625 +	pix13 * lumDec13 * 0.125 +	pix23 * lumDec23 * 0.0625;
					#else
					//1	 4	  7	    4	1
					//4	 16	  26	16	4
					//7	 26   41	26	7
					//4	 16   26	16	4
					//1	 4	  7 	4	1
					
	//				float blurRes = pix00 * lumDec00 + pix10 * lumDec10 * 4.0 + pix20 * lumDec20 * 7.0 + pix30 * lumDec30 * 4.0 + pix40 * lumDec40
	//								+ pix01 * lumDec01 * 4.0 + pix11 * lumDec11 * 16.0 + pix21 * lumDec21 * 26.0 + pix31 * lumDec31 * 16.0 + pix41 * lumDec41 * 4.0
	//								+ pix02 * lumDec02 * 7.0 + pix12 * lumDec12 * 26.0 + pix22 * lumDec22 * 41.0 + pix32 * lumDec32 * 26.0 + pix42 * lumDec42 * 7.0
	//								+ pix03 * lumDec03 * 4.0 + pix13 * lumDec13 * 16.0 + pix23 * lumDec23 * 26.0 + pix33 * lumDec33 * 16.0 + pix43 * lumDec43 * 4.0
	//								+ pix04 * lumDec04 + pix14 * lumDec14 * 4.0 + pix24 * lumDec24 * 7.0 + pix34 * lumDec34 * 4.0 + pix44 * lumDec44;
					#ifdef REAL_LUMINANCE_BLOOM
					float lumBlur = lumDec00 + lumDec10 * 4.0 + lumDec20 * 7.0 + lumDec30 * 4.0 + lumDec40
									+ lumDec01 * 4.0 + lumDec11 * 16.0 + lumDec21 * 26.0 + lumDec31 * 16.0 + lumDec41 * 4.0
									+ lumDec02 * 7.0 + lumDec12 * 26.0 + lumDec22 * 41.0 + lumDec32 * 26.0 + lumDec42 * 7.0
									+ lumDec03 * 4.0 + lumDec13 * 16.0 + lumDec23 * 26.0 + lumDec33 * 16.0 + lumDec43 * 4.0
									+ lumDec04 + lumDec14 * 4.0 + lumDec24 * 7.0 + lumDec34 * 4.0 + lumDec44;
									
					lumBlur *= 0.00366300366;
					lumBlur *= 10.0;
					#endif
					
					float pixBlur = pix00 + pix10 * 4.0 + pix20 * 7.0 + pix30 * 4.0 + pix40
									+ pix01 * 4.0 + pix11 * 16.0 + pix21 * 26.0 + pix31 * 16.0 + pix41 * 4.0
									+ pix02 * 7.0 + pix12 * 26.0 + pix22 * 41.0 + pix32 * 26.0 + pix42 * 7.0
									+ pix03 * 4.0 + pix13 * 16.0 + pix23 * 26.0 + pix33 * 16.0 + pix43 * 4.0
									+ pix04 + pix14 * 4.0 + pix24 * 7.0 + pix34 * 4.0 + pix44;
									
					pixBlur *= 0.00366300366;
					#endif
				#else
					float pixBlur = 0.0;
					
					//float oneOverBlurStepsSquared = 1.0 / (BLUR_STEPS * BLUR_STEPS);
					
					for (int xStep = -BLUR_SIZE; xStep <= BLUR_SIZE; xStep++) {
						for (int yStep = -BLUR_SIZE; yStep <= BLUR_SIZE; yStep++) {
							float2 curPixUV = i.uv_MainCameraTex + float2(xStep, yStep) * _BlurDeltaUV;
						
							float curPix = Luminance( tex2Dlod(_MainCameraTex, float4(curPixUV, 0.0, 0.0) ).rgb);		curPix = saturate( curPix - _BloomBias ) * _BloomStrength;
							pixBlur += curPix;
						}
					}
					
					float pixBlurCoefficient = (BLUR_SIZE * 2.0 + 1.0);
					
					pixBlur = pixBlur / (pixBlurCoefficient * pixBlurCoefficient);
				#endif

				//float blurRes = .1;
				
				//c = GoHDRApplyCorrection( fixed4(blurRes * 10.0) );
				
				
				
//				for (int i = 0; i < 40; i++) {
//					blurRes = tex2D( _MainCameraTex, uv11 ).r;
//				}
				
				//c = tex2D( _MainCameraTex, i.uv_MainCameraTex );
				
				//clip(c.a - 1);
				//c.rgb = 1.0f;//lumBlur;
				
				//c.a = 1.0;
//				if ( saturate(pixBlur - .9) > 0.0)
//					c.a = lumBlur;
//				else
//					c.a = 0.0;
					
				//c.a = lumBlur * saturate( saturate( pixBlur - .9 ) * 1 );// + .98;
				//c.a = pixBlur * pixBlur;
				
				//c.a = 0.0;				
				
				//c.a = pixBlur;// * 25.0;
				
				//c.a *= .25;
				
				c.rgb = pixBlur;//c.a;
				
//				c.gb = 0.0;
//				
//				c.r = c.a * 100.0;
				
				//#endif
				
				//c.a = .5;
				
				return c;
			}
			
			ENDCG
		}
	}
}

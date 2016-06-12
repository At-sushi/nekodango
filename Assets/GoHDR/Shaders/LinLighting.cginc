#ifndef LINEARLIGHTING_CG_INCLUDED
#define LINEARLIGHTING_CG_INCLUDED

//Disables gamma correction in all of the shaders.
//#define GAMMA_1

#define MOBILE_GAMMA

#if defined(MOBILE_GAMMA)
	#define GAMMA_2_0
#else
	#ifndef GAMMA_1
		#define GAMMA 2.2
		#define INV_GAMMA 0.454545
	#else
		#define GAMMA 1
		#define INV_GAMMA 1
	#endif
#endif

#define GOLIN_DECODETEXTURES
#define GOLIN_ENCODEGAMMA

//
//Workflow:
//Texture => Decode => Process => Encode

#ifdef GAMMA_2_0
	//#define LLDecodeGamma(a) a * a
	//Decoding
	inline fixed LLDecodeGamma ( fixed _color ) {
		return _color * _color;
	}
	
	inline fixed3 LLDecodeGamma ( fixed3 _color ) {
		return _color * _color;
	}
	
	inline fixed4 LLDecodeGamma ( fixed4 _color ) {
		return fixed4(_color.rgb * _color.rgb, _color.a);
	}
	
	//Encoding
	//#define LLEncodeGammaDef(a) sqrt(a)
	inline fixed LLEncodeGammaFunc ( fixed _color ) {
		return sqrt(_color);
	}
	
	inline fixed3 LLEncodeGammaFunc ( fixed3 _color ) {
		return sqrt(_color);
	}
	
	inline fixed4 LLEncodeGammaFunc ( fixed4 _color ) {
		return fixed4(sqrt(_color.rgb), _color.a);
	}
	
#elif !defined(GAMMA_1)
	//#define LLDecodeGamma(a) pow(a, GAMMA)
	inline fixed LLDecodeGamma ( fixed _color ) {
		return pow(_color, GAMMA);
	}
	
	inline fixed3 LLDecodeGamma ( fixed3 _color ) {
		return pow(_color, GAMMA);
	}
	
	inline fixed4 LLDecodeGamma ( fixed4 _color ) {
		return fixed4( pow(_color.rgb, GAMMA), _color.a);
	}

	//#define LLEncodeGammaFunc(a) pow(a, INV_GAMMA)
	inline fixed LLEncodeGammaFunc ( fixed _color ) {
		return pow(_color, INV_GAMMA);
	}
	
	inline fixed3 LLEncodeGammaFunc ( fixed3 _color ) {
		return pow(_color, INV_GAMMA);
	}
	
	inline fixed4 LLEncodeGammaFunc ( fixed4 _color ) {
		return fixed4( pow(_color.rgb, INV_GAMMA), _color.a);
		//return pow(_color, INV_GAMMA);
	}
#else
	//#define LLDecodeGamma(a) a
	inline fixed LLDecodeGamma ( fixed _color ) {
		return _color;
	}
	
	inline fixed3 LLDecodeGamma ( fixed3 _color ) {
		return _color;
	}
	
	inline fixed4 LLDecodeGamma ( fixed4 _color ) {
		return _color;
	}
	
	//Encoding
	//#define LLEncodeGammaDef(a) a
	inline fixed LLEncodeGammaFunc ( fixed _color ) {
		return _color;
	}
	
	inline fixed3 LLEncodeGammaFunc ( fixed3 _color ) {
		return _color;
	}
	
	inline fixed4 LLEncodeGammaFunc ( fixed4 _color ) {
		return _color;
	}
#endif

#ifdef GOLIN_DECODETEXTURES
	#define LLDecodeTex(a) LLDecodeGamma(a)
#else
	#define LLDecodeTex(a) a
#endif

#ifdef GOLIN_ENCODEGAMMA
	#define LLEncodeGamma(a) LLEncodeGammaFunc(a)
#else
	#define LLEncodeGamma(a) a
#endif

#endif
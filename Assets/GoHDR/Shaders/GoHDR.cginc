#ifndef GOHDR_CG_INCLUDED
#define GOHDR_CG_INCLUDED

#define ENABLE_GO_HDR
#define SEPARATE_LUMINANCE

#include "UnityCG.cginc"

half goHDRLightWeight;

inline fixed3 GoHDRApplyCorrection ( fixed3 _color ) {
	//c * (1 + c/w^2)/(1+c);
	#ifdef ENABLE_GO_HDR
	#ifdef SEPARATE_LUMINANCE
		fixed lum = Luminance(_color);
		
		fixed tonemappedLum = lum * (1.0f + lum/goHDRLightWeight) / (1.0f + lum);
		
		return tonemappedLum * _color / lum;
	#else
		return _color * (1.0f + _color/goHDRLightWeight) / (1.0f + _color);
	#endif
	#else
	return _color;
	#endif
}

inline fixed3 GoHDRApplyCorrection ( fixed3 _color, half _customLightWeight ) {
	//c * (1 + c/w^2)/(1+c);
	#ifdef ENABLE_GO_HDR
	#ifdef SEPARATE_LUMINANCE
		fixed lum = Luminance(_color);
		
		fixed tonemappedLum = lum * (1.0f + lum/_customLightWeight) / (1.0f + lum);
		
		return tonemappedLum * _color / lum;
	#else
		return _color * (1.0f + _color/_customLightWeight) / (1.0f + _color);
	#endif
	#else
	return _color;
	#endif
}

inline fixed4 GoHDRApplyCorrection ( fixed4 _color ) {
	//c * (1 + c/w^2)/(1+c);
	#ifdef ENABLE_GO_HDR
	return fixed4( GoHDRApplyCorrection(_color.rgb), _color.a );
	#else
	return _color;
	#endif
}

inline fixed4 GoHDRApplyCorrection ( fixed4 _color, half _customLightWeight ) {
	//c * (1 + c/w^2)/(1+c);
	#ifdef ENABLE_GO_HDR
	return fixed4( GoHDRApplyCorrection(_color.rgb, _customLightWeight), _color.a );
	#else
	return _color;
	#endif
}


#endif
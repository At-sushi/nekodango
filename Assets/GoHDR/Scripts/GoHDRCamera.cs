using UnityEngine;
using System.Collections;
using System.Collections.Generic;

[RequireComponent(typeof(Camera))]
[AddComponentMenu("Go HDR/Camera")]
public class GoHDRCamera : MonoBehaviour {
	//public Renderer testPlane;
	public float adaptationSpeed = 1f;
	public float minLimit = .1f;
	public float maxLimit = 100f;
	public float luminosityBoost = .2f;
	public int adaptationSmoothingFilter = 25;
	
//	public float skyBrightness = 4f;
	
	public bool bloomOn = false;
	public float bloomStrength = 25.0f;
	public float bloomBias = .98f;
	
	private float maxPossibleBrightness;
	
	private Camera luminosityCamera = null;
	private Camera downsampledCamera = null;
	
	//public Renderer testRenderer = null;
	
	private GoHDRManager gohdrManager = null;
	
//	private float textureScale = .03f;
	private int lumCamScaledWidth = 512, lumCamScaledHeight = 512;
	private int dsCamScaledWidth = 512, dsCamScaledHeight = 512;
	
	private Texture2D luminosityTexture = null;
	private Texture2D dsCameraTexture = null;
	
	private Texture2D dummyTexture;
	
	private Material bloomMaterial;
	
	//private float maxBrightness = 1.0f;
	
//	public void Awake()
//    {
//		CreateRenderObjects();
//		
//		//texWidth = (int) (renderCamera.pixelWidth * textureScale);
//		//int height = (int) (renderCamera.pixelHeight * textureScale);
//		
//		//Debug.Log(texWidth + " x " + texWidth);
//		//texWidth = GetNearestPOT( texWidth );
//		//Debug.Log(texWidth + " x " + texWidth);
//		
//		//camScaledHeight = Mathf.FloorToInt( renderCamera.pixelHeight * camScaledWidth / renderCamera.pixelWidth );
//		
//		//Debug.Log("cam: " + camScaledWidth + " x " + camScaledHeight);
//		
//		renderTexture = new Texture2D(camScaledWidth, camScaledWidth, TextureFormat.ARGB32, false);
//        renderTexture.anisoLevel = 1;
//        renderTexture.filterMode = FilterMode.Point;
//        renderTexture.wrapMode = TextureWrapMode.Clamp;
//        renderTexture.hideFlags = HideFlags.HideAndDontSave;
//    }
	
	public void OnDisable() {
//		Debug.Log("GoHDRCamera OnDisable");
//		if (null != gohdrManager)
//			gohdrManager.SetLightWeight(1f);
		Shader.SetGlobalFloat("goHDRLightWeight", 1f);
		Shader.SetGlobalFloat("skyboxLightweight", 1f );

	}
	
	public void Start(){
		GameObject gohdrManagerGO = GameObject.Find("GoHDRManager");
		
		if (null != gohdrManagerGO) {
			Destroy(gohdrManagerGO);
		}
		
		luminosityBoost = 1f - luminosityBoost;
		
		//if (null == gohdrManagerGO) {
			//Debug.Log("null == gohdrManagerGO");
			gohdrManagerGO = new GameObject("GoHDRManager");
			gohdrManagerGO.hideFlags = HideFlags.HideAndDontSave;
			//gohdrManagerGO.hideFlags = HideFlags.DontSave;
			
			gohdrManager = gohdrManagerGO.AddComponent<GoHDRManager>();
			
			gohdrManager.adaptationSpeed = adaptationSpeed;
			gohdrManager.minLimit = minLimit;
			gohdrManager.maxLimit = maxLimit;
			gohdrManager.luminosityBoost = luminosityBoost;
		//}
		
		//texWidth = (int) (renderCamera.pixelWidth * textureScale);
		//int height = (int) (renderCamera.pixelHeight * textureScale);
		
		//Debug.Log(texWidth + " x " + texWidth);
		//texWidth = GetNearestPOT( texWidth );
		//Debug.Log(texWidth + " x " + texWidth);
		
		//camScaledHeight = Mathf.FloorToInt( renderCamera.pixelHeight * camScaledWidth / renderCamera.pixelWidth );
		lumCamScaledHeight = (int)(camera.pixelRect.height * .125f);
		//lumCamScaledHeight = (int)(camera.pixelRect.height * .5f);
		lumCamScaledWidth = Mathf.FloorToInt( lumCamScaledHeight * camera.aspect );
//		Debug.Log("lum cam: " + lumCamScaledWidth + " x " + lumCamScaledHeight);
		
		if (bloomOn) {
			dsCamScaledHeight = (int)(camera.pixelRect.height * .5f);
			dsCamScaledWidth = Mathf.FloorToInt( dsCamScaledHeight * camera.aspect );
//			Debug.Log("ds cam: " + dsCamScaledWidth + " x " + dsCamScaledHeight);
		}
				
		if (!dummyTexture)
        {
            dummyTexture = new Texture2D(1, 1);
            dummyTexture.hideFlags = HideFlags.HideAndDontSave;
        }
		
		CreateRenderTextures();
		
		if (bloomOn) {
			if (!bloomMaterial) {
				//Debug.Log("!bloomMaterial");
				bloomMaterial = new Material( Shader.Find("GoHDR/Bloom") );
				
//				bloomMaterial.SetTexture("_LuminosityTex", luminosityTexture);
				bloomMaterial.SetTexture("_MainCameraTex", dsCameraTexture);
				
				float blurDeltaUV = 1f / dsCamScaledHeight;
				
				bloomMaterial.SetFloat("_BlurDeltaUV", blurDeltaUV);
				bloomMaterial.SetFloat("_BloomStrength", bloomStrength);
				bloomMaterial.SetFloat("_BloomBias", bloomBias);
			}
		}
		
		CreateRenderCameras();
		
		
		
		//pixelIntensities = new float[camScaledWidth * camScaledWidth];
	}
	
	public void OnPreRender()
    {
        if (!enabled)
            return;

        if (luminosityCamera == null)
            CreateRenderCameras();
		
		if (null == luminosityTexture || null == dsCameraTexture) {
			CreateRenderTextures();
			
//			bloomMaterial.SetTexture("_MainCameraTex", dsCameraTexture);
		}
		
		luminosityCamera.enabled = true;
		
        luminosityCamera.Render();

		luminosityTexture.ReadPixels(new Rect(0, 0, lumCamScaledWidth, lumCamScaledHeight), 0, 0, false);
        luminosityTexture.Apply(false, false);
		
		UpdateLightWeight( luminosityTexture );
		
		luminosityCamera.enabled = false;
		
		if (bloomOn) {
			downsampledCamera.enabled = true;
			downsampledCamera.Render();
			
			dsCameraTexture.ReadPixels(new Rect(0, lumCamScaledHeight, dsCamScaledWidth, dsCamScaledHeight), 0, 0, false);
			dsCameraTexture.Apply(false, false);
			downsampledCamera.enabled = false;
		}
	}
	
	List<float> maxBrightnessValues = new List<float>();
	
	private void UpdateLightWeight(Texture2D _tex) {
		//testPlane.sharedMaterial.SetTexture("_LuminosityTex", _tex);
		
		//testPlane.transform.localScale = new Vector3(camera.aspect, 1f, 1f);
		
		Color[] pixels = _tex.GetPixels();
		
//		int brightestX = 0, brightestY = 0;
		
		float maxBrightness = 0.0f;
		
		for (int y = 0; y < lumCamScaledHeight; y++) {
			for (int x = 0; x < lumCamScaledWidth; x++) {
				int index = y * lumCamScaledWidth + x;
				
				float curBrightness = ( pixels[index].r + pixels[index].g * 0.00392156862f ) * 10.0f;	//shaderValue/2, because of Unity's light doubling
				
				if (curBrightness > maxBrightness) {
					maxBrightness = curBrightness;
//					brightestX = x;
//					brightestY = y;
				}
			}
		}
		
//		for (int x = brightestX - 2; x <= brightestX + 2; x++) {
//			for (int y = brightestY - 2; y <= brightestY + 2; y++) {
//				if (x < 0 || x >= lumCamScaledWidth || y < 0 || y >= lumCamScaledHeight)
//					continue;
//				
//				pixels[y * lumCamScaledWidth + x] = Color.blue;
//			}
//		}
//		
//		
//		
//		_tex.SetPixels(pixels);
//		_tex.Apply();
		
		maxBrightness = Mathf.Min(maxBrightness, maxPossibleBrightness);
		
		maxBrightness *= luminosityBoost;
		
		//
		//Max brightness smoothing
		
		//Stack the max brightness values
		if (maxBrightnessValues.Count < adaptationSmoothingFilter) {
			maxBrightnessValues.Add( maxBrightness );
		} else {
			maxBrightnessValues.RemoveAt(0);
			maxBrightnessValues.Add( maxBrightness );
		}
		
		float smoothedBrightness = 0f;
		
		foreach (float curBrightness in maxBrightnessValues) {
			smoothedBrightness += curBrightness;	
		}
		
		smoothedBrightness /= maxBrightnessValues.Count;
		
		//Debug.Log("maxBrightness: " + maxBrightness + "[" + brightestX + "; " + brightestY + "]");
		
		gohdrManager.UpdateLightWeight( smoothedBrightness * smoothedBrightness );
		
//		float avgBrightness = 0.0f;
//		
//		for (int y = 0; y < lumCamScaledHeight; y++) {
//			for (int x = 0; x < lumCamScaledWidth; x++) {
//				int index = y * lumCamScaledWidth + x;
//				
//				float curBrightness = ( pixels[index].r + pixels[index].g * 0.00392156862f ) * 10.0f;	//shaderValue/2, because of Unity's light doubling
//				
//				avgBrightness += curBrightness;
//			}
//		}
//		
//		avgBrightness = avgBrightness / (lumCamScaledWidth * lumCamScaledHeight);
//		
//		avgBrightness = avgBrightness * 2f;
//		
//		gohdrManager.UpdateLightWeight( avgBrightness * avgBrightness );
		
//		pixels[brightestY * camScaledWidth + brightestX] = Color.red;
//		
//		_tex.SetPixels( pixels );
//		_tex.Apply();
		
		//Debug.LogWarning("maxBrightness: " + maxBrightness);
	}
	
	void OnGUI()
    {
        if (Event.current.type != EventType.repaint)
            return;
		
		if (bloomOn) {
       		Graphics.DrawTexture(camera.pixelRect, dummyTexture, bloomMaterial);
		}
    }
	
//	public void OnDestroy()
//    {
//		Debug.Log("OnDisable");
//        if (renderTexture)
//		{
//            DestroyImmediate(renderTexture);
//			renderTexture = null;
//		}
//		
//        if (renderCamera)
//        {
//            if (Application.isPlaying)
//                Destroy(renderCamera.gameObject);
//            else
//                DestroyImmediate(renderCamera.gameObject);
//			
//			renderCamera = null;
//        }
//    }
	private float GetColorLuminosity(Color _color) {
		return 0.2126f * _color.r + 0.7152f * _color.g + 0.0722f * _color.b;	
	}
	
	private float GetMasPossibleBrightness() {
		Light[] lights = GameObject.FindObjectsOfType( typeof(Light) ) as Light[];
		
		float brightestLight = 0f;
		
		foreach (Light light in lights) {
			//if (light.type == LightType.Directional)
			brightestLight = Mathf.Max(brightestLight, light.intensity * GetColorLuminosity( light.color ) );
		}
		
		return Mathf.Max(brightestLight * 2f, GetSkyBrightness());
		
	}
	
	private float GetSkyBrightness() {
		Light[] lights = GameObject.FindObjectsOfType( typeof(Light) ) as Light[];
		
		float brightestDirectionalLight = 0f;
		
		foreach (Light light in lights) {
			if (light.type == LightType.Directional)
				brightestDirectionalLight = Mathf.Max(brightestDirectionalLight, light.intensity * GetColorLuminosity( light.color ) );
		}
		
		//_color * (1.0f + _color/goHDRLightWeight) / (1.0f + _color)
		
		//c' = c * (1 + c/lw)/(1 + c)
		//c' + c * c' = c + c^2/lw
		//c' = c + c^2/lw - c * c'
		
		//0.5 - 4
		//1 - 2
		
		//0.5 light = sky 1
		//1 light = sky 1
		
		//if (lum < skylight_lum) => skybox cannot get darker;
		//						else skybox gets darker;
		
		//res = m * c * (1 + c/lw)/(1 + c)
		
		
		//Debug.Log("GetSkyBrightness: " + brightestDirectionalLight * 2f);
		//0.5 & 0.3 = 0.79607843137
		//0.5 & 0.4 = 0.59215686274
		//0.5 & 0.5 = 0.5
		//0.5 & 1 = 0.37647058823
		//0.5 & 2 = 0.34509803921
		//0.5 & 4 = 0.33725490196
		//0.5 & 8 = 0.33333333333
		
		//Shader.SetGlobalFloat("_skyboxMultiplier", .25f );
		
//		return brightestDirectionalLight;
		
		//return 2f * brightestDirectionalLight;//Mathf.Max(4f, 2f * brightestDirectionalLight);//brightestDirectionalLight * 2f;	//Sky is a bit brighter than the directional light
		return 2f * brightestDirectionalLight;// * luminosityBoost;
//		Debug.Log("brightestDirectionalLight: " + brightestDirectionalLight);
//		return skyBrightness;
	}
	
	private void CreateRenderTextures() {
		if (null == luminosityTexture) {
			luminosityTexture = new Texture2D(lumCamScaledWidth, lumCamScaledHeight, TextureFormat.RGB24, false);
	        luminosityTexture.anisoLevel = 0;
	        luminosityTexture.filterMode = FilterMode.Point;
	        luminosityTexture.wrapMode = TextureWrapMode.Clamp;
	        luminosityTexture.hideFlags = HideFlags.HideAndDontSave;
		}
		
		if (bloomOn && null == dsCameraTexture) {
			dsCameraTexture = new Texture2D( dsCamScaledWidth, dsCamScaledHeight, TextureFormat.RGB24, false );
			dsCameraTexture.anisoLevel = 1;
	        dsCameraTexture.filterMode = FilterMode.Trilinear;
	        dsCameraTexture.wrapMode = TextureWrapMode.Clamp;
	        dsCameraTexture.hideFlags = HideFlags.HideAndDontSave;
		}

	}
	
	private void CreateRenderCameras()
    {
        if (!luminosityCamera)
        {
//			Debug.Log("CreateRenderObjects");
            GameObject luminosityCamGO = null;
			GameObject dsCamGO = null;
			
			Transform luminosityCamGOTransform = transform.FindChild("GoHDR Luminosity Camera");
			Transform dsCamGOTransform = transform.FindChild("GoHDR DS Camera");
			
			if (null != luminosityCamGOTransform) {
				luminosityCamGO = luminosityCamGOTransform.gameObject;

			} else {
				luminosityCamGO = new GameObject("GoHDR Luminosity Camera", typeof(Camera));
				
				luminosityCamGO.transform.parent = transform;
				luminosityCamGO.transform.localPosition = Vector3.zero;
				luminosityCamGO.transform.localRotation = Quaternion.identity;
	            //go.hideFlags = HideFlags.HideAndDontSave;
				//go.hideFlags = HideFlags.DontSave;
			}
			
			if (bloomOn) {
				if (null != dsCamGOTransform) {
					dsCamGO = dsCamGOTransform.gameObject;
				} else {
					dsCamGO = new GameObject("GoHDR DS Camera", typeof(Camera) );
					dsCamGO.transform.parent = transform;
					dsCamGO.transform.localPosition = Vector3.zero;
					dsCamGO.transform.localRotation = Quaternion.identity;
					
					dsCamGO.camera.CopyFrom( camera );
					
					Skybox camSkybox = gameObject.GetComponent<Skybox>();
					
					if (null != camSkybox) {
						Skybox dsCamSkybox = dsCamGO.AddComponent<Skybox>();
						dsCamSkybox.material = camSkybox.material;
					}
				}
			}
			
			float skyBrightness = GetSkyBrightness();
			
			luminosityCamera = luminosityCamGO.camera;
            luminosityCamera.enabled = true;
			luminosityCamera.clearFlags = CameraClearFlags.Color;
			luminosityCamera.backgroundColor = EncodeFloatRG( Mathf.Min(skyBrightness, 9.9f) * 0.1f );
			
			maxPossibleBrightness = GetMasPossibleBrightness();
			
			gohdrManager.skyBrightness = skyBrightness;
			
			
//			Debug.Log("skyBrightness: " + skyBrightness + " maxPossibleBrightness: " + maxPossibleBrightness );
			
			//Debug.Log("renderCamera.backgroundColor: " + luminosityCamera.backgroundColor.ToString() );
			
			//Debug.Log("renderCamera.backgroundColor value: " + ( ( luminosityCamera.backgroundColor.r + luminosityCamera.backgroundColor.g * 0.00392156862f ) * 20.0f ) );
			
			//camera.SetReplacementShader( Shader.Find("Hidden/Go HDR/Cam HQ"), "");
			
			luminosityCamera.SetReplacementShader( Shader.Find("Hidden/GoHDR/Luminosity HQ"), "");
			
			luminosityCamera.pixelRect = new Rect( 0, 0, lumCamScaledWidth, lumCamScaledHeight);
//			Debug.Log("camScaledWidth: " + camScaledWidth + " camScaledHeight: " + camScaledHeight);
//			Debug.Log("luminosityCamera.pixelRect: " + luminosityCamera.pixelRect.ToString() ); 
			
			if (bloomOn) {
				downsampledCamera = dsCamGO.camera;
				downsampledCamera.enabled = true;
				downsampledCamera.pixelRect = new Rect( 0, lumCamScaledHeight, dsCamScaledWidth, dsCamScaledHeight);
			}
        }
    }
	
	private float Frac(float v)
	{
	   return v - Mathf.Floor(v);
	}
	
	private Color EncodeFloatRG( float v )
	{
		Color kEncodeMul = new Color(1f, 255f, 0f, 0f);
		float kEncodeBit = 1f/255f;
		
		Color enc = kEncodeMul * v;
		enc.r = Frac (enc.r);
		enc.g = Frac (enc.g);
		
		enc.r -= enc.g * kEncodeBit;
		
		return enc;
	}
	
	private int GetNearestPOT(int x)
    {
		int j = 65536;
		
		while(true) {
			if (x > j) {
				//x = 1920
				//j = 1024
				
				//2048 - 1920 < 896 ? 512
				//128 < 896 ? 
				return ((j<<1) - x) < (x - j)? (j<<1): (j); 
			} else if (x == j)
				return j;
			
			j = j >> 1;
		}
    }
}

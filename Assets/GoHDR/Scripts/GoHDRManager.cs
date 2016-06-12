using UnityEngine;
using System.Collections;
using System.Collections.Generic;

public class GoHDRManager : MonoBehaviour {
	public float adaptationSpeed = .3f;
	public float minLimit = .1f;
	public float maxLimit = 100f;
	
	public float skyBrightness;
	public float luminosityBoost;
	//private float adaptationSpeed;
	
//	private List<Material> allMaterials = new List<Material>();
	
	private float currentLightWeight = 1f, targetLightWeight = 1f;
	
	private bool firstLightUpdate;
	
	//private float lightUpdatedTime = 0.0f;
	
	public void SetLightWeight(float _weight) {
		currentLightWeight = _weight;
		Shader.SetGlobalFloat("goHDRLightWeight", currentLightWeight);

//		Shader.SetGlobalFloat("skyboxLightweight", 1f );
	}
	
	public void UpdateLightWeight(float _weight) {
		targetLightWeight = Mathf.Clamp(_weight, minLimit * minLimit, maxLimit * maxLimit);
		
		if (firstLightUpdate) {
			firstLightUpdate = false;
			currentLightWeight = targetLightWeight;
		}
	}
	
//	public void RegisterNewGoHDRRenderer(Renderer _renderer) {
//		Material curMat = _renderer.sharedMaterial;
//		
//		if (!allMaterials.Contains( curMat ) )
//			allMaterials.Add( curMat );
//	}
	
//	public void EmptyRenderersList() {
//		allMaterials.Clear();	
//	}
	
	private System.DateTime lastDirChangeTime;
	
	// Use this for initialization
	void Start () {
//		Debug.Log("GoHDRManager Start");
//		GoHDRCamera[] gohdrCameras = GameObject.FindObjectsOfType( typeof(GoHDRCamera) ) as GoHDRCamera[];
//		
//		if (null == gohdrCameras) {
//			Debug.LogError("No Go HDR cameras found. Aborting.");
//			DestroyImmediate(this);
//			return;
//		}
//		
//		foreach (GoHDRCamera cam in gohdrCameras) {
//			cam.Init( this );
//		}
		
//		currentLightWeight = 2f;	//Take sky into account
		
//		Renderer[] allRenderers = GameObject.FindObjectsOfType( typeof(Renderer) ) as Renderer[];
//		
//		foreach (Renderer rend in allRenderers) {
//			//Debug.Log("Renderer: " + rend.name);
//			
//			Material curMat = rend.sharedMaterial;
//			
//			if (null == curMat)
//				continue;
//			
//			if ( !allMaterials.Contains( curMat ) ) {
//				allMaterials.Add( curMat );	
//			}
//		}
		firstLightUpdate = true;
	}
	
	//System.DateTime lastWeightChange;
	
//	private float prevDir = -1f;
	
	void FixedUpdate () {
		//Debug.Log("Update currentLightWeight: " + currentLightWeight + " targetLightWeight: " + targetLightWeight);
		//if (currentLightWeight != targetLightWeight) {
			//Debug.Log("currentLightWeight != targetLightWeight");
			float dir = Mathf.Sign( targetLightWeight - currentLightWeight );
		
//			//Changed direction?
//			if (dir * prevDir < 0f) {
//				//Enough time passed since last dir change?
//				if ( (System.DateTime.Now - lastDirChangeTime).TotalMilliseconds < 1000f )
//					return;
//			
//				lastDirChangeTime = System.DateTime.Now;
//			}
//			
//			prevDir = dir;
			
			float curAdaptationSpeed = adaptationSpeed * Time.deltaTime;//(float)(System.DateTime.Now - lastWeightChange).TotalSeconds;
			
			//curAdaptationSpeed = Mathf.Min(curAdaptationSpeed * currentLightWeight, .1f);
		
			//float speedScale = Mathf.Min(Mathf.Max(currentLightWeight * currentLightWeight, .1f), 1f);
//			float speedScale = Mathf.Abs(currentLightWeight - targetLightWeight);
//			speedScale = 1f - speedScale*speedScale;
//			speedScale = 1f - speedScale;
//			speedScale = Mathf.Clamp(speedScale, .1f, .5f) * 10f;
//			speedScale = speedScale * speedScale * 25f;
//			speedScale *= 25f;
		
			//speedScale = Mathf.Max(currentLightWeight * currentLightWeight;
			//Debug.Log("speedScale: " + speedScale);
		
//			curAdaptationSpeed *= speedScale;// * Mathf.Clamp( Mathf.Abs(targetLightWeight - currentLightWeight), .5f, 5f);//Mathf.Min(currentLightWeight * 3f, 1.0f);	//Slow down closer to zero
			
			curAdaptationSpeed *= 2f;
		
			if (dir < 0f)
				curAdaptationSpeed *= 2.5f;// Mathf.Abs(targetLightWeight - currentLightWeight);
		
			//adaptationSpeed = 1f - adaptationSpeed;
			
			//curAdaptationSpeed = curAdaptationSpeed * curAdaptationSpeed;
			
//			float prevLightWeight = currentLightWeight;
		
			currentLightWeight = Mathf.SmoothStep(currentLightWeight, currentLightWeight + dir * curAdaptationSpeed, Time.deltaTime * 5f);
//			currentLightWeight = Mathf.SmoothStep(currentLightWeight, targetLightWeight,
//									Time.deltaTime * 1f / Mathf.Abs(targetLightWeight - currentLightWeight) );
			
			//Will cross the target weight?
			if (dir < 0.0f && currentLightWeight < targetLightWeight)
				currentLightWeight = targetLightWeight;
			else if (dir > 0.0f && currentLightWeight > targetLightWeight)
				currentLightWeight = targetLightWeight;
			
			//currentLightWeight = Mathf.Lerp(currentLightWeight, targetLightWeight, (Time.time - lightUpdatedTime) * 10000f);
			
			//Debug.Log("currentLightWeight: " + currentLightWeight + "; targetLightWeight: " + targetLightWeight);
			
			//float _006value = .06f * ( 1.0f + .06f / (currentLightWeight * currentLightWeight) ) / (1.0f + .06f);
		
			//Skybox
			Shader.SetGlobalFloat("goHDRLightWeight", currentLightWeight);
		
			float skyboxLightweight = currentLightWeight / (skyBrightness * skyBrightness);
		
//			Debug.Log("luminosityBoost: " + luminosityBoost);
		
//			if (skyboxLightweight < 1f)
//				Shader.SetGlobalFloat("_skyboxMultiplier", 0f);
//			else
//				Shader.SetGlobalFloat("_skyboxMultiplier", 1f);
		
			Shader.SetGlobalFloat("skyboxLightweight", skyboxLightweight / (luminosityBoost * luminosityBoost) );
		
//			Shader.SetGlobalFloat("_skyboxMultiplier", 4f);
		
//			Shader.SetGlobalFloat("_skyboxMultiplier", 1f / (1f + 1f/currentLightWeight) );
		
//			Debug.LogWarning("currentLightWeight: " + Mathf.Sqrt(currentLightWeight) + " targetLightWeight: " + Mathf.Sqrt(targetLightWeight) +
//			" curAdaptationSpeed: " + curAdaptationSpeed );//+ 
//			" speedScale: " + speedScale + " skyboxLightweight: " + skyboxLightweight + " skyBrightness: " + skyBrightness + " luminosityBoost: " + luminosityBoost );
			
		
			//lastWeightChange = System.DateTime.Now;
			
//			foreach (Material mat in allMaterials) {
//				if ( mat.HasProperty( "_HDRLightWeight" ) )
//					mat.SetFloat("_HDRLightWeight", currentLightWeight);
//			}
		//}
	}
}

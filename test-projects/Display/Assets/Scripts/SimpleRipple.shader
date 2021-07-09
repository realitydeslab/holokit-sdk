Shader "Unlit/SimpleRipple"
{
	Properties
	{
		// _hitPosition0 ("Hit Position0", Vector) = (0,0,0,0)
		// _hitPosition1 ("Hit Position1", Vector) = (0,0,0,0)
		// _hitPosition2 ("Hit Position2", Vector) = (0,0,0,0)
		// _impactForce("Impact Force", Float) = 0
		// _amp("Amplitude", Float) =0
		[HDR]_rippleColor("rippleColor", Color) = (1,0,0,0)
		_baseColor("baseColor", Color) = (0,1,0,0)
		_seperateSpeed("seperateSpeed", Float) =1
		_seperateMaxRadius("seperateMaxRadius", Float) =1
	}
	SubShader
	{
		Tags
        {
            "RenderPipeline"="UniversalPipeline"
            "RenderType"="Transparent"
            "Queue"="Transparent"
        }
		Pass
		{
			Name "ForwardLit"
            Tags { "LightMode" = "UniversalForward" }
 
            Blend SrcAlpha OneMinusSrcAlpha // (Traditional transparency)
			BlendOp Add // (is default anyway)
            Cull Back
            ZTest LEqual
            ZWrite Off

			HLSLPROGRAM
            #pragma vertex vert
            #pragma fragment frag

            #include "Packages/com.unity.render-pipelines.universal/ShaderLibrary/Lighting.hlsl"

			float3 _hitPosition0;
			float3 _hitPosition1; 
			float3 _hitPosition2; 
			float4 _rippleColor;
			float4 _baseColor;
			float _impactForce; 
			float _amp0;
			float _amp1;
			float _amp2;
			float _seperateSpeed;
			float _seperateMaxRadius;



			struct appdata
			{
				float4 vertex : POSITION; // OBJ POS
				float4 color : COLOR;
			};

			struct v2f {
				float4 pos: POSITION;
				float4 color : COLOR;
			};

			float greyCaculate_RippleEffect(float4 wpos, float3 hitPosition, float amp){
				// followings make a simple ripple
				float dis = distance(wpos,hitPosition);
				float fadeByDistance = clamp(-pow(dis,2)+1,0,1);
				float grey = 0; 
				if(dis <  (1- amp) * _seperateMaxRadius){
					grey = 0.5*(1+sin((dis + _Time*-1)*10)) * amp;
				}
				return grey;
			}

			v2f vert(appdata v)
			{
				v2f o;
				o.pos = TransformObjectToHClip(v.vertex);
				float4 wpos = mul(unity_ObjectToWorld, v.vertex); // 模型坐标转换为世界坐标，即：模型顶点的世界坐标

				float grey = 0; 
				grey = greyCaculate_RippleEffect(wpos, _hitPosition0, _amp0);
				grey += greyCaculate_RippleEffect(wpos, _hitPosition1, _amp1);
				grey += greyCaculate_RippleEffect(wpos, _hitPosition2, _amp2);
				grey = clamp(grey,0,1);

				float4 baseColor = v.color;
				if(_baseColor.a!=0) baseColor = _baseColor;

				o.color = lerp(baseColor, _rippleColor, grey);

				return o;
			}

			// pixel shader, no inputs needed
			float4 frag(v2f IN) : COLOR
			{
				return IN.color;
			}
			ENDHLSL
			}
	}
}
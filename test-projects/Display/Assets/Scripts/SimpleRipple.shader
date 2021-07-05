Shader "Unlit/SimpleRipple"
{
	Properties
	{
		// _hitPosition0 ("Hit Position0", Vector) = (0,0,0,0)
		// _hitPosition1 ("Hit Position1", Vector) = (0,0,0,0)
		// _hitPosition2 ("Hit Position2", Vector) = (0,0,0,0)
		// _impactForce("Impact Force", Float) = 0
		// _amp("Amplitude", Float) =0
		_rippleColor("rippleColor", Color) = (1,0,0,0)
		_seperateSpeed("seperateSpeed", Float) =1
		_seperateMaxRadius("seperateMaxRadius", Float) =1
	}
	SubShader
	{
		Pass
		{
			CGPROGRAM
			#pragma vertex vert
			#pragma fragment frag
			# include "unitycg.cginc"

			// vertex shader
			// this time instead of using "appdata" struct, just spell inputs manually,
			// and instead of returning v2f struct, also just return a single output
			// float4 clip position

		float3 _hitPosition0; // 因为expose了，在此代码中直接赋值是无效的
		float3 _hitPosition1; // 因为expose了，在此代码中直接赋值是无效的
		float3 _hitPosition2; // 因为expose了，在此代码中直接赋值是无效的
		fixed4 _rippleColor;
		float _impactForce; 
		float _amp0;
		float _amp1;
		float _amp2;
		float _seperateSpeed;
		float _seperateMaxRadius;
		// float frequency = 100;
		// float speed =-1;

			struct appdata
			{
				float4 vertex : POSITION; // OBJ POS
				fixed4 color : COLOR;
			};

		struct v2f {
				float4 pos: POSITION;
				fixed4 color : COLOR;
			};

		float greyCaculate(float4 wpos, float3 hitPosition, float amp){
			 // followings make a simple ripple
			 float dis = distance(wpos,hitPosition);
			 float fadeByDistance = clamp(-pow(dis,2)+1,0,1);
			 float grey = 0; 
			 if(dis <  (1- amp) * _seperateMaxRadius){
				 grey = 0.5*(1+sin((dis + _Time*-1)*100)) * amp;
			 }
			 return grey;
		}

		v2f vert(appdata v)
		{
			v2f o;
			o.pos = UnityObjectToClipPos(v.vertex);
			float4 wpos = mul(unity_ObjectToWorld, v.vertex); // 模型坐标转换为世界坐标，即：模型顶点的世界坐标

			float grey = 0; 
			grey = greyCaculate(wpos, _hitPosition0, _amp0);
			grey += greyCaculate(wpos, _hitPosition1, _amp1);
			grey += greyCaculate(wpos, _hitPosition2, _amp2);
			grey = clamp(grey,0,1);

			o.color = lerp(fixed4(0,1,0,0.1), _rippleColor, grey);

			return o;
		}

		// color from the material
		fixed4 _Color;

		// pixel shader, no inputs needed
		fixed4 frag(v2f IN) : COLOR
		{
			return IN.color;
		}
		ENDCG
		}
	}
}
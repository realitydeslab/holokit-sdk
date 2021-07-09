Shader "#Custom/360Cube" {
Properties {
    _MainTex("Main texture (RGB)", 2D) = "white" {}
    _Rotation("Rotation", float) = -90
    }
    SubShader {
        Tags { "Queue"="Background" "RenderType"="Background"}
        Cull Off ZWrite On
        Pass {
            ZTest Always Cull Off ZWrite On
            Fog { Mode off }
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityCG.cginc"
            sampler2D _MainTex;
            float4 _MainTex_ST;
            float _Rotation;

            struct appdata_t {
                float4 vertex : POSITION;
            };
            struct v2f {
                float4 vertex : SV_POSITION;
                float3 texcoord : TEXCOORD0;
            };
            v2f vert (appdata_t v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.texcoord = v.vertex.xyz ;
                float s = sin ( (_Rotation / 180) * UNITY_PI);
                float c = cos ( (_Rotation / 180) * UNITY_PI );
                float2x2 rotationMatrix = float2x2( c, -s, s, c);
                rotationMatrix *=0.5;
                rotationMatrix +=0.5;
                rotationMatrix = rotationMatrix * 2–1;
                o.texcoord.xz = mul(o.texcoord.xz, rotationMatrix);
                return o;
            }
            fixed4 frag (v2f i) : SV_Target
            {
                float3 dir = normalize(i.texcoord);
                float2 longlat = float2(atan2(dir.x , dir.z), acos(-dir.y));
                float2 uv = longlat / float2(2.0 * UNITY_PI, UNITY_PI);
                uv.x += 0.5;
                half4 tex = tex2D (_MainTex, TRANSFORM_TEX(uv, _MainTex));
                return tex;
            }
            ENDCG
            }
    }
    Fallback Off
}  

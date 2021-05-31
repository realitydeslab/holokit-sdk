Shader "Instanced/InstancedShaderSizheng" {
    Properties{
        _Color ("Color", Color) = (1,1,1,1)
        _InteractColor ("Interact Color", Color) = (1,1,1,1)
        _EmissionColor ("Emission Color", Color) = (1,1,1,1)
        _EmissionIntensity ("Emission Intensity", Float) = 1
        _MainTex("Albedo (RGB)", 2D) = "white" {}
    }
        SubShader{

            Pass {

                // Tags {"LightMode" = "ForwardBase"}

                CGPROGRAM

                #pragma vertex vert
                #pragma fragment frag
                #pragma multi_compile_fwdbase nolightmap nodirlightmap nodynlightmap novertexlight
                #pragma target 4.5

                #include "UnityCG.cginc"
                #include "UnityLightingCommon.cginc"
                #include "AutoLight.cginc"

                sampler2D _MainTex;
                fixed4 _Color;
                fixed4 _InteractColor;
                fixed4 _EmissionColor;
                float _EmissionIntensity;
                float3 _ObsPosition;
                float _ObsScaler;

                struct Boid
                {
                    float3 position;
                    float3 direction;
                    float noise_offset;
                    float3 padding;
                };

            float4x4 _LookAtMatrix;
            float3 _BoidPosition;


            #if SHADER_TARGET >= 45
                StructuredBuffer<float4> positionBuffer;
                StructuredBuffer<Boid> boidBuffer;
            #endif

            float4x4 look_at_matrix(float3 at, float3 eye, float3 up) {
                float3 zaxis = normalize(at - eye);
                float3 xaxis = normalize(cross(up, zaxis));
                float3 yaxis = cross(zaxis, xaxis);
                return float4x4(
                    xaxis.x, yaxis.x, zaxis.x, 0,
                    xaxis.y, yaxis.y, zaxis.y, 0,
                    xaxis.z, yaxis.z, zaxis.z, 0,
                    0, 0, 0, 1
                );
            }

            struct v2f
            {
                float4 pos : SV_POSITION;
                float2 uv_MainTex : TEXCOORD0;
                float3 ambient : TEXCOORD1;
                float3 diffuse : TEXCOORD2;
                float3 color : TEXCOORD3;
                SHADOW_COORDS(4)
            };

            v2f vert(appdata_full v, uint instanceID : SV_InstanceID)
            {
            #if SHADER_TARGET >= 45
                    Boid data = boidBuffer[instanceID];
            #else
                    Boid data = {0,0,0,0};
            #endif

                    _BoidPosition = boidBuffer[instanceID].position;
                    _LookAtMatrix = look_at_matrix(_BoidPosition, _BoidPosition + (boidBuffer[instanceID].direction * -1), float3(0.0, 1.0, 0.0));
                    v.vertex = mul(_LookAtMatrix, v.vertex);
                    v.vertex.xyz += _BoidPosition;
                    float3 worldNormal = v.normal;
                    float3 ndotl = saturate(dot(worldNormal, _WorldSpaceLightPos0.xyz));
                    float3 ambient = ShadeSH9(float4(worldNormal, 1.0f));
                    float3 diffuse = (ndotl * _LightColor0.rgb);
                    float3 color = v.color;

                    fixed4 fixedColor = _Color;
                    if(distance(_ObsPosition,_BoidPosition)<_ObsScaler) fixedColor = _InteractColor*1.5;


                    v2f o;
                    o.pos = mul(UNITY_MATRIX_VP, float4(v.vertex.xyz, 1.0f));
                    o.uv_MainTex = v.texcoord;
                    o.ambient = ambient;
                    o.diffuse = diffuse;
                    o.color =color;
                    o.color *= fixedColor;
                    TRANSFER_SHADOW(o)
                    return o;
                }

                fixed4 frag(v2f i) : SV_Target
                {
                    fixed shadow = SHADOW_ATTENUATION(i);
                    fixed4 albedo = tex2D(_MainTex, i.uv_MainTex);
                    
                    float3 lighting = i.diffuse * shadow + i.ambient;
                    float emission = _EmissionIntensity;
                    fixed4 output = fixed4(albedo.rgb * i.color * (lighting + emission), albedo.w);
                    UNITY_APPLY_FOG(i.fogCoord, output);
                    return output;
                }

                ENDCG
            }
    }
}
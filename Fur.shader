Shader "Custom/Diffuse"
{
    Properties
    {
        _MainTex ("Fur Normal", 2D) = "normal" {}
        _AlbedoTex ("Fur Texture", 2D) = "white" {}
        _Gloss ("Gloss", float) = 1
        _Color ("Color", Color) = (1,1,1,1)
        _AmbientLight("Ambient Light", Color) = (0,0,0,0)
        _FurLength("Fur Length", Range(-0.05,0.1)) = 1
    }
    SubShader
    {
        Tags { 
        "RenderType"="Opaque"
        }
        LOD 200
    Pass
        {
            CGPROGRAM
            // Physically based Standard lighting model, and enable shadows on all light types
            #pragma vertex vert
            #pragma fragment frag
            
            
            #include "UnityLightingCommon.cginc" // for _LightColor0
            #include "UnityCG.cginc"
            #include "AutoLight.cginc"
            #pragma target 3.0

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal : NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float3 worldPos : TEXCOORD2;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _AlbedoTex;
            float4 _AlbedoTex_ST;
            float4 _Color;
            float4 _AmbientLight;
            float _Gloss;
            float _FurLength;

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = TRANSFORM_TEX(v.uv.xy, _AlbedoTex);
                float height = tex2Dlod(_MainTex, float4(o.uv, 0, 0)).r;                

                v.vertex.xyz += v.normal * (height * _FurLength);
                o.vertex = UnityObjectToClipPos(v.vertex);  
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }
            
            float4 frag (v2f i) : SV_Target
            {
                //Diffuse
                float3 LightSource = _WorldSpaceLightPos0.xyz; //Direction
                float diffuseLight = dot(i.normal, LightSource);
                float3 lambert = saturate(dot(normalize(i.normal), LightSource));

                diffuseLight += _AmbientLight;
                
                //Specular
                float3 viewVector = normalize(_WorldSpaceCameraPos - i.worldPos);
                // float3 reflectedVector = reflect(-LightSource, normalize(i.normal));
                float3 halfVector = normalize(LightSource + viewVector);
                float3 specularLight = saturate(dot(halfVector, normalize(i.normal)));

                specularLight = pow(specularLight, _Gloss);
                float3 alpha = tex2D(_AlbedoTex, i.uv).rgb;

                return float4(diffuseLight * alpha, 1) * _Color;

                // return float4(diffuseLight.xxx, 1);
            
            }

        ENDCG
        }
    }
    FallBack "Diffuse"
}

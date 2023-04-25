Shader "Custom/Rock"
{
    Properties
    {
        _AlbedoTex ("Cliff texture", 2D) = "white" {}
        _NormalTex ("Normal Cliff texture", 2D) = "normal" {}
        _BumpTex ("Bump Cliff texture", 2D) = "bump" {}
        _DisplacementTex ("Displacement Cliff texture", 2D) = "white" {}
        _Gloss ("Gloss", float) = 1
        _Color ("Color", Color) = (1,1,1,1)
        _AmbientColor ("Ambient Color", Color) = (1,1,1,1)
        _HeightIntensity("Hiehgt Intensity", Range(0,0.1)) = 1
        _FresnelPower ("Fresnel Power", float) = 1

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
                float4 tangent : TANGENT;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float3 worldPos : TEXCOORD2;
                float4 tangent : TANGENT;
                half3 tspace0 : TEXCOORD3;
                half3 tspace1 : TEXCOORD4;
                half3 tspace2 : TEXCOORD5;
                float3 viewDir: TEXCOORD6;
                fixed4 diffuse: COLOR0;
            };

            sampler2D _AlbedoTex;
            float4 _AlbedoTex_ST;
            sampler2D _NormalTex;
            float4 _NormalTex_ST;
            sampler2D _BumpTex;
            float4 _BumpTex_ST;
            sampler2D _DisplacementTex;
            float4 _DisplacementTex_ST;
            float4 _Color;
            float _Gloss;
            float4 _AmbientColor;
            float _HeightIntensity;
            float _FresnelPower;

            v2f vert (appdata v)
            {
                v2f o;
                //Displacement Functionality
                o.uv = TRANSFORM_TEX(v.uv.xy, _AlbedoTex);
                float height = tex2Dlod(_DisplacementTex, float4(o.uv, 0, 0)).r;
                v.vertex.xyz += v.normal * (height * _HeightIntensity);

                //Normal Map
                o.normal = UnityObjectToWorldNormal(v.normal);
                half3 wNormal = UnityObjectToWorldNormal(v.normal);
                half3 wTangent = UnityObjectToWorldNormal(v.tangent.xyz);
                //Bitangent calculation
                half3 tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;

                o.tspace0 = half3(wBitangent.x, wNormal.x, wTangent.x);
                o.tspace1 = half3(wBitangent.y, wNormal.y, wTangent.y);
                o.tspace2 = half3(wBitangent.z, wNormal.z, wTangent.z);

                //World Lighting
                half nl = max(0, dot(wNormal, _WorldSpaceLightPos0.xyz));
                o.diffuse = nl * _LightColor0;
                o.diffuse.rgb += ShadeSH9(half4(wNormal, 1));

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.viewDir = normalize(WorldSpaceViewDir(v.vertex));
                return o;
            }
            
            float4 frag (v2f i) : SV_Target
            {
                //Normal
                half3 wNormal = UnpackNormal(tex2D(_NormalTex, i.uv));
                half3 worldNormal;
                worldNormal.x = dot(i.tspace0, wNormal);
                worldNormal.y = dot(i.tspace1, wNormal);
                worldNormal.z = dot(i.tspace2, wNormal);
                fixed4 c = fixed4(worldNormal * 0.5 + 0.5, 1);

                //Assignment of Normals
                float NdotL = dot(_WorldSpaceLightPos0, c);
                float NdotH = dot(c, normalize(_WorldSpaceLightPos0));
                i.normal.xy += NdotH;
                i.normal.xy += NdotL;

                //Diffuse
                float3 LightSource = _WorldSpaceLightPos0.xyz; //Direction
                float diffuseLight = dot(i.normal, LightSource);
                float3 lambert = saturate(dot(normalize(i.normal), LightSource));

                //Ambient Light
                diffuseLight += _AmbientColor;

                float4 mainTexture = tex2D(_AlbedoTex, i.uv);
                float4 Fresnel = pow((1.0 - saturate(dot(normalize(i.normal), normalize(i.viewDir)))), _FresnelPower);

                return (diffuseLight * mainTexture * _Color) * Fresnel * _LightColor0;

                // return float4(diffuseLight.xxx, 1);
            
            }

        ENDCG
        }
    }
    FallBack "Diffuse"
}

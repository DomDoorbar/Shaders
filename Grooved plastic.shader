Shader "Custom/Grooved Plastic"
{
    Properties
    {
        _MainTex ("Plastic Normal", 2D) = "bump" {}
        _HeightTex("Plastic Height", 2D)= "gray" {}
        _Gloss ("Gloss", float) = 1
        _Color ("Color", Color) = (1,1,1,1)
        _HeightIntensity("Height Intensity", Range(0,0.2)) = 1
        _AmbientLight("Ambient Light", Color) = (0,0,0,0)
        _FresnellPower ("Fresnel", float) = 1
        _FresnelColor ("Color", Color) = (1,1,1,1)

    }
    SubShader
    {
        Tags { 
        "LightMode"="UniversalForward"
        "RenderPipeline"="UniversalPipeline"
        "RenderType"="Opaque"
        "UniversalMaterialType" = "Lit"
        "Queue"="Geometry"
        "ShaderGraphShader"="true"
        "ShaderGraphTargetId"="UniversalLitSubTarget"
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
                float4 tangent: TANGENT;
                half3 tspace0 : TEXCOORD3;
                half3 tspace1 : TEXCOORD4;
                half3 tspace2 : TEXCOORD5;
                float3 viewDir: TEXCOORD6;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal : NORMAL;
                float3 worldPos : TEXCOORD2;
                float4 tangent: TANGENT;
                half3 tspace0 : TEXCOORD3;
                half3 tspace1 : TEXCOORD4;
                half3 tspace2 : TEXCOORD5;
                float3 viewDir: TEXCOORD6;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;
            sampler2D _HeightTex;
            float4 _HeightTex_ST;
            float4 _Color;
            float4 _AmbientLight;
            float4 _FresnelColor;
            float _Gloss;
            float _HeightIntensity;
            float _FresnellPower;

            v2f vert (appdata v)
            {
                v2f o;

                //Displacement Height Function
                o.uv = TRANSFORM_TEX(v.uv, _HeightTex);
                float height = tex2Dlod(_HeightTex, float4(o.uv, 0, 0)).x;

                v.vertex.xyz += v.normal * (height * _HeightIntensity);
                
                o.vertex = UnityObjectToClipPos(v.vertex);  
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.viewDir = normalize(WorldSpaceViewDir(v.vertex));

                //My Custom Normal Map Shader
                o.normal = UnityObjectToWorldNormal(v.normal);
                half3 wNormal = UnityObjectToWorldNormal(v.normal);
                half3 wTangent = UnityObjectToWorldNormal(v.tangent.xyz);
                //Compute bitangent from cross-product of normal and tangent
                half3 tangentSign = v.tangent.w * unity_WorldTransformParams.w;
                half3 wBitangent = cross(wNormal, wTangent) * tangentSign;
                //Output Tangent Space
                o.tspace0 = half3(wTangent.x, wBitangent.x, wNormal.x);
                o.tspace1 = half3(wTangent.y, wBitangent.y, wNormal.y);
                o.tspace2 = half3(wTangent.z, wBitangent.z, wNormal.z);

                return o;
            }
            
            float4 frag (v2f i) : SV_Target
            {

                half3 tNormal = UnpackNormal(tex2D(_MainTex, i.uv));
                half3 worldNormal;
                worldNormal.x = dot(i.tspace0, tNormal);
                worldNormal.y = dot(i.tspace1, tNormal);
                worldNormal.z = dot(i.tspace2, tNormal);
                fixed4 c = fixed4(worldNormal * 0.5 + 0.5, 1);

                float NdotL = dot(_WorldSpaceLightPos0, c);
                float NdotH = dot(c, normalize(_WorldSpaceLightPos0));
                i.normal.xy += NdotH;
                i.normal.xy += NdotL;

                //Diffuse
                float3 LightSource = _WorldSpaceLightPos0.xyz; //Direction
                float diffuseLight = dot(i.normal, LightSource);
                float3 lambert = saturate(dot(normalize(i.normal), LightSource));

                diffuseLight += _AmbientLight;
                
                //Specular
                float3 viewVector = normalize(_WorldSpaceCameraPos - i.worldPos);
                float3 halfVector = normalize(LightSource + viewVector);
                float3 specularLight = saturate(dot(halfVector, normalize(i.normal)));

                specularLight = pow(specularLight, _Gloss);

                diffuseLight += pow((1.0 - saturate(dot(normalize(i.normal), normalize(i.viewDir)))), _FresnellPower) *_FresnelColor;

                return float4((diffuseLight + specularLight) * _Color, 1) * _LightColor0;
            
            }

        ENDCG
        }
    }
    FallBack "Diffuse"
}

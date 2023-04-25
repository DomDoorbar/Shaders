// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/My Sand"
{
    Properties
    {
        _MainTex ("Main texture", 2D) = "normal" {}
        _MainColor ("Main Color", Color) = (1,1,1,1)
       [HDR] _SandGrainColor ("Sand Grain Colour", Color) = (1,1,1,1)
        _FresnelPowerColor ("Fresnel Power Colour", Color) = (1,1,1,1)
        _GrainDispersion ("Grain Dispersion", float) = 0.5
        _GrainSize ("Grain Size", float) = 0.5
        _FresnelPowerReduction ("Fresnel Power Reduction", float) = 0.5
        _HeightMapTexelSize("Height Map Texel Size", float) = 0.5
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
            #pragma target 3.0

            sampler2D _MainTex;
            float4 _MainTex_ST;


            struct Input
            {
                float2 uv_MainTex;
            };

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal: NORMAL;
                float3 viewDir: TEXCOORD1;
                float4 worldPos: TEXCOORD2;
                float4 tangent: TANGENT;
                fixed4 diffuse: COLOR0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float3 normal: NORMAL;
                float3 viewDir: TEXCOORD1;
                float3 worldPos: TEXCOORD2;
                fixed4 diffuse: COLOR0;
                float4 tangent: TANGENT;
                half3 tspace0 : TEXCOORD3;
                half3 tspace1 : TEXCOORD4;
                half3 tspace2 : TEXCOORD5;
            };

            
            fixed4 _MainColor;
            fixed4 _SandGrainColor;
            fixed4 _FresnelPowerColor;
            float _GrainDispersion;
            float _GrainSize;
            float _FresnelPowerReduction;
            float4 _HeightMapTexelSize;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                // o.viewDir = normalize(_WorldSpaceCameraPos - v.worldPos);
                o.viewDir = normalize(WorldSpaceViewDir(v.vertex));
                
                //Normal Work
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

                o.uv = TRANSFORM_TEX(v.uv, _MainTex);

                // factor in the light color
                half nl = max(0, dot(wNormal, _WorldSpaceLightPos0.xyz));
                o.diffuse = nl * _LightColor0;
                o.diffuse.rgb += ShadeSH9(half4(wNormal, 1));

                return o;
            }

            float2 unity_gradientNoise_dir(float2 p)
            {
                p = p % 289;
                float x = (34 * p.x + 1) * p.x % 289 + p.y;
                x = (34 * x + 1) * x % 289;
                x = frac(x / 41) * 2 - 1;
                return normalize(float2(x - floor(x + 0.5), abs(x) - 0.5));
            }

            float unity_gradientNoise(float2 p)
            {
                float2 ip = floor(p);
                float2 fp = frac(p);
                float d00 = dot(unity_gradientNoise_dir(ip), fp);
                float d01 = dot(unity_gradientNoise_dir(ip + float2(0, 1)), fp - float2(0, 1));
                float d10 = dot(unity_gradientNoise_dir(ip + float2(1, 0)), fp - float2(1, 0));
                float d11 = dot(unity_gradientNoise_dir(ip + float2(1, 1)), fp - float2(1, 1));
                fp = fp * fp * fp * (fp * (fp * 6 - 15) + 10);
                return lerp(lerp(d00, d01, fp.y), lerp(d10, d11, fp.y), fp.x);
            }

            void Unity_GradientNoise_float(float2 UV, float Scale, out float Out)
            {
                Out = unity_gradientNoise(UV * Scale) + 0.5;
            }

            void FresnelEffect(float3 Normal, float3 ViewDir, float Power, out float Out)
            {
                Out = pow((1.0 - saturate(dot(normalize(Normal), normalize(ViewDir)))), Power);
            }

            fixed4 frag (v2f i) : SV_Target
            {

                //Noise Generation
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
                

                //Gradient Noise
                float GradientNoise;
                Unity_GradientNoise_float(i.uv, _GrainSize, GradientNoise);
                float NormalizedGradientNoise = -1 * (normalize(lerp(-1, _GrainDispersion, GradientNoise)));

                //View Direction
                float NormalizedViewDir = -1 * (i.viewDir);

                //Dot product both Noise and View Direction
                float SandGrain = saturate(dot(NormalizedGradientNoise, 1)) * _SandGrainColor;

                //Begin Fresnel Effect
                float SandFresnelEffect;
                FresnelEffect(i.normal, i.viewDir, _FresnelPowerReduction, SandFresnelEffect);

                float4 CombinedSand = (( SandFresnelEffect * _FresnelPowerColor) + SandGrain) + _MainColor;
                
                CombinedSand *= i.diffuse;

                return CombinedSand;
                // return (SandFresnelEffect * _FresnelPowerColor) + SandGrain;
            
            }

        ENDCG
        }
    }
    FallBack "Diffuse"
}

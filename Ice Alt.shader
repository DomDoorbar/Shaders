Shader "Custom/Ice Alt"
{
    Properties
    {
        _Roughness("Roughness", float) = 0.1
        _IceColour1("Ice Colour 1", Color) = (1,1,1,1)
        _IceColour2("Ice Colour 2", Color) = (1,1,1,1)
        _FresnelPower("Fresnel Power", float) = 0.1
        _NoiseScale("Noise Scale", float) = 0.1
        _VoronoiStrength("Voronoi Strength", float) = 0.1
    }
    SubShader
    {
        Tags { "LightMode"="UniversalForward"
        "RenderPipeline"="UniversalPipeline"
        "RenderType"="Opaque"
        "UniversalMaterialType" = "Lit"
        "Queue"="Geometry"
        "ShaderGraphShader"="true"
        "ShaderGraphTargetId"="UniversalLitSubTarget"  }
        LOD 100
        

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #include "UnityLightingCommon.cginc" // for _LightColor0

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float4 worldPos: TEXCOORD1;
                float3 viewDir: TEXCOORD2;
                float3 objScale : TEXCOORD3;
                float4 objPos: TEXCOORD4;
                float3 normal: NORMAL;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                float4 vertex : SV_POSITION;
                float4 worldPos: TEXCOORD1;
                float3 viewDir: TEXCOORD2;
                float3 objScale : TEXCOORD3;
                float4 objPos: TEXCOORD4;
                float3 normal: NORMAL;
            };

            float _Roughness;
            float _FresnelPower;
            fixed4 _IceColour1;
            fixed4 _IceColour2;
            float _NoiseScale;
            float _VoronoiStrength;

            v2f vert (appdata v)
            {
                v2f o;
                o.uv = v.uv;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.viewDir = WorldSpaceViewDir(v.vertex);
                o.objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));
                o.objScale = float3(length(float3(UNITY_MATRIX_M[0].x, UNITY_MATRIX_M[1].x, UNITY_MATRIX_M[2].x)),
                             length(float3(UNITY_MATRIX_M[0].y, UNITY_MATRIX_M[1].y, UNITY_MATRIX_M[2].y)),
                             length(float3(UNITY_MATRIX_M[0].z, UNITY_MATRIX_M[1].z, UNITY_MATRIX_M[2].z)));
                return o;
            }

            float3 HeightToNormal(float height, float3 normal, float3 pos)
            {   
                float3 worldDirivativeX = ddx(pos);
                float3 worldDirivativeY = ddy(pos);
                float3 crossX = cross(normal, worldDirivativeX);
                float3 crossY = cross(normal, worldDirivativeY);
                float3 d = abs(dot(crossY, worldDirivativeX));
                float3 inToNormal = ((((height + ddx(height)) - height) * crossY) + (((height + ddy(height)) - height) * crossX)) * sign(d);
                inToNormal.y *= -1.0;
                return normalize((d * normal) - inToNormal);
            }

            inline float unity_noise_randomValue (float2 uv)
            {
                return frac(sin(dot(uv, float2(12.9898, 78.233)))*43758.5453);
            }

            inline float unity_noise_interpolate (float a, float b, float t)
            {
                return (1.0-t)*a + (t*b);
            }

            inline float unity_valueNoise (float2 uv)
            {
                float2 i = floor(uv);
                float2 f = frac(uv);
                f = f * f * (3.0 - 2.0 * f);

                uv = abs(frac(uv) - 0.5);
                float2 c0 = i + float2(0.0, 0.0);
                float2 c1 = i + float2(1.0, 0.0);
                float2 c2 = i + float2(0.0, 1.0);
                float2 c3 = i + float2(1.0, 1.0);
                float r0 = unity_noise_randomValue(c0);
                float r1 = unity_noise_randomValue(c1);
                float r2 = unity_noise_randomValue(c2);
                float r3 = unity_noise_randomValue(c3);

                float bottomOfGrid = unity_noise_interpolate(r0, r1, f.x);
                float topOfGrid = unity_noise_interpolate(r2, r3, f.x);
                float t = unity_noise_interpolate(bottomOfGrid, topOfGrid, f.y);
                return t;
            }

            void Unity_SimpleNoise_float(float2 UV, float Scale, out float Out)
            {
                float t = 0.0;

                float freq = pow(2.0, float(0));
                float amp = pow(0.5, float(3-0));
                t += unity_valueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;

                freq = pow(2.0, float(1));
                amp = pow(0.5, float(3-1));
                t += unity_valueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;

                freq = pow(2.0, float(2));
                amp = pow(0.5, float(3-2));
                t += unity_valueNoise(float2(UV.x*Scale/freq, UV.y*Scale/freq))*amp;

                Out = t;
            }

            inline float2 unity_voronoi_noise_randomVector (float2 UV, float offset)
            {
                float2x2 m = float2x2(15.27, 47.63, 99.41, 89.98);
                UV = frac(sin(mul(UV, m)) * 46839.32);
                return float2(sin(UV.y*+offset)*0.5+0.5, cos(UV.x*offset)*0.5+0.5);
            }

            void Unity_Voronoi_float(float2 UV, float AngleOffset, float CellDensity, out float Out)
            {
                float2 g = floor(UV * CellDensity);
                float2 f = frac(UV * CellDensity);
                float t = 8.0;
                float3 res = float3(8.0, 0.0, 0.0);

                for(int y=-1; y<=1; y++)
                {
                    for(int x=-1; x<=1; x++)
                    {
                        float2 lattice = float2(x,y);
                        float2 offset = unity_voronoi_noise_randomVector(lattice + g, AngleOffset);
                        float d = distance(lattice + offset, f);
                        if(d < res.x)
                        {
                            res = float3(d, offset.x, offset.y);
                            Out = res.x;
                        }
                    }
                }
            }

            void Unity_Posterize_float4(float4 In, float4 Steps, out float4 Out)
            {
                Out = floor(In / (1 / Steps)) * (1 / Steps);
            }


            fixed4 frag (v2f i) : SV_Target
            {
                //Position Object Split
                float3 objPositionSplit = i.objPos * i.objScale;
                float2 NoiseVector = float2(objPositionSplit[0], objPositionSplit[1]);

                //Fresnel
                float SampleNoise;
                Unity_SimpleNoise_float(i.uv, _NoiseScale, SampleNoise);

                float3 normalFromHeight = HeightToNormal((SampleNoise * _Roughness), i.normal, i.worldPos);

                float fresnellEffectNormalHeight = pow((1.0 - saturate(dot(normalize(normalFromHeight), normalize(i.viewDir)))), _FresnelPower);

                //Voronoi
                float Voronoi;
                Unity_Voronoi_float(i.uv, 5, 3, Voronoi);
                float4 VoronoiTexture = pow(Voronoi, _VoronoiStrength) * 0.5;

                //World Position for Ice Gradient

                //Ice Gradient
                float3 splitWorldPosition = (i.worldPos - i.objPos) / i.objScale;

                float saturatedWorldPos = saturate(splitWorldPosition[1] + 0.5);

                float4 IceGradient = lerp(_IceColour2, _IceColour1, saturatedWorldPos);

                //Combination of everything
                float4 combinedFresnellAndColour;
                Unity_Posterize_float4((saturatedWorldPos * fresnellEffectNormalHeight), 6, combinedFresnellAndColour);

                //Combine All

                return (combinedFresnellAndColour + VoronoiTexture) + IceGradient;
                // return fresnellEffectNormalHeight;
            }
            ENDCG
        }
    }
}

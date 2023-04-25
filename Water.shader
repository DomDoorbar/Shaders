Shader "Unlit/Water"
{
    Properties
    {
        _Size("Size", float) = 2
        _FlowStrength("Flow Strength", float) = 1.0
        _FlowSpeed("Flow Speed", float) = 1.0
        _FlowTexture("Flow Texture", 2D) = "white" {}
        _FoamTexture("Foam Texture", 2D) = "white" {}
        _WaterColour("Water Colour", Color) = (1,1,1,1)
        _LightFoamColour("Light Foam Colour", Color) = (1,1,1,1)
        _DarkFoamColour("Dark Foam Colour", Color) = (1,1,1,1)
        _FoamDistance("Foam Distance", float) = 2
        _Choppiness("Choppiness", float) = 1.0
        _Opacity("Opacity", float) = 1.0
    }
    SubShader
    {
        Tags { "Queue"="Transparent" }
        LOD 100
        Blend SrcAlpha OneMinusSrcAlpha

    Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            #define SHADERGRAPH_SAMPLE_SCENE_DEPTH(uv)
            #define TEXTURE2D(textureName) Texture2D textureName
            #define SAMPLER2D(samplerName) SamplerState samplerName 

            #include "UnityCG.cginc"
            #define REQUIRE_DEPTH_TEXTURE
            #pragma target 3.0

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal: NORMAL;
                float4 screenPos: TEXCOORD1;
                float3 worldPos: TEXCOORD2;
                float3 objPos: TEXCOORD3;
            };

            struct v2f
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal: NORMAL;
                float4 screenPos: TEXCOORD1;
                float3 worldPos: TEXCOORD2;
                float3 objPos: TEXCOORD3;
            };

            Texture2D _FlowTexture;
            SamplerState sampler_FlowTexture;
            float4 _FlowTexture_ST;
            sampler2D _FoamTexture;
            float4 _FoamTexture_ST;
            float _Size;
            float _FlowStrength;
            float _FlowSpeed;
            half4 _WaterColour;
            half4 _LightFoamColour;
            half4 _DarkFoamColour;
            float _FoamDistance;
            float _Choppiness;
            float _Opacity;

            void Unity_NormalFromTexture_float(Texture2D Texture, SamplerState Sampler, float2 UV, float Offset, float Strength, out float3 Out)
            {
                Offset = pow(Offset, 3) * 0.1;
                float2 offsetU = float2(UV.x + Offset, UV.y);
                float2 offsetV = float2(UV.x, UV.y + Offset);
                float normalSample = Texture.Sample(Sampler, UV);
                float uSample = Texture.Sample(Sampler, offsetU);
                float vSample = Texture.Sample(Sampler, offsetV);
                float3 va = float3(1, 0, (uSample - normalSample) * Strength);
                float3 vb = float3(0, 1, (vSample - normalSample) * Strength);
                Out = normalize(cross(va, vb));
            }


            v2f vert (appdata v)
            {
                v2f o;
                //Useful to make waves
                v.vertex.y += (cos(v.uv.x  + _Time.y) * 0.05f);
                
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _FlowTexture);
                o.normal = UnityObjectToWorldNormal(v.normal);
                o.screenPos = ComputeScreenPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex).xyz;
                o.objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));

                //vertex bobbing
                float3 worldPosSine = sin((o.worldPos[0] + o.worldPos[2]) + _Time) * _Choppiness;
                float3 objectPosition = float3(0, worldPosSine.y, 0);

                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                //Modulate the UV overtime
                float ModulatedUV = i.uv + ((_FlowSpeed / _Size) * _Time);

                float3 NormalMappedtexture;
                Unity_NormalFromTexture_float(_FlowTexture, sampler_FlowTexture, ModulatedUV, 0.5, 8, NormalMappedtexture);

                //multiply Normal Texture by Flow Strength
                float3 NormalTexMultiplied = NormalMappedtexture * _FlowStrength;

                //Main Foam Voronoi Sample

                float4 VoronoiTex = tex2D(_FoamTexture, (i.uv.xy + NormalTexMultiplied) * _Size);

                //Dark Foam Voronoi Sample
                float4 DarkFoamVoronoiTex = lerp(_WaterColour, _DarkFoamColour, tex2D(_FoamTexture, (i.uv.xy + NormalTexMultiplied) + (0.1,0.1,0)));

                //Water Depth Colour
                float4 WaterDepthColour = step(0.5, saturate((SHADERGRAPH_SAMPLE_SCENE_DEPTH(NormalTexMultiplied + i.screenPos) - i.screenPos[3]) / _FoamDistance));

                //Combining texture and intersection foam
                float4 combinedTextureIntersectionFoam = lerp(DarkFoamVoronoiTex, _LightFoamColour, VoronoiTex);


                return combinedTextureIntersectionFoam;
            }
            ENDCG
        }
    }
    FallBack "Diffuse"
}

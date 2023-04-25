// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

// Upgrade NOTE: replaced '_Object2World' with 'unity_ObjectToWorld'

Shader "Custom/Glass"
{
    Properties
    {
        _FillAmount ("Fill Amount", Range(0,1)) = 0.5
        _WobbleX ("Wobble X", Range(-1,1)) = 0.5
        _WobbleZ ("Wobble Z", Range(-1,1)) = 0.5
        _Offset ("Offset", Range(0,1)) = 0.5
        _TopColor ("Top Color", Color) = (1,1,1,1)
        _BottomColor ("Bottom Color", Color) = (1,1,1,1)
        _FoamColor ("Foam Color", Color) = (1,1,1,1)
        _GradientPower("Gradient Power", Range(0,5)) = 1.0

    }
    SubShader
    {
        Tags {
            "Queue"="Geometry" "RenderType"="Opaque" "DisableBatching" = "True" 
        }
        
        ZWrite On
        Blend SrcAlpha OneMinusSrcAlpha
        AlphaToMask On
        // ColorMask RGB
        Cull Off
    Pass
        {
            ColorMaterial AmbientAndDiffuse
            CGPROGRAM
            // Physically based Standard lighting model, and enable shadows on all light types
            #pragma vertex vert
            #pragma fragment frag
            #define SHADERGRAPH_OBJECT_POSITION
            #define ALPHA_CLIP_THRESHOLD 0.11
            
            #include "UnityLightingCommon.cginc" // for _LightColor0
            #include "UnityCG.cginc"
            #pragma target 3.0


            struct appdata
            {
                float4 vertex : POSITION;
                float3 viewDir: TEXCOORD1;
                float4 worldPos: TEXCOORD2;
                float4 objPos: TEXCOORD3;
            };

            struct v2f
            {
                float4 vertex : POSITION;
                float3 viewDir: TEXCOORD1;
                float3 worldPos: TEXCOORD2;
                float3 objPos: TEXCOORD3;
                half4 color: COLOR;
            };

            fixed4 _TopColor;
            fixed4 _BottomColor;
            fixed4 _FoamColor;
            float _WobbleX;
            float _WobbleZ;
            float _Offset;
            float _FillAmount;
            float _GradientPower;



            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                o.viewDir = mul(o.worldPos, unity_WorldToObject);
                o.objPos = mul(unity_ObjectToWorld, float4(0,0,0,1));

                return o;
            }

            void Unity_RotateAboutAxis_Degrees_float(float3 In, float3 Axis, float Rotation, out float3 Out)
            {
                Rotation = radians(Rotation);
                float s = sin(Rotation);
                float c = cos(Rotation);
                float one_minus_c = 1.0 - c;

                Axis = normalize(Axis);
                float3x3 rot_mat = 
                {   one_minus_c * Axis.x * Axis.x + c, one_minus_c * Axis.x * Axis.y - Axis.z * s, one_minus_c * Axis.z * Axis.x + Axis.y * s,
                    one_minus_c * Axis.x * Axis.y + Axis.z * s, one_minus_c * Axis.y * Axis.y + c, one_minus_c * Axis.y * Axis.z - Axis.x * s,
                    one_minus_c * Axis.z * Axis.x - Axis.y * s, one_minus_c * Axis.y * Axis.z + Axis.x * s, one_minus_c * Axis.z * Axis.z + c
                };
                Out = mul(rot_mat,  In);
            }

            void Unity_Branch_float4(float Predicate, float4 True, float4 False, out float4 Out)
            {
                Out = lerp(False, True, Predicate);
            }

            fixed4 frag (v2f i, fixed facing : VFACE) : SV_Target
            {
                //Add in the Object Position and add this based on the rotation around the axis to cover all sides of the position
                float3 objPosRotationAroundAxis;
                Unity_RotateAboutAxis_Degrees_float(i.vertex, (1,0,0), 90, objPosRotationAroundAxis);
                float3 objPosRotationAroundAxis1;
                Unity_RotateAboutAxis_Degrees_float(i.vertex, (0,0,1), 90, objPosRotationAroundAxis1);
                float3 objectPosition = (objPosRotationAroundAxis * _WobbleX) + (objPosRotationAroundAxis1 * _WobbleZ);

                //Get the World Position and minus this by the Object Position
                float3 subtractedWorldPos = i.worldPos - i.objPos;

                //Add both Positions together
                float3 combinedPosition = subtractedWorldPos + objectPosition;

                //Split each channel to get the G value of the new position
                float _Split_G = subtractedWorldPos[1];

                //Fill Amount
                float alphaVolume = step(_FillAmount + _Split_G, 0.58);
                //Sort Out the Colour, Foam and Offset
                float4 gradientColourAndCutoff = lerp(_BottomColor, _TopColor, saturate(_Split_G + _Offset));

                float4 branchedGradient;
                Unity_Branch_float4(facing, gradientColourAndCutoff, _FoamColor, branchedGradient);
                
                // //Multiply both together
                float4 mainResult = branchedGradient * alphaVolume;

                return mainResult;
            }

        ENDCG
        }
    }
    FallBack "Diffuse"
}

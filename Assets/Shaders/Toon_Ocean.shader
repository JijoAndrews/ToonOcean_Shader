Shader "Unlit/Toon_Ocean"
{
    Properties
    {
        _DepthGradientShallow("Depth Gradient Shallow", Color) = (0.325, 0.807, 0.971, 0.725)
        _DepthGradientDeep("Depth Gradient Deep", Color) = (0.086, 0.407, 1, 0.749)
        _DepthMaxDistance("Depth Maximum Distance", Float) = 1
      
        _SurfaceNoise("Surface Noise", 2D) = "white" {}
        _SurfaceNoiseCutoff("Surface Noise Cutoff", Range(0, 1)) = 0.777

        _SurfaceDistortion("Surface Distortion", 2D) = "white" {}
        _SurfaceDistortionAmount("Surface Distortion Amount", Range(0, 1)) = 0.27

         _FoamMaxDistance("Foam Maximum Distance", Float) = 0.4
        _FoamMinDistance("Foam Minimum Distance", Float) = 0.04

        _SurfaceNoiseScroll("Surface Noise Scroll Amount", Vector) = (0.03, 0.03, 0, 0)

        _NoiseTex("Wave Noise", 2D) = "white" {}
       [HideInInspector]_RippleNoiseTex("Ripple Noise", 2D) = "white" {}
       [HideInInspector]_RippleScale("Ripple Scale",Range(0,1)) = 0.5
        _Speed("Wave Speed", Range(0,1)) = 0.5
        _Amount("Wave Amount", Range(0,1)) = 0.5
        _Height("Wave Height", Range(0,1)) = 0.5
        
    }
    SubShader
    {
      Tags
        {
            "Queue" = "Transparent"
        }

        Pass
        {
            Blend SrcAlpha OneMinusSrcAlpha
            ZWrite Off

            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag


            #include "UnityCG.cginc"
            #define SMOOTHSTEP_AA 0.01
            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
                float3 normal: NORMAL;
            };

            struct v2f
            {
                float2 noiseUV : TEXCOORD0;
                float2 distortUV :TEXCOORD1;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
                float4 screenPosition : TEXCOORD2;
                float3 viewNormal: NORMAL;

                float3 worldPos : TEXCOORD3;

            };

            sampler2D _MainTex, _CameraDepthTexture, _SurfaceDistortion, _NoiseTex, _RippleNoiseTex;
            float4 _MainTex_ST, _SurfaceDistortion_ST;
            sampler2D _SurfaceNoise;
            sampler2D _CameraNormalsTexture;//global variable delcared in hidden normal script

            float4 _SurfaceNoise_ST;
            float4 _DepthGradientShallow;
            float4 _DepthGradientDeep;
            float _DepthMaxDistance;
            float _SurfaceNoiseCutoff;
            float _FoamMaxDistance;
            float _FoamMinDistance;

            float _SurfaceDistortionAmount;
            float2 _SurfaceNoiseScroll;

            float _Speed, _Amount, _Height ,_RippleScale;


            uniform float3 _Position;
            uniform sampler2D _GlobalEffectRT;
            uniform float _OrthographicCamSize;


            v2f vert (appdata v)
            {
                v2f o;

                float4 tex = tex2Dlod(_NoiseTex, float4(v.uv.xy, 0, 0));
                v.vertex.y += sin(_Time.z * _Speed +( v.vertex.x * v.vertex.z * _Amount * tex) ) * _Height;

                o.vertex = UnityObjectToClipPos(v.vertex);
                o.screenPosition = ComputeScreenPos(o.vertex);
                o.noiseUV = TRANSFORM_TEX(v.uv, _SurfaceNoise);
                o.distortUV = TRANSFORM_TEX(v.uv, _SurfaceDistortion);
                o.viewNormal = COMPUTE_VIEW_NORMAL;

                o.worldPos = mul(unity_ObjectToWorld, v.vertex);
                return o;
            }

            fixed4 frag (v2f i) : SV_Target
            {
              float existingDepth01 = tex2Dproj(_CameraDepthTexture, UNITY_PROJ_COORD(i.screenPosition)).r;
              float existingDepthLinear = LinearEyeDepth(existingDepth01);    
              float depthDifference = existingDepthLinear - i.screenPosition.w;

            //water color
              float waterDepthDifference01 = saturate(depthDifference / _DepthMaxDistance);
              float4 waterColor = lerp(_DepthGradientShallow, _DepthGradientDeep, waterDepthDifference01);

            //surface foam generation
              float2 distortSample = (tex2D(_SurfaceDistortion, i.distortUV).xy * 2 - 1) * _SurfaceDistortionAmount;
              float2 noiseUV = float2((i.noiseUV.x + _Time.y * _SurfaceNoiseScroll.x) + distortSample.x, (i.noiseUV.y + _Time.y * _SurfaceNoiseScroll.y) + distortSample.y);
              float surfaceNoiseSample = tex2D(_SurfaceNoise, noiseUV).r;


              float3 existingNormal = tex2Dproj(_CameraNormalsTexture, UNITY_PROJ_COORD(i.screenPosition));
              float3 normalDot = saturate(dot(existingNormal, i.viewNormal));


              float foamDistance = lerp(_FoamMaxDistance, _FoamMinDistance, normalDot);
              float foamDepthDifference01 = saturate(depthDifference / foamDistance);
              float surfaceNoiseCutoff = foamDepthDifference01 * _SurfaceNoiseCutoff;
              float surfaceNoise = surfaceNoiseSample > surfaceNoiseCutoff ? 1 : 0;//cuttof make jitter on noise texture
             // float surfaceNoise = smoothstep(surfaceNoiseCutoff - SMOOTHSTEP_AA, surfaceNoiseCutoff + SMOOTHSTEP_AA, surfaceNoiseSample); //smoothstep removes the jitter noise



              //ripples
              float2 uv = i.worldPos.xz - _Position.xz;
              uv = uv / (_OrthographicCamSize * 2);
              uv += 0.5;
              float ripples = tex2D(_GlobalEffectRT, uv).b;
              ripples = step(0.99, ripples * 3);
              fixed distortx = tex2D(_NoiseTex, (i.worldPos.xz * _RippleScale) + (_Time.x * 2)).r;// distortion 
              distortx += (ripples * 2);

                return  waterColor + surfaceNoise;
            }
            ENDCG
        }
    }
}

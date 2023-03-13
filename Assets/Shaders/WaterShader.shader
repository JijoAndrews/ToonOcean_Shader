Shader "Unlit/WaterShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color("Main Color", Color) = (0,0,1,0.7)
        _ColorT("Tint", Color) = (0,1,1,0.6)
        _Mask("Mask", 2D) = "" {}
        _Noise("Noise", 2D) = "black" {}
        _Tile("Tile", 2D) = "" {}
        _FalloffTex("FallOff", 2D) = "white" {}
        _Scale("Scale", Range(0,1)) = 0.1
        _Speed("Speed", Range(0,10)) = 1
        _Intensity("Intensity", Range(0,10)) = 5
        _NoiseScale("Noise Scale", Range(0,1)) = 0.1
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendOp("Blend Op", Int) = 5
        [Enum(UnityEngine.Rendering.BlendMode)] _BlendMode("Blend Mode", Int) = 10
    }
    SubShader
    {
        Tags { "Queue"="Transparent" }
        Zwrite Off
        Cull Off
        ColorMask RGB
        Blend [_BlendOp][_BlendMode]
        Offset -1,1

        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

           /* struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;

            };*/

            struct v2f
            {
                float4 uvMask : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 pos : SV_POSITION;
                float4 uvFalloff:TEXCOORD1;
                float3 WorldPos : TEXCOORD2;
                float3 WorldNormal:TEXCOORD3;



            };

            float4x4 unity_Projector;
            float4x4 unity_ProjectorClip;

            sampler2D _MainTex,_Tile,_Mask,_FallOffTex,_Noise;
            float4 _MainTex_ST,_Color,_ColorT;
            float _Scale,_Intensity,_Speed,_NoiseScale;


            v2f vert (appdata_full v)
            {
                v2f o;
               // o.vertex = UnityObjectToClipPos(v.vertex);
               // o.uv = TRANSFORM_TEX(v.uv, _MainTex);
               // UNITY_TRANSFER_FOG(o,o.vertex);
                o.uvFalloff = mul(unity_ProjectorClip, v.vertex);
                o.pos = UnityObjectToClipPos(v.vertex);
                o.uvMask = mul(unity_Projector, v.vertex);
                o.WorldPos = mul(unity_ObjectToWorld, v.vertex);

                o.WorldNormal = normalize(mul(float4(v.normal, 0.0), unity_ObjectToWorld).xyz);
                return o;
            }


            fixed4 triplanar(float3 blendNormal, float4 texturex, float4 texturey, float4 texturez) 
            {
                float4 triplanartexture = texturez;
                triplanartexture = lerp(triplanartexture, texturex, blendNormal.x);
                triplanartexture = lerp(triplanartexture, texturey, blendNormal.y);
                return triplanartexture;
            }




            fixed4 frag (v2f i) : SV_Target
            {
                // sample the texture
                fixed4 col = tex2D(_MainTex, i.pos);
                // apply fog
               // UNITY_APPLY_FOG(i.fogCoord, col);


                float speed = _Time.x * _Speed;
                float blendNormal = saturate(pow(i.WorldNormal * 1.4,4));

                //distortion
                float4 distortx = tex2D(_Noise, float2(i.WorldPos.zy * _NoiseScale) - (speed));
                float4 distorty = tex2D(_Noise, float2(i.WorldPos.xz * _NoiseScale) - (speed));
                float4 distortz = tex2D(_Noise, float2(i.WorldPos.xy * _NoiseScale) - (speed));
                float distort = triplanar(blendNormal, distortx, distorty, distortz);

                //Moving Caustics
                float4 xc = tex2D(_Tile, float2((i.WorldPos.z + distort) * _Scale, (i.WorldPos.y) * (_Scale / 4)));
                float4 zc = tex2D(_Tile, float2((i.WorldPos.x + distort) * _Scale, (i.WorldPos.y) * (_Scale / 4)));
                float4 yc = tex2D(_Tile, (float2(i.WorldPos.x + distort, i.WorldPos.z + distort)) * _Scale);
                float4 causticsTex = triplanar(blendNormal, xc, yc, zc);
                

                //Secondary moving caustics ,smaller scale and moving opposite direction
                float secScale = _Scale * 0.6;
                float4 xc2 = tex2D(_Tile, float2 ((i.WorldPos.z - distort) * secScale, (i.WorldPos.y) * (secScale / 4)));
                float4 zc2 = tex2D(_Tile, float2 ((i.WorldPos.x - distort) * secScale, (i.WorldPos.y) * (secScale / 4)));
                float4 yc2 = tex2D(_Tile, float2(i.WorldPos.x - distort, i.WorldPos.z - distort) * secScale);

                float4 causticsTex2 = triplanar(blendNormal, xc2, yc2, zc2);


                //combining
                causticsTex *= causticsTex2;
                causticsTex *= _Intensity * _ColorT;

                //Alhpa
                float falloff = tex2Dproj(_FallOffTex, UNITY_PROJ_COORD(i.uvFalloff)).a;
                float alphaMask = tex2Dproj(_Mask, UNITY_PROJ_COORD(i.uvMask)).a;
                float alpha = falloff * alphaMask;

                //Texture and Color times alpha
                _Color *= alpha * _Color.a;
                causticsTex *= alpha;



                return causticsTex + _Color;
            }
            ENDCG
        }
    }
}

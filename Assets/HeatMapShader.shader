Shader "Unlit/HeatMapShader"
{
    Properties
    {
        _MainTex ("Texture", 2D) = "white" {}
        _Color0("Color 0", Color) = (0, 0, 0, 1)
        _Color1("Color 1", Color) = (0, .9, .2, 1)
        _Color2("Color 2", Color) = (.9, 1, 0.3, 1)
        _Color3("Color 3", Color) = (.9, 0.7, 0.1, 1)
        _Color4("Color 4", Color) = (1, 0, 0, 1)

        //                 colors[1] = float4(0, 0.9, 0.2, 1); // green/blue
                // colors[2] = float4(0.9, 1, .3, 1);
                // colors[3] = float4(0.9, 0.7, 0.1, 1);
                // colors[4] = float4(1, 0, 0, 1); // red
    }
    SubShader
    {
        Tags { "RenderType"="Opaque" }
        LOD 100

        Pass
        {
            CGPROGRAM
            #pragma vertex vert
            #pragma fragment frag
            // make fog work
            #pragma multi_compile_fog

            #include "UnityCG.cginc"

            struct appdata
            {
                float4 vertex : POSITION;
                float2 uv : TEXCOORD0;
            };

            struct v2f
            {
                float2 uv : TEXCOORD0;
                UNITY_FOG_COORDS(1)
                float4 vertex : SV_POSITION;
            };

            sampler2D _MainTex;
            float4 _MainTex_ST;

            v2f vert (appdata v)
            {
                v2f o;
                o.vertex = UnityObjectToClipPos(v.vertex);
                o.uv = TRANSFORM_TEX(v.uv, _MainTex);
                UNITY_TRANSFER_FOG(o,o.vertex);
                return o;
            }

            float4 colors[5];
            float pointRanges[5];

            float _Hits[3 * 32];
            int _HitCount = 0;

            float4 _Color0;
            float4 _Color1;
            float4 _Color2;
            float4 _Color3;
            float4 _Color4;

            void init() {
                // Setup color ranges (black/transparent to red)
                colors[0] = _Color0;
                colors[1] = _Color1;
                colors[2] = _Color2;
                colors[3] = _Color3;
                colors[4] = _Color4;

                pointRanges[0] = 0;
                pointRanges[1] = 0.25;
                pointRanges[2] = 0.5;
                pointRanges[3] = 0.75;
                pointRanges[4] = 1.0;

                // _HitCount = 2;

                // Samples of manual hit
                // _Hits[0] = 0;
                // _Hits[1] = 0;
                // _Hits[2] = 2;

                // _Hits[3] = 1;
                // _Hits[4] = 1;
                // _Hits[5] = 3;
            }

            float3 getHeatForPixel(float weight) {
                if (weight < pointRanges[0]) {
                    return colors[0];
                }
                
                if (weight >= pointRanges[4]) {
                    return colors[4];
                }

                for (int i = 1; i < 5; i++) {
                    // If the weight is b/w the point and the point before its range
                    if (weight < pointRanges[i]) {
                        float distFromLowerPoint = weight - pointRanges[i - 1]; // how far the distance is from the lower point
                        float sizeOfPointRange = pointRanges[i] - pointRanges[i - 1];

                        float ratioOverLowerPoint = distFromLowerPoint / sizeOfPointRange; // value b/w 0 and 1

                        float3 colorRange = colors[i] - colors[i - 1];
                        float3 colorContribution = colorRange * ratioOverLowerPoint; // color contribution of the weight 

                        float3 newColor = colors[i - 1] + colorContribution;

                        return newColor;
                    }
                }

                return colors[0];
            }

            float distsq(float2 a, float2 b) {
                float diameterOfEffectSize = 0.5f; // Affects the diameter of the hit point
                float d = pow(max(0.0, 1.0 - distance(a, b) / diameterOfEffectSize), 2.0);

                return d;
            }

            fixed4 frag (v2f i) : SV_Target
            {
                fixed4 col = tex2D(_MainTex, i.uv);

                init();
                float2 uv = i.uv;
                uv = uv * 4.0 - float2(2.0, 2.0); // change uv coordinate range to -2 - 2

                float totalWeight = 0;
                
                for (float i = 0; i < _HitCount; i ++) {
                    float2 workPoint = float2(_Hits[i*3], _Hits[i*3+1]);
                    float pointIntensity = _Hits[i*3 + 2];

                    totalWeight += 0.5 * distsq(uv, workPoint) * pointIntensity;
                }

                float3 heat = getHeatForPixel(totalWeight);

                UNITY_APPLY_FOG(i.fogCoord, col);
                return col + float4(heat, 0.5);
            }
            ENDCG
        }
    }
}

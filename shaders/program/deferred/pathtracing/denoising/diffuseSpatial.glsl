
    #include "/include/uniforms.glsl"
    #include "/include/checker.glsl"
    #include "/include/config.glsl"
    #include "/include/constants.glsl"
    #include "/include/common.glsl"
    #include "/include/pbr.glsl"
    #include "/include/main.glsl"
    #include "/include/textureSampling.glsl"
    #include "/include/spaceConversion.glsl"

    #include "/include/text.glsl"

    /* RENDERTARGETS: 2 */
    layout (location = 0) out vec4 filteredData;

    const vec2 kernel[8] = vec2[8](
        vec2(-2.0, 2.0),
        vec2(2.0, 2.0),
        vec2(0.0, 40.0),
        vec2(40.0, 0.0),
        vec2(8.0, 0.0),
        vec2(0.0, 8.0),
        vec2(16.0, 16.0),
        vec2(-16.0, 16.0)
    );

    void main ()
    {   
        ivec2 srcTexel = ivec2(gl_FragCoord.xy);

        #ifdef DIFFUSE_HALF_RES
            ivec2 dstTexel = 2 * ivec2(gl_FragCoord.xy) + checker2x2(frameCounter);
        #else
            ivec2 dstTexel = srcTexel;
        #endif
        
        float depth = texelFetch(depthtex1, dstTexel, 0).x;

        if (depth == 1.0) 
        {
            filteredData = texelFetch(colortex2, srcTexel, 0);
            return;
        }
        
        uint normalData = texelFetch(colortex9, dstTexel, 0).r;

        vec4 currData = texelFetch(colortex2, srcTexel, 0);
        float currLogLum = log2(luminance(currData.rgb));
        vec3 currNormal = octDecode(unpackExp4x8(normalData).zw);
        vec4 currPos = screenToPlayerPos(vec3((dstTexel + 0.5) * internalTexelSize, depth));

        #ifdef NORMAL_MAPPING
            vec3 geoNormal = octDecode(unpackExp4x8(normalData).xy);
        #else
            vec3 geoNormal = currNormal;
        #endif

        #if FILTER_PASS > 3
            float dither = blueNoise(gl_FragCoord.xy).x;
        #endif

        vec2 sampleDir = kernel[FILTER_PASS ^ (frameCounter & 1)];
        
        float intensityWeight = DENOISER_INTENSITY_WEIGHT * 0.002 * length(sampleDir);
        float varianceWeight = exp(-currData.w) * (sqrt(DIFFUSE_SAMPLES) * 128.0);

        vec4 samples = vec4(0.0);
        float weights = 0.0;

        #if FILTER_PASS < 4 
            vec2 samplePos = gl_FragCoord.xy - sampleDir;
            for (int i = 0; i < 5; i++, samplePos += 0.5 * sampleDir) 
        #else
            #if DIFFUSE_FILTER_QUALITY == 1
                vec2 samplePos = gl_FragCoord.xy + (dither * 0.4 - 1.0) * sampleDir;
                for (int i = 0; i < 5; i++, samplePos += 0.4 * sampleDir) 
            #else
                vec2 samplePos = gl_FragCoord.xy + (dither * 0.66 - 1.0) * sampleDir;
                for (int i = 0; i < 3; i++, samplePos += 0.66 * sampleDir) 
            #endif
        #endif
        {   
            ivec2 sampleTexel = ivec2(samplePos);
            #ifdef DIFFUSE_HALF_RES
                ivec2 sampleCoord = 2 * sampleTexel + checker2x2(frameCounter);
            #else
                ivec2 sampleCoord = sampleTexel;
            #endif

            if (clamp(sampleCoord, ivec2(0), ivec2(internalScreenSize) - 1) == sampleCoord) {
                #ifdef DIFFUSE_HALF_RES
                    vec4 sampleData = texelFetch(colortex2, clamp(sampleTexel, ivec2(0), ivec2(floor(internalScreenSize * 0.5)) - 1), 0);
                #else
                    vec4 sampleData = texelFetch(colortex2, sampleCoord, 0);
                #endif

                if (!any(isnan(sampleData))) {
                    vec3 sampleNormal = octDecode(unpack2x8(texelFetch(colortex9, sampleCoord, 0).x & 65535u));
                    vec3 posDiff = currPos.xyz - screenToPlayerPos(vec3((sampleCoord + 0.5) * internalTexelSize, texelFetch(depthtex1, sampleCoord, 0).x)).xyz;

                    float sampleWeight = exp(-varianceWeight * (
                          DENOISER_NORMAL_WEIGHT * (-dot(sampleNormal, currNormal) * 0.5 + 0.5)
                        + DENOISER_DEPTH_WEIGHT * abs(dot(geoNormal, posDiff))
                        + intensityWeight * min(abs(log2(luminance(sampleData.rgb)) - currLogLum), 3.0)
                        )
                    );

                    weights += sampleWeight;
                    samples += sampleWeight * sampleData;
                }
            }
        }

        if (weights > exp2(-16.0)) filteredData = vec4(samples / weights);
        else filteredData = currData;
    }
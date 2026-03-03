
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

    const vec2 kernel[4] = vec2[4](
        vec2(4.0, -4.0),
        vec2(4.0, 4.0),
        vec2(16.0, 16.0),
        vec2(16.0, -16.0)
    );
    
    void main ()
    {   
        ivec2 texel = ivec2(gl_FragCoord.xy);

        float depth = texelFetch(depthtex1, texel, 0).x;
        filteredData = texelFetch(colortex2, texel, 0);

        if (depth == 1.0) return;
        
        DeferredMaterial mat = unpackMaterialData(texel);

        if (mat.roughness > REFLECTION_ROUGHNESS_THRESHOLD || mat.roughness < 0.003) return;

        vec4 currData = texelFetch(colortex2, texel, 0);
        float currLogLum = log2(currData.r + currData.g + currData.b);

        #if FILTER_PASS > 1
            float dither = blueNoise(gl_FragCoord.xy).r;
        #endif

        vec4 currPos = screenToPlayerPos(vec3(internalTexelSize * (texel + 0.5), depth));

        #if FILTER_PASS > 1
		    vec2 sampleDir = kernel[FILTER_PASS ^ (frameCounter & 1)] * min1(mat.roughness * 40.0);
        #else
            vec2 sampleDir = kernel[FILTER_PASS ^ (frameCounter & 1)];
        #endif

        float temporalWeight = (isnan(currData.w) ? 0.0 : clamp(currData.w, 0.0, 32.0)) * sqrt(REFLECTION_SAMPLES);
        vec4 samples = vec4(0.0);
        float weights = 0.0;

        #if FILTER_PASS < 2 
            vec2 samplePos = gl_FragCoord.xy - sampleDir;
            for (int i = 0; i < 5; i++, samplePos += 0.5 * sampleDir) 
        #else
            vec2 samplePos = gl_FragCoord.xy + (dither * 0.66 - 1.0) * sampleDir;
            for (int i = 0; i < 3; i++, samplePos += 0.66 * sampleDir) 
        #endif
        {
            ivec2 sampleTexel = ivec2(samplePos);

            if (clamp(sampleTexel, ivec2(0), ivec2(internalScreenSize) - 1) == sampleTexel) {
                vec4 sampleData = texelFetch(colortex2, sampleTexel, 0);

                if (!any(isnan(sampleData))) {
                    vec3 sampleNormal = octDecode(unpackExp4x8(texelFetch(colortex9, sampleTexel, 0).r).zw);
                    float sampleRoughness = sqr(1.0 - unpackUnorm4x8(texelFetch(colortex8, sampleTexel, 0).g).g);

                    float sampleWeight = exp(-temporalWeight * (
                          DENOISER_DEPTH_WEIGHT * abs(dot(mat.geoNormal, currPos.xyz - screenToPlayerPos(vec3((sampleTexel + 0.5) * internalTexelSize, texelFetch(depthtex1, sampleTexel, 0).x)).xyz))
                        + DENOISER_NORMAL_WEIGHT * (-dot(sampleNormal, mat.textureNormal) * 0.5 + 0.5)
                        + 5.0 * abs(mat.roughness - sampleRoughness)
                        )
                    );

                    weights += sampleWeight;
                    samples += sampleWeight * sampleData;
                }
            }
        }

        if (weights > 0.0008 && !any(isnan(filteredData))) filteredData = samples / weights;
        else filteredData = currData;
    }
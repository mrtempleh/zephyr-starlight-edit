    #include "/include/uniforms.glsl"
    #include "/include/checker.glsl"
    #include "/include/config.glsl"
    #include "/include/constants.glsl"
    #include "/include/common.glsl"
    #include "/include/pbr.glsl"
    #include "/include/main.glsl"
    #include "/include/textureSampling.glsl"
    #include "/include/spaceConversion.glsl"

    layout (rgba16f) uniform image2D colorimg2;
    layout (local_size_x = 8, local_size_y = 8) in;

    #ifdef DIFFUSE_HALF_RES
        #if TAA_UPSCALING_FACTOR == 100
            const vec2 workGroupsRender = vec2(0.5, 0.5);
        #elif TAA_UPSCALING_FACTOR == 83
            const vec2 workGroupsRender = vec2(0.415, 0.415);
        #elif TAA_UPSCALING_FACTOR == 75
            const vec2 workGroupsRender = vec2(0.375, 0.375);
        #elif TAA_UPSCALING_FACTOR == 66
            const vec2 workGroupsRender = vec2(0.33, 0.33);
        #elif TAA_UPSCALING_FACTOR == 50
            const vec2 workGroupsRender = vec2(0.25, 0.25);
        #elif TAA_UPSCALING_FACTOR == 33
            const vec2 workGroupsRender = vec2(0.165, 0.165);
        #elif TAA_UPSCALING_FACTOR == 25
            const vec2 workGroupsRender = vec2(0.125, 0.125);
        #endif
    #else
        #if TAA_UPSCALING_FACTOR == 100
            const vec2 workGroupsRender = vec2(1.0, 1.0);
        #elif TAA_UPSCALING_FACTOR == 83
            const vec2 workGroupsRender = vec2(0.83, 0.83);
        #elif TAA_UPSCALING_FACTOR == 75
            const vec2 workGroupsRender = vec2(0.75, 0.75);
        #elif TAA_UPSCALING_FACTOR == 66
            const vec2 workGroupsRender = vec2(0.66, 0.66);
        #elif TAA_UPSCALING_FACTOR == 50
            const vec2 workGroupsRender = vec2(0.5, 0.5);
        #elif TAA_UPSCALING_FACTOR == 33
            const vec2 workGroupsRender = vec2(0.33, 0.33);
        #elif TAA_UPSCALING_FACTOR == 25
            const vec2 workGroupsRender = vec2(0.25, 0.25);
        #endif
    #endif

    void main ()
    {   
        ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
        vec4 currData = texelFetch(colortex3, texel, 0);

        #ifdef DENOISER_VARIANCE_GUIDE
            float luminanceMax = 0.0; float luminanceMin = 65536.0;

            for (int x = -1; x <= 1; x++) {
                for (int y = -1; y <= 1; y++) {
                    float sampleData = luminance(texelFetch(colortex3, clamp(texel + ivec2(x, y), ivec2(0), ivec2(internalScreenSize) - 1), 0).rgb);

                    luminanceMax = max(luminanceMax, sampleData);
                    luminanceMin = min(luminanceMin, sampleData);
                }
            }

            float variance = (luminanceMax - luminanceMin) / max(0.00001, luminanceMin);

            variance = clamp(2.0 * variance + rcp(0.002 * currData.w * currData.w + 0.003), 0.0, 3.0);
        #else
            float variance = -log(currData.w * rcp(sqrt(DIFFUSE_SAMPLES) * 128.0));
        #endif

        imageStore(colorimg2, texel, vec4(currData.rgb, variance));
    }
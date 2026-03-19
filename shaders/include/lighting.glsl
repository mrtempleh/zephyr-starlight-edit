#ifndef INCLUDE_LIGHTING
    #define INCLUDE_LIGHTING

    IrradianceSum sampleReflectionLighting (vec3 playerPos, vec3 normal, vec2 rand, float gradient)
    {
        vec3 sampleUv = playerToScreenPos(playerPos);
        ivec2 sampleTexel = ivec2(sampleUv.xy * internalScreenSize);

        float weight = exp(-16.0 * lengthSquared(playerPos - screenToPlayerPos(vec3(sampleUv.xy, texelFetch(depthtex1, sampleTexel, 0).x)).xyz)) 
                     * (1.0 - smoothstep(gradient, 0.5, abs(sampleUv.x - 0.5))) 
                     * (1.0 - smoothstep(gradient, 0.5, abs(sampleUv.y - 0.5)));

        IrradianceSum screen = IrradianceSum(vec3(0.0), vec3(0.0));
        IrradianceSum cache  = IrradianceSum(vec3(0.0), vec3(0.0));

        #ifdef DIFFUSE_HALF_RES
            if (weight > 0.01) screen = IrradianceSum(texelFetch(colortex12, sampleTexel >> 1, 0).rgb, texelFetch(colortex5, sampleTexel, 0).rgb);
        #else
            if (weight > 0.01) screen = IrradianceSum(texelFetch(colortex12, sampleTexel, 0).rgb, texelFetch(colortex5, sampleTexel, 0).rgb);
        #endif

        if (weight < 0.99) {
            cache = irradianceCacheSmooth(playerPos, normal, 0u, rand);
/*
            #ifdef REFLECTION_PER_PIXEL_SHADOWS
                if (dot(normal, shadowDir) > -0.0001) cache.directIrradiance = TraceShadowRay(Ray(playerPos, sampleSunDir(shadowDir, rand)), SHADOW_MAX_RT_DISTANCE, true).rgb;
            #endif
        */
        }

        return IrradianceSum(mix(cache.diffuseIrradiance / SECONDARY_GI_BRIGHTNESS, screen.diffuseIrradiance, weight), mix(cache.directIrradiance, screen.directIrradiance, weight));
    }

#endif

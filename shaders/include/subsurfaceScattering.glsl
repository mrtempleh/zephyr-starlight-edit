#ifndef INCLUDE_SSS
    #define INCLUDE_SSS

    #ifdef SSS_ENABLED
        vec3 subsurfaceScattering (vec3 playerPos, vec3 albedo, float mu, vec2 dither)
        {
            vec3 shadowViewPos = playerToShadowViewPos(vec4(playerPos, 1.0));
            float sssDepth = 0.0;

            mat2 sampleRotate = rotate(0.2451223 * TWO_PI);
            vec2 state = vec2(sin(dither.x * TWO_PI), cos(dither.x * TWO_PI));

            for (int i = 0; i < SSS_STEP_COUNT; i++) 
            {
                float sampleDist = fract(0.4301597 * i + dither.y);
                state *= sampleRotate;

                sssDepth += clamp(textureShadow(shadowViewPos.xy + SSS_RADIUS * sampleDist * state) - shadowViewPos.z, 0.0, 8.0 * rcp(SSS_ABSORPTION));
            }

            return shadowLightBrightness * lightTransmittance(shadowDir)
                * SSS_INTENSITY
                * (1.0 - exp(-2.0 * albedo * albedo))
                * exp(-SSS_ABSORPTION * rcp(SSS_STEP_COUNT) * sssDepth + SSS_PHASE * mu)
                * 32.0;
        }
    #else
        #define subsurfaceScattering(playerPos, albedo, mu, dither) vec3(0.0)
    #endif

#endif
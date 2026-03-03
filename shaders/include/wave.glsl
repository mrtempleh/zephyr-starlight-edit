// Based on https://www.shadertoy.com/view/tdSSWz

#ifndef INCLUDE_WAVE
    #define INCLUDE_WAVE

    #define waterTransmittance(dist) exp(-vec3(WATER_ABSORPTION_R, WATER_ABSORPTION_G, WATER_ABSORPTION_B) * (dist))

    float noise (vec2 coord, float scale)
    {
        vec2 texel = coord * scale;

        float result = 0.0;

        for (int i = 0; i < 4; i++) {
            ivec2 offset = ivec2(i & 1, i >> 1);
            ivec2 sampleCoord = (ivec2(texel) + offset) & 65535;

            uint state = uint(sampleCoord.x) + 65536u * uint(sampleCoord.y);
            float sampleData = randomValue(state);

            result += sampleData * hermite(1.0 - abs(texel.x - floor(texel.x + offset.x))) 
                                 * hermite(1.0 - abs(texel.y - floor(texel.y + offset.y)));
        }

        return result;
    }

    #define NOISE_OCTAVES 4

    float fbm (vec2 coord)
    {
        float result = 0.0;

        for (int i = 0; i < NOISE_OCTAVES; i++) {
            result += exp2(-float(i)) * noise(coord, WATER_WAVE_FREQUENCY * exp2(float(i) * 0.7));
        }
        
        return result * 0.5;
    }

    float calcWaterHeight (vec3 worldPos)
    {
        vec3 coord = vec3(worldPos.xz + vec2(0.3, 0.4) * worldPos.y, mod(frameTimeCounter * WATER_WAVE_SPEED, 4096.0));

        float f1 = fbm(mat3x2(0.5, 1.6, 0.2, -0.9, 0.5, 0.6) * coord);
        float f2 = fbm(mat3x2(0.3, 1.8, -0.6, 0.9, -1.0, 0.1) * coord);

        return 0.25 * sqr(f1 + f2);
    }

    vec3 calcWaterNormal (vec3 worldPos)
    {
        vec3 offsetCoord = worldPos + vec3(WATER_WAVE_TURBULENCE * rcp(max(WATER_WAVE_FREQUENCY, 0.0001)) * calcWaterHeight(worldPos), 0.0, 0.0);

        float centerHeight = calcWaterHeight(offsetCoord);

        float dfdx = calcWaterHeight(offsetCoord + vec3(0.00025, 0.0, 0.0));
        float dfdz = calcWaterHeight(offsetCoord + vec3(0.0, 0.0, 0.00025));

        return vec3(rcp(0.00025) * (vec2(dfdx, dfdz) - centerHeight), rcp(max(WATER_WAVE_HEIGHT, 0.0001)));
    }

    #ifndef STAGE_BEGIN
        vec3 sampleWaterNormal (vec3 worldPos)
        {
            vec2 uv = fract((worldPos.xz + vec2(0.3, 0.4) * worldPos.y) * rcp(64.0) + 0.5);
            return vec3(texture(texWaterNormal, uv).rg, rcp(max(WATER_WAVE_HEIGHT, 0.0001)));
        }
  
        float calcWaterCaustics (vec3 playerPos, vec3 rayDir, float dist)
        {
            return exp(WATER_CAUSTICS_STRENGTH * 32.0 * sqrt(abs(rayDir.y)) * min(log(dist + 1.0), 4.0) * (dot(rayDir, normalize(sampleWaterNormal(playerPos + cameraPosition).xzy)) - rayDir.y));
        }
    #endif

#endif
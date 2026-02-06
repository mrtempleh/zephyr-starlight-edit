#ifndef INCLUDE_SURFACE
    #define INCLUDE_SURFACE

    ivec2 wrap (ivec2 x, ivec4 bounds)
    {
        return bounds.xy + (x - bounds.xy) % (bounds.zw - bounds.xy);
    }

    vec2 wrap (vec2 x, vec4 bounds)
    {
        return bounds.xy + mod(x - bounds.xy, bounds.zw - bounds.xy);
    }

    #ifdef POM
        POMHitResult tracePOM (vec3 rayPos, vec3 rayDir, ivec4 texBounds, int mipLevel, float mipScale)
        {
            POMHitResult result = POMHitResult(rayPos, vec3(0.0, 0.0, 1.0));

            ivec2 texel = ivec2(rayPos.xy);
            vec2 delta = abs(1.0 / rayDir.xy);
            vec2 rayStep = sign(rayDir.xy);
            vec2 sideDist = delta * abs(rayPos.xy - floor(rayPos.xy + max(vec2(0.0), rayStep)));
            vec2 prevSideDist = vec2(0.0);

            float heightScale = POM_DEPTH * POM_TEXTURE_RES * mipScale;

            for (int i = 0; i < POM_STEPS; i++) {
                float height = max(0.001, 1.0 - texelFetch(normals, wrap(texel, texBounds), mipLevel).a) * heightScale;
                float dist = (rayPos.z - height) / rayDir.z;

                bvec2 mask = lessThanEqual(sideDist.xy, sideDist.yx);
                
                if (dist < min(sideDist.x, sideDist.y)) {
                    float minDist = min(prevSideDist.x, prevSideDist.y);

                    if (dist > minDist) {
                        result.normal = vec3(0.0, 0.0, 1.0);
                    } else {
                        result.normal = vec3(-vec2(equal(prevSideDist.xy, vec2(minDist))) * rayStep, 0.0);
                        dist = minDist;
                    }

                    result.hitPos = rayPos + rayDir * dist - result.normal * 0.0005;
                    break;
                }

                prevSideDist = sideDist;
                sideDist += vec2(mask) * delta;
                texel += ivec2(mask) * ivec2(rayStep);
            }

            return result;
        }
    #endif

#endif
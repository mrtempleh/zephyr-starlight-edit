#ifndef INCLUDE_IRCACHE
    #define INCLUDE_IRCACHE

    uint packCachePos (ivec4 pos) 
    {
        pos &= ivec4(511, 511, 511, 31);
        return (pos.x << 23) | (pos.y << 14) | (pos.z << 5) | (pos.w);
    }

    ivec4 unpackCachePos (uint pack)
    {
        ivec4 result = ivec4(pack >> 23, pack >> 14, pack >> 5, pack) & ivec4(511, 511, 511, 31);
        return ((result - ivec4((cameraPositionInt >> max(0, result.w - 2)) << max(0, 2 - result.w), 0) + ivec4(256, 256, 256, 0)) & ivec4(511, 511, 511, 31)) + ivec4((cameraPositionInt >> max(0, result.w - 2)) << max(0, 2 - result.w), 0) - ivec4(256, 256, 256, 0);
    }

    uint hashCachePos (ivec4 pos)
    {
        return (uint(pos.x) * 73856093) ^ (uint(pos.y) * 19349663) ^ (uint(pos.z) * 83492791) ^ (uint(pos.w) * 51655181);
    }

    uint selectCascade (vec3 pos)
    {   
        float stepSize = clamp(floor(0.5 * log2(lengthSquared(pos)) + log2(6.0 / IRCACHE_CASCADE_RES)), -2.0, 3.0);
        return uint(clamp(0.5 * log2(lengthSquared(exp2(stepSize) * ((floor(exp2(-stepSize) * (cameraMod16 + pos)) + 0.5)) - cameraMod16)) - log2(IRCACHE_CASCADE_RES / 16.0), 0.0, 5.0));
    }

    ivec4 playerToVoxelPos (vec3 pos, vec3 normal, uint lod)
    {
        return ivec4(((cameraPositionInt >> max(0, int(lod) - 2)) << max(0, 2 - int(lod))) + ivec3(floor(exp2(2.0 - float(lod)) * (vec3(cameraPositionInt & ((1u << max(0, int(lod) - 2)) - 1u)) + cameraPositionFract + pos) + normal * 0.475)), lod);
    }

    IrradianceSum irradianceCache (vec3 pos, vec3 normal, uint rank, uint lod)
    {   
        ivec4 voxelPos = playerToVoxelPos(pos, normal, lod);

        uint packedPos = packCachePos(voxelPos);
        uint hashedPos = hashCachePos(voxelPos);

        if (packedPos == 0u) return IrradianceSum(vec3(0.0), vec3(0.0));

        uvec3 packedOrigin = uvec3(256.0 * fract(exp2(2.0 - float(lod)) * (cameraMod16 + pos) + normal * 0.475));
        uvec2 packedNormal = uvec2(14.0 * octEncode(normal) + 0.5);

        for (uint attempt = 0u; attempt < uint(IRCACHE_PROBE_ATTEMPTS); attempt++)
        {   
            uint index = (hashedPos + (attempt * attempt + attempt) / 2) % IRCACHE_VOXEL_ARRAY_SIZE;

            if (ircache.entries[index].packedPos == packedPos && ircache.entries[index].radiance != IRCACHE_INV_MARKER) {
                if (atomicMin(ircache.entries[index].rank, rank + 1u) >= rank + 1u) {
                    if (atomicExchange(ircache.entries[index].lastFrame, frameCounter) != frameCounter) {
                        ircache.entries[index].traceOrigin = (packedOrigin.x << 24u) | (packedOrigin.y << 16u) | (packedOrigin.z << 8u) | (packedNormal.x << 4u) | (packedNormal.y);
                    }
                }

                return IrradianceSum(SECONDARY_GI_BRIGHTNESS * unpackHalf4x16(ircache.entries[index].radiance).rgb, unpack3x10(ircache.entries[index].direct));
            }
        }

        for (uint attempt = 0u; attempt < uint(IRCACHE_PROBE_ATTEMPTS); attempt++)
        {   
            uint index = (hashedPos + (attempt * attempt + attempt) / 2) % IRCACHE_VOXEL_ARRAY_SIZE;

            if (atomicCompSwap(ircache.entries[index].packedPos, 0u, packedPos) == 0u) {
                ircache.entries[index].traceOrigin = (packedOrigin.x << 24u) | (packedOrigin.y << 16u) | (packedOrigin.z << 8u) | (packedNormal.x << 4u) | (packedNormal.y);
                ircache.entries[index].rank = rank + 1u;
                ircache.entries[index].lastFrame = frameCounter;
                break;
            }
        }

        return IrradianceSum(vec3(0.0), vec3(0.0));
    }

    IrradianceSum irradianceCache (vec3 pos, vec3 normal, uint rank)
    {   
        uint lod = selectCascade(pos + normal * 0.005);
       
        return irradianceCache(pos, normal, rank, lod);
    }

    #if SMOOTH_IRCACHE == 0
        #define irradianceCacheSmooth(pos, normal, rank, rand) irradianceCache(pos, normal, rank)
    #elif SMOOTH_IRCACHE == 1
////////////////////////////////////////////////////////////////////////////////////////////////////////////
        IrradianceSum irradianceCacheSmooth (vec3 pos, vec3 normal, uint rank, vec2 rand)
        {
            float scale = exp2(float(selectCascade(pos + normal * 0.005)) - 0.5) * 0.5;

            float theta = TWO_PI * rand.x;
            vec3 dir = tbnNormal(normal) * vec3(scale * (0.1 - sqrt(1.0 - sqrt(rand.y))) * vec2(sin(theta), cos(theta)), 0.0);

            IrradianceSum result = irradianceCache(pos + dir * min(20.0, TraceGenericRay(Ray(pos + normal * 0.003, dir), 2.0, false, false).dist - 0.0001), normal, rank);
            
            return result;
        }
////////////////////////////////////////////////////////////////////////////////////////////////////////////
    #else
////////////////////////////////////////////////////////////////////////////////////////////////////////////
IrradianceSum irradianceCacheSmooth (vec3 pos, vec3 normal, uint rank, vec2 rand)
{
    vec3 offsetPos = pos + normal * 0.005; 
    uint lod = selectCascade(offsetPos);
    float invScale = exp2(floor(lod - 2.0));
    mat3 tbn = tbnNormal(normal);

    IrradianceSum result = IrradianceSum(vec3(0.0), vec3(0.0));
    float weights = 0.0;

    const float smoothRadius = 6.0;
    const int sampleCount = 6;
    
    //
    float radii[6] = float[](0.2, 0.5, 0.9, 1.4, 2.0, 2.5);
    
    float baseAngle = rand.x * 6.28318;
    
    for (int i = 0; i < sampleCount; i++) {
        float angle = baseAngle + (float(i) * 1.0472); // 60 градусов
        float r = radii[i] * (smoothRadius / 2.5);
        
        vec2 finalOffset = vec2(cos(angle), sin(angle)) * r;
        
        vec3 offset = tbn * (invScale * vec3(finalOffset, 0.0));
        
        float traceDist = TraceGenericRay(Ray(offsetPos, offset), 1.0025, true, false).dist - 0.002;
        if (traceDist > 0.001) {
            offset *= min1(traceDist);
            
            IrradianceSum sampleData = irradianceCache(pos + offset, normal, rank, lod);
            
            if (sampleData.diffuseIrradiance != vec3(0.0)) {
                float distNorm = r / smoothRadius;
                float weight = exp(-distNorm * distNorm * 2.5);
                
                result.diffuseIrradiance += weight * sampleData.diffuseIrradiance;
                result.directIrradiance += weight * sampleData.directIrradiance;
                weights += weight;
            }
        }
    }

    if (weights > 0.0) {
        float weightInv = 1.0 / weights;
        result.diffuseIrradiance *= weightInv;
        result.directIrradiance *= weightInv;
    }
    
    return result;
}
////////////////////////////////////////////////////////////////////////////////////////////////////////////
    #endif

    IrradianceSum irradianceCacheSilent (vec3 pos, vec3 normal, uint lod)
    {   
        ivec4 voxelPos = playerToVoxelPos(pos, normal, lod);

        uint hashedPos = hashCachePos(voxelPos);
        uint packedPos = packCachePos(voxelPos);

        for (uint attempt = 0u; attempt < uint(IRCACHE_PROBE_ATTEMPTS); attempt++)
        {   
            uint index = (hashedPos + (attempt * attempt + attempt) / 2) % IRCACHE_VOXEL_ARRAY_SIZE;

            if (ircache.entries[index].packedPos == packedPos && ircache.entries[index].radiance != uvec2(0u)) {
                return IrradianceSum(unpackHalf4x16(ircache.entries[index].radiance).rgb, unpack3x10(ircache.entries[index].direct));
            }
        }

        return IrradianceSum(vec3(0.0), vec3(0.0));
    }

    IrradianceSum irradianceCacheSilent (vec3 pos, vec3 normal)
    {   
        return irradianceCacheSilent(pos, normal, selectCascade(pos + normal * 0.005));
    }

#endif

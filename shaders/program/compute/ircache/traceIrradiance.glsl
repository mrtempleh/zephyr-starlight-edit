#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/octree.glsl"
#include "/include/wave.glsl"
#include "/include/raytracing.glsl"
#include "/include/textureData.glsl"
#include "/include/ircache.glsl"
#include "/include/brdf.glsl"
#include "/include/atmosphere.glsl"
#include "/include/sampling.glsl"

layout (local_size_x = 64) in;

#if IRCACHE_VOXEL_ARRAY_SIZE == 32768
    const ivec3 workGroups = ivec3(512, 1, 1);
#elif IRCACHE_VOXEL_ARRAY_SIZE == 49152
    const ivec3 workGroups = ivec3(768, 1, 1);
#elif IRCACHE_VOXEL_ARRAY_SIZE == 65536
    const ivec3 workGroups = ivec3(1024, 1, 1);
#elif IRCACHE_VOXEL_ARRAY_SIZE == 98304
    const ivec3 workGroups = ivec3(1536, 1, 1);
#elif IRCACHE_VOXEL_ARRAY_SIZE == 131072
    const ivec3 workGroups = ivec3(2048, 1, 1);
#elif IRCACHE_VOXEL_ARRAY_SIZE == 262144
    const ivec3 workGroups = ivec3(4096, 1, 1);
#endif

void main ()
{   
    uint index = gl_GlobalInvocationID.x;

    IrcacheVoxel voxel = ircache.entries[index];
    uint state = gl_GlobalInvocationID.x + (frameCounter & 2047u) * IRCACHE_VOXEL_ARRAY_SIZE;

    if (voxel.packedPos == 0u || voxel.traceOrigin == 0u || frameCounter - voxel.lastFrame > 10u || voxel.lastFrame > frameCounter) {
        ircache.entries[index].traceOrigin = 0u;
        ircache.entries[index].rank = 128u;
        ircache.entries[index].lastFrame = 0u;
        ircache.entries[index].packedPos = 0u;
        ircache.entries[index].direct = 0u;
        ircache.entries[index].radiance = IRCACHE_INV_MARKER;
        return;
    }

    ivec4 voxelPos = unpackCachePos(voxel.packedPos);

    vec3 normal = octDecode(saturate(vec2(uvec2(voxel.traceOrigin >> 4u, voxel.traceOrigin) & 15u) * rcp(14.0)));
    vec3 playerPos = ((voxelPos.xyz << voxelPos.w) - (cameraPositionInt << 2)) / 4.0 - cameraPositionFract + exp2(voxelPos.w - 2.0) * ((uvec3(voxel.traceOrigin >> 24u, voxel.traceOrigin >> 16u, voxel.traceOrigin >> 8u) & 255u) * rcp(256.0) + rcp(512.0) - normal * 0.47);

    Ray ray;
    
    ray.origin = playerPos;

    vec4 currRadiance = vec4(0.0);

    for (int i = 0; i < IRCACHE_SAMPLES; i++) {
        ray.direction = randomHemisphereDir(normal, state);

        RayHitInfo rt = TraceGenericRay(ray, IRCACHE_MAX_RT_DISTANCE, true, true);
        float mu = dot(normal, ray.direction);

        if (rt.hit) {
            IrradianceSum query = irradianceCache(ray.origin + ray.direction * (rt.dist - 0.002), rt.normal, voxel.rank);
            currRadiance.rgb += mu * (rt.albedo.rgb * (rt.emission + query.diffuseIrradiance) + lightTransmittance(shadowDir) * shadowLightBrightness * query.directIrradiance * evalCookBRDF(shadowDir, ray.direction, max(0.2, rt.roughness), rt.normal, rt.albedo.rgb, rt.F0));
        } 
        #ifdef DIMENSION_OVERWORLD
            else {
                currRadiance.rgb += mu * rt.albedo.rgb * sampleSkyView(ray.direction);
            }
        #endif
    }
    
    currRadiance.rgb *= rcp(IRCACHE_SAMPLES);

    vec4 prevRadiance = unpackHalf4x16(voxel.radiance);
    vec3 prevShadow   = unpack3x10(voxel.direct);

    if (any(isnan(currRadiance))) currRadiance = vec4(0.0);
    if (any(isnan(prevRadiance))) prevRadiance = vec4(0.0, 0.0, 0.0, 1.0);

    vec3 currShadow = vec3(0.0);

    if (dot(normal, shadowDir) > 0.0) currShadow = TraceShadowRay(Ray(ray.origin, sampleSunDir(shadowDir, vec2(randomValue(state), randomValue(state)))), 1024.0, true).rgb;
    else currShadow = vec3(0.0);

    if (prevRadiance.w == 1.0) {
        for (int i = voxelPos.w - 1; i <= voxelPos.w + 2; i += 2) {
            if (i >= 0) {
                IrradianceSum prevData = irradianceCacheSilent(playerPos, normal, i);

                if (prevData.diffuseIrradiance != vec3(0.0)) {
                    prevRadiance.rgb = max(vec3(0.0), prevData.diffuseIrradiance);
                    prevRadiance.w = rcp(IRCACHE_BLEND_WEIGHT);

                    prevShadow = currShadow;

                    break;
                }
            }
        }
    }

    prevRadiance.w = clamp(prevRadiance.w, 1.0, rcp(IRCACHE_BLEND_WEIGHT));

    ircache.entries[index].direct   = pack3x10(mix(prevShadow, currShadow, rcp(min(prevRadiance.w, 16.0))));
    ircache.entries[index].radiance = packHalf4x16(vec4(mix(prevRadiance.rgb, currRadiance.rgb, rcp(prevRadiance.w)), prevRadiance.w + 1.0));
}
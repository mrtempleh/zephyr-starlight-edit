#include "/include/uniforms.glsl"
#include "/include/checker.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/sampling.glsl"
#include "/include/octree.glsl"
#include "/include/wave.glsl"
#include "/include/raytracing.glsl"
#include "/include/textureData.glsl"
#include "/include/brdf.glsl"
#include "/include/ircache.glsl"
#include "/include/atmosphere.glsl"
#include "/include/spaceConversion.glsl"
#include "/include/lighting.glsl"

layout (rgba16f) uniform image2D colorimg2;
layout (local_size_x = 8, local_size_y = 8) in;

#ifdef REFLECTION_HALF_RES
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
    #ifdef REFLECTION_HALF_RES
        ivec2 offsetCoord = min(ivec2(gl_GlobalInvocationID.xy) * 2 + checker2x2(frameCounter), ivec2(internalScreenSize) - 1);
        uint state = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * uint(internalScreenSize.x / 2.0) + uint(internalScreenSize.x / 2.0) * uint(internalScreenSize.y / 2.0) * (frameCounter & 1023u);
    #else
        ivec2 offsetCoord = ivec2(gl_GlobalInvocationID.xy);
        uint state = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * uint(internalScreenSize.x) + uint(internalScreenSize.x) * uint(internalScreenSize.y) * (frameCounter & 1023u);
    #endif

    float depth = texelFetch(depthtex1, offsetCoord, 0).x;

    if (depth == 1.0) {
        imageStore(colorimg2, ivec2(gl_GlobalInvocationID.xy), vec4(0.0, 0.0, 0.0, 1.0));
        return;
    }

    DeferredMaterial mat = unpackMaterialData(offsetCoord);

    if (mat.roughness > REFLECTION_ROUGHNESS_THRESHOLD) {
        imageStore(colorimg2, ivec2(gl_GlobalInvocationID.xy), vec4(0.0, 0.0, 0.0, 1.0));
        return;
    }

    vec2 uv = (vec2(offsetCoord) + 0.5) * internalTexelSize;
    vec3 rayOrigin = screenToPlayerPos(vec3(uv, depth)).xyz;
    vec3 rayDir = normalize(rayOrigin - screenToPlayerPos(vec3(uv, 0.0)).xyz);
    vec3 reflectedDir = reflect(rayDir, mat.textureNormal);

    if (mat.isHand) {
        rayOrigin += 0.5 * playerLookVector;
    }

    vec3 radiance = vec3(0.0);
    float reflectionDepth = REFLECTION_MAX_RT_DISTANCE;

    for (int i = 0; i < REFLECTION_SAMPLES; i++) {
        vec3 throughput = vec3(1.0);
        float roughnessAccum = mat.roughness;
        float rayDist = 0.0;

        Ray specularRay;
        specularRay.origin = rayOrigin + mat.geoNormal * 0.0;

        specularRay.direction = sampleVNDF(rayDir, mat.textureNormal, mat.roughness,
            #if NOISE_METHOD == 1
                vec2(heitzSample(ivec2(gl_GlobalInvocationID.xy), REFLECTION_SAMPLES * frameCounter + i, 0), heitzSample(ivec2(gl_GlobalInvocationID.xy), REFLECTION_SAMPLES * frameCounter + i, 1))
            #else
                vec2(randomValue(state), randomValue(state))
            #endif
        );

        float pdf = exp(8.0 * (dot(specularRay.direction, reflectedDir) - 1.0));

        if (dot(specularRay.direction, mat.geoNormal) < 0.0) {
            specularRay.direction = reflect(specularRay.direction, mat.geoNormal);
            throughput *= mat.F0;
        }

        for (int j = 0; j < REFLECTION_BOUNCES; j++) {
            RayHitInfo rt = TraceGenericRay(specularRay, REFLECTION_MAX_RT_DISTANCE, true, true);

            if (luminance(throughput) > 0.5 && roughnessAccum < 0.2) rayDist += rt.dist;

            if (rt.hit) {
                throughput *= pdf;

                radiance += throughput * rt.albedo.rgb * rt.emission;

                vec3 hitPos = specularRay.origin + rt.dist * specularRay.direction;

                #ifdef REFLECTION_SS_REUSE
                    IrradianceSum r = sampleReflectionLighting(hitPos, rt.normal, vec2(randomValue(state), randomValue(state)), 0.3);
                #else
                    vec2 rand = vec2(randomValue(state), randomValue(state));

                    IrradianceSum r = irradianceCacheSmooth(hitPos, rt.normal, 0u, rand);

                    #ifdef REFLECTION_PER_PIXEL_SHADOWS
                        if (dot(rt.normal, shadowDir) > -0.0001) r.directIrradiance = TraceShadowRay(Ray(specularRay.origin + rt.dist * specularRay.direction, sampleSunDir(shadowDir, rand)), SHADOW_MAX_RT_DISTANCE, true).rgb;
                    #endif
                #endif

                radiance += throughput * r.diffuseIrradiance * rt.albedo.rgb;

                if (dot(rt.normal, shadowDir) > -0.0001) {
                    radiance += throughput * lightTransmittance(shadowDir) * shadowLightBrightness * r.directIrradiance * evalCookBRDF(normalize(shadowDir + rt.normal * 0.03125), specularRay.direction, max(0.2, rt.roughness), rt.normal, rt.albedo.rgb, rt.F0);
                }

                roughnessAccum = mix(roughnessAccum, 1.0, rt.roughness);

                if (roughnessAccum > REFLECTION_ROUGHNESS_THRESHOLD || luminance(throughput) < 0.2) {
                    break;
                } else {
                    throughput *= schlickFresnel(rt.F0, -dot(specularRay.direction, rt.normal));
                    specularRay.origin = hitPos + rt.normal * 0.003;
                    specularRay.direction = sampleVNDF(specularRay.direction, rt.normal, rt.roughness, vec2(randomValue(state), randomValue(state)));
                }
            } else {
                #ifdef DIMENSION_OVERWORLD
                    radiance += throughput * rt.albedo.rgb * sampleSkyView(specularRay.direction);
                #endif
                break;
            }
        }
        
        reflectionDepth = min(reflectionDepth, rayDist);
    }

    imageStore(colorimg2, ivec2(gl_GlobalInvocationID.xy), vec4(radiance * rcp(REFLECTION_SAMPLES), reflectionDepth));
}

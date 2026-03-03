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

// This shit is not optimisated

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

// Path state for multiple bounces
struct PathState {
    vec3 origin;
    vec3 direction;
    vec3 throughput;  // Accumulated color from bounces
    float totalDistance; // Total ray distance traveled
    int bounce;       // Current bounce number
};

// Generate next bounce direction
vec3 generateBounceDirection(vec3 normal, vec3 textureNormal, inout uint state) {
    #if SAMPLING_METHOD == 1
        #if NOISE_METHOD == 1
            vec3 dir = randomHemisphereDir(normal, state);
        #else
            vec3 dir = randomHemisphereDir(normal, state);
        #endif
        return normalize(mix(normal, dir, 0.5));
    #else
        return randomHemisphereDir(normal, state);
    #endif
}

void main ()
{
    #ifdef DIFFUSE_HALF_RES
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

    if (luminance(mat.albedo) < 0.001) {
        imageStore(colorimg2, ivec2(gl_GlobalInvocationID.xy), vec4(0.0, 0.0, 0.0, 1.0));
        return;
    }

    vec2 uv = (vec2(offsetCoord) + 0.5) * internalTexelSize;
    vec3 rayOrigin;

    if (mat.isHand) {
        rayOrigin = 0.5 * playerLookVector;
    } else {
        rayOrigin = screenToPlayerPos(vec3(uv, depth)).xyz;
    }
    
    vec3 finalRadiance = vec3(0.0);
    
    // Use MAX_PATH_DISTANCE from config

    for (int sampleIdx = 0; sampleIdx < DIFFUSE_SAMPLES; sampleIdx++) {
        // Initialize path state for this sample
        PathState path;
        path.origin = rayOrigin + mat.geoNormal * 0.005;
        path.throughput = vec3(DIFFUSE_RAY_BRIGHTNESS * 1.5);
        path.totalDistance = 0.0;
        

        #if SAMPLING_METHOD == 1
            #if NOISE_METHOD == 1
                vec3 dir = randomDirBlueNoise(ivec2(gl_GlobalInvocationID.xy), sampleIdx);
                path.direction = normalize(mat.textureNormal + dir);
            #else
                vec3 dir = randomDir(state);
                path.direction = normalize(mat.textureNormal + dir);
            #endif

            if (dot(path.direction, mat.geoNormal) <= 0.0) continue;
        #else
            #if NOISE_METHOD == 1
                path.direction = randomHemisphereDirBlueNoise(ivec2(gl_GlobalInvocationID.xy), mat.geoNormal, sampleIdx);
            #else
                path.direction = randomHemisphereDir(mat.geoNormal, state);
            #endif
        #endif

        // Path tracing with multiple bounces
        for (int bounce = 0; bounce < DIFFUSE_BOUNCES + 1; bounce++) {
            #ifdef GLASS_REFRACTION
                RayHitInfo rt = TraceGenericRay(Ray(path.origin, path.direction), DIFFUSE_MAX_RT_DISTANCE, true, false);

                if (rt.hit) {
                    // Track total distance
                    float newDistance = path.totalDistance + rt.dist;
                    
                    // SIMPLE LINEAR FADE - just one line, no branches
                    float fadeFactor = clamp(1.0 - (newDistance / MAX_PATH_DISTANCE), 0.0, 1.0);
                    
                    // Stop completely if beyond limit
                    if (newDistance > MAX_PATH_DISTANCE) {
                        break;
                    }
                    
                    path.totalDistance = newDistance;
                    
                    vec3 hitPos = path.origin + path.direction * rt.dist;

                    if (rt.translucent) {
                        Ray diffuseRefractRay;
                        
                        diffuseRefractRay.origin = hitPos - rt.normal * 0.005;
                        
                        if (rt.blockId == 10100) diffuseRefractRay.direction = path.direction;
                        else diffuseRefractRay.direction = refract(path.direction, rt.normal, rcp(GLASS_IOR));

                        vec3 tintColor = rt.albedo.rgb;

                        rt = TraceGenericRay(diffuseRefractRay, DIFFUSE_MAX_RT_DISTANCE, true, true);
                        rt.albedo.rgb *= tintColor;
                        
                        newDistance = path.totalDistance + rt.dist;
                        
                        // Update fade factor
                        fadeFactor = clamp(1.0 - (newDistance / MAX_PATH_DISTANCE), 0.0, 1.0);
                        
                        // Check distance limit again
                        if (newDistance > MAX_PATH_DISTANCE) {
                            break;
                        }
                        
                        path.totalDistance = newDistance;
                        
                        hitPos += diffuseRefractRay.direction * rt.dist;
                    }

                    // Multiply throughput by surface albedo
                    path.throughput *= rt.albedo.rgb;
                    
                    float distGradient = exp2(-floor(clamp(log2(length(hitPos)) - log2(IRCACHE_CASCADE_RES / 8.0), -1.0, 0.0))) * rt.dist * dot(mat.geoNormal, path.direction);

                    IrradianceSum query = irradianceCache(hitPos, rt.normal, 0u);
                    
                    vec3 indirectLight = smoothstep(0.0, 0.5, distGradient) * max(MINIMUM_LIGHT * vec3(0.4, 0.5, 1.0), query.diffuseIrradiance * rt.albedo.rgb);
                    
                    #if SAMPLING_METHOD == 1
                        float pdf = rcp(HALF_PI);
                    #else
                        float pdf = max(0.0, dot(mat.textureNormal, path.direction));
                    #endif
                    
                    // Apply simple linear fade
                    vec3 contribution = path.throughput * (rt.emission + indirectLight) * pdf * fadeFactor;
                    finalRadiance += contribution;

                    if (bounce == 0) {
                        vec3 sunDir = sampleSunDir(shadowDir, vec2(randomValue(state), randomValue(state)));

                        if (dot(rt.normal, sunDir) > -0.0001) {
                            vec3 sunlight = lightTransmittance(shadowDir) * pdf * shadowLightBrightness * 
                                           evalCookBRDF(normalize(sunDir + rt.normal * 0.03125), path.direction, 
                                                      max(0.2, rt.roughness), rt.normal, rt.albedo.rgb, rt.F0);

                                    #if SUNLIGHT_GI_QUALITY == 0
            sunlight *= smoothstep(0.0, 0.75, distGradient) * query.directIrradiance;
        #elif SUNLIGHT_GI_QUALITY == 1
            if (randomValue(state) > smoothstep(0.5, 1.0, distGradient)) {
                sunlight *= TraceShadowRay(Ray(hitPos + rt.normal * 0.003, sunDir), SHADOW_MAX_RT_DISTANCE, true).rgb;
            } else {
                sunlight *= query.directIrradiance;
            }
        #elif SUNLIGHT_GI_QUALITY == 2
            sunlight *= TraceShadowRay(Ray(hitPos + rt.normal * 0.003, sunDir), SHADOW_MAX_RT_DISTANCE, true).rgb;
        #endif

        // TESTYY
        sunlight *= SUNLIGHT_GI_BOOST;
        
        // Применяем fade к sunlight
        finalRadiance += path.throughput * sunlight * fadeFactor;
    }
}


                    // Prepare next bounce
                    path.origin = hitPos + rt.normal * 0.005;
                    path.direction = generateBounceDirection(rt.normal, mat.textureNormal, state);
                } else {
            #else
                RayHitInfo rt = TraceGenericRay(Ray(path.origin, path.direction), DIFFUSE_MAX_RT_DISTANCE, true, true);

                if (rt.hit) {
                    float newDistance = path.totalDistance + rt.dist;
                    
                    // SIMPLE LINEAR FADE - just one line, no branches
                    float fadeFactor = clamp(1.0 - (newDistance / MAX_PATH_DISTANCE), 0.0, 1.0);
                    
                    // Stop completely if beyond limit
                    if (newDistance > MAX_PATH_DISTANCE) {
                        break;
                    }
                    
                    path.totalDistance = newDistance;
                    
                    vec3 hitPos = path.origin + path.direction * (rt.dist - 0.002);

                    // Multiply throughput by surface albedo
                    path.throughput *= rt.albedo.rgb;
                    
                    float distGradient = exp2(-floor(clamp(log2(length(hitPos)) - log2(IRCACHE_CASCADE_RES / 8.0), -1.0, 0.0))) * rt.dist * dot(mat.geoNormal, path.direction);

                    IrradianceSum query = irradianceCache(hitPos, rt.normal, 0u);
                    
                    #if SAMPLING_METHOD == 1
                        float pdf = rcp(HALF_PI);
                    #else
                        float pdf = max(0.0, dot(mat.textureNormal, path.direction));
                    #endif
                    
                    // Apply simple linear fade
                    vec3 contribution = path.throughput * (rt.emission + smoothstep(0.0, 0.5, distGradient) * max(MINIMUM_LIGHT * vec3(0.4, 0.5, 1.0), query.diffuseIrradiance * rt.albedo.rgb)) * pdf * fadeFactor;
                    finalRadiance += contribution;

                    if (bounce == 0) {
                        vec3 sunDir = sampleSunDir(shadowDir, vec2(randomValue(state), randomValue(state)));

                        if (dot(rt.normal, sunDir) > -0.0001) {
                            vec3 sunlight = lightTransmittance(shadowDir) * pdf * shadowLightBrightness * 
                                           evalCookBRDF(normalize(sunDir + rt.normal * 0.03125), path.direction, 
                                                      max(0.2, rt.roughness), rt.normal, rt.albedo.rgb, rt.F0);

                            #if SUNLIGHT_GI_QUALITY == 0
                                sunlight *= smoothstep(0.0, 0.75, distGradient) * query.directIrradiance;
                            #elif SUNLIGHT_GI_QUALITY == 1
                                if (randomValue(state) > smoothstep(0.5, 1.0, distGradient)) {
                                    sunlight *= TraceShadowRay(Ray(hitPos + rt.normal * 0.003, sunDir), SHADOW_MAX_RT_DISTANCE, true).rgb;
                                } else {
                                    sunlight *= query.directIrradiance;
                                }
                            #elif SUNLIGHT_GI_QUALITY == 2
                                sunlight *= TraceShadowRay(Ray(hitPos + rt.normal * 0.003, sunDir), SHADOW_MAX_RT_DISTANCE, true).rgb;
                            #endif

                            // Apply fade to sunlight too
                            finalRadiance += path.throughput * sunlight * fadeFactor;
                        }
                    }

                    path.origin = hitPos + rt.normal * 0.005;
                    path.direction = generateBounceDirection(rt.normal, mat.textureNormal, state);
                } else {
            #endif
                    #ifdef DIMENSION_OVERWORLD
                        #if SAMPLING_METHOD == 1
                            float pdf = rcp(HALF_PI);
                        #else
                            float pdf = max(0.0, dot(mat.textureNormal, path.direction));
                        #endif
                        finalRadiance += path.throughput * pdf * sampleSkyView(path.direction);
                    #endif
                    break;
                }
            
            // Russian roulette - stop if throughput gets too low
            float maxComponent = max(max(path.throughput.r, path.throughput.g), path.throughput.b);
            if (bounce > 2 && maxComponent < 0.1) {
                if (randomValue(state) < 0.5) {
                    break;
                } else {
                    path.throughput *= 2.0; // Compensation
                }
            }
        }
    }

    imageStore(colorimg2, ivec2(gl_GlobalInvocationID.xy), vec4(finalRadiance * rcp(DIFFUSE_SAMPLES), 1.0));
}
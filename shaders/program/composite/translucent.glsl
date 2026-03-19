#include "/include/uniforms.glsl"
#include "/include/checker.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/octree.glsl"
#include "/include/wave.glsl"
#include "/include/raytracing.glsl"
#include "/include/textureData.glsl"
#include "/include/brdf.glsl"
#include "/include/ircache.glsl"
#include "/include/spaceConversion.glsl"
#include "/include/textureSampling.glsl"
#include "/include/atmosphere.glsl"
#include "/include/sampling.glsl"
#include "/include/lighting.glsl"
#include "/include/text.glsl"
#include "/include/shadowMapping.glsl"
#include "/include/subsurfaceScattering.glsl"

layout (r11f_g11f_b10f) uniform image2D colorimg7;
layout (r32f) uniform image2D colorimg13;

layout (local_size_x = 8, local_size_y = 8) in;

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

// TODO : rewrite this mess

void main ()
{
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    vec2 uv = internalTexelSize * (vec2(texel) + 0.5);

    float depth0       = texelFetch(depthtex0, texel, 0).r;
    float depth1       = texelFetch(depthtex1, texel, 0).r;
    vec4 color         = texelFetch(colortex7, texel, 0) / EXPONENT_BIAS;
    float virtualDepth = texelFetch(colortex13, texel, 0).r;
    
    if (depth1 == depth0) {
        if (isEyeInWater == 1) {
            color.rgb *= waterTransmittance(distance(screenToPlayerPos(vec3(uv, depth0)).xyz, vec3(screenToPlayerPos(vec3(uv, 0.0)))));
            imageStore(colorimg7, texel, EXPONENT_BIAS * color);
        }

        imageStore(colorimg13, texel, vec4(virtualDepth, 0.0, 0.0, 1.0));
        
        return;
    }
    
    TranslucentMaterial mat = unpackTranslucentMaterial(texel);

    vec3 playerPos = screenToPlayerPos(vec3(uv, depth1)).xyz;
    vec3 rayPos    = screenToPlayerPos(vec3(uv, depth0)).xyz;

    float rayDist = distance(rayPos, playerPos);

    if (mat.isHand) {
        rayPos += 0.5 * playerLookVector;
    }

    vec3 rayDir = normalize(rayPos - screenToPlayerPos(vec3(uv, 0.000001)).xyz);
    vec3 refractDir = refract(rayDir, mat.normal, mat.blockId == 10100 ? (isEyeInWater == 1 ? WATER_IOR : rcp(WATER_IOR)) : rcp(GLASS_IOR));

    bool tir = refractDir == vec3(0.0);
    bool water = isEyeInWater == 1 && mat.blockId == 10100;

    Ray ray = Ray(rayPos + mat.normal * 0.01, reflect(rayDir, mat.normal));

    vec3 reflectedRadiance = vec3(0.0);

    RayHitInfo rt = TraceGenericRay(ray, REFLECTION_MAX_RT_DISTANCE, true, true);

    if (rt.hit) {
        IrradianceSum r = sampleReflectionLighting(ray.origin + rt.dist * ray.direction, rt.normal, blueNoise(vec2(texel)).rg, 0.3);

        reflectedRadiance += rt.albedo.rgb * rt.emission + rt.albedo.rgb * r.diffuseIrradiance + lightTransmittance(shadowDir) * shadowLightBrightness * r.directIrradiance * evalCookBRDF(normalize(shadowDir + rt.normal * 0.03125), ray.direction, max(0.1, rt.roughness), rt.normal, rt.albedo.rgb, rt.F0);
    } else {
        reflectedRadiance += rt.albedo.rgb * sampleSkyView(ray.direction);
    }

    if (isEyeInWater == 1) reflectedRadiance.rgb *= waterTransmittance(rt.dist);
    
    #ifdef WATER_REFRACTION
        float waterOpticalDepth = 0.0;
    #else
        float waterOpticalDepth = rayDist;
    #endif

    #if defined GLASS_REFRACTION || defined WATER_REFRACTION
        vec3 throughput = vec3(1.0);
        vec3 refractedRadiance = vec3(0.0);
        float refractionDist = 0.0;

        if (
            #if defined GLASS_REFRACTION && defined WATER_REFRACTION
                mat.blockId == 99 || mat.blockId == 10100
            #elif defined GLASS_REFRACTION
                mat.blockId == 99
            #else
                mat.blockId == 10100
            #endif
        ) { 
            Ray refractRay = Ray(rayPos - mat.normal * 0.01, refractDir);

            if (!tir)
            {
                bool medium = true;

                for (int i = 0; i < REFRACTION_BOUNCES; i++) {
                    RayHitInfo ref = TraceGenericRay(refractRay, 1024.0, true, i == (REFRACTION_BOUNCES - 1));
                    
                    #ifdef WATER_REFRACTION
                        if (mat.blockId == 10100 && i == 0) waterOpticalDepth += ref.dist;
                    #endif

                    refractionDist += ref.dist;

                    if (ref.hit) {
                        vec3 hitPos = refractRay.origin + refractRay.direction * ref.dist;
                        vec3 nextDir = refract(refractRay.direction, ref.normal, ref.blockId == 10100 ? (medium ? WATER_IOR : rcp(WATER_IOR)) : (medium ? GLASS_IOR : rcp(GLASS_IOR)));

                        if (
                            #if defined GLASS_REFRACTION && defined WATER_REFRACTION
                                ref.blockId == 99 || ref.blockId == 10100
                            #elif defined GLASS_REFRACTION
                                ref.blockId == 99
                            #else
                                ref.blockId == 10100
                            #endif
                        ) {
                            if (nextDir == vec3(0.0)) {
                                refractRay.origin = hitPos + ref.normal * 0.005;
                                refractRay.direction = reflect(refractRay.direction, ref.normal);
                            } else {
                                refractRay.origin = hitPos - ref.normal * 0.005;
                                refractRay.direction = nextDir;
                                throughput *= mix(vec3(1.0), ref.albedo.rgb, GLASS_OPACITY);
                                medium = !medium;
                            }
                        } else {
//
                            vec2 dither = blueNoise(vec2(texel)).rg;
                            // IrCache data
                            IrradianceSum r;
                            #if SMOOTH_IRCACHE == 1 || SMOOTH_IRCACHE == 2
                                r = irradianceCacheSmooth(hitPos, ref.normal, 0u, dither);
                            #else
                                r = irradianceCache(hitPos, ref.normal, 0u);
                            #endif
                            // Per Pixel Shadows
                            #ifdef REFLECTION_PER_PIXEL_SHADOWS
                                if (dot(ref.normal, shadowDir) > -0.0001) {
                                    // Трассируем тень
                                    vec3 shadowRayDir = sampleSunDir(shadowDir, dither);
                                    r.directIrradiance = TraceShadowRay(Ray(hitPos, shadowRayDir), SHADOW_MAX_RT_DISTANCE, true).rgb;
                                }
                            #endif

                            refractedRadiance += throughput * (
                                (ref.sssAmount > 0.005 ? 0.01 * ref.sssAmount * subsurfaceScattering(hitPos, ref.albedo.rgb, dot(shadowDir, refractRay.direction), dither) : vec3(0.0)) +
                                ref.albedo.rgb * ref.emission + 
                                ref.albedo.rgb * r.diffuseIrradiance + 
                                lightTransmittance(shadowDir) * shadowLightBrightness * r.directIrradiance * evalCookBRDF(normalize(shadowDir + ref.normal * 0.03125), refractRay.direction, ref.roughness, ref.normal, ref.albedo.rgb, ref.F0)
                            );
                            break;
//
                        }
                    } else {
                        refractedRadiance += throughput * sampleSkyView(refractRay.direction);
                        break;
                    }
                }
            }
        } else {
            refractedRadiance = color.rgb;
            refractionDist = rayDist;
        }
    #else
        vec3 refractedRadiance = color.rgb;
        float refractionDist = rayDist;
    #endif

    vec3 transmittance;

    if (mat.blockId == 10100) transmittance = waterTransmittance(min(8.0, waterOpticalDepth));
    else transmittance = mix(vec3(1.0), mat.albedo.rgb, GLASS_OPACITY);

    refractedRadiance *= transmittance;

    if (isEyeInWater == 1) {
        vec3 viewTransmittance = waterTransmittance(distance(rayPos, screenToPlayerPos(vec3(uv, 0.0)).xyz));

        reflectedRadiance *= viewTransmittance;
        refractedRadiance *= viewTransmittance;
    }

    vec3 fresnel = schlickFresnel(vec3(mat.blockId == 10100 ? WATER_REFLECTANCE : GLASS_REFLECTANCE), -dot(rayDir, mat.normal));
    
    vec3 reflectedFresnelRadiance = reflectedRadiance * fresnel;
    vec3 refractedFresnelRadiance = refractedRadiance * (1.0 - fresnel);

    float w1 = luminance(reflectedFresnelRadiance);
    float w2 = luminance(refractedFresnelRadiance);

    imageStore(colorimg13, texel, vec4(playerToScreenPos(rayPos.xyz + rayDir * ((rt.dist * w1 + refractionDist * w2) / (w1 + w2))).z, 0.0, 0.0, 1.0));
    imageStore(colorimg7, texel, vec4(EXPONENT_BIAS * (
        water ? (tir ? reflectedRadiance : refractedRadiance) : (reflectedFresnelRadiance + refractedFresnelRadiance)
    ), 1.0));
}

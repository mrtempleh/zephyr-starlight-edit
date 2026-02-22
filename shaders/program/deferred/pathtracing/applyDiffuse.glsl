#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/spaceConversion.glsl"
#include "/include/atmosphere.glsl"
#include "/include/brdf.glsl"
#include "/include/wave.glsl"
#include "/include/raytracing.glsl"
#include "/include/ircache.glsl"
#include "/include/text.glsl"

#ifdef DIFFUSE_HALF_RES
    #define INDIRECT_LIGHTING_RES 2
#else
    #define INDIRECT_LIGHTING_RES 1
#endif

#include "/include/textureSampling.glsl"

/* RENDERTARGETS: 7 */
layout (location = 0) out vec4 color;

void main ()
{   
    ivec2 texel = ivec2(gl_FragCoord.xy);
    float depth = texelFetch(depthtex1, texel, 0).r;
    
    color = vec4(0.0);

    if (depth == 1.0) return;

    vec2 uv = internalTexelSize * gl_FragCoord.xy;

    vec3 currPos = screenToPlayerPos(vec3(uv, depth)).xyz;
    DeferredMaterial mat = unpackMaterialData(texel);

    vec3 diffuseIrradiance = upsampleRadiance(currPos, mat.geoNormal, mat.textureNormal);

    #ifdef DEBUG_IRCACHE
        if (!hideGUI) diffuseIrradiance = irradianceCacheSilent(currPos, mat.geoNormal).diffuseIrradiance;
    #endif

    #ifdef WATER_REFLECTED_CAUSTICS
        Ray ray = Ray(currPos, vec3(shadowDir.x, -shadowDir.y, shadowDir.z));
        
        if (dot(ray.direction, mat.geoNormal) > -0.0001) {
            RayHitInfo rt = TraceGenericRay(ray, 1024.0, true, false);
            vec3 hitPos = ray.origin + ray.direction * rt.dist + rt.normal * 0.001;

            if (rt.blockId == 10100) {
                diffuseIrradiance += shadowLightBrightness * schlickFresnel(vec3(WATER_REFLECTANCE), shadowDir.y) * TraceShadowRay(Ray(hitPos, shadowDir), SHADOW_MAX_RT_DISTANCE, true) * calcWaterCaustics(hitPos, ray.direction, rt.dist) * lightTransmittance(shadowDir) * evalCookBRDF(
                    normalize(ray.direction + mat.geoNormal * 0.03125), 
                    normalize(currPos), 
                    mat.roughness, 
                    mat.textureNormal, 
                    mat.albedo.rgb, 
                    mat.F0
                ) / max(mat.albedo.rgb, vec3(0.0001));
            }
        }
    #endif

    if (mat.roughness <= REFLECTION_ROUGHNESS_THRESHOLD) diffuseIrradiance *= 1.0 - schlickFresnel(mat.F0, dot(mat.textureNormal, normalize(screenToPlayerPos(vec3(uv, 0.0)).xyz - currPos)));

    color.rgb = EXPONENT_BIAS * mat.albedo.rgb * diffuseIrradiance;
}
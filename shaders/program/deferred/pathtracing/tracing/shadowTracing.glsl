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
#include "/include/spaceConversion.glsl"

layout (rgba16f) uniform image2D colorimg2;
layout (local_size_x = 8, local_size_y = 4) in;

#ifdef SHADOW_HALF_RES
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
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    uint state = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * uint(internalScreenSize.x) + uint(internalScreenSize.x) * uint(internalScreenSize.y) * (frameCounter & 1023u);

    #ifdef SHADOW_HALF_RES
        ivec2 offsetCoord = 2 * texel + checker2x2(frameCounter);
    #else
        ivec2 offsetCoord = texel;
    #endif

    float depth = texelFetch(depthtex1, offsetCoord, 0).x;

    if (depth == 1.0) {
        imageStore(colorimg2, texel, vec4(0.0, 0.0, 0.0, 1.0));
        return;
    }

    DeferredMaterial mat = unpackMaterialData(offsetCoord);

    if (dot(mat.geoNormal, shadowDir) > -0.0001) {
        vec2 uv = internalTexelSize * (vec2(offsetCoord) + 0.5);
        
        Ray shadowRay;
        shadowRay.origin = screenToPlayerPos(vec3(uv, depth)).xyz + mat.geoNormal * 0.005;

        if (mat.isHand) {
            shadowRay.origin += 0.5 * playerLookVector;
        }

        vec3 shadowMask = vec3(0.0);

        for (int i = 0; i < SHADOW_SAMPLES; i++) {
            shadowRay.direction = sampleSunDir(shadowDir, 
                #if NOISE_METHOD == 1
                    vec2(heitzSample(texel, frameCounter, 2 * i), heitzSample(texel, frameCounter, 2 * i + 1))
                #else
                    vec2(randomValue(state), randomValue(state))
                #endif
            );
            
            shadowMask += TraceShadowRay(shadowRay, SHADOW_MAX_RT_DISTANCE, true).rgb;
        }

        imageStore(colorimg2, texel, vec4(shadowMask * rcp(SHADOW_SAMPLES), 1.0));
    } else imageStore(colorimg2, texel, vec4(0.0, 0.0, 0.0, 1.0));
}
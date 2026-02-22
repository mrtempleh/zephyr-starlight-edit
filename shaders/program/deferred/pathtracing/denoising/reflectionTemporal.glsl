#include "/include/uniforms.glsl"
#include "/include/checker.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/spaceConversion.glsl"
#include "/include/text.glsl"

#define INDIRECT_LIGHTING_RES 1

#include "/include/textureSampling.glsl"

/* RENDERTARGETS: 4,13 */
layout (location = 0) out vec4 filteredData;
layout (location = 1) out vec4 reflectionDepth;

void main ()
{   
    ivec2 texel = ivec2(gl_FragCoord.xy);

    #ifdef REFLECTION_HALF_RES
        ivec2 srcTexel = texel >> 1;
        ivec2 dstTexel = 2 * srcTexel + checker2x2(frameCounter);
    #else
        ivec2 srcTexel = texel;
    #endif

    vec2 uv = internalTexelSize * gl_FragCoord.xy;

    float depth = texelFetch(depthtex1, texel, 0).r;

    filteredData = texelFetch(colortex2, srcTexel, 0);
    reflectionDepth = vec4(depth, 0.0, 0.0, 1.0);

    if (depth == 1.0) return;

    DeferredMaterial mat = unpackMaterialData(texel);
    
    if (mat.roughness > REFLECTION_ROUGHNESS_THRESHOLD) return;

    float prefilterAmount = smoothstep(0.003, 0.008, mat.roughness);

    vec4 playerPos = screenToPlayerPos(vec3(uv, depth));
    vec3 virtualPos = playerPos.xyz + normalize(playerPos.xyz - screenToPlayerPos(vec3(uv, 0.0)).xyz) * filteredData.w;

    vec3 colorMin; vec3 colorMax;

    if (mat.roughness < 0.006) {
        colorMin = filteredData.rgb; colorMax = filteredData.rgb;

        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                if (abs(x) == -abs(y)) continue;

                vec3 sampleData = texelFetch(colortex2, srcTexel + ivec2(x, y), 0).rgb;

                colorMin = min(sampleData, colorMin);
                colorMax = max(sampleData, colorMax);
            }
        }
    }

    vec4 prevUv = projectAndDivide(gbufferPreviousModelViewProjection, virtualPos + cameraVelocity);

    prevUv.xy = (prevUv.xy + mix(taaOffset, taaOffsetPrev, prefilterAmount)) * 0.5 + 0.5;

    vec4 lastFrame;

    if (floor(prevUv.xy) == vec2(0.0) && prevUv.w > 0.0)
    {   
        lastFrame = sampleHistory(colortex4, playerPos.xyz, 
            #ifdef TEMPORAL_NORMAL_TOLERANCE
                mat.textureNormal,
            #else
                mat.geoNormal,
            #endif
        prevUv.xy, internalScreenSize);
    }
    else
    {
        lastFrame = vec4(0.0, 0.0, 0.0, 1.0);
    }

    if (any(isnan(lastFrame))) lastFrame = vec4(0.0, 0.0, 0.0, 1.0);

    float blendWeight = mix(1.0, rcp(max(1.0, lastFrame.w)),
        exp((prefilterAmount - 1.0) * (1.0 - (1.0 - 2.0 * abs(fract(prevUv.x * internalScreenSize.x) - 0.5)) * (1.0 - 2.0 * abs(fract(prevUv.y * internalScreenSize.y) - 0.5))))
    );

    #ifdef REFLECTION_HALF_RES
        bool isUnderSample = dstTexel != texel;
    #else
        bool isUnderSample = false;
    #endif

    if (isUnderSample && lastFrame.w > 1.0) blendWeight *= 0.0005;

    filteredData.rgb = mix(
        mat.roughness < 0.006 ? clamp(lastFrame.rgb, colorMin, colorMax) : lastFrame.rgb, 
        filteredData.rgb, 
        blendWeight
    );

    filteredData.w = min(lastFrame.w + (isUnderSample ? 0.0005 : 1.0), PT_REFLECTION_ACCUMULATION_LIMIT);

    reflectionDepth.x = playerToScreenPos(mix(virtualPos.xyz, playerPos.xyz, smoothstep(0.002, 0.007, mat.roughness))).z;
}
#define INDIRECT_LIGHTING_RES 1

#include "/include/uniforms.glsl"
#include "/include/checker.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/spaceConversion.glsl"
#include "/include/textureSampling.glsl"

#include "/include/text.glsl"

/* RENDERTARGETS: 5 */
layout (location = 0) out vec4 filteredData;

void main ()
{   
    ivec2 texel = ivec2(gl_FragCoord.xy);

    #ifdef SHADOW_HALF_RES
        ivec2 srcTexel = texel >> 1;
        ivec2 dstTexel = 2 * srcTexel + checker2x2(frameCounter);
    #else
        ivec2 srcTexel = texel;
    #endif

    vec2 uv = internalTexelSize * gl_FragCoord.xy;

    float depth = texelFetch(depthtex1, texel, 0).r;
    filteredData = texelFetch(colortex2, srcTexel, 0);

    if (depth == 1.0) return;

    #ifndef SHADOW_SKIP_CLIPPING
        vec3 shadowMin = filteredData.rgb; vec3 shadowMax = filteredData.rgb;

        for (int x = -2; x <= 2; x++) {
            for (int y = -2; y <= 2; y++) {
                if (abs(x) == -abs(y)) continue;

                vec3 sampleData = texelFetch(colortex2, srcTexel + ivec2(x, y), 0).rgb;

                shadowMin = min(sampleData, shadowMin);
                shadowMax = max(sampleData, shadowMax);
            }
        }
    #endif

    vec4 playerPos = screenToPlayerPos(vec3(uv, depth));
    vec4 normalData = unpackExp4x8(texelFetch(colortex9, texel, 0).x);

    #if defined TEMPORAL_NORMAL_TOLERANCE || !defined NORMAL_MAPPING
        vec3 normal = octDecode(normalData.zw);
    #else
        vec3 normal = octDecode(normalData.xy);
    #endif

    vec4 prevUv = projectAndDivide(gbufferPreviousModelViewProjection, playerPos.xyz + cameraVelocity);
        
    prevUv.xy += taaOffset;
    prevUv.xyz = prevUv.xyz * 0.5 + 0.5;

    vec4 lastFrame;

    if (floor(prevUv.xy) == vec2(0.0) && prevUv.w > 0.0)
    {   
        lastFrame = sampleHistory(colortex5, playerPos.xyz, normal, prevUv.xy, internalScreenSize);
    }
    else
    {
        lastFrame = vec4(0.0, 0.0, 0.0, 1.0);
    }

    if (any(isnan(lastFrame))) lastFrame = vec4(0.0, 0.0, 0.0, 1.0);

    float blendWeight = mix(1.0, rcp(lastFrame.w),
        exp(-0.5 * (1.0 - (1.0 - 2.0 * abs(fract(prevUv.x * internalScreenSize.x) - 0.5)) * (1.0 - 2.0 * abs(fract(prevUv.y * internalScreenSize.y) - 0.5))))
    );

    #ifdef SHADOW_HALF_RES
        bool isUnderSample = dstTexel != texel;
    #else
        bool isUnderSample = false;
    #endif

    if (isUnderSample && lastFrame.w > 1.0) blendWeight *= 0.0005;

    filteredData.rgb = mix(
        #ifdef SHADOW_SKIP_CLIPPING
            lastFrame.rgb,
        #else
            clamp(lastFrame.rgb, shadowMin, shadowMax), 
        #endif
        filteredData.rgb, 
        blendWeight
    );

    filteredData.w = min(lastFrame.w + (isUnderSample ? 0.0005 : 1.0), PT_SHADOW_ACCUMULATION_LIMIT);
}
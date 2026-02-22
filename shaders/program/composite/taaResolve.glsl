#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/checker.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureSampling.glsl"
#include "/include/spaceConversion.glsl"

#include "/include/text.glsl"

/* RENDERTARGETS: 6 */
layout (location = 0) out vec4 history;

void main ()
{   
    ivec2 texel = ivec2(gl_FragCoord.xy);

    #if TAA_UPSCALING_FACTOR < 100 
        ivec2 srcTexel = ivec2(TAAU_RENDER_SCALE * gl_FragCoord.xy);
        ivec2 dstTexel = ivec2((vec2(srcTexel) - internalScreenSize * taaOffset * 0.5 + 0.5) / TAAU_RENDER_SCALE);
    #else
        ivec2 srcTexel = texel;
        ivec2 dstTexel = srcTexel;
    #endif

    vec4 currData = texelFetch(colortex7, srcTexel, 0) / EXPONENT_BIAS;
    vec2 uv = texelSize * gl_FragCoord.xy;

    float depth = texelFetch(
        #ifdef TAA_REFLECTION_DEPTH
            colortex13, 
        #else
            depthtex0,
        #endif
    srcTexel, 0).r;

    for (int i = 0; i < 4; i++) {
        depth = min(depth, texelFetch(
            #ifdef TAA_REFLECTION_DEPTH
                colortex13, 
            #else
                depthtex0,
            #endif
        clamp(srcTexel + 2 * ivec2(i & 1, i >> 1) - 1, ivec2(0), ivec2(internalScreenSize) - 1), 0).r);
    }

    vec4 currPos = screenToPlayerPos(vec3(uv, depth));
    vec4 prevPos = projectAndDivide(gbufferPreviousModelViewProjection, depth == 1.0 ? currPos.xyz : (currPos.xyz + cameraVelocity));

    vec3 prevUv = (prevPos.xyz + vec3(taaOffset, 0.0)) * 0.5 + 0.5;

    if (saturate(prevUv.xyz) == prevUv.xyz && prevPos.w > 0.0) 
    {
        vec4 prevData = texture(colortex6, prevUv.xy);
        vec3 colorMin = vec3(INFINITY);
        vec3 colorMax = vec3(-INFINITY);

        for (int x = -1; x <= 1; x++) 
			for (int y = -1; y <= 1; y++) {
                vec3 sampleData = texelFetch(colortex7, clamp(srcTexel + ivec2(x, y), ivec2(0), ivec2(internalScreenSize) - 1), 0).rgb / EXPONENT_BIAS;

				colorMin = min(colorMin, sampleData);
				colorMax = max(colorMax, sampleData);
            }

        if (!any(isnan(prevData)))
        {   
            #if TAA_UPSCALING_FACTOR < 100
                bool isUnderSample = dstTexel != texel;
            #else
                bool isUnderSample = false;
            #endif

            float blendWeight = mix(1.0, rcp(max(prevData.a, 1.0)),
                exp(-(
                      16.0 * TAA_VARIANCE_WEIGHT * length(clamp(prevData.rgb, colorMin, colorMax) - prevData.rgb)
                    + TAA_OFFCENTER_WEIGHT * (1.0 - (1.0 - 2.0 * abs(fract(prevUv.x * screenSize.x) - 0.5)) * (1.0 - 2.0 * abs(fract(prevUv.y * screenSize.y) - 0.5)))
                ))
            );

            #if TAA_UPSCALING_FACTOR < 100
                if (isUnderSample && prevData.a > 1.0) blendWeight *= 0.0005;
            #endif

            // Log weighting from https://www.elopezr.com/temporal-aa-and-the-quest-for-the-holy-trail/
            currData.rgb = exp(mix(
                log(clamp(prevData.rgb, colorMin, colorMax) + 0.0001), 
                log(currData.rgb + 0.0001), 
                blendWeight)
            ) - 0.0001;

            history = vec4(currData.rgb, min(prevData.a + (isUnderSample ? 0.0005 : 1.0), rcp(TAA_BLEND_WEIGHT)));
        } else history = vec4(currData.rgb, rcp(TAA_BLEND_WEIGHT));
    } else history = vec4(currData.rgb, 1.0);
}
#include "/include/uniforms.glsl"
#include "/include/checker.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/wave.glsl"
#include "/include/raytracing.glsl"
#include "/include/textureData.glsl"
#include "/include/brdf.glsl"
#include "/include/text.glsl"
#include "/include/ircache.glsl"
#include "/include/atmosphere.glsl"
#include "/include/spaceConversion.glsl"
#include "/include/textureSampling.glsl"
#include "/include/shadowMapping.glsl"

layout (location = 0) out vec4 color;

vec3 tonemap (vec3 color, float exposure) 
{
    return pow(1.0 - exp(-exposure * color.rgb), vec3(1.0 / 2.2));
}

void main ()
{   
    //DeferredMaterial mat = unpackMaterialData(ivec2(gl_FragCoord.xy));

    #ifdef DEBUG_VOXELIZATION
        color.rgb = pow(TraceGenericRay(Ray(vec3(0.0), normalize(screenToPlayerPos(vec3(gl_FragCoord.xy * texelSize, 1.0)).xyz)), 1024.0, true, true).albedo.rgb, vec3(1.0 / 2.2));
        color.a = 1.0;
    #else
        ivec2 texel = ivec2(gl_FragCoord.xy);

        color = texelFetch(colortex10, texel, 0);

        vec4 sharpen = vec4(0.0);

        for (int x = -1; x <= 1; x++) {
            for (int y = -1; y <= 1; y++) {
                float sampleWeight = exp(-length(vec2(x, y)));

                sharpen += vec4(sampleWeight * texelFetch(colortex10, texel + ivec2(x, y), 0).rgb, sampleWeight);
            }
        }

        #ifdef DYNAMIC_EXPOSURE
            float exposure = BRIGHTNESS * 8.0 * exp(0.005 / renderState.globalLuminance);
        #else
            float exposure = BRIGHTNESS * MANUAL_EXPOSURE;
        #endif

        color.rgb = mix(tonemap(color.rgb, exposure), tonemap(sharpen.rgb, exposure / sharpen.w), -SHARPENING) + blueNoise(gl_FragCoord.xy) * rcp(255.0) - rcp(510.0);
        color.a = 1.0;
    #endif

    //vec3 playerPos = screenToPlayerPos(vec3(internalTexelSize * gl_FragCoord.xy, texelFetch(depthtex1, ivec2(gl_FragCoord.xy), 0).r)).xyz;

    //color.rgb = vec3(textureShadow(playerToShadowViewPos(playerPos).xy));

    #ifdef ENABLE_TEXT_RENDERING
        #define FONT_SIZE 2 // [1 2 3 4 5 6 7 8]
        
        beginText(ivec2(gl_FragCoord.xy / FONT_SIZE), ivec2(20, screenSize.y / FONT_SIZE - 20));
        text.fgCol = vec4(vec3(1.0), 1.0);
        text.bgCol = vec4(vec3(0.0), 0.0);
        
        printVec3(vec3(halfVoxelVolumeSize));
        
        endText(color.rgb);
    #endif
}
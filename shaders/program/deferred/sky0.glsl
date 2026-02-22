#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureSampling.glsl"
#include "/include/brdf.glsl"
#include "/include/spaceConversion.glsl"

#define SCATTER_POINTS 64

#include "/include/atmosphere.glsl"

layout (r11f_g11f_b10f) uniform image2D colorimg11;
layout (local_size_x = 8, local_size_y = 8) in;

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

void main ()
{   
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);

    #ifdef DIMENSION_OVERWORLD
        bool sky = false;

        for (int x = 0; x < 4; x++) {
            sky = sky || texelFetch(depthtex1, 4 * texel + 3 * ivec2(x & 1, x >> 1), 0).r == 1.0;

            if (sky) break;
        }

        if (!sky) {
            imageStore(colorimg11, texel, vec4(0.0));
            return;
        }

        vec2 uv = 4.0 * internalTexelSize * (texel + 0.5);

        imageStore(colorimg11, texel, vec4(EXPONENT_BIAS * evalScattering(vec3(0.0, planetRadius + eyeAltitude + ALTITUDE_BIAS, 0.0), normalize(screenToPlayerPos(vec3(uv, 1.0)).xyz - screenToPlayerPos(vec3(uv, 0.0)).xyz), sunDir, 0.499), 1.0));
    #else
        imageStore(colorimg11, texel, vec4(0.0, 0.0, 0.0, 1.0));
    #endif
}
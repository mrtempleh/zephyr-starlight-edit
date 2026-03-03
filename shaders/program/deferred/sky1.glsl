#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureSampling.glsl"
#include "/include/brdf.glsl"
#include "/include/spaceConversion.glsl"

/* RENDERTARGETS: 7 */
layout (location = 0) out vec4 color;

void main ()
{   
    ivec2 texel = ivec2(gl_FragCoord.xy);
    float depth = texelFetch(depthtex1, texel, 0).r;
    
    if (depth != 1.0) {
        color = texelFetch(colortex7, texel, 0);
    } else {
        color = texture(colortex11, internalTexelSize * gl_FragCoord.xy);
        color.rgb += EXPONENT_BIAS * pow(texelFetch(colortex10, texel, 0).rgb, vec3(2.2));
    }
}
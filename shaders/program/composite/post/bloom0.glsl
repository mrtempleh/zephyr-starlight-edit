#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"

const bool colortex10MipmapEnabled = true;

/* RENDERTARGETS: 12 */
layout (location = 0) out vec4 color;

void main ()
{   
    int tileIndex = int(floatBitsToUint(texelSize.x * gl_FragCoord.x) >> 23) - 127;
	color = texelFetch(colortex10, ivec2(gl_FragCoord.xy - uintBitsToFloat((tileIndex + 127) << 23) * screenSize), -tileIndex);
}
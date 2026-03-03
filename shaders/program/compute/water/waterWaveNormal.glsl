#include "/include/uniforms.glsl"
#include "/include/checker.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/octree.glsl"
#include "/include/textureData.glsl"
#include "/include/brdf.glsl"
#include "/include/atmosphere.glsl"
#include "/include/wave.glsl"

layout (local_size_x = 8, local_size_y = 8) in;
const ivec3 workGroups = ivec3(64, 64, 1);

void main ()
{
    vec2 pos = rcp(8.0) * vec2(gl_GlobalInvocationID.xy) - 32.0;    

    vec2 result = calcWaterNormal(vec3(pos.x, 0.0, pos.y)).xy;

    imageStore(imgWaterNormal, ivec2(gl_GlobalInvocationID.xy), vec4(any(greaterThan(abs(result), vec2(1.0))) ? vec2(0.0) : result, 0.0, 1.0));
}
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
#include "/include/sampling.glsl"

#define SCATTER_POINTS 32

#include "/include/atmosphere.glsl"

layout (local_size_x = 8, local_size_y = 8) in;
const ivec3 workGroups = ivec3(4, 4, 1);

void main ()
{   
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    uint state = gl_GlobalInvocationID.x + 128u * gl_GlobalInvocationID.y + 128u * 128u * (frameCounter & 65535u);

    vec2 uv = (vec2(gl_GlobalInvocationID.xy) + vec2(randomValue(state), randomValue(state))) * rcp(32.0);

    vec3 rayPos = vec3(0.0, planetRadius + atmosphereHeight * lift(uv.x, -2.0), 0.0);

    float lightDot = lift(uv.y * 2.0 - 1.0, -1.5);
    vec3 lightDir = vec3(sqrt(1.0 - lightDot * lightDot), lightDot, 0.0);

    vec3 prevData = imageLoad(imgMultiScatter, texel).rgb;
    vec3 currData = 4.0 * PI * evalScattering(rayPos, randomDir(state), lightDir, 0.5);
    
    if (any(isnan(currData))) currData = vec3(0.0);

    imageStore(imgMultiScatter, texel, vec4(mix(prevData, currData, rcp(min(frameCounter, 256))), 1.0));
}
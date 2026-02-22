#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureSampling.glsl"
#include "/include/brdf.glsl"
#include "/include/spaceConversion.glsl"
#include "/include/wave.glsl"
#include "/include/raytracing.glsl"
#include "/include/shadowMapping.glsl"

layout (local_size_x = 8, local_size_y = 8) in;
const ivec3 workGroups = ivec3(64, 64, 1);

void main ()
{   
    ivec2 texel = ivec2(gl_GlobalInvocationID.xy);
    
    vec2 uv = fract(gl_GlobalInvocationID.xy * rcp(256.0) + rcp(512.0));
    uint cascade = (texel.x >> 8u) + 2 * (texel.y >> 8u);

    vec3 shadowViewPos = vec3((uv * 2.0 - 1.0) * exp2(float(cascade) + 4.0), SHADOW_MAX_RT_DISTANCE);

    RayHitInfo rt = TraceGenericRay(Ray(shadowViewToPlayerPos(vec4(shadowViewPos, 1.0)), -shadowDir), 2.0 * SHADOW_MAX_RT_DISTANCE, false, false);

    imageStore(imgShadowTex, texel, vec4(rt.dist * rcp(2.0 * SHADOW_MAX_RT_DISTANCE), 0.0, 0.0, 1.0));
}
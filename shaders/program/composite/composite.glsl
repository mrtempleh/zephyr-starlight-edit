#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureSampling.glsl"
#include "/include/brdf.glsl"
#include "/include/spaceConversion.glsl"
#include "/include/shadowMapping.glsl"
#include "/include/atmosphere.glsl"
#include "/include/subsurfaceScattering.glsl"
#include "/include/atmosphere.glsl"

/* RENDERTARGETS: 7 */
layout (location = 0) out vec4 color;

float fogDensityAtPoint (vec3 playerPos)
{
    return VL_DENSITY * pow(texture(texWorley, fract(rcp(128.0) * (cameraMod256 + playerPos))).r, 4.0) * exp(-0.15 * max0(eyeAltitude + playerPos.y - 64.0));
}

void main ()
{   
    ivec2 texel = ivec2(gl_FragCoord.xy);
    float depth0 = texelFetch(depthtex0, texel, 0).r;
    float depth1 = texelFetch(depthtex1, texel, 0).r;
    
    color = texelFetch(colortex7, texel, 0);

    DeferredMaterial mat = unpackMaterialData(texel);

    vec2 uv = internalTexelSize * gl_FragCoord.xy;
    vec3 playerPos = screenToPlayerPos(vec3(uv, depth0)).xyz;
    vec3 viewOrigin = screenToPlayerPos(vec3(uv, 0.0)).xyz;
    vec3 viewDir = playerPos - viewOrigin;

    vec2 dither = blueNoise(gl_FragCoord.xy).xy;

    float sqrViewLength = dot(viewDir, viewDir);
    float invViewLength = inversesqrt(sqrViewLength);

    float mu = invViewLength * dot(viewDir, shadowDir);

    if (mat.sssAmount > 0.0 && depth0 < 1.0 && depth1 == depth0) color.rgb += mat.sssAmount * subsurfaceScattering(playerPos, mat.albedo.rgb, mu, dither);
    
    #ifdef VL_ENABLED
        float stepSize = rcp(VL_STEP_COUNT) * min(VL_DISTANCE, sqrViewLength * invViewLength);

        vec3 rayStep = viewDir * invViewLength * stepSize;
        vec3 rayPos  = viewOrigin + rayStep * dither.x;

        vec3 shadowRayPos  = playerToShadowViewPos(vec4(rayPos, 1.0));

        mat3 shadowViewMatrix = tbnNormal(shadowDir);

        vec3 shadowRayStep = rayStep * shadowViewMatrix;
        vec3 shadowViewNormal = depth1 == 1.0 ? vec3(0.0) : (mat.geoNormal * shadowViewMatrix);

        float viewOpticalDepth = 0.0;

        vec3 sunlightFactor = shadowLightBrightness * lightTransmittance(shadowDir) * mix(VL_INTENSITY, VL_INTENSITY_DAY, smoothstep(0.1, 0.3, sunDir.y)) * phaseMie(mu, 0.5);
        vec3 skylight = 2.0 * smoothstep(120.0, 240.0, float(eyeBrightnessSmooth.y)) * texelFetch(texSkyView, ivec2(16, 60), 0).rgb;

        vec3 integratedData = vec3(0.0);

        for (int i = 0; i < VL_STEP_COUNT; i++, rayPos += rayStep, shadowRayPos += shadowRayStep) {
            float sampleDensity = stepSize * fogDensityAtPoint(rayPos);

            viewOpticalDepth += sampleDensity;

            if (i == 0) viewOpticalDepth *= dither.x;

            vec3 sunlight = sunlightFactor * step(textureShadow((shadowRayPos + shadowViewNormal * max0(0.1 - dot(mat.geoNormal, rayPos - playerPos))).xy), shadowRayPos.z);

            integratedData += exp(-viewOpticalDepth) * sampleDensity * (sunlight + skylight);
        }

        color.rgb += integratedData;
    #endif
}
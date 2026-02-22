#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/atmosphere.glsl"

#ifdef fsh

in VSOUT 
{
    vec2 texcoord;
    vec3 vertexColor;
    vec3 vertexPosition;
} vsout;

/* RENDERTARGETS: 10 */
layout (location = 0) out vec4 albedo;

void main ()
{
    #if TAA_UPSCALING_FACTOR < 100
        if (any(greaterThan(gl_FragCoord.xy + 0.5, internalScreenSize))) {
            return;
        }
    #endif

    albedo = texture(gtexture, vsout.texcoord);

    if (renderStage == MC_RENDER_STAGE_MOON) albedo.rgb = vec3(luminance(albedo.rgb));

    albedo *= vec4(vsout.vertexColor, 1.0);
    albedo.rgb *= renderStage == MC_RENDER_STAGE_MOON ? (MOON_BRIGHNTESS * lightTransmittance(normalize(vsout.vertexPosition))) : vec3(3.0);

    if (albedo.a < 0.1) discard;
}

#endif

#ifdef vsh

out VSOUT 
{
    vec2 texcoord;
    vec3 vertexColor;
    vec3 vertexPosition;
} vsout;

void main ()
{   
    vsout.vertexPosition = (gbufferModelViewProjectionInverse * ftransform()).xyz;
    vsout.vertexPosition.xz *= rotate(torad(-(SUN_AZIMUTH_ROTATION)));

    if (renderStage == MC_RENDER_STAGE_SUN) vsout.vertexPosition = length(vsout.vertexPosition) * mix(sunDir, normalize(vsout.vertexPosition), SUN_SIZE);

    gl_Position = gbufferModelViewProjection * vec4(vsout.vertexPosition, 1.0);

    gl_Position.xy += gl_Position.w * taaOffset;
    
    #if TAA_UPSCALING_FACTOR < 100
        gl_Position.xy = mix(-gl_Position.ww, gl_Position.xy, TAAU_RENDER_SCALE);
    #endif

    vsout.texcoord = mat4x2(gl_TextureMatrix[0]) * gl_MultiTexCoord0;
    vsout.vertexColor = gl_Color.rgb * (renderStage == MC_RENDER_STAGE_SUN ? (smoothstep(-0.04, 0.01, sunDir.y) * 0.9 + 0.1) : 1.0);
}

#endif
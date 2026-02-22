#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/common.glsl"
#include "/include/constants.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/atmosphere.glsl"

#ifdef fsh

in VSOUT 
{
    vec4 vertexColor;
} vsout;

/* RENDERTARGETS: 10 */
layout (location = 0) out vec4 colortex0Out;

void main ()
{
    #if TAA_UPSCALING_FACTOR < 100
        if (any(greaterThan(gl_FragCoord.xy + 0.5, internalScreenSize))) {
            return;
        }
    #endif

    colortex0Out = vsout.vertexColor;
}


#endif

#ifdef vsh

out VSOUT 
{
    vec4 vertexColor;
} vsout;

void main ()
{
    if (renderStage == MC_RENDER_STAGE_SKY || renderStage == MC_RENDER_STAGE_SUNSET) {
        gl_Position = vec4(-1.0);
        return;
    }

    vec3 vertexPosition = (gbufferModelViewProjectionInverse * ftransform()).xyz;
    vertexPosition.xz *= rotate(torad(-(SUN_AZIMUTH_ROTATION)));

    gl_Position = gbufferModelViewProjection * vec4(vertexPosition, 1.0);

    gl_Position.xy += gl_Position.w * taaOffset;
    
    #if TAA_UPSCALING_FACTOR < 100
        gl_Position.xy = mix(-gl_Position.ww, gl_Position.xy, TAAU_RENDER_SCALE);
    #endif

    vsout.vertexColor = gl_Color;

    if (renderStage == MC_RENDER_STAGE_STARS) vsout.vertexColor.rgb *= STAR_BRIGHTNESS * lightTransmittance(normalize(vertexPosition));
}

#endif
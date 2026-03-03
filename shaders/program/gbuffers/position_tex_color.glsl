#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"

#ifdef fsh

in VSOUT 
{
    vec2 texcoord;
    vec3 vertexColor;
    flat uint packedNormal;
} vsout;

/* RENDERTARGETS: 8,9 */
layout (location = 0) out uvec4 materialData0;
layout (location = 1) out uvec4 materialData1;

void main ()
{
    #if TAA_UPSCALING_FACTOR < 100
        if (any(greaterThan(gl_FragCoord.xy + 0.5, internalScreenSize))) {
            return;
        }
    #endif
    
    vec4 albedo = texture(gtexture, vsout.texcoord) * vec4(vsout.vertexColor, 1.0);
    uvec4 packedData = uvec4(packUnorm4x8(vec4(albedo.rgb, 0.0)), 0u, vsout.packedNormal, 0u);

    materialData0 = packedData;
    materialData1 = packedData.zwxy;

    #ifdef STAGE_BEACON_BEAM
        if (albedo.a < 0.9) discard;
    #else
        if (albedo.a < 0.1) discard;
    #endif
}

#endif

#ifdef vsh

out VSOUT 
{
    vec2 texcoord;
    vec3 vertexColor;
    flat uint packedNormal;
} vsout;

void main ()
{   
    gl_Position = ftransform();

    gl_Position.xy += gl_Position.w * taaOffset;
    
    #if TAA_UPSCALING_FACTOR < 100
        gl_Position.xy = mix(-gl_Position.ww, gl_Position.xy, TAAU_RENDER_SCALE);
    #endif

    vsout.texcoord = mat4x2(gl_TextureMatrix[0]) * gl_MultiTexCoord0;
    vsout.vertexColor = gl_Color.rgb;
    vsout.packedNormal = packExp4x8(octEncode(alignNormal(transpose(mat3(gbufferModelView)) * gl_NormalMatrix * gl_Normal, 0.01)).xyxy);
}

#endif
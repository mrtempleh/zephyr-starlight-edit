#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureData.glsl"
#include "/include/surface.glsl"
#include "/include/spaceConversion.glsl"

uniform float alphaTestRef = 0.1;

#ifdef fsh

in VSOUT
{
    vec2 texcoord;
    vec3 vertexColor;

    #if defined NORMAL_MAPPING || defined POM
        vec4 vertexTangent;
    #endif

    #ifdef POM
        vec4 texBounds;
    #endif

    flat uint vertexNormal;
    flat uint blockId;
} vsout;

/* RENDERTARGETS: 8,9 */
layout (location = 0) out uvec4 colortex8Out;
layout (location = 1) out uvec4 colortex9Out;

void main ()
{   
    #if TAA_UPSCALING_FACTOR < 100
        if (any(greaterThan(gl_FragCoord.xy + 0.5, internalScreenSize))) {
            return;
        }
    #endif

    vec2 texSize = vec2(textureSize(gtexture, 0));
    vec2 atlasTexCoord = texSize * vsout.texcoord;
    float mipLevel = max(0.0, TAA_MIP_SCALE * 0.5 * log2(max(lengthSquared(dFdx(atlasTexCoord)), lengthSquared(dFdy(atlasTexCoord)))));

    vec3 geoNormal = octDecode(unpack2x16(vsout.vertexNormal));

    if (!gl_FrontFacing) geoNormal *= -1.0;

    #if defined POM || defined NORMAL_MAPPING
        mat3 tbnMatrix = tbnNormalTangent(geoNormal, vsout.vertexTangent);

        vec2 uv = internalTexelSize * gl_FragCoord.xy;
        vec3 playerPos = screenToPlayerPos(vec3(uv, gl_FragCoord.z)).xyz;
        vec3 viewDir = playerPos - screenToPlayerPos(vec3(uv, 0.0)).xyz;
    #endif
    
    #if defined POM && defined STAGE_TERRAIN
        vec3 rayDir = viewDir * tbnMatrix;

        float lod = 0.0;

        float mipScale    = exp2(-lod);
        float invMipScale = exp2(lod);

        POMHitResult hr = tracePOM(vec3(atlasTexCoord * mipScale, 0.0), rayDir, ivec4(vsout.texBounds * mipScale + 0.5), int(lod), mipScale);
        vec2 hitUv = wrap(hr.hitPos.xy * invMipScale, vsout.texBounds) / texSize;

        vec4 albedo = textureLod(gtexture, hitUv, lod) * vec4(vsout.vertexColor, 1.0);

        #ifdef SPECULAR_MAPPING
            vec4 specularData = textureLod(specular, hitUv, 0.0);
        #else
            vec4 specularData = vec4(0.0);
        #endif
    #else
        vec4 albedo = textureLod(gtexture, vsout.texcoord, mipLevel) * vec4(vsout.vertexColor, 1.0);

        #ifdef SPECULAR_MAPPING
            vec4 specularData = textureLod(specular, vsout.texcoord, 0.0);
        #else
            vec4 specularData = vec4(0.0);
        #endif
    #endif
    
    #ifdef NORMAL_MAPPING
        #if defined POM && defined STAGE_TERRAIN
            vec3 textureNormal;

            if (hr.normal.z > 0.5) {
                textureNormal = vec3(textureLod(normals, hitUv, mipLevel).rg * 2.0 - 1.0, 1.0);
                textureNormal.xy *= step(vec2(rcp(128.0)), abs(textureNormal.xy));
                textureNormal.z = sqrt(max(0.0, 1.0 - lengthSquared(textureNormal.xy)));
            } else {
                textureNormal = hr.normal;
            }
        #else
            vec3 textureNormal = vec3(textureLod(normals, vsout.texcoord, mipLevel).rg * 2.0 - 1.0, 1.0);
            textureNormal.xy *= step(vec2(rcp(128.0)), abs(textureNormal.xy));
            textureNormal.z = sqrt(max(0.0, 1.0 - lengthSquared(textureNormal.xy)));
        #endif

        textureNormal = tbnMatrix * normalize(vec3(textureNormal.xy, max(textureNormal.z, rcp(TAA_MIP_SCALE) * mipLevel)));
    #else
        vec3 textureNormal = geoNormal;
    #endif

    #ifdef IPBR
        applyIntegratedSpecular(albedo.rgb, specularData, vsout.blockId);
    #endif

    uvec4 packedData = packMaterialData(albedo.rgb, geoNormal, textureNormal, specularData, vsout.blockId, 
        #ifdef STAGE_HAND
            true
        #else
            false
        #endif
    );

    colortex8Out = packedData;
    colortex9Out = packedData.zwxy;

    if (albedo.a < alphaTestRef) discard;
}

#endif

#ifdef vsh

attribute vec2 mc_Entity;
attribute vec4 mc_midTexCoord;
attribute vec4 at_tangent;

out VSOUT
{
    vec2 texcoord;
    vec3 vertexColor;

    #if defined NORMAL_MAPPING || defined POM
        vec4 vertexTangent;
    #endif

    #ifdef POM
        vec4 texBounds;
    #endif

    flat uint vertexNormal;
    flat uint blockId;
} vsout;

void main ()
{   
    gl_Position = ftransform();

    #if defined STAGE_HAND && HAND_FOV > 0   
        gl_Position.xy *= handScale / gl_ProjectionMatrix[1].y;
    #endif

    gl_Position.xy += gl_Position.w * taaOffset;
    
    #if TAA_UPSCALING_FACTOR < 100
        gl_Position.xy = mix(-gl_Position.ww, gl_Position.xy, TAAU_RENDER_SCALE);
    #endif

    vsout.texcoord = mat4x2(gl_TextureMatrix[0]) * gl_MultiTexCoord0;
    vsout.vertexColor = gl_Color.rgb;
    vsout.vertexNormal = pack2x16(octEncode(alignNormal(transpose(mat3(gbufferModelView)) * gl_NormalMatrix * gl_Normal, 0.008)));

    #if defined NORMAL_MAPPING || defined POM
        vsout.vertexTangent = vec4(alignNormal(mat3(gbufferModelViewInverse) * mat3(gl_ModelViewMatrix) * at_tangent.xyz, 0.025), at_tangent.w);
    #endif

    #ifdef STAGE_TERRAIN
        vsout.blockId = uint(mc_Entity.x);
    #elif defined STAGE_HAND
        vsout.blockId = uint(currentRenderedItemId);
    #elif defined STAGE_ENTITIES
        vsout.blockId = uint(currentRenderedItemId == 0 ? entityId : currentRenderedItemId);
    #elif defined STAGE_BLOCK_ENTITIES
        vsout.blockId = uint(blockEntityId);
    #endif

    #ifdef POM
        vec2 midTexCoord = mat4x2(gl_TextureMatrix[0]) * mc_midTexCoord;
        vsout.texBounds = vec4(textureSize(gtexture, 0).xyxy) * vec4(midTexCoord - abs(midTexCoord - vsout.texcoord), midTexCoord + abs(midTexCoord - vsout.texcoord));
    #endif
}

#endif


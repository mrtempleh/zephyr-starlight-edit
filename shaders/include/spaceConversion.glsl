#ifndef INCLUDE_SPACE_CONVERSION
    #define INCLUDE_SPACE_CONVERSION

    vec4 projectAndDivide (mat4 matrix, vec3 position) 
    {
        vec4 homogeneousPos = matrix * vec4(position, 1.0);
        return vec4(homogeneousPos.xyz / homogeneousPos.w, homogeneousPos.w);
    }

    vec4 screenToPlayerPos (vec3 screen)
    {
        vec4 homogeneousPos = gbufferModelViewProjectionInverse3x4 * (screen * 2.0 - 1.0 - vec3(taaOffset, 0.0)) + gbufferModelViewProjectionInverse3;
        return vec4(homogeneousPos.xyz / homogeneousPos.w, homogeneousPos.w);
    }

    vec3 playerToScreenPos (vec3 playerPos)
    {
        vec4 homogeneousPos = gbufferModelViewProjection3x4 * playerPos + gbufferModelViewProjection3;
        return homogeneousPos.w > 0.0 ? (homogeneousPos.xyz / homogeneousPos.w + vec3(taaOffset, 0.0)) * 0.5 + 0.5 : vec3(-1.0);
    }

#endif
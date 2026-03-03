#ifndef INCLUDE_SHADOW_MAPPING
    #define INCLUDE_SHADOW_MAPPING

    vec3 playerToShadowViewPos (vec4 playerPos)
    {
        mat3 shadowViewMatrix = tbnNormal(shadowDir);

        return (playerPos.xyz * shadowViewMatrix) + playerPos.w * (fract(cameraMod256 * shadowViewMatrix) - 0.5);
    }

    vec3 shadowViewToPlayerPos (vec4 shadowViewPos)
    {
        mat3 shadowViewMatrix = tbnNormal(shadowDir);

        return shadowViewMatrix * (shadowViewPos.xyz - shadowViewPos.w * (fract(cameraMod256 * shadowViewMatrix) - 0.5));
    }

    float textureShadow (vec2 shadowViewPos, uint cascade)
    {
        return SHADOW_MAX_RT_DISTANCE - 2.0 * SHADOW_MAX_RT_DISTANCE * imageLoad(imgShadowTex, ivec2(shadowViewPos * exp2(3.0 - float(cascade)) + 256.0 * vec2(cascade & 1, cascade >> 1) + 128.0)).r;
    }

    float textureShadow (vec2 shadowViewPos) 
    {
        uint cascade = uint(log2(max(abs(shadowViewPos.x), abs(shadowViewPos.y))) - 3.0);

        if (cascade > 3) return 0.0;
        else return textureShadow(shadowViewPos, cascade);
    }

#endif
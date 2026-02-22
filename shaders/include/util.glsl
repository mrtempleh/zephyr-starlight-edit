#ifndef INCLUDE_UTILITY
    #define INCLUDE_UTILITY

    vec4 gamma (vec4 color)
    {
        return vec4(pow(color.rgb, vec3(2.2)), color.a);
    }

    // https://twitter.com/Stubbesaurus/status/937994790553227264

    vec2 octEncode (in vec3 n) 
    {
        n.xyz /= abs(n.x) + abs(n.y) + abs(n.z);
        float t = max0(-n.y);
        n.x += (n.x > 0.0) ? t : -t;
        n.z += (n.z > 0.0) ? t : -t;
        return n.xz * 0.5 + 0.5;
    }

    vec3 octDecode (in vec2 f)
    {
        f = f * 2.0 - 1.0;
 
        vec3 n = vec3(f.x, 1.0 - abs(f.x) - abs(f.y), f.y);
        float t = max0(-n.y);
        n.x += n.x >= 0.0 ? -t : t;
        n.z += n.z >= 0.0 ? -t : t;
        return normalize(n);
    }

    mat3 tbnNormalTangent (vec3 normal, vec4 tangent) 
    {
        return mat3(tangent.xyz, cross(tangent.xyz, normal) * sign(tangent.w), normal);
    }

    mat3 tbnNormal (vec3 normal) 
    {
        return tbnNormalTangent(normal, vec4(normalize(cross(normal, abs(normal.y) > abs(normal.z) ? vec3(0.0, 0.0, 1.0) : vec3(0.0, 1.0, 0.0))), 1.0));
    }

    vec3 alignNormal (vec3 normal, float eps) 
    {
        return normalize(normal * vec3(greaterThan(abs(normal), vec3(eps))));
    }

    // https://discordapp.com/channels/237199950235041794/525510804494221312/1416364500591837216

    vec3 blueNoise (vec2 coord) 
    {
        return texelFetch(
            noisetex,
            ivec3(ivec2(coord) % 128, frameCounter % 64),
            0
        ).rgb;
    }

    // R2 sequence from
    // https://extremelearning.com.au/unreasonable-effectiveness-of-quasirandom-sequences/

    vec3 blueNoise (vec2 coord, int i) 
    {
        const float g = 1.324717;

        return blueNoise(coord + 128.0 * fract(0.5 + i * rcp(vec2(g, g * g))));
    }

    vec3 dither11f (vec2 coord, vec3 color)
    {
        return color + (blueNoise(coord) - 0.5) * uintBitsToFloat(floatBitsToUint(max(vec3(0.000061035156), color)) & uvec3(0xff800000u)) * vec3(0.015625, 0.015625, 0.03125);
    }

    mat2 rotate (float theta)
    {
        float cosTheta = cos(theta);
        float sinTheta = sin(theta);

        return mat2(cosTheta, -sinTheta, sinTheta, cosTheta);
    }

    // Adapted from https://www.youtube.com/watch?v=Qz0KTGYJtUk&t=674s

    uint randomInt (inout uint state)
    {
        state = state * 747796405u + 2891336453u;
        uint result = ((state >> ((state >> 28u) + 4u)) ^ state) * 277803737u;
        return (result >> 22u) ^ result;
    }

    float randomValue (inout uint state) 
    {
        return randomInt(state) * rcp(4294967296.0);
    }

#endif
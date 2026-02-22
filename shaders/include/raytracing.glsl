#ifndef INCLUDE_RAYTRACING
    #define INCLUDE_RAYTRACING

    #include "/include/octree.glsl"

    float rayBox (vec3 rayOrigin, vec3 invDir, vec3 boxMin, vec3 boxMax) 
    {
        return maxOf(min((boxMin - rayOrigin) * invDir, (boxMax - rayOrigin) * invDir));
    }

    RayHitInfo TraceGenericRay (in Ray ray, float maxDist, bool useBackFaceCulling, bool alphaBlend)
    {   
        #include "/include/rtfunc.glsl"
    }

    vec3 TraceShadowRay (in Ray ray, float maxDist, bool useBackFaceCulling)
    {   
        #define RT_SHADOW
        #include "/include/rtfunc.glsl"
    }

#endif
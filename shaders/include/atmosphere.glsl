#ifndef INCLUDE_ATMOSPHERE
    #define INCLUDE_ATMOSPHERE

    #define ALTITUDE_BIAS 512.0

    const float planetRadius = 6371000.0;
    const float atmosphereHeight = 100000.0;

    const vec2 scaleHeights = vec2(8000.0, 1250.0);
    const vec2 invScaleHeights = rcp(scaleHeights);

    const vec3 betaR = vec3(SKY_RAYLEIGH_R, SKY_RAYLEIGH_G, SKY_RAYLEIGH_B) * pow(vec3(680.0, 530.0, 440.0), vec3(-4.0)) * 1e6;
    const vec3 betaM = SKY_MIE * vec3(1e-5);
    
    const vec3 alphaR = betaR;
    const vec3 alphaM = betaM * 1.1;
    const vec3 alphaO = SKY_OZONE * vec3(1.9, 2.7, 0.1) * 1e-6;

    #ifdef SCATTER_POINTS
        const mat2x3 scattering = rcp(SCATTER_POINTS) * mat2x3(betaR, betaM);
        const mat3   absorption = rcp(SCATTER_POINTS) * mat3(alphaR, alphaM, alphaO);
    #endif

    vec2 raySphere (Ray ray, float radius) 
    {
        float d = sqr(dot(ray.origin, ray.direction)) - dot(ray.origin, ray.origin) + radius * radius;

        if (d < 0) return vec2(INFINITY);

        d = sqrt(d);

        float cosTheta = dot(ray.origin, ray.direction);
        float invDet = -rcp(dot(ray.direction, ray.direction));

        float dstNear = (cosTheta + d) * invDet;
        float dstFar  = (cosTheta - d) * invDet;

        if (dstFar < 0.0) return vec2(INFINITY);

        dstNear = max0(dstNear);

        return vec2(dstNear, dstFar - dstNear);
    }
    
    vec3 getDensityAtHeight (float height) {
        float h = height - planetRadius;

        return vec3(exp(-h * invScaleHeights), max0(min(linearStep(h, 15000.0, 25000.0), linearStep(h, 40000.0, 25000.0))));
    }

    vec3 getDensityAtPoint (vec3 pos)
    {
        return getDensityAtHeight(length(pos));
    }

    #ifndef STAGE_SETUP
        vec3 lightTransmittance (vec3 pos, vec3 lightDir) 
        {
            float sqrLength = dot(pos, pos);
            float invLength = inversesqrt(sqrLength);

            vec2 uv =  mix(vec2(rcp(64.0)), vec2(1.0 - rcp(64.0)), vec2(liftInverse((sqrLength * invLength - planetRadius) / atmosphereHeight, -4.0), liftInverse(linearStep(dot(pos, lightDir) * invLength, -sqrt(1.0 - sqr(planetRadius * invLength)), 1.0), -16.0)));

            return floor(uv) == vec2(0.0) ? sqr(texture(texTransmittance, uv).rgb) : vec3(0.0);
        }

        vec3 lightTransmittance (vec3 lightDir) 
        {
            return lightTransmittance(vec3(0.0, planetRadius + eyeAltitude + ALTITUDE_BIAS, 0.0), lightDir);
        }
        
        #ifdef SCATTER_POINTS
            float phaseRayleigh (float cosTheta)
            {
                return (1.0 + cosTheta * cosTheta) * 3.0 / (16.0 * PI);
            }

            float phaseMie (float cosTheta, float k)
            {
                return (1.0 - k * k) / (4.0 * PI * sqr(1.0 - k * cosTheta));
            }

            vec2 multiScatterEncodeUv (vec3 pos, vec3 lightDir, float rayHeight) {
                vec2 uv = vec2(rcp(atmosphereHeight) * (rayHeight - planetRadius), dot(pos, lightDir) * inversesqrt(dot(pos, pos)) * 0.5 + 0.5);

                uv.x = liftInverse(uv.x, -2.0);
                uv.y = liftInverse(uv.y * 2.0 - 1.0, -1.5) * 0.5 + 0.5;

                return uv;
            }

            mat2x3 multiScatterDecodeUv (vec2 uv) {
                vec3 rayPos = vec3(0.0, planetRadius + atmosphereHeight * lift(uv.x, -2.0), 0.0);

                float lightDot = lift(uv.y * 2.0 - 1.0, -1.5);
                vec3 lightDir = vec3(sqrt(1.0 - lightDot * lightDot), lightDot, 0.0);

                return mat2x3(rayPos, lightDir);
            }
            
            vec3 evalScattering (vec3 rayOrigin, vec3 viewDir, vec3 lightDir, float dither) 
            {
                dither = clamp(dither, 0.005, 0.995);
                
                Ray ray = Ray(rayOrigin, viewDir);

                float rayDest = min(raySphere(ray, planetRadius).x, raySphere(ray, planetRadius + atmosphereHeight).y);
                vec3 rayStep = ray.direction * rayDest * rcp(SCATTER_POINTS);
                vec3 rayPos = ray.origin + rayStep * dither;

                vec3 opticalDepth = vec3(0.0);
                vec3 radiance = vec3(0.0);

                float mu = dot(ray.direction, lightDir);

                vec2 phase = vec2(phaseRayleigh(mu), phaseMie(mu, 0.98));
                vec2 phaseIsotropic = vec2(6.0 * rcp(16.0 * PI), rcp(4.0 * PI));

                for (int i = 0; i < SCATTER_POINTS; i++, rayPos += rayStep) {
                    float rayHeight = length(rayPos);

                    vec3 density = getDensityAtHeight(rayHeight);
                    opticalDepth += density;

                    if (i == 0) opticalDepth *= dither;

                    vec3 sunlight = (raySphere(Ray(rayPos, lightDir), planetRadius).x == INFINITY ? lightTransmittance(rayPos, lightDir) : vec3(0.0));
                    
                    #ifdef SKY_MULTISCATTER
                        vec3 multiScatter = texture(texMultiScatter, multiScatterEncodeUv(rayPos, lightDir, rayHeight)).rgb;
                    #else
                        vec3 multiScatter = vec3(0.0);
                    #endif

                    radiance += exp(-rayDest * (absorption * opticalDepth)) * (sunlight * (scattering * (phase * density.xy)) + multiScatter * (scattering * (phaseIsotropic * density.xy)));
                }

                return mix(rayDest * radiance, vec3(0.03 * smoothstep(-0.05, 0.1, lightDir.y)), rainStrength * 0.7);
            }
        #endif

        vec2 skyViewEncodeUv (vec3 dir) 
        {
            return vec2(atan(dot(dir.xz, vec2(sunDir.z, -sunDir.x)), dot(dir.xz, vec2(sunDir.x, sunDir.z))) / TWO_PI + 0.5, dir.y * 0.5 + 0.5);
        }

        vec3 skyViewDecodeUv (vec2 uv) 
        {
            vec3 result = vec3(sin(uv.x * TWO_PI), uv.y * 2.0 - 1.0, cos(uv.x * TWO_PI));

            return vec3(sqrt(1.0 - result.y * result.y) * normalize(mat2(-sunDir.z, sunDir.x, -sunDir.x, -sunDir.z) * result.xz), result.y).xzy;
        }

        #ifndef STAGE_BEGIN
            vec3 sampleSkyView (vec3 dir)
            {
                return texture(texSkyView, skyViewEncodeUv(dir)).rgb;
            }
        #endif

    #endif

#endif
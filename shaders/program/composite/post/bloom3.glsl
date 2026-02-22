#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"
#include "/include/textureSampling.glsl"

/* RENDERTARGETS: 10 */
layout (location = 0) out vec4 color;

void main() {
	vec2 uv = texelSize * gl_FragCoord.xy;
	vec3 bloom = vec3(0.0);

	for (int i = 0; i < BLOOM_TILES; i++) {
		vec3 sampleData = texBicubic(colortex12, uintBitsToFloat((126 - i) << 23) * (uv + 1), screenSize).rgb;

		if (!any(isnan(sampleData))) {
			bloom += sampleData;
		}
	}
	
	color.rgb = texelFetch(colortex10, ivec2(gl_FragCoord.xy), 0).rgb + bloom * BLOOM_STRENGTH;
}
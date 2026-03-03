#include "/include/uniforms.glsl"
#include "/include/config.glsl"
#include "/include/constants.glsl"
#include "/include/common.glsl"
#include "/include/pbr.glsl"
#include "/include/main.glsl"

/* RENDERTARGETS: 12 */
layout (location = 0) out vec4 color;

const float[3] w = float[3](0.3134375, 0.189843360, 0.046349696);

void main() {
	ivec2 texel = ivec2(gl_FragCoord.xy);

	vec4 result = vec4(0.0);

	for (int x = -2; x <= 2; x++) {
		result += vec4(texelFetch(colortex12, texel + ivec2(x, 0), 0).rgb, 1.0) * w[abs(x)];
	}

	color.rgb = result.rgb / result.w;
}
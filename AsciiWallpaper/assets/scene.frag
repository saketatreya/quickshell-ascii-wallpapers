#version 440
layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;
layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec4 groundColorA;
    vec4 groundColorB;
    vec2 gridSize;
    float frameBlend;
};
layout(binding = 1) uniform sampler2D gridTextureA;
layout(binding = 2) uniform sampler2D glyphTexture;
layout(binding = 3) uniform sampler2D paletteTextureA;
layout(binding = 4) uniform sampler2D gridTextureB;
layout(binding = 5) uniform sampler2D paletteTextureB;
vec3 renderCell(vec4 data, sampler2D paletteTexture, vec3 groundColor, vec2 localCell) {
    float glyph = floor(data.r * 255.0 + 0.5);
    float colorIndex = floor(data.g * 255.0 + 0.5);
    vec2 atlasUv = (vec2(glyph, 0.0) + clamp(localCell, vec2(0.012), vec2(0.988))) / vec2(4.0, 1.0);
    float ink = texture(glyphTexture, atlasUv).a;
    vec3 color = texture(paletteTexture, vec2((colorIndex + 0.5) / 64.0, 0.5)).rgb;
    return mix(groundColor, color, ink);
}
void main() {
    vec2 cell = qt_TexCoord0 * gridSize;
    vec2 cellIndex = min(floor(cell), gridSize - 1.0);
    vec2 gridUv = (cellIndex + 0.5) / gridSize;
    vec3 a = renderCell(texture(gridTextureA, gridUv), paletteTextureA, groundColorA.rgb, fract(cell));
    vec3 b = renderCell(texture(gridTextureB, gridUv), paletteTextureB, groundColorB.rgb, fract(cell));
    fragColor = vec4(mix(a, b, frameBlend), 1.0) * qt_Opacity;
}

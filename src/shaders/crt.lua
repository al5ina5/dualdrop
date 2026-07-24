-- src/shaders/crt.lua
-- CRT Shader for LÖVE — curvature, soft scanlines, chromatic aberration (no vignette)

return [[
    extern vec2 inputRes;
    extern float time;

    // Configuration — bright CRT look (no vignette)
    const float curvature = 5.0;
    const float scanlineIntensity = 0.12;
    const float chromaticAberration = 0.001;
    const float brightness = 1.12;

    vec2 curve(vec2 uv) {
        uv = uv * 2.0 - 1.0;
        vec2 offset = abs(uv.yx) / curvature;
        uv = uv + uv * offset * offset;
        uv = uv * 0.5 + 0.5;
        return uv;
    }

    vec4 effect(vec4 color, Image texture, vec2 texture_coords, vec2 screen_coords) {
        vec2 uv = curve(texture_coords);
        
        // Check if we are outside the curved screen
        if (uv.x < 0.0 || uv.x > 1.0 || uv.y < 0.0 || uv.y > 1.0) {
            return vec4(0.0, 0.0, 0.0, 1.0);
        }

        // Chromatic Aberration
        vec4 tex;
        tex.r = Texel(texture, uv + vec2(chromaticAberration, 0.0)).r;
        tex.g = Texel(texture, uv).g;
        tex.b = Texel(texture, uv - vec2(chromaticAberration, 0.0)).b;
        tex.a = 1.0;

        // Soft scanlines
        float scanline = sin(uv.y * inputRes.y * 3.14159 * 2.0);
        scanline = (scanline + 1.0) * 0.5;
        scanline = mix(1.0, scanline, scanlineIntensity);
        tex.rgb *= scanline;

        // Lift overall brightness (replaces old vignette darkening)
        tex.rgb *= brightness;

        return tex * color;
    }
]]

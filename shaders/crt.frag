// CRT effect for the Terminal theme. A GLSL port of the Figma "CRT" effect
// (barrel curvature, line jitter, chromatic dispersion, scanlines, rolling
// refresh bar, aperture-grille mask, flicker, static, vignette).
//
// Used two ways (lib/widgets/crt.dart):
//  - as an ImageFilter over widgets: the engine provides uSize and
//    uTexture (the widgets' pixels); uImgScale = 1, uImgOffset = 0;
//  - painted directly with an image (album art) as uTexture, where
//    uImgScale/uImgOffset crop the image like BoxFit.cover.
// Parameters are documented in lib/debug/terminal_tuning.dart.
#version 460 core
#include <flutter/runtime_effect.glsl>

uniform vec2 uSize;
uniform float uCurvature;
uniform float uScan;
uniform float uMask;
uniform float uAberr;
uniform float uBright;
uniform float uScanSize;
uniform float uTime;
uniform float uFlicker;
uniform float uNoise;
uniform float uRoll;
uniform float uJitter;
uniform float uNoiseSize;
uniform float uClip;
uniform float uMaskPitch;
uniform float uVignette;
uniform float uScale;
uniform vec2 uLogical;
uniform vec2 uImgScale;
uniform vec2 uImgOffset;
uniform sampler2D uTexture;

out vec4 fragColor;

const float TAU = 6.28318530718;
const float PHASE120 = 2.09439510239;

float hash21(vec2 p) {
  vec3 h = fract(vec3(p.x, p.y, p.x) * 0.1031);
  h += dot(h, h.yzx + 33.33);
  return fract((h.x + h.y) * h.z);
}

float hash31(vec3 p) {
  vec3 h = fract(p * vec3(0.1031, 0.1030, 0.0973));
  h += vec3(dot(h, h.yzx + 33.33));
  return fract((h.x + h.y) * h.z);
}

vec2 barrel(vec2 uv, vec2 aspect, float curv, vec2 scale) {
  vec2 c = (uv * 2.0 - 1.0) * aspect;
  float r2 = dot(c, c);
  c = c * (1.0 + curv * 0.35 * r2) * scale;
  return (c / aspect) * 0.5 + 0.5;
}

vec4 samp(vec2 p) {
  p = clamp(p, vec2(0.0), vec2(1.0));
  return texture(uTexture, uImgOffset + p * uImgScale);
}

float coverage(vec2 p, vec2 texel) {
  float fx = smoothstep(0.0, texel.x, p.x) * (1.0 - smoothstep(1.0 - texel.x, 1.0, p.x));
  float fy = smoothstep(0.0, texel.y, p.y) * (1.0 - smoothstep(1.0 - texel.y, 1.0, p.y));
  return fx * fy;
}

vec3 grille(vec3 th, float pitch) {
  float a1 = smoothstep(2.0, 3.0, pitch);
  float a2 = smoothstep(2.0, 3.0, pitch * 0.5);
  return vec3(0.375) + 0.5 * a1 * cos(th) + 0.125 * a2 * cos(th * 2.0);
}

void main() {
  vec2 uv = FlutterFragCoord().xy / max(uSize, vec2(1.0));
  vec2 outDims = max(uLogical, vec2(1.0));
  vec2 pointStep = 1.0 / outDims;
  vec2 texel = pointStep / max(uScale, 1.0);
  float t = uTime;

  vec2 aspectRaw = vec2(outDims.x / outDims.y, 1.0);
  vec2 aspect = aspectRaw / (length(aspectRaw) / sqrt(2.0));

  vec2 edgeFit = vec2(
    1.0 / (1.0 + uCurvature * 0.35 * aspect.x * aspect.x),
    1.0 / (1.0 + uCurvature * 0.35 * aspect.y * aspect.y));
  float jitterReserve = clamp(uJitter, 0.0, 1.0) * 3.9 * pointStep.x;
  vec2 reserve = vec2(jitterReserve + 0.5 * texel.x, 0.5 * texel.y);
  vec2 span = max(vec2(1.0) - 2.0 * reserve, vec2(0.05));
  vec2 clipFit = edgeFit / span;
  float cornerFit = 1.0 / (1.0 + 0.7 * uCurvature);
  vec2 bscale = uClip > 0.5 ? clipFit : vec2(cornerFit);

  float scanAmt = uScan * mix(0.6, 1.0, smoothstep(1.0, 2.5, uScanSize));
  float scanNorm = 1.0 / (1.0 - scanAmt * 0.5);

  vec2 w = barrel(uv, aspect, uCurvature, bscale);

  // Line jitter / tearing.
  float lineId = floor(w.y * outDims.y / uScanSize);
  float lineNoise = hash21(vec2(lineId, floor(t * 24.0))) - 0.5;
  float drift = sin(t * 1.7 + w.y * 9.0) * 0.5;
  w.x += uJitter * (lineNoise * 0.9 + drift * 0.4) * pointStep.x * 6.0;

  float cov = uClip > 0.5 ? coverage(w, texel) : 1.0;

  // Radial chromatic dispersion.
  vec2 p = uv * 2.0 - 1.0;
  vec2 c = p * aspect;
  float radius = length(c);
  vec2 dirN = radius > 0.0001 ? c / radius : vec2(1.0, 0.0);
  float radialLevel = clamp(radius / sqrt(2.0), 0.0, 1.0);
  vec2 dir = dirN * (uAberr * (0.72 + 0.48 * radialLevel)) * pointStep;

  vec4 sr = samp(w + dir);
  vec4 sg = samp(w);
  vec4 sb = samp(w - dir);
  float sharedA = max(sr.a, max(sg.a, sb.a));
  vec3 rgb = min(vec3(sr.r, sg.g, sb.b), vec3(sharedA));
  vec4 col4 = vec4(rgb, sharedA) * cov;

  // Scanlines, slowly drifting.
  float py = w.y * outDims.y + t * 6.0;
  float scan = (1.0 - scanAmt * 0.5 * (1.0 - cos(TAU * py / uScanSize))) * scanNorm;
  col4.rgb *= scan;

  // Rolling refresh bar.
  float rollPos = fract(w.y + t * uRoll * 0.12);
  float band = smoothstep(0.0, 0.06, rollPos) * (1.0 - smoothstep(0.06, 0.22, rollPos));
  col4.rgb *= 1.0 + band * 0.35 * step(0.001, uRoll);

  vec3 col = col4.rgb;
  float alpha = col4.a;
  vec2 bw = barrel(uv, aspect, uCurvature, bscale);

  // Aperture grille, locked to the glass.
  float pitch = clamp(uMaskPitch, 2.0, 12.0);
  float th = uv.x * outDims.x * (TAU / pitch);
  vec3 prof = grille(vec3(th, th - PHASE120, th + PHASE120), pitch);
  vec3 maskGain = (vec3(0.03) + 1.8 * prof) / (0.03 + 1.8 * 0.375);
  col *= mix(vec3(1.0), maskGain, clamp(uMask, 0.0, 1.0));

  // Mains-hum flicker.
  col *= 1.0 + uFlicker * (sin(t * 37.0) * 0.5 + sin(t * 11.3) * 0.3) * 0.06;

  // Static.
  float field = floor(t * 24.0);
  float ns = max(uNoiseSize, 1.0);
  vec2 gp = floor(bw * outDims / ns);
  float white = hash31(vec3(gp, field));
  float hiss = hash21(vec2(floor(bw.y * outDims.y / ns), field * 1.7)) - 0.5;
  float staticLvl = clamp(white + hiss * 0.35, 0.0, 1.0);
  float nMix = clamp(uNoise, 0.0, 1.0) * 0.55 * alpha;
  col = mix(col, vec3(staticLvl) * alpha, nMix);
  col *= 1.0 + (white - 0.5) * uNoise * 0.25;

  // Vignette.
  vec2 cc = (bw * 2.0 - 1.0) * aspect;
  float r2 = dot(cc, cc);
  float vig = clamp(uVignette, 0.0, 1.0);
  float vigStrength = 3.0 * vig * vig * (0.35 + 0.65 * vig);
  float vigSpread = clamp(vig * vig * (0.6 + 0.4 * clamp(uCurvature, 0.0, 1.0)), 0.0, 1.0);
  float vigInner = mix(1.4, 0.0, vigSpread);
  float v = 1.0 - vigStrength * smoothstep(vigInner, 2.0, r2);
  col *= max(v, 0.0) * uBright;

  // Soft highlight knee.
  float knee = alpha * 0.8;
  float room = max(alpha - knee, 0.000001);
  vec3 excess = max(col - vec3(knee), vec3(0.0));
  vec3 compressed = vec3(knee) + vec3(room) * (vec3(1.0) - exp(-excess / vec3(room)));
  col = mix(col, compressed, step(vec3(knee), col));

  fragColor = vec4(clamp(col, vec3(0.0), vec3(alpha)), alpha);
}

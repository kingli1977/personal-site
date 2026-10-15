#ifdef GL_FRAGMENT_PRECISION_HIGH
precision highp float;
#else
precision mediump float;
#endif

uniform vec2 uResolution;
uniform float uTime;
uniform float uDepth;
uniform vec2 uMouse;
uniform float uHasPhoto;
uniform sampler2D uHorizon;

varying vec2 vUv;

float hash(vec2 p) {
  return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453123);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return mix(
    mix(hash(i), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

float fbm(vec2 p) {
  float v = 0.0;
  float a = 0.5;
  for (int i = 0; i < 5; i++) {
    v += a * noise(p);
    p = p * 2.02 + vec2(1.7, 9.2);
    a *= 0.5;
  }
  return v;
}

vec2 rot(vec2 p) {
  return vec2(p.x * 0.80 + p.y * 0.60, -p.x * 0.60 + p.y * 0.80);
}

// |sin| choppy crest. Two opposing directions are summed by the caller.
float choppy(vec2 uv, float chop) {
  vec2 wv = 1.0 - abs(sin(uv));
  vec2 swv = abs(cos(uv));
  wv = mix(wv, swv, wv);
  float crest = 1.0 - pow(clamp(wv.x * wv.y, 0.0, 1.0), 0.65);
  return pow(clamp(crest, 0.0, 1.0), chop);
}

// Four-octave opposing sine field. Rotation only — frequency doubles via `freq`.
float seaHeight(vec2 xz, float t) {
  float freq = 1.55;
  float amp = 0.18;
  float chop = 2.4;
  vec2 uv = xz;
  uv.x *= 0.82;
  float h = 0.0;
  for (int i = 0; i < 4; i++) {
    vec2 travel = vec2(t, t * 0.37);
    float d = choppy((uv + travel) * freq, chop);
    d += choppy((uv - travel * 0.78) * freq, chop);
    h += d * amp;
    uv = rot(uv);
    freq *= 1.85;
    amp *= 0.58;
    chop = mix(chop, 1.15, 0.22);
  }
  return h;
}

vec3 sunDir() {
  return normalize(vec3(-0.15, 0.19, 0.97));
}

vec3 skyGradient(vec3 rd) {
  float h = clamp(rd.y * 0.85 + 0.08, 0.0, 1.0);
  vec3 zenith = vec3(0.012, 0.02, 0.055);
  vec3 rose = vec3(0.42, 0.09, 0.08);
  vec3 horizon = vec3(0.95, 0.38, 0.12);
  vec3 col = mix(horizon, rose, smoothstep(0.0, 0.55, h));
  col = mix(col, zenith, smoothstep(0.28, 1.0, h));

  float sd = max(dot(rd, sunDir()), 0.0);
  float disk = smoothstep(0.9982, 0.9994, sd);
  float glow = pow(sd, 140.0);
  float halo = pow(sd, 12.0);
  col += vec3(1.0, 0.42, 0.12) * halo * 0.42;
  col += vec3(1.0, 0.7, 0.32) * glow;
  col = mix(col, vec3(1.0, 0.95, 0.8), disk);
  return col;
}

vec3 skyColor(vec3 rd, float t) {
  vec3 col = skyGradient(rd);

  if (uHasPhoto > 0.5) {
    float band = (1.0 - smoothstep(0.02, 0.16, abs(rd.y - 0.02)));
    band *= smoothstep(-0.08, 0.02, rd.y);
    vec2 puv = vec2(
      clamp(0.5 + rd.x * 0.7, 0.0, 1.0),
      clamp(0.55 + rd.y * 1.2, 0.35, 0.95)
    );
    vec3 photo = pow(texture2D(uHorizon, puv).rgb, vec3(2.2));
    col = mix(col, photo, band * 0.7);
  }

  vec2 cuv = rd.xz / max(rd.y + 0.55, 0.22);
  cuv += vec2(t * 0.065, t * 0.012);
  float clouds = smoothstep(0.50, 0.74, fbm(cuv * 1.05));
  float wisps = smoothstep(0.58, 0.86, fbm(cuv * 2.15 + vec2(t * 0.09, 6.0)));
  float mask = smoothstep(0.0, 0.22, rd.y) * (1.0 - smoothstep(0.72, 0.95, rd.y));
  vec3 cloudCol = mix(vec3(0.72, 0.28, 0.14), vec3(1.0, 0.72, 0.55), smoothstep(0.05, 0.5, rd.y));
  col = mix(col, cloudCol, clamp(clouds * 0.9 + wisps * 0.35, 0.0, 1.0) * mask);

  float sd = max(dot(rd, sunDir()), 0.0);
  col += vec3(1.0, 0.92, 0.75) * smoothstep(0.9982, 0.9994, sd);
  return col;
}

vec3 reflectedSky(vec3 rd, float t) {
  vec3 col = skyGradient(rd);
  vec2 cuv = rd.xz / max(rd.y + 0.5, 0.25) + vec2(t * 0.05, 1.5);
  float c = noise(cuv * 1.4);
  col = mix(col, vec3(0.95, 0.55, 0.32), smoothstep(0.5, 0.85, c) * smoothstep(0.0, 0.18, rd.y) * 0.4);
  return col;
}

vec3 seaNormal(vec2 xz, float t) {
  float e = 0.028;
  float h = seaHeight(xz, t);
  float hx = seaHeight(xz + vec2(e, 0.0), t);
  float hz = seaHeight(xz + vec2(0.0, e), t);
  vec3 n = vec3((h - hx) * 2.6, e, (h - hz) * 2.6);
  return normalize(n);
}

// Jump to the top of the wave band, then walk down to a sign change and binary-refine.
vec4 traceSea(vec3 ro, vec3 rd, float t) {
  if (rd.y > 0.02) {
    return vec4(0.0);
  }
  float prevT = 0.02;
  if (ro.y > 0.92) {
    prevT = max(0.02, (0.92 - ro.y) / rd.y);
  }
  vec3 p0 = ro + rd * prevT;
  float prevD = p0.y - seaHeight(p0.xz, t);
  if (prevD < 0.0) {
    float a = 0.0;
    float b = prevT;
    for (int j = 0; j < 6; j++) {
      float m = 0.5 * (a + b);
      vec3 pm = ro + rd * m;
      if (pm.y - seaHeight(pm.xz, t) < 0.0) b = m;
      else a = m;
    }
    float dist = max(0.5 * (a + b), 0.001);
    return vec4(ro + rd * dist, dist);
  }
  for (int i = 0; i < 8; i++) {
    float planeStep = prevD / max(0.02, -rd.y);
    float stepLen = clamp(planeStep * 0.6, 0.05, 3.2);
    float currT = prevT + stepLen;
    if (currT > 96.0) {
      return vec4(0.0);
    }
    vec3 p = ro + rd * currT;
    float d = p.y - seaHeight(p.xz, t);
    if (d < 0.0) {
      float a = prevT;
      float b = currT;
      for (int j = 0; j < 5; j++) {
        float m = 0.5 * (a + b);
        vec3 pm = ro + rd * m;
        if (pm.y - seaHeight(pm.xz, t) < 0.0) b = m;
        else a = m;
      }
      float dist = max(0.5 * (a + b), 0.001);
      return vec4(ro + rd * dist, dist);
    }
    prevT = currT;
    prevD = d;
  }
  return vec4(0.0);
}

vec3 shadeSea(vec3 p, vec3 rd, vec3 n, float dist, float t) {
  vec3 sun = sunDir();
  vec3 refl = reflect(rd, n);
  float ndv = clamp(dot(n, -rd), 0.0, 1.0);
  float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
  float ndl = clamp(dot(n, sun), 0.0, 1.0);

  vec3 deep = vec3(0.002, 0.018, 0.026);
  vec3 body = vec3(0.02, 0.11, 0.11);
  vec3 water = mix(deep, body, smoothstep(0.0, 0.8, ndl));
  vec3 col = mix(water, reflectedSky(refl, t), clamp(fres * 0.62, 0.0, 0.92));

  vec3 halfVec = normalize(sun - rd);
  float ndh = clamp(dot(n, halfVec), 0.0, 1.0);
  float spec = pow(ndh, 28.0);
  float glint = pow(ndh, 140.0);
  col += vec3(1.0, 0.62, 0.28) * spec * 0.55;
  col += vec3(1.0, 0.97, 0.88) * glint * 2.8;

  float crest = smoothstep(0.42, 0.62, p.y) * pow(clamp(n.y, 0.0, 1.0), 2.0);
  col = mix(col, vec3(0.78, 0.7, 0.6), crest * 0.4);

  float fog = smoothstep(12.0, 58.0, dist);
  vec3 fogCol = skyGradient(vec3(rd.x * 0.25, 0.02, abs(rd.z)));
  col = mix(col, fogCol, fog);
  return col;
}

float waterline(vec2 uv, float dive, float t) {
  float rise = smoothstep(0.08, 0.64, dive);
  float base = mix(0.50, 1.18, rise);
  float s = sin(uv.x * 21.0 + t * 0.8) * 0.046;
  s += sin(uv.x * 48.0 - t * 1.15) * 0.022;
  float field = seaHeight(vec2(uv.x * 34.0 + 0.4, 2.4), t);
  field += 0.55 * seaHeight(vec2(uv.x * 62.0 - 2.0, 5.5), t);
  float crest = (field - 0.43) * 0.16;
  return base + s + crest;
}

vec3 underwater(vec2 uv, vec3 rd, vec3 ro, float t) {
  float g = clamp(uv.y * 0.9 + rd.y * 0.25 + 0.05, 0.0, 1.0);
  vec3 col = mix(vec3(0.0, 0.015, 0.03), vec3(0.0, 0.09, 0.11), smoothstep(0.0, 0.6, g));
  col = mix(col, vec3(0.04, 0.2, 0.22), smoothstep(0.45, 1.0, g));

  for (int i = 0; i < 6; i++) {
    float fi = float(i);
    float sway = sin(t * 0.28 + fi * 1.2) * 0.055;
    float x0 = 0.06 + fi * 0.16 + sway;
    float tilt = -0.2 + sin(fi * 1.9) * 0.16 + sin(t * 0.18 + fi) * 0.05;
    float d = abs((uv.x - x0) - (1.0 - uv.y) * tilt);
    float crossSec = exp(-d * 22.0);
    float along = exp(-pow(1.0 - uv.y, 1.2) * 0.7);
    float w = crossSec * along * (0.75 + 0.25 * sin(t * 0.4 + fi));
    vec3 warm = vec3(0.95, 0.7, 0.36);
    vec3 cool = vec3(0.4, 0.85, 0.8);
    col += mix(cool, warm, smoothstep(0.1, 0.95, uv.y)) * w * 0.85;
  }

  vec2 proj = ro.xz * 0.4 + rd.xz * (4.0 + uv.y * 6.0);
  proj += vec2(t * 0.18, -t * 0.07);
  float c1 = seaHeight(proj * 1.3, t * 0.8);
  float c2 = seaHeight(proj * 2.4 + 11.0, t * 0.55);
  float caust = smoothstep(0.22, 0.88, fract(c1 * 4.6 + c2 * 3.1));
  caust *= smoothstep(0.0, 0.4, uv.y);
  col += vec3(0.3, 0.75, 0.7) * caust * 0.34;

  vec2 aspect = vec2(uResolution.x / max(uResolution.y, 1.0), 1.0);
  for (int i = 0; i < 16; i++) {
    float fi = float(i);
    float sx = fract(sin(fi * 91.17) * 43758.5453);
    float sy = fract(sin(fi * 13.71) * 24634.634);
    float sp = 0.02 + sx * 0.03;
    float y = fract(sy - t * sp);
    float x = fract(sx + sin(t * 0.31 + fi * 1.7) * 0.025);
    vec2 d = (uv - vec2(x, y)) * aspect;
    float rad = 0.008 + fract(sy * 5.1) * 0.014;
    float blob = exp(-dot(d, d) / (rad * rad));
    col += vec3(0.85, 0.94, 0.98) * blob * (0.6 + 0.4 * sin(t * 1.4 + fi));
  }

  col += vec3(0.45, 0.7, 0.6) * pow(clamp(rd.y, 0.0, 1.0), 1.5) * 0.22;
  return col;
}

vec3 rayDir(vec2 uv, float yaw, float pitch) {
  vec3 f = normalize(vec3(sin(yaw) * cos(pitch), sin(pitch), cos(yaw) * cos(pitch)));
  vec3 side = normalize(cross(f, vec3(0.0, 1.0, 0.0)));
  vec3 up = cross(side, f);
  vec2 ndc = uv * 2.0 - 1.0;
  ndc.x *= uResolution.x / max(uResolution.y, 1.0);
  return normalize(f + side * ndc.x * 0.5 + up * ndc.y * 0.38);
}

void main() {
  vec2 uv = gl_FragCoord.xy / uResolution.xy;
  float dive = smoothstep(0.0, 1.0, clamp(uDepth, 0.0, 1.0));
  float camY = mix(1.10, 0.14, dive);
  vec3 ro = vec3(uMouse.x * 0.36, camY, uMouse.y * 0.1);
  float pitch = mix(-0.06, -0.62, dive) + uMouse.y * 0.025;
  float yaw = uMouse.x * 0.06;
  vec3 rd = rayDir(uv, yaw, pitch);

  float seaT = uTime * 0.7 + 1.7;
  float line = waterline(uv, dive, seaT);
  float gate = smoothstep(0.18, 0.4, dive);
  float full = smoothstep(0.7, 0.9, dive);
  float below = 1.0 - smoothstep(line - 0.08, line + 0.02, uv.y);
  float mask = clamp(max(below * gate, full), 0.0, 1.0);

  bool skipSea = full > 0.98 || (below > 0.92 && gate > 0.5);
  vec3 col = vec3(0.0, 0.02, 0.035);
  if (!skipSea && rd.y < 0.12) {
    vec4 hit = traceSea(ro, rd, seaT);
    if (hit.w > 0.0) {
      vec3 n = seaNormal(hit.xz, seaT);
      col = shadeSea(hit.xyz, rd, n, hit.w, uTime);
      if (hit.w < 2.8) {
        mask *= smoothstep(0.25, 2.2, hit.w);
      }
    } else {
      col = skyColor(rd, uTime);
    }
  } else if (!skipSea) {
    col = skyColor(rd, uTime);
  }

  vec3 uw = underwater(uv, rd, ro, uTime);
  col = mix(col, uw, mask);

  float onScreen = smoothstep(-0.12, 0.02, line) * (1.0 - smoothstep(1.02, 1.22, line));
  float crossWin = smoothstep(0.1, 0.22, dive) * (1.0 - smoothstep(0.58, 0.8, dive));
  float dLine = uv.y - line;
  float lens = exp(-dLine * dLine * 700.0);
  col = mix(col, vec3(1.0, 0.94, 0.78), clamp(lens, 0.0, 1.0) * onScreen * crossWin);

  vec2 q = uv - 0.5;
  float vig = dot(q * vec2(0.9, 1.02), q * vec2(0.9, 1.02));
  col *= mix(0.86, 1.0, 1.0 - smoothstep(0.22, 0.72, vig));
  col = pow(clamp(col, 0.0, 1.5), vec3(0.454545));
  gl_FragColor = vec4(col, 1.0);
}

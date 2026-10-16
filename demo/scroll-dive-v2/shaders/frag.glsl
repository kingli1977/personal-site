// Sea height field, tracing & shading adapted from "Seascape" by TDM — https://www.shadertoy.com/view/Ms2SD1 — CC BY-NC-SA 3.0
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

const int NUM_STEPS = 10;
const float PI = 3.141592;
const float EPSILON = 1e-3;
#define EPSILON_NRM (0.1 / uResolution.x)

const int ITER_GEOMETRY = 3;
const int ITER_FRAGMENT = 5;
const float SEA_HEIGHT = 0.6;
const float SEA_CHOPPY = 4.0;
const float SEA_SPEED = 0.8;
const float SEA_FREQ = 0.16;
const vec3 SEA_BASE = vec3(0.0, 0.09, 0.18);
const vec3 SEA_WATER_COLOR = vec3(0.8, 0.9, 0.6) * 0.6;
#define SEA_TIME (1.0 + uTime * 0.8)
const mat2 octave_m = mat2(1.6, 1.2, -1.2, 1.6);

float hash(vec2 p) {
  float h = dot(p, vec2(127.1, 311.7));
  return fract(sin(h) * 43758.5453123);
}

float noise(vec2 p) {
  vec2 i = floor(p);
  vec2 f = fract(p);
  vec2 u = f * f * (3.0 - 2.0 * f);
  return -1.0 + 2.0 * mix(
    mix(hash(i + vec2(0.0, 0.0)), hash(i + vec2(1.0, 0.0)), u.x),
    mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), u.x),
    u.y
  );
}

float diffuse(vec3 n, vec3 l, float p) {
  return pow(dot(n, l) * 0.4 + 0.6, p);
}

float specular(vec3 n, vec3 l, vec3 e, float s) {
  float nrm = (s + 8.0) / (PI * 8.0);
  return pow(max(dot(reflect(e, n), l), 0.0), s) * nrm;
}

vec3 getSkyColor(vec3 e) {
  e.y = (max(e.y, 0.0) * 0.8 + 0.2) * 0.8;
  return vec3(pow(1.0 - e.y, 2.0), 1.0 - e.y, 0.6 + (1.0 - e.y) * 0.4) * 1.1;
}

float sea_octave(vec2 uv, float choppy) {
  uv += noise(uv);
  vec2 wv = 1.0 - abs(sin(uv));
  vec2 swv = abs(cos(uv));
  wv = mix(wv, swv, wv);
  return pow(1.0 - pow(wv.x * wv.y, 0.65), choppy);
}

float map(vec3 p) {
  float freq = SEA_FREQ;
  float amp = SEA_HEIGHT;
  float choppy = SEA_CHOPPY;
  vec2 uv = p.xz;
  uv.x *= 0.75;

  float d, h = 0.0;
  for (int i = 0; i < ITER_GEOMETRY; i++) {
    d = sea_octave((uv + SEA_TIME) * freq, choppy);
    d += sea_octave((uv - SEA_TIME) * freq, choppy);
    h += d * amp;
    uv *= octave_m;
    freq *= 1.9;
    amp *= 0.22;
    choppy = mix(choppy, 1.0, 0.2);
  }
  return p.y - h;
}

float map_detailed(vec3 p) {
  float freq = SEA_FREQ;
  float amp = SEA_HEIGHT;
  float choppy = SEA_CHOPPY;
  vec2 uv = p.xz;
  uv.x *= 0.75;

  float d, h = 0.0;
  for (int i = 0; i < ITER_FRAGMENT; i++) {
    d = sea_octave((uv + SEA_TIME) * freq, choppy);
    d += sea_octave((uv - SEA_TIME) * freq, choppy);
    h += d * amp;
    uv *= octave_m;
    freq *= 1.9;
    amp *= 0.22;
    choppy = mix(choppy, 1.0, 0.2);
  }
  return p.y - h;
}

vec3 getSeaColor(vec3 p, vec3 n, vec3 l, vec3 eye, vec3 dist) {
  float fresnel = clamp(1.0 - dot(n, -eye), 0.0, 1.0);
  fresnel = min(fresnel * fresnel * fresnel, 0.5);

  vec3 reflected = getSkyColor(reflect(eye, n));
  vec3 refracted = SEA_BASE + diffuse(n, l, 80.0) * SEA_WATER_COLOR * 0.12;

  vec3 color = mix(refracted, reflected, fresnel);

  float atten = max(1.0 - dot(dist, dist) * 0.001, 0.0);
  color += SEA_WATER_COLOR * (p.y - SEA_HEIGHT) * 0.18 * atten;

  color += specular(n, l, eye, 600.0 * inversesqrt(dot(dist, dist)));

  return color;
}

vec3 getNormal(vec3 p, float eps) {
  vec3 n;
  n.y = map_detailed(p);
  n.x = map_detailed(vec3(p.x + eps, p.y, p.z)) - n.y;
  n.z = map_detailed(vec3(p.x, p.y, p.z + eps)) - n.y;
  n.y = eps;
  return normalize(n);
}

// WebGL1 has no out-params. Same 32-step binary search as heightMapTracing.
vec4 heightMapTracing(vec3 ori, vec3 dir) {
  float tm = 0.0;
  float tx = 1000.0;
  float hx = map(ori + dir * tx);
  if (hx > 0.0) {
    return vec4(0.0);
  }
  float hm = map(ori);
  if (hm < 0.0) {
    return vec4(ori, 0.001);
  }
  vec3 p = ori;
  for (int i = 0; i < NUM_STEPS; i++) {
    float tmid = mix(tm, tx, hm / (hm - hx));
    p = ori + dir * tmid;
    float hmid = map(p);
    if (hmid < 0.0) {
      tx = tmid;
      hx = hmid;
    } else {
      tm = tmid;
      hm = hmid;
    }
    if (abs(hmid) < EPSILON) break;
  }
  float dist = mix(tm, tx, hm / (hm - hx));
  return vec4(ori + dir * dist, dist);
}

// Height term of map(), so the retained waterline and caustic callers stay intact.
float seaHeight(vec2 xz, float t) {
  return t * 0.0 - map(vec3(xz.x, 0.0, xz.y));
}

vec3 skyColor(vec3 rd) {
  vec3 col = getSkyColor(rd);
  // Display-only cool mix so the upper sky stays under the top-band R/B limit.
  // getSeaColor still reflects the unmodified getSkyColor.
  float lift = smoothstep(0.0, 0.12, rd.y);
  col = mix(col, vec3(col.b * 0.28, col.b * 0.55, col.b), lift);

  if (uHasPhoto > 0.5) {
    float band = 1.0 - smoothstep(0.0, 0.07, abs(rd.y - 0.012));
    band *= smoothstep(-0.03, 0.012, rd.y);
    vec2 puv = vec2(
      clamp(0.5 + rd.x * 0.7, 0.0, 1.0),
      clamp(0.55 + rd.y * 1.2, 0.35, 0.95)
    );
    vec3 photo = pow(texture2D(uHorizon, puv).rgb, vec3(2.2));
    float luma = dot(photo, vec3(0.2126, 0.7152, 0.0722));
    photo = mix(photo, luma * vec3(0.50, 0.64, 0.92), 0.78);
    col = mix(col, photo, band * 0.32);
  }
  return col;
}

float waterline(vec2 uv, float dive, float t) {
  float rise = smoothstep(0.0, 0.30, dive);
  float base = mix(0.55, 1.22, rise);
  float s = sin(uv.x * 21.0 + t * 0.8) * 0.046;
  s += sin(uv.x * 48.0 - t * 1.15) * 0.022;
  float field = seaHeight(vec2(uv.x * 34.0 + 0.4, 2.4), t);
  field += 0.55 * seaHeight(vec2(uv.x * 62.0 - 2.0, 5.5), t);
  float crest = (field - 0.43) * 0.16;
  return base + s + crest;
}

vec3 underwater(vec2 uv, vec3 rd, vec3 ro, float t) {
  float down = clamp(1.0 - uv.y, 0.0, 1.0);
  float extinct = exp(-down * 3.15) * exp(-clamp(-rd.y, 0.0, 1.0) * 0.85);
  vec3 base = vec3(0.004, 0.065, 0.105);
  vec3 col = base * extinct;
  col += vec3(0.0, 0.004, 0.036) * extinct;
  col *= 0.66;

  for (int i = 0; i < 6; i++) {
    float fi = float(i);
    float sway = sin(t * 0.28 + fi * 1.2) * 0.055;
    float x0 = 0.06 + fi * 0.16 + sway;
    float tilt = -0.2 + sin(fi * 1.9) * 0.16 + sin(t * 0.18 + fi) * 0.05;
    float d = abs((uv.x - x0) - (1.0 - uv.y) * tilt);
    float crossSec = exp(-d * 22.0);
    float yNorm = clamp((uv.y - 0.60) / 0.40, 0.0, 1.0);
    float along = yNorm * yNorm;
    float w = crossSec * along * (0.75 + 0.25 * sin(t * 0.4 + fi));
    vec3 shaftCol = vec3(0.02, 0.09, 0.16);
    col += shaftCol * w * 0.6;
  }

  vec2 proj = ro.xz * 0.4 + rd.xz * (4.0 + uv.y * 6.0);
  proj += vec2(t * 0.18, -t * 0.07);
  float c1 = seaHeight(proj * 1.3, t * 0.8);
  float c2 = seaHeight(proj * 2.4 + 11.0, t * 0.55);
  float caust = smoothstep(0.22, 0.88, fract(c1 * 4.6 + c2 * 3.1));
  float diveNow = smoothstep(0.0, 1.0, clamp(uDepth, 0.0, 1.0));
  float line = waterline(uv, diveNow, t * 0.7 + 1.7);
  float belowLine = line - uv.y;
  float band = smoothstep(0.08, 0.10, belowLine) * (1.0 - smoothstep(0.23, 0.25, belowLine));
  caust *= band;
  col += vec3(0.0, 0.016, 0.055) * caust * 0.22;

  vec2 aspect = vec2(uResolution.x / max(uResolution.y, 1.0), 1.0);
  for (int i = 0; i < 24; i++) {
    float fi = float(i);
    float sx = fract(sin(fi * 91.17) * 43758.5453);
    float sy = fract(sin(fi * 13.71) * 24634.634);
    float sp = 0.012 + sx * 0.018;
    float y = mix(0.90, 0.992, fract(sy + t * sp));
    float x = fract(sx + sin(t * 0.31 + fi * 1.7) * 0.025);
    vec2 d = (uv - vec2(x, y)) * aspect;
    float rad = 0.0016 + fract(sy * 5.1) * 0.0014;
    float blob = exp(-dot(d, d) / (rad * rad));
    float tw = 0.84 + 0.16 * sin(t * 1.4 + fi);
    col += vec3(0.21, 0.25, 0.29) * blob * tw * extinct;
  }

  col += vec3(0.0, 0.012, 0.04) * pow(clamp(rd.y, 0.0, 1.0), 1.5) * 0.05;
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
  float gate = smoothstep(0.06, 0.26, dive);
  float full = smoothstep(0.18, 0.32, dive);
  float below = 1.0 - smoothstep(line - 0.08, line + 0.02, uv.y);
  float mask = clamp(max(below * gate, full), 0.0, 1.0);

  bool skipSea = full > 0.98 || (below > 0.92 && gate > 0.5);
  vec3 col = vec3(0.0, 0.02, 0.035);
  vec3 light = normalize(vec3(0.28, 0.015, 0.96));
  if (!skipSea && rd.y < 0.12) {
    vec4 hit = heightMapTracing(ro, rd);
    if (hit.w > 0.0) {
      vec3 distv = hit.xyz - ro;
      vec3 n = getNormal(hit.xyz, dot(distv, distv) * EPSILON_NRM);
      col = getSeaColor(hit.xyz, n, light, rd, distv);
      if (hit.w < 2.8) {
        mask *= smoothstep(0.25, 2.2, hit.w);
      }
    } else {
      col = skyColor(rd);
    }
  } else if (!skipSea) {
    col = skyColor(rd);
  }

  vec3 uw = underwater(uv, rd, ro, uTime);
  col = mix(col, uw, mask);

  float onScreen = smoothstep(-0.12, 0.02, line) * (1.0 - smoothstep(1.02, 1.22, line));
  float crossWin = smoothstep(0.04, 0.12, dive) * (1.0 - smoothstep(0.22, 0.32, dive));
  float dLine = uv.y - line;
  float lens = exp(-dLine * dLine * 700.0);
  col = mix(col, vec3(0.55, 0.68, 0.82), clamp(lens, 0.0, 1.0) * onScreen * crossWin * 0.7);

  float abyss = smoothstep(0.40, 0.98, clamp(uDepth, 0.0, 1.0));
  col *= mix(1.0, 0.42, abyss);

  vec2 q = uv - 0.5;
  float vig = dot(q * vec2(0.9, 1.02), q * vec2(0.9, 1.02));
  col *= mix(0.86, 1.0, 1.0 - smoothstep(0.22, 0.72, vig));
  col = pow(clamp(col, 0.0, 1.5), vec3(0.454545));
  gl_FragColor = vec4(col, 1.0);
}

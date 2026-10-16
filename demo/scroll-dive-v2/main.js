const canvas = document.getElementById("c");
const intro = document.getElementById("intro");
const watch = document.getElementById("watch");
const fallbackNote = document.getElementById("fallback-note");
const lines = Array.from(document.querySelectorAll(".story p"));

const reduceQuery = window.matchMedia("(prefers-reduced-motion: reduce)");
let reduce = reduceQuery.matches;
let raf = 0;
let time = 1.6;
let lastStamp = 0;
let mouseX = 0;
let mouseY = 0;
let targetX = 0;
let targetY = 0;
let filmToken = 0;
let pixelScale = 1;
const scaleSteps = [1, 0.85, 0.7, 0.55];
let scaleIndex = 0;
let scaleHoldUntil = 0;
let frameTimes = [];
let gl = null;
let program = null;
let photo = 0;

function smoothstep(a, b, x) {
  const t = Math.min(1, Math.max(0, (x - a) / (b - a || 1)));
  return t * t * (3 - 2 * t);
}

function scrollProgress() {
  const max = document.documentElement.scrollHeight - window.innerHeight;
  if (max <= 0) return 0;
  return Math.min(1, Math.max(0, window.scrollY / max));
}

function paintCopy(p) {
  intro.style.opacity = (1 - smoothstep(0.02, 0.15, p)).toFixed(3);
  for (const node of lines) {
    const a = Number(node.dataset.in);
    const b = Number(node.dataset.out);
    const fade = 0.045;
    const o = smoothstep(a, a + fade, p) * (1 - smoothstep(b - fade, b, p));
    node.style.opacity = o.toFixed(3);
  }
}

function showFallback(message) {
  canvas.style.visibility = "hidden";
  fallbackNote.hidden = false;
  if (message) fallbackNote.textContent = message;
}

function compile(gl, type, source) {
  const shader = gl.createShader(type);
  gl.shaderSource(shader, source);
  gl.compileShader(shader);
  if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
    const log = gl.getShaderInfoLog(shader) || "shader compile failed";
    gl.deleteShader(shader);
    throw new Error(log);
  }
  return shader;
}

function link(gl, vertSrc, fragSrc) {
  const program = gl.createProgram();
  const vs = compile(gl, gl.VERTEX_SHADER, vertSrc);
  const fs = compile(gl, gl.FRAGMENT_SHADER, fragSrc);
  gl.attachShader(program, vs);
  gl.attachShader(program, fs);
  gl.bindAttribLocation(program, 0, "aPos");
  gl.linkProgram(program);
  gl.deleteShader(vs);
  gl.deleteShader(fs);
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    const log = gl.getProgramInfoLog(program) || "program link failed";
    gl.deleteProgram(program);
    throw new Error(log);
  }
  return program;
}

function resize() {
  if (!gl) return;
  const dpr = Math.min(window.devicePixelRatio || 1, 1.25);
  const w = Math.max(1, Math.floor(canvas.clientWidth * dpr * pixelScale));
  const h = Math.max(1, Math.floor(canvas.clientHeight * dpr * pixelScale));
  if (canvas.width !== w || canvas.height !== h) {
    canvas.width = w;
    canvas.height = h;
  }
  gl.viewport(0, 0, canvas.width, canvas.height);
}

function draw() {
  if (!gl || !program) return;
  const p = scrollProgress();
  paintCopy(p);
  if (!reduce) {
    mouseX += (targetX - mouseX) * 0.06;
    mouseY += (targetY - mouseY) * 0.06;
  } else {
    mouseX = targetX;
    mouseY = targetY;
  }

  gl.useProgram(program);
  gl.uniform2f(program.uResolution, canvas.width, canvas.height);
  gl.uniform1f(program.uTime, time);
  gl.uniform1f(program.uDepth, p);
  gl.uniform2f(program.uMouse, mouseX, mouseY);
  gl.uniform1f(program.uHasPhoto, photo);
  gl.uniform1i(program.uHorizon, 0);
  gl.drawArrays(gl.TRIANGLE_STRIP, 0, 4);
  canvas.style.visibility = "visible";
}

function adaptScale(wallMs) {
  if (wallMs <= 0 || wallMs > 4000) return;
  frameTimes.push(wallMs);
  if (frameTimes.length > 8) frameTimes.shift();
  if (frameTimes.length < 4) return;
  if (performance.now() < scaleHoldUntil) return;
  const avg = frameTimes.reduce((sum, value) => sum + value, 0) / frameTimes.length;
  let next = scaleIndex;
  if (avg > 34 && scaleIndex < scaleSteps.length - 1) next = scaleIndex + 1;
  else if (avg < 15 && scaleIndex > 0) next = scaleIndex - 1;
  if (next !== scaleIndex) {
    scaleIndex = next;
    pixelScale = scaleSteps[scaleIndex];
    scaleHoldUntil = performance.now() + 2500;
    frameTimes.length = 0;
    resize();
  }
}

function frame(now) {
  if (reduce) return;
  const wall = lastStamp ? now - lastStamp : 16;
  lastStamp = now;
  time += Math.min(0.25, wall * 0.001);
  adaptScale(wall);
  draw();
  raf = requestAnimationFrame(frame);
}

function startLoop() {
  cancelAnimationFrame(raf);
  if (reduce) {
    draw();
    return;
  }
  lastStamp = 0;
  raf = requestAnimationFrame(frame);
}

function playFilm() {
  const token = ++filmToken;
  const max = document.documentElement.scrollHeight - window.innerHeight;
  if (reduce) {
    window.scrollTo(0, max);
    draw();
    return;
  }
  window.scrollTo(0, 0);
  const t0 = performance.now();
  const dur = 12000;
  const step = (now) => {
    if (token !== filmToken) return;
    const t = Math.min(1, (now - t0) / dur);
    window.scrollTo(0, max * t);
    if (t < 1) requestAnimationFrame(step);
  };
  requestAnimationFrame(step);
}

function stopFilm() {
  filmToken++;
}

async function loadImage(url) {
  const img = new Image();
  img.decoding = "async";
  img.src = url;
  await new Promise((resolve, reject) => {
    img.onload = () => resolve();
    img.onerror = () => reject(new Error("image"));
  });
  return img;
}

async function boot() {
  paintCopy(scrollProgress());
  gl = canvas.getContext("webgl", {
    alpha: false,
    antialias: false,
    depth: false,
    stencil: false,
    powerPreference: "high-performance",
    failIfMajorPerformanceCaveat: false
  });
  if (!gl) {
    showFallback("This frame needs WebGL. The still above is the sunset horizon.");
    return;
  }

  let vertSrc;
  let fragSrc;
  try {
    const root = new URL(".", import.meta.url);
    [vertSrc, fragSrc] = await Promise.all([
      fetch(new URL("shaders/vert.glsl", root)).then((r) => {
        if (!r.ok) throw new Error("vertex shader missing");
        return r.text();
      }),
      fetch(new URL("shaders/frag.glsl", root)).then((r) => {
        if (!r.ok) throw new Error("fragment shader missing");
        return r.text();
      })
    ]);
    program = link(gl, vertSrc, fragSrc);
  } catch (err) {
    console.error(err);
    showFallback("This frame needs WebGL. The still above is the sunset horizon.");
    return;
  }

  program.uResolution = gl.getUniformLocation(program, "uResolution");
  program.uTime = gl.getUniformLocation(program, "uTime");
  program.uDepth = gl.getUniformLocation(program, "uDepth");
  program.uMouse = gl.getUniformLocation(program, "uMouse");
  program.uHasPhoto = gl.getUniformLocation(program, "uHasPhoto");
  program.uHorizon = gl.getUniformLocation(program, "uHorizon");

  const buffer = gl.createBuffer();
  gl.bindBuffer(gl.ARRAY_BUFFER, buffer);
  gl.bufferData(gl.ARRAY_BUFFER, new Float32Array([
    -1, -1, 1, -1, -1, 1, 1, 1
  ]), gl.STATIC_DRAW);
  gl.enableVertexAttribArray(0);
  gl.vertexAttribPointer(0, 2, gl.FLOAT, false, 0, 0);

  const tex = gl.createTexture();
  gl.activeTexture(gl.TEXTURE0);
  gl.bindTexture(gl.TEXTURE_2D, tex);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_S, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_WRAP_T, gl.CLAMP_TO_EDGE);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MIN_FILTER, gl.LINEAR);
  gl.texParameteri(gl.TEXTURE_2D, gl.TEXTURE_MAG_FILTER, gl.LINEAR);
  gl.texImage2D(
    gl.TEXTURE_2D, 0, gl.RGB, 1, 1, 0, gl.RGB, gl.UNSIGNED_BYTE,
    new Uint8Array([18, 14, 22])
  );
  gl.pixelStorei(gl.UNPACK_FLIP_Y_WEBGL, true);

  try {
    const img = await loadImage(new URL("assets/sunset-horizon.jpg", import.meta.url).href);
    gl.bindTexture(gl.TEXTURE_2D, tex);
    gl.texImage2D(gl.TEXTURE_2D, 0, gl.RGB, gl.RGB, gl.UNSIGNED_BYTE, img);
    photo = 1;
  } catch (err) {
    photo = 0;
  }

  resize();
  startLoop();
}

window.addEventListener("resize", () => {
  resize();
  if (reduce) draw();
});
window.addEventListener("scroll", () => {
  if (reduce) draw();
}, { passive: true });
window.addEventListener("pointermove", (event) => {
  targetX = (event.clientX / Math.max(1, window.innerWidth)) * 2 - 1;
  targetY = (event.clientY / Math.max(1, window.innerHeight)) * 2 - 1;
  if (reduce) draw();
}, { passive: true });
window.addEventListener("wheel", stopFilm, { passive: true });
window.addEventListener("touchstart", stopFilm, { passive: true });
watch.addEventListener("click", playFilm);
reduceQuery.addEventListener("change", () => {
  reduce = reduceQuery.matches;
  startLoop();
});

const preset = new URLSearchParams(location.search).get("at");
if (preset !== null && preset !== "") {
  const at = Math.min(1, Math.max(0, Number(preset)));
  if (!Number.isNaN(at)) {
    const jump = () => {
      const max = document.documentElement.scrollHeight - window.innerHeight;
      window.scrollTo(0, max * at);
    };
    jump();
    window.addEventListener("load", jump);
  }
}

boot();

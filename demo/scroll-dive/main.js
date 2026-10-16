(function () {
  var motion = window.matchMedia("(prefers-reduced-motion: reduce)");

  if (motion.addEventListener) {
    motion.addEventListener("change", function () {
      window.location.reload();
    });
  }

  var reduced = document.documentElement.classList.contains("reduced") || motion.matches;

  // Deterministic field so the deep phase always reads as a particle cloud.
  function rnd(state) {
    state.v = (state.v * 16807) % 2147483647;
    return (state.v - 1) / 2147483646;
  }

  function fillParticles(container, animate) {
    if (!container || container.childElementCount > 0) {
      return;
    }
    var count = Number(container.getAttribute("data-count")) || 48;
    var state = { v: 19 + (animate ? 3 : 11) };
    var i;
    for (i = 0; i < count; i += 1) {
      var dot = document.createElement("span");
      var size = 2 + rnd(state) * 4;
      dot.style.left = (rnd(state) * 100).toFixed(2) + "%";
      dot.style.top = (rnd(state) * 100).toFixed(2) + "%";
      dot.style.width = size.toFixed(2) + "px";
      dot.style.height = size.toFixed(2) + "px";
      dot.style.setProperty("--dx", ((rnd(state) - 0.5) * 18).toFixed(2) + "vw");
      if (animate) {
        dot.style.animationDuration = (14 + rnd(state) * 12).toFixed(2) + "s";
        dot.style.animationDelay = (-rnd(state) * 26).toFixed(2) + "s";
      }
      container.appendChild(dot);
    }
  }

  document.querySelectorAll(".particles").forEach(function (container) {
    var inJourney = Boolean(container.closest(".journey"));
    fillParticles(container, inJourney && !reduced);
  });

  if (reduced || !window.gsap || !window.ScrollTrigger) {
    return;
  }

  var gsap = window.gsap;
  var ScrollTrigger = window.ScrollTrigger;

  gsap.registerPlugin(ScrollTrigger);
  ScrollTrigger.config({ ignoreMobileResize: true });

  var journey = document.getElementById("journey");
  var button = document.getElementById("dive-button");

  // 500vh track − 100vh stage = 400vh of scroll (4 screens).
  // Copy travels 60.8vh (15.2vh per screen, above the 15vh floor).
  // Mid 36.5vh and background 18.2vh keep the 15:30:50 ratio and clear
  // the 15 / 30 / 50vh baselines. Scale 1→1.15 is only ~4% per screen,
  // so the copy parallax is what satisfies every 100vh.
  var screens = 4;
  var copyPerScreen = 0.152;
  var copyTravel = copyPerScreen * screens;
  var midTravel = copyTravel * (30 / 50);
  var bgTravel = copyTravel * (15 / 50);

  var tl = gsap.timeline({
    defaults: { ease: "none", force3D: true },
    scrollTrigger: {
      trigger: journey,
      start: "top top",
      end: "bottom bottom",
      scrub: true,
      invalidateOnRefresh: true,
    },
  });

  tl.fromTo(".bg-scale", { scale: 1 }, { scale: 1.15, duration: 1 }, 0);
  tl.fromTo(".bg-parallax", { y: 0 }, {
    y: function () { return window.innerHeight * bgTravel; },
    duration: 1,
  }, 0);
  tl.fromTo(".mid-parallax", { y: 0 }, {
    y: function () { return window.innerHeight * midTravel; },
    duration: 1,
  }, 0);
  tl.fromTo(".copy-parallax", { y: 0 }, {
    y: function () { return window.innerHeight * copyTravel; },
    duration: 1,
  }, 0);

  tl.to(".scene-surface", { opacity: 0, duration: 0.2 }, 0.26);
  tl.fromTo(".scene-transition", { opacity: 0 }, { opacity: 1, duration: 0.16 }, 0.22);
  tl.to(".scene-transition", { opacity: 0, duration: 0.18 }, 0.62);
  tl.fromTo(".scene-deep", { opacity: 0 }, { opacity: 1, duration: 0.2 }, 0.56);

  tl.fromTo(".beams", { opacity: 0 }, { opacity: 1, duration: 0.12 }, 0.22);
  tl.to(".beams", { opacity: 0, duration: 0.16 }, 0.62);
  tl.fromTo(".particles", { opacity: 0 }, { opacity: 1, duration: 0.14 }, 0.34);
  tl.fromTo(".caustics", { opacity: 0 }, { opacity: 1, duration: 0.16 }, 0.58);

  tl.fromTo(".seg-sub", { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 0.1 }, 0.15);
  tl.fromTo(".seg-btn", { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 0.1 }, 0.32);

  var live = false;
  tl.eventCallback("onUpdate", function () {
    var next = tl.progress() >= 0.38;
    if (next === live) {
      return;
    }
    live = next;
    button.classList.toggle("is-live", live);
    button.tabIndex = live ? 0 : -1;
  });

  button.addEventListener("click", function () {
    var distance = journey.offsetHeight - window.innerHeight;
    window.scrollTo({
      top: journey.offsetTop + distance * 0.9,
      behavior: "smooth",
    });
  });
})();

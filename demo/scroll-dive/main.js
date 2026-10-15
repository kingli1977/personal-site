(function () {
  var motion = window.matchMedia("(prefers-reduced-motion: reduce)");

  if (motion.addEventListener) {
    motion.addEventListener("change", function () {
      window.location.reload();
    });
  }

  if (document.documentElement.classList.contains("reduced") || motion.matches) {
    return;
  }

  if (!window.gsap || !window.ScrollTrigger) {
    return;
  }

  var gsap = window.gsap;
  var ScrollTrigger = window.ScrollTrigger;

  gsap.registerPlugin(ScrollTrigger);
  ScrollTrigger.config({ ignoreMobileResize: true });

  var journey = document.getElementById("journey");
  var button = document.getElementById("dive-button");

  // Progress 0→1 is the only scrubbed timeline. Reveals are windows on that
  // progress, not separate entrance tweens. Ease stays linear so the dive
  // tracks the scroll position in both directions.
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
  tl.fromTo(
    ".bg-parallax",
    { y: 0 },
    { y: function () { return -window.innerHeight * 0.04; }, duration: 1 },
    0
  );
  tl.fromTo(
    ".mid-parallax",
    { y: 0 },
    { y: function () { return -window.innerHeight * 0.11; }, duration: 1 },
    0
  );
  tl.fromTo(
    ".copy-parallax",
    { y: 0 },
    { y: function () { return -window.innerHeight * 0.2; }, duration: 1 },
    0
  );

  tl.to(".scene-surface", { opacity: 0, duration: 0.2 }, 0.3);
  tl.fromTo(".scene-transition", { opacity: 0 }, { opacity: 1, duration: 0.18 }, 0.26);
  tl.to(".scene-transition", { opacity: 0, duration: 0.2 }, 0.62);
  tl.fromTo(".scene-deep", { opacity: 0 }, { opacity: 1, duration: 0.22 }, 0.58);

  tl.fromTo(".beams", { opacity: 0 }, { opacity: 1, duration: 0.16 }, 0.32);
  tl.to(".beams", { opacity: 0, duration: 0.18 }, 0.66);
  tl.fromTo(".caustics", { opacity: 0 }, { opacity: 1, duration: 0.18 }, 0.68);
  tl.fromTo(".motes", { opacity: 0.28 }, { opacity: 0.9, duration: 1 }, 0);

  // Second text segment: subtitle, progress 0.15–0.25.
  tl.fromTo(".seg-sub", { opacity: 0, y: 40 }, { opacity: 1, y: 0, duration: 0.1 }, 0.15);
  // Third text segment: primary button.
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

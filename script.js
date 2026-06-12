// Year
const yearEl = document.getElementById("year");
if (yearEl) yearEl.textContent = new Date().getFullYear();

// Menu overlay
const menuBtn = document.getElementById("menuBtn");
const menuClose = document.getElementById("menuClose");
const navOverlay = document.getElementById("navOverlay");
if (menuBtn && navOverlay) {
  menuBtn.addEventListener("click", () => {
    navOverlay.classList.add("is-open");
    document.body.style.overflow = "hidden";
  });
  menuClose.addEventListener("click", () => {
    navOverlay.classList.remove("is-open");
    document.body.style.overflow = "";
  });
  window.addEventListener("keydown", (e) => {
    if (e.key === "Escape" && navOverlay.classList.contains("is-open")) {
      navOverlay.classList.remove("is-open");
      document.body.style.overflow = "";
    }
  });
}

// Lightbox
const lightbox = document.getElementById("lightbox");

if (lightbox) {
  const lightboxImg = document.getElementById("lightboxImg");
  const lightboxCaption = document.getElementById("lightboxCaption");
  const closeLightboxBtn = document.getElementById("closeLightbox");
  const prevBtn = document.getElementById("prevBtn");
  const nextBtn = document.getElementById("nextBtn");

  let currentList = [];
  let activeIndex = 0;

  function openLightbox(list, i) {
    currentList = list;
    activeIndex = i;
    const p = currentList[activeIndex];
    lightboxImg.src = p.src;
    lightboxImg.alt = "";
    if (lightboxCaption) lightboxCaption.textContent = "";
    lightbox.classList.add("is-open");
    lightbox.setAttribute("aria-hidden", "false");
    document.body.style.overflow = "hidden";
  }

  function closeLightbox() {
    lightbox.classList.remove("is-open");
    lightbox.setAttribute("aria-hidden", "true");
    document.body.style.overflow = "";
    lightboxImg.src = "";
  }

  function step(dir) {
    activeIndex = (activeIndex + dir + currentList.length) % currentList.length;
    openLightbox(currentList, activeIndex);
  }

  closeLightboxBtn.addEventListener("click", closeLightbox);
  prevBtn.addEventListener("click", () => step(-1));
  nextBtn.addEventListener("click", () => step(1));
  lightbox.addEventListener("click", (e) => { if (e.target === lightbox) closeLightbox(); });
  window.addEventListener("keydown", (e) => {
    if (!lightbox.classList.contains("is-open")) return;
    if (e.key === "Escape") closeLightbox();
    if (e.key === "ArrowLeft") step(-1);
    if (e.key === "ArrowRight") step(1);
  });

  // Swipe to navigate on touch devices
  let touchStartX = 0;
  lightbox.addEventListener("touchstart", (e) => {
    touchStartX = e.touches[0].clientX;
  }, { passive: true });
  lightbox.addEventListener("touchend", (e) => {
    const dx = e.changedTouches[0].clientX - touchStartX;
    if (Math.abs(dx) > 50) step(dx < 0 ? 1 : -1);
  }, { passive: true });

  const GAP = 10;

  // Fisher–Yates shuffle — returns a new randomized array
  function shuffle(arr) {
    const a = arr.slice();
    for (let i = a.length - 1; i > 0; i--) {
      const j = Math.floor(Math.random() * (i + 1));
      [a[i], a[j]] = [a[j], a[i]];
    }
    return a;
  }

  function renderGallery(gridId, tag, photos) {
    const grid = document.getElementById(gridId);
    if (!grid) return;
    // Shuffle once per page load; resizing reuses this same order
    const list = shuffle(photos.filter(p => p.tag === tag));
    if (!list.length) return;

    let rafId;

    // Build cards once; layout() only positions them, so resizing
    // never recreates <img> elements or retriggers loads
    const cards = list.map((p, i) => {
      const card = document.createElement("button");
      card.type = "button";
      card.className = "card";
      card.setAttribute("aria-label", "Open photo");

      const img = document.createElement("img");
      img.alt     = "";
      img.loading = i < 6 ? "eager" : "lazy";
      img.src     = p.src;

      // Legacy photo without stored aspect — detect and re-layout once
      if (!p.aspect) {
        img.onload = () => {
          p.aspect = parseFloat((img.naturalWidth / img.naturalHeight).toFixed(3));
          cancelAnimationFrame(rafId);
          rafId = requestAnimationFrame(layout);
        };
      }

      card.appendChild(img);
      card.addEventListener("click", () => openLightbox(list, i));
      grid.appendChild(card);
      return card;
    });

    function layout() {
      const totalW = grid.clientWidth;
      if (!totalW) return;

      const cols  = totalW >= 600 ? 3 : 2;
      const colW  = (totalW - GAP * (cols + 1)) / cols;
      const colH  = new Array(cols).fill(GAP); // start each column GAP from top

      list.forEach((p, i) => {
        const aspect = p.aspect || 0.75;
        const h      = Math.round(colW / aspect);
        const col    = colH.indexOf(Math.min(...colH));

        cards[i].style.cssText =
          `width:${colW}px;height:${h}px;top:${colH[col]}px;left:${GAP + col * (colW + GAP)}px`;
        colH[col] += h + GAP;
      });

      grid.style.height = Math.max(...colH) + "px";
    }

    layout();

    // Recompute on container resize (debounced)
    let resizeTimer;
    new ResizeObserver(() => {
      clearTimeout(resizeTimer);
      resizeTimer = setTimeout(layout, 80);
    }).observe(grid);
  }

  // Load photos from photos.json
  fetch("photos.json")
    .then(r => r.json())
    .then(photos => {
      renderGallery("grid-portrait", "portrait", photos);
      renderGallery("grid-city-nature", "city-nature", photos);
      renderGallery("grid-events", "events", photos);
    })
    .catch(() => {});
}

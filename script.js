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
    lightboxImg.alt = p.src;
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

  // Brickwork pattern — period of 6, tiles gap-free in a 3-col grid with dense packing:
  // Row 1: portrait(1col) + landscape(2col)
  // Row 2: landscape(2col) + tall-portrait(1col)
  // Row 3: portrait(1col) + portrait(1col) + portrait(1col)
  const BRICK = [
    { span: 1, ratio: "3/4"  },  // portrait
    { span: 2, ratio: "16/9" },  // landscape
    { span: 2, ratio: "3/2"  },  // landscape (slightly squarer)
    { span: 1, ratio: "2/3"  },  // tall portrait
    { span: 1, ratio: "3/4"  },  // portrait
    { span: 1, ratio: "5/6"  },  // standard portrait
  ];

  function renderGallery(gridId, tag, photos) {
    const grid = document.getElementById(gridId);
    if (!grid) return;
    const list = photos.filter(p => p.tag === tag);
    list.forEach((p, i) => {
      const { span, ratio } = BRICK[i % BRICK.length];
      const card = document.createElement("button");
      card.className = "card";
      card.style.gridColumn = `span ${span}`;
      card.style.aspectRatio = ratio;
      card.setAttribute("type", "button");
      card.setAttribute("aria-label", "Open photo");
      card.innerHTML = `<img src="${p.src}" alt="" loading="lazy" />`;
      card.addEventListener("click", () => openLightbox(list, i));
      grid.appendChild(card);
    });
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

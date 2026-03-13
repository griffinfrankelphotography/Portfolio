const photos = [
  // Portrait gallery — tag: "portrait"
  { src: "images/photo-01.jpg", title: "Untitled 01", tag: "portrait", layout: "tall" },
  { src: "images/photo-04.jpg", title: "Untitled 04", tag: "portrait", layout: "" },
  { src: "images/photo-08.jpg", title: "Untitled 08", tag: "portrait", layout: "" },

  // City & Nature gallery — tag: "city-nature"
  { src: "images/photo-02.jpg", title: "Untitled 02", tag: "city-nature", layout: "wide" },
  { src: "images/photo-07.jpg", title: "Untitled 07", tag: "city-nature", layout: "" },
  { src: "images/photo-03.jpg", title: "Untitled 03", tag: "city-nature", layout: "" },

  // Events gallery — tag: "events"
  { src: "images/photo-05.jpg", title: "Untitled 05", tag: "events", layout: "wide" },
  { src: "images/photo-06.jpg", title: "Untitled 06", tag: "events", layout: "" },
];

const year = document.getElementById("year");
year.textContent = new Date().getFullYear();

// Theme toggle
const themeBtn = document.getElementById("themeBtn");
const root = document.documentElement;

const savedTheme = localStorage.getItem("theme");
if (savedTheme) root.setAttribute("data-theme", savedTheme);

themeBtn.addEventListener("click", () => {
  const current = root.getAttribute("data-theme") || "dark";
  const next = current === "dark" ? "light" : "dark";
  root.setAttribute("data-theme", next);
  localStorage.setItem("theme", next);
});

// Lightbox state
const lightbox = document.getElementById("lightbox");
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
  lightboxImg.alt = p.title;
  lightboxCaption.textContent = p.title;

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

lightbox.addEventListener("click", (e) => {
  if (e.target === lightbox) closeLightbox();
});

window.addEventListener("keydown", (e) => {
  if (!lightbox.classList.contains("is-open")) return;
  if (e.key === "Escape") closeLightbox();
  if (e.key === "ArrowLeft") step(-1);
  if (e.key === "ArrowRight") step(1);
});

// Render a gallery section
function renderGallery(gridId, tag) {
  const grid = document.getElementById(gridId);
  const list = photos.filter(p => p.tag === tag);

  list.forEach((p, i) => {
    const card = document.createElement("button");
    card.className = `card ${p.layout ? `card--${p.layout}` : ""}`.trim();
    card.setAttribute("type", "button");
    card.setAttribute("aria-label", `Open ${p.title}`);

    card.innerHTML = `
      <img src="${p.src}" alt="${p.title}" loading="lazy" />
      <div class="card__meta" aria-hidden="true">
        <span class="card__title">${p.title}</span>
      </div>
    `;

    card.addEventListener("click", () => openLightbox(list, i));
    grid.appendChild(card);
  });
}

renderGallery("grid-portrait", "portrait");
renderGallery("grid-city-nature", "city-nature");
renderGallery("grid-events", "events");

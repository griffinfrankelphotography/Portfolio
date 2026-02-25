const photos = [
  // Update these to match your files + titles + categories
  { src: "images/photo-01.jpg", title: "Untitled 01", tag: "portraits", layout: "tall" },
  { src: "images/photo-02.jpg", title: "Untitled 02", tag: "street", layout: "wide" },
  { src: "images/photo-03.jpg", title: "Untitled 03", tag: "landscape", layout: "" },
  { src: "images/photo-04.jpg", title: "Untitled 04", tag: "portraits", layout: "" },
  { src: "images/photo-05.jpg", title: "Untitled 05", tag: "street", layout: "tall" },
  { src: "images/photo-06.jpg", title: "Untitled 06", tag: "landscape", layout: "wide" },
  { src: "images/photo-07.jpg", title: "Untitled 07", tag: "street", layout: "" },
  { src: "images/photo-08.jpg", title: "Untitled 08", tag: "portraits", layout: "" },
];

const grid = document.getElementById("grid");
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

// Render gallery
let activeFilter = "all";
let activeIndex = 0;

function filteredPhotos() {
  if (activeFilter === "all") return photos;
  return photos.filter(p => p.tag === activeFilter);
}

function render() {
  const list = filteredPhotos();
  grid.innerHTML = "";

  list.forEach((p, i) => {
    const card = document.createElement("button");
    card.className = `card ${p.layout ? `card--${p.layout}` : ""}`.trim();
    card.setAttribute("type", "button");
    card.setAttribute("aria-label", `Open ${p.title}`);

    card.innerHTML = `
      <img src="${p.src}" alt="${p.title}" loading="lazy" />
      <div class="card__meta" aria-hidden="true">
        <span class="card__title">${p.title}</span>
        <span class="card__tag">${p.tag}</span>
      </div>
    `;

    card.addEventListener("click", () => openLightbox(i));
    grid.appendChild(card);
  });
}

render();

// Filters
document.querySelectorAll(".chip").forEach(btn => {
  btn.addEventListener("click", () => {
    document.querySelectorAll(".chip").forEach(b => {
      b.classList.remove("is-active");
      b.setAttribute("aria-selected", "false");
    });
    btn.classList.add("is-active");
    btn.setAttribute("aria-selected", "true");

    activeFilter = btn.dataset.filter;
    render();
  });
});

// Lightbox
const lightbox = document.getElementById("lightbox");
const lightboxImg = document.getElementById("lightboxImg");
const lightboxCaption = document.getElementById("lightboxCaption");
const closeLightboxBtn = document.getElementById("closeLightbox");
const prevBtn = document.getElementById("prevBtn");
const nextBtn = document.getElementById("nextBtn");

function openLightbox(i) {
  const list = filteredPhotos();
  activeIndex = i;

  const p = list[activeIndex];
  lightboxImg.src = p.src;
  lightboxImg.alt = p.title;
  lightboxCaption.textContent = `${p.title} • ${p.tag}`;

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
  const list = filteredPhotos();
  activeIndex = (activeIndex + dir + list.length) % list.length;
  openLightbox(activeIndex);
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
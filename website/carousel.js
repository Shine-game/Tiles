const carousel = document.querySelector(".carousel");
const slides = [...carousel.querySelectorAll("figure")];
const controls = carousel.querySelector(".carousel-controls");
const rotation = carousel.querySelector("[data-rotate]");
const status = carousel.querySelector('[role="status"]');

let index = 0;
let timer;

function showSlide(step, announce = false) {
  slides[index].hidden = true;
  index = (index + step + slides.length) % slides.length;
  slides[index].hidden = false;

  if (announce) status.textContent = slides[index].querySelector("figcaption").textContent;
}

function setRotation(enabled) {
  clearInterval(timer);
  timer = enabled ? setInterval(() => showSlide(1), 7000) : undefined;
  rotation.textContent = enabled ? "Pause" : "Play";
}

controls.addEventListener("click", (event) => {
  const button = event.target.closest("button");
  if (!button) return;

  if (button === rotation) {
    setRotation(timer === undefined);
  } else {
    setRotation(false);
    showSlide(Number(button.dataset.step), true);
  }
});

controls.hidden = false;
setRotation(!matchMedia("(prefers-reduced-motion: reduce)").matches);

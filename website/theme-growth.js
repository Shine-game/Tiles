const reduceMotion = matchMedia("(prefers-reduced-motion: reduce)");

for (const preview of document.querySelectorAll(".growth-preview")) {
  const image = preview.querySelector("img");
  const poster = image.getAttribute("src");

  function setPlaying(playing) {
    image.src = playing ? preview.dataset.animation : poster;
    preview.setAttribute("aria-pressed", String(playing));
  }

  preview.addEventListener("pointerenter", (event) => {
    if (event.pointerType === "mouse" && !reduceMotion.matches) setPlaying(true);
  });
  preview.addEventListener("pointerleave", (event) => {
    if (event.pointerType === "mouse") setPlaying(false);
  });
  preview.addEventListener("click", () => {
    setPlaying(preview.getAttribute("aria-pressed") === "false");
  });
}

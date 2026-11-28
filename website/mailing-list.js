const signup = document.querySelector(".mailing-signup");
const email = document.querySelector("#signup-email");

signup.addEventListener("submit", (event) => {
  event.preventDefault();
  const body = `Please subscribe ${email.value} to the SIMIS mailing list. I agree to receive the free theme promo code and the Google Play launch announcement at this address.`;
  window.location.href = `${signup.action}&body=${encodeURIComponent(body)}`;
});

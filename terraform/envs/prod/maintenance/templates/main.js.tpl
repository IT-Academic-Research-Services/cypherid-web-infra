'use strict';

/* ─────────────────────────────────────────────────────────────────────────────
   CONFIGURATION
   After deploying the backend, replace the placeholder below with the
   API Gateway endpoint URL output by the CloudFormation stack or deploy script.
   Example: https://abc123xyz.execute-api.us-west-2.amazonaws.com/prod/signup
───────────────────────────────────────────────────────────────────────────── */
const API_ENDPOINT = `${REPLACE_WITH_API_GATEWAY_ENDPOINT}`;

/* ---- Mobile Nav ---- */
const navToggle = document.getElementById('navToggle');
const navLinks  = document.querySelector('.nav-links');

if (navToggle && navLinks) {
  navToggle.addEventListener('click', () => {
    navLinks.classList.toggle('open');
    navToggle.setAttribute('aria-expanded', navLinks.classList.contains('open'));
  });
  navLinks.querySelectorAll('a').forEach(link => {
    link.addEventListener('click', () => navLinks.classList.remove('open'));
  });
}

/* ---- FAQ Accordion ---- */
document.querySelectorAll('.faq-question').forEach(btn => {
  btn.addEventListener('click', () => {
    const item   = btn.closest('.faq-item');
    const isOpen = item.classList.contains('open');
    document.querySelectorAll('.faq-item').forEach(i => i.classList.remove('open'));
    document.querySelectorAll('.faq-question').forEach(b => b.setAttribute('aria-expanded', 'false'));
    if (!isOpen) {
      item.classList.add('open');
      btn.setAttribute('aria-expanded', 'true');
    }
  });
});

/* ---- Mailing List Form ---- */
const form         = document.getElementById('waitlistForm');
const formSuccess  = document.getElementById('formSuccess');
const successEmail = document.getElementById('successEmail');
const submitBtn    = form ? form.querySelector('button[type="submit"]') : null;

function showFieldError(field, message) {
  const group = field.closest('.form-group');
  group.classList.add('has-error');
  field.classList.add('error');
  if (!group.querySelector('.field-error')) {
    const err       = document.createElement('span');
    err.className   = 'field-error';
    err.textContent = message;
    group.appendChild(err);
  }
}

function clearFieldError(field) {
  const group    = field.closest('.form-group');
  group.classList.remove('has-error');
  field.classList.remove('error');
  const existing = group.querySelector('.field-error');
  if (existing) existing.remove();
}

function showFormError(message) {
  let banner = form.querySelector('.form-error-banner');
  if (!banner) {
    banner           = document.createElement('div');
    banner.className = 'form-error-banner';
    form.prepend(banner);
  }
  banner.textContent   = message;
  banner.style.display = 'block';
}

function clearFormError() {
  const banner = form && form.querySelector('.form-error-banner');
  if (banner) banner.style.display = 'none';
}

function setLoading(loading) {
  if (!submitBtn) return;
  submitBtn.disabled    = loading;
  submitBtn.textContent = loading ? 'Submitting\u2026' : 'Join the Mailing List';
}

if (form) {
  form.addEventListener('submit', async (e) => {
    e.preventDefault();
    clearFormError();

    const nameField        = document.getElementById('wl-name');
    const emailField       = document.getElementById('wl-email');
    const institutionField = document.getElementById('wl-institution');
    const focusField       = document.getElementById('wl-role');

    // Clear previous field errors
    [nameField, emailField, institutionField].forEach(clearFieldError);

    // Client-side validation
    let valid = true;
    if (!nameField.value.trim()) {
      showFieldError(nameField, 'Please enter your name.');
      valid = false;
    }
    const emailRegex = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;
    if (!emailField.value.trim() || !emailRegex.test(emailField.value.trim())) {
      showFieldError(emailField, 'Please enter a valid email address.');
      valid = false;
    }
    if (!institutionField.value.trim()) {
      showFieldError(institutionField, 'Please enter your institution.');
      valid = false;
    }
    if (!valid) return;

    setLoading(true);

    const payload = {
      name:        nameField.value.trim(),
      email:       emailField.value.trim(),
      institution: institutionField.value.trim(),
      focus:       focusField ? focusField.value : '',
    };

    try {
      const response = await fetch(API_ENDPOINT, {
        method:  'POST',
        headers: { 'Content-Type': 'application/json' },
        body:    JSON.stringify(payload),
      });

      const result = await response.json();

      if (response.ok) {
        if (successEmail) successEmail.textContent = payload.email;
        form.style.display        = 'none';
        formSuccess.style.display = 'block';
      } else {
        showFormError(result.error || 'Something went wrong. Please try again.');
        setLoading(false);
      }
    } catch (err) {
      console.error('Signup error:', err);
      // Dev/preview mode — show success if API not yet wired up
      if (API_ENDPOINT === `${REPLACE_WITH_API_GATEWAY_ENDPOINT}`) {
        if (successEmail) successEmail.textContent = payload.email;
        form.style.display        = 'none';
        formSuccess.style.display = 'block';
      } else {
        showFormError('Unable to connect. Please check your connection and try again.');
        setLoading(false);
      }
    }
  });

  // Clear field errors on input
  form.querySelectorAll('input, select').forEach(field => {
    field.addEventListener('input', () => clearFieldError(field));
  });
}

/* ---- Smooth scroll offset for sticky nav ---- */
document.querySelectorAll('a[href^="#"]').forEach(anchor => {
  anchor.addEventListener('click', function (e) {
    const target = document.querySelector(this.getAttribute('href'));
    if (target) {
      e.preventDefault();
      const top = target.getBoundingClientRect().top + window.pageYOffset - 80;
      window.scrollTo({ top, behavior: 'smooth' });
    }
  });
});

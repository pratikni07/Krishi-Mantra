/* ============================================================
   Krishi Mantra Landing Page — Interactions & Animations
   ============================================================ */

// ─── Navbar Scroll Effect ───
const navbar = document.getElementById('navbar');
const hamburger = document.getElementById('hamburger');
const navLinks = document.getElementById('navLinks');

let lastScrollY = 0;

window.addEventListener('scroll', () => {
    const scrollY = window.scrollY;

    if (scrollY > 50) {
        navbar.classList.add('scrolled');
    } else {
        navbar.classList.remove('scrolled');
    }

    lastScrollY = scrollY;
}, { passive: true });


// ─── Mobile Menu Toggle ───
hamburger.addEventListener('click', () => {
    hamburger.classList.toggle('active');
    navLinks.classList.toggle('open');
    document.body.style.overflow = navLinks.classList.contains('open') ? 'hidden' : '';
});

function closeMenu() {
    hamburger.classList.remove('active');
    navLinks.classList.remove('open');
    document.body.style.overflow = '';
}

// Make closeMenu available globally for inline onclick handlers
window.closeMenu = closeMenu;


// ─── Scroll Animations (IntersectionObserver) ───
const animateElements = document.querySelectorAll('[data-animate]');

const observerOptions = {
    threshold: 0.15,
    rootMargin: '0px 0px -40px 0px',
};

const animationObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
        if (entry.isIntersecting) {
            const el = entry.target;
            const delay = el.getAttribute('data-delay') || 0;

            setTimeout(() => {
                el.classList.add('animated');
            }, parseInt(delay));

            animationObserver.unobserve(el);
        }
    });
}, observerOptions);

animateElements.forEach((el) => {
    animationObserver.observe(el);
});


// ─── Stats Counter Animation ───
function animateCounter(el, target) {
    const duration = 2000;
    const start = performance.now();
    const startVal = 0;

    function update(now) {
        const elapsed = now - start;
        const progress = Math.min(elapsed / duration, 1);

        // Ease out cubic
        const eased = 1 - Math.pow(1 - progress, 3);
        const current = Math.floor(startVal + (target - startVal) * eased);

        el.textContent = current.toLocaleString('en-IN');

        if (progress < 1) {
            requestAnimationFrame(update);
        }
    }

    requestAnimationFrame(update);
}

const statsSection = document.getElementById('stats');
let statsAnimated = false;

const statsObserver = new IntersectionObserver((entries) => {
    entries.forEach((entry) => {
        if (entry.isIntersecting && !statsAnimated) {
            statsAnimated = true;

            const counters = document.querySelectorAll('.stats__number[data-target]');
            counters.forEach((counter) => {
                const target = parseInt(counter.getAttribute('data-target'));
                animateCounter(counter, target);
            });

            statsObserver.unobserve(entry.target);
        }
    });
}, { threshold: 0.3 });

if (statsSection) {
    statsObserver.observe(statsSection);
}


// ─── Smooth Scroll for Anchor Links ───
document.querySelectorAll('a[href^="#"]').forEach((anchor) => {
    anchor.addEventListener('click', (e) => {
        const targetId = anchor.getAttribute('href');
        if (targetId === '#') return;

        const target = document.querySelector(targetId);
        if (target) {
            e.preventDefault();
            const offsetTop = target.getBoundingClientRect().top + window.scrollY - 80;
            window.scrollTo({ top: offsetTop, behavior: 'smooth' });
        }
    });
});


// ─── Active Nav Link on Scroll ───
const sections = document.querySelectorAll('section[id]');

function updateActiveLink() {
    const scrollY = window.scrollY + 120;

    sections.forEach((section) => {
        const top = section.offsetTop;
        const height = section.offsetHeight;
        const id = section.getAttribute('id');
        const link = document.querySelector(`.navbar__link[href="#${id}"]`);

        if (link) {
            if (scrollY >= top && scrollY < top + height) {
                link.style.opacity = '1';
                link.style.fontWeight = '600';
            } else {
                link.style.opacity = '';
                link.style.fontWeight = '';
            }
        }
    });
}

window.addEventListener('scroll', updateActiveLink, { passive: true });


// ─── Parallax-lite for Hero shapes ───
window.addEventListener('mousemove', (e) => {
    const shapes = document.querySelectorAll('.hero__shape');
    const x = (e.clientX / window.innerWidth - 0.5) * 2;
    const y = (e.clientY / window.innerHeight - 0.5) * 2;

    shapes.forEach((shape, i) => {
        const speed = (i + 1) * 8;
        shape.style.transform = `translate(${x * speed}px, ${y * speed}px)`;
    });
}, { passive: true });


// ============================================================
//  IoT Product Modal & Registration Form
// ============================================================

const productDetails = {
  auto_pump: {
    title: 'Auto Pump Starter',
    subtitle: 'Smart Water Management System',
    description: 'Transform your irrigation with our intelligent auto pump system. Automatically control water pumps based on soil moisture levels, scheduled timings, and weather conditions.',
    features: [
      'Remote pump on/off control from your mobile phone',
      'Schedule automatic watering times (morning, evening, or custom)',
      'Real-time water usage and electricity consumption tracking',
      'Automatic shut-off when soil moisture threshold is reached',
      'SMS/push alerts for pump status and errors',
      'Integration with soil moisture sensors',
      'Power surge and overload protection',
      'Compatible with single and three-phase pumps',
      'Weather-based irrigation recommendations',
      'Historical usage analytics and reports'
    ],
    testimonials: [
      {
        text: 'The auto pump has saved me ₹3000 per month in electricity costs. It waters my fields exactly when needed, no more, no less.',
        author: 'Ramesh Kumar, Maharashtra'
      },
      {
        text: 'I can now control my pump from anywhere. Even when I\'m in the city, my farm gets watered on schedule.',
        author: 'Suresh Patil, Karnataka'
      }
    ]
  },
  krishi_doctor: {
    title: 'Krishi Doctor',
    subtitle: 'Complete Crop Health Monitoring System',
    description: 'Your 24/7 crop health expert. Monitor soil nutrients, weather conditions, and get AI-powered insights to maximize your crop yield and prevent diseases before they spread.',
    features: [
      'Soil NPK (Nitrogen, Phosphorus, Potassium) level monitoring',
      'Soil pH, moisture, and temperature tracking',
      'Weather station: humidity, rainfall, wind speed, atmospheric pressure',
      'Light intensity measurement for optimal growth',
      'AI-powered disease and pest prediction alerts',
      'Crop-specific recommendations based on real-time data',
      'Historical trend analysis with graphs and charts',
      'Fertilizer application suggestions based on NPK levels',
      'Irrigation recommendations based on soil moisture',
      'Integration with Krishi Mantra app for expert consultations'
    ],
    testimonials: [
      {
        text: 'Krishi Doctor detected low nitrogen in my wheat field before visible symptoms appeared. Early fertilizer application saved my entire crop.',
        author: 'Vijay Singh, Punjab'
      },
      {
        text: 'The weather alerts helped me protect my tomatoes from an unexpected frost. Worth every rupee!',
        author: 'Lakshmi Devi, Tamil Nadu'
      }
    ]
  }
};

function openProductModal(deviceType) {
  const modal = document.getElementById('productModal');
  const modalBody = document.getElementById('modalBody');
  const product = productDetails[deviceType];

  if (!product) return;

  const deviceDisplayName = deviceType === 'auto_pump' ? 'Auto Pump Starter' : 'Krishi Doctor';

  modalBody.innerHTML = `
    <div class="modal__header">
      <h2 class="modal__title">${product.title}</h2>
      <p class="modal__subtitle">${product.subtitle}</p>
    </div>

    <div class="modal__section">
      <p style="color: var(--color-text-secondary); line-height: 1.7; font-size: 1.05rem;">
        ${product.description}
      </p>
    </div>

    <div class="modal__section">
      <h3 class="modal__section-title">Key Features</h3>
      <ul class="modal__features">
        ${product.features.map(feature => `<li>${feature}</li>`).join('')}
      </ul>
    </div>

    <div class="modal__testimonials">
      <h3 class="modal__section-title">What Farmers Say</h3>
      ${product.testimonials.map(testimonial => `
        <div class="modal__testimonial">
          <div class="modal__testimonial-stars">★★★★★</div>
          <p class="modal__testimonial-text">"${testimonial.text}"</p>
          <p class="modal__testimonial-author">— ${testimonial.author}</p>
        </div>
      `).join('')}
    </div>

    <div class="registration-form">
      <h3 class="registration-form__title">Register Your Interest</h3>
      <form id="deviceRegistrationForm" onsubmit="submitRegistration(event, '${deviceType}')">
        <div class="form-group">
          <label for="name">Full Name <span class="required">*</span></label>
          <input type="text" id="name" name="name" placeholder="Enter your full name" required>
        </div>
        
        <div class="form-group">
          <label for="phone">Phone Number <span class="required">*</span></label>
          <input type="tel" id="phone" name="phone" placeholder="10-digit mobile number" pattern="[0-9]{10}" inputmode="numeric" required>
        </div>
        
        <div class="form-group">
          <label for="email">Email (Optional)</label>
          <input type="email" id="email" name="email" placeholder="your.email@example.com">
        </div>
        
        <div class="form-group">
          <label for="address">Address <span class="required">*</span></label>
          <textarea id="address" name="address" placeholder="Village, Taluka, District, State" required></textarea>
        </div>

        <input type="hidden" name="deviceType" value="${deviceType}">
        
        <button type="submit" class="form-submit" id="submitBtn">
          Register Interest for ${deviceDisplayName}
        </button>

        <div id="formMessage"></div>
      </form>
    </div>
  `;

  modal.classList.add('active');
  document.body.style.overflow = 'hidden';
}

function closeProductModal() {
  const modal = document.getElementById('productModal');
  modal.classList.remove('active');
  document.body.style.overflow = '';
}

// Close modal on Escape key
document.addEventListener('keydown', (e) => {
  if (e.key === 'Escape') {
    closeProductModal();
  }
});

async function submitRegistration(event, deviceType) {
  event.preventDefault();

  const form = event.target;
  const submitBtn = document.getElementById('submitBtn');
  const formMessage = document.getElementById('formMessage');
  
  // Get form data
  const formData = {
    name: form.name.value.trim(),
    phone: form.phone.value.trim(),
    email: form.email.value.trim() || undefined,
    address: form.address.value.trim(),
    deviceType: deviceType
  };

  // Disable submit button
  submitBtn.disabled = true;
  submitBtn.textContent = 'Submitting...';
  formMessage.innerHTML = '';

  try {
    // Determine API URL based on environment
    const apiUrl = window.location.hostname === 'localhost' || window.location.hostname === '127.0.0.1'
      ? 'http://localhost:3002/api/device-registration'
      : '/api/device-registration';

    const response = await fetch(apiUrl, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
      },
      body: JSON.stringify(formData)
    });

    const result = await response.json();

    if (response.ok && result.success) {
      formMessage.innerHTML = '<div class="form-message success">✓ Registration submitted successfully! Our team will contact you soon.</div>';
      form.reset();
      
      // Auto-close modal after 3 seconds
      setTimeout(() => {
        closeProductModal();
      }, 3000);
    } else {
      throw new Error(result.message || 'Failed to submit registration');
    }
  } catch (error) {
    console.error('Registration error:', error);
    formMessage.innerHTML = `<div class="form-message error">✗ ${error.message || 'Something went wrong. Please try again.'}</div>`;
  } finally {
    submitBtn.disabled = false;
    submitBtn.textContent = `Register Interest for ${deviceType === 'auto_pump' ? 'Auto Pump Starter' : 'Krishi Doctor'}`;
  }
}

// Make functions globally available
window.openProductModal = openProductModal;
window.closeProductModal = closeProductModal;
window.submitRegistration = submitRegistration;

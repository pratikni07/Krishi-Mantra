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

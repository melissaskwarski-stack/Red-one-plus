import { characters } from './characters.js';

// ── Remove white PNG backgrounds ─────────────────────────────────────────────
function removeWhiteBg(img) {
    const process = () => {
        if (img.src.endsWith('.svg')) return;
        const deg = parseInt(img.dataset.rotate || '0');
        const c = document.createElement('canvas');
        // Swap dimensions for 90/270 rotations (not needed for 180 but handles future cases)
        c.width  = (deg % 180 === 0) ? img.naturalWidth  : img.naturalHeight;
        c.height = (deg % 180 === 0) ? img.naturalHeight : img.naturalWidth;
        const ctx = c.getContext('2d');
        ctx.translate(c.width / 2, c.height / 2);
        ctx.rotate(deg * Math.PI / 180);
        ctx.drawImage(img, -img.naturalWidth / 2, -img.naturalHeight / 2);
        ctx.resetTransform();
        const id = ctx.getImageData(0, 0, c.width, c.height);
        const d = id.data;
        for (let i = 0; i < d.length; i += 4) {
            const r = d[i], g = d[i + 1], b = d[i + 2];
            const max = Math.max(r, g, b);
            const min = Math.min(r, g, b);
            const avg = (r + g + b) / 3;
            // Saturation: 0 = pure gray/white, 1 = fully saturated colour
            const sat = max > 0 ? (max - min) / max : 0;
            // Target only bright + low-saturation pixels (white / near-white)
            // This leaves coloured pixels (gold, red, blue) completely untouched
            if (avg > 180 && sat < 0.18) {
                const fade = Math.min(1, (avg - 180) / 75); // 0→1 as avg goes 180→255
                d[i + 3] = Math.round(d[i + 3] * (1 - fade));
            }
        }
        ctx.putImageData(id, 0, 0);
        img.src = c.toDataURL('image/png');
    };
    if (img.complete && img.naturalWidth) process();
    else img.addEventListener('load', process, { once: true });
}

document.querySelectorAll('.plane-display img').forEach(removeWhiteBg);

// ── Starfield ────────────────────────────────────────────────────────────────
const canvas = document.createElement('canvas');
canvas.style.cssText = 'position:fixed;inset:0;width:100%;height:100%;z-index:0;pointer-events:none;';
document.body.prepend(canvas);
const ctx = canvas.getContext('2d');

function resize() { canvas.width = window.innerWidth; canvas.height = window.innerHeight; }
resize();
window.addEventListener('resize', resize);

// Three layers: small dim stars, medium stars, a few bright ones
const stars = Array.from({ length: 220 }, (_, i) => ({
    x:     Math.random(),
    y:     Math.random(),
    r:     i < 160 ? Math.random() * 0.7 + 0.2
         : i < 200 ? Math.random() * 1.0 + 0.5
         :            Math.random() * 1.4 + 0.8,
    alpha: i < 160 ? Math.random() * 0.35 + 0.1
         : i < 200 ? Math.random() * 0.5  + 0.2
         :            Math.random() * 0.6  + 0.35,
    speed: Math.random() * 0.06 + 0.02,
    phase: Math.random() * Math.PI * 2,
}));

const comets = [];
function createComet() {
    comets.push({
        x: Math.random() * canvas.width,
        y: -50,
        vx: (Math.random() - 0.5) * 8,
        vy: Math.random() * 10 + 10,
        len: Math.random() * 80 + 40,
        alpha: 1
    });
}

(function tick(ts) {
    ctx.clearRect(0, 0, canvas.width, canvas.height);
    const t = ts * 0.001;
    
    // Stars
    stars.forEach(s => {
        const a = s.alpha * (0.6 + 0.4 * Math.sin(t * 0.9 + s.phase));
        ctx.beginPath();
        ctx.arc(s.x * canvas.width, s.y * canvas.height, s.r, 0, Math.PI * 2);
        ctx.fillStyle = `rgba(255,255,255,${a.toFixed(2)})`;
        ctx.fill();
        s.y += s.speed / canvas.height;
        if (s.y > 1) { s.y = 0; s.x = Math.random(); }
    });

    // Comets
    if (Math.random() < 0.02) createComet();
    for (let i = comets.length - 1; i >= 0; i--) {
        const c = comets[i];
        ctx.beginPath();
        const grad = ctx.createLinearGradient(c.x, c.y, c.x - c.vx * c.len * 0.1, c.y - c.vy * c.len * 0.1);
        grad.addColorStop(0, `rgba(255,255,255,${c.alpha})`);
        grad.addColorStop(1, 'transparent');
        ctx.strokeStyle = grad;
        ctx.lineWidth = 2;
        ctx.moveTo(c.x, c.y);
        ctx.lineTo(c.x - c.vx * c.len * 0.1, c.y - c.vy * c.len * 0.1);
        ctx.stroke();
        
        c.x += c.vx;
        c.y += c.vy;
        c.alpha -= 0.01;
        if (c.alpha <= 0) comets.splice(i, 1);
    }

    requestAnimationFrame(tick);
})(0);

// ── Stat bar stagger animation ───────────────────────────────────────────────
setTimeout(() => {
    document.querySelectorAll('.stat-bar-fill').forEach((el, i) => {
        setTimeout(() => { el.style.width = el.dataset.width + '%'; }, i * 90);
    });
}, 250);

// ── Background Parallax ──────────────────────────────────────────────────────
document.addEventListener('mousemove', (e) => {
    const x = (e.clientX / window.innerWidth - 0.5) * 2;
    const y = (e.clientY / window.innerHeight - 0.5) * 2;
    
    // Parallax for nebula layers
    document.body.style.setProperty('--px', `${x * 15}px`);
    document.body.style.setProperty('--py', `${y * 15}px`);
    
    // Slight shift for the starfield canvas
    canvas.style.transform = `translate(${x * 5}px, ${y * 5}px)`;
});

// ── Card Tilt & Selection ────────────────────────────────────────────────────
let selectedCharId = null;
const cards   = document.querySelectorAll('.char-card');
const startBtn = document.getElementById('start-game');

cards.forEach(card => {
    card.addEventListener('mousemove', (e) => {
        const rect = card.getBoundingClientRect();
        const x = e.clientX - rect.left;
        const y = e.clientY - rect.top;
        
        const xc = rect.width / 2;
        const yc = rect.height / 2;
        
        const dx = (x - xc) / (rect.width / 2);
        const dy = (y - yc) / (rect.height / 2);
        
        card.style.transform = `perspective(1000px) rotateY(${dx * 12}deg) rotateX(${-dy * 12}deg) translateY(-14px) scale(1.04)`;
        
        // Add a "shine" effect based on mouse position
        const inner = card.querySelector('.card-inner');
        inner.style.background = `radial-gradient(circle at ${x}px ${y}px, rgba(255,255,255,0.08) 0%, transparent 70%)`;
    });

    card.addEventListener('mouseleave', () => {
        if (!card.classList.contains('selected')) {
            card.style.transform = '';
        } else {
            card.style.transform = 'translateY(-8px) scale(1.01)';
        }
        card.querySelector('.card-inner').style.background = '';
    });

    card.addEventListener('click', () => {
        // Trigger selection burst effect
        const rect = card.getBoundingClientRect();
        createBurst(rect.left + rect.width / 2, rect.top + rect.height / 2, card.dataset.color || '#fff');

        cards.forEach(c => c.classList.remove('selected'));
        card.classList.add('selected');
        selectedCharId = card.id;
        startBtn.classList.add('active');
        console.log(`Selected: ${characters[selectedCharId].name}`);
    });
});

// ── Selection Burst Effect ───────────────────────────────────────────────────
function createBurst(x, y, color) {
    const burst = document.createElement('div');
    burst.className = 'selection-burst';
    burst.style.left = `${x}px`;
    burst.style.top = `${y}px`;
    burst.style.setProperty('--burst-color', color);
    document.body.appendChild(burst);
    setTimeout(() => burst.remove(), 800);
}

startBtn.addEventListener('click', () => {
    if (!selectedCharId) return;
    const { name, skill } = characters[selectedCharId];
    alert(`Mission Initiated with ${name}!\nSkill: ${skill.name}\n${skill.description}`);
});

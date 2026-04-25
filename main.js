import { characters } from './characters.js';

let selectedCharId = null;

const cards = document.querySelectorAll('.char-card');
const startBtn = document.getElementById('start-game');

cards.forEach(card => {
    card.addEventListener('click', () => {
        // Remove selection from others
        cards.forEach(c => c.classList.remove('selected'));
        
        // Add selection to current
        card.classList.add('selected');
        selectedCharId = card.id;
        
        // Enable start button
        startBtn.classList.add('active');
        
        console.log(`Selected: ${characters[selectedCharId].name}`);
    });
});

startBtn.addEventListener('click', () => {
    if (selectedCharId) {
        const charData = characters[selectedCharId];
        alert(`Mission Initiated with ${charData.name}!\nSkill: ${charData.skill.name}\n${charData.skill.description}`);
        // Here you would transition to the game scene
    }
});

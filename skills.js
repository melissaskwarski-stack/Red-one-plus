export const skills = {
    'Afterburner': (player) => {
        console.log(`${player.name} activated Afterburner!`);
        // Logic for speed boost
        const originalSpeed = player.speed;
        player.speed *= 2;
        setTimeout(() => {
            player.speed = originalSpeed;
            console.log('Afterburner expired.');
        }, 3000);
    },
    'Plasma Shield': (player) => {
        console.log(`${player.name} activated Plasma Shield!`);
        // Logic for shield
        player.isShielded = true;
        setTimeout(() => {
            player.isShielded = false;
            console.log('Plasma Shield expired.');
        }, 3000);
    },
    'Multi-Barrage': (player) => {
        console.log(`${player.name} activated Multi-Barrage!`);
        // Logic for multi-shot
        player.shotPattern = 'spread';
        setTimeout(() => {
            player.shotPattern = 'normal';
            console.log('Multi-Barrage expired.');
        }, 5000);
    }
};

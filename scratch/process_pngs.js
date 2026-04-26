const { Jimp } = require('jimp');
const path = require('path');

async function processImage(filename, rotateDeg = 0) {
    const inputPath = path.join(__dirname, '../assets', filename);
    const outputPath = path.join(__dirname, '../assets', filename);
    
    try {
        const image = await Jimp.read(inputPath);
        
        // Remove white background BEFORE rotation to keep it simple
        const { data } = image.bitmap;
        for (let i = 0; i < data.length; i += 4) {
            const r = data[i], g = data[i+1], b = data[i+2];
            if (r > 240 && g > 240 && b > 240) {
                data[i+3] = 0;
            }
        }

        // Rotate clockwise (-90 in some libs, or 90 with CCW)
        // I'll try -90 for clockwise.
        if (rotateDeg !== 0) {
            image.rotate(rotateDeg);
        }

        await image.write(outputPath);
        console.log(`Processed ${filename} - Rotated ${rotateDeg}deg`);
    } catch (err) {
        console.error(`Error processing ${filename}:`, err);
    }
}

async function start() {
    // Red and Blue are already Top-facing in the original files? 
    // Let me check Red and Blue too.
    await processImage('red_plane.png', 0);
    await processImage('blue_plane.png', 0);
    await processImage('gold_plane.png', -90); // Try -90 for clockwise
}

start();

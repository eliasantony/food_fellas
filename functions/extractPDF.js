const puppeteer = require('puppeteer');

(async () => {
    const url = 'https://www.gutekueche.at/lachsnudeln-rezept-1375';

    const browser = await puppeteer.launch({ headless: true });
    const page = await browser.newPage();

    // Open the recipe page
    await page.goto(url, { waitUntil: 'networkidle2' });

    // Wait for print-friendly elements if needed
    await page.waitForSelector('body');

    // Generate PDF
    await page.pdf({ path: 'recipe.pdf', format: 'A4', printBackground: true });

    console.log('PDF saved as recipe.pdf');

    await browser.close();
})();
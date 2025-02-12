const puppeteer = require('puppeteer');
const fs = require('fs');
const path = require('path');

/**
 * Site-specific "print" URL transformations 
 * and any special logic for each domain.
 * 
 * E.g., "allrecipes.com" appends "?print" if not present,
 * "chefkoch.de" uses "/rezepte/drucken/ID" style,
 * "thekitchn.com" might require a certain fragment, etc.
 */
const PRINT_URL_PATTERNS = {
  'allrecipes.com': (url) => {
    // For allrecipes, if `?print` is not in the URL, add it.
    if (!url.includes('?print')) {
      return url.includes('?') ? url + '&print' : url + '?print';
    }
    return url;
  },
  'chefkoch.de': (url) => {
    // Chefkoch can transform: 
    //   https://www.chefkoch.de/rezepte/1578671265353584/Chili-con-Carne.html
    // into:
    //   https://www.chefkoch.de/rezepte/drucken/1578671265353584/Chili-con-Carne.html
    // so we replace "/rezepte/" with "/rezepte/drucken/" if not already done.
    // This is a naive approach; you might refine it with regex, etc.
    if (!url.includes('/rezepte/drucken/')) {
      return url.replace('/rezepte/', '/rezepte/drucken/');
    }
    return url;
  },
  'gutekueche.at': (url) => {
    // gutekueche.at doesn’t have a simple “?print” pattern
    // There's a "print to PDF" button, but no direct print view.
    // We'll keep the original URL for now.
    return url;
  },
  'einfachbacken.de': (url) => {
    // No known print URL param. Keep the original.
    return url;
  },
  'ichkoche.at': (url) => {
    // No known direct print URL. Keep the original.
    return url;
  },
  'oetker.at': (url) => {
    // Might be forced to rely on a user pressing Ctrl+P in the real site.
    // No direct print URL known. Keep the original.
    return url;
  },
  'thekitchn.com': (url) => {
    // The user mentions that The Kitchn’s print button transforms the URL
    // to something with "#:~:text=SAVE-,PRINT,-SHARE" in it. 
    // We can’t easily replicate that in a stable manner, so we might just keep the original
    // or try to do a manual click on the "print" button in domainExtractors if needed.
    return url;
  }
};

/**
 * Domain-specific extraction logic:
 * We define how to pull the recipe from each site (title, ingredients, instructions, or 
 * the main container) so we can create a structured snippet or text dump.
 */
const domainExtractors = {
  // ========== ALLRECIPES ==========
  "allrecipes.com": {
    printUrl: PRINT_URL_PATTERNS['allrecipes.com'],
    extract: async (page) => {
      // Example known selectors (may differ by article):
      const titleSel = 'h1.recipe-summary__h1, h1.headline';
      const ingredientsSel = 'span.recipe-ingred_txt, li.ingredients-item';
      const instructionsSel = 'span.recipe-directions__list--item, li.instructions-section-item';

      const title = await page.$eval(titleSel, el => el.innerText.trim()).catch(() => null);
      const ingredients = await page.$$eval(ingredientsSel, els =>
        els.map(el => el.innerText.trim()).filter(Boolean)
      ).catch(() => []);
      const instructions = await page.$$eval(instructionsSel, els =>
        els.map(el => el.innerText.trim()).filter(Boolean)
      ).catch(() => []);

      return { title, ingredients, instructions };
    }
  },

  // ========== CHEFKOCH.DE ==========
  "chefkoch.de": {
    printUrl: PRINT_URL_PATTERNS['chefkoch.de'],
    extract: async (page) => {
      // In the print view: main content is in <main class="ds-container print"></main>
      // We can just pull the entire <main> innerText or further parse out by sub selectors.
      const mainSel = 'main.ds-container.print';

      // Some basic approach: just get the entire block of text
      const mainText = await page.$eval(mainSel, el => el.innerText).catch(() => null);
      return { fullText: mainText || '' };
    }
  },

  // ========== GUTEKUECHE.AT ==========
  "gutekueche.at": {
    printUrl: PRINT_URL_PATTERNS['gutekueche.at'],
    extract: async (page) => {
      // You mentioned the main container might be <article data-article="RZT/xxxx" id="recipe">
      const articleSel = 'article#recipe';

      const handle = await page.$(articleSel);
      if (handle) {
        const articleText = await page.evaluate(el => el.innerText, handle).catch(() => '');
        return { fullText: articleText.trim() };
      }

      // fallback
      return { fullText: await page.evaluate(() => document.body.innerText) };
    }
  },

  // ========== EINFACHBACKEN.DE ==========
  "einfachbacken.de": {
    printUrl: PRINT_URL_PATTERNS['einfachbacken.de'],
    extract: async (page) => {
      // They have `<div id="block-recipeheading"></div>` for heading
      // and `<div class="recipe recipe--full"></div>` for the recipe
      const headingSel = '#block-recipeheading';
      const recipeSel = '.recipe.recipe--full';

      const headingText = await page.$eval(headingSel, el => el.innerText.trim()).catch(() => null);
      const recipeText = await page.$eval(recipeSel, el => el.innerText.trim()).catch(() => null);

      return { title: headingText || '', fullText: recipeText || '' };
    }
  },

  // ========== ICHKOCHE.AT ==========
  "ichkoche.at": {
    printUrl: PRINT_URL_PATTERNS['ichkoche.at'],
    extract: async (page) => {
      // The name is in <h1 itemprop="name" class="page_title"></h1>
      // The content is in <div class="recipe_content"></div>
      const titleSel = 'h1.page_title[itemprop="name"]';
      const contentSel = 'div.recipe_content';

      const titleText = await page.$eval(titleSel, el => el.innerText.trim()).catch(() => null);
      const recipeContent = await page.$eval(contentSel, el => el.innerText.trim()).catch(() => null);

      return { title: titleText || '', fullText: recipeContent || '' };
    }
  },

  // ========== OETKER.AT ==========
  "oetker.at": {
    printUrl: PRINT_URL_PATTERNS['oetker.at'],
    extract: async (page) => {
      // No direct print URL. We'll just fallback to the body or attempt a known container.
      // You may need to open dev tools on the site to see if there's a specific container. 
      // This is just a fallback approach:
      const fallbackText = await page.evaluate(() => document.body.innerText).catch(() => '');
      return { fullText: fallbackText.trim() };
    }
  },

  // ========== THEKITCHN.COM ==========
  "thekitchn.com": {
    printUrl: PRINT_URL_PATTERNS['thekitchn.com'],
    extract: async (page) => {
      // They mention the print view has <div class="jsx-2539430080 jsx-965696149 Recipe"></div>
      // But that might only appear after clicking the print button. 
      // We'll try a direct selector anyway (it might or might not appear in normal view).
      const printSel = 'div.Recipe'; // or the class from your snippet
      const handle = await page.$(printSel);
      if (handle) {
        const text = await page.evaluate(el => el.innerText, handle).catch(() => '');
        return { fullText: text.trim() };
      }

      // fallback
      return { fullText: await page.evaluate(() => document.body.innerText).catch(() => '') };
    }
  },
};

/**
 * If there's no recognized domain-specific logic OR domain-specific extraction fails,
 * we attempt a fallback strategy scanning for known "recipe" blocks.
 */
async function fallbackExtract(page) {
  // Attempt to find something that looks like a recipe container
  const possibleSelectors = [
    '.recipe-main',
    '.recipe',
    '.content-recipe',
    '[itemtype*="Recipe"]',
    'article#recipe'
  ];

  for (let sel of possibleSelectors) {
    const handle = await page.$(sel);
    if (handle) {
      const text = await page.evaluate(el => el.innerText, handle).catch(() => '');
      if (text.trim()) return { fullText: text.trim() };
    }
  }

  // If no known container found, fallback to entire body
  const fallbackText = await page.evaluate(() => document.body.innerText).catch(() => '');
  return { fullText: fallbackText.trim() };
}

/**
 * Returns the domain (hostname minus 'www.' prefix) from a URL string.
 */
function getDomain(urlString) {
  try {
    const { hostname } = new URL(urlString);
    return hostname.replace(/^www\./, '');
  } catch (err) {
    console.error('Error parsing domain from URL:', err);
    return null;
  }
}

/**
 * Attempt to transform the URL into a "print view" if possible.
 * Otherwise, fallback to the original URL.
 */
function getPrintOrFallbackUrl(url) {
  const domain = getDomain(url);
  if (domain && PRINT_URL_PATTERNS[domain]) {
    return PRINT_URL_PATTERNS[domain](url);
  }
  return url; // no recognized pattern => use original
}

/**
 * The main function to parse a recipe from a given URL.
 */
async function parseRecipeWithPuppeteer(url) {
  const domain = getDomain(url);
  const knownExtractor = domain ? domainExtractors[domain] : null;
  const targetUrl = knownExtractor && knownExtractor.printUrl
    ? knownExtractor.printUrl(url)
    : url;

  let browser;
  try {
    browser = await puppeteer.launch({
      headless: 'new',  
      args: [
        '--no-sandbox',
        '--disable-setuid-sandbox'
      ],
    });

    const page = await browser.newPage();
    await page.setUserAgent(
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) ' +
      'AppleWebKit/537.36 (KHTML, like Gecko) ' +
      'Chrome/114.0.0.0 Safari/537.36'
    );

    // Go to the page
    await page.goto(targetUrl, {
      waitUntil: 'networkidle2',
      timeout: 60_000, // 60 seconds
    });

    // Use domain-specific extraction if we have one
    if (knownExtractor && knownExtractor.extract) {
      try {
        const data = await knownExtractor.extract(page);
        // If we got data, return it
        if (data && Object.keys(data).length > 0) {
          await browser.close();
          return data;
        }
      } catch (err) {
        console.warn(`Domain-specific extraction failed for ${domain}:`, err);
        // fallback below
      }
    }

    // Fallback approach
    const fallbackData = await fallbackExtract(page);
    await browser.close();
    return fallbackData;

  } catch (err) {
    console.error('Error in parseRecipeWithPuppeteer:', err);
    if (browser) {
      await browser.close();
    }
    throw err;
  }
}

/**
 * Utility to write extracted text (or data) to a .txt file,
 * for debugging or further processing offline.
 */
function writeToFile(filename, data) {
  // if data is an object with keys: {title, ingredients, instructions} or {fullText}, etc.
  const outPath = path.join(__dirname, filename);
  if (typeof data === 'object') {
    // Convert object to a readable format
    fs.writeFileSync(outPath, JSON.stringify(data, null, 2), 'utf-8');
  } else {
    // if it's just a string
    fs.writeFileSync(outPath, String(data), 'utf-8');
  }
  console.log(`\n---\nSaved output to ${outPath}\n`);
}

/**
 * Demo usage: pass in a URL from your terminal arguments or just hardcode one.
 * 
 * Usage:
 *   node extractRecipeFromWeb.js "https://www.chefkoch.de/rezepte/1578671265353584/Chili-con-Carne.html"
 */
(async () => {
  let inputUrl = process.argv[2];
  if (!inputUrl) {
    // fallback
    inputUrl = 'https://www.allrecipes.com/recipe/229021/blueberry-banana-bread/';
  }

  try {
    console.log(`\nParsing URL: ${inputUrl}`);
    const data = await parseRecipeWithPuppeteer(inputUrl);

    // Write data to local file
    // (You can also pass it to an LLM or do further processing)
    writeToFile('recipe_extracted.txt', data);

  } catch (err) {
    console.error('Error in main script:', err);
  }
})();
/**
 * Krishi-Mantra Master Seed Script
 * Runs all service seed scripts to populate the complete platform
 *
 * Usage: node seedAll.js
 *
 * Prerequisites:
 * 1. MongoDB running and accessible
 * 2. .env files configured in each service with MONGODB_URL
 *
 * This script will populate:
 * - 10 realistic Indian farmer users
 * - 8 agricultural companies (Bayer, UPL, Tata Rallis, etc.)
 * - 8+ farming products
 * - 8 major Indian crops with calendar data
 * - 8 farming activities
 * - 10+ real farming news articles
 * - 6 government schemes (PM-KISAN, PMFBY, KCC, etc.)
 * - 8 services
 * - 3 agricultural regions
 * - 15+ feed posts with comments and likes
 * - 15+ farming reels
 * - 12+ video tutorials
 * - 5 marketplace products
 * - Home sliders and ads
 * - Testimonials
 */

const { spawn } = require('child_process');
const path = require('path');

// Seed scripts to run in order
const seedScripts = [
  {
    name: 'Main Service',
    path: './src/scripts/seedData.js',
    cwd: path.join(__dirname, 'main-service'),
  },
  {
    name: 'Feed Service',
    path: './src/scripts/seedFeedData.js',
    cwd: path.join(__dirname, 'feed-service'),
  },
  {
    name: 'Reel Service',
    path: './src/scripts/seedReelData.js',
    cwd: path.join(__dirname, 'reel-service'),
  },
];

async function runSeedScript(script) {
  return new Promise((resolve, reject) => {
    console.log(`\n${'='.repeat(60)}`);
    console.log(`🚀 Starting ${script.name} seed...`);
    console.log(`${'='.repeat(60)}\n`);

    const child = spawn('node', [script.path], {
      cwd: script.cwd,
      stdio: 'inherit',
      env: { ...process.env },
    });

    child.on('close', (code) => {
      if (code === 0) {
        console.log(`\n✅ ${script.name} seed completed successfully!\n`);
        resolve();
      } else {
        reject(new Error(`${script.name} seed failed with code ${code}`));
      }
    });

    child.on('error', (err) => {
      reject(new Error(`Failed to start ${script.name} seed: ${err.message}`));
    });
  });
}

async function seedAll() {
  console.log(`
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          🌾 KRISHI-MANTRA COMPLETE SEED SCRIPT 🌾            ║
║                                                              ║
║  This will populate all databases with realistic            ║
║  Indian farming data across all microservices.              ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝
  `);

  const startTime = Date.now();

  try {
    for (const script of seedScripts) {
      await runSeedScript(script);
    }

    const duration = ((Date.now() - startTime) / 1000).toFixed(2);

    console.log(`
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║          🎉 ALL SEED SCRIPTS COMPLETED! 🎉                   ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

📊 Data Summary:
────────────────────────────────────────────────────────────────

MAIN SERVICE:
  👥 Users: 10 (farmers, consultants, admin, marketplace)
  🏢 Companies: 8 (Bayer, UPL, Tata Rallis, etc.)
  📦 Products: 8+ (pesticides, fertilizers, seeds)
  🌾 Crops: 8 (Wheat, Rice, Cotton, Soybean, etc.)
  📅 Crop Calendars: 12+ entries
  🔧 Activities: 8 (Sowing, Irrigation, Harvesting, etc.)
  🗺️  Regions: 3 (Punjab, Vidarbha, Cauvery Delta)
  📰 News: 10+ articles
  📋 Schemes: 6 (PM-KISAN, PMFBY, KCC, etc.)
  🛠️  Services: 8
  🖼️  Home Sliders: 4
  📢 Home Ads: 3
  💬 Testimonials: 5
  🛒 Marketplace: 5 products

FEED SERVICE:
  📝 Feed Posts: 15+
  💬 Comments: 30+
  ❤️  Likes: 50+
  🏷️  Tags: 20+
  🎯 User Interests: 10

REEL SERVICE:
  🎬 Reels: 15+
  📹 Video Tutorials: 12+
  💬 Reel Comments: 30+
  ❤️  Reel Likes: 40+
  🏷️  Reel Tags: 15+

────────────────────────────────────────────────────────────────
⏱️  Total time: ${duration} seconds
────────────────────────────────────────────────────────────────

🔑 Default Credentials:
   Password for all users: KrishiMantra@123

📱 Test Users:
   - ramesh.patel@gmail.com (user)
   - sunita.devi@gmail.com (user)
   - venkatesh.reddy@gmail.com (consultant)
   - govind.das@gmail.com (admin)
   - balwinder.singh@gmail.com (marketplace)

🚀 Your Krishi-Mantra platform is now ready with realistic data!
    `);

  } catch (error) {
    console.error('\n❌ Seed process failed:', error.message);
    process.exit(1);
  }
}

// Run the master seed
seedAll();

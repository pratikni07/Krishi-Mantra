/**
 * Seed script for Crop Calendar Data
 * This script creates calendar entries for all existing crops
 * Run with: node src/scripts/seedCropCalendarData.js
 */

const path = require('path');
const dotenv = require('dotenv');

dotenv.config({ path: path.resolve(__dirname, '../../.env.development') });
dotenv.config({ path: path.resolve(__dirname, '../../.env') });
const mongoose = require('mongoose');
const Crop = require('../model/CropCalendar/Crop');
const Activity = require('../model/CropCalendar/Activity');
const CropCalendar = require('../model/CropCalendar/CropCalendar');

// Connect to MongoDB
const connectDB = async () => {
  try {
    const mongoUri = process.env.MONGODB_URL || process.env.MONGODB_URI || 'mongodb://localhost:27017/krishimantra';
    console.log('Connecting to MongoDB...');
    await mongoose.connect(mongoUri);
    console.log('MongoDB connected successfully');
  } catch (error) {
    console.error('MongoDB connection error:', error);
    process.exit(1);
  }
};

// Growth stages by month index (for different crop types)
const growthStages = {
  vegetable: ['Germination', 'Seedling', 'Vegetative Growth', 'Flowering', 'Fruit Development', 'Maturation', 'Harvesting'],
  grain: ['Sowing', 'Germination', 'Tillering', 'Stem Extension', 'Heading', 'Flowering', 'Grain Filling', 'Ripening', 'Harvesting'],
  fruit: ['Dormancy', 'Bud Break', 'Flowering', 'Fruit Set', 'Fruit Development', 'Ripening', 'Harvesting', 'Post-Harvest']
};

// Default activities for each growth stage
const defaultActivities = {
  'Germination': {
    instructions: 'Ensure soil moisture is maintained for proper seed germination. Avoid waterlogging.',
    importance: 'Critical'
  },
  'Seedling': {
    instructions: 'Thin out weak seedlings and maintain proper spacing. Apply light fertilizer.',
    importance: 'Important'
  },
  'Vegetative Growth': {
    instructions: 'Apply nitrogen-rich fertilizer. Ensure adequate irrigation and weed control.',
    importance: 'Critical'
  },
  'Flowering': {
    instructions: 'Reduce nitrogen application. Monitor for pests. Ensure pollination conditions are optimal.',
    importance: 'Critical'
  },
  'Fruit Development': {
    instructions: 'Increase potassium application. Maintain consistent watering. Support heavy branches.',
    importance: 'Important'
  },
  'Maturation': {
    instructions: 'Reduce watering gradually. Monitor for pests and diseases. Prepare for harvest.',
    importance: 'Important'
  },
  'Harvesting': {
    instructions: 'Harvest at optimal time. Handle produce carefully to avoid damage.',
    importance: 'Critical'
  },
  'Sowing': {
    instructions: 'Prepare soil properly. Sow seeds at recommended depth and spacing.',
    importance: 'Critical'
  },
  'Tillering': {
    instructions: 'Apply fertilizer to promote tiller development. Maintain water level.',
    importance: 'Important'
  },
  'Stem Extension': {
    instructions: 'Continue irrigation. Monitor for lodging. Apply growth regulators if needed.',
    importance: 'Important'
  },
  'Heading': {
    instructions: 'Critical water requirement period. Protect from birds and pests.',
    importance: 'Critical'
  },
  'Grain Filling': {
    instructions: 'Maintain adequate moisture. Protect from diseases and pests.',
    importance: 'Critical'
  },
  'Ripening': {
    instructions: 'Reduce irrigation. Monitor grain moisture content for harvest timing.',
    importance: 'Important'
  },
  'Dormancy': {
    instructions: 'Prune dead branches. Apply dormant spray. Prepare for next season.',
    importance: 'Optional'
  },
  'Bud Break': {
    instructions: 'Apply fertilizer. Monitor for late frost. Begin pest management program.',
    importance: 'Important'
  },
  'Fruit Set': {
    instructions: 'Thin excess fruit. Apply calcium spray if needed. Monitor for pests.',
    importance: 'Critical'
  },
  'Post-Harvest': {
    instructions: 'Clean up fallen fruit. Apply post-harvest fertilizer. Prepare for dormancy.',
    importance: 'Important'
  }
};

// Create calendar entries for a crop
const createCalendarForCrop = async (crop, activities) => {
  const currentMonth = new Date().getMonth() + 1; // 1-12
  const growingPeriodMonths = Math.ceil(crop.growingPeriod / 30);

  // Determine crop type based on name or scientific name
  let cropType = 'vegetable';
  const name = crop.name.toLowerCase();
  if (['rice', 'wheat', 'maize', 'barley', 'millet', 'sorghum', 'oats'].some(g => name.includes(g))) {
    cropType = 'grain';
  } else if (['mango', 'apple', 'orange', 'grape', 'banana', 'papaya', 'guava'].some(f => name.includes(f))) {
    cropType = 'fruit';
  }

  const stages = growthStages[cropType];
  const calendarsCreated = [];

  // Create calendar for each month (12 months cycle)
  for (let month = 1; month <= 12; month++) {
    // Determine growth stage based on month in cycle
    const stageIndex = (month - 1) % stages.length;
    const growthStage = stages[stageIndex];

    // Check if calendar already exists
    const existing = await CropCalendar.findOne({ cropId: crop._id, month });
    if (existing) {
      console.log(`  Calendar already exists for ${crop.name} month ${month}`);
      continue;
    }

    // Find relevant activity
    let activityId = null;
    const activityName = getActivityNameForStage(growthStage);
    if (activityName && activities.length > 0) {
      const activity = activities.find(a =>
        a.name.toLowerCase().includes(activityName.toLowerCase())
      );
      activityId = activity ? activity._id : activities[0]._id;
    }

    const activityData = defaultActivities[growthStage] || defaultActivities['Vegetative Growth'];

    const calendarEntry = new CropCalendar({
      cropId: crop._id,
      month: month,
      growthStage: growthStage,
      activities: activityId ? [{
        activityId: activityId,
        timing: {
          week: Math.ceil(Math.random() * 4),
          recommendedTime: ['Morning', 'Afternoon', 'Evening', 'Any'][Math.floor(Math.random() * 4)]
        },
        instructions: activityData.instructions,
        importance: activityData.importance
      }] : [],
      weatherConsiderations: {
        idealTemperature: {
          min: 20 + Math.floor(Math.random() * 10),
          max: 30 + Math.floor(Math.random() * 10)
        },
        rainfall: getWeatherDescription('rainfall', month),
        humidity: getWeatherDescription('humidity', month)
      },
      possibleIssues: getPossibleIssues(growthStage),
      expectedOutcomes: {
        growth: getExpectedGrowth(growthStage),
        signs: getGrowthSigns(growthStage)
      },
      tips: getTips(growthStage, crop.name),
      nextMonthPreparation: getNextMonthPrep(stages[(stageIndex + 1) % stages.length]),
      status: 'active'
    });

    await calendarEntry.save();
    calendarsCreated.push(month);
  }

  return calendarsCreated;
};

// Helper functions
function getActivityNameForStage(stage) {
  const stageToActivity = {
    'Germination': 'watering',
    'Seedling': 'transplanting',
    'Vegetative Growth': 'fertilizing',
    'Flowering': 'pest control',
    'Fruit Development': 'irrigation',
    'Harvesting': 'harvesting',
    'Sowing': 'sowing',
    'Tillering': 'weeding',
    'Ripening': 'monitoring'
  };
  return stageToActivity[stage] || 'general care';
}

function getWeatherDescription(type, month) {
  // Indian seasons
  if (type === 'rainfall') {
    if (month >= 6 && month <= 9) return 'High rainfall expected (Monsoon season)';
    if (month >= 10 && month <= 2) return 'Low rainfall, may need irrigation';
    return 'Moderate rainfall possible';
  } else {
    if (month >= 4 && month <= 6) return 'High humidity due to rising temperatures';
    if (month >= 7 && month <= 9) return 'Very high humidity during monsoon';
    return 'Moderate humidity levels';
  }
}

function getPossibleIssues(stage) {
  const issues = {
    'Germination': [{
      problem: 'Poor germination rate',
      solution: 'Ensure proper soil temperature and moisture. Use fresh, quality seeds.',
      preventiveMeasures: ['Use treated seeds', 'Maintain optimal soil temperature', 'Avoid overwatering']
    }],
    'Seedling': [{
      problem: 'Damping off disease',
      solution: 'Apply fungicide. Improve drainage and air circulation.',
      preventiveMeasures: ['Use sterilized soil', 'Avoid overwatering', 'Ensure good ventilation']
    }],
    'Vegetative Growth': [{
      problem: 'Nutrient deficiency',
      solution: 'Apply balanced fertilizer. Conduct soil test if symptoms persist.',
      preventiveMeasures: ['Regular soil testing', 'Balanced fertilization', 'Proper pH management']
    }],
    'Flowering': [{
      problem: 'Poor pollination',
      solution: 'Introduce pollinators. Avoid pesticide use during flowering.',
      preventiveMeasures: ['Plant pollinator-friendly flowers nearby', 'Time pesticide applications carefully']
    }],
    'Fruit Development': [{
      problem: 'Fruit drop',
      solution: 'Ensure adequate water and nutrients. Check for pest damage.',
      preventiveMeasures: ['Consistent watering', 'Proper nutrition', 'Regular pest monitoring']
    }],
    'Harvesting': [{
      problem: 'Post-harvest losses',
      solution: 'Harvest at right maturity. Handle carefully. Store properly.',
      preventiveMeasures: ['Proper harvest timing', 'Clean storage facilities', 'Temperature control']
    }]
  };
  return issues[stage] || [{
    problem: 'General pest attack',
    solution: 'Identify pest and apply appropriate treatment.',
    preventiveMeasures: ['Regular monitoring', 'Crop rotation', 'Integrated pest management']
  }];
}

function getExpectedGrowth(stage) {
  const descriptions = {
    'Germination': 'Seeds should sprout within 5-10 days with proper conditions',
    'Seedling': 'Young plants should develop 2-4 true leaves',
    'Vegetative Growth': 'Rapid increase in plant size and leaf development',
    'Flowering': 'Flower buds should appear and open',
    'Fruit Development': 'Fruits should grow in size steadily',
    'Maturation': 'Fruits/grains should reach full size and begin ripening',
    'Harvesting': 'Produce should be ready for harvest',
    'Sowing': 'Seeds should be properly planted in prepared soil',
    'Tillering': 'Multiple shoots should develop from base',
    'Stem Extension': 'Main stem should elongate rapidly',
    'Heading': 'Grain heads should emerge from stem',
    'Grain Filling': 'Grains should fill and gain weight',
    'Ripening': 'Grains should turn golden and dry',
    'Dormancy': 'Plant should be resting, conserving energy',
    'Bud Break': 'New growth should emerge from buds',
    'Fruit Set': 'Small fruits should form after flowering',
    'Post-Harvest': 'Plant should recover and prepare for next cycle'
  };
  return descriptions[stage] || 'Normal growth expected';
}

function getGrowthSigns(stage) {
  const signs = {
    'Germination': ['Seed coat breaking', 'Radicle emergence', 'First shoot visible'],
    'Seedling': ['True leaves developing', 'Stem strengthening', 'Root system establishing'],
    'Vegetative Growth': ['Rapid leaf production', 'Stem thickening', 'Branching begins'],
    'Flowering': ['Flower buds forming', 'Flowers opening', 'Pollen release'],
    'Fruit Development': ['Fruit size increasing', 'Color beginning to change', 'Seeds developing'],
    'Harvesting': ['Full color development', 'Proper firmness', 'Easy separation from plant']
  };
  return signs[stage] || ['Healthy green color', 'Active growth', 'No disease symptoms'];
}

function getTips(stage, cropName) {
  return [
    `Monitor ${cropName} daily during ${stage} stage`,
    'Keep detailed records of growth and any issues',
    'Consult local agricultural extension office if problems persist',
    'Consider weather forecasts when planning activities'
  ];
}

function getNextMonthPrep(nextStage) {
  return [
    `Prepare for ${nextStage} stage`,
    'Stock necessary inputs and supplies',
    'Check equipment and tools',
    'Plan labor requirements'
  ];
}

// Main seed function
const seedCropCalendars = async () => {
  try {
    await connectDB();

    // First, ensure we have some activities
    let activities = await Activity.find();

    if (activities.length === 0) {
      console.log('Creating default activities...');
      const defaultActivitiesList = [
        { name: 'Watering', description: 'Regular irrigation', category: 'Irrigation', type: 'routine' },
        { name: 'Fertilizing', description: 'Apply fertilizers', category: 'Nutrition', type: 'routine' },
        { name: 'Weeding', description: 'Remove weeds', category: 'Maintenance', type: 'routine' },
        { name: 'Pest Control', description: 'Monitor and control pests', category: 'Protection', type: 'monitoring' },
        { name: 'Harvesting', description: 'Collect mature produce', category: 'Harvesting', type: 'one-time' },
        { name: 'Sowing', description: 'Plant seeds', category: 'Planting', type: 'one-time' },
        { name: 'Transplanting', description: 'Move seedlings', category: 'Planting', type: 'one-time' },
        { name: 'Pruning', description: 'Remove excess growth', category: 'Maintenance', type: 'routine' }
      ];

      for (const act of defaultActivitiesList) {
        const activity = new Activity(act);
        await activity.save();
      }
      activities = await Activity.find();
      console.log(`Created ${activities.length} activities`);
    }

    // Get all crops
    const crops = await Crop.find({ status: 'active' });
    console.log(`Found ${crops.length} crops to process`);

    if (crops.length === 0) {
      console.log('No crops found. Please seed crops first.');
      process.exit(0);
    }

    // Create calendar entries for each crop
    let totalCreated = 0;
    for (const crop of crops) {
      console.log(`Processing ${crop.name}...`);
      const created = await createCalendarForCrop(crop, activities);
      totalCreated += created.length;
      if (created.length > 0) {
        console.log(`  Created ${created.length} calendar entries for months: ${created.join(', ')}`);
      }
    }

    console.log(`\n✅ Seed completed! Created ${totalCreated} calendar entries total.`);

  } catch (error) {
    console.error('Error seeding crop calendars:', error);
  } finally {
    await mongoose.connection.close();
    console.log('Database connection closed');
    process.exit(0);
  }
};

// Run the seeder
seedCropCalendars();

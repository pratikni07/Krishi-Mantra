// types/index.ts
export interface Crop {
  _id?: string;
  name: string;
  scientificName: string;
  description: string;
  growingPeriod: number;
  seasons: Season[];
  imageUrl?: string;
}

export interface Season {
  type: string;
  startMonth: number;
  endMonth: number;
}

export interface Activity {
  _id?: string;
  name: string;
  description: string;
  category: string;
  requiredTools: string[];
  precautions: string[];
}

export interface CropCalendar {
  _id?: string;
  cropId: string;
  month: number;
  growthStage: string;
  activities: CalendarActivity[];
  weatherConsiderations: WeatherConsiderations;
  possibleIssues: Issue[];
  expectedOutcomes: Outcomes;
  tips: string[];
  nextMonthPreparation: string[];
}

interface CalendarActivity {
  activityId: string;
  timing: {
    week: number;
    recommendedTime: string;
  };
  instructions: string;
  importance: string;
}

interface WeatherConsiderations {
  idealTemperature: {
    min: number;
    max: number;
  };
  rainfall: string;
  humidity: string;
}

interface Issue {
  problem: string;
  solution: string;
  preventiveMeasures: string[];
}

interface Outcomes {
  growth: string;
  signs: string[];
}

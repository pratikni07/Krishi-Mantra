import React from 'react';
import { 
  Users, 
  Tractor, 
  Leaf, 
  BarChart2, 
  ChevronUp, 
  ChevronDown 
} from 'lucide-react';
import { 
  LineChart, 
  Line, 
  XAxis, 
  YAxis, 
  CartesianGrid, 
  Tooltip, 
  ResponsiveContainer 
} from 'recharts';
import { 
  ComposableMap, 
  Geographies, 
  Geography,
  ZoomableGroup
} from 'react-simple-maps';

interface UserTrendData {
  name: string;
  users: number;
}

interface UserRequestData {
  country: string;
  requests: number;
  color: string;
  coordinates: [number, number]; // [Longitude, Latitude]
}

interface GeographyObject {
  rsmKey: string;
  geometry: {
    type: string;
    coordinates: number[][][]; // Array of coordinates for geometry shapes
  };
  properties: {
    [key: string]: any;
  };
}


const userTrendData:UserTrendData[] = [
  { name: 'Day 1', users: 1500 },
  { name: 'Day 2', users: 1700 },
  { name: 'Day 3', users: 1600 },
  { name: 'Day 4', users: 1900 },
  { name: 'Day 5', users: 2000 },
  { name: 'Day 6', users: 2200 },
  { name: 'Day 7', users: 2000 }
];

const userRequestData:UserRequestData[] = [
    { 
      country: 'United States', 
      requests: 450, 
      color: '#4AB677',
      coordinates: [-98.5, 39.8] // Longitude, Latitude for US center
    },
    { 
      country: 'India', 
      requests: 350, 
      color: '#118D45',
      coordinates: [78.9629, 20.5937] // Longitude, Latitude for India center
    },
    { 
      country: 'Brazil', 
      requests: 250, 
      color: '#1E90FF',
      coordinates: [-55.4868, -14.2350] // Longitude, Latitude for Brazil center
    },
    { 
      country: 'China', 
      requests: 200, 
      color: '#FF6347',
      coordinates: [104.1954, 35.8617] // Longitude, Latitude for China center
    },
    { 
      country: 'Australia', 
      requests: 150, 
      color: '#9370DB',
      coordinates: [133.7751, -25.2744] // Longitude, Latitude for Australia center
    }
  ];

const Home = () => {
  return (
    <div className="min-h-screen bg-gray-50 p-6">
      {/* Header */}
      <div className="mb-8">
        <h1 className="text-3xl font-bold text-green-800 mb-2">Welcome back, Pratik</h1>
        <p className="text-gray-600">Here's an overview of your farm management dashboard</p>
      </div>

      {/* Dashboard Cards */}
      <div className="grid grid-cols-4 gap-6">
        {/* Online Users Card */}
        <div className="bg-green-500 text-white rounded-lg shadow-md p-6 transform transition hover:scale-105">
          <div className="flex justify-between items-center mb-4">
            <Users size={32} />
            <div className="text-sm flex items-center text-green-100">
              <ChevronUp className="mr-1" size={16} />
              12% this week
            </div>
          </div>
          <h2 className="text-2xl font-bold">2,000</h2>
          <p className="text-sm">Online Users</p>
        </div>

        {/* Active Farms Card */}
        <div className="bg-blue-500 text-white rounded-lg shadow-md p-6 transform transition hover:scale-105">
          <div className="flex justify-between items-center mb-4">
            <Tractor size={32} />
            <div className="text-sm flex items-center text-blue-100">
              <ChevronUp className="mr-1" size={16} />
              8% this week
            </div>
          </div>
          <h2 className="text-2xl font-bold">750</h2>
          <p className="text-sm">Active Farms</p>
        </div>

        {/* Crop Health Card */}
        <div className="bg-yellow-500 text-white rounded-lg shadow-md p-6 transform transition hover:scale-105">
          <div className="flex justify-between items-center mb-4">
            <Leaf size={32} />
            <div className="text-sm flex items-center text-yellow-100">
              <ChevronDown className="mr-1" size={16} />
              5% this week
            </div>
          </div>
          <h2 className="text-2xl font-bold">68%</h2>
          <p className="text-sm">Crop Health</p>
        </div>

        {/* Revenue Card */}
        <div className="bg-purple-500 text-white rounded-lg shadow-md p-6 transform transition hover:scale-105">
          <div className="flex justify-between items-center mb-4">
            <BarChart2 size={32} />
            <div className="text-sm flex items-center text-purple-100">
              <ChevronUp className="mr-1" size={16} />
              15% this week
            </div>
          </div>
          <h2 className="text-2xl font-bold">$45,000</h2>
          <p className="text-sm">Total Revenue</p>
        </div>
      </div>
     
       <div className="grid grid-cols-2 gap-6 mt-[40px]">
        {/* First Row - Left: User Trends Graph */}
        <div className="bg-white rounded-lg shadow-md p-6">
          <div className="flex justify-between items-center mb-4">
            <h2 className="text-xl font-semibold text-gray-800">User Trends (Last 7 Days)</h2>
            <div className="flex items-center text-green-500">
              <ChevronUp className="mr-1" size={16} />
              <span className="text-sm">12% Increase</span>
            </div>
          </div>
          <ResponsiveContainer width="100%" height={400}>
            <LineChart data={userTrendData}>
              <CartesianGrid strokeDasharray="3 3" stroke="#f0f0f0" />
              <XAxis dataKey="name" />
              <YAxis />
              <Tooltip 
                contentStyle={{ 
                  backgroundColor: '#4AB677', 
                  color: 'white',
                  border: 'none',
                  borderRadius: '8px'
                }}
              />
              <Line 
                type="monotone" 
                dataKey="users" 
                stroke="#4AB677" 
                strokeWidth={3}
                dot={{ r: 6, fill: '#4AB677' }}
              />
            </LineChart>
          </ResponsiveContainer>
        </div>

        <div className="grid grid-cols gap-6 ">
        <div className="bg-white rounded-lg shadow-md p-6">
          <h2 className="text-xl font-semibold text-gray-800 mb-4">Global User Requests</h2>
          <div className="h-[400px]">
            <ComposableMap projection="geoMercator">
              <ZoomableGroup zoom={1}>
                <Geographies geography="https://cdn.jsdelivr.net/npm/world-atlas@2/countries-110m.json">
                {({ geographies }: { geographies: GeographyObject[] }) =>
                    geographies.map((geo: GeographyObject) => (
                      <Geography 
                        key={geo.rsmKey} 
                        geography={geo}
                        fill="#D6D6DA"
                        stroke="#FFFFFF"
                        strokeWidth={0.5}
                      />
                    ))
                  }
                </Geographies>
                {userRequestData.map((country, index) => (
                  <circle
                    key={index}
                    cx={country.coordinates[0]}
                    cy={country.coordinates[1]}
                    r={Math.sqrt(country.requests) * 0.5}
                    fill={country.color}
                    fillOpacity={0.7}
                  />
                ))}
              </ZoomableGroup>
            </ComposableMap>
          </div>
        </div>

      </div>
      </div>
    </div>
  );
};

export default Home;

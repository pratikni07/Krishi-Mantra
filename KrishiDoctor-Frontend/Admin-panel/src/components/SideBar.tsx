import React from 'react';
import { Link, useLocation } from 'react-router-dom';
import { 
  LayoutDashboard, 
  Users, 
  Tractor, 
  Leaf, 
  UserCheck,
  Settings, 
  LogIn 
} from 'lucide-react';

const SideBar = () => {
  const location = useLocation();

  const menuItems = [
    { 
      path: "/", 
      icon: LayoutDashboard, 
      label: "Dashboard" 
    },
    { 
      path: "/farms", 
      icon: Tractor, 
      label: "Farms" 
    },
    { 
      path: "/crops", 
      icon: Leaf, 
      label: "Crop Management" 
    },
    { 
      path: "/company", 
      icon: Leaf, 
      label: "Company" 
    },
    { 
      path: "/users", 
      icon: Users, 
      label: "Users" 
    },
    { 
      path: "/doctors", 
      icon: UserCheck, 
      label: "Doctor" 
    },
    { 
      path: "/settings", 
      icon: Settings, 
      label: "Settings" 
    },
    { 
      path: "/login", 
      icon: LogIn, 
      label: "Login" 
    }
  ];

  return (
    <div className="w-64 bg-gradient-to-b from-[#4AB677] to-[#118D45] text-white h-screen rounded-r-xl shadow-xl flex flex-col">
      {/* Logo Section */}
      <div className="flex items-center p-6 mb-8">
        <Tractor className="mr-3" size={32} />
        <h2 className="text-2xl font-bold">Krishi Doctor</h2>
      </div>

      {/* Navigation Links */}
      <nav className="flex-grow">
        {menuItems.map((item) => (
          <Link 
            key={item.path}
            to={item.path} 
            className={`
              flex items-center px-6 py-3 transition-all duration-200 
              ${location.pathname === item.path 
                ? 'bg-white bg-opacity-20 border-r-4 border-white' 
                : 'hover:bg-white hover:bg-opacity-10'}
            `}
          >
            <item.icon className="mr-3" size={20} />
            <span className="font-medium">{item.label}</span>
          </Link>
        ))}
      </nav>

      {/* Footer Section */}
      <div className="p-4 text-center text-sm text-white text-opacity-70">
        © 2024 Krishi Doctor
      </div>
    </div>
  );
};

export default SideBar;
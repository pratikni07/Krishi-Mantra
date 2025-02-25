import React from "react";
import { Routes, Route, useLocation } from "react-router-dom";
import Login from "./Pages/Login";
import Home from "./Pages/Home";
import SideBar from "./components/SideBar";
import DoctorLogin from "./Pages/DoctorLogin";
import Crops from "./Pages/Crops";
import Users from "./Pages/Users";
import Company from "./Pages/Company";
import FileUpload from "./config/FileUpload";
function App() {
  const location = useLocation();

  return (
    <div className="flex h-screen overflow-hidden">
      {/* Conditionally render sidebar */}
      {location.pathname !== "/login" &&
        location.pathname !== "/doctorlogin" && <SideBar />}

      {/* Content area with independent scrolling */}
      <div className="flex-1 overflow-y-auto">
        <Routes>
          <Route path="/login" element={<Login />} />
          <Route path="/doctorlogin" element={<DoctorLogin />} />
          <Route path="/" element={<Home />} />
          <Route path="/company" element={<Company />} />
          {/* <Route path="/crops" element={<Crops />} /> */}
          <Route path="/users" element={<Users />} />
        </Routes>
      </div>
    </div>
  );
}

export default App;

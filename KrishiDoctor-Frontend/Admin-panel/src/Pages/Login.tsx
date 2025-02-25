import React, { useState } from 'react';
import { Lock, Mail, Eye, EyeOff } from 'lucide-react';

const Login = () => {
    const [showPassword, setShowPassword] = useState<boolean>(false);
    const [email, setEmail] = useState<string>('');
    const [password, setPassword] = useState<string>('');

  const handleLogin = (e:React.FormEvent) => {
    e.preventDefault();
    // Implement login logic here
    console.log('Login attempted', { email, password });
  };

  return (
    <div className="min-h-screen bg-gradient-to-br from-[#4AB677] to-[#118D45] flex items-center justify-center px-4">
      <div className="w-full max-w-md">
        <div className="bg-white shadow-2xl rounded-2xl overflow-hidden">
          {/* Header */}
          <div className="bg-gradient-to-r from-[#4AB677] to-[#118D45] p-6 text-center">
            <h1 className="text-3xl font-bold text-white">Krishi Doctor</h1>
            <p className="text-white text-opacity-80 mt-2">Manage Your Farm Intelligently</p>
          </div>

          {/* Login Form */}
          <form onSubmit={handleLogin} className="p-8">
            {/* Email Input */}
            <div className="mb-6 relative">
              <Mail className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
              <input
                type="email"
                placeholder="Email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                className="w-full pl-10 pr-4 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4AB677]"
                required
              />
            </div>

            {/* Password Input */}
            <div className="mb-6 relative">
              <Lock className="absolute left-3 top-1/2 transform -translate-y-1/2 text-gray-400" size={20} />
              <input
                type={showPassword ? "text" : "password"}
                placeholder="Password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                className="w-full pl-10 pr-10 py-3 border border-gray-300 rounded-lg focus:outline-none focus:ring-2 focus:ring-[#4AB677]"
                required
              />
              <button
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                className="absolute right-3 top-1/2 transform -translate-y-1/2 text-gray-400 hover:text-[#4AB677]"
              >
                {showPassword ? <EyeOff size={20} /> : <Eye size={20} />}
              </button>
            </div>

            {/* Forgot Password */}
            <div className="text-right mb-6">
              <a href="/forgot-password" className="text-sm text-[#118D45] hover:underline">
                Forgot Password?
              </a>
            </div>

            {/* Login Button */}
            <button
              type="submit"
              className="w-full py-3 bg-gradient-to-r from-[#4AB677] to-[#118D45] text-white rounded-lg 
              hover:opacity-90 transition-all duration-300 transform hover:scale-[1.02] 
              focus:outline-none focus:ring-2 focus:ring-[#4AB677] focus:ring-opacity-50"
            >
              Login
            </button>

            {/* Sign Up Link */}
            <div className="text-center mt-6">
              <p className="text-sm text-gray-600">
                Don't have an account? {' '}
                <a href="/signup" className="text-[#118D45] font-bold hover:underline">
                  Sign Up
                </a>
              </p>
            </div>
          </form>
        </div>


        <div className="text-center text-white mt-4 text-sm">
          Krishi Doctor v1.0.0
        </div>
      </div>
    </div>
  );
};

export default Login;
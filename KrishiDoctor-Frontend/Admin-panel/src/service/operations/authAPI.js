import { setLoading, setToken } from "@/slices/authSlice";
import { endpoints } from "../apis";
import { apiConnector } from "../apiconnector";
import { setUser } from "@/slices/profileSlice";
const {
  SENDOTP_API,
  SIGNUP_API,
  LOGIN_API,
  ADD_ADDRESS_API,
  GET_ALL_ADDRESS_API,
  GET_ALL_USERS_API,
  GET_USER_DETAILS_API,
} = endpoints;

export function sendOtp(email, navigate) {
  return async (dispatch) => {
    dispatch(setLoading(true));
    try {
      const response = await apiConnector("POST", SENDOTP_API, {
        email,
        checkUserPresent: true,
      });

      if (!response.data.success) {
        throw new Error(response.data.message);
      }
    } catch (error) {
      console.log("SENDOTP API ERROR............", error);
      // toast.error(error?.response?.data?.message);
      // dispatch(setProgress(100));
    }
    dispatch(setLoading(false));
    // toast.dismiss(toastId)
  };
}

export function signUp(
  role,
  firstName,
  lastName,
  email,
  phoneNumber,
  password,
  confirmPassword,
  otp,
  navigate
) {
  return async (dispatch) => {
    dispatch(setLoading(true));
    try {
      const response = await apiConnector("POST", SIGNUP_API, {
        role,
        firstName,
        lastName,
        email,
        phoneNumber,
        password,
        confirmPassword,
        otp,
      });
      console.log("SIGNUP API RESPONSE............", response);
      console.log(response.data.success);
      if (!response.data.success) {
        throw new Error(response.data.message);
      }
    } catch (error) {
      console.log("SIGNUP API ERROR............", error);
    }
    dispatch(setLoading(false));
  };
}

export function login(email, password, navigate) {
  return async (dispatch) => {
    dispatch(setLoading(true));
    try {
      const response = await apiConnector("POST", LOGIN_API, {
        email,
        password,
      });
      // console.log(response)
      console.log("LOGIN API RESPONSE............", response);
      console.log(response.data.success);
      if (!response.data.success) {
        throw new Error(response.data.message);
      }
      dispatch(setToken(response.data.token));
      dispatch(setUser({ ...response.data.user }));
      localStorage.setItem("user", JSON.stringify(response.data.user));
      localStorage.setItem("token", JSON.stringify(response.data.token));
      console.log("login");
      navigate("/");
    } catch (error) {
      console.log("LOGIN API ERROR............", error);
    }
    dispatch(setLoading(false));
  };
}

export async function getAllAddress({ userId }) {
  try {
    const response = await apiConnector("POST", GET_ALL_ADDRESS_API, {
      userId,
    });
    console.log("GET ALL ADDRESSES API RESPONSE:", response);
    if (!response.data.success) {
      throw new Error(response.data.message);
    }
    return response; // Assuming categories are nested within the response data
  } catch (error) {
    console.log("GET ALL ADDRESS API ERROR:", error);
    throw error; // Re-throwing the error for further handling
  }
}

export async function addAddress({ userId, formData }) {
  try {
    const res = await apiConnector("POST", ADD_ADDRESS_API, {
      userId,
      formData,
    });
    return res;
  } catch (error) {}
}

export async function getAllUsers() {
  try {
    const response = await apiConnector("GET", GET_ALL_USERS_API);
    console.log("GET ALL USERS API RESPONSE:", response);
    // if (!response.data.=) {
    //     throw new Error(response.data.message);
    // }
    return response; // Assuming categories are nested within the response data
  } catch (error) {
    console.log("GET ALL USERS API ERROR:", error);
    throw error; // Re-throwing the error for further handling
  }
}

export const getUserDetails = async (userId) => {
  try {
    const response = await apiConnector("GET", GET_USER_DETAILS_API + userId);
    return response.data;
  } catch (error) {
    console.error("Error fetching user details:", error);
    throw error;
  }
};

const BASE_URL = "http://localhost:3001/api";

export const endpoints = {
  SENDOTP_API: BASE_URL + "/auth/sendotp",
  SIGNUP_API: BASE_URL + "/auth/register",
  LOGIN_API: BASE_URL + "/auth/login",
  ADD_ADDRESS_API: BASE_URL + "/auth/addAddress",
  GET_ALL_ADDRESS_API: BASE_URL + "/auth/getAllAddress",

  GET_ALL_USERS_API: BASE_URL + "/auth/getAllUsers",
  GET_USER_DETAILS_API: BASE_URL + "/auth/users/",
};

export const usersendpoints = {
  GET_ALL_USER_API: BASE_URL + "/main/user/users",
};

export const company = {
  GET_ALL_COMPANY_API: BASE_URL + "/main/companies",

  ADD_COMPANY_API: BASE_URL + "/main/companies",
};
export const crop = {
  GET_ALL_CROP_API: BASE_URL + "/main/crop-calendar/crops",
  CREATE_CROP_API: BASE_URL + "/main/crop-calendar/crops/create",
  UPDATE_CROP_API: BASE_URL + "/main/crop-calendar/crops/update",
  DELETE_CROP_API: BASE_URL + "/main/crop-calendar/crops/delete",
};

export const activity = {
  GET_ALL_ACTIVITIES_API: BASE_URL + "/main/crop-calendar/activities",
  CREATE_ACTIVITY_API: BASE_URL + "/main/crop-calendar/activities/create",
};

export const calendar = {
  GET_CALENDAR_API: BASE_URL + "/main/crop-calendar/calendar",
  CREATE_CALENDAR_API: BASE_URL + "/main/crop-calendar/calendar/create",
};

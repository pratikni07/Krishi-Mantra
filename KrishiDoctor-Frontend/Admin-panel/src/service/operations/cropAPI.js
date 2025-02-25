// services/operations.js
import { apiConnector } from "../apiconnector";
import { crop, activity, calendar } from "../apis";

// Crop operations
export const getAllCrops = async () => {
  try {
    const response = await apiConnector("POST", crop.GET_ALL_CROP_API);
    return response;
  } catch (error) {
    console.log("GET_ALL_CROPS_API ERROR............", error);
    throw error;
  }
};

export const createCrop = async (data) => {
  try {
    const response = await apiConnector("POST", crop.CREATE_CROP_API, data);
    return response;
  } catch (error) {
    console.log("CREATE_CROP_API ERROR............", error);
    throw error;
  }
};

// Activity operations
export const getAllActivities = async () => {
  try {
    const response = await apiConnector(
      "POST",
      activity.GET_ALL_ACTIVITIES_API
    );
    return response;
  } catch (error) {
    console.log("GET_ALL_ACTIVITIES_API ERROR............", error);
    throw error;
  }
};

export const createActivity = async (data) => {
  try {
    const response = await apiConnector(
      "POST",
      activity.CREATE_ACTIVITY_API,
      data
    );
    return response;
  } catch (error) {
    console.log("CREATE_ACTIVITY_API ERROR............", error);
    throw error;
  }
};

// Calendar operations
export const getCalendar = async () => {
  try {
    const response = await apiConnector("POST", calendar.GET_CALENDAR_API);
    return response;
  } catch (error) {
    console.log("GET_CALENDAR_API ERROR............", error);
    throw error;
  }
};

export const createCalendar = async (data) => {
  try {
    const response = await apiConnector(
      "POST",
      calendar.CREATE_CALENDAR_API,
      data
    );
    return response;
  } catch (error) {
    console.log("CREATE_CALENDAR_API ERROR............", error);
    throw error;
  }
};

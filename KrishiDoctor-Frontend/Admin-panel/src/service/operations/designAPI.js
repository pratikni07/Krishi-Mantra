// import { apiConnector } from "../apiconnector";
// import { design } from "../apis";

// const {
//   ADD_HERO_SLIDER,
//   GET_HERO_SLIDER,
//   ADD_HOME_MODAL,
//   GET_HOME_MODAL,
//   ADD_SALE,
//   GET_ALL_SALES,
// } = design;

// export const addHeroSlider = async (homeSliderData, imagePreview) => {
//   try {
//     const response = await apiConnector("POST", ADD_HERO_SLIDER, {
//       homeSliderData,
//       image: imagePreview,
//     });
//     return response;
//   } catch (error) {
//     throw error;
//   }
// };

// export async function getHeroSlider() {
//   try {
//     const response = await apiConnector("GET", GET_HERO_SLIDER);

//     // console.log("GET HERI SLIDER API RESPONSE:", response);
//     if (!response.data.success) {
//       throw new Error(response.data);
//     }
//     return response.data.data; // Assuming categories are nested within the response data
//   } catch (error) {
//     console.log("GET HERO SLIDER API ERROR:", error);
//     throw error; // Re-throwing the error for further handling
//   }
// }

// // home modal

// export async function addHomeModal(data, imagePreview) {
//   try {
//     const response = await apiConnector("POST", ADD_HOME_MODAL, {
//       homeModalData: data,
//       image: imagePreview,
//     });
//     // console.log(response.data);
//     return response;
//   } catch (error) {
//     console.log("ADD HOME MODAL API ERROR:", error);
//     throw error; // Propagate the error to be handled by the caller
//   }
// }

// // get home modal
// export async function getHomeModal() {
//   try {
//     const response = await apiConnector("GET", GET_HOME_MODAL);
//     // console.log(response.data);
//     return response;
//   } catch (error) {
//     console.log("GET HOME MODAL API ERROR:", error);
//   }
// }

// // add sale

// export async function addSale(
//   formData,
//   mainImagePreview,
//   additionalImagePreviews
// ) {
//   try {
//     console.log(formData, mainImagePreview, additionalImagePreviews);
//     const response = await apiConnector("POST", ADD_SALE, {
//       formData,
//       mainImagePreview,
//       additionalImagePreviews,
//     });
//     // console.log(response.data);
//     return response;
//   } catch (error) {
//     console.log("ADD HOME MODAL API ERROR:", error);
//     throw error; // Propagate the error to be handled by the caller
//   }
// }

// // get all sale
// export async function getAllSales() {
//   try {
//     const response = await apiConnector("GET", GET_ALL_SALES);
//     // console.log(response.data);
//     return response;
//   } catch (error) {
//     console.log("GET HOME MODAL API ERROR:", error);
//   }
// }

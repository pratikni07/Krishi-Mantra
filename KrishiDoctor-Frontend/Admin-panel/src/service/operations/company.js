import { apiConnector } from "../apiconnector";
import { company } from "../apis";

const { GET_ALL_COMPANY_API, ADD_COMPANY_API } = company;

export async function getCompanies() {
  try {
    const response = await apiConnector("GET", GET_ALL_COMPANY_API);
    console.log(response);
    return response;
  } catch (error) {
    throw error;
  }
}

export async function addCompanies(data) {
  try {
    console.log(data);
    const response = await apiConnector("POST", ADD_COMPANY_API, data);
    console.log(response);
    return response;
  } catch (error) {
    throw error;
  }
}

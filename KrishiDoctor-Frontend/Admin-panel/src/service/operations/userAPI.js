import { apiConnector } from "../apiconnector";
import { users } from "../apis";

const {
    GET_ALL_USER_API
} = users;

export async function getHeroSlider() {
  try {
    const response = await apiConnector("GET", GET_ALL_USER_API);

  } catch (error) {

    throw error; 
  }
}

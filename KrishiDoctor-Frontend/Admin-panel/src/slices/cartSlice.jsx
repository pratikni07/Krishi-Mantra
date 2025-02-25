import { createSlice } from "@reduxjs/toolkit";

const initialState = {
  cart: localStorage.getItem("cart")
    ? JSON.parse(localStorage.getItem("cart"))
    : [],
  total: localStorage.getItem("total")
    ? JSON.parse(localStorage.getItem("total"))
    : 0,
  totalItems: localStorage.getItem("totalItems")
    ? JSON.parse(localStorage.getItem("totalItems"))
    : 0,
};

const cartSlice = createSlice({
  name: "cart",
  initialState,
  reducers: {
    addToCart: (state, action) => {
      const product = action.payload;
      const index = state.cart.findIndex((item) => item._id === product._id);

      if (index >= 0) {
        // console.log('already present');
        return;
      }

      state.cart.push({ ...product, quantity: 1 });
      state.totalItems++;
      state.total += product.newPrice;
      localStorage.setItem("cart", JSON.stringify(state.cart));
      localStorage.setItem("total", JSON.stringify(state.total));
      localStorage.setItem("totalItems", JSON.stringify(state.totalItems));
      // console.log("product added to cart");
    },
    removeFromCart: (state, action) => {
      const productId = action.payload;
      const index = state.cart.findIndex((item) => item._id === productId);

      if (index >= 0) {
        if(state.totalItems>0){
          state.totalItems--;
        }
        
        state.total -= state.cart[index].newPrice * state.cart[index].quantity;
        state.cart.splice(index, 1);
        localStorage.setItem("cart", JSON.stringify(state.cart));
        localStorage.setItem("total", JSON.stringify(state.total));
        localStorage.setItem("totalItems", JSON.stringify(state.totalItems));
        // console.log("product removed from cart");
      }
    },
    resetCart: (state) => {
      state.cart = [];
      state.total = 0;
      state.totalItems = 0;
      localStorage.removeItem("cart");
      localStorage.removeItem("total");
      localStorage.removeItem("totalItems");
    },
    increaseQuantity: (state, action) => {
      const productId = action.payload;
      const index = state.cart.findIndex((item) => item._id === productId);

      if (index >= 0) {
        state.cart[index].quantity++;
        // state.totalItems++;
        state.total += state.cart[index].newPrice;
        localStorage.setItem("cart", JSON.stringify(state.cart));
        localStorage.setItem("total", JSON.stringify(state.total));
        localStorage.setItem("totalItems", JSON.stringify(state.totalItems));
      }
    },
    decreaseQuantity: (state, action) => {
      const productId = action.payload;
      const index = state.cart.findIndex((item) => item._id === productId);

      if (index >= 0 && state.cart[index].quantity > 1) {
        state.cart[index].quantity--;
        state.total -= state.cart[index].newPrice;
        localStorage.setItem("cart", JSON.stringify(state.cart));
        localStorage.setItem("total", JSON.stringify(state.total));
        localStorage.setItem("totalItems", JSON.stringify(state.totalItems));
      }
    },
  },
});

export const { addToCart, removeFromCart, resetCart, increaseQuantity, decreaseQuantity } = cartSlice.actions;

export default cartSlice.reducer;

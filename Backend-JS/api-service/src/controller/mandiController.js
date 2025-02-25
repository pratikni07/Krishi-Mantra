// src/controllers/mandiController.js
import axios from "axios";

class MandiController {
  // Get prices for all vegetables in a state
  async getPricesByState(req, res) {
    try {
      const { state } = req.params;
      const response = await axios.get(
        `https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070?api-key=${process.env.API_KEY}&format=json&filters[state]=${state}`
      );

      const prices = response.data.records.map((record) => ({
        commodity: record.commodity,
        variety: record.variety,
        market: record.market,
        price: record.modal_price,
        date: record.arrival_date,
      }));

      res.json({
        success: true,
        data: prices,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Error fetching state prices",
        details: error.message,
      });
    }
  }

  // Get prices for all vegetables in a specific market
  async getPricesByMarket(req, res) {
    try {
      const { market } = req.params;
      const response = await axios.get(
        `https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070?api-key=${process.env.API_KEY}&format=json&filters[market]=${market}`
      );

      const prices = response.data.records.map((record) => ({
        commodity: record.commodity,
        variety: record.variety,
        price: record.modal_price,
        date: record.arrival_date,
      }));

      res.json({
        success: true,
        data: prices,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Error fetching market prices",
        details: error.message,
      });
    }
  }

  // Get price for a specific vegetable across all markets
  async getVegetablePrices(req, res) {
    try {
      const { vegetable } = req.params;
      const response = await axios.get(
        `https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070?api-key=${process.env.API_KEY}&format=json&filters[commodity]=${vegetable}`
      );

      const prices = response.data.records.map((record) => ({
        state: record.state,
        market: record.market,
        variety: record.variety,
        price: record.modal_price,
        date: record.arrival_date,
      }));

      res.json({
        success: true,
        data: prices,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Error fetching vegetable prices",
        details: error.message,
      });
    }
  }

  // Get latest prices (today's prices)
  async getLatestPrices(req, res) {
    try {
      const today = new Date().toISOString().split("T")[0];
      const response = await axios.get(
        `https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070?api-key=${process.env.API_KEY}&format=json&filters[arrival_date]=${today}`
      );

      const prices = response.data.records.map((record) => ({
        state: record.state,
        market: record.market,
        commodity: record.commodity,
        variety: record.variety,
        price: record.modal_price,
      }));

      res.json({
        success: true,
        data: prices,
      });
    } catch (error) {
      res.status(500).json({
        success: false,
        error: "Error fetching latest prices",
        details: error.message,
      });
    }
  }
}

export default new MandiController();

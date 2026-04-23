// src/controllers/mandiController.js
import axios from "axios";

const MANDI_ENDPOINT =
  "https://api.data.gov.in/resource/9ef84268-d588-465a-a308-a864a43d0070";

// Letters, digits, spaces, and a couple of punctuation characters that
// appear in real state/market/commodity names ("Tamil Nadu", "T.Kallupatti").
// Anything else is rejected to prevent URL injection or abuse of this
// endpoint as an open proxy against data.gov.in.
const SAFE_FILTER_VALUE = /^[A-Za-z0-9][A-Za-z0-9 .,()\-'&]{0,60}$/;

const rejectInvalid = (res, field) =>
  res.status(400).json({
    success: false,
    error: `Invalid ${field}. Must be alphanumeric (max 60 chars).`,
  });

const buildParams = (filters) => ({
  "api-key": process.env.API_KEY,
  format: "json",
  ...Object.fromEntries(
    Object.entries(filters).map(([k, v]) => [`filters[${k}]`, v])
  ),
});

class MandiController {
  // Get prices for all vegetables in a state
  async getPricesByState(req, res) {
    const { state } = req.params;
    if (!SAFE_FILTER_VALUE.test(state || "")) return rejectInvalid(res, "state");
    try {
      const response = await axios.get(MANDI_ENDPOINT, {
        params: buildParams({ state }),
        timeout: 10000,
      });
      const prices = (response.data.records || []).map((record) => ({
        commodity: record.commodity,
        variety: record.variety,
        market: record.market,
        price: record.modal_price,
        date: record.arrival_date,
      }));
      res.json({ success: true, data: prices });
    } catch (error) {
      res.status(502).json({
        success: false,
        error: "Error fetching state prices",
      });
    }
  }

  // Get prices for all vegetables in a specific market
  async getPricesByMarket(req, res) {
    const { market } = req.params;
    if (!SAFE_FILTER_VALUE.test(market || "")) return rejectInvalid(res, "market");
    try {
      const response = await axios.get(MANDI_ENDPOINT, {
        params: buildParams({ market }),
        timeout: 10000,
      });
      const prices = (response.data.records || []).map((record) => ({
        commodity: record.commodity,
        variety: record.variety,
        price: record.modal_price,
        date: record.arrival_date,
      }));
      res.json({ success: true, data: prices });
    } catch (error) {
      res.status(502).json({
        success: false,
        error: "Error fetching market prices",
      });
    }
  }

  // Get price for a specific vegetable across all markets
  async getVegetablePrices(req, res) {
    const { vegetable } = req.params;
    if (!SAFE_FILTER_VALUE.test(vegetable || "")) return rejectInvalid(res, "vegetable");
    try {
      const response = await axios.get(MANDI_ENDPOINT, {
        params: buildParams({ commodity: vegetable }),
        timeout: 10000,
      });
      const prices = (response.data.records || []).map((record) => ({
        state: record.state,
        market: record.market,
        variety: record.variety,
        price: record.modal_price,
        date: record.arrival_date,
      }));
      res.json({ success: true, data: prices });
    } catch (error) {
      res.status(502).json({
        success: false,
        error: "Error fetching vegetable prices",
      });
    }
  }

  // Get latest prices (today's prices)
  async getLatestPrices(req, res) {
    try {
      const today = new Date().toISOString().split("T")[0];
      const response = await axios.get(MANDI_ENDPOINT, {
        params: buildParams({ arrival_date: today }),
        timeout: 10000,
      });
      const prices = (response.data.records || []).map((record) => ({
        state: record.state,
        market: record.market,
        commodity: record.commodity,
        variety: record.variety,
        price: record.modal_price,
      }));
      res.json({ success: true, data: prices });
    } catch (error) {
      res.status(502).json({
        success: false,
        error: "Error fetching latest prices",
      });
    }
  }
}

export default new MandiController();

const mongoose = require('mongoose');

const companySchema = new mongoose.Schema({
  name: { type: String, required: true, trim: true },
  email: { 
    type: String, 
    required: true, 
    unique: true, 
    lowercase: true,
    match: [/^\w+([.-]?\w+)*@\w+([.-]?\w+)*(\.\w{2,3})+$/, 'Please fill a valid email address']
  },
  address: {
    street: { type: String, required: true, trim: true },
    city: { type: String, required: true, trim: true },
    state: { type: String, required: true, trim: true },
    zip: { type: String, required: true, trim: true }
  },
  phone: { 
    type: String, 
    required: true,
    match: [/^\+?(\d{10,14})$/, 'Please fill a valid phone number']
  },
  website: { 
    type: String, 
    required: true,
    validate: {
      validator: function(v) {
        return /^(https?:\/\/)?([\da-z\.-]+)\.([a-z\.]{2,6})([\/\w \.-]*)*\/?$/.test(v);
      },
      message: props => `${props.value} is not a valid website URL!`
    }
  },
  description: { type: String, required: true, trim: true },
  logo: { type: String, required: true },
  rating: { 
    type: Number, 
    required: true, 
    min: [0, 'Rating must be at least 0'], 
    max: [5, 'Rating cannot exceed 5']
  },
  reviews: [{
    user: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
    rating: { type: Number, min: 0, max: 5 },
    comment: { type: String },
    createdAt: { type: Date, default: Date.now }
  }],
  products: [{ 
    type: mongoose.Schema.Types.ObjectId, 
    ref: 'Products' 
  }]
}, { timestamps: true });

module.exports = mongoose.model('Company', companySchema);

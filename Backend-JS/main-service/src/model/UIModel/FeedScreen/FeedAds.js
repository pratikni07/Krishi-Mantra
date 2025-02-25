const  mongoose  = require("mongoose");

const feedAdSchema = new mongoose.Schema({
    title:{
        type:String,
    },
    content:{
        type:String,
    },
    dirURL:{
        type:String,
    },
    impression:{
        type:Number
    },
    views:{
        type:Number
    },
    createdAt:{
        type:String,
    }
})

module.exports = mongoose.model("FeedAds",feedAdSchema)
const mongoose = require("mongoose")
const LikeSchema = new mongoose.Schema({
    userId:{
        type: String
    },
    userName:{
        type: String
    },
    profilePhoto:{
        type: String
    },
    feed:{
        type: mongoose.Schema.Types.ObjectId,
        ref: 'Feed'
    },
    
    date:{
        type:Date,
        default:Date.now
    }
})

module.exports = mongoose.model("Likes",LikeSchema)
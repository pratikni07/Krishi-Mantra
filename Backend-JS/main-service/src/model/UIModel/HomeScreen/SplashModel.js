const  mongoose  = require("mongoose");

const SplashSchema = new mongoose.Schema({
    title:{
        type:String
    },
    content:{
        type:String
    },
    dirURL : {
        type:String
    },
    modal:{
        type:Boolean,
        default:false
    },
    createdAt:{
        type:Date,
        default:Date.now
    },
})


module.exports = mongoose.model("SplashModal",SplashSchema)
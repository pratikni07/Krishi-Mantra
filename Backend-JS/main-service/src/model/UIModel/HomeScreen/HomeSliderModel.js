const mongoose = require("mongoose");

const homeSliderSchema = new mongoose.Schema({
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
    prority:{
        type:Number,
        require:true
    },
    createdAt:{
        type:Date,
        default:Date.now
    },
})

module.exports = mongoose.model("HomeSlider",homeSliderSchema)



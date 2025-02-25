const mongoose = require("mongoose")

const UIDisplaySchema = new mongoose.Schema({
    Slider:{
        type:Boolean,
        default:true
    },
    SplashSreen:{
        type:Boolean,
        default:true
    },
    HomeScreenAdOne:{
        type:Boolean,
        default:true
    },
    HomeScreenAdTwo:{
        type:Boolean,
        default:true
    },
    HomeScreenAdThree:{
        type:Boolean,
        default:true
    },
    HomeScreenAdFour:{
        type:Boolean,
        default:true
    },
    FeedAds:{
        type:Boolean,
        default:true
    },
    ReelAds:{
        type:Boolean,
        default:true
    },
    NewsAds:{
        type:Boolean,
        default:true
    }
})

module.exports=mongoose.model("UIDisplay",UIDisplaySchema)
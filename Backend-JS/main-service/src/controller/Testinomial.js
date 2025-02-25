const Testimonial = require("../model/Testinomial")
const User = require("../model/User")


exports.addTestinomial = async(req,res)=>{
    try {
        const { userId,testimonial, name ,profilePhoto} = req.body
        const user = await User.findById(userId)
        if(!user){
            return res.status(404).json({message:"User not found"})
        }
        const testimonialData = new Testimonial({
            testimonial,
            name,
            profilePhoto,
            userId
        })
        await testimonialData.save()
        res.status(201).json({message:"Testimonial added successfully"})
    } catch (error) {
        res.status(500).json({message:error.message})
    }
}

//  delete Testinmoal 
exports.deleteTestinomial = async(req,res)=>{
    try {
        const { id } = req.params
        const testimonial = await Testimonial.findById(id)
        if(!testimonial){
            return res.status(404).json({message:"Testimonial not found"})
        }
        await testimonial.remove()
        res.status(200).json({message:"Testimonial deleted successfully"})
    } catch (error) {
        res.status(500).json({message:error.message})
    }
}


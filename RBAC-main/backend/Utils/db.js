import mongoose from "mongoose";


const DbCon = async()=>{
    try {
        await mongoose.connect(process.env.MONGODB)
        console.log("MongoDB is connected")
    } catch (error) {
        console.log(error)
    }
}

export default DbCon
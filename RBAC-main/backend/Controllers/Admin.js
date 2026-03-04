import UserModel from "../Models/user.js"


const getUser = async(req,res) =>{
    try {
        const users = await UserModel.find()
        res.status(200).json({users})
    } catch (error) {
        res.status(500).json({message:"Internal Server Error!"})
        console.log(error)
    }
}

export {getUser}
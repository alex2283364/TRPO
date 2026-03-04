import jwt from 'jsonwebtoken'
import UserModel from '../Models/user.js'


const isAdmin =async(req,res,next)=>{
    try {

        const token = req.cookies.token
        if(!token){
            return res.status(401).json({success:false,message:"Unauthorised Token"})
        }

        const decoded =jwt.verify(token,process.env.SECRETKEY)

        const user = await UserModel.findById(decoded.userId)

        if(!user){
            return res.status(401).json({success:false,message:"Inavlid Operation"})
        }
        
        if(user.role!=='HOD'){
            return res.status(403).json({success:false,message:"Unauthorised User Access Denied"})
        }
        req.user=user
        next()

    } catch (error) {
        res.status(500).json({message:"Internal Server Error!"})
        console.log(error)
    }
}



const isuser = async(req,res,next)=>{
    try {
        const token = req.cookies.token
        if(!token){
            return res.status(401).json({success:false,message:"Unautharised Token"})
        }

        const decoded =jwt.verify(token,process.env.SECRETKEY)

        const user = await UserModel.findById(decoded.userId)

        if(!user){
            return res.status(401).json({success:false,message:"Inavlid Operation"})
        }
        
        req.user=user
        next()
    } catch (error) {
        res.status(500).json({message:"Internal Server Error!"})
        console.log(error)
    }
}

export {isAdmin,isuser}
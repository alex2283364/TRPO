import UserModel from '../Models/user.js'
import Teacher from '../Models/teachers.js'
import Student from '../Models/students.js'
import Schedule from '../Models/schedule.js';

const deleteuser = async(req,res) =>{
    try {
        const userId = req.params.id

        const checkAdmin = await UserModel.findById(userId)
        if(checkAdmin.role =='HOD'){
            return res.status(409).json({message:"you Cannot  Delete Yourself"})
        }else if (checkAdmin.role === "Teacher") {
            await Schedule.deleteMany({ teacherId: userId });
            await Teacher.findOneAndDelete({ userId: userId });
        } else if (checkAdmin.role === "Student") {
            await Student.findOneAndDelete({ userId: userId});
        } 

        const user = await UserModel.findByIdAndDelete(userId)

        if(!user){
            return res.status(404).json({success:false,message:"User Not Found"})
        }
        res.status(200).json({message:"User Deleted Succesfully",user})
    } catch (error) {
        res.status(500).json({message:"Internal Server Error!"})
        console.log(error)
    }
}

export {deleteuser}

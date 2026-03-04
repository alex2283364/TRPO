import UserModel from "../Models/user.js";
import Teacher from "../Models/teachers.js";
import HOD from "../Models/hod.js";
import Student from "../Models/students.js";
import bcrypt from "bcryptjs";
import jwt from "jsonwebtoken";

const register = async (req, res) => {
    try {
      const { name, email, password, role, department } = req.body;

      const isExist = await UserModel.findOne({ email });
      if (isExist) {
        return res.status(401).json({ success: false, message: "User Already Exists!" });
      }
  
      const hashedPassword = bcrypt.hashSync(password, 10);
  
      const newUser = new UserModel({
        name,
        email,
        password: hashedPassword,
        role,
      });
  
      await newUser.save();
  
      let referenceId;
  
      if (role === "Teacher") {

        const available = [
          {
            day: "M",
            periods: [
              { period: 1, isAvailable: true },
              { period: 2, isAvailable: true },
              { period: 3, isAvailable: true },
              { period: 4, isAvailable: true },
            ],
          },
          {
            day: "T",
            periods: [
              { period: 1, isAvailable: true },
              { period: 2, isAvailable: true },
              { period: 3, isAvailable: true },
              { period: 4, isAvailable: true },
            ],
          },
          {
            day: "W",
            periods: [
              { period: 1, isAvailable: true },
              { period: 2, isAvailable: true },
              { period: 3, isAvailable: true },
              { period: 4, isAvailable: true },
            ],
          },
          {
            day: "Th",
            periods: [
              { period: 1, isAvailable: true },
              { period: 2, isAvailable: true },
              { period: 3, isAvailable: true },
              { period: 4, isAvailable: true },
            ],
          },
          {
            day: "F",
            periods: [
              { period: 1, isAvailable: true },
              { period: 2, isAvailable: true },
              { period: 3, isAvailable: true },
              { period: 4, isAvailable: true },
            ],
          }
        ];
  
 
        const newTeacher = await Teacher.create({
          userId: newUser._id,
          department,
          available,
        });
  
        referenceId = newTeacher._id;
      }else if (role === "HOD") {
 
        const newHOD = await HOD.create({
          userId: newUser._id,
          department,
          managedClasses: [], 
        });
  
        referenceId = newHOD._id;
      } else if (role === "Student") {
 
        const newStudent = await Student.create({
          userId: newUser._id
        });
  
        referenceId = newStudent._id;
      } else {
        return res.status(400).json({ success: false, message: "Invalid Role Specified" });
      }
   

      newUser.referenceId = referenceId;
      await newUser.save();
  
      res.status(200).json({ message: "User Registered Successfully", user: newUser });
    } catch (error) {
      res.status(500).json({ success: false, message: "Internal Server Error" });
      console.error(error);
    }
  };

const login = async (req, res) => {
  try {
    const { email, password } = req.body;

    const user = await UserModel.findOne({ email });
    if (!user) {
      return res.status(404).json({ success: false, message: "User Does Not Exist" });
    }

    const isValidPassword = bcrypt.compareSync(password, user.password);
    if (!isValidPassword) {
      return res.status(401).json({ success: false, message: "Invalid Password" });
    }

    const token = jwt.sign({ userId: user._id, role: user.role }, process.env.SECRETKEY, {
      expiresIn: "1h",
    });

    // Set the token in cookies
    res.cookie("token", token, {
      httpOnly: true,
      secure: true, 
      sameSite:"None",
      maxAge: 3600000, // 1 hour
    });

    res.status(200).json({ success: true, message: "Logged In Successfully", user, token });
  } catch (error) {
    res.status(500).json({ success: false, message: "Internal Server Error" });
    console.error(error);
  }
};

const logout = async (req, res) => {
  try {
  
    res.clearCookie("token");
    res.status(200).json({ success: true, message: "Logged Out Successfully" });
  } catch (error) {
    res.status(500).json({ success: false, message: "Internal Server Error" });
    console.error(error);
  }
};


const checkuser =async(req,res)=>{
  try {
    const user =req.user
    if(!user){
      res.status(404).json({message:"User Not Found"})
    }
    res.status(200).json(user)
  } catch (error) {
    res.status(500).json({message:"Internal Server Error"})
    console.log(error)
  }
}

//get teachers
const getTeachers = async (req, res) => {
  try {
    const teachers = await UserModel.find({ role: 'Teacher' });

    if (teachers.length === 0) {
      return res.status(200).json({ message: "No Teacher found." });
    }

    res.status(200).json({ teachers });
  } catch (error) {
    res.status(500).json({ message: "Internal Server Error!" });
    console.log(error);
  }
};
//getstudents
const getstudents = async (req, res) => {
  try {
    const students = await UserModel.find({ role: 'Student' });

    if (students.length === 0) {
      return res.status(200).json({ message: "No Students found." });
    }

    res.status(200).json({ students });
  } catch (error) {
    res.status(500).json({ message: "Internal Server Error!" });
    console.log(error);
  }
};



export { register, login, logout ,checkuser, getTeachers,getstudents};

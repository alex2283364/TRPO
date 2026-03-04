import Teacher from "../Models/teachers.js";
import UserModel from "../Models/user.js";

const getAvailableTeachers = async (req, res) => {
    try {
        const { day, period } = req.query;

        if (!day || !period) {
            return res.status(400).json({ success: false, message: "Day and period are required." });
        }

        const availableTeachers = await Teacher.find({
            available: {
                $elemMatch: {
                    day,
                    periods: {
                        $elemMatch: {
                            period: Number(period), 
                            isAvailable: true
                        }
                    }
                }
            }
        }, { userId: 1, _id: 0 });

        
        const userIds = availableTeachers.map((teacher) => teacher.userId);

        const teacherDetails = await UserModel.find(
            { _id: { $in: userIds } },
            { _id: 1, name: 1 } 
        );

        if (teacherDetails.length === 0) {
            return res.status(404).json({ success: false, message: "No teachers found for the specified criteria." });
        }

        res.status(200).json({
            success: true,
            message: "Available teachers retrieved successfully.",
            data: teacherDetails
        });
    } catch (error) {
        res.status(500).json({ success: false, message: "Internal Server Error." });
        console.error(error);
    }
};

export { getAvailableTeachers };

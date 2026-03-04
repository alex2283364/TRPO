import Schedule from "../Models/schedule.js";
import Teacher from "../Models/teachers.js";

const assignTeacher = async (req, res) => {
    try {
        const { classId, teacherId, day, period } = req.body;

        if (!classId || !teacherId || !day || !period) {
            return res.status(400).json({ success: false, message: "All fields are required!" });
        }

   
        const teacher = await Teacher.findOne({
            userId: teacherId,
            available: {
                $elemMatch: {
                    day,
                    periods: { $elemMatch: { period, isAvailable: true } },
                },
            },
        });

        if (!teacher) {
            return res.status(400).json({ success: false, message: "Teacher is not available for the specified slot!" });
        }

        const existingSchedule = await Schedule.findOne({ classId, day, period });
        if (existingSchedule) {
            return res.status(409).json({ success: false, message: "This slot is already assigned to another teacher!" });
        }

        const schedule = await Schedule.create({ classId, teacherId, day, period });

        await Teacher.updateOne(
            { userId: teacherId, "available.day": day },
            {
                $set: {
                    "available.$[dayFilter].periods.$[periodFilter].isAvailable": false,
                },
            },
            {
                arrayFilters: [{ "dayFilter.day": day }, { "periodFilter.period": period }],
            }
        );

        res.status(200).json({ success: true, message: "Teacher assigned successfully!", schedule });
    } catch (error) {
        res.status(500).json({ success: false, message: "Internal Server Error." });
        console.error(error);
    }
};

export {assignTeacher}
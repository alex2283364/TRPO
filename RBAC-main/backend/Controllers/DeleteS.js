import Schedule from "../Models/schedule.js";
import Teacher from "../Models/teachers.js";

const deleteSchedule = async (req, res) => {
    try {
        const  scheduleId  = req.params.id;

        const schedule = await Schedule.findById(scheduleId);
        if (!schedule) {
            return res.status(404).json({ success: false, message: "Schedule not found!" });
        }

        const { teacherId, day, period } = schedule;

        await Schedule.findByIdAndDelete(scheduleId);

        await Teacher.updateOne(
            { userId: teacherId, "available.day": day },
            {
                $set: {
                    "available.$[dayFilter].periods.$[periodFilter].isAvailable": true,
                },
            },
            {
                arrayFilters: [{ "dayFilter.day": day }, { "periodFilter.period": period }],
            }
        );

        res.status(200).json({ success: true, message: "Schedule deleted and teacher's availability updated successfully!" });
    } catch (error) {
        res.status(500).json({ success: false, message: "Internal Server Error." });
        console.error(error);
    }
};

export{deleteSchedule}
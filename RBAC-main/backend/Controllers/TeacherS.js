import Schedule from "../Models/schedule.js";

const getTschedule = async (req, res) => {
    try {
        const tId  = req.params.tId;

        const schedules = await Schedule.find({ teacherId:tId })
            
        if (!schedules.length) {
            return res.status(404).json({ success: false, message: "No schedules found for You!" });
        }

        res.status(200).json({ success: true, message: "Class schedule retrieved successfully!", schedules });
    } catch (error) {
        res.status(500).json({ success: false, message: "Internal Server Error." });
        console.error(error);
    }
};

export {getTschedule}

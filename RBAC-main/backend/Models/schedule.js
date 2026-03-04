import mongoose from "mongoose";


const scheduleSchema = new mongoose.Schema({
    classId: { type: String,required: true },  
    teacherId: { type: mongoose.Schema.Types.ObjectId, ref: "User", required: true },
    day: { type: String, enum: ["M", "T", "W", "Th", "F"], required: true },
    period: { type: Number, required: true }, 
    createdAt: { type: Date, default: Date.now }
});


const Schedule = mongoose.model("Schedule", scheduleSchema);

export default Schedule;

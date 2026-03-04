import mongoose from 'mongoose'

const teacherSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    department: { type: String, required: true },
    available: [
        {
            day: { type: String, enum: ['M', 'T', 'W', 'Th', 'F'] },
            periods: [{ period: Number, isAvailable: Boolean }]
        }
    ],
    assignedSchedules: [
        {
            classId: { type: mongoose.Schema.Types.ObjectId, ref: 'Class' },
            day: String,
            period: Number
        }
    ],
    tutorOf: { type: mongoose.Schema.Types.ObjectId, ref: 'Class' }
});

export const Teacher = mongoose.model('Teacher', teacherSchema);


export default Teacher;

import mongoose from "mongoose";

const userSchema = new mongoose.Schema({
    name: { type: String, required: true },
    email: { type: String, required: true, unique: true },
    password: { type: String, required: true },  
    role: { type: String, enum: ['HOD', 'Teacher', 'Student'], required: true },  
    referenceId: { type: mongoose.Schema.Types.ObjectId },  
    createdAt: { type: Date, default: Date.now }
});

export const UserModel = mongoose.model('User', userSchema);


export default UserModel
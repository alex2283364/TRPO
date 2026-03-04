import mongoose from "mongoose";

const classSchema = new mongoose.Schema({
    id: { type: String, required: true, unique: true },  
    name: { type: String, required: true },             
    room: { type: String, required: true },             
    tutor: { type: mongoose.Schema.Types.ObjectId, ref: "User" }, 
    students: [{ type: mongoose.Schema.Types.ObjectId, ref: "Student" }], 
    createdAt: { type: Date, default: Date.now },      
});

const Class = mongoose.model("Class", classSchema);

export default Class;

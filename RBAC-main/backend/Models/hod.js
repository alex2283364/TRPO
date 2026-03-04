import mongoose from 'mongoose'

const hodSchema = new mongoose.Schema({
    userId: { type: mongoose.Schema.Types.ObjectId, ref: 'User', required: true },
    department: { type: String, required: true },
    managedClasses: [{ type: mongoose.Schema.Types.ObjectId, ref: 'Class' }]
});

const HOD = mongoose.model('HOD', hodSchema);
export default  HOD
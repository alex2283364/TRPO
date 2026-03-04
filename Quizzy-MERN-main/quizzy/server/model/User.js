const mongoose = require("mongoose")

const UserSchema = new mongoose.Schema({
    name: String,
    email: String,
    password: String,
    role: String,
    dept: String,
    phone: String
})

const UserModel = mongoose.model("user_credentials", UserSchema)

module.exports = UserModel
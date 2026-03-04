import express from 'express'
import { getUser } from '../Controllers/Admin.js'
import { isAdmin } from '../MiddleWare/VerifyToken.js'
import { getAvailableTeachers } from '../Controllers/Available.js'
import { assignTeacher } from '../Controllers/AssignS.js'
import { deleteSchedule } from '../Controllers/DeleteS.js'
import { getClassSchedule } from '../Controllers/ViewS.js'
import { deleteuser } from '../Controllers/DeleteUsers.js'


const AuthAdmin = express.Router()

AuthAdmin.get('/getuser',isAdmin,getUser)
AuthAdmin.delete('/delete/:id',isAdmin,deleteuser)
AuthAdmin.get('/available',isAdmin,getAvailableTeachers)
AuthAdmin.post('/assignS',isAdmin,assignTeacher)
AuthAdmin.post('/deleteS/:id',isAdmin,deleteSchedule)
AuthAdmin.get('/classS/:classId',isAdmin,getClassSchedule)

export default AuthAdmin
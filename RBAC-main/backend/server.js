import express from 'express'
import dotenv from 'dotenv'
import cors from 'cors'
import DbCon from './Utils/db.js'
import AuthRoutes from './Routes/Auth.js'
import AuthAdmin from './Routes/AdminRoute.js'
import cookieparser from 'cookie-parser'

dotenv.config()

const app = express();
const PORT = process.env.PORT || 3000

DbCon()


app.use(express.json())
app.use(cors({
    credentials: true,
    origin : "https://rbac-frontend-bu6e.onrender.com"
}))
app.use(cookieparser())

app.use('/api/auth',AuthRoutes)
app.use('/api/admin',AuthAdmin)


app.get('/',(req,res)=>{
    res.send('test')
})

app.listen(PORT,()=>{
    console.log(`server is running on ${PORT}`)
})

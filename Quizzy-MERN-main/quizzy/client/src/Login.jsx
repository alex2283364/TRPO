import { Link } from "react-router-dom"
import { useState } from "react"
import axios from 'axios'
import { useNavigate } from "react-router-dom"
import './Login.css';

export default function Login(){

    const [email, setEmail] = useState('')
    const [password, setPassword] = useState('')
    const navigate = useNavigate()

    const handleSubmit = (e) => {
        e.preventDefault()
        axios.post('http://localhost:3001/login', {email, password})
        .then(result => {
            console.log(result)
            if (result.data.message === "Success"){
                navigate('/dashboard', { state: { name: result.data.name, email: result.data.email, role: result.data.role, dept: result.data.dept } })
            }
            else if (result.data.message === "The password is incorrect"){
                window.alert("Invalid Credentials. Try Again...")
                navigate('/login')
            }
            else{
                window.alert("No such user exists. Create one...")
                navigate('/register')
            }
        })
        .catch(err=> console.log(err))
    }

    return(
        <div className="d-flex justify-content-center align-items-center bg-secondary vh-100">
            <div className="bg-white p-3 rounded w-25">
            <h2>Login</h2>
            <form onSubmit={handleSubmit}>
                <div className="mb-3">
                    <label htmlFor="email">
                        <strong>Email</strong>
                    </label>
                    <input
                        type="email"
                        placeholder="Enter Email"
                        autoComplete="off"
                        name="email"
                        className="form-control rounded-0"
                        onChange={(e) => setEmail(e.target.value)}
                        required
                    />
                </div>
                <div className="mb-3">
                    <label htmlFor="password">
                        <strong>Password</strong>
                    </label>
                    <input
                        type="password"
                        placeholder="Enter Password"
                        autoComplete="off"
                        name="password"
                        className="form-control rounded-0"
                        onChange={(e) => setPassword(e.target.value)}
                        required
                    />
                </div>
                <button type="submit" className="btn btn-success w-100 rounded-0">Login</button>
                </form>
                <center><p>Don't have an Account</p></center>
                <Link to="/register" className="btn btn-default border w-100 bg-light rounded-0 text-decoration-none">Register</Link>
            </div>
        </div>
    );
}
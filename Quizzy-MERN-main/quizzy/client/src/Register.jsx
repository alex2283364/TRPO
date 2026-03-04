import { Link } from "react-router-dom"
import { useState } from "react"
import axios from 'axios'
import { useNavigate } from "react-router-dom"

export default function Register(){

    const [name, setName] = useState('')
    const [email, setEmail] = useState('')
    const [password, setPassword] = useState('')
    const [role, setRole] = useState('')
    const [dept, setDept] = useState('')
    const [phone, setPhone] = useState('')
    const navigate = useNavigate()

    const handleSubmit = (e) => {
        e.preventDefault()
        axios.post('http://localhost:3001/register', {name, email, password, role, dept, phone})
        .then(result => {console.log(result)
            navigate('/dashboard', { state: { name: result.data.name, email: result.data.email, role: result.data.role, dept: result.data.dept } })
        })
        .catch(err=> console.log(err))
    }

    return(
        <div className="d-flex justify-content-center align-items-center bg-secondary vh-100">
            <div className="bg-white p-3 rounded w-25">
            <h2>Register</h2>
            <form onSubmit={handleSubmit}>
                <div className="mb-3">
                    <label htmlFor="email">
                        <strong>Name</strong>
                    </label>
                    <input
                        type="text"
                        placeholder="Enter name"
                        autoComplete="off"
                        name="name"
                        className="form-control rounded-0"
                        onChange={(e) => setName(e.target.value)}
                        required
                    />
                </div>
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
                <div className="mb-3">
                    <label htmlFor="role">
                        <strong>Role</strong>
                    </label>
                    <input
                        type="text"
                        placeholder="Student / Teacher"
                        autoComplete="off"
                        name="role"
                        className="form-control rounded-0"
                        onChange={(e) => setRole(e.target.value)}
                        required
                    />
                </div>
                <div className="mb-3">
                    <label htmlFor="department">
                        <strong>Department</strong>
                    </label>
                    <input
                        type="text"
                        placeholder="Department-Year(in Roman Letters)-Section"
                        autoComplete="off"
                        name="role"
                        className="form-control rounded-0"
                        onChange={(e) => setDept(e.target.value)}
                        required
                    />
                </div>
                <div className="mb-3">
                    <label htmlFor="phone">
                        <strong>Phone</strong>
                    </label>
                    <input
                        type="text"
                        placeholder="Phone number"
                        autoComplete="off"
                        name="role"
                        className="form-control rounded-0"
                        onChange={(e) => setPhone(e.target.value)}
                        required
                    />
                </div>
                <button type="submit" className="btn btn-success w-100 rounded-0">Register</button>
                </form>
                <center><p>Already have an Account</p></center>
                <Link to="/login" className="btn btn-default border w-100 bg-light rounded-0 text-decoration-none">Login</Link>
            </div>
        </div>
    );
}
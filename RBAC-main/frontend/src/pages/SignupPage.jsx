import React, { useState } from 'react';
import { Link, useNavigate } from "react-router-dom";
import { post } from '../services/ApiEndPoint';
import { toast } from 'react-hot-toast';
import { motion } from "framer-motion";

const Signup = () => {

	const navigate = useNavigate();
	const [formData, setFormData] = useState({
		name: "",
		email: "",
		password: "",
		confirmPassword: "",
		role: "Student",
		department: "",
	});
	const [isMatching, setIsMatching] = useState(false); // Tracks password match status

	const handleChange = (e) => {
		const { name, value } = e.target;
		setFormData({ ...formData, [name]: value });

		if (name === "confirmPassword" || name === "password") {
			setIsMatching(
				name === "confirmPassword" 
					? value === formData.password 
					: value === formData.confirmPassword
			);
		}
	};

	const handleSubmit = async (e) => {
		e.preventDefault();
		if (!isMatching) {
			toast.error("Passwords do not match");
			return;
		}

		try {
			const request = await post('/api/auth/register', formData);
			const response = request.data;
			if (request.status === 200) {
				toast.success(response.message);
				navigate('/login');
			}
		} catch (error) {
			//console.log(error);
			toast.error(error.response.data.message);
		}
	};

	return (
		<motion.div
			className="flex items-center justify-center min-h-screen bg-gray-900"
			initial={{ opacity: 0 }}
			animate={{ opacity: 1 }}
			transition={{ duration: 0.5 }}
		>
			<div className="bg-gray-800 bg-opacity-50 backdrop-blur-md shadow-lg rounded-xl p-6 border border-gray-700 max-w-md w-full">
				<h2 className="text-2xl font-semibold text-center text-gray-100 mb-6">Signup</h2>
				<form onSubmit={handleSubmit}>
					<div className="mb-4">
						<label htmlFor="name" className="block text-gray-400 text-sm font-medium mb-2">Name</label>
						<input
							type="text"
							name="name"
							id="name"
							className="bg-gray-700 text-white placeholder-gray-400 rounded-lg w-full px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
							placeholder="Enter your name"
							value={formData.name}
							onChange={handleChange}
							required
						/>
					</div>
					<div className="mb-4">
						<label htmlFor="email" className="block text-gray-400 text-sm font-medium mb-2">Email</label>
						<input
							type="email"
							name="email"
							id="email"
							className="bg-gray-700 text-white placeholder-gray-400 rounded-lg w-full px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
							placeholder="Enter your email"
							value={formData.email}
							onChange={handleChange}
							required
						/>
					</div>
					<div className="mb-4">
						<label htmlFor="password" className="block text-gray-400 text-sm font-medium mb-2">Password</label>
						<input
							type="password"
							name="password"
							id="password"
							className="bg-gray-700 text-white placeholder-gray-400 rounded-lg w-full px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
							placeholder="Enter your password"
							value={formData.password}
							onChange={handleChange}
							required
						/>
					</div>
					<div className="mb-4">
						<label htmlFor="confirmPassword" className="block text-gray-400 text-sm font-medium mb-2">Confirm Password</label>
						<input
							type="password"
							name="confirmPassword"
							id="confirmPassword"
							className={`bg-gray-700 text-white placeholder-gray-400 rounded-lg w-full px-4 py-2 focus:outline-none focus:ring-2 ${
								isMatching
									? "ring-green-500 border-green-500"
									: "ring-red-500 border-red-500"
							}`}
							placeholder="Confirm your password"
							value={formData.confirmPassword}
							onChange={handleChange}
							required
						/>
					</div>
					<div className="mb-4">
						<label htmlFor="role" className="block text-gray-400 text-sm font-medium mb-2">Role</label>
						<select
							name="role"
							id="role"
							className="bg-gray-700 text-white placeholder-gray-400 rounded-lg w-full px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
							value={formData.role}
							onChange={handleChange}
						>
							<option value="Student">Student</option>
							<option value="Teacher">Teacher</option>
							<option value="HOD">HOD</option>
						</select>
					</div>
					<div className="mb-6">
						<label htmlFor="department" className="block text-gray-400 text-sm font-medium mb-2">Department</label>
						<input
							type="text"
							name="department"
							id="department"
							className="bg-gray-700 text-white placeholder-gray-400 rounded-lg w-full px-4 py-2 focus:outline-none focus:ring-2 focus:ring-blue-500"
							placeholder="Enter your department"
							value={formData.department}
							onChange={handleChange}
							required
						/>
					</div>
					<button
						type="submit"
						className={`w-full text-white font-semibold py-2 px-4 rounded-lg ${
							isMatching
								? "bg-blue-500 hover:bg-blue-600"
								: "bg-gray-500 cursor-not-allowed"
						}`}
						disabled={!isMatching} // Disable button if passwords don't match
					>
						Signup
					</button>
				</form>
				<p className="text-gray-400 text-sm text-center mt-4">
					Already have an account?{" "}
					<Link to="/login" className="text-blue-500 hover:underline">
						Login
					</Link>
				</p>
			</div>
		</motion.div>
	);
};

export default Signup;

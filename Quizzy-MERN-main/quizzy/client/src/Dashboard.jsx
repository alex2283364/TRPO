import React, { useState, useEffect } from 'react';
import { useLocation } from "react-router-dom";
import { useNavigate } from "react-router-dom";
import './Dashboard.css';
import axios from 'axios';

export default function Dashboard() {
    const { state } = useLocation();
    const { name, email, role, dept } = state;
    const [emailID, setEmailId] = useState('');
    const [quizId, setQuizId] = useState('');
    const [currentTime, setCurrentTime] = useState(new Date().toLocaleTimeString());
    const navigate = useNavigate();
    const [marksVisible, setMarksVisible] = useState(false);
    const [marks, setMarks] = useState([]);

    const handleCreateQuiz = () => {
        navigate('/create', { state: { name: name, email: email, role: role, dept: dept } })
    }

    const handleAttemptQuiz = () => {
        axios.post('http://localhost:3001/check-quiz-attempt', { email, topic: quizId })
            .then(response => {
                const { attempted } = response.data;
                if (attempted) {
                    alert('You have already attempted this quiz.');
                } else {
                    navigate('/attempt', { state: { name, email, role, dept, topic: quizId } });
                }
            })
            .catch(error => {
                console.error('Error checking quiz attempt:', error);
                alert('Error checking quiz attempt. Please try again later.');
            });
    };

    // Teacher Dashboard
    const handleCheckTeacherMarks = () => {
        axios.post('http://localhost:3001/check-teacher-marks', { quizTopic: emailID })
            .then(response => {
                const { marks } = response.data;
                setMarks(marks);
                setMarksVisible(true);
            })
            .catch(error => {
                console.error('Error fetching marks:', error);
                setMarksVisible(false);
            });
    };

    // Student Dashboard
    const handleCheckStudentMarks = () => {
        axios.post('http://localhost:3001/check-student-marks', { email })
            .then(response => {
                const { marks } = response.data;
                setMarks(marks);
                setMarksVisible(true);
            })
            .catch(error => {
                console.error('Error fetching marks:', error);
                setMarksVisible(false);
            });
    };

    const handleLogout = () => {
        navigate('/home');
    }

    useEffect(() => {
        const intervalId = setInterval(() => {
            setCurrentTime(new Date().toLocaleTimeString());
        }, 1000);

        return () => clearInterval(intervalId);
    }, []);

    const MarksDisplay = () => {
        return (
            <div style={{ marginBottom: '20px', display: marksVisible ? 'block' : 'none' }}>
                <h3>My Marks:</h3>
                <table className="table">
                    <thead>
                        <tr>
                            <th>{role === "Teacher" ? "Email ID" : "Topic"}</th>
                            <th>Score</th>
                        </tr>
                    </thead>
                    <tbody>
                        {marks.map((mark, index) => (
                            <tr key={index}>
                                <td>{role === "Teacher" ? mark.name : mark.topic}</td>
                                <td>{mark.score}</td>
                            </tr>
                        ))}
                    </tbody>
                </table>
            </div>
        );
    };

    return (
        <div className="container d-flex justify-content-center align-items-center vh-100">
            <div className="text-center dashboard-container">
                <h1>Welcome {name}</h1>
                <h2 className="mb-4">Department: {dept}</h2>
                {role === "Teacher" && (
                    <div>
                        <h3 className="mb-4">Teacher Dashboard</h3>
                        <div className="mb-3 text-center">
                            <input
                                type="text"
                                placeholder="Enter Quiz Topic"
                                value={emailID}
                                onChange={(e) => setEmailId(e.target.value)}
                                className="form-control me-2"
                                style={{ width: '200px', display: 'inline-block' }}
                            />
                        </div>
                        <div className="text-center mb-4">
                            <button className="btn btn-primary me-2" onClick={handleCheckTeacherMarks}>Check Marks</button>
                            <button className="btn btn-success me-2" onClick={handleCreateQuiz}>Create Quiz</button>
                        </div>
                    </div>
                )}
                {role === "Student" && (
                    <div>
                        <h3 className="mb-4">Student Dashboard</h3>
                        <div className="mb-3 text-center">
                            <p className="mt-4">Current time: {currentTime}</p>
                            <input
                                type="text"
                                placeholder="Enter Quiz Topic"
                                value={quizId}
                                onChange={(e) => setQuizId(e.target.value)}
                                className="form-control me-2"
                                style={{ width: '200px', display: 'inline-block' }}
                            />
                        </div>
                        <div className="text-center mb-4">
                            <button className="btn btn-primary me-2" onClick={handleCheckStudentMarks}>Check Marks</button>
                            <button className="btn btn-success me-2" onClick={handleAttemptQuiz}>Attempt Quiz</button>
                        </div>
                    </div>
                )}
                <MarksDisplay />
                <button onClick={handleLogout} className="btn btn-danger">Logout</button>
            </div>
        </div>
    );
}

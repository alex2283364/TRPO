import React, { useState } from 'react';
import { useLocation } from "react-router-dom";
import { useNavigate } from "react-router-dom"
import axios from 'axios';

export default function Create() {
    const [numQuestions, setNumQuestions] = useState(0);
    const [questions, setQuestions] = useState([]);
    const [quizTopic, setQuizTopic] = useState('');
    const [duration, setDuration] = useState(0); // New state for duration

    const navigate = useNavigate()

    const { state } = useLocation();
    const { name, email, role, dept } = state;

    const handleChange = (e) => {
        const value = e.target.value;
    
        if (!isNaN(value) && parseInt(value) >= 0) {
            setNumQuestions(parseInt(value));
        } else {
            console.error("Invalid number of questions");
        }
    };

    const handleCreate = () => {
        const newQuestions = [];

        for (let i = 0; i < numQuestions; i++) {
            newQuestions.push({
                question: '',
                options: ['', '', '', ''], 
                correctOption: '',
                marks: ''
            });
        }

        setQuestions(newQuestions);
    };

    const handleQuestionChange = (index, e) => {
        const updatedQuestions = [...questions];
        updatedQuestions[index].question = e.target.value;
        setQuestions(updatedQuestions);
    };

    const handleOptionChange = (index, optionIndex, e) => {
        const updatedQuestions = [...questions];
        updatedQuestions[index].options[optionIndex] = e.target.value;
        setQuestions(updatedQuestions);
    };

    const handleCorrectOptionChange = (index, e) => {
        const updatedQuestions = [...questions];
        updatedQuestions[index].correctOption = e.target.value;
        setQuestions(updatedQuestions);
    };

    const handleMarksChange = (index, e) => {
        const updatedQuestions = [...questions];
        updatedQuestions[index].marks = e.target.value;
        setQuestions(updatedQuestions);
    };

    const handleSubmit = () => {
        const quizData = {
            quizTopic,
            duration, // Add duration to quiz data
            questions
        };

        axios.post('http://localhost:3001/addQuestions', quizData)
            .then(result => {
                if (result.data.message === "Quiz added successfully"){
                    navigate('/dashboard', { state: { name, email, role, dept } })
                    window.alert("Successfully Created!!!")
                }
                else{
                    window.alert("Try again...")
                }
            })
            .catch(err => console.log(err));
    };

    return (
        <div className="container mt-5">
            <div className="row mb-3">
                <div className="col">
                    <label htmlFor="quizTopic" className="form-label">Quiz Topic:</label>
                    <input type="text" id="quizTopic" className="form-control" value={quizTopic} onChange={(e) => setQuizTopic(e.target.value)} required />
                </div>
            </div>
            <div className="row mb-3">
                <div className="col">
                    <label htmlFor="numQuestions" className="form-label">Number of Questions:</label>
                    <input type="number" id="numQuestions" className="form-control" value={numQuestions} onChange={handleChange} required />
                </div>
            </div>
            <div className="row mb-3">
                <div className="col">
                    <label htmlFor="duration" className="form-label">Duration (in minutes):</label> {/* New duration input field */}
                    <input type="number" id="duration" className="form-control" value={duration} onChange={(e) => setDuration(parseInt(e.target.value))} required />
                </div>
            </div>
            <div className="row mb-3">
                <div className="col">
                    <button className="btn btn-primary" onClick={handleCreate}>Create</button>
                </div>
            </div>

            {questions.map((question, index) => (
                <div key={index} className="mb-4">
                    <h4>Question {index + 1}:</h4>
                    <input type="text" value={question.question} onChange={(e) => handleQuestionChange(index, e)} className="form-control mb-2" placeholder="Enter question" required />

                    <h5>Options:</h5>
                    {question.options.map((option, optionIndex) => (
                        <input key={optionIndex} type="text" value={option} onChange={(e) => handleOptionChange(index, optionIndex, e)} className="form-control mb-2" placeholder={`Option ${optionIndex + 1}`} required />
                    ))}

                    <input type="number" min="1" max="4" value={question.correctOption} onChange={(e) => handleCorrectOptionChange(index, e)} className="form-control mb-2" placeholder="Correct Option" required />
                    <input type="number" value={question.marks} onChange={(e) => handleMarksChange(index, e)} className="form-control mb-2" placeholder="Marks" required />
                </div>
            ))}

            <button onClick={handleSubmit} className="btn btn-success">Submit</button>
        </div>
    );
}

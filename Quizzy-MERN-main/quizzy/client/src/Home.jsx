import React from 'react';
import { Link } from 'react-router-dom';
import "./Home.css"

export default function Home(){
    return(
        <>
        <div id='background'>
                <div id='navbar'>
                    <Link to="/home" id='logo'>
                        <h1>&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Quizzy!</h1>
                    </Link>
                </div>
                <div id='content'>
                    <h1>Quizzy!</h1>
                    <h2>A one stop solution to make and evaluate</h2>
                    <h2>Quizes online!<i> Create, Send, and Analyze</i> your</h2>
                    <h2>quizzes and assesments for free with Quizzy!</h2>
                    <button id='button'>
                        <Link to="/register" style={{ textDecoration: 'none', color: 'inherit' }}>
                            Get Started for Free
                        </Link>
                    </button>
                    <button id='button'>
                        <Link to="/login" style={{ textDecoration: 'none', color: 'inherit' }}>
                            Already have an account?
                        </Link>
                    </button>
                </div>
                </div>
        </>
    )
}

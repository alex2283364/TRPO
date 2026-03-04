const express = require("express");
const mongoose = require("mongoose");
const cors = require("cors");
const UserModel = require('./model/User');
const QuizModel = require('./model/Quiz');
const MarkModel = require('./model/Mark');

const app = express();
app.use(express.json());
app.use(cors());

mongoose.connect("mongodb://localhost:27017/quizzy");

app.post('/addQuestions', (req, res) => {
    const { quizTopic, duration, questions } = req.body;

    QuizModel.create({ quizTopic, duration, questions })
        .then(quiz => {
            res.json({ message: 'Quiz added successfully', quiz });
        })
        .catch(err => {
            res.json({ error: err.message });
        });
});

app.post('/login', (req, res) => {
    const { email, password } = req.body;
    
    UserModel.findOne({ email: email })
        .then(user => {
            if (user) {
                if (user.password === password) {
                    res.json({
                        message: "Success",
                        name: user.name,
                        email: user.email,
                        role: user.role,
                        dept: user.dept
                    });
                } else {
                    res.json({
                        message: "The password is incorrect"
                    });
                }
            } else {
                res.json({
                    message: "No record exists"
                });
            }
        });
});

app.post('/register', (req, res) => {
    UserModel.create(req.body)
        .then(user => res.json(user))
        .catch(err => res.status(500).json({ error: err.message }));
});

app.post('/check-quiz-attempt', (req, res) => {
    const { email, topic } = req.body;

    // Query the database to check if the user has already attempted the quiz
    MarkModel.findOne({ email, topic })
        .then(attempt => {
            if (attempt) {
                // User has already attempted the quiz
                res.status(200).json({ attempted: true });
            } else {
                // User has not attempted the quiz yet
                res.status(200).json({ attempted: false });
            }
        })
        .catch(error => {
            console.error('Error checking quiz attempt:', error);
            res.status(500).json({ error: 'Internal Server Error' });
        });
});

app.post('/quiz-results', (req, res) => {
    const { topic, name, email, dept, score, answers } = req.body;
    
    console.log('Received score:', score); // Log score to verify
    
    MarkModel.create({
        topic,
        name,
        email,
        dept,
        score,
        answers,
    })
    .then(() => {
        res.status(201).send('Quiz results saved successfully');
    })
    .catch(error => {
        console.error('Error saving quiz results:', error);
        res.status(500).send('Internal Server Error');
    });
});


// Teacher marks endpoint
app.post('/check-teacher-marks', (req, res) => {
    const { quizTopic } = req.body;
    // Fetch marks for the given quiz topic from the database
    MarkModel.find({ topic: quizTopic })
        .sort({ name: 1 }) // Sort marks by email in ascending order
        .then(marks => {
            res.json({ marks });
        })
        .catch(error => {
            console.error('Error fetching marks:', error);
            res.status(500).json({ error: 'Error fetching marks' });
        });
});

app.post('/check-student-marks', (req, res) => {
    const { email } = req.body;
    MarkModel.find({ email })
        .then(marks => {
            res.json({ marks });
        })
        .catch(error => {
            console.error('Error fetching marks:', error);
            res.status(500).json({ error: 'Error fetching marks' });
        });
});

app.get('/questions/:topic', (req, res) => {
    const topic = req.params.topic;

    QuizModel.findOne({ quizTopic: topic })
        .then(quiz => {
            if (quiz) {
                const { duration, questions } = quiz;
                res.json({ duration, questions });
            } else {
                res.status(404).json({ message: 'Quiz not found for the specified topic' });
            }
        })
        .catch(err => {
            res.status(500).json({ error: err.message });
        });
});

app.listen(3001, () => {
    console.log("Server is running");
});

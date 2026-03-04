const mongoose = require('mongoose');

const quizSchema = new mongoose.Schema({
    quizTopic: {
        type: String,
        required: true
    },
    questions: [{
        question: {
            type: String,
            required: true
        },
        options: {
            type: [String],
            required: true
        },
        correctOption: {
            type: Number,
            required: true
        },
        marks: {
            type: Number,
            required: true
        }
    }],
    duration: {
        type: Number,
        required: true
    }
});

const QuizModel = mongoose.model('quiz_datas', quizSchema);

module.exports = QuizModel;

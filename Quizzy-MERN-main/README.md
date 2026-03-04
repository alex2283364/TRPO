# Quizzy - Quiz Management System

Quizzy is a quiz management system built with React for the frontend and Node.js with Express for the backend. It allows users to register, log in, create quizzes, and check their scores.

## Features
- **User Registration and Login**: Users can register and log in to access the application.
- **Quiz Creation**: Teachers can create quizzes with specified topics, durations, and questions.
- **Quiz Attempt Checking**: Users can check if they have already attempted a quiz.
- **Score Submission**: Users can submit their quiz scores along with answers.
- **Mark Retrieval**: Teachers can view marks for specific quiz topics and students can check their marks.

## Technologies Used
- **Frontend**: 
  - React
  - React Router
  - Axios for API calls
- **Backend**: 
  - Node.js
  - Express
  - Mongoose for MongoDB interaction
  - Cors for handling cross-origin requests
- **Database**: 
  - MongoDB

## Installation

### Prerequisites
- Node.js and npm installed on your machine.
- MongoDB installed and running.

### Clone the Repository
```bash
git clone <repository-url>
cd quizzy
```

### Install Server Dependencies
```bash
cd server
npm install
```

### Install Client Dependencies
```bash
cd client
npm install
```

## Running the Application

### Run the Server
1. Open a terminal.
2. Navigate to the server directory:
   ```bash
   cd server
   ```
3. Start the server:
   ```bash
   node index.js
   ```
   The server will start on `http://localhost:3001`.

### Run the Client
1. Open a new terminal.
2. Navigate to the client directory:
   ```bash
   cd client
   ```
3. Start the client:
   ```bash
   npm start
   ```
   The client will open in your default web browser at `http://localhost:3000`.

## API Endpoints

### User Endpoints
- **POST /register**
  - Register a new user.
  - Request body: `{ name, email, password, role, dept, phone }`

- **POST /login**
  - Log in an existing user.
  - Request body: `{ email, password }`

### Quiz Endpoints
- **POST /addQuestions**
  - Add a new quiz.
  - Request body: `{ quizTopic, duration, questions }`

- **GET /questions/:topic**
  - Get questions for a specific quiz topic.
  - URL parameter: `topic`

### Mark Endpoints
- **POST /quiz-results**
  - Submit quiz results.
  - Request body: `{ topic, name, email, dept, score, answers }`

- **POST /check-quiz-attempt**
  - Check if a user has attempted a specific quiz.
  - Request body: `{ email, topic }`

- **POST /check-teacher-marks**
  - Get marks for a specific quiz topic.
  - Request body: `{ quizTopic }`

- **POST /check-student-marks**
  - Get marks for a specific student.
  - Request body: `{ email }`

# EduManage

Full-stack course management system built with MERN. Students enroll in courses, submit assignments, track attendance and grades. Instructors create/manage courses, grade submissions, and track student progress. Admins verify instructors, approve courses, and oversee platform.

## About The Project

EduManage is a complete educational management platform addressing the need for streamlined course and student management in institutions. It combines role-based access control with a modern, intuitive interface where students discover and enroll in courses, instructors manage content and assess work, and administrators oversee the entire ecosystem. The project demonstrates full-stack architecture with secure authentication, file handling, and real-time dashboards.

## Built With

- React 18, React Router, Tailwind CSS, Headless UI, Axios, React Hot Toast, Heroicons
- Node.js, Express.js, MongoDB, Mongoose, JWT, bcryptjs, Express Validator, Multer

## Getting Started

### Prerequisites

- Node.js 16 or higher
- npm or pnpm
- MongoDB (local or MongoDB Atlas)

### Installation

1. Clone the repo
   ```bash
   git clone https://github.com/tumansutradhar/edu-manage.git
   cd edu-manage
   ```

2. Backend setup
   ```bash
   cd backend
   npm install
   ```

3. Configure backend environment (`.env`)
   ```
   NODE_ENV=development
   PORT=5000
   MONGODB_URI=mongodb://127.0.0.1:27017/edumanage_db
   JWT_SECRET=your_super_secret_key_here_make_it_long
   JWT_EXPIRES_IN=7d
   ADMIN_EMAIL=admin@edumanage.com
   ADMIN_PASSWORD=SecureAdminPassword123!
   ADMIN_FIRST_NAME=System
   ADMIN_LAST_NAME=Administrator
   EMAIL_FROM=noreply@edumanage.com
   EMAIL_HOST=smtp.gmail.com
   EMAIL_PORT=587
   EMAIL_USER=your_email@gmail.com
   EMAIL_PASS=your_app_password
   MAX_FILE_SIZE=10485760
   UPLOAD_PATH=./uploads
   CLIENT_URL=http://localhost:3000
   ```

4. Start backend
   ```bash
   npm run dev
   ```

5. Frontend setup (new terminal)
   ```bash
   cd frontend
   npm install
   npm start
   ```

App runs at http://localhost:3000.

## Usage

- **Students:** Register, browse courses, enroll, access materials, submit assignments, track grades/attendance, message instructors
- **Instructors:** Verify account, create courses, upload content, manage enrollments, create/grade assignments, track attendance
- **Admins:** Approve instructors, approve courses, manage users, view analytics

Example student flow: Register → Browse courses → Enroll → Submit assignment → View grade.

## Features

- User authentication with JWT and role-based access
- Instructor verification workflow with document upload
- Course creation, approval, and enrollment with capacity management
- Assignment submissions (file and text) with grading and feedback
- Attendance tracking with status options and reporting
- Internal messaging between students and instructors
- Personalized role-specific dashboards
- File upload with validation and secure storage
- Password hashing with bcryptjs
- Input validation on all endpoints

## Project Structure

```
edu-manage/
├── backend/
│   ├── models/         # MongoDB schemas
│   ├── routes/         # API endpoints
│   ├── middleware/     # Auth and validation
│   ├── scripts/        # Admin seeding
│   ├── package.json
│   └── server.js
├── frontend/
│   ├── src/
│   │   ├── components/
│   │   ├── pages/
│   │   └── App.jsx
│   ├── package.json
│   └── tailwind.config.js
└── README.md
```

## Scripts

- **Backend:** `npm run dev` (start dev server with nodemon)
- **Backend:** `npm run create-admin` (seed initial admin user, if script exists)
- **Frontend:** `npm start` (start Vite dev server)
- **Frontend:** `npm run build` (production build)

## Roadmap

- [x] User authentication and role-based access
- [x] Course management with approvals
- [x] Assignment submission and grading
- [x] Attendance tracking
- [ ] Add unit and integration tests
- [ ] Implement automated email notifications
- [ ] Enhance analytics and reporting dashboards
- [ ] Add file storage to cloud (AWS S3 or similar)
- [ ] Improve mobile responsiveness
- [ ] Add two-factor authentication

## Contributing

Contributions are welcome. Fork the repo, create a feature branch, commit your changes, and open a pull request.

```bash
git checkout -b feature/YourFeature
git commit -m 'Add YourFeature'
git push origin feature/YourFeature
```

## License

Distributed under the MIT License. See `LICENSE.md` for more information.

## Contact

Tuman Sutradhar

- GitHub: [@tumansutradhar](https://github.com/tumansutradhar)
- Email: connect.tuman@gmail.com
- LinkedIn: [Tuman Sutradhar](https://www.linkedin.com/in/tumansutradhar/)

Project Link: [https://github.com/tumansutradhar/edu-manage](https://github.com/tumansutradhar/edu-manage)

## Acknowledgments

- MERN stack documentation and tutorials
- Tailwind CSS and Headless UI community
- MongoDB and Mongoose resources
- JWT authentication best practices
- Educational technology inspiration

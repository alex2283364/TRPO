# Schedulo - A Role-Based Access Control (RBAC) System for Managing and Scheduling Classes for Teachers
![Demo](https://github.com/user-attachments/assets/bdde407f-ab98-4473-b912-ab5280841e9f)

## Overview

This repository contains the codebase for Schedulo, a modern scheduling and management system for colleges. Built with React for the frontend and Node.js/Express for the backend, it facilitates the administration of class schedules, teacher assignments, and student management. It incorporates Role-Based Access Control (RBAC) to provide secure access for different users, including Admins, Teachers, and Students.

The system is designed to:
- **Manage Class Schedules**: Admins (Head of Department) can assign teachers to classes and manage class schedules.
- **RBAC Implementation**: A secure role-based access system where users are granted permissions based on their roles (Admin, Teacher, Student).
- **Teacher Availability**: Teachers can view their schedules, request changes, and see which classes they are assigned to.
- **User Management**: Admins can add, modify, or delete users and manage their roles and permissions.
## Test Deployed App
- **Issues**:
  - ✅The app is currently experiencing an issue with the frontend accessing cookies from the backend in the Render deployment.(Solved).Ensure that your browser is not blockng third-party cookies and cross-site tracking (this will prevent site from using cross-site cookies)
  - Responses are delayed due to limited resources in the free-tier hosting. Please be patient while performing operations during testing, as it might take some time to receive a response.
  - ✅All pages are functioning properly; however, rerouting has some issues with the hosting platform. (Solved).

[RBAC Frontend Dashboard](https://rbac-frontend-bu6e.onrender.com)  
## Technologies Used

- **Frontend**:
  - **React**: A powerful JavaScript library for building user interfaces.
  - **Redux**: For state management, ensuring efficient data flow across components.
  - **React Router**: For managing navigation and routing within the application.
  - **Tailwind CSS**: Used to build modern and responsive UIs.
  - **Framer Motion**: For adding animations and transitions.
  - **Lucide**: A collection of open-source icons, used in the app for a clean and modern interface.

- **Backend**:
  - **Node.js**: A JavaScript runtime environment used to build the server-side of the application.
  - **Express**: A web application framework for Node.js to handle routes and API requests.
  - **MongoDB**: A NoSQL database used to store user data, schedules, roles, and permissions.
  - **JWT (JSON Web Token)**: For secure authentication and role-based authorization.
  - **Bcrypt.js**: For password hashing to ensure security.
  - **Mongoose**: A MongoDB object modeling tool for Node.js, used to interact with MongoDB databases.

- **Other Tools**:
  - **Redux Toolkit**: For efficient and scalable Redux implementation.
  - **Axios**: For making HTTP requests from the frontend to the backend.
  - **dotenv**: For managing environment variables.
  - **Toastify**: For displaying notifications like success or error messages.

## Features

### 1. **Role-Based Access Control (RBAC)**

The system is built with a robust **Role-Based Access Control** to manage the access levels of different users. Each user is assigned one of the following roles:

- **Admin (HOD)**: Can manage schedules, approve/reject changes, assign teachers to classes, manage user roles, and perform administrative tasks.
- **Teacher**: Can view their schedule, request schedule changes, and manage their own profile.
- **Student**: Can view class schedules and teachers assigned to each class.

#### Role Flow and Permissions:

| Role      | Permissions                                                             |
|-----------|-------------------------------------------------------------------------|
| **Admin** | Can view, modify, delete schedules, manage users, assign teachers.       |
| **Teacher** | Can view their schedule, request changes, and manage own profile.    |
| **Student** | Can view class schedules and their assigned teachers.                 |

### 2. **Scheduling System**

The **Admin** (Head of Department) can assign teachers to various periods of the day, taking into account the availability of teachers. If a teacher is unavailable, the Admin can see that information and ensure that there are no scheduling conflicts.

### 3. **Teacher Assignment**

Teachers are dynamically assigned to classes based on the schedules. The system allows for:
- Viewing of schedules by teachers.
- Assigning teachers to specific time slots for particular classes.
- Removing or changing teacher assignments.

### 4. **Search and Filter**

A comprehensive **search and filter** system is implemented for schedules. Admins can filter by day, class, or teacher to view specific schedules quickly.

### 5. **User Management**

Admins can:
- Create, modify, and delete users.
- Assign roles (Admin, Teacher, Student) to users.
- Restrict access based on roles and permissions.

### 6. **Responsive Design**

The system uses a **responsive design**, ensuring that the application is fully functional across devices, from desktops to mobile phones.

## Project Structure

The project is structured to keep the code clean, organized, and maintainable:

```
├── backend
│   ├── Controllers
│   │   ├── Admin.js
│   │   ├── AssignS.js
│   │   ├── Auth.js
│   │   └── ViewS.js
│   ├── MiddleWare
│   │   └── VerifyToken.js
│   ├── Models
│   │   ├── class.js
│   │   ├── schedule.js
│   │   ├── teachers.js
│   │   └── user.js
│   ├── Routes
│   │   ├── AdminRoute.js
│   │   └── Auth.js
│   ├── Utils
│   │   └── db.js
│   └── server.js
├── frontend
│   ├── src
│   │   ├── components
│   │   │   ├── common
│   │   │   │   ├── Header.jsx
│   │   │   │   └── Sidebar.jsx
│   │   │   ├── schedule
│   │   │   │   └── ScheduleTable.jsx
│   │   │   └── users
│   │   │       └── UsersTable.jsx
│   │   ├── Layouts
│   │   │   ├── AdminLayout.jsx
│   │   │   └── UserLayout.jsx
│   │   ├── pages
│   │   │   ├── DashPage.jsx
│   │   │   ├── LoginPage.jsx
│   │   │   ├── SchedulePage.jsx
│   │   │   └── UsersPage.jsx
│   │   ├── Redux
│   │   │   ├── AuthSlice.js
│   │   │   └── Store.js
│   │   ├── App.jsx
│   │   └── main.jsx

```

## API Endpoints

The backend exposes the following API endpoints:

### Authentication & User Management
- **POST /api/auth/register** - Register a new user.
- **POST /api/auth/login** - Login and retrieve JWT token.
- **GET /api/admin/getusers** - Get a list of all users (Admin only).
- **DELETE /api/admin/delete/:id** - Delete a user (Admin only).

### Schedule Management
- **GET /api/admin/classS/:classId** - Fetch schedules for a specific class.
- **POST /api/admin/assignS** - Assign a teacher to a class.
- **POST /api/admin/deleteS/:scheduleId** - Delete a schedule entry.

## Database Models

### 1. **User Model**
```javascript
const UserSchema = new mongoose.Schema({
  name: { type: String, required: true },
  email: { type: String, required: true, unique: true },
  password: { type: String, required: true },
  role: { type: String, enum: ['Admin', 'Teacher', 'Student'], default: 'Student' },
});
```

### 2. **Schedule Model**
```javascript
const ScheduleSchema = new mongoose.Schema({
  teacherId: { type: mongoose.Schema.Types.ObjectId, ref: 'User' },
  classId: { type: String, required: true },
  day: { type: String, enum: ['M', 'T', 'W', 'Th', 'F'], required: true },
  period: { type: Number, required: true },
});
```


## Frontend Components

### 1. **ScheduleTable Component**
The `ScheduleTable` component is responsible for displaying the class schedule in a tabular format. It includes functionalities such as:
- Viewing teacher assignments.
- Assigning teachers to free periods using the "Plus" button.
- Deleting existing assignments.

### 2. **Sidebar Component**
The sidebar provides navigation between various parts of the application:
- Dashboard
- Schedules
- Users
- Settings

### 3. **UserProfile Component**
The `UserProfile` component allows teachers and students to view and edit their profiles. Admins can update any user's information.



## Setup Instructions

### Prerequisites
- MongoDB installed and running
- Node.js and npm installed

### Backend Setup
1. Clone the repository:
   ```bash
   git clone https://github.com/anugraheeth/RABC.git
   cd RBAC
   ```

2. Install dependencies:
   ```bash
   cd backend
   npm install
   ```

3. Set up environment variables in `.env` file:
   ```bash
   PORT=5000
   MONGODB=mongodb://localhost:27017/RBAC
   SECRET=your_jwt_secret
   ```

4. Import Collation Data
   The project includes a `RBAC.zip` file containing JSON files for initializing MongoDB collections. Follow these steps to import the data:

   a. Extract the `RBAC.zip` file
   
   b. Use MongoDB's `mongoimport` utility to import the collections:
   ```bash
   # Make sure you're in the directory containing the JSON files
   
   # Import Users Collection
   mongoimport --db RBAC --collection users --file users.json --jsonArray
   
   # Import Schedules Collection
   mongoimport --db RBAC --collection schedules --file schedules.json --jsonArray
   
   # Import Teachers Collection
   mongoimport --db RBAC --collection roles --file teacherss.json --jsonArray

   # Import Hods Collection
   mongoimport --db RBAC --collection roles --file hods.json --jsonArray

   # Import Students Collection
   mongoimport --db RBAC --collection roles --file roles.json --jsonArray

  
   ```

   Note: Replace `RBAC` with the database name specified in your `MONGODB`(.env) if different.

5. Start the server:
   ```bash
   npm start
   ```

### Frontend Setup
1. Navigate to the frontend folder:
   ```bash
   cd frontend
   ```

2. Install dependencies:
   ```bash
   npm install
   ```

3. Start the React application:
   ```bash
   npm start
   ```

### Running Both Backend and Frontend
You can run both the backend and frontend concurrently using tools like **Nodemon** for the backend and the default React development server for the frontend.

### Troubleshooting
- Ensure MongoDB is running before launching the application
- Verify that all JSON files from `RBAC.zip` are imported correctly
- Check that environment variables are correctly set
- Confirm that all dependencies are installed


### Running Both Backend and Frontend
You can run both the backend and frontend concurrently using tools like **Nodemon** for the backend and the default React development server for the frontend.

## Conclusion
**Schedulo** is an all-in-one platform for managing class schedules, teacher assiignments, and student data, with a strong focus on security through role-bassed acess control (RBAC). Built using **React**, **Redux**, and **Tailwind-CSS**, it ensures a seamless user experience while offering scalablility, maintainabiity, and efficiency for academic scheduling and management.


---

**Note**: Ensure that MongoDB is running before launching the application, and use valid environment variables for secure connections.

import 'bootstrap/dist/css/bootstrap.min.css'
import Register from "./Register.jsx"
import Login from "./Login.jsx"
import Home from "./Home.jsx"
import Create from "./Create.jsx"
import Dashboard from './Dashboard.jsx'
import Attempt from './Attempt.jsx'
import React from 'react'
import { BrowserRouter, Routes, Route } from 'react-router-dom';

function App() {
    return(
        <div>
            <BrowserRouter>
                <Routes>
                    <Route index element={<Home/>}></Route>
                    <Route path="/" element={<Home/>}></Route>
                    <Route path="/home" element={<Home/>}></Route>
                    <Route path="/register" element={<Register/>}></Route>
                    <Route path="/login" element={<Login/>}></Route>
                    <Route path="/dashboard" element={<Dashboard/>}></Route>
                    <Route path="/create" element={<Create/>}></Route>
                    <Route path="/attempt" element={<Attempt/>}></Route>
                </Routes>
            </BrowserRouter>
        </div>
    )
}

export default App;

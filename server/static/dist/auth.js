"use strict";
var __awaiter = (this && this.__awaiter) || function (thisArg, _arguments, P, generator) {
    function adopt(value) { return value instanceof P ? value : new P(function (resolve) { resolve(value); }); }
    return new (P || (P = Promise))(function (resolve, reject) {
        function fulfilled(value) { try { step(generator.next(value)); } catch (e) { reject(e); } }
        function rejected(value) { try { step(generator["throw"](value)); } catch (e) { reject(e); } }
        function step(result) { result.done ? resolve(result.value) : adopt(result.value).then(fulfilled, rejected); }
        step((generator = generator.apply(thisArg, _arguments || [])).next());
    });
};
document.addEventListener('DOMContentLoaded', () => {
    const loginForm = document.getElementById('loginForm');
    const loginContainer = document.getElementById('loginContainer');
    const bindContainer = document.getElementById('bindRoleContainer');
    const bindForm = document.getElementById('bindRoleForm');
    const bindMessageDiv = document.getElementById('bindMessage');
    const backToLogin = document.getElementById('backToLogin');
    const messageDiv = document.getElementById('message');
    let currentLogin = ''; // сохраняем логин для привязки
    // Обработка формы входа
    loginForm.addEventListener('submit', (e) => __awaiter(void 0, void 0, void 0, function* () {
        e.preventDefault();
        const login = document.getElementById('login').value.trim();
        const password = document.getElementById('password').value;
        messageDiv.innerHTML = '';
        messageDiv.className = '';
        if (!login || !password) {
            showMessage('Пожалуйста, заполните все поля', 'error', messageDiv);
            return;
        }
        try {
            const response = yield fetch('/login', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ login, password })
            });
            const result = yield response.json();
            if (result.authenticated) {
                if (result.role_bound) {
                    localStorage.setItem('username', login);
                    showMessage('Успешный вход! Перенаправление...', 'success', messageDiv);
                    setTimeout(() => window.location.href = '/mainpage.html', 500);
                }
                else {
                    currentLogin = login;
                    loginContainer.style.display = 'none';
                    bindContainer.style.display = 'block';
                }
            }
            else {
                showMessage('Неверный логин или пароль', 'error', messageDiv);
            }
        }
        catch (error) {
            console.error('Ошибка:', error);
            showMessage('Ошибка сети или сервера', 'error', messageDiv);
        }
    }));
    // Обработка привязки роли
    bindForm.addEventListener('submit', (e) => __awaiter(void 0, void 0, void 0, function* () {
        e.preventDefault();
        const rolePassword = document.getElementById('rolePassword').value.trim();
        bindMessageDiv.innerHTML = '';
        bindMessageDiv.className = '';
        if (!rolePassword) {
            showMessage('Введите код роли', 'error', bindMessageDiv);
            return;
        }
        try {
            const response = yield fetch('/bind-role', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ login: currentLogin, role_password: rolePassword })
            });
            const result = yield response.json();
            if (response.ok && result.success) {
                localStorage.setItem('username', currentLogin);
                showMessage('Роль привязана! Перенаправление...', 'success', bindMessageDiv);
                setTimeout(() => window.location.href = '/mainpage.html', 500);
            }
            else {
                const errorMsg = result.error || 'Ошибка привязки роли';
                showMessage(errorMsg, 'error', bindMessageDiv);
            }
        }
        catch (error) {
            console.error('Ошибка:', error);
            showMessage('Ошибка сети или сервера', 'error', bindMessageDiv);
        }
    }));
    // Возврат на форму входа
    backToLogin.addEventListener('click', (e) => {
        e.preventDefault();
        bindContainer.style.display = 'none';
        loginContainer.style.display = 'block';
        // Очищаем поле ввода кода
        document.getElementById('rolePassword').value = '';
        bindMessageDiv.innerHTML = '';
    });
    function showMessage(text, type, element) {
        element.textContent = text;
        element.classList.add(type);
    }
});

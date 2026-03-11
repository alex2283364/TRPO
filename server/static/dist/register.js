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
    const form = document.getElementById('registerForm');
    const messageDiv = document.getElementById('message');
    form.addEventListener('submit', (e) => __awaiter(void 0, void 0, void 0, function* () {
        e.preventDefault();
        const username = document.getElementById('username').value.trim();
        const email = document.getElementById('email').value.trim();
        const password = document.getElementById('password').value.trim();
        messageDiv.innerHTML = '';
        messageDiv.className = '';
        if (!username || !email || !password) {
            showMessage('Пожалуйста, заполните все поля', 'error');
            return;
        }
        // Простейшая валидация email
        if (!email.includes('@')) {
            showMessage('Введите корректный email', 'error');
            return;
        }
        const data = { username, email, password };
        try {
            const response = yield fetch('/users', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });
            if (response.status === 201) {
                const user = yield response.json();
                showMessage(`Регистрация успешна! Добро пожаловать, ${user.user_name}`, 'success');
                // Очистить форму
                form.reset();
                // Можно перенаправить на страницу входа через 2 секунды
                setTimeout(() => {
                    window.location.href = '/';
                }, 2000);
            }
            else if (response.status === 409) {
                const text = yield response.text();
                showMessage(text, 'error'); // "Пользователь с таким именем уже существует" или email
            }
            else {
                const text = yield response.text();
                showMessage(`Ошибка: ${text}`, 'error');
            }
        }
        catch (error) {
            console.error('Ошибка:', error);
            showMessage('Ошибка сети или сервера', 'error');
        }
    }));
    function showMessage(text, type) {
        messageDiv.textContent = text;
        messageDiv.classList.add(type);
    }
});

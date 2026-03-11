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
document.addEventListener('DOMContentLoaded', () => __awaiter(void 0, void 0, void 0, function* () {
    const infoDiv = document.getElementById('info');
    const errorDiv = document.getElementById('error');
    const username = localStorage.getItem('username');
    if (!username) {
        errorDiv.textContent = 'Необходимо войти в систему';
        setTimeout(() => window.location.href = '/', 500);
        return;
    }
    try {
        const response = yield fetch('/user-info', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username })
        });
        if (response.ok) {
            const data = yield response.json();
            infoDiv.innerHTML = `
                <div class="info-item">
                    <div class="label">Фамилия</div>
                    <div class="value">${data.lastname}</div>
                </div>
                <div class="info-item">
                    <div class="label">Имя</div>
                    <div class="value">${data.firstname}</div>
                </div>
                <div class="info-item">
                    <div class="label">Отчество</div>
                    <div class="value">${data.patronymic}</div>
                </div>
                <div class="info-item">
                    <div class="label">Группа</div>
                    <div class="value">${data.groupp}</div>
                </div>
            `;
        }
        else if (response.status === 404) {
            infoDiv.innerHTML = '<div class="info-item">Студент не найден</div>';
        }
        else {
            errorDiv.textContent = 'Ошибка загрузки данных';
        }
        fetch('/courses', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username })
        })
            .then(res => res.json())
            .then((courses) => {
            var _a;
            const coursesDiv = document.createElement('div');
            coursesDiv.innerHTML = '<h3>Доступные курсы</h3>';
            const list = document.createElement('ul');
            courses.forEach(course => {
                const item = document.createElement('li');
                const link = document.createElement('a');
                // Передаём данные через query-параметры (временное решение)
                link.href = `course.html?id=${course.id}&name=${encodeURIComponent(course.name)}&description=${encodeURIComponent(course.description)}&start_date=${course.start_date}&end_date=${course.end_date}`;
                link.textContent = course.name;
                item.appendChild(link);
                list.appendChild(item);
            });
            coursesDiv.appendChild(list);
            (_a = document.getElementById('info')) === null || _a === void 0 ? void 0 : _a.appendChild(coursesDiv);
        })
            .catch(err => {
            console.error('Ошибка загрузки курсов:', err);
        });
    }
    catch (error) {
        console.error('Ошибка:', error);
        errorDiv.textContent = 'Ошибка сети или сервера';
    }
}));

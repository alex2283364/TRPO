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
    const params = new URLSearchParams(window.location.search);
    const course = {
        id: params.get('id') || '',
        name: params.get('name') || '',
        description: params.get('description') || '',
        start_date: params.get('start_date') || '',
        end_date: params.get('end_date') || '',
    };
    const title = document.getElementById('courseTitle');
    const courseInfo = document.getElementById('courseInfo');
    const contentItems = document.getElementById('contentItems');
    const errorDiv = document.getElementById('error');
    if (!course.id) {
        errorDiv.textContent = 'Курс не найден';
        return;
    }
    // Отображаем основную информацию о курсе
    title.textContent = course.name;
    courseInfo.innerHTML = `
        <div class="field">
            <div class="label">Описание</div>
            <div class="value">${course.description}</div>
        </div>
        <div class="field">
            <div class="label">Дата начала</div>
            <div class="value">${course.start_date}</div>
        </div>
        <div class="field">
            <div class="label">Дата окончания</div>
            <div class="value">${course.end_date}</div>
        </div>
    `;
    const username = localStorage.getItem('username');
    if (!username) {
        errorDiv.textContent = 'Необходимо войти в систему';
        setTimeout(() => window.location.href = '/', 2000);
        return;
    }
    // Загружаем содержимое курса
    fetch(`/course-content/${course.id}?username=${encodeURIComponent(username)}`)
        .then((response) => __awaiter(void 0, void 0, void 0, function* () {
        if (response.status === 403) {
            errorDiv.textContent = 'У вас нет доступа к этому курсу';
            return null;
        }
        if (!response.ok) {
            const text = yield response.text();
            throw new Error(text);
        }
        return response.json();
    }))
        .then((items) => {
        if (!items)
            return;
        contentItems.innerHTML = '<h3>Содержание курса</h3>';
        // Сортируем по order (на всякий случай)
        //items.sort((a, b) => a.order - b.order);
        for (const item of items) {
            const div = document.createElement('div');
            div.className = 'content-item';
            if (item.type === 'text' && item.text) {
                div.innerHTML = `
                        <div class="text-content">${item.text.replace(/\n/g, '<br>')}</div>
                    `;
            }
            else if (item.type === 'file' && item.file) {
                div.innerHTML = `
                        <a href="/file/${item.file.id}" download>
                        ${item.file.file_name}.${item.file.extension}
                        </a>
                    `;
            }
            else {
                continue; // пропускаем пустые
            }
            contentItems.appendChild(div);
        }
    })
        .catch(err => {
        console.error('Ошибка загрузки содержимого:', err);
        errorDiv.textContent = 'Не удалось загрузить содержимое курса';
    });
});

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
// === ГЛОБАЛЬНЫЕ ФУНКЦИИ (доступны из HTML) ===

window.loadCourses = function() {
    const username = localStorage.getItem('username');
    
    const mainContainer = document.querySelector('.main-content');
    if (!mainContainer) return;
    
    mainContainer.innerHTML = '<h2>Мои курсы</h2><ul class="course-list"></ul>';
    
    const navContainer = document.querySelector('.nav-list');
    const coursesContainer = document.querySelector('.course-list');
    
    if (!navContainer || !coursesContainer) return;

    fetch('/courses', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: username || '' })
    })
    .then(res => res.json())
    .then((courses) => {
        // Обновляем навигацию
        navContainer.innerHTML = '<li><a href="" id="back-to-main">► В начало</a></li>';
        courses.forEach(course => {
            const li = document.createElement('li');
            const a = document.createElement('a');
            a.textContent = course.name;
            a.className="targetcourse";
            a.id="targetcourse";
            a.href = `course.html?&id=${course.id}&name=${encodeURIComponent(course.name)}&description=${encodeURIComponent(course.description)}&start_date=${course.start_date}&end_date=${course.end_date}`;
            li.appendChild(a);
            navContainer.appendChild(li);
        });
        
        // Обновляем основной список
        coursesContainer.innerHTML = '';
        courses.forEach(course => {
            const li = document.createElement('li');
            const a = document.createElement('a');
            a.textContent = course.name;
            a.id="targetcourse";
            a.href = `course.html?&id=${course.id}&name=${encodeURIComponent(course.name)}&description=${encodeURIComponent(course.description)}&start_date=${course.start_date}&end_date=${course.end_date}`;
            li.appendChild(a);
            coursesContainer.appendChild(li);
        });
        
        // Перепривязываем обработчик для кнопки "В начало"
        const backBtn = document.getElementById('back-to-main');
        if (backBtn) {
            backBtn.onclick = (e) => { e.preventDefault(); loadCourses(); };
        }
    })
    .catch(err => {
        console.error('Ошибка загрузки курсов:', err);
        if (navContainer) navContainer.innerHTML = '<li>Ошибка загрузки</li>';
        if (coursesContainer) coursesContainer.innerHTML = '<li>Ошибка загрузки</li>';
    });
}

window.loadUserInfo = function() {
    const username = localStorage.getItem('username');
    const mainContainer = document.querySelector('.main-content');
    const errorDiv = document.getElementById('error');
    
    if (!mainContainer) return;
    
    if (!username) {
        if (errorDiv) errorDiv.textContent = 'Необходимо войти в систему';
        setTimeout(() => window.location.href = '/', 500);
        return;
    }
    
    mainContainer.innerHTML = '<div class="loading">Загрузка...</div>';

    fetch('/user-info', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username })
    })
    .then(res => {
        if (res.ok) return res.json();
        else if (res.status === 404) throw new Error('not_found');
        else throw new Error('server_error');
    })
    //Переделать
    .then(data => {
        mainContainer.innerHTML = `
            <h2>Информация о пользователе</h2>
            <div class="info-item"><div class="label">Фамилия</div><div class="value">${data.lastname}</div></div>
            <div class="info-item"><div class="label">Имя</div><div class="value">${data.firstname}</div></div>
            <div class="info-item"><div class="label">Отчество</div><div class="value">${data.patronymic}</div></div>
            <div class="info-item"><div class="label">Группа</div><div class="value">${data.groupp}</div></div>
            <div id="user-courses"></div>
        `;
        
        // Загружаем курсы пользователя
        loadUserCourses();
        
    })
    .catch(err => {
        console.error('Ошибка:', err);
        if (err.message === 'not_found') {
            mainContainer.innerHTML = '<div class="info-item">Студент не найден</div>';
        } else {
            if (errorDiv) errorDiv.textContent = 'Ошибка сети или сервера';
            mainContainer.innerHTML = '<div class="error">Ошибка загрузки данных</div>';
        }
    });
}

function loadUserCourses() {
    const username = localStorage.getItem('username');
    const coursesContainer = document.getElementById('user-courses');
    if (!coursesContainer || !username) return;
    
    fetch('/courses', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username })
    })
    .then(res => res.json())
    .then(courses => {
        if (courses.length === 0) return;
        
        const coursesDiv = document.createElement('div');
        coursesDiv.className = 'courses-section';
        coursesDiv.innerHTML = '<h3>Доступные курсы</h3><ul></ul>';
        const list = coursesDiv.querySelector('ul');
        
        courses.forEach(course => {
            const item = document.createElement('li');
            const link = document.createElement('a');
            link.textContent = course.name;
            link.id="targetcourse";
            link.href = `course.html?id=${course.id}&name=${encodeURIComponent(course.name)}&description=${encodeURIComponent(course.description)}&start_date=${course.start_date}&end_date=${course.end_date}`;
            item.appendChild(link);
            list.appendChild(item);
        });
        
        coursesContainer.appendChild(coursesDiv);
    })
    .catch(err => console.error('Ошибка загрузки курсов:', err));
}

window.loadTargetCourse = function(coursedata) {
    console.log(coursedata);
    const params = new URLSearchParams(coursedata);
    const allParams = {};
    for (const [key, value] of params.entries()) {
    allParams[key] = decodeURIComponent(value);
}
console.log('Все параметры:', allParams);
    const course = {
        id: params.get('id') || '',
        name: params.get('name') || '',
        description: params.get('description') || '',
        start_date: params.get('start_date') || '',
        end_date: params.get('end_date') || '',
    };
    console.log(course);
    const courseInfo = document.querySelector('.main-content');
    courseInfo.innerHTML=`
        <h2 id="courseTitle">Загрузка...</h2> 
        <div id="courseInfo"></div>
        <div id="contentItems" class="content-items"></div>
        <div id="error" class="error"></div>`
        ;
    const title = document.getElementById('courseTitle');
    const contentItems = document.getElementById('contentItems');
    const errorDiv = document.getElementById('error');
    if (!course.id) {
        errorDiv.textContent = 'Курс не найден';
        return;
    }
    // Отображаем основную информацию о курсе
    title.textContent = course.name;
    contentItems.innerHTML = `
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
    //const username = localStorage.getItem('username');
    //if (!username) {
    //    errorDiv.textContent = 'Необходимо войти в систему';
     //   setTimeout(() => window.location.href = '/', 2000);
    //    return;
   // }
    // Загружаем содержимое курса
    fetch(`/course-content/${course.id}?username=${'test5'}`)
        .then((response) => __awaiter(void 0, void 0, void 0, function* () {
        if (response.status === 403) {
            errorDiv.textContent = 'У вас нет доступа к этому курсу';
            return null;
        }
        if (!response.ok) {
            const text = yield response.text();
            throw new Error(text);
        }
       // console.log('Содержимое курса:', response.json());
        return response.json();
    })).then((items) => {
        //throw new Error('Начало обработки');
        if (!items){
            throw new Error('Ничего не получено');
        }
        contentItems.innerHTML += '<h3>Содержание курса</h3>';
        // Сортируемлучай)
        //items.sort((a, b) => a.order - b.order); по order (на всякий с
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
}

// Некоректный вывод
window.updateCalendar = function() {
    const calendarMonth = document.querySelector('.calendar-month');
    const calendarGrid = document.querySelector('.calendar-grid');
    if (!calendarMonth || !calendarGrid) return;

    const now = new Date();
    const months = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь', 
                   'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    
    calendarMonth.textContent = `${months[now.getMonth()]} ${now.getFullYear()}`;
    
    const dayHeaders = Array.from(calendarGrid.querySelectorAll('.calendar-day-header'));
    calendarGrid.innerHTML = '';
    dayHeaders.forEach(h => calendarGrid.appendChild(h));
    
    const firstDay = new Date(now.getFullYear(), now.getMonth(), 1).getDay();
    const daysInMonth = new Date(now.getFullYear(), now.getMonth() + 1, 0).getDate();
    
    for (let i = 0; i < firstDay; i++) {
        const empty = document.createElement('div');
        empty.className = 'calendar-day other-month';
        calendarGrid.appendChild(empty);
    }
    for (let day = 1; day <= daysInMonth; day++) {
        const dayEl = document.createElement('div');
        dayEl.className = 'calendar-day' + (day === now.getDate() ? ' today' : '');
        dayEl.textContent = day;
        calendarGrid.appendChild(dayEl);
    }
}


// === ИНИЦИАЛИЗАЦИЯ ПРИ ЗАГРУЗКЕ СТРАНИЦЫ ===
document.addEventListener('DOMContentLoaded', () => {
    const username = localStorage.getItem('username');
    const helloUser = document.querySelector('.helloUser');
    
    if (username && helloUser) {
        helloUser.textContent = `Здравствуйте, ${username}!`;
    }
    
    // Загружаем курсы по умолчанию
    loadCourses();
    updateCalendar();
    
    // Обработчик для кнопки "Личный кабинет"
    const cabinetLink = document.querySelector('.cabinet-link');
    if (cabinetLink) {
        cabinetLink.addEventListener('click', (e) => {
            e.preventDefault();
            loadUserInfo();
        });
    }

    document.addEventListener('click', (e) => {
    if (e.target.classList.contains('targetcourse')) {
        e.preventDefault();
        const courseName = e.target.textContent.trim();
        console.log("Click on course:", courseName);
        
        // Здесь вызовите функцию загрузки курса
        // Например, с передачей данных:
        
        loadTargetCourse(e.target.href);
    }
});
});
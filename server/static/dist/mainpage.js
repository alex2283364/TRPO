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

window.loadCourses = function () {
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
                a.className = "targetcourse";
                a.id = "targetcourse";
                a.href = `&id=${course.id}&name=${encodeURIComponent(course.name)}&description=${encodeURIComponent(course.description)}&start_date=${course.start_date}&end_date=${course.end_date}`;
                li.appendChild(a);
                navContainer.appendChild(li);
            });

            // Обновляем основной список
            coursesContainer.innerHTML = '';
            courses.forEach(course => {
                const li = document.createElement('li');
                const a = document.createElement('a');
                a.textContent = course.name;
                a.id = "targetcourse";
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

window.loadUserInfo = function () {
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
                link.id = "targetcourse";
                link.href = `course.html?id=${course.id}&name=${encodeURIComponent(course.name)}&description=${encodeURIComponent(course.description)}&start_date=${course.start_date}&end_date=${course.end_date}`;
                item.appendChild(link);
                list.appendChild(item);
            });

            coursesContainer.appendChild(coursesDiv);
        })
        .catch(err => console.error('Ошибка загрузки курсов:', err));
}

window.loadTargetCourse = function (coursedata) {
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
    courseInfo.innerHTML = `
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
    const username = localStorage.getItem('username');
    if (!username) {
        errorDiv.textContent = 'Необходимо войти в систему';
        setTimeout(() => window.location.href = '/', 2000);
        return;
    }
    // Загружаем содержимое курса
    fetch(`/course-content/${course.id}?username=${username}`)
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
            if (!items) {
                throw new Error('Ничего не получено');
            }
            contentItems.innerHTML += '<h3>Содержание курса</h3>';
            // Сортируемлучай)
            //items.sort((a, b) => a.order - b.order); по order (на всякий с
            for (const item of items) {
                console.log(item.type);
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
                else if (item.type === 'task' && item.task) {
                    div.innerHTML = `
                        <a href="&id=${item.task.id}&time_id=${item.task.time_id}&name=${encodeURIComponent(item.task.name)}&qdescription=${encodeURIComponent(item.task.qdescription)}&adescription=${encodeURIComponent(item.task.adescription)}"
                        class="task">
                        ${item.task.name}
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

window.loadTargetTask = async function (taskData) {
    // 1. Парсим параметры из строки (исправляем возможный начальный '&')
    let paramsStr = taskData;
    if (paramsStr.startsWith('&')) {
        paramsStr = '?' + paramsStr.substring(1);
    }
    const params = new URLSearchParams(paramsStr);
    const task = {
        id: params.get('id') || '',
        time_id: params.get('time_id') || '',
        name: params.get('name') || '',
        qdescription: params.get('qdescription') || '',
        adescription: params.get('adescription') || ''
    };

    // 2. Подготовка DOM-элементов
    const taskInfo = document.querySelector('.main-content');
    if (!taskInfo) return;

    taskInfo.innerHTML = `
        <h2 id="courseTitle">Загрузка...</h2>
        <div id="courseInfo"></div>
        <div id="contentItems" class="content-items"></div>
        <div id="error" class="error"></div>
    `;
    const title = document.getElementById('courseTitle');
    const contentItems = document.getElementById('contentItems');
    const errorDiv = document.getElementById('error');

    if (!task.id || !task.time_id) {
        errorDiv.textContent = 'Некорректные параметры задания';
        return;
    }

    title.textContent = task.name;

    // 3. Получаем имя пользователя
    const username = localStorage.getItem('username');
    if (!username) {
        errorDiv.textContent = 'Необходимо войти в систему';
        setTimeout(() => window.location.href = '/', 2000);
        return;
    }

    // 4. Запрос к серверу
    try {
        const response = await fetch(`/task/${task.id}/${task.time_id}?username=${encodeURIComponent(username)}`);

        if (response.status === 403) {
            errorDiv.textContent = 'У вас нет доступа к этому заданию';
            return;
        }
        if (!response.ok) {
            const text = await response.text();
            throw new Error(text);
        }

        const data = await response.json();

        // 5. Отрисовка данных
        // Очищаем контейнер, оставляя возможность добавлять блоки
        contentItems.innerHTML = '';

        // 5.1. Описания (из параметров URL)
        if (task.qdescription) {
            const descBlock = document.createElement('div');
            descBlock.className = 'field';
            descBlock.innerHTML = `
                <div class="label">Описание задания</div>
                <div class="value">${task.qdescription.replace(/\n/g, '<br>')}</div>
            `;
            contentItems.appendChild(descBlock);
        }
        if (task.adescription) {
            const ansDescBlock = document.createElement('div');
            ansDescBlock.className = 'field';
            ansDescBlock.innerHTML = `
                <div class="label">Описание ответа</div>
                <div class="value">${task.adescription.replace(/\n/g, '<br>')}</div>
            `;
            contentItems.appendChild(ansDescBlock);
        }

        // 5.2. Временные рамки
        if (data.time) {
            const timeBlock = document.createElement('div');
            timeBlock.className = 'time-info';
            timeBlock.innerHTML = `
                <h3>Время выполнения</h3>
                <div class="field"><div class="label">Начало</div><div class="value">${data.time.start_date || '—'}</div></div>
                <div class="field"><div class="label">Окончание</div><div class="value">${data.time.end_date || '—'}</div></div>
            `;
            contentItems.appendChild(timeBlock);
        }

        // 5.3. Файлы задания
        if (data.task_files && data.task_files.length > 0) {
            const filesBlock = document.createElement('div');
            filesBlock.className = 'task-files';
            filesBlock.innerHTML = '<h3>Файлы задания</h3><ul></ul>';
            const list = filesBlock.querySelector('ul');
            data.task_files.forEach(file => {
                const li = document.createElement('li');
                const link = document.createElement('a');
                link.href = `/file/${file.id}`;
                link.download = true;
                link.textContent = `${file.file_name}.${file.extension}`;
                li.appendChild(link);
                list.appendChild(li);
            });
            contentItems.appendChild(filesBlock);
        }

        // 5.4. Результат выполнения
        if (data.result) {
            const resultBlock = document.createElement('div');
            resultBlock.className = 'task-result';
            resultBlock.innerHTML = `
                <h3>Результат</h3>
                <div class="field"><div class="label">Дата ответа</div><div class="value">${data.result.create_date || '—'}</div></div>
                <div class="field"><div class="label">Статус</div><div class="value">${data.result.validation || '—'}</div></div>
                <div class="field"><div class="label">Оценка</div><div class="value">${data.result.result !== undefined ? data.result.result : '—'}</div></div>
            `;
            if (data.result.answertext && data.result.answertext.length > 0) {
                resultBlock.innerHTML += `
                <div class="field"><div class="label">Представленный ответ на задание: </div><div class="value">${data.result.answertext ? data.result.answertext.replace(/\n/g, '<br>') : '—'}</div></div>
                `;
            }
            contentItems.appendChild(resultBlock);

            // 5.5. Файлы ответа (если есть)
            if (data.answer_files && data.answer_files.length > 0) {
                const answerFilesBlock = document.createElement('div');
                answerFilesBlock.className = 'answer-files';
                answerFilesBlock.innerHTML = '<h3>Файлы ответа</h3><ul></ul>';
                const list = answerFilesBlock.querySelector('ul');
                data.answer_files.forEach(file => {
                    const li = document.createElement('li');
                    const link = document.createElement('a');
                    link.href = `/file/${file.id}`;
                    link.download = true;
                    link.textContent = `${file.file_name}.${file.extension}`;
                    li.appendChild(link);
                    list.appendChild(li);
                });
                contentItems.appendChild(answerFilesBlock);
            }
        } else {
            const noResultBlock = document.createElement('div');
            noResultBlock.className = 'no-result';
            noResultBlock.innerHTML = `
            <p>Задание еще не сдано.</p>
            <button id="submitTaskBtn" class="btn">Сдать задание</button>
            <div id="answerFormContainer" style="display:none;"></div>
            `;
            contentItems.appendChild(noResultBlock);

            // Обработчик кнопки сдачи
            document.getElementById('submitTaskBtn')?.addEventListener('click', () => {
                const container = document.getElementById('answerFormContainer');
                if (!container) return;

                // Если форма уже показана – скрываем, иначе показываем и заполняем
                if (container.style.display === 'block') {
                    container.style.display = 'none';
                    container.innerHTML = '';
                    return;
                }

                // Создаём форму
                container.style.display = 'block';
                container.innerHTML = `
        <h3>Сдать задание</h3>
        <form id="answerForm">
            <div class="field">
                <label for="answerText">Ваш ответ (текст):</label>
                <textarea id="answerText" name="answertext" rows="5" style="width:100%;"></textarea>
            </div>
            <div class="field">
                <label for="answerFile">Прикрепить файл (необязательно):</label>
                <input type="file" id="answerFile" name="file">
            </div>
            <button type="submit" class="btn">Отправить</button>
            <button type="button" id="cancelAnswer" class="btn">Отмена</button>
        </form>
        <div id="answerStatus" class="status"></div>
    `;

                const form = document.getElementById('answerForm');
                const cancelBtn = document.getElementById('cancelAnswer');

                cancelBtn?.addEventListener('click', () => {
                    container.style.display = 'none';
                    container.innerHTML = '';
                });

                form?.addEventListener('submit', async (e) => {
                    e.preventDefault();

                    const answerText = document.getElementById('answerText').value;
                    const fileInput = document.getElementById('answerFile');
                    const file = fileInput?.files?.[0];

                    let fileId = null;

                    // Загрузка файла, если выбран
                    if (file) {
                        const formData = new FormData();
                        formData.append('file', file);
                        formData.append('username', username);

                        try {
                            const uploadRes = await fetch('/upload', {
                                method: 'POST',
                                body: formData
                            });
                            if (!uploadRes.ok) throw new Error('Ошибка загрузки файла');
                            const uploadData = await uploadRes.json();
                            fileId = uploadData.file_id;
                        } catch (err) {
                            console.error(err);
                            document.getElementById('answerStatus').textContent = 'Не удалось загрузить файл';
                            return;
                        }
                    }

                    // Отправляем данные ответа
                    const payload = {
                        username: username,
                        answer_id: 0,           // 0 = создать новый результат
                        task_id: Number(task.id),
                        answertext: answerText,
                        file_id: Number(fileId) !== null ? fileId : -1   // если файла нет, передаём -1 (или null, но процедура ожидает integer)
                    };

                    try {
                        const response = await fetch('/set-answer', {
                            method: 'POST',
                            headers: { 'Content-Type': 'application/json' },
                            body: JSON.stringify(payload)
                        });
                        if (!response.ok) {
                            const errText = await response.text();
                            throw new Error(errText);
                        }
                        const result = await response.json();
                        if (result.success) {
                            document.getElementById('answerStatus').textContent = 'Ответ успешно сохранён!';
                            // Перезагружаем задание, чтобы увидеть результат
                            setTimeout(() => loadTargetTask(taskData), 1500);
                        } else {
                            document.getElementById('answerStatus').textContent = result.error || 'Ошибка сохранения';
                        }
                    } catch (err) {
                        console.error(err);
                        document.getElementById('answerStatus').textContent = 'Ошибка связи с сервером';
                    }
                });
            });
        }

    } catch (err) {
        console.error('Ошибка загрузки задания:', err);
        errorDiv.textContent = 'Не удалось загрузить данные задания';
    }
};


// Некоректный вывод
window.updateCalendar = function () {
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
    document.addEventListener('click', (e) => {
        if (e.target.classList.contains('task')) {
            e.preventDefault();
            const taskName = e.target.textContent.trim();
            console.log("Click on task:", taskName);

            // Здесь вызовите функцию загрузки курса
            // Например, с передачей данных:

            loadTargetTask(e.target.href);
        }


    });
});
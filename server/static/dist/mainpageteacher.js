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



// === ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ ДЛЯ РАБОТЫ С URL ===
function updateUrlAndState(newUrl) {
    const current = window.location.pathname + window.location.search;
    if (current !== newUrl) {
        history.pushState(null, '', newUrl);
    }
}

function restoreStateFromURL() {
    const path = window.location.pathname;
    const search = window.location.search;

    if (path === '/' || (path === '' && !search)) {
        loadCourses();
    } else if (path === '/profile') {
        loadTeacherInfo();
    } else if (path === '/course') {
        const params = new URLSearchParams(search);
        let paramStr = '';
        for (let [key, value] of params.entries()) {
            paramStr += `&${key}=${encodeURIComponent(value)}`;
        }
        if (paramStr) paramStr = paramStr.substring(1);
        loadTargetCourse(paramStr);
    } else if (path === '/task') {
        const params = new URLSearchParams(search);
        let paramStr = '';
        for (let [key, value] of params.entries()) {
            paramStr += `&${key}=${encodeURIComponent(value)}`;
        }
        if (paramStr) paramStr = paramStr.substring(1);
        loadTargetTask(paramStr);
    } else if (path === '/test') {
        const params = new URLSearchParams(search);
        let paramStr = '';
        for (let [key, value] of params.entries()) {
            paramStr += `&${key}=${encodeURIComponent(value)}`;
        }
        if (paramStr) paramStr = paramStr.substring(1);
        loadTargetTest(paramStr);
    } else if (path === '/test-run') {
        const params = new URLSearchParams(search);
        const testId = params.get('test_id');
        const attemptId = params.get('attempt_id');
        if (testId && attemptId) {
            document.querySelector('.main-content').innerHTML = '<div class="error">Тест уже начат. Обновление страницы временно не поддерживается.</div>';
        }
    } else {
        loadCourses();
    }
}

// === ГЛОБАЛЬНЫЕ ФУНКЦИИ (доступны из HTML) ===

window.loadCourses = function () {
    const username = localStorage.getItem('username');
    const mainContainer = document.querySelector('.main-content');
    if (!mainContainer) return;

    mainContainer.innerHTML = '<h2>Мои курсы</h2><ul class="course-list"></ul>';

    const navContainer = document.querySelector('.nav-list');
    const coursesContainer = document.querySelector('.course-list');
    if (!navContainer || !coursesContainer) return;

    fetch('/courses-teacher', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username: username || '' })
    })
        .then(res => res.json())
        .then((courses) => {
            navContainer.innerHTML = '<li><a href="#" id="back-to-main">► В начало</a></li>';
            courses.forEach(course => {
                const li = document.createElement('li');
                const a = document.createElement('a');
                a.textContent = course.name;
                a.className = "targetcourse";
                a.id = "targetcourse";
                a.href = `?id=${course.id}&name=${encodeURIComponent(course.name)}&description=${encodeURIComponent(course.description)}&start_date=${course.start_date}&end_date=${course.end_date}`;
                li.appendChild(a);
                navContainer.appendChild(li);
            });

            coursesContainer.innerHTML = '';
            courses.forEach(course => {
                const li = document.createElement('li');
                const a = document.createElement('a');
                li.id = "coursesContainer";
                a.textContent = course.name;
                a.className = "targetcourse";
                a.id = "targetcourse";
                a.href = `?id=${course.id}&name=${encodeURIComponent(course.name)}&description=${encodeURIComponent(course.description)}&start_date=${course.start_date}&end_date=${course.end_date}`;
                li.appendChild(a);
                coursesContainer.appendChild(li);
                li.innerHTML += `
                    <p>${course.description}</p>
                    <p>Начало: ${course.start_date}</p>
                    <p>Окончание: ${course.end_date}</p>`;
            });

            const backBtn = document.getElementById('back-to-main');
            if (backBtn) {
                backBtn.onclick = (e) => { e.preventDefault(); loadCourses(); };
            }

            updateUrlAndState('/');
        })
        .catch(err => {
            console.error('Ошибка загрузки курсов:', err);
            if (navContainer) navContainer.innerHTML = '<li>Ошибка загрузки</li>';
            if (coursesContainer) coursesContainer.innerHTML = '<li>Ошибка загрузки</li>';
        });
};

window.loadTeacherInfo = function () {
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

    fetch('/teacher-info', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ username })
    })
        .then(res => {
            if (res.ok) return res.json();
            else if (res.status === 404) throw new Error('not_found');
            else throw new Error('server_error');
        })
        .then(data => {
            mainContainer.innerHTML = `
                <h2 class="user-info-title">Информация о преподавателе</h2>
                <div id="user-courses">
                    <div class="info-row"><div class="label">Фамилия: ${data.lastname}</div></div>
                    <div class="info-row"><div class="label">Имя: ${data.firstname}</div></div>
                    <div class="info-row"><div class="label">Отчество: ${data.patronymic}</div></div>
                </div>
            `;
            updateUrlAndState('/profile');
        })
        .catch(err => {
            console.error('Ошибка:', err);
            if (err.message === 'not_found') {
                mainContainer.innerHTML = '<div class="info-item">Преподаватель не найден</div>';
            } else {
                if (errorDiv) errorDiv.textContent = 'Ошибка сети или сервера';
                mainContainer.innerHTML = '<div class="error">Ошибка загрузки данных</div>';
            }
        });
};

function loadUserCourses() {
    const username = localStorage.getItem('username');
    const coursesContainer = document.getElementById('user-courses');
    if (!coursesContainer || !username) return;

    fetch('/courses-teacher', {
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
                link.href = `?id=${course.id}&name=${encodeURIComponent(course.name)}&description=${encodeURIComponent(course.description)}&start_date=${course.start_date}&end_date=${course.end_date}`;
                item.appendChild(link);
                list.appendChild(item);
            });

            coursesContainer.appendChild(coursesDiv);
        })
        .catch(err => console.error('Ошибка загрузки курсов:', err));
}

window.loadCourseGroups = async function (courseId) {
    const mainContainer = document.querySelector('.main-content');
    const errorDiv = document.getElementById('error');

    if (!mainContainer) return;

    mainContainer.innerHTML = '<div class="loading">Загрузка списка студентов...</div>';

    try {
        const response = await fetch('/course-groups', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ course_id: Number(courseId) })
        });

        if (!response.ok) {
            throw new Error(`Ошибка HTTP: ${response.status}`);
        }

        const groups = await response.json();

        if (!groups.length) {
            mainContainer.innerHTML = '<div class="info-item">На этот курс не назначено ни одной группы</div>';
            return;
        }

        let html = '<h2>Группы и студенты курса</h2>';
        for (const group of groups) {
            html += `
                <div class="group-card">
                    <h3>Группа: ${escapeHtml(group.name)} (${escapeHtml(group.academic_year)})</h3>
                    <p> Максимум студентов: ${group.max_students}</p>
                    ${group.students.length ? `
                        <table class="students-table">
                            <thead>
                                <tr><th>Логин</th><th>Фамилия</th><th>Имя</th><th>Отчество</th><th>Код студента</th></tr>
                            </thead>
                            <tbody>
                                ${group.students.map(s => `
                                    <tr>
                                        <td>${escapeHtml(s.user_name)}</td>
                                        <td>${escapeHtml(s.lastname)}</td>
                                        <td>${escapeHtml(s.firstname)}</td>
                                        <td>${escapeHtml(s.patronymic)}</td>
                                        <td>${escapeHtml(s.student_code)}</td>
                                    </tr>
                                `).join('')}
                            </tbody>
                        </table>
                    ` : '<p>В группе нет студентов</p>'}
                </div>
            `;
        }
        mainContainer.innerHTML = html;
        updateUrlAndState(`/course/${courseId}/students`);
    } catch (err) {
        console.error('Ошибка загрузки групп и студентов:', err);
        if (errorDiv) errorDiv.textContent = 'Не удалось загрузить список студентов';
        mainContainer.innerHTML = '<div class="error">Ошибка загрузки данных</div>';
    }
};

// === ФУНКЦИИ ДЛЯ ДОБАВЛЕНИЯ ЗАДАНИЯ ===

window.showAddTaskForm = function(courseId) {
    const mainContainer = document.querySelector('.main-content');
    if (!mainContainer) return;

    mainContainer.dataset.currentCourseId = courseId;

    const formHtml = `
        <div class="add-task-form-container">
            <h3>Добавить новое задание</h3>
            <form id="addTaskForm" class="add-task-form" enctype="multipart/form-data">
                <div class="form-group">
                    <label for="taskName">Название задания:</label>
                    <input type="text" id="taskName" name="name" required class="form-control" placeholder="Введите название задания">
                </div>
                
                <div class="form-group">
                    <label for="taskDescription">Описание задания:</label>
                    <textarea id="taskDescription" name="description" rows="5" required class="form-control" placeholder="Опишите что нужно сделать..."></textarea>
                </div>
                
                <div class="form-group">
                    <label for="taskAnswerDesc">Описание ответа (что нужно сдать):</label>
                    <textarea id="taskAnswerDesc" name="answer_description" rows="3" class="form-control" placeholder="Например: SQL запрос, файл с кодом и т.д."></textarea>
                </div>

                <!-- === НОВАЯ СЕКЦИЯ ДЛЯ ФАЙЛОВ === -->
                <div class="form-group">
                    <label>Файлы задания (если есть):</label>
                    <div class="file-upload-area" id="dropZone">
                        <input type="file" id="taskFiles" name="files[]" multiple class="file-input-hidden">
                        <div class="file-upload-content">
                            <span class="icon">📁</span>
                            <p>Перетащите файлы сюда или нажмите для выбора</p>
                            <span class="file-hint">Можно загрузить несколько файлов</span>
                        </div>
                        <div id="fileList" class="file-list"></div>
                    </div>
                </div>
                <!-- ================================= -->
                
                <div class="form-group">
                    <label>Время выполнения:</label>
                    <div class="datetime-row">
                        <div class="datetime-field">
                            <label for="startDate">Начало:</label>
                            <input type="datetime-local" id="startDate" name="start_date" class="form-control">
                        </div>
                        <div class="datetime-field">
                            <label for="endDate">Окончание:</label>
                            <input type="datetime-local" id="endDate" name="end_date" class="form-control">
                        </div>
                    </div>
                </div>
                
                <div class="form-actions">
                    <button type="submit" class="btn btn-primary">Создать задание</button>
                    <button type="button" class="btn btn-secondary" onclick="cancelAddTask()">Отмена</button>
                </div>
            </form>
        </div>
    `;

    mainContainer.innerHTML = formHtml;

    // Логика Drag & Drop и выбора файлов
    const dropZone = document.getElementById('dropZone');
    const fileInput = document.getElementById('taskFiles');
    const fileListContainer = document.getElementById('fileList');

    dropZone.addEventListener('click', () => fileInput.click());

    dropZone.addEventListener('dragover', (e) => {
        e.preventDefault();
        dropZone.classList.add('drag-over');
    });

    dropZone.addEventListener('dragleave', () => {
        dropZone.classList.remove('drag-over');
    });

    dropZone.addEventListener('drop', (e) => {
        e.preventDefault();
        dropZone.classList.remove('drag-over');
        handleFiles(e.dataTransfer.files, fileInput, fileListContainer);
    });

    fileInput.addEventListener('change', () => {
        handleFiles(fileInput.files, fileInput, fileListContainer);
    });

    // Функция отправки
    const form = document.getElementById('addTaskForm');
    if (form) {
        form.addEventListener('submit', async (e) => {
            e.preventDefault();
            await submitNewTask(courseId);
        });
    }

    updateUrlAndState(`/course/add-task?id=${courseId}`);
};

// Вспомогательная функция для отображения выбранных файлов
function handleFiles(files, fileInput, container) {
    container.innerHTML = '';
    // Обновляем файлы в инпуте (для отправки)
    const dt = new DataTransfer();
    for (let i = 0; i < files.length; i++) {
        const file = files[i];
        dt.items.add(file);
        
        // Добавляем визуальный элемент списка
        const fileItem = document.createElement('div');
        fileItem.className = 'file-item';
        fileItem.innerHTML = `
            <span class="file-icon">📄</span>
            <span class="file-name">${file.name}</span>
            <span class="file-size">(${(file.size / 1024).toFixed(1)} KB)</span>
            <button type="button" class="remove-file" data-index="${i}">×</button>
        `;
        container.appendChild(fileItem);
    }
    fileInput.files = dt.files;
    
    // Обработчики удаления файлов из списка
    document.querySelectorAll('.remove-file').forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.stopPropagation(); // Чтобы не срабатывал клик по зоне
            const index = parseInt(btn.dataset.index);
            const newDt = new DataTransfer();
            for (let i = 0; i < fileInput.files.length; i++) {
                if (i !== index) newDt.items.add(fileInput.files[i]);
            }
            fileInput.files = newDt.files;
            handleFiles(fileInput.files, fileInput, container); // Перерисовать
        });
    });
}

window.cancelAddTask = function() {
    const mainContainer = document.querySelector('.main-content');
    if (!mainContainer) return;
    
    const previousContent = mainContainer.dataset.previousContent;
    const courseId = mainContainer.dataset.currentCourseId;
    
    if (previousContent && courseId) {
        // Возвращаемся к просмотру курса
        const courseParams = new URLSearchParams(window.location.search);
        const courseData = `?id=${courseId}&name=${courseParams.get('name')}&description=${courseParams.get('description')}&start_date=${courseParams.get('start_date')}&end_date=${courseParams.get('end_date')}`;
        loadTargetCourse(courseData);
    } else {
        loadCourses();
    }
};

async function submitNewTask(courseId) {
    const form = document.getElementById('addTaskForm');
    if (!form) return;
    
    // Используем FormData для отправки файлов
    const formData = new FormData(form);
    formData.append('course_id', Number(courseId));
    
    const username = localStorage.getItem('username');
    if (!username) {
        alert('Необходимо войти в систему');
        return;
    }
    formData.append('username', username);

    try {
        // Отправляем как multipart/form-data (не нужно указывать Content-Type в заголовках, браузер сам)
        const response = await fetch('/create-task', {
            method: 'POST',
            body: formData 
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(errorText || 'Ошибка сервера');
        }

        const result = await response.json();
        
        if (result.success || result.task_id) {
            alert('Задание успешно создано!');
            // Возвращаемся к просмотру курса
            const courseParams = new URLSearchParams(window.location.search);
            const courseData = `?id=${courseId}&name=${courseParams.get('name')}&description=${courseParams.get('description')}&start_date=${courseParams.get('start_date')}&end_date=${courseParams.get('end_date')}`;
            loadTargetCourse(courseData);
        } else {
            throw new Error(result.message || 'Неизвестная ошибка');
        }
    } catch (err) {
        console.error('Ошибка при создании задания:', err);
        alert('Не удалось создать задание: ' + err.message);
    }
}

window.loadTargetCourse = function (coursedata) {
    let paramsStr = coursedata;
    if (paramsStr.startsWith('?')) {
        paramsStr = '&' + paramsStr.substring(1);
    }
    const params = new URLSearchParams(paramsStr);
    const course = {
        id: params.get('id') || '',
        name: params.get('name') || '',
        description: params.get('description') || '',
        start_date: params.get('start_date') || '',
        end_date: params.get('end_date') || '',
    };

    const courseInfo = document.querySelector('.main-content');
    courseInfo.innerHTML = `
        <h2 id="courseTitle">Загрузка...</h2> 
        <div id="courseInfo"></div>
        <div id="contentItems" class="content-items"></div>
        <div id="error" class="error"></div>`;
    const title = document.getElementById('courseTitle');
    const contentItems = document.getElementById('contentItems');
    const errorDiv = document.getElementById('error');

    if (!course.id) {
        errorDiv.textContent = 'Курс не найден';
        return;
    }

    title.textContent = course.name;
    contentItems.innerHTML = `
        <div class="field">
            <div class="label">Общее</div>
            <div class="value">${course.description}</div>
            <div class="label">Дата начала</div>
            <div class="value">${course.start_date}</div>
            <div class="label">Дата окончания</div>
            <div class="value">${course.end_date}</div>
        </div>
    `;

    const studentsLinkDiv = document.createElement('div');
    studentsLinkDiv.className = 'students-link-wrapper';
    studentsLinkDiv.innerHTML = `<a href="#" id="showCourseStudentsLink" class="students-link">Показать группы и студентов курса</a>`;
    contentItems.appendChild(studentsLinkDiv);

    document.getElementById('showCourseStudentsLink').addEventListener('click', (e) => {
        e.preventDefault();
        window.loadCourseGroups(course.id);
    });

    const username = localStorage.getItem('username');
    if (!username) {
        errorDiv.textContent = 'Необходимо войти в систему';
        setTimeout(() => window.location.href = '/', 2000);
        return;
    }

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
            return response.json();
        })).then((items) => {
            if (!items) {
                throw new Error('Ничего не получено');
            }
            const descBlock = document.createElement('div');
            descBlock.className = 'field';
            descBlock.innerHTML = `<h3>Содержание курса</h3>`;
            contentItems.appendChild(descBlock);

            for (const item of items) {
                const div = document.createElement('div');
                div.className = 'content-item';
                if (item.type === 'text' && item.text) {
                    div.innerHTML = `<div class="text-content">${item.text.replace(/\n/g, '<br>')}</div>`;
                } else if (item.type === 'file' && item.file) {
                    div.innerHTML = `<a href="/file/${item.file.id}" download>${item.file.file_name}.${item.file.extension}</a>`;
                } else if (item.type === 'task' && item.task) {
                    div.innerHTML = `<a href="?task_id=${item.task.id}&time_id=${item.task.time_id}&name=${encodeURIComponent(item.task.name)}&qdescription=${encodeURIComponent(item.task.qdescription)}&adescription=${encodeURIComponent(item.task.adescription)}" class="task">${item.task.name}</a>`;
                } else if (item.type === 'test' && item.test) {
                    const test = item.test;
                    div.innerHTML = `<a href="?test_id=${test.id}&title=${encodeURIComponent(test.title)}&description=${encodeURIComponent(test.description || '')}&time_limit_seconds=${test.time_limit_seconds || ''}&max_attempts=${test.max_attempts}" class="test">${test.title}</a>`;
                } else {
                    continue;
                }
                descBlock.appendChild(div);
            }

            // === ДОБАВЛЯЕМ КНОПКУ "ДОБАВИТЬ ЗАДАНИЕ" ===
            const addTaskButtonDiv = document.createElement('div');
            addTaskButtonDiv.className = 'add-task-button-wrapper';
            addTaskButtonDiv.innerHTML = `
                <button id="addTaskBtn" class="btn btn-add-task">
                    <span class="icon">+</span> Добавить задание
                </button>
            `;
            descBlock.appendChild(addTaskButtonDiv);

            // Добавляем обработчик для кнопки
            document.getElementById('addTaskBtn').addEventListener('click', () => {
                showAddTaskForm(course.id);
            });

            const newUrl = `/course?id=${course.id}&name=${encodeURIComponent(course.name)}&description=${encodeURIComponent(course.description)}&start_date=${course.start_date}&end_date=${course.end_date}`;
            updateUrlAndState(newUrl);
        })
        .catch(err => {
            console.error('Ошибка загрузки содержимого:', err);
            errorDiv.textContent = 'Не удалось загрузить содержимое курса';
        });
};

window.loadTargetTask = async function (taskData) {
    let paramsStr = taskData;
    if (paramsStr.startsWith('?')) {
        paramsStr = '&' + paramsStr.substring(1);
    }
    const params = new URLSearchParams(paramsStr);
    const task = {
        id: params.get('task_id') || params.get('id') || '',
        time_id: params.get('time_id') || '',
        name: params.get('name') || '',
        qdescription: params.get('qdescription') || '',
        adescription: params.get('adescription') || ''
    };

    const taskInfo = document.querySelector('.main-content');
    if (!taskInfo) return;

    taskInfo.innerHTML = `
        <h2 id="courseTitle">Загрузка...</h2>
        <div id="courseInfo"></div>
        <div id="contentItems" class="content-items"></div>
        <div id="resultsSection"></div>
        <div id="error" class="error"></div>
    `;
    const title = document.getElementById('courseTitle');
    const contentItems = document.getElementById('contentItems');
    const resultsSection = document.getElementById('resultsSection');
    const errorDiv = document.getElementById('error');

    if (!task.id || !task.time_id) {
        errorDiv.textContent = 'Некорректные параметры задания';
        return;
    }

    title.textContent = task.name;

    const username = localStorage.getItem('username');
    if (!username) {
        errorDiv.textContent = 'Необходимо войти в систему';
        setTimeout(() => window.location.href = '/', 2000);
        return;
    }

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
        contentItems.innerHTML = '';

        if (task.qdescription) {
            const descBlock = document.createElement('div');
            descBlock.className = 'field';
            descBlock.innerHTML = `<div class="label">Общее</div><div class="value">${escapeHtml(task.qdescription).replace(/\n/g, '<br>')}</div>`;
            contentItems.appendChild(descBlock);
        }
        if (task.adescription) {
            const ansDescBlock = document.createElement('div');
            ansDescBlock.className = 'field';
            ansDescBlock.innerHTML = `<div class="label">Описание ответа</div><div class="value">${escapeHtml(task.adescription).replace(/\n/g, '<br>')}</div>`;
            contentItems.appendChild(ansDescBlock);
        }

        if (data.time) {
            const timeBlock = document.createElement('div');
            timeBlock.className = 'time-info';
            timeBlock.innerHTML = `
                <h3>Время выполнения</h3>
                <div class="field"><div class="label">Начало</div><div class="value">${escapeHtml(data.time.start_date || '—')}</div></div>
                <div class="field"><div class="label">Окончание</div><div class="value">${escapeHtml(data.time.end_date || '—')}</div></div>
            `;
            contentItems.appendChild(timeBlock);
        }

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
                link.textContent = `${escapeHtml(file.file_name)}.${escapeHtml(file.extension)}`;
                li.appendChild(link);
                list.appendChild(li);
            });
            contentItems.appendChild(filesBlock);
        }

        await loadTaskResults(task.id, resultsSection);

        let newUrl = `/task?task_id=${task.id}&time_id=${task.time_id}&name=${encodeURIComponent(task.name)}&qdescription=${encodeURIComponent(task.qdescription)}&adescription=${encodeURIComponent(task.adescription)}`;
        updateUrlAndState(newUrl);
    } catch (err) {
        console.error('Ошибка загрузки задания:', err);
        errorDiv.textContent = 'Не удалось загрузить данные задания';
    }
};

async function loadTaskResults(taskId, container) {
    if (!container) return;

    try {
        const response = await fetch('/task-results', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ task_id: Number(taskId) })
        });

        if (!response.ok) {
            throw new Error(`Ошибка HTTP: ${response.status}`);
        }

        const results = await response.json();

        if (!results || results.length === 0) {
            container.innerHTML = '<div class="info-item">Нет результатов для этого задания</div>';
            return;
        }

        let tableHtml = `
            <h3>Результаты выполнения задания</h3>
            <div class="results-table-wrapper">
                <table class="results-table">
                    <thead>
                        <tr>
                            <th>Фамилия</th>
                            <th>Имя</th>
                            <th>Отчество</th>
                            <th>Группа</th>
                            <th>Текст ответа</th>
                            <th>Результат проверки</th>
                            <th>Файлы ответа</th>
                            <th>Статус проверки</th>
                            <th>Действие</th>
                        </tr>
                    </thead>
                    <tbody>
        `;

        for (const result of results) {
            let filesHtml = '';
            if (result.answer_files && result.answer_files.length > 0) {
                filesHtml = '<ul class="answer-files-list">';
                result.answer_files.forEach(file => {
                    filesHtml += `<li><a href="/file/${file.id}" download>${escapeHtml(file.file_name)}.${escapeHtml(file.extension)}</a></li>`;
                });
                filesHtml += '</ul>';
            } else {
                filesHtml = '—';
            }

            const statusTextMap = {
                'verification': 'Ожидает проверки',
                'aproved': 'Принято',
                'rejected': 'Отклонено',
                'redevelopment': 'На доработку'
            };
            const statusText = statusTextMap[result.validation_status] || result.validation_status;
            const statusClass = result.validation_status || 'verification';

            tableHtml += `
                <tr data-result-id="${result.result_id}" data-validation-status="${escapeHtml(result.validation_status)}">
                    <td>${escapeHtml(result.lastname)}</td>
                    <td>${escapeHtml(result.firstname)}</td>
                    <td>${escapeHtml(result.patronymic)}</td>
                    <td>${escapeHtml(result.groupp)}</td>
                    <td class="answer-text-cell">${result.answertext ? escapeHtml(result.answertext).replace(/\n/g, '<br>') : '—'}</td>
                    <td class="result-cell">${result.result ? escapeHtml(result.result).replace(/\n/g, '<br>') : '—'}</td>
                    <td class="files-cell">${filesHtml}</td>
                    <td class="status-cell ${statusClass}">${escapeHtml(statusText)}</td>
                    <td class="action-cell">
                        <button class="evaluate-btn" data-result-id="${result.result_id}" data-current-result="${escapeHtml(result.result || '')}" data-current-status="${escapeHtml(result.validation_status)}">Оценить</button>
                    </td>
                </tr>
            `;
        }

        tableHtml += `
                    </tbody>
                </table>
            </div>
        `;

        container.innerHTML = tableHtml;

        addTableStyles();

        document.querySelectorAll('.evaluate-btn').forEach(btn => {
            btn.addEventListener('click', async (e) => {
                e.preventDefault();
                const resultId = parseInt(btn.dataset.resultId);
                const currentResult = btn.dataset.currentResult;
                const currentStatus = btn.dataset.currentStatus;
                await showEvaluationDialog(resultId, currentResult, currentStatus, taskId, container);
            });
        });

    } catch (err) {
        console.error('Ошибка загрузки результатов задания:', err);
        container.innerHTML = '<div class="error">Не удалось загрузить результаты выполнения задания</div>';
    }
}

async function showEvaluationDialog(resultId, currentResult, currentStatus, taskId, container) {
    const modal = document.createElement('div');
    modal.className = 'evaluation-modal';
    modal.innerHTML = `
        <div class="modal-content">
            <h4>Оценка работы</h4>
            <label>Результат проверки:</label>
            <textarea id="eval-result" rows="3" style="width:100%">${escapeHtml(currentResult)}</textarea>
            <label>Статус проверки:</label>
            <select id="eval-status" style="width:100%">
                <option value="verification" ${currentStatus === 'verification' ? 'selected' : ''}>Ожидает проверки</option>
                <option value="aproved" ${currentStatus === 'aproved' ? 'selected' : ''}>Принято</option>
                <option value="rejected" ${currentStatus === 'rejected' ? 'selected' : ''}>Отклонено</option>
                <option value="redevelopment" ${currentStatus === 'redevelopment' ? 'selected' : ''}>На доработку</option>
            </select>
            <label>Комментарий (необязательно):</label>
            <textarea id="eval-comment" rows="3" style="width:100%" placeholder="Введите комментарий к работе..."></textarea>
            <div style="margin-top: 15px; text-align: right;">
                <button id="modal-cancel">Отмена</button>
                <button id="modal-submit">Сохранить</button>
            </div>
        </div>
    `;
    document.body.appendChild(modal);

    modal.addEventListener('click', (e) => {
        if (e.target === modal) modal.remove();
    });

    const cancelBtn = modal.querySelector('#modal-cancel');
    const submitBtn = modal.querySelector('#modal-submit');

    cancelBtn.addEventListener('click', () => modal.remove());

    submitBtn.addEventListener('click', async () => {
        const newResult = modal.querySelector('#eval-result').value.trim();
        const newStatus = modal.querySelector('#eval-status').value;
        const commentText = modal.querySelector('#eval-comment').value.trim();

        if (!newResult) {
            alert('Пожалуйста, заполните результат проверки');
            return;
        }

        const username = localStorage.getItem('username');
        if (!username) {
            alert('Необходимо войти в систему');
            modal.remove();
            return;
        }

        const payload = {
            validation: newStatus,
            result: newResult,
            task_id: Number(taskId),
            task_result_id: Number(resultId),
            username: username
        };
        if (commentText) {
            payload.comment_text = commentText;
        }

        try {
            const response = await fetch('/update-task-validation', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(payload)
            });

            if (!response.ok) {
                const errorText = await response.text();
                throw new Error(errorText || 'Ошибка сервера');
            }

            const data = await response.json();
            if (data.success) {
                alert('Оценка и комментарий сохранены');
                modal.remove();
                await loadTaskResults(taskId, container);
            } else {
                throw new Error(data.message || 'Неизвестная ошибка');
            }
        } catch (err) {
            console.error('Ошибка при сохранении:', err);
            alert('Не удалось сохранить: ' + err.message);
        }
    });
}

function addTableStyles() {
    if (document.getElementById('task-results-styles')) return;

    const style = document.createElement('style');
    style.id = 'task-results-styles';
    style.textContent = `
        .results-table-wrapper { overflow-x: auto; margin-top: 20px; }
        .results-table { width: 100%; border-collapse: collapse; font-size: 14px; }
        .results-table th, .results-table td { border: 1px solid #ddd; padding: 10px; text-align: left; vertical-align: top; }
        .results-table th { background-color: #4CAF50; color: white; font-weight: bold; position: sticky; top: 0; }
        .results-table tr:nth-child(even) { background-color: #f9f9f9; }
        .results-table tr:hover { background-color: #f5f5f5; }
        .answer-text-cell, .result-cell { max-width: 300px; word-wrap: break-word; }
        .files-cell ul { margin: 0; padding-left: 20px; }
        .status-cell { font-weight: bold; text-align: center; }
        .status-cell.verification { background-color: #fff3cd; color: #856404; }
        .status-cell.aproved { background-color: #d4edda; color: #155724; }
        .status-cell.rejected { background-color: #f8d7da; color: #721c24; }
        .status-cell.redevelopment { background-color: #d1ecf1; color: #0c5460; }
        .action-cell { text-align: center; }
        .evaluate-btn { padding: 5px 10px; background-color: #007bff; color: white; border: none; border-radius: 4px; cursor: pointer; }
        .evaluate-btn:hover { background-color: #0056b3; }

        .evaluation-modal {
            position: fixed;
            top: 0; left: 0;
            width: 100%; height: 100%;
            background: rgba(0,0,0,0.5);
            display: flex;
            justify-content: center;
            align-items: center;
            z-index: 1000;
        }
        .evaluation-modal .modal-content {
            background: white;
            padding: 20px;
            border-radius: 8px;
            width: 400px;
            max-width: 90%;
            box-shadow: 0 2px 10px rgba(0,0,0,0.3);
        }
        .evaluation-modal h4 { margin-top: 0; }
        .evaluation-modal label { display: block; margin-top: 10px; font-weight: bold; }
        .evaluation-modal button { margin-left: 10px; padding: 5px 15px; cursor: pointer; }
    `;
    document.head.appendChild(style);
}

window.loadTargetTest = async function (testData) {
    let paramsStr = testData;
    if (paramsStr.startsWith('?')) {
        paramsStr = '&' + paramsStr.substring(1);
    }
    const params = new URLSearchParams(paramsStr);
    const test = {
        id: params.get('test_id') || params.get('id') || '',
        title: params.get('title') || '',
        description: params.get('description') || '',
        time_limit_seconds: params.get('time_limit_seconds') || '',
        max_attempts: params.get('max_attempts') || ''
    };

    const mainContainer = document.querySelector('.main-content');
    if (!mainContainer) return;

    mainContainer.innerHTML = `
        <h2 id="testTitle">Загрузка...</h2>
        <div id="testInfo"></div>
        <div id="testActions"></div>
        <div id="error" class="error"></div>
        <div id="testResultsContainer"></div>
    `;
    const titleEl = document.getElementById('testTitle');
    const testInfo = document.getElementById('testInfo');
    const actionsDiv = document.getElementById('testActions');
    const errorDiv = document.getElementById('error');
    const resultsContainer = document.getElementById('testResultsContainer');

    if (!test.id) {
        errorDiv.textContent = 'Некорректные параметры теста';
        return;
    }

    titleEl.textContent = test.title;

    let infoHtml = `<div class="field"><div class="label">Описание</div><div class="value">${test.description ? test.description.replace(/\n/g, '<br>') : '—'}</div></div>`;
    if (test.time_limit_seconds) {
        const minutes = Math.floor(test.time_limit_seconds / 60);
        const seconds = test.time_limit_seconds % 60;
        infoHtml += `<div class="field"><div class="label">Время на прохождение</div><div class="value">${minutes} мин ${seconds} сек</div></div>`;
    } else {
        infoHtml += `<div class="field"><div class="label">Время на прохождение</div><div class="value">Не ограничено</div></div>`;
    }
    infoHtml += `<div class="field"><div class="label">Максимум попыток</div><div class="value">${test.max_attempts || '1'}</div></div>`;
    testInfo.innerHTML = infoHtml;

    const bestResultContainer = document.createElement('div');
    bestResultContainer.id = 'bestResultContainer';
    bestResultContainer.className = 'best-result-container';
    testInfo.appendChild(bestResultContainer);

    try {
        const response = await fetch('/test-results', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ test_id: Number(test.id) })
        });
        if (!response.ok) {
            const errText = await response.text();
            resultsContainer.innerHTML = `<div class="error">Ошибка загрузки результатов: ${errText}</div>`;
            return;
        }
        const results = await response.json();
        if (!results.length) {
            resultsContainer.innerHTML = '<div class="info">Нет результатов по данному тесту.</div>';
        } else {
            let tableHtml = `
            <div class="table-container">
                <h3>Результаты студентов</h3>
                <table class="results-table">
                    <thead>
                        <tr><th>Фамилия</th><th>Имя</th><th>Отчество</th><th>Группа</th><th>Набрано баллов</th><th>Максимум баллов</th><th>Процент</th></tr>
                    </thead>
                    <tbody>
            `;
            for (const row of results) {
                tableHtml += `
                    <tr>
                        <td>${escapeHtml(row.lastname)}</td>
                        <td>${escapeHtml(row.firstname)}</td>
                        <td>${escapeHtml(row.patronymic)}</td>
                        <td>${escapeHtml(row.groupp)}</td>
                        <td>${row.total_points}</td>
                        <td>${row.max_points}</td>
                        <td>${row.percentage}%</td>
                    </tr>
                `;
            }
            tableHtml += `</tbody></table></div>`;
            resultsContainer.innerHTML = tableHtml;
        }
    } catch (err) {
        console.error(err);
        resultsContainer.innerHTML = '<div class="error">Ошибка при получении результатов теста</div>';
    }

    const newUrl = `/test?test_id=${test.id}&title=${encodeURIComponent(test.title)}&description=${encodeURIComponent(test.description)}&time_limit_seconds=${test.time_limit_seconds}&max_attempts=${test.max_attempts}`;
    updateUrlAndState(newUrl);
};

async function startTestAttempt(testId, testTitle) {
    const username = localStorage.getItem('username');
    if (!username) {
        alert('Необходимо войти в систему');
        window.location.href = '/';
        return;
    }

    try {
        const response = await fetch(`/test/${testId}/questions?username=${encodeURIComponent(username)}`);
        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(errorText);
        }
        const data = await response.json();
        const attemptId = data.attempt_id;
        const questions = data.questions;
        const endTimeStr = data.end_time;
        renderTestPage(testTitle, testId, questions, attemptId, endTimeStr);
    } catch (err) {
        console.error('Ошибка начала теста:', err);
        alert('Не удалось начать тест: ' + err.message);
    }
}

function renderTestPage(title, test_id, questions, attemptId, endTimeStr) {
    const mainContainer = document.querySelector('.main-content');
    if (!mainContainer) return;

    mainContainer.innerHTML = `
        <h2>${escapeHtml(title)}</h2>
        <div id="testTimer" class="timer" style="font-weight:bold; margin-bottom:20px;"></div>
        <form id="testForm">
            <div id="questionsContainer"></div>
            <button type="button" id="submitTestBtn" class="btn">Завершить тест</button>
        </form>
        <div id="testError" class="error"></div>
    `;

    const questionsContainer = document.getElementById('questionsContainer');
    if (!questionsContainer) return;

    questions.forEach((q, idx) => {
        const qDiv = document.createElement('div');
        qDiv.className = 'question';
        qDiv.style.marginBottom = '20px';
        qDiv.style.padding = '10px';
        qDiv.style.border = '1px solid #ccc';
        qDiv.style.borderRadius = '5px';

        qDiv.innerHTML = `<p><strong>${idx + 1}. ${escapeHtml(q.question_text)}</strong> (${q.points} баллов)</p>`;

        const optionsContainer = document.createElement('div');
        optionsContainer.className = 'question-options';
        optionsContainer.style.marginLeft = '20px';

        if (q.question_type === 'single_choice') {
            if (q.options && q.options.length > 0) {
                q.options.forEach(opt => {
                    const label = document.createElement('label');
                    label.style.display = 'block';
                    label.style.margin = '5px 0';
                    const radio = document.createElement('input');
                    radio.type = 'radio';
                    radio.name = `question_${q.id}`;
                    radio.value = opt.sort_order;
                    label.appendChild(radio);
                    label.appendChild(document.createTextNode(' ' + escapeHtml(opt.option_text)));
                    optionsContainer.appendChild(label);
                });
            } else {
                optionsContainer.innerHTML = '<p class="info">Нет вариантов ответа</p>';
            }
        }
        else if (q.question_type === 'multiple_choice') {
            if (q.options && q.options.length > 0) {
                q.options.forEach(opt => {
                    const label = document.createElement('label');
                    label.style.display = 'block';
                    label.style.margin = '5px 0';
                    const checkbox = document.createElement('input');
                    checkbox.type = 'checkbox';
                    checkbox.name = `question_${q.id}[]`;
                    checkbox.value = opt.sort_order;
                    label.appendChild(checkbox);
                    label.appendChild(document.createTextNode(' ' + escapeHtml(opt.option_text)));
                    optionsContainer.appendChild(label);
                });
            } else {
                optionsContainer.innerHTML = '<p class="info">Нет вариантов ответа</p>';
            }
        }
        else if (q.question_type === 'text') {
            const textarea = document.createElement('textarea');
            textarea.name = `question_${q.id}`;
            textarea.rows = 3;
            textarea.style.width = '100%';
            optionsContainer.appendChild(textarea);
        }
        else {
            optionsContainer.innerHTML = '<p class="error">Неизвестный тип вопроса</p>';
        }

        qDiv.appendChild(optionsContainer);
        questionsContainer.appendChild(qDiv);
    });

    if (endTimeStr) {
        const endTime = new Date(endTimeStr).getTime();
        startTimer(endTime);
    } else {
        const timerDiv = document.getElementById('testTimer');
        if (timerDiv) timerDiv.textContent = 'Время не ограничено';
    }

    const submitBtn = document.getElementById('submitTestBtn');
    if (submitBtn) {
        submitBtn.addEventListener('click', () => {
            finishTest(test_id, attemptId, questions);
        });
    }
    
    const newUrl = `/test-run?test_id=${test_id}&attempt_id=${attemptId}`;
    updateUrlAndState(newUrl);
}

async function finishTest(testId, attemptId, questions) {
    const answers = [];

    for (const q of questions) {
        const questionId = q.id;
        let answer = null;

        if (q.question_type === 'single_choice') {
            const selectedRadio = document.querySelector(`input[name="question_${questionId}"]:checked`);
            answer = selectedRadio ? parseInt(selectedRadio.value, 10) : null;
        }
        else if (q.question_type === 'multiple_choice') {
            const checkboxes = document.querySelectorAll(`input[name="question_${questionId}[]"]:checked`);
            answer = Array.from(checkboxes).map(cb => parseInt(cb.value, 10));
        }
        else if (q.question_type === 'text') {
            const textarea = document.querySelector(`textarea[name="question_${questionId}"]`);
            answer = textarea ? textarea.value.trim() : '';
        }

        answers.push({
            question_id: questionId,
            answer: answer
        });
    }
    try {
        const response = await fetch('/test/submit', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                test_id: 1,
                attempt_id: attemptId,
                answers: answers
            })
        });

        if (!response.ok) {
            const errorText = await response.text();
            throw new Error(errorText);
        }

        const result = await response.json();
        alert(`Тест завершён! Результат: ${result.score}/${result.max_score}`);

        if (confirm('Вернуться к курсу?')) {
            window.history.back();
        } else {
            loadCourses();
        }
    } catch (err) {
        console.error('Ошибка при отправке теста:', err);
        document.getElementById('testError').textContent = 'Ошибка сохранения ответов: ' + err.message;
    }
}

function startTimer(endTimestamp) {
    const timerElement = document.getElementById('testTimer');
    if (!timerElement) return;

    const interval = setInterval(() => {
        const now = Date.now();
        const remaining = endTimestamp - now;
        if (remaining <= 0) {
            clearInterval(interval);
            timerElement.textContent = 'Время вышло!';
            if (confirm('Время вышло. Завершить тест?')) {
                document.getElementById('submitTestBtn')?.click();
            }
        } else {
            const minutes = Math.floor(remaining / 60000);
            const seconds = Math.floor((remaining % 60000) / 1000);
            timerElement.textContent = `Осталось времени: ${minutes} мин ${seconds} сек`;
        }
    }, 1000);
}

function escapeHtml(str) {
    if (!str) return '';
    return str.replace(/[&<>"']/g, function (m) {
        if (m === '&') return '&amp;';
        if (m === '<') return '&lt;';
        if (m === '>') return '&gt;';
        if (m === '"') return '&quot;';
        if (m === "'") return '&#039;';
        return m;
    });
}

// === КАЛЕНДАРЬ ===
window.calendarState = { currentDate: new Date() };

window.updateCalendar = function (targetDate = null) {
    const calendarMonth = document.querySelector('.calendar-month');
    const calendarGrid = document.querySelector('.calendar-grid');
    if (!calendarMonth || !calendarGrid) return;

    const displayDate = targetDate ? new Date(targetDate) : window.calendarState.currentDate;
    window.calendarState.currentDate = displayDate;

    const months = ['Январь', 'Февраль', 'Март', 'Апрель', 'Май', 'Июнь',
        'Июль', 'Август', 'Сентябрь', 'Октябрь', 'Ноябрь', 'Декабрь'];
    const dayNames = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];

    calendarMonth.textContent = `${months[displayDate.getMonth()]} ${displayDate.getFullYear()}`;
    calendarGrid.innerHTML = '';

    dayNames.forEach(day => {
        const header = document.createElement('div');
        header.className = 'calendar-day-header';
        header.textContent = day;
        calendarGrid.appendChild(header);
    });

    const firstDay = new Date(displayDate.getFullYear(), displayDate.getMonth(), 1).getDay();
    const daysInMonth = new Date(displayDate.getFullYear(), displayDate.getMonth() + 1, 0).getDate();
    const adjustedFirstDay = firstDay === 0 ? 6 : firstDay - 1;

    for (let i = 0; i < adjustedFirstDay; i++) {
        const empty = document.createElement('div');
        empty.className = 'calendar-day other-month';
        calendarGrid.appendChild(empty);
    }

    const today = new Date();
    const isCurrentMonth = displayDate.getMonth() === today.getMonth() &&
        displayDate.getFullYear() === today.getFullYear();

    for (let day = 1; day <= daysInMonth; day++) {
        const dayEl = document.createElement('div');
        dayEl.className = 'calendar-day' + (isCurrentMonth && day === today.getDate() ? ' today' : '');
        dayEl.textContent = day;
        dayEl.dataset.date = `${displayDate.getFullYear()}-${String(displayDate.getMonth() + 1).padStart(2, '0')}-${String(day).padStart(2, '0')}`;
        calendarGrid.appendChild(dayEl);
    }
};

// === ИНИЦИАЛИЗАЦИЯ ===
document.addEventListener('DOMContentLoaded', () => {
    restoreStateFromURL();

    window.updateCalendar();
    document.querySelectorAll('.calendar-nav').forEach(btn => {
        btn.addEventListener('click', (e) => {
            const direction = e.target.textContent.trim();
            const current = window.calendarState.currentDate;
            const newDate = new Date(current);
            if (direction === '←') newDate.setMonth(newDate.getMonth() - 1);
            else if (direction === '→') newDate.setMonth(newDate.getMonth() + 1);
            window.updateCalendar(newDate);
        });
    });

    const username = localStorage.getItem('username');
    const helloUser = document.querySelector('.helloUser');
    
    if (username && helloUser) {
        helloUser.textContent = `Здравствуйте, ${username}!`;
    
        fetch('/user-info', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username })
        })
        .then(res => res.ok ? res.json() : null)
        .then(data => {
            if (data) {
                const fio = [data.lastname, data.firstname, data.patronymic]
                            .filter(part => part && part.trim() !== '')
                            .join(' ');
                
                if (fio) {
                    helloUser.textContent = `Здравствуйте, ${fio}!`;
                }
            }
        })
        .catch(err => console.warn('Не удалось загрузить ФИО для приветствия:', err));
    }

    const cabinetLink = document.querySelector('.cabinet-link');
    if (cabinetLink) {
        cabinetLink.addEventListener('click', (e) => {
            e.preventDefault();
            loadTeacherInfo();
        });
    }

    document.addEventListener('click', (e) => {
        if (e.target.classList.contains('targetcourse')) {
            e.preventDefault();
            const url = new URL(e.target.href);
            loadTargetCourse(url.search);
        }
    });

    document.addEventListener('click', (e) => {
        if (e.target.classList.contains('task')) {
            e.preventDefault();
            const url = new URL(e.target.href);
            loadTargetTask(url.search);
        }
        if (e.target.classList.contains('test')) {
            e.preventDefault();
            const url = new URL(e.target.href);
            loadTargetTest(url.search);
        }
    });

    window.addEventListener('popstate', () => {
        restoreStateFromURL();
    });
});
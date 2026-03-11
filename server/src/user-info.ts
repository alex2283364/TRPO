interface StudentInfo {
    lastname: string;
    firstname: string;
    patronymic: string;
    groupp: string;
}

interface Course {
    id: number;
    name: string;
    description: string;
    start_date: string;
    end_date: string;
}

document.addEventListener('DOMContentLoaded', async () => {
    const infoDiv = document.getElementById('info') as HTMLDivElement;
    const errorDiv = document.getElementById('error') as HTMLDivElement;

    const username = localStorage.getItem('username');
    if (!username) {
        errorDiv.textContent = 'Необходимо войти в систему';
        setTimeout(() => window.location.href = '/', 500);
        return;
    }

    try {
        const response = await fetch('/user-info', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username })
        });

        if (response.ok) {
            const data: StudentInfo = await response.json();
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
        } else if (response.status === 404) {
            infoDiv.innerHTML = '<div class="info-item">Студент не найден</div>';
        } else {
            errorDiv.textContent = 'Ошибка загрузки данных';
        }
        fetch('/courses', {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ username })
        })
            .then(res => res.json())
            .then((courses: Course[]) => {
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
                document.getElementById('info')?.appendChild(coursesDiv);
            })
            .catch(err => {
                console.error('Ошибка загрузки курсов:', err);
            });
    } catch (error) {
        console.error('Ошибка:', error);
        errorDiv.textContent = 'Ошибка сети или сервера';
    }
});
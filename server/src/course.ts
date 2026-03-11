interface CourseParams {
    id: string;
    name: string;
    description: string;
    start_date: string;
    end_date: string;
}

document.addEventListener('DOMContentLoaded', () => {
    const params = new URLSearchParams(window.location.search);
    const course: CourseParams = {
        id: params.get('id') || '',
        name: params.get('name') || '',
        description: params.get('description') || '',
        start_date: params.get('start_date') || '',
        end_date: params.get('end_date') || '',
    };

    const container = document.getElementById('courseInfo') as HTMLDivElement;

    if (!course.id) {
        container.innerHTML = '<p>Курс не найден</p>';
        return;
    }

    container.innerHTML = `
        <div class="field">
            <div class="label">Название</div>
            <div class="value">${course.name}</div>
        </div>
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
});
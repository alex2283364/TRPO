interface RegisterRequest {
    username: string;
    email: string;
    password: string;
}

interface UserResponse {
    id: number;
    user_name: string;
    email: string;
    create_at: string;
}

document.addEventListener('DOMContentLoaded', () => {
    const form = document.getElementById('registerForm') as HTMLFormElement;
    const messageDiv = document.getElementById('message') as HTMLDivElement;

    form.addEventListener('submit', async (e: Event) => {
        e.preventDefault();

        const username = (document.getElementById('username') as HTMLInputElement).value.trim();
        const email = (document.getElementById('email') as HTMLInputElement).value.trim();
        const password = (document.getElementById('password') as HTMLInputElement).value.trim();

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

        const data: RegisterRequest = { username, email, password };

        try {
            const response = await fetch('/users', {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify(data)
            });

            if (response.status === 201) {
                const user: UserResponse = await response.json();
                showMessage(`Регистрация успешна! Добро пожаловать, ${user.user_name}`, 'success');
                // Очистить форму
                form.reset();
                // Можно перенаправить на страницу входа через 2 секунды
                setTimeout(() => {
                    window.location.href = '/';
                }, 2000);
            } else if (response.status === 409) {
                const text = await response.text();
                showMessage(text, 'error'); // "Пользователь с таким именем уже существует" или email
            } else {
                const text = await response.text();
                showMessage(`Ошибка: ${text}`, 'error');
            }
        } catch (error) {
            console.error('Ошибка:', error);
            showMessage('Ошибка сети или сервера', 'error');
        }
    });

    function showMessage(text: string, type: 'success' | 'error') {
        messageDiv.textContent = text;
        messageDiv.classList.add(type);
    }
});